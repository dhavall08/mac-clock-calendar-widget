import SwiftUI

/// The calendar face. Laid out at fixed metrics (see `CalendarConfig.Metrics`)
/// and scaled as a whole by `WidgetShell`, so every size looks identical.
struct CalendarWidgetView: View {
    let config: CalendarConfig
    let theme: WidgetTheme
    let accent: Accent
    let showGlow: Bool
    let onOffsetChange: (Int) -> Void
    /// Pre-set hover cell, used only by `--render-preview` so the hover
    /// highlight and tooltip can be inspected offscreen.
    var previewHover: (row: Int, column: Int)? = nil

    @ObservedObject private var time = TimeKeeper.shared
    /// Grid position of the cell under the pointer, for the hover highlight and
    /// the tooltip anchor.
    @State private var hover: HoverTarget?

    private struct HoverTarget: Equatable {
        let row: Int
        let column: Int
        let dayKey: Int
    }

    private typealias M = CalendarConfig.Metrics

    private var palette: Palette { Palette.of(theme) }
    private var accentColor: Color { accent.color(theme) }
    private var holidayColor: Color { config.holidayAccent.color(theme) }
    private var language: PanchangLanguage { config.panchangLanguage }

    private var calendar: Calendar { CalendarMath.calendar(weekStart: config.weekStart) }

    private var reference: Date {
        CalendarMath.referenceMonth(anchor: time.today, offset: config.monthOffset, calendar: calendar)
    }

    private var weeks: [[DayCell]] {
        CalendarMath.weeks(
            for: reference,
            today: time.today,
            rows: config.rowCount(reference: reference, calendar: calendar),
            calendar: calendar
        )
    }

    /// Column index of today's weekday, or nil when the displayed month isn't
    /// the current one.
    private var todayColumn: Int? {
        guard config.monthOffset == 0 else { return nil }
        let weekday = calendar.component(.weekday, from: time.today)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var design: Font.Design { .from(config.typeStyle) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if config.showHeader { header }
            VStack(spacing: 0) {
                weekdayHeader
                Spacer().frame(height: M.gridTopGap)
                grid
            }
            // Weekend rules span the weekday header and the grid together.
            .overlay(alignment: .topLeading) { weekendSeparators }
            if config.showTodayLine { footer }
        }
        // Outermost, so the card draws after the footer. Attached to the grid it
        // ended up *under* the footer, which is a later sibling; and attached to
        // the header/grid wrapper its origin shifted up by the weekday row and it
        // covered the very day it describes.
        .overlay(alignment: .topLeading) { tooltipLayer }
        .padding(M.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            guard let previewHover else { return }
            let rows = weeks
            guard previewHover.row < rows.count,
                  previewHover.column < rows[previewHover.row].count else { return }
            let day = rows[previewHover.row][previewHover.column]
            hover = HoverTarget(row: previewHover.row, column: previewHover.column,
                                dayKey: HolidayYear.dayKey(day.date, calendar: calendar))
        }
    }

    // MARK: Day data

    private func info(_ day: DayCell) -> DayInfo {
        CalendarDataStore.shared.info(for: day.date, calendar: calendar)
    }

    private func holidays(_ day: DayCell) -> [Holiday] {
        config.visibleHolidays(from: info(day), on: day.date, calendar: calendar)
    }

