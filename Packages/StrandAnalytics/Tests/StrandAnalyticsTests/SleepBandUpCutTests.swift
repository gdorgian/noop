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

    /// Strap motion per second: `share` of each ten seconds above the moving line.
    private func motion(_ from: Int, _ to: Int, share: Double) -> [GravitySample] {
        (from..<to).map { GravitySample(ts: $0, x: 0, y: 0, z: 1, dynAccel: Double($0 % 10) < share * 10 ? 0.1 : 0.01) }
    }

    func testUpOnALaptopInBedCutsByMovement() {
        // Awake in bed: the pulse rises only 3 bpm, but the wrist moves a fifth of the time.
        let state = band([(0, 22_000, 2), (22_000, 26_000, 3)])
        let hr = pulse([(0, 22_000, 72), (22_000, 26_000, 75)])
        let moving = motion(0, 22_000, share: 0) + motion(22_000, 26_000, share: 0.2)
        XCTAssertEqual(SleepStager.bandUpCut(start: 0, end: 26_000, bandSleepState: state, hr: hr, grav: moving), 22_000)
        // Lying still through the same "up": still in bed.
        let still = motion(0, 26_000, share: 0.05)
        XCTAssertNil(SleepStager.bandUpCut(start: 0, end: 26_000, bandSleepState: state, hr: hr, grav: still))
    }

    func testAsleepAfterUpAtAWakingPulseKeepsTheCut() {
        // Up at 75, then the strap calls "asleep" at 78 while the wearer lies still with a film.
        let state = band([(0, 22_000, 2), (22_000, 26_000, 3), (26_000, 28_000, 2), (28_000, 29_000, 3)])
        let hr = pulse([(0, 22_000, 70), (22_000, 26_000, 78), (26_000, 29_000, 79)])
        XCTAssertEqual(SleepStager.bandUpCut(start: 0, end: 29_000, bandSleepState: state, hr: hr), 22_000)
        // Back to sleep for real: the pulse falls and the night goes on.
        let fell = pulse([(0, 22_000, 70), (22_000, 26_000, 78), (26_000, 29_000, 68)])
        XCTAssertNil(SleepStager.bandUpCut(start: 0, end: 29_000,
                                           bandSleepState: band([(0, 22_000, 2), (22_000, 26_000, 3), (26_000, 29_000, 2)]),
                                           hr: fell))
    }

    func testBriefAsleepBlipAfterUpStillCuts() {
        let state = band([(0, 10_000, 2), (10_000, 11_000, 3), (11_000, 11_030, 2), (11_030, 12_000, 3)])
        XCTAssertEqual(SleepStager.bandUpCut(start: 0, end: 12_000, bandSleepState: state), 10_000)
    }
}
