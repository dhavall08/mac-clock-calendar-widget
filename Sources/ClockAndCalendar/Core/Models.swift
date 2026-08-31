import SwiftUI

// MARK: - Theme

enum WidgetTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case dark, light

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dark: "Dark"
        case .light: "Light"
        }
    }
}

// MARK: - Accent palette

/// Named accents so a widget's colour survives JSON round-trips without
/// encoding raw component values.
///
/// Components are stored as RGB rather than `Color` so the light theme can
/// derive a deeper variant — the neon values that read well on near-black are
/// far too pale on white.
enum Accent: String, Codable, CaseIterable, Identifiable, Sendable {
    case cyan, sky, blue, indigo, violet, magenta, pink, rose
    case crimson, red, orange, amber, yellow, lime, green, mint
    case teal, sand, graphite, slate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cyan: "Cyan"
        case .sky: "Sky"
        case .blue: "Blue"
        case .indigo: "Indigo"
        case .violet: "Violet"
        case .magenta: "Magenta"
        case .pink: "Pink"
        case .rose: "Rose"
        case .crimson: "Crimson"
        case .red: "Red"
        case .orange: "Orange"
        case .amber: "Amber"
        case .yellow: "Yellow"
        case .lime: "Lime"
        case .green: "Green"
        case .mint: "Mint"
        case .teal: "Teal"
        case .sand: "Sand"
        case .graphite: "Graphite"
        case .slate: "Slate"
        }
    }

    /// Raw values that older builds wrote, mapped to their current case so a
    /// rename doesn't silently reset someone's chosen colour.
    private static let renamed: [String: Accent] = ["ice": .graphite]

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Accent(rawValue: raw) ?? Self.renamed[raw] ?? .cyan
    }

    private var leadingRGB: (Double, Double, Double) {
        switch self {
        case .cyan: (0.31, 0.85, 1.00)
        case .sky: (0.42, 0.72, 1.00)
        case .blue: (0.36, 0.55, 1.00)
        case .indigo: (0.48, 0.44, 1.00)
        case .violet: (0.66, 0.51, 1.00)
        case .magenta: (0.90, 0.42, 1.00)
        case .pink: (1.00, 0.52, 0.82)
        case .rose: (1.00, 0.44, 0.62)
        case .crimson: (0.94, 0.30, 0.42)
        case .red: (1.00, 0.36, 0.32)
        case .orange: (1.00, 0.58, 0.21)
        case .amber: (1.00, 0.74, 0.31)
        case .yellow: (1.00, 0.87, 0.32)
        case .lime: (0.72, 0.98, 0.37)
        case .green: (0.38, 0.90, 0.50)
        case .mint: (0.35, 0.95, 0.75)
        case .teal: (0.28, 0.86, 0.86)
        case .sand: (0.90, 0.82, 0.66)
        case .graphite: (0.78, 0.82, 0.88)
        case .slate: (0.58, 0.66, 0.78)
        }
    }

    private var trailingRGB: (Double, Double, Double) {
        switch self {
        case .cyan: (0.45, 0.55, 1.00)
        case .sky: (0.30, 0.88, 0.98)
        case .blue: (0.52, 0.42, 1.00)
        case .indigo: (0.76, 0.44, 1.00)
        case .violet: (1.00, 0.45, 0.85)
        case .magenta: (0.58, 0.42, 1.00)
        case .pink: (1.00, 0.62, 0.52)
        case .rose: (0.72, 0.40, 1.00)
        case .crimson: (1.00, 0.48, 0.32)
        case .red: (1.00, 0.55, 0.30)
        case .orange: (1.00, 0.36, 0.34)
        case .amber: (1.00, 0.45, 0.35)
        case .yellow: (1.00, 0.62, 0.28)
        case .lime: (0.25, 0.90, 0.62)
        case .green: (0.24, 0.82, 0.74)
        case .mint: (0.30, 0.78, 1.00)
        case .teal: (0.30, 0.66, 1.00)
        case .sand: (0.82, 0.66, 0.48)
        case .graphite: (0.55, 0.60, 0.70)
        case .slate: (0.42, 0.50, 0.66)
        }
    }

    /// Light theme needs a darker, more saturated accent to survive on white.
    private static func adjust(_ rgb: (Double, Double, Double), for theme: WidgetTheme) -> Color {
        switch theme {
        case .dark:
            return Color(red: rgb.0, green: rgb.1, blue: rgb.2)
        case .light:
            let factor = 0.58
            return Color(red: rgb.0 * factor, green: rgb.1 * factor, blue: rgb.2 * factor)
        }
    }

    func color(_ theme: WidgetTheme = .dark) -> Color { Self.adjust(leadingRGB, for: theme) }
    func trailing(_ theme: WidgetTheme = .dark) -> Color { Self.adjust(trailingRGB, for: theme) }

    /// The fill used for today's highlight, toggles and chips. Always flat —
    /// gradients were removed from the whole app.
    func fill(_ theme: WidgetTheme = .dark) -> AnyShapeStyle {
        AnyShapeStyle(color(theme))
    }

    /// Text/glyph colour that sits legibly on top of `fill`.
    func onAccent(_ theme: WidgetTheme = .dark) -> Color {
        theme == .light ? Color.white : Color.black.opacity(0.88)
    }
}

