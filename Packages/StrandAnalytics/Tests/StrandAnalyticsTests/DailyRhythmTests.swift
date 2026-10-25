import XCTest
@testable import StrandAnalytics

final class DailyRhythmTests: XCTestCase {

    /// A day whose motion is a cosine peaking at `peak` minutes, mean 40, amplitude `amp`.
    private func day(_ i: Int, peak: Int = 15 * 60, amp: Double = 30, missing: ClosedRange<Int>? = nil,
                     noise: Double = 0) -> DailyRhythm.Day {
        var rng = SystemRandomNumberGenerator()
        let minutes: [Double?] = (0..<1440).map { m in
            if let missing, missing.contains(m) { return nil }
            let w = 2 * Double.pi * Double(m - peak) / 1440
            return 40 + amp * cos(w) + (noise > 0 ? Double.random(in: -noise...noise, using: &rng) : 0)
        }
        return DailyRhythm.Day(key: "d\(i)", minutes: minutes)
    }

    /// The fit recovers several different peak times and strengths, not one convenient value.
    func testRecoversPeakAndStrengthAcrossInputs() {
        for (peak, amp) in [(14 * 60, 30.0), (9 * 60 + 30, 20.0), (20 * 60, 12.0)] {
            guard case .reading(let r) = DailyRhythm.read((0..<7).map { day($0, peak: peak, amp: amp) }) else {
                return XCTFail("expected a reading for peak \(peak)")
            }
            XCTAssertEqual(Double(r.peakMinute), Double(peak), accuracy: 2)
            XCTAssertEqual(r.relativeAmplitude, amp / 40, accuracy: 0.01)
            XCTAssertEqual(r.profile.max(), 1)
        }
    }

    /// Identical smooth days are perfectly stable and barely fragmented; noisy ones are neither.
    func testStabilityAndFragmentation() {
        guard case .reading(let smooth) = DailyRhythm.read((0..<7).map { day($0) }),
              case .reading(let noisy) = DailyRhythm.read((0..<7).map { day($0, amp: 12, noise: 60) }) else {
            return XCTFail()
        }
        XCTAssertEqual(smooth.stability, 1, accuracy: 0.001)
        XCTAssertLessThan(smooth.fragmentation, 0.1)
        XCTAssertLessThan(noisy.stability, smooth.stability)
        XCTAssertGreaterThan(noisy.fragmentation, smooth.fragmentation)
    }

    /// Too few counting days gathers; the same three night hours missing every day is a blind spot.
    func testGates() {
        XCTAssertEqual(DailyRhythm.read((0..<4).map { day($0) }), .gathering(days: 4))
        let gappy = (0..<7).map { day($0, missing: (2 * 60)...(5 * 60 - 1)) }
        XCTAssertEqual(DailyRhythm.read(gappy), .blindSpot(hours: 3))
        XCTAssertEqual(DailyRhythm.read((0..<7).map { day($0, amp: 2) }), .flat)
    }

    func testFoldingMinutesIntoDays() {
        let days = DailyRhythm.days(minuteMeans: [(1440 * 3 + 10, 5), (1440 * 3 + 11, 6), (1440 * 4, 7)]) { "k\($0)" }
        XCTAssertEqual(days.map(\.key), ["k3", "k4"])
        XCTAssertEqual(days[0].minutes[10], 5)
        XCTAssertEqual(days[1].observed, 1)
    }
}
