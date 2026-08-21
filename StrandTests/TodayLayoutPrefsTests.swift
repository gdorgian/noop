import XCTest
@testable import Strand

/// Default order, encode/decode round-trip, reorder, and the never-hide "insert missing section at its
/// default position" invariant (#today-layout), pinning the persisted "today.sectionOrder" wire format.
///
/// Formerly the twin of the Android `TodayLayoutPrefsTest`. That is no longer a contract: the parity
/// obligation was retired on 2026-07-23 (iOS/macOS-only — see CLAUDE.md), and the enums have since
/// diverged, `coach` and `dataSources` existing only here. The wire format still matters for THIS
/// platform's saved layouts, so the raw keys stay pinned below — just not against Kotlin.
final class TodayLayoutPrefsTests: XCTestCase {

    func testEmptyOrUnsetYieldsDefaultOrder() {
        XCTAssertEqual(TodayLayoutPrefs.decodeOrder(""), TodaySection.defaultOrder)
        XCTAssertEqual(TodayLayoutPrefs.decodeOrder("   "), TodaySection.defaultOrder)
    }

    /// `coach` sits deliberately mid-list rather than at the front: it is FIRST in `defaultOrder`, so a
    /// decoder that re-inserted it at its default position instead of honouring the saved one would still
    /// look right in every other test here.
    func testEncodeDecodeRoundTripsAReorderedList() {
        let reordered: [TodaySection] = [
            .heartRate, .goals, .hero, .yourCards, .coach, .liveSession, .synthesis,
            .keyMetrics, .workouts, .recoveryVitals, .menstrualCycle, .journal, .dataSources, .addedCards,
        ]
        let encoded = TodayLayoutPrefs.encode(reordered)
        XCTAssertEqual(encoded, "heartRate,goals,hero,yourCards,coach,liveSession,synthesis,keyMetrics,workouts,recoveryVitals,menstrualCycle,journal,dataSources,addedCards")
        XCTAssertEqual(TodayLayoutPrefs.decodeOrder(encoded), reordered)
    }

    /// The v1 upgrade path: an order saved by the FIRST cut (6 sections — no hero/liveSession, which were
    /// pinned then) must surface the newer sections at the TOP (their default position), not teleport
    /// them to the bottom of the user's saved order. `coach` is the newest such section and leads the
    /// default order, so it lands ahead of hero/liveSession.
    func testSavedOrderFromFirstCutInsertsHeroAndSessionAtTheirDefaultPosition() {
        let firstCut = "synthesis,keyMetrics,workouts,heartRate,recoveryVitals,yourCards"
        XCTAssertEqual(
            TodayLayoutPrefs.decodeOrder(firstCut),
            [.coach, .hero, .liveSession, .synthesis, .goals, .keyMetrics, .workouts, .heartRate,
             .recoveryVitals, .yourCards, .menstrualCycle, .journal, .dataSources, .addedCards]
        )
    }

    func testInsertsAnyMissingSectionAtItsDefaultPositionRelativeToSaved() {
        let partial = "heartRate,synthesis,keyMetrics,recoveryVitals"
        XCTAssertEqual(
            TodayLayoutPrefs.decodeOrder(partial),
            [.coach, .hero, .liveSession, .goals, .workouts, .heartRate, .synthesis, .keyMetrics,
             .recoveryVitals, .yourCards, .menstrualCycle, .journal, .dataSources, .addedCards]
        )
    }

    func testDropsUnknownTokensAndCollapsesDuplicates() {
        let messy = "yourCards,BOGUS,yourCards,heartRate, ,heartRate"
        XCTAssertEqual(
            TodayLayoutPrefs.decodeOrder(messy),
            [.coach, .hero, .liveSession, .synthesis, .goals, .keyMetrics, .workouts, .recoveryVitals,
             .yourCards, .heartRate, .menstrualCycle, .journal, .dataSources, .addedCards]
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
            [.coach, .goals, .heartRate, .yourCards, .liveSession, .synthesis, .keyMetrics, .recoveryVitals,
             .menstrualCycle, .journal, .dataSources, .addedCards]
        )
        XCTAssertEqual(TodayLayoutPrefs.decodeOrder(order), [
            .coach, .goals, .heartRate, .hero, .yourCards, .liveSession, .synthesis, .keyMetrics, .workouts,
            .recoveryVitals, .menstrualCycle, .journal, .dataSources, .addedCards,
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
        // Pin the exact wire strings: they are the persisted identity, so renaming one silently resets
        // that section's saved position for every existing user.
        XCTAssertEqual(
            raws,
            ["coach", "hero", "liveSession", "synthesis", "goals", "keyMetrics", "workouts",
             "heartRate", "recoveryVitals", "yourCards", "menstrualCycle", "journal", "dataSources",
             "addedCards"]
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
