#if os(iOS)
import XCTest
@testable import NOOP_Staging

/// The calm defaults (docs/aura/defaults.md): units from the region, which notices start on, and how a
/// page the wearer arranged treats a section a later build adds.
@MainActor
final class NoopDefaultsTests: XCTestCase {

    private var page = ""

    override func setUp() {
        super.setUp()
        page = "test-\(UUID().uuidString)"
    }

    override func tearDown() {
        for suffix in ["", ".known", ".version"] {
            UserDefaults.standard.removeObject(forKey: "noop.layout.\(page)\(suffix)")
        }
        super.tearDown()
    }

    func testUnitsAreImperialOnlyForUSMeasurements() {
        XCTAssertEqual(NoopDefaults.unitSystem(for: .us), .imperial)
        XCTAssertEqual(NoopDefaults.unitSystem(for: .metric), .metric)
        XCTAssertEqual(NoopDefaults.unitSystem(for: .uk), .metric)
    }

    func testOnlyTheNightAndTheBackupNoticesStartOn() {
        XCTAssertTrue(AuraNotices.Kind.morning.defaultOn)
        XCTAssertTrue(AuraNotices.Kind.backup.defaultOn)
        XCTAssertFalse(AuraNotices.Kind.bedtime.defaultOn)
        XCTAssertFalse(AuraNotices.Kind.best.defaultOn)
        XCTAssertFalse(AuraNotices.Kind.weekly.defaultOn)
    }

    private func section(_ id: String, on: Bool = true) -> NoopPageSection {
        NoopPageSection(id: id, title: id, detail: "", onByDefault: on)
    }

    func testAFreshPageShowsOnlyItsDefaults() {
        let layout = NoopPageLayout(page: page, catalog: [section("a"), section("alt", on: false), section("b")])
        XCTAssertEqual(layout.order, ["a", "b"])
        XCTAssertTrue(layout.suggestions.isEmpty)
        XCTAssertFalse(NoopPageLayout.hasArrangement(page: page, catalog: layout.catalog))
    }

    func testANewSectionIsOfferedNotSlippedIntoAnArrangedPage() {
        NoopPageLayout(page: page, catalog: [section("a"), section("b")]).save(["b", "a"])

        let later = NoopPageLayout(page: page, catalog: [section("a"), section("b"), section("c")])
        XCTAssertEqual(later.order, ["b", "a"], "an arranged page keeps its order")
        XCTAssertEqual(later.suggestions, ["c"])

        later.acceptSuggestion("c")
        XCTAssertEqual(later.order, ["b", "c", "a"], "added after the nearest default section above it")
        XCTAssertTrue(later.suggestions.isEmpty)
        XCTAssertTrue(NoopPageLayout(page: page, catalog: later.catalog).suggestions.isEmpty)
    }

    func testADeclinedSectionIsNotOfferedAgain() {
        NoopPageLayout(page: page, catalog: [section("a")]).save(["a"])
        let later = NoopPageLayout(page: page, catalog: [section("a"), section("c")])
        later.declineSuggestion("c")
        let again = NoopPageLayout(page: page, catalog: later.catalog)
        XCTAssertEqual(again.order, ["a"])
        XCTAssertTrue(again.suggestions.isEmpty)
    }

    func testSavingAnEditDoesNotQuietlyDeclineAnOffer() {
        NoopPageLayout(page: page, catalog: [section("a"), section("b")]).save(["a", "b"])
        let later = NoopPageLayout(page: page, catalog: [section("a"), section("b"), section("c")])
        later.save(["b", "a"])
        XCTAssertEqual(NoopPageLayout(page: page, catalog: later.catalog).suggestions, ["c"])
    }

    func testUsingTheDefaultForgetsTheArrangement() {
        let catalog = [section("a"), section("b"), section("alt", on: false)]
        NoopPageLayout(page: page, catalog: catalog).save(["alt", "a"])
        XCTAssertTrue(NoopPageLayout.hasArrangement(page: page, catalog: catalog))

        let layout = NoopPageLayout(page: page, catalog: catalog)
        layout.useDefault()
        XCTAssertEqual(layout.order, ["a", "b"])
        XCTAssertFalse(NoopPageLayout.hasArrangement(page: page, catalog: catalog))
    }
}
#endif
