import XCTest
import SuperAgeCore
import WhoopStore
@testable import StrandAnalytics

/// The mapping from NOOP's own data onto SuperAgeCore's normalized inputs. SuperAgeCore's scoring is
/// its own problem and is golden-tested upstream; what these cover is the half that is ours — which of
/// NOOP's numbers answers which of its questions, and what happens when one is missing.
final class BioAgeInputsTests: XCTestCase {

    private func day(
        _ key: String,
        sleepMin: Double? = 450,
        rhr: Int? = 52,
        rmssd: Double? = 68,
        sdnn: Double? = 41,
        resp: Double? = 14.2,
        spo2: Double? = 96,
        skinTemp: Double? = -0.2,
        steps: Int? = 9_000,
        kcal: Double? = 640
    ) -> DailyMetric {
        DailyMetric(
            day: key, totalSleepMin: sleepMin, efficiency: nil, deepMin: nil, remMin: nil,
            lightMin: nil, disturbances: nil, restingHr: rhr, avgHrv: rmssd, recovery: nil,
            strain: nil, exerciseCount: nil, spo2Pct: spo2, skinTempDevC: skinTemp,
            respRateBpm: resp, steps: steps, activeKcalEst: kcal, spo2Red: nil, spo2Ir: nil,
            avgSdnn: sdnn
        )
    }

    private var week: [DailyMetric] {
        (1...7).map { day(String(format: "2026-08-%02d", $0)) }
    }

    // MARK: The mapping decisions that fail silently

    /// The single most dangerous mistake available here: `avgHrv` is RMSSD, SuperAgeCore's curve is
    /// SDNN-shaped. Reaching for the field whose name contains "hrv" would compile, run, and be wrong.
    func testHeartRateVariabilityIsSDNNAndNotTheRMSSDHeadline() {
        let metrics = BioAge.metrics(days: week)
        XCTAssertEqual(metrics.heartRateVariability, 41, "SDNN")
        XCTAssertNotEqual(metrics.heartRateVariability, 68, "must not be the RMSSD headline")
    }

    /// The signal HealthKit will not let this app share still has to reach the scorer, because
    /// SuperAgeCore takes it as a plain number rather than through HealthKit.
    func testWristTemperatureComesFromTheStrapNotHealthKit() {
        XCTAssertEqual(BioAge.metrics(days: week).sleepingWristTemperatureDeviation, -0.2)
    }

    /// Nightly vitals are medianed so one outlier night cannot move a domain.
    func testNightlyVitalsAreMedianedNotMeaned() {
        var days = (1...6).map { day(String(format: "2026-08-%02d", $0), rhr: 50) }
        days.append(day("2026-08-07", rhr: 120))   // one bad night
        let metrics = BioAge.metrics(days: days)
        XCTAssertEqual(metrics.restingHeartRate ?? 0, 50, accuracy: 0.5,
                       "a single outlier must not drag the resting-HR input")
    }

    /// Activity totals are per-day figures, which is the shape the activity curves expect.
    func testActivityTotalsAreMeanedToAPerDayFigure() {
        let metrics = BioAge.metrics(days: week)
        XCTAssertEqual(metrics.stepCount ?? 0, 9_000, accuracy: 1)
        XCTAssertEqual(metrics.activeEnergy ?? 0, 640, accuracy: 1)
    }

    // MARK: Missing data

    /// A missing instrument must arrive as nil. Passing 0 would score as the worst possible reading
    /// instead of as an absence.
    func testAMissingInstrumentIsNilRatherThanZero() {
        let blank = [day("2026-08-01", sleepMin: nil, rhr: nil, rmssd: nil, sdnn: nil, resp: nil,
                         spo2: nil, skinTemp: nil, steps: nil, kcal: nil)]
        let metrics = BioAge.metrics(days: blank)
        XCTAssertNil(metrics.restingHeartRate)
        XCTAssertNil(metrics.heartRateVariability)
        XCTAssertNil(metrics.oxygenSaturation)
        XCTAssertNil(metrics.stepCount)
        XCTAssertNil(metrics.sleepHours)
        XCTAssertNil(metrics.sleepingWristTemperatureDeviation)
    }

    /// A zero-length night is not a night. Filtering it out matters because a strap left on the desk
    /// records the day, not the sleep.
    func testZeroLengthNightsAreNotCountedAsSleep() {
        let days = [day("2026-08-01", sleepMin: 0), day("2026-08-02", sleepMin: 480)]
        XCTAssertEqual(BioAge.metrics(days: days).sleepHours ?? 0, 8, accuracy: 0.01)
    }

