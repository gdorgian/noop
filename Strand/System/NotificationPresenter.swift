import Foundation
import UserNotifications

/// Foreground presentation delegate for the app's local notifications (wind-down nudge, smart-alarm
/// backup, battery/illness alerts).
///
/// Without a `UNUserNotificationCenterDelegate`, iOS/macOS suppress a notification's banner while the
/// app is in the FOREGROUND (the default). A user testing a reminder with the app open would see
/// nothing and conclude notifications are broken. Returning banner + sound + list here makes them
/// visible whether the app is open or not — matching what the user expects from a reminder.
///
/// Cross-platform (iOS + macOS). Register once at launch:
/// `UNUserNotificationCenter.current().delegate = NotificationPresenter.shared`.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationPresenter()

    private override init() { super.init() }

    /// K5: wired by the app root (`StrandApp` on macOS, `StrandiOSApp` on iOS) at launch to route a
    /// tapped scheduled morning-brief notification to the Coach screen via `NavRouter.openCoach()`. nil
    /// is a safe no-op (the tap is simply not routed) rather than a crash if this ever fires before the
    /// root has wired it.
    var onCoachBriefTapped: (() -> Void)?

    /// Posted with the session's start (unix seconds) when a detected-activity notification is tapped.
    static let activityTapped = Notification.Name("noop.activityNotificationTapped")

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // The rest alert is for a phone in a pocket. With NOOP open the lift screen already shows the
        // rest is done, so it only sounds.
        if notification.request.content.categoryIdentifier == "noop.lift.rest" {
            completionHandler([.sound])
            return
        }
        completionHandler([.banner, .sound, .list])
    }

    /// Handle a tap on a delivered notification. Only the scheduled morning-brief category (K5) routes
    /// anywhere; every other notification (wind-down, smart-alarm, battery/illness) just opens the app
    /// to wherever it was, matching the pre-K5 behaviour.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.content.categoryIdentifier == CoachBriefScheduler.notificationCategoryId {
            onCoachBriefTapped?()
        }
        // A detected-activity notice opens that session's sheet.
        if let start = response.notification.request.content.userInfo["activityStart"] as? Int {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.activityTapped, object: start)
            }
        }
        completionHandler()
    }
}
