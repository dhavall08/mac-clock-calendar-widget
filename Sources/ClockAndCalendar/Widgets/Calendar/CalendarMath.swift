import Foundation

/// One day in the rendered grid.
struct DayCell: Identifiable {
    let id: Int
    let date: Date
    let dayNumber: Int
    let isInDisplayedMonth: Bool
    let isToday: Bool
    let isWeekend: Bool
}

/// Pure date maths, kept out of the view so it can be reasoned about (and
/// reused by a future WidgetKit extension) on its own.
enum CalendarMath {

    /// Calendar honouring the user's chosen first weekday while keeping the
    /// system locale for month and weekday names.
    static func calendar(weekStart: WeekStart) -> Calendar {
        var calendar = Calendar(identifier: Calendar.current.identifier)
        calendar.locale = Locale.autoupdatingCurrent
        calendar.timeZone = TimeZone.autoupdatingCurrent
        calendar.firstWeekday = weekStart.firstWeekday
        return calendar
    }

    /// First day of the month `offset` months from `anchor`.
    static func referenceMonth(anchor: Date, offset: Int, calendar: Calendar) -> Date {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: anchor)) ?? anchor
        return calendar.date(byAdding: .month, value: offset, to: startOfMonth) ?? startOfMonth
    }

    /// How many week rows this month spans given the calendar's first weekday.
    static func weekRowCount(for referenceMonth: Date, calendar: Calendar) -> Int {
        let dayCount = calendar.range(of: .day, in: .month, for: referenceMonth)?.count ?? 30
        return Int(ceil(Double(leadingBlanks(for: referenceMonth, calendar: calendar) + dayCount) / 7.0))
    }

    /// Cells before the 1st of the month.
    static func leadingBlanks(for referenceMonth: Date, calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: referenceMonth)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    /// Builds the grid as rows of seven days, including leading/trailing spill
    /// from the neighbouring months.
    static func weeks(for referenceMonth: Date, today: Date, rows: Int, calendar: Calendar) -> [[DayCell]] {
        let blanks = leadingBlanks(for: referenceMonth, calendar: calendar)
        guard let gridStart = calendar.date(byAdding: .day, value: -blanks, to: referenceMonth) else { return [] }
        let startOfToday = calendar.startOfDay(for: today)
        let displayedMonth = calendar.component(.month, from: referenceMonth)
        let displayedYear = calendar.component(.year, from: referenceMonth)

        var result: [[DayCell]] = []
        var index = 0
        for row in 0..<rows {
            var week: [DayCell] = []
            for column in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: row * 7 + column, to: gridStart) else { continue }
                let components = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
                let inMonth = components.month == displayedMonth && components.year == displayedYear
                week.append(
                    DayCell(
                        id: index,
                        date: date,
                        dayNumber: components.day ?? 0,
                        isInDisplayedMonth: inMonth,
                        isToday: calendar.startOfDay(for: date) == startOfToday,
                        // Deliberately not `calendar.isDateInWeekend`: that
                        // follows the locale's weekend range, which in several
                        // locales is Sunday only — so Saturday would be styled
                        // as an ordinary weekday.
                        isWeekend: isWeekendDay(components.weekday)
                    )
                )
                index += 1
            }
            result.append(week)
        }
        return result
    }

    /// Saturday and Sunday, regardless of locale. `weekday` is 1 = Sunday.
    static func isWeekendDay(_ weekday: Int?) -> Bool {
        weekday == 1 || weekday == 7
    }

    /// The weekday number (1 = Sunday) sitting in `column`, once the week has
    /// been rotated to start on the calendar's first weekday.
    static func weekday(forColumn column: Int, calendar: Calendar) -> Int {
        ((calendar.firstWeekday - 1 + column) % 7) + 1
    }

    static func weekNumbers(for weeks: [[DayCell]], calendar: Calendar) -> [Int] {
        weeks.compactMap { week in
            guard let first = week.first else { return nil }
            return calendar.component(.weekOfYear, from: first.date)
        }
    }

    /// Weekday headers rotated to start on the calendar's first weekday.
    static func weekdaySymbols(style: WeekdayLabelStyle, calendar: Calendar) -> [String] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? Locale.autoupdatingCurrent
        let symbols: [String]? = style == .initial ? formatter.veryShortWeekdaySymbols : formatter.shortWeekdaySymbols
        guard let symbols, symbols.count == 7 else { return ["S", "M", "T", "W", "T", "F", "S"] }
        let shift = calendar.firstWeekday - 1
        return (0..<7).map { symbols[($0 + shift) % 7] }
    }

    static func monthTitle(_ date: Date, includeYear: Bool, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? Locale.autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate(includeYear ? "MMMMy" : "MMMM")
        return formatter.string(from: date)
    }

    /// "14 Aug" — short enough to prefix a holiday name in the footer.
    static func dayMonthLine(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? Locale.autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter.string(from: date)
    }

    static func fullDateLine(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? Locale.autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMMy")
        return formatter.string(from: date)
    }
}
