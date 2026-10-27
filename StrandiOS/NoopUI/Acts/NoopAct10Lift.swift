#if os(iOS)
import SwiftUI
import StrandFitness
import StrandAnalytics
import UniformTypeIdentifiers
import Security
import WhoopStore
import StrandImport
import StrandTraining

// MARK: - Act 10 · The lift

/// Route-to-route Lift state. The running workout deliberately does not live here — it is owned by
/// `LiftSessionController` above the shell, so leaving this Act cannot stop its clock or strap tap.
@MainActor
final class NoopLiftFlowModel: ObservableObject {
    @Published var programs: [LiftProgramRow] = []
    @Published var archivedPrograms: [LiftProgramRow] = []
    @Published var sessions: [LiftSessionRow] = []
    @Published var selectedProgram: LiftProgramRow?
    @Published var programItems: [LiftProgramItemRow] = []
    @Published var selectedSession: LiftSessionRow?
    @Published var sessionSets: [LiftSetRow] = []
    @Published var importResult: LiftingImportResult?
    @Published var importFileName: String?
    /// The same Hevy file read set by set, so a commit can store the sets as well as the session totals.
    private var importWorkouts: [HevyCSVWorkout] = []
    @Published var importError: String?
    @Published var importCommitted = false
    @Published var isReadingImport = false
    @Published var deletedSetIDs: Set<String> = []
    @Published var editSaved = false
    @Published var isLoaded = false

    func refresh(repo: Repository) async {
        guard let store = await repo.storeHandle() else { return }
        let allPrograms = (try? await store.liftPrograms(deviceId: repo.deviceId, includeArchived: true)) ?? []
        programs = allPrograms.filter { !$0.archived }
        archivedPrograms = allPrograms.filter(\.archived)
        let now = Int(Date().timeIntervalSince1970)
        sessions = (try? await store.liftSessions(deviceId: repo.deviceId, fromTs: 0, toTs: now)) ?? []
        isLoaded = true
    }

    func loadSession(id: String?, repo: Repository) async {
        guard let id, let store = await repo.storeHandle() else {
            selectedSession = nil
            sessionSets = []
            return
        }
        if !isLoaded { await refresh(repo: repo) }
        selectedSession = sessions.first { $0.id == id }
        sessionSets = (try? await store.liftSets(sessionId: id)) ?? []
        deletedSetIDs = []
        editSaved = false
    }

    func readImport(url: URL) async {
        isReadingImport = true
        importError = nil
        importCommitted = false
        defer { isReadingImport = false }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let parsed = LiftingImporter.parse(data: data)
            guard parsed.sessionCount > 0 else {
                importResult = nil
                importFileName = url.lastPathComponent
                importError = "No sessions were found. Choose the CSV Hevy exports or a Liftosaur JSON export. Nothing was added."
                return
            }
            importResult = parsed
            importWorkouts = LiftingImporter.detectFormat(data: data) == .hevyCsv ? LiftingImporter.hevyWorkouts(data: data) : []
            importFileName = url.lastPathComponent
        } catch {
            importResult = nil
            importFileName = url.lastPathComponent
            importError = "The file could not be read. Nothing was added."
        }
    }

    /// Each Hevy workout as a lift session with its sets, so it opens exercise by exercise like one
    /// recorded here. The id comes from the start time, so importing the same file again replaces the
    /// same sets rather than adding a second copy; a session Noop recorded itself at that time stands.
    private func storeImportedSets(store: WhoopStore, deviceId: String) async throws {
        for w in importWorkouts {
            let start = Int(w.start.timeIntervalSince1970), end = Int(w.end.timeIntervalSince1970)
            let nearby = (try? await store.liftSessions(deviceId: deviceId, fromTs: start - 30 * 60, toTs: max(end, start))) ?? []
            if nearby.contains(where: { !$0.id.hasPrefix("hevy") && abs($0.startTs - start) < 30 * 60 }) { continue }
            let sessionId = "hevycsv-\(start)"
            var perExercise: [String: Int] = [:]
            let rows = w.sets.enumerated().map { ord, set -> LiftSetRow in
                let name = HevySync.noopName(set.exercise)
                let choice = NoopFitnessExerciseChoice.lookup(name)
                let index = perExercise[name, default: 0]
                perExercise[name] = index + 1
                return LiftSetRow(id: "\(sessionId)-\(ord)", deviceId: deviceId, sessionId: sessionId, ord: ord,
                                  exercise: name, primaryMuscle: choice?.primary, secondaryMuscles: choice?.secondaries ?? [],
                                  setIndex: index, weightKg: set.weightKg, reps: set.reps, rpe: set.rpe,
                                  isWarmup: set.isWarmup, startTs: nil, endTs: nil, restSec: nil,
                                  note: index == 0 ? set.note : nil,
                                  setKind: set.setType == "dropset" ? .drop : set.setType == "failure" ? .failure : nil)
            }
            _ = try await store.upsertLiftSessions([LiftSessionRow(
                id: sessionId, deviceId: deviceId, startTs: start, endTs: end, sport: LiftingImporter.sport,
                programId: nil, programName: w.title, sessionRpe: nil, note: "From a Hevy export")])
            _ = try await store.replaceLiftSessionSets(sessionId: sessionId, rows: rows)
        }
    }

    func commitImport(repo: Repository) async -> Bool {
        guard !importCommitted, let result = importResult,
              let store = await repo.storeHandle() else { return false }
        let rows = result.sessions.map { item in
            WorkoutRow(
                startTs: Int(item.start.timeIntervalSince1970), endTs: Int(item.end.timeIntervalSince1970),
                sport: LiftingImporter.sport, source: LiftingImporter.sourceId,
                durationS: item.durationS, energyKcal: nil, avgHr: nil, maxHr: nil,
                strain: nil, distanceM: nil, zonesJSON: nil,
                notes: item.volumeLoadNote(), steps: nil
            )
        }
        do {
            try await store.upsertWorkouts(rows, deviceId: LiftingImporter.sourceId)
            try await storeImportedSets(store: store, deviceId: repo.deviceId)
            NoopFitnessModel.markChanged()
            importCommitted = true
            await repo.refresh()
            await refresh(repo: repo)
            return true
        } catch {
            importError = "The sessions could not be written to the local record. Nothing was added."
            return false
        }
    }
}

struct NoopAct10Screens: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var flow: NoopLiftFlowModel

    var body: some View {
        switch navigation.route {
        case .liftLive: NoopLiftLiveScreen(navigation: navigation, flow: flow)
        case .liftDetail: NoopLiftDetailScreen(navigation: navigation, flow: flow)
        case .liftEdit: NoopLiftEditScreen(navigation: navigation, flow: flow)
        case .liftImport: NoopLiftImportScreen(navigation: navigation, flow: flow)
        case .liftReview: NoopLiftReviewScreen(navigation: navigation, flow: flow)
        case .liftMuscles: NoopLiftMusclesScreen(navigation: navigation, flow: flow)
        // The Programs list was retired for Fitness; navigation sends its route there, and so does this.
        default: Color.clear.onAppear { navigation.reset(to: .fitness) }
        }
    }
}

// MARK: - Shared Act 10 pieces

/// Act 10's HTML header is 34 pt tall at y=56, with an 18 pt outer inset. The
/// general back header adds top and bottom spacing for older acts, which moves
/// every Lift title and card down even when the screen's own inset is correct.
private struct NoopLiftBackHeader: View {
    let label: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            NoopBackButton(action: action)

            NoopBackTitle(label)
            Spacer()
        }
        .padding(.horizontal, -2)
        // The enclosing 14 pt stack gap and this 2 pt make the HTML's
        // header-bottom 8 + content-top 8, without changing later card gaps.
        .padding(.bottom, 2)
    }
}

private struct NoopLiftTitle: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(NoopHTMLFont.outfit(NoopType.title2, weight: .regular))
                .tracking(-0.625)
                .foregroundStyle(NoopHTMLColor.ink)
            Text(subtitle)
                .font(NoopHTMLFont.sans(NoopType.footnote))
                .foregroundStyle(NoopHTMLColor.copy)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct NoopLiftSheetHeader: View {
    let label: String
    let trailing: String?
    let back: () -> Void
    var body: some View {
        HStack {
            Button(action: back) {
                Text(label)
                    .font(NoopHTMLFont.sans(NoopType.footnote))
                    .foregroundStyle(NoopHTMLColor.blueLight)
                    .frame(minHeight: 36)
                    .padding(.horizontal, 4)
            }
            .buttonStyle(NoopPlainHitStyle())
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.blueLight)
            }
        }
    }
}

private struct NoopLiftActionButton: View {
    let title: String
    var accent = true
    var warm = false
    var disabled = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                .foregroundStyle(warm ? Color(hex: 0xF3C888) : accent ? NoopHTMLColor.blueInk : NoopHTMLColor.inkSoft)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(warm ? NoopHTMLColor.warm.opacity(0.10) : accent ? NoopHTMLColor.blue : Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(warm ? NoopHTMLColor.warm.opacity(0.34) : accent ? NoopHTMLColor.blue.opacity(0.50) : Color.white.opacity(0.12), lineWidth: 0.5)
                )
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.42 : 1)
    }
}

private func liftClock(_ seconds: Int, long: Bool = false) -> String {
    let safe = max(0, seconds)
    if long { return String(format: "%d:%02d:%02d", safe / 3600, (safe / 60) % 60, safe % 60) }
    return String(format: "%d:%02d", safe / 60, safe % 60)
}

private func liftWeight(_ kilograms: Double?, system: UnitSystem) -> String? {
    guard let kilograms else { return nil }
    let value = LiftFormat.trim(LiftFormat.display(fromKilograms: kilograms, system: system))
    return "\(value) \(LiftFormat.weightUnit(system))"
}

private extension Date {
    var noopLiftDay: String { formatted(.dateTime.locale(Locale(identifier: "en_GB")).day().month(.abbreviated)) }
    var noopLiftTime: String { formatted(date: .omitted, time: .shortened) }
}

/// The lifting-import key is separate from Svea's provider key. It is device-only and the UI keeps
/// only the final four characters in memory; no preference or log receives the secret.
private enum NoopHevyKeyStore {
    // Read at runtime: the signing bundle id lives only in the untracked secrets xcconfig and must
    // never appear in this public tree. It resolves to the same service name the key was saved under.
    private static let service = (Bundle.main.bundleIdentifier ?? "com.noopapp.noop") + ".hevy"
    private static let account = "read-only-api-key"
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
    static func read() -> String? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ value: String) -> Bool {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let data = clean.data(using: .utf8) else { return false }
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }
    static func clear() { SecItemDelete(query as CFDictionary) }
}

// MARK: - lift-live

