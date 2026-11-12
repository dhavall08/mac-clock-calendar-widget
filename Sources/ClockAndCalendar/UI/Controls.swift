import SwiftUI

// MARK: - Section card

struct SettingsCard<Content: View>: View {
    let title: String
    var symbol: String? = nil
    var accent: Accent = .cyan
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accent.color())
                }
                Text(title.uppercased())
                    .font(Theme.font(10.5, .bold))
                    .tracking(1.4)
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 12) { content }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.surfaceRaised.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.hairline, lineWidth: 1)
                )
        )
    }
}

// MARK: - Labelled row

struct SettingRow<Control: View>: View {
    let label: String
    var detail: String? = nil
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Theme.font(12.5, .medium))
                    .foregroundStyle(Theme.textPrimary)
                if let detail {
                    Text(detail)
                        .font(Theme.font(10.5))
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            control
        }
    }
}

// MARK: - Size slider

/// The headline control: continuous scale with a live readout of the resulting
/// pixel size and how much of the screen it covers.
struct SizeSlider: View {
    @Binding var scale: Double
    let range: ClosedRange<Double>
    let renderedSize: CGSize
    let screenCoverage: Double
    let accent: Accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Size")
                    .font(Theme.font(12.5, .medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(Int(renderedSize.width))×\(Int(renderedSize.height)) pt")
                    .font(Theme.font(11, .semibold, .monospaced))
                    .foregroundStyle(accent.color())
                Text("· \(Int(screenCoverage * 100))% of screen width")
                    .font(Theme.font(10.5, .regular, .monospaced))
                    .foregroundStyle(Theme.textTertiary)
            }

            Slider(value: $scale, in: range)
                .tint(accent.color())

            HStack {
                ForEach(presets, id: \.label) { preset in
                    Button(preset.label) { scale = preset.value }
                        .buttonStyle(ChipButtonStyle(accent: accent, isOn: abs(scale - preset.value) < 0.02))
                }
                Spacer()
                Text(String(format: "%.2f×", scale))
                    .font(Theme.font(10.5, .medium, .monospaced))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    /// Quick jumps expressed in terms of screen width, which is how people
    /// actually think about widget size.
    private var presets: [(label: String, value: Double)] {
        let span = range.upperBound - range.lowerBound
        return [
            ("Compact", range.lowerBound + span * 0.05),
            ("Medium", range.lowerBound + span * 0.28),
            ("Half screen", halfScreenScale),
            ("Max", range.upperBound)
        ]
    }

    /// Scale at which the widget is ~50% of the screen width, clamped to range.
    private var halfScreenScale: Double {
        guard screenCoverage > 0 else { return range.lowerBound }
        let target = scale * (0.5 / screenCoverage)
        return min(max(target, range.lowerBound), range.upperBound)
    }
}

// MARK: - Chip button

struct ChipButtonStyle: ButtonStyle {
    let accent: Accent
    var isOn: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(10.5, .semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(isOn ? Color.black.opacity(0.85) : Theme.textSecondary)
            .background(
                Capsule(style: .continuous)
                    .fill(isOn ? AnyShapeStyle(accent.color()) : AnyShapeStyle(Color.white.opacity(0.07)))
            )
            .overlay(Capsule().stroke(Theme.hairline, lineWidth: isOn ? 0 : 1))
            .opacity(configuration.isPressed ? 0.65 : 1)
            .contentShape(Capsule())
    }
}

// MARK: - Segmented picker

struct NeoSegmented<T: Hashable & Identifiable>: View {
    @Binding var selection: T
    let options: [T]
    let label: (T) -> String
    let accent: Accent

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options) { option in
                let isOn = option == selection
                Button { selection = option } label: {
                    Text(label(option))
                        .font(Theme.font(11, .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .foregroundStyle(isOn ? Color.black.opacity(0.85) : Theme.textSecondary)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(isOn ? AnyShapeStyle(accent.color()) : AnyShapeStyle(Color.clear))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.surfaceSunken.opacity(0.8))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
        )
    }
}

// MARK: - Accent picker

/// Swatch grid. Wraps rather than using one row, since the palette is 20 wide.
struct AccentPicker: View {
    @Binding var accent: Accent
    var columns: Int = 10

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(18), spacing: 7), count: columns),
            spacing: 7
        ) {
            ForEach(Accent.allCases) { option in
                Button { accent = option } label: {
                    Circle()
                        .fill(option.color())
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(accent == option ? 0.95 : 0.15),
                                        lineWidth: accent == option ? 2 : 1)
                        )
                        .shadow(color: option.color().opacity(accent == option ? 0.7 : 0), radius: 6)
                }
                .buttonStyle(.plain)
                .help(option.label)
            }
        }
        .frame(width: CGFloat(columns) * 25)
    }
}

// MARK: - Numeric slider row

/// Slider with a live value readout, for point sizes and widths.
struct MetricSlider: View {
    let label: String
    var detail: String? = nil
    @Binding var value: Double
    let range: ClosedRange<Double>
    var unit: String = "pt"
    var decimals: Int = 0
    let accent: Accent

    var body: some View {
        SettingRow(label: label, detail: detail) {
            HStack(spacing: 8) {
                Slider(value: $value, in: range)
                    .tint(accent.color())
                    .frame(width: 150)
                Text(String(format: "%.\(decimals)f\(unit)", value))
                    .font(Theme.font(10.5, .medium, .monospaced))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }
}

// MARK: - Toggle style

struct NeoToggleStyle: ToggleStyle {
    let accent: Accent

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? AnyShapeStyle(accent.color()) : AnyShapeStyle(Color.white.opacity(0.12)))
                    .frame(width: 38, height: 22)
                Circle()
                    .fill(Color.white)
                    .frame(width: 17, height: 17)
                    .padding(.horizontal, 2.5)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isOn)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Icon button

struct IconButton: View {
    let symbol: String
    var help: String = ""
    var accent: Accent = .cyan
    var isProminent: Bool = false
    let action: () -> Void

    @ViewState private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
                .foregroundStyle(isProminent ? Color.black.opacity(0.85) : (hovering ? accent.color() : Theme.textSecondary))
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isProminent ? AnyShapeStyle(accent.color())
                                          : AnyShapeStyle(Color.white.opacity(hovering ? 0.14 : 0.07)))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}
