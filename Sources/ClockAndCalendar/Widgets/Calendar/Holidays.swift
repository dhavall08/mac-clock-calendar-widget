import Foundation

// MARK: - Region

enum HolidayRegion: String, Codable, CaseIterable, Identifiable, Sendable {
    case india, usa, uk
    /// Holidays you added yourself. Always available; never filtered by region.
    case custom

    var id: String { rawValue }

    /// The three that appear as region toggles. `custom` is implicit.
    static var selectable: [HolidayRegion] { [.india, .usa, .uk] }

    var label: String {
        switch self {
        case .india: "India"
        case .usa: "USA"
        case .uk: "UK"
        case .custom: "Mine"
        }
    }

    var shortLabel: String {
        switch self {
        case .india: "IN"
        case .usa: "US"
        case .uk: "UK"
        case .custom: "★"
        }
    }
}

// MARK: - Custom holiday

/// A date you added yourself — a birthday, an anniversary, a regional holiday
/// the built-in rules don't cover.
struct CustomHoliday: Codable, Equatable, Identifiable, Sendable {
    var id: UUID = UUID()
    var name: String = ""
    var month: Int = 1
    var day: Int = 1
    /// When false, `year` pins it to a single date.
    var repeatsYearly: Bool = true
    var year: Int = Calendar(identifier: .gregorian).component(.year, from: Date())

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = CustomHoliday()
        id = c.value(.id, d.id)
        name = c.value(.name, d.name)
        month = c.value(.month, d.month)
        day = c.value(.day, d.day)
        repeatsYearly = c.value(.repeatsYearly, d.repeatsYearly)
        year = c.value(.year, d.year)
    }

    /// Occurs in `year`?
    func occurs(in year: Int) -> Bool {
        repeatsYearly || self.year == year
    }
}

// MARK: - Holiday

struct Holiday: Sendable, Equatable {
    let name: String
    let region: HolidayRegion
    /// Religious/cultural observances that aren't public holidays are still worth
    /// showing, but callers may want to weight them differently.
    var isPublicHoliday: Bool = true
}

// MARK: - Rules

/// Computes holidays from rules rather than a lookup table, so any year works —
/// including ones after this code was written.
///
/// Sources of truth per region:
///  * Fixed civil dates (Republic Day, 4 July, Christmas…).
///  * Nth-weekday rules (US federal Mondays, UK bank holidays).
///  * Easter, via the Gregorian computus, for Good Friday / Easter Monday.
///  * Islamic dates, via Foundation's Umm al-Qura calendar.
///  * Hindu festivals, via tithi + lunar month + traditional observance window
///    (see `HinduCalendar.Observance`).
///
/// Hindu and Islamic dates are computed, not looked up, so they can differ by a
/// day from a regional panchang or a local moon sighting. Nothing here accounts
/// for a holiday being moved to a weekday when it falls on a weekend.
enum HolidayRules {

    // MARK: Fixed civil dates

    /// (month, day, name, region)
    static let fixed: [(month: Int, day: Int, name: String, region: HolidayRegion)] = [
        // India
        (1, 26, "Republic Day", .india),
        (8, 15, "Independence Day", .india),
        (10, 2, "Gandhi Jayanti", .india),
        (12, 25, "Christmas", .india),
        // USA
        (1, 1, "New Year's Day", .usa),
        (6, 19, "Juneteenth", .usa),
        (7, 4, "Independence Day", .usa),
        (11, 11, "Veterans Day", .usa),
        (12, 25, "Christmas Day", .usa),
        // UK
        (1, 1, "New Year's Day", .uk),
        (12, 25, "Christmas Day", .uk),
        (12, 26, "Boxing Day", .uk)
    ]

    /// Nth weekday of a month. `week` of -1 means the last one.
    /// weekday uses 1 = Sunday.
    static let nthWeekday: [(month: Int, weekday: Int, week: Int, name: String, region: HolidayRegion)] = [
        // USA federal
        (1, 2, 3, "Martin Luther King Jr. Day", .usa),
        (2, 2, 3, "Presidents' Day", .usa),
        (5, 2, -1, "Memorial Day", .usa),
        (9, 2, 1, "Labor Day", .usa),
        (10, 2, 2, "Columbus Day", .usa),
        (11, 5, 4, "Thanksgiving", .usa),
        // UK bank holidays (England & Wales)
        (5, 2, 1, "Early May bank holiday", .uk),
        (5, 2, -1, "Spring bank holiday", .uk),
        (8, 2, -1, "Summer bank holiday", .uk)
    ]

