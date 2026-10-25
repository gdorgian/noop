#if os(iOS)
import SwiftUI
import WhoopStore
import StrandTraining

// MARK: - Starting a routine

/// Starts a saved routine as a Lift session, under the one-session rule every start button keeps.
enum NoopFitnessRoutineStarter {
    /// Returns the running session that blocked the start, if one did.
    @MainActor
    static func start(routineID: String, repo: Repository, live: LiftSessionController, app: AppModel,
                      navigation: NoopNavigation) async -> NoopRunningSession? {
        if let running = NoopRunningSession.current(app: app, lift: live, navigation: navigation) { return running }
        guard let store = await repo.storeHandle(),
              let program = ((try? await store.liftPrograms(deviceId: repo.deviceId, includeArchived: true)) ?? [])
                .first(where: { $0.id == routineID }) else { return nil }
        let items = ((try? await store.liftProgramItems(programId: routineID)) ?? []).sorted { $0.ord < $1.ord }
        guard !items.isEmpty else { return nil }
        let vocabulary = (try? await store.liftExercises(deviceId: repo.deviceId)) ?? []
        let plan = items.map { row in
            let known = vocabulary.first { $0.name == row.exercise }
            return LiftPlanItem(
                exercise: row.exercise, primaryMuscle: known?.primaryMuscle,
                secondaryMuscles: known?.secondaryMuscles ?? [], targetSets: row.targetSets,
                restSec: row.restSec, targetRepsLow: row.targetRepsLow,
                targetRepsHigh: row.targetRepsHigh, targetRpe: row.targetRpe,
                targetWeightKg: row.targetWeightKg, note: row.note, programItemId: row.id,
                routinePlan: row.planJSON.flatMap { $0.data(using: .utf8) }.flatMap { try? JSONDecoder().decode(RoutineExercise.self, from: $0) })
        }
        if let running = NoopRunningSession.current(app: app, lift: live, navigation: navigation) { return running }
        guard live.start(plan: plan, programId: program.id, programName: program.name) else { return nil }
        live.advance()
        navigation.liftDetailReturnRoute = .fitness
        navigation.push(.liftLive)
        return nil
    }
}

// MARK: - Add sheet

/// The one "+" (tab bar and Fitness): log something already done, start a routine, or start
/// any cardio session. `routines` is nil when opened outside Fitness; the sheet reads them itself.
struct NoopFitnessAddSheet: View {
    @ObservedObject var navigation: NoopNavigation
    var routines: [NoopFitnessSnapshot.Routine]? = nil
    @State private var loadedRoutines: [NoopFitnessSnapshot.Routine] = []
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var live: LiftSessionController
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var logging = false
    @State private var refusal: NoopRunningSession?
    @State private var showAll = false

    private static let quick: [(name: String, symbol: String)] = [
        ("Running", "figure.run"), ("Walking", "figure.walk"), ("Cycling", "figure.outdoor.cycle"),
        ("Hiking", "figure.hiking"), ("Pool swim", "figure.pool.swim"), ("Open-water swim", "figure.open.water.swim"),
        ("Rowing", "figure.rower"), ("HIIT", "figure.highintensity.intervaltraining"), ("Yoga", "figure.yoga"),
        ("Elliptical", "figure.elliptical"), ("Indoor cycle", "figure.indoor.cycle"), ("Treadmill run", "figure.run.treadmill"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("Add").font(NoopHTMLFont.sheetTitle).foregroundStyle(NoopHTMLColor.ink)
                    Spacer()
                    NoopCloseButton { dismiss() }
                }
                if let refusal {
                    Text("\(refusal.name) is still running. Finish it before starting another session.")
                        .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.volt)
                }

                section("Log") {
                    row(symbol: "square.and.pencil", tint: NoopHTMLColor.green, title: "A workout you did",
                        detail: "Sport, start and end. Noop scores it from your strap's heart rate") { logging = true }
                    row(symbol: "cup.and.saucer.fill", tint: NoopHTMLColor.blueLight, title: "Coffee, drinks and more",
                        detail: "One tap each, counted into today") {
                        navigation.afterAddSheet { navigation.show(.dayLog) }
                    }
                    row(symbol: "moon.stars.fill", tint: NoopHTMLColor.night, title: "Evening journal",
                        detail: "How the day went, read against tonight's sleep") {
                        navigation.afterAddSheet { navigation.show(.nightJournal) }
                    }
                    row(symbol: "scalemass.fill", tint: NoopHTMLColor.blush, title: "Weight and measurements",
                        detail: "Height, weight and the optional waist") {
                        navigation.afterAddSheet { navigation.reset(to: .record) }
                    }
                    row(symbol: "drop.fill", tint: NoopHTMLColor.volt, title: "Bloodwork",
                        detail: "Photograph a lab report or type the results") {
                        navigation.afterAddSheet { navigation.enterLabPicker() }
                    }
                }

