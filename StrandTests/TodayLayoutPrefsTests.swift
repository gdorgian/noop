import XCTest
@testable import Strand

/// Twin of the Android `TodayLayoutPrefsTest` (#today-layout): default order, encode/decode round-trip,
/// reorder, and the never-hide "insert missing section at its default position" invariant — pinned on both
/// platforms so the byte-identical "today.sectionOrder" wire format can't drift.
final class TodayLayoutPrefsTests: XCTestCase {

    func testEmptyOrUnsetYieldsDefaultOrder() {
        XCTAssertEqual(TodayLayoutPrefs.decodeOrder(""), TodaySection.defaultOrder)
        XCTAssertEqual(TodayLayoutPrefs.decodeOrder("   "), TodaySection.defaultOrder)
    }

    func testEncodeDecodeRoundTripsAReorderedList() {
        let reordered: [TodaySection] = [
            .heartRate, .hero, .yourCards, .liveSession, .synthesis, .keyMetrics, .workouts, .recoveryVitals,
            .journal, .menstrualCycle, .addedCards,
        ]
        let encoded = TodayLayoutPrefs.encode(reordered)
        XCTAssertEqual(encoded, "heartRate,hero,yourCards,liveSession,synthesis,keyMetrics,workouts,recoveryVitals,journal,menstrualCycle,addedCards")
        XCTAssertEqual(TodayLayoutPrefs.decodeOrder(encoded), reordered)
    }

    /// The v1 upgrade path: an order saved by the FIRST cut (6 sections — no hero/liveSession, which were
    /// pinned then) must surface the two new sections at the TOP (their default position), not teleport
    /// them to the bottom of the user's saved order.
    func testSavedOrderFromFirstCutInsertsHeroAndSessionAtTheirDefaultPosition() {
        let firstCut = "synthesis,keyMetrics,workouts,heartRate,recoveryVitals,yourCards"
        XCTAssertEqual(
            TodayLayoutPrefs.decodeOrder(firstCut),
            // hero(1) lands straight after synthesis(0); liveSession(5) between keyMetrics(4) and
            // workouts(6). menstrualCycle(8)/journal(9)/addedCards(10) follow everything saved → appended.
            [.synthesis, .hero, .keyMetrics, .liveSession, .workouts, .heartRate, .recoveryVitals, .yourCards, .menstrualCycle, .journal, .addedCards]
        )
    }

    func testInsertsAnyMissingSectionAtItsDefaultPositionRelativeToSaved() {
        let partial = "heartRate,synthesis,keyMetrics,recoveryVitals"
        XCTAssertEqual(
            TodayLayoutPrefs.decodeOrder(partial),
            // The SAVED sequence is preserved verbatim (heartRate still precedes synthesis even though the
            // default now has it after) — only the missing sections are placed by default position.
            [.hero, .heartRate, .synthesis, .keyMetrics, .recoveryVitals, .liveSession, .workouts, .yourCards, .menstrualCycle, .journal, .addedCards]
        )
    }

    func testDropsUnknownTokensAndCollapsesDuplicates() {
        let messy = "yourCards,BOGUS,yourCards,heartRate, ,heartRate"
        XCTAssertEqual(
            TodayLayoutPrefs.decodeOrder(messy),
            // Everything defaulting above yourCards(7) precedes it; heartRate stays where it was SAVED
            // (after yourCards), not where the default would put it.
            [.synthesis, .hero, .recoveryVitals, .keyMetrics, .liveSession, .workouts, .yourCards, .heartRate, .menstrualCycle, .journal, .addedCards]
        )
    }

    // MARK: - Fork intent

    /// FORK: Today must LEAD WITH THE ANSWER. `synthesis` carries the greeting, the readiness pills and the
    /// one plain-language sentence saying what to do about the numbers; upstream placed it third, below the
    /// hero and the Start-session row. This pins the decision so a future rebase onto upstream's
    /// `defaultOrder` can't quietly restore the old sequence — the sections would all still be present and
    /// nothing would fail, the screen would just stop opening with the sentence.
    func testDefaultOrderLeadsWithTheSynthesisSentence() {
        XCTAssertEqual(TodaySection.defaultOrder.first, .synthesis)
        // The hero scores follow immediately — the sentence explains them, so it must not be stranded far
        // above the thing it is describing.
        XCTAssertEqual(TodaySection.defaultOrder.dropFirst().first, .hero)
        // An ACTION must not interrupt the readings at the top of the screen.
        let sessionIndex = try? XCTUnwrap(TodaySection.defaultOrder.firstIndex(of: .liveSession))
        XCTAssertGreaterThan(sessionIndex ?? 0, 3)
    }

