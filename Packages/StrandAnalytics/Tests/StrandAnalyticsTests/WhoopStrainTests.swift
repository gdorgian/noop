import XCTest
import Foundation
@testable import StrandAnalytics
import WhoopProtocol

/// WhoopStrain — WHOOP's own Day Strain recipe, and the shape of its two exact tables.
///
/// Every constant here is WHOOP's, read from the WHOOP iOS 5.65.1 binary; these tests pin the
/// arithmetic so nothing can quietly "tune" a step. The exact-table test at the bottom is the
/// build-level guarantee the owner asked for: when the git-ignored WHOOP tables are present at
/// `Config/`, every row of WHOOP's own scale is run through NOOP's lookup and the test fails if
/// NOOP is off by even 0.1. On a machine without the files (public CI builds) that test skips.
final class WhoopStrainTests: XCTestCase {

    // MARK: minute buckets

    func testMinuteBucketsAtThirtySecondCadence() {
        // Four minutes: one reading every 30 s at a constant 100 bpm.
        let hr = (0..<8).map { HRSample(ts: 0 + $0 * 30, bpm: 100) }
        let buckets = WhoopStrain.minuteBuckets(hr)
        XCTAssertEqual(buckets.count, 4)
        XCTAssertEqual(buckets.first?.hr, 100)
        // Pin the CURRENT coverage approximation while the per-reading-duration handoff is unverified.
        XCTAssertEqual(buckets.map(\.coverage), [60, 60, 60, 60])
    }

    func testMinuteBucketsTakeThe25thPercentilePerBucket() {
        // One dense bucket: five samples at 150 bpm, forty-five at 100 bpm. Ascending, p25 sits
        // at index (50 − 1) * 0.25 = 12.25 — inside the 100-run — so the minute reads exactly 100.
        // The fixture starts on a 60 s boundary so all 50 samples land in a single bucket.
        let ts = 1_700_000_040                        // aligned: ts % 60 == 0
        let samples = (0..<50).map { HRSample(ts: ts + $0, bpm: $0 < 5 ? 150 : 100) }
        let buckets = WhoopStrain.minuteBuckets(samples)
        XCTAssertEqual(buckets.count, 1)
        XCTAssertEqual(buckets.first?.hr ?? 0, 100, accuracy: 1e-9)
        // And a purely elevated bucket reads its p25 elevated (single-value bucket = itself):
        let elevated = (0..<40).map { HRSample(ts: ts + $0, bpm: 160) }
        XCTAssertEqual(WhoopStrain.minuteBuckets(elevated).first?.hr ?? 0, 160, accuracy: 1e-9)
    }

    func testMinuteBucketsSkipMisreadBuckets() {
        // WHOOP's 30 bpm gate: a bucket whose maximum never reaches 30 bpm contributes nothing.
        let hr = [HRSample(ts: 100, bpm: 20), HRSample(ts: 130, bpm: 25), HRSample(ts: 200, bpm: 120)]
        XCTAssertEqual(WhoopStrain.minuteBuckets(hr).map(\.hr), [120])
    }

    func testMinutePercentileIsNotTheMinimumOrQuarterPercentile() {
        let samples = (0..<60).map { HRSample(ts: 3_000 + $0, bpm: $0 == 0 ? 50 : 150) }
        XCTAssertEqual(WhoopStrain.minuteBuckets(samples).first?.hr, 150)
        XCTAssertGreaterThan(WhoopStrain.rawStrain(samples, restingHR: 50, hrMax: 185), 0)
    }

    func testMinutePercentileInterpolatesAtQuarterOfSortedPositions() {
        // The p25 position is (60 − 1) × 0.25 = 14.75, between 114 and 115 bpm.
        let samples = (0..<60).reversed().map { HRSample(ts: 3_000 + $0, bpm: 100 + $0) }
        XCTAssertEqual(WhoopStrain.minuteBuckets(samples).first?.hr, 114.75)
    }

    // MARK: the recipe's steps, one literal each

    func testReserveUsesWHOOPMaxBumpAndClampsBeforeTheFloor() {
        // (150 − 50) / ((185 + 3) − 50) — the +3 bump on HRmax is WHOOP's own.
        XCTAssertEqual(WhoopStrain.reserve(150, restingHR: 50, hrMax: 185), 0.7246376811594203, accuracy: 1e-12)
        XCTAssertEqual(WhoopStrain.reserve(80, restingHR: 50, hrMax: 185), 0.0)   // 20/138 = 0.145 < floor
        XCTAssertEqual(WhoopStrain.reserve(50, restingHR: 50, hrMax: 185), 0.0)   // resting itself = zero
        XCTAssertEqual(WhoopStrain.reserve(300, restingHR: 50, hrMax: 185), 1.0)  // clamped
        XCTAssertEqual(WhoopStrain.reserve(92, restingHR: 50, hrMax: 185), 42.0 / 138.0, accuracy: 1e-12)
    }

