import Foundation

// ActivityBoutDetector.swift — finds the workouts a wearer did without starting one, so they can be
// logged automatically as "detected" activities the wearer may rename, correct or delete.
//
// Why a new detector. `AutoWorkoutDetector` asks for twelve unbroken minutes at resting + 30 bpm and
// ends a bout at any dip longer than ninety seconds. That shape misses exactly the sessions people
// most often forget to start: lifting (two- to three-minute rests between sets fall below the line),
// intervals, swimming (lengths and wall rests), and any easy session by a fit wearer, for whom
// +30 bpm is already moderate work. It is kept as the shadow baseline; this one replaces it on screen.
//
// Method — Noop Aura's own, from published physiology:
//
//  1. Minutes. Heart rate is binned into calendar minutes; a minute needs `minCoverageS` seconds of
//     samples. Each minute's mean is expressed as heart-rate reserve, r = (HR − rest) / (max − rest)
//     (Karvonen), so one rule fits a resting pulse of 45 and one of 70. Optional motion (gravity change
//     per second) and step ticks are averaged into the same minutes.
//
//  2. Bouts, with hysteresis. A bout starts at a minute with r ≥ `startReserve` and continues while
//     minutes stay at r ≥ `holdReserve`. Recovery is not the end of a session: up to `restToleranceMin`
//     minutes below the hold line are bridged while the pulse stays at r ≥ `recoveryReserve` — the
//     elevated floor between sets and lengths — and up to `dipToleranceMin` minutes below that. A gap
//     in the recording longer than `maxGapMin` always ends a bout: missing time is not exercise.
//     Ends are trimmed back to the first and last minute at the start line.
//
//  3. Significance. A bout is an activity when it lasts at least `minDurationMin` AND its accumulated
//     training impulse (Banister TRIMP, Σ r·0.75·e^(1.795·r) per minute, sex-neutral) reaches
//     `minTrimp` — "significant enough", rather than a stopwatch. Sleep windows never qualify.
//
//  4. Not stress, not coffee, not a hot room. Those raise the pulse modestly and without movement.
//     When motion is recorded, a bout needs movement in at least `minActiveFraction` of its minutes,
//     or `minHardMinutes` minutes at r ≥ `hardReserve` (a hard effort the wrist barely shows, such as
//     cycling). With no motion recorded, the hard-minutes rule is required.
//
//  5. Sport, only when the evidence is strong. Naming is `WorkoutTypeClassifier`'s job (it reads the
//     strap's own still/walk/run class and motion); this detector adds one shape it can see in heart
//     rate alone: a pulse that rises and falls in repeated 1.5- to 5-minute cycles is sets and rests.
//     Anything else is a generic Activity the wearer names — a wrong sport is worse than no sport.
//
// Pure and headless: no I/O, no clock. Timestamps are unix seconds. Not medical advice.

public enum ActivityBoutDetector {

    // MARK: Tunables

    public static let minCoverageS = 20
    public static let startReserve = 0.30
    public static let holdReserve = 0.22
    public static let recoveryReserve = 0.12
    public static let restToleranceMin = 5
    public static let dipToleranceMin = 2
    public static let maxGapMin = 3
    public static let minDurationMin = 10
    public static let minTrimp = 4.5
    public static let hardReserve = 0.35
    public static let minHardMinutes = 5
    public static let activeMotion = 0.05
    public static let minActiveFraction = 0.4
    /// Two bouts closer than this are one session (a superset, a drink, changing machines).
    public static let mergeGapMin = 6

    // MARK: Types

    public enum Sport: String, Sendable, CaseIterable {
        case strength, activity
    }

    public struct Bout: Equatable, Sendable {
        public let startSec: Int
        public let endSec: Int
        public let avgBpm: Int
        public let peakBpm: Int
        public let trimp: Double
        public let sport: Sport
        /// Why it qualified, for the Test Centre trace.
        public let reason: String

        public var durationMin: Int { (endSec - startSec) / 60 }
    }

    public struct Span: Equatable, Sendable {
        public let startSec: Int
        public let endSec: Int
        public init(startSec: Int, endSec: Int) {
            self.startSec = startSec
            self.endSec = endSec
        }
        func overlaps(_ s: Int, _ e: Int) -> Bool { s <= endSec && e >= startSec }
    }

    struct Minute {
        let start: Int
        var hrSum = 0.0, hrCount = 0, peak = 0
        var motionSum = 0.0, motionCount = 0
        var mean: Double { hrCount > 0 ? hrSum / Double(hrCount) : 0 }
        var motion: Double? { motionCount > 0 ? motionSum / Double(motionCount) : nil }
    }

    // MARK: Detection

