import XCTest
@testable import Strand
import WhoopStore
import StrandTraining

/// Aura's logger extras: a warm-up ramp put in front of the working sets, drop and failure sets, a
/// superset made during the session, and routine warm-ups counted as warm-ups from the start.
@MainActor
final class LiftSessionLoggerExtrasTests: XCTestCase {

    private func controller() -> LiftSessionController {
        LiftSessionController(buzz: { _ in }, setStrapHandler: { _ in })
    }

    private func slot(_ e: Int, _ s: Int) -> LiftSlot { LiftSlot(exerciseIndex: e, setIndex: s) }

    private func freehand() -> [LiftPlanItem] {
        [LiftPlanItem(exercise: "Bench press", primaryMuscle: .chest, targetSets: 3,
                      restSec: 120, targetRepsLow: 8, targetWeightKg: 100),
         LiftPlanItem(exercise: "Row", primaryMuscle: .lats, targetSets: 2,
                      restSec: 90, targetRepsLow: 10, targetWeightKg: 60)]
    }

    override func tearDown() {
        LiftSessionPersistence.clear()
        super.tearDown()
    }

    // MARK: - Warm-up ramp

    func testWarmupsGoInFrontAndWorkingSetsKeepTheirNumbers() {
        let c = controller()
        c.start(plan: freehand(), programId: nil, programName: nil)
        c.updateSet(slot(0, 2), weightKg: 105, reps: 6, rpe: nil, isWarmup: false)   // typed in advance
        c.setKind(slot(0, 3), .failure)

        let ramp = c.warmupSuggestion(forExercise: 0, incrementKg: 2.5)
        XCTAssertEqual(ramp.count, 3)
        XCTAssertTrue(ramp.allSatisfy { ($0.targetWeightKg ?? 0) < 100 }, "a warm-up never reaches the work weight")

        XCTAssertEqual(c.insertWarmups(intoExercise: 0, incrementKg: 2.5), 3)
        XCTAssertEqual(c.engine?.plan[0].targetSets, 6)
        for s in 1...3 { XCTAssertTrue(c.isWarmup(slot(0, s))) }
        XCTAssertFalse(c.isWarmup(slot(0, 4)))
        // The working sets slid down with what they carried.
        XCTAssertEqual(c.values(of: slot(0, 4)).weightKg, 100)
        XCTAssertEqual(c.enteredValues(for: slot(0, 5)).weightKg, 105)
        XCTAssertEqual(c.kind(of: slot(0, 6)), .failure)
        XCTAssertNil(c.kind(of: slot(0, 3)))
        // The ramp shows its own light numbers, not last session's work weight.
        XCTAssertEqual(c.values(of: slot(0, 1)).weightKg, ramp[0].targetWeightKg)
        // A second ramp is not offered.
        XCTAssertTrue(c.warmupSuggestion(forExercise: 0, incrementKg: 2.5).isEmpty)
    }

    func testNoRampOnceASetOfTheExerciseIsDone() {
        let c = controller()
        c.start(plan: freehand(), programId: nil, programName: nil)
        c.advance(); c.advance()                                   // set 1 done, resting
        XCTAssertTrue(c.warmupSuggestion(forExercise: 0, incrementKg: 2.5).isEmpty)
        XCTAssertFalse(c.warmupSuggestion(forExercise: 1, incrementKg: 2.5).isEmpty)
    }

    func testNoRampWithoutAWorkingWeight() {
        let c = controller()
        c.start(plan: [LiftPlanItem(exercise: "Dips", targetSets: 3, targetRepsLow: 10)],
                programId: nil, programName: nil)
        XCTAssertTrue(c.warmupSuggestion(forExercise: 0, incrementKg: 2.5).isEmpty)
    }

    func testWorkingTheFirstSetWhileTheRampGoesInFollowsTheSet() {
        let c = controller()
        c.start(plan: freehand(), programId: nil, programName: nil)
        c.advance()                                                // working set 1
        c.insertWarmups(intoExercise: 0, incrementKg: 2.5)
        XCTAssertEqual(c.engine?.stage, .working(slot(0, 4)), "the set being done is the same set, renumbered")
    }