    func testCurveWeightIsWHOOPSigmoid() {
        // 16 / (1 + exp((1 − u)/0.15)): the weight is 8.0 at a full reserve.
        XCTAssertEqual(WhoopStrain.curveWeight(1.0), 8.0, accuracy: 1e-12)
        XCTAssertEqual(WhoopStrain.curveWeight(0.7246376811594203), 2.200877626109682, accuracy: 1e-12)
        XCTAssertEqual(WhoopStrain.curveWeight(0.36231884057971014), 0.224750250915181, accuracy: 1e-12)
    }

    func testRawStrainIsThe691200DivisorSum() {
        // u = (150 − 50)/138 = 0.72463768…; w = 2.20087762611….
        // Sum weight × duration only: multiplying by u again would undercount every minute.
        // Four minutes under the current minute-coverage approximation.
        // Aligned to 60 s boundaries so the eight samples form exactly four buckets.
        let hr = (0..<8).map { HRSample(ts: 3_000 + $0 * 30, bpm: 150) }
        let raw = WhoopStrain.rawStrain(hr, restingHR: 50, hrMax: 185)
        XCTAssertEqual(raw, 4 * 2.200877626109682 * 60 / 691_200, accuracy: 1e-15)
        // A calm-made-real day (every minute at 100 bpm, above the 0.3 floor) is NOT zero —
        // the whole visible fix: gentle days stop reading zero.
        let calm = (0..<8).map { HRSample(ts: 1_700_000_040 + $0 * 30, bpm: 100) }
        let calmRaw = WhoopStrain.rawStrain(calm, restingHR: 50, hrMax: 185)
        XCTAssertGreaterThan(calmRaw, 0)
        // Calm minute: u = 50/138 determines w, but is not an additional multiplier.
        XCTAssertEqual(calmRaw, 4 * 0.224750250915181 * 60 / 691_200, accuracy: 1e-15)
        // Fully-resting minutes below the floor contribute exactly nothing.
        XCTAssertEqual(WhoopStrain.rawStrain(
            (0..<8).map { HRSample(ts: 2_000_000_000 + $0 * 30, bpm: 55) },
            restingHR: 50, hrMax: 185), 0.0, accuracy: 1e-15)
    }

    func testDenseMinuteAccumulatesWeightWithoutExtraIntensity() {
        let samples = (0..<60).map { HRSample(ts: 3_000 + $0, bpm: 150) }
        XCTAssertEqual(WhoopStrain.rawStrain(samples, restingHR: 50, hrMax: 185),
                       2.200877626109682 * 60 / 691_200, accuracy: 1e-15)
    }

    func testRawStrainZeroesWhenMaxDoesNotReachResting() {
        // A degenerate reserve (HRmax below resting) can never fabricate effort.
        XCTAssertEqual(WhoopStrain.rawStrain([HRSample(ts: 1, bpm: 100)], restingHR: 50, hrMax: 45), 0)
    }

    // MARK: raw → 0–21 scale

    func testScaleLookupSnapsAtMidpointsWithTiesToUpperRow() {
        let rows = [
            WhoopStrain.ScaleRow(raw: 0, strain: 0),
            WhoopStrain.ScaleRow(raw: 1, strain: 10),
            WhoopStrain.ScaleRow(raw: 2, strain: 21),
        ]
        XCTAssertEqual(WhoopStrain.scaleLookup(raw: 0.5.nextDown, table: rows), 0)
        XCTAssertEqual(WhoopStrain.scaleLookup(raw: 0.5, table: rows), 10)
        XCTAssertEqual(WhoopStrain.scaleLookup(raw: 0.5.nextUp, table: rows), 10)
        XCTAssertEqual(WhoopStrain.scaleLookup(raw: 1, table: rows), 10, accuracy: 1e-12)
        XCTAssertEqual(WhoopStrain.scaleLookup(raw: 1.5.nextDown, table: rows), 10)
        XCTAssertEqual(WhoopStrain.scaleLookup(raw: 1.5, table: rows), 21)
        XCTAssertEqual(WhoopStrain.scaleLookup(raw: 1.5.nextUp, table: rows), 21)
        XCTAssertEqual(WhoopStrain.scaleLookup(raw: 2, table: rows), 21)
        XCTAssertEqual(WhoopStrain.scaleLookup(raw: 2.5, table: rows), 21, accuracy: 1e-12)
        XCTAssertEqual(WhoopStrain.scaleLookup(raw: -1, table: rows), 0, accuracy: 1e-12)
    }