// MARK: - Window layering

enum WidgetLayer: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Sits with the desktop icons: visible on the wallpaper, behind every app window.
    case desktop
    /// Behaves like an ordinary window in the stacking order.
    case normal
    /// Always on top of other apps.
    case floating

    var id: String { rawValue }

    var label: String {
        switch self {
        case .desktop: "On desktop"
        case .normal: "In window order"
        case .floating: "Always on top"
        }
    }

    var detail: String {
        switch self {
        case .desktop: "Pinned to the wallpaper, behind all app windows."
        case .normal: "Stacks like a regular window."
        case .floating: "Stays above every other app."
        }
    }
}

// MARK: - Border

enum BorderTint: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Hairline that picks up a hint of the accent — the default glass edge.
    case subtle
    /// Fully accent-coloured outline.
    case accent
    /// Plain light/dark outline with no accent in it.
    case neutral

    var id: String { rawValue }

    var label: String {
        switch self {
        case .subtle: "Subtle"
        case .accent: "Accent"
        case .neutral: "Neutral"
        }
    }
}

// MARK: - Remembered placement

/// Where a widget sat on one particular display.
///
/// Positions are stored per display and relative to that display's top-left
/// corner, not as the global Cocoa coordinates the window server hands us:
/// unplugging a monitor (or plugging one in) renumbers and shifts every other
/// display's global frame, so an absolute point is only meaningful while the
/// exact same set of screens is attached.
struct WidgetPlacement: Codable, Equatable, Sendable {
    /// Top-left corner, measured right and *down* from the display's top-left.
    var offsetX: Double = 0
    var offsetY: Double = 0
    /// The same corner as a fraction of the display's size, used when that
    /// display's resolution changed while we weren't looking.
    var fractionX: Double = 0
    var fractionY: Double = 0
    /// The size the widget had here. A display swap can force a widget to shrink
    /// to fit; this is what it goes back to when the bigger screen returns.
    var scale: Double = 1.0
    /// When the user last put the widget here. Restoration picks the most recent
    /// placement among the displays that are actually attached.
    var updatedAt: Date = Date(timeIntervalSince1970: 0)

    init(offsetX: Double, offsetY: Double, fractionX: Double, fractionY: Double, scale: Double, updatedAt: Date) {
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.fractionX = fractionX
        self.fractionY = fractionY
        self.scale = scale
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = WidgetPlacement(offsetX: 0, offsetY: 0, fractionX: 0, fractionY: 0, scale: 1.0,
                                updatedAt: Date(timeIntervalSince1970: 0))
        offsetX = c.value(.offsetX, d.offsetX)
        offsetY = c.value(.offsetY, d.offsetY)
        fractionX = c.value(.fractionX, d.fractionX)
        fractionY = c.value(.fractionY, d.fractionY)
        scale = c.value(.scale, d.scale)
        updatedAt = c.value(.updatedAt, d.updatedAt)
    }
}

extension WidgetPlacement {

    /// Captures a global top-left anchor as an offset within the display it sits
    /// on. `frame` is that display's `NSScreen.frame`.
    init(topLeft: CGPoint, on frame: CGRect, scale: Double) {
        let dx = topLeft.x - frame.minX
        // Cocoa's y grows upwards; measuring down from the top edge keeps a
        // widget the same distance below the menu bar when a display's height
        // changes, which is how people think about where they put it.
        let dy = frame.maxY - topLeft.y
        self.init(
            offsetX: dx,
            offsetY: dy,
            fractionX: frame.width > 0 ? dx / frame.width : 0,
            fractionY: frame.height > 0 ? dy / frame.height : 0,
            scale: scale,
            updatedAt: Date()
        )
    }

    /// The global top-left anchor this placement means for a display that is
    /// attached right now.
    ///
    /// Prefers the exact offsets — the same pixels the user dragged to — and only
    /// falls back to the proportional ones when the display has since changed
    /// resolution enough that a widget of `size` would no longer fit there.
    func topLeft(on frame: CGRect, size: CGSize) -> CGPoint {
        var dx = offsetX
        var dy = offsetY
        if dx + size.width > frame.width || dy + size.height > frame.height {
            dx = fractionX * frame.width
            dy = fractionY * frame.height
        }
        return CGPoint(x: frame.minX + dx, y: frame.maxY - dy)
    }
}

// MARK: - Chrome (shared by every widget kind)