    func testBMINeedsBothHeightAndWeight() {
        XCTAssertNil(BioAge.bmi(heightCm: 180, weightKg: nil))
        XCTAssertNil(BioAge.bmi(heightCm: nil, weightKg: 80))
        XCTAssertNil(BioAge.bmi(heightCm: 0, weightKg: 80))
        XCTAssertEqual(BioAge.bmi(heightCm: 178, weightKg: 80) ?? 0, 25.249, accuracy: 1e-3)
    }

    // MARK: Profile

    func testUnstatedSexMapsToUnknownRatherThanAssumingOne() {
        XCTAssertEqual(BioAge.biologicalSex("male"), .male)
        XCTAssertEqual(BioAge.biologicalSex("Female"), .female)
        XCTAssertEqual(BioAge.biologicalSex("nonbinary"), .unknown)
        XCTAssertEqual(BioAge.biologicalSex(""), .unknown)
    }

    // MARK: Scoring gates

    func testScoringProducesDomainsAndAConfidenceFromAWeekOfStrapData() {
        guard let result = BioAge.score(chronologicalAge: 34, sex: "male", days: week,
                                        restScores: [78, 81, 74],
                                        body: .init(heightCm: 178, weightKg: 78)) else {
            return XCTFail("a full week of strap data must score")
        }
        XCTAssertGreaterThan(result.metricsUsed, 0)
        XCTAssertLessThanOrEqual(result.metricsUsed, result.totalPossibleMetrics)
        XCTAssertGreaterThan(result.confidence, 0)
        XCTAssertLessThanOrEqual(result.confidence, 1)
        // The strap alone can reach cardiovascular, activity, recovery and body composition; lifestyle
        // needs instruments only the phone has.
        XCTAssertNotNil(result.domainScores[.cardiovascular])
        XCTAssertNotNil(result.domainScores[.recovery])
        XCTAssertNotNil(result.domainScores[.activity])
    }

    /// An under-18 profile gets SuperAgeCore's neutral placeholder rather than a real estimate. Showing
    /// that as a reading would present a refusal as a result.
    func testAnUnderageProfileIsNotScored() {
        XCTAssertNil(BioAge.score(chronologicalAge: 16, sex: "male", days: week))
    }

    /// No instruments means no evidence. The scorer still returns a neutral 50 that maps to exactly the
    /// chronological age — putting that on screen would be presenting an absence as a finding.
    func testNoInstrumentsProducesNoResult() {
        let blank = [day("2026-08-01", sleepMin: nil, rhr: nil, rmssd: nil, sdnn: nil, resp: nil,
                         spo2: nil, skinTemp: nil, steps: nil, kcal: nil)]
        XCTAssertNil(BioAge.score(chronologicalAge: 34, sex: "male", days: blank))
    }

    /// Phone instruments raise the evidence count without changing what the strap contributed.
    func testPhoneInstrumentsAddEvidenceRatherThanReplacingIt() {
        guard let strapOnly = BioAge.score(chronologicalAge: 34, sex: "male", days: week),
              let withPhone = BioAge.score(
                  chronologicalAge: 34, sex: "male", days: week,
                  body: .init(heightCm: 178, weightKg: 78, isSmoker: false),
                  phone: .init(vo2Max: 47, systolicBloodPressure: 118, diastolicBloodPressure: 74,
                               flightsClimbed: 12, standHours: 11, timeInDaylight: 95))
        else { return XCTFail("both configurations must score") }

        XCTAssertGreaterThan(withPhone.metricsUsed, strapOnly.metricsUsed)
        XCTAssertGreaterThan(withPhone.confidence, strapOnly.confidence,
                             "more observed instruments must read as more confidence")
        XCTAssertNotNil(withPhone.domainScores[.lifestyle],
                        "lifestyle becomes reachable once the phone contributes")
    }

    /// Determinism is the property the whole feature rests on: the same week must not produce a
    /// different age on a second look.
    func testTheSameInputsAlwaysProduceTheSameResult() {
        let first = BioAge.score(chronologicalAge: 34, sex: "male", days: week)
        let second = BioAge.score(chronologicalAge: 34, sex: "male", days: week)
        XCTAssertEqual(first?.fitnessAge, second?.fitnessAge)
        XCTAssertEqual(first?.confidence, second?.confidence)
    }
}
