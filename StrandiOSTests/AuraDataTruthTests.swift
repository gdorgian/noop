#if os(iOS)
import XCTest
import StrandAnalytics
import WhoopStore
@testable import NOOP_Staging

final class AuraDataTruthTests: XCTestCase {

    func testBodyAgeUsesOnlyTheMatchingWeeklyDriverSnapshot() {
        let reading = AuraAgeReading.live(
            bodyAgeSeries: [(day: "2026-08-22", value: 38)],
            chronologicalAgeSeries: [(day: "2026-08-22", value: 40)],
            fitnessAgeSeries: [
                (day: "2026-08-22", value: 36),
                (day: "2026-08-23", value: 31),
            ],
            vo2maxSeries: [(day: "2026-08-23", value: 49)],
            contributionSeries: [
                "rhr": [
                    (day: "2026-08-15", value: -0.20),
                    (day: "2026-08-22", value: 0.10),
                ],
                "sleep": [(day: "2026-08-15", value: -0.30)],
            ],
            domainResult: nil,
            readiness: FitnessAgeEngine.assessReadiness(
                hasAge: true, hasSex: true, rhrDays: 7, activityDays: 7,
                hasHeightWeight: true, hasWaist: false),
            chronologicalAge: 40)

        XCTAssertEqual(reading.drivers.map(\.id), ["rhr"],
                       "a driver from a different Body Age week must not leak into this explanation")
        XCTAssertFalse(reading.drivers[0].isProtective,
                       "the matching current snapshot must win over an older point for the same factor")
        XCTAssertEqual(reading.fitnessAge, "36", "weekly companion values must match the Body Age day")
        XCTAssertEqual(reading.vo2max, "—", "an unmatched VO₂max week must be withheld")
    }

    func testBodyAgeWithholdsAComparisonWhenItsAgeSnapshotDoesNotMatch() {
        let reading = AuraAgeReading.live(
            bodyAgeSeries: [(day: "2026-08-22", value: 38)],
            chronologicalAgeSeries: [(day: "2026-08-15", value: 40)],
            fitnessAgeSeries: [],
            vo2maxSeries: [],
            contributionSeries: [:],
            domainResult: nil,
            readiness: FitnessAgeEngine.assessReadiness(
                hasAge: true, hasSex: true, rhrDays: 7, activityDays: 7,
                hasHeightWeight: true, hasWaist: false),
            chronologicalAge: 55)

        XCTAssertEqual(
            reading.delta,
            String(localized: "Comparison unavailable for this stored week")
        )
        XCTAssertEqual(
            reading.driversNote,
            String(localized: "Driver snapshot unavailable")
        )
        XCTAssertFalse(reading.read.contains("55"),
                       "current profile age must not be substituted into a historical calculation")
    }

    func testRestRecencyClaimsUseActualWakeDays() {
        let now = DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026, month: 8, day: 24, hour: 12).date!

        let current = AuraRestReading.periodLabels(
            wakeDayKeys: ["2026-08-18", "2026-08-22", "2026-08-24"], now: now)
        XCTAssertTrue(current.isCurrentWeek)
        XCTAssertTrue(current.isLastNight)

        let stale = AuraRestReading.periodLabels(
            wakeDayKeys: ["2026-07-03", "2026-07-04"], now: now)
        XCTAssertFalse(stale.isCurrentWeek)
        XCTAssertFalse(stale.isLastNight)

        let mixed = AuraRestReading.periodLabels(
            wakeDayKeys: ["2026-07-03", "2026-08-24"], now: now)
        XCTAssertFalse(mixed.isCurrentWeek,
                       "seven-newest history cannot be called this week when it includes an old wear gap")
        XCTAssertTrue(mixed.isLastNight)
    }

    func testZeroDeepSleepRemainsInTheObservedAverage() {
        let reading = AuraRestReading.live(
            days: [
                daily(day: "2026-08-23", totalSleep: 420, deep: 0),
                daily(day: "2026-08-24", totalSleep: 420, deep: 60),
            ],
            sessions: [],
            habitualMidsleepSec: nil)

        XCTAssertEqual(reading.averageDeepValue, "0.5",
                       "0 and 60 observed minutes average to 30 minutes, not 60")
    }

    @MainActor
    func testWeeklyEffortClassifiesEachDailyTargetWithoutCancellation() {
        let target = CoupledView.optimalStrainRange(recovery: 80)!
        func storedEffort(_ effort21: Double) -> Double {
            effort21 / UnitFormatter.effortScaleFactor
        }
        let rows = [
            daily(day: "2026-08-21", recovery: 80,
                  strain: storedEffort(Double(target.lowerBound) - 0.5)),
            daily(day: "2026-08-22", recovery: 80,
                  strain: storedEffort(Double(target.lowerBound + target.upperBound) / 2)),
            daily(day: "2026-08-23", recovery: 80,
                  strain: storedEffort(Double(target.upperBound) + 0.5)),
            daily(day: "2026-08-24", recovery: nil, strain: 8),
        ]

        let counts = AuraEffortReading.weekTargetCounts(rows: rows, scale: .whoop)
        XCTAssertEqual(counts.recorded, 4)
        XCTAssertEqual(counts.comparable, 3)
        XCTAssertEqual(counts.below, 1)
        XCTAssertEqual(counts.inRange, 1)
        XCTAssertEqual(counts.above, 1)
    }

    private func daily(
        day: String,
        totalSleep: Double? = nil,
        deep: Double? = nil,
        recovery: Double? = nil,
        strain: Double? = nil
    ) -> DailyMetric {
        DailyMetric(
            day: day,
            totalSleepMin: totalSleep,
            efficiency: nil,
            deepMin: deep,
            remMin: nil,
            lightMin: nil,
            disturbances: nil,
            restingHr: nil,
            avgHrv: nil,
            recovery: recovery,
            strain: strain,
            exerciseCount: nil)
    }
}
#endif
