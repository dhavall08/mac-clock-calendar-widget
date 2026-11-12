import Foundation

// MARK: - Week start

enum WeekStart: String, Codable, CaseIterable, Identifiable, Sendable {
    case sunday, monday, saturday

    var id: String { rawValue }

    /// `Calendar.firstWeekday` uses 1 = Sunday.
    var firstWeekday: Int {
        switch self {
        case .sunday: 1
        case .monday: 2
        case .saturday: 7
        }
    }

    var label: String {
        switch self {
        case .sunday: "Sunday"
        case .monday: "Monday"
        case .saturday: "Saturday"
        }
    }
}

// MARK: - Today emphasis

enum TodayStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case glow, fill, ring, underline

    var id: String { rawValue }

    var label: String {
        switch self {
        case .glow: "Glow"
        case .fill: "Solid"
        case .ring: "Ring"
        case .underline: "Bar"
        }
    }
}

/// Shape of today's marker for the `glow` and `fill` styles.
enum TodayShape: String, Codable, CaseIterable, Identifiable, Sendable {
    case circle, roundedSquare

    var id: String { rawValue }

    var label: String {
        switch self {
        case .circle: "Circle"
        case .roundedSquare: "Square"
        }
    }
}

// MARK: - Weekday header style

enum WeekdayLabelStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case initial, short

    var id: String { rawValue }

    var label: String {
        switch self {
        case .initial: "S M T"
        case .short: "Sun Mon"
        }
    }
}

// MARK: - Config

struct CalendarConfig: WidgetConfig {
    var weekStart: WeekStart = .sunday
    var weekdayLabels: WeekdayLabelStyle = .short
    var todayStyle: TodayStyle = .glow
    var todayShape: TodayShape = .circle

    var showHeader: Bool = true
    var showMonthNavigation: Bool = true
    var showYear: Bool = false
    var showWeekNumbers: Bool = false
    var showAdjacentMonths: Bool = false
    var showTodayLine: Bool = false
    var showGridLines: Bool = true
    /// Vertical rules on the boundary between weekend and weekday columns — with
    /// a Sunday start, one after Sun and one before Sat.
    var showWeekendSeparators: Bool = true
    var highlightWeekends: Bool = true
    /// Marks today's column in the weekday header, so the current day of the
    /// week is readable straight from the heading.
    var highlightTodayColumn: Bool = true
    /// Always draw six week rows so the widget never changes size month to month.
    var fixedSixWeeks: Bool = true

    var typeStyle: TypeStyle = .system
    /// Months away from the current month. Persisted so the widget stays where
    /// you left it after a relaunch.
    var monthOffset: Int = 0

    // MARK: Type sizes
    //
    // These are point sizes at scale 1.0; the widget's size slider multiplies
    // everything on top. Row heights are derived from them so a bigger number
    // can't collide with the row below.

    /// The Gregorian day number — 1, 2, 3…
    var dayNumberSize: Double = 22.4
    /// The tithi / moon / holiday strip under each day.
    var secondaryTextSize: Double = 10.4
    /// The full-date line along the bottom.
    var footerTextSize: Double = 10.5
    /// Multiplier for the hover tooltip.
    var tooltipScale: Double = 1.26

    // MARK: Holidays

    /// Regions whose holidays are shown. Empty means none.
    var holidayRegions: Set<HolidayRegion> = [.india]
    /// Colour for holiday dates. Takes precedence over the weekend tint.
    var holidayAccent: Accent = .red
    /// Small dot under a holiday date, in addition to the coloured number.
    var showHolidayDots: Bool = true
    /// Include observances that aren't public holidays (Dhanteras, Navratri…).
    var includeMinorObservances: Bool = false
    /// Names switched off in the holiday manager. Matched on name, so it also
    /// suppresses a holiday shared by two regions.
    var hiddenHolidayNames: Set<String> = []
    /// Holidays and anniversaries you added yourself.
    var customHolidays: [CustomHoliday] = []

    // MARK: Moon and panchang

    var showMoonPhases: Bool = true
    /// Quarters as well as new/full moons.
    var showAllMoonQuarters: Bool = false
    var showHinduCalendar: Bool = true
    var panchangLanguage: PanchangLanguage = .gujarati

