import Combine
import SwiftUI

/// The few strap facts the Aura screens draw.
///
/// `LiveState` publishes sixty-odd properties — the BLE log, R-R buffers, raw sample windows, offload
/// counters — and a view that observes it re-renders on every one of them: dozens of times a second
/// during a sync. The shell and Today used to observe it directly, so the whole app re-laid itself out
/// behind every log line. Observe this instead. It republishes only when one of these values changes.
@MainActor
final class NoopLiveGlance: ObservableObject {
    @Published private(set) var connected = false
    @Published private(set) var bonded = false
    @Published private(set) var heartRate: Int?
    /// Whole percent, so a millivolt wobble that rounds to the same figure redraws nothing.
    @Published private(set) var batteryPercent: Int?
    /// A history offload is running: the battery pill draws its sync line.
    @Published private(set) var syncing = false

    private var bound: ObjectIdentifier?
    private var subscriptions: Set<AnyCancellable> = []

    /// Idempotent: binding the same `LiveState` twice keeps the first subscription.
    func bind(to live: LiveState) {
        let id = ObjectIdentifier(live)
        guard bound != id else { return }
        bound = id
        subscriptions.removeAll()

        connected = live.connected
        bonded = live.bonded
        heartRate = live.heartRate
        batteryPercent = live.batteryPct.map { Int($0.rounded()) }
        syncing = live.backfilling

        live.$connected.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.connected = $0 }.store(in: &subscriptions)
        live.$bonded.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.bonded = $0 }.store(in: &subscriptions)
        live.$heartRate.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.heartRate = $0 }.store(in: &subscriptions)
        live.$batteryPct.map { $0.map { Int($0.rounded()) } }.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.batteryPercent = $0 }.store(in: &subscriptions)
        live.$backfilling.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.syncing = $0 }.store(in: &subscriptions)
    }
}
