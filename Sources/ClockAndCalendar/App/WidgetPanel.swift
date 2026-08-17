import AppKit

/// Borderless, non-activating panel that hosts one widget.
///
/// Non-activating means clicking the widget doesn't steal focus from whatever
/// you were working in — the behaviour people expect from a widget rather than
/// from an app window.
final class WidgetPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false           // the SwiftUI glass draws its own shadow + glow
        isMovableByWindowBackground = true
        ignoresMouseEvents = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        // Widgets are decoration: keep them out of Mission Control's window list
        // and out of screenshots' window picker noise.
        isExcludedFromWindowsMenu = true
        appearance = NSAppearance(named: .darkAqua)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
