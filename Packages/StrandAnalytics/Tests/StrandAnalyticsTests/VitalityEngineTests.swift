import XCTest
@testable import StrandAnalytics

final class VitalityEngineTests: XCTestCase {

    /// An average-for-their-age person nets ~0 hazard → Body Age == chronological age, Vitality 50.
    func testAveragePersonReadsAtTheirAge() {
        let r = VitalityEngine.compute(.init(
            chronoAge: 40, restingHR: 65, vo2max: 45, expectedVO2max: 45,
            sleepHours: 7.5, sleepConsistency: 0.75, rmssd: 45, rmssdNorm: 45, steps: 7000))!
        XCTAssertEqual(r.bodyAge, 40, accuracy: 0.01)
        XCTAssertEqual(r.vitality, 50, accuracy: 0.01)
        XCTAssertEqual(r.deltaYears, 0, accuracy: 0.01)
        XCTAssertEqual(r.factorsUsed, 6)
    }

    /// A clearly healthy person reads younger + higher vitality (hand-computed Δage ≈ −7.58).
    func testHealthyPersonIsYounger() {
        let r = VitalityEngine.compute(.init(
            chronoAge: 40, restingHR: 52, vo2max: 55.5, expectedVO2max: 45,
            sleepHours: 7.5, sleepConsistency: 0.9, rmssd: 54, rmssdNorm: 45, steps: 11000))!
        XCTAssertEqual(r.bodyAge, 32.42, accuracy: 0.1)
        XCTAssertEqual(r.vitality, 68.95, accuracy: 0.2)
        XCTAssertGreaterThan(r.deltaYears, 0)   // younger than chrono age
    }

    /// A clearly unhealthy person reads older + lower vitality (hand-computed Δage ≈ +9.71).
    func testUnhealthyPersonIsOlder() {
        let r = VitalityEngine.compute(.init(
            chronoAge: 40, restingHR: 80, vo2max: 34.5, expectedVO2max: 45,
            sleepHours: 5.5, sleepConsistency: 0.5, rmssd: 31.5, rmssdNorm: 45, steps: 3000))!
        XCTAssertEqual(r.bodyAge, 49.71, accuracy: 0.1)
        XCTAssertEqual(r.vitality, 25.73, accuracy: 0.2)
        XCTAssertLessThan(r.deltaYears, 0)      // older than chrono age
    }

    /// Below the minimum-factor honesty gate → nil (don't show a number on too little data).
    func testNilBelowMinFactors() {
        XCTAssertNil(VitalityEngine.compute(.init(chronoAge: 40, restingHR: 65, sleepHours: 7.5))) // 2 factors
        XCTAssertNotNil(VitalityEngine.compute(.init(chronoAge: 40, restingHR: 65, sleepHours: 7.5,
                                                     sleepConsistency: 0.75)))                     // 3 factors
    }

    /// Body Age + Vitality stay within their clamped ranges at the extremes.
    func testClamps() {
        let young = VitalityEngine.compute(.init(
            chronoAge: 22, restingHR: 40, vo2max: 70, expectedVO2max: 40,
            sleepHours: 7.5, sleepConsistency: 1.0, rmssd: 90, rmssdNorm: 45, steps: 11000))!
        XCTAssertGreaterThanOrEqual(young.bodyAge, VitalityEngine.minBodyAge)
        XCTAssertLessThanOrEqual(young.vitality, 100)
        XCTAssertGreaterThanOrEqual(young.vitality, 0)

        let old = VitalityEngine.compute(.init(
            chronoAge: 85, restingHR: 110, vo2max: 12, expectedVO2max: 35,
            sleepHours: 3, sleepConsistency: 0.1, rmssd: 8, rmssdNorm: 30, steps: 200))!
        XCTAssertLessThanOrEqual(old.bodyAge, VitalityEngine.maxBodyAge)
        XCTAssertGreaterThanOrEqual(old.vitality, 0)
    }

    func testRmssdNormByAge() {
        XCTAssertEqual(VitalityEngine.rmssdNorm(forAge: 20), 47, accuracy: 0.01)
        XCTAssertEqual(VitalityEngine.rmssdNorm(forAge: 40), 33, accuracy: 0.01)
        XCTAssertEqual(VitalityEngine.rmssdNorm(forAge: 45), 31, accuracy: 0.01)   // halfway 33→29
        XCTAssertEqual(VitalityEngine.rmssdNorm(forAge: 90), 20, accuracy: 0.01)   // clamps to last anchor
    }

    func testSleepConsistency() {
        XCTAssertEqual(VitalityEngine.sleepConsistency(nightlyHours: [7, 7, 7, 7])!, 1.0, accuracy: 1e-9)
        XCTAssertEqual(VitalityEngine.sleepConsistency(nightlyHours: [6, 8, 6, 8])!, 0.857, accuracy: 0.005)
        XCTAssertNil(VitalityEngine.sleepConsistency(nightlyHours: [7, 7]))   // < 3 nights
    }

