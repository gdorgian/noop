import XCTest
import WhoopProtocol
@testable import StrandAnalytics

final class PersonalZonesTests: XCTestCase {

    private func trace(_ bpms: [Int], from t0: Int = 1_000) -> [HRSample] {
        bpms.enumerated().map { HRSample(ts: t0 + $0.offset, bpm: $0.element) }
    }

    /// A one-second spike never counts: the held level is what every second of the window stayed at.
    func testSpikeIsNotHeld() {
        let s = trace(Array(repeating: 150, count: 60) + [205] + Array(repeating: 150, count: 60))
        XCTAssertEqual(HeldPeak.heldPeak(s), 150)
    }

    /// A climb held for 30 s at 181 reads 181, even with a brief higher top.
    func testHeldLevelOfAClimb() {
        let s = trace(Array(repeating: 140, count: 40) + Array(repeating: 181, count: 30) + [186, 186]
                      + Array(repeating: 160, count: 20))
        XCTAssertEqual(HeldPeak.heldPeak(s), 181)
    }

    /// A gap breaks the window, so two halves of a broken trace never make one held stretch.
    func testGapBreaksTheWindow() {
        let first = trace(Array(repeating: 180, count: 20))
        let second = trace(Array(repeating: 180, count: 20), from: 1_030)
        let base = trace(Array(repeating: 120, count: 40), from: 2_000)
        XCTAssertEqual(HeldPeak.heldPeak(first + second + base), 120)
    }

    func testTooShortIsNil() {
        XCTAssertNil(HeldPeak.heldPeak(trace(Array(repeating: 170, count: 20))))
    }

    /// Two separate days must reach the level; the offer is what both agree on.
    func testSuggestionNeedsTwoDays() {
        let one = [MaxHRSuggestion.Peak(day: "2026-10-01", bpm: 192)]
        XCTAssertNil(MaxHRSuggestion.suggestion(peaks: one, current: 180, declined: nil))
        let two = one + [.init(day: "2026-10-05", bpm: 188), .init(day: "2026-10-05", bpm: 170)]
        XCTAssertEqual(MaxHRSuggestion.suggestion(peaks: two, current: 180, declined: nil), 188)
    }

    /// It only ever offers a HIGHER maximum, and never re-offers a declined level.
    func testOnlyRaisesAndRespectsDecline() {
        let peaks = [MaxHRSuggestion.Peak(day: "a", bpm: 140), .init(day: "b", bpm: 138)]
        XCTAssertNil(MaxHRSuggestion.suggestion(peaks: peaks, current: 180, declined: nil))
        let high = [MaxHRSuggestion.Peak(day: "a", bpm: 190), .init(day: "b", bpm: 189)]
        XCTAssertNil(MaxHRSuggestion.suggestion(peaks: high, current: 188, declined: nil), "inside the margin")
        XCTAssertNil(MaxHRSuggestion.suggestion(peaks: high, current: 180, declined: 189))
        XCTAssertEqual(MaxHRSuggestion.suggestion(peaks: high, current: 180, declined: 185), 189)
    }

    /// Reserve zones sit on the resting floor: resting 55, max 185 → Zone 2 starts at 55 + 0.6 × 130 = 133.
    func testReserveBounds() {
        XCTAssertEqual(ReserveZones.lowerBounds(resting: 55, maxHR: 185), [120, 133, 146, 159, 172])
        XCTAssertNil(ReserveZones.lowerBounds(resting: 90, maxHR: 120))
    }

    /// The floor waits for fourteen nights and takes their median.
    func testRestingFloor() {
        XCTAssertNil(ReserveZones.restingFloor(nightly: Array(repeating: 55, count: 13)))
        XCTAssertEqual(ReserveZones.restingFloor(nightly: Array(repeating: 55, count: 13) + [90]), 55)
    }
}
