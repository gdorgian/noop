#if os(iOS)
import Foundation
import Security
import StrandImport
import StrandTraining
import WhoopStore

/// Hevy, kept in step with Noop through the wearer's own API key (Hevy Pro).
///
/// Noop stays the record. Hevy workouts arrive as full Noop lift sessions, every exercise and set, under
/// Noop's own exercise names where the catalogue knows them, so records, muscle load and volume count them
/// like a session logged here. Edits and deletions in Hevy follow on the next sync (its change feed). Body
/// measurements land in Body; routines are offered and copied into Programs on request. Optionally, sessions
/// logged in Noop are sent to Hevy, and are never brought back as a second copy.
///
/// Each workout is one session keyed by Hevy's id ("hevy-<id>"), and its summary row shares the CSV import's
/// key (start time under "lifting"), so a session imported once from a CSV export and again here is one
/// session. A Hevy workout that overlaps a session already logged in Noop is left out: the wearer logged it
/// twice, and Noop's own copy (with live heart rate) is the one kept.
@MainActor
final class HevySync: ObservableObject {
    static let shared = HevySync()

    enum Phase: Equatable {
        case idle
        case working(String)
        case done(String)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var account: String?
    @Published private(set) var lastSync: Date?
    @Published private(set) var sessionCount = 0
    @Published private(set) var routines: [HevyAPI.Routine] = []
    @Published var sendSessions: Bool { didSet { d.set(sendSessions, forKey: K.send) } }
    @Published var bringBody: Bool { didSet { d.set(bringBody, forKey: K.body) } }

    var hasKey: Bool { Keychain.read() != nil }
    var isBusy: Bool { if case .working = phase { return true } else { return false } }

    private let d = UserDefaults.standard
    private enum K {
        static let account = "hevy.account"
        static let lastSync = "hevy.lastSync"
        static let send = "hevy.sendSessions"
        static let body = "hevy.bringBody"
        /// Hevy id → session start, so a deletion can find the summary row it must remove.
        static let index = "hevy.index"
        /// Noop session id → the Hevy id it was sent as, so the change feed never brings it back.
        static let sent = "hevy.sent"
        /// Normalised exercise name → Hevy template id created for it.
        static let customTemplates = "hevy.customTemplates"
    }

    private var templates: [String: HevyAPI.ExerciseTemplate] = [:]

    private init() {
        sendSessions = d.object(forKey: K.send) as? Bool ?? false
        bringBody = d.object(forKey: K.body) as? Bool ?? true
        account = d.string(forKey: K.account)
        lastSync = d.object(forKey: K.lastSync) as? Date
        sessionCount = index.count
    }

    // MARK: - Connect

    /// Check the key against Hevy, keep it in the Keychain, then bring everything across.
    func connect(key: String, repo: Repository) async -> Bool {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return false }
        phase = .working("Checking the key")
        do {
            let data = try await get("/v1/user/info", key: clean)
            guard let user = HevyAPI.parseUserInfo(data: data) else {
                phase = .failed("Hevy answered, but not with an account. Check the key and try again.")
                return false
            }
            guard Keychain.save(clean) else {
                phase = .failed("The key could not be stored on this phone.")
                return false
            }
            account = user.name ?? "your Hevy account"
            d.set(account, forKey: K.account)
            // The key check is done: leave its working phase, or `sync` sees a sync already running and
            // returns at once, and a first connect brought nothing across while the sheet said Syncing.
            phase = .idle
            await sync(repo: repo)
            return true
        } catch {
            phase = .failed(Self.message(for: error))
            return false
        }
    }

    /// Forget the key. Sessions already brought across stay unless `removeImported`.
    func disconnect(removeImported: Bool, repo: Repository) async {
        Keychain.clear()
        if removeImported, let store = await repo.storeHandle() {
            for (id, start) in index {
                _ = try? await store.deleteLiftSession(id: Self.sessionId(id))
                _ = try? await store.deleteWorkouts(deviceId: LiftingImporter.sourceId,
                                                    sport: LiftingImporter.sport, from: start, to: start)
            }
            index = [:]
            await repo.refresh()
        }
        for key in [K.account, K.lastSync, K.sent] { d.removeObject(forKey: key) }
        account = nil
        lastSync = nil
        routines = []
        sessionCount = index.count
        phase = .idle
    }

