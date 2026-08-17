import SwiftUI

// MARK: - Config

enum ClockFace: String, Codable, CaseIterable, Identifiable, Sendable {
    case digital, analog

    var id: String { rawValue }
    var label: String {
        switch self {
        case .digital: "Digital"
        case .analog: "Analog"
        }
    }
}

/// Look of the analog dial.
enum DialStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Follows the widget theme: dark dial, accent-tinted ticks, neon glow.
    case modern
    /// The stock macOS clock: white face, black tapered hands, coloured second
    /// hand, black 5-minute ticks with fine grey minute ticks between them.
    case classic

    var id: String { rawValue }
    var label: String {
        switch self {
        case .modern: "Modern"
        case .classic: "Classic"
        }
    }
}

/// How the hours are labelled around an analog dial.
enum DialNumerals: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, quarters, all, roman

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "None"
        case .quarters: "3·6·9·12"
        case .all: "1–12"
        case .roman: "Roman"
        }
    }

    func hours() -> [Int] {
        switch self {
        case .none: []
        case .quarters: [12, 3, 6, 9]
        case .all, .roman: Array(1...12)
        }
    }

    func text(for hour: Int) -> String {
        guard self == .roman else { return "\(hour)" }
        let numerals = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]
        return numerals[hour - 1]
    }
}

struct ClockConfig: WidgetConfig {
    var face: ClockFace = .digital
    var use24Hour: Bool = false
    var showSeconds: Bool = true
    var showDate: Bool = true

    // Digital
    /// Point size of the time itself, at scale 1.0.
    var digitSize: Double = 46

    // Analog
    var dialStyle: DialStyle = .classic
    /// Diameter of the dial, at scale 1.0.
    var dialDiameter: Double = 176
    var showTicks: Bool = true
    var numerals: DialNumerals = .all
    /// Point size of the hour numbers, at scale 1.0.
    var numeralSize: Double = 17
    var sweepSecondHand: Bool = true

    var typeStyle: TypeStyle = .rounded

    // World clock
    /// IANA identifier, or nil for this Mac's zone. DST is handled by the
    /// system tz database, so no offset is stored.
    var timeZoneIdentifier: String? = nil
    /// Shows the city and its live UTC offset under the time.
    var showZoneLabel: Bool = true

    static let defaults = ClockConfig()

    var zone: WorldZone { WorldZones.zone(for: timeZoneIdentifier) }
    var isWorldClock: Bool { timeZoneIdentifier != nil }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ClockConfig()
        face = c.value(.face, d.face)
        use24Hour = c.value(.use24Hour, d.use24Hour)
        showSeconds = c.value(.showSeconds, d.showSeconds)
        showDate = c.value(.showDate, d.showDate)
        digitSize = c.value(.digitSize, d.digitSize)
        dialStyle = c.value(.dialStyle, d.dialStyle)
        dialDiameter = c.value(.dialDiameter, d.dialDiameter)
        showTicks = c.value(.showTicks, d.showTicks)
        numerals = c.value(.numerals, d.numerals)
        numeralSize = c.value(.numeralSize, d.numeralSize)
        sweepSecondHand = c.value(.sweepSecondHand, d.sweepSecondHand)
        typeStyle = c.value(.typeStyle, d.typeStyle)
        timeZoneIdentifier = c.value(.timeZoneIdentifier, d.timeZoneIdentifier)
        showZoneLabel = c.value(.showZoneLabel, d.showZoneLabel)
    }

    enum Metrics {
        static let padding: CGFloat = 16
        static let dateRow: CGFloat = 26
        static let zoneRow: CGFloat = 20
    }

    /// The zone caption only earns a row when this is a world clock.
    var showsZoneRow: Bool { isWorldClock && showZoneLabel }

    /// Derived from the size sliders so the panel always fits its contents.
    var size: CGSize {
        let padding = Metrics.padding * 2
        switch face {
        case .digital:
            // Monospaced digits run ~0.64em, colons ~0.32em.
            let glyphWidth: Double = showSeconds ? (6 * 0.64 + 2 * 0.32) : (4 * 0.64 + 0.32)
            var width = padding + digitSize * glyphWidth + 8
            if !use24Hour { width += digitSize * 0.34 + 6 }
            var height = padding + digitSize * 1.45
            if showDate { height += Metrics.dateRow }
            if showsZoneRow { height += Metrics.zoneRow }
            return CGSize(width: width.rounded(), height: height.rounded())
        case .analog:
            var height = padding + dialDiameter
            if showDate { height += Metrics.dateRow }
            if showsZoneRow { height += Metrics.zoneRow }
            return CGSize(width: (padding + dialDiameter).rounded(), height: height.rounded())
        }
    }
}

// MARK: - Provider

