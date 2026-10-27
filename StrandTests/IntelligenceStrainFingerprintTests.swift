import XCTest
import Foundation
import WhoopStore
import StrandAnalytics
@testable import Strand

@MainActor
final class IntelligenceStrainFingerprintTests: XCTestCase {
    func testUnchangedInputsProduceOneStableWatermark() {
        let recipe = DayStrainScorer.cacheIdentity(method: .edwards, tables: nil)
        let first = IntelligenceEngine.analysisWatermark(rawFingerprint: "raw-v5|h600:123", dailyStrainIdentity: recipe)
        XCTAssertFalse(first.isEmpty)
        XCTAssertEqual(first, IntelligenceEngine.analysisWatermark(rawFingerprint: "raw-v5|h600:123", dailyStrainIdentity: recipe))
        XCTAssertFalse(IntelligenceEngine.rawAnalysisInputsChanged(rawFingerprint: "raw-v5|h600:123", storedWatermark: first))
        XCTAssertTrue(IntelligenceEngine.rawAnalysisInputsChanged(rawFingerprint: "raw-v5|h601:124", storedWatermark: first))
    }

    func testRecipeMethodAndBothTableContentsInvalidateTheWatermark() {
        let original = tables()
        let variants: [String] = [
            DayStrainScorer.cacheIdentity(method: .edwards, tables: nil),
            DayStrainScorer.cacheIdentity(method: .edwards, tables: original),
            DayStrainScorer.cacheIdentity(method: .banister, tables: original),
            DayStrainScorer.cacheIdentity(method: .edwards, tables: tables(scaleMidpoint: 0.4)),
            DayStrainScorer.cacheIdentity(method: .edwards, tables: tables(target: 13)),
            "future-recipe-version",
        ]
        let watermarks = variants.map {
            IntelligenceEngine.analysisWatermark(rawFingerprint: "same-raw-data", dailyStrainIdentity: $0)
        }
        XCTAssertEqual(Set(watermarks).count, watermarks.count)
        for watermark in watermarks {
            XCTAssertFalse(IntelligenceEngine.rawAnalysisInputsChanged(rawFingerprint: "same-raw-data", storedWatermark: watermark),
                           "a scoring change must not be reported as new sensor data")
        }
    }

    func testLegacyRawOnlyWatermarkRequiresOneRecipeAwarePass() {
        let raw = "v5|h600:123"
        let current = IntelligenceEngine.analysisWatermark(rawFingerprint: raw,
            dailyStrainIdentity: DayStrainScorer.cacheIdentity(method: .edwards, tables: nil))
        XCTAssertNotEqual(current, raw, "the old raw-only gate must not suppress the upgrade rescore")
        XCTAssertFalse(IntelligenceEngine.rawAnalysisInputsChanged(rawFingerprint: raw, storedWatermark: raw))
        XCTAssertFalse(IntelligenceEngine.rawAnalysisInputsChanged(rawFingerprint: raw, storedWatermark: current))
    }

    func testUnreadableStoreOrWatermarkCannotSuppressAnalysis() {
        XCTAssertEqual(IntelligenceEngine.analysisWatermark(rawFingerprint: "", dailyStrainIdentity: "recipe"), "")
        XCTAssertTrue(IntelligenceEngine.rawAnalysisInputsChanged(rawFingerprint: "", storedWatermark: "old"))
        XCTAssertTrue(IntelligenceEngine.rawAnalysisInputsChanged(rawFingerprint: "raw", storedWatermark: "corrupted"))
        XCTAssertTrue(IntelligenceEngine.rawAnalysisInputsChanged(rawFingerprint: "raw", storedWatermark: nil))
    }

