#if os(iOS)
import Foundation
import WhoopStore

/// The You hub's measured record for the production shell: the wearer's usual sleep window (for the
/// 24-hour dial and the bedtime card), the need, and the counts the hub rows print.
struct NoopYouRecord: Equatable {
    /// Local hour-of-day (0..<24) of the usual onset and wake, a circular mean over recent nights.
    var usualOnsetHour: Double?
    var usualWakeHour: Double?
    /// Nights behind the usual window.
    var windowNights = 0
    var needMin: Double = 0
    var needNights = 0
    var loaded = false

    /// Recent nights the usual window is averaged over.
    static let windowSpan = 30

    static func build(days: [DailyMetric], sessions: [CachedSleepSession],
                      calendar: Calendar = .current) -> NoopYouRecord {
        var record = NoopYouRecord()
        let recent = sessions.sorted { $0.endTs > $1.endTs }.prefix(windowSpan)
        func hour(_ ts: Int) -> Double {
            let d = Date(timeIntervalSince1970: TimeInterval(ts))
            let c = calendar.dateComponents([.hour, .minute], from: d)
            return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
        }
        func circularMean(_ hours: [Double]) -> Double? {
            guard !hours.isEmpty else { return nil }
            let angles = hours.map { $0 / 24 * 2 * .pi }
            let x = angles.map(cos).reduce(0, +), y = angles.map(sin).reduce(0, +)
            guard abs(x) + abs(y) > 1e-9 else { return nil }
            var mean = atan2(y, x) / (2 * .pi) * 24
            if mean < 0 { mean += 24 }
            return mean
        }
        record.usualOnsetHour = circularMean(recent.map { hour($0.effectiveStartTs) })
        record.usualWakeHour = circularMean(recent.map { hour($0.endTs) })
        record.windowNights = recent.count
        record.needMin = SleepModel.debtNeedMin(days: days)
        record.needNights = days.filter { ($0.totalSleepMin ?? 0) > 0 }.count
        record.loaded = true
        return record
    }

    /// "23:20" in the wearer's clock setting.
    static func clock(_ hour: Double) -> String {
        let minutes = Int((hour * 60).rounded()) % (24 * 60)
        var c = DateComponents(); c.hour = minutes / 60; c.minute = minutes % 60
        let date = Calendar.current.date(from: c) ?? Date()
        return AppClock.hourMinuteFormatter().string(from: date)
    }

    /// One or two initials from a display name (first and last word), per spec 44 §5.1.
    static func initials(_ name: String?) -> String? {
        guard let words = name?.split(whereSeparator: \.isWhitespace), let first = words.first?.first else {
            return nil
        }
        guard words.count > 1, let last = words.last?.first else { return String(first).uppercased() }
        return (String(first) + String(last)).uppercased()
    }
}

@MainActor
final class NoopYouStore: ObservableObject {
    @Published private(set) var record = NoopYouRecord()

    func load(from repo: Repository) async {
        guard repo.loaded else { return }
        let sessions = await repo.allSleepSessions()
        record = NoopYouRecord.build(days: repo.days, sessions: sessions.isEmpty ? repo.sleeps : sessions)
    }
}
#endif

#if os(iOS)
import SwiftUI

/// The designed "Later" chip (`soonRow`'s), for a control that has no feature behind it yet.
struct NoopLaterChip: View {
    var body: some View {
        Text("Later")
            .font(NoopHTMLFont.sans(9.5, weight: .semibold))
            .tracking(0.95)
            .textCase(.uppercase)
            .foregroundStyle(Color(hex: 0x7F8A85))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.09), lineWidth: 0.5))
    }
}
#endif

#if os(iOS)
/// "Everything you logged", measured: recorded sleeps, sessions and journal answers, grouped by day,
/// newest first, over the last sixty days. Rows carry only what the store recorded.
struct NoopHistoryRecord {
    enum Kind { case session, sleep, log }
    struct Entry {
        let kind: Kind
        let date: Date
        let name: String
        let detail: String
        let value: String
        let sport: String?
    }
    struct Day { let label: String; let entries: [Entry] }

    var days: [Day] = []
    var monthName = ""
    var monthSessions = 0
    var monthMovingMin = 0
    var monthLoad = 0
    var loaded = false

    static let span = 60

