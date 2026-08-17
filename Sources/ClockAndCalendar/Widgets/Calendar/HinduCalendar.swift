import Foundation

/// Hindu lunisolar (Amanta) calendar: tithi, paksha and lunar month.
///
/// Conventions used, which are the ones a printed panchang uses:
///  * A tithi is 1/30th of the Moon's elongation from the Sun, and the tithi
///    *for a day* is the one current at sunrise (approximated as 06:00 local).
///  * Months are Amanta — each begins the day after a new moon — and takes its
///    name from the sidereal (nirayana) sign the Sun occupies at that new moon.
///  * Sidereal longitude uses the Lahiri ayanamsa, the Indian civil standard.
///
/// Accuracy: tithi boundaries land within a few minutes of an authoritative
/// panchang, so a day label can differ when a boundary falls close to sunrise.
/// Regional panchangs also disagree with each other for the same reason.
enum HinduCalendar {

    // MARK: Names

    static let monthNames = [
        "Chaitra", "Vaishakha", "Jyeshtha", "Ashadha", "Shravana", "Bhadrapada",
        "Ashwina", "Kartika", "Margashirsha", "Pausha", "Magha", "Phalguna"
    ]

    static let tithiNames = [
        "Pratipada", "Dwitiya", "Tritiya", "Chaturthi", "Panchami",
        "Shashthi", "Saptami", "Ashtami", "Navami", "Dashami",
        "Ekadashi", "Dwadashi", "Trayodashi", "Chaturdashi"
    ]

    enum Paksha: String, Sendable {
        case shukla, krishna

        var label: String {
            switch self {
            case .shukla: "Shukla"
            case .krishna: "Krishna"
            }
        }
    }

    // MARK: Gujarati names
    //
    // Not transliterations of the Sanskrit: these are the words a Gujarati
    // panchang actually prints. The paksha is સુદ / વદ rather than
    // Shukla / Krishna, and the tithis are એકમ, બીજ, ત્રીજ… not Pratipada,
    // Dwitiya, Tritiya.

    static let gujaratiMonthNames = [
        "ચૈત્ર", "વૈશાખ", "જેઠ", "અષાઢ", "શ્રાવણ", "ભાદરવો",
        "આસો", "કારતક", "માગશર", "પોષ", "મહા", "ફાગણ"
    ]

    static let gujaratiTithiNames = [
        "એકમ", "બીજ", "ત્રીજ", "ચોથ", "પાંચમ",
        "છઠ", "સાતમ", "આઠમ", "નોમ", "દશમ",
        "અગિયારસ", "બારસ", "તેરસ", "ચૌદસ"
    ]

    static func gujaratiPaksha(_ paksha: Paksha) -> String {
        switch paksha {
        case .shukla: "સુદ"
        case .krishna: "વદ"
        }
    }

    /// One day's panchang essentials.
    struct Day: Sendable, Equatable {
        /// 1...30 across the whole lunation.
        let tithiIndex: Int
        /// 1...15 within the paksha.
        let tithi: Int
        let paksha: Paksha
        /// 0 = Chaitra.
        let monthIndex: Int
        /// True for an intercalary (Adhika) month.
        let isAdhikaMonth: Bool

        func monthName(_ language: PanchangLanguage) -> String {
            let names = language == .gujarati ? HinduCalendar.gujaratiMonthNames : HinduCalendar.monthNames
            let prefix = isAdhikaMonth ? (language == .gujarati ? "અધિક " : "Adhika ") : ""
            return prefix + names[monthIndex]
        }

        /// Purnima / Amavasya (પૂનમ / અમાસ) replace the 15th tithi of each paksha.
        func tithiName(_ language: PanchangLanguage) -> String {
            if tithi == 15 {
                if language == .gujarati { return paksha == .shukla ? "પૂનમ" : "અમાસ" }
                return paksha == .shukla ? "Purnima" : "Amavasya"
            }
            let names = language == .gujarati ? HinduCalendar.gujaratiTithiNames : HinduCalendar.tithiNames
            return names[tithi - 1]
        }

        func pakshaName(_ language: PanchangLanguage) -> String {
            language == .gujarati ? HinduCalendar.gujaratiPaksha(paksha) : paksha.label
        }

