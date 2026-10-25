import Foundation

/// Builds a weekly training program from a few answers: goal, experience, days a week, time per
/// session, equipment at hand, and joints to spare.
///
/// The method is the conventional one, written out so it can be checked:
/// - **Split by frequency.** Two or three days train the whole body each time; four alternate upper and
///   lower; five add a push, pull and legs block to an upper/lower pair; six run push, pull, legs twice.
///   Every muscle is trained at least twice a week at four days or more.
/// - **Movement patterns, not muscles.** A day is an ordered list of patterns (squat, hinge, horizontal
///   push…), compound ones first. Each pattern is filled with the first exercise whose equipment is at
///   hand and which does not load a joint the lifter asked to spare. A pattern with no such exercise is
///   left out rather than filled with something unsuitable.
/// - **Volume by goal and time.** Strength works heavy, low-rep compounds with long rests; muscle work
///   uses moderate reps; general fitness higher reps and shorter rests. Session length sets how many
///   patterns a day keeps — the lowest-priority ones go first. Beginners do a set less on compounds.
/// - **Progression is the routine's own.** Each exercise gets double progression over its rep range,
///   with the routine's deload after repeated misses (`ProgressionEngine`).
///
/// Deterministic: the same answers always produce the same program.
public enum ProgramGenerator {

    public enum Goal: String, CaseIterable, Codable, Sendable { case strength, muscle, general }
    public enum Level: String, CaseIterable, Codable, Sendable { case beginner, intermediate, advanced }
    public enum Joint: String, CaseIterable, Codable, Sendable { case shoulder, elbow, wrist, lowerBack, hip, knee }

    /// What a gym can offer. `bodyweight` is always available.
    public enum Equipment: String, CaseIterable, Codable, Sendable {
        case barbell, rack, bench, dumbbell, cable, machine, pullUpBar, kettlebell
    }

    public struct Input: Equatable, Codable, Sendable {
        public var goal: Goal
        public var level: Level
        public var daysPerWeek: Int
        public var minutes: Int
        public var equipment: Set<Equipment>
        public var spare: Set<Joint>
        /// Muscle-group ids (`ProgramGenerator.Group`) to give an extra set.
        public var focus: Set<Group>

        public init(goal: Goal, level: Level, daysPerWeek: Int, minutes: Int,
                    equipment: Set<Equipment>, spare: Set<Joint> = [], focus: Set<Group> = []) {
            self.goal = goal
            self.level = level
            self.daysPerWeek = min(6, max(2, daysPerWeek))
            self.minutes = min(120, max(20, minutes))
            self.equipment = equipment
            self.spare = spare
            self.focus = focus
        }
    }

    /// The groups the weekly volume preview and the focus choice speak in.
    public enum Group: String, CaseIterable, Codable, Sendable {
        case chest, back, shoulders, arms, quads, hamstrings, glutes, calves, core

        public var title: String {
            switch self {
            case .chest: "Chest"
            case .back: "Back"
            case .shoulders: "Shoulders"
            case .arms: "Arms"
            case .quads: "Quads"
            case .hamstrings: "Hamstrings"
            case .glutes: "Glutes"
            case .calves: "Calves"
            case .core: "Core"
            }
        }
    }

    public struct Exercise: Equatable, Sendable {
        public let id: String
        public let title: String
        public let primaryMuscleIds: [String]
        public let secondaryMuscleIds: [String]
        public let groups: [Group]
        public let compound: Bool
        public let mode: TrainingMeasurementMode
        public let plan: RoutineExercise
    }

    public struct Day: Equatable, Sendable {
        public let title: String
        public let exercises: [Exercise]
    }

    public struct Program: Equatable, Sendable {
        public let name: String
        public let split: String
        public let days: [Day]
        /// Working sets per group per week: a set counts 1 for its main groups, ½ for the rest.
        public let weeklySets: [Group: Double]
        /// Patterns left out because nothing suitable was at hand.
        public let missing: [String]
    }

    // MARK: - Generate

