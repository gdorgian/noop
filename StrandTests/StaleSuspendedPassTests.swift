import XCTest
@testable import Strand

/// Pins when a re-score pass discards its results instead of writing them.
///
/// A tester's pass read its inputs at 01:43, was suspended with the phone, and woke at 09:05 to write
/// 56 min of sleep for a 495-min night; the forced pass queued behind it corrected it 40 s later. A pass
/// that old, with newer data waiting, now steps aside.
final class StaleSuspendedPassTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testOvernightPassWithQueuedRescoreIsDiscarded() {
        XCTAssertTrue(IntelligenceEngine.staleSuspendedPass(
            startedAt: start, now: start.addingTimeInterval(7 * 3600), forcedPending: true))
    }

    func testOldPassWithNothingQueuedStillWrites() {
        XCTAssertFalse(IntelligenceEngine.staleSuspendedPass(
            startedAt: start, now: start.addingTimeInterval(7 * 3600), forcedPending: false))
    }

    func testOrdinaryPassWithQueuedRescoreStillWrites() {
        XCTAssertFalse(IntelligenceEngine.staleSuspendedPass(
            startedAt: start, now: start.addingTimeInterval(90), forcedPending: true))
    }

    func testBoundaryIsTenMinutes() {
        let limit = IntelligenceEngine.staleSuspendedPassSeconds
        XCTAssertFalse(IntelligenceEngine.staleSuspendedPass(
            startedAt: start, now: start.addingTimeInterval(limit), forcedPending: true))
        XCTAssertTrue(IntelligenceEngine.staleSuspendedPass(
            startedAt: start, now: start.addingTimeInterval(limit + 1), forcedPending: true))
    }
}
