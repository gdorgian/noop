#if os(iOS)
import SwiftUI
import WhoopStore
import StrandTraining

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

    typealias Plan = RoutineScheduleEntry

    @Published var routineToast: String?
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

    /// Several dates at once, saved in one write.
    func schedule(routineID: String, name: String, dates: [Date], includesTime: Bool = true) {
        plans += dates.map { Plan(routineID: routineID, routineName: name, date: $0, includesTime: includesTime) }
    }

    func remove(_ plan: Plan) { plans.removeAll { $0.id == plan.id } }

    /// Every future plan of a routine, for "stop repeating".
    func removeUpcoming(routineID: String) {
        plans.removeAll { $0.routineID == routineID && $0.isUpcoming(asOf: Date()) }
    }

    private func save() {
        let s = Stored(sections: sections, hidden: Array(hidden), plans: plans)
        if let d = try? JSONEncoder().encode(s) { defaults.set(d, forKey: Self.key) }
    }
}

// MARK: - Edit Fitness

struct NoopFitnessEditScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var layout: NoopFitnessSettings
    @AppStorage(Repository.autoLogActivitiesKey) private var autoLog = true
    @AppStorage(ActivityNotifier.enabledKey) private var activityNotices = true

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
                NoopFitnessPanel(label: "Activity detection") {
                    Toggle(isOn: $autoLog) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Log detected activities").font(NoopHTMLFont.sans(14, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                            Text("When your strap records a workout you did not start, it is added as a detected activity you can rename, correct or delete.")
                                .font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(NoopHTMLColor.volt)
                    Toggle(isOn: $activityNotices) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Notify me").font(NoopHTMLFont.sans(14, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                            Text("While a session is under way, and once it has been logged, so you can confirm what it was.")
                                .font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(NoopHTMLColor.volt)
                    .disabled(!autoLog)
                }
                Button {
                    layout.sections = NoopFitnessSettings.Section.allCases
                    layout.hidden = []
                } label: {
                    Text("Reset to the standard layout")
                        .font(NoopHTMLFont.sans(13.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.blueLight)
                        .frame(maxWidth: .infinity).frame(minHeight: 46)
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
    @EnvironmentObject private var profile: ProfileStore
    @State private var deleting = false
    @State private var error: String?
    @State private var program: LiftProgramRow?
    @State private var items: [LiftProgramItemRow] = []
    @State private var scheduling = false
    @State private var rescheduling = false
    @State private var when = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0,
                                                     of: Date().addingTimeInterval(86_400)) ?? Date()
    @State private var refusal: NoopRunningSession?

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    NoopBackHeader(label: "Fitness") { navigation.back(or: .fitness) }
                    Spacer()
                    Menu {
                        Button("Edit") { navigation.push(.fitnessRoutineEdit) }
                        Button("Duplicate") { Task { await duplicate() } }
                        Button("Delete", role: .destructive) { deleting = true }
                    } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                }
                .padding(.bottom, 18)

                VStack(spacing: 6) {
                    NoopCanonicalGlyph(name: .weight, size: 24, color: NoopHTMLColor.volt)
                        .frame(width: 52, height: 52)
                        .overlay(Circle().strokeBorder(NoopHTMLColor.volt.opacity(0.5), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])))
                    Text("Strength").font(NoopHTMLFont.sans(13, weight: .semibold)).foregroundStyle(NoopHTMLColor.volt)
                    Text(program?.name ?? "Routine").font(NoopHTMLFont.outfit(27)).foregroundStyle(NoopHTMLColor.ink)
                    Text("\(exerciseCount) \(exerciseCount == 1 ? "exercise" : "exercises") · \(setCount) \(setCount == 1 ? "set" : "sets")")
                        .font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)

                VStack(spacing: 10) {
                    ForEach(items, id: \.id) { item in exerciseCard(item) }
                }

                if let error { Text(error).foregroundStyle(NoopHTMLColor.red) }
                if let refusal {
                    Text("\(refusal.name) is still running. Finish it before starting another session.")
                        .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.volt)
                        .padding(.top, 12)
                }

                let upcoming = settings.plans.filter { $0.routineID == navigation.fitnessRoutineID && $0.isUpcoming(asOf: Date()) }
                    .sorted { $0.date < $1.date }
                if !upcoming.isEmpty {
                    NoopFitnessScheduleSummary(
                        upcoming: upcoming,
                        remove: { p in settings.remove(p) },
                        restore: { p in settings.plans.append(p) },
                        stopRepeating: {
                            guard let id = navigation.fitnessRoutineID else { return }
                            withAnimation(NoopMotion.swap) { settings.removeUpcoming(routineID: id) }
                        },
                        edit: { rescheduling = true; scheduling = true })
                }

                HStack(spacing: 10) {
                    Button { scheduling = true } label: {
                        Text("Schedule")
                            .font(NoopHTMLFont.sans(15, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                            .frame(maxWidth: .infinity).frame(minHeight: 52)
                            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    Button { Task { await start() } } label: {
                        HStack(spacing: 8) {
                            NoopCanonicalGlyph(name: .play, size: 15, color: NoopHTMLColor.voltInk)
                            Text("Start").font(NoopHTMLFont.sans(15, weight: .semibold))
                        }
                        .foregroundStyle(NoopHTMLColor.voltInk)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(NoopHTMLColor.volt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    .disabled(items.isEmpty)
                    .opacity(items.isEmpty ? 0.5 : 1)
                }
                .padding(.top, 16)
            }
        }
        .alert("Delete this routine?", isPresented: $deleting) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await delete() } }
        } message: { Text("Your logged sessions will be kept.") }
        .task(id: "\(navigation.fitnessRoutineID ?? "")-\(repo.refreshSeq)") { await load() }
        .sheet(isPresented: $scheduling, onDismiss: { rescheduling = false }) {
            NoopFitnessPlanSheet(routines: [.init(id: program?.id ?? "", name: program?.name ?? "Routine",
                                                  exercises: exerciseCount, sets: setCount)],
                                 fixedRoutineID: navigation.fitnessRoutineID,
                                 replacing: rescheduling ? settings.plans.filter {
                                     $0.routineID == navigation.fitnessRoutineID && $0.isUpcoming(asOf: Date())
                                 }.sorted { $0.date < $1.date } : [])
                .environmentObject(settings)
                .noopSheet([.height(600), .large])
        }
    }

    private var exerciseCount: Int { Set(items.map(\.exercise)).count }
    private var setCount: Int { items.reduce(0) { $0 + ($1.targetSets ?? 1) } }

    private func exerciseCard(_ item: LiftProgramItemRow) -> some View {
        let plan = item.planJSON.flatMap { $0.data(using: .utf8) }.flatMap { try? JSONDecoder().decode(RoutineExercise.self, from: $0) }
        let sets = plan?.sets ?? (0..<max(1, item.targetSets ?? 1)).map { _ in
            RoutineSetPlan(targetWeightKg: item.targetWeightKg, repsMin: item.targetRepsLow, repsMax: item.targetRepsHigh)
        }
        return NoopFitnessPanel {
            Text(item.exercise).font(NoopHTMLFont.sans(15, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
            Text("\(sets.count) sets · \(LiftFormat.duration(plan?.restSeconds ?? item.restSec ?? 120)) rest")
                .font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy)
            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                HStack(spacing: 8) {
                    Text("\(index + 1)").frame(width: 30)
                    cell(set.targetWeightKg.map { "\(LiftFormat.trim($0)) kg" } ?? "—")
                    cell(set.targetDurationS.map { "\($0)s" } ?? set.repsMin.map { low in
                        if let high = set.repsMax, high != low { return "\(low)–\(high) reps" }
                        return "\(low) reps"
                    } ?? "—")
                    cell(NoopRestFormat.clock(set.restSeconds ?? plan?.restSeconds ?? item.restSec ?? 120))
                }
            }
        }
    }

    private func duplicate() async {
        guard let program, let store = await repo.storeHandle() else { return }
        do {
            let now = Int(Date().timeIntervalSince1970)
            var copy = program
            copy.id = "routine-\(UUID().uuidString)"
            copy.name += " copy"
            copy.createdAt = now; copy.updatedAt = now; copy.archived = false
            var groups: [UUID: UUID] = [:]
            let copied = try items.map { item in
                var result = item
                result.id = UUID().uuidString; result.programId = copy.id
                if let data = item.planJSON?.data(using: .utf8), let plan = try? JSONDecoder().decode(RoutineExercise.self, from: data) {
                    var fresh = RoutineEditing.duplicate(.init(title: "", exercises: [plan]), title: "", now: now).exercises[0]
                    if let group = plan.supersetId {
                        let next = groups[group] ?? UUID(); groups[group] = next; fresh.supersetId = next
                    }
                    result.id = fresh.id.uuidString
                    result.planJSON = String(decoding: try JSONEncoder().encode(fresh), as: UTF8.self)
                }
                return result
            }
            try await store.saveLiftProgram(copy, items: copied)
            NoopFitnessModel.markChanged()
            await repo.refresh(); await fitness.load(repo: repo, profile: profile)
            navigation.fitnessRoutineID = copy.id
            await load()
        } catch { self.error = "The routine could not be duplicated. Try again." }
    }

    private func delete() async {
        guard var program, let store = await repo.storeHandle() else { return }
        do {
            program.archived = true
            program.updatedAt = Int(Date().timeIntervalSince1970)
            try await store.saveLiftProgram(program, items: items)
            settings.removeUpcoming(routineID: program.id)
            settings.routineToast = "Routine deleted"
            NoopFitnessModel.markChanged()
            await repo.refresh(); await fitness.load(repo: repo, profile: profile)
            navigation.fitnessRoutineID = nil
            navigation.reset(to: .fitness)
        } catch { self.error = "The routine could not be deleted. Try again." }
    }

    private func cell(_ t: String) -> some View {
        Text(t).font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.ink)
            .frame(maxWidth: .infinity).frame(minHeight: 34)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func load() async {
        guard let id = navigation.fitnessRoutineID, let store = await repo.storeHandle() else { return }
        program = ((try? await store.liftPrograms(deviceId: repo.deviceId, includeArchived: true)) ?? []).first { $0.id == id }
        items = ((try? await store.liftProgramItems(programId: id)) ?? []).sorted { $0.ord < $1.ord }
    }

    /// Starts the routine as a Lift session, under the same one-session rule the Lift screens keep.
    private func start() async {
        guard let id = navigation.fitnessRoutineID, !items.isEmpty else { return }
        if let blocked = await NoopFitnessRoutineStarter.start(routineID: id, repo: repo, live: live, app: app,
                                                               navigation: navigation) {
            withAnimation(NoopMotion.swap) { refusal = blocked }
        }
    }
}

