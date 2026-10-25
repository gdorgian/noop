import XCTest
@testable import Strand

/// The "strap hasn't synced" reminder shows three hours after Noop was last seen running, and never while syncs
/// keep landing: every one moves it.
final class SyncReminderPolicyTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let synced: TimeInterval = 1_789_999_000

    func testItShowsThreeHoursAfterTheMomentThatArmedIt() {
        XCTAssertEqual(SyncReminderPolicy.fireDate(enabled: true, lastSyncedAt: synced, now: now),
                       now.addingTimeInterval(3 * 60 * 60))
    }

    func testEverySyncMovesItAhead() {
        let later = now.addingTimeInterval(10 * 60)
        let first = SyncReminderPolicy.fireDate(enabled: true, lastSyncedAt: synced, now: now) ?? .distantPast
        let second = SyncReminderPolicy.fireDate(enabled: true, lastSyncedAt: synced, now: later) ?? .distantPast
        XCTAssertEqual(second.timeIntervalSince(first), 10 * 60)
    }

    func testWithdrawnWhenOffOrWhenNoStrapEverSynced() {
        XCTAssertNil(SyncReminderPolicy.fireDate(enabled: false, lastSyncedAt: synced, now: now))
        XCTAssertNil(SyncReminderPolicy.fireDate(enabled: true, lastSyncedAt: nil, now: now))
    }

    /// The title names the last sync: a time today, "yesterday at" across midnight.
    func testTitleNamesTheLastSync() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let noon = cal.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 12))!
        let today = SyncReminderPolicy.content(lastSyncedAt: noon.addingTimeInterval(-3 * 3600).timeIntervalSince1970,
                                               now: noon, calendar: cal)
        XCTAssertFalse(today.title.contains("yesterday"))
        let lateNight = cal.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 1))!
        let yesterday = SyncReminderPolicy.content(lastSyncedAt: lateNight.addingTimeInterval(-3 * 3600).timeIntervalSince1970,
                                                   now: lateNight, calendar: cal)
        XCTAssertTrue(yesterday.title.contains("yesterday"))
    }
}
