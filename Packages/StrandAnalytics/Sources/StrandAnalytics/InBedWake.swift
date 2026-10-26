import Foundation
import WhoopProtocol

// InBedWake.swift — separates time ASLEEP from time awake IN BED at the two edges of a night.
//
// THE PROBLEM. A night's window is the in-bed span: detection opens it when the wrist settles and closes it
// when the wearer gets up. Both stagers then label each 30 s epoch, and both find wake mainly from movement
// bursts. Lying awake but still — reading before sleep, or staying in bed for an hour on the phone after
// waking — has no bursts, so it is staged as light sleep and counted as sleep. The PSG harness
// (`Tools/SleepPSG`) measures the same bias across a whole cohort: the shipped recipe calls about 4 % of the
// night awake where polysomnography scores about 9 %, and finds under a third of true wake epochs.
//
// THE SIGNALS. Quiet wakefulness and sleep differ even when the wrist is still:
//   1. Heart rate. Waking lifts the pulse above the night's sleeping level and it stays there (the
//      cortisol awakening response adds to it in the morning). REM also lifts it, but in short episodes
//      inside a still, atonic body.
//   2. Micro-movement. An awake person shifts, holds a phone, turns a page: small wrist movements most
//      minutes. Asleep, the wrist is still between occasional turn-overs.
//   3. The strap's own per-second sleep state (WHOOP 5.0 / MG), when it was recorded: "wake", or "up"
//      when the pulse rose with it.
// A minute is AWAKE-LIKE when the strap says awake, or the pulse is well above the sleeping level, or the
// pulse is above it while the wrist moves. It is SLEEP-LIKE when the strap says asleep, or the pulse is at
// the sleeping level with a still wrist. Anything else is undecided.
//
// THE RULE. Only the night's edges are examined; interior stages are left to the stager. From the end, the
// final awakening is the first awake-like minute after the last sustained run of sleep-like minutes; from
// the start, sleep onset is the first sustained sleep-like run, and latency runs to the last awake-like
// minute before it. An edge is relabelled "wake" only when awake-like minutes dominate it, and never so
// far that less than an hour of sleep would remain. It only ever turns sleep into wake at an edge. With no
// heart rate the night is returned unchanged: still wrists alone cannot tell the two apart.
//
// Pure and deterministic, no I/O. An approximation from wrist signals, not polysomnography, and not medical
// advice.

public enum InBedWake {

    // MARK: Tunables

    /// Pulse above the sleeping level that counts as raised, as a fraction, and never less than `minRiseBpm`.
    public static let raisedFraction = 0.10
    public static let minRiseBpm = 5.0
    /// Pulse this far above the sleeping level is awake-like even with a still wrist.
    public static let highFraction = 0.20
    /// The sleeping level: this percentile of the per-minute pulse across minutes staged as sleep.
    public static let sleepingPercentile = 0.40
    /// A minute moves when its summed wrist movement is this many times the night's typical sleeping minute,
    /// and above `minMoveG`.
    public static let moveMultiple = 2.5
    public static let minMoveG = 0.01
    /// Consecutive sleep-like minutes that count as being asleep.
    public static let sustainedSleepMin = 5
    /// Share of an edge's decided minutes that must be awake-like before it is relabelled.
    public static let tailAwakeShare = 0.6
    public static let headAwakeShare = 0.5
    /// Edges shorter than this are left to the stager.
    public static let minEdgeMin = 5
    /// Sleep that must remain after both edges.
    public static let minRemainingSleepMin = 60
    /// Strap sleep states (see `SleepStager.applyBandStateWakeVeto`): 0 wake, 1 still, 2 asleep, 3 up.
    static let bandWake = 0, bandAsleep = 2, bandUp = 3

    // MARK: Output

    public struct Edges: Equatable, Sendable {
        /// Minutes relabelled at the start (falling asleep) and at the end (awake in bed after the final waking).
        public let latencyMin: Int
        public let afterWakeMin: Int
    }

