import XCTest
@testable import StrandAnalytics
import WhoopProtocol

/// `SleepStager.bridgeShortStirs`: a short restless stretch at a sleeping pulse does not split a dense night.
final class SleepShortStirBridgeTests: XCTestCase {

    private let runs = [SleepStager.Period(stage: "sleep", start: 0, end: 10_000),
                        SleepStager.Period(stage: "active", start: 10_000, end: 10_900),
                        SleepStager.Period(stage: "sleep", start: 10_900, end: 20_000)]

    private func shape(_ p: [SleepStager.Period]) -> [String] { p.map { "\($0.stage) \($0.start)-\($0.end)" } }

    private func pulse(_ bpm: Int) -> [HRSample] { (0..<20_000).map { HRSample(ts: $0, bpm: bpm) } }

    func testFifteenMinuteStirAtASleepingPulseJoinsTheNight() {
        let out = SleepStager.bridgeShortStirs(runs, hr: pulse(60), baseline: 70, bandSleepState: [])
        XCTAssertEqual(shape(out), ["sleep 0-20000"])
    }

    func testRaisedPulseKeepsTheSplit() {
        let hr = (0..<20_000).map { HRSample(ts: $0, bpm: (10_000..<10_900).contains($0) ? 90 : 60) }
        XCTAssertEqual(shape(SleepStager.bridgeShortStirs(runs, hr: hr, baseline: 70, bandSleepState: [])), shape(runs))
    }

    func testLongStirKeepsTheSplit() {
        let long = [runs[0], SleepStager.Period(stage: "active", start: 10_000, end: 11_500),
                    SleepStager.Period(stage: "sleep", start: 11_500, end: 20_000)]
        XCTAssertEqual(shape(SleepStager.bridgeShortStirs(long, hr: pulse(60), baseline: 70, bandSleepState: [])), shape(long))
    }

    func testPulseConfirmedStrapUpKeepsTheSplit() {
        let hr = (0..<20_000).map { HRSample(ts: $0, bpm: $0 >= 10_000 && $0 < 10_900 ? 68 : 60) }
        let up = (10_000..<10_900).map { (ts: $0, state: 3) }
        XCTAssertEqual(shape(SleepStager.bridgeShortStirs(runs, hr: hr, baseline: 70, bandSleepState: up)), shape(runs))
    }
}
