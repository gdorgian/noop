#if os(iOS)
import SwiftUI
import WhoopStore

// MARK: - Layout and schedule

/// What the wearer chose for the Fitness page: section order, hidden cards, and planned routines.
/// Stored in UserDefaults: it is a preference and a plan, not a measurement.
@MainActor
final class NoopFitnessSettings: ObservableObject {
    enum Section: String, CaseIterable, Codable, Identifiable {
        case activity, routines, load, cardio, strength
        var id: String { rawValue }
        var title: String {
            switch self {
            case .activity: "Activity"
            case .routines: "Routines"
            case .load: "Training load"
            case .cardio: "Cardio"
            case .strength: "Strength"
            }
        }
        var cards: [Card] {
            switch self {
            case .cardio: [.activeTime, .activeEnergy, .vo2, .recovery, .focus, .zones]
            case .strength: [.sets, .volume, .freshness]
            default: []
            }
        }
    }

    enum Card: String, CaseIterable, Codable {
        case activeTime, activeEnergy, vo2, recovery, focus, zones, sets, volume, freshness
        var title: String {
            switch self {
            case .activeTime: "Active time"
            case .activeEnergy: "Active energy"
            case .vo2: "VO₂ max"
            case .recovery: "Heart rate recovery"
            case .focus: "Cardio focus"
            case .zones: "Heart rate zones"
            case .sets: "Working sets"
            case .volume: "Volume"
            case .freshness: "Muscle freshness"
            }
        }
    }

    struct Plan: Codable, Identifiable, Equatable {
        var id = UUID()
        let routineID: String
        let routineName: String
        let date: Date
    }

    @Published var sections: [Section] { didSet { save() } }
    @Published var hidden: Set<Card> { didSet { save() } }
    @Published var plans: [Plan] { didSet { save() } }

    private let defaults: UserDefaults
    private static let key = "fitness.settings.v1"

    private struct Stored: Codable {
        var sections: [Section]
        var hidden: [Card]
        var plans: [Plan]
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(Stored.self, from: $0) }
        // A section added in a later build joins at the end rather than vanishing.
        let order = stored?.sections ?? Section.allCases
        sections = order + Section.allCases.filter { !order.contains($0) }
        hidden = Set(stored?.hidden ?? [])
        plans = stored?.plans ?? []
    }

    func isShown(_ c: Card) -> Bool { !hidden.contains(c) }

    func plans(on day: Date) -> [Plan] {
        plans.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }.sorted { $0.date < $1.date }
    }

    func schedule(routineID: String, name: String, at date: Date) {
        plans.append(Plan(routineID: routineID, routineName: name, date: date))
    }

    func remove(_ plan: Plan) { plans.removeAll { $0.id == plan.id } }

    private func save() {
        let s = Stored(sections: sections, hidden: Array(hidden), plans: plans)
        if let d = try? JSONEncoder().encode(s) { defaults.set(d, forKey: Self.key) }
    }
}

// MARK: - Edit Fitness

