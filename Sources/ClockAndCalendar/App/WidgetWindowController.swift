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
    private var reorderWorkItem: DispatchWorkItem?
    private var screenResyncItems: [DispatchWorkItem] = []

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
            .sink { [weak self] _ in self?.scheduleScreenResync() }
            .store(in: &cancellables)

        // Waking and unlocking both re-attach displays without necessarily
        // changing the screen parameters afterwards, so they need their own
        // nudge: a monitor that was asleep can report the wrong resolution (or
        // be missing) at the moment the screens *do* change.
        for name: NSNotification.Name in [
            NSWorkspace.didWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification,
            NSWorkspace.screensDidWakeNotification
        ] {
            NSWorkspace.shared.notificationCenter
                .publisher(for: name)
                .sink { [weak self] _ in self?.scheduleScreenResync() }
                .store(in: &cancellables)
        }

        // Finder re-fronts its desktop window when it activates (a click on the
        // wallpaper does it) and when the active Space changes. Desktop-layer
        // widgets share that window level, so they can end up behind it — see
        // `reassertDesktopOrdering`.
        for name: NSNotification.Name in [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.activeSpaceDidChangeNotification
        ] {
            NSWorkspace.shared.notificationCenter
                .publisher(for: name)
                .sink { [weak self] _ in self?.scheduleDesktopReorder() }
                .store(in: &cancellables)
        }

        // At login the app is started by a LaunchAgent, which can win the race
        // against the window server finishing its display setup. If a monitor
        // shows up a second later it posts screen parameters and we'd catch it
        // anyway, but a display that was merely *slow* to be reported posts
        // nothing — so re-place everything once things have settled.
        scheduleScreenResync()
    }

    // MARK: Sync

    /// Re-places every widget after the set of displays changed.
    ///
    /// Display reconfiguration arrives as a burst of notifications, and the
    /// screen list is briefly untrustworthy in the middle of it — a display
    /// coming back can be absent, or report its pre-wake resolution, for a beat
    /// or two. So: coalesce, then check again as the dust settles. `syncAll` is
    /// idempotent, so the repeats cost nothing once the layout is right.
    private func scheduleScreenResync() {
        for item in screenResyncItems { item.cancel() }
        screenResyncItems = [0.35, 1.2, 3.0].map { delay in
            let item = DispatchWorkItem { [weak self] in self?.syncAll() }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
            return item
        }
    }

    func syncAll() {
        // Mid-reconfiguration (and while every display sleeps) AppKit can report
        // no screens at all. Placing widgets against that would scatter them; the
        // burst above will call back once there's a real layout to place them on.
        guard !NSScreen.screens.isEmpty else { return }
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

        // Layering and click handling don't depend on the size negotiation below,
        // and step 2 can bail out of this method early — so settle them first. A
        // panel left click-through because we returned before this line is the
        // one failure mode the user can't undo from the widget itself.
        panel.level = level(for: chrome.layer)
        panel.ignoresMouseEvents = chrome.isLocked

        // The shell keeps a transparent margin for its toolbar, grip and glow.
        var size = WidgetShellMetrics.windowSize(for: state.renderedSize(for: id))

        // 1. Decide which display this widget belongs on, and where on it. This
        //    only needs `size` as a rough on-screen test, so it can run before
        //    the size is finally settled below.
        let target = resolvedPlacement(chrome: chrome, size: size, id: id)

        // 2. If we're restoring a remembered placement, restore the size the
        //    widget had there too — a stint on a smaller display may have shrunk
        //    it. Do this before positioning, since everything below measures
        //    against the rendered size.
        if let wanted = target.scale,
           abs(wanted - chrome.scale) > 0.001,
           wanted <= state.maxScale(for: id, on: target.scaleFrame) + 0.001 {
            // Doesn't touch `placements`, so this can't fight step 4 below.
            state.applyScaleWithoutRemembering(id, wanted)   // re-enters sync
            return
        }

        // 3. Settle on a position: `maxScale` needs to know which display the
        //    widget is on before it can decide what "too big" means.
        size = WidgetShellMetrics.windowSize(for: state.renderedSize(for: id))
        let topLeft = clamped(topLeft: target.topLeft, size: size, in: target.screenFrame)
        if chrome.originX != topLeft.x || chrome.originY != topLeft.y {
            // `recordOrigin` deliberately doesn't republish, so this can't loop.
            state.recordOrigin(id, topLeft: topLeft)
        }
        if target.adopt {
            // Nothing was remembered for this widget yet (a fresh install, or a
            // document written before placements existed) — make wherever it is
            // now its home, so the next display change has something to restore.
            state.rememberPlacement(id, topLeft: topLeft)
        }

        // 4. A scale saved on a bigger display (or before a monitor was
        //    unplugged) would hang off the screen — pull it back in. The
        //    remembered placement keeps the user's chosen size for when that
        //    display comes back.
        let limit = state.maxScale(for: id)
        if state.chrome(for: id).scale > limit + 0.001 {
            state.applyScaleWithoutRemembering(id, limit)   // re-enters sync
            return
        }

        size = WidgetShellMetrics.windowSize(for: state.renderedSize(for: id))
        let frame = NSRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height)
        panel.setFrame(frame, display: true)
        panel.orderFront(nil)
    }

    private func level(for layer: WidgetLayer) -> NSWindow.Level {
        switch layer {
        // One above the desktop icon window, not level with it: Finder's desktop
        // lives at that exact level, and two windows in the same level are
        // ordered by whoever was fronted last. Losing that race hands our clicks
        // to the desktop, which looks exactly like the widget having locked
        // itself. +1 is still ~2.1 billion levels below `.normal`, so the widget
        // stays behind every app window as "On desktop" promises.
        case .desktop: NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        case .normal: .normal
        case .floating: .floating
        }
    }

    // MARK: Desktop ordering

    /// Coalesces reorder requests and runs them a beat late: the workspace
    /// notifications fire *before* Finder finishes restacking the desktop, so
    /// ordering front immediately would be undone again.
    private func scheduleDesktopReorder() {
        reorderWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.reassertDesktopOrdering() }
        reorderWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
    }

    /// Puts desktop-layer widgets back at the front of their own window level.
    ///
    /// Only `.desktop` panels need this. `.normal` must keep its place in the
    /// regular stacking order (fronting it would make it behave like
    /// "Always on top"), and `.floating` is already above everything.
    private func reassertDesktopOrdering() {
        for (id, panel) in panels where state.instance(id)?.chrome.layer == .desktop {
            guard panel.isVisible else { continue }
            panel.orderFront(nil)
        }
    }

    // MARK: Placement

    /// Where a widget should sit right now, and on which display.
    private struct ResolvedPlacement {
        var topLeft: CGPoint
        /// The display's full `frame`, for keeping the panel on that display.
        var screenFrame: CGRect
        /// The display's `visibleFrame` — what `AppState.screenFrame(for:)`
        /// reports once the widget has moved there. The scale check below has to
        /// use the same rect the clamp will, or a restore and a clamp could
        /// undo each other forever.
        var scaleFrame: CGRect
        /// A remembered size to restore, when this came from a placement.
        var scale: Double?
        /// Record this spot as the widget's placement — only for a widget that
        /// has none yet.
        var adopt: Bool
    }

    /// Decides where a widget goes, in this order:
    ///
    /// 1. The most recent remembered placement whose display is attached. This is
    ///    what restores a widget after a login, or after its monitor is unplugged
    ///    and plugged back in.
    /// 2. Its live position, if that's still on some attached display — the
    ///    ordinary case where nothing about the displays changed.
    /// 3. A cascaded default, so a widget can never end up stranded off-screen.
    ///
    /// Cases 2 and 3 leave `placements` alone (unless there are none to leave):
    /// parking a widget on the built-in display because its own monitor is away
    /// has to stay reversible, and overwriting what it remembers is exactly what
    /// would make it permanent.
    private func resolvedPlacement(chrome: WidgetChrome, size: CGSize, id: UUID) -> ResolvedPlacement {
        if let (placement, screen) = bestRememberedPlacement(chrome: chrome) {
            return ResolvedPlacement(
                topLeft: placement.topLeft(on: screen.frame, size: size),
                screenFrame: screen.frame,
                scaleFrame: screen.visibleFrame,
                scale: placement.scale,
                adopt: false
            )
        }

        let adopt = chrome.placements.isEmpty
        if let x = chrome.originX, let y = chrome.originY {
            let candidate = CGPoint(x: x, y: y)
            if isOnAnyScreen(topLeft: candidate, size: size) {
                let screen = ScreenIdentity.screen(containing: candidate) ?? fallbackScreen
                return ResolvedPlacement(
                    topLeft: candidate,
                    screenFrame: screen?.frame ?? fallbackFrame,
                    scaleFrame: screen?.visibleFrame ?? fallbackFrame,
                    scale: nil,
                    adopt: adopt
                )
            }
        }

        let topLeft = defaultTopLeft(size: size, id: id)
        let screen = ScreenIdentity.screen(containing: topLeft) ?? fallbackScreen
        return ResolvedPlacement(
            topLeft: topLeft,
            screenFrame: screen?.frame ?? fallbackFrame,
            scaleFrame: screen?.visibleFrame ?? fallbackFrame,
            scale: nil,
            adopt: adopt
        )
    }

    /// The remembered placement to honour: the most recently used one among the
    /// displays that are attached right now.
    ///
    /// Recency is what makes both directions work. Unplug the external monitor
    /// and the widget falls back to whatever it remembers about the built-in
    /// display; plug it back in and the external placement — still the newest —
    /// wins again. Drag the widget somewhere on the built-in display in the
    /// meantime and *that* becomes the newest, so it stays put: the last place
    /// the user put it is always the place it goes.
    private func bestRememberedPlacement(chrome: WidgetChrome) -> (WidgetPlacement, NSScreen)? {
        chrome.placements
            .compactMap { key, placement -> (WidgetPlacement, NSScreen)? in
                guard let screen = ScreenIdentity.screen(for: key) else { return nil }
                return (placement, screen)
            }
            .max { $0.0.updatedAt < $1.0.updatedAt }
    }

    private var fallbackScreen: NSScreen? {
        NSScreen.main ?? NSScreen.screens.first
    }

    private var fallbackFrame: CGRect {
        CGRect(x: 0, y: 0, width: 1440, height: 900)
    }

    /// Keeps the whole panel inside one display. Clamps against `frame` rather
    /// than `visibleFrame` so a widget deliberately tucked up under the menu bar
    /// isn't dragged down every time a display comes back.
    private func clamped(topLeft: CGPoint, size: CGSize, in frame: CGRect) -> CGPoint {
        let x = min(max(topLeft.x, frame.minX), max(frame.minX, frame.maxX - size.width))
        let y = max(min(topLeft.y, frame.maxY), min(frame.maxY, frame.minY + size.height))
        return CGPoint(x: x, y: y)
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
        let topLeft = CGPoint(x: panel.frame.minX, y: panel.frame.maxY)

        // A drag is the user saying "here", so it's remembered against the
        // display it landed on. Anything else that moves the panel is not: when a
        // monitor is unplugged, the window server itself shunts our windows onto
        // a surviving display and posts this notification, and treating that as a
        // deliberate placement would erase the very position we want to restore.
        // The panel only moves under the mouse, so a held button is what tells
        // the two apart.
        let isUserDrag = NSEvent.pressedMouseButtons & 0x1 != 0
        if isUserDrag {
            state.rememberPlacement(id, topLeft: topLeft)
        } else {
            state.recordOrigin(id, topLeft: topLeft)
        }
    }
}