                section("Strength") {
                    if allRoutines.isEmpty {
                        row(symbol: "plus", tint: NoopHTMLColor.volt, title: "Build your first routine",
                            detail: "Exercises, sets and rest, then start it in one tap") {
                            navigation.afterAddSheet {
                                navigation.fitnessRoutineID = nil
                                if navigation.route.tab != .fitness { navigation.reset(to: .fitness) }
                                navigation.push(.fitnessRoutineEdit)
                            }
                        }
                    }
                    ForEach(allRoutines) { r in
                        row(symbol: "dumbbell.fill", tint: NoopHTMLColor.volt, title: r.name,
                            detail: "\(r.exercises) \(r.exercises == 1 ? "exercise" : "exercises") · \(r.sets) sets",
                            trailing: "Start") {
                            Task {
                                if let blocked = await NoopFitnessRoutineStarter.start(
                                    routineID: r.id, repo: repo, live: live, app: app, navigation: navigation) {
                                    withAnimation(NoopMotion.swap) { refusal = blocked }
                                } else { dismiss() }
                            }
                        }
                    }
                }

                section("Cardio") {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10),
                                        GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(Self.quick, id: \.name) { s in
                            Button { startCardio(s.name) } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: s.symbol).font(.system(size: 21, weight: .medium))
                                        .foregroundStyle(NoopHTMLColor.blueLight)
                                        .frame(height: 26)
                                    Text(s.name).font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                                        .lineLimit(1).minimumScaleFactor(0.75)
                                }
                                .frame(maxWidth: .infinity).frame(minHeight: 84)
                                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
                            }
                            .buttonStyle(NoopHTMLPressStyle())
                        }
                    }
                    Button { showAll = true } label: {
                        Text("Every other sport").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(NoopHTMLColor.blueLight)
                            .frame(maxWidth: .infinity).frame(minHeight: 40)
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                }

            }
            .padding(20)
        }
        .background(NoopHTMLColor.canvas.ignoresSafeArea())
        .task {
            guard routines == nil, let store = await repo.storeHandle() else { return }
            let programs = ((try? await store.liftPrograms(deviceId: repo.deviceId)) ?? [])
                .sorted { $0.updatedAt > $1.updatedAt }
            var out: [NoopFitnessSnapshot.Routine] = []
            for p in programs {
                let items = (try? await store.liftProgramItems(programId: p.id)) ?? []
                out.append(.init(id: p.id, name: p.name, exercises: Set(items.map(\.exercise)).count,
                                 sets: items.reduce(0) { $0 + ($1.targetSets ?? 1) }))
            }
            loadedRoutines = out
        }
        .sheet(isPresented: $logging) {
            ManualWorkoutSheet { row, replacing in
                Task {
                    await repo.saveManualWorkout(row, replacing: replacing)
                    NoopFitnessModel.markChanged()
                    await app.intelligence.analyzeRecent()
                    await repo.refresh()
                }
                dismiss()
            }
            .environmentObject(repo)
            .noopSheet()
        }
        .confirmationDialog("Start a session", isPresented: $showAll, titleVisibility: .visible) {
            ForEach(WorkoutCatalog.all.filter { s in !Self.quick.contains { $0.name == s.name } && s.name != "Strength" }) { s in
                Button(s.name) { startCardio(s.name) }
            }
        }
    }

    private var allRoutines: [NoopFitnessSnapshot.Routine] { routines ?? loadedRoutines }

    private func startCardio(_ sport: String) {
        if let running = NoopRunningSession.current(app: app, lift: live, navigation: navigation) {
            withAnimation(NoopMotion.swap) { refusal = running }
            return
        }
        app.startWorkout(sport: sport)
        navigation.beginSession(at: app.activeWorkout?.start ?? Date())
        dismiss()
        navigation.push(.live)
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            NoopSectionLabel(title)
            content()
        }
    }

    private func row(symbol: String, tint: Color, title: String, detail: String, trailing: String? = nil,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(tint)
                    .frame(width: 42, height: 42).background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink).lineLimit(1)
                    Text(detail).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy).lineLimit(2)
                }
                Spacer(minLength: 6)
                if let trailing {
                    Text(trailing).font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(NoopHTMLColor.voltInk)
                        .padding(.horizontal, 14).frame(minHeight: 32).background(NoopHTMLColor.volt, in: Capsule())
                } else {
                    NoopFixedChevron(direction: .right, color: NoopHTMLColor.chevronDim)
                }
            }
            .padding(13)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

