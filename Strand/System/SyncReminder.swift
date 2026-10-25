#if os(iOS)
import Foundation
import UserNotifications

/// Keeps the one pending "strap hasn't synced" notification where `SyncReminderPolicy` puts it: moved on at every
/// completed sync and every move on or off screen, withdrawn when the switch is off. Each call replaces the same
/// request, so there is never more than one. Without notification permission iOS never shows it.
@MainActor
enum SyncReminder {

    /// Logged once per run: the first arm is what a tester's log needs, the re-arms after every sync only repeat it.
    private static var armLogged = false

    static func rearm(enabled: Bool, lastSyncedAt: TimeInterval?, log: (String) -> Void) {
        let center = UNUserNotificationCenter.current()
        let now = Date()
        guard let fire = SyncReminderPolicy.fireDate(enabled: enabled, lastSyncedAt: lastSyncedAt, now: now),
              let lastSyncedAt else {
            center.removePendingNotificationRequests(withIdentifiers: [SyncReminderPolicy.identifier])
            return
        }
        // Worded for the moment it shows, with the last sync it would report then.
        let words = SyncReminderPolicy.content(lastSyncedAt: lastSyncedAt, now: fire)
        let content = UNMutableNotificationContent()
        content.title = words.title
        content.body = words.body
        content.interruptionLevel = .passive
        content.threadIdentifier = SyncReminderPolicy.identifier
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, fire.timeIntervalSince(now)), repeats: false)
        center.add(UNNotificationRequest(identifier: SyncReminderPolicy.identifier, content: content, trigger: trigger))
        if !armLogged {
            armLogged = true
            log("Sync reminder: armed for \(fire.formatted(date: .omitted, time: .shortened)); every sync moves it 3 h on")
        }
    }

    /// Asked when the switch is turned on, the way the other alert switches ask.
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    /// Noop is on screen: a reminder already delivered describes a gap that is over.
    static func clearDelivered() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [SyncReminderPolicy.identifier])
    }
}
#endif
