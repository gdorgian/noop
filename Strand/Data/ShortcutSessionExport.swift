import Foundation
import WhoopStore
import WhoopProtocol
import StrandImport

/// Session half of the Apple-Health-free export (the window half is `ShortcutHealthExport`).
///
/// `noop_sync.txt` carries the three *sampled* streams (HR / HRV / steps) as fixed 15-minute
/// windows. Sleep and workouts are **sessions** — an arbitrary span with a start and an end — so
/// they do not fit that positional 4-column row, and folding them in would either break every
/// existing Shortcut or force a prefix-branch inside a Shortcuts `Repeat` loop.
///
/// Instead this drops two SIBLING files next to it, each a trivial CSV a Shortcut can loop over
/// with no branching, and each independently watermarked:
///
/// ```
/// noop_sleep.txt      stage,start,end                       → Log Health Sample: Sleep Analysis
/// noop_workouts.txt   sport,start,end,kcal,avgHr,maxHr,m    → Log Health Sample / Log Workout
/// ```
///
/// `noop_sync.txt` is untouched, so an install that already has the reporter's pre-built Shortcut
/// keeps working unchanged and can adopt these two at its own pace.
///
/// **Timestamps are `yyyy-MM-dd HH:mm:ss`, not the window file's `HH:mm`.** Stage boundaries land on
/// the stager's 30-second hypnogram grid; truncating them to whole minutes collapses short segments
/// to zero length and makes adjacent ones overlap, both of which Health rejects or mis-renders.
/// en_US_POSIX, LOCAL zone — same contract as the window file otherwise.
///
/// **Sources.** Sleep sessions and detected workouts are NOOP-*computed* rows, so they live under the
/// `"\(deviceId)-noop"` computed sibling, NOT the raw strap id `ShortcutHealthExport` reads. This
/// reads BOTH (a strap row can exist for imported nights) and de-dupes on the natural key. It never
/// reads `apple-health` — a Shortcut-logged value must not round-trip back in on the next import.
enum ShortcutSessionExport {

    /// Shares the window exporter's single opt-in toggle: one switch, all three files.
    static let enabledKey = ShortcutHealthExport.enabledKey
    /// Highest `startTs` the Shortcut has CONFIRMED it logged, per stream. Advances only on
    /// `confirm(...)` — see `ShortcutHealthExport.pendingKey` for why a write must not advance it.
    static let sleepWatermarkKey = "noop.shortcutSync.lastSleepStartTs"
    static let workoutWatermarkKey = "noop.shortcutSync.lastWorkoutStartTs"
    /// Highest `startTs` the last successful write PUT IN THE FILE, awaiting confirmation.
    static let sleepPendingKey = "noop.shortcutSync.pendingSleepStartTs"
    static let workoutPendingKey = "noop.shortcutSync.pendingWorkoutStartTs"

    static let sleepFileName = "noop_sleep.txt"
    static let workoutFileName = "noop_workouts.txt"
    /// Per-night vitals that are single values rather than spans or samples — `metric,value,start,end`.
    ///
    /// One generic file rather than one file per metric: the Shortcut loops it once and branches on the
    /// metric name, and a new vital costs a row type instead of a new file and a new loop. Values are
    /// anchored to the SLEEP SESSION they describe, because that is the window they were measured over —
    /// Apple Health wants an interval, and a bare day would place a night's respiration at midnight.
    static let vitalsFileName = "noop_vitals.txt"

    /// Metric labels used in `noop_vitals.txt`. Stable strings — a Shortcut matches on them.
    enum Vital: String {
        /// Breaths per minute during sleep, estimated on-device from the R-R stream (RSA). The 5.0 sends
        /// no raw respiration channel, so this is the only respiration NOOP has — and it is real, not a
        /// placeholder. Maps to Apple Health's Respiratory Rate.
        case respiratoryRate = "respiratory_rate"
        /// Resting heart rate for the night, already carried on the sleep session.
        case restingHR = "resting_hr"
    }

    /// Catch-up bound, mirroring the window exporter: never reach further back than 7 days.
    static let lookbackSeconds = ShortcutHealthExport.lookbackSeconds
    /// A night is not exported until it has been over for this long.
    ///
    /// Sleep sessions are RE-STAGED as the strap's history keeps offloading after you wake: the
    /// session that exists at 07:00 can gain segments (or move its wake bound) by 09:00. The
    /// watermark is one-way, so exporting too eagerly would pin the *worse* version into Health
    /// forever. Two hours is long enough for the post-wake offload + restage to settle and still
    /// puts last night into Health mid-morning.
    static let settleSeconds = 2 * 3_600
    /// Sessions per read. Seven days is a handful of nights and a few dozen workouts; this never
    /// truncates a real span.
    static let readLimit = 10_000