    static func build(sleeps: [CachedSleepSession], workouts: [WorkoutRow], journal: [JournalEntry],
                      needMin: Double, now: Date = Date(), calendar: Calendar = .current) -> NoopHistoryRecord {
        let clock = AppClock.hourMinuteFormatter()
        let cutoff = calendar.date(byAdding: .day, value: -span, to: calendar.startOfDay(for: now)) ?? now
        var entries: [Entry] = []

        for s in sleeps {
            let end = Date(timeIntervalSince1970: TimeInterval(s.endTs))
            guard end >= cutoff else { continue }
            let start = Date(timeIntervalSince1970: TimeInterval(s.effectiveStartTs))
            let asleep = SleepView.decodedAsleepMinutes(s.stagesJSON, effectiveStartTs: s.effectiveStartTs)
            guard asleep > 0 else { continue }
            let diff = (asleep - needMin).rounded()
            let delta = needMin > 0
                ? " \u{00B7} \(Int(abs(diff))) min \(diff >= 0 ? "over" : "short of") your need" : ""
            entries.append(.init(kind: .sleep, date: end,
                                 name: "Slept \(NoopRestRecord.duration(asleep))",
                                 detail: "\(clock.string(from: start)) \u{2192} \(clock.string(from: end))\(delta)",
                                 value: "", sport: nil))
        }
        for w in workouts {
            let start = Date(timeIntervalSince1970: TimeInterval(w.startTs))
            guard start >= cutoff else { continue }
            let minutes = Int(((w.durationS ?? Double(w.endTs - w.startTs)) / 60).rounded())
            var detail = "\(clock.string(from: start)) \u{00B7} \(minutes) min"
            if let avg = w.avgHr { detail += " \u{00B7} avg \(avg) bpm" }
            entries.append(.init(kind: .session, date: start, name: WorkoutSource.displaySport(w.sport),
                                 detail: detail, value: w.strain.map { "load \(Int($0.rounded()))" } ?? "",
                                 sport: w.sport))
        }
        let dayParser = DateFormatter()
        dayParser.locale = Locale(identifier: "en_US_POSIX"); dayParser.dateFormat = "yyyy-MM-dd"
        for (key, group) in Dictionary(grouping: journal.filter { $0.answeredYes }, by: { "\($0.day)|\($0.question)" }) {
            guard let first = group.first, let date = dayParser.date(from: first.day), date >= cutoff else { continue }
            _ = key
            entries.append(.init(kind: .log, date: date.addingTimeInterval(12 * 3600), name: first.question,
                                 detail: first.notes ?? "", value: group.count > 1 ? "\u{00D7}\(group.count)" : "",
                                 sport: nil))
        }

        let long = DateFormatter(); long.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
        var record = NoopHistoryRecord()
        record.days = grouped.keys.sorted(by: >).map { day in
            let label = calendar.isDateInToday(day) ? "Today" : calendar.isDateInYesterday(day) ? "Yesterday" : long.string(from: day)
            return Day(label: label, entries: grouped[day]!.sorted { $0.date > $1.date })
        }
        let month = DateFormatter(); month.setLocalizedDateFormatFromTemplate("MMMM")
        record.monthName = month.string(from: now)
        let thisMonth = workouts.filter {
            calendar.isDate(Date(timeIntervalSince1970: TimeInterval($0.startTs)), equalTo: now, toGranularity: .month)
        }
        record.monthSessions = thisMonth.count
        record.monthMovingMin = Int(thisMonth.reduce(0.0) { $0 + ($1.durationS ?? Double($1.endTs - $1.startTs)) } / 60)
        record.monthLoad = Int(thisMonth.compactMap(\.strain).reduce(0, +).rounded())
        record.loaded = true
        return record
    }
}

@MainActor
final class NoopHistoryStore: ObservableObject {
    @Published private(set) var record = NoopHistoryRecord()

    func load(from repo: Repository) async {
        guard repo.loaded else { return }
        let workouts = await repo.workoutRows(days: NoopHistoryRecord.span + 1)
        let journal = await repo.journalEntries(days: NoopHistoryRecord.span + 1)
        record = NoopHistoryRecord.build(sleeps: repo.sleeps, workouts: workouts, journal: journal,
                                         needMin: SleepModel.debtNeedMin(days: repo.days))
    }
}
#endif

#if os(iOS)
import StrandAnalytics

/// Where the wearer's heart-rate zones come from, so every surface that prints a bpm edge can say
/// whether it is estimated or set (owner decision, 24 Sep). The app has no observed maximum, so
/// nothing here is ever called "measured".
enum NoopZoneSource: Equatable {
    /// Bands the wearer edited; the maximum can still be age-estimated unless separately set.
    case custom(maximumIsManual: Bool)
    /// A maximum the wearer entered.
    case manualMax
    /// The age formula, over an age the wearer confirmed.
    case estimated
    /// The age formula over the profile's example age: not the wearer's zones, so no bpm is shown.
    case unconfirmed

    @MainActor static func current(_ profile: ProfileStore) -> NoopZoneSource {
        if profile.hrMaxOverride > 0 {
            return profile.hasCustomHRZones ? .custom(maximumIsManual: true) : .manualMax
        }
        // Custom bpm thresholds do not confirm the example age used for the automatic maximum.
        // Until that age is confirmed, the derived max and its dependent zone edges stay hidden.
        guard UserDefaults.standard.bool(forKey: "noop.energy.profileConfirmed") else { return .unconfirmed }
        return profile.hasCustomHRZones ? .custom(maximumIsManual: false) : .estimated
    }

    var trusted: Bool { self != .unconfirmed }

    /// The short tag printed beside a maximum or a zone list.
    var tag: String? {
        switch self {
        case .custom(let maximumIsManual): maximumIsManual ? "set by you" : "custom zones; estimated max"
        case .manualMax: "set by you"
        case .estimated: "estimated"
        case .unconfirmed: nil
        }
    }

    /// The maximum card's title.
    var maximumTitle: String {
        switch self {
        case .manualMax, .custom(maximumIsManual: true): "Maximum you set"
        case .custom(maximumIsManual: false), .estimated, .unconfirmed: "Estimated maximum"
        }
    }

    /// "Zone 3" — the app's own zone vocabulary (the design uses it on Automations). The design's
    /// Resting/Easy/Steady/Hard/All out bands do not line up with the app's zones.
    static func name(_ number: Int) -> String { "Zone \(number)" }
}
#endif