    func testScaleLookupSnapsAtANonuniformDecimalMidpoint() {
        let rows = [WhoopStrain.ScaleRow(raw: 0, strain: 0),
                    .init(raw: 0.001, strain: 3.1), .init(raw: 0.01, strain: 7.2),
                    .init(raw: 0.5, strain: 21)]
        let midpoint = 0.0055
        XCTAssertEqual(WhoopStrain.scaleLookup(raw: midpoint.nextDown, table: rows), 3.1)
        XCTAssertEqual(WhoopStrain.scaleLookup(raw: midpoint, table: rows), 7.2)
        XCTAssertEqual(WhoopStrain.scaleLookup(raw: midpoint.nextUp, table: rows), 7.2)
    }

    // MARK: item 2 — recovery → target curve

    private func targetTable() -> WhoopStrain.Tables {
        WhoopStrain.Tables(
            scale: [WhoopStrain.ScaleRow(raw: 0, strain: 0), WhoopStrain.ScaleRow(raw: 1, strain: 21)],
            targets: [
                WhoopStrain.TargetRow(recovery: 0, lower: 0, target: 5, upper: 10),
                WhoopStrain.TargetRow(recovery: 50, lower: 7.018, target: 11, upper: 14.976),
                WhoopStrain.TargetRow(recovery: 100, lower: 13, target: 17, upper: 21),
            ])
    }

    func testTargetStrainInterpolatesOneValuePerRecoveryPercent() {
        let result = WhoopStrain.targetStrain21(recovery: 25, tables: targetTable())
        // Between WHOOP's rows at 0 and 50 percent: every field interpolates.
        XCTAssertEqual(result?.target ?? 0, (5 + 11) / 2, accuracy: 1e-12)
        XCTAssertEqual(result?.band.lowerBound ?? 0, (0 + 7.018) / 2, accuracy: 1e-12)
        XCTAssertEqual(result?.band.upperBound ?? 0, (10 + 14.976) / 2, accuracy: 1e-12)
        // Clamped at both ends.
        XCTAssertEqual(WhoopStrain.targetStrain21(recovery: -5, tables: targetTable())?.target, 5)
        XCTAssertEqual(WhoopStrain.targetStrain21(recovery: 150, tables: targetTable())?.target, 17)
        // Without tables installed there is no target — callers keep their fallback bands.
        XCTAssertNil(WhoopStrain.targetStrain21(recovery: 50, tables: nil))
    }

    // MARK: git-ignored exact build — the one test the owner asked to be strict