        /// Label for the calendar cell: "સુદ ૧૨" / "વદ ૩" / "પૂનમ" / "અમાસ" in
        /// Gujarati, "S 12" / "P" / "A" in English.
        func shortLabel(_ language: PanchangLanguage) -> String {
            switch language {
            case .gujarati:
                if tithi == 15 { return paksha == .shukla ? "પૂનમ" : "અમાસ" }
                return "\(HinduCalendar.gujaratiPaksha(paksha)) \(language.digits(tithi))"
            case .devanagari:
                if tithi == 15 { return paksha == .shukla ? "पूर्णिमा" : "अमावस्या" }
                return "\(paksha == .shukla ? "शु" : "कृ") \(language.digits(tithi))"
            case .english:
                if tithi == 15 { return paksha == .shukla ? "Purnima" : "Amavasya" }
                return "\(paksha == .shukla ? "S" : "K") \(language.digits(tithi))"
            }
        }

        /// "શ્રાવણ સુદ પાંચમ" / "Shravana · Shukla Panchami".
        func fullLabel(_ language: PanchangLanguage) -> String {
            switch language {
            case .gujarati:
                return "\(monthName(language)) \(pakshaName(language)) \(tithiName(language))"
            case .english, .devanagari:
                return "\(monthName(language)) · \(pakshaName(language)) \(tithiName(language))"
            }
        }
    }

    // MARK: Observance windows
    //
    // A festival is not simply "this tithi at sunrise". Each has a traditional
    // window during which the tithi must prevail, and using the wrong one shifts
    // the date by a day. These four are the ones the classical rules name.

    enum Observance: Sendable {
        /// Sunrise — the default for a tithi's day label.
        case sunrise
        /// Madhyahna, midday. Ganesh Chaturthi, Ram Navami.
        case midday
        /// Aparahna, mid-afternoon. Vijayadashami.
        case afternoon
        /// Pradosh, dusk. Diwali/Amavasya.
        case dusk
        /// Nishita, near midnight. Maha Shivratri, Janmashtami.
        case midnight

        var hour: Int {
            switch self {
            case .sunrise: 6
            case .midday: 12
            case .afternoon: 15
            case .dusk: 18
            case .midnight: 23
            }
        }
    }

    // MARK: Tithi

    /// Tithi index 1...30 at an exact instant.
    static func tithiIndex(at instant: Date) -> Int {
        min(30, Int(floor(Astronomy.elongation(Astronomy.julianDay(instant)) / 12.0)) + 1)
    }