private struct NoopLiftLiveScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var flow: NoopLiftFlowModel
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var live: LiftSessionController
    @AppStorage(UnitPrefs.systemKey) private var unitSystemRaw = UnitSystem.metric.rawValue
    @State private var loadText = ""
    @State private var repsText = ""
    @State private var showFinish = false
    @State private var saving = false
    @State private var saveError: String?
    @State private var addingExercise = false
    @State private var vocabulary: [LiftExerciseRow] = []
    @State private var confirmDiscard = false
    @State private var ratingEffort = false
    @State private var sessionRpe = 6.0
    @State private var lastTime: [String: [Int: LiftSetCarry]] = [:]
    @State private var lastTimeFor: NoopLiftExerciseName?
    @FocusState private var focused: Field?
    @EnvironmentObject private var heart: LiveState
    @AppStorage(LiftSessionController.restAlertsKey) private var restAlerts = true
    @AppStorage(LiftSessionController.autoScrollKey) private var autoScroll = true
    @AppStorage(LiftSessionController.barKgKey) private var barKg = 20.0
    /// Every earlier session of each exercise on the sheet, for the records a set can break.
    @State private var priorHistory: [String: [LiftHistorySet]] = [:]
    @State private var celebration: NoopLiftCelebration?
    @State private var insightsFor: NoopFitnessExerciseChoice?

    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }
    private var presentation: LiftSessionController.Presentation? { live.presentation(system: units) }
    private var slot: LiftSlot? { live.engine?.currentSlot ?? live.engine?.nextPendingSlot }

    var body: some View {
        Group {
            if let engine = live.engine, let presentation, let slot,
               let item = engine.planItem(for: slot) {
                session(engine: engine, presentation: presentation, slot: slot, item: item)
            } else {
                noSession
            }
        }
        .task { await prepare() }
        .task(id: live.engine?.plan.count) { await loadPriorHistory() }
        .onChange(of: slot) { _, _ in syncFields() }
        .onChange(of: live.engine?.sets.count) { old, new in
            syncFields()
            if (new ?? 0) > (old ?? 0) { celebrateRecords() }
        }
        .alert("Lift not saved", isPresented: Binding(
            get: { saveError != nil }, set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "Your session and its sets are still here. Try saving again.")
        }
    }

    private enum Field: Hashable { case weight, reps }

    private static func exerciseAnchor(_ index: Int) -> String { "lift-exercise-\(index)" }

    /// One warm-up step on the bar: 2.5 kg, or 5 lb.
    private var plateStepKg: Double { units == .metric ? 2.5 : LiftFormat.kilograms(fromDisplay: 5, system: units) }

    private func session(engine: LiftSessionEngine,
                         presentation: LiftSessionController.Presentation,
                         slot: LiftSlot,
                         item: LiftPlanItem) -> some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { scroll in
            NoopScreen(bottomInset: 120, topInset: 54) {
                VStack(alignment: .leading, spacing: 14) {
                    liveHeader(presentation)
                    ForEach(Array(engine.plan.enumerated()), id: \.offset) { index, line in
                        exerciseBlock(engine: engine, index: index, line: line, current: slot,
                                      isResting: presentation.isResting)
                            .id(Self.exerciseAnchor(index))
                    }
                    Button { addingExercise = true } label: {
                        HStack(spacing: 8) {
                            NoopCanonicalGlyph(name: .plus, size: 14, color: NoopHTMLColor.inkSoft)
                            Text("Add exercise").font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.inkSoft)
                        }
                        .frame(maxWidth: .infinity).frame(minHeight: 50)
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    Text("Warm-ups are left out of every figure. Sets you never reach are not saved.")
                        .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.muted)
                        .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                }
            }
            // The next set is on another exercise — the other half of a superset, or the next line
            // once one is finished: bring it into view, so the lifter never hunts for the row to tap.
            // Not while a number is being typed, which would pull the field out from under the finger.
            .onChange(of: slot.exerciseIndex) { _, index in
                guard autoScroll, focused == nil else { return }
                withAnimation(NoopMotion.swap) { scroll.scrollTo(Self.exerciseAnchor(index), anchor: UnitPoint(x: 0.5, y: 0.12)) }
            }
            }
            // While a number is typed the keypad and its own bar (−, +, plates, Reps) own the bottom of
            // the screen: the session bar steps aside rather than sit on top of them, and returns with
            // the keyboard's own timing when the field is let go.
            if focused == nil {
                liveBar(engine: engine, presentation: presentation, slot: slot, item: item)
                    // Clear of the home indicator: this screen runs edge to edge, so the bar keeps the same
                    // distance from the bottom the tab bar does on every other screen.
                    .padding(.horizontal, 14).padding(.bottom, 26)
                    .transition(.opacity.combined(with: .offset(y: 24)))
            }
        }
        .animation(.easeOut(duration: 0.22), value: focused == nil)
        .overlay(alignment: .top) {
            if let celebration {
                NoopLiftRecordBanner(celebration: celebration)
                    .padding(.horizontal, 14).padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { withAnimation(NoopMotion.swap) { self.celebration = nil } }
            }
        }
        .sensoryFeedback(.success, trigger: celebration?.id)
        .sheet(item: $insightsFor) { choice in
            NoopFitnessExerciseDetail(choice: choice, initialTab: .records).noopSheet()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) { keypadBar(slot: slot) }
        }
        .sheet(isPresented: $addingExercise) {
            NoopFitnessExercisePicker(yours: vocabulary) { choice in
                _ = live.addExercise(choice.name, primaryMuscle: choice.primary, secondaryMuscles: choice.secondaries)
            }
            .noopSheet()
        }
        .sheet(item: $lastTimeFor) { target in
            NoopLiftLastTimeSheet(exercise: target.name, sets: lastTime[target.name] ?? [:], units: units)
                .noopSheet([.medium])
        }
        .sheet(isPresented: $ratingEffort) {
            NoopLiftEffortSheet(rating: $sessionRpe) {
                ratingEffort = false
                Task { await finish(includeShownValues: true) }
            }
            .noopSheet()
            .interactiveDismissDisabled(saving)
        }
        .alert("End the workout?", isPresented: $showFinish) {
            Button("Keep going", role: .cancel) { }
            Button("End workout") { ratingEffort = true }
        } message: {
            Text("The sets you completed are saved. Sets you never reached stay out of your record.")
        }
        .alert("Discard this workout?", isPresented: $confirmDiscard) {
            Button("Keep it", role: .cancel) { }
            Button("Discard", role: .destructive) {
                live.discard()
                navigation.replace(with: .fitness)
            }
        } message: {
            Text("Nothing from this session will be saved.")
        }
    }

    // MARK: Header

    private func liveHeader(_ presentation: LiftSessionController.Presentation) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                // The clock reads the wall clock once a second, because the session publishes nothing
                // between taps (upstream 12.0).
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(liftClock(liveElapsed(presentation, at: context.date), long: true))
                        .font(NoopHTMLFont.outfit(NoopType.title1, weight: .light))
                        .monospacedDigit()
                        .foregroundStyle(live.isPaused ? NoopHTMLColor.copy : NoopHTMLColor.ink)
                }
                HStack(spacing: 6) {
                    NoopCanonicalGlyph(name: .weight, size: 13, color: NoopHTMLColor.warm)
                    Text(live.isPaused ? "Paused" : (live.programName ?? "Lift"))
                        .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                        .foregroundStyle(live.isPaused ? NoopHTMLColor.copy : NoopHTMLColor.warm)
                        .lineLimit(1)
                }
            }
            Spacer()
            Button {
                if live.engine?.allCompleted == true { ratingEffort = true } else { showFinish = true }
            } label: {
                Text("Finish").font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.warmInk)
                    .padding(.horizontal, 18).frame(minHeight: 40)
                    .background(NoopHTMLColor.warm, in: Capsule())
            }
            .buttonStyle(NoopHTMLPressStyle())
            .disabled(saving)
            Menu {
                Button { live.togglePause() } label: {
                    Label(live.isPaused ? "Resume workout" : "Pause workout", systemImage: live.isPaused ? "play" : "pause")
                }
                Button { live.undo() } label: { Label("Undo last step", systemImage: "arrow.uturn.backward") }
                    .disabled(!(live.engine?.canUndo ?? false))
                Toggle(isOn: Binding(get: { restAlerts }, set: { on in
                    restAlerts = on
                    if on { LiftSessionController.askForRestAlertsIfUndecided() }
                    live.refreshRestAlert()
                })) {
                    Label("Alert when rest ends", systemImage: "bell")
                }
                Divider()
                Button(role: .destructive) { confirmDiscard = true } label: { Label("Discard workout", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.inkSoft)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.06), in: Circle())
                    .overlay(Circle().stroke(NoopHTMLColor.borderStrong, lineWidth: 0.5))
            }
        }
    }

    // MARK: Exercise

    private func exerciseBlock(engine: LiftSessionEngine, index: Int, line: LiftPlanItem,
                               current: LiftSlot, isResting: Bool) -> some View {
        let slots = engine.slots(forExercise: index)
        let working = slots.filter { !live.isWarmup($0) }
        let done = working.filter { engine.isCompleted($0) }.count
        let isCurrent = current.exerciseIndex == index
        let group = line.supersetGroup
        let next = engine.plan.indices.contains(index + 1) ? engine.plan[index + 1] : nil
        let ramp = live.warmupSuggestion(forExercise: index, incrementKg: plateStepKg)
        let coach = done < working.count ? live.coachNote(forExercise: index, incrementKg: plateStepKg) : nil
        return VStack(alignment: .leading, spacing: 8) {
            if group != nil {
                supersetLabel(engine: engine, index: index, group: group)
            }
            HStack(spacing: 11) {
                NoopCanonicalGlyph(name: .weight, size: 16, color: isCurrent ? NoopHTMLColor.warm : NoopHTMLColor.copy)
                    .frame(width: 36, height: 36)
                    .background((isCurrent ? NoopHTMLColor.warm : Color.white).opacity(isCurrent ? 0.14 : 0.05),
                                in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Button {
                        insightsFor = .named(line.exercise, primary: line.primaryMuscle, secondaries: line.secondaryMuscles)
                    } label: {
                        Text(line.exercise).font(NoopHTMLFont.sans(NoopType.body, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                            .lineLimit(1)
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    .accessibilityHint("Opens this exercise's records and history")
                    Text(exerciseMeta(line, done: done, of: working.count, warmups: slots.count - working.count))
                        .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy).lineLimit(1)
                }
                Spacer(minLength: 4)
                HStack(spacing: 4) {
                    Image(systemName: "timer").font(.system(size: 10.5, weight: .semibold))
                    Text(liftClock(line.restSec)).font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).monospacedDigit()
                }
                .foregroundStyle(NoopHTMLColor.copy)
                .padding(.horizontal, 9).frame(height: 26)
                .background(Color.white.opacity(0.05), in: Capsule())
                .accessibilityLabel("Rest \(liftClock(line.restSec)) between sets")
                Menu {
                    Button { _ = live.addSet(toExercise: index) } label: { Label("Add a set", systemImage: "plus") }
                    Button { _ = live.removeSet(fromExercise: index) } label: { Label("Remove the last set", systemImage: "minus") }
                        .disabled(slots.count <= 1 || engine.isCompleted(slots.last ?? current))
                    Button { _ = live.insertWarmups(intoExercise: index, incrementKg: plateStepKg) } label: {
                        if let top = ramp.last?.targetWeightKg, let first = ramp.first?.targetWeightKg {
                            Label("Add \(ramp.count) warm-up sets, \(LiftFormat.trim(LiftFormat.display(fromKilograms: first, system: units)))–\(LiftFormat.trim(LiftFormat.display(fromKilograms: top, system: units))) \(LiftFormat.weightUnit(units))",
                                  systemImage: "flame")
                        } else {
                            Label("Add warm-up sets", systemImage: "flame")
                        }
                    }
                    .disabled(ramp.isEmpty)
                    Section {
                        if let next, group == nil || group != next.supersetGroup {
                            Button { live.linkSuperset(index) } label: {
                                Label("Superset with \(next.exercise)", systemImage: "link")
                            }
                        }
                        if group != nil {
                            Button { live.unlinkSuperset(index) } label: {
                                Label("Remove from superset", systemImage: "minus.circle")
                            }
                        }
                    }
                    Button { lastTimeFor = .init(name: line.exercise) } label: { Label("Last time", systemImage: "clock.arrow.circlepath") }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.copy).frame(width: 32, height: 32).noopHitTarget()
                }
            }
            if let coach { coachLine(coach) }
            HStack(spacing: 8) {
                Text("SET").lineLimit(1).frame(width: 34, alignment: .leading)
                if isTimed(line) {
                    Text("TIME").frame(maxWidth: .infinity)
                } else {
                    Text(LiftFormat.weightUnit(units).uppercased()).frame(maxWidth: .infinity)
                    Text("REPS").frame(maxWidth: .infinity)
                }
                Color.clear.frame(width: 38, height: 1)
            }
            .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).tracking(0.8).foregroundStyle(NoopHTMLColor.muted)
            .padding(.top, 4)
            ForEach(slots, id: \.self) { row in
                setRow(row, engine: engine, active: row == current && !isResting)
                restLine(after: row, engine: engine, isLast: row == slots.last)
            }
            Button { _ = live.addSet(toExercise: index) } label: {
                HStack(spacing: 5) {
                    NoopCanonicalGlyph(name: .plus, size: 11, color: NoopHTMLColor.inkSoft)
                    Text("Add set").font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(NoopHTMLColor.inkSoft)
                }
                .frame(maxWidth: .infinity).frame(minHeight: 36)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(NoopHTMLPressStyle())
            .padding(.top, 4)
        }
        .padding(14)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(isCurrent ? NoopHTMLColor.warm.opacity(0.28) : NoopHTMLColor.border, lineWidth: isCurrent ? 0.8 : 0.5))
        .overlay(alignment: .leading) {
            // A superset reads as one block: the same rail down every line in it.
            if group != nil {
                Capsule().fill(NoopHTMLColor.night).frame(width: 3).padding(.vertical, 20).offset(x: -1.5)
            }
        }
        .animation(NoopMotion.swap, value: group)
    }

    /// Above a superset line: which group it is in, and where the session goes after this line's set.
    private func supersetLabel(engine: LiftSessionEngine, index: Int, group: UUID?) -> some View {
        let members = engine.plan.indices.filter { engine.plan[$0].supersetGroup == group }
        let position = (members.firstIndex(of: index) ?? 0) + 1
        let letter = String(UnicodeScalar(UInt8(64 + min(26, supersetOrdinal(engine: engine, group: group)))))
        return HStack(spacing: 6) {
            Image(systemName: "link").font(.system(size: 10, weight: .bold))
            Text("SUPERSET \(letter) · \(position) OF \(members.count)")
                .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).tracking(1)
        }
        .foregroundStyle(NoopHTMLColor.nightLight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Superset \(letter), exercise \(position) of \(members.count). Sets alternate between them.")
    }

    /// Supersets are lettered in the order they appear on the sheet: A, B, C.
    private func supersetOrdinal(engine: LiftSessionEngine, group: UUID?) -> Int {
        var seen: [UUID] = []
        for line in engine.plan { if let g = line.supersetGroup, !seen.contains(g) { seen.append(g) } }
        return (group.flatMap { seen.firstIndex(of: $0) } ?? 0) + 1
    }

    private func exerciseMeta(_ line: LiftPlanItem, done: Int, of total: Int, warmups: Int) -> String {
        var parts = ["\(done) of \(total) sets"]
        if warmups > 0 { parts.append("\(warmups) warm-up") }
        let muscles = LiftMuscleSummary.line(primary: line.primaryMuscle, secondaries: line.secondaryMuscles)
        if !muscles.isEmpty { parts.append(muscles) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func setRow(_ row: LiftSlot, engine: LiftSessionEngine, active: Bool) -> some View {
        let done = engine.isCompleted(row)
        let values = live.values(of: row)
        let entered = live.enteredValues(for: row)
        let resting: Bool = {
            if case .resting(let s, _) = engine.stage { return s == row }
            return false
        }()
        let type = NoopLiftSetType(warmup: live.isWarmup(row), kind: live.kind(of: row))
        VStack(spacing: 10) {
        HStack(spacing: 8) {
            Menu {
                Picker("Set type", selection: Binding(get: { type }, set: { apply($0, to: row) })) {
                    ForEach(NoopLiftSetType.allCases, id: \.self) { option in
                        Label(option.title, systemImage: option.symbol).tag(option)
                    }
                }
                Divider()
                Button { lastTimeFor = .init(name: engine.planItem(for: row)?.exercise ?? "") } label: {
                    Label("Last time", systemImage: "clock.arrow.circlepath")
                }
            } label: {
                ZStack {
                    Circle().fill(done ? NoopHTMLColor.green.opacity(0.16) : type.tint.map { $0.opacity(0.14) } ?? Color.clear)
                    Circle().strokeBorder(active ? NoopHTMLColor.warm : done ? .clear : type.tint?.opacity(0.5) ?? Color.white.opacity(0.12), lineWidth: 1.2)
                    Text(type.letter ?? "\(workingNumber(row, engine: engine))")
                        .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                        .foregroundStyle(type.tint ?? (done ? NoopHTMLColor.green : active ? NoopHTMLColor.warm : NoopHTMLColor.inkSoft))
                }
                .frame(width: 30, height: 30)
                .contentTransition(.numericText())
            }
            .frame(width: 34, alignment: .leading)
            .accessibilityLabel("\(type.title) set \(row.setIndex). Change the set type or see last time.")
            if let line = engine.planItem(for: row), isTimed(line) {
                // A timed exercise is measured by the set itself: the clock runs while it is the set
                // in progress and stops on the tick. There is no weight or count to type.
                if active {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        cell(Self.clock(max(0, Self.second(context.date) - engine.stageStartedAt)),
                             done: false, typed: true)
                    }
                } else if done, let set = engine.sets.first(where: { $0.slot == row }) {
                    cell(Self.clock(max(0, set.endTs - set.startTs)), done: true, typed: true)
                } else {
                    cell(line.routinePlan?.sets[safe: row.setIndex - 1]?.targetDurationS.map { Self.clock($0) } ?? "—",
                         done: false, typed: false)
                }
            } else if active {
                field($loadText, placeholder: values.weightKg.map { LiftFormat.trim(LiftFormat.display(fromKilograms: $0, system: units)) } ?? "—",
                      focus: .weight, slot: row)
                field($repsText, placeholder: values.reps.map(String.init) ?? "—", focus: .reps, slot: row)
            } else {
                cell(values.weightKg.map { LiftFormat.trim(LiftFormat.display(fromKilograms: $0, system: units)) } ?? "—",
                     done: done, typed: entered.weightKg != nil)
                cell(values.reps.map(String.init) ?? "—", done: done, typed: entered.reps != nil)
            }
            Button {
                guard !live.isPaused else { return }
                if active {
                    focused = nil
                    writeFields(slot: row)
                    live.advance()
                } else if !done, !resting, let current = slot {
                    writeFields(slot: current)
                    live.start(row)
                }
            } label: {
                ZStack {
                    Circle().fill(done ? NoopHTMLColor.green : active ? NoopHTMLColor.warm : Color.white.opacity(0.06))
                    if done {
                        NoopCanonicalGlyph(name: .check, size: 14, color: NoopHTMLColor.canvas)
                    } else if active {
                        NoopCanonicalGlyph(name: .check, size: 14, color: NoopHTMLColor.warmInk)
                    } else {
                        NoopCanonicalGlyph(name: .play, size: 12, color: NoopHTMLColor.inkSoft)
                    }
                }
                .frame(width: 34, height: 34)
            }
            .buttonStyle(NoopHTMLPressStyle())
            .disabled(done)
            .frame(width: 38)
            .accessibilityLabel(done ? "Done" : active ? "Log set \(row.setIndex)" : "Start set \(row.setIndex)")
        }
        // While the weight is being typed, the bar as it will be loaded.
        if active, focused == .weight, let load = plateBreakdown {
            NoopPlateBar(load: load)
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
        }
        }
        .opacity(done || active ? 1 : 0.86)
        .animation(NoopMotion.swap, value: done)
        .animation(NoopMotion.swap, value: focused == .weight && active)
    }

    /// Today's aim for the exercise, from last time: a quiet line with its reason, under the name.
    private func coachLine(_ note: LiftCoachNote) -> some View {
        let unit = LiftFormat.weightUnit(units)
        func w(_ kg: Double) -> String { LiftFormat.trim(LiftFormat.display(fromKilograms: kg, system: units)) }
        let last = note.lastReps.map(String.init).joined(separator: ", ")
        let (symbol, headline, reason): (String, String, String) = {
            switch note.advice {
            case .addWeight(let to, let by, let reps):
                return ("arrow.up.right", "Go up to \(w(to)) \(unit) for \(reps)", "+\(w(by)) \(unit) · every set reached the top last time (\(last))")
            case .addRep(let kg, let reps):
                return ("plus", "\(w(kg)) \(unit) again, aim for \(reps) reps", "One more than last time (\(last))")
            case .repeatTarget(let kg, let reps):
                return ("arrow.counterclockwise", "Hold \(w(kg)) \(unit) for \(reps)", "Last time fell a little short (\(last)), so it is the same target")
            }
        }()
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).font(.system(size: 11, weight: .bold)).foregroundStyle(NoopHTMLColor.warm)
                .frame(width: 22, height: 22).background(NoopHTMLColor.warm.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(headline).font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                    .monospacedDigit()
                Text(reason).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.copy)
                    .monospacedDigit().fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(NoopHTMLColor.warm.opacity(0.06), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// A working set's number counts working sets only: three warm-ups and then the first working set
    /// read W W W 1, the way a lifter counts them.
    private func workingNumber(_ row: LiftSlot, engine: LiftSessionEngine) -> Int {
        max(1, (1...row.setIndex).filter { !live.isWarmup(LiftSlot(exerciseIndex: row.exerciseIndex, setIndex: $0)) }.count)
    }

    private func apply(_ type: NoopLiftSetType, to row: LiftSlot) {
        switch type {
        case .working: live.setKind(row, nil); live.setWarmup(row, false)
        case .warmup: live.setWarmup(row, true)
        case .drop: live.setKind(row, .drop)
        case .failure: live.setKind(row, .failure)
        }
    }

    /// Under a set: the rest running after it, or the rest that was taken.
    @ViewBuilder
    private func restLine(after row: LiftSlot, engine: LiftSessionEngine, isLast: Bool) -> some View {
        if case .resting(let s, _) = engine.stage, s == row {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = presentation?.heldClockSeconds ?? engine.restRemaining(now: Self.second(context.date)) ?? 0
                HStack(spacing: 8) {
                    Capsule().fill(NoopHTMLColor.blueLight.opacity(0.35)).frame(height: 1)
                    HStack(spacing: 5) {
                        Image(systemName: "timer").font(.system(size: 10, weight: .bold))
                        Text(remaining > 0 ? liftClock(remaining) : "Rest done")
                            .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).monospacedDigit()
                    }
                    .foregroundStyle(NoopHTMLColor.blueInk)
                    .padding(.horizontal, 10).frame(height: 24)
                    .background(remaining > 0 ? NoopHTMLColor.blueLight : NoopHTMLColor.green, in: Capsule())
                    Capsule().fill(NoopHTMLColor.blueLight.opacity(0.35)).frame(height: 1)
                }
                .padding(.vertical, 2)
            }
        } else if let rest = engine.recordedSet(for: row)?.restSec, !isLast {
            Text("rested \(liftClock(rest))")
                .font(NoopHTMLFont.sans(NoopType.eyebrow)).monospacedDigit().foregroundStyle(NoopHTMLColor.muted)
                .frame(maxWidth: .infinity)
        }
    }

    private func cell(_ t: String, done: Bool, typed: Bool) -> some View {
        Text(t).font(NoopHTMLFont.sans(NoopType.subhead, weight: done ? .semibold : .regular))
            .foregroundStyle(done ? NoopHTMLColor.ink : typed ? NoopHTMLColor.inkSoft : NoopHTMLColor.muted)
            .monospacedDigit()
            .frame(maxWidth: .infinity).frame(minHeight: 40)
            .background(done ? NoopHTMLColor.green.opacity(0.08) : Color.white.opacity(0.03),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    /// The active set's value, typed on the number pad; the bar above the pad nudges it.
    private func field(_ text: Binding<String>, placeholder: String, focus: Field, slot: LiftSlot) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(focus == .weight ? .decimalPad : .numberPad)
            .multilineTextAlignment(.center)
            .font(NoopHTMLFont.sans(NoopType.body, weight: .semibold))
            .foregroundStyle(NoopHTMLColor.ink)
            .monospacedDigit()
            .focused($focused, equals: focus)
            .onChange(of: text.wrappedValue) { _, _ in writeFields(slot: slot) }
            .frame(maxWidth: .infinity).frame(height: 40)
            .background(NoopHTMLColor.warm.opacity(focused == focus ? 0.16 : 0.08),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(NoopHTMLColor.warm.opacity(focused == focus ? 0.8 : 0.4), lineWidth: focused == focus ? 1.2 : 0.8))
    }

    /// Above the number pad: step the value, read the plates for it, move on.
    @ViewBuilder
    private func keypadBar(slot: LiftSlot) -> some View {
        if let f = focused {
            Button { nudge(isWeight: f == .weight, amount: -1, slot: slot) } label: { Image(systemName: "minus") }
            Button { nudge(isWeight: f == .weight, amount: 1, slot: slot) } label: { Image(systemName: "plus") }
            Spacer()
            if f == .weight, let plates = plateLine {
                Text(plates).font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(NoopHTMLColor.copy)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
            }
            Button(f == .weight ? "Reps" : "Done") {
                if f == .weight { focused = .reps } else { focused = nil; writeFields(slot: slot) }
            }
            .fontWeight(.semibold)
        }
    }

    /// Plates per side for the typed weight on the chosen bar (20 kg reads as 45 lb), largest first, and
    /// what no plate pair can make.
    private var plateBreakdown: NoopPlateBar.Load? {
        guard let total = Double(loadText.replacingOccurrences(of: ",", with: ".")) else { return nil }
        let metric = units == .metric
        // The chosen bar, in the units on screen: 20 kg reads as 45 lb, the way the plates are sold.
        let bar = metric ? barKg : (barKg >= 19 ? 45 : barKg >= 14 ? 35 : (LiftFormat.display(fromKilograms: barKg, system: units)).rounded())
        guard total > bar else { return nil }
        var side = (total - bar) / 2
        var used: [Double] = []
        for p in NoopPlateBar.plates(metric: metric) {
            while side + 0.001 >= p { side -= p; used.append(p) }
        }
        guard !used.isEmpty else { return nil }
        return .init(bar: bar, perSide: used, leftover: side > 0.01 ? side : 0, metric: metric)
    }

    private var plateLine: String? {
        guard let load = plateBreakdown else { return nil }
        var groups: [(Double, Int)] = []
        for p in load.perSide {
            if let i = groups.firstIndex(where: { $0.0 == p }) { groups[i].1 += 1 } else { groups.append((p, 1)) }
        }
        let used = groups.map { $0.1 > 1 ? "\($0.1)×\(LiftFormat.trim($0.0))" : LiftFormat.trim($0.0) }
        return "Each side: " + used.joined(separator: " + ") + (load.leftover > 0 ? " (+\(LiftFormat.trim(load.leftover)))" : "")
    }

    // MARK: Bottom bar

    private func liveBar(engine: LiftSessionEngine, presentation: LiftSessionController.Presentation,
                         slot: LiftSlot, item: LiftPlanItem) -> some View {
        let warmup = engine.stage == .warmup
        // Every set done: the bar stops offering a next set and offers the finish line instead.
        let allDone = engine.allCompleted
        // Only the words tick. The button stays outside the once-a-second redraw, so a press that
        // spans a tick is never cancelled.
        return HStack(spacing: 12) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let nowSec = Self.second(context.date)
                let remaining = presentation.heldClockSeconds ?? engine.restRemaining(now: nowSec)
                let inSet = max(0, nowSec - engine.stageStartedAt)
                VStack(alignment: .leading, spacing: 2) {
                    Text(allDone ? "Every set done" : warmup ? "Warm-up" : item.exercise)
                        .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink).lineLimit(1)
                    Group {
                        if allDone {
                            Text("Finish to save the workout").foregroundStyle(NoopHTMLColor.green)
                        } else if presentation.isResting {
                            Text((remaining ?? 0) > 0 ? "Rest \(liftClock(remaining ?? 0))" : "Ready for the next set")
                                .foregroundStyle(NoopHTMLColor.blueLight)
                        } else if warmup {
                            Text("Start when you are ready").foregroundStyle(NoopHTMLColor.copy)
                        } else {
                            Text("\(live.isWarmup(slot) ? "Warm-up" : "Set \(workingNumber(slot, engine: engine))") · \(liftClock(inSet))").foregroundStyle(NoopHTMLColor.copy)
                        }
                    }
                    .font(NoopHTMLFont.sans(NoopType.caption, weight: .medium)).monospacedDigit()
                }
            }
            Spacer(minLength: 6)
            if let bpm = heart.heartRate, bpm > 0 {
                HStack(spacing: 4) {
                    Text("\(bpm)").font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(NoopHTMLColor.ink)
                    Image(systemName: "heart.fill").font(.system(size: 11)).foregroundStyle(NoopHTMLColor.red)
                }
                .accessibilityLabel("\(bpm) beats per minute")
            }
            if presentation.isResting, !presentation.isReady, !allDone, !live.isPaused {
                // More rest, in place. Ending it early is the main button: it starts the next set.
                Button { live.adjustRest(by: 30); restBumps += 1 } label: {
                    Text("+30").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(NoopHTMLColor.blueLight)
                        .frame(width: 46, height: 40)
                        .background(NoopHTMLColor.blueLight.opacity(0.12), in: Capsule())
                        .noopHitTarget()
                }
                .buttonStyle(NoopHTMLPressStyle())
                .sensoryFeedback(.increase, trigger: restBumps)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .accessibilityLabel("Add 30 seconds of rest")
            }
            Button {
                focused = nil
                if allDone { ratingEffort = true; return }
                if !presentation.isResting { writeFields(slot: slot) }
                live.advance()
            } label: {
                ZStack {
                    Circle().fill(allDone ? NoopHTMLColor.green : presentation.isResting ? NoopHTMLColor.blueLight : NoopHTMLColor.warm)
                    if allDone {
                        Image(systemName: "flag.checkered").font(.system(size: 20, weight: .bold))
                            .foregroundStyle(NoopHTMLColor.canvas)
                            .transition(.scale.combined(with: .opacity))
                    } else if presentation.isResting || warmup {
                        NoopCanonicalGlyph(name: .play, size: 17, color: NoopHTMLColor.blueInk)
                    } else {
                        NoopCanonicalGlyph(name: .check, size: 19, color: NoopHTMLColor.warmInk)
                    }
                }
                .frame(width: 54, height: 54)
                .shadow(color: (allDone ? NoopHTMLColor.green : presentation.isResting ? NoopHTMLColor.blueLight : NoopHTMLColor.warm).opacity(0.3), radius: 12, y: 6)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: allDone)
            }
            .buttonStyle(NoopHTMLPressStyle())
            .disabled(live.isPaused || saving)
            .opacity(live.isPaused ? 0.45 : 1)
            .accessibilityLabel(allDone ? "Finish the workout" : presentation.isResting ? "Start the next set" : warmup ? "Start the first set" : "Log set \(slot.setIndex)")
        }
        .padding(.leading, 18).padding(.trailing, 8).padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .background(NoopHTMLColor.cardRaised.opacity(0.85), in: Capsule())
        .overlay(Capsule().strokeBorder(NoopHTMLColor.borderStrong, lineWidth: 0.5))
        .sensoryFeedback(.success, trigger: engine.completedWorkingSets)
        .sensoryFeedback(.impact(weight: .heavy), trigger: allDone)
    }

    /// Counts +30 taps, for their haptic.
    @State private var restBumps = 0

    private static func second(_ date: Date) -> Int { Int(date.timeIntervalSince1970) }

    /// "0:45", "1:30": a set's own duration.
    private static func clock(_ seconds: Int) -> String { String(format: "%d:%02d", seconds / 60, seconds % 60) }

    /// A plank or a hang: timed by its routine, by the catalogue, or by the lifter's own exercise.
    private func isTimed(_ line: LiftPlanItem) -> Bool {
        if line.routinePlan?.sets.contains(where: { ($0.targetDurationS ?? 0) > 0 }) == true { return true }
        let timedModes: Set<TrainingMeasurementMode> = [.duration, .distanceDuration]
        if let mode = NoopFitnessExerciseChoice.lookup(line.exercise)?.definition?.mode { return timedModes.contains(mode) }
        let key = NoopFitnessExercisePicker.fold(line.exercise)
        guard let own = vocabulary.first(where: { NoopFitnessExercisePicker.fold($0.name) == key }),
              let json = own.definitionJSON?.data(using: .utf8),
              let definition = try? JSONDecoder().decode(TrainingExercise.self, from: json) else { return false }
        return timedModes.contains(definition.mode)
    }

    /// Elapsed session time at `date`: the controller's figure as of its last change, carried forward
    /// by the wall clock unless the session is paused.
    private func liveElapsed(_ presentation: LiftSessionController.Presentation, at date: Date) -> Int {
        guard !live.isPaused else { return presentation.sessionElapsedSeconds }
        return presentation.sessionElapsedSeconds + max(0, Self.second(date) - live.now)
    }


    private var noSession: some View {
        NoopScreen(bottomInset: 26, topInset: 58) {
            VStack(alignment: .leading, spacing: 14) {
                NoopLiftTitle(title: "No lift is running",
                              subtitle: "Start from one of your programs. The session will remain live if you leave this screen.")
                NoopHTMLCard {
                    Text("Nothing is timed, inferred or saved until you start a session.")
                        .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.inkSoft)
                }
                NoopLiftActionButton(title: "Choose a program") { navigation.replace(with: .liftLibrary) }
            }
        }
    }

    private func prepare() async {
        await loadLastSessionValues()
        if let store = await repo.storeHandle() {
            vocabulary = (try? await store.liftExercises(deviceId: repo.deviceId)) ?? []
        }
        syncFields()
    }

    /// Each exercise's sessions before this one. Loaded for a line added mid-session too, so its sets can
    /// break records as well.
    private func loadPriorHistory() async {
        guard let engine = live.engine, true, let store = await repo.storeHandle() else { return }
        for name in Set(engine.plan.map(\.exercise)) where priorHistory[name] == nil {
            let rows = (try? await store.liftExerciseHistory(deviceId: repo.deviceId, exercise: name)) ?? []
            priorHistory[name] = rows.filter { $0.sessionStartTs < engine.startTs }
        }
    }

    /// The set just done broke a record: say which, briefly, at the top. Judged on the numbers the set
    /// counts as (typed, else grey) against every earlier session plus the sets already done today, so
    /// a second heavier set today is a record too — over the first. An exercise never logged before
    /// breaks nothing (`LiftRecords.broken`).
    private func celebrateRecords() {
        guard let engine = live.engine, let last = engine.sets.last, !live.isWarmup(last.slot),
              let line = engine.planItem(for: last.slot),
              let prior = priorHistory[line.exercise], !prior.isEmpty else { return }
        func row(_ slot: LiftSlot, id: String) -> LiftSetRow {
            let shown = live.values(of: slot)
            return LiftSetRow(id: id, deviceId: repo.deviceId, sessionId: "live", ord: 0, exercise: line.exercise,
                              primaryMuscle: line.primaryMuscle, setIndex: slot.setIndex, weightKg: shown.weightKg,
                              reps: shown.reps, rpe: nil, isWarmup: live.isWarmup(slot), startTs: nil, endTs: nil,
                              restSec: nil, note: nil)
        }
        let today = engine.sets.dropLast()
            .filter { engine.planItem(for: $0.slot)?.exercise == line.exercise }
            .map { LiftHistorySet(set: row($0.slot, id: "live-\($0.exerciseIndex)-\($0.setIndex)"), sessionStartTs: engine.startTs) }
        let set = row(last.slot, id: "live-now")
        let kinds = LiftRecords.broken(by: set, against: LiftRecords.exercise(prior + today))
        guard let first = kinds.first else { return }
        let shown = kinds.prefix(2).map { kind -> String in
            switch kind {
            case .heaviestWeight: return "Heaviest \(NoopExerciseFormat.kg(set.weightKg ?? 0, units))"
            case .bestOneRepMax:
                return "Est. max \(NoopExerciseFormat.kg(LiftMetrics.estimatedOneRepMaxKg(weightKg: set.weightKg, reps: set.reps) ?? 0, units))"
            case .bestSetVolume: return "Best set \(NoopExerciseFormat.set(set.weightKg, set.reps, units))"
            case .mostReps: return "Most reps \(set.reps ?? 0)"
            default: return NoopExerciseFormat.title(kind)
            }
        }
        let item = NoopLiftCelebration(exercise: line.exercise, lines: shown, symbol: NoopExerciseFormat.symbol(first),
                                       more: max(0, kinds.count - 2))
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { celebration = item }
        Task {
            try? await Task.sleep(nanoseconds: 3_400_000_000)
            if celebration?.id == item.id { withAnimation(NoopMotion.swap) { celebration = nil } }
        }
    }

    private func loadLastSessionValues() async {
        guard let engine = live.engine, let store = await repo.storeHandle() else { return }
        var result: [String: [Int: LiftSetCarry]] = [:]
        for name in NSOrderedSet(array: engine.plan.map(\.exercise)).compactMap({ $0 as? String }) {
            let rows = (try? await store.lastLiftSets(deviceId: repo.deviceId, exercise: name, before: engine.startTs)) ?? []
            result[name] = Dictionary(uniqueKeysWithValues: rows.filter { !$0.isWarmup }.map {
                ($0.setIndex, LiftSetCarry(weightKg: $0.weightKg, reps: $0.reps))
            })
        }
        live.setLastSession(result)
        lastTime = result
    }

    private func syncFields() {
        guard let slot else { loadText = ""; repsText = ""; return }
        let entered = live.enteredValues(for: slot)
        let shown = live.values(of: slot)
        let kg = entered.weightKg ?? shown.weightKg
        let reps = entered.reps ?? shown.reps
        loadText = kg.map { LiftFormat.trim(LiftFormat.display(fromKilograms: $0, system: units)) } ?? ""
        repsText = reps.map(String.init) ?? ""
    }

    private func writeFields(slot: LiftSlot) {
        let displayWeight = Double(loadText.replacingOccurrences(of: ",", with: "."))
        let kg = displayWeight.map { LiftFormat.kilograms(fromDisplay: $0, system: units) }
        live.updateSet(slot, weightKg: kg, reps: Int(repsText), rpe: nil, isWarmup: live.isWarmup(slot))
    }

    private func nudge(isWeight: Bool, amount: Int, slot: LiftSlot) {
        if isWeight {
            let current = Double(loadText.replacingOccurrences(of: ",", with: ".")) ?? 0
            loadText = LiftFormat.trim(max(0, current + Double(amount) * (units == .metric ? 2.5 : 5)))
        } else {
            repsText = String(max(0, (Int(repsText) ?? 0) + amount))
        }
        writeFields(slot: slot)
    }

    private func finish(includeShownValues: Bool) async {
        guard !saving, live.engine != nil else { return }
        saving = true
        defer { saving = false }
        if let slot { writeFields(slot: slot) }
        // The last rest ends here; without this its measured duration never reached the record.
        live.closeRunningRest()
        guard let engine = live.engine else { return }
        // A retry after a partial write must address the same natural session and replace the same
        // set list, not mint a second collection of sets under a new random session id.
        let sessionID = "manual-lift-\(repo.deviceId)-\(engine.startTs)"
        let finished: [LiftSessionController.FinishedSet]
        if includeShownValues {
            finished = engine.sets.map { set in
                let shown = live.values(of: set.slot)
                return .init(slot: set.slot, weightKg: shown.weightKg, reps: shown.reps,
                             rpe: set.rpe, isWarmup: set.isWarmup, startTs: set.startTs,
                             endTs: set.endTs, restSec: set.restSec,
                             kind: set.isWarmup ? nil : live.kind(of: set.slot))
            }
        } else {
            finished = live.setsToSave(completingUnfinished: false)
        }
        guard !finished.isEmpty else {
            live.discard()
            navigation.replace(with: .liftLibrary)
            return
        }
        // Finish freezes the clock before the disk work. If a write fails, the same session stays
        // paused on disk and can be retried without charging the failed-save wait as exercise time.
        if !live.isPaused { live.togglePause() }
        let end = live.now
        let activeDuration = live.sessionElapsedSeconds
        guard live.beginSaving() else { return }
        var saved = false
        defer { if !saved { live.saveFailed() } }
        guard let store = await repo.storeHandle() else {
            saveError = "The record is unavailable. Your session and its sets are still here. Try saving again."
            return
        }
        let sessionRow = LiftSessionRow(
            id: sessionID, deviceId: repo.deviceId, startTs: engine.startTs, endTs: end,
            sport: LiftingImporter.sport, programId: live.programId,
            programName: live.programName, sessionRpe: sessionRpe, note: live.programName
        )
        let rows = finished.enumerated().map { ord, value -> LiftSetRow in
            let line = engine.planItem(for: value.slot)
            return LiftSetRow(
                id: "\(sessionID)-set-\(ord)", deviceId: repo.deviceId, sessionId: sessionID,
                ord: ord, exercise: line?.exercise ?? "", primaryMuscle: line?.primaryMuscle,
                secondaryMuscles: line?.secondaryMuscles ?? [], setIndex: value.slot.setIndex,
                weightKg: value.weightKg, reps: value.reps, rpe: value.rpe,
                isWarmup: value.isWarmup, startTs: value.startTs, endTs: value.endTs,
                restSec: value.restSec, note: nil, setKind: value.kind
            )
        }
        let workout = WorkoutRow(
            startTs: engine.startTs, endTs: end, sport: LiftingImporter.sport, source: "manual",
            durationS: Double(activeDuration), energyKcal: nil, avgHr: nil,
            maxHr: nil, strain: nil, distanceM: nil, zonesJSON: nil,
            notes: live.programName, steps: nil
        )
        do {
            _ = try await store.upsertLiftSessions([sessionRow])
            // Replace in one transaction so a retried save cannot duplicate sets from an earlier
            // partial attempt. The in-flight controller remains intact until all writes succeed.
            _ = try await store.replaceLiftSessionSets(sessionId: sessionID, rows: rows)
            _ = try await store.upsertWorkouts([workout], deviceId: repo.deviceId)
            NoopFitnessModel.markChanged()
        } catch {
            saveError = "The session could not be written. Your session and its sets are still here. Try saving again."
            return
        }
        saved = true
        navigation.recordFinishedLift(sessionID: sessionID, title: live.programName,
                                      durationSeconds: activeDuration,
                                      at: Date(timeIntervalSince1970: TimeInterval(end)))
        live.finishedSaving()
        await repo.refresh()
        await flow.refresh(repo: repo)
        flow.selectedSession = sessionRow
        flow.sessionSets = rows
        navigation.selectedLiftSessionID = sessionID
        navigation.justFinishedLiftID = sessionID
        navigation.liftDetailReturnRoute = .fitness
        navigation.land(on: .liftDetail, over: .fitness)
    }

    private func setLine(_ slot: LiftSlot) -> String {
        let values = live.values(of: slot)
        switch (liftWeight(values.weightKg, system: units), values.reps) {
        case let (weight?, reps?): return "\(weight) × \(reps)"
        case let (weight?, nil): return weight
        case let (nil, reps?): return "\(reps) reps"
        default: return slot == self.slot ? "logging" : "—"
        }
    }


    private func targetSummary(_ item: LiftPlanItem) -> String {
        guard item.targetWeightKg != nil || item.targetRepsLow != nil else { return "no targets" }
        var pieces: [String] = []
        if let reps = item.targetRepsLow { pieces.append("\(item.targetSets) × \(reps)") }
        if let weight = liftWeight(item.targetWeightKg, system: units) { pieces.append(weight) }
        return pieces.joined(separator: " · ")
    }

}

