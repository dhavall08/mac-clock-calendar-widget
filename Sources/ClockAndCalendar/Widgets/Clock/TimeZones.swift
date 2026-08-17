import Foundation

/// A pickable time zone for the world-clock mode.
///
/// Identifiers are IANA zones, so daylight saving is handled by the system's tz
/// database — no offset arithmetic here. `TimeZone.secondsFromGMT(for:)` is
/// evaluated against the current instant, which is what makes "London" read
/// +1:00 in July and +0:00 in January without any special-casing.
struct WorldZone: Identifiable, Hashable, Sendable {
    /// IANA identifier, e.g. "Europe/London". `nil` means the system zone.
    let identifier: String?
    let city: String
    let country: String

    var id: String { identifier ?? "system" }

    var label: String { identifier == nil ? "System (this Mac)" : "\(city), \(country)" }

    var timeZone: TimeZone {
        guard let identifier, let zone = TimeZone(identifier: identifier) else {
            return TimeZone.autoupdatingCurrent
        }
        return zone
    }

    /// Current UTC offset as "+5:30" / "−4:00", reflecting DST right now.
    func offsetLabel(at date: Date = Date()) -> String {
        let seconds = timeZone.secondsFromGMT(for: date)
        let sign = seconds < 0 ? "−" : "+"
        let total = abs(seconds) / 60
        return String(format: "%@%d:%02d", sign, total / 60, total % 60)
    }

    /// True when this zone is on a different calendar day than the local one.
    func dayDifference(at date: Date = Date()) -> Int {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = TimeZone.autoupdatingCurrent
        var remote = Calendar(identifier: .gregorian)
        remote.timeZone = timeZone

        let localDay = local.dateComponents([.year, .month, .day], from: date)
        let remoteDay = remote.dateComponents([.year, .month, .day], from: date)
        guard let a = local.date(from: localDay), let b = local.date(from: remoteDay) else { return 0 }
        return Int((b.timeIntervalSince(a) / 86_400).rounded())
    }
}

enum WorldZones {
    static let system = WorldZone(identifier: nil, city: "System", country: "")

