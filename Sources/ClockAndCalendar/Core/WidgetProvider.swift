import SwiftUI

// MARK: - Config

/// Settings owned by a single widget kind.
protocol WidgetConfig: Codable, Equatable, Sendable {
    static var defaults: Self { get }
}

// MARK: - Provider
//
// To add a new widget kind:
//   1. Define a `WidgetConfig` struct.
//   2. Define a type conforming to `WidgetProvider`.
//   3. Add one line to `WidgetRegistry.all`.
// Nothing else in the app needs to change.

@MainActor
protocol WidgetProvider {
    associatedtype Config: WidgetConfig
    associatedtype Content: View
    associatedtype Settings: View

    /// Stable identifier persisted on disk. Never rename once shipped.
    static var kind: String { get }
    static var displayName: String { get }
    /// SF Symbol shown in the gallery and menu bar.
    static var symbolName: String { get }
    static var blurb: String { get }

    /// Intrinsic layout size at scale 1.0. May depend on config (e.g. an extra
    /// column for week numbers).
    static func baseSize(for config: Config) -> CGSize

    /// Lower bound for the size slider, as a multiple of `baseSize`.
    static var minScale: Double { get }

    @ViewBuilder static func content(_ ctx: WidgetContext<Config>) -> Content
    @ViewBuilder static func settings(_ ctx: WidgetContext<Config>) -> Settings
}

extension WidgetProvider {
    static var minScale: Double { 0.75 }
}

// MARK: - Context handed to a provider's views

/// Live, two-way access to one instance's state. Writes go straight to
/// `AppState`, which persists them and resizes the panel.
@MainActor
struct WidgetContext<Config: WidgetConfig> {
    let id: UUID
    let state: AppState

    var config: Config { state.config(for: id, as: Config.self) }
    var chrome: WidgetChrome { state.chrome(for: id) }

    var configBinding: Binding<Config> { state.configBinding(for: id, as: Config.self) }
    var chromeBinding: Binding<WidgetChrome> { state.chromeBinding(for: id) }

    func bind<V>(_ path: WritableKeyPath<Config, V>) -> Binding<V> {
        let b = configBinding
        return Binding(get: { b.wrappedValue[keyPath: path] },
                       set: { var c = b.wrappedValue; c[keyPath: path] = $0; b.wrappedValue = c })
    }

    func bindChrome<V>(_ path: WritableKeyPath<WidgetChrome, V>) -> Binding<V> {
        let b = chromeBinding
        return Binding(get: { b.wrappedValue[keyPath: path] },
                       set: { var c = b.wrappedValue; c[keyPath: path] = $0; b.wrappedValue = c })
    }

    var accent: Accent { chrome.accent }
}

// MARK: - Type-erased provider

/// Erases a `WidgetProvider` so heterogeneous kinds can live in one array.
///
/// Not `Identifiable`: the synthesised conformance would have to cross the main
/// actor boundary. Callers use `id: \.kind` in `ForEach` instead.
@MainActor
struct AnyWidgetType {
    let kind: String
    let displayName: String
    let symbolName: String
    let blurb: String
    let minScale: Double

    let defaultConfigData: () -> Data
    /// Decodes persisted settings, falling back to defaults on any schema drift.
    let decodeConfig: (Data?) -> any WidgetConfig
    let baseSize: (any WidgetConfig) -> CGSize
    let content: (AppState, UUID) -> AnyView
    let settings: (AppState, UUID) -> AnyView

    init<P: WidgetProvider>(_ provider: P.Type) {
        kind = P.kind
        displayName = P.displayName
        symbolName = P.symbolName
        blurb = P.blurb
        minScale = P.minScale

        defaultConfigData = { (try? JSONEncoder().encode(P.Config.defaults)) ?? Data() }
        decodeConfig = { data in
            guard let data, let decoded = try? JSONDecoder().decode(P.Config.self, from: data) else {
                return P.Config.defaults
            }
            return decoded
        }
        baseSize = { cfg in P.baseSize(for: (cfg as? P.Config) ?? P.Config.defaults) }
        content = { state, id in AnyView(P.content(WidgetContext<P.Config>(id: id, state: state))) }
        settings = { state, id in AnyView(P.settings(WidgetContext<P.Config>(id: id, state: state))) }
    }
}