/// A record a set just broke, as the live screen announces it.
struct NoopLiftCelebration: Equatable {
    let id = UUID()
    let exercise: String
    let lines: [String]
    let symbol: String
    let more: Int
}

/// The banner that drops in when a set breaks a record, and leaves on its own.
private struct NoopLiftRecordBanner: View {
    let celebration: NoopLiftCelebration
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill").font(.system(size: 17, weight: .semibold))
                .foregroundStyle(NoopHTMLColor.voltInk)
                .frame(width: 40, height: 40).background(NoopHTMLColor.volt, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("New record · \(celebration.exercise)")
                    .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                    .lineLimit(1)
                Text(celebration.lines.joined(separator: " · ") + (celebration.more > 0 ? " · +\(celebration.more)" : ""))
                    .font(NoopHTMLFont.sans(NoopType.caption)).monospacedDigit().foregroundStyle(NoopHTMLColor.volt)
                    .lineLimit(1).minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 10).padding(.trailing, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(NoopHTMLColor.cardRaised.opacity(0.9), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(NoopHTMLColor.volt.opacity(0.35), lineWidth: 0.8))
        .shadow(color: NoopHTMLColor.volt.opacity(0.18), radius: 18, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

/// What kind of set a row is, as the live sheet and the session detail show it.
private enum NoopLiftSetType: CaseIterable, Hashable {
    case working, warmup, drop, failure

    init(warmup: Bool, kind: LiftSetKind?) {
        if warmup { self = .warmup; return }
        switch kind {
        case .drop: self = .drop
        case .failure: self = .failure
        case nil: self = .working
        }
    }

    var title: String {
        switch self {
        case .working: "Working"
        case .warmup: "Warm-up"
        case .drop: "Drop set"
        case .failure: "Failure"
        }
    }

    var symbol: String {
        switch self {
        case .working: "number"
        case .warmup: "flame"
        case .drop: "arrow.down.right"
        case .failure: "bolt"
        }
    }

    /// The letter in place of the set number. A working set shows its number.
    var letter: String? {
        switch self {
        case .working: nil
        case .warmup: "W"
        case .drop: "D"
        case .failure: "F"
        }
    }

    var tint: Color? {
        switch self {
        case .working: nil
        case .warmup: NoopHTMLColor.warm
        case .drop: NoopHTMLColor.nightLight
        case .failure: NoopHTMLColor.red
        }
    }
}

// MARK: - lift-program

// MARK: - lift-detail

struct NoopLiftDetailScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var flow: NoopLiftFlowModel
    /// Opened over Fitness as a sheet (23 Oct 2026), like every other session, instead of as a page.
    var asSheet = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var repo: Repository
    @AppStorage(UnitPrefs.systemKey) private var unitSystemRaw = UnitSystem.metric.rawValue

    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }
    private var record: LiftSessionRow? {
        flow.selectedSession ?? (nil)
    }
    private var sets: [LiftSetRow] {
        flow.sessionSets
    }
    private var working: [LiftSetRow] { sets.filter { !$0.isWarmup } }
    private var volume: Double { working.compactMap(\.volumeKg).reduce(0, +) }
    private var heaviest: LiftSetRow? { working.filter { $0.weightKg != nil }.max { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) } }

