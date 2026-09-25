#if os(iOS)
import XCTest
import StrandDesign
import WhoopStore
@testable import NOOP_Staging

/// The production Rest screen prints every figure through these helpers, so each rule the screen
/// relies on is pinned here: how a duration reads, when a night counts as even, how a recorded
/// timeline is sliced for the ring, and when the need is still the population default.
final class NoopRestRecordTests: XCTestCase {

    func testDurationReadsTheWayAPersonSaysIt() {
        XCTAssertEqual(NoopRestRecord.duration(432), "7h 12m")
        XCTAssertEqual(NoopRestRecord.duration(366), "6h 06m")
        XCTAssertEqual(NoopRestRecord.duration(48), "48m")
        XCTAssertEqual(NoopRestRecord.duration(-5), "0m")
    }

    func testDeltaSaysOverShortOrEven() {
        XCTAssertEqual(NoopRestRecord.delta(asleepMin: 432, needMin: 425).text, "7m over")
        XCTAssertTrue(NoopRestRecord.delta(asleepMin: 432, needMin: 425).closes)
        XCTAssertEqual(NoopRestRecord.delta(asleepMin: 330, needMin: 425).text, "1h 35m short")
        XCTAssertFalse(NoopRestRecord.delta(asleepMin: 330, needMin: 425).closes)
        XCTAssertEqual(NoopRestRecord.delta(asleepMin: 420, needMin: 425).text, "5m short \u{2014} even")
        XCTAssertTrue(NoopRestRecord.delta(asleepMin: 420, needMin: 425).closes)
    }

    func testSlicesFollowTheRecordedTimelineInOrder() {
        // Two hours deep, then two hours REM: the first half of the slices is deep, the second REM.
        let intervals = [
            SleepInterval(stage: .deep, start: 0, end: 7200),
            SleepInterval(stage: .rem, start: 7200, end: 14400)
        ]
        let slices = NoopRestRecord.slices(of: intervals)
        XCTAssertEqual(slices.count, NoopRestRecord.sliceCount)
        XCTAssertEqual(Set(slices.prefix(16)), [3])
        XCTAssertEqual(Set(slices.suffix(16)), [2])
    }

    func testNoTimelineMeansNoSlices() {
        XCTAssertEqual(NoopRestRecord.slices(of: []), [])
    }

    func testConfidenceCalibratesUntilTheEngineStopsUsingTheDefault() {
        func record(_ nights: Int) -> NoopRestRecord {
            NoopRestRecord(phase: .ready, slots: Array(repeating: nil, count: 7), latest: nil,
                           needMin: 480, needNights: nights)
        }
        XCTAssertEqual(record(3).confidence, .calibrating)
        XCTAssertEqual(record(30).confidence, .building)
        XCTAssertEqual(record(90).confidence, .solid)
    }

    func testAnEmptyRecordIsEmptyNotZero() {
        let record = NoopRestRecord.build(days: [], sessions: [], habitualMidsleepSec: nil)
        XCTAssertEqual(record.phase, .empty)
        XCTAssertNil(record.latest)
        XCTAssertNil(record.latencyMin)
        XCTAssertEqual(record.slots.count, 7)
        XCTAssertTrue(record.slots.allSatisfy { $0 == nil })
    }

    func testDetectedTimelineDoesNotInventTimeFromBedToSleep() {
        let start = Int(Date().timeIntervalSince1970) - 8 * 86_400
        let sessions: [CachedSleepSession] = (0..<3).map { index in
            let onset = start + index * 86_400
            let segments = "[{\"start\":\(onset),\"end\":\(onset + 1800),\"stage\":\"wake\"}," +
                "{\"start\":\(onset + 1800),\"end\":\(onset + 27_000),\"stage\":\"light\"}]"
            return CachedSleepSession(startTs: onset, endTs: onset + 27_000, efficiency: nil,
                                      restingHr: nil, avgHrv: nil, stagesJSON: segments)
        }
        let record = NoopRestRecord.build(days: [], sessions: sessions, habitualMidsleepSec: nil)
        XCTAssertNil(record.latencyMin, "A detected session onset is not a verified time of getting into bed")
    }
}

final class NoopAgesRecordTests: XCTestCase {
    func testBuildingLabelNamesTheRealGateInsteadOfTheState() {
        var record = NoopAgesRecord()
        XCTAssertEqual(record.buildReason, "Checking recorded signals")

        record.loaded = true
        XCTAssertEqual(record.buildReason, "Confirm your profile")

        record.chronoAge = 40
        record.factorsAvailable = 2
        XCTAssertEqual(record.buildReason, "2 of 3 model factors")
        XCTAssertFalse(record.buildReason.localizedCaseInsensitiveContains("calibrating"))
    }

    func testHistoricalInputDoesNotBorrowFutureVO2() {
        let samples = [(day: "2026-06-01", value: 40.0), (day: "2026-08-01", value: 48.0)]
        XCTAssertEqual(NoopAgesRecord.latestValue(in: samples, from: "2026-05-01", through: "2026-07-01"), 40)
        XCTAssertNil(NoopAgesRecord.latestValue(in: samples, from: "2026-07-01", through: "2026-07-31"))
        XCTAssertEqual(NoopAgesRecord.latestValue(in: samples, from: "2026-07-01", through: "2026-08-02"), 48)
    }
}

final class SveaProactiveBackgroundTaskTests: XCTestCase {
    func testLegacyEnabledBitCannotOverrideNeverOrMissingChoice() {
        XCTAssertFalse(SveaProactiveBackgroundTask.permitsBackground(enabled: true, proactive: nil, voice: "Plain"))
        XCTAssertFalse(SveaProactiveBackgroundTask.permitsBackground(enabled: true, proactive: "Never", voice: "Plain"))
    }

    func testVoiceOffPausesButDoesNotEraseAnExplicitChoice() {
        XCTAssertFalse(SveaProactiveBackgroundTask.permitsBackground(
            enabled: true, proactive: "When something changed", voice: "Off"))
        XCTAssertTrue(SveaProactiveBackgroundTask.permitsBackground(
            enabled: true, proactive: "When something changed", voice: "Plain"))
        XCTAssertTrue(SveaProactiveBackgroundTask.permitsBackground(
            enabled: true, proactive: "Freely", voice: "Quiet"))
    }

    func testBackgroundNeedsTheExplicitEnableBit() {
        XCTAssertFalse(SveaProactiveBackgroundTask.permitsBackground(
            enabled: false, proactive: "Freely", voice: "Plain"))
        XCTAssertFalse(SveaProactiveBackgroundTask.permitsBackground(
            enabled: true, proactive: "unexpected", voice: "Plain"))
    }
}
#endif
