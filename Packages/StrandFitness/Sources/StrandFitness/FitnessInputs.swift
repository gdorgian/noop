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

/// What the engines need to know about the wearer. Everything optional is estimated from what is
/// present, and the estimate is reported rather than hidden (see `HeartRateZones.Method`).
public struct FitnessPhysiology: Equatable, Sendable {
    public enum Sex: String, Sendable { case male, female, unspecified }

    /// Resting heart rate baseline for the day being scored.
    public var restingHeartRate: Double
    /// Highest heart rate actually measured, when the wearer has one.
    public var measuredMaxHeartRate: Double?
    public var ageYears: Double?
    public var sex: Sex
    public var bodyMassKg: Double?

    public init(restingHeartRate: Double, measuredMaxHeartRate: Double? = nil, ageYears: Double? = nil,
                sex: Sex = .unspecified, bodyMassKg: Double? = nil) {
        self.restingHeartRate = restingHeartRate
        self.measuredMaxHeartRate = measuredMaxHeartRate
        self.ageYears = ageYears
        self.sex = sex
        self.bodyMassKg = bodyMassKg
    }

    /// Measured maximum when there is one; otherwise Tanaka, Monahan & Seals (2001): 208 − 0.7 × age.
    /// With neither, 190 — a deliberately middling figure that the zone method reports as a guess.
    public var maxHeartRate: Double {
        if let measuredMaxHeartRate, measuredMaxHeartRate > restingHeartRate + 20 { return measuredMaxHeartRate }
        if let ageYears { return 208 - 0.7 * ageYears }
        return 190
    }
}

/// How a workout loads the legs when it has no logged sets. Running and cycling load the lower body;
/// most other sports spread a smaller share across it.
public enum CardioModality: String, Sendable, CaseIterable {
    case running, cycling, rowing, walking, hiking, swimming, elliptical, stairs, mixed, other
}

/// One cardio or mixed session, as the app already stores it (Health import or a strap session).
public struct FitnessCardioSession: Equatable, Sendable {
    public let id: String
    public let start: Date
    public let durationS: Double
    public let modality: CardioModality
    public let activeEnergyKcal: Double?
    /// The session's own heart-rate stream. When empty, `averageHeartRate` is scored as if held flat.
    public let heartRate: [FitnessHeartRateSample]
    public let averageHeartRate: Double?

    public init(id: String, start: Date, durationS: Double, modality: CardioModality,
                activeEnergyKcal: Double? = nil, heartRate: [FitnessHeartRateSample] = [],
                averageHeartRate: Double? = nil) {
        self.id = id
        self.start = start
        self.durationS = max(0, durationS)
        self.modality = modality
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
