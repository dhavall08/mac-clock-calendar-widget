import Combine
import Foundation

/// One shared clock for the whole app.
///
/// `second` ticks every second for the clock widget; `today` only republishes
/// when the calendar day actually rolls over, so calendars don't redraw 86,400
/// times a day.
@MainActor
final class TimeKeeper: ObservableObject {
    static let shared = TimeKeeper()

    @Published private(set) var second: Date = Date()
    @Published private(set) var today: Date = Calendar.current.startOfDay(for: Date())

    private var timer: Timer?

    private init() {
        start()
    }

    private func start() {
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // Keeps ticking while menus are open or a window is being dragged.
        timer.tolerance = 0.15
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let now = Date()
        second = now
        let startOfToday = Calendar.current.startOfDay(for: now)
        if startOfToday != today { today = startOfToday }
    }
}
