#if os(iOS)
import Foundation
import UIKit
import UserNotifications
import StrandAnalytics
import WhoopStore

/// Noop Aura's own notifications, scheduled from what the data says (`NoticeRules`):
///
///  • Your night is in: once the night is scored, its sleep and Charge, if Noop is not already open.
///  • Bedtime: a quiet nudge before the bedtime that gets the wearer their own need before their usual wake,
///    planned a week ahead, per weekday.
///  • A new best: a vital that beat every night of the last three months.
///  • Your week: Sunday at seven, the week against the one before. Off by default.
///  • Backup: the record lives only on this phone; a reminder thirty days after the last backup.
///
/// Every refresh replaces what it scheduled before, so a pending notification always reflects the latest
/// data. Without notification permission nothing shows, and nothing here asks for it: the switches do.
@MainActor
enum AuraNotices {

    enum Kind: String, CaseIterable {
        case morning = "notices.morning"
        case bedtime = "notices.bedtime"
        case best = "notices.best"
        case weekly = "notices.weekly"
        case backup = "notices.backup"

        /// The week is off by default: most weeks do not need a summary.
        var defaultOn: Bool { self != .weekly }
    }

    static func isOn(_ kind: Kind) -> Bool {
        UserDefaults.standard.object(forKey: kind.rawValue) as? Bool ?? kind.defaultOn
    }