// MARK: - Planning

/// When a routine happens: once on a date, or on chosen weekdays for a number of weeks.
struct NoopFitnessRepeatPlan: Equatable {
    var includesTime = true
    var weekly = true
    var weekdays: Set<Int> = []          // 1 = Monday … 7 = Sunday
    var weeks = 8
    var start = Calendar.current.startOfDay(for: Date())
    var time = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    var once = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()

    var isValid: Bool { weekly ? !weekdays.isEmpty : true }

    /// Every dated session the plan describes, from today on.
    var dates: [Date] {
        let cal = Calendar.current
        let hm = cal.dateComponents([.hour, .minute], from: time)
        func at(_ day: Date) -> Date {
            guard includesTime else { return cal.startOfDay(for: day) }
            return cal.date(bySettingHour: hm.hour ?? 18, minute: hm.minute ?? 0, second: 0, of: day) ?? day
        }
        guard weekly else { return [at(once)] }
        var out: [Date] = []
        let end = cal.date(byAdding: .weekOfYear, value: weeks, to: start) ?? start
        var d = start
        while d < end {
            let wd = (cal.component(.weekday, from: d) + 5) % 7 + 1
            if weekdays.contains(wd), at(d) >= cal.startOfDay(for: Date()), (!includesTime || at(d) > Date()) { out.append(at(d)) }
            d = cal.date(byAdding: .day, value: 1, to: d) ?? end
        }
        return out
    }

    var summary: String {
        guard weekly else {
            let date = dates.first ?? once
            return "Once, " + (includesTime ? date.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()) : date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        }
        guard !weekdays.isEmpty else { return "Pick the days you train" }
        let names = Calendar.current.shortWeekdaySymbols
        let days = weekdays.sorted().map { names[$0 % 7] }.joined(separator: ", ")
        let n = dates.count
        let timing = includesTime ? " at \(time.formatted(date: .omitted, time: .shortened))" : ""
        return "\(days)\(timing) · \(n) \(n == 1 ? "session" : "sessions") over \(weeks) weeks"
    }
}

/// The controls for a `NoopFitnessRepeatPlan`, shared by the plan sheet and the routine editor.
struct NoopFitnessRepeatEditor: View {
    @Binding var plan: NoopFitnessRepeatPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NoopTabs(options: [("Every week", true), ("Once", false)], selection: $plan.weekly)

