import SwiftUI

enum CalendarWidget: WidgetProvider {
    typealias Config = CalendarConfig

    static let kind = "calendar"
    static let displayName = "Calendar"
    static let symbolName = "calendar"
    static let blurb = "Month grid with today highlighted. Resize from compact to half-screen and beyond."
    static let minScale: Double = 0.7

    static func baseSize(for config: CalendarConfig) -> CGSize {
        let calendar = CalendarMath.calendar(weekStart: config.weekStart)
        let reference = CalendarMath.referenceMonth(anchor: Date(), offset: config.monthOffset, calendar: calendar)
        return config.size(reference: reference, calendar: calendar)
    }

    static func content(_ ctx: WidgetContext<CalendarConfig>) -> some View {
        CalendarWidgetView(
            config: ctx.config,
            theme: ctx.chrome.theme,
            accent: ctx.accent,
            showGlow: ctx.chrome.showsGlow,
            onOffsetChange: { offset in
                var config = ctx.config
                config.monthOffset = offset
                ctx.state.updateConfig(ctx.id, config)
            }
        )
    }

    static func settings(_ ctx: WidgetContext<CalendarConfig>) -> some View {
        CalendarSettingsView(state: ctx.state, id: ctx.id)
    }
}

// MARK: - Settings

private struct CalendarSettingsView: View {
    @ObservedObject var state: AppState
    let id: UUID

    @State private var showingHolidayManager = false

    private var ctx: WidgetContext<CalendarConfig> { WidgetContext(id: id, state: state) }
    /// Settings controls use the fixed blue, not the widget accent.
    private var accent: Accent { Theme.control }

    private var hiddenCount: Int { ctx.config.hiddenHolidayNames.count }

    private var customisationSummary: String {
        var parts: [String] = []
        if hiddenCount > 0 { parts.append("\(hiddenCount) hidden") }
        let added = ctx.config.customHolidays.count
        if added > 0 { parts.append("\(added) of your own") }
        return parts.joined(separator: " · ")
    }

    /// Legend for the tithi shorthand, in whichever language is selected.
    private var panchangLegend: String {
        switch ctx.config.panchangLanguage {
        case .gujarati:
            return "સુ = સુદ (વધતો ચંદ્ર), વ = વદ (ઘટતો ચંદ્ર), પૂ = પૂનમ, અ = અમાસ."
        case .devanagari, .english:
            return "S = Shukla (waxing), K = Krishna (waning), P = Purnima, A = Amavasya."
        }
    }

    var body: some View {
        content
            .sheet(isPresented: $showingHolidayManager) {
                HolidayManagerView(state: state, id: id) { showingHolidayManager = false }
            }
    }