    func testBothUnchangedDataGatesRescoreAMethodChangeThenSettle() async throws {
        try await withPreferences {
            let store = try await WhoopStore.inMemory()
            let repo = Repository(deviceId: "my-whoop")
            repo.setStoreForTesting(store)
            let engine = IntelligenceEngine(repo: repo, profile: ProfileStore(), deviceId: "my-whoop")
            var completions = 0
            var lines: [String] = []
            engine.diagnosticSink = { line, _ in lines.append(line) }
            await engine.analyzeRecent(maxDays: 1, force: false, onPersisted: { completions += 1 })
            XCTAssertEqual(completions, 1)
            let raw = try await store.analysisFingerprint()
            XCTAssertEqual(UserDefaults.standard.string(forKey: "noop.analyzeWatermark"),
                IntelligenceEngine.analysisWatermark(rawFingerprint: raw,
                    dailyStrainIdentity: DayStrainScorer.cacheIdentity(method: .edwards)))

            await engine.analyzeRecent(maxDays: 1, force: false, onPersisted: { completions += 1 })
            XCTAssertEqual(completions, 1, "the unchanged idle pass must remain cheap")

            UserDefaults.standard.set(true, forKey: PuffinExperiment.banisterEffortKey)
            await engine.analyzeRecent(maxDays: 1, force: true, skipIfUnchanged: true,
                                       onPersisted: { completions += 1 })
            XCTAssertEqual(completions, 2, "a duplicate offload must still rescore a changed recipe")
            XCTAssertTrue(lines.contains { $0.contains("newData=no scoringChanged=yes") })
            XCTAssertEqual(UserDefaults.standard.string(forKey: "noop.analyzeWatermark"),
                IntelligenceEngine.analysisWatermark(rawFingerprint: raw,
                    dailyStrainIdentity: DayStrainScorer.cacheIdentity(method: .banister)))

            await engine.analyzeRecent(maxDays: 1, force: false, onPersisted: { completions += 1 })
            await engine.analyzeRecent(maxDays: 1, force: true, skipIfUnchanged: true,
                                       onPersisted: { completions += 1 })
            XCTAssertEqual(completions, 2, "both gates must settle after the new recipe is persisted")

            UserDefaults.standard.set(false, forKey: PuffinExperiment.banisterEffortKey)
            await engine.analyzeRecent(maxDays: 1, force: false, onPersisted: { completions += 1 })
            XCTAssertEqual(completions, 3, "the idle gate must also admit a recipe-only change")
            await engine.analyzeRecent(maxDays: 1, force: false, onPersisted: { completions += 1 })
            XCTAssertEqual(completions, 3)
        }
    }

    private func tables(scaleMidpoint: Double = 0.5, target: Double = 12) -> WhoopStrain.Tables {
        WhoopStrain.Tables(
            scale: [.init(raw: 0, strain: 0), .init(raw: scaleMidpoint, strain: 10), .init(raw: 1, strain: 21)],
            targets: [.init(recovery: 0, lower: 0, target: 5, upper: 10),
                      .init(recovery: 100, lower: 10, target: target, upper: 21)])
    }

    private func withPreferences(_ body: () async throws -> Void) async throws {
        let defaults = UserDefaults.standard
        let keys = [
            "profile.dateOfBirth", "profile.age", "profile.sex", "profile.weightKg",
            "profile.heightCm", "profile.waistCm", "profile.hrMaxOverride", "profile.stepTicksPerStep",
            "profile.stepsCalibrationCoefficient", "profile.stepsCalibrationSampleDays",
            "profile.stepsCalibrationConfidence", "profile.stepsCalibrationManual",
            "profile.stepsManualCoefficient", "profile.stepsHasBankedMotion",
            "noop.analyzeWatermark", "analyzeRecent.stepsMotionCache.v1", "analyzeRecent.stepsGravityMark.v1",
            "noop.hrvBaselineEpoch", "noop.recoveryBaselineEpoch", UnitPrefs.hrvWindowKey,
            RescoreBackgroundScheduler.owedKey, RescoreBackgroundScheduler.owedTokenKey,
            RescoreBackgroundScheduler.lastPassSecondsKey, DayCycleMode.storageKey,
            PuffinExperiment.experimentalSleepV2Key, PuffinExperiment.motionAwareWakeKey,
            PuffinExperiment.banisterEffortKey,
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
        try await body()
    }
}
