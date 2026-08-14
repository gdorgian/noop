import XCTest
import WhoopStore
@testable import Strand

/// Pins the Mi Band merge precedence.
///
/// The Mi Fitness import always landed in the same tables under `xiaomi-band`, but `refresh()` only asked
/// for the strap, its computed sibling, Apple Health and activity files — so an imported year was visible
/// on the Mi Band screen and nowhere else. Folding it in is a DATA-PATH change, and the risk is not a
/// crash: it is a wrist-worn strap's measured value being quietly overwritten by a second device's
/// estimate for the same day. That direction is what these pin.
final class XiaomiMergeTests: XCTestCase {

    private func day(_ d: String,
                     steps: Int? = nil,
                     restingHr: Int? = nil,
                     totalSleepMin: Double? = nil,
                     recovery: Double? = nil) -> DailyMetric {
        DailyMetric(day: d, totalSleepMin: totalSleepMin, efficiency: nil, deepMin: nil,
                    remMin: nil, lightMin: nil, disturbances: nil, restingHr: restingHr,
                    avgHrv: nil, recovery: recovery, strain: nil, exerciseCount: nil,
                    steps: steps)
    }

    // MARK: - The strap always wins

    /// The load-bearing one. A day the WHOOP measured must keep the WHOOP's number.
    func testStrapValueSurvivesAMiBandValueForTheSameDay() {
        let base = [day("2026-08-01", restingHr: 52)]
        let mi = [day("2026-08-01", restingHr: 61)]
        let merged = Repository.mergeXiaomi(into: base, mi)
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].restingHr, 52, "Mi Band overwrote a measured strap value")
    }

    /// …but it fills the fields the strap left empty on that same day.
    func testMiBandFillsOnlyTheFieldsTheStrapLeftNil() {
        let base = [day("2026-08-01", steps: nil, restingHr: 52)]
        let mi = [day("2026-08-01", steps: 9_000, restingHr: 61)]
        let merged = Repository.mergeXiaomi(into: base, mi)
        XCTAssertEqual(merged[0].restingHr, 52)      // strap keeps what it had
        XCTAssertEqual(merged[0].steps, 9_000)       // and the gap is filled
    }

    // MARK: - Days the strap never saw

    /// The whole point of the merge: history from before the strap existed.
    func testADayTheStrapNeverSawIsTakenWhole() throws {
        let base = [day("2026-08-01", restingHr: 52)]
        let mi = [day("2025-03-14", steps: 12_000, totalSleepMin: 430)]
        let merged = Repository.mergeXiaomi(into: base, mi)
        XCTAssertEqual(merged.count, 2)
        let old = try XCTUnwrap(merged.first { $0.day == "2025-03-14" })
        XCTAssertEqual(old.steps, 12_000)
        XCTAssertEqual(old.totalSleepMin, 430)
    }

    func testResultStaysSortedByDay() {
        let base = [day("2026-08-01"), day("2026-08-03")]
        let mi = [day("2025-01-01"), day("2026-08-02")]
        let merged = Repository.mergeXiaomi(into: base, mi)
        XCTAssertEqual(merged.map(\.day), ["2025-01-01", "2026-08-01", "2026-08-02", "2026-08-03"])
    }

    // MARK: - Degenerate input

    func testNoMiBandDataLeavesTheBaseExactlyAsItWas() {
        let base = [day("2026-08-01", restingHr: 52), day("2026-08-02", steps: 100)]
        XCTAssertEqual(Repository.mergeXiaomi(into: base, []), base)
    }

    func testMiBandOnlyInstallStillProducesEveryDay() {
        let mi = [day("2025-01-01", steps: 1), day("2025-01-02", steps: 2)]
        XCTAssertEqual(Repository.mergeXiaomi(into: [], mi).map(\.day), ["2025-01-01", "2025-01-02"])
    }

    /// A duplicate day in `base` must not trap the way `Dictionary(uniqueKeysWithValues:)` would.
    func testADuplicateDayInTheBaseDoesNotTrap() {
        let base = [day("2026-08-01", restingHr: 52), day("2026-08-01", restingHr: 53)]
        let merged = Repository.mergeXiaomi(into: base, [day("2026-08-01", steps: 500)])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].steps, 500)
    }

    // MARK: - What the merge must NOT invent

    /// Recovery is scored from HRV over R-R intervals against a personal baseline; the Mi Fitness export
    /// carries no beat-to-beat data at all. A Mi-Band-only day must therefore stay blank on it rather than
    /// be handed a number — this pins that the merge itself never fabricates one.
    func testAMiBandOnlyDayCarriesNoRecoveryUnlessTheImportSuppliedOne() {
        let merged = Repository.mergeXiaomi(into: [], [day("2025-03-14", steps: 12_000)])
        XCTAssertNil(merged[0].recovery)
    }

    /// And the mirror: the strap's own Recovery on a shared day is never displaced.
    func testStrapRecoverySurvivesAMiBandRowForTheSameDay() {
        let base = [day("2026-08-01", recovery: 74)]
        let merged = Repository.mergeXiaomi(into: base, [day("2026-08-01", steps: 9_000)])
        XCTAssertEqual(merged[0].recovery, 74)
        XCTAssertEqual(merged[0].steps, 9_000)
    }
}