/// Presentation state that every widget has, independent of its own config.
struct WidgetChrome: Codable, Equatable, Sendable {
    var isVisible: Bool = true
    /// Multiplier applied to the widget's intrinsic base size. 1.0 == compact.
    var scale: Double = 1.0
    var opacity: Double = 1.0
    var theme: WidgetTheme = .dark
    var accent: Accent = .cyan
    var layer: WidgetLayer = .desktop
    var cornerRadius: Double = 26
    /// Panel outline. 0 hides it entirely.
    var borderWidth: Double = 1
    var borderTint: BorderTint = .subtle
    /// Blocks all mouse input so the widget cannot be nudged by accident.
    var isLocked: Bool = false
    var showsGlow: Bool = false
    /// Off by default: a drop shadow has to be clipped by the panel bounds, and
    /// the clipped edge reads as a grey box around the widget.
    var showsShadow: Bool = false
    var showsBackground: Bool = true
    /// Top-left corner in Cocoa screen coordinates. `nil` means "place me".
    ///
    /// This is the widget's *live* position, rewritten whenever it has to be
    /// nudged to stay on screen. `placements` is the durable record.
    var originX: Double? = nil
    var originY: Double? = nil
    /// Remembered position per display, keyed by `ScreenIdentity`. Survives a
    /// monitor being unplugged so the widget can go back when it returns.
    var placements: [String: WidgetPlacement] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = WidgetChrome()
        isVisible = c.value(.isVisible, d.isVisible)
        scale = c.value(.scale, d.scale)
        opacity = c.value(.opacity, d.opacity)
        theme = c.value(.theme, d.theme)
        accent = c.value(.accent, d.accent)
        layer = c.value(.layer, d.layer)
        cornerRadius = c.value(.cornerRadius, d.cornerRadius)
        borderWidth = c.value(.borderWidth, d.borderWidth)
        borderTint = c.value(.borderTint, d.borderTint)
        isLocked = c.value(.isLocked, d.isLocked)
        showsGlow = c.value(.showsGlow, d.showsGlow)
        showsShadow = c.value(.showsShadow, d.showsShadow)
        showsBackground = c.value(.showsBackground, d.showsBackground)
        originX = c.value(.originX, d.originX)
        originY = c.value(.originY, d.originY)
        placements = c.value(.placements, d.placements)
    }
}

// MARK: - Instance

/// One placed widget. `configData` holds the kind-specific settings blob so new
/// widget kinds can be added without touching the persistence format.
struct WidgetInstance: Codable, Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    var kind: String
    var chrome: WidgetChrome = WidgetChrome()
    var configData: Data?
}

// MARK: - App-level settings

/// Settings that belong to the app rather than to any one widget.
struct AppSettings: Codable, Equatable, Sendable {
    /// Removes the status item. The app stays running; re-opening it from
    /// Finder/Spotlight brings the Settings window back.
    var hideMenuBarIcon: Bool = false
    var launchAtLogin: Bool = false

    /// Remembered Settings window size, so a wider layout survives a relaunch.
    var settingsWidth: Double = 840
    var settingsHeight: Double = 720

    static let minimumSettingsSize = CGSize(width: 700, height: 480)

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        hideMenuBarIcon = c.value(.hideMenuBarIcon, d.hideMenuBarIcon)
        launchAtLogin = c.value(.launchAtLogin, d.launchAtLogin)
        settingsWidth = c.value(.settingsWidth, d.settingsWidth)
        settingsHeight = c.value(.settingsHeight, d.settingsHeight)
    }
}

/// Named Settings window sizes offered in Preferences.
enum SettingsWindowPreset: String, CaseIterable, Identifiable, Sendable {
    case standard, large, huge, fitScreen

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: "Standard"
        case .large: "Large"
        case .huge: "Extra large"
        case .fitScreen: "Fit screen"
        }
    }

    /// Clamped to the visible frame so a preset can never exceed the display.
    func size(on visibleFrame: CGRect) -> CGSize {
        let ideal: CGSize
        switch self {
        case .standard: ideal = CGSize(width: 840, height: 720)
        case .large: ideal = CGSize(width: 1080, height: 840)
        case .huge: ideal = CGSize(width: 1320, height: 980)
        case .fitScreen: ideal = CGSize(width: visibleFrame.width - 80,
                                        height: visibleFrame.height - 80)
        }
        return CGSize(width: min(ideal.width, visibleFrame.width - 40),
                      height: min(ideal.height, visibleFrame.height - 40))
    }
}

/// Root persisted document.
struct WidgetDocument: Codable, Sendable {
    var version: Int = 2
    var instances: [WidgetInstance] = []
    var settings: AppSettings = AppSettings()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = c.value(.version, 2)
        instances = c.value(.instances, [])
        settings = c.value(.settings, AppSettings())
    }
}
