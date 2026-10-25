import XCTest
import WhoopStore
@testable import StrandAnalytics

final class LiftRecordsTests: XCTestCase {

    private var n = 0
    private func set(_ session: String, _ start: Int, _ w: Double?, _ r: Int?, warm: Bool = false,
                     kind: LiftSetKind? = nil) -> LiftHistorySet {
        n += 1
        return LiftHistorySet(set: LiftSetRow(id: "s\(n)", deviceId: "d", sessionId: session, ord: n,
                                              exercise: "Bench", primaryMuscle: .chest, setIndex: n,
                                              weightKg: w, reps: r, rpe: nil, isWarmup: warm,
                                              startTs: nil, endTs: nil, restSec: nil, note: nil, setKind: kind),
                              sessionStartTs: start)
    }

    func testRecordsComeFromWorkingSetsAndTheFirstSetToReachThemHoldsThem() {
        let history = [
            set("a", 100, 120, 5, warm: true),            // a warm-up is never a record
            set("a", 100, 80, 8), set("a", 100, 80, 8),
            set("b", 200, 85, 6), set("b", 200, 80, 8),   // ties a's 80×8: a keeps the set-volume record
            set("c", 300, 70, 12, kind: .drop),
            set("c", 300, 60, 0),                         // never performed
        ]
        let e = LiftRecords.exercise(history)
        XCTAssertEqual(e.records[.heaviestWeight]?.value, 85)
        XCTAssertEqual(e.records[.heaviestWeight]?.sessionId, "b")
        XCTAssertEqual(e.records[.bestSetVolume]?.value, 840)            // the drop set, 70 × 12
        XCTAssertEqual(e.records[.bestSessionVolume]?.value, 1280)       // a: 640 + 640
        XCTAssertEqual(e.records[.bestSessionVolume]?.sessionId, "a")
        XCTAssertNil(e.records[.bestSessionVolume]?.setId)
        XCTAssertEqual(e.records[.mostReps]?.value, 12)
        XCTAssertEqual(e.records[.bestOneRepMax]?.value ?? 0, 85 * (1 + 6.0 / 30), accuracy: 1e-9)
        XCTAssertEqual(e.repBests[8]?.value, 80)
        XCTAssertEqual(e.repBests[8]?.sessionId, "a")
        XCTAssertNil(e.repBests[5], "the 120 kg warm-up is not a 5-rep best")
        XCTAssertEqual(e.sessions.map(\.sessionId), ["a", "b", "c"])
        XCTAssertEqual(e.sessions.map(\.workingSets), [2, 2, 1])
        XCTAssertFalse(e.isBodyweight)
    }

    func testASetBreaksOnlyWhatItBeats() {
        let before = LiftRecords.exercise([set("a", 100, 80, 8), set("a", 100, 70, 10)])
        func probe(_ w: Double, _ r: Int) -> Set<LiftRecords.Kind> {
            Set(LiftRecords.broken(by: set("now", 500, w, r).set, against: before))
        }
        XCTAssertEqual(probe(80, 8), [], "matching a record is not a new one")
        XCTAssertEqual(probe(82.5, 5), [.heaviestWeight])
        XCTAssertEqual(probe(80, 9), [.bestOneRepMax, .bestSetVolume], "nine reps is not the ten already done")
        XCTAssertEqual(probe(80, 11), [.bestOneRepMax, .bestSetVolume, .mostReps])
        XCTAssertEqual(probe(40, 15), [], "light reps beat nothing")
        XCTAssertEqual(LiftRecords.broken(by: set("now", 500, 200, 1, warm: true).set, against: before), [])
    }

    func testAFirstTimeBeatsNothing() {
        XCTAssertEqual(LiftRecords.broken(by: set("now", 500, 100, 5).set, against: .empty), [])
    }

    func testBodyweightRecordsAreReps() {
        let before = LiftRecords.exercise([set("a", 100, nil, 12), set("b", 200, 0, 15)])
        XCTAssertTrue(before.isBodyweight)
        XCTAssertEqual(before.records[.mostReps]?.value, 15)
        XCTAssertEqual(before.records[.mostSessionReps]?.value, 15)
        XCTAssertEqual(LiftRecords.broken(by: set("now", 500, nil, 16).set, against: before), [.mostReps])
        XCTAssertEqual(LiftRecords.broken(by: set("now", 500, nil, 14).set, against: before), [])
    }
}
