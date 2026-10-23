import Foundation
import UserNotifications
import WhoopStore

// MARK: - Detected activity notifications (23 Oct 2026)
//
// Two local notifications around an activity the wearer never started in the app: one while it is under
// way ("looks like you're working out"), and one once it has been logged as a detected activity, asking
// them to confirm what it was so the personal model learns. Both are posted from the analysis pass that
// finds the bout, so they arrive whether or not the app is open. Nothing leaves the device.
enum ActivityNotifier {
    /// On unless the wearer turns it off; follows the auto-log toggle's default.
    static let enabledKey = "fitness.activityNotifications"
    static var enabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }

    private static let inProgressKey = "fitness.activityNotified.inProgress"
    private static let loggedKey = "fitness.activityNotified.logged"
    /// A bout's detected start can move by a few minutes between passes; within this it is the same bout.
    private static let sameBoutS = 20 * 60

    static func inProgress(startSec: Int) {
        guard enabled, claim(startSec, key: inProgressKey) else { return }
        post(id: "activity-live-\(startSec)",
             title: String(localized: "Looks like you're working out"),
             body: String(localized: "Your heart rate has been up since \(clock(startSec)). Noop will log it when you finish."))
    }

    static func logged(_ row: WorkoutRow) {
        guard enabled, claim(row.startTs, key: loggedKey) else { return }
        let minutes = max(1, (row.endTs - row.startTs) / 60)
        let named = row.sport.lowercased() != "detected"
        let title = named
            ? String(localized: "\(minutes) min of \(row.sport) logged")
            : String(localized: "\(minutes) min activity logged")
        post(id: "activity-logged-\(row.startTs)", title: title,
             body: String(localized: "\(clock(row.startTs))–\(clock(row.endTs)). Open Noop to confirm what it was, so detection keeps getting better."))
    }

    /// True the first time a bout near `start` is seen for this notification; remembers the last few.
    private static func claim(_ start: Int, key: String) -> Bool {
        let d = UserDefaults.standard
        var seen = (d.array(forKey: key) as? [Int]) ?? []
        guard !seen.contains(where: { abs($0 - start) < sameBoutS }) else { return false }
        seen.append(start)
        d.set(Array(seen.suffix(30)), forKey: key)
        return true
    }

    private static func clock(_ ts: Int) -> String {
        AppClock.hourMinuteFormatter().string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }

    private static func post(id: String, title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            let send = {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                content.userInfo = ["route": "fitness"]
                center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
            }
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral: send()
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in if granted { send() } }
            default: break
            }
        }
    }
}
