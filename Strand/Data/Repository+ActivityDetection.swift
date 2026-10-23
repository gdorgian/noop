import Foundation
import WhoopProtocol
import WhoopStore
import StrandAnalytics

/// Automatic activity logging (22 Oct 2026). After each analysis pass, the last day and a half of strap
/// heart rate is scanned with `ActivityBoutDetector`; every finished bout that no logged, imported or
/// dismissed workout already covers is saved as a DETECTED row under the computed ("-noop") namespace —
/// the same place and shape the app's detected workouts have always used, so they show as "detected",
/// are replaced by any real session they overlap, and can be renamed, corrected or deleted. Deleting one
/// leaves the dismissal marker the detected rows already use, so it is never logged again.
extension Repository {
    /// On unless the wearer turns it off in Settings.
    static let autoLogActivitiesKey = "fitness.autoLogActivities"
    static var autoLogActivitiesEnabled: Bool {
        UserDefaults.standard.object(forKey: autoLogActivitiesKey) as? Bool ?? true
    }

    /// How far back each scan looks, and how long a bout must have been over before it is logged — so a
    /// session still under way is not saved half-finished and then blocked from growing.
    static let autoLogLookbackS = 36 * 3600
    static let autoLogSettleS = 12 * 60

    /// Scans and logs. Returns how many activities were added.
    @discardableResult
    func autoLogDetectedActivities(now: Date = Date()) async -> Int {
        guard Self.autoLogActivitiesEnabled, let store = await storeHandle() else { return 0 }
        let nowTs = Int(now.timeIntervalSince1970)
        let from = nowTs - Self.autoLogLookbackS
        let samples = await hrSamples(from: from, to: nowTs, limit: 200_000)
        guard let lastTs = samples.map(\.ts).max(), samples.count >= 600 else { return 0 }

        let gravity = await gravitySamplesUnion(from: from, to: nowTs)
        let motion = AutoWorkoutDetector.motionPoints(gravity).map { (ts: $0.ts, intensity: $0.intensity) }
        var steps: [StepSample] = []
        for id in importedReadIds {
            let s = (try? await store.stepSamples(deviceId: id, from: from, to: nowTs, limit: 200_000)) ?? []
            if !s.isEmpty { steps = s; break }
        }

        let resting = Double(days.last(where: { $0.restingHr != nil })?.restingHr ?? AutoWorkoutDetector.defaultRestingHR)
        let maxHR = strainProfile?.hrMax ?? 190

        let sleepRows = await sleepSessions(from: from - 86_400, to: nowTs)
            + (await computedSleepSessions(from: from - 86_400, to: nowTs))
        let sleep = sleepRows.map { ActivityBoutDetector.Span(startSec: $0.startTs, endSec: $0.endTs) }

        // Anything already covered: every visible workout (real or detected) and every dismissed span.
        var exclude = (await workoutRows(days: 3)).map { ActivityBoutDetector.Span(startSec: $0.startTs, endSec: $0.endTs) }
        let dismissed = (UserDefaults.standard.stringArray(forKey: WorkoutSource.dismissedDefaultsKey) ?? [])
            + autoDetectDismissedSpans
        for token in dismissed {
            let parts = token.split(separator: ":").compactMap { Int($0) }
            if parts.count == 2 { exclude.append(.init(startSec: parts[0], endSec: parts[1])) }
        }

        let found = ActivityBoutDetector.detect(
            hr: samples.map { (ts: $0.ts, bpm: $0.bpm) }, restingBpm: resting, maxBpm: maxHR,
            motion: motion, sleep: sleep, exclude: exclude)
        // A bout still running at the newest sample, with fresh heart rate, is a session under way: say
        // so once, while the wearer is still in it.
        if let live = found.last, lastTs - live.endSec < Self.autoLogSettleS, nowTs - lastTs < 10 * 60,
           live.endSec - live.startSec >= Self.autoLogSettleS {
            ActivityNotifier.inProgress(startSec: live.startSec)
        }
        let bouts = found.filter { lastTs - $0.endSec >= Self.autoLogSettleS }
        guard !bouts.isEmpty else { return 0 }

        let hrPairs = samples.map { (ts: $0.ts, bpm: $0.bpm) }
        let examples = await personalActivityExamples()
        let rows = bouts.map { b -> WorkoutRow in
            let learned = Self.learnedSport(start: b.startSec, end: b.endSec, hr: hrPairs,
                                            resting: Int(resting), examples: examples)
            return WorkoutRow(startTs: b.startSec, endTs: b.endSec,
                       sport: learned ?? Self.detectedSport(b, hr: samples, gravity: gravity, steps: steps,
                                                            resting: resting, maxHR: maxHR),
                       source: computedDeviceId, durationS: Double(b.endSec - b.startSec),
                       energyKcal: nil, avgHr: b.avgBpm, maxHr: b.peakBpm, strain: nil,
                       distanceM: nil, zonesJSON: nil, notes: nil, steps: nil)
        }
        do {
            _ = try await store.upsertWorkouts(rows, deviceId: computedDeviceId)
        } catch {
            return 0
        }
        for row in rows { ActivityNotifier.logged(row) }
        return rows.count
    }

