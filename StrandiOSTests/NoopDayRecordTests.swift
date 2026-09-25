#if os(iOS)
import XCTest
import StrandAnalytics
import StrandDesign
import WhoopStore
@testable import NOOP_Staging

/// The production Day, Effort and Trends screens print their figures through these helpers, so the
/// rules each sentence relies on are pinned here.
final class NoopDayRecordTests: XCTestCase {

    private func reading(key: String, value: Double?, band: VitalBands.Band,
                         basis: VitalBands.Basis = .personal, baseline: Double? = nil,
                         spread: Double = 1) -> BodyVitalReading {
        BodyVitalReading(
            key: key, label: key, unit: "", value: value, format: { "\($0)" },
            banding: VitalBands.Result(band: band, basis: basis, nights: 20),
            metricColor: .clear, day: "2026-09-22", source: nil, missingCaption: "",
            personal: baseline.map {
                BaselineState(baseline: $0, spread: spread, nValid: 20, nightsSinceUpdate: 0, status: .trusted)
            })
    }

    func testAVitalWithNoValueIsLeftOut() {
        XCTAssertNil(NoopVital(reading: reading(key: "rhr", value: nil, band: .noData)))
    }

    func testPersonalZoneIsTheBaselinePlusMinusTwoSigma() throws {
        let vital = try XCTUnwrap(NoopVital(reading: reading(key: "rhr", value: 58, band: .inRange, baseline: 60, spread: 2)))
        let reach = VitalBands.sigmaK * Baselines.sigma(BaselineState(baseline: 60, spread: 2, nValid: 20,
                                                                          nightsSinceUpdate: 0, status: .trusted))
        XCTAssertEqual(vital.baseline, 60)
        XCTAssertEqual(vital.low, 60 - reach, accuracy: 1e-9)
        XCTAssertEqual(vital.high, 60 + reach, accuracy: 1e-9)
        XCTAssertEqual(vital.delta, "\u{2212}2 bpm vs baseline")
        XCTAssertTrue(vital.deltaIsGood, "lower resting pulse is the good side")
    }

    func testPopulationZoneHasNoBaselineAndNoDelta() throws {
        let vital = try XCTUnwrap(NoopVital(reading: reading(key: "resp", value: 16.1, band: .inRange, basis: .population)))
        XCTAssertNil(vital.baseline)
        XCTAssertNil(vital.delta)
        XCTAssertEqual(vital.low, 12)
        XCTAssertEqual(vital.high, 20)
    }

    func testSummaryCountsOnlyWhatWasJudged() throws {
        let inZone = try XCTUnwrap(NoopVital(reading: reading(key: "rhr", value: 58, band: .inRange, baseline: 60)))
        let out = try XCTUnwrap(NoopVital(reading: reading(key: "resp", value: 25, band: .outOfRange, basis: .population)))
        XCTAssertEqual(NoopVital.summary([inZone, out]), "One in your normal zone, one outside it")
        XCTAssertEqual(NoopVital.summary([inZone]), "One in your normal zone, none outside it")
        XCTAssertNil(NoopVital.summary([]))
    }

    func testEnergyMinutesReadTheWayTheHTMLWritesThem() {
        XCTAssertEqual(NoopEnergyReading.minutes(4200), "1 h 10 m")
        XCTAssertEqual(NoopEnergyReading.minutes(1440), "24 m")
        XCTAssertEqual(NoopEnergyReading.minutes(-5), "0 m")
    }

    func testStressStepRoundsIntoTheFourNames() {
        XCTAssertEqual(NoopDayRecord.stressStep(0.4), 0)
        XCTAssertEqual(NoopDayRecord.stressStep(2.6), 3)
        XCTAssertEqual(NoopDayRecord.stressStep(9), 3)
        XCTAssertEqual(NoopDayRecord.stressNames.count, 4)
    }

    func testEffortRecordKeepsAnEmptyWeekEmpty() {
        let record = NoopEffortRecord.build(days: [], workouts: [])
        XCTAssertEqual(record.week.count, 7)
        XCTAssertTrue(record.week.allSatisfy { $0.value == nil })
        XCTAssertEqual(record.historyDays(), 0)
        XCTAssertTrue(record.sessions(inLast: 30).isEmpty)
    }

    func testWorkoutSourceWords() {
        func row(_ source: String) -> WorkoutRow {
            WorkoutRow(startTs: 0, endTs: 600, sport: "Cycling", source: source, durationS: 600,
                       energyKcal: nil, avgHr: nil, maxHr: nil, strain: nil, distanceM: nil,
                       zonesJSON: nil, notes: nil, steps: nil)
        }
        XCTAssertEqual(row("manual").noopSourceLabel, "strap")
        XCTAssertEqual(row("apple-health").noopSourceLabel, "Health")
        XCTAssertEqual(row("whoop-import").noopSourceLabel, "imported")
        XCTAssertEqual(row("manual").noopMinutes, 10)
    }
}
#endif