    private func moonEvent(_ day: DayCell) -> Astronomy.MoonEvent? {
        guard config.showMoonPhases, let event = info(day).moonEvent else { return nil }
        if config.showAllMoonQuarters { return event }
        return (event == .newMoon || event == .fullMoon) ? event : nil
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(CalendarMath.monthTitle(reference, includeYear: false, calendar: calendar))
                        .font(.system(size: 19, weight: .semibold, design: design))
                        .foregroundStyle(palette.textPrimary)
                    if let lunar = lunarMonthLabel {
                        Text("(\(lunar))")
                            .font(.system(size: 12, weight: .medium, design: design))
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(1)
                    }
                }
                if config.showYear {
                    Text(verbatim: String(calendar.component(.year, from: reference)))
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(accentColor.opacity(0.85))
                }
            }

            Spacer(minLength: 0)

            if config.showMonthNavigation {
                HStack(spacing: 4) {
                    if config.monthOffset != 0 {
                        Button { onOffsetChange(0) } label: {
                            Text("Today")
                                .font(.system(size: 9.5, weight: .bold, design: design))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(accentColor.opacity(0.18)))
                                .foregroundStyle(accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    navButton("chevron.left") { onOffsetChange(config.monthOffset - 1) }
                    navButton("chevron.right") { onOffsetChange(config.monthOffset + 1) }
                }
            }
        }
        .frame(height: M.header, alignment: .center)
    }

    private func navButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .frame(width: 20, height: 20)
                .foregroundStyle(palette.textSecondary)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(palette.controlFill)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Weekday row

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            if config.showWeekNumbers {
                Text("WK")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.textTertiary)
                    .frame(width: M.weekNumberColumn, alignment: .center)
            }
            ForEach(Array(CalendarMath.weekdaySymbols(style: config.weekdayLabels, calendar: calendar).enumerated()),
                    id: \.offset) { index, symbol in
                weekdayLabel(symbol, column: index)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.hairline)
                .frame(height: 1)
        }
    }

    private func weekdayLabel(_ symbol: String, column: Int) -> some View {
        let isToday = config.highlightTodayColumn && todayColumn == column
        let isWeekend = config.highlightWeekends
            && CalendarMath.isWeekendDay(CalendarMath.weekday(forColumn: column, calendar: calendar))

        return Text(symbol.uppercased())
            .font(.system(size: config.weekdayLabels == .initial ? 10.5 : 9.5,
                          weight: isToday ? .heavy : .bold, design: design))
            .tracking(0.7)
            .foregroundStyle(isToday ? accent.onAccent(theme)
                             : (isWeekend ? accentColor.opacity(0.75) : palette.textTertiary))
            .frame(width: config.cellWidth, height: M.weekdayRow)
            .background {
                if isToday {
                    Capsule(style: .continuous)
                        .fill(accentColor)
                        .frame(height: M.weekdayRow - 6)
                        .shadow(color: showGlow ? accentColor.opacity(0.6) : .clear, radius: 6)
                }
            }
    }

    // MARK: Weekend separators

    /// Vertical rules wherever a weekend column meets a weekday column.
    ///
    /// Derived from the rotated week rather than hardcoded to columns 1 and 6, so
    /// a Monday or Saturday week start still brackets Sat/Sun correctly.
    private var weekendSeparatorOffsets: [CGFloat] {
        guard config.showWeekendSeparators else { return [] }
        let leadingInset = config.showWeekNumbers ? M.weekNumberColumn : 0
        return (1..<config.columnCount).compactMap { boundary in
            let left = CalendarMath.isWeekendDay(
                CalendarMath.weekday(forColumn: boundary - 1, calendar: calendar))
            let right = CalendarMath.isWeekendDay(
                CalendarMath.weekday(forColumn: boundary, calendar: calendar))
            guard left != right else { return nil }
            return leadingInset + CGFloat(boundary) * config.cellWidth
        }
    }

    @ViewBuilder
    private var weekendSeparators: some View {
        let height = M.weekdayRow + M.gridTopGap + CGFloat(weeks.count) * config.cellHeight
        ForEach(Array(weekendSeparatorOffsets.enumerated()), id: \.offset) { _, x in
            Rectangle()
                .fill(palette.hairline)
                .frame(width: 1, height: height)
                .offset(x: x)
                .allowsHitTesting(false)
        }
    }

    /// Hindu month(s) spanning the displayed Gregorian month, for the header.
    /// A Gregorian month usually straddles two lunar months, so both are shown.
    private var lunarMonthLabel: String? {
        guard config.showHinduCalendar else { return nil }
        guard let lastDay = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: reference),
              let first = CalendarDataStore.shared.info(for: reference, calendar: calendar).panchang
        else { return nil }
        let firstName = first.monthName(language)
        guard let last = CalendarDataStore.shared.info(for: lastDay, calendar: calendar).panchang,
              last.monthIndex != first.monthIndex
        else { return firstName }
        return "\(firstName)–\(last.monthName(language))"
    }

    // MARK: Grid

    private var grid: some View {
        let rows = weeks
        let numbers = CalendarMath.weekNumbers(for: rows, calendar: calendar)

        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, week in
                HStack(spacing: 0) {
                    if config.showWeekNumbers {
                        Text(rowIndex < numbers.count ? "\(numbers[rowIndex])" : "")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(palette.textTertiary)
                            .frame(width: M.weekNumberColumn, height: config.cellHeight)
                    }
                    ForEach(Array(week.enumerated()), id: \.element.id) { columnIndex, day in
                        dayView(day, row: rowIndex, column: columnIndex)
                    }
                }
                .background(alignment: .bottom) {
                    if config.showGridLines && rowIndex < rows.count - 1 {
                        Rectangle().fill(palette.grid).frame(height: 1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayView(_ day: DayCell, row: Int, column: Int) -> some View {
        let hidden = !day.isInDisplayedMonth && !config.showAdjacentMonths
        let target = HoverTarget(row: row, column: column,
                                 dayKey: HolidayYear.dayKey(day.date, calendar: calendar))

        VStack(spacing: 0) {
            ZStack {
                if day.isToday { todayDecoration }
                Text("\(day.dayNumber)")
                    .font(.system(size: config.dayNumberSize,
                                  weight: day.isToday ? .bold : (day.isInDisplayedMonth ? .medium : .regular),
                                  design: design))
                    .monospacedDigit()
                    .foregroundStyle(numberColor(day))
            }
            .frame(height: config.numberRowHeight)
            .overlay(alignment: .bottom) {
                if day.isToday && config.todayStyle == .underline {
                    Capsule()
                        .fill(accentColor)
                        .frame(width: 16, height: 2.5)
                        .offset(y: -2)
                        .shadow(color: showGlow ? accentColor.opacity(0.9) : .clear, radius: 4)
                }
            }

            if config.hasSecondaryRow {
                secondaryRow(day)
                    .frame(height: config.secondaryRowHeight)
            }

            // Keeps the indicators clear of the row separator below.
            Spacer(minLength: 0).frame(height: M.cellBottomGap)
        }
        .opacity(hidden ? 0 : 1)
        // The frame has to come before the background: the VStack is only as wide
        // as its widest child, so a background attached earlier drew a narrow
        // sliver instead of a highlight around the whole cell.
        .frame(width: config.cellWidth, height: config.cellHeight)
        .background {
            if hover == target && !hidden {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(palette.textPrimary.opacity(0.08))
                    .padding(.horizontal, M.hoverInsetX)
                    .padding(.vertical, M.hoverInsetY)
            }
        }
        .contentShape(Rectangle())
        .onHover { inside in
            if inside { hover = target } else if hover == target { hover = nil }
        }
    }

    /// Tithi, moon phase and holiday dot.
    private func secondaryRow(_ day: DayCell) -> some View {
        let holidayList = holidays(day)
        let event = moonEvent(day)

        return HStack(spacing: 2.5) {
            if config.showHinduCalendar, let panchang = info(day).panchang {
                Text(panchang.shortLabel(language))
                    .font(.system(size: config.secondaryTextSize, weight: .semibold, design: design))
                    .foregroundStyle(palette.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if let event {
                MoonGlyph(event: event, size: max(6, config.secondaryTextSize * 0.9), color: palette.textSecondary.opacity(0.85))
            }
            if config.showHolidayDots && !holidayList.isEmpty {
                Circle()
                    .fill(holidayColor)
                    .frame(width: max(3, config.secondaryTextSize * 0.5),
                           height: max(3, config.secondaryTextSize * 0.5))
            }
        }
    }

    // MARK: Tooltip

    /// Floating card anchored to the hovered cell.
    ///
    /// Positioned arithmetically from the row/column index — the grid is
    /// fixed-metric, so there's no need for a GeometryReader, and the result is
    /// exact at any scale.
    @ViewBuilder
    private var tooltipLayer: some View {
        if let hover, let cell = cell(at: hover), let content = tooltipContent(cell) {
            let size = DayTooltip.size(for: content, scale: config.tooltipScale)
            let position = tooltipOrigin(for: hover, height: size.height)

            DayTooltip(content: content, palette: palette, holidayColor: holidayColor,
                       design: design, scale: config.tooltipScale)
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                // Offsets, not alignment guides: a guide override on both axes of
                // a `.topLeading` overlay silently did nothing here, and offsets
                // are exact and easy to reason about.
                .offset(x: position.x, y: position.y)
                .allowsHitTesting(false)
        }
    }

    /// Clearance between the hovered cell and the card, so the day it describes
    /// stays fully readable.
    private static let tooltipGap: CGFloat = 6

    /// Distance from the top of the widget's content to the top of the week grid.
    private var gridOriginY: CGFloat {
        (config.showHeader ? M.header : 0) + M.weekdayRow + M.gridTopGap
    }

    /// Top-left of the tooltip in the widget's content space, centred on the
    /// hovered cell and clamped so it can't hang off either side.
    private func tooltipOrigin(for hover: HoverTarget, height: CGFloat) -> CGPoint {
        let leadingInset = config.showWeekNumbers ? M.weekNumberColumn : 0
        let gridWidth = leadingInset + CGFloat(config.columnCount) * config.cellWidth
        let width = DayTooltip.width * config.tooltipScale

        let cellCentre = leadingInset + (CGFloat(hover.column) + 0.5) * config.cellWidth
        let x = min(max(cellCentre - width / 2, 0), max(gridWidth - width, 0))

        let cellTop = CGFloat(hover.row) * config.cellHeight
        let below = cellTop + config.cellHeight + Self.tooltipGap
        let above = cellTop - height - Self.tooltipGap

        // Below is the default, so the card never sits on the day it describes.
        // Flip up only for the bottom row, where there is no room left inside the
        // glass panel: the footer band plus the widget's own padding, less a
        // hair so the card can't touch the panel edge.
        let gridHeight = CGFloat(weeks.count) * config.cellHeight
        let roomBelowGrid = (config.showTodayLine ? config.footerRowHeight : 0)
            + M.padding - 4
        let fitsBelow = below + height <= gridHeight + roomBelowGrid

        let y = (fitsBelow || above < 0) ? below : above
        return CGPoint(x: x, y: y + gridOriginY)
    }

    private func cell(at target: HoverTarget) -> DayCell? {
        weeks.flatMap { $0 }.first {
            HolidayYear.dayKey($0.date, calendar: calendar) == target.dayKey
        }
    }

    /// Holiday names first, then a gap, then the date and sky/panchang detail.
    private func tooltipContent(_ day: DayCell) -> DayTooltip.Content? {
        let names = holidays(day).map(\.name)
        var detail: [String] = [CalendarMath.fullDateLine(day.date, calendar: calendar)]
        if let event = moonEvent(day) { detail.append(event.label) }
        if config.showHinduCalendar, let panchang = info(day).panchang {
            detail.append(panchang.fullLabel(language))
        }
        // Nothing beyond the bare date isn't worth a tooltip.
        guard !names.isEmpty || detail.count > 1 else { return nil }
        return DayTooltip.Content(holidays: names, detail: detail)
    }

    /// Circle or rounded square, per `config.todayShape`.
    @ViewBuilder
    private func markerShape<S: ShapeStyle>(_ style: S, size: CGFloat) -> some View {
        switch config.todayShape {
        case .circle:
            Circle().fill(style).frame(width: size, height: size)
        case .roundedSquare:
            RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
                .fill(style).frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private var todayDecoration: some View {
        switch config.todayStyle {
        case .glow:
            markerShape(accentColor, size: config.todayMarkerSize)
                .shadow(color: showGlow ? accentColor.opacity(0.75) : .clear, radius: 10)
        case .fill:
            markerShape(accentColor, size: config.todayMarkerSize)
        case .ring:
            Circle()
                .stroke(accentColor, lineWidth: 1.8)
                .frame(width: config.todayMarkerSize - 1, height: config.todayMarkerSize - 1)
                .shadow(color: showGlow ? accentColor.opacity(0.6) : .clear, radius: 6)
        case .underline:
            EmptyView()
        }
    }

    /// Colour precedence: today first, then holidays, then weekends. A holiday
    /// falling on a weekend reads as a holiday.
    private func numberColor(_ day: DayCell) -> Color {
        if day.isToday {
            switch config.todayStyle {
            case .glow, .fill: return accent.onAccent(theme)
            case .ring, .underline: return accentColor
            }
        }
        let isHoliday = !holidays(day).isEmpty
        if !day.isInDisplayedMonth {
            return (isHoliday ? holidayColor : palette.textTertiary).opacity(0.55)
        }
        if isHoliday { return holidayColor }
        if day.isWeekend && config.highlightWeekends { return accentColor.opacity(0.9) }
        return palette.textPrimary.opacity(0.88)
    }

    // MARK: Footer

    /// Shows the hovered day's holidays and panchang, falling back to today.
    private var footer: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(footerIsHoliday ? holidayColor : accentColor)
                .frame(width: 5, height: 5)
                .shadow(color: showGlow ? accentColor : .clear, radius: 4)
            Text(footerText)
                .font(.system(size: config.footerTextSize, weight: .medium, design: design))
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .frame(height: config.footerRowHeight, alignment: .center)
    }

    private var hoveredCell: DayCell? {
        hover.flatMap(cell(at:))
    }

    private var footerIsHoliday: Bool {
        guard let cell = hoveredCell else { return false }
        return !holidays(cell).isEmpty
    }

    private var footerText: String {
        guard let cell = hoveredCell else {
            return CalendarMath.fullDateLine(time.today, calendar: calendar)
        }
        var parts: [String] = []
        let holidayNames = holidays(cell).map(\.name)
        if !holidayNames.isEmpty { parts.append(holidayNames.joined(separator: " · ")) }
        if let event = moonEvent(cell) { parts.append(event.label) }
        if config.showHinduCalendar, let panchang = info(cell).panchang {
            parts.append(panchang.fullLabel(language))
        }
        if parts.isEmpty {
            return CalendarMath.fullDateLine(cell.date, calendar: calendar)
        }
        let day = CalendarMath.dayMonthLine(cell.date, calendar: calendar)
        return "\(day) — \(parts.joined(separator: " · "))"
    }
}

// MARK: - Tooltip card

/// Holiday names on top in the holiday colour, then a gap, then the quieter
/// date / moon / panchang lines.
struct DayTooltip: View {
    struct Content: Equatable {
        var holidays: [String]
        var detail: [String]
    }

    /// Base width at scale 1.0, so the caller can place the card without
    /// measuring it. Multiply by `scale` for the rendered width.
    static let width: CGFloat = 196
    private static let holidayLine: CGFloat = 14
    private static let detailLine: CGFloat = 13
    private static let gap: CGFloat = 6
    private static let verticalPadding: CGFloat = 12
    private static let holidayFont: CGFloat = 10.5
    private static let detailFont: CGFloat = 9.5

    /// Exact rendered size. Every line is limited to one, so this can't drift.
    static func size(for content: Content, scale: Double = 1) -> CGSize {
        var height = verticalPadding
        height += CGFloat(content.holidays.count) * holidayLine
        if !content.holidays.isEmpty { height += gap }
        height += CGFloat(content.detail.count) * detailLine
        return CGSize(width: width * scale, height: height * scale)
    }

    let content: Content
    let palette: Palette
    let holidayColor: Color
    let design: Font.Design
    var scale: Double = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !content.holidays.isEmpty {
                ForEach(content.holidays, id: \.self) { name in
                    Text(name)
                        .font(.system(size: Self.holidayFont * scale, weight: .bold, design: design))
                        .foregroundStyle(holidayColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(height: Self.holidayLine * scale, alignment: .leading)
                }
                // The requested breathing room between the holiday and the rest.
                Spacer(minLength: 0).frame(height: Self.gap * scale)
            }
            ForEach(content.detail, id: \.self) { line in
                Text(line)
                    .font(.system(size: Self.detailFont * scale, weight: .medium, design: design))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(height: Self.detailLine * scale, alignment: .leading)
            }
        }
        .frame(width: (Self.width - 16) * scale, alignment: .leading)
        .padding(.horizontal, 8 * scale)
        .padding(.vertical, Self.verticalPadding / 2 * scale)
        .background(
            RoundedRectangle(cornerRadius: 8 * scale, style: .continuous)
                .fill(palette.isLight ? Color.white : Color(red: 0.11, green: 0.12, blue: 0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(palette.isLight ? Color.black.opacity(0.12) : Color.white.opacity(0.14),
                                lineWidth: 1)
                )
                .shadow(color: .black.opacity(palette.isLight ? 0.16 : 0.45), radius: 8, y: 3)
        )
    }
}