    func testWarmupsSaveAsWarmupsAndOutOfVolume() {
        let c = controller()
        c.start(plan: freehand(), programId: nil, programName: nil)
        c.insertWarmups(intoExercise: 0, incrementKg: 2.5)
        let saved = c.setsToSave(completingUnfinished: true).filter { $0.slot.exerciseIndex == 0 }
        XCTAssertEqual(saved.filter(\.isWarmup).count, 3)
        XCTAssertEqual(saved.filter { !$0.isWarmup }.map(\.weightKg), [100, 100, 100])
    }

    // MARK: - Set kinds

    func testAKindAndAWarmupExcludeEachOther() {
        let c = controller()
        c.start(plan: freehand(), programId: nil, programName: nil)
        c.setWarmup(slot(0, 1), true)
        c.setKind(slot(0, 1), .drop)
        XCTAssertFalse(c.isWarmup(slot(0, 1)))
        XCTAssertEqual(c.kind(of: slot(0, 1)), .drop)
        c.setWarmup(slot(0, 1), true)
        XCTAssertNil(c.kind(of: slot(0, 1)))
    }

    func testKindsSaveOnTheirSetsAndSurviveARelaunch() {
        let c = controller()
        c.start(plan: freehand(), programId: nil, programName: nil)
        c.setKind(slot(0, 3), .drop)
        c.advance(); c.advance()                                   // set 1 done
        c.setKind(slot(0, 1), .failure)

        let resumed = controller()
        resumed.resume(from: try! XCTUnwrap(LiftSessionPersistence.load()))
        XCTAssertEqual(resumed.kind(of: slot(0, 1)), .failure)
        XCTAssertEqual(resumed.kind(of: slot(0, 3)), .drop)
        let saved = resumed.setsToSave(completingUnfinished: true)
        XCTAssertEqual(saved.first { $0.slot == slot(0, 1) }?.kind, .failure)
        XCTAssertEqual(saved.first { $0.slot == slot(0, 3) }?.kind, .drop)
    }

    func testRemovingASetForgetsItsKind() {
        let c = controller()
        c.start(plan: freehand(), programId: nil, programName: nil)
        c.setKind(slot(0, 3), .drop)
        c.removeSet(fromExercise: 0)
        c.addSet(toExercise: 0)
        XCTAssertNil(c.kind(of: slot(0, 3)))
    }

    // MARK: - Supersets

    func testASupersetMadeMidSessionAlternatesAndSurvivesARelaunch() {
        let c = controller()
        c.start(plan: freehand(), programId: nil, programName: nil)
        XCTAssertTrue(c.linkSuperset(0))
        c.advance()                                                // bench 1
        c.advance()                                                // done, resting
        XCTAssertEqual(c.engine?.upcomingSlot, slot(1, 1), "after bench set 1 comes row set 1")

        let resumed = controller()
        resumed.resume(from: try! XCTUnwrap(LiftSessionPersistence.load()))
        XCTAssertNotNil(resumed.engine?.plan[0].supersetGroup)
        XCTAssertEqual(resumed.engine?.plan[0].supersetGroup, resumed.engine?.plan[1].supersetGroup)

        XCTAssertTrue(resumed.unlinkSuperset(1))
        XCTAssertNil(resumed.engine?.plan[0].supersetGroup, "a group of one dissolves")
    }

    // MARK: - Routine warm-ups

    func testARoutinesWarmupsCountAsWarmupsFromTheStart() {
        let routine = RoutineExercise(exerciseId: "bench", sets: [
            RoutineSetPlan(phase: .warmup, targetWeightKg: 40, repsMin: 10, repsMax: 10),
            RoutineSetPlan(targetWeightKg: 80, repsMin: 8, repsMax: 8),
        ])
        let c = controller()
        c.start(plan: [LiftPlanItem(exercise: "Bench press", targetSets: 2, routinePlan: routine)],
                programId: nil, programName: nil)
        XCTAssertTrue(c.isWarmup(slot(0, 1)))
        XCTAssertFalse(c.isWarmup(slot(0, 2)))
        c.advance(); c.advance()
        XCTAssertEqual(c.engine?.sets.first?.isWarmup, true)
    }
}