enum ClockWidget: WidgetProvider {
    typealias Config = ClockConfig

    static let kind = "clock"
    static let displayName = "Clock"
    static let symbolName = "clock"
    static let blurb = "Digital or analog time. Classic dial matches the stock macOS clock."
    static let minScale: Double = 0.6

    static func baseSize(for config: ClockConfig) -> CGSize { config.size }

    static func content(_ ctx: WidgetContext<ClockConfig>) -> some View {
        ClockWidgetView(
            config: ctx.config,
            theme: ctx.chrome.theme,
            accent: ctx.accent,
            showGlow: ctx.chrome.showsGlow
        )
    }

    static func settings(_ ctx: WidgetContext<ClockConfig>) -> some View {
        ClockSettingsView(state: ctx.state, id: ctx.id)
    }
}

// MARK: - View

struct ClockWidgetView: View {
    let config: ClockConfig
    let theme: WidgetTheme
    let accent: Accent
    let showGlow: Bool

    @ObservedObject private var time = TimeKeeper.shared

    private var design: Font.Design { .from(config.typeStyle) }
    private var palette: Palette { Palette.of(theme) }
    private var accentColor: Color { accent.color(theme) }

    private var isClassic: Bool { config.face == .analog && config.dialStyle == .classic }

    /// Second hand and hub colour on the dial.
    ///
    /// The classic face is white whatever the widget theme is, so it takes the
    /// undimmed accent — the light theme's darkened variant exists for accents
    /// sitting on a light *panel*, and applying it here turned the stock clock's
    /// vivid orange into brown.
    private var dialAccent: Color { isClassic ? accent.color(.dark) : accent.color(theme) }

    private var radius: CGFloat { config.dialDiameter / 2 }

    // MARK: Time zone

    private var zone: WorldZone { config.zone }
    private var timeZone: TimeZone { zone.timeZone }

