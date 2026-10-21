import XCTest
import WhoopStore
@testable import Strand

/// A finished session must survive until the store confirms it (device test, 25 Sep: a cardio
/// session could be lost if its write failed after the in-flight snapshot was cleared).
final class PendingWorkoutSavesTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "PendingWorkoutSavesTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func row(_ start: Int, _ sport: String = "Run", strain: Double? = 9.1) -> WorkoutRow {
        WorkoutRow(startTs: start, endTs: start + 1_800, sport: sport, source: "manual", durationS: 1_800,
                   energyKcal: 310, avgHr: 141, maxHr: 172, strain: strain, distanceM: nil,
                   zonesJSON: nil, notes: nil, steps: nil)
    }

    func testAPendingRowSurvivesARead() {
        PendingWorkoutSaves.add(row(1_000), to: defaults)
        XCTAssertEqual(PendingWorkoutSaves.all(in: defaults), [row(1_000)])
    }

    func testTheSameSessionIsReplacedNotStacked() {
        PendingWorkoutSaves.add(row(1_000, strain: 8), to: defaults)
        PendingWorkoutSaves.add(row(1_000, strain: 9.1), to: defaults)
        XCTAssertEqual(PendingWorkoutSaves.all(in: defaults), [row(1_000, strain: 9.1)])
    }

    func testRemovingOneLeavesTheOthers() {
        PendingWorkoutSaves.add(row(1_000), to: defaults)
        PendingWorkoutSaves.add(row(5_000, "Ride"), to: defaults)
        PendingWorkoutSaves.remove(row(1_000), from: defaults)
        XCTAssertEqual(PendingWorkoutSaves.all(in: defaults), [row(5_000, "Ride")])
        PendingWorkoutSaves.remove(row(5_000, "Ride"), from: defaults)
        XCTAssertTrue(PendingWorkoutSaves.all(in: defaults).isEmpty)
        XCTAssertNil(defaults.data(forKey: PendingWorkoutSaves.defaultsKey))
    }

    func testCorruptStorageReadsAsNothingPending() {
        defaults.set(Data("not json".utf8), forKey: PendingWorkoutSaves.defaultsKey)
        XCTAssertTrue(PendingWorkoutSaves.all(in: defaults).isEmpty)
    }
}