    /// The instant a `Observance` window falls on for a given day.
    static func instant(on day: Date, at observance: Observance, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .hour, value: observance.hour, to: start) ?? start
    }

    // MARK: Computation

    /// Panchang for the calendar day containing `date`, in `timeZone`.
    ///
    /// Convenience wrapper; rendering a whole month goes through `Year`, which
    /// solves the lunar months once instead of once per day.
    static func day(for date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> Day {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        let reference = instant(on: date, at: .sunrise, calendar: gregorian)

        let index = tithiIndex(at: reference)
        let newMoon = previousNewMoon(before: reference)
        let earlier = previousNewMoon(before: newMoon.addingTimeInterval(-2 * 86_400))

        return Day(tithiIndex: index,
                   tithi: index <= 15 ? index : index - 15,
                   paksha: index <= 15 ? .shukla : .krishna,
                   monthIndex: monthIndex(forNewMoonAt: newMoon),
                   isAdhikaMonth: rashi(at: newMoon) == rashi(at: earlier))
    }

    // MARK: Year

    /// A lunar month: when it began and what it's called.
    struct LunarMonth: Sendable {
        let newMoon: Date
        let monthIndex: Int
        let isAdhika: Bool
    }

    /// Every lunar month touching a Gregorian year, solved once.
    ///
    /// Rendering a month view needs the panchang for ~42 days at up to five
    /// observance hours. Locating the enclosing new moon per lookup would repeat
    /// a 40-step bisection thousands of times; here it happens ~14 times a year.
    struct Year: Sendable {
        let months: [LunarMonth]

        init(year: Int, calendar: Calendar) {
            var components = DateComponents()
            components.year = year
            components.month = 1
            components.day = 1
            let start = calendar.date(from: components) ?? Date()
            // Pad both ends so January's and December's months are fully resolved.
            let end = start.addingTimeInterval(400 * 86_400)

            var found: [LunarMonth] = []
            var moment = HinduCalendar.previousNewMoon(before: start.addingTimeInterval(-45 * 86_400))
            var previousRashi: Int?

            while moment < end, found.count < 20 {
                let signAtNewMoon = HinduCalendar.rashi(at: moment)
                found.append(
                    LunarMonth(
                        newMoon: moment,
                        monthIndex: HinduCalendar.monthIndex(forNewMoonAt: moment),
                        // Two consecutive new moons under the same sign: the
                        // first month is intercalary (Adhika).
                        isAdhika: previousRashi == signAtNewMoon
                    )
                )
                previousRashi = signAtNewMoon
                moment = HinduCalendar.nextNewMoon(after: moment.addingTimeInterval(3600))
            }
            months = found
        }

        /// The lunar month containing an instant.
        func month(at instant: Date) -> LunarMonth? {
            months.last { $0.newMoon <= instant }
        }

        /// Panchang at an exact instant.
        func panchang(at instant: Date) -> Day? {
            guard let month = month(at: instant) else { return nil }
            let index = HinduCalendar.tithiIndex(at: instant)
            return Day(tithiIndex: index,
                       tithi: index <= 15 ? index : index - 15,
                       paksha: index <= 15 ? .shukla : .krishna,
                       monthIndex: month.monthIndex,
                       isAdhikaMonth: month.isAdhika)
        }
    }

    // MARK: Lunar month

    /// Instant of the last new moon at or before `date`.
    ///
    /// Estimates the position from the current elongation, then bisects on the
    /// elongation wrap so the result is minutes-accurate rather than day-accurate.
    static func previousNewMoon(before date: Date) -> Date {
        let synodicMonth = 29.530588
        let elongation = Astronomy.elongation(Astronomy.julianDay(date))
        let estimate = date.addingTimeInterval(-(elongation / 360.0) * synodicMonth * 86_400)

        // Bracket the crossing: walk out from the estimate until elongation is
        // small just after and large just before.
        var low = estimate.addingTimeInterval(-2 * 86_400)
        var high = estimate.addingTimeInterval(2 * 86_400)

        // Elongation near a new moon runs 355°… → 0 → …5°. Work with a signed
        // offset so bisection sees a monotonic function.
        func signed(_ moment: Date) -> Double {
            let value = Astronomy.elongation(Astronomy.julianDay(moment))
            return value > 180 ? value - 360 : value
        }

        guard signed(low) < 0, signed(high) > 0 else { return estimate }

        for _ in 0..<40 {
            let mid = Date(timeIntervalSince1970: (low.timeIntervalSince1970 + high.timeIntervalSince1970) / 2)
            if signed(mid) < 0 { low = mid } else { high = mid }
        }
        return high
    }

    /// Instant of the first new moon strictly after `date`.
    ///
    /// Mirrors `previousNewMoon` so month stepping can't drift: estimating the
    /// next one by adding a synodic month and then searching *backwards* is what
    /// made an earlier version skip alternate months.
    static func nextNewMoon(after date: Date) -> Date {
        let synodicMonth = 29.530588
        let elongation = Astronomy.elongation(Astronomy.julianDay(date))
        // Fraction of the lunation still to run.
        let remaining = (360.0 - elongation) / 360.0
        let estimate = date.addingTimeInterval(remaining * synodicMonth * 86_400)

        func signed(_ moment: Date) -> Double {
            let value = Astronomy.elongation(Astronomy.julianDay(moment))
            return value > 180 ? value - 360 : value
        }

        var low = estimate.addingTimeInterval(-2 * 86_400)
        var high = estimate.addingTimeInterval(2 * 86_400)
        guard signed(low) < 0, signed(high) > 0 else { return estimate }

        for _ in 0..<40 {
            let mid = Date(timeIntervalSince1970: (low.timeIntervalSince1970 + high.timeIntervalSince1970) / 2)
            if signed(mid) < 0 { low = mid } else { high = mid }
        }
        return high
    }

    /// Lahiri ayanamsa in degrees: the offset between tropical and sidereal
    /// longitudes, drifting by about 50.29″ a year.
    static func ayanamsa(at date: Date) -> Double {
        let year = Double(Calendar(identifier: .gregorian).component(.year, from: date))
        return 23.853 + 0.013969 * (year - 2000)
    }

    /// Sidereal sign the Sun occupies: 0 = Mesha (Aries) … 11 = Meena (Pisces).
    static func rashi(at date: Date) -> Int {
        let tropical = Astronomy.sunLongitude(Astronomy.julianDay(date))
        let sidereal = Astronomy.normalize(tropical - ayanamsa(at: date))
        return min(11, Int(floor(sidereal / 30.0)))
    }

    /// An Amanta month starting at `newMoon` is named for the sign the Sun is in:
    /// a new moon with the Sun in Meena opens Chaitra, in Mesha opens Vaishakha,
    /// and so on round the zodiac.
    static func monthIndex(forNewMoonAt newMoon: Date) -> Int {
        (rashi(at: newMoon) + 1) % 12
    }
}
