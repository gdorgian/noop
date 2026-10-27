import XCTest
@testable import StrandImport

/// A Hevy CSV import keeps each set (QA 27 Oct 2026: only session totals reached the record).
final class HevyCSVSetsTests: XCTestCase {
    private let csv = """
    "title","start_time","end_time","description","exercise_title","superset_id","exercise_notes","set_index","set_type","weight_kg","reps","distance_km","duration_seconds","rpe"
    "Push","20 Oct 2026, 18:00","20 Oct 2026, 19:05","","Bench Press (Barbell)","","Pause","0","warmup","40","10","","",""
    "Push","20 Oct 2026, 18:00","20 Oct 2026, 19:05","","Bench Press (Barbell)","","","1","normal","70","8","","","8"
    "Push","20 Oct 2026, 18:00","20 Oct 2026, 19:05","","Bench Press (Barbell)","","","2","failure","70","7","","","10"
    "Pull","22 Oct 2026, 18:10","22 Oct 2026, 19:00","","Pull Up","","","0","normal","","10","","",""
    "","not a date","","","Ghost","","","0","normal","10","10","","",""
    """

    private let utc = TimeZone(identifier: "UTC")!

    func testEveryWorkoutKeepsItsSetsInOrder() {
        let workouts = LiftingImporter.hevyWorkouts(data: Data(csv.utf8), zone: utc)
        XCTAssertEqual(workouts.map(\.title), ["Push", "Pull"])
        XCTAssertEqual(workouts[0].sets.count, 3)
        XCTAssertEqual(workouts[0].sets.map(\.isWarmup), [true, false, false])
        XCTAssertEqual(workouts[0].sets[1].weightKg, 70)
        XCTAssertEqual(workouts[0].sets[1].reps, 8)
        XCTAssertEqual(workouts[0].sets[1].rpe, 8)
        XCTAssertEqual(workouts[0].sets[2].setType, "failure")
        XCTAssertEqual(workouts[0].sets[0].note, "Pause")
        XCTAssertEqual(workouts[0].end.timeIntervalSince(workouts[0].start), 65 * 60)
        XCTAssertNil(workouts[1].sets[0].weightKg, "a bodyweight set has no weight")
    }

    func testTheSetsAgreeWithTheSessionTotals() {
        let summary = LiftingImporter.parseHevy(data: Data(csv.utf8), zone: utc).sessions
        let sets = LiftingImporter.hevyWorkouts(data: Data(csv.utf8), zone: utc)
        XCTAssertEqual(summary.count, sets.count)
        for (s, w) in zip(summary, sets) {
            XCTAssertEqual(s.start, w.start)
            XCTAssertEqual(s.setCount, w.sets.filter { !$0.isWarmup }.count)
        }
    }
}