    enum Outcome: Equatable {
        case written(sleepLines: Int, workoutLines: Int)
        case nothingNew
        case failure(String)
    }

    // MARK: - Entry points

    /// Background-transition hook, called next to `ShortcutHealthExport.writeIfEnabled`. No-op until
    /// the user opts in.
    @MainActor
    static func writeIfEnabled(repo: Repository) async {
        guard UserDefaults.standard.bool(forKey: enabledKey) else { return }
        _ = await writeNow(repo: repo)
    }

    @MainActor
    @discardableResult
    static func writeNow(repo: Repository) async -> Outcome {
        guard let store = await repo.storeHandle() else {
            return .failure("Couldn't open the local store.")
        }
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return .failure("No Documents directory.")
        }
        return await export(source: store, deviceId: repo.deviceId, now: Date(),
                            defaults: .standard, directory: docs, timeZone: .current)
    }

    /// Injectable core — store reads behind `ShortcutSessionReads`, clock/defaults/destination/zone
    /// as parameters — so the watermark and file semantics are unit-testable without a live DB.
    @discardableResult
    static func export(source: ShortcutSessionReads, deviceId: String, now: Date,
                       defaults: UserDefaults, directory: URL, timeZone: TimeZone) async -> Outcome {
        // Deletion IS acknowledgement — see the twin in `ShortcutHealthExport`. Checked per stream so a
        // Shortcut that consumes sleep but not workouts acks only what it took.
        acknowledgeDeletedFiles(defaults: defaults, directory: directory)

        let nowTs = Int(now.timeIntervalSince1970)
        let horizon = nowTs - settleSeconds
        let floor = nowTs - lookbackSeconds
        let ids = sourceIds(deviceId: deviceId)

        let sleepMark = defaults.integer(forKey: sleepWatermarkKey)
        let workoutMark = defaults.integer(forKey: workoutWatermarkKey)

        do {
            // Read from `floor` (not the watermark) and filter after: a session whose startTs sits
            // below the watermark but whose endTs only just cleared the settle horizon must still be
            // excluded by key, not silently re-read into a duplicate.
            var sleeps: [CachedSleepSession] = []
            var seenSleep = Set<String>()
            for id in ids {
                for s in try await source.sleepSessions(deviceId: id, from: floor, to: horizon,
                                                        limit: readLimit)
                where seenSleep.insert("\(s.startTs)|\(s.endTs)").inserted { sleeps.append(s) }
            }
            var workouts: [WorkoutRow] = []
            var seenWorkout = Set<String>()
            for id in ids {
                for w in try await source.workouts(deviceId: id, from: floor, to: horizon,
                                                   limit: readLimit)
                where seenWorkout.insert("\(w.startTs)|\(w.sport)").inserted { workouts.append(w) }
            }

            let freshSleep = selectSleep(sleeps, watermark: sleepMark, horizon: horizon)
            let freshWorkouts = selectWorkouts(workouts, watermark: workoutMark, horizon: horizon)

            // Per-night vitals ride the SLEEP selection: same sessions, same watermark, so a night's
            // respiration cannot be exported before (or after) the night it describes.
            var dailies: [DailyMetric] = []
            if let first = freshSleep.first, let last = freshSleep.last {
                let fromDay = dayString(first.effectiveStartTs, timeZone: timeZone)
                let toDay = dayString(last.endTs, timeZone: timeZone)
                for id in ids {
                    dailies += try await source.dailyMetrics(deviceId: id, from: fromDay, to: toDay)
                }
            }

            let sleepLines = renderSleep(freshSleep, timeZone: timeZone)
            let workoutLines = renderWorkouts(freshWorkouts, timeZone: timeZone)
            let vitalsLines = renderVitals(freshSleep, dailies: dailies, timeZone: timeZone)

            // Full-file replace even when empty. The Shortcut has no dedup and its automation fires on
            // every app close, so stale rows left behind would be re-logged into Health on the next
            // run (the #167 trade-off, applied to both sibling files).
            try Data(sleepLines.joined(separator: "\n").utf8)
                .write(to: directory.appendingPathComponent(sleepFileName), options: .atomic)
            try Data(workoutLines.joined(separator: "\n").utf8)
                .write(to: directory.appendingPathComponent(workoutFileName), options: .atomic)
            try Data(vitalsLines.joined(separator: "\n").utf8)
                .write(to: directory.appendingPathComponent(vitalsFileName), options: .atomic)

            // PENDING, not confirmed — only after both writes landed, and only to what we emitted.
            // `confirm(...)` promotes these once the Shortcut has logged the rows.
            if let newest = freshSleep.map(\.startTs).max() {
                defaults.set(newest, forKey: sleepPendingKey)
            }
            if let newest = freshWorkouts.map(\.startTs).max() {
                defaults.set(newest, forKey: workoutPendingKey)
            }

            if sleepLines.isEmpty && workoutLines.isEmpty { return .nothingNew }
            return .written(sleepLines: sleepLines.count, workoutLines: workoutLines.count)
        } catch {
            return .failure("Shortcut session export failed: \(error.localizedDescription)")
        }
    }

    /// Drop both watermarks so the next export re-emits the full 7-day window (e.g. after the user
    /// rebuilds their Shortcut or clears its Health entries). Mirrors
    /// `ShortcutHealthExport.resetWatermark`.
    static func resetWatermarks(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: sleepWatermarkKey)
        defaults.removeObject(forKey: workoutWatermarkKey)
        defaults.removeObject(forKey: sleepPendingKey)
        defaults.removeObject(forKey: workoutPendingKey)
    }

    /// The Shortcut has logged both files: promote pending → confirmed for each stream independently,
    /// so a night that logged does not wait on a workout that did not. Monotonic and no-op when nothing
    /// is pending, so a repeated confirm cannot skip a session.
    static func confirm(defaults: UserDefaults = .standard) {
        for (pendingKey, watermarkKey) in [(sleepPendingKey, sleepWatermarkKey),
                                           (workoutPendingKey, workoutWatermarkKey)] {
            let pending = defaults.integer(forKey: pendingKey)
            guard pending > 0 else { continue }
            if pending > defaults.integer(forKey: watermarkKey) {
                defaults.set(pending, forKey: watermarkKey)
            }
            defaults.removeObject(forKey: pendingKey)
        }
    }

    // MARK: - Pure logic

    /// The strap id and its NOOP-computed sibling, in a stable order. `apple-health` /
    /// `health-connect` are deliberately absent — see the type doc.
    static func sourceIds(deviceId: String) -> [String] { [deviceId, deviceId + "-noop"] }

    /// Promote pending → confirmed for any stream whose drop file the consumer has DELETED.
    ///
    /// A file that is gone was taken; a file still sitting there was not. Per stream, so a Shortcut that
    /// handles sleep but ignores workouts does not silently acknowledge the workouts it never read.
    static func acknowledgeDeletedFiles(defaults: UserDefaults, directory: URL) {
        let fm = FileManager.default
        for (file, pendingKey, watermarkKey) in [
            (sleepFileName, sleepPendingKey, sleepWatermarkKey),
            (workoutFileName, workoutPendingKey, workoutWatermarkKey),
        ] {
            let pending = defaults.integer(forKey: pendingKey)
            guard pending > 0,
                  !fm.fileExists(atPath: directory.appendingPathComponent(file).path) else { continue }
            if pending > defaults.integer(forKey: watermarkKey) {
                defaults.set(pending, forKey: watermarkKey)
            }
            defaults.removeObject(forKey: pendingKey)
        }
    }

    /// `metric,value,start,end` — one row per per-night vital, anchored to the sleep session it describes.
    ///
    /// Respiration comes from the day row (`respRateBpm`, the on-device RSA estimate); resting HR is
    /// already on the session. A vital with no value is simply not emitted — an absent row is honest,
    /// where a zero would be logged into Health as a real reading.
    static func renderVitals(_ sessions: [CachedSleepSession], dailies: [DailyMetric],
                             timeZone: TimeZone) -> [String] {
        let byDay = Dictionary(dailies.map { ($0.day, $0) }, uniquingKeysWith: { a, b in
            // Prefer whichever row actually carries a respiration value; ties keep the first source.
            a.respRateBpm != nil ? a : b
        })
        return sessions.flatMap { s -> [String] in
            let start = s.effectiveStartTs
            guard s.endTs > start else { return [] }
            let stamps = "\(stamp(start, timeZone)),\(stamp(s.endTs, timeZone))"
            var out: [String] = []
            if let resp = byDay[dayString(start, timeZone: timeZone)]?.respRateBpm {
                out.append("\(Vital.respiratoryRate.rawValue),\(String(format: "%.1f", resp)),\(stamps)")
            }
            if let rhr = s.restingHr {
                out.append("\(Vital.restingHR.rawValue),\(rhr),\(stamps)")
            }
            return out
        }
    }

    /// `yyyy-MM-dd` in the given zone — the key `dailyMetrics` rows are stored under.
    static func dayString(_ ts: Int, timeZone: TimeZone) -> String {
        dayFormatter.timeZone = timeZone
        return dayFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Sessions strictly newer than the watermark that have also finished settling, oldest first.
    static func selectSleep(_ all: [CachedSleepSession], watermark: Int,
                            horizon: Int) -> [CachedSleepSession] {
        all.filter { $0.startTs > watermark && $0.endTs <= horizon }
           .sorted { $0.startTs < $1.startTs }
    }

    static func selectWorkouts(_ all: [WorkoutRow], watermark: Int, horizon: Int) -> [WorkoutRow] {
        all.filter { $0.startTs > watermark && $0.endTs <= horizon }
           .sorted { $0.startTs < $1.startTs }
    }

    /// One line per stage interval: `stage,start,end`.
    ///
    /// Stage vocabulary is `HealthWriteback.StageKind` verbatim (`awake|light|deep|rem|unspecified`)
    /// so the Shortcut's mapping matches what the entitled HealthKit path writes:
    /// `awake → .awake`, `light → .asleepCore`, `deep → .asleepDeep`, `rem → .asleepREM`,
    /// `unspecified → .asleepUnspecified`.
    ///
    /// A session whose `stagesJSON` carries no placement (the aggregate `{"deep":min,…}` shapes, or
    /// nothing at all) yields ONE `unspecified` line spanning the night rather than fabricated
    /// positions — the same honest fallback the HealthKit bridge makes.
    static func renderSleep(_ sessions: [CachedSleepSession], timeZone: TimeZone) -> [String] {
        sessions.flatMap { s -> [String] in
            let start = s.effectiveStartTs
            guard s.endTs > start else { return [] }
            let intervals = HealthWriteback.stageIntervals(stagesJSON: s.stagesJSON,
                                                           sessionStart: start,
                                                           sessionEnd: s.endTs)
            guard !intervals.isEmpty else {
                return ["unspecified,\(stamp(start, timeZone)),\(stamp(s.endTs, timeZone))," +
                        "\(healthState(for: .unspecified))"]
            }
            return intervals.map {
                "\($0.kind.rawValue),\(stamp($0.start, timeZone)),\(stamp($0.end, timeZone))," +
                "\(healthState(for: $0.kind))"
            }
        }
    }

    /// Column 4: the stage collapsed to the vocabulary the Shortcuts "Log Health Sample → Sleep"
    /// picker actually offers — **Awake / In Bed / Asleep**, and nothing else.
    ///
    /// Shortcuts cannot write the staged categories (`asleepCore` / `asleepDeep` / `asleepREM`) that the
    /// entitled HealthKit path can, so a sideloaded install has to collapse them. Doing it HERE rather
    /// than in the Shortcut keeps the true stage in column 1 — nothing is lost from the file, a future
    /// consumer that can write stages just reads the other column — and leaves the Shortcut with a value
    /// it passes straight through, with no mapping logic to get wrong.
    static func healthState(for kind: HealthWriteback.StageKind) -> String {
        switch kind {
        case .awake: return "Awake"
        case .light, .deep, .rem, .unspecified: return "Asleep"
        }
    }

    /// One line per workout: `sport,start,end,kcal,avgHr,maxHr,distanceM`.
    ///
    /// Empty fields keep their commas so column positions are fixed, matching the window file. The
    /// sport label is sanitised of commas so a multi-word sport can't shift every later column.
    static func renderWorkouts(_ workouts: [WorkoutRow], timeZone: TimeZone) -> [String] {
        workouts.compactMap { w -> String? in
            guard w.endTs > w.startTs else { return nil }
            // Swap commas for spaces, then collapse the runs: "strength, upper" must render as
            // "strength upper", not "strength  upper" — the label reaches Health as a workout name.
            let sport = w.sport
                .replacingOccurrences(of: ",", with: " ")
                .split(whereSeparator: \.isWhitespace)
                .joined(separator: " ")
            let kcal = w.energyKcal.map { String(Int($0.rounded())) } ?? ""
            let avg = w.avgHr.map(String.init) ?? ""
            let max = w.maxHr.map(String.init) ?? ""
            let dist = w.distanceM.map { String(Int($0.rounded())) } ?? ""
            return "\(sport.isEmpty ? "workout" : sport),\(stamp(w.startTs, timeZone))," +
                   "\(stamp(w.endTs, timeZone)),\(kcal),\(avg),\(max),\(dist)"
        }
    }

    // en_US_POSIX per the project's date contract; the zone is set per call (LOCAL in production,
    // injected in tests). Single shared instance — only ever used from one task at a time.
    private static let lineFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    static func stamp(_ ts: Int, _ timeZone: TimeZone) -> String {
        lineFormatter.timeZone = timeZone
        return lineFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }
}

/// The two store reads the session export needs — a seam so the watermark/selection logic is
/// testable without a live DB. `WhoopStore`'s own methods match the signatures exactly.
protocol ShortcutSessionReads {
    func sleepSessions(deviceId: String, from: Int, to: Int, limit: Int) async throws -> [CachedSleepSession]
    func workouts(deviceId: String, from: Int, to: Int, limit: Int) async throws -> [WorkoutRow]
    /// Day rows, for the per-night vitals that are not carried on the session itself. `from`/`to` are
    /// `yyyy-MM-dd`.
    func dailyMetrics(deviceId: String, from: String, to: String) async throws -> [DailyMetric]
}

extension WhoopStore: ShortcutSessionReads {}
