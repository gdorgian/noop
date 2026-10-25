import Foundation

/// The "strap hasn't synced" reminder (iOS).
///
/// Swiping Noop away ends it, and iOS never relaunches a force-quit app for Bluetooth: syncing stops until the
/// next open and nothing says so. The strap keeps recording, so nothing is lost, but Today, Sleep and Health all
/// sit on old data. The same happens when the strap is left out of reach.
///
/// Noop keeps ONE pending local notification and pushes it `quietInterval` ahead at every completed sync and
/// whenever it comes on screen or leaves it. While syncs keep landing it keeps moving and never shows. Once they
/// stop, it shows `quietInterval` after the last of those moments, passively: no sound, no screen wake.
///
/// Pure so `StrandTests` covers it; `SyncReminder` schedules what this decides.
enum SyncReminderPolicy {

    /// The one request's identifier: each re-arm replaces it rather than adding another.
    static let identifier = "noop.syncReminder"

    /// How long without a sync before the reminder shows.
    static let quietInterval: TimeInterval = 3 * 60 * 60

    /// When the reminder shows unless something moves it first, or nil to withdraw it. `lastSyncedAt` is nil on a
    /// phone that has never synced a strap, where there is nothing to remind about. `now` is the sync, or the move
    /// on or off screen, that re-arms it: a moment Noop was demonstrably running.
    static func fireDate(enabled: Bool, lastSyncedAt: TimeInterval?, now: Date) -> Date? {
        guard enabled, lastSyncedAt != nil else { return nil }
        return now.addingTimeInterval(quietInterval)
    }

    /// The notification's words. It names the last sync, so a reminder read hours late still says how stale the
    /// numbers are, and it says nothing was lost, because the strap holds its own history.
    static func content(lastSyncedAt: TimeInterval, now: Date, calendar: Calendar = .current) -> (title: String, body: String) {
        let last = Date(timeIntervalSince1970: lastSyncedAt)
        let time = last.formatted(date: .omitted, time: .shortened)
        let day = calendar.isDate(last, inSameDayAs: now) ? nil
            : calendar.isDate(last, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now)
                ? String(localized: "yesterday")
                : last.formatted(.dateTime.weekday(.wide))
        // Short enough that the Lock Screen never cuts it: "Last synced yesterday, 21:31".
        let title = day.map { String(localized: "Last synced \($0), \(time)") } ?? String(localized: "Last synced \(time)")
        return (title, String(localized: "Your strap is still recording. Open Noop and it catches up."))
    }
}