    @State private var records: [NoopLiftRecord] = []
    /// Opened straight after saving: the hero's ring closes once.
    @State private var celebrating = false
    @State private var rating = false
    @State private var newRpe = 6.0
    @State private var insightsFor: NoopFitnessExerciseChoice?

    @State private var matched: WorkoutRow?
    @State private var confirmDelete = false

    var body: some View {
        Group {
            if asSheet {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        NoopSheetHeader(title: "Workout") { dismiss() }
                        content
                    }
                    .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 28)
                }
            } else {
                NoopScreen(topInset: 56) {
                    VStack(alignment: .leading, spacing: 14) {
                        NoopLiftBackHeader(label: navigation.liftDetailReturnRoute == .history ? "Everything you logged" : navigation.liftDetailReturnRoute.screenTitle) {
                            navigation.back(or: navigation.liftDetailReturnRoute)
                        }
                        content
                    }
                }
            }
        }
        .task { await load(); await loadMatched() }
        .sheet(item: $insightsFor) { choice in
            NoopFitnessExerciseDetail(choice: choice, initialTab: .records).noopSheet()
        }
        .sheet(isPresented: $rating) {
            NoopLiftEffortSheet(rating: $newRpe) {
                rating = false
                Task { await saveRpe() }
            }
            .noopSheet()
        }
        .confirmationDialog("Delete this session?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await deleteSession() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This removes it and every set in it from your record.") }
    }

    /// The lift, its sets and the workout row it saved, so Fitness and Effort stop counting it.
    private func deleteSession() async {
        guard let record, true, let store = await repo.storeHandle() else { return }
        _ = try? await store.deleteLiftSession(id: record.id)
        if let matched {
            if WorkoutSource.classify(matched.source) == .lifting {
                // An imported lift's summary row lives in the import namespace, which deleteWorkout leaves alone.
                _ = try? await store.deleteWorkouts(deviceId: LiftingImporter.sourceId, sport: matched.sport,
                                                    from: matched.startTs, to: matched.startTs)
            } else {
                await repo.deleteWorkout(matched)
            }
        }
        flow.selectedSession = nil
        NoopFitnessModel.markChanged()
        await repo.refresh()
        if asSheet { dismiss() } else { navigation.back(or: navigation.liftDetailReturnRoute) }
    }

    /// Leaves the sheet first when there is one, so the next screen opens on the page underneath.
    private func open(_ route: NoopRoute) {
        guard asSheet else { navigation.push(route); return }
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { navigation.push(route) }
    }

    /// The card "Share" sends: the lift's time, sets, volume and records.
    private func shareContent(_ record: LiftSessionRow) -> NoopShareContent {
        let minutes = max(1, ((record.endTs ?? record.startTs) - record.startTs) / 60)
        var figures: [(value: String, label: String)] = [
            (minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes) min", "time"),
            ("\(working.count)", working.count == 1 ? "set" : "sets"),
        ]
        if volume > 0 {
            figures.append((LiftFormat.trim((LiftFormat.display(fromKilograms: volume, system: units)).rounded()),
                            "\(LiftFormat.weightUnit(units)) lifted"))
        }
        if !records.isEmpty { figures.append(("\(records.count)", records.count == 1 ? "record" : "records")) }
        return NoopShareContent(symbol: "figure.strengthtraining.traditional", tint: NoopHTMLColor.volt,
                                ink: NoopHTMLColor.voltInk, kind: "Strength training",
                                title: record.programName ?? "A lift", when: detailSubtitle(record), figures: figures)
    }

    private var content: some View {
            VStack(alignment: .leading, spacing: 14) {
                if let record {
                    NoopSessionHero(symbol: "figure.strengthtraining.traditional", kind: "Strength training",
                                    title: record.programName ?? "A lift", when: detailSubtitle(record),
                                    source: "Noop Aura · recorded live",
                                    celebrate: celebrating, share: shareContent(record))
                        .onAppear {
                            if navigation.justFinishedLiftID == record.id {
                                celebrating = true
                                navigation.justFinishedLiftID = nil
                            }
                        }
                    if !records.isEmpty { recordsStrip }
                    NoopSessionHeading(title: "Workout details")
                    if let strain = matched?.strain, strain > 0 {
                        let e = NoopSessionEffort.describe(strain)
                        NoopSessionRingRow(value: e.value, fraction: e.fraction, title: "Effort", line: e.line)
                    }
                    statsGrid(record)
                    NoopSessionHeading(title: "Perceived effort")
                    effortCard(record)
                    if !muscleShares.isEmpty {
                        NoopSessionHeading(title: "Muscles")
                        musclesCard
                    }
                    NoopSessionHeading(title: "Exercises", subtitle: exercisesLine)
                    exerciseTables
                    if let end = record.endTs {
                        NoopSessionHeart(start: record.startTs, end: end, source: matched?.source ?? "")
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        NoopSectionLabel("Where these exercises come from")
                        Text("Exercise data: ExerciseDB v1 via hasaneyldrm/exercises-dataset, MIT licence. Exercise animations, when turned on, © Gym visual.")
                            .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.copy)
                            .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 2).padding(.top, 10)
                } else {
                    NoopLiftTitle(title: "No session selected",
                                  subtitle: "Open a lifting session from your history to see what was recorded.")
                    NoopLiftActionButton(title: "Open programs") { navigation.replace(with: .liftLibrary) }
                }
            }
    }

    private var exercisesLine: String {
        let n = Set(working.map(\.exercise)).count
        return "\(n) \(n == 1 ? "exercise" : "exercises"), \(working.count) \(working.count == 1 ? "set" : "sets")"
    }

    /// The workout row this lift saved, for the strap's effort, heart rate and energy over the session.
    private func loadMatched() async {
        guard let record else { matched = nil; return }
        matched = (await repo.workoutRows(days: 400))
            .filter { abs($0.startTs - record.startTs) <= 180 }
            .min { abs($0.startTs - record.startTs) < abs($1.startTs - record.startTs) }
    }

    // MARK: Records

    private var recordsStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            NoopSectionLabel(records.count == 1 ? "A personal record" : "\(records.count) personal records")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(records) { r in
                        VStack(alignment: .leading, spacing: 6) {
                            Image(systemName: r.symbol).font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(r.tint)
                                .frame(width: 30, height: 30).background(r.tint.opacity(0.15), in: Circle())
                            Text(r.exercise).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy).lineLimit(1)
                            Text(r.title).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                                .lineLimit(1)
                            Text(r.detail).font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(r.tint).lineLimit(1)
                        }
                        .padding(14).frame(width: 168, alignment: .leading)
                        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(r.tint.opacity(0.25), lineWidth: 0.6))
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
    }

    // MARK: Stats

    private func statsGrid(_ record: LiftSessionRow) -> some View {
        let total = record.endTs.map { $0 - record.startTs }
        let active = working.compactMap { s in s.startTs.flatMap { a in s.endTs.map { $0 - a } } }.filter { $0 > 0 }.reduce(0, +)
        let reps = working.compactMap(\.reps).reduce(0, +)
        var items: [NoopSessionFigures.Item] = []
        if active > 0 { items.append(.init(label: "Active duration", value: liftClock(active))) }
        items.append(.init(label: "Total duration", value: total.map { liftClock($0) } ?? "—"))
        items.append(.init(label: "Total reps", value: reps > 0 ? "\(reps)" : "—"))
        items.append(.init(label: "Total weight", value: volume > 0 ? groupedWeight(volume) : "—",
                           unit: volume > 0 ? LiftFormat.weightUnit(units) : nil))
        if let hr = matched?.avgHr { items.append(.init(label: "Avg HR", value: "\(hr)", unit: "bpm")) }
        if let kcal = matched?.energyKcal, kcal > 0 { items.append(.init(label: "Energy", value: "\(Int(kcal.rounded()))", unit: "kcal")) }
        if let h = heaviest, let w = liftWeight(h.weightKg, system: units) {
            items.append(.init(label: "Heaviest set", value: h.reps.map { "\(w) × \($0)" } ?? w))
        }
        return NoopSessionFigures(items: items)
    }

    // MARK: Effort

    private func effortCard(_ record: LiftSessionRow) -> some View {
        Button {
            newRpe = record.sessionRpe ?? 6
            rating = true
        } label: {
            let rpe = record.sessionRpe
            NoopSessionRingRow(value: rpe.map { "\(Int($0.rounded()))" } ?? "–", fraction: (rpe ?? 0) / 10,
                               title: rpe.map { NoopLiftEffortSheet.word(Int($0.rounded())) } ?? "How hard was it?",
                               line: rpe == nil ? "Not rated yet. Tap to rate it from 1 to 10." : "Your rating, out of 10. Tap to change it.",
                               colors: [NoopHTMLColor.blueLight, Color(hex: 0xF2B45C), effortColor(rpe ?? 0)],
                               chevron: true)
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private func effortColor(_ v: Double) -> Color {
        v < 4 ? NoopHTMLColor.blueLight : v < 7 ? NoopHTMLColor.warm : v < 9 ? NoopHTMLColor.amber : NoopHTMLColor.red
    }

    private func saveRpe() async {
        guard var row = flow.selectedSession, let store = await repo.storeHandle() else { return }
        row.sessionRpe = newRpe.rounded()
        if (try? await store.upsertLiftSessions([row])) != nil { flow.selectedSession = row; NoopFitnessModel.markChanged() }
    }

    // MARK: Muscles

    /// Each working set counts in full for its main muscle and half for each helper.
    private var muscleShares: [(muscle: LiftMuscle, share: Double)] {
        var credit: [LiftMuscle: Double] = [:]
        for s in working {
            if let p = s.primaryMuscle { credit[p, default: 0] += 1 }
            for m in s.secondaryMuscles where m != s.primaryMuscle { credit[m, default: 0] += 0.5 }
        }
        let total = credit.values.reduce(0, +)
        guard total > 0 else { return [] }
        return credit.map { ($0.key, $0.value / total) }.sorted { $0.share > $1.share }
    }

    private var musclesCard: some View {
        NoopSessionMuscles(shares: Array(muscleShares.prefix(6))) {
            Button { open(.liftMuscles) } label: {
                HStack(spacing: 6) {
                    Text("How sets are credited").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(NoopHTMLColor.copy).frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(NoopPlainHitStyle())
        }
    }

    // MARK: Exercises

    private var exerciseTables: some View {
        let order = NSOrderedSet(array: sets.map(\.exercise)).array.compactMap { $0 as? String }
        let prSets = Set(records.compactMap(\.setID))
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(order, id: \.self) { exercise in
                let rows = sets.filter { $0.exercise == exercise }
                let choice = NoopFitnessExerciseChoice.lookup(exercise)
                NoopSessionCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            insightsFor = .named(exercise, primary: rows.first?.primaryMuscle, secondaries: rows.first?.secondaryMuscles ?? [])
                        } label: {
                        HStack(spacing: 13) {
                            if let choice {
                                NoopExerciseMedia(choice: choice, thumbnail: true, tile: 60)
                            } else {
                                NoopCanonicalGlyph(name: .weight, size: 20, color: NoopHTMLColor.volt)
                                    .frame(width: 60, height: 60)
                                    .background(NoopHTMLColor.volt.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(exercise).font(NoopHTMLFont.sans(NoopType.body, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                                let n = rows.filter { !$0.isWarmup }.count
                                Text([choice?.equipment?.split(separator: ",").first.map { String($0).capitalized },
                                      "\(n) \(n == 1 ? "set" : "sets")"].compactMap { $0 }.joined(separator: " · "))
                                    .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.chevronDim)
                        }
                        .contentShape(Rectangle())
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                        .accessibilityHint("Opens this exercise's records and history")
                        HStack(spacing: 8) {
                            Text("SET").frame(width: 36)
                            Text(LiftFormat.weightUnit(units).uppercased()).frame(maxWidth: .infinity)
                            Text("REPS").frame(maxWidth: .infinity)
                            Text("REST").frame(maxWidth: .infinity)
                        }
                        .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).tracking(0.8).foregroundStyle(NoopHTMLColor.muted)
                        .padding(.top, 4)
                        ForEach(rows, id: \.id) { row in
                            HStack(spacing: 8) {
                                let type = NoopLiftSetType(warmup: row.isWarmup, kind: row.setKind)
                                Text(type.letter ?? "\(rows.prefix { $0.id != row.id }.filter { !$0.isWarmup }.count + 1)")
                                    .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                                    .foregroundStyle(type.tint ?? NoopHTMLColor.ink)
                                    .frame(width: 36, height: 36).background((type.tint ?? .white).opacity(type.tint == nil ? 0.06 : 0.14), in: Circle())
                                    .accessibilityLabel("\(type.title) set")
                                pill(row.weightKg.map { LiftFormat.trim(LiftFormat.display(fromKilograms: $0, system: units)) } ?? "—")
                                pill(row.reps.map { "\($0) reps" } ?? "—", trophy: prSets.contains(row.id))
                                pill(row.restSec.map { liftClock($0) } ?? "—", dim: true)
                            }
                            .opacity(row.isWarmup ? 0.75 : 1)
                        }
                    }
                }
            }
            Button { open(.liftEdit) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pencil").font(.system(size: 13, weight: .semibold))
                    Text("Correct something in this session").font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                }
                .foregroundStyle(NoopHTMLColor.ink)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.white.opacity(0.07), in: Capsule())
            }
            .buttonStyle(NoopHTMLPressStyle())
            .padding(.top, 4)
            Button(role: .destructive) { confirmDelete = true } label: {
                Text("Delete session").font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 46)
            }
            .foregroundStyle(NoopHTMLColor.red)
            .buttonStyle(NoopPlainHitStyle())
        }
    }

    private func pill(_ text: String, trophy: Bool = false, dim: Bool = false) -> some View {
        HStack(spacing: 5) {
            Text(text)
            if trophy { Image(systemName: "trophy.fill").font(.system(size: 10)).foregroundStyle(NoopHTMLColor.volt) }
        }
        .font(NoopHTMLFont.sans(NoopType.subhead, weight: .medium)).monospacedDigit()
        .foregroundStyle(dim ? NoopHTMLColor.inkSoft : NoopHTMLColor.ink)
        .frame(maxWidth: .infinity, minHeight: 40)
        .background(trophy ? NoopHTMLColor.volt.opacity(0.10) : Color.white.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Bests from every earlier session of each exercise in this one, so a record says what it beat.
    private func loadRecords() async {
        guard let record, !working.isEmpty, let store = await repo.storeHandle() else { records = []; return }
        let earlier = (try? await store.liftSessions(deviceId: repo.deviceId, fromTs: 0, toTs: record.startTs - 1)) ?? []
        var past: [LiftSetRow] = []
        for s in earlier where s.id != record.id {
            past += ((try? await store.liftSets(sessionId: s.id)) ?? []).filter { !$0.isWarmup }
        }
        records = NoopLiftRecord.find(now: working, past: past, units: units)
    }

    private func load() async {
        if let startTs = navigation.liftDetailStartTs {
            navigation.liftDetailStartTs = nil
            await flow.refresh(repo: repo)
            navigation.selectedLiftSessionID = flow.sessions.first { $0.startTs == startTs }?.id
            await flow.loadSession(id: navigation.selectedLiftSessionID, repo: repo)
            await loadRecords()
            return
        }
        if let shown = flow.selectedSession, !flow.sessionSets.isEmpty,
           navigation.selectedLiftSessionID == nil || shown.id == navigation.selectedLiftSessionID {
            await loadRecords()
            return
        }
        await flow.refresh(repo: repo)
        let id = navigation.selectedLiftSessionID ?? flow.sessions.first?.id
        navigation.selectedLiftSessionID = id
        await flow.loadSession(id: id, repo: repo)
        await loadRecords()
    }

    private func detailSubtitle(_ row: LiftSessionRow) -> String {
        let start = Date(timeIntervalSince1970: TimeInterval(row.startTs))
        let minutes = row.endTs.map { max(1, ($0 - row.startTs) / 60) }
        let end = row.endTs.map { Date(timeIntervalSince1970: TimeInterval($0)).noopLiftTime }
        _ = minutes
        return "\(start.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))), \(start.noopLiftTime)" + (end.map { " – \($0)" } ?? "")
    }

    private func groupedWeight(_ kg: Double) -> String {
        let display = LiftFormat.display(fromKilograms: kg, system: units)
        // Whole numbers once volume is in the hundreds; below that a 2.5 kg set must not read as 2.
        return display.formatted(.number.precision(.fractionLength(display < 100 ? 0...1 : 0...0)).grouping(.automatic))
    }

    private func exerciseMeta(_ exercise: String, rows: [LiftSetRow]) -> String {
        return "\(rows.count) working \(rows.count == 1 ? "set" : "sets")"
    }

}

// MARK: - lift-edit

private struct NoopLiftEditScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var flow: NoopLiftFlowModel
    @EnvironmentObject private var repo: Repository
    @AppStorage(UnitPrefs.systemKey) private var unitSystemRaw = UnitSystem.metric.rawValue
    @State private var rows: [LiftSetRow] = []
    @State private var deleted: Set<String> = []
    @State private var saving = false
    @State private var saved = false
    @State private var saveError: String?

    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }
    private var kept: [LiftSetRow] { rows.filter { !deleted.contains($0.id) } }
    private var working: [LiftSetRow] { kept.filter { !$0.isWarmup } }
    private var volume: Double { working.compactMap(\.volumeKg).reduce(0, +) }
    private var selectedExercise: String { rows.first?.exercise ?? "Recorded sets" }
    /// Every exercise in the session, in the order it was done, each corrected in its own card.
    private var exercises: [String] {
        var seen: [String] = []
        for row in rows where !row.isWarmup && !seen.contains(row.exercise) { seen.append(row.exercise) }
        return seen.isEmpty ? [selectedExercise] : seen
    }
    private func displayIndices(_ exercise: String) -> [Int] {
        rows.indices.filter { rows[$0].exercise == exercise && !rows[$0].isWarmup }
    }

    var body: some View {
        NoopScreen(bottomInset: 40, topInset: 58) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Button("Cancel") { navigation.back(or: .liftDetail) }
                        .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.blueLight)
                        .buttonStyle(NoopPlainHitStyle()).frame(minHeight: 36)
                    Spacer()
                    NoopSectionLabel("Correcting")
                    Spacer()
                    Button(saving ? "Saving…" : "Save") { Task { await save() } }
                        .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(NoopHTMLColor.blueLight)
                        .buttonStyle(NoopPlainHitStyle()).disabled(saving)
                }
                NoopLiftTitle(title: editTitle,
                              subtitle: "Change what you logged. What the strap measured during the session — your pulse, the minutes, the cost — is not touched by anything here.")

                if saved {
                    HStack(spacing: 11) {
                        NoopCanonicalGlyph(name: .check, size: 19, color: Color(hex: 0x6FBF7F))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Saved").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(Color(hex: 0xA8E0B0))
                            Text("\(working.count) working sets, \(groupedWeight(volume)). The session’s figures are recomputed from what is here now.")
                                .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.inkSoft)
                        }
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: 0x6FBF7F).opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color(hex: 0x6FBF7F).opacity(0.22), lineWidth: 0.5))
                }

                ForEach(exercises, id: \.self) { exercise in
                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        NoopSectionLabel(exercise)
                        Spacer()
                        Text(totalText(exercise))
                            .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(NoopHTMLColor.blueLight)
                            .monospacedDigit()
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(displayIndices(exercise).enumerated()), id: \.element) { position, index in
                            editRow(index, number: position + 1, first: position == 0)
                        }
                    }
                    Button { addSet(to: exercise) } label: {
                        HStack(spacing: 9) {
                            NoopCanonicalGlyph(name: .plus, size: 16, color: NoopHTMLColor.blueLight)
                            Text("Add a set you forgot")
                                .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.blueLight)
                            Spacer()
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(NoopPlainHitStyle())
                    .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5) }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
                }

                Text("A corrected session is the session. Noop keeps one record and this screen edits it — there is no second, truer copy kept somewhere you cannot see.")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                    .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }
        }
        .task { await load() }
        .alert("Correction not saved", isPresented: Binding(
            get: { saveError != nil }, set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "Your original session is still on this phone. Try saving again.")
        }
    }

    /// `number` is the set's place in its exercise, as the session summary numbers it.
    private func editRow(_ index: Int, number: Int, first: Bool) -> some View {
        let isDeleted = deleted.contains(rows[index].id)
        return HStack(spacing: 10) {
            Text("\(number)")
                .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                .frame(width: 20, alignment: .leading)
            HStack(spacing: 7) {
                TextField("—", text: weightBinding(index))
                    .keyboardType(.decimalPad).multilineTextAlignment(.center)
                    .font(NoopHTMLFont.sans(NoopType.subhead, weight: .medium)).foregroundStyle(isDeleted ? NoopHTMLColor.copy : NoopHTMLColor.ink)
                    .frame(width: 76, height: 36)
                    .background(isDeleted ? Color.clear : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(isDeleted ? Color.clear : Color.white.opacity(0.12), lineWidth: 0.5))
                    .strikethrough(isDeleted)
                    .disabled(isDeleted)
                Text("×").font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                TextField("—", text: repsBinding(index))
                    .keyboardType(.numberPad).multilineTextAlignment(.center)
                    .font(NoopHTMLFont.sans(NoopType.subhead, weight: .medium)).foregroundStyle(isDeleted ? NoopHTMLColor.copy : NoopHTMLColor.ink)
                    .frame(width: 48, height: 36)
                    .background(isDeleted ? Color.clear : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(isDeleted ? Color.clear : Color.white.opacity(0.12), lineWidth: 0.5))
                    .strikethrough(isDeleted)
                    .disabled(isDeleted)
                if isDeleted {
                    Text("deleted")
                        .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).foregroundStyle(NoopHTMLColor.copy)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            Spacer(minLength: 4)
            Button {
                if isDeleted { deleted.remove(rows[index].id) } else { deleted.insert(rows[index].id) }
            } label: {
                if isDeleted {
                    Text("Undo").font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(NoopHTMLColor.blueLight)
                } else {
                    NoopCanonicalGlyph(name: .trash, size: 17, color: NoopHTMLColor.copy.opacity(0.82))
                }
            }
            .buttonStyle(NoopPlainHitStyle()).frame(minWidth: 44, minHeight: 44)
        }
        .frame(minHeight: 48).opacity(isDeleted ? 0.5 : 1)
        .overlay(alignment: .top) {
            if !first { Rectangle().fill(Color.white.opacity(0.055)).frame(height: 0.5) }
        }
    }

    /// One exercise's working sets and what they moved, so a card counts only its own rows.
    private func totalText(_ exercise: String) -> String {
        let all = rows.filter { !$0.isWarmup && $0.exercise == exercise }
        let mine = working.filter { $0.exercise == exercise }
        let moved = mine.compactMap(\.volumeKg).reduce(0, +)
        let noun = mine.count == 1 ? "working set" : "working sets"
        let suffix = moved > 0 ? "\(mine.count) \(noun) · \(groupedWeight(moved))" : "\(mine.count) \(noun)"
        return all.count == mine.count ? suffix : "\(all.count) → \(suffix)"
    }

    private var editTitle: String {
        let record = flow.selectedSession
        let name = record?.programName ?? "A lift"
        let day = record.map { Date(timeIntervalSince1970: TimeInterval($0.startTs)).formatted(.dateTime.weekday(.wide)) }
        return day.map { "\(name), \($0)" } ?? name
    }

    private func load() async {
        if flow.sessionSets.isEmpty {
            await flow.loadSession(id: navigation.selectedLiftSessionID, repo: repo)
        }
        rows = flow.sessionSets
        deleted = flow.deletedSetIDs
        if false, deleted.isEmpty,
           let fourth = rows.filter({ $0.exercise == selectedExercise && !$0.isWarmup }).dropFirst(3).first {
            deleted.insert(fourth.id)
        }
    }

    private func addSet(to exercise: String) {
        guard let source = kept.last(where: { $0.exercise == exercise })
                ?? rows.last(where: { $0.exercise == exercise }),
              let session = flow.selectedSession ?? recordFallback else { return }
        let next = (rows.filter { $0.exercise == source.exercise }.map(\.setIndex).max() ?? 0) + 1
        rows.append(LiftSetRow(id: UUID().uuidString, deviceId: repo.deviceId, sessionId: session.id,
                               ord: rows.count, exercise: source.exercise,
                               primaryMuscle: source.primaryMuscle, secondaryMuscles: source.secondaryMuscles,
                               setIndex: next, weightKg: nil, reps: nil, rpe: nil,
                               isWarmup: false, startTs: nil, endTs: nil, restSec: nil, note: nil))
    }

    private var recordFallback: LiftSessionRow? {
        nil
    }

    private func save() async {
        guard !saving else { return }
        guard let store = await repo.storeHandle(),
              let sessionID = flow.selectedSession?.id ?? navigation.selectedLiftSessionID else {
            saveError = "The session could not be opened. Nothing was changed."
            return
        }
        saving = true
        defer { saving = false }
        let survivors = rows.filter { !deleted.contains($0.id) }.enumerated().map { ord, source -> LiftSetRow in
            var row = source; row.ord = ord; return row
        }
        do {
            try await store.replaceLiftSessionSets(sessionId: sessionID, rows: survivors)
            NoopFitnessModel.markChanged()
        } catch {
            saveError = "The corrected sets could not be written. Your original session is unchanged."
            return
        }
        flow.sessionSets = survivors; flow.deletedSetIDs = []; flow.editSaved = true
        await repo.refresh()
        withAnimation(NoopMotion.swap) { saved = true }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        navigation.back(or: .liftDetail)
    }

    private func weightBinding(_ index: Int) -> Binding<String> {
        Binding(get: {
            guard rows.indices.contains(index), let kg = rows[index].weightKg else { return "" }
            return LiftFormat.trim(LiftFormat.display(fromKilograms: kg, system: units))
        }, set: {
            guard rows.indices.contains(index) else { return }
            rows[index].weightKg = Double($0.replacingOccurrences(of: ",", with: "."))
                .map { LiftFormat.kilograms(fromDisplay: $0, system: units) }
        })
    }
    private func repsBinding(_ index: Int) -> Binding<String> {
        Binding(get: { rows.indices.contains(index) ? rows[index].reps.map(String.init) ?? "" : "" },
                set: { if rows.indices.contains(index) { rows[index].reps = Int($0) } })
    }
    private func groupedWeight(_ kg: Double) -> String {
        guard kg > 0 else { return "no volume" }
        let shown = LiftFormat.display(fromKilograms: kg, system: units)
        return "\(shown.formatted(.number.precision(.fractionLength(0)).grouping(.automatic))) \(LiftFormat.weightUnit(units))"
    }
}

