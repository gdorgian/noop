import Foundation
import UserNotifications

/// "Your strap is off your wrist" — one reminder when the strap has been off for ten minutes.
///
/// The strap reports WRIST_OFF and WRIST_ON itself (a 5.0 about two seconds after it leaves the wrist),
/// so the wait is not a guess. It is scheduled with the OS the moment the strap comes off, which is what
/// makes it reliable: iOS delivers it even if Noop has been suspended since, and WRIST_ON simply
/// withdraws it. A strap taken off to charge is not nagged about: a confirmed charging reading cancels it.
/// The ten minutes absorb a strap pushed up the arm or briefly loosened, which also reports WRIST_OFF.
enum WearNotifier {
    static let identifier = "noop.strap.offWrist"
    static let delaySeconds: TimeInterval = 10 * 60

    static func wristChanged(worn: Bool, charging: Bool?, enabled: Bool) {
        let center = UNUserNotificationCenter.current()
        guard !worn, enabled, charging != true else {
            withdraw()
            return
        }
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = "Your strap is off your wrist"
            content.body = "Put it back on to keep your heart rate, sleep and Charge recording."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delaySeconds, repeats: false)
            center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        }
    }

    /// Back on, or on the charger: drop the pending reminder and any delivered one still on screen.
    static func withdraw() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}
