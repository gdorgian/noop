import XCTest
@testable import StrandTraining

final class ExerciseMediaPolicyTests: XCTestCase {
    func testAllDayScheduleRemainsUpcomingTodayAndOldTimedEntriesKeepTheirMeaning() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let noon = Date(timeIntervalSince1970: 1_728_043_200)
        let midnight = calendar.startOfDay(for: noon)
        let allDay = RoutineScheduleEntry(routineID: "routine", routineName: "A", date: midnight, includesTime: false)
        XCTAssertTrue(allDay.isUpcoming(asOf: noon, calendar: calendar))
        XCTAssertFalse(allDay.isUpcoming(asOf: noon.addingTimeInterval(86_400), calendar: calendar))
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(allDay)) as? [String: Any])
        legacy.removeValue(forKey: "includesTime")
        let old = try JSONDecoder().decode(RoutineScheduleEntry.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(old.includesTime)
        XCTAssertFalse(old.isUpcoming(asOf: noon, calendar: calendar))
        XCTAssertEqual(try JSONDecoder().decode(RoutineScheduleEntry.self, from: JSONEncoder().encode(allDay)), allDay)
    }

    func testPinnedURLsAndStarterMapping() throws {
        let entry = try XCTUnwrap(BundledExerciseCatalog.exercises.first { $0.sourceId == "0001" })
        let revision = "7455efae41b330c265e7cd4b78dfa848e7ce5ebd"
        let media = try XCTUnwrap(entry.mediaId)
        XCTAssertEqual(ExerciseMediaPolicy.url(for: entry, kind: .animation)?.absoluteString,
                       "https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/\(revision)/videos/0001-\(media).gif")
        XCTAssertEqual(ExerciseMediaPolicy.url(for: entry, kind: .thumbnail)?.pathExtension, "jpg")
        for starter in TrainingStarterCatalog.exercises where starter.mediaId != nil {
            XCTAssertNotNil(ExerciseMediaPolicy.url(for: starter, kind: .animation), starter.id)
        }
        XCTAssertNil(ExerciseMediaPolicy.url(for: .init(id: "custom", title: "Custom", mode: .duration), kind: .animation))
        XCTAssertNil(ExerciseMediaPolicy.url(revision: "../main", sourceId: "0001", mediaId: "abc", kind: .animation))
    }

    func testLRUEvictsOldestUntilWithinBudgetAndBreaksTiesDeterministically() {
        let entries: [ExerciseMediaPolicy.CacheEntry] = [
            .init(name: "recent", bytes: 4, accessed: Date(timeIntervalSince1970: 3)),
            .init(name: "old-b", bytes: 3, accessed: Date(timeIntervalSince1970: 1)),
            .init(name: "old-a", bytes: 2, accessed: Date(timeIntervalSince1970: 1))
        ]
        XCTAssertEqual(ExerciseMediaPolicy.evictions(entries, limit: 7), ["old-a"])
        XCTAssertEqual(ExerciseMediaPolicy.evictions(entries, limit: 4), ["old-a", "old-b"])
        XCTAssertEqual(ExerciseMediaPolicy.evictions(entries, limit: 9), [])
        XCTAssertEqual(ExerciseMediaPolicy.evictions(entries, limit: 0), ["old-a", "old-b", "recent"])
        XCTAssertEqual(ExerciseMediaPolicy.evictions([], limit: 0), [])
    }

    func testLegacyPlanDecodesWithoutSupersetOrPerSetRestAndNewValuesRoundTrip() throws {
        let old = RoutineExercise(exerciseId: "push-up", sets: [.init(repsMin: 10)])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        object.removeValue(forKey: "supersetId")
        let decoded = try JSONDecoder().decode(RoutineExercise.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.supersetId)
        XCTAssertNil(decoded.sets[0].restSeconds)
        var current = decoded
        current.supersetId = UUID()
        current.sets[0].restSeconds = 75
        XCTAssertEqual(try JSONDecoder().decode(RoutineExercise.self, from: JSONEncoder().encode(current)), current)
        let copy = RoutineEditing.duplicate(.init(title: "A", exercises: [current]), title: "B", now: 1)
        XCTAssertEqual(copy.exercises[0].sets[0].restSeconds, 75)
        XCTAssertNotEqual(copy.exercises[0].sets[0].id, current.sets[0].id)
    }
}
