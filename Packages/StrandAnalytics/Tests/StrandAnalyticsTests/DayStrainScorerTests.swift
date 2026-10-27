import XCTest
import Foundation
import WhoopProtocol
@testable import StrandAnalytics

final class DayStrainScorerTests: XCTestCase {
    private var samples: [HRSample] {
        (0..<600).map { HRSample(ts: 3_000 + $0, bpm: 150) }
    }

    private var tables: WhoopStrain.Tables {
        WhoopStrain.Tables(scale: [.init(raw: 0, strain: 0), .init(raw: 0.001, strain: 10),
                                    .init(raw: 1, strain: 21)], targets: nil)
    }

    func testInstalledTablesSelectWHOOPAndMapOntoEffortAxis() throws {
        var lines: [String] = []
        let value = try XCTUnwrap(DayStrainScorer.score(samples, maxHR: 185, restingHR: 50,
                                                       diag: { lines.append($0) }, tables: tables))
        XCTAssertEqual(value, 10 * 100 / 21, accuracy: 1e-12)
        XCTAssertNotEqual(value, StrainScorer.strain(samples, maxHR: 185, restingHR: 50))
        XCTAssertEqual(lines, ["effort method: whoop (WHOOP tables bundled)"])
    }

    func testAbsentTablesRetainEachIndependentMethodAndNameIt() {
        for method in [StrainScorer.Method.edwards, .banister] {
            var lines: [String] = []
            let result = DayStrainScorer.score(samples, maxHR: 185, restingHR: 50,
                                               method: method, sex: "female",
                                               diag: { lines.append($0) }, tables: nil)
            XCTAssertEqual(result, StrainScorer.strain(samples, maxHR: 185, restingHR: 50,
                                                       method: method, sex: "female"))
            let name = method == .edwards ? "edwards" : "banister"
            XCTAssertEqual(lines.last, "effort method: \(name) (fallback: tables absent)")
        }
    }

    func testMissingHRmaxNamesTheCalibrationGapWithTablesInstalled() {
        var lines: [String] = []
        let result = DayStrainScorer.score(samples, restingHR: 50, method: .banister,
                                           diag: { lines.append($0) }, tables: tables)
        XCTAssertEqual(result, StrainScorer.strain(samples, restingHR: 50, method: .banister))
        XCTAssertEqual(lines.last, "effort method: banister (fallback: HRmax unavailable)")
        XCTAssertFalse(lines.last?.contains("tables absent") ?? true)
    }

    func testInvalidHRmaxNamesTheInvalidCalibration() {
        var lines: [String] = []
        XCTAssertNil(DayStrainScorer.score(samples, maxHR: 40, restingHR: 50,
                                           diag: { lines.append($0) }, tables: tables))
        XCTAssertEqual(lines.last, "effort method: edwards (fallback: invalid HRmax/resting HR)")
    }

    func testWHOOPNoDataStaysUnknownWithoutIndependentFallback() {
        let misreads = (0..<600).map { HRSample(ts: 3_000 + $0, bpm: 20) }
        for input in [[], misreads] {
            var lines: [String] = []
            XCTAssertNil(DayStrainScorer.score(input, maxHR: 185, restingHR: 50,
                                               diag: { lines.append($0) }, tables: tables))
            XCTAssertEqual(lines, ["effort method: whoop (no usable HR)"])
        }
    }

    func testMeasuredQuietDayRemainsAZero() {
        let quiet = (0..<600).map { HRSample(ts: 3_000 + $0, bpm: 50) }
        XCTAssertEqual(DayStrainScorer.score(quiet, maxHR: 185, restingHR: 50, tables: tables), 0)
    }

    func testCacheIdentityIncludesMethodAndBothTables() {
        let scale = tables.scale
        let target = WhoopStrain.TargetRow(recovery: 50, lower: 5, target: 10, upper: 15)
        let withTarget = WhoopStrain.Tables(scale: scale, targets: [target])
        let original = DayStrainScorer.cacheIdentity(tables: withTarget)
        XCTAssertFalse(original.contains("|"), "identity must remain one analysis-config field")
        XCTAssertNotEqual(original, DayStrainScorer.cacheIdentity(tables: nil))
        XCTAssertNotEqual(original, DayStrainScorer.cacheIdentity(method: .banister, tables: withTarget))
        XCTAssertNotEqual(original, DayStrainScorer.cacheIdentity(tables: tables))
        XCTAssertNotEqual(DayStrainScorer.cacheIdentity(tables: tables),
                          DayStrainScorer.cacheIdentity(tables: .init(scale: scale, targets: [])))
        for changed in [
            WhoopStrain.TargetRow(recovery: 51, lower: 5, target: 10, upper: 15),
            .init(recovery: 50, lower: 6, target: 10, upper: 15),
            .init(recovery: 50, lower: 5, target: 11, upper: 15),
            .init(recovery: 50, lower: 5, target: 10, upper: 16),
        ] {
            XCTAssertNotEqual(original, DayStrainScorer.cacheIdentity(tables: .init(scale: scale, targets: [changed])))
        }
        let changedScale = WhoopStrain.Tables(scale: [.init(raw: 0, strain: 0), .init(raw: 0.002, strain: 10),
                                                      .init(raw: 1, strain: 21)], targets: [target])
        XCTAssertNotEqual(original, DayStrainScorer.cacheIdentity(tables: changedScale))
    }

    func testCacheIdentityIsStableAndIndependentOfJSONFormatting() throws {
        let compact = try WhoopStrain.Tables.parse(
            scaleData: Data("[[0,0],[0.01,10],[1,21]]".utf8), targetsData: nil)
        let spaced = try WhoopStrain.Tables.parse(
            scaleData: Data("[ [0.0, 0], [0.010, 10.0], [1.0, 21] ]".utf8), targetsData: nil)
        // Pinned independently using Python's explicit little-endian IEEE-754 bytes and FNV-1a.
        XCTAssertEqual(DayStrainScorer.cacheIdentity(tables: compact),
                       "day-strain-v2:fallback=edwards:tables=aaf1574734f59de8")
        XCTAssertEqual(DayStrainScorer.cacheIdentity(tables: compact),
                       DayStrainScorer.cacheIdentity(tables: spaced))
    }
}