    static func set(_ kind: Kind, _ on: Bool) {
        UserDefaults.standard.set(on, forKey: kind.rawValue)
        if on { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in } }
    }

    private static let bedtimePrefix = "noop.bedtime."
    private static let weeklyId = "noop.weekly"
    private static let backupId = "noop.backup"
    private static let morningDayKey = "notices.morning.lastDay"
    private static let bestDayKey = "notices.best.lastDay"

    /// Re-plan everything from the repository's current days and nights.
    static func refresh(repo: Repository, now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }
        let days = repo.days.sorted { $0.day < $1.day }
        let active = UIApplication.shared.applicationState == .active
        morning(days: days, now: now, appActive: active, center: center)
        bedtime(days: days, sleeps: repo.sleeps, now: now, center: center)
        best(days: days, now: now, appActive: active, center: center)
        weekly(days: days, now: now, center: center)
        backup(days: days, now: now, center: center)
        #if DEBUG
        for r in await center.pendingNotificationRequests() where r.identifier.hasPrefix("noop.") {
            let at = (r.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()
            NSLog("AuraNotices: \(r.identifier) at \(at.map { $0.formatted() } ?? "now") — \(r.content.title) / \(r.content.body)")
        }
        #endif
    }

    // MARK: - Your night is in

    private static func morning(days: [DailyMetric], now: Date, appActive: Bool, center: UNUserNotificationCenter) {
        let today = Repository.localDayKey(now)
        let d = UserDefaults.standard
        guard isOn(.morning), d.string(forKey: morningDayKey) != today,
              let night = days.last, night.day == today,
              let asleep = night.totalSleepMin, asleep >= 180, let charge = night.recovery else { return }
        let hour = Calendar.current.component(.hour, from: now)
        guard (4..<13).contains(hour) else { return }
        d.set(today, forKey: morningDayKey)
        // Open already: the night is on screen, a banner would only repeat it.
        guard !appActive else { return }
        var stages: [String] = []
        if let deep = night.deepMin, deep > 0 { stages.append("Deep \(duration(deep))") }
        if let rem = night.remMin, rem > 0 { stages.append("REM \(duration(rem))") }
        post(id: "noop.morning",
             title: "\(duration(asleep)) asleep · Charge \(Int(charge.rounded()))",
             body: (stages.isEmpty ? "" : stages.joined(separator: ", ") + ". ") + "Your day is ready to read.",
             level: .active, center: center)
    }

    // MARK: - Bedtime

    private static func bedtime(days: [DailyMetric], sleeps: [CachedSleepSession], now: Date,
                                center: UNUserNotificationCenter) {
        let ids = (0..<7).map { "\(bedtimePrefix)\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard isOn(.bedtime) else { return }
        let cal = Calendar.current
        let since = now.timeIntervalSince1970 - 42 * 86_400
        // Main sleeps only: a nap's end is not a wake time.
        let wakes = sleeps.filter { Double($0.endTs) > since && $0.endTs - $0.effectiveStartTs >= 3 * 3600 }
            .map { s -> NoticeRules.Wake in
                let end = Date(timeIntervalSince1970: TimeInterval(s.endTs))
                let c = cal.dateComponents([.weekday, .hour, .minute], from: end)
                return NoticeRules.Wake(weekday: c.weekday ?? 1, minute: (c.hour ?? 0) * 60 + (c.minute ?? 0))
            }
        let usual = NoticeRules.usualWake(wakes)
        guard !usual.isEmpty else { return }
        let need = NoticeRules.sleepNeed(days.suffix(42).map {
            NoticeRules.Night(asleepMinutes: $0.totalSleepMin ?? 0, charge: $0.recovery)
        })
        let midnight = cal.startOfDay(for: now)
        for offset in 0..<7 {
            guard let evening = cal.date(byAdding: .day, value: offset, to: midnight),
                  let morning = cal.date(byAdding: .day, value: 1, to: evening),
                  let wake = usual[cal.component(.weekday, from: morning)] else { continue }
            let plan = NoticeRules.bedtime(wakeMinute: wake, need: need)
            let fire = evening.addingTimeInterval(TimeInterval(plan.nudge * 60))
            guard fire > now.addingTimeInterval(60) else { continue }
            let bed = evening.addingTimeInterval(TimeInterval(plan.bedtime * 60))
            let wakeAt = morning.addingTimeInterval(TimeInterval(wake * 60))
            post(id: ids[offset],
                 title: "Wind down for \(clock(bed))",
                 body: "In bed by \(clock(bed)) gives you \(duration(Double(need))) asleep before your usual \(clock(wakeAt)).",
                 at: fire, level: .active, sound: false, center: center)
        }
    }

    // MARK: - A new best

    private static func best(days: [DailyMetric], now: Date, appActive: Bool, center: UNUserNotificationCenter) {
        let d = UserDefaults.standard
        guard isOn(.best), let last = days.last else { return }
        let today = Repository.localDayKey(now)
        let yesterday = Repository.localDayKey(now.addingTimeInterval(-86_400))
        guard last.day == today || last.day == yesterday, d.string(forKey: bestDayKey) != last.day else { return }
        let prior = days.dropLast().suffix(90)
        typealias Check = (value: Double?, prior: [Double], higher: Bool, margin: Double,
                           title: String, unit: String)
        let checks: [Check] = [
            (last.avgHrv, prior.compactMap(\.avgHrv), true, 2, "Highest HRV in three months", "ms"),
            (last.restingHr.map(Double.init), prior.compactMap { $0.restingHr.map(Double.init) }, false, 1,
             "Lowest resting pulse in three months", "bpm"),
            (last.recovery, prior.compactMap(\.recovery), true, 2, "Highest Charge in three months", "")
        ]
        for c in checks {
            guard let value = c.value,
                  let previous = NoticeRules.previousBest(value, prior: c.prior, higherIsBetter: c.higher,
                                                          margin: c.margin) else { continue }
            d.set(last.day, forKey: bestDayKey)
            guard !appActive else { return }
            let unit = c.unit.isEmpty ? "" : " \(c.unit)"
            post(id: "noop.best", title: c.title,
                 body: "\(Int(value.rounded()))\(unit) last night, past your best of \(Int(previous.rounded()))\(unit) before it.",
                 level: .active, center: center)
            return
        }
    }

    // MARK: - Your week

    private static func weekly(days: [DailyMetric], now: Date, center: UNUserNotificationCenter) {
        center.removePendingNotificationRequests(withIdentifiers: [weeklyId])
        guard isOn(.weekly), days.count >= 14 else { return }
        let cal = Calendar.current
        var next = cal.nextDate(after: now, matching: DateComponents(hour: 19, minute: 0, weekday: 1),
                                matchingPolicy: .nextTime) ?? now
        if next <= now { next = next.addingTimeInterval(7 * 86_400) }
        let thisWeek = days.suffix(7), lastWeek = days.dropLast(7).suffix(7)
        let a = NoticeRules.week(asleep: thisWeek.map(\.totalSleepMin), charge: thisWeek.map(\.recovery),
                                 sessions: thisWeek.compactMap(\.exerciseCount).reduce(0, +))
        let b = NoticeRules.week(asleep: lastWeek.map(\.totalSleepMin), charge: lastWeek.map(\.recovery),
                                 sessions: lastWeek.compactMap(\.exerciseCount).reduce(0, +))
        var parts: [String] = []
        if let s = a.asleepMinutes {
            let delta = b.asleepMinutes.map { Int((s - $0).rounded()) }
            parts.append("\(duration(s)) asleep a night" + (delta.map { $0 == 0 ? "" : " (\($0 > 0 ? "+" : "−")\(abs($0)) min)" } ?? ""))
        }
        if let c = a.charge {
            let delta = b.charge.map { Int((c - $0).rounded()) }
            parts.append("Charge \(Int(c.rounded()))" + (delta.map { $0 == 0 ? "" : " (\($0 > 0 ? "+" : "−")\(abs($0)))" } ?? ""))
        }
        parts.append(a.sessions == 1 ? "1 session" : "\(a.sessions) sessions")
        post(id: weeklyId, title: "Your week", body: parts.joined(separator: ", ") + ".",
             at: next, level: .passive, sound: false, center: center)
    }

    // MARK: - Backup

    private static func backup(days: [DailyMetric], now: Date, center: UNUserNotificationCenter) {
        center.removePendingNotificationRequests(withIdentifiers: [backupId])
        guard isOn(.backup), days.count >= 14 else { return }
        let folder = TimeInterval(FolderBackup.lastBackupMs) / 1000
        let export = UserDefaults.standard.double(forKey: DataBackup.lastExportKey)
        let last = max(folder, export)
        let cal = Calendar.current
        let due = last > 0 ? Date(timeIntervalSince1970: last).addingTimeInterval(30 * 86_400)
            : now.addingTimeInterval(2 * 86_400)
        // At six in the evening, never sooner than tomorrow's: a reminder is not an interruption.
        let base = max(due, now.addingTimeInterval(3600))
        guard let fire = cal.date(bySettingHour: 18, minute: 0, second: 0, of: base) else { return }
        let when = fire < now ? fire.addingTimeInterval(86_400) : fire
        let body = last > 0
            ? "Your last backup is a month old. A fresh one takes a minute: You › Data › Back up."
            : "It has never been backed up. One takes a minute: You › Data › Back up."
        post(id: backupId, title: "Your record lives only on this phone", body: body,
             at: when, level: .passive, sound: false, center: center)
    }

    // MARK: - Helpers

    private static func post(id: String, title: String, body: String, at date: Date? = nil,
                             level: UNNotificationInterruptionLevel, sound: Bool = true,
                             center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.interruptionLevel = level
        if sound { content.sound = .default }
        let trigger = date.map {
            UNTimeIntervalNotificationTrigger(timeInterval: max(1, $0.timeIntervalSinceNow), repeats: false)
        }
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// "7 h 12" from minutes.
    static func duration(_ minutes: Double) -> String {
        let m = Int(minutes.rounded())
        if m < 60 { return "\(m) min" }
        return m % 60 == 0 ? "\(m / 60) h" : "\(m / 60) h \(String(format: "%02d", m % 60))"
    }

    private static func clock(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }
}
#endif
