import Foundation

/// The single place the app learns which widget kinds exist.
@MainActor
enum WidgetRegistry {
    static let all: [AnyWidgetType] = [
        AnyWidgetType(CalendarWidget.self),
        AnyWidgetType(ClockWidget.self),
        // Add new widget kinds here.
    ]

    static func type(for kind: String) -> AnyWidgetType? {
        all.first { $0.kind == kind }
    }
}