    // MARK: - Learning from the wearer's own sessions

    /// Where each labelled session's shape is kept, keyed "start:end:sport", so a session's heart rate
    /// is read once rather than on every pass.
    static let personalExamplesKey = "fitness.personalActivityExamples.v1"
    /// How far back labelled sessions count, and how many at most.
    static let personalExamplesDays = 120
    static let personalExamplesMax = 150

    /// Every session the wearer named — logged by hand, confirmed from a detection, imported or recorded
    /// live — as a shape the personal model can compare a new detection with. Detected rows are not
    /// examples until the wearer confirms them (confirming rewrites them as manual rows).
    func personalActivityExamples() async -> [PersonalActivityModel.Example] {
        let rows = (await workoutRows(days: Self.personalExamplesDays))
            .filter { WorkoutSource.classify($0.source) != .detected }
            .filter { !$0.sport.isEmpty && $0.sport.lowercased() != "detected" }
            .filter { $0.endTs - $0.startTs >= 10 * 60 && $0.endTs - $0.startTs <= 6 * 3600 }
            .sorted { $0.startTs > $1.startTs }
            .prefix(Self.personalExamplesMax)
        let defaults = UserDefaults.standard
        let cached = (defaults.dictionary(forKey: Self.personalExamplesKey) as? [String: [Double]]) ?? [:]
        var kept: [String: [Double]] = [:]
        var out: [PersonalActivityModel.Example] = []
        let resting = days.last(where: { $0.restingHr != nil })?.restingHr
        for row in rows {
            let key = "\(row.startTs):\(row.endTs):\(row.sport)"
            var features = cached[key]
            if features == nil {
                let hr = await hrSamples(from: row.startTs, to: row.endTs, limit: 40_000)
                features = PersonalActivityModel.features(hr: hr.map { (ts: $0.ts, bpm: $0.bpm) },
                                                          startSec: row.startTs, endSec: row.endTs,
                                                          restingBpm: resting,
                                                          utcOffsetSec: TimeZone.current.secondsFromGMT())
            }
            guard let features else { continue }
            kept[key] = features
            out.append(.init(sport: row.sport, features: features))
        }
        defaults.set(kept, forKey: Self.personalExamplesKey)
        return out
    }

    /// The wearer's own activities ranked for a window, best first. Empty until enough are logged.
    func personalActivitySuggestions(start: Int, end: Int) async -> [PersonalActivityModel.Suggestion] {
        let hr = await hrSamples(from: start, to: end, limit: 40_000)
        let resting = days.last(where: { $0.restingHr != nil })?.restingHr
        guard let f = PersonalActivityModel.features(hr: hr.map { (ts: $0.ts, bpm: $0.bpm) }, startSec: start,
                                                     endSec: end, restingBpm: resting,
                                                     utcOffsetSec: TimeZone.current.secondsFromGMT())
        else { return [] }
        return PersonalActivityModel.suggest(f, from: await personalActivityExamples())
    }

    /// The learned name for a new bout, when the wearer's history clearly agrees on one.
    nonisolated static func learnedSport(start: Int, end: Int, hr: [(ts: Int, bpm: Int)], resting: Int,
                                         examples: [PersonalActivityModel.Example]) -> String? {
        guard let f = PersonalActivityModel.features(hr: hr, startSec: start, endSec: end, restingBpm: resting,
                                                     utcOffsetSec: TimeZone.current.secondsFromGMT()),
              let top = PersonalActivityModel.suggest(f, from: examples).first,
              top.share >= 0.5, top.examples >= 2 else { return nil }
        return top.sport
    }

    /// The sport to show. The coarse classifier names it when it is confident (it reads the strap's own
    /// still/walk/run class and motion); the detector's set-and-rest rule names strength; otherwise the
    /// neutral "detected", which the app shows as Activity until the wearer picks one.
    nonisolated static func detectedSport(_ b: ActivityBoutDetector.Bout, hr: [HRSample], gravity: [GravitySample],
                                          steps: [StepSample], resting: Double, maxHR: Double) -> String {
        if let f = WorkoutTypeFeatureExtractor.extract(hr: hr, gravity: gravity, steps: steps,
                                                       start: b.startSec, end: b.endSec,
                                                       restingHR: resting, maxHR: maxHR) {
            let p = WorkoutTypeClassifier.classify(f)
            if p.confidence >= 0.55 {
                switch p.predictedClass {
                case .run: return "Running"
                case .walk: return "Walking"
                case .cycle: return "Cycling"
                case .strength: return "Strength"
                case .ski, .other: break
                }
            }
        }
        return b.sport == .strength ? "Strength" : "detected"
    }
}