    /// Contributions carry the right sign: a low resting HR is protective (negative), a high one ages you.
    func testContributionSigns() {
        let lowRHR = VitalityEngine.contributions(.init(chronoAge: 40, restingHR: 50))
            .first { $0.key == "rhr" }!
        XCTAssertLessThan(lowRHR.lnHazard, 0)
        let highRHR = VitalityEngine.contributions(.init(chronoAge: 40, restingHR: 85))
            .first { $0.key == "rhr" }!
        XCTAssertGreaterThan(highRHR.lnHazard, 0)
    }

    func testContributionYearsUseTheSameMappingAsBodyAge() {
        let inputs = VitalityEngine.Inputs(
            chronoAge: 40, restingHR: 52, vo2max: 55.5, expectedVO2max: 45,
            sleepHours: 7.5, sleepConsistency: 0.9, rmssd: 54, rmssdNorm: 45, steps: 11_000
        )
        let contributions = VitalityEngine.contributions(inputs)
        let attributedYears = contributions.map { VitalityEngine.ageEffectYears(for: $0) }.reduce(0, +)
        let result = VitalityEngine.compute(inputs)!
        XCTAssertEqual(result.bodyAge - result.chronoAge, attributedYears, accuracy: 1e-9)
    }
}

// MARK: - The VO₂max term (added when Body Age was finally given its strongest input)

extension VitalityEngineTests {
    func testVo2maxNormFallsWithAgeAndSeparatesSexes() {
        XCTAssertGreaterThan(VitalityEngine.vo2maxNorm(forAge: 25, sex: "male"),
                             VitalityEngine.vo2maxNorm(forAge: 65, sex: "male"))
        XCTAssertGreaterThan(VitalityEngine.vo2maxNorm(forAge: 40, sex: "male"),
                             VitalityEngine.vo2maxNorm(forAge: 40, sex: "female"))
    }

    func testVo2maxNormInterpolatesAndHoldsOutsideTheAnchors() {
        let thirty = VitalityEngine.vo2maxNorm(forAge: 30, sex: "male")
        XCTAssertLessThan(thirty, VitalityEngine.vo2maxNorm(forAge: 25, sex: "male"))
        XCTAssertGreaterThan(thirty, VitalityEngine.vo2maxNorm(forAge: 35, sex: "male"))
        // Outside the anchor range the curve holds rather than extrapolating into nonsense.
        XCTAssertEqual(VitalityEngine.vo2maxNorm(forAge: 18, sex: "male"),
                       VitalityEngine.vo2maxNorm(forAge: 25, sex: "male"))
        XCTAssertEqual(VitalityEngine.vo2maxNorm(forAge: 95, sex: "female"),
                       VitalityEngine.vo2maxNorm(forAge: 75, sex: "female"))
    }

    func testUnstatedSexTakesTheMidpointRatherThanAssumingMale() {
        let age = 45.0
        let male = VitalityEngine.vo2maxNorm(forAge: age, sex: "male")
        let female = VitalityEngine.vo2maxNorm(forAge: age, sex: "female")
        XCTAssertEqual(VitalityEngine.vo2maxNorm(forAge: age, sex: "nonbinary"),
                       (male + female) / 2, accuracy: 1e-9)
    }

    func testFitterThanTheAgeNormIsProtectiveAndReadsAsAYoungerBody() {
        let age = 40.0
        let norm = VitalityEngine.vo2maxNorm(forAge: age, sex: "male")
        func inputs(_ vo2: Double) -> VitalityEngine.Inputs {
            VitalityEngine.Inputs(chronoAge: age, restingHR: 65, vo2max: vo2, expectedVO2max: norm,
                                  sleepHours: 7.5, rmssd: VitalityEngine.rmssdNorm(forAge: age),
                                  rmssdNorm: VitalityEngine.rmssdNorm(forAge: age))
        }
        guard let fit = VitalityEngine.compute(inputs(norm + 7)),
              let unfit = VitalityEngine.compute(inputs(norm - 7)) else {
            return XCTFail("both inputs carry ≥3 factors and must produce a result")
        }
        XCTAssertLessThan(fit.bodyAge, unfit.bodyAge)
        let driver = VitalityEngine.contributions(inputs(norm + 7)).first { $0.key == "vo2max" }
        XCTAssertNotNil(driver, "the fitness term must appear in the driver breakdown")
        XCTAssertLessThan(driver?.lnHazard ?? 0, 0, "fitter than the norm is protective")
    }

    /// A VO₂max with no reference is not evidence — the term must drop out rather than score against 0.
    func testVo2maxWithoutAReferenceContributesNothing() {
        let inputs = VitalityEngine.Inputs(chronoAge: 40, restingHR: 65, vo2max: 45,
                                           sleepHours: 7.5, rmssd: 33, rmssdNorm: 33)
        XCTAssertNil(VitalityEngine.contributions(inputs).first { $0.key == "vo2max" })
    }
}