// MARK: - lift-import

private struct NoopLiftImportScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var flow: NoopLiftFlowModel
    @State private var choosingFile = false
    @State private var showKey = false
    @State private var showHevy = false
    @State private var keyDraft = ""
    @State private var keySuffix: String?
    @State private var keyMessage: String?

    var body: some View {
        NoopScreen(bottomInset: 40, topInset: 58) {
            VStack(alignment: .leading, spacing: 14) {
                NoopLiftSheetHeader(label: "Programs", trailing: nil) { navigation.back(or: .liftLibrary) }
                NoopLiftTitle(title: "Bring your lifting across",
                              subtitle: "Import adds sessions. Nothing you already have is changed, replaced or removed, and running it twice does not double anything.")

                VStack(spacing: 9) {
                    importDoor(icon: .file, title: "Choose a file", meta: "the CSV Hevy exports",
                               note: "Everything in the export: sessions, exercises and the sets it contains.") {
                        choosingFile = true
                    }
                    importDoor(icon: .link, title: HevySync.shared.hasKey ? "Hevy · connected" : "Connect Hevy",
                               meta: "workouts, routines and body, kept in step",
                               note: "Every set of every workout, edits and deletions included. Your key stays in this phone’s Keychain.") {
                        showHevy = true
                    }
                }

                if showKey { keyCard }
                if flow.isReadingImport { readingCard }
                if let error = flow.importError { failureCard(error) }

                VStack(alignment: .leading, spacing: 9) {
                    NoopSectionLabel("Two things it does to your numbers")
                    Text("Hevy counts warm-ups in a set count. Noop does not: warm-up sets fold away and are left out of every figure a session states.")
                        .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.inkSoft).lineSpacing(4)
                    Text("Exercise names are matched to Noop’s own catalogue where they match, and kept exactly as the file wrote them where they do not. Nothing is renamed for you.")
                        .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.inkSoft).lineSpacing(4)
                }
                .padding(16).background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))

                Text("The file stays where it is. Noop reads it, writes its own rows only after review, and never modifies or deletes what you handed it.")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                    .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }
        }
        .onAppear { keySuffix = NoopHevyKeyStore.read().map { String($0.suffix(4)) } }
        .fileImporter(isPresented: $choosingFile,
                      allowedContentTypes: [.commaSeparatedText, .json, .plainText, .data],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    await flow.readImport(url: url)
                    if flow.importResult != nil { navigation.push(.liftReview) }
                }
            case .failure:
                flow.importError = "The file picker did not return a readable file. Nothing was added."
            }
        }
        .sheet(isPresented: $showHevy) { NoopHevyScreen() }
    }

    private func importDoor(icon: NoopCanonicalGlyphName, title: String, meta: String,
                            note: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 13) {
                    NoopCanonicalGlyph(name: icon, size: 21, color: NoopHTMLColor.blue)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                        Text(meta).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    NoopChevron()
                }
                Text(note).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                    .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16).padding(.vertical, 15)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private var keyCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                NoopSectionLabel(keySuffix == nil ? "Hevy key" : "Replace the Hevy key", color: NoopHTMLColor.blueLight)
                Spacer()
                if keySuffix != nil {
                    Button("Remove") {
                        NoopHevyKeyStore.clear(); keySuffix = nil; keyDraft = ""; keyMessage = "Removed from this phone."
                    }
                    .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(NoopHTMLColor.copy)
                    .buttonStyle(NoopPlainHitStyle())
                }
            }
            SecureField("Paste the read-only key", text: $keyDraft)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.ink)
                .padding(.horizontal, 13).frame(height: 46)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
            NoopLiftActionButton(title: keySuffix == nil ? "Keep this key" : "Replace key", disabled: keyDraft.isEmpty) {
                if NoopHevyKeyStore.save(keyDraft) {
                    keySuffix = String(keyDraft.suffix(4)); keyDraft = ""
                    keyMessage = "Stored in this phone’s Keychain."
                } else {
                    keyMessage = "The key could not be stored. Nothing changed."
                }
            }
            if let keyMessage {
                Text(keyMessage).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
            }
        }
        .padding(16).background(NoopHTMLColor.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(NoopHTMLColor.blue.opacity(0.24), lineWidth: 0.5))
    }

    private var readingCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack { NoopSectionLabel("Reading the file", color: NoopHTMLColor.blueLight); Spacer()
                Text("on this phone").font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy) }
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.07))
                    .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 3).fill(NoopHTMLColor.blue).frame(width: proxy.size.width * 0.72) }
            }.frame(height: 6)
            Text("Reading does not write anything. Nothing is added until you have seen what it found.")
                .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(3)
        }
        .padding(16).background(NoopHTMLColor.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(NoopHTMLColor.blue.opacity(0.24), lineWidth: 0.5))
    }

    private func failureCard(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The file stopped here").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
            failurePart("What happened", error)
            failurePart("Why it stopped", "Guessing which value is a weight or rep count would write numbers nobody measured.")
            failurePart("What you can do", "In Hevy, export your data and choose that CSV. A screenshot or workout summary cannot be read, and nothing was added.")
            HStack(spacing: 8) {
                NoopLiftActionButton(title: "Pick another file", accent: false) { choosingFile = true }
                NoopLiftActionButton(title: "Leave it", accent: false) { navigation.back(or: .liftLibrary) }
            }
        }
        .padding(16).background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private func failurePart(_ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(NoopHTMLColor.blueLight).frame(width: 7, height: 7).padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                NoopSectionLabel(title)
                Text(text).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.inkSoft)
                    .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - lift-review