    // MARK: Easter

    /// Gregorian computus (Meeus/Jones/Butcher). Returns (month, day).
    static func easter(year: Int) -> (month: Int, day: Int) {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        return (month, day)
    }

    // MARK: Hindu festivals

    /// A festival pinned to a lunar month, paksha and tithi, judged during a
    /// specific observance window.
    struct HinduRule: Sendable {
        let name: String
        /// Index into `HinduCalendar.monthNames`.
        let month: Int
        let paksha: HinduCalendar.Paksha
        /// 1...15 within the paksha.
        let tithi: Int
        let observance: HinduCalendar.Observance
        var isPublicHoliday: Bool = true
    }

    /// Verified against known 2024–2026 dates; see the tests in the README notes.
    static let hindu: [HinduRule] = [
        HinduRule(name: "Holi", month: 11, paksha: .shukla, tithi: 15, observance: .sunrise),
        HinduRule(name: "Holika Dahan", month: 11, paksha: .shukla, tithi: 15,
                  observance: .dusk, isPublicHoliday: false),
        HinduRule(name: "Gudi Padwa / Ugadi", month: 0, paksha: .shukla, tithi: 1, observance: .midday),
        HinduRule(name: "Ram Navami", month: 0, paksha: .shukla, tithi: 9, observance: .sunrise),
        HinduRule(name: "Mahavir Jayanti", month: 0, paksha: .shukla, tithi: 13, observance: .sunrise),
        HinduRule(name: "Buddha Purnima", month: 1, paksha: .shukla, tithi: 15, observance: .sunrise),
        HinduRule(name: "Raksha Bandhan", month: 4, paksha: .shukla, tithi: 15, observance: .sunrise),
        HinduRule(name: "Krishna Janmashtami", month: 4, paksha: .krishna, tithi: 8, observance: .sunrise),
        HinduRule(name: "Ganesh Chaturthi", month: 5, paksha: .shukla, tithi: 4, observance: .midday),
        HinduRule(name: "Navratri begins", month: 6, paksha: .shukla, tithi: 1,
                  observance: .sunrise, isPublicHoliday: false),
        HinduRule(name: "Durga Ashtami", month: 6, paksha: .shukla, tithi: 8,
                  observance: .sunrise, isPublicHoliday: false),
        HinduRule(name: "Dussehra (Vijayadashami)", month: 6, paksha: .shukla, tithi: 10, observance: .afternoon),
        HinduRule(name: "Dhanteras", month: 6, paksha: .krishna, tithi: 13,
                  observance: .dusk, isPublicHoliday: false),
        HinduRule(name: "Diwali", month: 6, paksha: .krishna, tithi: 15, observance: .dusk),
        HinduRule(name: "Bhai Dooj", month: 7, paksha: .shukla, tithi: 2,
                  observance: .midday, isPublicHoliday: false),
        // Kartika Purnima is an evening observance (Dev Deepawali), so dusk is
        // the window that reproduces the published dates.
        HinduRule(name: "Guru Nanak Jayanti", month: 7, paksha: .shukla, tithi: 15, observance: .dusk),
        HinduRule(name: "Maha Shivratri", month: 10, paksha: .krishna, tithi: 14, observance: .midnight)
    ]

    // MARK: Islamic

    /// Days to add to the Umm al-Qura (Saudi tabular) date. India waits on a
    /// local moon sighting and in practice observes Eid one day later.
    /// Islamic dates are therefore indicative — a sighting can shift them.
    static let islamicOffsetDays = 1

    /// (islamicMonth, islamicDay, name)
    static let islamic: [(month: Int, day: Int, name: String)] = [
        (1, 10, "Muharram (Ashura)"),
        (3, 12, "Milad un-Nabi"),
        (10, 1, "Eid al-Fitr"),
        (12, 10, "Eid al-Adha")
    ]
}

// MARK: - Year index

/// All holidays for one Gregorian year, built in a single pass and cached.
struct HolidayYear: Sendable {
    /// Keyed by days-since-epoch so lookups don't allocate date strings.
    private let byDay: [Int: [Holiday]]

    static func dayKey(_ date: Date, calendar: Calendar) -> Int {
        Int(calendar.startOfDay(for: date).timeIntervalSince1970 / 86_400.0)
    }

