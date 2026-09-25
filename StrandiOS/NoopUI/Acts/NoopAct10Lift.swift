#if os(iOS)
import SwiftUI
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

    func loadProgram(id: String?, repo: Repository) async {
        guard let id, let store = await repo.storeHandle() else {
            selectedProgram = nil
            programItems = []
            return
        }
        if !isLoaded { await refresh(repo: repo) }
        selectedProgram = (programs + archivedPrograms).first { $0.id == id }
        programItems = (try? await store.liftProgramItems(programId: id)) ?? []
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
            importFileName = url.lastPathComponent
        } catch {
            importResult = nil
            importFileName = url.lastPathComponent
            importError = "The file could not be read. Nothing was added."
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
        case .liftLibrary: NoopLiftLibraryScreen(navigation: navigation, flow: flow)
        case .liftProgram: NoopLiftProgramScreen(navigation: navigation, flow: flow)
        case .liftDetail: NoopLiftDetailScreen(navigation: navigation, flow: flow)
        case .liftEdit: NoopLiftEditScreen(navigation: navigation, flow: flow)
        case .liftImport: NoopLiftImportScreen(navigation: navigation, flow: flow)
        case .liftReview: NoopLiftReviewScreen(navigation: navigation, flow: flow)
        case .liftMuscles: NoopLiftMusclesScreen(navigation: navigation, flow: flow)
        default: NoopLiftLibraryScreen(navigation: navigation, flow: flow)
        }
    }
}

// MARK: - Deterministic visual fixture (Debug + --demo-seed only)

private enum NoopLiftDemo {
    static let programID = "noop-demo-upper-a"

    static var programs: [LiftProgramRow] {
        let now = Int(Date().timeIntervalSince1970)
        return [
            LiftProgramRow(id: programID, deviceId: "demo", name: "Upper A", note: nil,
                           createdAt: now - 90 * 86_400, updatedAt: now, archived: false),
            LiftProgramRow(id: "noop-demo-lower-a", deviceId: "demo", name: "Lower A", note: nil,
                           createdAt: now - 80 * 86_400, updatedAt: now - 7 * 86_400, archived: false),
            LiftProgramRow(id: "noop-demo-deadlift", deviceId: "demo", name: "Deadlift only", note: nil,
                           createdAt: now - 70 * 86_400, updatedAt: now - 50 * 86_400, archived: false),
        ]
    }

    static var archivedPrograms: [LiftProgramRow] {
        let now = Int(Date().timeIntervalSince1970)
        return [
            LiftProgramRow(id: "noop-demo-winter", deviceId: "demo", name: "Winter block", note: nil,
                           createdAt: now - 300 * 86_400, updatedAt: now - 60 * 86_400, archived: true),
            LiftProgramRow(id: "noop-demo-upper-old", deviceId: "demo", name: "Upper A, old", note: nil,
                           createdAt: now - 400 * 86_400, updatedAt: now - 100 * 86_400, archived: true),
        ]
    }

    static func item(_ id: String, _ ord: Int, _ exercise: String, sets: Int? = nil,
                     reps: Int? = nil, kg: Double? = nil, rest: Int? = nil,
                     rpe: Double? = nil, note: String? = nil) -> LiftProgramItemRow {
        LiftProgramItemRow(
            id: id, deviceId: "demo", programId: programID, ord: ord, exercise: exercise,
            targetSets: sets, targetRepsLow: reps, targetRepsHigh: reps,
            targetRpe: rpe, targetWeightKg: kg, restSec: rest, note: note
        )
    }

    static let items: [LiftProgramItemRow] = [
        item("demo-bench", 0, "Bench press", sets: 4, reps: 8, kg: 80, rest: 150,
             rpe: 8, note: "The last two sessions held here. Keep the load and add the clean reps first."),
        item("demo-incline", 1, "Incline dumbbell press"),
        item("demo-pulldown", 2, "Lat pulldown", sets: 3, reps: 10, kg: 55, rest: 120),
        item("demo-fly", 3, "Cable fly"),
        item("demo-raise", 4, "Lateral raise", sets: 3, reps: 12, kg: 12, rest: 90),
        item("demo-face", 5, "Face pull"),
    ]

    static let plan: [LiftPlanItem] = [
        LiftPlanItem(exercise: "Bench press", primaryMuscle: .chest,
                     secondaryMuscles: [.frontDelts, .triceps], targetSets: 4, restSec: 150,
                     targetRepsLow: 8, targetRepsHigh: 8, targetRpe: 8, targetWeightKg: 80,
                     note: "The last two sessions held here. Keep the load and add the clean reps first.",
                     programItemId: "demo-bench"),
        LiftPlanItem(exercise: "Incline dumbbell press", primaryMuscle: .chest,
                     secondaryMuscles: [.frontDelts, .triceps], targetSets: 3, restSec: 120,
                     programItemId: "demo-incline"),
        LiftPlanItem(exercise: "Lat pulldown", primaryMuscle: .lats,
                     secondaryMuscles: [.biceps, .upperBack], targetSets: 3, restSec: 120,
                     targetRepsLow: 10, targetRepsHigh: 10, targetWeightKg: 55,
                     programItemId: "demo-pulldown"),
        LiftPlanItem(exercise: "Cable fly", primaryMuscle: .chest, targetSets: 3, restSec: 90,
                     programItemId: "demo-fly"),
        LiftPlanItem(exercise: "Lateral raise", primaryMuscle: .sideDelts, targetSets: 3,
                     restSec: 90, targetRepsLow: 12, targetRepsHigh: 12, targetWeightKg: 12,
                     programItemId: "demo-raise"),
        LiftPlanItem(exercise: "Face pull", primaryMuscle: .rearDelts,
                     secondaryMuscles: [.upperBack], targetSets: 3, restSec: 90,
                     programItemId: "demo-face"),
    ]

    static var detailSession: LiftSessionRow {
        let end = Int(Date().timeIntervalSince1970) - 2 * 86_400
        return LiftSessionRow(id: "noop-demo-session", deviceId: "demo",
                              startTs: end - 62 * 60, endTs: end,
                              sport: LiftingImporter.sport, programId: programID,
                              programName: "Upper A", sessionRpe: 7.5, note: nil)
    }

    static var detailSets: [LiftSetRow] {
        let session = detailSession
        let values: [(String, LiftMuscle, [LiftMuscle], Double, Int)] = [
            ("Bench press", .chest, [.frontDelts, .triceps], 80, 8),
            ("Bench press", .chest, [.frontDelts, .triceps], 80, 8),
            ("Bench press", .chest, [.frontDelts, .triceps], 80, 7),
            ("Bench press", .chest, [.frontDelts, .triceps], 80, 6),
            ("Incline dumbbell press", .chest, [.frontDelts, .triceps], 22, 12),
            ("Incline dumbbell press", .chest, [.frontDelts, .triceps], 22, 11),
            ("Incline dumbbell press", .chest, [.frontDelts, .triceps], 22, 9),
            ("Lat pulldown", .lats, [.biceps, .upperBack], 55, 10),
            ("Lat pulldown", .lats, [.biceps, .upperBack], 55, 10),
            ("Lat pulldown", .lats, [.biceps, .upperBack], 55, 8),
            ("Lateral raise", .sideDelts, [], 12, 14),
            ("Lateral raise", .sideDelts, [], 12, 12),
            ("Lateral raise", .sideDelts, [], 12, 11),
            ("Lateral raise", .sideDelts, [], 8, 9),
            ("Lateral raise", .sideDelts, [], 6, 7),
            ("Face pull", .rearDelts, [.upperBack], 20, 12),
        ]
        var perExercise: [String: Int] = [:]
        return values.enumerated().map { ord, value in
            perExercise[value.0, default: 0] += 1
            return LiftSetRow(id: "noop-demo-set-\(ord)", deviceId: "demo", sessionId: session.id,
                              ord: ord, exercise: value.0, primaryMuscle: value.1,
                              secondaryMuscles: value.2, setIndex: perExercise[value.0] ?? 1,
                              weightKg: value.3, reps: value.4, rpe: nil, isWarmup: false,
                              startTs: session.startTs + ord * 180, endTs: session.startTs + ord * 180 + 35,
                              restSec: 120, note: nil)
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
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.09), lineWidth: 0.5))
                    NoopFixedChevron(direction: .left, color: NoopHTMLColor.inkSoft)
                        .offset(x: -1)
                }
                .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)

            Text(label)
                .font(NoopHTMLFont.sans(13.5))
                .foregroundStyle(NoopHTMLColor.copy)
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
                .font(NoopHTMLFont.outfit(25, weight: .regular))
                .tracking(-0.625)
                .foregroundStyle(NoopHTMLColor.ink)
            Text(subtitle)
                .font(NoopHTMLFont.sans(13))
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
                    .font(NoopHTMLFont.sans(13.5))
                    .foregroundStyle(NoopHTMLColor.blueLight)
                    .frame(minHeight: 34)
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(NoopHTMLFont.sans(13.5, weight: .semibold))
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
                .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                .foregroundStyle(warm ? Color(hex: 0xF3C888) : accent ? NoopHTMLColor.blueInk : NoopHTMLColor.inkSoft)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
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

