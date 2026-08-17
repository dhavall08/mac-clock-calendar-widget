// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ClockAndCalendar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ClockAndCalendar",
            path: "Sources/ClockAndCalendar",
            swiftSettings: [
                // The app is single-threaded / @MainActor by construction. Swift 5
                // mode keeps that ergonomic without wrapping every AppKit callback.
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