    /// - Parameters:
    ///   - hr: heart-rate samples, any order.
    ///   - restingBpm / maxBpm: the wearer's resting baseline and maximum (the same max their zones use).
    ///   - motion: optional per-second motion intensity (gravity change), same scale as `AutoWorkoutDetector`.
    ///   - sleep: windows the wearer was asleep; no bout may overlap one.
    ///   - exclude: already-logged or dismissed workouts; a bout overlapping one is dropped.
    public static func detect(hr: [(ts: Int, bpm: Int)], restingBpm: Double, maxBpm: Double,
                              motion: [(ts: Int, intensity: Double)] = [],
                              sleep: [Span] = [], exclude: [Span] = []) -> [Bout] {
        guard maxBpm > restingBpm + 20, hr.count > 1 else { return [] }
        let minutes = bin(hr: hr, motion: motion)
        guard !minutes.isEmpty else { return [] }
        let r: (Minute) -> Double = { ($0.mean - restingBpm) / (maxBpm - restingBpm) }

        // 2. Bouts with hysteresis, recovery tolerance and gap breaks. Indices into `minutes`.
        var raw: [(Int, Int)] = []
        var i = 0
        while i < minutes.count {
            guard r(minutes[i]) >= startReserve else { i += 1; continue }
            var lastStrong = i          // last minute at the start line
            var j = i
            var restRun = 0, dipRun = 0
            while j + 1 < minutes.count {
                let next = minutes[j + 1]
                if (next.start - minutes[j].start) / 60 > maxGapMin { break }
                let rv = r(next)
                if rv >= holdReserve {
                    restRun = 0; dipRun = 0
                } else if rv >= recoveryReserve {
                    restRun += 1
                    if restRun > restToleranceMin { break }
                } else {
                    dipRun += 1
                    restRun += 1
                    if dipRun > dipToleranceMin || restRun > restToleranceMin { break }
                }
                j += 1
                if rv >= startReserve { lastStrong = j }
            }
            raw.append((i, lastStrong))
            i = j + 1
        }

        // Merge near bouts that belong to one session, never across a recording gap.
        var merged: [(Int, Int)] = []
        for b in raw {
            if let last = merged.last,
               (minutes[b.0].start - minutes[last.1].start) / 60 <= mergeGapMin,
               !hasGap(minutes, from: last.1, to: b.0) {
                merged[merged.count - 1].1 = b.1
            } else {
                merged.append(b)
            }
        }

        // 3–5. Qualify and describe.
        var out: [Bout] = []
        for (a, b) in merged {
            let span = Array(minutes[a...b])
            let start = span.first!.start, end = span.last!.start + 60
            guard (end - start) / 60 >= minDurationMin else { continue }
            guard !sleep.contains(where: { $0.overlaps(start, end) }),
                  !exclude.contains(where: { $0.overlaps(start, end) }) else { continue }
            let reserves = span.map(r)
            let trimp = reserves.reduce(0) { acc, x in
                let rr = min(1, max(0, x))
                return acc + rr * 0.75 * exp(1.795 * rr)
            }
            guard trimp >= minTrimp else { continue }
            let hard = reserves.filter { $0 >= hardReserve }.count
            let withMotion = span.compactMap(\.motion)
            let reason: String
            if withMotion.count >= span.count / 2 {
                let active = Double(withMotion.filter { $0 >= activeMotion }.count) / Double(withMotion.count)
                guard active >= minActiveFraction || hard >= minHardMinutes else { continue }
                reason = active >= minActiveFraction ? "movement \(Int(active * 100))%" : "hard minutes \(hard)"
            } else {
                guard hard >= minHardMinutes else { continue }
                reason = "hard minutes \(hard), no motion recorded"
            }
            let total = span.reduce(0) { $0 + $1.hrSum }, count = span.reduce(0) { $0 + $1.hrCount }
            out.append(Bout(startSec: start, endSec: end,
                            avgBpm: Int((total / Double(max(1, count))).rounded()),
                            peakBpm: span.map(\.peak).max() ?? 0,
                            trimp: trimp, sport: sport(span, reserves: reserves),
                            reason: reason))
        }
        return out
    }

    // MARK: Pieces

    static func bin(hr: [(ts: Int, bpm: Int)], motion: [(ts: Int, intensity: Double)]) -> [Minute] {
        var byMinute: [Int: Minute] = [:]
        for s in hr where s.bpm > 25 && s.bpm < 230 {
            let m = s.ts / 60 * 60
            var x = byMinute[m] ?? Minute(start: m)
            x.hrSum += Double(s.bpm); x.hrCount += 1; x.peak = max(x.peak, s.bpm)
            byMinute[m] = x
        }
        // Coverage: a sample stands for the seconds until the next one, capped, so 1 Hz and sparser
        // live sampling both count fairly.
        let sorted = hr.map(\.ts).sorted()
        var covered: [Int: Int] = [:]
        for (k, t) in sorted.enumerated() {
            let next = k + 1 < sorted.count ? sorted[k + 1] : t + 1
            covered[t / 60 * 60, default: 0] += min(max(1, next - t), 15)
        }
        for p in motion {
            let m = p.ts / 60 * 60
            guard var x = byMinute[m] else { continue }
            x.motionSum += p.intensity; x.motionCount += 1
            byMinute[m] = x
        }
        return byMinute.values
            .filter { (covered[$0.start] ?? 0) >= minCoverageS }
            .sorted { $0.start < $1.start }
    }

    static func hasGap(_ minutes: [Minute], from a: Int, to b: Int) -> Bool {
        guard a < b else { return false }
        for k in a..<b where (minutes[k + 1].start - minutes[k].start) / 60 > maxGapMin { return true }
        return false
    }

    static func sport(_ span: [Minute], reserves: [Double]) -> Sport {
        cycles(reserves) >= 4 ? .strength : .activity
    }

    /// Rise-and-fall cycles in the reserve series: peaks at least 0.08 above both neighbouring troughs,
    /// spaced 1.5–5 minutes apart — the shape of sets and rests, or of intervals.
    static func cycles(_ x: [Double]) -> Int {
        guard x.count >= 5 else { return 0 }
        var peaks: [Int] = []
        for k in 1..<(x.count - 1) where x[k] > x[k - 1] && x[k] >= x[k + 1] {
            let leftMin = x[max(0, k - 3)..<k].min() ?? x[k]
            let rightMin = x[(k + 1)...min(x.count - 1, k + 3)].min() ?? x[k]
            if x[k] - leftMin >= 0.08 && x[k] - rightMin >= 0.08 { peaks.append(k) }
        }
        var n = 0
        for (a, b) in zip(peaks, peaks.dropFirst()) where (2...5).contains(b - a) { n += 1 }
        return n
    }
}