// MARK: - Calendar

struct NoopFitnessCalendarScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var fitness: NoopFitnessModel
    @EnvironmentObject private var settings: NoopFitnessSettings
    @State private var month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    @State private var selected = Calendar.current.startOfDay(for: Date())
    @State private var metric: Metric = .none
    @State private var planningDay = false
    @State private var sport: String?

    enum Metric: String, CaseIterable { case none = "Sessions", time = "Active time", energy = "Energy", distance = "Distance" }

    var body: some View {
        let cal = Calendar.current
        let sessions = (fitness.snapshot?.history.sessions ?? []).filter { sport == nil || $0.title == sport }
        NoopFitnessPage(navigation: navigation, title: "Calendar") {
            VStack(alignment: .leading, spacing: 14) {
                Color.clear.frame(height: 0)
                    .sheet(isPresented: $planningDay) {
                        NoopFitnessPlanSheet(routines: fitness.snapshot?.routines ?? [], day: selected).environmentObject(settings).noopSheet()
                    }
                HStack {
                    step(.left) { month = cal.date(byAdding: .month, value: -1, to: month) ?? month }
                    Text(month.formatted(.dateTime.month(.wide).year()))
                        .font(NoopHTMLFont.sans(15, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                        .frame(maxWidth: .infinity)
                    step(.right) { month = cal.date(byAdding: .month, value: 1, to: month) ?? month }
                }
                let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
                monthSummary(sessions)
                HStack(spacing: 8) {
                    Menu {
                        ForEach(Metric.allCases, id: \.self) { m in
                            Button { withAnimation(NoopMotion.swap) { metric = m } } label: {
                                if metric == m { Label(m.rawValue, systemImage: "checkmark") } else { Text(m.rawValue) }
                            }
                        }
                    } label: { filterChip("Show: \(metric.rawValue)") }
                    Menu {
                        Button("Every activity") { withAnimation(NoopMotion.swap) { sport = nil } }
                        ForEach(sportNames, id: \.self) { n in Button(n) { withAnimation(NoopMotion.swap) { sport = n } } }
                    } label: { filterChip(sport ?? "Every activity") }
                    Spacer()
                }
                LazyVGrid(columns: cols, spacing: 6) {
                    ForEach(Self.weekdayLetters, id: \.self) { l in
                        Text(l).font(NoopHTMLFont.sans(10.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.muted)
                    }
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        if let day {
                            dayCell(day, done: sessions.filter { cal.isDate($0.start, inSameDayAs: day) },
                                    planned: settings.plans(on: day))
                        } else {
                            Color.clear.frame(height: 54)
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 24).onEnded { v in
                    guard abs(v.translation.width) > abs(v.translation.height) else { return }
                    withAnimation(NoopMotion.swap) {
                        month = cal.date(byAdding: .month, value: v.translation.width < 0 ? 1 : -1, to: month) ?? month
                    }
                })
                .sensoryFeedback(.selection, trigger: month)
                HStack {
                    NoopSectionLabel(selected.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    Spacer()
                    if Calendar.current.startOfDay(for: selected) >= Calendar.current.startOfDay(for: Date()) {
                        NoopFitnessIconButton(glyph: .plus) { planningDay = true }
                            .accessibilityLabel("Plan a routine on this day")
                    }
                }
                .padding(.top, 6)
                let done = sessions.filter { cal.isDate($0.start, inSameDayAs: selected) }
                let planned = settings.plans(on: selected).filter { p in !done.contains { $0.routineID == p.routineID } }
                if done.isEmpty && planned.isEmpty {
                    Text(selected > Date() ? "Nothing planned." : "Rest day.")
                        .font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.copy)
                }
                ForEach(done) { s in
                    NoopFitnessSessionButton(session: s, navigation: navigation, returnRoute: .fitnessCalendar)
                }
                ForEach(planned) { p in
                    Button {
                        navigation.fitnessRoutineID = p.routineID
                        navigation.push(.fitnessRoutine)
                    } label: {
                        HStack(spacing: 13) {
                            NoopCanonicalGlyph(name: .weight, size: 18, color: NoopHTMLColor.volt)
                                .frame(width: 38, height: 38)
                                .overlay(Circle().strokeBorder(NoopHTMLColor.volt.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(p.routineName).font(NoopHTMLFont.sans(14.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                                Text(p.includesTime == false ? "Planned" : "Planned · \(p.date.formatted(date: .omitted, time: .shortened))")
                                    .font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy)
                            }
                            Spacer()
                            NoopFixedChevron(direction: .right, color: NoopHTMLColor.chevronDim)
                        }
                        .padding(15)
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(NoopHTMLColor.volt.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    .contextMenu {
                        Button(role: .destructive) { settings.remove(p) } label: { Label("Remove this one", systemImage: "trash") }
                        Button(role: .destructive) { settings.removeUpcoming(routineID: p.routineID) } label: {
                            Label("Remove every upcoming one", systemImage: "calendar.badge.minus")
                        }
                    }
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
        let today = cal.isDateInToday(day)
        return Button { withAnimation(NoopMotion.swap) { selected = cal.startOfDay(for: day) } } label: {
            VStack(spacing: 3) {
                Text("\(cal.component(.day, from: day))")
                    .font(NoopHTMLFont.sans(12, weight: today ? .bold : .medium))
                    .foregroundStyle(today ? NoopHTMLColor.blueLight : NoopHTMLColor.copy)
                ZStack {
                    if let first = done.first {
                        Circle().fill(NoopFitnessSessionRow.tint(first).opacity(0.2))
                        NoopCanonicalGlyph(name: NoopFitnessSessionRow.glyph(first), size: 12, color: NoopFitnessSessionRow.tint(first))
                    } else if !planned.isEmpty {
                        Circle().strokeBorder(NoopHTMLColor.volt.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                        NoopCanonicalGlyph(name: .weight, size: 11, color: NoopHTMLColor.volt.opacity(0.8))
                    } else {
                        Circle().fill(Color.white.opacity(day > Date() ? 0 : 0.035))
                    }
                }
                .frame(width: 26, height: 26)
                .overlay(alignment: .topTrailing) {
                    if done.count > 1 {
                        Text("\(done.count)").font(NoopHTMLFont.sans(8.5, weight: .bold)).foregroundStyle(NoopHTMLColor.canvas)
                            .frame(width: 13, height: 13).background(NoopHTMLColor.ink, in: Circle()).offset(x: 4, y: -3)
                    }
                }
                if metric != .none {
                    Text(value(done) ?? " ").font(NoopHTMLFont.sans(9, weight: .semibold)).foregroundStyle(NoopHTMLColor.inkSoft)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity).frame(height: metric == .none ? 54 : 64)
            .background(isSelected ? Color.white.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? NoopHTMLColor.borderStrong : .clear, lineWidth: 0.6))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private func value(_ done: [NoopFitnessSession]) -> String? {
        guard !done.isEmpty else { return nil }
        switch metric {
        case .none: return nil
        case .time: return NoopFitnessHome.duration(done.reduce(0) { $0 + $1.durationS })
        case .energy:
            let k = done.compactMap(\.kcal).reduce(0, +)
            return k > 0 ? "\(Int(k.rounded()))" : nil
        case .distance:
            let m = done.compactMap { $0.row?.distanceM }.reduce(0, +)
            return m > 0 ? String(format: "%.1f", m / 1000) : nil
        }
    }

    private func monthSummary(_ sessions: [NoopFitnessSession]) -> some View {
        let cal = Calendar.current
        let inMonth = sessions.filter { cal.isDate($0.start, equalTo: month, toGranularity: .month) }
        let time = inMonth.reduce(0) { $0 + $1.durationS }
        let lifts = inMonth.filter { $0.kind == .strength }.count
        let days = Set(inMonth.map { cal.startOfDay(for: $0.start) }).count
        return HStack(spacing: 0) {
            summaryCell("\(inMonth.count)", "sessions")
            summaryCell("\(days)", "active days")
            summaryCell(NoopFitnessHome.duration(time), "active")
            summaryCell("\(lifts)", lifts == 1 ? "lift" : "lifts")
        }
        .padding(.vertical, 12)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private func summaryCell(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(NoopHTMLFont.outfit(19)).foregroundStyle(NoopHTMLColor.ink).monospacedDigit()
            Text(l).font(NoopHTMLFont.sans(10.5)).foregroundStyle(NoopHTMLColor.copy)
        }
        .frame(maxWidth: .infinity)
    }

    private func filterChip(_ t: String) -> some View {
        HStack(spacing: 5) {
            Text(t).font(NoopHTMLFont.sans(12, weight: .semibold))
            Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(NoopHTMLColor.inkSoft)
        .padding(.horizontal, 12).frame(height: 30)
        .background(Color.white.opacity(0.06), in: Capsule())
    }

    private var sportNames: [String] {
        var n: [String: Int] = [:]
        for s in fitness.snapshot?.history.sessions ?? [] { n[s.title, default: 0] += 1 }
        return n.sorted { $0.value > $1.value }.map(\.key)
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