    enum Evidence: Equatable { case awake, asleep, undecided }

    // MARK: Refinement

    /// Relabels the awake edges of a staged night. `stages` must tile `[start, end]`.
    public static func refine(_ stages: [StageSegment], start: Int, end: Int,
                              hr: [HRSample], grav: [GravitySample],
                              bandSleepState: [(ts: Int, state: Int)] = []) -> [StageSegment] {
        guard let (wakeEnd, wakeStart) = edges(stages, start: start, end: end, hr: hr, grav: grav,
                                               bandSleepState: bandSleepState) else { return stages }
        return relabel(stages, wakeUntil: wakeEnd, wakeFrom: wakeStart)
    }

    /// How many minutes `refine` relabels at each edge, for traces and tests.
    public static func measure(_ stages: [StageSegment], start: Int, end: Int,
                               hr: [HRSample], grav: [GravitySample],
                               bandSleepState: [(ts: Int, state: Int)] = []) -> Edges {
        guard let (wakeEnd, wakeStart) = edges(stages, start: start, end: end, hr: hr, grav: grav,
                                               bandSleepState: bandSleepState) else {
            return Edges(latencyMin: 0, afterWakeMin: 0)
        }
        return Edges(latencyMin: max(0, wakeEnd - start) / 60, afterWakeMin: max(0, end - wakeStart) / 60)
    }

    /// `(wake until, wake from)`: the in-bed time before the first moment and after the second is awake.
    /// nil when nothing changes.
    static func edges(_ stages: [StageSegment], start: Int, end: Int,
                      hr: [HRSample], grav: [GravitySample],
                      bandSleepState: [(ts: Int, state: Int)]) -> (Int, Int)? {
        guard end - start >= 2 * 3600, !stages.isEmpty else { return nil }
        let n = (end - start) / 60
        let minuteHR = smoothed(perMinuteHR(hr, start: start, n: n))
        guard minuteHR.compactMap({ $0 }).count >= n / 2 else { return nil }
        let staged = stagedAsleep(stages, start: start, n: n)
        let sleepHRs = (0..<n).compactMap { staged[$0] ? minuteHR[$0] : nil }.sorted()
        guard sleepHRs.count >= 30 else { return nil }
        let sleeping = sleepHRs[Int(Double(sleepHRs.count - 1) * sleepingPercentile)]
        let raised = sleeping + max(minRiseBpm, sleeping * raisedFraction)
        let high = sleeping + max(minRiseBpm * 2, sleeping * highFraction)

        let move = perMinuteMovement(grav, start: start, n: n)
        let sleepMoves = (0..<n).compactMap { staged[$0] ? move[$0] : nil }.sorted()
        let moveLine: Double? = sleepMoves.count >= 30
            ? max(minMoveG, sleepMoves[sleepMoves.count / 2] * moveMultiple) : nil
        let band = perMinuteBand(pulseCheckedBand(bandSleepState, hr: hr), start: start, n: n)

        let evidence: [Evidence] = (0..<n).map { m in
            if let b = band[m] {
                if b == bandWake || b == bandUp { return .awake }
                if b == bandAsleep { return .asleep }
            }
            guard let h = minuteHR[m] else { return .undecided }
            let moving: Bool? = moveLine.flatMap { line in move[m].map { $0 >= line } }
            if h >= high { return .awake }
            if h >= raised, moving == true { return .awake }
            if h < raised, moving != true { return .asleep }
            return .undecided
        }

        // Final awakening: after the last sustained sleep-like run, the first awake-like minute.
        var tail = n
        if let lastRun = lastSustainedRunEnd(evidence) {
            if let first = (lastRun..<n).first(where: { evidence[$0] == .awake }),
               dominated(evidence[first..<n], share: tailAwakeShare), n - first >= minEdgeMin {
                tail = first
            }
        }
        // Sleep onset: before the first sustained sleep-like run, through the last awake-like minute.
        var head = 0
        if let firstRun = firstSustainedRunStart(evidence), firstRun > 0,
           let last = (0..<firstRun).last(where: { evidence[$0] == .awake }),
           dominated(evidence[0...last], share: headAwakeShare), last + 1 >= minEdgeMin {
            head = last + 1
        }
        // The strap's own onset bounds it: lying still in bed with a film reads sleep-like above for hours.
        if let strap = strapOnset(band) { head = max(head, strap) }
        guard head > 0 || tail < n else { return nil }
        // Never leave less than an hour of sleep: drop the head first, then the tail.
        let remaining = { (h: Int, t: Int) in (h..<max(h, t)).filter { staged[$0] }.count }
        if remaining(head, tail) < minRemainingSleepMin { head = 0 }
        if remaining(head, tail) < minRemainingSleepMin { tail = n }
        guard head > 0 || tail < n else { return nil }
        return (start + head * 60, tail >= n ? end : start + tail * 60)
    }

