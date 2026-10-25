import XCTest
@testable import StrandTraining

final class ProgramGeneratorTests: XCTestCase {

    private let fullGym: Set<ProgramGenerator.Equipment> = Set(ProgramGenerator.Equipment.allCases)

    func testSplitFollowsDaysPerWeek() {
        func titles(_ days: Int, _ level: ProgramGenerator.Level = .intermediate) -> [String] {
            ProgramGenerator.generate(.init(goal: .muscle, level: level, daysPerWeek: days, minutes: 60, equipment: fullGym))
                .days.map(\.title)
        }
        XCTAssertEqual(titles(2), ["Full body A", "Full body B"])
        XCTAssertEqual(titles(3), ["Full body A", "Full body B", "Full body C"])
        XCTAssertEqual(titles(3, .advanced), ["Push", "Pull", "Legs"])
        XCTAssertEqual(titles(4), ["Upper A", "Lower A", "Upper B", "Lower B"])
        XCTAssertEqual(titles(6).count, 6)
    }

    func testSessionLengthSetsHowManyExercisesADayKeeps() {
        let short = ProgramGenerator.generate(.init(goal: .muscle, level: .intermediate, daysPerWeek: 4, minutes: 30, equipment: fullGym))
        let long = ProgramGenerator.generate(.init(goal: .muscle, level: .intermediate, daysPerWeek: 4, minutes: 75, equipment: fullGym))
        XCTAssertTrue(short.days.allSatisfy { $0.exercises.count <= 4 })
        XCTAssertGreaterThan(long.days[0].exercises.count, short.days[0].exercises.count)
        XCTAssertTrue(short.days[0].exercises.first?.compound ?? false, "compounds come first and survive the cut")
    }

    func testOnlyEquipmentAtHandIsUsed() {
        let p = ProgramGenerator.generate(.init(goal: .general, level: .beginner, daysPerWeek: 3, minutes: 45, equipment: []))
        let all = p.days.flatMap(\.exercises)
        XCTAssertFalse(all.isEmpty)
        for e in all {
            let option = ProgramGenerator.options.first { $0.id == e.id }!
            XCTAssertTrue(option.needs.contains { $0.isEmpty }, "\(e.title) needs equipment that is not there")
        }
    }

    func testSparedJointsAreNotLoaded() {
        let p = ProgramGenerator.generate(.init(goal: .strength, level: .intermediate, daysPerWeek: 4, minutes: 60,
                                                equipment: fullGym, spare: [.lowerBack, .knee]))
        for e in p.days.flatMap(\.exercises) {
            let option = ProgramGenerator.options.first { $0.id == e.id }!
            XCTAssertTrue(option.loads.isDisjoint(with: [.lowerBack, .knee]), "\(e.title) loads a spared joint")
        }
        XCTAssertFalse(p.days.flatMap(\.exercises).contains { $0.id == "back-squat" || $0.id == "deadlift" })
    }

    func testPrescriptionFollowsGoalAndTheFirstLiftWarmsUp() {
        let strength = ProgramGenerator.generate(.init(goal: .strength, level: .intermediate, daysPerWeek: 4, minutes: 60, equipment: fullGym))
        let first = strength.days[0].exercises[0]
        XCTAssertEqual(first.plan.sets.filter { $0.phase == .warmup }.count, 2)
        let work = first.plan.sets.filter { $0.phase == .work }
        XCTAssertGreaterThanOrEqual(work.count, 4)
        XCTAssertEqual(work.first?.repsMax, 6)
        XCTAssertEqual(first.plan.progression?.policy, .doubleProgression)
        let general = ProgramGenerator.generate(.init(goal: .general, level: .beginner, daysPerWeek: 4, minutes: 60, equipment: fullGym))
        XCTAssertEqual(general.days[0].exercises[0].plan.sets.filter { $0.phase == .work }.count, 2, "beginners do a set less on compounds")
    }

    func testFocusAddsSetsAndEveryGroupIsTrained() {
        let base = ProgramGenerator.generate(.init(goal: .muscle, level: .intermediate, daysPerWeek: 4, minutes: 60, equipment: fullGym))
        let focused = ProgramGenerator.generate(.init(goal: .muscle, level: .intermediate, daysPerWeek: 4, minutes: 60,
                                                      equipment: fullGym, focus: [.chest]))
        XCTAssertGreaterThan(focused.weeklySets[.chest] ?? 0, base.weeklySets[.chest] ?? 0)
        for days in 2...6 {
            for goal in [ProgramGenerator.Goal.muscle, .strength] {
                let p = ProgramGenerator.generate(.init(goal: goal, level: .intermediate, daysPerWeek: days, minutes: 60, equipment: fullGym))
                for g in ProgramGenerator.majorGroups {
                    XCTAssertGreaterThanOrEqual(p.weeklySets[g] ?? 0, 10, "\(days)-day \(goal): \(g) under ten sets")
                }
                XCTAssertTrue(p.days.flatMap(\.exercises).allSatisfy { ProgramGenerator.workSets($0) <= 5 })
            }
        }
    }

    func testTheSameAnswersGiveTheSameProgram() {
        let input = ProgramGenerator.Input(goal: .muscle, level: .advanced, daysPerWeek: 5, minutes: 75, equipment: fullGym)
        XCTAssertEqual(ProgramGenerator.generate(input), ProgramGenerator.generate(input))
    }
}
