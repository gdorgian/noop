import XCTest
import WhoopStore
@testable import Strand

/// A computed session later passes stop finding is removed, but only on a day the pass re-detected.
final class SupersededSleepTests: XCTestCase {
    // 27 Oct 2026 00:00 UTC, with a UTC offset of 0 so day strings are plain.
    let midnight = 1_793_059_200
    func row(_ start: Int, _ end: Int, edited: Bool = false) -> CachedSleepSession {
        CachedSleepSession(startTs: start, endTs: end, efficiency: 0.9, restingHr: 60, avgHrv: 40,
                           stagesJSON: nil, userEdited: edited)
    }

    func testEveningBlockRejectedLaterIsRemoved() {
        let evening = row(midnight - 5_800, midnight + 300)          // 22:23–00:05
        let night = row(midnight + 9_000, midnight + 26_700)          // 02:30–07:25
        let gone = IntelligenceEngine.supersededSleep(stored: [evening, night], fresh: [night],
                                                      skipWindows: [], tzOffset: 0)
        XCTAssertEqual(gone, [evening])
    }

    func testEditedAndOverlappingAndUnscoredDaysStay() {
        let night = row(midnight + 9_000, midnight + 26_700)
        let edited = row(midnight - 5_800, midnight + 300, edited: true)
        let drifted = row(midnight + 8_940, midnight + 26_700)        // the overlap heal's job
        let lastWeek = row(midnight - 6 * 86_400, midnight - 6 * 86_400 + 25_000)
        let gone = IntelligenceEngine.supersededSleep(stored: [night, edited, drifted, lastWeek], fresh: [night],
                                                      skipWindows: [], tzOffset: 0)
        XCTAssertEqual(gone, [])
    }

    func testNothingFreshRemovesNothing() {
        let evening = row(midnight - 5_800, midnight + 300)
        XCTAssertEqual(IntelligenceEngine.supersededSleep(stored: [evening], fresh: [], skipWindows: [], tzOffset: 0), [])
    }
}
