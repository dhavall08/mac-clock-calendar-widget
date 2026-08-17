import Foundation

/// Start-at-login, via a plain LaunchAgent.
///
/// `SMAppService` would be the modern route, but it wants a properly signed
/// bundle. A LaunchAgent plist in `~/Library/LaunchAgents` needs no
/// entitlements and no developer account, which is the whole point here.
@MainActor
enum LoginItemManager {

    static let label = "com.dhaval.clockandcalendar"

    private static var plistURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    /// The executable a login item should launch. Uses the running bundle, so
    /// it works whether the app lives in /Applications or in ./dist.
    static var executablePath: String? {
        Bundle.main.executableURL?.path
    }

    /// Path the installed login item currently points at, if any.
    static var recordedExecutablePath: String? {
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dictionary = plist as? [String: Any],
              let arguments = dictionary["ProgramArguments"] as? [String]
        else { return nil }
        return arguments.first
    }

    /// True when the app isn't in /Applications. A login item pointing into a
    /// build directory breaks the moment that directory is cleaned.
    static var isRunningFromApplications: Bool {
        Bundle.main.bundlePath.hasPrefix("/Applications/")
    }

    /// Re-points an existing login item at the running copy.
    ///
    /// Without this, moving or reinstalling the app leaves a login item aimed at
    /// a path that no longer exists, and it fails silently at every login.
    static func repairIfNeeded() {
        guard isEnabled,
              let current = executablePath,
              recordedExecutablePath != current
        else { return }
        NSLog("ClockAndCalendar: re-pointing login item at \(current)")
        _ = enable()
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        enabled ? enable() : disable()
    }

    private static func enable() -> Bool {
        guard let executable = executablePath else { return false }

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive"
        ]

        do {
            try FileManager.default.createDirectory(
                at: plistURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL, options: .atomic)
        } catch {
            NSLog("ClockAndCalendar: could not write login item - \(error)")
            return false
        }

        // Re-register so an updated executable path takes effect immediately.
        runLaunchctl(["bootout", "gui/\(getuid())/\(label)"])
        return runLaunchctl(["bootstrap", "gui/\(getuid())", plistURL.path])
    }

    private static func disable() -> Bool {
        runLaunchctl(["bootout", "gui/\(getuid())/\(label)"])
        try? FileManager.default.removeItem(at: plistURL)
        return true
    }

    @discardableResult
    private static func runLaunchctl(_ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