    static let defaults = CalendarConfig()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = CalendarConfig()
        weekStart = c.value(.weekStart, d.weekStart)
        weekdayLabels = c.value(.weekdayLabels, d.weekdayLabels)
        todayStyle = c.value(.todayStyle, d.todayStyle)
        todayShape = c.value(.todayShape, d.todayShape)
        showHeader = c.value(.showHeader, d.showHeader)
        showMonthNavigation = c.value(.showMonthNavigation, d.showMonthNavigation)
        showYear = c.value(.showYear, d.showYear)
        showWeekNumbers = c.value(.showWeekNumbers, d.showWeekNumbers)
        showAdjacentMonths = c.value(.showAdjacentMonths, d.showAdjacentMonths)
        showTodayLine = c.value(.showTodayLine, d.showTodayLine)
        showGridLines = c.value(.showGridLines, d.showGridLines)
        showWeekendSeparators = c.value(.showWeekendSeparators, d.showWeekendSeparators)
        highlightWeekends = c.value(.highlightWeekends, d.highlightWeekends)
        dayNumberSize = c.value(.dayNumberSize, d.dayNumberSize)
        secondaryTextSize = c.value(.secondaryTextSize, d.secondaryTextSize)
        footerTextSize = c.value(.footerTextSize, d.footerTextSize)
        tooltipScale = c.value(.tooltipScale, d.tooltipScale)
        highlightTodayColumn = c.value(.highlightTodayColumn, d.highlightTodayColumn)
        fixedSixWeeks = c.value(.fixedSixWeeks, d.fixedSixWeeks)
        typeStyle = c.value(.typeStyle, d.typeStyle)
        monthOffset = c.value(.monthOffset, d.monthOffset)
        holidayRegions = c.value(.holidayRegions, d.holidayRegions)
        holidayAccent = c.value(.holidayAccent, d.holidayAccent)
        showHolidayDots = c.value(.showHolidayDots, d.showHolidayDots)
        includeMinorObservances = c.value(.includeMinorObservances, d.includeMinorObservances)
        hiddenHolidayNames = c.value(.hiddenHolidayNames, d.hiddenHolidayNames)
        customHolidays = c.value(.customHolidays, d.customHolidays)
        showMoonPhases = c.value(.showMoonPhases, d.showMoonPhases)
        showAllMoonQuarters = c.value(.showAllMoonQuarters, d.showAllMoonQuarters)
        showHinduCalendar = c.value(.showHinduCalendar, d.showHinduCalendar)
        panchangLanguage = c.value(.panchangLanguage, d.panchangLanguage)
    }

    // MARK: Layout metrics — the single source for base size and the view

    enum Metrics {
        /// Clearance below the cell contents. Without it the indicator dots sit
        /// directly on the row separator.
        static let cellBottomGap: CGFloat = 5
        /// Inset of the hover highlight inside the cell, so it reads as a
        /// rounded pill around the day rather than a full-bleed block.
        static let hoverInsetX: CGFloat = 3
        static let hoverInsetY: CGFloat = 2
        static let padding: CGFloat = 18
        static let weekNumberColumn: CGFloat = 26
        static let weekdayRow: CGFloat = 24
        static let header: CGFloat = 48
        static let gridTopGap: CGFloat = 4
    }

    // MARK: Derived row heights

    /// Height of the area holding the Gregorian day number.
    var numberRowHeight: CGFloat { max(28, CGFloat(dayNumberSize) * 2.35) }

    /// Height of the tithi / moon / holiday strip beneath it.
    var secondaryRowHeight: CGFloat { max(10, CGFloat(secondaryTextSize) * 1.4) }

    /// Height of the bottom date line.
    var footerRowHeight: CGFloat { max(22, CGFloat(footerTextSize) * 2.6) }

    /// Diameter of today's circle/square marker.
    var todayMarkerSize: CGFloat { CGFloat(dayNumberSize) * 2.0 }

    var columnCount: Int { 7 }

    // MARK: Holiday resolution

    /// Custom holidays falling on `date`.
    ///
    /// Kept out of `CalendarDataStore` on purpose: that cache is shared between
    /// widgets and keyed only by year, while these live in one widget's config.
    func customHolidays(on date: Date, calendar: Calendar) -> [Holiday] {
        guard !customHolidays.isEmpty else { return [] }
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return customHolidays.compactMap { entry in
            guard entry.month == parts.month, entry.day == parts.day,
                  let year = parts.year, entry.occurs(in: year),
                  !entry.name.isEmpty
            else { return nil }
            return Holiday(name: entry.name, region: .custom)
        }
    }

    /// Everything to show for a day: computed holidays for the enabled regions
    /// plus custom ones, with hidden names and minor observances filtered out.
    func visibleHolidays(from info: DayInfo, on date: Date, calendar: Calendar) -> [Holiday] {
        var all = info.holidays(in: holidayRegions)
        all.append(contentsOf: customHolidays(on: date, calendar: calendar))
        return all.filter { holiday in
            guard !hiddenHolidayNames.contains(holiday.name) else { return false }
            // Custom entries are never treated as minor.
            return holiday.region == .custom || includeMinorObservances || holiday.isPublicHoliday
        }
    }

    /// True when a cell needs the strip under the day number. Driven by config
    /// alone, not by whether a given day happens to have anything in it, so all
    /// cells stay the same height.
    var hasSecondaryRow: Bool {
        showHinduCalendar || showMoonPhases || (showHolidayDots && !holidayRegions.isEmpty)
    }

    /// Wide enough for the day number, and for a spelled-out tithi like
    /// "સુદ ૧૨" or "Amavasya" when the Hindu calendar is on.
    var cellWidth: CGFloat {
        let forNumber = max(40, CGFloat(dayNumberSize) * 2.6)
        guard showHinduCalendar else { return forNumber }
        let perGlyph: CGFloat = panchangLanguage == .english ? 6.2 : 5.6
        // "Amavasya" is the longest English label at 8 characters.
        let longestLabel: CGFloat = panchangLanguage == .english ? 8 : 6
        return max(forNumber, CGFloat(secondaryTextSize) * perGlyph / 8 * longestLabel + 14)
    }

    var cellHeight: CGFloat {
        numberRowHeight
            + (hasSecondaryRow ? secondaryRowHeight : 0)
            + Metrics.cellBottomGap
    }

    func rowCount(reference: Date, calendar: Calendar) -> Int {
        if fixedSixWeeks { return 6 }
        return CalendarMath.weekRowCount(for: reference, calendar: calendar)
    }

    func size(reference: Date, calendar: Calendar) -> CGSize {
        let m = Metrics.self
        var width = CGFloat(columnCount) * cellWidth + m.padding * 2
        if showWeekNumbers { width += m.weekNumberColumn }

        var height = m.padding * 2 + m.weekdayRow + m.gridTopGap
        height += CGFloat(rowCount(reference: reference, calendar: calendar)) * cellHeight
        if showHeader { height += m.header }
        if showTodayLine { height += footerRowHeight }
        return CGSize(width: width.rounded(), height: height.rounded())
    }
}

// MARK: - Panchang language

/// Script and vocabulary for the Hindu calendar labels.
enum PanchangLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case english
    case gujarati
    case devanagari

    var id: String { rawValue }

    var label: String {
        switch self {
        case .english: "English"
        case .gujarati: "ગુજરાતી"
        case .devanagari: "देवनागरी"
        }
    }

    private static let gujaratiDigits = ["૦", "૧", "૨", "૩", "૪", "૫", "૬", "૭", "૮", "૯"]
    private static let devanagariDigits = ["०", "१", "२", "३", "४", "५", "६", "७", "८", "९"]

    /// Renders an integer in this language's numerals.
    func digits(_ value: Int) -> String {
        let table: [String]
        switch self {
        case .english: return String(value)
        case .gujarati: table = Self.gujaratiDigits
        case .devanagari: table = Self.devanagariDigits
        }
        return String(value).compactMap { character in
            character.wholeNumberValue.flatMap { table[$0] }
        }.joined()
    }
}
