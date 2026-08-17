import AppKit
import SwiftUI

@MainActor
final class ControlCenterModel: ObservableObject {
    enum Section: Hashable {
        case widget(UUID)
        case app
    }

    @Published var section: Section = .app

    /// Set by `ControlCenterWindowController`; the view can't resize the window
    /// itself, so preset buttons hand the request back to the controller.
    var onApplyWindowPreset: ((SettingsWindowPreset) -> Void)?

    var selectedWidget: UUID? {
        if case .widget(let id) = section { return id }
        return nil
    }
}

/// Configuration surface: the size slider, shared chrome, whatever settings the
/// selected widget kind contributes, and the app-level preferences.
struct ControlCenterView: View {
    @ObservedObject var state: AppState
    @ObservedObject var model: ControlCenterModel

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 232)
            Divider().overlay(Theme.hairline)
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.surface)
        .preferredColorScheme(.dark)
        .onAppear {
            if model.selectedWidget.flatMap(state.instance) == nil,
               let first = state.instances.first?.id {
                model.section = .widget(first)
            }
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.control.color())
                VStack(alignment: .leading, spacing: 0) {
                    Text("Clock and Calendar")
                        .font(Theme.font(13.5, .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("by Dhaval")
                        .font(Theme.font(9.5, .medium))
                        .tracking(0.8)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    label("Placed")
                    ForEach(state.instances) { instance in
                        instanceRow(instance)
                    }

                    label("Add a widget").padding(.top, 14)
                    ForEach(WidgetRegistry.all, id: \.kind) { type in
                        Button {
                            if let id = state.addWidget(kind: type.kind) { model.section = .widget(id) }
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: "plus")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Theme.textTertiary)
                                Image(systemName: type.symbolName)
                                    .font(.system(size: 11))
                                    .frame(width: 14)
                                    .foregroundStyle(Theme.textSecondary)
                                Text(type.displayName)
                                    .font(Theme.font(12))
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(HoverRowStyle())
                    }

                    label("App").padding(.top, 14)
                    appRow
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 16)
            }
        }
        .background(Theme.surfaceSunken)
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Theme.font(9.5, .bold))
            .tracking(1.3)
            .foregroundStyle(Theme.textTertiary)
            .padding(.horizontal, 10)
            .padding(.bottom, 4)
    }

    private var appRow: some View {
        let isSelected = model.section == .app
        return Button {
            model.section = .app
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .frame(width: 16)
                    .foregroundStyle(isSelected ? Theme.control.color() : Theme.textSecondary)
                Text("Preferences")
                    .font(Theme.font(12.5, .medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(selectionBackground(isSelected, accent: Theme.control))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func instanceRow(_ instance: WidgetInstance) -> some View {
        let type = WidgetRegistry.type(for: instance.kind)
        let isSelected = model.section == .widget(instance.id)

        return Button {
            model.section = .widget(instance.id)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: type?.symbolName ?? "square")
                    .font(.system(size: 12))
                    .frame(width: 16)
                    .foregroundStyle(instance.chrome.isVisible ? instance.chrome.accent.color() : Theme.textTertiary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(type?.displayName ?? instance.kind)
                        .font(Theme.font(12.5, .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(String(format: "%.2f× · %@", instance.chrome.scale, instance.chrome.layer.label))
                        .font(Theme.font(9.5, .regular, .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 0)
                Toggle("", isOn: state.chromeBinding(for: instance.id).isVisible)
                    .labelsHidden()
                    .toggleStyle(NeoToggleStyle(accent: Theme.control))
                    .scaleEffect(0.8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(selectionBackground(isSelected, accent: Theme.control))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func selectionBackground(_ isSelected: Bool, accent: Accent) -> some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(isSelected ? Color.white.opacity(0.08) : .clear)
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isSelected ? accent.color().opacity(0.5) : .clear, lineWidth: 1)
            )
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        switch model.section {
        case .app:
            ScrollView {
                VStack(spacing: 12) {
                    preferencesHeader
                    preferencesCard
                    aboutCard
                }
                .padding(18)
                .frame(maxWidth: 760)
            }
            .frame(maxWidth: .infinity)

        case .widget(let id):
            if let instance = state.instance(id), let type = state.type(of: id) {
                ScrollView {
                    VStack(spacing: 12) {
                        detailHeader(instance: instance, type: type)
                        sizeCard(id: id, instance: instance, type: type)
                        appearanceCard(id: id, instance: instance)
                        type.settings(state, id)
                        dangerCard(id: id)
                    }
                    .padding(18)
                    .frame(maxWidth: 760)
                }
                .frame(maxWidth: .infinity)
            } else {
                emptyState
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.dashed")
                .font(.system(size: 26))
                .foregroundStyle(Theme.textTertiary)
            Text("Add a widget to get started")
                .font(Theme.font(13))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: App preferences

    private var preferencesHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "gearshape")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.control.color())
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Theme.control.color().opacity(0.12))
                )
            VStack(alignment: .leading, spacing: 3) {
                Text("Preferences")
                    .font(Theme.font(17, .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Settings for the app itself, not for a single widget.")
                    .font(Theme.font(11))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: 0)
        }
    }

    private var preferencesCard: some View {
        SettingsCard(title: "System", symbol: "menubar.rectangle", accent: Theme.control) {
            SettingRow(label: "Start at login",
                       detail: "Installs a LaunchAgent in ~/Library/LaunchAgents") {
                Toggle("", isOn: state.settingsBinding(\.launchAtLogin))
                    .labelsHidden()
                    .toggleStyle(NeoToggleStyle(accent: Theme.control))
            }

            if state.settings.launchAtLogin, !LoginItemManager.isRunningFromApplications {
                notice(
                    "This copy is running from **\(Bundle.main.bundlePath)**, not /Applications. "
                        + "The login item points there, so it will stop working if that folder is "
                        + "rebuilt or removed. Run `./build.sh --install` and reopen from /Applications.",
                    accent: .amber
                )
            }

            Divider().overlay(Theme.hairline)

            SettingRow(label: "Settings window size",
                       detail: "Remembered between launches; dragging the edges also sticks") {
                HStack(spacing: 5) {
                    ForEach(SettingsWindowPreset.allCases) { preset in
                        Button(preset.label) { model.onApplyWindowPreset?(preset) }
                            .buttonStyle(ChipButtonStyle(accent: Theme.control))
                    }
                }
            }
            Text(String(format: "Currently %.0f × %.0f pt.",
                        state.settings.settingsWidth, state.settings.settingsHeight))
                .font(Theme.font(10.5))
                .foregroundStyle(Theme.textTertiary)

            Divider().overlay(Theme.hairline)

            SettingRow(label: "Hide menu bar icon",
                       detail: "Widgets keep running without the status item") {
                Toggle("", isOn: state.settingsBinding(\.hideMenuBarIcon))
                    .labelsHidden()
                    .toggleStyle(NeoToggleStyle(accent: Theme.control))
            }

            if state.settings.hideMenuBarIcon {
                notice(
                    "With the icon hidden, open **Clock and Calendar by Dhaval** again from "
                        + "Spotlight or Finder to get this window back.",
                    accent: .cyan
                )
            }
        }
    }

    /// Inline callout used for the two Preferences warnings.
    private func notice(_ markdown: String, accent: Accent) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "info.circle")
                .font(.system(size: 11))
                .foregroundStyle(accent.color())
            Text(.init(markdown))
                .font(Theme.font(10.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(accent.color().opacity(0.10))
        )
    }

    private var aboutCard: some View {
        SettingsCard(title: "About", symbol: "info.circle", accent: Theme.control) {
            SettingRow(label: "Settings file",
                       detail: AppState.supportDirectory.appendingPathComponent("state.json").path) {
                Button("Reveal") {
                    NSWorkspace.shared.selectFile(
                        AppState.supportDirectory.appendingPathComponent("state.json").path,
                        inFileViewerRootedAtPath: AppState.supportDirectory.path
                    )
                }
                .buttonStyle(ChipButtonStyle(accent: Theme.control))
            }
            SettingRow(label: "Quit") {
                Button("Quit app") {
                    state.flush()
                    NSApp.terminate(nil)
                }
                .buttonStyle(ChipButtonStyle(accent: .rose))
            }
        }
    }

    // MARK: Widget detail

    private func detailHeader(instance: WidgetInstance, type: AnyWidgetType) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: type.symbolName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.control.color())
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Theme.control.color().opacity(0.12))
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(type.displayName)
                    .font(Theme.font(17, .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(type.blurb)
                    .font(Theme.font(11))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: state.chromeBinding(for: instance.id).isVisible)
                .labelsHidden()
                .toggleStyle(NeoToggleStyle(accent: Theme.control))
        }
        .padding(.bottom, 2)
    }

    private func sizeCard(id: UUID, instance: WidgetInstance, type: AnyWidgetType) -> some View {
        let rendered = state.renderedSize(for: id)
        let screenWidth = state.screenFrame(for: id).width
        let maxScale = state.maxScale(for: id)

        return SettingsCard(title: "Size & placement", symbol: "arrow.up.left.and.arrow.down.right",
                            accent: Theme.control) {
            SizeSlider(
                scale: state.chromeBinding(for: id).scale,
                range: type.minScale...maxScale,
                renderedSize: rendered,
                screenCoverage: rendered.width / screenWidth,
                accent: Theme.control
            )

            Divider().overlay(Theme.hairline)

            SettingRow(label: "Layer", detail: instance.chrome.layer.detail) {
                NeoSegmented(selection: state.chromeBinding(for: id).layer,
                             options: WidgetLayer.allCases,
                             label: { $0.label },
                             accent: Theme.control)
                    .frame(width: 260)
            }
            SettingRow(label: "Lock in place", detail: "Ignores all clicks so it can't be nudged") {
                Toggle("", isOn: state.chromeBinding(for: id).isLocked)
                    .labelsHidden()
                    .toggleStyle(NeoToggleStyle(accent: Theme.control))
            }
            HStack {
                Text("Drag the widget itself to move it, or its bottom-right grip to resize.")
                    .font(Theme.font(10.5))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Button("Reposition on screen") { state.rescueOffscreenWidgets() }
                    .buttonStyle(ChipButtonStyle(accent: Theme.control))
            }
        }
    }

    private func appearanceCard(id: UUID, instance: WidgetInstance) -> some View {
        SettingsCard(title: "Appearance", symbol: "paintpalette", accent: Theme.control) {
            SettingRow(label: "Theme") {
                NeoSegmented(selection: state.chromeBinding(for: id).theme,
                             options: WidgetTheme.allCases,
                             label: { $0.label },
                             accent: Theme.control)
                    .frame(width: 150)
            }
            SettingRow(label: "Accent") {
                AccentPicker(accent: state.chromeBinding(for: id).accent)
            }
            SettingRow(label: "Opacity") {
                HStack(spacing: 8) {
                    Slider(value: state.chromeBinding(for: id).opacity, in: 0.25...1.0)
                        .tint(Theme.control.color())
                        .frame(width: 150)
                    Text("\(Int(instance.chrome.opacity * 100))%")
                        .font(Theme.font(10.5, .medium, .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(width: 34, alignment: .trailing)
                }
            }
            MetricSlider(label: "Corner radius",
                         value: state.chromeBinding(for: id).cornerRadius,
                         range: 0...44, accent: Theme.control)
            MetricSlider(label: "Border width", detail: "0 hides the outline",
                         value: state.chromeBinding(for: id).borderWidth,
                         range: 0...6, decimals: 1, accent: Theme.control)
            if instance.chrome.borderWidth > 0 {
                SettingRow(label: "Border colour") {
                    NeoSegmented(selection: state.chromeBinding(for: id).borderTint,
                                 options: BorderTint.allCases,
                                 label: { $0.label },
                                 accent: Theme.control)
                        .frame(width: 210)
                }
            }
            SettingRow(label: "Glass background") {
                Toggle("", isOn: state.chromeBinding(for: id).showsBackground)
                    .labelsHidden()
                    .toggleStyle(NeoToggleStyle(accent: Theme.control))
            }
            SettingRow(label: "Neon glow") {
                Toggle("", isOn: state.chromeBinding(for: id).showsGlow)
                    .labelsHidden()
                    .toggleStyle(NeoToggleStyle(accent: Theme.control))
            }
            SettingRow(label: "Drop shadow", detail: "Off by default — it can read as a faint box edge") {
                Toggle("", isOn: state.chromeBinding(for: id).showsShadow)
                    .labelsHidden()
                    .toggleStyle(NeoToggleStyle(accent: Theme.control))
            }
        }
    }

    private func dangerCard(id: UUID) -> some View {
        HStack(spacing: 8) {
            Button("Duplicate") { state.duplicateWidget(id) }
                .buttonStyle(ChipButtonStyle(accent: .graphite))
            Button("Reset to defaults") { state.resetConfig(id) }
                .buttonStyle(ChipButtonStyle(accent: .amber))
            Spacer()
            Button("Remove widget") {
                let next = state.instances.first { $0.id != id }?.id
                state.removeWidget(id)
                model.section = next.map { ControlCenterModel.Section.widget($0) } ?? .app
            }
            .buttonStyle(ChipButtonStyle(accent: .rose))
        }
        .padding(.top, 2)
    }
}

// MARK: - Hover row

struct HoverRowStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(hovering ? 0.07 : 0))
            )
            .onHover { hovering = $0 }
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
