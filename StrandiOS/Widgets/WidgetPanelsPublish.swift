#if os(iOS)
import Foundation
import StrandAnalytics
import StrandFitness
import WhoopStore
import WidgetKit

/// Builds `WidgetPanels` from what the app's own screens read, and hands it to the widgets.
///
/// Each panel goes through the builder its screen uses, so a widget can never disagree with the page it
/// opens: the night through `NoopRestRecord.build` (Rest), the vitals through `BodyVitalSigns` and
/// `NoopVital` (Today's Vitals), the weight through `WeightTrendSummary` (the goal tracker's own trend),
/// the sessions through the Fitness tab's "a logged lift is shown once" rule, and the goal through
/// `GoalTrackingStore`. Nothing is estimated to fill a gap; a panel with nothing behind it is left out.
@MainActor
enum WidgetPanelsPublisher {
    private static var inFlight = false
    private static var lastRun: Date = .distantPast

    /// Called from the full glance publish (app active, after a sync or a score), never from the
    /// once-a-minute live path: nothing here moves with the heart rate.
    static func publish(from model: AppModel, now: Date = Date(), force: Bool = false) async {
        let repo = model.repo
        guard repo.loaded, !inFlight else { return }
        // A refresh storm (sync, analysis passes) bumps the repository several times a minute; the
        // panels change at most with a new night, a weigh-in or a session, so one pass a minute is
        // plenty unless a save asked for it directly.
        guard force || now.timeIntervalSince(lastRun) >= 60 else { return }
        inFlight = true
        lastRun = now
        defer { inFlight = false }
        let calendar = Calendar.current
        let panels = WidgetPanels(
            updated: now,
            sleep: await sleep(repo: repo, now: now, calendar: calendar),
            steps: await steps(repo: repo, now: now, calendar: calendar),
            vitals: vitals(repo: repo, now: now),
            weight: await weight(repo: repo, now: now),
            training: await training(repo: repo, now: now),
            goal: goal(now: now, calendar: calendar)
        )
        if panels.saveIfChanged(previous: WidgetPanels.load()) {
            for kind in WidgetPanels.kinds { WidgetCenter.shared.reloadTimelines(ofKind: kind) }
        }
    }

    // MARK: Sleep

    private static func sleep(repo: Repository, now: Date, calendar: Calendar) async -> WidgetPanels.Sleep? {
        let sessions = await repo.allSleepSessions(days: 30)
        let habitual = await repo.habitualMidsleepSec()
        let record = NoopRestRecord.build(days: repo.days,
                                          sessions: sessions.isEmpty ? repo.sleeps : sessions,
                                          habitualMidsleepSec: habitual,
                                          importedDebtMin: repo.importedSleep.compactMapValues(\.debtMin),
                                          now: now, calendar: calendar)
        guard let night = record.latest else { return nil }
        let today = calendar.startOfDay(for: now)
        let letters = (0..<7).map { index -> String in
            guard let day = calendar.date(byAdding: .day, value: index - 6, to: today) else { return "" }
            return calendar.veryShortStandaloneWeekdaySymbols[calendar.component(.weekday, from: day) - 1]
        }
        return .init(
            endedAt: night.endDate,
            asleepMin: night.asleepMin,
            deepMin: night.stages.deep, remMin: night.stages.rem,
            lightMin: night.stages.light, awakeMin: night.stages.awake,
            window: night.asleepWindow,
            needMin: record.needMin > 0 ? record.needMin : nil,
            needCalibrating: record.confidence == .calibrating,
            runs: night.runs?.map { .init(stage: $0.stage, from: $0.from, to: $0.to) },
            week: record.slots.map { $0?.asleepMin },
            weekLetters: letters)
    }

    // MARK: Steps

    /// The strap's count, with Apple Health's winning on any day it carries one — the same merge the
    /// Instrument's step signal makes, so the two never disagree about a day.
    private static func steps(repo: Repository, now: Date, calendar: Calendar) async -> WidgetPanels.Steps? {
        let keys = dayKeys(endingAt: now, count: 7, calendar: calendar)
        let strap = Dictionary(repo.days.suffix(10).compactMap { row in row.steps.map { (row.day, $0) } },
                               uniquingKeysWith: { _, last in last })
        let apple = Dictionary(await repo.series(key: "steps", source: Repository.appleHealthSource, days: 10)
                                   .map { ($0.day, Int($0.value.rounded())) },
                               uniquingKeysWith: { _, last in last })
        let week: [Int?] = keys.map { key in (apple[key] ?? strap[key]).flatMap { $0 > 0 ? $0 : nil } }
        guard week.contains(where: { $0 != nil }) else { return nil }
        let todayKey = keys.last ?? ""
        let source: String? = apple[todayKey].map { $0 > 0 ? "health" : nil } ?? (strap[todayKey].map { $0 > 0 ? "strap" : nil } ?? nil)
        return .init(today: week.last ?? nil, source: source, week: week,
                     weekLetters: letters(for: keys, calendar: calendar),
                     goal: stepGoal())
    }