    // MARK: - Sync

    /// Sync when the last one is more than `gap` old. Called on every foreground.
    func syncIfDue(repo: Repository, gap: TimeInterval = 15 * 60) async {
        guard hasKey, !isBusy else { return }
        if let lastSync, Date().timeIntervalSince(lastSync) < gap { return }
        await sync(repo: repo, quiet: true)
    }

    /// Bring Hevy's changes in, then send Noop's new sessions out when that is on.
    func sync(repo: Repository, quiet: Bool = false) async {
        guard let key = Keychain.read(), !isBusy, let store = await repo.storeHandle() else { return }
        let started = Date()
        if !quiet { phase = .working("Reading Hevy") }
        do {
            try await loadTemplates(key: key)
            var added = 0, removed = 0
            if let since = lastSync {
                // The change feed: updates and deletions since the last sync, with a minute of overlap.
                var page = 1
                repeat {
                    let data = try await get("/v1/workouts/events", key: key, query: [
                        "page": "\(page)", "pageSize": "10",
                        "since": ISO8601DateFormatter().string(from: since.addingTimeInterval(-60))])
                    let changes = HevyAPI.parseWorkoutChanges(data: data)
                    for change in changes.items {
                        switch change {
                        case .updated(let w): if try await save(w, store: store, repo: repo) { added += 1 }
                        case .deleted(let id): if try await remove(id, store: store) { removed += 1 }
                        }
                    }
                    if !changes.hasMore { break }
                    page += 1
                } while page <= 500
            } else {
                // The first sync reads the whole history, ten workouts a page.
                var page = 1
                repeat {
                    if !quiet { phase = .working(page == 1 ? "Reading your workouts" : "Reading your workouts · page \(page)") }
                    let data = try await get("/v1/workouts", key: key, query: ["page": "\(page)", "pageSize": "10"])
                    let workouts = HevyAPI.parseWorkouts(data: data)
                    for w in workouts.items {
                        if try await save(w, store: store, repo: repo) { added += 1 }
                    }
                    if !workouts.hasMore { break }
                    page += 1
                } while page <= 1_000
            }
            var measured = 0
            if bringBody { measured = try await syncBody(key: key, store: store, repo: repo) }
            var sent = 0
            if sendSessions { sent = try await sendNew(key: key, store: store, repo: repo) }
            lastSync = started
            d.set(started, forKey: K.lastSync)
            sessionCount = index.count
            if added + removed + measured > 0 {
                NoopFitnessModel.markChanged()
                await repo.refresh()
            }
            var parts: [String] = []
            if added > 0 { parts.append(added == 1 ? "1 workout in" : "\(added) workouts in") }
            if removed > 0 { parts.append("\(removed) removed") }
            if measured > 0 { parts.append(measured == 1 ? "1 measurement" : "\(measured) measurements") }
            if sent > 0 { parts.append(sent == 1 ? "1 session sent" : "\(sent) sessions sent") }
            phase = .done(parts.isEmpty ? "Up to date" : parts.joined(separator: " · "))
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    // MARK: - Workouts in

    /// Store one Hevy workout as a Noop session. False when it was left out.
    private func save(_ w: HevyAPI.Workout, store: WhoopStore, repo: Repository) async throws -> Bool {
        // Sent from Noop: it is already here.
        if sentIds.contains(w.id) { return false }
        let start = Int(w.start.timeIntervalSince1970), end = Int(w.end.timeIntervalSince1970)
        // Logged twice: Noop's own session stands.
        let nearby = (try? await store.liftSessions(deviceId: repo.deviceId, fromTs: start - 30 * 60, toTs: end)) ?? []
        if nearby.contains(where: { !$0.id.hasPrefix("hevy-") && abs($0.startTs - start) < 30 * 60 }) { return false }

        let sessionId = Self.sessionId(w.id)
        var rows: [LiftSetRow] = []
        var ord = 0
        var volume = 0.0, reps = 0, topSet: Double?
        for e in w.exercises {
            let name = Self.noopName(e.title)
            let muscles = muscles(for: e)
            var setIndex = 0
            for s in e.sets {
                rows.append(LiftSetRow(
                    id: "\(sessionId)-\(ord)", deviceId: repo.deviceId, sessionId: sessionId, ord: ord,
                    exercise: name, primaryMuscle: muscles.primary, secondaryMuscles: muscles.secondary,
                    setIndex: setIndex, weightKg: s.weightKg, reps: s.reps, rpe: s.rpe, isWarmup: s.isWarmup,
                    startTs: nil, endTs: nil, restSec: nil,
                    note: setIndex == 0 ? e.notes : nil,
                    setKind: s.type == "dropset" ? .drop : s.type == "failure" ? .failure : nil))
                ord += 1
                setIndex += 1
                if !s.isWarmup, let kg = s.weightKg, let r = s.reps {
                    volume += kg * Double(r); reps += r
                    topSet = max(topSet ?? 0, kg)
                }
            }
        }
        guard !rows.isEmpty else { return false }
        _ = try await store.upsertLiftSessions([LiftSessionRow(
            id: sessionId, deviceId: repo.deviceId, startTs: start, endTs: end, sport: LiftingImporter.sport,
            programId: nil, programName: w.title, sessionRpe: nil,
            note: ["From Hevy", w.description].compactMap { $0 }.joined(separator: " · "))])
        _ = try await store.replaceLiftSessionSets(sessionId: sessionId, rows: rows)
        let working = rows.filter { !$0.isWarmup }.count
        let summary = LiftingSession(start: w.start, end: w.end, volumeLoadKg: volume, setCount: working,
                                     exerciseCount: w.exercises.count, totalReps: reps, topSetKg: topSet,
                                     title: w.title)
        // An edit that moved the start leaves the old summary row behind: remove it first.
        if let old = index[w.id], old != start {
            _ = try? await store.deleteWorkouts(deviceId: LiftingImporter.sourceId, sport: LiftingImporter.sport,
                                                from: old, to: old)
        }
        try await store.upsertWorkouts([WorkoutRow(
            startTs: start, endTs: end, sport: LiftingImporter.sport, source: LiftingImporter.sourceId,
            durationS: Double(end - start), energyKcal: nil, avgHr: nil, maxHr: nil, strain: nil,
            distanceM: nil, zonesJSON: nil, notes: summary.volumeLoadNote(), steps: nil)],
            deviceId: LiftingImporter.sourceId)
        index[w.id] = start
        return true
    }

    private func remove(_ id: String, store: WhoopStore) async throws -> Bool {
        guard let start = index[id] else { return false }
        _ = try await store.deleteLiftSession(id: Self.sessionId(id))
        _ = try await store.deleteWorkouts(deviceId: LiftingImporter.sourceId, sport: LiftingImporter.sport,
                                           from: start, to: start)
        index[id] = nil
        return true
    }

    // MARK: - Body

    private func syncBody(key: String, store: WhoopStore, repo: Repository) async throws -> Int {
        var rows: [BodyMeasurementRow] = []
        var page = 1
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        repeat {
            let data = try await get("/v1/body_measurements", key: key, query: ["page": "\(page)", "pageSize": "10"])
            let entries = HevyAPI.parseBodyMeasurements(data: data)
            for m in entries.items {
                // Noon of the day it names: a bare date has no time, and noon never crosses into a neighbour.
                guard let day = f.date(from: m.date) else { continue }
                let ts = Int(day.addingTimeInterval(12 * 3600).timeIntervalSince1970)
                func add(_ kind: BodyMeasurementKind, _ value: Double?) {
                    guard let value else { return }
                    rows.append(BodyMeasurementRow(id: "hevy-\(m.date)-\(kind.rawValue)", deviceId: repo.deviceId,
                                                   ts: ts, kind: kind, value: value, note: "From Hevy"))
                }
                add(.weight, m.weightKg)
                add(.bodyFat, m.fatPercent)
                for (field, cm) in m.circumferencesCm {
                    if let kind = Self.bodyKind[field] { add(kind, cm) }
                }
            }
            if !entries.hasMore { break }
            page += 1
        } while page <= 100
        guard !rows.isEmpty else { return 0 }
        return try await store.upsertBodyMeasurements(rows)
    }

    private static let bodyKind: [String: BodyMeasurementKind] = [
        "neck_cm": .neck, "shoulder_cm": .shoulders, "chest_cm": .chest, "waist": .waist, "hips": .hips,
        "left_bicep_cm": .leftBicep, "right_bicep_cm": .rightBicep, "left_forearm_cm": .leftForearm,
        "right_forearm_cm": .rightForearm, "left_thigh": .leftThigh, "right_thigh": .rightThigh,
        "left_calf": .leftCalf, "right_calf": .rightCalf
    ]

    // MARK: - Routines

    /// Read the routines, for the wearer to choose which to copy.
    func loadRoutines() async {
        guard let key = Keychain.read() else { return }
        phase = .working("Reading your routines")
        do {
            var all: [HevyAPI.Routine] = []
            var page = 1
            repeat {
                let data = try await get("/v1/routines", key: key, query: ["page": "\(page)", "pageSize": "10"])
                let p = HevyAPI.parseRoutines(data: data)
                all += p.items
                if !p.hasMore { break }
                page += 1
            } while page <= 100
            routines = all
            phase = .done(all.isEmpty ? "No routines in Hevy" : all.count == 1 ? "1 routine" : "\(all.count) routines")
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    /// Copy routines into Programs. A second copy of the same routine replaces the first.
    func importRoutines(_ ids: Set<String>, repo: Repository) async -> Int {
        guard let store = await repo.storeHandle() else { return 0 }
        let now = Int(Date().timeIntervalSince1970)
        var count = 0
        for r in routines where ids.contains(r.id) {
            let programId = "hevy-routine-\(r.id)"
            let items = r.exercises.enumerated().map { i, e -> LiftProgramItemRow in
                let working = e.sets.filter { $0.type != "warmup" }
                let low = working.compactMap { $0.repRangeLow ?? $0.reps }.min()
                let high = working.compactMap { $0.repRangeHigh ?? $0.reps }.max()
                return LiftProgramItemRow(
                    id: "\(programId)-\(i)", deviceId: repo.deviceId, programId: programId, ord: i,
                    exercise: Self.noopName(e.title), targetSets: working.isEmpty ? nil : working.count,
                    targetRepsLow: low, targetRepsHigh: high, targetRpe: nil,
                    targetWeightKg: working.compactMap(\.weightKg).max(), restSec: e.restSeconds, note: e.notes)
            }
            do {
                try await store.saveLiftProgram(LiftProgramRow(id: programId, deviceId: repo.deviceId, name: r.title,
                                                               note: "From Hevy", createdAt: now, updatedAt: now,
                                                               archived: false), items: items)
                count += 1
            } catch { continue }
        }
        if count > 0 { NoopFitnessModel.markChanged() }
        phase = .done(count == 1 ? "1 routine added to Programs" : "\(count) routines added to Programs")
        return count
    }

    // MARK: - Sessions out

    /// Send Noop sessions finished since the switch went on, once each.
    private func sendNew(key: String, store: WhoopStore, repo: Repository) async throws -> Int {
        let since = d.object(forKey: K.send + ".since") as? Int ?? {
            let now = Int(Date().timeIntervalSince1970)
            d.set(now, forKey: K.send + ".since")
            return now
        }()
        let sessions = try await store.liftSessions(deviceId: repo.deviceId, fromTs: since,
                                                    toTs: Int(Date().timeIntervalSince1970))
        var sent = sentMap
        var count = 0
        for s in sessions where !s.id.hasPrefix("hevy-") && sent[s.id] == nil {
            guard let end = s.endTs else { continue }
            let sets = try await store.liftSets(sessionId: s.id)
            var exercises: [HevyAPI.OutgoingExercise] = []
            for name in sets.map(\.exercise).uniqued() {
                guard let template = try await templateId(for: name, sets: sets, key: key) else { continue }
                let mine = sets.filter { $0.exercise == name }.sorted { $0.ord < $1.ord }
                exercises.append(.init(templateId: template, notes: mine.first?.note, sets: mine.map {
                    .init(type: $0.isWarmup ? "warmup" : $0.setKind == .drop ? "dropset" : $0.setKind == .failure ? "failure" : "normal",
                          weightKg: $0.weightKg, reps: $0.reps, durationSeconds: nil, rpe: $0.rpe)
                }))
            }
            guard !exercises.isEmpty,
                  let body = HevyAPI.workoutBody(title: s.programName ?? "Noop session", description: "Logged in Noop",
                                                 start: Date(timeIntervalSince1970: TimeInterval(s.startTs)),
                                                 end: Date(timeIntervalSince1970: TimeInterval(end)),
                                                 exercises: exercises) else { continue }
            let response = try await send("POST", "/v1/workouts", key: key, body: body)
            let created = HevyAPI.parseWorkouts(data: response).items.first
                ?? (try? JSONSerialization.jsonObject(with: response) as? [String: Any]).flatMap {
                    ($0["workout"] as? [String: Any]).flatMap { HevyAPI.workout(from: $0, zone: .current) }
                }
            sent[s.id] = created?.id ?? "sent"
            count += 1
        }
        sentMap = sent
        return count
    }

    /// The Hevy template for a Noop exercise: Hevy's own when a title matches, else one created once.
    private func templateId(for name: String, sets: [LiftSetRow], key: String) async throws -> String? {
        let want = ExerciseAnatomyCatalog.normalize(name)
        if let match = templates.values.first(where: {
            ExerciseAnatomyCatalog.normalize($0.title) == want
                || ExerciseAnatomyCatalog.normalize(HevyAPI.equipmentFirst($0.title)) == want
                || Self.noopName($0.title) == name
        }) { return match.id }
        var custom = d.dictionary(forKey: K.customTemplates) as? [String: String] ?? [:]
        if let id = custom[want] { return id }
        let muscle = sets.first { $0.exercise == name }?.primaryMuscle
        let body: [String: Any] = ["exercise": [
            "title": name, "exercise_type": "weight_reps", "equipment_category": "other",
            "muscle_group": Self.hevyMuscle(muscle), "other_muscles": [String]()]]
        let data = try await send("POST", "/v1/exercise_templates", key: key,
                                  body: try JSONSerialization.data(withJSONObject: body))
        let id = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]).flatMap {
            ($0["id"] as? String) ?? (($0["exercise_template"] as? [String: Any])?["id"] as? String)
        } ?? String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet(charactersIn: "\" \n"))
        guard let id, !id.isEmpty, !id.contains("{") else { return nil }
        custom[want] = id
        d.set(custom, forKey: K.customTemplates)
        return id
    }

    // MARK: - Templates and names

    private func loadTemplates(key: String) async throws {
        guard templates.isEmpty else { return }
        var page = 1
        repeat {
            let data = try await get("/v1/exercise_templates", key: key, query: ["page": "\(page)", "pageSize": "100"])
            let p = HevyAPI.parseExerciseTemplates(data: data)
            for t in p.items { templates[t.id] = t }
            if !p.hasMore { break }
            page += 1
        } while page <= 60
    }

    /// Noop's own name for a Hevy exercise when the catalogue knows it, so its history and records join the
    /// ones logged here; Hevy's title when it does not.
    static func noopName(_ hevyTitle: String) -> String {
        ExerciseAnatomyCatalog.resolve(title: HevyAPI.equipmentFirst(hevyTitle))?.title
            ?? ExerciseAnatomyCatalog.resolve(title: hevyTitle)?.title
            ?? hevyTitle
    }

    private func muscles(for e: HevyAPI.WorkoutExercise) -> (primary: LiftMuscle?, secondary: [LiftMuscle]) {
        if let t = e.templateId.flatMap({ templates[$0] }) {
            return (t.primaryMuscleGroup.flatMap(Self.liftMuscle), t.secondaryMuscleGroups.compactMap(Self.liftMuscle))
        }
        return (nil, [])
    }

    private static func liftMuscle(_ g: HevyAPI.MuscleGroup) -> LiftMuscle? {
        switch g {
        case .chest: .chest
        case .shoulders: .frontDelts
        case .biceps: .biceps
        case .triceps: .triceps
        case .forearms: .forearms
        case .quadriceps: .quads
        case .hamstrings: .hamstrings
        case .calves: .calves
        case .glutes: .glutes
        case .abductors: .abductors
        case .adductors: .adductors
        case .lats: .lats
        case .upperBack: .upperBack
        case .traps: .traps
        case .lowerBack: .lowerBack
        case .abdominals: .abs
        case .neck: .neck
        case .cardio, .fullBody, .other: nil
        }
    }

    private static func hevyMuscle(_ m: LiftMuscle?) -> String {
        switch m {
        case .chest: "chest"
        case .frontDelts, .sideDelts, .rearDelts: "shoulders"
        case .triceps: "triceps"
        case .biceps: "biceps"
        case .forearms: "forearms"
        case .lats: "lats"
        case .upperBack: "upper_back"
        case .traps: "traps"
        case .quads: "quadriceps"
        case .hamstrings: "hamstrings"
        case .glutes: "glutes"
        case .adductors: "adductors"
        case .abductors: "abductors"
        case .calves: "calves"
        case .abs, .obliques: "abdominals"
        case .lowerBack: "lower_back"
        case .neck: "neck"
        default: "other"
        }
    }

    static func sessionId(_ hevyId: String) -> String { "hevy-\(hevyId)" }

    // MARK: - Stored maps

    private var index: [String: Int] {
        get { d.dictionary(forKey: K.index) as? [String: Int] ?? [:] }
        set { d.set(newValue, forKey: K.index) }
    }

    private var sentMap: [String: String] {
        get { d.dictionary(forKey: K.sent) as? [String: String] ?? [:] }
        set { d.set(newValue, forKey: K.sent) }
    }

    private var sentIds: Set<String> { Set(sentMap.values) }

    // MARK: - Transport

    private enum Failure: Error { case status(Int), offline }

    /// Hevy's API. A Debug build may point it at a local stand-in with `--hevy-base-url <url>`, so the
    /// whole sync can be exercised without a real account; Release always talks to Hevy.
    private static let baseURL: String = {
        #if DEBUG
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--hevy-base-url"), args.indices.contains(i + 1) { return args[i + 1] }
        #endif
        return "https://api.hevyapp.com"
    }()

    private func get(_ path: String, key: String, query: [String: String] = [:]) async throws -> Data {
        try await send("GET", path, key: key, query: query)
    }

    private func send(_ method: String, _ path: String, key: String, query: [String: String] = [:],
                      body: Data? = nil) async throws -> Data {
        var components = URLComponents(string: Self.baseURL + path)
        if !query.isEmpty { components?.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        guard let url = components?.url else { throw Failure.offline }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        request.setValue(key, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        // One retry after a pause on a rate limit, which a first full sync of a long history can meet.
        for attempt in 0..<2 {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 429, attempt == 0 { try await Task.sleep(nanoseconds: 3_000_000_000); continue }
            guard (200..<300).contains(status) else { throw Failure.status(status) }
            return data
        }
        throw Failure.status(429)
    }

    private static func message(for error: Error) -> String {
        switch error {
        case Failure.status(401), Failure.status(403):
            return "Hevy did not accept that key. Check it was copied whole, or make a new one in Hevy › Settings › Developer."
        case Failure.status(429): return "Hevy asked Noop to slow down. Try again in a minute."
        case Failure.status(let code) where code >= 500: return "Hevy is not answering right now. Try again later."
        case Failure.status(let code): return "Hevy turned the request down (\(code))."
        default: return "Hevy could not be reached. Check the connection and try again."
        }
    }

    // MARK: - Keychain

    /// The same item the import screen saved a key under before, so a key entered there carries over.
    private enum Keychain {
        static let service = (Bundle.main.bundleIdentifier ?? "com.noopapp.noop") + ".hevy"
        static let account = "read-only-api-key"
        static var query: [String: Any] {
            [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
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
            guard let data = value.data(using: .utf8) else { return false }
            SecItemDelete(query as CFDictionary)
            var attributes = query
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
        }
        static func clear() { SecItemDelete(query as CFDictionary) }
    }
}

private extension Array where Element: Hashable {
    /// Elements in first-seen order, each once.
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
#endif