    /// Calendar in the widget's zone. Used for the analog hand angles, so a
    /// world clock's hands point at that city's time, not this Mac's.
    private var zoneCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private func formatter(_ configure: (DateFormatter) -> Void) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.timeZone = timeZone
        configure(formatter)
        return formatter
    }

    var body: some View {
        VStack(spacing: config.face == .analog ? 10 : 4) {
            switch config.face {
            case .digital: digital
            case .analog: analog
            }
            if config.showDate {
                Text(dateString)
                    .font(.system(size: max(9, config.digitSize * 0.24), weight: .medium, design: design))
                    .foregroundStyle(palette.textSecondary)
                    .frame(height: ClockConfig.Metrics.dateRow)
            }
            if config.showsZoneRow { zoneLabel }
        }
        .padding(ClockConfig.Metrics.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// City, live UTC offset, and a day marker when the zone is on another date.
    private var zoneLabel: some View {
        HStack(spacing: 5) {
            Text(zone.city.uppercased())
                .font(.system(size: 9.5, weight: .bold, design: design))
                .tracking(1.0)
                .foregroundStyle(accentColor)
            Text(zone.offsetLabel(at: time.second))
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(palette.textTertiary)
            if let marker = dayOffsetMarker {
                Text(marker)
                    .font(.system(size: 8.5, weight: .bold, design: design))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(accentColor.opacity(0.16)))
                    .foregroundStyle(accentColor)
            }
        }
        .frame(height: ClockConfig.Metrics.zoneRow)
    }

    private var dayOffsetMarker: String? {
        switch zone.dayDifference(at: time.second) {
        case 1: "NEXT DAY"
        case -1: "PREV DAY"
        default: nil
        }
    }

    // MARK: Digital

    private var digital: some View {
        HStack(alignment: .lastTextBaseline, spacing: config.digitSize * 0.09) {
            Text(timeString)
                .font(.system(size: config.digitSize, weight: .semibold, design: design))
                .monospacedDigit()
                .foregroundStyle(palette.textPrimary)
                .shadow(color: showGlow ? accentColor.opacity(0.35) : .clear, radius: 12)
            if !config.use24Hour {
                Text(amPmString)
                    .font(.system(size: config.digitSize * 0.28, weight: .bold, design: design))
                    .foregroundStyle(accentColor)
                    .padding(.bottom, config.digitSize * 0.09)
            }
        }
    }

    // MARK: Analog

    private var analog: some View {
        let components = zoneCalendar.dateComponents([.hour, .minute, .second], from: time.second)
        let second = Double(components.second ?? 0)
        let minute = Double(components.minute ?? 0) + second / 60
        let hour = Double((components.hour ?? 0) % 12) + minute / 60

        return ZStack {
            dialBackground
            if config.showTicks { ticks }
            if config.numerals != .none { numerals }
            hands(hour: hour, minute: minute, second: second)
        }
        .frame(width: config.dialDiameter, height: config.dialDiameter)
    }

    @ViewBuilder
    private var dialBackground: some View {
        if isClassic {
            Circle().fill(Color.white)
            Circle().stroke(Color.black.opacity(0.10), lineWidth: max(1, radius * 0.012))
        } else {
            Circle().stroke(palette.hairline, lineWidth: 1)
            Circle().fill(
                RadialGradient(colors: [accentColor.opacity(theme == .light ? 0.06 : 0.10), .clear],
                               center: .center, startRadius: 0, endRadius: radius)
            )
        }
    }

    /// Sixty ticks. On the classic dial the 5-minute marks are black and long
    /// while the minute marks between them are short and grey — that contrast is
    /// most of what makes the stock face recognisable.
    private var ticks: some View {
        ForEach(0..<60, id: \.self) { tick in
            let isMajor = tick % 5 == 0
            let length = isMajor ? radius * 0.105 : radius * 0.055
            let width = isMajor ? radius * 0.030 : radius * 0.016

            Capsule()
                .fill(tickColor(isMajor: isMajor))
                .frame(width: max(0.8, width), height: max(2, length))
                .offset(y: -(radius - radius * 0.055 - length / 2))
                .rotationEffect(.degrees(Double(tick) * 6))
        }
    }

    private func tickColor(isMajor: Bool) -> Color {
        if isClassic {
            return isMajor ? Color.black.opacity(0.88) : Color.black.opacity(0.26)
        }
        return isMajor ? accentColor.opacity(0.7) : palette.textTertiary.opacity(0.5)
    }

    /// Hour labels, upright rather than rotated with their angle.
    private var numerals: some View {
        let labelRadius = radius - radius * 0.055 - radius * 0.10 - config.numeralSize * 0.85

        return ForEach(config.numerals.hours(), id: \.self) { hour in
            let angle = Angle.degrees(Double(hour) * 30 - 90)
            Text(config.numerals.text(for: hour))
                .font(.system(size: config.numeralSize,
                              weight: isClassic ? .semibold : .semibold,
                              design: isClassic ? .default : design))
                .monospacedDigit()
                .foregroundStyle(isClassic ? Color.black.opacity(0.90) : palette.textPrimary.opacity(0.82))
                .offset(x: labelRadius * cos(angle.radians), y: labelRadius * sin(angle.radians))
        }
    }

    @ViewBuilder
    private func hands(hour: Double, minute: Double, second: Double) -> some View {
        let handColor = isClassic ? Color.black.opacity(0.92) : palette.textPrimary
        let secondColor = dialAccent

        hand(length: radius * 0.50, width: radius * 0.090, angle: hour * 30, color: handColor)
        hand(length: radius * 0.80, width: radius * 0.068,
             angle: minute * 6, color: isClassic ? handColor : handColor.opacity(0.85))

        if config.showSeconds {
            secondHand(angle: second * 6, color: secondColor)
                .shadow(color: showGlow ? accentColor.opacity(0.8) : .clear, radius: 5)
                // The shared timer fires once a second; animating between ticks
                // is what makes the hand glide rather than jump.
                .animation(config.sweepSecondHand ? .linear(duration: 1) : nil, value: second)
        }

        // Hub, drawn last so it sits over the hands.
        Circle()
            .fill(dialAccent)
            .frame(width: radius * 0.10, height: radius * 0.10)
            .shadow(color: showGlow ? accentColor.opacity(0.9) : .clear, radius: 6)
    }

    private func hand(length: CGFloat, width: CGFloat, angle: Double, color: Color) -> some View {
        Capsule()
            .fill(color)
            .frame(width: max(1.5, width), height: length)
            .offset(y: -length / 2)
            .rotationEffect(.degrees(angle))
    }

    /// Thin hand with a short counterweight past the hub, like the stock clock.
    private func secondHand(angle: Double, color: Color) -> some View {
        let length = radius * 0.86
        let tail = radius * 0.20
        return Capsule()
            .fill(color)
            .frame(width: max(1, radius * 0.018), height: length + tail)
            .offset(y: -(length - tail) / 2)
            .rotationEffect(.degrees(angle))
    }

    // MARK: Formatting

    private var timeString: String {
        let hours = config.use24Hour ? "HH" : "h"
        let pattern = config.showSeconds ? "\(hours):mm:ss" : "\(hours):mm"
        return formatter { $0.dateFormat = pattern }.string(from: time.second)
    }

    private var amPmString: String {
        formatter { $0.dateFormat = "a" }.string(from: time.second)
    }

    private var dateString: String {
        formatter { $0.setLocalizedDateFormatFromTemplate("EEEEdMMMM") }.string(from: time.second)
    }
}

// MARK: - Settings