    /// The highest step target among active goal actions; nil when none is set.
    private static func stepGoal() -> Int? {
        GoalActionStore.shared.actions
            .filter(\.isActive)
            .compactMap { action -> Int? in
                if case .steps(let minimum) = action.requirement { return minimum }
                return nil
            }
            .max()
    }

    // MARK: Vitals

    private static func vitals(repo: Repository, now: Date) -> WidgetPanels.Vitals? {
        let readings = BodyVitalSigns.readings(sourceRows: repo.vitalMetricRows, temperatureUnit: .celsius, now: now)
            .filter { NoopDayStore.todayVitalKeys.contains($0.key) }
        let items: [WidgetPanels.Vitals.Item] = NoopVital.designOrder.compactMap { key in
            guard let vital = readings.first(where: { $0.key == key }).flatMap(NoopVital.init(reading:)) else {
                return nil
            }
            let scale = vital.scale
            return .init(id: vital.key, name: vital.name, short: shortName(vital.key), unit: vital.unit,
                         decimals: vital.decimals, value: vital.value, low: vital.low, high: vital.high,
                         scaleLow: scale.lowerBound, scaleHigh: scale.upperBound,
                         baseline: vital.baseline, outside: vital.outside)
        }
        guard !items.isEmpty else { return nil }
        let newest = readings.compactMap(\.day).max()
        return .init(measuredAt: newest.flatMap(date(fromKey:)), items: items)
    }

    private static func shortName(_ key: String) -> String {
        switch key {
        case "rhr": "Resting"
        case "hrv": "HRV"
        case "resp": "Breathing"
        case "spo2": "Oxygen"
        default: "Skin temp"
        }
    }

    // MARK: Weight

    /// Weigh-ins logged on Body and those Apple Health holds, one reading per day (a logged entry wins),
    /// folded by the goal tracker's own smoothing.
    private static func weight(repo: Repository, now: Date) async -> WidgetPanels.Weight? {
        let since = now.addingTimeInterval(-120 * 86_400)
        var byDay: [String: (date: Date, kg: Double)] = [:]
        for row in await repo.series(key: "weight", source: Repository.appleHealthSource, days: 120) {
            guard let day = date(fromKey: row.day) else { continue }
            byDay[row.day] = (day.addingTimeInterval(8 * 3600), row.value)
        }
        if let store = await repo.storeHandle(),
           let logged = try? await store.bodyMeasurements(deviceId: repo.deviceId) {
            for row in logged where row.kind == .weight {
                let at = Date(timeIntervalSince1970: TimeInterval(row.ts))
                guard at >= since else { continue }
                byDay[Repository.localDayKey(at)] = (at, row.value)
            }
        }
        let samples = byDay.values.filter { $0.date >= since }.map { (date: $0.date, value: $0.kg) }
        guard let summary = WeightTrendSummary.summarize(samples, now: now) else { return nil }
        let units = UnitSystem(rawValue: UserDefaults.standard.string(forKey: UnitPrefs.systemKey) ?? "") ?? .metric
        let shown = { (kg: Double) in LiftFormat.display(fromKilograms: kg, system: units) }
        let window = now.addingTimeInterval(-90 * 86_400)
        return .init(
            unit: LiftFormat.weightUnit(units),
            latest: shown(summary.latestKg), latestAt: summary.latestAt,
            trend: shown(summary.trendKg), trendReliable: summary.isTrendReliable,
            change30: summary.change30dKg.map { shown(abs($0)) * ($0 < 0 ? -1 : 1) },
            readings: samples.filter { $0.date >= window }.sorted { $0.date < $1.date }
                .map { .init(at: $0.date, value: shown($0.value)) },
            trendLine: WeightTrendSummary.smoothedSeries(samples).filter { $0.date >= window }
                .map { .init(at: $0.date, value: shown($0.value)) })
    }

    // MARK: Training

    private struct Session {
        let start: Date
        let minutes: Int
        let title: String
        let strength: Bool
        let symbol: String
    }

