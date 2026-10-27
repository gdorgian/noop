import XCTest
@testable import Strand

/// What was rested reaches the record however the rest ends: by the big button, by starting a set from
/// its own row, or by finishing with a rest still running (QA 27 Oct 2026: both of the last two were lost).
final class LiftSessionRestRecordTests: XCTestCase {

    private let t0 = 1_700_000_000

    private func plan() -> [LiftPlanItem] {
        [LiftPlanItem(exercise: "Bench press", primaryMuscle: .chest, targetSets: 3, restSec: 120),
         LiftPlanItem(exercise: "Pull-up", targetSets: 2, restSec: 90)]
    }

    private func slot(_ e: Int, _ s: Int) -> LiftSlot { LiftSlot(exerciseIndex: e, setIndex: s) }

    private func rest(_ engine: LiftSessionEngine, _ s: LiftSlot) -> Int? {
        engine.sets.first { $0.slot == s }?.restSec
    }

    func testTheBigButtonRecordsTheRest() {
        var engine = LiftSessionEngine(plan: plan(), startTs: t0)
        engine.advance(now: t0)           // set 1 starts
        engine.advance(now: t0 + 40)      // set 1 done, rest starts
        engine.advance(now: t0 + 100)     // rest ends, set 2 starts
        XCTAssertEqual(rest(engine, slot(0, 1)), 60)
    }

    func testStartingASetFromItsRowRecordsTheRestItEnded() {
        var engine = LiftSessionEngine(plan: plan(), startTs: t0)
        engine.advance(now: t0)
        engine.advance(now: t0 + 40)      // resting after bench set 1
        engine.start(slot(1, 1), now: t0 + 72)
        XCTAssertEqual(rest(engine, slot(0, 1)), 32)
        XCTAssertEqual(engine.stage, .working(slot(1, 1)))
    }

    func testClosingTheRunningRestKeepsTheStageAndRecordsOnce() {
        var engine = LiftSessionEngine(plan: plan(), startTs: t0)
        engine.advance(now: t0)
        engine.advance(now: t0 + 40)
        let stage = engine.stage
        engine.closeRunningRest(now: t0 + 75)
        engine.closeRunningRest(now: t0 + 500)
        XCTAssertEqual(rest(engine, slot(0, 1)), 35, "written once, at the first close")
        XCTAssertEqual(engine.stage, stage, "saving does not end the session on its own")
    }
}