    /// Every known section must still appear exactly once — reordering must never drop one, which would
    /// make it unreachable (the order registry is also what the Arrange sheet lists).
    func testDefaultOrderCoversEverySectionExactlyOnce() {
        XCTAssertEqual(Set(TodaySection.defaultOrder), Set(TodaySection.allCases))
        XCTAssertEqual(TodaySection.defaultOrder.count, TodaySection.allCases.count)
    }

    func testAllJunkYieldsDefaultOrder() {
        XCTAssertEqual(TodayLayoutPrefs.decodeOrder("nope,,zzz"), TodaySection.defaultOrder)
    }

    func testHiddenSectionsAreExplicitReversibleAndDeduplicated() {
        let hidden = TodayLayoutPrefs.decodeHidden("workouts,BOGUS,workouts,journal")
        XCTAssertEqual(hidden, [.workouts, .journal])
        XCTAssertEqual(TodayLayoutPrefs.encodeHidden(hidden), "workouts,journal")
    }

    func testVisibleOrderFiltersHiddenWithoutChangingSavedOrder() {
        let order = "heartRate,hero,yourCards,liveSession,synthesis,keyMetrics,workouts,recoveryVitals,journal"
        XCTAssertEqual(
            TodayLayoutPrefs.visibleOrder(orderRaw: order, hiddenRaw: "hero,workouts"),
            [.heartRate, .yourCards, .liveSession, .synthesis, .keyMetrics, .recoveryVitals, .menstrualCycle, .journal, .addedCards]
        )
        XCTAssertEqual(TodayLayoutPrefs.decodeOrder(order), [
            .heartRate, .hero, .yourCards, .liveSession, .synthesis, .keyMetrics, .workouts,
            .recoveryVitals, .menstrualCycle, .journal, .addedCards,
        ])
    }

    func testNewOrPreviouslyMissingSectionsDefaultToVisible() {
        XCTAssertTrue(
            TodayLayoutPrefs.visibleOrder(
                orderRaw: "synthesis,keyMetrics,workouts,heartRate,recoveryVitals,yourCards",
                hiddenRaw: "workouts"
            ).contains(.journal)
        )
    }

    /// defaultOrder must cover EVERY case: the never-hide merge iterates it, so a case missing from the
    /// default order could otherwise be dropped from render (Android) or mis-sorted (iOS).
    func testDefaultOrderCoversEveryCase() {
        XCTAssertEqual(Set(TodaySection.defaultOrder), Set(TodaySection.allCases))
        XCTAssertEqual(TodaySection.defaultOrder.count, TodaySection.allCases.count)
    }

    func testSectionRawKeysAreStableAndUnique() {
        let raws = TodaySection.allCases.map(\.rawValue)
        XCTAssertEqual(raws.count, Set(raws).count, "raw keys must be unique (they're the persisted identity)")
        // Pin the exact wire strings — they must match the Android TodaySection byte-for-byte.
        XCTAssertEqual(
            raws,
            ["hero", "liveSession", "synthesis", "keyMetrics", "workouts", "heartRate", "recoveryVitals", "yourCards", "menstrualCycle", "journal", "addedCards"]
        )
    }

    func testEditableLayoutHidesAndRestoresWithoutDeleting() {
        var draft = EditableLayoutDraft(
            visible: TodaySection.defaultOrder,
            allItems: TodaySection.defaultOrder
        )

        draft.hide(.workouts)
        XCTAssertFalse(draft.visible.contains(.workouts))
        XCTAssertEqual(draft.hidden, [.workouts])

        draft.show(.workouts)
        XCTAssertEqual(draft.visible.last, .workouts)
        XCTAssertTrue(draft.hidden.isEmpty)
        XCTAssertEqual(Set(draft.visible), Set(TodaySection.defaultOrder))
    }

    func testEditableLayoutKeepsAtLeastOneItemVisible() {
        // `canonicalOrder` is "every tile"; `defaultOrder` is only the ones a fresh install shows, so the
        // hidden remainder has to come from the canonical registry for this to mean what it reads as.
        var draft = EditableLayoutDraft(visible: [KeyMetric.hrv], hidden: KeyMetric.canonicalOrder.filter { $0 != .hrv })
        draft.hide(.hrv)
        XCTAssertEqual(draft.visible, [.hrv])
    }
}
