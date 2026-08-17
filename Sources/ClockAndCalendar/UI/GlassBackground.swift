import SwiftUI

/// Frosted panel background.
///
/// Uses macOS 26 Liquid Glass where available and falls back to a flat fill over
/// a material on older systems, so the app still runs on 14/15.
struct GlassBackground: View {
    let cornerRadius: CGFloat
    let accent: Accent
    var theme: WidgetTheme = .dark
    var opacity: Double = 1.0
    var showsGlow: Bool = false
    var showsShadow: Bool = false
    var borderWidth: Double = 1
    var borderTint: BorderTint = .subtle

    /// Shadow and glow have to fit inside the transparent margin the panel keeps
    /// around the widget, otherwise the panel bounds clip them and the straight
    /// clipped edge reads as a grey box around the widget.
    private static let shadowRadius: CGFloat = 16
    private static let shadowOffsetY: CGFloat = 6
    private static let glowRadius: CGFloat = 18

    private var palette: Palette { Palette.of(theme) }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    /// Flat, not a gradient — gradients were removed from the whole app.
    private var fill: Color {
        palette.panelTop.opacity((theme == .light ? 0.94 : 0.90) * opacity)
    }

    /// Flat outline in one of three tints.
    private var edge: Color {
        switch borderTint {
        case .subtle: theme == .light ? Color.black.opacity(0.12) : Color.white.opacity(0.16)
        case .accent: accent.color(theme).opacity(0.75)
        case .neutral: theme == .light ? Color.black.opacity(0.24) : Color.white.opacity(0.26)
        }
    }

    var body: some View {
        shape
            .fill(fill)
            .background(liquidGlass)
            .overlay {
                if borderWidth > 0 {
                    // strokeBorder keeps the whole stroke inside the shape, so a
                    // thick border can't spill past the panel's rounded corners.
                    shape.strokeBorder(edge, lineWidth: borderWidth)
                }
            }
            .shadow(color: showsShadow ? Color.black.opacity((theme == .light ? 0.18 : 0.40) * opacity) : .clear,
                    radius: Self.shadowRadius, x: 0, y: Self.shadowOffsetY)
            .shadow(color: showsGlow ? accent.color(theme).opacity(0.20 * opacity) : .clear,
                    radius: Self.glowRadius, x: 0, y: 0)
    }

    @ViewBuilder
    private var liquidGlass: some View {
        if #available(macOS 26.0, *) {
            shape.fill(.clear).glassEffect(.regular, in: shape)
        } else {
            shape.fill(.ultraThinMaterial)
        }
    }

}
