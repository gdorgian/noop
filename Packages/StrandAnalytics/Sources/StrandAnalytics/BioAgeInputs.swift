import Foundation
import SuperAgeCore
import WhoopStore

// MARK: - The five-domain Fitness Age, from NOOP's own data
//
// NOOP already computes two ages. `FitnessAgeEngine` answers "how does my cardiorespiratory fitness
// compare to a typical person, in years"; `VitalityEngine` answers "what does my measured hazard sum
// come to, in years". Both produce ONE number from a handful of cardio-metabolic signals.
//
// This is a third shape, not a third opinion: SuperAgeCore scores five weighted domains —
// cardiovascular, activity, body composition, recovery, lifestyle — and reports how complete the
// evidence was. The breakdown is the point. Neither existing engine can say "your recovery domain is
// carrying you and your activity domain is not", because neither has domains.
//
// Everything here is a MAPPING. No scoring happens in this file; SuperAgeCore owns that, and it is
// deterministic, Foundation-only and golden-tested upstream. What this file owns is the harder half:
// deciding which of NOOP's numbers legitimately answers each of its inputs.
//
// Three mapping decisions worth stating, because getting them wrong is silent:
//
//  1. HRV is `avgSdnn`, NOT `avgHrv`. SuperAgeCore's curve is written against Apple-Health-shaped HRV,
//     which is SDNN. NOOP's headline `avgHrv` is RMSSD. They are different statistics on different
//     scales, and swapping them skews the recovery domain without any error ever surfacing.
//
//  2. Sleeping wrist temperature comes from NOOP's own `skinTempDevC` and never from HealthKit.
//     HealthKit reserves `.appleSleepingWristTemperature` to Apple Watch and will not let a third-party
//     app share it — which is why this signal cannot reach Apple Health or anything reading from it.
//     SuperAgeCore takes it as a plain `Double`, so the reading the platform locked out is still
//     scoreable inside this app.
//
//  3. A missing value is passed as `nil`, never as zero. SuperAgeCore treats a supplied numeric 0 as an
//     omitted observation for most metrics, but relying on that would be relying on someone else's
//     defensive coding. An absent instrument must lower the reported confidence, not score as the worst
//     possible reading.

public enum BioAge {

    /// SuperAgeCore's result type, spelled out. `StrandAnalytics` already has a `FitnessAgeResult` — the
    /// Nes/HUNT one that `FitnessAgeEngine` returns — and the two are unrelated: one carries a single age
    /// plus a VO₂max, the other carries five domain scores and a confidence. An unqualified name here
    /// would resolve to whichever module the caller imported last, so it is never left unqualified.
    public typealias DomainResult = SuperAgeCore.FitnessAgeResult


    /// Instruments NOOP cannot measure from a strap, supplied by the host from HealthKit when the
    /// wearer's phone or another device has recorded them. Every field is optional and independent: the
    /// domains renormalize over whatever is present, so an empty value here costs confidence, not
    /// correctness.
    ///
    /// This type exists so the mapping below stays pure. The app layer does the HealthKit reading and
    /// hands over plain numbers; this package never imports HealthKit and stays testable with no device.
    public struct PhoneMetrics: Equatable, Sendable {
        public var vo2Max: Double?                     // ml/kg/min, if Apple Health has a better one
        public var systolicBloodPressure: Double?      // mmHg
        public var diastolicBloodPressure: Double?     // mmHg
        public var bloodGlucose: Double?               // mg/dL
        public var walkingHeartRateAverage: Double?    // bpm
        public var bodyFatPercentage: Double?          // 0...100
        public var leanBodyMass: Double?               // kg
        public var flightsClimbed: Double?             // count over the window
        public var standHours: Double?                 // hours over the window
        public var sixMinuteWalkTestDistance: Double?  // metres
        public var stairAscentSpeed: Double?           // m/s
        public var stairDescentSpeed: Double?          // m/s
        public var walkingSteadiness: Double?          // 0...1
        public var walkingAsymmetry: Double?           // 0...100
        public var walkingDoubleSupport: Double?       // 0...100
        public var timeInDaylight: Double?             // minutes

