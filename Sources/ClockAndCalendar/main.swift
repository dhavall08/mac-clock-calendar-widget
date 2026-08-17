import AppKit

// Dev affordance: render the widget faces to a PNG and exit, no windows opened.
if let flagIndex = CommandLine.arguments.firstIndex(of: "--render-preview") {
    let path = CommandLine.arguments.count > flagIndex + 1
        ? CommandLine.arguments[flagIndex + 1]
        : "preview.png"
    _ = NSApplication.shared      // SwiftUI rendering needs an app instance
    let ok = MainActor.assumeIsolated { PreviewRenderer.render(to: path) }
    print(ok ? "wrote \(path)" : "render failed")
    exit(ok ? 0 : 1)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Menu-bar-only app: no Dock icon, no main menu presence until a window is opened.
app.setActivationPolicy(.accessory)
app.run()