    func holidays(on date: Date, calendar: Calendar) -> [Holiday] {
        byDay[Self.dayKey(date, calendar: calendar)] ?? []
    }

    init(year: Int, calendar: Calendar, lunar: HinduCalendar.Year) {
        var map: [Int: [Holiday]] = [:]

        func add(_ holiday: Holiday, on date: Date) {
            map[Self.dayKey(date, calendar: calendar), default: []].append(holiday)
        }

        func date(month: Int, day: Int) -> Date? {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            return calendar.date(from: components)
        }

        // Fixed civil dates.
        for rule in HolidayRules.fixed {
            if let d = date(month: rule.month, day: rule.day) {
                add(Holiday(name: rule.name, region: rule.region), on: d)
            }
        }

        // Nth weekday of month.
        for rule in HolidayRules.nthWeekday {
            if let d = Self.nthWeekday(rule.weekday, week: rule.week, month: rule.month,
                                       year: year, calendar: calendar) {
                add(Holiday(name: rule.name, region: rule.region), on: d)
            }
        }

        // Easter-relative.
        let easter = HolidayRules.easter(year: year)
        if let easterDate = date(month: easter.month, day: easter.day) {
            if let goodFriday = calendar.date(byAdding: .day, value: -2, to: easterDate) {
                add(Holiday(name: "Good Friday", region: .uk), on: goodFriday)
                add(Holiday(name: "Good Friday", region: .india), on: goodFriday)
            }
            if let easterMonday = calendar.date(byAdding: .day, value: 1, to: easterDate) {
                add(Holiday(name: "Easter Monday", region: .uk), on: easterMonday)
            }
            add(Holiday(name: "Easter Sunday", region: .uk, isPublicHoliday: false), on: easterDate)
        }

        // One pass over the year for everything date-dependent.
        var islamicCalendar = Calendar(identifier: .islamicUmmAlQura)
        islamicCalendar.timeZone = calendar.timeZone

        guard let january1 = date(month: 1, day: 1) else {
            byDay = map
            return
        }
        let dayCount = calendar.range(of: .day, in: .year, for: january1)?.count ?? 365

        func dayStart(_ date: Date) -> Date { calendar.startOfDay(for: date) }

        for offset in 0..<dayCount {
            guard let day = calendar.date(byAdding: .day, value: offset, to: january1) else { continue }

            // Hindu festivals: check each rule in its own observance window.
            for rule in HolidayRules.hindu {
                let instant = HinduCalendar.instant(on: day, at: rule.observance, calendar: calendar)
                guard let panchang = lunar.panchang(at: instant),
                      // Adhika months repeat a month name; festivals stay in the
                      // regular (Nija) month.
                      !panchang.isAdhikaMonth,
                      panchang.monthIndex == rule.month,
                      panchang.paksha == rule.paksha,
                      panchang.tithi == rule.tithi
                else { continue }
                add(Holiday(name: rule.name, region: .india,
                            isPublicHoliday: rule.isPublicHoliday), on: day)
            }

            // Islamic dates. Foundation's Umm al-Qura is the Saudi tabular
            // calendar; India observes Eid a day later because it waits on a
            // local sighting, so shift by `islamicOffsetDays`.
            if let shifted = calendar.date(byAdding: .day, value: -HolidayRules.islamicOffsetDays, to: day) {
                let components = islamicCalendar.dateComponents([.month, .day], from: shifted)
                for rule in HolidayRules.islamic
                where components.month == rule.month && components.day == rule.day {
                    add(Holiday(name: rule.name, region: .india), on: day)
                }
            }

            // Makar Sankranti is the day the *transit* into Makara (Capricorn)
            // happens, not the first day that starts with the Sun already there —
            // so compare the sign at this midnight against the next.
            let rashiAtStart = HinduCalendar.rashi(at: dayStart(day))
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: day) {
                let rashiTomorrow = HinduCalendar.rashi(at: dayStart(tomorrow))
                if rashiAtStart == 8, rashiTomorrow == 9 {
                    add(Holiday(name: "Makar Sankranti", region: .india), on: day)
                }
            }
        }

        byDay = map
    }

    /// Nth (or last, when `week` is -1) `weekday` of a month.
    private static func nthWeekday(_ weekday: Int, week: Int, month: Int,
                                   year: Int, calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.weekday = weekday
        components.weekdayOrdinal = week == -1 ? -1 : week
        return calendar.date(from: components)
    }
}
