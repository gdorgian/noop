import XCTest
@testable import StrandImport

/// Whole Hevy workouts, changes, routines, tape measurements and the body sent to create a workout.
/// Fixtures are written for Noop from Hevy's published OpenAPI shapes.
final class HevyWorkoutsTests: XCTestCase {

    private let utc = TimeZone(identifier: "UTC")!

    private let page = Data("""
    {"page":1,"page_count":3,"workouts":[{"id":"w1","title":"Push","routine_id":"r9",
     "start_time":"2026-10-20T07:00:00Z","end_time":"2026-10-20T08:05:00Z","updated_at":"2026-10-20T08:06:00Z",
     "exercises":[
      {"index":1,"title":"Triceps Pushdown (Cable)","exercise_template_id":"T2","superset_id":null,
       "sets":[{"index":0,"type":"normal","weight_kg":30,"reps":12,"rpe":8}]},
      {"index":0,"title":"Bench Press (Barbell)","exercise_template_id":"T1","notes":"",
       "sets":[{"index":1,"type":"normal","weight_kg":80,"reps":8,"rpe":8.5},
               {"index":0,"type":"warmup","weight_kg":40,"reps":10}]}]},
     {"id":"","start_time":"bad"}]}
    """.utf8)

    func testWholeWorkoutKeepsEverySetInOrder() {
        let p = HevyAPI.parseWorkouts(data: page, zone: utc)
        XCTAssertEqual(p.items.count, 1)
        XCTAssertEqual(p.skipped, 1)
        XCTAssertTrue(p.hasMore)
        let w = p.items[0]
        XCTAssertEqual(w.id, "w1")
        XCTAssertEqual(w.routineId, "r9")
        XCTAssertEqual(w.end.timeIntervalSince(w.start), 65 * 60)
        XCTAssertEqual(w.exercises.map(\.title), ["Bench Press (Barbell)", "Triceps Pushdown (Cable)"])
        XCTAssertEqual(w.exercises[0].sets.map(\.isWarmup), [true, false])
        XCTAssertEqual(w.exercises[0].sets[1].weightKg, 80)
        XCTAssertNil(w.exercises[0].notes, "an empty note is no note")
    }

    func testChangesCarryUpdatesAndDeletions() {
        let data = Data("""
        {"page":1,"page_count":1,"events":[
         {"type":"updated","workout":{"id":"w2","title":"Legs","start_time":"2026-10-21T07:00:00Z",
          "end_time":"2026-10-21T08:00:00Z","exercises":[]}},
         {"type":"deleted","id":"w3","deleted_at":"2026-10-22T00:00:00Z"},
         {"type":"mystery"}]}
        """.utf8)
        let p = HevyAPI.parseWorkoutChanges(data: data, zone: utc)
        XCTAssertEqual(p.items.count, 2)
        XCTAssertEqual(p.skipped, 1)
        if case .deleted(let id) = p.items[1] { XCTAssertEqual(id, "w3") } else { XCTFail() }
    }

    func testRoutineRepRanges() {
        let data = Data("""
        {"page":1,"page_count":1,"routines":[{"id":"r1","title":"Upper",
         "exercises":[{"index":0,"title":"Pull Up","exercise_template_id":"T9","rest_seconds":90,
          "sets":[{"type":"normal","reps":null,"rep_range":{"start":6,"end":10}}]}]}]}
        """.utf8)
        let r = HevyAPI.parseRoutines(data: data).items[0]
        XCTAssertEqual(r.exercises[0].restSeconds, 90)
        XCTAssertEqual(r.exercises[0].sets[0].repRangeLow, 6)
        XCTAssertEqual(r.exercises[0].sets[0].repRangeHigh, 10)
    }

    func testTapeOnlyMeasurementIsKept() {
        let data = Data(#"{"body_measurements":[{"date":"2026-10-01","waist":82.5,"left_bicep_cm":36}]}"#.utf8)
        let m = HevyAPI.parseBodyMeasurements(data: data).items
        XCTAssertEqual(m.count, 1)
        XCTAssertEqual(m[0].circumferencesCm["waist"], 82.5)
    }

    func testOutgoingBodySnapsRpe() throws {
        let body = try XCTUnwrap(HevyAPI.workoutBody(
            title: "Noop", description: nil,
            start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 3600),
            exercises: [.init(templateId: "T1", notes: nil, sets: [
                .init(type: "normal", weightKg: 80, reps: 8, durationSeconds: nil, rpe: 8.4),
                .init(type: "normal", weightKg: 80, reps: 8, durationSeconds: nil, rpe: 3)])]))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let sets = (((json["workout"] as? [String: Any])?["exercises"] as? [[String: Any]])?[0]["sets"] as? [[String: Any]]) ?? []
        XCTAssertEqual(sets[0]["rpe"] as? Double, 8.5)
        XCTAssertNil(sets[1]["rpe"], "an RPE Hevy does not accept is left out, not sent")
    }

    func testEquipmentFirst() {
        XCTAssertEqual(HevyAPI.equipmentFirst("Bench Press (Barbell)"), "Barbell Bench Press")
        XCTAssertEqual(HevyAPI.equipmentFirst("Pull Up"), "Pull Up")
    }
}
