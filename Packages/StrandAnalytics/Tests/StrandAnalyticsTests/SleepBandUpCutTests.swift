import XCTest
@testable import StrandAnalytics
import WhoopProtocol

/// The strap's own "up" state closes the night (`SleepStager.bandUpCut`). Shapes follow a real WHOOP 5.0
/// morning: a 15-minute "up" while the wearer lay still in bed (pulse flat), back asleep, then the real
/// get-up (pulse +9 bpm) after which the wrist stayed still at a desk and the gravity run kept going.
final class SleepBandUpCutTests: XCTestCase {

    private func band(_ runs: [(from: Int, to: Int, state: Int)]) -> [(ts: Int, state: Int)] {
        runs.flatMap { r in (r.from..<r.to).map { (ts: $0, state: r.state) } }
    }

    private func pulse(_ runs: [(from: Int, to: Int, bpm: Int)]) -> [HRSample] {
        runs.flatMap { r in (r.from..<r.to).map { HRSample(ts: $0, bpm: r.bpm) } }
    }

    func testRealMorningCutsAtTheGetUpNotTheFalseUp() {
        let state = band([(0, 22_000, 2), (22_000, 22_900, 3), (22_900, 25_000, 2), (25_000, 26_000, 3)])
        let hr = pulse([(0, 25_000, 69), (25_000, 26_000, 77)])
        XCTAssertEqual(SleepStager.bandUpCut(start: 0, end: 26_000, bandSleepState: state, hr: hr), 25_000)
    }

    func testUpWithAFlatPulseIsStillInBed() {
        let state = band([(0, 22_000, 2), (22_000, 24_000, 3)])
        let hr = pulse([(0, 24_000, 69)])
        XCTAssertNil(SleepStager.bandUpCut(start: 0, end: 24_000, bandSleepState: state, hr: hr))
    }

    func testFinalUpClosesTheNightAfterABathroomTrip() {
        let start = 0, end = 30_000
        let state = band([(0, 22_000, 2), (22_000, 22_900, 3), (22_900, 25_000, 2), (25_000, 30_000, 3)])
        XCTAssertEqual(SleepStager.bandUpCut(start: start, end: end, bandSleepState: state), 25_000)
    }

    func testUpFollowedBySleepDoesNotCut() {
        let state = band([(0, 10_000, 2), (10_000, 10_900, 3), (10_900, 20_000, 2)])
        XCTAssertNil(SleepStager.bandUpCut(start: 0, end: 20_000, bandSleepState: state))
    }

    func testShortUpStirDoesNotCut() {
        let state = band([(0, 10_000, 2), (10_000, 10_060, 3), (10_060, 10_100, 1)])
        XCTAssertNil(SleepStager.bandUpCut(start: 0, end: 10_100, bandSleepState: state))
    }

    func testNoBandStateKeepsTheGravityEnd() {
        XCTAssertNil(SleepStager.bandUpCut(start: 0, end: 10_000, bandSleepState: []))
    }

    func testBriefAsleepBlipAfterUpStillCuts() {
        let state = band([(0, 10_000, 2), (10_000, 11_000, 3), (11_000, 11_030, 2), (11_030, 12_000, 3)])
        XCTAssertEqual(SleepStager.bandUpCut(start: 0, end: 12_000, bandSleepState: state), 10_000)
    }
}