    public static func generate(_ input: Input) -> Program {
        let (split, templates) = Self.split(input)
        var missing: [String] = []
        var days: [Day] = []
        for (index, template) in templates.enumerated() {
            let keep = Self.patternCount(minutes: input.minutes)
            var exercises: [Exercise] = []
            var used = Set<String>()
            for slot in template.slots {
                guard exercises.count < keep else { break }
                guard let option = Self.pick(slot.pattern, variant: slot.variant, input: input, used: used) else {
                    missing.append(slot.pattern.title)
                    continue
                }
                used.insert(option.id)
                exercises.append(Self.exercise(option, input: input, isFirst: exercises.isEmpty, dayIndex: index))
            }
            // A focus group gets one isolation exercise a day it belongs on, when time allows one more:
            // more sets on the same press only go so far.
            if exercises.count < keep + 1 {
                for group in Group.allCases where input.focus.contains(group) && template.mayCarry(group) {
                    if let pattern = Pattern.isolation(for: group),
                       let option = Self.pick(pattern, variant: 0, input: input, used: used) {
                        used.insert(option.id)
                        exercises.append(Self.exercise(option, input: input, isFirst: false, dayIndex: index))
                        break
                    }
                }
            }
            days.append(Day(title: template.title, exercises: exercises))
        }
        // Muscle and strength goals bring every major group up to the ten weekly sets the growth
        // literature centres on: one more working set on that group's lifts, in turn, up to five sets an
        // exercise. General fitness keeps the lighter week it asked for.
        if input.goal != .general {
            // A focus group aims higher, so asking for it always shows in the week.
            for g in Self.majorGroups + input.focus.filter({ !Self.majorGroups.contains($0) }).sorted(by: { $0.rawValue < $1.rawValue }) {
                let target = input.focus.contains(g) ? Self.focusWeeklySets : Self.minimumWeeklySets
                var guardrail = 0
                while (Self.weekly(days)[g] ?? 0) < target, guardrail < 12 {
                    guardrail += 1
                    var added = false
                    for d in days.indices {
                        guard (Self.weekly(days)[g] ?? 0) < target else { break }
                        if let i = days[d].exercises.firstIndex(where: { $0.groups.contains(g) && Self.workSets($0) < 5 && $0.mode != .duration }) {
                            days[d] = Self.addingSet(to: i, in: days[d], dayIndex: d)
                            added = true
                        }
                    }
                    if !added { break }
                }
            }
        }
        let weekly = Self.weekly(days)
        let name = "\(input.daysPerWeek)-day \(split)"
        return Program(name: name, split: split, days: days, weeklySets: weekly,
                       missing: Array(NSOrderedSet(array: missing).compactMap { $0 as? String }))
    }

    /// The groups a muscle or strength program must bring to `minimumWeeklySets`.
    static let majorGroups: [Group] = [.chest, .back, .shoulders, .quads, .hamstrings, .glutes]
    static let minimumWeeklySets: Double = 10
    static let focusWeeklySets: Double = 14

    static func workSets(_ e: Exercise) -> Int { e.plan.sets.filter { $0.phase == .work }.count }

    static func weekly(_ days: [Day]) -> [Group: Double] {
        var out: [Group: Double] = [:]
        for day in days {
            for e in day.exercises {
                let sets = Double(workSets(e))
                let primary = Set(e.primaryMuscleIds.compactMap(group))
                for g in primary { out[g, default: 0] += sets }
                for g in Set(e.secondaryMuscleIds.compactMap(group)).subtracting(primary) {
                    out[g, default: 0] += sets * 0.5
                }
            }
        }
        return out
    }

    /// The day with one more working set on exercise `i`, a copy of its last working set.
    private static func addingSet(to i: Int, in day: Day, dayIndex: Int) -> Day {
        var exercises = day.exercises
        let e = exercises[i]
        var plan = e.plan
        if let last = plan.sets.last(where: { $0.phase == .work }) {
            var copy = last
            copy = RoutineSetPlan(id: stableUUID("\(dayIndex)-\(e.id)-set-\(10 + workSets(e))"), phase: .work,
                                  targetWeightKg: last.targetWeightKg, repsMin: last.repsMin, repsMax: last.repsMax,
                                  targetDurationS: last.targetDurationS, restSeconds: last.restSeconds)
            plan.sets.append(copy)
        }
        exercises[i] = Exercise(id: e.id, title: e.title, primaryMuscleIds: e.primaryMuscleIds,
                                secondaryMuscleIds: e.secondaryMuscleIds, groups: e.groups, compound: e.compound,
                                mode: e.mode, plan: plan)
        return Day(title: day.title, exercises: exercises)
    }