private struct NoopLiftDoor: View {
    let icon: NoopCanonicalGlyphName
    let title: String
    let subtitle: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                NoopCanonicalGlyph(name: icon, size: 20, color: NoopHTMLColor.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(NoopHTMLFont.sans(13.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                    Text(subtitle)
                        .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                NoopChevron()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
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

private func liftTargetSummary(_ row: LiftProgramItemRow, system: UnitSystem) -> String {
    var pieces: [String] = []
    if let sets = row.targetSets {
        if let low = row.targetRepsLow { pieces.append("\(sets) × \(low)") }
        else { pieces.append("\(sets) sets") }
    } else if let low = row.targetRepsLow { pieces.append("reps \(low)") }
    if let weight = liftWeight(row.targetWeightKg, system: system) { pieces.append(weight) }
    if let rest = row.restSec { pieces.append("rest \(liftClock(rest))") }
    if let rpe = row.targetRpe { pieces.append("RPE \(LiftFormat.trim(rpe))") }
    return pieces.isEmpty ? "just the exercise" : pieces.joined(separator: " · ")
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
        .onChange(of: slot) { _, _ in syncFields() }
        .confirmationDialog("Finish this lift?", isPresented: $showFinish, titleVisibility: .visible) {
            Button("Save performed sets") { Task { await finish(includeShownValues: true) } }
            Button("Save only typed values") { Task { await finish(includeShownValues: false) } }
            Button("Keep lifting", role: .cancel) { }
        } message: {
            Text("Only performed sets are saved. Sets you never reached stay out of your record.")
        }
        .alert("Lift not saved", isPresented: Binding(
            get: { saveError != nil }, set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "Your session and its sets are still here. Try saving again.")
        }
    }

    private func session(engine: LiftSessionEngine,
                         presentation: LiftSessionController.Presentation,
                         slot: LiftSlot,
                         item: LiftPlanItem) -> some View {
        NoopScreen(bottomInset: 26, topInset: 54) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(presentation.isResting
                             ? liftClock(presentation.heldClockSeconds ?? engine.restRemaining(now: live.now) ?? 0)
                             : liftClock(presentation.sessionElapsedSeconds
                                         + (isPrototypeSession ? 1_394 : 0), long: true))
                            .font(NoopHTMLFont.outfit(20, weight: .light))
                            .tracking(-0.5)
                            .monospacedDigit()
                            .foregroundStyle(live.isPaused ? NoopHTMLColor.copy.opacity(0.8)
                                             : presentation.isResting ? NoopHTMLColor.blueLight : NoopHTMLColor.ink)
                        Text(presentation.isResting ? "REST LEFT" : live.isPaused ? "PAUSED" : "IN THE SESSION")
                            .font(NoopHTMLFont.sans(10, weight: .semibold))
                            .tracking(1.1)
                            .foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(live.programName ?? "Lift")
                            .font(NoopHTMLFont.sans(13))
                            .foregroundStyle(NoopHTMLColor.inkSoft)
                        Text("Exercise \(slot.exerciseIndex + 1) of \(engine.plan.count)")
                            .font(NoopHTMLFont.sans(10.5))
                            .foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                            .monospacedDigit()
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.exercise)
                        .font(NoopHTMLFont.outfit(29, weight: .light))
                        .tracking(-0.87)
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(LiftMuscleSummary.line(primary: item.primaryMuscle, secondaries: item.secondaryMuscles))
                        .font(NoopHTMLFont.sans(12))
                        .foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                }

                reasonCard(item)
                setList(engine: engine, current: slot, isResting: presentation.isResting)

                if presentation.isResting {
                    restCard(engine: engine, item: item, slot: slot)
                } else {
                    entryCard(slot: slot, item: item)
                    if let next = nextExercise(after: slot.exerciseIndex, in: engine) {
                        nextCard(next, engine: engine)
                    }
                }

                HStack(spacing: 10) {
                    NoopLiftActionButton(title: live.isPaused ? "Pick it up" : "Pause", accent: live.isPaused) {
                        live.togglePause()
                    }
                    NoopLiftActionButton(title: "Finish", accent: false, warm: true, disabled: saving) {
                        showFinish = true
                    }
                }

                Text(live.isPaused
                     ? "Paused stops both clocks and holds the numbers you had already typed. Nothing is ended or written until you finish."
                     : "Warm-ups are excluded from every figure this session states. Nothing on this screen is a target you are behind on.")
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }
        }
    }

    private func reasonCard(_ item: LiftPlanItem) -> some View {
        let hasReason = item.note?.isEmpty == false
        return VStack(alignment: .leading, spacing: 5) {
            Text(hasReason ? "WHY THESE NUMBERS" : "NO TARGETS ON THIS LINE")
                .font(NoopHTMLFont.sans(9.5, weight: .semibold))
                .tracking(1.33)
                .foregroundStyle(hasReason ? NoopHTMLColor.blueLight : NoopHTMLColor.muted)
            Text(item.note ?? "This line is a name, which is all it has to be. Log what you actually did and Noop will keep it — there is nothing here you are falling short of.")
                .font(NoopHTMLFont.sans(12.5))
                .foregroundStyle(NoopHTMLColor.inkSoft.opacity(0.92))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(hasReason ? NoopHTMLColor.blue.opacity(0.08) : Color.white.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(hasReason ? NoopHTMLColor.blue.opacity(0.24) : Color.white.opacity(0.09), lineWidth: 0.5))
    }

    private func setList(engine: LiftSessionEngine, current: LiftSlot, isResting: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(engine.slots(forExercise: current.exerciseIndex), id: \.self) { rowSlot in
                let done = engine.isCompleted(rowSlot)
                let active = rowSlot == current && !isResting
                HStack(spacing: 11) {
                    Group {
                        if done {
                            NoopCanonicalGlyph(name: .check, size: 16, color: Color(hex: 0x6FBF7F))
                        } else {
                            Circle()
                                .fill(active ? NoopHTMLColor.blue : Color.clear)
                                .overlay(Circle().strokeBorder(active ? Color.clear : Color.white.opacity(0.18), lineWidth: 1))
                                .shadow(color: active ? NoopHTMLColor.blue.opacity(0.34) : .clear, radius: 7)
                        }
                    }
                    .frame(width: 17, height: 17)
                    Text("\(rowSlot.setIndex)")
                        .font(NoopHTMLFont.sans(11.5, weight: .semibold))
                        .foregroundStyle(active ? NoopHTMLColor.blueLight : NoopHTMLColor.copy.opacity(0.82))
                        .frame(width: 20, alignment: .leading)
                    Text(setLine(rowSlot))
                        .font(NoopHTMLFont.sans(14, weight: active ? .semibold : .regular))
                        .foregroundStyle(active ? NoopHTMLColor.ink : done ? NoopHTMLColor.copy : NoopHTMLColor.muted)
                        .monospacedDigit()
                    Spacer()
                    if let rest = displayedRest(for: rowSlot, engine: engine) {
                        Text(rest)
                            .font(NoopHTMLFont.sans(11))
                            .foregroundStyle(NoopHTMLColor.copy.opacity(0.8))
                            .monospacedDigit()
                    }
                }
                .frame(minHeight: 46)
                .overlay(alignment: .top) {
                    if rowSlot.setIndex > 1 { Rectangle().fill(Color.white.opacity(0.055)).frame(height: 0.5) }
                }
                .contentShape(Rectangle())
                .onTapGesture { if !live.isPaused { live.start(rowSlot) } }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private func entryCard(slot: LiftSlot, item: LiftPlanItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SET \(slot.setIndex) OF \(item.targetSets)")
                    .font(NoopHTMLFont.sans(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(NoopHTMLColor.muted)
                Spacer()
                if item.targetWeightKg == nil && item.targetRepsLow == nil {
                    Text("no target to hit").font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                }
            }
            HStack(spacing: 9) {
                valueEditor(label: LiftFormat.weightUnit(units), text: $loadText, isWeight: true, slot: slot)
                valueEditor(label: "reps", text: $repsText, isWeight: false, slot: slot)
            }
            Button {
                writeFields(slot: slot)
                live.advance()
            } label: {
                Text("Log the set")
                    .font(NoopHTMLFont.sans(15.5, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.blueInk)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(NoopHTMLColor.blue, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: NoopHTMLColor.blue.opacity(0.28), radius: 13, y: 8)
            }
            .buttonStyle(NoopHTMLPressStyle())
            .disabled(live.isPaused)
            HStack(alignment: .top, spacing: 10) {
                NoopCanonicalGlyph(name: .watch, size: 17, color: NoopHTMLColor.blueLight)
                Text("Double-tap the strap to log this set and start the rest timer. You do not have to pick the phone up.")
                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.inkSoft)
                    .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12).padding(.vertical, 11)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), style: StrokeStyle(lineWidth: 0.5, dash: [4, 3])))
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
        .opacity(live.isPaused ? 0.48 : 1)
    }

    private func valueEditor(label: String, text: Binding<String>, isWeight: Bool, slot: LiftSlot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(NoopHTMLFont.sans(10.5)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
            HStack(spacing: 6) {
                nudgeButton(plus: false) { nudge(isWeight: isWeight, amount: -1, slot: slot) }
                TextField("—", text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(NoopHTMLFont.outfit(21, weight: .light))
                    .foregroundStyle(NoopHTMLColor.ink)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(NoopHTMLColor.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(NoopHTMLColor.blue.opacity(0.30), lineWidth: 0.5))
                    .onSubmit { writeFields(slot: slot) }
                nudgeButton(plus: true) { nudge(isWeight: isWeight, amount: 1, slot: slot) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func nudgeButton(plus: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(plus ? "+" : "−")
                .font(NoopHTMLFont.outfit(20, weight: .light)).foregroundStyle(NoopHTMLColor.inkSoft)
                .frame(width: 44, height: 48)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private func restCard(engine: LiftSessionEngine, item: LiftPlanItem, slot: LiftSlot) -> some View {
        let remaining = presentation?.heldClockSeconds ?? engine.restRemaining(now: live.now) ?? 0
        return VStack(spacing: 12) {
            Text("REST · \(liftClock(item.restSec)) ASKED FOR")
                .font(NoopHTMLFont.sans(10, weight: .semibold)).tracking(1.2).foregroundStyle(NoopHTMLColor.muted)
            Text(liftClock(remaining))
                .font(NoopHTMLFont.outfit200(76)).tracking(-3.42)
                .foregroundStyle(Color(hex: 0xF6FDFF)).monospacedDigit()
            Text(nextRestSentence(engine: engine, item: item, slot: slot))
                .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.copy)
                .multilineTextAlignment(.center).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            NoopLiftActionButton(title: remaining == 0 ? "Start the next set" : "Skip the rest of it", accent: false) {
                live.advance()
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 18)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5))
    }

    private func nextCard(_ next: LiftPlanItem, engine: LiftSessionEngine) -> some View {
        Button {
            guard let index = engine.plan.firstIndex(of: next),
                  let nextSlot = engine.slots(forExercise: index).first(where: { !engine.isCompleted($0) }) else { return }
            live.start(nextSlot)
        } label: {
            HStack(spacing: 12) {
                NoopCanonicalGlyph(name: .weight, size: 19, color: NoopHTMLColor.copy.opacity(0.82))
                VStack(alignment: .leading, spacing: 2) {
                    Text("NEXT").font(NoopHTMLFont.sans(10, weight: .semibold)).tracking(1.2).foregroundStyle(NoopHTMLColor.muted)
                    Text(next.exercise).font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.ink)
                }
                Spacer()
                Text(targetSummary(next)).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private var noSession: some View {
        NoopScreen(bottomInset: 26, topInset: 58) {
            VStack(alignment: .leading, spacing: 14) {
                NoopLiftTitle(title: "No lift is running",
                              subtitle: "Start from one of your programs. The session will remain live if you leave this screen.")
                NoopHTMLCard {
                    Text("Nothing is timed, inferred or saved until you start a session.")
                        .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.inkSoft)
                }
                NoopLiftActionButton(title: "Choose a program") { navigation.replace(with: .liftLibrary) }
            }
        }
    }

    private func prepare() async {
        if NoopContentPolicy.allowsPrototypeContent, !live.isActive {
            live.start(plan: NoopLiftDemo.plan, programId: NoopLiftDemo.programID, programName: "Upper A")
            live.advance()
            if let first = live.engine?.currentSlot {
                live.updateSet(first, weightKg: 80, reps: 8, rpe: nil, isWarmup: false)
                live.advance(); live.advance()
            }
            if let second = live.engine?.currentSlot {
                live.updateSet(second, weightKg: 80, reps: 8, rpe: nil, isWarmup: false)
                live.advance(); live.advance()
            }
        }
        await loadLastSessionValues()
        syncFields()
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
        if isPrototypeSession {
            // The deterministic HTML person is a visual fixture, never a workout in the user's store.
            live.discard()
            navigation.selectedLiftSessionID = nil
            flow.selectedSession = nil
            flow.sessionSets = []
            navigation.liftDetailReturnRoute = .today
            navigation.replace(with: .liftDetail)
            return
        }
        saving = true
        defer { saving = false }
        if let slot { writeFields(slot: slot) }
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
                             endTs: set.endTs, restSec: set.restSec)
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
            programName: live.programName, sessionRpe: nil, note: live.programName
        )
        let rows = finished.enumerated().map { ord, value -> LiftSetRow in
            let line = engine.planItem(for: value.slot)
            return LiftSetRow(
                id: "\(sessionID)-set-\(ord)", deviceId: repo.deviceId, sessionId: sessionID,
                ord: ord, exercise: line?.exercise ?? "", primaryMuscle: line?.primaryMuscle,
                secondaryMuscles: line?.secondaryMuscles ?? [], setIndex: value.slot.setIndex,
                weightKg: value.weightKg, reps: value.reps, rpe: value.rpe,
                isWarmup: value.isWarmup, startTs: value.startTs, endTs: value.endTs,
                restSec: value.restSec, note: nil
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
        } catch {
            saveError = "The session could not be written. Your session and its sets are still here. Try saving again."
            return
        }
        saved = true
        live.finishedSaving()
        await repo.refresh()
        await flow.refresh(repo: repo)
        flow.selectedSession = sessionRow
        flow.sessionSets = rows
        navigation.selectedLiftSessionID = sessionID
        navigation.liftDetailReturnRoute = .today
        navigation.replace(with: .liftDetail)
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

    private func displayedRest(for slot: LiftSlot, engine: LiftSessionEngine) -> String? {
        if isPrototypeSession,
           slot.exerciseIndex == 0, engine.isCompleted(slot) {
            return slot.setIndex == 1 ? "2:30" : "2:31"
        }
        return engine.recordedSet(for: slot)?.restSec.map { liftClock($0) }
    }

    private var isPrototypeSession: Bool {
        NoopContentPolicy.allowsPrototypeContent && live.programId == NoopLiftDemo.programID
    }

    private func nextExercise(after index: Int, in engine: LiftSessionEngine) -> LiftPlanItem? {
        guard engine.plan.indices.contains(index + 1) else { return nil }
        return engine.plan[index + 1]
    }

    private func targetSummary(_ item: LiftPlanItem) -> String {
        guard item.targetWeightKg != nil || item.targetRepsLow != nil else { return "no targets" }
        var pieces: [String] = []
        if let reps = item.targetRepsLow { pieces.append("\(item.targetSets) × \(reps)") }
        if let weight = liftWeight(item.targetWeightKg, system: units) { pieces.append(weight) }
        return pieces.joined(separator: " · ")
    }

    private func nextRestSentence(engine: LiftSessionEngine, item: LiftPlanItem, slot: LiftSlot) -> String {
        let nextIndex = min(item.targetSets, slot.setIndex + 1)
        let nextSlot = LiftSlot(exerciseIndex: slot.exerciseIndex, setIndex: nextIndex)
        let values = live.values(of: nextSlot)
        let detail = [liftWeight(values.weightKg, system: units), values.reps.map { "× \($0)" }]
            .compactMap { $0 }.joined(separator: " ")
        return "Next: set \(nextIndex) of \(item.targetSets)\(detail.isEmpty ? "" : ", \(detail)"). The strap will buzz once when the clock runs out."
    }
}

// MARK: - lift-library

private struct NoopLiftLibraryScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var flow: NoopLiftFlowModel
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var live: LiftSessionController
    @EnvironmentObject private var app: AppModel
    @State private var showArchived = false
    /// The session that refused this start, while its refusal is up.
    @State private var refusal: NoopRunningSession?

    private var programs: [LiftProgramRow] {
        if !flow.programs.isEmpty || !NoopContentPolicy.allowsPrototypeContent { return flow.programs }
        return NoopLiftDemo.programs
    }
    private var archived: [LiftProgramRow] {
        if !flow.archivedPrograms.isEmpty || !NoopContentPolicy.allowsPrototypeContent { return flow.archivedPrograms }
        return NoopLiftDemo.archivedPrograms
    }

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 14) {
                NoopLiftBackHeader(label: "Today’s session") { navigation.back(or: .session) }
                NoopLiftTitle(
                    title: "Programs",
                    subtitle: programs.isEmpty
                        ? "A program is a list of lines you keep. Every target on a line is optional, and a line that is only an exercise name is a finished line."
                        : "A list of lines you keep. Every target is optional — an exercise name can be a finished line."
                )

                if !flow.isLoaded && !NoopContentPolicy.allowsPrototypeContent {
                    NoopHTMLCard { ProgressView().tint(NoopHTMLColor.blueLight).frame(maxWidth: .infinity) }
                } else if programs.isEmpty {
                    NoopHTMLCard {
                        Text("Nothing here yet. A program is a list of lines you keep — write one, or bring your programs across from Hevy.")
                            .font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.copy)
                            .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    VStack(spacing: 9) {
                        ForEach(Array(programs.enumerated()), id: \.element.id) { index, program in
                            programCard(program, featured: index == 0)
                        }
                    }
                }

                VStack(spacing: 9) {
                    NoopLiftDoor(icon: .plus, title: "Write a program", subtitle: "a name is enough to start with") {
                        navigation.selectedLiftProgramID = nil
                        flow.selectedProgram = nil
                        flow.programItems = []
                        navigation.push(.liftProgram)
                    }
                    NoopLiftDoor(icon: .file, title: "Bring sessions in from Hevy", subtitle: "adds what it reads, changes nothing you have") {
                        navigation.push(.liftImport)
                    }
                }

                if !archived.isEmpty {
                    archivedCard
                }

                Text("Lifting is not a sixth tab. It lives under Today, the way a session does, and a program is something you keep rather than somewhere you go.")
                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                    .lineSpacing(4)

                VStack(alignment: .leading, spacing: 6) {
                    NoopSectionLabel("Where the exercises come from")
                    Text("Exercise data: ExerciseDB v1 via hasaneyldrm/exercises-dataset, MIT licence. Exercise media is not included and is not covered by that licence.")
                        .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 2)
            }
        }
        .task { await flow.refresh(repo: repo) }
        .overlay {
            if let refusal {
                NoopSessionRefusal(session: refusal,
                                   goToIt: { self.refusal = nil; refusal.go(navigation: navigation, lift: live) },
                                   notNow: { withAnimation(NoopMotion.swap) { self.refusal = nil } })
            }
        }
    }

    private var archivedCard: some View {
        VStack(spacing: 4) {
            Button {
                withAnimation(NoopMotion.swap) { showArchived.toggle() }
            } label: {
                HStack {
                    Text(showArchived ? "Archived · \(archived.count)" : "Show \(archived.count) archived programs")
                        .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.blueLight)
                    Spacer()
                    NoopChevron().rotationEffect(.degrees(showArchived ? -90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showArchived {
                ForEach(archived, id: \.id) { program in
                    HStack(spacing: 11) {
                        NoopCanonicalGlyph(name: .weight, size: 17, color: NoopHTMLColor.copy)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(program.name).font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.ink)
                            Text("kept with its session history")
                                .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy)
                        }
                        Spacer()
                        Text("read-only")
                            .font(NoopHTMLFont.sans(10.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.copy)
                    }
                    .padding(.vertical, 11).opacity(0.38)
                    .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.055)).frame(height: 0.5) }
                    .contentShape(Rectangle()).onTapGesture { open(program) }
                }
                Text("An archived program keeps every session you did on it. Restore it to change a line.")
                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                    .lineSpacing(3)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private func programCard(_ program: LiftProgramRow, featured: Bool) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Button { open(program) } label: {
                HStack(alignment: .top, spacing: 12) {
                    NoopCanonicalGlyph(name: .weight, size: 21,
                                       color: featured ? NoopHTMLColor.blue : NoopHTMLColor.copy.opacity(0.82))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(program.name).font(NoopHTMLFont.sans(15, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                        Text(programMeta(program)).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if featured {
                        Text("next up")
                            .font(NoopHTMLFont.sans(10, weight: .semibold)).foregroundStyle(NoopHTMLColor.blueLight)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(NoopHTMLColor.blue.opacity(0.13), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .buttonStyle(.plain)
            HStack(spacing: 8) {
                NoopLiftActionButton(title: featured ? "Start it" : "Start", accent: featured) {
                    Task { await start(program) }
                }
                Button { open(program) } label: {
                    Text("Open")
                        .font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.inkSoft)
                        .padding(.horizontal, 16).frame(height: 44)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                }
                .buttonStyle(NoopHTMLPressStyle())
            }
            if featured {
                Text("Targets are optional. Any line may remain only an exercise name.")
                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
        .background(featured ? NoopHTMLColor.blue.opacity(0.08) : NoopHTMLColor.card,
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(featured ? NoopHTMLColor.blue.opacity(0.30) : NoopHTMLColor.border, lineWidth: 0.5))
    }

    private func open(_ program: LiftProgramRow) {
        navigation.selectedLiftProgramID = program.id
        flow.selectedProgram = program
        if NoopContentPolicy.allowsPrototypeContent && program.id.hasPrefix("noop-demo") {
            flow.programItems = NoopLiftDemo.items
        }
        navigation.push(.liftProgram)
    }

    private func start(_ program: LiftProgramRow) async {
        // One session at a time, a lift or a cardio session alike (spec 90 §9.1): refuse, never swap.
        if let running = NoopRunningSession.current(app: app, lift: live, navigation: navigation) {
            withAnimation(NoopMotion.swap) { refusal = running }
            return
        }
        let items: [LiftProgramItemRow]
        if NoopContentPolicy.allowsPrototypeContent && program.id.hasPrefix("noop-demo") {
            items = NoopLiftDemo.items
        } else if let store = await repo.storeHandle() {
            items = (try? await store.liftProgramItems(programId: program.id)) ?? []
        } else { items = [] }
        guard !items.isEmpty else {
            navigation.selectedLiftProgramID = program.id
            flow.selectedProgram = program
            flow.programItems = []
            navigation.push(.liftProgram)
            return
        }
        let vocabulary: [LiftExerciseRow]
        if let store = await repo.storeHandle() {
            vocabulary = (try? await store.liftExercises(deviceId: repo.deviceId)) ?? []
        } else { vocabulary = [] }
        let plan = items.map { row in
            let known = vocabulary.first { $0.name == row.exercise }
            return LiftPlanItem(
                exercise: row.exercise, primaryMuscle: known?.primaryMuscle,
                secondaryMuscles: known?.secondaryMuscles ?? [], targetSets: row.targetSets,
                restSec: row.restSec, targetRepsLow: row.targetRepsLow,
                targetRepsHigh: row.targetRepsHigh, targetRpe: row.targetRpe,
                targetWeightKg: row.targetWeightKg, note: row.note, programItemId: row.id
            )
        }
        // The database reads above suspend this task. A cardio or another lift may have started
        // meanwhile; recheck at the last possible moment, then claim the one session synchronously.
        if let running = NoopRunningSession.current(app: app, lift: live, navigation: navigation) {
            withAnimation(NoopMotion.swap) { refusal = running }
            return
        }
        guard live.start(plan: plan, programId: program.id, programName: program.name) else {
            if let running = NoopRunningSession.current(app: app, lift: live, navigation: navigation) {
                withAnimation(NoopMotion.swap) { refusal = running }
            }
            return
        }
        navigation.replace(with: .liftLive)
    }

    private func programMeta(_ program: LiftProgramRow) -> String {
        if NoopContentPolicy.allowsPrototypeContent && program.id.hasPrefix("noop-demo") {
            switch program.name {
            case "Upper A": return "6 lines · last done Tuesday"
            case "Lower A": return "5 lines · last done a week ago"
            case "Deadlift only": return "1 line · last done in July"
            default: break
            }
        }
        return program.note?.isEmpty == false ? program.note! : "saved program"
    }
}

// MARK: - lift-program

private struct NoopLiftProgramScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var flow: NoopLiftFlowModel
    @EnvironmentObject private var repo: Repository
    @AppStorage(UnitPrefs.systemKey) private var unitSystemRaw = UnitSystem.metric.rawValue
    @State private var name = ""
    @State private var items: [LiftProgramItemRow] = []
    @State private var selectedLine = 0
    @State private var loaded = false
    @State private var saving = false
    @State private var saveError: String?

    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }
    private var readOnly: Bool { flow.selectedProgram?.archived == true }
    private var canSave: Bool {
        !readOnly && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        items.contains { !$0.exercise.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        NoopScreen(bottomInset: 40, topInset: 58) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Button("Programs") { navigation.back(or: .liftLibrary) }
                        .font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.blueLight)
                        .buttonStyle(.plain).frame(minHeight: 34)
                    Spacer()
                    if !readOnly {
                        Button(saving ? "Saving…" : "Done") { Task { await save() } }
                            .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                            .foregroundStyle(canSave ? NoopHTMLColor.blueLight : NoopHTMLColor.muted)
                            .buttonStyle(.plain).disabled(!canSave || saving)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    if readOnly {
                        Text(name).font(NoopHTMLFont.outfit(25, weight: .regular)).tracking(-0.625)
                    } else {
                        TextField("Name it", text: $name)
                            .font(NoopHTMLFont.outfit(25, weight: .regular)).tracking(-0.625)
                            .foregroundStyle(NoopHTMLColor.ink)
                    }
                    Text(readOnly
                         ? "These lines are exactly as they were when the program was archived."
                         : "A name and one exercise is a program. Add targets later, or never.")
                        .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                }

                if readOnly {
                    HStack(alignment: .top, spacing: 10) {
                        NoopCanonicalGlyph(name: .key, size: 17, color: NoopHTMLColor.copy)
                        Text("Archived and read-only. Restore it from Programs and every line becomes editable again.")
                            .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.inkSoft)
                            .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(13)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5))
                }

                lineList

                if !readOnly {
                    editor
                    NoopLiftDoor(icon: .plus, title: "Add an exercise", subtitle: "targets remain optional") {
                        addLine()
                    }
                }

                modes
            }
        }
        .task { await load() }
        .alert("Program not saved", isPresented: Binding(
            get: { saveError != nil }, set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "Your changes are still here. Try saving again.")
        }
    }

    private var lineList: some View {
        VStack(spacing: 0) {
            if items.isEmpty {
                Text("Add the first exercise. Nothing else is required.")
                    .font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 18)
            }
            ForEach(items.indices, id: \.self) { index in
                Button {
                    guard !readOnly else { return }
                    withAnimation(NoopMotion.swap) { selectedLine = index }
                } label: {
                    HStack(spacing: 11) {
                        if !readOnly {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 13, weight: .medium)).foregroundStyle(NoopHTMLColor.faint)
                                .frame(width: 17)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(items[index].exercise.isEmpty ? "Exercise name" : items[index].exercise)
                                .font(NoopHTMLFont.sans(13.5)).foregroundStyle(items[index].exercise.isEmpty ? NoopHTMLColor.muted : NoopHTMLColor.ink)
                            Text(liftTargetSummary(items[index], system: units))
                                .font(NoopHTMLFont.sans(11.5))
                                .foregroundStyle(liftTargetSummary(items[index], system: units) == "just the exercise" ? NoopHTMLColor.muted : NoopHTMLColor.blueLight)
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if !readOnly { NoopChevron().rotationEffect(.degrees(selectedLine == index ? 90 : 0)) }
                    }
                    .frame(minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) {
                    if index > 0 { Rectangle().fill(Color.white.opacity(0.055)).frame(height: 0.5) }
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    @ViewBuilder
    private var editor: some View {
        if items.indices.contains(selectedLine) {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Text(items[selectedLine].exercise.isEmpty ? "EXERCISE" : items[selectedLine].exercise.uppercased())
                        .font(NoopHTMLFont.sans(10, weight: .semibold)).tracking(1.2).foregroundStyle(NoopHTMLColor.muted)
                    Spacer()
                    Text("weight × reps").font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                }
                targetRow("Exercise", text: binding(\.exercise), keyboard: .default)
                targetRow("Sets", text: optionalIntBinding(\.targetSets))
                targetRow("Reps", text: optionalIntBinding(\.targetRepsLow))
                targetRow("Weight", text: weightBinding())
                targetRow("Rest between sets", text: restBinding())
                targetRow("Effort to aim for", text: optionalDoubleBinding(\.targetRpe))
                targetRow("Time under the bar", text: .constant("not set"), disabled: true)
                targetRow("Technique note", text: optionalStringBinding(\.note), keyboard: .default)
                Button(role: .destructive) {
                    items.remove(at: selectedLine)
                    selectedLine = max(0, min(selectedLine, items.count - 1))
                } label: {
                    Text("Remove this line")
                        .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                        .frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 15)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
        }
    }

    private func targetRow(_ label: String, text: Binding<String>,
                           keyboard: UIKeyboardType = .decimalPad, disabled: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(label).font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.inkSoft)
            Spacer(minLength: 8)
            TextField("not set", text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .font(NoopHTMLFont.sans(13, weight: text.wrappedValue == "not set" || text.wrappedValue.isEmpty ? .regular : .semibold))
                .foregroundStyle(disabled || text.wrappedValue == "not set" ? NoopHTMLColor.muted : NoopHTMLColor.ink)
                .disabled(disabled)
                .frame(maxWidth: 178)
        }
        .frame(minHeight: 46)
        .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.055)).frame(height: 0.5) }
    }

    private var modes: some View {
        VStack(alignment: .leading, spacing: 10) {
            NoopSectionLabel("Six ways a line can be measured")
            let values = [
                ("Weight × reps", "881", "80 kg × 8"),
                ("Bodyweight reps", "284", "× 12"),
                ("Duration", "102", "0:45"),
                ("Weighted bodyweight", "36", "+10 kg × 8"),
                ("Assisted bodyweight", "15", "−20 kg × 8"),
                ("Reps only", "6", "× 20"),
            ]
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(value.0).font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.inkSoft)
                        Text(value.2).font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                    }
                    Spacer()
                    Text(value.1).font(NoopHTMLFont.outfit(18, weight: .regular)).foregroundStyle(NoopHTMLColor.blueLight)
                }
                .padding(.vertical, 8)
                .overlay(alignment: .top) { if index > 0 { Rectangle().fill(Color.white.opacity(0.055)).frame(height: 0.5) } }
            }
            Text("The catalogue carries the mode. A line only asks for the values that mode can honestly hold.")
                .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private func load() async {
        if let selected = flow.selectedProgram, !flow.programItems.isEmpty {
            name = selected.name; items = flow.programItems; loaded = true; return
        }
        if NoopContentPolicy.allowsPrototypeContent && navigation.selectedLiftProgramID == nil {
            flow.selectedProgram = NoopLiftDemo.programs[0]
            flow.programItems = NoopLiftDemo.items
            name = "Upper A"; items = NoopLiftDemo.items; loaded = true; return
        }
        await flow.loadProgram(id: navigation.selectedLiftProgramID, repo: repo)
        name = flow.selectedProgram?.name ?? ""
        items = flow.programItems
        loaded = true
    }

    private func addLine() {
        let programID = flow.selectedProgram?.id ?? navigation.selectedLiftProgramID ?? "new"
        items.append(LiftProgramItemRow(
            id: UUID().uuidString, deviceId: repo.deviceId, programId: programID,
            ord: items.count, exercise: "", targetSets: nil, targetRepsLow: nil,
            targetRepsHigh: nil, targetRpe: nil, targetWeightKg: nil, restSec: nil, note: nil
        ))
        selectedLine = max(0, items.count - 1)
    }

    private func save() async {
        guard canSave, !saving else { return }
        if NoopContentPolicy.allowsPrototypeContent,
           flow.selectedProgram?.id.hasPrefix("noop-demo") == true {
            // Editing the preview program must not write its invented lines to the real database.
            navigation.back(or: .liftLibrary)
            return
        }
        guard let store = await repo.storeHandle() else { return }
        saving = true
        defer { saving = false }
        let now = Int(Date().timeIntervalSince1970)
        let id = flow.selectedProgram?.id ?? UUID().uuidString
        let created = flow.selectedProgram?.createdAt ?? now
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let row = LiftProgramRow(id: id, deviceId: repo.deviceId, name: cleanName, note: nil,
                                 createdAt: created, updatedAt: now, archived: false)
        let cleanItems = items.filter { !$0.exercise.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .enumerated().map { ord, source -> LiftProgramItemRow in
                var item = source
                item.deviceId = repo.deviceId; item.programId = id; item.ord = ord
                item.exercise = source.exercise.trimmingCharacters(in: .whitespacesAndNewlines)
                return item
            }
        do {
            try await store.saveLiftProgram(row, items: cleanItems)
        } catch {
            saveError = "The program and its lines could not be written. Your changes are still here."
            return
        }
        flow.selectedProgram = row; flow.programItems = cleanItems
        navigation.selectedLiftProgramID = id
        await flow.refresh(repo: repo)
        navigation.back(or: .liftLibrary)
    }

    private func binding(_ keyPath: WritableKeyPath<LiftProgramItemRow, String>) -> Binding<String> {
        Binding(get: { items.indices.contains(selectedLine) ? items[selectedLine][keyPath: keyPath] : "" },
                set: { if items.indices.contains(selectedLine) { items[selectedLine][keyPath: keyPath] = $0 } })
    }
    private func optionalStringBinding(_ keyPath: WritableKeyPath<LiftProgramItemRow, String?>) -> Binding<String> {
        Binding(get: { items.indices.contains(selectedLine) ? items[selectedLine][keyPath: keyPath] ?? "" : "" },
                set: { if items.indices.contains(selectedLine) { items[selectedLine][keyPath: keyPath] = $0.isEmpty ? nil : $0 } })
    }
    private func optionalIntBinding(_ keyPath: WritableKeyPath<LiftProgramItemRow, Int?>) -> Binding<String> {
        Binding(get: { items.indices.contains(selectedLine) ? items[selectedLine][keyPath: keyPath].map(String.init) ?? "" : "" },
                set: { if items.indices.contains(selectedLine) { items[selectedLine][keyPath: keyPath] = Int($0) } })
    }
    private func optionalDoubleBinding(_ keyPath: WritableKeyPath<LiftProgramItemRow, Double?>) -> Binding<String> {
        Binding(get: { items.indices.contains(selectedLine) ? items[selectedLine][keyPath: keyPath].map(LiftFormat.trim) ?? "" : "" },
                set: { if items.indices.contains(selectedLine) { items[selectedLine][keyPath: keyPath] = Double($0.replacingOccurrences(of: ",", with: ".")) } })
    }
    private func weightBinding() -> Binding<String> {
        Binding(get: {
            guard items.indices.contains(selectedLine), let kg = items[selectedLine].targetWeightKg else { return "" }
            return LiftFormat.trim(LiftFormat.display(fromKilograms: kg, system: units))
        }, set: {
            guard items.indices.contains(selectedLine) else { return }
            let display = Double($0.replacingOccurrences(of: ",", with: "."))
            items[selectedLine].targetWeightKg = display.map { LiftFormat.kilograms(fromDisplay: $0, system: units) }
        })
    }
    private func restBinding() -> Binding<String> {
        Binding(get: {
            guard items.indices.contains(selectedLine), let seconds = items[selectedLine].restSec else { return "" }
            return liftClock(seconds)
        }, set: {
            guard items.indices.contains(selectedLine) else { return }
            let parts = $0.split(separator: ":").compactMap { Int($0) }
            if parts.count == 2 { items[selectedLine].restSec = parts[0] * 60 + parts[1] }
            else { items[selectedLine].restSec = Int($0) }
        })
    }
}

