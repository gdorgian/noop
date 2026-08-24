import XCTest
@testable import StrandAnalytics

/// The measurement that can actually settle the v18 units question, and the guards that stop it
/// overstating a thin sample.
final class RRUnitEvidenceTests: XCTestCase {

    private func pair(_ liveMs: Int, _ historicalRaw: Int, ts: Int = 1_780_916_150) -> RRUnitEvidence.Pair {
        RRUnitEvidence.Pair(ts: ts, liveMs: liveMs, historicalRaw: historicalRaw)
    }

    // MARK: One pair

    /// The pair reported upstream from a #1451 diagnostic: `-1s[872#0, 893#0]`, both at ord 0.
    func testTheUpstreamFieldPairReadsAsTheConversion() {
        XCTAssertTrue(pair(872, 893).matchesTickConversion)
        XCTAssertEqual(pair(872, 893).ratio, 1.0241, accuracy: 1e-4)
    }

    /// Ordinary beat-to-beat variability must NOT read as a units match, or the whole measurement is
    /// circular. 21 ms on a ~600 ms beat is 3.5% — well outside the window; 21 ms on an 872 ms beat is
    /// 2.4%, which is exactly why a single pair proves nothing and the tolerance is tight.
    func testAnOrdinaryBeatToBeatStepIsNotAUnitsMatch() {
        XCTAssertFalse(pair(600, 621).matchesTickConversion, "3.5% is not the conversion")
        XCTAssertFalse(pair(800, 800).matchesTickConversion, "identical values are the ms hypothesis")
        XCTAssertFalse(pair(800, 760).matchesTickConversion, "a shorter next beat is not the conversion")
    }

    // MARK: Verdicts

    func testAPileUpAtTheConversionReadsAsTicks() {
        // 40 pairs, each the same beat in two units, with the integer rounding both sides apply.
        let pairs = (0..<40).map { index -> RRUnitEvidence.Pair in
            let live = 700 + index * 3
            return pair(live, Int((Double(live) * RRUnitEvidence.tickRatio).rounded()), ts: 1_780_916_000 + index)
        }
        let verdict = RRUnitEvidence.verdict(for: pairs)
        XCTAssertEqual(verdict.pairs, 40)
        XCTAssertGreaterThanOrEqual(verdict.fractionMatchingTicks, 0.9)
        XCTAssertEqual(verdict.medianRatio, RRUnitEvidence.tickRatio, accuracy: 0.002)
        XCTAssertTrue(verdict.summary.contains("1/1024-s ticks"), verdict.summary)
    }

    func testAgreementAtIdentityReadsAsMilliseconds() {
        let pairs = (0..<40).map { pair(700 + $0 * 3, 700 + $0 * 3, ts: 1_780_916_000 + $0) }
        let verdict = RRUnitEvidence.verdict(for: pairs)
        XCTAssertEqual(verdict.matchingIdentity, 40)
        XCTAssertEqual(verdict.matchingTickConversion, 0)
        XCTAssertTrue(verdict.summary.contains("transports agree"), verdict.summary)
    }

    /// Two genuinely different beats in one second must not be read as a units finding either way.
    func testScatteredRatiosConcludeNothing() {
        let deltas = [-38, 25, -17, 41, -29, 12, 33, -21, 19, -35,
                      27, -14, 44, -31, 16, 37, -23, 11, -40, 29,
                      -18, 35, -26, 14, 42, -33, 21, -15, 39, -28,
                      17, 31, -20, 13, -36, 24, -11, 43, -30, 18]
        let pairs = deltas.enumerated().map { index, delta in
            pair(700 + index * 3, 700 + index * 3 + delta, ts: 1_780_916_000 + index)
        }
        let verdict = RRUnitEvidence.verdict(for: pairs)
        XCTAssertLessThan(verdict.fractionMatchingTicks, 0.5)
        XCTAssertTrue(verdict.summary.contains("probably different beats"), verdict.summary)
    }

    /// The third state, which only exists once a CONVERTING build has banked rows: if v18 was
    /// milliseconds all along, our conversion made the historical copy 2.4% short, and the diagnostic has
    /// to say so rather than reading a 0.977 cluster as "different beats".
    func testAnOverConvertedHistoricalCopyIsCalledOut() {
        let pairs = (0..<40).map { index -> RRUnitEvidence.Pair in
            let live = 700 + index * 3
            return pair(live, Int((Double(live) / RRUnitEvidence.tickRatio).rounded()), ts: 1_780_916_000 + index)
        }
        let verdict = RRUnitEvidence.verdict(for: pairs)
        XCTAssertGreaterThanOrEqual(verdict.matchingOverConversion, 36)
        XCTAssertTrue(verdict.summary.contains("revert it"), verdict.summary)
    }