    /// Workouts from every source the Fitness tab shows, with a lift that the Lift log holds counted
    /// once, from the log — the same rule as `NoopFitnessModel.load`.
    private static func training(repo: Repository, now: Date) async -> WidgetPanels.Training? {
        let calendar = Calendar.current
        let weeks = 12
        let monday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
            ?? calendar.startOfDay(for: now)
        guard let gridStart = calendar.date(byAdding: .day, value: -7 * (weeks - 1), to: monday) else { return nil }
        let fromTs = Int(gridStart.timeIntervalSince1970)
        let rows = await repo.workoutRows(days: 7 * weeks + 7, reconcileHrCap: 0).filter { $0.startTs >= fromTs }
        var lifts: [LiftSessionRow] = []
        if let store = await repo.storeHandle() {
            lifts = (try? await store.liftSessions(deviceId: repo.deviceId, fromTs: fromTs,
                                                    toTs: Int(now.timeIntervalSince1970))) ?? []
        }
        var sessions: [Session] = rows
            .filter { row in
                CardioModality.of(sport: row.sport) != .strength
                    || !lifts.contains { abs($0.startTs - row.startTs) < 15 * 60 }
            }
            .map { row in
                let strength = CardioModality.of(sport: row.sport) == .strength
                return Session(start: Date(timeIntervalSince1970: TimeInterval(row.startTs)),
                               minutes: Int(((row.durationS ?? Double(row.endTs - row.startTs)) / 60).rounded()),
                               title: WorkoutSource.displaySport(row.sport), strength: strength,
                               symbol: strength ? "dumbbell.fill" : symbol(NoopFitnessModel.kind(row.sport)))
            }
        sessions += lifts.map { lift in
            Session(start: Date(timeIntervalSince1970: TimeInterval(lift.startTs)),
                    minutes: Int((Double((lift.endTs ?? lift.startTs) - lift.startTs) / 60).rounded()),
                    title: lift.programName ?? "Strength", strength: true, symbol: "dumbbell.fill")
        }

        // The first day anything was recorded: earlier days are unknown, not rest days.
        let firstDay: Date? = repo.days.first.flatMap { date(fromKey: $0.day) }
        let firstSession: Date? = sessions.map(\.start).min()
        let firstRecord: Date? = [firstDay, firstSession].compactMap { $0 }.min().map { calendar.startOfDay(for: $0) }
        let today = calendar.startOfDay(for: now)
        var minutesByDay: [Date: Int] = [:]
        var countByDay: [Date: Int] = [:]
        for s in sessions {
            let day = calendar.startOfDay(for: s.start)
            minutesByDay[day, default: 0] += max(1, s.minutes)
            countByDay[day, default: 0] += 1
        }
        let grid: [Int?] = (0..<(weeks * 7)).map { offset -> Int? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: gridStart) else { return nil }
            if day > today { return nil }
            guard let firstRecord, day >= firstRecord else { return nil }
            return minutesByDay[day] ?? 0
        }
        guard grid.contains(where: { $0 != nil }) else { return nil }
        let weekDays = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
        let trained28 = (0..<28).filter { back in
            calendar.date(byAdding: .day, value: -back, to: today).map { (countByDay[$0] ?? 0) > 0 } ?? false
        }.count
        let last = sessions.max { $0.start < $1.start }

        // The Train widget: recent sports, then routines; the streak; this week's two colours.
        var starts: [WidgetPanels.Training.Start] = []
        for row in rows.sorted(by: { $0.startTs > $1.startTs }) where CardioModality.of(sport: row.sport) != .strength {
            let name = row.sport
            guard !name.isEmpty, !["detected", "other", "activity"].contains(name.lowercased()),
                  WorkoutCatalog.sport(named: name) != nil,
                  !starts.contains(where: { $0.key.caseInsensitiveCompare(name) == .orderedSame }) else { continue }
            starts.append(.init(title: name, symbol: NoopFitnessCardioLive.symbol(for: name), key: name, strength: false))
            if starts.count == 3 { break }
        }
        for name in ["Running", "Walking", "Cycling"] where starts.count < 3 && !starts.contains(where: { $0.key == name }) {
            starts.append(.init(title: name, symbol: NoopFitnessCardioLive.symbol(for: name), key: name, strength: false))
        }
        if let store = await repo.storeHandle() {
            let programs = ((try? await store.liftPrograms(deviceId: repo.deviceId)) ?? [])
                .sorted { $0.updatedAt > $1.updatedAt }
            for p in programs.prefix(2) {
                starts.append(.init(title: p.name, symbol: "dumbbell.fill", key: p.id, strength: true))
            }
        }
        let thisWeek = sessions.filter { $0.start >= monday }
        let streak = TrainingStreak.reading(sessionDates: sessions.map(\.start), now: now)

