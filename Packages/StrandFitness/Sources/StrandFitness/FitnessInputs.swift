import Foundation

/// One heart-rate reading. Seconds since 1970, beats per minute.
public struct FitnessHeartRateSample: Equatable, Sendable {
    public let ts: Double
    public let bpm: Double

    public init(ts: Double, bpm: Double) {
        self.ts = ts
        self.bpm = bpm
    }
}

/// What the engines need to know about the wearer. The app supplies max heart rate from the same
/// source its zones use (measured, set by hand, or age), so the Fitness page and Your zones agree.
public struct FitnessPhysiology: Equatable, Sendable {
    public enum Sex: String, Sendable { case male, female, unspecified }

    /// Resting heart rate baseline for the day being scored.
    public var restingHeartRate: Double
    public var maxHeartRate: Double
    public var sex: Sex
    public var bodyMassKg: Double?

    public init(restingHeartRate: Double, maxHeartRate: Double, sex: Sex = .unspecified, bodyMassKg: Double? = nil) {
        self.restingHeartRate = restingHeartRate
        self.maxHeartRate = maxHeartRate
        self.sex = sex
        self.bodyMassKg = bodyMassKg
    }

    /// Heart-rate reserve fraction (Karvonen): (HR − resting) / (max − resting).
    public func reserveFraction(_ bpm: Double) -> Double {
        let span = maxHeartRate - restingHeartRate
        return span > 0 ? (bpm - restingHeartRate) / span : 0
    }
}

/// How a workout loads the legs when it has no logged sets. Running and cycling load the lower body;
/// most other sports spread a smaller share across it.
public enum FitnessCardioKind: String, Sendable, CaseIterable {
    case running, cycling, rowing, walking, hiking, swimming, elliptical, stairs, mixed, other
}

/// One cardio or mixed session, as the app already stores it (Health import or a strap session).
public struct FitnessCardioSession: Equatable, Sendable {
    public let id: String
    public let start: Date
    public let durationS: Double
    public let kind: FitnessCardioKind
    public let activeEnergyKcal: Double?
    /// The session's own heart-rate stream. When empty, `averageHeartRate` is scored as if held flat.
    public let heartRate: [FitnessHeartRateSample]
    public let averageHeartRate: Double?

    public init(id: String, start: Date, durationS: Double, kind: FitnessCardioKind,
                activeEnergyKcal: Double? = nil, heartRate: [FitnessHeartRateSample] = [],
                averageHeartRate: Double? = nil) {
        self.id = id
        self.start = start
        self.durationS = max(0, durationS)
        self.kind = kind
        self.activeEnergyKcal = activeEnergyKcal
        self.heartRate = heartRate
        self.averageHeartRate = averageHeartRate
    }

    public var end: Date { start.addingTimeInterval(durationS) }
}

/// One completed working set. Muscle ids are the stable ids of `TrainingMuscleCatalog`.
public struct FitnessStrengthSet: Equatable, Sendable {
    public let date: Date
    public let exerciseId: String
    public let primaryMuscleId: String?
    public let secondaryMuscleIds: [String]
    public let weightKg: Double?
    public let reps: Int?
    public let durationS: Double?
    /// The weight moved includes the lifter's own body (pull-ups, dips, push-ups).
    public let includesBodyweight: Bool
    /// Reps in reserve the lifter reported, when they did. Preferred over the estimate.
    public let reportedRepsInReserve: Double?

    public init(date: Date, exerciseId: String, primaryMuscleId: String?, secondaryMuscleIds: [String] = [],
                weightKg: Double? = nil, reps: Int? = nil, durationS: Double? = nil,
                includesBodyweight: Bool = false, reportedRepsInReserve: Double? = nil) {
        self.date = date
        self.exerciseId = exerciseId
        self.primaryMuscleId = primaryMuscleId
        self.secondaryMuscleIds = secondaryMuscleIds
        self.weightKg = weightKg
        self.reps = reps
        self.durationS = durationS
        self.includesBodyweight = includesBodyweight
        self.reportedRepsInReserve = reportedRepsInReserve
    }
}