    /// Patterns a session keeps for its length: about ten minutes each, warm-up included.
    public static func patternCount(minutes: Int) -> Int {
        switch minutes {
        case ..<40: 4
        case ..<55: 5
        case ..<70: 6
        case ..<85: 7
        default: 8
        }
    }

    // MARK: - Prescription

    private static func exercise(_ o: Option, input: Input, isFirst: Bool, dayIndex: Int) -> Exercise {
        let (sets, low, high, rest): (Int, Int, Int, Int) = {
            switch (input.goal, o.compound) {
            case (.strength, true): return (4, 4, 6, 180)
            case (.strength, false): return (3, 8, 12, 90)
            case (.muscle, true): return (3, 6, 10, 150)
            case (.muscle, false): return (3, 10, 15, 75)
            case (.general, true): return (3, 8, 12, 120)
            case (.general, false): return (2, 12, 15, 60)
            }
        }()
        var working = sets
        if input.level == .beginner, o.compound { working = max(2, working - 1) }
        if input.level == .advanced, isFirst { working += 1 }
        if !Set(o.primaryMuscleIds.compactMap(group)).isDisjoint(with: input.focus) { working += 1 }
        let timed = o.mode == .duration
        var plans: [RoutineSetPlan] = []
        func id(_ n: Int) -> UUID { stableUUID("\(dayIndex)-\(o.id)-set-\(n)") }
        // The first lift of the day ramps up: two light sets the session counts as warm-ups.
        if isFirst, o.compound, o.mode == .weightReps {
            plans += [RoutineSetPlan(id: id(0), phase: .warmup, repsMin: 8, repsMax: 8, restSeconds: 60),
                      RoutineSetPlan(id: id(1), phase: .warmup, repsMin: 5, repsMax: 5, restSeconds: 60)]
        }
        plans += (0..<working).map { n in
            timed ? RoutineSetPlan(id: id(10 + n), targetDurationS: input.goal == .general ? 45 : 40, restSeconds: 60)
                  : RoutineSetPlan(id: id(10 + n), repsMin: low, repsMax: high, restSeconds: rest)
        }
        let progression = timed
            ? ProgressionConfiguration(policy: .time, durationIncrementS: 5)
            : ProgressionConfiguration(policy: o.mode == .weightReps ? .doubleProgression : .off,
                                       weightIncrementKg: o.groups.contains(where: { [.quads, .hamstrings, .glutes].contains($0) }) && o.compound ? 5 : 2.5,
                                       repsMin: low, repsMax: high)
        let plan = RoutineExercise(id: stableUUID("\(dayIndex)-\(o.id)"), exerciseId: o.id, sets: plans,
                                   restSeconds: timed ? 60 : rest, warmupRestSeconds: 60, progression: progression)
        return Exercise(id: o.id, title: o.title, primaryMuscleIds: o.primaryMuscleIds,
                        secondaryMuscleIds: o.secondaryMuscleIds, groups: o.groups, compound: o.compound,
                        mode: o.mode, plan: plan)
    }