        return .init(
            weekMinutes: weekDays.map { $0 > today ? nil : (minutesByDay[$0] ?? 0) },
            weekSessions: weekDays.map { countByDay[$0] ?? 0 },
            weekLetters: weekDays.map {
                calendar.veryShortStandaloneWeekdaySymbols[calendar.component(.weekday, from: $0) - 1]
            },
            todayIndex: weekDays.firstIndex(of: today) ?? 0,
            last: last.map { .init(title: $0.title, strength: $0.strength, symbol: $0.symbol,
                                   start: $0.start, minutes: $0.minutes) },
            grid: grid,
            trained28: trained28,
            starts: starts,
            streakWeeks: streak.weeks,
            weekStrengthMinutes: thisWeek.filter(\.strength).reduce(0) { $0 + $1.minutes },
            weekCardioMinutes: thisWeek.filter { !$0.strength }.reduce(0) { $0 + $1.minutes })
    }

    private static func symbol(_ kind: FitnessCardioKind) -> String {
        switch kind {
        case .running: "figure.run"
        case .cycling: "figure.outdoor.cycle"
        case .rowing: "figure.rower"
        case .walking: "figure.walk"
        case .hiking: "figure.hiking"
        case .swimming: "figure.pool.swim"
        case .elliptical: "figure.elliptical"
        case .stairs: "figure.stair.stepper"
        case .mixed, .other: "figure.mixed.cardio"
        }
    }

    // MARK: Goal

    /// The goal the journey shows (the first active one), with the tracker's own verdict.
    private static func goal(now: Date, calendar: Calendar) -> WidgetPanels.Goal? {
        guard let goal = CoachGoalStore.shared.activeGoals.first else { return nil }
        let snapshot = GoalTrackingStore.shared.snapshot(for: goal.id)
        let units = UnitSystem(rawValue: UserDefaults.standard.string(forKey: UnitPrefs.systemKey) ?? "") ?? .metric
        func format(_ value: Double?) -> String? {
            guard let value else { return nil }
            if goal.kind == .weight {
                return "\(LiftFormat.trim((LiftFormat.display(fromKilograms: value, system: units) * 10).rounded() / 10)) \(LiftFormat.weightUnit(units))"
            }
            let unit = goal.kind.unit
            let number = abs(value - value.rounded()) < 0.05 ? String(Int(value.rounded())) : String(format: "%.1f", value)
            return unit.isEmpty ? number : "\(number) \(unit)"
        }
        let todayKey = Repository.localDayKey(now)
        let actions = GoalTrackingStore.shared.todayActions
            .filter { $0.day == todayKey && ($0.action.goalIds.isEmpty || $0.action.goalIds.contains(goal.id)) }
            .map { occurrence in
                let title = occurrence.action.title.trimmingCharacters(in: .whitespaces)
                return WidgetPanels.Goal.Action(label: title.isEmpty ? occurrence.action.requirement.label : title,
                                                done: occurrence.isCompleted)
            }
        return .init(
            title: goal.title, kind: goal.kind.label, symbol: goal.kind.icon,
            progress: goal.kind.isQuantified ? snapshot?.progressFraction : nil,
            health: snapshot?.health.label ?? (goal.status == .paused ? "Paused" : "Building evidence"),
            healthRank: snapshot?.health.rawValue ?? GoalTrackingSnapshot.Health.building.rawValue,
            reason: snapshot?.reason ?? "",
            deadline: goal.targetDate,
            current: format(snapshot?.measurement?.value),
            target: format(goal.target),
            nextMilestone: snapshot?.nextMilestone.flatMap { format($0.value) },
            streakWeeks: snapshot?.currentStreak ?? 0,
            today: Array(actions.prefix(3)),
            measured: goal.kind.isQuantified)
    }

    // MARK: Days

    private static func dayKeys(endingAt now: Date, count: Int, calendar: Calendar) -> [String] {
        let start = calendar.startOfDay(for: now)
        return (0..<count).reversed().compactMap { back in
            calendar.date(byAdding: .day, value: -back, to: start).map(Repository.localDayKey)
        }
    }

    private static func letters(for keys: [String], calendar: Calendar) -> [String] {
        keys.map { key in
            guard let day = date(fromKey: key) else { return "" }
            return calendar.veryShortStandaloneWeekdaySymbols[calendar.component(.weekday, from: day) - 1]
        }
    }

    private static func date(fromKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
#endif
