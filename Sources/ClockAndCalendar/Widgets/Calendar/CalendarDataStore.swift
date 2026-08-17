import Foundation
import SwiftUI

/// Moon phase indicator.
///
/// Drawn rather than taken from SF Symbols: `moonphase.new.moon` renders as a
/// filled disc and `moonphase.full.moon` as an outline, which is the opposite of
/// what a reader expects — a full moon should be the solid one.
struct MoonGlyph: View {
    let event: Astronomy.MoonEvent
    var size: CGFloat = 7.5
    var color: Color

    private var lineWidth: CGFloat { max(0.7, size * 0.16) }

    var body: some View {
        switch event {
        case .fullMoon:
            Circle()
                .fill(color)
                .frame(width: size, height: size)
        case .newMoon:
            Circle()
                .strokeBorder(color, lineWidth: lineWidth)
                .frame(width: size, height: size)
        case .firstQuarter:
            halfMoon(litOnRight: true)
        case .lastQuarter:
            halfMoon(litOnRight: false)
        }
    }

    private func halfMoon(litOnRight: Bool) -> some View {
        Circle()
            .strokeBorder(color, lineWidth: lineWidth)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .mask(
                        Rectangle()
                            .frame(width: size / 2, height: size)
                            .offset(x: litOnRight ? size / 4 : -size / 4)
                    )
            )
    }
}

/// Everything the calendar wants to know about one day beyond its number.
struct DayInfo: Sendable, Equatable {
    var holidays: [Holiday] = []
    var panchang: HinduCalendar.Day?
    var moonEvent: Astronomy.MoonEvent?

    var isEmpty: Bool { holidays.isEmpty && panchang == nil && moonEvent == nil }

    /// Holidays the user asked to see, in a stable order.
    func holidays(in regions: Set<HolidayRegion>) -> [Holiday] {
        holidays
            .filter { regions.contains($0.region) }
            .sorted { lhs, rhs in
                if lhs.isPublicHoliday != rhs.isPublicHoliday { return lhs.isPublicHoliday }
                return lhs.name < rhs.name
            }
    }
}

/// Caches a year's holidays, lunar months and moon phases.
///
/// The astronomy is cheap per call but a month view asks about ~42 days on every
/// redraw, and a redraw happens on every hover. Everything is computed once per
/// (year, time zone) and then read from a dictionary.
@MainActor
final class CalendarDataStore {
    static let shared = CalendarDataStore()

    private struct Key: Hashable {
        let year: Int
        let timeZoneIdentifier: String
    }

    private var cache: [Key: [Int: DayInfo]] = [:]

    private init() {}

    /// Discards cached years. Call if the time zone changes under us.
    func invalidate() { cache.removeAll() }

    func info(for day: Date, calendar: Calendar) -> DayInfo {
        let year = calendar.component(.year, from: day)
        let key = Key(year: year, timeZoneIdentifier: calendar.timeZone.identifier)

        let table: [Int: DayInfo]
        if let cached = cache[key] {
            table = cached
        } else {
            table = Self.buildYear(year: year, calendar: calendar)
            cache[key] = table
            // Two adjacent years are enough for a month view's spill days.
            if cache.count > 6 { trim(keeping: key) }
        }
        return table[HolidayYear.dayKey(day, calendar: calendar)] ?? DayInfo()
    }

    /// Every computed holiday name in a year, for the holiday manager's list.
    ///
    /// Deliberately not filtered by region or by the hidden set: the manager has
    /// to show what it would hide.
    func catalogue(year: Int, calendar: Calendar) -> [(region: HolidayRegion, name: String, isPublic: Bool)] {
        let key = Key(year: year, timeZoneIdentifier: calendar.timeZone.identifier)
        let table = cache[key] ?? {
            let built = Self.buildYear(year: year, calendar: calendar)
            cache[key] = built
            return built
        }()

        var seen: Set<String> = []
        var result: [(region: HolidayRegion, name: String, isPublic: Bool)] = []
        // Sorted by day so the list reads chronologically.
        for dayKey in table.keys.sorted() {
            for holiday in table[dayKey]?.holidays ?? [] {
                let identity = "\(holiday.region.rawValue)|\(holiday.name)"
                guard seen.insert(identity).inserted else { continue }
                result.append((holiday.region, holiday.name, holiday.isPublicHoliday))
            }
        }
        return result
    }

    private func trim(keeping key: Key) {
        for existing in cache.keys where abs(existing.year - key.year) > 2 {
            cache[existing] = nil
        }
    }

    // MARK: Build

    private static func buildYear(year: Int, calendar: Calendar) -> [Int: DayInfo] {
        // Use a fixed Gregorian calendar for the maths; the user's `firstWeekday`
        // must not influence dates, only layout.
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        gregorian.locale = calendar.locale

        let lunar = HinduCalendar.Year(year: year, calendar: gregorian)
        let holidays = HolidayYear(year: year, calendar: gregorian, lunar: lunar)

        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        guard let january1 = gregorian.date(from: components) else { return [:] }
        let dayCount = gregorian.range(of: .day, in: .year, for: january1)?.count ?? 365

        var table: [Int: DayInfo] = [:]
        table.reserveCapacity(dayCount)

        for offset in 0..<dayCount {
            guard let day = gregorian.date(byAdding: .day, value: offset, to: january1) else { continue }
            let dayStart = gregorian.startOfDay(for: day)
            guard let nextDayStart = gregorian.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            var info = DayInfo()
            info.holidays = holidays.holidays(on: dayStart, calendar: gregorian)
            info.panchang = lunar.panchang(
                at: HinduCalendar.instant(on: dayStart, at: .sunrise, calendar: gregorian)
            )
            info.moonEvent = Astronomy.moonEvent(between: dayStart, and: nextDayStart)

            if !info.isEmpty {
                table[HolidayYear.dayKey(dayStart, calendar: gregorian)] = info
            }
        }
        return table
    }
}
