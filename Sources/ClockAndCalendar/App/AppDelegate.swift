import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var state: AppState!
    private var windows: WidgetWindowController!
    private var menuBar: MenuBarController!
    private var controlCenter: ControlCenterWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        state = AppState()
        windows = WidgetWindowController(state: state)
        controlCenter = ControlCenterWindowController(state: state)
        menuBar = MenuBarController(state: state)

        windows.onOpenSettings = { [weak self] id in
            self?.controlCenter.show(selecting: id)
        }
        menuBar.onOpenControlCenter = { [weak self] id in
            self?.controlCenter.show(selecting: id)
        }

        windows.syncAll()

        // First run has nothing on screen to explain itself — and with the menu
        // bar icon hidden there'd be no way in at all — so open Settings.
        let hasLaunched = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if !hasLaunched || state.settings.hideMenuBarIcon {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            controlCenter.show()
        }

        NSApp.mainMenu = Self.makeMainMenu()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Re-opening the app from Finder or Spotlight brings Settings back. This is
    /// the escape hatch when the menu bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controlCenter.show()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        state?.flush()
    }

    private static func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Clock and Calendar",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Clock and Calendar",
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)

        return main
    }
}