private struct NoopLiftReviewScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var flow: NoopLiftFlowModel
    @EnvironmentObject private var repo: Repository
    @State private var committing = false


    private var result: LiftingImportResult? {
        if let result = flow.importResult { return result }
        return nil
    }

    var body: some View {
        NoopScreen(bottomInset: 40, topInset: 58) {
            VStack(alignment: .leading, spacing: 14) {
                NoopLiftSheetHeader(label: "Import", trailing: nil) { navigation.back(or: .liftImport) }
                if flow.importCommitted {
                    committed
                } else if let result, result.sessionCount > 0 {
                    NoopLiftTitle(title: "What the file contains",
                                  subtitle: "Nothing has been added yet. This is the complete summary the file reader can defend.")
                    summary(result)
                    newest(result)
                    if result.skipped > 0 { skipped(result) }
                    VStack(spacing: 4) {
                        NoopLiftActionButton(title: committing ? "Adding…" : "Add \(result.sessionCount) \(result.sessionCount == 1 ? "session" : "sessions")",
                                             disabled: committing) {
                            Task {
                                committing = true
                                _ = await flow.commitImport(repo: repo)
                            
                                committing = false
                            }
                        }
                        Button("Not now") { navigation.back(or: .liftLibrary) }
                            .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                            .buttonStyle(NoopPlainHitStyle()).frame(maxWidth: .infinity).frame(height: 46)
                    }
                    Text("Adding uses the dates in the file. Running the same import twice does not double a session already in your record.")
                        .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                        .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                } else {
                    nothingRead
                }
            }
        }
    }

    private func summary(_ result: LiftingImportResult) -> some View {
        VStack(spacing: 0) {
            summaryRow("Sessions read", sub: dateSpan(result), value: "\(result.sessionCount)", first: true)
            summaryRow("Exercises matched to the catalogue",
                       sub: "the current importer does not expose a defensible count",
                       value: "—")
            summaryRow("Names kept as the file wrote them",
                       sub: "no match count is available from this export summary",
                       value: "—")
            summaryRow("Warm-up sets folded away",
                       sub: "excluded by the parser; source count is not exposed",
                       value: "—")
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private func summaryRow(_ title: String, sub: String, value: String, first: Bool = false) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.ink)
                Text(sub).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text(value).font(NoopHTMLFont.outfit(NoopType.title3, weight: .regular)).foregroundStyle(NoopHTMLColor.blueLight)
        }
        .frame(minHeight: 52).padding(.vertical, 6)
        .overlay(alignment: .top) { if !first { Rectangle().fill(Color.white.opacity(0.055)).frame(height: 0.5) } }
    }

    private func newest(_ result: LiftingImportResult) -> some View {
        let recent = Array(result.sessions.suffix(5).reversed())
        return VStack(alignment: .leading, spacing: 10) {
            HStack { NoopSectionLabel("The newest of them"); Spacer()
                Text("from the file").font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82)) }
            ForEach(Array(recent.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 11) {
                    Text(item.start.noopLiftDay).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82)).frame(width: 52, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title?.isEmpty == false ? item.title! : "Untitled")
                            .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.ink)
                        Text("\(item.exerciseCount) exercise\(item.exerciseCount == 1 ? "" : "s") · \(item.setCount) working set\(item.setCount == 1 ? "" : "s")" + (item.durationS.map { " · \(Int($0 / 60)) min" } ?? ""))
                            .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                    }
                    Spacer()
                    Text("from the file")
                        .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).foregroundStyle(NoopHTMLColor.copy)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
                .padding(.vertical, 10)
                .overlay(alignment: .top) { if index > 0 { Rectangle().fill(Color.white.opacity(0.055)).frame(height: 0.5) } }
            }
            Text("There is nothing to tick here. Each session comes in whole, with every set the file lists, warm-ups marked as warm-ups.")
                .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private func skipped(_ result: LiftingImportResult) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Some rows could not become sessions")
                .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
            HStack { Text("No readable date or no countable set")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.inkSoft)
                Spacer(); Text("\(result.skipped)").font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink) }
            Text("A skipped row stays in the file; it is never half-added to your record.")
                .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(3)
        }
        .padding(16).background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private var committed: some View {
        VStack(alignment: .leading, spacing: 14) {
            NoopLiftTitle(title: "Added to your record", subtitle: "The file is unchanged and remains where you left it.")
            HStack(alignment: .top, spacing: 11) {
                NoopCanonicalGlyph(name: .check, size: 19, color: Color(hex: 0x6FBF7F))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Sessions added").font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(Color(hex: 0xA8E0B0))
                    Text("They are in your record, dated when they happened. Everything that reads your history can use them now.")
                        .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.inkSoft).lineSpacing(3)
                }
            }
            .padding(16).background(Color(hex: 0x6FBF7F).opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color(hex: 0x6FBF7F).opacity(0.22), lineWidth: 0.5))
            NoopLiftActionButton(title: "Back to programs") { navigation.replace(with: .liftLibrary) }
        }
    }

    private var nothingRead: some View {
        VStack(alignment: .leading, spacing: 14) {
            NoopLiftTitle(title: "Nothing was read",
                          subtitle: "Nothing was written, nothing changed, and the file is exactly as it was handed over.")
            NoopHTMLCard {
                Text("Choose a Hevy CSV export or a Liftosaur JSON export. A screenshot or summary cannot supply the individual sessions this import needs.")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.inkSoft)
                    .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            }
            NoopLiftActionButton(title: "Choose another file", accent: false) { navigation.back(or: .liftImport) }
        }
    }

    private func dateSpan(_ result: LiftingImportResult) -> String {
        guard let first = result.earliest, let last = result.latest else { return "dates unavailable" }
        if Calendar.current.isDate(first, inSameDayAs: last) { return first.formatted(date: .abbreviated, time: .omitted) }
        return "\(first.formatted(date: .abbreviated, time: .omitted)) to \(last.formatted(date: .abbreviated, time: .omitted))"
    }

}

