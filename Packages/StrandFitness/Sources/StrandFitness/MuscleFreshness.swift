import Foundation

/// The muscle groups the body map and freshness list show. Finer catalogue ids (upper chest, side
/// delts, outer quads) fold into these, because recovery is not tracked usefully finer than this.
public enum FitnessMuscleGroup: String, CaseIterable, Sendable, Codable {
    case chest, shoulders, biceps, triceps, forearms
    case lats, upperBack, traps, lowerBack
    case abs, obliques
    case quads, hamstrings, glutes, adductors, abductors, hipFlexors, calves, tibialis
    case neck

    public var title: String {
        switch self {
        case .chest: "Chest"
        case .shoulders: "Shoulders"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .forearms: "Forearms"
        case .lats: "Lats"
        case .upperBack: "Upper back"
        case .traps: "Traps"
        case .lowerBack: "Lower back"
        case .abs: "Abs"
        case .obliques: "Obliques"
        case .quads: "Quads"
        case .hamstrings: "Hamstrings"
        case .glutes: "Glutes"
        case .adductors: "Adductors"
        case .abductors: "Abductors"
        case .hipFlexors: "Hip flexors"
        case .calves: "Calves"
        case .tibialis: "Shins"
        case .neck: "Neck"
        }
    }

    /// Hours for half of a session's fatigue to clear. Large, slow-recovering muscles hold fatigue
    /// longest; small and postural muscles turn over fastest. Chosen so a hard session on a large
    /// muscle is mostly cleared after about three days, in line with the 48–72 h recovery the
    /// resistance-training literature reports for trained lifters.
    public var halfLifeHours: Double {
        switch self {
        case .quads, .hamstrings, .glutes, .lowerBack, .adductors: 36
        case .chest, .lats, .upperBack, .traps: 30
        case .shoulders, .biceps, .triceps, .forearms, .abductors, .hipFlexors: 24
        case .abs, .obliques, .calves, .tibialis, .neck: 18
        }
    }

    /// The group a `TrainingMuscleCatalog` id belongs to.
    public static func forMuscleId(_ id: String) -> FitnessMuscleGroup? {
        switch id {
        case "chest", "upper_chest", "lower_chest": .chest
        case "shoulders", "front_delts", "side_delts", "rear_delts", "rotator_cuff": .shoulders
        case "biceps": .biceps
        case "triceps": .triceps
        case "forearms": .forearms
        case "lats": .lats
        case "back", "upper_back", "rhomboids": .upperBack
        case "traps", "upper_traps", "lower_traps": .traps
        case "lower_back": .lowerBack
        case "core", "abdominals", "upper_abs", "lower_abs", "serratus": .abs
        case "obliques": .obliques
        case "legs", "quadriceps", "inner_quadriceps", "outer_quadriceps": .quads
        case "hamstrings": .hamstrings
        case "glutes": .glutes
        case "adductors": .adductors
        case "abductors": .abductors
        case "hip_flexors": .hipFlexors
        case "calves": .calves
        case "tibialis": .tibialis
        case "neck": .neck
        default: nil
        }
    }
}

/// How ready each muscle group is for more work, 1–100 %.
///
/// Every set (and every cardio session's leg share) leaves fatigue on a muscle equal to its muscular
/// load. Fatigue halves every `halfLifeHours` for that group:
///
///     fatigue(t) = Σ load_i × 0.5^((t − t_i) / halfLife)
///     freshness  = clamp(100 × (1 − fatigue / capacity), 1, 100)
///
/// Capacity is personal: 1.5 × the group's mean load per training day over the last 42 days, so a
/// typical session leaves a muscle tired but not empty, and someone who trains a muscle hard every
/// week is not shown as wrecked by their normal day. Until a group has been trained on at least
/// `minimumTrainingDays` days in that window its capacity falls back to `defaultCapacity`
/// (six hard sets) and the reading is marked calibrating.
///
/// Status: recovered at 75 % and above, fatigued from 40 %, depleted below.
public enum MuscleFreshness {
    public enum Status: String, Sendable, CaseIterable { case calibrating, recovered, fatigued, depleted }

    public struct Reading: Equatable, Sendable {
        public let group: FitnessMuscleGroup
        public let percent: Double
        public let status: Status
        /// The underlying 0…100 status ignoring calibration, for colouring a still-calibrating map.
        public let provisionalStatus: Status
    }

    public static let windowDays = 42
    public static let minimumTrainingDays = 3
    public static let defaultCapacity = 6 * MuscularLoad.pointsPerSet
    public static let capacityMultiple = 1.5

    public static func status(percent: Double) -> Status {
        percent >= 75 ? .recovered : percent >= 40 ? .fatigued : .depleted
    }

    /// - Parameter events: muscular load per catalogue muscle id, with when it happened.
    public static func readings(events: [(date: Date, muscleLoad: [String: Double])], asOf now: Date,
                                calendar: Calendar = .current) -> [Reading] {
        let windowStart = now.addingTimeInterval(-Double(windowDays) * 86_400)
        var fatigue: [FitnessMuscleGroup: Double] = [:]
        var dayLoad: [FitnessMuscleGroup: [Date: Double]] = [:]
        for e in events where e.date <= now {
            for (id, load) in e.muscleLoad {
                guard let g = FitnessMuscleGroup.forMuscleId(id), load > 0 else { continue }
                let hours = now.timeIntervalSince(e.date) / 3600
                fatigue[g, default: 0] += load * pow(0.5, hours / g.halfLifeHours)
                if e.date >= windowStart { dayLoad[g, default: [:]][calendar.startOfDay(for: e.date), default: 0] += load }
            }
        }
        return FitnessMuscleGroup.allCases.map { g in
            let days = dayLoad[g] ?? [:]
            let calibrated = days.count >= minimumTrainingDays
            let capacity = calibrated
                ? max(defaultCapacity / 2, capacityMultiple * days.values.reduce(0, +) / Double(days.count))
                : defaultCapacity
            let pct = min(100, max(1, 100 * (1 - (fatigue[g] ?? 0) / capacity)))
            let provisional = status(percent: pct)
            return Reading(group: g, percent: pct, status: calibrated ? provisional : .calibrating,
                           provisionalStatus: provisional)
        }
    }
}