    // MARK: Pieces

    /// Minutes of the strap's "asleep" in a row that count as its sleep onset.
    public static let strapSustainedAsleepMin = 10
    /// Share of the minutes before that onset the strap must have recorded for it to bound the night.
    public static let strapCoverage = 0.8

    /// The minute after the strap's last "wake" (or pulse-confirmed "up") before its first sustained
    /// "asleep". Going to bed the strap reads wake, then "still", then asleep. On four WHOOP 5.0 nights
    /// (23–26 Oct 2026) sleep began within 4 minutes of that point by Fitbit, including a night spent
    /// awake in bed from 23:00 to 03:00 at a pulse near the sleeping level, which the pulse-and-movement
    /// rule took for sleep from 01:56. nil without a recorded strap state, or with no "wake" before onset.
    static func strapOnset(_ band: [Int?]) -> Int? {
        var run = 0, onset: Int?
        for m in band.indices {
            run = band[m] == bandAsleep ? run + 1 : 0
            if run >= strapSustainedAsleepMin { onset = m - run + 1; break }
        }
        guard let onset, onset > 0 else { return nil }
        let recorded = band[0..<onset].compactMap { $0 }.count
        guard Double(recorded) >= Double(onset) * strapCoverage else { return nil }
        return (0..<onset).last(where: { band[$0] == bandWake || band[$0] == bandUp }).map { $0 + 1 }
    }

    static func dominated(_ e: ArraySlice<Evidence>, share: Double) -> Bool {
        let awake = e.filter { $0 == .awake }.count, asleep = e.filter { $0 == .asleep }.count
        return awake + asleep > 0 && Double(awake) / Double(awake + asleep) >= share
    }

    /// Index just past the last run of `sustainedSleepMin` sleep-like minutes.
    static func lastSustainedRunEnd(_ e: [Evidence]) -> Int? {
        var run = 0
        for m in stride(from: e.count - 1, through: 0, by: -1) {
            run = e[m] == .asleep ? run + 1 : 0
            if run >= sustainedSleepMin { return m + run }
        }
        return nil
    }

    static func firstSustainedRunStart(_ e: [Evidence]) -> Int? {
        var run = 0
        for m in e.indices {
            run = e[m] == .asleep ? run + 1 : 0
            if run >= sustainedSleepMin { return m - run + 1 }
        }
        return nil
    }

    static func perMinuteHR(_ hr: [HRSample], start: Int, n: Int) -> [Double?] {
        var sum = [Double](repeating: 0, count: n), count = [Int](repeating: 0, count: n)
        for s in hr where s.ts >= start && s.bpm > 25 && s.bpm < 230 {
            let m = (s.ts - start) / 60
            guard m < n else { continue }
            sum[m] += Double(s.bpm); count[m] += 1
        }
        return (0..<n).map { count[$0] >= 5 ? sum[$0] / Double(count[$0]) : nil }
    }