        public init(
            vo2Max: Double? = nil,
            systolicBloodPressure: Double? = nil,
            diastolicBloodPressure: Double? = nil,
            bloodGlucose: Double? = nil,
            walkingHeartRateAverage: Double? = nil,
            bodyFatPercentage: Double? = nil,
            leanBodyMass: Double? = nil,
            flightsClimbed: Double? = nil,
            standHours: Double? = nil,
            sixMinuteWalkTestDistance: Double? = nil,
            stairAscentSpeed: Double? = nil,
            stairDescentSpeed: Double? = nil,
            walkingSteadiness: Double? = nil,
            walkingAsymmetry: Double? = nil,
            walkingDoubleSupport: Double? = nil,
            timeInDaylight: Double? = nil
        ) {
            self.vo2Max = vo2Max
            self.systolicBloodPressure = systolicBloodPressure
            self.diastolicBloodPressure = diastolicBloodPressure
            self.bloodGlucose = bloodGlucose
            self.walkingHeartRateAverage = walkingHeartRateAverage
            self.bodyFatPercentage = bodyFatPercentage
            self.leanBodyMass = leanBodyMass
            self.flightsClimbed = flightsClimbed
            self.standHours = standHours
            self.sixMinuteWalkTestDistance = sixMinuteWalkTestDistance
            self.stairAscentSpeed = stairAscentSpeed
            self.stairDescentSpeed = stairDescentSpeed
            self.walkingSteadiness = walkingSteadiness
            self.walkingAsymmetry = walkingAsymmetry
            self.walkingDoubleSupport = walkingDoubleSupport
            self.timeInDaylight = timeInDaylight
        }
    }

    /// What the wearer told us about themselves. Height and weight are the only body inputs a strap
    /// cannot measure and the profile always has.
    public struct Body: Equatable, Sendable {
        public var heightCm: Double?
        public var weightKg: Double?
        /// `true`/`false` are BOTH observations — `false` scores at the top of its metric. `nil` means
        /// the wearer has not said, which is not the same as "does not smoke".
        public var isSmoker: Bool?

        public init(heightCm: Double? = nil, weightKg: Double? = nil, isSmoker: Bool? = nil) {
            self.heightCm = heightCm
            self.weightKg = weightKg
            self.isSmoker = isSmoker
        }
    }