// MARK: - lift-detail

private struct NoopLiftDetailScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var flow: NoopLiftFlowModel
    @EnvironmentObject private var repo: Repository
    @AppStorage(UnitPrefs.systemKey) private var unitSystemRaw = UnitSystem.metric.rawValue

    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }
    private var isPrototypeRecord: Bool {
        NoopContentPolicy.allowsPrototypeContent && flow.selectedSession == nil
            && navigation.selectedLiftSessionID == nil
    }
    private var record: LiftSessionRow? {
        flow.selectedSession ?? (isPrototypeRecord ? NoopLiftDemo.detailSession : nil)
    }
    private var sets: [LiftSetRow] {
        isPrototypeRecord ? NoopLiftDemo.detailSets : flow.sessionSets
    }
    private var working: [LiftSetRow] { sets.filter { !$0.isWarmup } }
    private var volume: Double { working.compactMap(\.volumeKg).reduce(0, +) }
    private var heaviest: LiftSetRow? { working.filter { $0.weightKg != nil }.max { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) } }

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 14) {
                NoopLiftBackHeader(label: navigation.liftDetailReturnRoute == .history ? "Everything you logged" : "Today") {
                    navigation.back(or: navigation.liftDetailReturnRoute)
                }
                if let record {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(record.programName ?? "A lift")
                            .font(NoopHTMLFont.outfit(27, weight: .light)).tracking(-0.756)
                            .foregroundStyle(NoopHTMLColor.ink)
                        Text(detailSubtitle(record)).font(NoopHTMLFont.sans(13))
                            .foregroundStyle(NoopHTMLColor.copy).monospacedDigit()
                    }
                    metricGrid(record)
                    if record.sessionRpe == nil {
                        Text("You did not rate this session, so there is no figure for how hard it was. Noop will not estimate one from the weights — an effort reading is yours or it is nothing.")
                            .font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                            .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 2)
                    }
                    exerciseCards
                    musclesDoor
                    costCard
                    VStack(alignment: .leading, spacing: 6) {
                        NoopSectionLabel("Where these exercises come from")
                        Text("Exercise data: ExerciseDB v1 via hasaneyldrm/exercises-dataset, MIT licence. Exercise media is not included and is not covered by that licence.")
                            .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy)
                            .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 2)
                    Text("No score, no grade, no medal. A session is a thing you did and a cost you paid, and both are written down plainly.")
                        .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                        .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                } else {
                    NoopLiftTitle(title: "No session selected",
                                  subtitle: "Open a lifting session from your history to see what was recorded.")
                    NoopLiftActionButton(title: "Open programs") { navigation.replace(with: .liftLibrary) }
                }
            }
        }
        .task { await load() }
    }

    private func metricGrid(_ record: LiftSessionRow) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)], spacing: 9) {
            metricTile(value: isPrototypeRecord ? "16" : "\(working.count)", unit: "sets", label: "working sets, warm-ups left out")
            metricTile(value: isPrototypeRecord ? (units == .metric ? "6,280" : "13,840") : volume > 0 ? groupedWeight(volume) : "—",
                       unit: isPrototypeRecord || volume > 0 ? LiftFormat.weightUnit(units) : "",
                       label: volume > 0 ? "lifted altogether" : "volume was not recorded")
            metricTile(value: heaviest.flatMap { liftWeight($0.weightKg, system: units) } ?? "—",
                       unit: heaviest?.reps.map { "× \($0)" } ?? "",
                       label: heaviest == nil ? "no weighted set recorded" : "heaviest set you finished")
            metricTile(value: record.sessionRpe.map(LiftFormat.trim) ?? "—",
                       unit: record.sessionRpe == nil ? "" : "RPE",
                       label: record.sessionRpe == nil ? "how hard it was — not recorded" : "how hard it was, your reading")
        }
    }

    private func metricTile(value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(value).font(NoopHTMLFont.outfit(27, weight: .light)).tracking(-0.675).foregroundStyle(NoopHTMLColor.ink)
                    .minimumScaleFactor(0.72).lineLimit(1)
                Text(unit).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy)
            }
            Text(label).font(NoopHTMLFont.sans(10.5)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 94, alignment: .topLeading)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private var exerciseCards: some View {
        let allExercises = NSOrderedSet(array: working.map(\.exercise)).array.compactMap { $0 as? String }
        let order = isPrototypeRecord
            ? allExercises.filter { ["Bench press", "Incline dumbbell press", "Lat pulldown", "Lateral raise"].contains($0) }
            : allExercises
        let warmups = sets.filter(\.isWarmup).count
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                NoopSectionLabel("What you lifted")
                Spacer()
                Text(isPrototypeRecord ? "5 warm-ups folded" : warmupNote(warmups))
                    .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
            }
            VStack(alignment: .leading, spacing: 15) {
                ForEach(order, id: \.self) { exercise in
                    let rows = working.filter { $0.exercise == exercise }
                    VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(exercise).font(NoopHTMLFont.sans(14.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                        Spacer()
                        Text(exerciseMeta(exercise, rows: rows))
                            .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                    }
                    FlowLayout(spacing: 6) {
                        ForEach(rows, id: \.id) { row in
                            Text(setPill(row))
                                .font(NoopHTMLFont.sans(12, weight: .medium)).foregroundStyle(NoopHTMLColor.inkSoft)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                        }
                    }
                        if let note = exerciseNote(exercise) {
                            Text(note).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                                .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            Button {
                navigation.push(.liftEdit)
            } label: {
                HStack(spacing: 9) {
                    Text("Correct something in this session")
                        .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.blueLight)
                    Spacer(); NoopChevron()
                }
                .padding(.horizontal, 2).frame(minHeight: 48)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5) }
        }
        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private var musclesDoor: some View {
        Button {
            navigation.push(.liftMuscles)
        } label: {
            HStack(spacing: 13) {
                NoopCanonicalGlyph(name: .person, size: 21, color: NoopHTMLColor.blush)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Which muscles this credited").font(NoopHTMLFont.sans(13.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                    Text(isPrototypeRecord
                         ? "7 regions · 22.5 credited sets · mapping stated"
                         : "credited sets · mapping stated")
                        .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                }
                Spacer(); NoopChevron()
            }
            .padding(16)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private var costCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 9) {
                NoopCanonicalGlyph(name: .moon, size: 18, color: NoopHTMLColor.nightLight)
                Text("What it cost you").font(NoopHTMLFont.sans(13.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
            }
            if isPrototypeRecord {
                costRow("Added to tonight’s sleep need", "+18 min")
                costRow("Recovered by", "Thursday, 09:00")
                costRow("Load added to the week", "64 → 324")
            } else {
                Text("This session record does not contain a defensible recovery or sleep-cost estimate. Noop will show one here only when it can be calculated from measured data.")
                    .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.inkSoft)
                    .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            }
            Text("Priced the way a ride is priced, in the same currency: minutes on tonight’s sleep need and load on the week. A lift is not a different kind of effort.")
                .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy)
                .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(NoopHTMLColor.night.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.night.opacity(0.24), lineWidth: 0.5))
    }

    private func costRow(_ label: String, _ value: String) -> some View {
        HStack { Text(label).font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.inkSoft); Spacer()
            Text(value).font(NoopHTMLFont.sans(12.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.nightLight) }
    }

    private func load() async {
        if isPrototypeRecord { return }
        if let startTs = navigation.liftDetailStartTs {
            navigation.liftDetailStartTs = nil
            await flow.refresh(repo: repo)
            navigation.selectedLiftSessionID = flow.sessions.first { $0.startTs == startTs }?.id
            await flow.loadSession(id: navigation.selectedLiftSessionID, repo: repo)
            return
        }
        if flow.selectedSession != nil && !flow.sessionSets.isEmpty { return }
        await flow.refresh(repo: repo)
        let id = navigation.selectedLiftSessionID ?? flow.sessions.first?.id
        navigation.selectedLiftSessionID = id
        await flow.loadSession(id: id, repo: repo)
    }

    private func detailSubtitle(_ row: LiftSessionRow) -> String {
        if isPrototypeRecord { return "Tuesday, 18:12 · 62 min · Upper A" }
        let start = Date(timeIntervalSince1970: TimeInterval(row.startTs))
        let minutes = row.endTs.map { max(1, ($0 - row.startTs) / 60) }
        var parts = [start.formatted(.dateTime.weekday(.wide)), start.noopLiftTime]
        if let minutes { parts.append("\(minutes) min") }
        if let program = row.programName { parts.append(program) } else { parts.append("no program") }
        return parts.joined(separator: " · ")
    }

    private func groupedWeight(_ kg: Double) -> String {
        let display = LiftFormat.display(fromKilograms: kg, system: units)
        return display.formatted(.number.precision(.fractionLength(0)).grouping(.automatic))
    }

    private func setPill(_ row: LiftSetRow) -> String {
        switch (liftWeight(row.weightKg, system: units), row.reps) {
        case let (weight?, reps?): return "\(weight) × \(reps)"
        case let (weight?, nil): return weight
        case let (nil, reps?): return "× \(reps)"
        default: return "recorded"
        }
    }

    private func warmupNote(_ count: Int) -> String {
        count == 0 ? "no warm-ups logged" : "\(count) warm-up\(count == 1 ? "" : "s") folded"
    }

    private func exerciseMeta(_ exercise: String, rows: [LiftSetRow]) -> String {
        if isPrototypeRecord && exercise == "Lateral raise" {
            return "3 working sets, one dropped"
        }
        return "\(rows.count) working \(rows.count == 1 ? "set" : "sets")"
    }

    private func exerciseNote(_ exercise: String) -> String? {
        guard isPrototypeRecord else { return nil }
        switch exercise {
        case "Bench press": return "2 warm-ups folded away"
        case "Incline dumbbell press": return "No targets on this line — this is what you did."
        case "Lateral raise": return "The third set expanded into three rows when you dropped the weight."
        default: return nil
        }
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
    private var isPrototypeRecord: Bool {
        NoopContentPolicy.allowsPrototypeContent && flow.selectedSession == nil
            && navigation.selectedLiftSessionID == nil
    }
    private var kept: [LiftSetRow] { rows.filter { !deleted.contains($0.id) } }
    private var working: [LiftSetRow] { kept.filter { !$0.isWarmup } }
    private var volume: Double { working.compactMap(\.volumeKg).reduce(0, +) }
    private var selectedExercise: String { rows.first?.exercise ?? "Recorded sets" }
    private var displayIndices: [Int] { rows.indices.filter { rows[$0].exercise == selectedExercise && !rows[$0].isWarmup } }

    var body: some View {
        NoopScreen(bottomInset: 40, topInset: 58) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Button("Cancel") { navigation.back(or: .liftDetail) }
                        .font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.blueLight)
                        .buttonStyle(.plain).frame(minHeight: 34)
                    Spacer()
                    NoopSectionLabel("Correcting")
                    Spacer()
                    Button(saving ? "Saving…" : "Save") { Task { await save() } }
                        .font(NoopHTMLFont.sans(13.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.blueLight)
                        .buttonStyle(.plain).disabled(saving)
                }
                NoopLiftTitle(title: editTitle,
                              subtitle: "Change what you logged. What the strap measured during the session — your pulse, the minutes, the cost — is not touched by anything here.")

                if saved {
                    HStack(spacing: 11) {
                        NoopCanonicalGlyph(name: .check, size: 19, color: Color(hex: 0x6FBF7F))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Saved").font(NoopHTMLFont.sans(13.5, weight: .semibold)).foregroundStyle(Color(hex: 0xA8E0B0))
                            Text("\(working.count) working sets, \(groupedWeight(volume)). The session’s figures are recomputed from what is here now.")
                                .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.inkSoft)
                        }
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: 0x6FBF7F).opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color(hex: 0x6FBF7F).opacity(0.22), lineWidth: 0.5))
                }

                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        NoopSectionLabel(selectedExercise)
                        Spacer()
                        Text(totalText)
                            .font(NoopHTMLFont.sans(11.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.blueLight)
                            .monospacedDigit()
                    }
                    VStack(spacing: 0) {
                        ForEach(displayIndices, id: \.self) { index in
                            editRow(index)
                        }
                    }
                    Button { addSet() } label: {
                        HStack(spacing: 9) {
                            NoopCanonicalGlyph(name: .plus, size: 16, color: NoopHTMLColor.blueLight)
                            Text("Add a set you forgot")
                                .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.blueLight)
                            Spacer()
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5) }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))

                Text("A corrected session is the session. Noop keeps one record and this screen edits it — there is no second, truer copy kept somewhere you cannot see.")
                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
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

    private func editRow(_ index: Int) -> some View {
        let isDeleted = deleted.contains(rows[index].id)
        return HStack(spacing: 10) {
            Text("\(rows[index].setIndex)")
                .font(NoopHTMLFont.sans(11.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                .frame(width: 20, alignment: .leading)
            HStack(spacing: 7) {
                TextField("—", text: weightBinding(index))
                    .keyboardType(.decimalPad).multilineTextAlignment(.center)
                    .font(NoopHTMLFont.sans(14, weight: .medium)).foregroundStyle(isDeleted ? NoopHTMLColor.copy : NoopHTMLColor.ink)
                    .frame(width: 76, height: 36)
                    .background(isDeleted ? Color.clear : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(isDeleted ? Color.clear : Color.white.opacity(0.12), lineWidth: 0.5))
                    .strikethrough(isDeleted)
                    .disabled(isDeleted)
                Text("×").font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy)
                TextField("—", text: repsBinding(index))
                    .keyboardType(.numberPad).multilineTextAlignment(.center)
                    .font(NoopHTMLFont.sans(14, weight: .medium)).foregroundStyle(isDeleted ? NoopHTMLColor.copy : NoopHTMLColor.ink)
                    .frame(width: 48, height: 36)
                    .background(isDeleted ? Color.clear : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(isDeleted ? Color.clear : Color.white.opacity(0.12), lineWidth: 0.5))
                    .strikethrough(isDeleted)
                    .disabled(isDeleted)
                if isDeleted {
                    Text("deleted")
                        .font(NoopHTMLFont.sans(10, weight: .semibold)).foregroundStyle(NoopHTMLColor.copy)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            Spacer(minLength: 4)
            Button {
                if isDeleted { deleted.remove(rows[index].id) } else { deleted.insert(rows[index].id) }
            } label: {
                if isDeleted {
                    Text("Undo").font(NoopHTMLFont.sans(12.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.blueLight)
                } else {
                    NoopCanonicalGlyph(name: .trash, size: 17, color: NoopHTMLColor.copy.opacity(0.82))
                }
            }
            .buttonStyle(.plain).frame(minWidth: 44, minHeight: 44)
        }
        .frame(minHeight: 48).opacity(isDeleted ? 0.5 : 1)
        .overlay(alignment: .top) {
            if index != displayIndices.first { Rectangle().fill(Color.white.opacity(0.055)).frame(height: 0.5) }
        }
    }

    private var totalText: String {
        if isPrototypeRecord {
            return deleted.isEmpty ? "14 working sets · 5,020 kg" : "14 → 13 working sets · 4,540 kg"
        }
        let suffix = "\(working.count) working sets · \(groupedWeight(volume))"
        return deleted.isEmpty ? suffix : "\(rows.filter { !$0.isWarmup }.count) → \(suffix)"
    }

    private var editTitle: String {
        if isPrototypeRecord { return "Upper A, Tuesday" }
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
        if rows.isEmpty && isPrototypeRecord { rows = NoopLiftDemo.detailSets }
        deleted = flow.deletedSetIDs
        if isPrototypeRecord, deleted.isEmpty,
           let fourth = rows.filter({ $0.exercise == selectedExercise && !$0.isWarmup }).dropFirst(3).first {
            deleted.insert(fourth.id)
        }
    }

    private func addSet() {
        guard let source = kept.last(where: { $0.exercise == selectedExercise })
                ?? rows.last(where: { $0.exercise == selectedExercise }),
              let session = flow.selectedSession ?? recordFallback else { return }
        let next = (rows.filter { $0.exercise == source.exercise }.map(\.setIndex).max() ?? 0) + 1
        rows.append(LiftSetRow(id: UUID().uuidString, deviceId: repo.deviceId, sessionId: session.id,
                               ord: rows.count, exercise: source.exercise,
                               primaryMuscle: source.primaryMuscle, secondaryMuscles: source.secondaryMuscles,
                               setIndex: next, weightKg: nil, reps: nil, rpe: nil,
                               isWarmup: false, startTs: nil, endTs: nil, restSec: nil, note: nil))
    }

    private var recordFallback: LiftSessionRow? {
        isPrototypeRecord ? NoopLiftDemo.detailSession : nil
    }

    private func save() async {
        guard !saving else { return }
        if isPrototypeRecord {
            // The demo session is not a stored record; never persist its fabricated sets.
            withAnimation(NoopMotion.swap) { saved = true }
            try? await Task.sleep(nanoseconds: 600_000_000)
            navigation.back(or: .liftDetail)
            return
        }
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
                    importDoor(icon: .link, title: keySuffix == nil ? "Use your Hevy key" : "Hevy key · ••••\(keySuffix!)",
                               meta: "read-only, revocable in Hevy",
                               note: "The key is kept in this phone’s Keychain. This build does not fetch with it yet and never writes back to Hevy.") {
                        showKey = true
                    }
                }

                if showKey { keyCard }
                if flow.isReadingImport { readingCard }
                if let error = flow.importError { failureCard(error) }

                VStack(alignment: .leading, spacing: 9) {
                    NoopSectionLabel("Two things it does to your numbers")
                    Text("Hevy counts warm-ups in a set count. Noop does not: warm-up sets fold away and are left out of every figure a session states.")
                        .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.inkSoft).lineSpacing(4)
                    Text("Exercise names are matched to Noop’s own catalogue where they match, and kept exactly as the file wrote them where they do not. Nothing is renamed for you.")
                        .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.inkSoft).lineSpacing(4)
                }
                .padding(16).background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))

                Text("The file stays where it is. Noop reads it, writes its own rows only after review, and never modifies or deletes what you handed it.")
                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
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
    }

    private func importDoor(icon: NoopCanonicalGlyphName, title: String, meta: String,
                            note: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 13) {
                    NoopCanonicalGlyph(name: icon, size: 21, color: NoopHTMLColor.blue)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(NoopHTMLFont.sans(14.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                        Text(meta).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    NoopChevron()
                }
                Text(note).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
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
                    .font(NoopHTMLFont.sans(11.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.copy)
                    .buttonStyle(.plain)
                }
            }
            SecureField("Paste the read-only key", text: $keyDraft)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.ink)
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
                Text(keyMessage).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy)
            }
        }
        .padding(16).background(NoopHTMLColor.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(NoopHTMLColor.blue.opacity(0.24), lineWidth: 0.5))
    }

    private var readingCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack { NoopSectionLabel("Reading the file", color: NoopHTMLColor.blueLight); Spacer()
                Text("on this phone").font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy) }
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.07))
                    .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 3).fill(NoopHTMLColor.blue).frame(width: proxy.size.width * 0.72) }
            }.frame(height: 6)
            Text("Reading does not write anything. Nothing is added until you have seen what it found.")
                .font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(3)
        }
        .padding(16).background(NoopHTMLColor.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(NoopHTMLColor.blue.opacity(0.24), lineWidth: 0.5))
    }

    private func failureCard(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The file stopped here").font(NoopHTMLFont.sans(13.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
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
                Text(text).font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.inkSoft)
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
    @State private var prototypeCommitted = false

    private var isPrototypeImport: Bool {
        NoopContentPolicy.allowsPrototypeContent && flow.importResult == nil
    }

    private var result: LiftingImportResult? {
        if let result = flow.importResult { return result }
        if isPrototypeImport { return demoImportResult }
        return nil
    }

    var body: some View {
        NoopScreen(bottomInset: 40, topInset: 58) {
            VStack(alignment: .leading, spacing: 14) {
                NoopLiftSheetHeader(label: "Import", trailing: nil) { navigation.back(or: .liftImport) }
                if flow.importCommitted || prototypeCommitted {
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
                                if isPrototypeImport {
                                    // Screenshot fixtures simulate the transition without importing fake rows.
                                    prototypeCommitted = true
                                } else {
                                    _ = await flow.commitImport(repo: repo)
                                }
                                committing = false
                            }
                        }
                        Button("Not now") { navigation.back(or: .liftLibrary) }
                            .font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                            .buttonStyle(.plain).frame(maxWidth: .infinity).frame(height: 46)
                    }
                    Text("Adding uses the dates in the file. Running the same import twice does not double a session already in your record.")
                        .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
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
                       sub: isPrototypeImport ? "by name, where the name matched" : "the current importer does not expose a defensible count",
                       value: isPrototypeImport ? "206" : "—")
            summaryRow("Names kept as the file wrote them",
                       sub: isPrototypeImport ? "no match, so nothing was renamed" : "no match count is available from this export summary",
                       value: isPrototypeImport ? "14" : "—")
            summaryRow("Warm-up sets folded away",
                       sub: isPrototypeImport ? "out of every figure a session states" : "excluded by the parser; source count is not exposed",
                       value: isPrototypeImport ? "96" : "—")
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private func summaryRow(_ title: String, sub: String, value: String, first: Bool = false) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.ink)
                Text(sub).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text(value).font(NoopHTMLFont.outfit(20, weight: .regular)).foregroundStyle(NoopHTMLColor.blueLight)
        }
        .frame(minHeight: 52).padding(.vertical, 6)
        .overlay(alignment: .top) { if !first { Rectangle().fill(Color.white.opacity(0.055)).frame(height: 0.5) } }
    }

    private func newest(_ result: LiftingImportResult) -> some View {
        let recent = Array(result.sessions.suffix(5).reversed())
        return VStack(alignment: .leading, spacing: 10) {
            HStack { NoopSectionLabel("The newest of them"); Spacer()
                Text("from the file").font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82)) }
            ForEach(Array(recent.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 11) {
                    Text(item.start.noopLiftDay).font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82)).frame(width: 52, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title?.isEmpty == false ? item.title! : "Untitled")
                            .font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.ink)
                        Text("\(item.exerciseCount) exercises · \(item.setCount) working sets" + (item.durationS.map { " · \(Int($0 / 60)) min" } ?? ""))
                            .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                    }
                    Spacer()
                    Text("from the file")
                        .font(NoopHTMLFont.sans(10, weight: .semibold)).foregroundStyle(NoopHTMLColor.copy)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
                .padding(.vertical, 10)
                .overlay(alignment: .top) { if index > 0 { Rectangle().fill(Color.white.opacity(0.055)).frame(height: 0.5) } }
            }
            Text("There is nothing to tick here. The importer produces whole sessions with no reference back to each source row, so Noop cannot honestly claim a reconstructed line is the exact line it read.")
                .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
                .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private func skipped(_ result: LiftingImportResult) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Some rows could not become sessions")
                .font(NoopHTMLFont.sans(13.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
            HStack { Text("No readable date or no countable set")
                    .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.inkSoft)
                Spacer(); Text("\(result.skipped)").font(NoopHTMLFont.sans(12.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink) }
            Text("A skipped row stays in the file; it is never half-added to your record.")
                .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(3)
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
                    Text("Sessions added").font(NoopHTMLFont.sans(14, weight: .semibold)).foregroundStyle(Color(hex: 0xA8E0B0))
                    Text("They are in your record, dated when they happened. Everything that reads your history can use them now.")
                        .font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.inkSoft).lineSpacing(3)
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
                    .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.inkSoft)
                    .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            }
            NoopLiftActionButton(title: "Choose another file", accent: false) { navigation.back(or: .liftImport) }
        }
    }

    private func dateSpan(_ result: LiftingImportResult) -> String {
        if isPrototypeImport { return "12 March to 14 September" }
        guard let first = result.earliest, let last = result.latest else { return "dates unavailable" }
        if Calendar.current.isDate(first, inSameDayAs: last) { return first.formatted(date: .abbreviated, time: .omitted) }
        return "\(first.formatted(date: .abbreviated, time: .omitted)) to \(last.formatted(date: .abbreviated, time: .omitted))"
    }

    private var demoImportResult: LiftingImportResult {
        let calendar = Calendar(identifier: .gregorian)
        func day(_ month: Int, _ value: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: month, day: value, hour: 18))!
        }
        func session(_ date: Date, _ title: String, _ exercises: Int, _ sets: Int, _ minutes: Int) -> LiftingSession {
            LiftingSession(start: date, end: date.addingTimeInterval(Double(minutes * 60)),
                           volumeLoadKg: 0, setCount: sets, exerciseCount: exercises,
                           totalReps: 0, topSetKg: nil, title: title)
        }
        let first = day(3, 12)
        var sessions = (0..<33).map { index in
            session(first.addingTimeInterval(Double(index * 4 * 86_400)),
                    index.isMultiple(of: 2) ? "Upper A" : "Lower A", 5, 14, 58)
        }
        sessions += [
            session(day(9, 4), "Lower A", 4, 12, 49),
            session(day(9, 7), "Untitled", 3, 9, 38),
            session(day(9, 9), "Upper B", 6, 18, 71),
            session(day(9, 12), "Lower A", 4, 13, 54),
            session(day(9, 14), "Upper A", 5, 16, 62),
        ]
        return LiftingImportResult(sessions: sessions, skipped: 0,
                                   earliest: first, latest: day(9, 14))
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
    private static let demoCredits: [String: Double] = [
        "chest": 7, "upper_chest": 4.5, "lower_chest": 2.5,
        "front_delts": 5.5, "side_delts": 4, "rear_delts": 2,
        "triceps": 5, "biceps": 1.5, "forearms": 0.5,
        "lats": 3, "upper_back": 1.5, "rhomboids": 1.5, "traps": 1,
        "upper_traps": 0.5, "lower_traps": 0.5,
        "abdominals": 0.5, "serratus": 0.5,
    ]

    private var workingSets: [LiftSetRow] { weekSets.filter { !$0.isWarmup } }
    private var uniqueExercises: [String] { Array(Set(workingSets.map(\.exercise))).sorted() }
    private var unresolvedExercises: [String] {
        uniqueExercises.filter { ExerciseAnatomyCatalog.resolve(title: $0) == nil }
    }
    private var isDemo: Bool { NoopContentPolicy.allowsPrototypeContent && flow.sessions.isEmpty }
    private var isAbsent: Bool { loaded && workingSets.isEmpty }
    private var isCalibrating: Bool {
        loaded && !workingSets.isEmpty && (weekSessionCount < 5 || !unresolvedExercises.isEmpty)
    }
    private var credits: [String: Double] {
        if isDemo { return Self.demoCredits }
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
                                        recoveryRead: isDemo ? demoRecovery(for: region) : nil)
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
                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy.opacity(0.82))
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
                .font(NoopHTMLFont.sans(12.5)).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private var calibratingCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(weekSessionCount) \(weekSessionCount == 1 ? "session" : "sessions") recorded")
                    .font(NoopHTMLFont.sans(13.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                Spacer()
                Text("still learning").font(NoopHTMLFont.sans(11, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.blueLight).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(NoopHTMLColor.blue.opacity(0.13), in: RoundedRectangle(cornerRadius: 7))
            }
            Text(calibratingReason).font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.inkSoft)
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
                Text(regionName(group.region)).font(NoopHTMLFont.sans(13.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                Spacer()
                Text(group.total > 0 ? "\(creditString(group.total)) credited" : "nothing this week")
                    .font(NoopHTMLFont.sans(11.5, weight: .semibold))
                    .foregroundStyle(group.total > 0 ? NoopHTMLColor.blueLight : NoopHTMLColor.muted)
            }
            VStack(spacing: 9) { ForEach(group.muscles) { muscleRow($0) } }
            if let read = group.recoveryRead, !read.isEmpty {
                Text(read).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.nightLight)
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
            Text(muscle.name).font(NoopHTMLFont.sans(12.5))
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
                .font(NoopHTMLFont.sans(12)).foregroundStyle(value > 0 ? NoopHTMLColor.inkSoft : NoopHTMLColor.copy)
                .monospacedDigit().frame(width: 26, alignment: .trailing)
        }
    }

    private var provenanceCard: some View {
        let mapped = uniqueExercises.count - unresolvedExercises.count
        return VStack(alignment: .leading, spacing: 9) {
            NoopSectionLabel("Where the mapping comes from")
            Text(isDemo
                 ? "Nineteen of this week’s twenty-four exercises carry a muscle mapping someone checked by hand. Five fall back to the catalogue’s own, which is usually right and occasionally generous about what a movement uses. They are named so a number you doubt can be traced."
                 : "Each credited exercise is resolved through Noop’s reviewed local anatomy catalogue. An exercise without an unambiguous mapping is withheld rather than guessed.")
                .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.inkSoft)
                .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                provenanceChip(isDemo ? "19 checked" : "\(mapped) checked", highlighted: true)
                provenanceChip(isDemo ? "5 from the catalogue" : "0 fallbacks")
                provenanceChip("0 you confirmed")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private func provenanceChip(_ text: String, highlighted: Bool = false) -> some View {
        Text(text).font(NoopHTMLFont.sans(10, weight: .semibold))
            .foregroundStyle(highlighted ? NoopHTMLColor.blueLight : NoopHTMLColor.copy)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(highlighted ? NoopHTMLColor.blue.opacity(0.13) : Color.white.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 6))
    }

    private var absentCard: some View {
        Text("No lifting on record. This screen fills itself the first time you finish a session — there is nothing to set up and nothing to connect.")
            .font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.copy)
            .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private func loadWeek() async {
        await flow.refresh(repo: repo)
        if NoopContentPolicy.allowsPrototypeContent && flow.sessions.isEmpty {
            weekSets = NoopLiftDemo.detailSets
            weekSessionCount = 6
            loaded = true
            return
        }
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

    private func demoRecovery(for region: TrainingBodyRegion) -> String? {
        switch region {
        case .chest: return "Worked hard. Recovered by Thursday morning."
        case .shoulders: return "Worked. Nothing owed by tomorrow."
        case .back: return "Light this week — one pulling line in six."
        case .legs: return "Nothing this week. Monday’s ride is the only thing your legs have had."
        default: return nil
        }
    }
}

#endif
