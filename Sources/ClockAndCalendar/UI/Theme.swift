import SwiftUI

/// Colours for a widget's own surface, resolved from its theme.
///
/// Widget content reads a `Palette`; the Settings window keeps using the static
/// `Theme` tokens below, since that window is always dark.
struct Palette {
    let isLight: Bool

    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let hairline: Color
    let grid: Color

    /// Panel background, top to bottom.
    let panelTop: Color
    let panelBottom: Color
    /// Top-left specular edge of the glass border.
    let edgeHighlight: Color
    /// Tint of the small inline button backgrounds (nav arrows, etc.).
    let controlFill: Color

    static let dark = Palette(
        isLight: false,
        textPrimary: Color.white.opacity(0.95),
        textSecondary: Color.white.opacity(0.60),
        textTertiary: Color.white.opacity(0.34),
        hairline: Color.white.opacity(0.10),
        grid: Color.white.opacity(0.05),
        panelTop: Color(red: 0.07, green: 0.08, blue: 0.12),
        panelBottom: Color(red: 0.03, green: 0.04, blue: 0.07),
        edgeHighlight: Color.white.opacity(0.28),
        controlFill: Color.white.opacity(0.07)
    )

    static let light = Palette(
        isLight: true,
        textPrimary: Color(red: 0.09, green: 0.10, blue: 0.13),
        textSecondary: Color(red: 0.09, green: 0.10, blue: 0.13).opacity(0.62),
        textTertiary: Color(red: 0.09, green: 0.10, blue: 0.13).opacity(0.34),
        hairline: Color.black.opacity(0.10),
        grid: Color.black.opacity(0.06),
        panelTop: Color(red: 1.00, green: 1.00, blue: 1.00),
        panelBottom: Color(red: 0.94, green: 0.95, blue: 0.97),
        edgeHighlight: Color.white.opacity(0.90),
        controlFill: Color.black.opacity(0.05)
    )

    static func of(_ theme: WidgetTheme) -> Palette {
        switch theme {
        case .dark: .dark
        case .light: .light
        }
    }
}

/// Design tokens for the Settings window, which is always dark.
enum Theme {
    /// Accent for every control in the Settings window.
    ///
    /// Deliberately fixed: tying it to the selected widget's accent made the
    /// whole settings UI change colour as you clicked between widgets, which
    /// read as a bug. Destructive actions still use their own red/amber.
    static let control: Accent = .blue

    static let surface = Color(red: 0.05, green: 0.06, blue: 0.09)
    static let surfaceRaised = Color(red: 0.09, green: 0.10, blue: 0.14)
    static let surfaceSunken = Color(red: 0.03, green: 0.04, blue: 0.06)

    static let textPrimary = Color.white.opacity(0.95)
    static let textSecondary = Color.white.opacity(0.60)
    static let textTertiary = Color.white.opacity(0.34)

    static let hairline = Color.white.opacity(0.10)

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular, _ design: Font.Design = .rounded) -> Font {
        .system(size: size, weight: weight, design: design)
    }
}

extension Font.Design {
    static func from(_ style: TypeStyle) -> Font.Design {
        switch style {
        case .rounded: .rounded
        case .mono: .monospaced
        case .serif: .serif
        case .system: .default
        }
    }
}

/// Typeface choice exposed in widget settings.
enum TypeStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case rounded, system, mono, serif
    var id: String { rawValue }
    var label: String {
        switch self {
        case .rounded: "Rounded"
        case .system: "System"
        case .mono: "Mono"
        case .serif: "Serif"
        }
    }
}
