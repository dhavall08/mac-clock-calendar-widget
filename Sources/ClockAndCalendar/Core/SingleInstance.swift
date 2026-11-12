import Foundation

/// Makes sure only one copy of the app runs at a time.
///
/// Opening the app from Finder never starts a second copy, but the login item
/// does: launchd runs the executable directly, so registering it while the app
/// is already open used to leave two copies drawing the same widgets and
/// writing the same settings file.
///
/// The guard is an exclusive lock on a file. The system drops it when the
/// process ends, even after a crash, so a stale lock can't block a launch. Two
/// copies starting in the same instant can't both win either.
@MainActor
enum SingleInstance {

    /// Held for the life of the process. Closing it would release the lock.
    private static var lockDescriptor: Int32 = -1

    /// Returns false when another copy already holds the lock.
    static func acquire() -> Bool {
        let directory = AppState.supportDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent(".lock").path

        // O_CLOEXEC keeps the lock out of helper processes such as launchctl.
        let descriptor = open(path, O_CREAT | O_RDWR | O_CLOEXEC, 0o644)
        guard descriptor >= 0 else {
            // Can't create the file at all. Running is better than refusing to start.
            return true
        }
        if flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
            close(descriptor)
            return false
        }
        lockDescriptor = descriptor
        return true
    }
}
