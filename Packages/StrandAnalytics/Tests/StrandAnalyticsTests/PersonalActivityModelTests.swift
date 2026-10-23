import XCTest
@testable import StrandAnalytics

final class PersonalActivityModelTests: XCTestCase {
    /// Sets-and-rest work: alternating 2-minute efforts and rests.
    private func lift(start: Int, minutes: Int) -> [(ts: Int, bpm: Int)] {
        (0..<(minutes * 60)).map { s in (ts: start + s, bpm: (s / 120) % 2 == 0 ? 125 : 95) }
    }
    /// A steady effort at one level.
    private func steady(start: Int, minutes: Int, bpm: Int) -> [(ts: Int, bpm: Int)] {
        (0..<(minutes * 60)).map { s in (ts: start + s, bpm: bpm + (s % 7) - 3) }
    }
    private func example(_ sport: String, _ hr: [(ts: Int, bpm: Int)]) -> PersonalActivityModel.Example {
        let f = PersonalActivityModel.features(hr: hr, startSec: hr.first!.ts, endSec: hr.last!.ts, restingBpm: 60)!
        return .init(sport: sport, features: f)
    }

    func testSilentWithoutHistory() {
        let hr = lift(start: 0, minutes: 40)
        let f = PersonalActivityModel.features(hr: hr, startSec: 0, endSec: hr.last!.ts, restingBpm: 60)!
        XCTAssertEqual(PersonalActivityModel.suggest(f, from: []), [])
    }

    func testLearnsLiftFromSwimAndWalk() {
        let day = 86_400
        var examples: [PersonalActivityModel.Example] = []
        for i in 0..<4 {
            examples.append(example("Strength", lift(start: i * day + 57_600, minutes: 45 + i)))
            examples.append(example("Swimming", steady(start: i * day + 25_200, minutes: 25 + i, bpm: 140)))
            examples.append(example("Walking", steady(start: i * day + 68_400, minutes: 35 + i, bpm: 95)))
        }
        let hr = lift(start: 10 * day + 57_000, minutes: 50)
        let f = PersonalActivityModel.features(hr: hr, startSec: hr.first!.ts, endSec: hr.last!.ts, restingBpm: 60)!
        let ranked = PersonalActivityModel.suggest(f, from: examples)
        XCTAssertEqual(ranked.first?.sport, "Strength")
        XCTAssertTrue(PersonalActivityModel.isConfident(ranked))

        let swim = steady(start: 10 * day + 25_000, minutes: 27, bpm: 142)
        let g = PersonalActivityModel.features(hr: swim, startSec: swim.first!.ts, endSec: swim.last!.ts, restingBpm: 60)!
        XCTAssertEqual(PersonalActivityModel.suggest(g, from: examples).first?.sport, "Swimming")
    }

    func testTooLittleHeartRateHasNoFeatures() {
        XCTAssertNil(PersonalActivityModel.features(hr: [(ts: 0, bpm: 100)], startSec: 0, endSec: 600, restingBpm: 60))
    }
}