// MARK: - lift-muscles

private struct NoopLiftMuscleRegion: Identifiable {
    let region: TrainingBodyRegion
    let muscles: [TrainingMuscle]
    let total: Double
    let recoveryRead: String?
    var id: String { region.rawValue }
}

private struct NoopLiftMusclesScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var flow: NoopLiftFlowModel
    @EnvironmentObject private var repo: Repository
    @State private var weekSets: [LiftSetRow] = []
    @State private var weekSessionCount = 0
    @State private var loaded = false

    private static let visibleRegions: [TrainingBodyRegion] = [.chest, .shoulders, .arms, .back, .core, .legs]
    private static let indentedMuscles: Set<String> = [
        "upper_traps", "lower_traps", "upper_abs", "lower_abs",
        "inner_quadriceps", "outer_quadriceps",
    ]

    private var workingSets: [LiftSetRow] { weekSets.filter { !$0.isWarmup } }
    private var uniqueExercises: [String] { Array(Set(workingSets.map(\.exercise))).sorted() }
    private var unresolvedExercises: [String] {
        uniqueExercises.filter { ExerciseAnatomyCatalog.resolve(title: $0) == nil }
    }
    private var isAbsent: Bool { loaded && workingSets.isEmpty }
    private var isCalibrating: Bool {
        loaded && !workingSets.isEmpty && (weekSessionCount < 5 || !unresolvedExercises.isEmpty)
    }
    private var credits: [String: Double] {
        var result: [String: Double] = [:]
        for set in workingSets {
            guard let anatomy = ExerciseAnatomyCatalog.resolve(title: set.exercise) else { continue }
            for id in anatomy.primaryMuscleIds { result[id, default: 0] += 1 }
            for id in anatomy.secondaryMuscleIds { result[id, default: 0] += 0.5 }
        }
        return result
    }
    private var regions: [NoopLiftMuscleRegion] {
        Self.visibleRegions.map { region in
            let muscles = TrainingMuscleCatalog.all.filter { TrainingBodyRegion.forMuscle($0.id) == region }
            let total = muscles.reduce(0.0) { value, muscle in
                value + (Self.indentedMuscles.contains(muscle.id) ? 0 : credits[muscle.id, default: 0])
            }
            return NoopLiftMuscleRegion(region: region, muscles: muscles, total: total,
                                        recoveryRead: nil)
        }
    }
    private var maxCredit: Double { max(1, credits.values.max() ?? 1) }

    var body: some View {
        NoopScreen(bottomInset: 40, topInset: 56) {
            VStack(alignment: .leading, spacing: 14) {
                NoopLiftBackHeader(label: "Session") { navigation.back(or: .liftDetail) }
                NoopLiftTitle(title: "Muscles", subtitle: intro)
                if !isAbsent { arithmeticCard }
                if isCalibrating { calibratingCard }
                if loaded && !isAbsent && !isCalibrating {
                    VStack(spacing: 9) { ForEach(regions) { regionCard($0) } }
                    provenanceCard
                }
                if isAbsent { absentCard }
                Text("Seven regions and thirty-three muscles, which is what the catalogue actually knows. Credited sets are a count of work, not a target: there is no weekly figure to hit here and nothing on this screen goes red.")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                    .lineSpacing(4).fixedSize(horizontal: false, vertical: true).padding(.horizontal, 2)
            }
        }
        .task { await loadWeek() }
    }

    private var intro: String {
        if isAbsent { return "What your lifting credited, once there is some." }
        if isCalibrating { return "What your lifting credited, over seven days. Too little of it yet to state a figure." }
        return "Credited sets over seven days, from the \(weekSessionCount) sessions in them."
    }

    private var arithmeticCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            NoopSectionLabel("How a set is credited")
            (Text("A working set counts ").foregroundStyle(NoopHTMLColor.inkSoft)
             + Text("1.0").fontWeight(.semibold).foregroundStyle(NoopHTMLColor.ink)
             + Text(" to the muscle the exercise is built around and ").foregroundStyle(NoopHTMLColor.inkSoft)
             + Text("0.5").fontWeight(.semibold).foregroundStyle(NoopHTMLColor.ink)
             + Text(" to the ones it also uses. Stabilisers count nothing — they are written down, not credited. Warm-ups count nothing either.").foregroundStyle(NoopHTMLColor.inkSoft))
                .font(NoopHTMLFont.sans(NoopType.caption)).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private var calibratingCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(weekSessionCount) \(weekSessionCount == 1 ? "session" : "sessions") recorded")
                    .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                Spacer()
                Text("still learning").font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.blueLight).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(NoopHTMLColor.blue.opacity(0.13), in: RoundedRectangle(cornerRadius: 7))
            }
            Text(calibratingReason).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.inkSoft)
                .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(NoopHTMLColor.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.blue.opacity(0.26), lineWidth: 0.5))
    }

    private var calibratingReason: String {
        if !unresolvedExercises.isEmpty {
            return "Noop is withholding the figures because \(unresolvedExercises.count) \(unresolvedExercises.count == 1 ? "exercise has" : "exercises have") no reviewed muscle mapping yet. Nothing is guessed from the exercise name."
        }
        return "Credited sets are held back until a week of lifting is on record, because four sessions in one part of the body would read as a plan rather than a sample. The count is what there is to show, so the count is what is shown."
    }

    private func regionCard(_ group: NoopLiftMuscleRegion) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(regionName(group.region)).font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                Spacer()
                Text(group.total > 0 ? "\(creditString(group.total)) credited" : "nothing this week")
                    .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                    .foregroundStyle(group.total > 0 ? NoopHTMLColor.blueLight : NoopHTMLColor.muted)
            }
            VStack(spacing: 9) { ForEach(group.muscles) { muscleRow($0) } }
            if let read = group.recoveryRead, !read.isEmpty {
                Text(read).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.nightLight)
                    .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private func muscleRow(_ muscle: TrainingMuscle) -> some View {
        let value = credits[muscle.id, default: 0]
        let indented = Self.indentedMuscles.contains(muscle.id)
        return HStack(spacing: 10) {
            Text(muscle.name).font(NoopHTMLFont.sans(NoopType.caption))
                .foregroundStyle(value > 0 ? NoopHTMLColor.ink : NoopHTMLColor.muted)
                .padding(.leading, indented ? 12 : 0).frame(width: indented ? 112 : 100, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule().fill(value >= 4 ? NoopHTMLColor.blue : NoopHTMLColor.blue.opacity(0.55))
                        .frame(width: proxy.size.width * min(1, value / maxCredit))
                }
            }
            .frame(height: 5)
            Text(value > 0 ? creditString(value) : "—")
                .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(value > 0 ? NoopHTMLColor.inkSoft : NoopHTMLColor.copy)
                .monospacedDigit().frame(width: 26, alignment: .trailing)
        }
    }

    private var provenanceCard: some View {
        let mapped = uniqueExercises.count - unresolvedExercises.count
        return VStack(alignment: .leading, spacing: 9) {
            NoopSectionLabel("Where the mapping comes from")
            Text("Each credited exercise is resolved through Noop’s reviewed local anatomy catalogue. An exercise without an unambiguous mapping is withheld rather than guessed.")
                .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.inkSoft)
                .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                provenanceChip("\(mapped) checked", highlighted: true)
                provenanceChip("0 fallbacks")
                provenanceChip("0 you confirmed")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private func provenanceChip(_ text: String, highlighted: Bool = false) -> some View {
        Text(text).font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
            .foregroundStyle(highlighted ? NoopHTMLColor.blueLight : NoopHTMLColor.copy)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(highlighted ? NoopHTMLColor.blue.opacity(0.13) : Color.white.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 6))
    }

    private var absentCard: some View {
        Text("No lifting on record. This screen fills itself the first time you finish a session — there is nothing to set up and nothing to connect.")
            .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
            .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private func loadWeek() async {
        await flow.refresh(repo: repo)
        guard let store = await repo.storeHandle() else { loaded = true; return }
        let cutoff = Int(Date().timeIntervalSince1970) - 7 * 86_400
        let sessions = flow.sessions.filter { $0.startTs >= cutoff }
        var rows: [LiftSetRow] = []
        for session in sessions {
            rows.append(contentsOf: (try? await store.liftSets(sessionId: session.id)) ?? [])
        }
        weekSessionCount = sessions.count
        weekSets = rows
        loaded = true
    }

    private func regionName(_ region: TrainingBodyRegion) -> String {
        region.rawValue.prefix(1).uppercased() + region.rawValue.dropFirst()
    }

    private func creditString(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }

}


