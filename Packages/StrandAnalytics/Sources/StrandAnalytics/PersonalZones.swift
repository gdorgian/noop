import Foundation
import WhoopProtocol

// PersonalZones.swift — zones from what the strap has seen on the wearer, not from their age.
//
// Two measured numbers replace the age formula once there is enough data:
//
//  • RESTING PULSE, the floor. Taken from the overnight resting rate the app already scores. Zones then sit
//    on the heart-rate RESERVE (Karvonen: resting + fraction × (max − resting)), so two people with the same
//    maximum but different resting rates get different zones, as their hearts actually differ.
//
//  • A HELD PEAK, the ceiling. The highest pulse held for 30 seconds inside a workout. Holding it rules out
//    a one-beat optical spike and a strap that briefly locked onto cadence. It only ever RAISES the maximum
//    in use: a wearer who never trains hard has a low observed peak, and that says nothing about their real
//    maximum. Lowering the maximum on that evidence would score every session as harder than it was.
//
// A higher held peak is offered, never applied silently, because the maximum also feeds Effort: taking it
// changes how sessions score from that day on. Effort already scored is left as it is.

/// The highest heart rate held for a window inside a stretch of samples.
public enum HeldPeak {

    /// Seconds a pulse must be held to count.
    public static let window = 30
    /// A window must hold at least this share of its seconds as samples (the strap runs at about 1 Hz).
    public static let minimumDensity = 0.8
    /// A gap longer than this inside a window breaks it: a held level needs a continuous trace.
    public static let maximumGap = 5
    /// Readings outside this range are sensor noise, not a heart rate.
    public static let plausible = 40...230

    /// The highest level every sample of some `window`-second stretch stayed at or above, or nil when no
    /// stretch is dense and continuous enough. That is the minimum of the window, maximised over windows:
    /// the level the heart actually held, not the brief top of it.
    public static func heldPeak(_ samples: [HRSample], window: Int = window) -> Int? {
        let s = samples.filter { plausible.contains($0.bpm) }.sorted { $0.ts < $1.ts }
        guard s.count >= 2 else { return nil }
        let needed = Int((Double(window) * minimumDensity).rounded(.up))
        var best: Int?
        var lo = 0
        // Monotonic deque of indices whose bpm increases, so its front is the window minimum.
        var deque: [Int] = []
        var head = 0
        for hi in s.indices {
            // A gap breaks continuity: restart the window after it.
            if hi > 0, s[hi].ts - s[hi - 1].ts > maximumGap {
                lo = hi
                deque.removeAll(keepingCapacity: true)
                head = 0
            }
            while deque.count > head, s[deque[deque.count - 1]].bpm >= s[hi].bpm { deque.removeLast() }
            deque.append(hi)
            while s[hi].ts - s[lo].ts > window - 1 { lo += 1 }
            while head < deque.count, deque[head] < lo { head += 1 }
            let span = s[hi].ts - s[lo].ts + 1
            guard span >= window - 1, hi - lo + 1 >= needed, head < deque.count else { continue }
            let held = s[deque[head]].bpm
            if best.map({ held > $0 }) ?? true { best = held }
        }
        return best
    }
}

/// Whether to offer a higher maximum, and which.
public enum MaxHRSuggestion {

    /// One workout's held peak and the local day it fell on.
    public struct Peak: Equatable, Sendable {
        public let day: String
        public let bpm: Int
        public init(day: String, bpm: Int) { self.day = day; self.bpm = bpm }
    }

    /// How far above the maximum in use a peak must sit before it is worth offering.
    public static let margin = 3
    /// Distinct days that must reach the offered level, so one odd session never moves anything.
    public static let daysNeeded = 2

    /// The maximum to offer, or nil. `peaks` come from the last six months of workouts; `current` is the
    /// maximum in use; `declined` is a value the wearer turned down, which is not offered again until the
    /// evidence clears it. The offer is the level reached on at least `daysNeeded` days, so the second
    /// highest day's peak: the highest level two separate days agree on.
    public static func suggestion(peaks: [Peak], current: Int, declined: Int?) -> Int? {
        var byDay: [String: Int] = [:]
        for p in peaks { byDay[p.day] = max(byDay[p.day] ?? 0, p.bpm) }
        let ranked = byDay.values.sorted(by: >)
        guard ranked.count >= daysNeeded else { return nil }
        let offer = ranked[daysNeeded - 1]
        guard offer >= current + margin else { return nil }
        if let declined, offer <= declined { return nil }
        return offer
    }
}

/// Zones on the heart-rate reserve.
public enum ReserveZones {

    /// The five lower edges as fractions of the reserve. The same 50/60/70/80/90 steps as the %HRmax zones,
    /// measured from the resting floor instead of from zero.
    public static let fractions: [Double] = [0.50, 0.60, 0.70, 0.80, 0.90]

    /// Nights of resting pulse needed before the floor is trusted.
    public static let nightsNeeded = 14

    /// The five lower edges in bpm, or nil when the inputs cannot make a reserve.
    public static func lowerBounds(resting: Double, maxHR: Double) -> [Double]? {
        guard resting >= 30, maxHR > resting + 40 else { return nil }
        return fractions.map { (resting + $0 * (maxHR - resting)).rounded() }
    }

    /// The resting floor to build on: the median of the last `nightsNeeded` nights, or nil with fewer.
    /// The median, so one feverish or short night does not move every zone.
    public static func restingFloor(nightly: [Int]) -> Double? {
        let recent = nightly.suffix(nightsNeeded).filter { (30...110).contains($0) }.sorted()
        guard recent.count >= nightsNeeded else { return nil }
        let mid = recent.count / 2
        return recent.count.isMultiple(of: 2)
            ? Double(recent[mid - 1] + recent[mid]) / 2 : Double(recent[mid])
    }
}
