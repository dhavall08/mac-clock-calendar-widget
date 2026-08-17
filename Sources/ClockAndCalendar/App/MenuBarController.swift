import AppKit
import Combine

/// Status-item menu. Can be hidden entirely from Preferences, in which case the
/// status item is removed from the menu bar and the app keeps running headless.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {

    private let state: AppState
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private var cancellables: Set<AnyCancellable> = []

    var onOpenControlCenter: ((UUID?) -> Void)?

    init(state: AppState) {
        self.state = state
        super.init()

        menu.delegate = self
        applyVisibility(hidden: state.settings.hideMenuBarIcon)

        state.settingsChanged
            .sink { [weak self] settings in self?.applyVisibility(hidden: settings.hideMenuBarIcon) }
            .store(in: &cancellables)
    }

    /// Mirrors whether the status item is currently installed. A menu-bar app
    /// that can hide its only affordance needs some way to answer "are you
    /// there?" from outside the process:
    ///
    ///     defaults read com.dhaval.clockandcalendar statusItemInstalled
    static let statusItemInstalledKey = "statusItemInstalled"

    private func applyVisibility(hidden: Bool) {
        defer {
            UserDefaults.standard.set(statusItem != nil, forKey: Self.statusItemInstalledKey)
        }

        if hidden {
            if let statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
                self.statusItem = nil
            }
            return
        }
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "calendar.badge.clock",
                accessibilityDescription: "Clock and Calendar"
            )
            button.image?.isTemplate = true
            button.toolTip = "Clock and Calendar by Dhaval"
        }
        item.menu = menu
        statusItem = item
    }

    // MARK: Menu construction

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(title: "Widgets", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        if state.instances.isEmpty {
            let empty = NSMenuItem(title: "  None yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }

        for instance in state.instances {
            guard let type = WidgetRegistry.type(for: instance.kind) else { continue }
            let item = NSMenuItem(
                title: type.displayName,
                action: #selector(toggleVisibility(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = instance.id
            item.state = instance.chrome.isVisible ? .on : .off
            item.image = NSImage(systemSymbolName: type.symbolName, accessibilityDescription: nil)

            // Alternate item (hold ⌥) jumps straight to that widget's settings.
            let configure = NSMenuItem(
                title: "\(type.displayName) settings…",
                action: #selector(configureWidget(_:)),
                keyEquivalent: ""
            )
            configure.target = self
            configure.representedObject = instance.id
            configure.isAlternate = true
            configure.keyEquivalentModifierMask = .option

            menu.addItem(item)
            menu.addItem(configure)
        }

        menu.addItem(.separator())

        let addMenu = NSMenu()
        for type in WidgetRegistry.all {
            let item = NSMenuItem(title: type.displayName, action: #selector(addWidget(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = type.kind
            item.image = NSImage(systemSymbolName: type.symbolName, accessibilityDescription: nil)
            addMenu.addItem(item)
        }
        let addItem = NSMenuItem(title: "Add Widget", action: nil, keyEquivalent: "")
        addItem.submenu = addMenu
        menu.addItem(addItem)

        let control = NSMenuItem(title: "Settings…", action: #selector(openControlCenter), keyEquivalent: ",")
        control.target = self
        menu.addItem(control)

        let rescue = NSMenuItem(title: "Bring Widgets On Screen", action: #selector(rescue), keyEquivalent: "")
        rescue.target = self
        menu.addItem(rescue)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: Actions

    @objc private func toggleVisibility(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        var chrome = state.chrome(for: id)
        chrome.isVisible.toggle()
        state.updateChrome(id, chrome)
    }

    @objc private func configureWidget(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        onOpenControlCenter?(id)
    }

    @objc private func addWidget(_ sender: NSMenuItem) {
        guard let kind = sender.representedObject as? String else { return }
        let id = state.addWidget(kind: kind)
        onOpenControlCenter?(id)
    }

    @objc private func openControlCenter() {
        onOpenControlCenter?(nil)
    }

    @objc private func rescue() {
        state.rescueOffscreenWidgets()
    }

    @objc private func quit() {
        state.flush()
        NSApp.terminate(nil)
    }
}