    private var content: some View {
        VStack(spacing: 12) {
            SettingsCard(title: "Week", symbol: "calendar.day.timeline.left", accent: accent) {
                SettingRow(label: "Week starts on", detail: "First column of the grid") {
                    NeoSegmented(selection: ctx.bind(\.weekStart),
                                 options: WeekStart.allCases,
                                 label: { $0.label },
                                 accent: accent)
                        .frame(width: 210)
                }
                SettingRow(label: "Weekday labels") {
                    NeoSegmented(selection: ctx.bind(\.weekdayLabels),
                                 options: WeekdayLabelStyle.allCases,
                                 label: { $0.label },
                                 accent: accent)
                        .frame(width: 150)
                }
                SettingRow(label: "Tint weekends", detail: "Saturday and Sunday in the accent colour") {
                    Toggle("", isOn: ctx.bind(\.highlightWeekends))
                        .labelsHidden()
                        .toggleStyle(NeoToggleStyle(accent: accent))
                }
                SettingRow(label: "Week numbers", detail: "Adds an ISO week column") {
                    Toggle("", isOn: ctx.bind(\.showWeekNumbers))
                        .labelsHidden()
                        .toggleStyle(NeoToggleStyle(accent: accent))
                }
            }

            SettingsCard(title: "Today", symbol: "sparkles", accent: accent) {
                SettingRow(label: "Highlight style") {
                    NeoSegmented(selection: ctx.bind(\.todayStyle),
                                 options: TodayStyle.allCases,
                                 label: { $0.label },
                                 accent: accent)
                        .frame(width: 220)
                }
                if ctx.config.todayStyle == .glow || ctx.config.todayStyle == .fill {
                    SettingRow(label: "Marker shape") {
                        NeoSegmented(selection: ctx.bind(\.todayShape),
                                     options: TodayShape.allCases,
                                     label: { $0.label },
                                     accent: accent)
                            .frame(width: 150)
                    }
                }
                SettingRow(label: "Mark today in the heading",
                           detail: "Highlights the current weekday column") {
                    Toggle("", isOn: ctx.bind(\.highlightTodayColumn))
                        .labelsHidden()
                        .toggleStyle(NeoToggleStyle(accent: accent))
                }
                SettingRow(label: "Full date footer", detail: "\"Friday, 14 August 2026\" under the grid") {
                    Toggle("", isOn: ctx.bind(\.showTodayLine))
                        .labelsHidden()
                        .toggleStyle(NeoToggleStyle(accent: accent))
                }
            }

            SettingsCard(title: "Type sizes", symbol: "textformat.size", accent: accent) {
                MetricSlider(label: "Date numbers", detail: "1, 2, 3 — rows grow to fit",
                             value: ctx.bind(\.dayNumberSize), range: 10...34,
                             decimals: 1, accent: accent)
                if ctx.config.hasSecondaryRow {
                    MetricSlider(label: "Tithi & indicators",
                                 value: ctx.bind(\.secondaryTextSize), range: 6...16,
                                 decimals: 1, accent: accent)
                }
                if ctx.config.showTodayLine {
                    MetricSlider(label: "Bottom date line",
                                 value: ctx.bind(\.footerTextSize), range: 8...22,
                                 decimals: 1, accent: accent)
                }
                MetricSlider(label: "Hover tooltip", detail: "Scales the card that appears on hover",
                             value: ctx.bind(\.tooltipScale), range: 0.7...2.2,
                             unit: "×", decimals: 2, accent: accent)
                Text("These are sizes at 1×; the widget's own size slider multiplies them.")
                    .font(Theme.font(10.5))
                    .foregroundStyle(Theme.textTertiary)
            }

            SettingsCard(title: "Holidays", symbol: "flag", accent: accent) {
                SettingRow(label: "Regions", detail: "Dates are computed, so any year works") {
                    HStack(spacing: 5) {
                        ForEach(HolidayRegion.selectable) { region in
                            let isOn = ctx.config.holidayRegions.contains(region)
                            Button(region.label) {
                                var config = ctx.config
                                if isOn { config.holidayRegions.remove(region) }
                                else { config.holidayRegions.insert(region) }
                                state.updateConfig(id, config)
                            }
                            .buttonStyle(ChipButtonStyle(accent: accent, isOn: isOn))
                        }
                    }
                }
                if !ctx.config.holidayRegions.isEmpty {
                    SettingRow(label: "Holiday colour",
                               detail: "Wins over the weekend tint when both apply") {
                        AccentPicker(accent: ctx.bind(\.holidayAccent))
                    }
                    SettingRow(label: "Dot under holidays") {
                        Toggle("", isOn: ctx.bind(\.showHolidayDots))
                            .labelsHidden().toggleStyle(NeoToggleStyle(accent: accent))
                    }
                    SettingRow(label: "Minor observances",
                               detail: "Dhanteras, Navratri, Bhai Dooj and similar") {
                        Toggle("", isOn: ctx.bind(\.includeMinorObservances))
                            .labelsHidden().toggleStyle(NeoToggleStyle(accent: accent))
                    }
                }
                HStack {
                    Text("Hover any date for an instant tooltip with its holiday, moon phase and tithi.")
                        .font(Theme.font(10.5))
                        .foregroundStyle(Theme.textTertiary)
                    Spacer(minLength: 8)
                    Button("Choose holidays…") { showingHolidayManager = true }
                        .buttonStyle(ChipButtonStyle(accent: accent, isOn: true))
                }
                if hiddenCount > 0 || !ctx.config.customHolidays.isEmpty {
                    Text(customisationSummary)
                        .font(Theme.font(10.5, .medium))
                        .foregroundStyle(accent.color())
                }
            }

            SettingsCard(title: "Moon & panchang", symbol: "moon.stars", accent: accent) {
                SettingRow(label: "Moon phases", detail: "Marks new and full moon days") {
                    Toggle("", isOn: ctx.bind(\.showMoonPhases))
                        .labelsHidden().toggleStyle(NeoToggleStyle(accent: accent))
                }
                if ctx.config.showMoonPhases {
                    SettingRow(label: "Include quarters") {
                        Toggle("", isOn: ctx.bind(\.showAllMoonQuarters))
                            .labelsHidden().toggleStyle(NeoToggleStyle(accent: accent))
                    }
                }
                SettingRow(label: "Hindu calendar",
                           detail: "Tithi under each date, smaller than the Gregorian day") {
                    Toggle("", isOn: ctx.bind(\.showHinduCalendar))
                        .labelsHidden().toggleStyle(NeoToggleStyle(accent: accent))
                }
                if ctx.config.showHinduCalendar {
                    SettingRow(label: "Language") {
                        NeoSegmented(selection: ctx.bind(\.panchangLanguage),
                                     options: PanchangLanguage.allCases,
                                     label: { $0.label },
                                     accent: accent)
                            .frame(width: 230)
                    }
                    Text(panchangLegend)
                        .font(Theme.font(10.5))
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            SettingsCard(title: "Grid", symbol: "square.grid.3x3", accent: accent) {
                SettingRow(label: "Month header") {
                    Toggle("", isOn: ctx.bind(\.showHeader))
                        .labelsHidden()
                        .toggleStyle(NeoToggleStyle(accent: accent))
                }
                SettingRow(label: "Month navigation", detail: "Arrows to browse other months") {
                    Toggle("", isOn: ctx.bind(\.showMonthNavigation))
                        .labelsHidden()
                        .toggleStyle(NeoToggleStyle(accent: accent))
                }
                SettingRow(label: "Show year") {
                    Toggle("", isOn: ctx.bind(\.showYear))
                        .labelsHidden()
                        .toggleStyle(NeoToggleStyle(accent: accent))
                }
                SettingRow(label: "Days from other months") {
                    Toggle("", isOn: ctx.bind(\.showAdjacentMonths))
                        .labelsHidden()
                        .toggleStyle(NeoToggleStyle(accent: accent))
                }
                SettingRow(label: "Weekend separators",
                           detail: "Vertical rules after Sunday and before Saturday") {
                    Toggle("", isOn: ctx.bind(\.showWeekendSeparators))
                        .labelsHidden()
                        .toggleStyle(NeoToggleStyle(accent: accent))
                }
                SettingRow(label: "Row separators") {
                    Toggle("", isOn: ctx.bind(\.showGridLines))
                        .labelsHidden()
                        .toggleStyle(NeoToggleStyle(accent: accent))
                }
                SettingRow(label: "Always six rows", detail: "Keeps the widget the same size every month") {
                    Toggle("", isOn: ctx.bind(\.fixedSixWeeks))
                        .labelsHidden()
                        .toggleStyle(NeoToggleStyle(accent: accent))
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
}
