import XCTest
@testable import StrandAnalytics

/// The live equivalents of the series `WhoopImporter` derives from a CSV export. The tests that matter
/// are the ones pinning them to the SAME definitions, because an imported day and a computed day sit in
/// one series and have to mean the same thing.
final class TrainingLoadSeriesTests: XCTestCase {

    private func workout(_ day: String = "2026-08-14", minutes: Double = 60,
                         sport: String = "Running",
                         zones: [Double]? = [20, 30, 30, 15, 5]) -> TrainingLoadSeries.Workout {
        .init(day: day, minutes: minutes, sport: sport, zonePercents: zones)
    }

    // MARK: Zone minutes

    func testZoneMinutesAreDurationTimesTheWorkoutsOwnPercentages() {
        let totals = TrainingLoadSeries.dayTotals(workouts: [workout()])
        XCTAssertEqual(totals.count, 1)
        // 60 min at 20/30/30/15/5 %.
        XCTAssertEqual(totals[0].zoneMinutes, [12, 18, 18, 9, 3])
        XCTAssertEqual(totals[0].zones13, 48)
        XCTAssertEqual(totals[0].zones45, 12)
        XCTAssertEqual(totals[0].zonesAll, 60)
    }

    func testTwoWorkoutsInADayAccumulate() {
        let totals = TrainingLoadSeries.dayTotals(workouts: [
            workout(minutes: 60), workout(minutes: 30),
        ])
        XCTAssertEqual(totals.count, 1)
        XCTAssertEqual(totals[0].zonesAll, 90)
    }

    func testAWorkoutWithoutZoneDataContributesNoZoneMinutes() {
        let totals = TrainingLoadSeries.dayTotals(workouts: [
            workout(sport: "Strength", zones: nil),
        ])
        XCTAssertEqual(totals[0].zonesAll, 0, "no zone data is not zero minutes in zone 1")
        XCTAssertEqual(totals[0].strengthMinutes, 60, "but it is still strength time")
    }

    // MARK: Strength

    /// Matches the importer's substring test, which is loose on purpose — the sport string can come from
    /// WHOOP's naming, NOOP's catalog, or a wearer's own edit.
    func testStrengthMatchesTheImportersSubstringRule() {
        XCTAssertTrue(TrainingLoadSeries.isStrength(sport: "Strength"))
        XCTAssertTrue(TrainingLoadSeries.isStrength(sport: "Strength Training"))
        XCTAssertTrue(TrainingLoadSeries.isStrength(sport: "Weightlifting"))
        XCTAssertTrue(TrainingLoadSeries.isStrength(sport: "Upper body strength"))
        XCTAssertFalse(TrainingLoadSeries.isStrength(sport: "Running"))
        XCTAssertFalse(TrainingLoadSeries.isStrength(sport: "Cycling"))
    }

    func testStrengthTimeSumsOnlyStrengthWorkouts() {
        let totals = TrainingLoadSeries.dayTotals(workouts: [
            workout(minutes: 45, sport: "Weightlifting"),
            workout(minutes: 60, sport: "Running"),
        ])
        XCTAssertEqual(totals[0].strengthMinutes, 45)
    }

    // MARK: Absence

    /// A day the wearer did not train and a day NOOP did not observe are different facts. Only the
    /// second should be missing from a series, so a no-workout day produces nothing at all rather than a
    /// row of zeroes that reads as "measured, and it was nothing".
    func testADayWithNoWorkoutsProducesNoRow() {
        XCTAssertTrue(TrainingLoadSeries.dayTotals(workouts: []).isEmpty)
        XCTAssertTrue(TrainingLoadSeries.dayTotals(workouts: [workout(minutes: 0)]).isEmpty)
    }

    /// But a day that DID have a workout writes its zeroes: "you trained and none of it was zone 5" is a
    /// measurement worth keeping.
    func testAZoneWithNoTimeStillWritesAZeroOnADayThatTrained() {
        let totals = TrainingLoadSeries.dayTotals(workouts: [workout(zones: [100, 0, 0, 0, 0])])
        let points = TrainingLoadSeries.seriesPoints(for: totals[0])
        XCTAssertEqual(points.first { $0.key == "hr_zone5_min" }?.value, 0)
        XCTAssertNil(points.first { $0.key == "strength_min" }, "no strength work, no strength row")
    }

    // MARK: Keys

    /// The keys have to match `WhoopImporter` exactly, or a computed day lands in a different series
    /// from an imported one and the chart shows two half-histories.
    func testKeysMatchTheImportersSpelling() {
        let totals = TrainingLoadSeries.dayTotals(workouts: [workout(sport: "Strength")])
        let keys = Set(TrainingLoadSeries.seriesPoints(for: totals[0]).map(\.key))
        XCTAssertEqual(keys, [
            "hr_zone1_min", "hr_zone2_min", "hr_zone3_min", "hr_zone4_min", "hr_zone5_min",
            "hr_zones13_min", "hr_zones45_min", "hr_zones_all_min", "strength_min",
        ])
    }
}