// MARK: - lift-live sheets

struct NoopLiftExerciseName: Identifiable {
    let name: String
    var id: String { name }
}

/// What the last session of an exercise held, set by set.
private struct NoopLiftLastTimeSheet: View {
    let exercise: String
    let sets: [Int: LiftSetCarry]
    let units: UnitSystem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NoopSheetHeader(title: "Last time", subtitle: exercise) { dismiss() }
            if sets.isEmpty {
                Text("No earlier session of this exercise. The numbers you log today become next time's guide.")
                    .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(sets.keys.sorted(), id: \.self) { i in
                    let s = sets[i]!
                    HStack {
                        Text("\(i)").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(NoopHTMLColor.inkSoft)
                            .frame(width: 30, height: 30).background(Color.white.opacity(0.06), in: Circle())
                        Text(s.weightKg.map { "\(LiftFormat.trim(LiftFormat.display(fromKilograms: $0, system: units))) \(LiftFormat.weightUnit(units))" } ?? "—")
                            .frame(maxWidth: .infinity)
                        Text(s.reps.map { "\($0) reps" } ?? "—").frame(maxWidth: .infinity)
                    }
                    .font(NoopHTMLFont.sans(NoopType.subhead, weight: .medium)).foregroundStyle(NoopHTMLColor.ink).monospacedDigit()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(NoopHTMLColor.canvas)
    }
}

/// One side of the bar as it will be loaded: plates to scale in the competition colours, largest nearest
/// the collar, and the sum in words beneath. It answers "what do I put on" at a glance across the gym.
struct NoopPlateBar: View {
    struct Load: Equatable {
        let bar: Double
        let perSide: [Double]
        let leftover: Double
        let metric: Bool
    }

    let load: Load

    static func plates(metric: Bool) -> [Double] {
        metric ? [25, 20, 15, 10, 5, 2.5, 1.25] : [45, 35, 25, 10, 5, 2.5]
    }

    /// Competition colours by size: red, blue, yellow, green, then white, black and chrome for the change.
    private func color(_ p: Double) -> Color {
        let rank = Self.plates(metric: load.metric).firstIndex(of: p) ?? 6
        let metricColors = [Color(hex: 0xE5484D), Color(hex: 0x3E7BFA), Color(hex: 0xF2C94C), Color(hex: 0x3FB37F),
                            Color(hex: 0xE8ECEB), Color(hex: 0x2B2F2E), Color(hex: 0xB8C0BE)]
        let imperialColors = [Color(hex: 0x3E7BFA), Color(hex: 0xF2C94C), Color(hex: 0x3FB37F), Color(hex: 0xE8ECEB),
                              Color(hex: 0xE5484D), Color(hex: 0xB8C0BE)]
        let palette = load.metric ? metricColors : imperialColors
        return palette[min(rank, palette.count - 1)]
    }

    /// Height by weight, so a 25 reads as the big plate it is and change plates stay small.
    private func height(_ p: Double) -> CGFloat {
        let largest = Self.plates(metric: load.metric).first ?? 25
        return 22 + 30 * CGFloat(sqrt(p / largest))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                // The sleeve end of the bar, then the collar.
                Capsule().fill(Color.white.opacity(0.22)).frame(width: 26, height: 6)
                RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.4)).frame(width: 5, height: 20)
                HStack(spacing: 2) {
                    ForEach(Array(load.perSide.enumerated()), id: \.offset) { i, p in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(color(p).gradient)
                            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
                            .frame(width: p >= (load.metric ? 10 : 25) ? 11 : 8, height: height(p))
                            .transition(.scale(scale: 0.4, anchor: .leading).combined(with: .opacity))
                    }
                }
                .padding(.leading, 3)
                Capsule().fill(Color.white.opacity(0.22)).frame(width: 18, height: 6)
                Spacer(minLength: 10)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Each side").font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).foregroundStyle(NoopHTMLColor.muted)
                    Text(LiftFormat.trim(load.perSide.reduce(0, +)) + (load.metric ? " kg" : " lb"))
                        .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(NoopHTMLColor.ink).contentTransition(.numericText())
                }
            }
            .frame(height: 54)
            .animation(.snappy(duration: 0.25), value: load)
            Text(words).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy).monospacedDigit()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(words)
    }

    private var words: String {
        var groups: [(Double, Int)] = []
        for p in load.perSide {
            if let i = groups.firstIndex(where: { $0.0 == p }) { groups[i].1 += 1 } else { groups.append((p, 1)) }
        }
        let unit = load.metric ? "kg" : "lb"
        let plates = groups.map { $0.1 > 1 ? "\($0.1) × \(LiftFormat.trim($0.0))" : LiftFormat.trim($0.0) }.joined(separator: " + ")
        let extra = load.leftover > 0 ? ", \(LiftFormat.trim(load.leftover * 2)) \(unit) short of a plate pair" : ""
        return "\(LiftFormat.trim(load.bar)) \(unit) bar, then \(plates) a side\(extra)"
    }
}

/// "How hard was that?" — the session's effort on a 1–10 dial, saved with the lift.
struct NoopLiftEffortSheet: View {
    @Binding var rating: Double
    /// A cardio session reads in its own words and Aura blue; a lift keeps the warm save.
    var cardio = false
    let save: () -> Void
    @Environment(\.dismiss) private var dismiss

    private static let cardioWords: [(String, String)] = [
        ("Barely anything", "Could have kept going all day."),
        ("Very easy", "Breathing calm the whole way."),
        ("Easy", "Could hold a full conversation."),
        ("Comfortable", "Some work, nothing that asked much."),
        ("Moderate", "Talking in sentences, not paragraphs."),
        ("Working", "Steady effort that needed focus."),
        ("Hard", "A few words at a time."),
        ("Very hard", "Holding the pace took everything."),
        ("Near the limit", "Little or nothing left by the end."),
        ("Everything you had", "Could not have gone any harder."),
    ]

    private static let words: [(String, String)] = [
        ("Barely anything", "Could have done it all again without noticing."),
        ("Very easy", "Breathing calm the whole way through."),
        ("Easy", "Comfortable; plenty left in every set."),
        ("Comfortable", "Some work, nothing that asked much."),
        ("Moderate", "Noticeable effort, still well in control."),
        ("Working", "The last reps took some focus."),
        ("Hard", "A few sets got close to the edge."),
        ("Very hard", "Most sets ended near failure."),
        ("Near the limit", "Little or nothing left by the end."),
        ("Everything you had", "Could not have done another rep."),
    ]

    private var value: Int { min(10, max(1, Int(rating.rounded()))) }
    private var phrases: [(String, String)] { cardio ? Self.cardioWords : Self.words }

    static func word(_ v: Int) -> String { words[min(10, max(1, v)) - 1].0 }
    static func cardioWord(_ v: Int) -> String { cardioWords[min(10, max(1, v)) - 1].0 }

    private func color(_ v: Double) -> Color {
        v < 4 ? NoopHTMLColor.blueLight : v < 7 ? NoopHTMLColor.warm : v < 9 ? NoopHTMLColor.amber : NoopHTMLColor.red
    }

    var body: some View {
        VStack(spacing: 18) {
            NoopSheetHeader(title: "How hard was that?") { dismiss() }
                .padding(.top, 18)
            Text(cardio
                 ? "Your own read of the whole session. It sits beside the heart rate, which cannot feel the legs or the heat."
                 : "Your own read of the whole session. It sits beside the heart-rate figures, which cannot see a heavy set.")
                .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                .multilineTextAlignment(.center).padding(.horizontal, 26)
            dial.frame(width: 280, height: 280).padding(.top, 10)
            VStack(spacing: 4) {
                Text(phrases[value - 1].0).font(NoopHTMLFont.outfit(NoopType.title3)).foregroundStyle(color(rating))
                Text(phrases[value - 1].1).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                    .multilineTextAlignment(.center)
            }
            .animation(NoopMotion.swap, value: value)
            Spacer()
            Button(action: save) {
                Text("Save workout").font(NoopHTMLFont.sans(NoopType.body, weight: .semibold))
                    .foregroundStyle(cardio ? NoopHTMLColor.blueInk : NoopHTMLColor.warmInk)
                    .frame(maxWidth: .infinity).frame(minHeight: 56)
                    .background(cardio ? NoopHTMLColor.blueLight : NoopHTMLColor.warm,
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(NoopHTMLPressStyle())
            .padding(.horizontal, 22).padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NoopHTMLColor.canvas)
        .sensoryFeedback(.selection, trigger: value)
    }

    /// A 270° arc from bottom-left to bottom-right; drag the knob or anywhere on the ring.
    private var dial: some View {
        GeometryReader { g in
            let size = min(g.size.width, g.size.height)
            let r = size / 2 - 18
            let c = CGPoint(x: g.size.width / 2, y: g.size.height / 2)
            let start = 135.0, sweep = 270.0
            let frac = (rating - 1) / 9
            let angle = Angle(degrees: start + sweep * frac)
            ZStack {
                Circle().trim(from: 0, to: 0.75)
                    .stroke(Color.white.opacity(0.07), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(start))
                    .frame(width: r * 2, height: r * 2)
                Circle().trim(from: 0, to: 0.75 * frac)
                    .stroke(AngularGradient(colors: [NoopHTMLColor.blueLight, NoopHTMLColor.warm, NoopHTMLColor.amber, NoopHTMLColor.red],
                                            center: .center, startAngle: .degrees(0), endAngle: .degrees(270)),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(start))
                    .frame(width: r * 2, height: r * 2)
                ForEach(1...10, id: \.self) { i in
                    let a = Angle(degrees: start + sweep * Double(i - 1) / 9)
                    Circle().fill(Color.white.opacity(i <= value ? 0.0 : 0.25)).frame(width: 4, height: 4)
                        .position(x: c.x + (r) * cos(a.radians), y: c.y + (r) * sin(a.radians))
                }
                Circle().fill(NoopHTMLColor.ink).frame(width: 26, height: 26)
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
                    .position(x: c.x + r * cos(angle.radians), y: c.y + r * sin(angle.radians))
                Text("\(value)").font(NoopHTMLFont.outfit200(84)).monospacedDigit().foregroundStyle(color(rating))
                    .contentTransition(.numericText())
                HStack {
                    Text("1"); Spacer(); Text("10")
                }
                .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(NoopHTMLColor.muted)
                .frame(width: r * 1.3).position(x: c.x, y: c.y + r * 0.92)
            }
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                var deg = atan2(v.location.y - c.y, v.location.x - c.x) * 180 / .pi
                if deg < 0 { deg += 360 }
                var rel = deg - start
                if rel < 0 { rel += 360 }
                if rel > sweep { rel = rel > sweep + (360 - sweep) / 2 ? 0 : sweep }
                rating = 1 + 9 * rel / sweep
            }.onEnded { _ in withAnimation(NoopMotion.swap) { rating = rating.rounded() } })
            .accessibilityElement()
            .accessibilityLabel("Effort")
            .accessibilityValue("\(value) of 10, \(phrases[value - 1].0)")
            .accessibilityAdjustableAction { d in
                rating = d == .increment ? min(10, rating.rounded() + 1) : max(1, rating.rounded() - 1)
            }
        }
    }
}

/// A best set in this session that no earlier session of the exercise matched.
struct NoopLiftRecord: Identifiable {
    let id: String
    let exercise: String
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let setID: String?

    static func find(now: [LiftSetRow], past: [LiftSetRow], units: UnitSystem) -> [NoopLiftRecord] {
        func e1rm(_ s: LiftSetRow) -> Double? {
            guard let w = s.weightKg, w > 0, let r = s.reps, r > 0, r <= 12 else { return nil }
            return w * (1 + Double(r) / 30)
        }
        func kg(_ v: Double) -> String { "\(LiftFormat.trim(LiftFormat.display(fromKilograms: v, system: units))) \(LiftFormat.weightUnit(units))" }
        var out: [NoopLiftRecord] = []
        for exercise in NSOrderedSet(array: now.map(\.exercise)).array.compactMap({ $0 as? String }) {
            let mine = now.filter { $0.exercise == exercise }
            let before = past.filter { $0.exercise == exercise }
            guard !before.isEmpty else { continue }
            if let top = mine.filter({ ($0.weightKg ?? 0) > 0 }).max(by: { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) }),
               let w = top.weightKg, let old = before.compactMap(\.weightKg).max(), w > old {
                out.append(.init(id: "\(exercise)-heaviest", exercise: exercise, title: "Heaviest lift",
                                 detail: "\(kg(w)) · +\(kg(w - old))", symbol: "arrow.up", tint: NoopHTMLColor.warm, setID: top.id))
            }
            if let top = mine.max(by: { (e1rm($0) ?? 0) < (e1rm($1) ?? 0) }), let v = e1rm(top),
               let old = before.compactMap(e1rm).max(), v > old + 0.01 {
                out.append(.init(id: "\(exercise)-e1rm", exercise: exercise, title: "Best estimated max",
                                 detail: "\(kg(v.rounded())) · +\(kg((v - old).rounded()))", symbol: "bolt.fill",
                                 tint: NoopHTMLColor.blueLight, setID: top.id))
            }
            if let top = mine.max(by: { ($0.reps ?? 0) < ($1.reps ?? 0) }), let r = top.reps,
               (top.weightKg ?? 0) == 0, let old = before.filter({ ($0.weightKg ?? 0) == 0 }).compactMap(\.reps).max(), r > old {
                out.append(.init(id: "\(exercise)-reps", exercise: exercise, title: "Most reps",
                                 detail: "\(r) reps · +\(r - old)", symbol: "repeat", tint: NoopHTMLColor.green, setID: top.id))
            }
            let volume = mine.compactMap(\.volumeKg).reduce(0, +)
            let sessions = Dictionary(grouping: before, by: \.sessionId).values.map { $0.compactMap(\.volumeKg).reduce(0, +) }
            if volume > 0, let old = sessions.max(), volume > old {
                out.append(.init(id: "\(exercise)-volume", exercise: exercise, title: "Most volume",
                                 detail: "\(kg(volume)) · +\(kg(volume - old))", symbol: "square.stack.3d.up.fill",
                                 tint: NoopHTMLColor.blush, setID: nil))
            }
        }
        return out
    }
}
#endif