            if plan.weekly {
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { d in
                        let on = plan.weekdays.contains(d)
                        Button {
                            withAnimation(NoopMotion.swap) { if on { plan.weekdays.remove(d) } else { plan.weekdays.insert(d) } }
                        } label: {
                            Text(String(Calendar.current.veryShortWeekdaySymbols[d % 7]))
                                .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                                .foregroundStyle(on ? NoopHTMLColor.canvas : NoopHTMLColor.inkSoft)
                                .frame(maxWidth: .infinity).frame(minHeight: 42)
                                .background(on ? NoopHTMLColor.ink : Color.white.opacity(0.06), in: Circle())
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                        .accessibilityLabel(Calendar.current.weekdaySymbols[d % 7])
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .sensoryFeedback(.selection, trigger: plan.weekdays)
                HStack {
                    Text("For").font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                    Spacer()
                    ForEach([4, 8, 12, 26], id: \.self) { w in
                        Button { plan.weeks = w } label: {
                            Text("\(w) wk").font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                                .foregroundStyle(plan.weeks == w ? NoopHTMLColor.canvas : NoopHTMLColor.inkSoft)
                                .padding(.horizontal, 11).frame(minHeight: 30)
                                .background(plan.weeks == w ? NoopHTMLColor.ink : Color.white.opacity(0.06), in: Capsule())
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                    }
                }
                DatePicker("Starting", selection: $plan.start, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                    .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
            } else {
                DatePicker("Day", selection: $plan.once, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
            }
            NoopToggleRow(title: "Set a time", isOn: $plan.includesTime)
            if plan.includesTime {
                DatePicker("Time", selection: $plan.time, displayedComponents: .hourAndMinute)
                    .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
            }
            Text(plan.summary).font(NoopHTMLFont.sans(NoopType.caption, weight: .medium)).foregroundStyle(NoopHTMLColor.volt)
                .fixedSize(horizontal: false, vertical: true)
        }
        .tint(NoopHTMLColor.volt)
        .colorScheme(.dark)
    }

}

/// "Plan a routine": which one, and when.
struct NoopFitnessPlanSheet: View {
    let routines: [NoopFitnessSnapshot.Routine]
    var fixedRoutineID: String? = nil
    var day: Date? = nil
    /// The routine's upcoming sessions when changing its schedule: the sheet opens on their pattern and
    /// saving replaces them, rather than adding a second set of dates beside them.
    var replacing: [NoopFitnessSettings.Plan] = []
    @EnvironmentObject private var settings: NoopFitnessSettings
    @Environment(\.dismiss) private var dismiss
    @State private var routineID: String?
    @State private var plan = NoopFitnessRepeatPlan()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Plan a routine").font(NoopHTMLFont.sheetTitle).foregroundStyle(NoopHTMLColor.ink)
                    Spacer()
                    NoopCloseButton { dismiss() }
                }
                if fixedRoutineID == nil {
                    VStack(alignment: .leading, spacing: 8) {
                        NoopSectionLabel("Routine")
                        if routines.isEmpty {
                            Text("Build a routine first; then it can go on the calendar.")
                                .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                        }
                        ForEach(routines) { r in
                            let on = routineID == r.id
                            Button { withAnimation(NoopMotion.swap) { routineID = r.id } } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 19)).foregroundStyle(on ? NoopHTMLColor.volt : NoopHTMLColor.muted)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(r.name).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                                        Text("\(r.exercises) exercise\(r.exercises == 1 ? "" : "s") · \(r.sets) set\(r.sets == 1 ? "" : "s")").font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                                    }
                                    Spacer()
                                }
                                .padding(13)
                                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(on ? NoopHTMLColor.volt.opacity(0.6) : NoopHTMLColor.border, lineWidth: on ? 1 : 0.5))
                            }
                            .buttonStyle(NoopHTMLPressStyle())
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    NoopSectionLabel("When")
                    NoopFitnessRepeatEditor(plan: $plan)
                        .padding(16)
                        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                Button(action: save) {
                    Text("Add to calendar").font(NoopHTMLFont.sans(NoopType.body, weight: .semibold)).foregroundStyle(NoopHTMLColor.voltInk)
                        .frame(maxWidth: .infinity).frame(minHeight: 54)
                        .background(NoopHTMLColor.volt.opacity(canSave ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(NoopHTMLPressStyle())
                .disabled(!canSave)
            }
            .padding(20)
        }
        .background(NoopHTMLColor.canvas.ignoresSafeArea())
        .onAppear {
            routineID = fixedRoutineID ?? routineID ?? routines.first?.id
            if let day {
                plan.weekly = false
                plan.once = day
                let wd = (Calendar.current.component(.weekday, from: day) + 5) % 7 + 1
                plan.weekdays = [wd]
                plan.start = Calendar.current.startOfDay(for: day)
            }
            if let first = replacing.first, let last = replacing.last {
                let cal = Calendar.current
                plan.weekly = replacing.count > 1
                plan.once = first.date
                plan.weekdays = Set(replacing.map { (cal.component(.weekday, from: $0.date) + 5) % 7 + 1 })
                plan.start = cal.startOfDay(for: first.date)
                plan.includesTime = first.includesTime != false
                if plan.includesTime { plan.time = first.date }
                let weeks = (cal.dateComponents([.day], from: plan.start, to: last.date).day ?? 0) / 7 + 1
                plan.weeks = [4, 8, 12, 26].first { $0 >= weeks } ?? 26
            }
        }
    }

    private var canSave: Bool { routineID != nil && plan.isValid && !plan.dates.isEmpty }

    private func save() {
        guard let id = routineID else { return }
        let name = routines.first { $0.id == id }?.name ?? "Routine"
        if !replacing.isEmpty { settings.removeUpcoming(routineID: id) }
        settings.schedule(routineID: id, name: name, dates: plan.dates, includesTime: plan.includesTime)
        dismiss()
    }
}
#endif
