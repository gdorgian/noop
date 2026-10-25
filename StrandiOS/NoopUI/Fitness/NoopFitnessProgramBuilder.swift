#if os(iOS)
import SwiftUI
import StrandTraining
import WhoopStore

/// "Build a program for me": a handful of answers, a preview of the week it gives, and one tap to turn
/// it into ordinary routines — editable, startable and schedulable like any other (`ProgramGenerator`).
struct NoopFitnessProgramBuilder: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var fitness: NoopFitnessModel
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var settings: NoopFitnessSettings
    @AppStorage("fitness.program.answers") private var stored = ""

    @State private var goal: ProgramGenerator.Goal = .muscle
    @State private var level: ProgramGenerator.Level = .intermediate
    @State private var days = 4
    @State private var minutes = 60
    @State private var equipment: Set<ProgramGenerator.Equipment> = Set(ProgramGenerator.Equipment.allCases)
    @State private var spare: Set<ProgramGenerator.Joint> = []
    @State private var focus: Set<ProgramGenerator.Group> = []
    @State private var weekdays: Set<Int> = []
    @State private var schedule = true
    @State private var saving = false
    @State private var error: String?
    @State private var loaded = false

    private var input: ProgramGenerator.Input {
        .init(goal: goal, level: level, daysPerWeek: days, minutes: minutes, equipment: equipment, spare: spare, focus: focus)
    }

    var body: some View {
        let program = ProgramGenerator.generate(input)
        NoopFitnessPage(navigation: navigation, title: "Build a program",
                        subtitle: "Answer a few questions. Noop lays out a week of routines you can edit, start and schedule like any other.") {
            VStack(alignment: .leading, spacing: 22) {
                question("Goal") {
                    chips(ProgramGenerator.Goal.allCases, selected: [goal], title: Self.title) { goal = $0 }
                }
                question("Experience") {
                    chips(ProgramGenerator.Level.allCases, selected: [level], title: Self.title) { level = $0 }
                }
                question("Days a week") {
                    NoopTabs(options: (2...6).map { ("\($0)", $0) }, selection: $days)
                }
                question("Time per session") {
                    NoopTabs(options: [30, 45, 60, 75, 90].map { ("\($0) min", $0) }, selection: $minutes)
                }
                question("Equipment you have", note: "Bodyweight exercises are always available.") {
                    HStack(spacing: 6) {
                        presetChip("Full gym", Set(ProgramGenerator.Equipment.allCases))
                        presetChip("Home", [.dumbbell, .bench, .pullUpBar])
                        presetChip("None", [])
                    }
                    chips(ProgramGenerator.Equipment.allCases, selected: equipment, title: Self.title) { e in
                        if equipment.contains(e) { equipment.remove(e) } else { equipment.insert(e) }
                    }
                }
                question("Spare these joints", note: "Exercises that load them are left out.") {
                    chips(ProgramGenerator.Joint.allCases, selected: spare, title: Self.title) { j in
                        if spare.contains(j) { spare.remove(j) } else { spare.insert(j) }
                    }
                }
                question("Extra focus", note: "One more set for these, and an extra exercise where a day has room.") {
                    chips(ProgramGenerator.Group.allCases, selected: focus, title: { $0.title }) { g in
                        if focus.contains(g) { focus.remove(g) } else { focus.insert(g) }
                    }
                }
                preview(program)
                scheduleSection(program)
                if let error { Text(error).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.red) }
                NoopActionButton(title: saving ? "Creating…" : "Create \(program.days.count) routines",
                                 enabled: !saving && !program.days.contains { $0.exercises.isEmpty }) {
                    Task { await create(program) }
                }
            }
            .animation(NoopMotion.swap, value: input)
        }
        .onAppear(perform: restore)
        .onChange(of: input) { _, _ in remember() }
        .onChange(of: days) { _, n in weekdays = Self.defaultWeekdays(n) }
    }

    // MARK: Pieces

    private func question<C: View>(_ title: String, note: String? = nil, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            NoopSectionLabel(title)
            content()
            if let note {
                Text(note).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.muted)
            }
        }
    }

    private func chips<T: Hashable>(_ all: [T], selected: Set<T>, title: @escaping (T) -> String,
                                    toggle: @escaping (T) -> Void) -> some View {
        NoopFlowLayout(spacing: 6) {
            ForEach(all, id: \.self) { v in NoopChip(title: title(v), isOn: selected.contains(v)) { toggle(v) } }
        }
    }

    private func presetChip(_ label: String, _ set: Set<ProgramGenerator.Equipment>) -> some View {
        NoopChip(title: label, systemImage: equipment == set ? "checkmark" : nil, isOn: equipment == set) { equipment = set }
    }

    private func preview(_ p: ProgramGenerator.Program) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                NoopSectionLabel("Your week")
                Spacer()
                Text(p.name).font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(NoopHTMLColor.volt)
            }
            ForEach(Array(p.days.enumerated()), id: \.offset) { _, day in
                NoopSessionCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(day.title).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                            Spacer()
                            Text("\(day.exercises.count) exercises").font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                        }
                        ForEach(day.exercises, id: \.id) { e in
                            let work = e.plan.sets.filter { $0.phase == .work }
                            HStack {
                                Text(e.title).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.inkSoft)
                                Spacer()
                                Text(prescription(work)).font(NoopHTMLFont.sans(NoopType.caption)).monospacedDigit()
                                    .foregroundStyle(NoopHTMLColor.copy)
                            }
                        }
                    }
                }
            }
            weekly(p)
            if !p.missing.isEmpty {
                Text("Nothing at hand for: \(p.missing.joined(separator: ", ")). Add equipment, or spare fewer joints, to fill them.")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.amber)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func prescription(_ work: [RoutineSetPlan]) -> String {
        guard let first = work.first else { return "" }
        if let s = first.targetDurationS { return "\(work.count) × \(s)s" }
        let reps = first.repsMin == first.repsMax ? "\(first.repsMin ?? 0)" : "\(first.repsMin ?? 0)–\(first.repsMax ?? 0)"
        return "\(work.count) × \(reps)"
    }

    /// Weekly sets per group against the 10–20 range Muscle groups uses, so the plan can be read the
    /// same way the training it produces will be.
    private func weekly(_ p: ProgramGenerator.Program) -> some View {
        let range = NoopFitnessMuscleGroupsScreen.setRange
        let groups = ProgramGenerator.Group.allCases.filter { (p.weeklySets[$0] ?? 0) > 0 }
        return NoopSessionCard {
            VStack(alignment: .leading, spacing: 10) {
                NoopSessionCardTitle(symbol: "chart.bar.fill", title: "Sets a week per muscle")
                ForEach(groups, id: \.self) { g in
                    let n = p.weeklySets[g] ?? 0
                    HStack(spacing: 10) {
                        Text(g.title).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.ink).frame(width: 92, alignment: .leading)
                        GeometryReader { geo in
                            let scale = geo.size.width / CGFloat(max(range.upperBound + 6, n))
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.06))
                                Rectangle().fill(NoopHTMLColor.green.opacity(0.12))
                                    .frame(width: CGFloat(range.upperBound - range.lowerBound) * scale)
                                    .offset(x: CGFloat(range.lowerBound) * scale)
                                Capsule().fill(n >= range.lowerBound ? NoopHTMLColor.green : NoopHTMLColor.inkSoft.opacity(0.7))
                                    .frame(width: max(6, CGFloat(n) * scale))
                            }
                        }
                        .frame(height: 8)
                        Text(n == n.rounded() ? "\(Int(n))" : String(format: "%.1f", n))
                            .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).monospacedDigit()
                            .foregroundStyle(NoopHTMLColor.copy).frame(width: 34, alignment: .trailing)
                    }
                }
                Text("The shaded band is 10–20 sets a week, where most growth studies see clear gains.")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.muted)
            }
        }
    }

    private func scheduleSection(_ p: ProgramGenerator.Program) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            NoopToggleRow(title: "Put it on the calendar",
                          subtitle: "The routines rotate through the days you pick, for the next six weeks.",
                          isOn: $schedule)
            if schedule {
                HStack(spacing: 6) {
                    ForEach(Self.weekOrder, id: \.self) { wd in
                        let on = weekdays.contains(wd)
                        Button {
                            if on { weekdays.remove(wd) } else { weekdays.insert(wd) }
                        } label: {
                            Text(Calendar.current.veryShortWeekdaySymbols[wd - 1])
                                .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                                .foregroundStyle(on ? NoopHTMLColor.voltInk : NoopHTMLColor.inkSoft)
                                .frame(maxWidth: .infinity).frame(height: 40)
                                .background(on ? NoopHTMLColor.volt : Color.white.opacity(0.07), in: Circle())
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                    }
                }
                if weekdays.count != p.days.count {
                    Text("\(weekdays.count) days picked for \(p.days.count) routines; they rotate in order.")
                        .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.muted)
                }
            }
        }
    }

    // MARK: Create

    private func create(_ p: ProgramGenerator.Program) async {
        guard !saving, let store = await repo.storeHandle() else { return }
        saving = true
        defer { saving = false }
        let now = Int(Date().timeIntervalSince1970)
        do {
            let existing = Set(((try? await store.liftPrograms(deviceId: repo.deviceId)) ?? []).map { $0.name.lowercased() })
            let vocabulary = (try? await store.liftExercises(deviceId: repo.deviceId)) ?? []
            var created: [(id: String, name: String)] = []
            for day in p.days {
                var name = day.title
                var n = 2
                while existing.contains(name.lowercased()) || created.contains(where: { $0.name.lowercased() == name.lowercased() }) {
                    name = "\(day.title) \(n)"; n += 1
                }
                let id = "routine-\(UUID().uuidString)"
                let row = LiftProgramRow(id: id, deviceId: repo.deviceId, name: name, note: "Built for \(p.name): \(Self.title(goal).lowercased()), \(Self.title(level).lowercased()).",
                                         createdAt: now, updatedAt: now, archived: false)
                let items = try day.exercises.enumerated().map { ord, e -> LiftProgramItemRow in
                    let work = e.plan.sets.first { $0.phase == .work }
                    return LiftProgramItemRow(id: e.plan.id.uuidString + "-\(id.suffix(8))", deviceId: repo.deviceId,
                        programId: id, ord: ord, exercise: e.title, targetSets: e.plan.sets.count,
                        targetRepsLow: work?.repsMin, targetRepsHigh: work?.repsMax, targetRpe: nil, targetWeightKg: nil,
                        restSec: e.plan.restSeconds, note: nil,
                        planJSON: String(decoding: try JSONEncoder().encode(e.plan), as: UTF8.self))
                }
                let exercises = day.exercises.map { e -> LiftExerciseRow in
                    let known = vocabulary.first { $0.name == e.title }
                    let primary = e.primaryMuscleIds.compactMap(NoopFitnessExerciseChoice.liftMuscle).first
                    return LiftExerciseRow(id: known?.id ?? "ex-\(UUID().uuidString)", deviceId: repo.deviceId, name: e.title,
                        primaryMuscle: known?.primaryMuscle ?? primary,
                        secondaryMuscles: known?.secondaryMuscles ?? (e.primaryMuscleIds.dropFirst() + e.secondaryMuscleIds)
                            .compactMap(NoopFitnessExerciseChoice.liftMuscle).filter { $0 != primary },
                        createdAt: known?.createdAt ?? now, lastUsedTs: known?.lastUsedTs, definitionJSON: known?.definitionJSON)
                }
                _ = try await store.upsertLiftExercises(exercises)
                try await store.saveLiftProgram(row, items: items)
                created.append((id, name))
            }
            if schedule, !weekdays.isEmpty { plan(created) }
            NoopFitnessModel.markChanged()
            await repo.refresh()
            await fitness.load(repo: repo, profile: profile)
            settings.routineToast = "\(created.count) routines created"
            navigation.back(or: .fitness)
        } catch {
            self.error = "The routines could not be created. Nothing was saved; try again."
        }
    }

    /// The next six weeks of the picked weekdays, each given the next routine in turn.
    private func plan(_ routines: [(id: String, name: String)]) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var index = 0
        var byRoutine: [String: [Date]] = [:]
        for offset in 0..<42 {
            guard let day = cal.date(byAdding: .day, value: offset, to: today),
                  weekdays.contains(cal.component(.weekday, from: day)),
                  let at = cal.date(bySettingHour: 18, minute: 0, second: 0, of: day) else { continue }
            let r = routines[index % routines.count]
            byRoutine[r.id, default: []].append(at)
            index += 1
        }
        for r in routines { settings.schedule(routineID: r.id, name: r.name, dates: byRoutine[r.id] ?? [], includesTime: false) }
    }

    // MARK: Answers

    private struct Answers: Codable {
        var goal: ProgramGenerator.Goal, level: ProgramGenerator.Level, days: Int, minutes: Int
        var equipment: [ProgramGenerator.Equipment], spare: [ProgramGenerator.Joint], focus: [ProgramGenerator.Group]
    }

    /// The last answers come back next time; a first visit reads the profile for nothing it does not have.
    private func restore() {
        guard !loaded else { return }
        loaded = true
        if let data = stored.data(using: .utf8), let a = try? JSONDecoder().decode(Answers.self, from: data) {
            goal = a.goal; level = a.level; days = a.days; minutes = a.minutes
            equipment = Set(a.equipment); spare = Set(a.spare); focus = Set(a.focus)
        }
        weekdays = Self.defaultWeekdays(days)
    }

    private func remember() {
        let a = Answers(goal: goal, level: level, days: days, minutes: minutes, equipment: Array(equipment),
                        spare: Array(spare), focus: Array(focus))
        if let d = try? JSONEncoder().encode(a) { stored = String(decoding: d, as: UTF8.self) }
    }

    /// Monday first, as the week strip shows it.
    private static let weekOrder = [2, 3, 4, 5, 6, 7, 1]

    /// Training days spread across the week with rest between where the count allows (weekday numbers, Sunday = 1).
    static func defaultWeekdays(_ n: Int) -> Set<Int> {
        switch n {
        case 2: [2, 5]
        case 3: [2, 4, 6]
        case 4: [2, 3, 5, 6]
        case 5: [2, 3, 4, 6, 7]
        default: [2, 3, 4, 5, 6, 7]
        }
    }

    static func title(_ g: ProgramGenerator.Goal) -> String {
        switch g { case .strength: "Get stronger"; case .muscle: "Build muscle"; case .general: "General fitness" }
    }

    static func title(_ l: ProgramGenerator.Level) -> String {
        switch l { case .beginner: "Beginner"; case .intermediate: "Intermediate"; case .advanced: "Advanced" }
    }

    static func title(_ e: ProgramGenerator.Equipment) -> String {
        switch e {
        case .barbell: "Barbell"
        case .rack: "Squat rack"
        case .bench: "Bench"
        case .dumbbell: "Dumbbells"
        case .cable: "Cables"
        case .machine: "Machines"
        case .pullUpBar: "Pull-up bar"
        case .kettlebell: "Kettlebell"
        }
    }

    static func title(_ j: ProgramGenerator.Joint) -> String {
        switch j {
        case .shoulder: "Shoulders"
        case .elbow: "Elbows"
        case .wrist: "Wrists"
        case .lowerBack: "Lower back"
        case .hip: "Hips"
        case .knee: "Knees"
        }
    }
}
#endif
