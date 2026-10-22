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

        let bouts = ActivityBoutDetector.detect(
            hr: samples.map { (ts: $0.ts, bpm: $0.bpm) }, restingBpm: resting, maxBpm: maxHR,
            motion: motion, sleep: sleep, exclude: exclude)
            .filter { lastTs - $0.endSec >= Self.autoLogSettleS }
        guard !bouts.isEmpty else { return 0 }

        let rows = bouts.map { b -> WorkoutRow in
            WorkoutRow(startTs: b.startSec, endTs: b.endSec,
                       sport: Self.detectedSport(b, hr: samples, gravity: gravity, steps: steps,
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
        return rows.count
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
