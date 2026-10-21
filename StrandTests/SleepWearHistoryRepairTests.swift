import XCTest
import WhoopProtocol
import WhoopStore
import StrandAnalytics
@testable import Strand

@MainActor
final class SleepWearHistoryRepairTests: XCTestCase {
    private func withPreferences(_ body: () async throws -> Void) async throws {
        let defaults = UserDefaults.standard
        let keys = [
            "profile.dateOfBirth", "profile.age", "profile.sex", "profile.weightKg",
            "profile.heightCm", "profile.waistCm", "profile.hrMaxOverride", "profile.stepTicksPerStep",
            "profile.stepsCalibrationCoefficient", "profile.stepsCalibrationSampleDays",
            "profile.stepsCalibrationConfidence", "profile.stepsCalibrationManual",
            "profile.stepsManualCoefficient", "profile.stepsHasBankedMotion",
            IntelligenceEngine.effortRescoreFlagKey, IntelligenceEngine.sleepWearRescoreFlagKey,
            "noop.analyzeWatermark", "analyzeRecent.stepsMotionCache.v1",
            "noop.hrvBaselineEpoch", "noop.recoveryBaselineEpoch", UnitPrefs.hrvWindowKey,
            RescoreBackgroundScheduler.owedKey, RescoreBackgroundScheduler.owedTokenKey,
            RescoreBackgroundScheduler.lastPassSecondsKey, DayCycleMode.storageKey,
            PuffinExperiment.experimentalSleepV2Key, PuffinExperiment.motionAwareWakeKey,
        ]
        let saved = keys.map { ($0, defaults.object(forKey: $0)) }
        defer {
            for (key, value) in saved {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        for key in keys { defaults.removeObject(forKey: key) }
        defaults.set(DayCycleMode.midnight.rawValue, forKey: DayCycleMode.storageKey)
        defaults.set(true, forKey: PuffinExperiment.experimentalSleepV2Key)
        defaults.set(false, forKey: PuffinExperiment.motionAwareWakeKey)
        try await body()
    }

    func testEitherPendingFlagSchedulesExactlyOneSharedRepair() {
        XCTAssertTrue(IntelligenceEngine.historyRepairIsPending(effortDone: false, sleepWearDone: false))
        XCTAssertTrue(IntelligenceEngine.historyRepairIsPending(effortDone: true, sleepWearDone: false))
        XCTAssertTrue(IntelligenceEngine.historyRepairIsPending(effortDone: false, sleepWearDone: true))
        XCTAssertFalse(IntelligenceEngine.historyRepairIsPending(effortDone: true, sleepWearDone: true))
    }

    func testRepairsOlderThan21DaysPersistsAndRunsOnlyOnce() async throws {
        try await verifyHistoryRepair(queueForcedRescore: false)
    }

    func testQueuedForcedRescoreCompletesRepairAndReturnsToRecentWindow() async throws {
        try await verifyHistoryRepair(queueForcedRescore: true)
    }

    private func verifyHistoryRepair(queueForcedRescore: Bool) async throws {
        try await withPreferences {
            let store = try await WhoopStore.inMemory()
            let source = "my-whoop"
            let registry = DeviceRegistryStore(dbQueue: store.registryWriter)
            try registry.add(PairedDevice(id: source, brand: "WHOOP", model: "4.0",
                sourceKind: .liveBLE, capabilities: [.hr, .hrv], status: .active, addedAt: 1, lastSeenAt: 1))
            let now = Int(Date().timeIntervalSince1970)
            let tz = TimeZone.current.secondsFromGMT()
            let dayStart = IntelligenceEngine.midnightLocal(now, offsetSec: tz) - 35 * 86400
            let start = dayStart + 2 * 3600, end = start + 2 * 3600
            let hr = stride(from: start - 900, through: end, by: 5).map { HRSample(ts: $0, bpm: 50) }
            let grav = stride(from: start, through: end, by: 5).map { GravitySample(ts: $0, x: 0, y: 0, z: 1, unit: "g") }
            let events = [WhoopEvent(ts: start - 1800, kind: "WRIST_OFF(10)", payload: [:])]
            _ = try await store.insert(Streams(hr: hr, gravity: grav, events: events), deviceId: source)
            // A cached day with no retained raw data must survive the wide repair unchanged.
            let cachedDay = AnalyticsEngine.dayString(dayStart - 3 * 86400, offsetSec: tz)
            let cached = DailyMetric(day: cachedDay, totalSleepMin: 456, efficiency: 0.9,
                deepMin: 100, remMin: 100, lightMin: 256, disturbances: 1, restingHr: 55,
                avgHrv: 35, recovery: 70, strain: 10, exerciseCount: 0)
            _ = try await store.upsertDailyMetrics([cached], deviceId: source + "-noop")
            // Hand-edited bounds overlapping a second night's raw data remain authoritative.
            let editedStart = start + 86400, editedEnd = end + 86400
            let secondHR = hr.map { HRSample(ts: $0.ts + 86400, bpm: $0.bpm) }
            let secondGravity = grav.map { GravitySample(ts: $0.ts + 86400, x: $0.x, y: $0.y, z: $0.z, unit: "g") }
            _ = try await store.insert(Streams(hr: secondHR, gravity: secondGravity), deviceId: source)
            let edited = CachedSleepSession(startTs: editedStart, endTs: editedEnd - 300,
                efficiency: 0.9, restingHr: 50, avgHrv: nil, stagesJSON: "[]", userEdited: true,
                startTsAdjusted: editedStart + 300)
            _ = try await store.upsertSleepSessions([edited], deviceId: source + "-noop")
            let repo = Repository(deviceId: source)
            repo.setStoreForTesting(store)
            let engine = IntelligenceEngine(repo: repo, profile: ProfileStore(), deviceId: source)
            defer { engine.diagnosticSink = nil }
            var triggers = 0
            var completedPasses = 0
            var queuedWasObserved = false
            var queuedCall: Task<Void, Never>?
            let followUpFinished = XCTestExpectation(description: "Queued recent pass completed")
            engine.diagnosticSink = { line, _ in
                if line.contains("trigger=sleep-wear-history-repair") {
                    triggers += 1
                    if queueForcedRescore, queuedCall == nil {
                        queuedCall = Task { @MainActor in
                            await engine.analyzeRecent(force: true)
                        }
                    }
                }
                if line.contains("queued behind a 40-day pass") { queuedWasObserved = true }
                if line.contains("re-score: done") {
                    completedPasses += 1
                    if completedPasses == 3 { followUpFinished.fulfill() }
                }
            }
            // The normal recent pass cannot repair this older night.
            await engine.analyzeRecent(maxDays: 21)
            let before = try await store.sleepSessions(deviceId: source + "-noop", from: dayStart, to: dayStart + 86400, limit: 100)
            XCTAssertTrue(before.isEmpty)
            await engine.runSleepWearRescoreIfNeeded(historyDays: 40)
            // Assert before yielding to the queued pass: only the repair itself may mark its flags.
            XCTAssertTrue(UserDefaults.standard.bool(forKey: IntelligenceEngine.sleepWearRescoreFlagKey))
            XCTAssertTrue(UserDefaults.standard.bool(forKey: IntelligenceEngine.effortRescoreFlagKey))
            if queueForcedRescore {
                await queuedCall?.value
                XCTAssertTrue(queuedWasObserved, "The forced update must actually overlap the repair")
                await fulfillment(of: [followUpFinished], timeout: 30)
                XCTAssertFalse(engine.results.contains { $0.day == AnalyticsEngine.dayString(dayStart, offsetSec: tz) },
                    "The queued recent pass must not repeat the older-than-21-day repair")
            }
            let after = try await store.sleepSessions(deviceId: source + "-noop", from: dayStart, to: dayStart + 86400, limit: 100)
            XCTAssertEqual(after.count, 1)
            let day = AnalyticsEngine.dayString(dayStart, offsetSec: tz)
            let dailies = try await store.dailyMetrics(deviceId: source + "-noop", from: day, to: day)
            XCTAssertGreaterThan(try XCTUnwrap(dailies.first?.totalSleepMin), 60)
            let cachedAfter = try await store.dailyMetrics(deviceId: source + "-noop", from: cachedDay, to: cachedDay)
            XCTAssertEqual(cachedAfter.first?.totalSleepMin, cached.totalSleepMin)
            XCTAssertEqual(cachedAfter.first?.recovery, cached.recovery)
            let editedAfter = try await store.sleepSessions(deviceId: source + "-noop", from: editedStart, to: editedEnd, limit: 100)
            XCTAssertEqual(editedAfter.count, 1)
            XCTAssertEqual(editedAfter.first?.effectiveStartTs, edited.effectiveStartTs)
            XCTAssertEqual(editedAfter.first?.endTs, edited.endTs)
            XCTAssertEqual(editedAfter.first?.userEdited, true)
            XCTAssertTrue(UserDefaults.standard.bool(forKey: IntelligenceEngine.sleepWearRescoreFlagKey))
            XCTAssertTrue(UserDefaults.standard.bool(forKey: IntelligenceEngine.effortRescoreFlagKey))
            await engine.runSleepWearRescoreIfNeeded(historyDays: 40)
            XCTAssertEqual(triggers, 1, "Completed history repair must not run on every launch")
        }
    }

    func testBusyAndCancelledAttemptsRemainPending() async throws {
        try await withPreferences {
            let repo = Repository(deviceId: "test-sleep-wear")
            let engine = IntelligenceEngine(repo: repo, profile: ProfileStore(), deviceId: "test-sleep-wear")
            engine.computing = true
            await engine.runSleepWearRescoreIfNeeded(historyDays: 40)
            XCTAssertFalse(UserDefaults.standard.bool(forKey: IntelligenceEngine.sleepWearRescoreFlagKey))
            XCTAssertFalse(UserDefaults.standard.bool(forKey: IntelligenceEngine.effortRescoreFlagKey))
            engine.computing = false
            let task = Task { @MainActor in
                await Task.yield()
                await engine.runSleepWearRescoreIfNeeded(historyDays: 40)
            }
            task.cancel()
            await task.value
            XCTAssertFalse(UserDefaults.standard.bool(forKey: IntelligenceEngine.sleepWearRescoreFlagKey))
        }
    }
}
