import Foundation

/// Solar and lunar positions, accurate enough to date moon phases and Hindu
/// tithis to the day.
///
/// These are the standard truncated series from Meeus, *Astronomical Algorithms*
/// (chapters 25 and 47). The lunar longitude series is cut after the 14 largest
/// periodic terms, which holds the Moon to roughly 0.02° — about 40 seconds of
/// its motion. That is far inside the precision needed to say which calendar day
/// a phase or tithi boundary falls on.
///
/// Everything here is pure and stateless, so it is equally usable from a future
/// WidgetKit extension.
enum Astronomy {

    // MARK: Time

    /// Julian Day number (UT) for an instant.
    static func julianDay(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400.0 + 2_440_587.5
    }

    /// Julian centuries since J2000.0.
    private static func centuries(_ jd: Double) -> Double {
        (jd - 2_451_545.0) / 36_525.0
    }

    // MARK: Angles

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }

    /// Normalises to 0..<360.
    static func normalize(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    // MARK: Sun

    /// Apparent geocentric longitude of the Sun, in degrees.
    static func sunLongitude(_ jd: Double) -> Double {
        let t = centuries(jd)
        let meanLongitude: Double = 280.46646 + 36_000.76983 * t + 0.0003032 * t * t
        let meanAnomaly: Double = radians(357.52911 + 35_999.05029 * t - 0.0001537 * t * t)

        // Equation of the centre, split up for the type checker's sake.
        var centre: Double = (1.914602 - 0.004817 * t - 0.000014 * t * t) * sin(meanAnomaly)
        centre += (0.019993 - 0.000101 * t) * sin(2 * meanAnomaly)
        centre += 0.000289 * sin(3 * meanAnomaly)

        return normalize(meanLongitude + centre)
    }

    // MARK: Moon

    /// Apparent geocentric longitude of the Moon, in degrees.
    static func moonLongitude(_ jd: Double) -> Double {
        let t = centuries(jd)

        let meanLongitude = 218.3164477 + 481_267.88123421 * t - 0.0015786 * t * t
        let elongation = radians(297.8501921 + 445_267.1114034 * t - 0.0018819 * t * t)
        let sunAnomaly = radians(357.5291092 + 35_999.0502909 * t)
        let moonAnomaly = radians(134.9633964 + 477_198.8675055 * t + 0.0087414 * t * t)
        let argLatitude = radians(93.2720950 + 483_202.0175233 * t - 0.0036539 * t * t)

        let d: Double = elongation
        let m: Double = sunAnomaly
        let mp: Double = moonAnomaly
        let f: Double = argLatitude

        // Kept as separate statements: as one 15-term expression the Swift type
        // checker gives up ("unable to type-check in reasonable time").
        var correction: Double = 6.288774 * sin(mp)
        correction += 1.274027 * sin(2 * d - mp)
        correction += 0.658314 * sin(2 * d)
        correction += 0.213618 * sin(2 * mp)
        correction -= 0.185116 * sin(m)
        correction -= 0.114332 * sin(2 * f)
        correction += 0.058793 * sin(2 * d - 2 * mp)
        correction += 0.057066 * sin(2 * d - m - mp)
        correction += 0.053322 * sin(2 * d + mp)
        correction += 0.045758 * sin(2 * d - m)
        correction -= 0.040923 * sin(m - mp)
        correction -= 0.034720 * sin(d)
        correction -= 0.030383 * sin(m + mp)
        correction += 0.015327 * sin(2 * d - 2 * f)

        return normalize(meanLongitude + correction)
    }

    // MARK: Phase

    /// Moon−Sun elongation in degrees: 0 at new moon, 180 at full moon.
    /// This is also the quantity the Hindu tithi divides into 30 steps.
    static func elongation(_ jd: Double) -> Double {
        normalize(moonLongitude(jd) - sunLongitude(jd))
    }

    /// Illuminated fraction of the Moon's disc, 0...1.
    static func illumination(_ date: Date) -> Double {
        (1 - cos(radians(elongation(julianDay(date))))) / 2
    }

    enum MoonEvent {
        case newMoon
        case firstQuarter
        case fullMoon
        case lastQuarter

        /// Elongation the event happens at.
        var elongation: Double {
            switch self {
            case .newMoon: 0
            case .firstQuarter: 90
            case .fullMoon: 180
            case .lastQuarter: 270
            }
        }

        var label: String {
            switch self {
            case .newMoon: "New moon"
            case .firstQuarter: "First quarter"
            case .fullMoon: "Full moon"
            case .lastQuarter: "Last quarter"
            }
        }
    }

    /// The phase event occurring between `start` and `end`, if any.
    ///
    /// Detected by watching the elongation cross the event's target angle, which
    /// is exact regardless of how long the interval is — no lunation counting and
    /// no accumulating drift.
    static func moonEvent(between start: Date, and end: Date) -> MoonEvent? {
        let a = elongation(julianDay(start))
        let b = elongation(julianDay(end))

        for event in [MoonEvent.newMoon, .firstQuarter, .fullMoon, .lastQuarter] {
            if crosses(from: a, to: b, target: event.elongation) { return event }
        }
        return nil
    }

    /// True when the angle sweeps past `target` going forward from `from` to `to`.
    /// Handles the 360→0 wrap, which is exactly where the new moon sits.
    private static func crosses(from: Double, to: Double, target: Double) -> Bool {
        let swept = normalize(to - from)
        // Guard against an interval so long it laps the target twice.
        guard swept < 180 else { return true }
        return normalize(target - from) <= swept && normalize(target - from) > 0
            || (from == target)
    }
}
