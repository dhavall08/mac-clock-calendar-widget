import AppKit
import Combine
import SwiftUI

/// Keeps one `WidgetPanel` per visible instance in sync with `AppState`.
///
/// `AppState` is the only writer of widget geometry; this class translates it
/// into Cocoa frames and back (when the user drags a panel).
@MainActor
final class WidgetWindowController: NSObject, NSWindowDelegate {

    private let state: AppState
    private var panels: [UUID: WidgetPanel] = [:]
    private var cancellables: Set<AnyCancellable> = []
    /// Suppresses `windowDidMove` bookkeeping while we're the ones moving it.
    private var isApplyingGeometry = false

    var onOpenSettings: ((UUID) -> Void)?

    init(state: AppState) {
        self.state = state
        super.init()

        state.instanceChanged
            .sink { [weak self] id in self?.sync(id) }
            .store(in: &cancellables)

        state.rosterChanged
            .sink { [weak self] _ in self?.syncAll() }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.syncAll() }
            .store(in: &cancellables)
    }

    // MARK: Sync

    func syncAll() {
        for instance in state.instances { sync(instance.id) }
        // Tear down panels for instances that no longer exist.
        let live = Set(state.instances.map(\.id))
        for (id, panel) in panels where !live.contains(id) {
            panel.orderOut(nil)
            panels[id] = nil
        }
    }

    func sync(_ id: UUID) {
        guard let instance = state.instance(id) else {
            panels[id]?.orderOut(nil)
            panels[id] = nil
            return
        }

        guard instance.chrome.isVisible else {
            panels[id]?.orderOut(nil)
            panels[id] = nil
            return
        }

        let panel = panels[id] ?? makePanel(for: id)
        apply(chrome: instance.chrome, to: panel, id: id)
    }

    private func makePanel(for id: UUID) -> WidgetPanel {
        let panel = WidgetPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 380))
        panel.delegate = self
        panel.identifier = NSUserInterfaceItemIdentifier(id.uuidString)

        let root = WidgetShell(state: state, id: id, onOpenSettings: { [weak self] in
            self?.onOpenSettings?(id)
        })
        let hosting = NSHostingView(rootView: AnyView(root))
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        panels[id] = panel
        return panel
    }

    private func apply(chrome: WidgetChrome, to panel: WidgetPanel, id: UUID) {
        isApplyingGeometry = true
        defer { isApplyingGeometry = false }

        // The shell keeps a transparent margin for its toolbar, grip and glow.
        var size = WidgetShellMetrics.windowSize(for: state.renderedSize(for: id))

        // 1. Settle on a position first: `maxScale` needs to know which display
        //    the widget is on before it can decide what "too big" means.
        let topLeft = resolvedTopLeft(chrome: chrome, size: size, id: id)
        if chrome.originX != topLeft.x || chrome.originY != topLeft.y {
            // `recordOrigin` deliberately doesn't republish, so this can't loop.
            state.recordOrigin(id, topLeft: topLeft)
        }

        // 2. A scale saved on a bigger display (or before a monitor was
        //    unplugged) would hang off the screen — pull it back in.
        let limit = state.maxScale(for: id)
        if chrome.scale > limit + 0.001 {
            var clamped = chrome
            clamped.scale = limit
            state.updateChrome(id, clamped)   // re-enters sync with the new size
            return
        }

        size = WidgetShellMetrics.windowSize(for: state.renderedSize(for: id))
        let frame = NSRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height)
        panel.setFrame(frame, display: true)

        panel.level = level(for: chrome.layer)
        panel.ignoresMouseEvents = chrome.isLocked
        panel.orderFront(nil)
    }

    private func level(for layer: WidgetLayer) -> NSWindow.Level {
        switch layer {
        case .desktop: NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
        case .normal: .normal
        case .floating: .floating
        }
    }

    // MARK: Placement

    /// Uses the stored top-left when it's still on a screen; otherwise picks a
    /// sensible spot so a widget can never end up stranded off-screen.
    private func resolvedTopLeft(chrome: WidgetChrome, size: CGSize, id: UUID) -> CGPoint {
        if let x = chrome.originX, let y = chrome.originY {
            let candidate = CGPoint(x: x, y: y)
            if isOnAnyScreen(topLeft: candidate, size: size) { return candidate }
        }
        return defaultTopLeft(size: size, id: id)
    }

    private func isOnAnyScreen(topLeft: CGPoint, size: CGSize) -> Bool {
        let rect = NSRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height)
        // Require a meaningful overlap, not just a pixel.
        return NSScreen.screens.contains { screen in
            let intersection = screen.frame.intersection(rect)
            return intersection.width > 80 && intersection.height > 60
        }
    }

    private func defaultTopLeft(size: CGSize, id: UUID) -> CGPoint {
        let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let index = state.instances.firstIndex { $0.id == id } ?? 0
        let cascade = CGFloat(index) * 28
        let x = min(visible.maxX - size.width - 40 + cascade, visible.maxX - size.width - 8)
        let y = visible.maxY - 40 - cascade
        return CGPoint(x: max(visible.minX + 8, x), y: y)
    }

    // MARK: NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        guard !isApplyingGeometry,
              let panel = notification.object as? WidgetPanel,
              let raw = panel.identifier?.rawValue,
              let id = UUID(uuidString: raw)
        else { return }
        state.recordOrigin(id, topLeft: CGPoint(x: panel.frame.minX, y: panel.frame.maxY))
    }
}