struct NoopFitnessEditScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var layout: NoopFitnessSettings

    var body: some View {
        NoopFitnessPage(navigation: navigation, title: "Edit Fitness",
                        subtitle: "Move sections up or down, and switch off the cards you do not need.") {
            VStack(spacing: 10) {
                ForEach(Array(layout.sections.enumerated()), id: \.element) { i, section in
                    NoopFitnessPanel {
                        HStack {
                            Text(section.title).font(NoopHTMLFont.sans(15, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                            Spacer()
                            move(.up, enabled: i > 0) { swap(i, i - 1) }
                            move(.down, enabled: i < layout.sections.count - 1) { swap(i, i + 1) }
                        }
                        ForEach(section.cards, id: \.self) { card in
                            Toggle(isOn: Binding(
                                get: { layout.isShown(card) },
                                set: { on in if on { layout.hidden.remove(card) } else { layout.hidden.insert(card) } })
                            ) {
                                Text(card.title).font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.inkSoft)
                            }
                            .tint(NoopHTMLColor.blue)
                        }
                    }
                }
                Button {
                    layout.sections = NoopFitnessSettings.Section.allCases
                    layout.hidden = []
                } label: {
                    Text("Reset to the standard layout")
                        .font(NoopHTMLFont.sans(13.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.blueLight)
                        .frame(maxWidth: .infinity).frame(height: 46)
                }
                .buttonStyle(NoopHTMLPressStyle())
            }
        }
    }

    private func swap(_ a: Int, _ b: Int) {
        withAnimation(NoopMotion.swap) { layout.sections.swapAt(a, b) }
    }

    private enum Way { case up, down }

    private func move(_ way: Way, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            NoopFixedChevron(direction: .right, color: enabled ? NoopHTMLColor.inkSoft : NoopHTMLColor.chevronDim)
                .rotationEffect(.degrees(way == .up ? -90 : 90))
                .frame(width: 34, height: 30)
                .background(Color.white.opacity(enabled ? 0.06 : 0.02), in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(!enabled)
        .accessibilityLabel(way == .up ? "Move up" : "Move down")
    }
}

// MARK: - Routine

struct NoopFitnessRoutineScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var fitness: NoopFitnessModel
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var settings: NoopFitnessSettings
    @EnvironmentObject private var live: LiftSessionController
    @EnvironmentObject private var app: AppModel
    @State private var program: LiftProgramRow?
    @State private var items: [LiftProgramItemRow] = []
    @State private var scheduling = false
    @State private var when = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0,
                                                     of: Date().addingTimeInterval(86_400)) ?? Date()
    @State private var refusal: NoopRunningSession?

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    NoopBackHeader(label: "Fitness") { navigation.back(or: .fitness) }
                    Spacer()
                    Button {
                        navigation.selectedLiftProgramID = navigation.fitnessRoutineID
                        navigation.push(.liftProgram)
                    } label: {
                        Text("Edit").font(NoopHTMLFont.sans(13, weight: .semibold)).foregroundStyle(NoopHTMLColor.inkSoft)
                            .padding(.horizontal, 14).frame(height: 32)
                            .background(Color.white.opacity(0.06), in: Capsule())
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                }
                .padding(.bottom, 18)

                VStack(spacing: 6) {
                    NoopCanonicalGlyph(name: .weight, size: 24, color: NoopHTMLColor.warm)
                        .frame(width: 52, height: 52)
                        .overlay(Circle().strokeBorder(NoopHTMLColor.warm.opacity(0.5), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])))
                    Text("Strength").font(NoopHTMLFont.sans(13, weight: .semibold)).foregroundStyle(NoopHTMLColor.warm)
                    Text(program?.name ?? "Routine").font(NoopHTMLFont.outfit(27)).foregroundStyle(NoopHTMLColor.ink)
                    Text("\(exerciseCount) \(exerciseCount == 1 ? "exercise" : "exercises") · \(setCount) \(setCount == 1 ? "set" : "sets")")
                        .font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)

                VStack(spacing: 10) {
                    ForEach(items, id: \.id) { item in exerciseCard(item) }
                }

                if let refusal {
                    Text("\(refusal.name) is still running. Finish it before starting another session.")
                        .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.warm)
                        .padding(.top, 12)
                }

                let upcoming = settings.plans.filter { $0.routineID == navigation.fitnessRoutineID && $0.date > Date() }
                if !upcoming.isEmpty {
                    NoopFitnessPanel(label: "Scheduled") {
                        ForEach(upcoming) { p in
                            HStack {
                                Text(p.date.formatted(.dateTime.weekday(.wide).day().month().hour().minute()))
                                    .font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.ink)
                                Spacer()
                                Button("Remove") { settings.remove(p) }
                                    .font(NoopHTMLFont.sans(12.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.red)
                            }
                        }
                    }
                    .padding(.top, 12)
                }

                if scheduling {
                    NoopFitnessPanel(label: "Schedule") {
                        DatePicker("When", selection: $when, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.graphical)
                            .tint(NoopHTMLColor.warm)
                            .colorScheme(.dark)
                        Button {
                            if let id = navigation.fitnessRoutineID {
                                settings.schedule(routineID: id, name: program?.name ?? "Routine", at: when)
                            }
                            withAnimation(NoopMotion.swap) { scheduling = false }
                        } label: {
                            Text("Add to calendar")
                                .font(NoopHTMLFont.sans(14.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.warmInk)
                                .frame(maxWidth: .infinity).frame(height: 46)
                                .background(NoopHTMLColor.warm, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                    }
                    .padding(.top, 12)
                }

                HStack(spacing: 10) {
                    Button { withAnimation(NoopMotion.swap) { scheduling.toggle() } } label: {
                        Text(scheduling ? "Cancel" : "Schedule")
                            .font(NoopHTMLFont.sans(15, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    Button { Task { await start() } } label: {
                        HStack(spacing: 8) {
                            NoopCanonicalGlyph(name: .play, size: 15, color: NoopHTMLColor.warmInk)
                            Text("Start").font(NoopHTMLFont.sans(15, weight: .semibold))
                        }
                        .foregroundStyle(NoopHTMLColor.warmInk)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(NoopHTMLColor.warm, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    .disabled(items.isEmpty)
                    .opacity(items.isEmpty ? 0.5 : 1)
                }
                .padding(.top, 16)
            }
        }
        .task(id: navigation.fitnessRoutineID) { await load() }
    }

    private var exerciseCount: Int { Set(items.map(\.exercise)).count }
    private var setCount: Int { items.reduce(0) { $0 + ($1.targetSets ?? 1) } }

    private func exerciseCard(_ item: LiftProgramItemRow) -> some View {
        let n = max(1, item.targetSets ?? 1)
        let reps: String = {
            switch (item.targetRepsLow, item.targetRepsHigh) {
            case let (lo?, hi?) where hi != lo: return "\(lo)–\(hi)"
            case let (lo?, _): return "\(lo)"
            case let (nil, hi?): return "\(hi)"
            default: return "—"
            }
        }()
        let kg = item.targetWeightKg.map { $0.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int($0))" : String(format: "%.1f", $0) } ?? "—"
        return NoopFitnessPanel {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.exercise).font(NoopHTMLFont.sans(15, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                    Text("\(n) \(n == 1 ? "set" : "sets")\(item.restSec.map { " · \($0)s rest" } ?? "")")
                        .font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy)
                }
                Spacer()
            }
            HStack {
                Text("SET").frame(width: 34, alignment: .leading)
                Text("KG").frame(maxWidth: .infinity)
                Text("REPS").frame(maxWidth: .infinity)
            }
            .font(NoopHTMLFont.sans(10, weight: .semibold)).foregroundStyle(NoopHTMLColor.muted)
            ForEach(1...n, id: \.self) { i in
                HStack(spacing: 8) {
                    Text("\(i)").font(NoopHTMLFont.sans(13, weight: .semibold)).foregroundStyle(NoopHTMLColor.inkSoft)
                        .frame(width: 26, height: 30).background(Color.white.opacity(0.06), in: Circle())
                        .frame(width: 34, alignment: .leading)
                    cell(kg)
                    cell(reps == "—" ? reps : "\(reps) reps")
                }
            }
        }
    }

    private func cell(_ t: String) -> some View {
        Text(t).font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.ink)
            .frame(maxWidth: .infinity).frame(height: 34)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func load() async {
        guard let id = navigation.fitnessRoutineID, let store = await repo.storeHandle() else { return }
        program = ((try? await store.liftPrograms(deviceId: repo.deviceId, includeArchived: true)) ?? []).first { $0.id == id }
        items = ((try? await store.liftProgramItems(programId: id)) ?? []).sorted { $0.ord < $1.ord }
    }

    /// Starts the routine as a Lift session, under the same one-session rule the Lift screens keep.
    private func start() async {
        guard let program, !items.isEmpty else { return }
        if let running = NoopRunningSession.current(app: app, lift: live, navigation: navigation) {
            withAnimation(NoopMotion.swap) { refusal = running }
            return
        }
        var vocabulary: [LiftExerciseRow] = []
        if let store = await repo.storeHandle() {
            vocabulary = (try? await store.liftExercises(deviceId: repo.deviceId)) ?? []
        }
        let plan = items.map { row in
            let known = vocabulary.first { $0.name == row.exercise }
            return LiftPlanItem(
                exercise: row.exercise, primaryMuscle: known?.primaryMuscle,
                secondaryMuscles: known?.secondaryMuscles ?? [], targetSets: row.targetSets,
                restSec: row.restSec, targetRepsLow: row.targetRepsLow,
                targetRepsHigh: row.targetRepsHigh, targetRpe: row.targetRpe,
                targetWeightKg: row.targetWeightKg, note: row.note, programItemId: row.id)
        }
        if let running = NoopRunningSession.current(app: app, lift: live, navigation: navigation) {
            withAnimation(NoopMotion.swap) { refusal = running }
            return
        }
        guard live.start(plan: plan, programId: program.id, programName: program.name) else { return }
        live.advance()
        navigation.liftDetailReturnRoute = .fitness
        navigation.push(.liftLive)
    }
}

// MARK: - Calendar

struct NoopFitnessCalendarScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var fitness: NoopFitnessModel
    @EnvironmentObject private var settings: NoopFitnessSettings
    @State private var month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    @State private var selected = Calendar.current.startOfDay(for: Date())

    var body: some View {
        let cal = Calendar.current
        let sessions = fitness.snapshot?.history.sessions ?? []
        NoopFitnessPage(navigation: navigation, title: "Calendar") {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    step(.left) { month = cal.date(byAdding: .month, value: -1, to: month) ?? month }
                    Text(month.formatted(.dateTime.month(.wide).year()))
                        .font(NoopHTMLFont.sans(15, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                        .frame(maxWidth: .infinity)
                    step(.right) { month = cal.date(byAdding: .month, value: 1, to: month) ?? month }
                }
                let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
                LazyVGrid(columns: cols, spacing: 6) {
                    ForEach(Self.weekdayLetters, id: \.self) { l in
                        Text(l).font(NoopHTMLFont.sans(10.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.muted)
                    }
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        if let day {
                            dayCell(day, done: sessions.filter { cal.isDate($0.start, inSameDayAs: day) },
                                    planned: settings.plans(on: day))
                        } else {
                            Color.clear.frame(height: 46)
                        }
                    }
                }
                NoopSectionLabel(selected.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .padding(.top, 6)
                let done = sessions.filter { cal.isDate($0.start, inSameDayAs: selected) }
                let planned = settings.plans(on: selected)
                if done.isEmpty && planned.isEmpty {
                    Text(selected > Date() ? "Nothing planned." : "Rest day.")
                        .font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.copy)
                }
                ForEach(done) { s in
                    Button {
                        guard let lift = s.liftSessionID else { return }
                        navigation.selectedLiftSessionID = lift
                        navigation.liftDetailReturnRoute = .fitnessCalendar
                        navigation.push(.liftDetail)
                    } label: { NoopFitnessSessionRow(session: s) }
                    .buttonStyle(NoopHTMLPressStyle())
                }
                ForEach(planned) { p in
                    Button {
                        navigation.fitnessRoutineID = p.routineID
                        navigation.push(.fitnessRoutine)
                    } label: {
                        HStack(spacing: 13) {
                            NoopCanonicalGlyph(name: .weight, size: 18, color: NoopHTMLColor.warm)
                                .frame(width: 38, height: 38)
                                .overlay(Circle().strokeBorder(NoopHTMLColor.warm.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(p.routineName).font(NoopHTMLFont.sans(14.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                                Text("Planned · \(p.date.formatted(date: .omitted, time: .shortened))")
                                    .font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy)
                            }
                            Spacer()
                            NoopFixedChevron(direction: .right, color: NoopHTMLColor.chevronDim)
                        }
                        .padding(15)
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(NoopHTMLColor.warm.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                }
            }
        }
    }

    /// Monday-first weeks, padded with nil before the 1st.
    private var days: [Date?] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = cal.component(.weekday, from: month)   // 1 = Sunday
        let lead = (weekday + 5) % 7
        return Array(repeating: nil, count: lead) + range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: month) }
    }

    static let weekdayLetters = ["M", "T", "W", "T ", "F", "S", "S "]

    private func dayCell(_ day: Date, done: [NoopFitnessSession], planned: [NoopFitnessSettings.Plan]) -> some View {
        let cal = Calendar.current
        let isSelected = cal.isDate(day, inSameDayAs: selected)
        return Button { selected = cal.startOfDay(for: day) } label: {
            VStack(spacing: 4) {
                Text("\(cal.component(.day, from: day))")
                    .font(NoopHTMLFont.sans(13.5, weight: cal.isDateInToday(day) ? .bold : .regular))
                    .foregroundStyle(cal.isDateInToday(day) ? NoopHTMLColor.blueLight : NoopHTMLColor.ink)
                HStack(spacing: 3) {
                    if !done.isEmpty { Circle().fill(NoopHTMLColor.warm).frame(width: 6, height: 6) }
                    if !planned.isEmpty {
                        Circle().strokeBorder(NoopHTMLColor.warm, lineWidth: 1).frame(width: 6, height: 6)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity).frame(height: 46)
            .background(isSelected ? Color.white.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private func step(_ d: NoopFixedChevron.Direction, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            NoopFixedChevron(direction: d, color: NoopHTMLColor.inkSoft)
                .frame(width: 38, height: 34)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}
#endif
