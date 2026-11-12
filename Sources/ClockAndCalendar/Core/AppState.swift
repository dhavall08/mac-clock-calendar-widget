import AppKit
import Combine
import SwiftUI

/// Single source of truth for every placed widget, plus JSON persistence.
///
/// Configs are kept decoded in memory (`configs`) and only serialised when the
/// document is written, so binding reads stay cheap.
@MainActor
final class AppState: ObservableObject {

    @Published private(set) var instances: [WidgetInstance] = []
    @Published private(set) var settings = AppSettings()
    @Published private var configs: [UUID: any WidgetConfig] = [:]

    /// Fires with an instance id whenever its chrome or config changed, so the
    /// window controller can re-apply geometry without diffing everything.
    let instanceChanged = PassthroughSubject<UUID, Never>()
    /// Fires when instances are added or removed.
    let rosterChanged = PassthroughSubject<Void, Never>()
    /// Fires when app-level settings change.
    let settingsChanged = PassthroughSubject<AppSettings, Never>()

    private var saveWorkItem: DispatchWorkItem?

    // MARK: Storage location

    private static var applicationSupport: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
    }

    static var supportDirectory: URL {
        applicationSupport.appendingPathComponent("ClockAndCalendar", isDirectory: true)
    }

    /// Where settings lived before the app was renamed.
    private static var legacySupportDirectory: URL {
        applicationSupport.appendingPathComponent("NebulaWidgets", isDirectory: true)
    }

    private static var documentURL: URL {
        supportDirectory.appendingPathComponent("state.json")
    }

    // MARK: Lifecycle

    init() {
        migrateLegacyStoreIfNeeded()
        load()
        // The plist on disk is the real state of the login item; trust it over
        // whatever the document happens to say.
        LoginItemManager.repairIfNeeded()
        settings.launchAtLogin = LoginItemManager.isEnabled
    }

    /// Moves the pre-rename settings directory across so existing widgets and
    /// their tweaks survive the rename.
    private func migrateLegacyStoreIfNeeded() {
        let fm = FileManager.default
        let legacyDocument = Self.legacySupportDirectory.appendingPathComponent("state.json")
        guard !fm.fileExists(atPath: Self.documentURL.path),
              fm.fileExists(atPath: legacyDocument.path)
        else { return }
        do {
            try fm.createDirectory(at: Self.supportDirectory, withIntermediateDirectories: true)
            try fm.copyItem(at: legacyDocument, to: Self.documentURL)
            NSLog("ClockAndCalendar: migrated settings from NebulaWidgets")
        } catch {
            NSLog("ClockAndCalendar: settings migration failed - \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.documentURL),
              let doc = try? JSONDecoder().decode(WidgetDocument.self, from: data),
              !doc.instances.isEmpty
        else {
            seedDefaults()
            return
        }
        settings = doc.settings
        // Drop instances whose kind no longer exists in this build.
        instances = doc.instances.filter { WidgetRegistry.type(for: $0.kind) != nil }
        for instance in instances {
            let type = WidgetRegistry.type(for: instance.kind)!
            configs[instance.id] = type.decodeConfig(instance.configData)
        }
        if instances.isEmpty { seedDefaults() }
    }

    private func seedDefaults() {
        // A calendar and an analog clock, both visible.
        var calendar = WidgetInstance(kind: CalendarWidget.kind)
        calendar.chrome = Self.defaultChrome(for: CalendarWidget.kind)
        configs[calendar.id] = CalendarConfig.defaults

        var clock = WidgetInstance(kind: ClockWidget.kind)
        clock.chrome = Self.defaultChrome(for: ClockWidget.kind)
        configs[clock.id] = ClockConfig.defaults

        instances = [calendar, clock]
        save(immediately: true)
    }

    /// Starting look for a new widget of `kind`. Position is left nil so the
    /// window controller places it on whatever display is attached.
    static func defaultChrome(for kind: String) -> WidgetChrome {
        var chrome = WidgetChrome()
        switch kind {
        case CalendarWidget.kind:
            chrome.scale = 1.41
            chrome.accent = .blue
            chrome.cornerRadius = 32
            chrome.borderWidth = 0.9
            chrome.showsShadow = true
        case ClockWidget.kind:
            chrome.scale = 1.87
            chrome.theme = .light
            chrome.accent = .crimson
            chrome.cornerRadius = 24.6
            chrome.borderWidth = 0.46
            chrome.showsBackground = false
            chrome.showsGlow = true
            chrome.showsShadow = true
        default:
            chrome.scale = 1.3
        }
        return chrome
    }

    // MARK: Reads

    func instance(_ id: UUID) -> WidgetInstance? {
        instances.first { $0.id == id }
    }

    func type(of id: UUID) -> AnyWidgetType? {
        guard let instance = instance(id) else { return nil }
        return WidgetRegistry.type(for: instance.kind)
    }

    func chrome(for id: UUID) -> WidgetChrome {
        instance(id)?.chrome ?? WidgetChrome()
    }

    func config<C: WidgetConfig>(for id: UUID, as type: C.Type) -> C {
        (configs[id] as? C) ?? C.defaults
    }

    func rawConfig(for id: UUID) -> (any WidgetConfig)? {
        configs[id]
    }

    /// Layout size of an instance at scale 1.0.
    func baseSize(for id: UUID) -> CGSize {
        guard let type = type(of: id), let cfg = configs[id] else { return CGSize(width: 320, height: 360) }
        return type.baseSize(cfg)
    }

    /// Rendered size, i.e. `baseSize * scale`.
    func renderedSize(for id: UUID) -> CGSize {
        let base = baseSize(for: id)
        let scale = chrome(for: id).scale
        return CGSize(width: (base.width * scale).rounded(), height: (base.height * scale).rounded())
    }

    /// The display a widget currently lives on, so "half the screen" means half
    /// of *its* screen on a multi-monitor setup.
    ///
    /// Matches on a small probe around the widget's top-left anchor rather than
    /// its whole frame: an oversized widget can straddle two displays, and the
    /// anchor is the one part of it that doesn't move when the scale changes.
    func screenFrame(for id: UUID) -> CGRect {
        let chrome = chrome(for: id)
        if let x = chrome.originX, let y = chrome.originY {
            let probe = CGRect(x: x, y: y - 80, width: 80, height: 80)
            let best = NSScreen.screens.max { a, b in
                area(a.frame.intersection(probe)) < area(b.frame.intersection(probe))
            }
            if let best, area(best.frame.intersection(probe)) > 0 {
                return best.visibleFrame
            }
        }
        return NSScreen.main?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
            ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    }

    private func area(_ rect: CGRect) -> CGFloat {
        rect.isNull || rect.isEmpty ? 0 : rect.width * rect.height
    }

    /// Largest scale at which the widget still fits its own screen, allowing for
    /// the transparent margin the shell adds.
    func maxScale(for id: UUID) -> Double {
        maxScale(for: id, on: screenFrame(for: id))
    }

    /// As `maxScale(for:)`, but for a display the widget is about to move to —
    /// its stored origin still points at the display it's leaving.
    func maxScale(for id: UUID, on frame: CGRect) -> Double {
        let base = baseSize(for: id)
        let byWidth = (frame.width - WidgetShellMetrics.insetSide * 2) / base.width
        let byHeight = (frame.height - WidgetShellMetrics.insetTop - WidgetShellMetrics.insetBottom) / base.height
        // Floor of 1.0 only guards against a degenerate slider range on a tiny
        // display; it is not a licence to overflow the screen.
        return max(1.0, min(byWidth, byHeight))
    }

    // MARK: Writes

    func chromeBinding(for id: UUID) -> Binding<WidgetChrome> {
        Binding(
            get: { [weak self] in self?.chrome(for: id) ?? WidgetChrome() },
            set: { [weak self] newValue in self?.updateChrome(id, newValue) }
        )
    }

    func configBinding<C: WidgetConfig>(for id: UUID, as type: C.Type) -> Binding<C> {
        Binding(
            get: { [weak self] in self?.config(for: id, as: C.self) ?? C.defaults },
            set: { [weak self] newValue in self?.updateConfig(id, newValue) }
        )
    }

    func updateChrome(_ id: UUID, _ chrome: WidgetChrome) {
        guard let index = instances.firstIndex(where: { $0.id == id }) else { return }
        let previous = instances[index].chrome
        guard previous != chrome else { return }
        instances[index].chrome = chrome
        // A deliberate resize is part of "where I put this widget", so it belongs
        // in the placement for the display it's on — but only if the widget is
        // already homed there. Resizing a widget that is sitting on a stand-in
        // display (because its own monitor is unplugged) must not claim that
        // display, or it would never go home.
        if previous.scale != chrome.scale { rememberScaleForCurrentScreen(id) }
        instanceChanged.send(id)
        save()
    }

    /// Applies a scale the app decided on rather than the user: fitting a widget
    /// to a smaller display, or restoring the size it had on a display that just
    /// came back. Deliberately leaves `placements` alone so the size the user
    /// chose is still there when the bigger screen returns.
    func applyScaleWithoutRemembering(_ id: UUID, _ scale: Double) {
        guard let index = instances.firstIndex(where: { $0.id == id }),
              instances[index].chrome.scale != scale
        else { return }
        instances[index].chrome.scale = scale
        instanceChanged.send(id)
        save()
    }

    func updateConfig<C: WidgetConfig>(_ id: UUID, _ config: C) {
        guard let existing = configs[id] as? C, existing != config else {
            configs[id] = config
            instanceChanged.send(id)
            save()
            return
        }
        configs[id] = config
        instanceChanged.send(id)
        save()
    }

    /// Records where a panel currently *is* without triggering a geometry
    /// re-apply loop, and without claiming it as the widget's home.
    ///
    /// Used for positions the app chose — a widget parked on the built-in display
    /// while its own monitor is away, say. The remembered placement is untouched,
    /// which is what makes that relocation reversible.
    func recordOrigin(_ id: UUID, topLeft: CGPoint) {
        guard let index = instances.firstIndex(where: { $0.id == id }) else { return }
        instances[index].chrome.originX = topLeft.x
        instances[index].chrome.originY = topLeft.y
        save()
    }

    /// Records where the user *put* a panel: the live origin plus a durable,
    /// display-relative placement that outlives the display being unplugged.
    func rememberPlacement(_ id: UUID, topLeft: CGPoint) {
        guard let index = instances.firstIndex(where: { $0.id == id }) else { return }
        instances[index].chrome.originX = topLeft.x
        instances[index].chrome.originY = topLeft.y
        if let screen = ScreenIdentity.screen(containing: topLeft),
           let key = ScreenIdentity.key(for: screen) {
            instances[index].chrome.placements[key] = WidgetPlacement(
                topLeft: topLeft,
                on: screen.frame,
                scale: instances[index].chrome.scale
            )
        }
        save()
    }

    /// Keeps the current display's remembered scale in step with a user resize.
    /// Only updates a placement that already exists — see `updateChrome`.
    private func rememberScaleForCurrentScreen(_ id: UUID) {
        guard let index = instances.firstIndex(where: { $0.id == id }) else { return }
        let chrome = instances[index].chrome
        guard let x = chrome.originX, let y = chrome.originY,
              let screen = ScreenIdentity.screen(containing: CGPoint(x: x, y: y)),
              let key = ScreenIdentity.key(for: screen),
              chrome.placements[key] != nil
        else { return }
        // Scale only: `updatedAt` stays put deliberately. It ranks *placements*,
        // and resizing a widget isn't a statement about which display it lives
        // on — bumping it here would let a resize on a stand-in display outrank
        // the monitor the widget actually belongs to.
        instances[index].chrome.placements[key]?.scale = chrome.scale
    }

    // MARK: App settings

    func settingsBinding<V>(_ path: WritableKeyPath<AppSettings, V>) -> Binding<V> {
        Binding(
            get: { [weak self] in (self?.settings ?? AppSettings())[keyPath: path] },
            set: { [weak self] newValue in
                guard let self else { return }
                var next = self.settings
                next[keyPath: path] = newValue
                self.updateSettings(next)
            }
        )
    }

    func updateSettings(_ next: AppSettings) {
        guard next != settings else { return }
        let loginChanged = next.launchAtLogin != settings.launchAtLogin
        settings = next
        if loginChanged {
            LoginItemManager.setEnabled(next.launchAtLogin)
            // Reflect what actually happened rather than what was asked for.
            settings.launchAtLogin = LoginItemManager.isEnabled
        }
        settingsChanged.send(settings)
        save()
    }

    // MARK: Roster

    @discardableResult
    func addWidget(kind: String) -> UUID? {
        guard let type = WidgetRegistry.type(for: kind) else { return nil }
        var instance = WidgetInstance(kind: kind)
        instance.chrome = Self.defaultChrome(for: kind)
        configs[instance.id] = type.decodeConfig(type.defaultConfigData())
        instances.append(instance)
        rosterChanged.send(())
        save()
        return instance.id
    }

    func removeWidget(_ id: UUID) {
        instances.removeAll { $0.id == id }
        configs[id] = nil
        rosterChanged.send(())
        save()
    }

    func duplicateWidget(_ id: UUID) {
        guard let source = instance(id), let cfg = configs[id] else { return }
        var copy = source
        copy.id = UUID()
        copy.chrome.originX = (source.chrome.originX ?? 80) + 32
        copy.chrome.originY = (source.chrome.originY ?? 80) - 32
        // Not the original's remembered spot — the copy would restore straight
        // back on top of it the next time a display changed.
        copy.chrome.placements = [:]
        configs[copy.id] = cfg
        instances.append(copy)
        rosterChanged.send(())
        save()
    }

    func resetConfig(_ id: UUID) {
        guard let type = type(of: id) else { return }
        configs[id] = type.decodeConfig(type.defaultConfigData())
        if let index = instances.firstIndex(where: { $0.id == id }) {
            let wasVisible = instances[index].chrome.isVisible
            instances[index].chrome = Self.defaultChrome(for: instances[index].kind)
            instances[index].chrome.isVisible = wasVisible
        }
        instanceChanged.send(id)
        save()
    }

    /// Clears saved positions so every visible widget is re-laid out on screen.
    func rescueOffscreenWidgets() {
        for index in instances.indices {
            instances[index].chrome.originX = nil
            instances[index].chrome.originY = nil
            instances[index].chrome.placements = [:]
            instances[index].chrome.isLocked = false
        }
        for instance in instances { instanceChanged.send(instance.id) }
        save()
    }

    // MARK: Persistence

    private func save(immediately: Bool = false) {
        saveWorkItem?.cancel()
        let write: () -> Void = { [weak self] in self?.writeDocument() }
        if immediately {
            write()
            return
        }
        let item = DispatchWorkItem(block: write)
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: item)
    }

    func flush() { save(immediately: true) }

    private func writeDocument() {
        var doc = WidgetDocument()
        doc.settings = settings
        doc.instances = instances.map { instance in
            var copy = instance
            if let cfg = configs[instance.id] {
                copy.configData = encode(cfg)
            }
            return copy
        }
        do {
            try FileManager.default.createDirectory(at: Self.supportDirectory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(doc)
            try data.write(to: Self.documentURL, options: .atomic)
        } catch {
            NSLog("ClockAndCalendar: failed to save state - \(error)")
        }
    }

    /// Encodes an existential config without knowing its concrete type.
    private func encode(_ config: any WidgetConfig) -> Data? {
        func inner<C: WidgetConfig>(_ value: C) -> Data? { try? JSONEncoder().encode(value) }
        return inner(config)
    }
}