    /// Three-minute centred median, so a single REM spike or a cough does not read as waking.
    static func smoothed(_ x: [Double?]) -> [Double?] {
        x.indices.map { i in
            guard x[i] != nil else { return nil }
            let w = (max(0, i - 1)...min(x.count - 1, i + 1)).compactMap { x[$0] }.sorted()
            return w[w.count / 2]
        }
    }

    static func perMinuteMovement(_ grav: [GravitySample], start: Int, n: Int) -> [Double?] {
        var sum = [Double](repeating: 0, count: n), count = [Int](repeating: 0, count: n)
        var prev: GravitySample?
        for g in grav where g.ts >= start {
            defer { prev = g }
            let m = (g.ts - start) / 60
            guard m < n else { break }
            count[m] += 1
            guard let p = prev, g.ts - p.ts <= 60 else { continue }
            let dx = p.x - g.x, dy = p.y - g.y, dz = p.z - g.z
            sum[m] += (dx * dx + dy * dy + dz * dz).squareRoot()
        }
        return (0..<n).map { count[$0] >= 2 ? sum[$0] : nil }
    }

    /// The strap's states with every "up" run the pulse does not confirm dropped (the same check as
    /// `SleepStager.bandUpCut`). The strap calls "up" while the wearer lies still and asleep — 70 minutes
    /// of it one morning at a sleeping pulse, while Fitbit on the same wrist scored REM and light — so an
    /// unconfirmed "up" is left to the pulse and movement evidence instead of counting as awake.
    static func pulseCheckedBand(_ band: [(ts: Int, state: Int)], hr: [HRSample]) -> [(ts: Int, state: Int)] {
        let sorted = band.sorted { $0.ts < $1.ts }
        var out: [(ts: Int, state: Int)] = [], run: [(ts: Int, state: Int)] = []
        func flush() {
            if let first = run.first, SleepStager.hrConfirmsUp(at: first.ts, hr: hr) { out += run }
            run = []
        }
        for b in sorted {
            if b.state == bandUp {
                if let last = run.last, b.ts - last.ts > SleepStager.bandUpMaxGapS { flush() }
                run.append(b)
            } else {
                flush()
                out.append(b)
            }
        }
        flush()
        return out
    }

    static func perMinuteBand(_ band: [(ts: Int, state: Int)], start: Int, n: Int) -> [Int?] {
        guard !band.isEmpty else { return [Int?](repeating: nil, count: n) }
        var tally = [[Int: Int]](repeating: [:], count: n)
        for b in band where b.ts >= start {
            let m = (b.ts - start) / 60
            guard m < n else { continue }
            tally[m][b.state, default: 0] += 1
        }
        return tally.map { $0.max { $0.value < $1.value }?.key }
    }

    static func stagedAsleep(_ stages: [StageSegment], start: Int, n: Int) -> [Bool] {
        (0..<n).map { m in
            let t = start + m * 60 + 30
            guard let s = stages.first(where: { $0.start <= t && t < $0.end }) else { return false }
            return !SleepStageVocabulary.isWake(s.stage)
        }
    }

    /// Marks `[start, wakeUntil)` and `[wakeFrom, end]` as wake; the rest keeps its stages.
    static func relabel(_ stages: [StageSegment], wakeUntil: Int, wakeFrom: Int) -> [StageSegment] {
        var out: [StageSegment] = []
        func add(_ s: Int, _ e: Int, _ stage: String) {
            guard e > s else { return }
            if let last = out.last, last.stage == stage, last.end == s {
                out[out.count - 1].end = e
            } else {
                out.append(StageSegment(start: s, end: e, stage: stage))
            }
        }
        for seg in stages {
            let wakeHead = (seg.start, min(seg.end, wakeUntil))
            let middle = (max(seg.start, wakeUntil), min(seg.end, wakeFrom))
            let wakeTail = (max(seg.start, wakeFrom), seg.end)
            add(wakeHead.0, wakeHead.1, "wake")
            add(middle.0, middle.1, seg.stage)
            add(wakeTail.0, wakeTail.1, "wake")
        }
        return out
    }
}
