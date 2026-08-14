import XCTest
@testable import Strand

/// FORK: pins that Today states each number ONCE.
///
/// The screen grew three independent metric surfaces — the hero gauges, the KEY METRICS grid, and the
/// YOUR CARDS list — each with its own default set and its own visual grammar. Every default happened to
/// be "show everything", so a stock Today rendered HRV three times, resting HR three times, and
/// Charge/Effort/Rest twice. Worse, the grid labelled the hero's Charge and Effort as "Recovery" and
/// "Strain", so the duplicates did not even read as duplicates — they read as four more metrics.
///
/// Nothing was deleted to fix it: every tile and card stays in its canonical registry so the CUSTOMISE
/// sheet still offers all of them. Only the DEFAULTS changed. That is easy to undo by accident — adding a
/// tile back to a default list is a one-line change that looks harmless — so the no-overlap rule is
/// pinned here rather than left as a comment.
final class TodayDeduplicationTests: XCTestCase {

    /// Shown by the hero gauges at the top of Today.
    private let heroScores: Set<KeyMetric> = [.charge, .effort, .rest]
    /// Shown as rows in the RECOVERY VITALS card.
    private let recoveryVitals: Set<KeyMetric> = [.hrv, .restingHr, .respiratory]

    // MARK: - Key Metrics

    func testKeyMetricDefaultsDoNotRepeatTheHeroScores() {
        let defaults = Set(KeyMetric.defaultOrder)
        XCTAssertTrue(defaults.isDisjoint(with: heroScores),
                      "these are the hero gauges directly above the grid: "
                      + "\(defaults.intersection(heroScores).map(\.rawValue).sorted())")
    }

    func testKeyMetricDefaultsDoNotRepeatTheRecoveryVitals() {
        let defaults = Set(KeyMetric.defaultOrder)
        XCTAssertTrue(defaults.isDisjoint(with: recoveryVitals),
                      "these are already rows in RECOVERY VITALS: "
                      + "\(defaults.intersection(recoveryVitals).map(\.rawValue).sorted())")
    }

    /// De-duplicating must not empty the section — an empty grid would leave a bare header.
    func testKeyMetricDefaultsAreNotEmpty() {
        XCTAssertFalse(KeyMetric.defaultOrder.isEmpty)
    }

    /// The default is a SUBSET of the registry. If a tile were defaulted-on without being canonical, the
    /// editor could not list it and the wearer could never turn it back off.
    func testEveryDefaultKeyMetricIsOfferedByTheEditor() {
        XCTAssertTrue(Set(KeyMetric.defaultOrder).isSubset(of: Set(KeyMetric.canonicalOrder)))
    }

    /// Trimming the DEFAULT must never trim what the editor offers — that is the difference between
    /// "not shown until you ask" and "removed from the app".
    func testTheEditorStillOffersEveryKnownTile() {
        XCTAssertEqual(Set(KeyMetric.canonicalOrder), Set(KeyMetric.allCases))
        XCTAssertEqual(KeyMetric.canonicalOrder.count, KeyMetric.allCases.count)
    }

    func testNoDuplicateTilesWithinEitherList() {
        XCTAssertEqual(Set(KeyMetric.defaultOrder).count, KeyMetric.defaultOrder.count)
        XCTAssertEqual(Set(KeyMetric.canonicalOrder).count, KeyMetric.canonicalOrder.count)
    }

    // MARK: - Your Cards

    /// HRV and resting HR were in this default AND in RECOVERY VITALS AND in the Key Metrics grid — the
    /// three-times case.
    func testDashboardDefaultsDoNotRepeatTheRecoveryVitals() {
        let defaults = Set(DashboardCard.defaultSelection.map(\.rawValue))
        for duplicated in ["hrv", "restingHr", "respiratory"] {
            XCTAssertFalse(defaults.contains(duplicated),
                           "\(duplicated) is already a RECOVERY VITALS row")
        }
    }

    func testDashboardDefaultsAreNotEmpty() {
        XCTAssertFalse(DashboardCard.defaultSelection.isEmpty)
    }

    func testEveryDefaultCardIsOfferedByTheEditor() {
        XCTAssertTrue(Set(DashboardCard.defaultSelection).isSubset(of: Set(DashboardCard.canonicalOrder)))
    }

    func testTheEditorStillOffersEveryKnownCard() {
        XCTAssertEqual(Set(DashboardCard.canonicalOrder), Set(DashboardCard.allCases))
    }

    // MARK: - Decoding still honours a customised layout

    /// The whole change is a DEFAULT. A wearer who has already chosen their tiles must be unaffected —
    /// including one who deliberately chose a tile the new default drops.
    func testAStoredSelectionStillWinsOverTheNewDefault() {
        let stored = KeyMetricPrefs.encode([.charge, .hrv])
        XCTAssertEqual(KeyMetricPrefs.decodeEnabled(stored), [.charge, .hrv])
    }

    func testAnUnsetSelectionFallsBackToTheDeduplicatedDefault() {
        XCTAssertEqual(KeyMetricPrefs.decodeEnabled(""), KeyMetric.defaultOrder)
        XCTAssertEqual(KeyMetricPrefs.decodeEnabled("   "), KeyMetric.defaultOrder)
    }

    func testAStoredCardSelectionStillWinsOverTheNewDefault() {
        let stored = DashboardCardPrefs.encode([.hrv, .stress])
        XCTAssertEqual(DashboardCardPrefs.decodeEnabled(stored), [.hrv, .stress])
    }
}
