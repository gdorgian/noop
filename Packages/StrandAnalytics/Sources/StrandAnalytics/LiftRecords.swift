import Foundation
import WhoopStore

/// Personal records for one exercise, from every set ever logged for it.
///
/// Only WORKING sets that were performed count (`LiftMetrics.isPerformed`): a warm-up is not an attempt
/// at anything, and a 0-rep row is a set that never happened. A drop set or a set taken to failure is a
/// working set and counts like one.
///
/// A record is held by the FIRST set that reached it. Matching it later is not a new record — the
/// lifter sees "record" only for something they have never done before.
public enum LiftRecords {

    public enum Kind: String, CaseIterable, Sendable {
        /// The most weight on the bar for any reps.
        case heaviestWeight
        /// Best Epley estimate (`LiftMetrics.estimatedOneRepMaxKg`, 12 reps or fewer).
        case bestOneRepMax
        /// The best single set by weight × reps.
        case bestSetVolume
        /// The most weight × reps in one session.
        case bestSessionVolume
        /// The most reps in one set, at any weight — the record that matters for bodyweight work.
        case mostReps
        /// The most reps in one session.
        case mostSessionReps

        /// The per-set kinds: what one finished set can break on its own.
        public static let perSet: [Kind] = [.heaviestWeight, .bestOneRepMax, .bestSetVolume, .mostReps]
    }

    /// One record: its value, and the set and session that set it.
    public struct Value: Equatable, Sendable {
        public let value: Double
        public let weightKg: Double?
        public let reps: Int?
        /// Nil for a session-level record.
        public let setId: String?
        public let sessionId: String
        public let sessionStartTs: Int
    }

    /// One session of this exercise, for its history and trend lines.
    public struct SessionPoint: Equatable, Sendable {
        public let sessionId: String
        public let startTs: Int
        public let workingSets: Int
        public let heaviestKg: Double?
        public let bestOneRepMaxKg: Double?
        public let volumeKg: Double?
        public let totalReps: Int
        /// The session's best set, ranked by estimated max, then weight, then reps.
        public let bestWeightKg: Double?
        public let bestReps: Int?
    }

    public struct Exercise: Equatable, Sendable {
        public let records: [Kind: Value]
        /// The heaviest weight lifted for exactly n reps, n in 1...12 — the rep-max table.
        public let repBests: [Int: Value]
        /// Oldest first.
        public let sessions: [SessionPoint]
        /// No working set ever carried weight: the records to show are reps, not kilograms.
        public let isBodyweight: Bool

        public static let empty = Exercise(records: [:], repBests: [:], sessions: [], isBodyweight: true)
    }

    /// The highest rep count the rep-max table keeps. Past it a "best weight for n reps" is endurance.
    public static let repTableCeiling = 12

    public static func exercise(_ history: [LiftHistorySet]) -> Exercise {
        let working = history.filter { !$0.set.isWarmup && LiftMetrics.isPerformed(reps: $0.set.reps) }
        var records: [Kind: Value] = [:]
        var repBests: [Int: Value] = [:]

        func offer(_ kind: Kind, _ value: Double?, _ h: LiftHistorySet, setLevel: Bool = true) {
            guard let value, value > 0 else { return }
            if let held = records[kind], held.value >= value { return }
            records[kind] = Value(value: value, weightKg: h.set.weightKg, reps: h.set.reps,
                                  setId: setLevel ? h.set.id : nil, sessionId: h.set.sessionId,
                                  sessionStartTs: h.sessionStartTs)
        }

        for h in working {
            let s = h.set
            offer(.heaviestWeight, s.weightKg, h)
            offer(.bestOneRepMax, LiftMetrics.estimatedOneRepMaxKg(weightKg: s.weightKg, reps: s.reps), h)
            offer(.bestSetVolume, s.volumeKg, h)
            offer(.mostReps, s.reps.map(Double.init), h)
            if let reps = s.reps, (1...repTableCeiling).contains(reps), let w = s.weightKg, w > 0,
               (repBests[reps]?.value ?? 0) < w {
                repBests[reps] = Value(value: w, weightKg: w, reps: reps, setId: s.id,
                                       sessionId: s.sessionId, sessionStartTs: h.sessionStartTs)
            }
        }

        var order: [String] = []
        var bySession: [String: [LiftHistorySet]] = [:]
        for h in working {
            if bySession[h.set.sessionId] == nil { order.append(h.set.sessionId) }
            bySession[h.set.sessionId, default: []].append(h)
        }
        var sessions: [SessionPoint] = []
        for id in order {
            let sets = bySession[id] ?? []
            guard let first = sets.first else { continue }
            let volume = LiftMetrics.volumeLoadKg(sets.map(\.set))
            let reps = sets.compactMap(\.set.reps).reduce(0, +)
            let best = sets.max { rank($0.set) < rank($1.set) }?.set
            sessions.append(SessionPoint(
                sessionId: id, startTs: first.sessionStartTs, workingSets: sets.count,
                heaviestKg: sets.compactMap(\.set.weightKg).filter { $0 > 0 }.max(),
                bestOneRepMaxKg: sets.compactMap { LiftMetrics.estimatedOneRepMaxKg(weightKg: $0.set.weightKg, reps: $0.set.reps) }.max(),
                volumeKg: volume, totalReps: reps, bestWeightKg: best?.weightKg, bestReps: best?.reps))
            if let volume { offer(.bestSessionVolume, volume, first, setLevel: false) }
            if reps > 0 { offer(.mostSessionReps, Double(reps), first, setLevel: false) }
        }

        let bodyweight = !working.contains { ($0.set.weightKg ?? 0) > 0 }
        return Exercise(records: records, repBests: repBests, sessions: sessions, isBodyweight: bodyweight)
    }

    /// The per-set records `set` breaks against `before` — what a live session celebrates the moment a
    /// set is done. Nothing for an exercise never logged before: a first time beats nothing, and calling
    /// every first set a record would make the word mean nothing. Nothing for a warm-up.
    public static func broken(by set: LiftSetRow, against before: Exercise) -> [Kind] {
        guard !before.sessions.isEmpty, !set.isWarmup, LiftMetrics.isPerformed(reps: set.reps) else { return [] }
        let candidates: [(Kind, Double?)] = [
            (.heaviestWeight, set.weightKg),
            (.bestOneRepMax, LiftMetrics.estimatedOneRepMaxKg(weightKg: set.weightKg, reps: set.reps)),
            (.bestSetVolume, set.volumeKg),
            // Reps alone are a record only where weight is not the point: bodyweight work, or the same
            // weight as the heaviest ever done. Ten easy reps with the empty bar beat nothing.
            (.mostReps, (before.isBodyweight || (set.weightKg ?? 0) >= (before.records[.heaviestWeight]?.value ?? 0))
                ? set.reps.map(Double.init) : nil),
        ]
        return candidates.compactMap { kind, value in
            guard let value, value > 0 else { return nil }
            if before.isBodyweight, kind != .mostReps { return nil }
            guard let held = before.records[kind]?.value else { return nil }
            return value > held + 1e-9 ? kind : nil
        }
    }

    /// Estimated max first, then weight, then reps — the order a lifter ranks two sets in.
    private static func rank(_ s: LiftSetRow) -> (Double, Double, Int) {
        (LiftMetrics.estimatedOneRepMaxKg(weightKg: s.weightKg, reps: s.reps) ?? 0, s.weightKg ?? 0, s.reps ?? 0)
    }
}