    // MARK: The honesty gate

    /// The whole point of the gate: one pair that happens to land on 1.024 must not print a conclusion.
    /// This is the shape of evidence that withdrew #194.
    func testASinglePairRefusesToConclude() {
        let verdict = RRUnitEvidence.verdict(for: [pair(872, 893)])
        XCTAssertEqual(verdict.pairs, 1)
        XCTAssertEqual(verdict.fractionMatchingTicks, 1.0, "it does match — that is not the same as proof")
        XCTAssertTrue(verdict.summary.contains("too few pairs"), verdict.summary)
        XCTAssertFalse(verdict.summary.contains("ticks."), verdict.summary)
    }

    func testNoPairsSaysSoRatherThanReturningZeroes() {
        let verdict = RRUnitEvidence.verdict(for: [])
        XCTAssertEqual(verdict.pairs, 0)
        XCTAssertTrue(verdict.summary.contains("nothing to compare"), verdict.summary)
    }

    func testRowsWithAZeroSideAreDiscardedNotScored() {
        let verdict = RRUnitEvidence.verdict(for: [pair(0, 893), pair(872, 0), pair(872, 893)])
        XCTAssertEqual(verdict.pairs, 1, "a missing side is not a ratio")
    }

    // MARK: Lag search

    func testLagSearchFindsReceiveTimeSkewAcrossContinuousRows() {
        let base = 1_780_916_000
        let historical = (0..<40).map {
            RRUnitEvidence.TimedValue(ts: base + $0, value: 650 + ($0 * 17) % 271)
        }
        let live = historical.map {
            RRUnitEvidence.TimedValue(ts: $0.ts + 3, value: $0.value)
        }

        let search = RRUnitEvidence.lagSearch(live: live, historical: historical)

        XCTAssertEqual(search.candidates.map(\.lagSeconds), Array(-5...5))
        XCTAssertEqual(search.best?.lagSeconds, 3)
        XCTAssertEqual(search.best?.verdict.pairs, 40)
        XCTAssertEqual(search.best?.verdict.exactValueMatches, 40)
        XCTAssertEqual(search.best?.verdict.mismatches, 0)
        XCTAssertEqual(search.best?.coverage ?? 0, 1, accuracy: 1e-12)
    }

    func testLagSearchPreservesSameSecondOrderAndDoesNotCollapseExtraBeats() throws {
        let base = 1_780_916_000
        // Deliberately not value-sorted. MIN/MAX or rrMs sorting would change this sequence.
        let historical = [
            RRUnitEvidence.TimedValue(ts: base, value: 900),
            RRUnitEvidence.TimedValue(ts: base, value: 700),
        ]
        let live = [
            RRUnitEvidence.TimedValue(ts: base + 3, value: 900),
            RRUnitEvidence.TimedValue(ts: base + 3, value: 700),
            RRUnitEvidence.TimedValue(ts: base + 3, value: 800),
        ]

        let result = try XCTUnwrap(
            RRUnitEvidence.lagSearch(live: live, historical: historical).best)

        XCTAssertEqual(result.lagSeconds, 3)
        XCTAssertEqual(result.pairs.map(\.liveMs), [900, 700])
        XCTAssertEqual(result.pairs.map(\.historicalRaw), [900, 700])
        XCTAssertEqual(result.verdict.pairs, 2, "pair every ordered row available, not one MIN row")
        XCTAssertEqual(result.coverage, 2.0 / 3.0, accuracy: 1e-12,
                       "the unmatched third live row remains visible in coverage")
    }

    func testLagSearchReturnsNoBestWhenTheTransportsDoNotOverlap() {
        let live = [RRUnitEvidence.TimedValue(ts: 100, value: 800)]
        let historical = [RRUnitEvidence.TimedValue(ts: 1_000, value: 800)]
        let search = RRUnitEvidence.lagSearch(live: live, historical: historical)

        XCTAssertNil(search.best)
        XCTAssertTrue(search.candidates.allSatisfy { $0.verdict.pairs == 0 })
    }
}
