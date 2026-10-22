import Foundation

/// How hard each set was, and where on the body it landed.
///
/// A set's stimulus runs from 0.3 to 1.0 by its proximity to failure, measured in reps in reserve (RIR):
///
///     stimulus = clamp(1 − max(0, RIR − 3) / 10, 0.3, 1)
///
/// so any set within three reps of failure counts in full, and an easy set still counts for something.
/// RIR is the lifter's own report when they gave one. Otherwise it is estimated from their history of
/// that exercise:
///
/// - weighted sets: Epley's one-rep max, e1RM = w × (1 + reps / 30), taken as the best the lifter has
///   shown on the exercise up to and including this set. Reps possible at the set's weight are
///   30 × (e1RM / w − 1), and RIR is that minus the reps done.
/// - bodyweight sets (no weight): best reps on the exercise minus this set's reps.
/// - timed sets: (best time − this time) / best time × 10.
///
/// The set then loads its primary muscle at 1.0 and each secondary at 0.5. Muscular Load counts every
/// set as `pointsPerSet` × stimulus, so a hard working set is worth 10 points. Cardio adds to it through
/// `cardioMuscleShare`: a run loads the legs, which the lifting-only view would otherwise miss.
public enum MuscularLoad {
    public static let pointsPerSet = 10.0
    public static let secondaryWeight = 0.5

    public static func stimulus(repsInReserve rir: Double) -> Double {
        min(1, max(0.3, 1 - max(0, rir - 3) / 10))
    }

    public struct ScoredSet: Equatable, Sendable {
        public let set: FitnessStrengthSet
        public let stimulus: Double
        /// Load per muscle id, already weighted primary/secondary and multiplied by `pointsPerSet`.
        public let muscleLoad: [String: Double]

        public var load: Double { stimulus * MuscularLoad.pointsPerSet }
    }

    /// Scores sets in date order, so each set is judged only against what came before it and itself.
    public static func score(_ sets: [FitnessStrengthSet]) -> [ScoredSet] {
        var bestE1RM: [String: Double] = [:], bestReps: [String: Int] = [:], bestTime: [String: Double] = [:]
        return sets.sorted { $0.date < $1.date }.map { s in
            let rir: Double
            if let reported = s.reportedRepsInReserve {
                rir = max(0, reported)
            } else if let w = s.weightKg, w > 0, let reps = s.reps, reps > 0 {
                let e1 = w * (1 + Double(reps) / 30)
                let best = max(bestE1RM[s.exerciseId] ?? 0, e1)
                bestE1RM[s.exerciseId] = best
                rir = max(0, 30 * (best / w - 1) - Double(reps))
            } else if let reps = s.reps, reps > 0 {
                let best = max(bestReps[s.exerciseId] ?? 0, reps)
                bestReps[s.exerciseId] = best
                rir = Double(best - reps)
            } else if let t = s.durationS, t > 0 {
                let best = max(bestTime[s.exerciseId] ?? 0, t)
                bestTime[s.exerciseId] = best
                rir = (best - t) / best * 10
            } else {
                rir = 10
            }
            let st = stimulus(repsInReserve: rir)
            var muscles: [String: Double] = [:]
            if let p = s.primaryMuscleId { muscles[p, default: 0] += st * pointsPerSet }
            for m in s.secondaryMuscleIds where m != s.primaryMuscleId {
                muscles[m, default: 0] += st * pointsPerSet * secondaryWeight
            }
            return ScoredSet(set: s, stimulus: st, muscleLoad: muscles)
        }
    }

    /// Share of a cardio session's TRIMP that becomes muscular load, per muscle. Weights sum to the
    /// modality's total share: running puts half its TRIMP on the legs, swimming a quarter on the back
    /// and shoulders, and so on. Mapped to `TrainingMuscleCatalog` ids.
    public static func cardioMuscleShare(_ m: CardioModality) -> [String: Double] {
        switch m {
        case .running: ["quadriceps": 0.15, "hamstrings": 0.12, "glutes": 0.1, "calves": 0.13]
        case .cycling: ["quadriceps": 0.2, "glutes": 0.12, "hamstrings": 0.06, "calves": 0.07]
        case .rowing: ["quadriceps": 0.1, "glutes": 0.08, "lats": 0.1, "upper_back": 0.08, "biceps": 0.04]
        case .walking, .hiking: ["quadriceps": 0.08, "glutes": 0.07, "calves": 0.08, "hamstrings": 0.04]
        case .stairs: ["quadriceps": 0.14, "glutes": 0.12, "calves": 0.1]
        case .elliptical: ["quadriceps": 0.1, "glutes": 0.08, "hamstrings": 0.05]
        case .swimming: ["lats": 0.08, "front_delts": 0.06, "triceps": 0.05, "upper_back": 0.06]
        case .mixed, .other: ["quadriceps": 0.05, "glutes": 0.04]
        }
    }

    /// Muscular load of one cardio session, per muscle.
    public static func cardioMuscleLoad(trimp: Double, modality: CardioModality) -> [String: Double] {
        cardioMuscleShare(modality).mapValues { $0 * trimp }
    }
}