    /// A curated list rather than all ~600 IANA zones, ordered west to east.
    /// The picker also accepts any identifier the system knows.
    static let curated: [WorldZone] = [
        WorldZone(identifier: "Pacific/Honolulu", city: "Honolulu", country: "USA"),
        WorldZone(identifier: "America/Anchorage", city: "Anchorage", country: "USA"),
        WorldZone(identifier: "America/Los_Angeles", city: "Los Angeles", country: "USA"),
        WorldZone(identifier: "America/Vancouver", city: "Vancouver", country: "Canada"),
        WorldZone(identifier: "America/Denver", city: "Denver", country: "USA"),
        WorldZone(identifier: "America/Mexico_City", city: "Mexico City", country: "Mexico"),
        WorldZone(identifier: "America/Chicago", city: "Chicago", country: "USA"),
        WorldZone(identifier: "America/New_York", city: "New York", country: "USA"),
        WorldZone(identifier: "America/Toronto", city: "Toronto", country: "Canada"),
        WorldZone(identifier: "America/Bogota", city: "Bogotá", country: "Colombia"),
        WorldZone(identifier: "America/Sao_Paulo", city: "São Paulo", country: "Brazil"),
        WorldZone(identifier: "America/Argentina/Buenos_Aires", city: "Buenos Aires", country: "Argentina"),
        WorldZone(identifier: "Atlantic/Reykjavik", city: "Reykjavík", country: "Iceland"),
        WorldZone(identifier: "Europe/London", city: "London", country: "UK"),
        WorldZone(identifier: "Europe/Dublin", city: "Dublin", country: "Ireland"),
        WorldZone(identifier: "Europe/Lisbon", city: "Lisbon", country: "Portugal"),
        WorldZone(identifier: "Europe/Madrid", city: "Madrid", country: "Spain"),
        WorldZone(identifier: "Europe/Paris", city: "Paris", country: "France"),
        WorldZone(identifier: "Europe/Amsterdam", city: "Amsterdam", country: "Netherlands"),
        WorldZone(identifier: "Europe/Brussels", city: "Brussels", country: "Belgium"),
        WorldZone(identifier: "Europe/Zurich", city: "Zurich", country: "Switzerland"),
        WorldZone(identifier: "Europe/Berlin", city: "Berlin", country: "Germany"),
        WorldZone(identifier: "Europe/Rome", city: "Rome", country: "Italy"),
        WorldZone(identifier: "Europe/Stockholm", city: "Stockholm", country: "Sweden"),
        WorldZone(identifier: "Europe/Warsaw", city: "Warsaw", country: "Poland"),
        WorldZone(identifier: "Africa/Lagos", city: "Lagos", country: "Nigeria"),
        WorldZone(identifier: "Africa/Cairo", city: "Cairo", country: "Egypt"),
        WorldZone(identifier: "Africa/Johannesburg", city: "Johannesburg", country: "South Africa"),
        WorldZone(identifier: "Europe/Athens", city: "Athens", country: "Greece"),
        WorldZone(identifier: "Europe/Istanbul", city: "Istanbul", country: "Türkiye"),
        WorldZone(identifier: "Europe/Moscow", city: "Moscow", country: "Russia"),
        WorldZone(identifier: "Asia/Jerusalem", city: "Jerusalem", country: "Israel"),
        WorldZone(identifier: "Asia/Dubai", city: "Dubai", country: "UAE"),
        WorldZone(identifier: "Asia/Karachi", city: "Karachi", country: "Pakistan"),
        WorldZone(identifier: "Asia/Kolkata", city: "Mumbai", country: "India"),
        WorldZone(identifier: "Asia/Colombo", city: "Colombo", country: "Sri Lanka"),
        WorldZone(identifier: "Asia/Kathmandu", city: "Kathmandu", country: "Nepal"),
        WorldZone(identifier: "Asia/Dhaka", city: "Dhaka", country: "Bangladesh"),
        WorldZone(identifier: "Asia/Bangkok", city: "Bangkok", country: "Thailand"),
        WorldZone(identifier: "Asia/Jakarta", city: "Jakarta", country: "Indonesia"),
        WorldZone(identifier: "Asia/Singapore", city: "Singapore", country: "Singapore"),
        WorldZone(identifier: "Asia/Hong_Kong", city: "Hong Kong", country: "China"),
        WorldZone(identifier: "Asia/Shanghai", city: "Shanghai", country: "China"),
        WorldZone(identifier: "Asia/Manila", city: "Manila", country: "Philippines"),
        WorldZone(identifier: "Asia/Seoul", city: "Seoul", country: "South Korea"),
        WorldZone(identifier: "Asia/Tokyo", city: "Tokyo", country: "Japan"),
        WorldZone(identifier: "Australia/Perth", city: "Perth", country: "Australia"),
        WorldZone(identifier: "Australia/Adelaide", city: "Adelaide", country: "Australia"),
        WorldZone(identifier: "Australia/Sydney", city: "Sydney", country: "Australia"),
        WorldZone(identifier: "Pacific/Auckland", city: "Auckland", country: "New Zealand")
    ]

    static var all: [WorldZone] { [system] + curated }

    /// Resolves a stored identifier, falling back to a synthesised entry so an
    /// identifier typed by hand (or one dropped from the curated list) still works.
    static func zone(for identifier: String?) -> WorldZone {
        guard let identifier else { return system }
        if let match = curated.first(where: { $0.identifier == identifier }) { return match }
        guard TimeZone(identifier: identifier) != nil else { return system }
        let city = identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") }
        return WorldZone(identifier: identifier, city: city ?? identifier, country: "")
    }
}