    /// A UUID derived from a string, so the same answers give the same plan ids.
    private static func stableUUID(_ key: String) -> UUID {
        var h1: UInt64 = 0xcbf29ce484222325, h2: UInt64 = 0x84222325cbf29ce4
        for u in key.utf16 {
            h1 = (h1 ^ UInt64(u)) &* 0x100000001b3
            h2 = (h2 ^ UInt64(u)) &* 0x100000001b3 &+ 0x9e3779b97f4a7c15
        }
        let b = withUnsafeBytes(of: h1.bigEndian, Array.init) + withUnsafeBytes(of: h2.bigEndian, Array.init)
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], (b[6] & 0x0F) | 0x40, b[7],
                           (b[8] & 0x3F) | 0x80, b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }

    // MARK: - Splits

    struct Slot { let pattern: Pattern; let variant: Int }

    struct Template {
        let title: String
        let slots: [Slot]
        /// Which focus groups this day may add an isolation for: an upper day never gets a calf raise.
        let region: Region
        enum Region { case full, upper, lower }

        func mayCarry(_ g: Group) -> Bool {
            switch region {
            case .full: true
            case .upper: [.chest, .back, .shoulders, .arms, .core].contains(g)
            case .lower: [.quads, .hamstrings, .glutes, .calves, .core].contains(g)
            }
        }
    }

    private static func s(_ p: Pattern, _ v: Int = 0) -> Slot { Slot(pattern: p, variant: v) }

    static func split(_ input: Input) -> (String, [Template]) {
        let fullA = Template(title: "Full body A", slots: [s(.squat), s(.horizontalPush), s(.horizontalPull), s(.hinge, 1),
                                                           s(.sideDelts), s(.core), s(.elbowFlexion), s(.calves)], region: .full)
        let fullB = Template(title: "Full body B", slots: [s(.hinge), s(.inclinePush), s(.verticalPull), s(.lunge),
                                                           s(.verticalPush), s(.elbowExtension), s(.core, 1), s(.rearDelts)], region: .full)
        let fullC = Template(title: "Full body C", slots: [s(.squat, 1), s(.inclinePush), s(.horizontalPull, 1), s(.kneeFlexion),
                                                           s(.sideDelts), s(.elbowFlexion, 1), s(.core), s(.calves)], region: .full)
        let upperA = Template(title: "Upper A", slots: [s(.horizontalPush), s(.horizontalPull), s(.verticalPush), s(.verticalPull),
                                                        s(.sideDelts), s(.elbowFlexion), s(.elbowExtension), s(.rearDelts)], region: .upper)
        let upperB = Template(title: "Upper B", slots: [s(.inclinePush), s(.verticalPull, 1), s(.horizontalPull, 1), s(.verticalPush, 1),
                                                        s(.sideDelts), s(.elbowExtension, 1), s(.elbowFlexion, 1), s(.rearDelts)], region: .upper)
        let lowerA = Template(title: "Lower A", slots: [s(.squat), s(.hinge, 1), s(.lunge), s(.kneeFlexion),
                                                        s(.calves), s(.core), s(.kneeExtension)], region: .lower)
        let lowerB = Template(title: "Lower B", slots: [s(.hinge), s(.squat, 1), s(.kneeExtension), s(.kneeFlexion),
                                                        s(.calves), s(.core, 1), s(.lunge, 1)], region: .lower)
        let push = Template(title: "Push", slots: [s(.horizontalPush), s(.verticalPush), s(.inclinePush), s(.sideDelts),
                                                   s(.elbowExtension), s(.chestIsolation), s(.elbowExtension, 1)], region: .upper)
        let pull = Template(title: "Pull", slots: [s(.verticalPull), s(.horizontalPull), s(.horizontalPull, 1), s(.rearDelts),
                                                   s(.elbowFlexion), s(.elbowFlexion, 1), s(.core)], region: .upper)
        let legs = Template(title: "Legs", slots: [s(.squat), s(.hinge, 1), s(.lunge), s(.kneeExtension),
                                                   s(.kneeFlexion), s(.calves), s(.core)], region: .lower)
        func variant(_ t: Template, _ title: String) -> Template {
            Template(title: title, slots: t.slots.map { s($0.pattern, $0.variant + 1) }, region: t.region)
        }
        switch input.daysPerWeek {
        case 2: return ("full body", [fullA, fullB])
        case 3 where input.level == .advanced: return ("push, pull, legs", [push, pull, legs])
        case 3: return ("full body", [fullA, fullB, fullC])
        case 4: return ("upper/lower", [upperA, lowerA, upperB, lowerB])
        case 5: return ("upper/lower + PPL", [upperA, lowerA, push, pull, legs])
        default: return ("push, pull, legs", [push, pull, legs, variant(push, "Push B"), variant(pull, "Pull B"), variant(legs, "Legs B")])
        }
    }

    // MARK: - Exercise options

    enum Pattern: String, CaseIterable {
        case squat, hinge, lunge, kneeFlexion, kneeExtension, calves
        case horizontalPush, inclinePush, verticalPush, chestIsolation
        case horizontalPull, verticalPull, sideDelts, rearDelts
        case elbowFlexion, elbowExtension, core

        var title: String {
            switch self {
            case .squat: "Squat"
            case .hinge: "Hinge"
            case .lunge: "Lunge"
            case .kneeFlexion: "Leg curl"
            case .kneeExtension: "Leg extension"
            case .calves: "Calves"
            case .horizontalPush: "Press"
            case .inclinePush: "Incline press"
            case .verticalPush: "Overhead press"
            case .chestIsolation: "Chest fly"
            case .horizontalPull: "Row"
            case .verticalPull: "Pull-down"
            case .sideDelts: "Lateral raise"
            case .rearDelts: "Rear delts"
            case .elbowFlexion: "Curl"
            case .elbowExtension: "Triceps"
            case .core: "Core"
            }
        }

        static func isolation(for g: Group) -> Pattern? {
            switch g {
            case .chest: .chestIsolation
            case .back: .rearDelts
            case .shoulders: .sideDelts
            case .arms: .elbowFlexion
            case .quads: .kneeExtension
            case .hamstrings: .kneeFlexion
            case .glutes: .lunge
            case .calves: .calves
            case .core: .core
            }
        }
    }

    struct Option {
        let id: String
        let title: String
        let pattern: Pattern
        /// Any one inner set is enough: [[dumbbell, bench], [machine]] needs dumbbells and a bench, or a machine.
        let needs: [Set<Equipment>]
        let loads: Set<Joint>
        let compound: Bool
        let mode: TrainingMeasurementMode
        let primaryMuscleIds: [String]
        let secondaryMuscleIds: [String]
        var groups: [Group] { Array(NSOrderedSet(array: primaryMuscleIds.compactMap(ProgramGenerator.group))).compactMap { $0 as? Group } }
    }

    private static func o(_ id: String, _ title: String, _ p: Pattern, _ needs: [Set<Equipment>], _ loads: Set<Joint>,
                          compound: Bool, mode: TrainingMeasurementMode = .weightReps,
                          _ primary: [String], _ secondary: [String] = []) -> Option {
        Option(id: id, title: title, pattern: p, needs: needs, loads: loads, compound: compound, mode: mode,
               primaryMuscleIds: primary, secondaryMuscleIds: secondary)
    }

    /// In order of preference within each pattern. Titles match the exercise catalogue where it has one.
    static let options: [Option] = [
        o("back-squat", "Back Squat", .squat, [[.barbell, .rack]], [.knee, .lowerBack], compound: true, ["quadriceps", "glutes"], ["hamstrings", "adductors"]),
        o("leg-press", "Leg Press", .squat, [[.machine]], [.knee], compound: true, ["quadriceps", "glutes"], ["hamstrings"]),
        o("goblet-squat", "Goblet Squat", .squat, [[.dumbbell], [.kettlebell]], [.knee], compound: true, ["quadriceps", "glutes"], ["adductors"]),
        o("front-squat", "Front Squat", .squat, [[.barbell, .rack]], [.knee, .wrist], compound: true, ["quadriceps"], ["glutes"]),
        o("bodyweight-squat", "Bodyweight Squat", .squat, [[]], [.knee], compound: true, mode: .bodyweightReps, ["quadriceps", "glutes"]),
        o("romanian-deadlift", "Romanian Deadlift", .hinge, [[.barbell], [.dumbbell]], [.lowerBack], compound: true, ["hamstrings", "glutes"], ["lower_back"]),
        o("hip-thrust", "Hip Thrust", .hinge, [[.barbell, .bench], [.machine]], [.hip], compound: true, ["glutes"], ["hamstrings"]),
        o("deadlift", "Deadlift", .hinge, [[.barbell]], [.lowerBack, .hip], compound: true, ["glutes", "hamstrings"], ["lower_back", "upper_back", "quadriceps"]),
        o("kettlebell-swing", "Kettlebell Swing", .hinge, [[.kettlebell]], [.lowerBack], compound: true, ["glutes", "hamstrings"], ["lower_back"]),
        o("glute-bridge", "Glute Bridge", .hinge, [[]], [], compound: true, mode: .bodyweightReps, ["glutes"], ["hamstrings"]),
        o("bulgarian-split-squat", "Bulgarian Split Squat", .lunge, [[.dumbbell, .bench], [.bench]], [.knee], compound: true, ["quadriceps", "glutes"], ["hamstrings", "adductors"]),
        o("lunge", "Lunge", .lunge, [[.dumbbell], []], [.knee], compound: true, ["quadriceps", "glutes"], ["hamstrings"]),
        o("step-up", "Step-up", .lunge, [[.dumbbell, .bench], [.bench]], [.knee], compound: true, ["quadriceps", "glutes"]),
        o("leg-curl", "Leg Curl", .kneeFlexion, [[.machine]], [], compound: false, ["hamstrings"]),
        o("nordic-curl", "Nordic Curl", .kneeFlexion, [[.bench]], [.knee], compound: false, mode: .bodyweightReps, ["hamstrings"]),
        o("leg-extension", "Leg Extension", .kneeExtension, [[.machine]], [.knee], compound: false, ["quadriceps"]),
        o("calf-raise", "Calf Raise", .calves, [[.machine], [.dumbbell], []], [], compound: false, ["calves"]),
        o("barbell-bench-press", "Barbell Bench Press", .horizontalPush, [[.barbell, .bench]], [.shoulder, .wrist], compound: true, ["chest"], ["triceps", "front_delts"]),
        o("dumbbell-bench-press", "Dumbbell Bench Press", .horizontalPush, [[.dumbbell, .bench]], [.shoulder], compound: true, ["chest"], ["triceps", "front_delts"]),
        o("chest-press", "Chest Press", .horizontalPush, [[.machine]], [.shoulder], compound: true, ["chest"], ["triceps", "front_delts"]),
        o("push-up", "Push-up", .horizontalPush, [[]], [.wrist], compound: true, mode: .bodyweightReps, ["chest"], ["triceps", "front_delts"]),
        o("incline-dumbbell-press", "Incline Dumbbell Press", .inclinePush, [[.dumbbell, .bench]], [.shoulder], compound: true, ["upper_chest"], ["triceps", "front_delts"]),
        o("incline-press", "Incline Press", .inclinePush, [[.barbell, .bench], [.machine]], [.shoulder, .wrist], compound: true, ["upper_chest"], ["triceps", "front_delts"]),
        o("dip", "Dip", .inclinePush, [[.pullUpBar]], [.shoulder, .elbow], compound: true, mode: .bodyweightReps, ["lower_chest", "triceps"], ["front_delts"]),
        o("overhead-press", "Overhead Press", .verticalPush, [[.barbell]], [.shoulder, .lowerBack], compound: true, ["front_delts"], ["triceps", "side_delts"]),
        o("dumbbell-shoulder-press", "Dumbbell Shoulder Press", .verticalPush, [[.dumbbell]], [.shoulder], compound: true, ["front_delts"], ["triceps", "side_delts"]),
        o("pike-push-up", "Pike Push-up", .verticalPush, [[]], [.shoulder, .wrist], compound: true, mode: .bodyweightReps, ["front_delts"], ["triceps"]),
        o("chest-fly", "Chest Fly", .chestIsolation, [[.cable], [.machine], [.dumbbell, .bench]], [.shoulder], compound: false, ["chest"], ["front_delts"]),
        o("barbell-row", "Barbell Row", .horizontalPull, [[.barbell]], [.lowerBack], compound: true, ["upper_back", "lats"], ["biceps", "rear_delts"]),
        o("seated-cable-row", "Seated Cable Row", .horizontalPull, [[.cable]], [], compound: true, ["upper_back", "lats"], ["biceps", "rear_delts"]),
        o("dumbbell-row", "Dumbbell Row", .horizontalPull, [[.dumbbell, .bench], [.dumbbell]], [], compound: true, ["lats", "upper_back"], ["biceps", "rear_delts"]),
        o("chest-supported-row", "Chest-supported Row", .horizontalPull, [[.machine], [.dumbbell, .bench]], [], compound: true, ["upper_back", "lats"], ["biceps", "rear_delts"]),
        o("inverted-row", "Inverted Row", .horizontalPull, [[.pullUpBar], [.barbell, .rack]], [], compound: true, mode: .bodyweightReps, ["upper_back", "lats"], ["biceps"]),
        o("pull-up", "Pull-up", .verticalPull, [[.pullUpBar]], [.shoulder, .elbow], compound: true, mode: .bodyweightReps, ["lats"], ["biceps", "upper_back"]),
        o("lat-pulldown", "Lat Pulldown", .verticalPull, [[.cable], [.machine]], [], compound: true, ["lats"], ["biceps", "upper_back"]),
        o("assisted-pull-up", "Assisted Pull-up", .verticalPull, [[.machine]], [], compound: true, mode: .assistedBodyweight, ["lats"], ["biceps", "upper_back"]),
        o("lateral-raise", "Lateral Raise", .sideDelts, [[.dumbbell], [.cable]], [.shoulder], compound: false, ["side_delts"]),
        o("face-pull", "Face Pull", .rearDelts, [[.cable]], [], compound: false, ["rear_delts"], ["upper_back"]),
        o("rear-delt-fly", "Rear Delt Fly", .rearDelts, [[.dumbbell], [.machine]], [], compound: false, ["rear_delts"], ["upper_back"]),
        o("dumbbell-curl", "Dumbbell Curl", .elbowFlexion, [[.dumbbell]], [.elbow], compound: false, ["biceps"], ["forearms"]),
        o("barbell-curl", "Barbell Curl", .elbowFlexion, [[.barbell]], [.elbow, .wrist], compound: false, ["biceps"], ["forearms"]),
        o("hammer-curl", "Hammer Curl", .elbowFlexion, [[.dumbbell]], [], compound: false, ["biceps", "forearms"]),
        o("cable-curl", "Cable Curl", .elbowFlexion, [[.cable]], [.elbow], compound: false, ["biceps"]),
        o("triceps-pushdown", "Triceps Pushdown", .elbowExtension, [[.cable]], [.elbow], compound: false, ["triceps"]),
        o("triceps-extension", "Triceps Extension", .elbowExtension, [[.dumbbell], [.cable]], [.elbow, .shoulder], compound: false, ["triceps"]),
        o("diamond-push-up", "Diamond Push-up", .elbowExtension, [[]], [.wrist, .elbow], compound: false, mode: .bodyweightReps, ["triceps"], ["chest"]),
        o("plank", "Plank", .core, [[]], [], compound: false, mode: .duration, ["abdominals"], ["obliques"]),
        o("hanging-leg-raise", "Hanging Leg Raise", .core, [[.pullUpBar]], [.shoulder], compound: false, mode: .bodyweightReps, ["lower_abs", "hip_flexors"]),
        o("cable-crunch", "Cable Crunch", .core, [[.cable]], [.lowerBack], compound: false, ["abdominals"]),
        o("dead-bug", "Dead Bug", .core, [[]], [], compound: false, mode: .bodyweightReps, ["abdominals"]),
    ]

    /// The `variant`-th suitable option for a pattern, wrapping round; nil when none suits.
    static func pick(_ pattern: Pattern, variant: Int, input: Input, used: Set<String>) -> Option? {
        let have = input.equipment
        let suitable = options.filter { o in
            o.pattern == pattern && o.loads.isDisjoint(with: input.spare)
                && o.needs.contains { $0.isSubset(of: have) } && !used.contains(o.id)
        }
        guard !suitable.isEmpty else { return nil }
        return suitable[variant % suitable.count]
    }

    static func group(_ muscleId: String) -> Group? {
        switch muscleId {
        case "chest", "upper_chest", "lower_chest": .chest
        case "lats", "upper_back", "rhomboids", "traps", "upper_traps", "lower_traps", "lower_back": .back
        case "front_delts", "side_delts", "rear_delts": .shoulders
        case "biceps", "triceps", "forearms": .arms
        case "quadriceps": .quads
        case "hamstrings": .hamstrings
        case "glutes", "adductors", "abductors": .glutes
        case "calves", "tibialis": .calves
        case "abdominals", "upper_abs", "lower_abs", "obliques", "hip_flexors": .core
        default: nil
        }
    }
}