    /// WHOOP's tables only exist in a local build that carried them out of the owner's own IPA.
    /// Where they exist, run WHOOP's own rows through NOOP's lookup. This checks node/loader
    /// integrity; the independent midpoint tests above distinguish snapping from interpolation.
    func testWHOOPScaleRowsLookupExactly() throws {
        let root = URL(fileURLWithPath: #filePath)                     // …/Tests/StrandAnalyticsTests/WhoopStrainTests.swift
            .deletingLastPathComponent()                               // …/Tests/StrandAnalyticsTests
            .deletingLastPathComponent()                               // …/Tests
            .deletingLastPathComponent()                               // …/StrandAnalytics
            .deletingLastPathComponent()                               // …/Packages
            .deletingLastPathComponent()                               // repo root
            .path
        let scaleURL = URL(fileURLWithPath: root)
            .appendingPathComponent("Config/strain_raw_scale_lookup.json")
        try XCTSkipIf(!FileManager.default.fileExists(atPath: scaleURL.path),
                      "local WHOOP tables absent (public build) — strict check runs owner-side")
        let targetsURL = URL(fileURLWithPath: root)
            .appendingPathComponent("Config/recovery_to_strain.json")
        let hasTargets = FileManager.default.fileExists(atPath: targetsURL.path)
        let tables = try WhoopStrain.Tables.load(
            scaleAt: scaleURL, targetsAt: hasTargets ? targetsURL : nil)
        XCTAssertGreaterThanOrEqual(tables.scale.count, 10, "a stub, not WHOOP's scale — refusing to 'pass' it")
        // Monotone on both axes: the shipped curve is one curve, not noise.
        for pair in zip(tables.scale, tables.scale.dropFirst()) {
            XCTAssertLessThanOrEqual(pair.0.raw, pair.1.raw + 1e-12)
            XCTAssertLessThanOrEqual(pair.0.strain, pair.1.strain + 1e-12)
        }
        // First row is the zero and the last is the top: anything beyond the table still reads 21.
        XCTAssertEqual(tables.scale.first?.strain, 0)
        XCTAssertEqual(tables.scale.last?.strain, 21)
        // THE exact row check: 0.099 < the owner's "off by even 0.1" bound.
        for row in tables.scale {
            XCTAssertEqual(WhoopStrain.scaleLookup(raw: row.raw, table: tables.scale),
                           row.strain, accuracy: 0.099,
                           "raw \(row.raw) must read WHOOP's \(row.strain) through NOOP's lookup")
        }
        // With recovery rows present, every percent's target interpolates inside the same bound.
        if let rows = tables.targets {
            for row in rows {
                let at = WhoopStrain.targetStrain21(recovery: Double(row.recovery), tables: tables)
                XCTAssertEqual(at?.target ?? -1, row.target, accuracy: 0.099)
                XCTAssertEqual(at?.band.lowerBound ?? -1, row.lower, accuracy: 0.099)
                XCTAssertEqual(at?.band.upperBound ?? -1, row.upper, accuracy: 0.099)
            }
        }
    }

    // MARK: parse + loader plumbing

    func testParseScaleAndTargetsShapes() throws {
        let scaleData = Data("[[0,0],[0.02,5.5],[0.3,21]]".utf8)
        let targetsData = Data("""
        [{"recovery":0,"lower_rec_strain":0,"rec_strain":5,"upper_rec_strain":10},
         {"recovery":100,"lower_rec_strain":13,"rec_strain":17,"upper_rec_strain":21}]
        """.utf8)
        let tables = try WhoopStrain.Tables.parse(scaleData: scaleData, targetsData: targetsData)
        XCTAssertEqual(tables.scale.count, 3)
        XCTAssertEqual(tables.targets?.count, 2)
        XCTAssertEqual(tables.targets?.first?.target, 5)
        // The target rows are optional: the scale alone ports the strain path.
        let scaleOnly = try WhoopStrain.Tables.parse(scaleData: scaleData, targetsData: nil)
        XCTAssertNil(scaleOnly.targets)
        // A wrong-shaped scale is an error, never a scored day.
        XCTAssertThrowsError(try WhoopStrain.Tables.parse(scaleData: Data("[[1,2,3]]".utf8), targetsData: nil))
    }

    func testLoadFromBundleIsNilForATestBundle() {
        // Test bundles never carry app resources, so the loader must fail silently here exactly
        // as it will in a public build's app bundle.
        XCTAssertNil(WhoopStrain.Tables.load(from: Bundle(for: WhoopStrainTests.self)))
    }

    func testDayStrain21FallsBackToNilWithoutTables() {
        let hr = (0..<60).map { HRSample(ts: 1_700_000_000 + $0, bpm: 120) }
        XCTAssertNil(WhoopStrain.dayStrain21(hr, restingHR: 50, hrMax: 185, tables: nil))
    }

    func testDayStrain21PreservesMissingAndRejectedHeartRateAsNil() {
        let tables = targetTable()
        XCTAssertNil(WhoopStrain.dayStrain21([], restingHR: 50, hrMax: 185, tables: tables))
        let rejected = (0..<600).map { HRSample(ts: 3_000 + $0, bpm: 20) }
        XCTAssertNil(WhoopStrain.dayStrain21(rejected, restingHR: 50, hrMax: 185, tables: tables))
        // A valid measured resting minute is a real zero, unlike missing or rejected data.
        let resting = (0..<60).map { HRSample(ts: 3_000 + $0, bpm: 55) }
        XCTAssertEqual(WhoopStrain.dayStrain21(resting, restingHR: 50, hrMax: 185, tables: tables), 0)
    }

    func testEffortMappingOnTheTrialAnchor() {
        // 26 Aug's anchor: WHOOP read 20.5 where the earlier reconstruction read 19.5 — so a
        // This checks DISPLAY MAPPING ONLY, not an end-to-end re-score of the absent trial data.
        // WHOOP 20.5 must land on the 0–100 Effort axis at exactly 20.5 * 100/21. NOOP displays
        // Effort on its own scale; the WHOOP number passes through un-truncated.
        XCTAssertEqual(StrainScorer.effortValue(fromWhoopStrain: 20.5), 97.61904761904762, accuracy: 1e-12)
    }

    /// A minute at exactly 30 % of reserve counts nothing; just above it counts.
    func testReserveAtExactlyThirtyPercentIsZero() {
        // resting 60, max 187 → reserve span 130 (max + 3); 99 bpm is exactly 30 %.
        XCTAssertEqual(WhoopStrain.reserve(99, restingHR: 60, hrMax: 187), 0)
        XCTAssertGreaterThan(WhoopStrain.reserve(99.5, restingHR: 60, hrMax: 187), 0)
    }
}
