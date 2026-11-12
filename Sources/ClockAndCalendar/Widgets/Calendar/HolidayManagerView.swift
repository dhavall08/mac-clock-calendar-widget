import SwiftUI

/// Pick which holidays appear, and add your own.
///
/// The built-in list is whatever the rules produce for the displayed year, so it
/// always reflects what the calendar would actually draw — including festivals
/// whose dates move.
struct HolidayManagerView: View {
    @ObservedObject var state: AppState
    let id: UUID
    let onClose: () -> Void

    @ViewState private var draft = CustomHoliday()
    @ViewState private var year: Int = Calendar(identifier: .gregorian).component(.year, from: Date())

    private var ctx: WidgetContext<CalendarConfig> { WidgetContext(id: id, state: state) }
    private var config: CalendarConfig { ctx.config }
    private var accent: Accent { Theme.control }

    private var calendar: Calendar { CalendarMath.calendar(weekStart: config.weekStart) }

    /// Built-in holidays for `year`, restricted to the regions in use.
    private var catalogue: [(region: HolidayRegion, name: String, isPublic: Bool)] {
        CalendarDataStore.shared
            .catalogue(year: year, calendar: calendar)
            .filter { config.holidayRegions.contains($0.region) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.hairline)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    builtInCard
                    customCard
                }
                .padding(16)
            }
            Divider().overlay(Theme.hairline)
            footer
        }
        .frame(width: 520, height: 560)
        .background(Theme.surface)
        .preferredColorScheme(.dark)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 14))
                .foregroundStyle(accent.color())
            VStack(alignment: .leading, spacing: 1) {
                Text("Choose holidays")
                    .font(Theme.font(14, .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Uncheck anything you don't want to see, or add your own dates.")
                    .font(Theme.font(10.5))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            HStack(spacing: 4) {
                Button { year -= 1 } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(ChipButtonStyle(accent: accent))
                Text(verbatim: String(year))
                    .font(Theme.font(11.5, .semibold, .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                Button { year += 1 } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(ChipButtonStyle(accent: accent))
            }
        }
        .padding(16)
    }

    // MARK: Built-in list

    private var builtInCard: some View {
        SettingsCard(title: "Built-in", symbol: "list.bullet", accent: accent) {
            if config.holidayRegions.isEmpty {
                Text("No regions are switched on. Enable India, USA or UK first.")
                    .font(Theme.font(11))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                ForEach(HolidayRegion.selectable.filter { config.holidayRegions.contains($0) }) { region in
                    let entries = catalogue.filter { $0.region == region }
                    if !entries.isEmpty {
                        Text(region.label.uppercased())
                            .font(Theme.font(9.5, .bold))
                            .tracking(1.2)
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.top, 4)
                        ForEach(entries, id: \.name) { entry in
                            holidayRow(name: entry.name, isPublic: entry.isPublic)
                        }
                    }
                }
            }
        }
    }

    private func holidayRow(name: String, isPublic: Bool) -> some View {
        let isHidden = config.hiddenHolidayNames.contains(name)
        return Button {
            var next = config
            if isHidden { next.hiddenHolidayNames.remove(name) }
            else { next.hiddenHolidayNames.insert(name) }
            state.updateConfig(id, next)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isHidden ? "square" : "checkmark.square.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(isHidden ? Theme.textTertiary : accent.color())
                Text(name)
                    .font(Theme.font(11.5))
                    .foregroundStyle(isHidden ? Theme.textTertiary : Theme.textPrimary)
                    .strikethrough(isHidden, color: Theme.textTertiary)
                if !isPublic {
                    Text("minor")
                        .font(Theme.font(8.5, .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Custom holidays

    private var customCard: some View {
        SettingsCard(title: "Your own dates", symbol: "star", accent: accent) {
            ForEach(config.customHolidays) { entry in
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(config.holidayAccent.color())
                    Text(entry.name.isEmpty ? "Untitled" : entry.name)
                        .font(Theme.font(11.5))
                        .foregroundStyle(Theme.textPrimary)
                    Text(dateLabel(entry))
                        .font(Theme.font(10, .medium, .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                    Spacer(minLength: 0)
                    Button("Remove") {
                        var next = config
                        next.customHolidays.removeAll { $0.id == entry.id }
                        state.updateConfig(id, next)
                    }
                    .buttonStyle(ChipButtonStyle(accent: .rose))
                }
            }

            Divider().overlay(Theme.hairline)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Name", text: $draft.name)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                    Picker("", selection: $draft.month) {
                        ForEach(1...12, id: \.self) { month in
                            Text(monthName(month)).tag(month)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 90)
                    Picker("", selection: $draft.day) {
                        ForEach(1...daysInMonth(draft.month), id: \.self) { day in
                            Text(String(day)).tag(day)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 62)
                }
                HStack(spacing: 8) {
                    Toggle("", isOn: $draft.repeatsYearly)
                        .labelsHidden()
                        .toggleStyle(NeoToggleStyle(accent: accent))
                    Text(draft.repeatsYearly ? "Every year" : "Only \(String(draft.year))")
                        .font(Theme.font(11))
                        .foregroundStyle(Theme.textSecondary)
                    if !draft.repeatsYearly {
                        Stepper(value: $draft.year, in: 1900...2200) { EmptyView() }
                            .labelsHidden()
                    }
                    Spacer()
                    Button("Add") { addDraft() }
                        .buttonStyle(ChipButtonStyle(accent: accent, isOn: !draft.name.isEmpty))
                        .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addDraft() {
        var next = config
        var entry = draft
        entry.id = UUID()
        entry.name = entry.name.trimmingCharacters(in: .whitespaces)
        guard !entry.name.isEmpty else { return }
        // Clamp in case the month changed after the day was picked.
        entry.day = min(entry.day, daysInMonth(entry.month))
        next.customHolidays.append(entry)
        state.updateConfig(id, next)
        draft = CustomHoliday()
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Button("Show all built-in") {
                var next = config
                next.hiddenHolidayNames.removeAll()
                state.updateConfig(id, next)
            }
            .buttonStyle(ChipButtonStyle(accent: .amber))
            Spacer()
            Button("Done", action: onClose)
                .buttonStyle(ChipButtonStyle(accent: accent, isOn: true))
        }
        .padding(16)
    }

    // MARK: Helpers

    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        return formatter.shortMonthSymbols?[month - 1] ?? String(month)
    }

    private func daysInMonth(_ month: Int) -> Int {
        var components = DateComponents()
        components.year = 2024   // a leap year, so 29 February stays selectable
        components.month = month
        guard let date = Calendar(identifier: .gregorian).date(from: components),
              let range = Calendar(identifier: .gregorian).range(of: .day, in: .month, for: date)
        else { return 31 }
        return range.count
    }

    private func dateLabel(_ entry: CustomHoliday) -> String {
        let day = String(format: "%d %@", entry.day, monthName(entry.month))
        return entry.repeatsYearly ? "\(day) · yearly" : "\(day) \(entry.year)"
    }
}