private struct ClockSettingsView: View {
    @ObservedObject var state: AppState
    let id: UUID

    private var ctx: WidgetContext<ClockConfig> { WidgetContext(id: id, state: state) }
    /// Settings controls use the fixed blue, not the widget accent.
    private var accent: Accent { Theme.control }

    @State private var zoneQuery = ""

    var body: some View {
        VStack(spacing: 12) {
        SettingsCard(title: "Time zone", symbol: "globe", accent: accent) {
            SettingRow(label: "Show time for",
                       detail: "Duplicate this widget and pick another city for a world clock") {
                Menu {
                    Button("System (this Mac)") { setZone(nil) }
                    Divider()
                    ForEach(WorldZones.curated) { zone in
                        Button("\(zone.label)  \(zone.offsetLabel())") { setZone(zone.identifier) }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(ctx.config.zone.label)
                            .font(Theme.font(11.5, .medium))
                        Text(ctx.config.zone.offsetLabel())
                            .font(Theme.font(10, .semibold, .monospaced))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .menuStyle(.borderlessButton)
                .frame(width: 230)
            }
            if ctx.config.isWorldClock {
                SettingRow(label: "Show city and offset") {
                    Toggle("", isOn: ctx.bind(\.showZoneLabel))
                        .labelsHidden().toggleStyle(NeoToggleStyle(accent: accent))
                }
                Text("Daylight saving is applied automatically from the system time-zone database — the offset shown above is the one in effect right now.")
                    .font(Theme.font(10.5))
                    .foregroundStyle(Theme.textTertiary)
            }
        }

        SettingsCard(title: "Clock", symbol: "clock", accent: accent) {
            SettingRow(label: "Face") {
                NeoSegmented(selection: ctx.bind(\.face),
                             options: ClockFace.allCases,
                             label: { $0.label },
                             accent: accent)
                    .frame(width: 160)
            }
            SettingRow(label: "24-hour time") {
                Toggle("", isOn: ctx.bind(\.use24Hour))
                    .labelsHidden().toggleStyle(NeoToggleStyle(accent: accent))
            }
            SettingRow(label: "Seconds") {
                Toggle("", isOn: ctx.bind(\.showSeconds))
                    .labelsHidden().toggleStyle(NeoToggleStyle(accent: accent))
            }

            if ctx.config.face == .digital {
                MetricSlider(label: "Digit size", detail: "Grows the panel to match",
                             value: ctx.bind(\.digitSize), range: 24...120, accent: accent)
            } else {
                Divider().overlay(Theme.hairline)
                SettingRow(label: "Dial style",
                           detail: ctx.config.dialStyle == .classic
                               ? "White face, black hands, coloured second hand"
                               : "Follows the widget theme and accent") {
                    NeoSegmented(selection: ctx.bind(\.dialStyle),
                                 options: DialStyle.allCases,
                                 label: { $0.label },
                                 accent: accent)
                        .frame(width: 160)
                }
                MetricSlider(label: "Dial size", value: ctx.bind(\.dialDiameter),
                             range: 110...320, accent: accent)
                SettingRow(label: "Hour numbers") {
                    NeoSegmented(selection: ctx.bind(\.numerals),
                                 options: DialNumerals.allCases,
                                 label: { $0.label },
                                 accent: accent)
                        .frame(width: 250)
                }
                if ctx.config.numerals != .none {
                    MetricSlider(label: "Number size", value: ctx.bind(\.numeralSize),
                                 range: 8...30, accent: accent)
                }
                SettingRow(label: "Minute ticks") {
                    Toggle("", isOn: ctx.bind(\.showTicks))
                        .labelsHidden().toggleStyle(NeoToggleStyle(accent: accent))
                }
                SettingRow(label: "Sweeping second hand") {
                    Toggle("", isOn: ctx.bind(\.sweepSecondHand))
                        .labelsHidden().toggleStyle(NeoToggleStyle(accent: accent))
                }
                Text("The second hand and hub use the widget's accent colour — pick Orange to match the stock macOS clock.")
                    .font(Theme.font(10.5))
                    .foregroundStyle(Theme.textTertiary)
            }

            Divider().overlay(Theme.hairline)

            SettingRow(label: "Date line") {
                Toggle("", isOn: ctx.bind(\.showDate))
                    .labelsHidden().toggleStyle(NeoToggleStyle(accent: accent))
            }
            SettingRow(label: "Typeface") {
                NeoSegmented(selection: ctx.bind(\.typeStyle),
                             options: TypeStyle.allCases,
                             label: { $0.label },
                             accent: accent)
                    .frame(width: 250)
            }
        }
        }
    }

    private func setZone(_ identifier: String?) {
        var config = ctx.config
        config.timeZoneIdentifier = identifier
        state.updateConfig(id, config)
    }
}
