import AppKit
import SwiftUI

/// Owns the single Settings window.
@MainActor
final class ControlCenterWindowController: NSObject, NSWindowDelegate {

    private let state: AppState
    let model = ControlCenterModel()
    private var window: NSWindow?
    /// Suppresses the resize handler while we're the ones setting the size.
    private var isApplyingSize = false

    init(state: AppState) {
        self.state = state
        super.init()
    }

    private var visibleFrame: CGRect {
        NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    }

    func show(selecting id: UUID? = nil) {
        if let id { model.section = .widget(id) }

        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 840, height: 720),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Clock and Calendar by Dhaval"
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.appearance = NSAppearance(named: .darkAqua)
            window.backgroundColor = NSColor(Theme.surface)
            window.minSize = NSSize(width: AppSettings.minimumSettingsSize.width,
                                    height: AppSettings.minimumSettingsSize.height)
            window.delegate = self
            window.isReleasedWhenClosed = false

            let root = ControlCenterView(state: state, model: model)
            window.contentView = NSHostingView(rootView: root)
            self.window = window

            model.onApplyWindowPreset = { [weak self] preset in
                self?.applyPreset(preset)
            }
            applyStoredSize(centering: true)
        }

        // Accessory apps need an explicit activation to come to the front.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: Sizing

    /// Restores the remembered size, clamped to whatever display is in use now.
    private func applyStoredSize(centering: Bool) {
        guard let window else { return }
        let frame = visibleFrame
        let size = NSSize(
            width: min(max(state.settings.settingsWidth, AppSettings.minimumSettingsSize.width),
                       frame.width - 20),
            height: min(max(state.settings.settingsHeight, AppSettings.minimumSettingsSize.height),
                        frame.height - 20)
        )
        isApplyingSize = true
        // NSHostingView otherwise grows the window to its full ideal height,
        // which can overflow a laptop display.
        window.setContentSize(size)
        if centering { window.center() }
        isApplyingSize = false
    }

    /// Applies a named preset and remembers it.
    func applyPreset(_ preset: SettingsWindowPreset) {
        let size = preset.size(on: visibleFrame)
        var next = state.settings
        next.settingsWidth = size.width
        next.settingsHeight = size.height
        state.updateSettings(next)
        applyStoredSize(centering: preset == .fitScreen)
    }

    // MARK: NSWindowDelegate

    func windowDidResize(_ notification: Notification) {
        guard !isApplyingSize, let window, let content = window.contentView else { return }
        var next = state.settings
        next.settingsWidth = content.bounds.width
        next.settingsHeight = content.bounds.height
        state.updateSettings(next)
    }

    func windowWillClose(_ notification: Notification) {
        // Drop back to menu-bar-only so no Dock icon lingers.
        NSApp.setActivationPolicy(.accessory)
        state.flush()
    }
}
