import AppKit
import SwiftUI

/// Renders widget faces to a PNG without opening any windows.
///
///     Clock\ and\ Calendar\ by\ Dhaval.app/Contents/MacOS/ClockAndCalendar \
///       --render-preview out.png
///
/// Useful for checking a design change without dragging panels around.
@MainActor
enum PreviewRenderer {

    private struct Variant {
        var caption: String
        var theme: WidgetTheme = .dark
        var accent: Accent = .cyan
        var scale: Double = 1.0
        var config: CalendarConfig = .defaults
        var hover: (row: Int, column: Int)? = nil
    }

    private struct ClockVariant {
        var caption: String
        var theme: WidgetTheme = .dark
        var accent: Accent = .cyan
        var config: ClockConfig = .defaults
    }

    static func render(to path: String) -> Bool {
        let calendars: [Variant] = [
            Variant(caption: "row 0 — below", hover: (0, 3)),
            Variant(caption: "separators · 20pt dates · tooltip 1.3x", config: {
                var c = CalendarConfig.defaults
                c.showWeekendSeparators = true
                c.dayNumberSize = 20
                c.footerTextSize = 13
                c.tooltipScale = 1.3
                return c
            }(), hover: (2, 6)),
            Variant(caption: "light · separators · row 4 below", theme: .light, accent: .violet, config: {
                var c = CalendarConfig.defaults
                c.showWeekendSeparators = true
                return c
            }(), hover: (4, 5)),
            Variant(caption: "row 5 — no room, flips above", theme: .light, accent: .teal, hover: (5, 5))
        ]

        let clocks: [ClockVariant] = [
            ClockVariant(caption: "dark digital", accent: .mint),
            ClockVariant(caption: "light digital · solid", theme: .light, accent: .rose),
            ClockVariant(caption: "CLASSIC dial · orange", theme: .light, accent: .orange, config: {
                var c = ClockConfig.defaults
                c.face = .analog
                c.dialStyle = .classic
                c.numerals = .all
                c.showDate = false
                return c
            }()),
            ClockVariant(caption: "world clock · London", accent: .blue, config: {
                var c = ClockConfig.defaults
                c.face = .digital
                c.timeZoneIdentifier = "Europe/London"
                c.digitSize = 38
                return c
            }()),
            ClockVariant(caption: "world clock · Tokyo (next day)", theme: .light, accent: .crimson, config: {
                var c = ClockConfig.defaults
                c.face = .digital
                c.timeZoneIdentifier = "Asia/Tokyo"
                c.digitSize = 38
                return c
            }())
        ]

        let sheet = VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 22) {
                ForEach(Array(calendars.enumerated()), id: \.offset) { _, variant in
                    calendarSample(variant)
                }
            }
            HStack(alignment: .top, spacing: 22) {
                ForEach(Array(clocks.enumerated()), id: \.offset) { _, variant in
                    clockSample(variant)
                }
            }
        }
        .padding(40)
        .background(
            LinearGradient(colors: [Color(red: 0.42, green: 0.55, blue: 0.72),
                                    Color(red: 0.16, green: 0.20, blue: 0.30)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )

        let renderer = ImageRenderer(content: sheet)
        renderer.scale = 2.0
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:])
        else { return false }

        do {
            try data.write(to: URL(fileURLWithPath: path))
            return true
        } catch {
            FileHandle.standardError.write("render failed: \(error)\n".data(using: .utf8)!)
            return false
        }
    }

    private static func calendarSample(_ v: Variant) -> some View {
        let base = CalendarWidget.baseSize(for: v.config)
        return VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                GlassBackground(cornerRadius: 26 * v.scale, accent: v.accent, theme: v.theme)
                CalendarWidgetView(config: v.config, theme: v.theme, accent: v.accent,
                                   showGlow: false, onOffsetChange: { _ in },
                                   previewHover: v.hover)
                    .frame(width: base.width, height: base.height, alignment: .topLeading)
                    .scaleEffect(v.scale, anchor: .topLeading)
            }
            .frame(width: base.width * v.scale, height: base.height * v.scale)
            caption(v.caption)
        }
    }

    private static func clockSample(_ v: ClockVariant) -> some View {
        let base = ClockWidget.baseSize(for: v.config)
        return VStack(alignment: .leading, spacing: 8) {
            ZStack {
                GlassBackground(cornerRadius: 26, accent: v.accent, theme: v.theme)
                ClockWidgetView(config: v.config, theme: v.theme, accent: v.accent,
                                showGlow: false)
                    .frame(width: base.width, height: base.height)
            }
            .frame(width: base.width, height: base.height)
            caption(v.caption)
        }
    }

    private static func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.9))
    }
}
