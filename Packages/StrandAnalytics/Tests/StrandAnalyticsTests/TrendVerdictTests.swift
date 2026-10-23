import XCTest
@testable import StrandAnalytics

final class TrendVerdictTests: XCTestCase {
    private let week = 7.0 * 86_400
    private let t0 = Date(timeIntervalSince1970: 1_780_000_000)

    private func series(weeks: Int, slopePerYear: Double, start: Double = 34, wobble: [Double] = [0]) -> [(date: Date, age: Double)] {
        (0..<weeks).map { i in
            let years = Double(i) * 7 / 365.2425
            return (t0.addingTimeInterval(Double(i) * week), start + slopePerYear * years + wobble[i % wobble.count])
        }
    }

    // MARK: Pace

    func testPaceRecoversInjectedSlopes() {
        for injected in [0.4, 1.0, 1.8] {
            let r = AgingPace.estimate(series(weeks: 30, slopePerYear: injected, wobble: [0.05, -0.05, 0.02]))
            XCTAssertNotNil(r)
            XCTAssertEqual(r!.pace, injected, accuracy: 0.15)
            XCTAssertTrue(r!.isDefensible)
        }
    }

    func testPaceDirectionNeedsTheWholeInterval() {
        XCTAssertEqual(AgingPace.estimate(series(weeks: 40, slopePerYear: 0.3, wobble: [0.02, -0.02]))?.direction, .slower)
        XCTAssertEqual(AgingPace.estimate(series(weeks: 40, slopePerYear: 1.0, wobble: [0.02, -0.02]))?.direction, .inStep)
        XCTAssertEqual(AgingPace.estimate(series(weeks: 40, slopePerYear: 2.0, wobble: [0.02, -0.02]))?.direction, .faster)
    }

    func testTenNoisyWeeksAreNotDefensible() {
        // A weekly body age that wobbles by ±0.3 years cannot pin a slope in ten weeks.
        let r = AgingPace.estimate(series(weeks: 10, slopePerYear: 1, wobble: [0.3, -0.3, 0.25, -0.2]))
        XCTAssertNotNil(r)
        XCTAssertFalse(r!.isDefensible)
    }

    func testPaceNeedsEightPoints() {
        XCTAssertNil(AgingPace.estimate(series(weeks: 7, slopePerYear: 1)))
    }

    // MARK: Verdict

    private func signal(_ key: String, _ early: Double, _ late: Double, weeks: Int = 26, noise: Double = 0.5,
                        higherIsBetter: Bool = true, minimum: Double = 1) -> TrendVerdict.Signal {
        let w = [noise, -noise, noise / 2, -noise / 2]
        let values: [Double?] = (0..<weeks).map { i in (i < weeks / 2 ? early : late) + w[i % 4] }
        return .init(key: key, weekly: values, higherIsBetter: higherIsBetter, minimumChange: minimum)
    }

    func testShortWindowIsTooEarly() {
        let r = TrendVerdict.evaluate([signal("rhr", 60, 55, weeks: 6, higherIsBetter: false),
                                       signal("hrv", 40, 50, weeks: 6)], windowWeeks: 6)
        XCTAssertEqual(r.headline, .tooEarly)
    }

    func testTwoClearImprovementsAreWorking() {
        let r = TrendVerdict.evaluate([signal("rhr", 60, 56, higherIsBetter: false),
                                       signal("hrv", 40, 50),
                                       signal("sleep", 7, 7, minimum: 0.15)], windowWeeks: 26)
        XCTAssertEqual(r.headline, .working)
        XCTAssertEqual(r.readings.map(\.call), [.improved, .improved, .steady])
    }

    func testOneImprovementIsSlowly() {
        let r = TrendVerdict.evaluate([signal("rhr", 60, 56, higherIsBetter: false), signal("hrv", 45, 45)],
                                      windowWeeks: 26)
        XCTAssertEqual(r.headline, .slowly)
    }

    func testChangeInsideNoiseIsSteady() {
        // A 1-unit shift on a signal that swings ±4 week to week is not a change.
        let r = TrendVerdict.evaluate([signal("hrv", 45, 46, noise: 4), signal("rhr", 58, 58, higherIsBetter: false)],
                                      windowWeeks: 26)
        XCTAssertEqual(r.headline, .steady)
    }

    func testMixedAndSlipping() {
        XCTAssertEqual(TrendVerdict.evaluate([signal("rhr", 56, 60, higherIsBetter: false), signal("hrv", 40, 50)],
                                             windowWeeks: 26).headline, .mixed)
        XCTAssertEqual(TrendVerdict.evaluate([signal("rhr", 56, 60, higherIsBetter: false), signal("hrv", 50, 40)],
                                             windowWeeks: 26).headline, .slipping)
    }

    func testSparseSignalIsUnknown() {
        let sparse = TrendVerdict.Signal(key: "cap", weekly: [40, nil, nil, nil, nil, 42], higherIsBetter: true, minimumChange: 0.5)
        XCTAssertEqual(TrendVerdict.read(sparse).call, .unknown)
    }
}