    /// Median of the non-nil values, or nil when there are none. Median rather than mean throughout:
    /// these are 7-to-30-day windows of nightly readings, and one bad night should not move a domain.
    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
    }

    static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Body mass index, or nil unless BOTH height and weight are real.
    public static func bmi(heightCm: Double?, weightKg: Double?) -> Double? {
        guard let heightCm, let weightKg, heightCm > 0, weightKg > 0 else { return nil }
        let metres = heightCm / 100
        return weightKg / (metres * metres)
    }

    /// Fold a window of NOOP's daily rows, the profile, and any host-supplied phone instruments into
    /// SuperAgeCore's normalized metric set.
    ///
    /// - Parameters:
    ///   - days: daily rows over the scoring window, in any order. Nightly vitals are medianed;
    ///     activity totals are meaned to a per-day figure, which is the shape SuperAgeCore's activity
    ///     curves expect.
    ///   - restScores: the 0–100 Rest scores over the same window, if scored.
    ///   - phone: instruments read from HealthKit by the host, all optional.
    /// Mean daily minutes spent at or above HR zone 2, from the strap's own heart-rate series.
    ///
    /// This is what fills SuperAgeCore's `exerciseTime`, and it is the honest home for zone minutes.
    /// WHOOP Age takes zone 1–3 and zone 4–5 minutes as two of its nine inputs with their own
    /// coefficients; NOOP's hazard model (`VitalityEngine`) has no such terms and inventing them would
    /// mean inventing the coefficients too. Feeding the same measurement through the activity domain
    /// instead uses a curve somebody else calibrated, and claims only what it can support.
    ///
    /// Zone 2 is the floor rather than zone 1 because zone 1 is most of a sedentary day — counting it as
    /// exercise would report sitting still as training.
    public static func exerciseMinutes(zoneMinutesPerDay: [Double]?) -> Double? {
        guard let zoneMinutesPerDay, zoneMinutesPerDay.count >= 5 else { return nil }
        let atOrAboveZone2 = zoneMinutesPerDay.dropFirst().reduce(0, +)
        return atOrAboveZone2 > 0 ? atOrAboveZone2 : nil
    }

    public static func metrics(
        days: [DailyMetric],
        restScores: [Double] = [],
        exerciseMinutesPerDay: Double? = nil,
        body: Body = Body(),
        phone: PhoneMetrics = PhoneMetrics()
    ) -> FitnessAgeMetrics {
        let sleepHours = days.compactMap { $0.totalSleepMin }.filter { $0 > 0 }.map { $0 / 60 }

        return FitnessAgeMetrics(
            restingHeartRate: median(days.compactMap { $0.restingHr }.map(Double.init)),
            // Prefer a measured VO₂max from Apple Health over NOOP's own estimate: the estimate is a
            // non-exercise model with a ~5 ml/kg/min standard error, and anything Health holds came from
            // a device that at least observed a workout.
            vo2Max: phone.vo2Max,
            // SDNN, not RMSSD. See the note at the top of this file — this is the mapping most likely to
            // be got wrong by reaching for the field named `avgHrv`.
            heartRateVariability: median(days.compactMap { $0.avgSdnn }),
            respiratoryRate: median(days.compactMap { $0.respRateBpm }),
            systolicBloodPressure: phone.systolicBloodPressure,
            diastolicBloodPressure: phone.diastolicBloodPressure,
            oxygenSaturation: median(days.compactMap { $0.spo2Pct }),
            walkingHeartRateAverage: phone.walkingHeartRateAverage,
            stepCount: mean(days.compactMap { $0.steps }.map(Double.init)),
            activeEnergy: mean(days.compactMap { $0.activeKcalEst }),
            exerciseTime: exerciseMinutesPerDay,
            flightsClimbed: phone.flightsClimbed,
            sixMinuteWalkTestDistance: phone.sixMinuteWalkTestDistance,
            standHours: phone.standHours,
            stairAscentSpeed: phone.stairAscentSpeed,
            stairDescentSpeed: phone.stairDescentSpeed,
            sleepHours: median(sleepHours),
            sleepScore: median(restScores).map { Int($0.rounded()) },
            // From the strap, never from HealthKit — the platform will not share this type at all.
            sleepingWristTemperatureDeviation: median(days.compactMap { $0.skinTempDevC }),
            bodyFatPercentage: phone.bodyFatPercentage,
            leanBodyMass: phone.leanBodyMass,
            height: body.heightCm,
            bodyMassIndex: bmi(heightCm: body.heightCm, weightKg: body.weightKg),
            bloodGlucose: phone.bloodGlucose,
            walkingSteadiness: phone.walkingSteadiness,
            walkingAsymmetry: phone.walkingAsymmetry,
            walkingDoubleSupport: phone.walkingDoubleSupport,
            isSmoker: body.isSmoker,
            timeInDaylight: phone.timeInDaylight
        )
    }

    /// NOOP's profile sex string onto SuperAgeCore's enum. An unstated or non-binary answer maps to
    /// `.unknown`, which the scorer handles by lowering confidence rather than by assuming one.
    public static func biologicalSex(_ sex: String) -> FitnessAgeBiologicalSex {
        switch sex.lowercased() {
        case "male":      return .male
        case "female":    return .female
        case "intersex":  return .intersex
        default:          return .unknown
        }
    }

    /// The whole calculation. Returns nil for a profile SuperAgeCore will not score — it is calibrated
    /// for adults and answers an under-18 profile with a neutral placeholder, which is not something
    /// worth putting on a screen as if it were a reading.
    public static func score(
        chronologicalAge: Int,
        sex: String,
        days: [DailyMetric],
        restScores: [Double] = [],
        exerciseMinutesPerDay: Double? = nil,
        body: Body = Body(),
        phone: PhoneMetrics = PhoneMetrics()
    ) -> DomainResult? {
        let profile = FitnessAgeProfile(
            chronologicalAge: chronologicalAge,
            biologicalSex: biologicalSex(sex)
        )
        guard profile.isValidForCalculation else { return nil }
        let result = FitnessAgeCalculator().calculate(FitnessAgeInput(
            profile: profile,
            metrics: metrics(days: days, restScores: restScores,
                             exerciseMinutesPerDay: exerciseMinutesPerDay, body: body, phone: phone)
        ))
        // No instruments means no evidence. The scorer will still return a number — the neutral 50 that
        // maps to exactly the chronological age — and showing that as a result would be presenting an
        // absence of data as a finding.
        guard result.metricsUsed > 0 else { return nil }
        return result
    }
}
