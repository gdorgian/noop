#if os(iOS)
import Foundation
import WhoopProtocol
import WhoopStore
import StrandAnalytics
import StrandFitness

/// Everything the Fitness page shows, computed once per load from the wearer's own records:
/// workouts (strap, Health, manual), the Lift log, heart rate, resting baseline and profile.
/// The maths lives in `StrandFitness` (see its FORMULAS.md); this file only adapts records into it.
struct NoopFitnessSnapshot {
    struct WeekDay: Identifiable {
        let date: Date
        let sessions: [NoopFitnessSession]
        var id: Date { date }
    }

    struct Routine: Identifiable {
        let id: String
        let name: String
        let exercises: Int
        let sets: Int
    }

    /// The days of the current week, Monday first, each with its sessions.
    var week: [WeekDay] = []
    /// Saved Lift programs, most recently edited first.
    var routines: [Routine] = []
    var cardioLoad: AcuteChronicLoad.Reading
    var muscularLoad: AcuteChronicLoad.Reading
    var activeSeconds: PeriodTotals.Series
    var activeKcal: PeriodTotals.Series
    /// Latest VO₂ max and the readings behind its line, oldest first.
    var vo2Max: [(date: Date, value: Double)] = []
    /// One-minute recovery of the most recent session that measured one, with its date.
    var heartRateRecovery: (date: Date, drop: Double)?
    var cardioFocus: CardioFocus.Breakdown
    /// Minutes in each of the five zones over the period, lowest first.
    var zoneMinutes: [Double]
    var zoneNames: [String]
    var totalSets: PeriodTotals.Series
    /// The exercise with the most volume in the period and its running total.
    var topExercise: (name: String, volume: PeriodTotals.Series)?
    var freshness: [MuscleFreshness.Reading]
    var periodDays: Int
}

/// One workout or lift on the calendar strip and in Today's Activity.
struct NoopFitnessSession: Identifiable {
    enum Kind { case cardio, strength }
    let id: String
    let start: Date
    let durationS: Double
    let title: String
    let kind: Kind
    let kcal: Double?
    let liftSessionID: String?
}

@MainActor
final class NoopFitnessModel: ObservableObject {
    @Published private(set) var snapshot: NoopFitnessSnapshot?
    @Published private(set) var isLoading = false

    static let periodDays = 30
    private static let historyDays = 60

    func load(repo: Repository, profile: ProfileStore, now: Date = Date()) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let cal = Calendar.current
        let nowTs = Int(now.timeIntervalSince1970)
        let fromTs = nowTs - Self.historyDays * 86_400

        let restingSamples = repo.days.suffix(14).compactMap(\.restingHr).sorted()
        let resting = restingSamples.isEmpty ? 60 : Double(restingSamples[restingSamples.count / 2])
        let zoneSet = profile.hrZoneSet
        let phys = FitnessPhysiology(
            restingHeartRate: resting, maxHeartRate: zoneSet.maxHR,
            sex: profile.sex == "male" ? .male : profile.sex == "female" ? .female : .unspecified,
            bodyMassKg: profile.weightKg > 0 ? profile.weightKg : nil)

        // Workouts: every source the Effort screens already show, newest history only.
        let rows = await repo.workoutRows(days: Self.historyDays).filter { $0.startTs >= fromTs }
        // Heart-rate streams are read only where a figure needs them: the 42-day load window. Older
        // sessions only feed the previous-period totals, which need duration and energy alone.
        let streamFromTs = nowTs - AcuteChronicLoad.chronicDays * 86_400
        var cardio: [(row: WorkoutRow, session: FitnessCardioSession, zoneMinutes: [Double])] = []
        for row in rows {
            let ids = Repository.workoutHrDeviceIds(source: row.source, activeStrapId: repo.deviceId,
                                                    importedIds: repo.importedReadIds)
            let hr = row.startTs >= streamFromTs
                ? await repo.hrSamples(deviceIds: ids, from: row.startTs, to: row.endTs, limit: 6_000) : []
            let session = FitnessCardioSession(
                id: "\(row.source)-\(row.startTs)", start: Date(timeIntervalSince1970: Double(row.startTs)),
                durationS: row.durationS ?? Double(row.endTs - row.startTs), kind: Self.kind(row.sport), activeEnergyKcal: row.energyKcal,
                heartRate: hr.map { FitnessHeartRateSample(ts: Double($0.ts), bpm: Double($0.bpm)) },
                averageHeartRate: row.avgHr.map(Double.init))
            // With no stream, the whole session sits in the zone of its average, as the Effort screens show it.
            var tiz = [Double](repeating: 0, count: 5)
            if !hr.isEmpty {
                tiz = HRZones.timeInZone(hr, zoneSet: zoneSet).seconds.map { $0 / 60 }
            } else if let avg = row.avgHr,
                      let z = zoneSet.zones.lastIndex(where: { Double(avg) >= $0.lower }) {
                tiz[z] = session.durationS / 60
            }
            cardio.append((row, session, tiz))
        }

        // Lift log: every working set, with the muscles the lifter classified it under.
        var sets: [FitnessStrengthSet] = []
        var liftSessions: [LiftSessionRow] = []
        var routines: [NoopFitnessSnapshot.Routine] = []
        if let store = await repo.storeHandle() {
            let programs = ((try? await store.liftPrograms(deviceId: repo.deviceId)) ?? [])
                .sorted { $0.updatedAt > $1.updatedAt }
            for p in programs {
                let items = (try? await store.liftProgramItems(programId: p.id)) ?? []
                routines.append(.init(id: p.id, name: p.name, exercises: Set(items.map(\.exercise)).count,
                                      sets: items.reduce(0) { $0 + ($1.targetSets ?? 1) }))
            }
            liftSessions = (try? await store.liftSessions(deviceId: repo.deviceId, fromTs: fromTs, toTs: nowTs)) ?? []
            for s in liftSessions {
                for set in (try? await store.liftSets(sessionId: s.id)) ?? [] where !set.isWarmup {
                    sets.append(FitnessStrengthSet(
                        date: Date(timeIntervalSince1970: Double(set.endTs ?? set.startTs ?? s.startTs)),
                        exerciseId: set.exercise, primaryMuscleId: set.primaryMuscle?.rawValue,
                        secondaryMuscleIds: set.secondaryMuscles.map(\.rawValue),
                        weightKg: set.weightKg, reps: set.reps,
                        includesBodyweight: Self.isBodyweight(set.exercise),
                        reportedRepsInReserve: set.rpe.map { max(0, 10 - $0) }))
                }
            }
        }

        // Loads.
        let trimps = cardio.map { (date: $0.session.start, load: CardioLoad.trimp($0.session, physiology: phys)) }
        let cardioSessions = cardio.filter { CardioModality.of(sport: $0.row.sport) != .strength }
        let cardioReading = AcuteChronicLoad.reading(
            dailyLoad: AcuteChronicLoad.dailyTotals(
                cardioSessions.map { (date: $0.session.start, load: CardioLoad.trimp($0.session, physiology: phys)) }),
            sessionDates: cardioSessions.map(\.session.start), asOf: now)
        let scored = MuscularLoad.score(sets)
        var muscleEvents: [(date: Date, muscleLoad: [String: Double])] = scored.map { ($0.set.date, $0.muscleLoad) }
        var muscularDaily = scored.map { (date: $0.set.date, load: $0.load) }
        for (c, t) in zip(cardio, trimps) where CardioModality.of(sport: c.row.sport) != .strength {
            let legs = MuscularLoad.cardioMuscleLoad(trimp: t.load, kind: c.session.kind)
            muscleEvents.append((c.session.start, legs))
            muscularDaily.append((c.session.start, legs.values.reduce(0, +)))
        }
        let muscularDates = cardio.map(\.session.start) + liftSessions.map { Date(timeIntervalSince1970: Double($0.startTs)) }
        let muscularReading = AcuteChronicLoad.reading(
            dailyLoad: AcuteChronicLoad.dailyTotals(muscularDaily), sessionDates: muscularDates, asOf: now)

        // Period cards.
        let period = Self.periodDays
        let periodStart = cal.date(byAdding: .day, value: -(period - 1), to: cal.startOfDay(for: now)) ?? now
        let active = PeriodTotals.cumulative(cardio.map { ($0.session.start, $0.session.durationS) }, days: period, asOf: now)
        let kcal = PeriodTotals.cumulative(cardio.compactMap { c in c.row.energyKcal.map { (c.session.start, $0) } },
                                           days: period, asOf: now)
        var zoneTotals = [Double](repeating: 0, count: 5)
        for c in cardio where c.session.start >= periodStart {
            for i in 0..<min(5, c.zoneMinutes.count) { zoneTotals[i] += c.zoneMinutes[i] }
        }
        let setSeries = PeriodTotals.cumulative(sets.map { ($0.date, 1) }, days: period, asOf: now)
        var volumeByExercise: [String: [(date: Date, value: Double)]] = [:]
        for s in sets { volumeByExercise[s.exerciseId, default: []].append((s.date, StrengthTotals.volumeKg(s, bodyMassKg: phys.bodyMassKg))) }
        let top = volumeByExercise
            .map { (name: $0.key, series: PeriodTotals.cumulative($0.value, days: period, asOf: now)) }
            .filter { $0.series.total > 0 }
            .max { $0.series.total < $1.series.total }

        // VO₂ max from Health, recovery from the newest session that recorded one.
        let vo2 = await repo.appleDailyRows(days: Self.historyDays)
            .compactMap { d -> (date: Date, value: Double)? in
                guard let v = d.vo2max, let date = Self.dayFormatter.date(from: d.day) else { return nil }
                return (date, v)
            }
            .sorted { $0.date < $1.date }
        var hrr: (date: Date, drop: Double)?
        for c in cardioSessions.sorted(by: { $0.row.startTs > $1.row.startTs }).prefix(5) {
            if let r = await repo.workoutHeartRateRecovery(from: c.row.startTs, to: c.row.endTs,
                                                            maxHR: zoneSet.maxHR, source: c.row.source),
               let after = r.after1Minute {
                hrr = (c.session.start, Double(r.endHR - after))
                break
            }
        }

        // The week strip.
        let monday = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        // A lift logged in the Lift log is shown once, from the log, not again as its strap workout.
        var all: [NoopFitnessSession] = cardio
            .filter { c in
                CardioModality.of(sport: c.row.sport) != .strength
                    || !liftSessions.contains { abs($0.startTs - c.row.startTs) < 15 * 60 }
            }
            .map { NoopFitnessSession(id: $0.session.id, start: $0.session.start, durationS: $0.session.durationS,
                                      title: $0.row.sport,
                                      kind: CardioModality.of(sport: $0.row.sport) == .strength ? .strength : .cardio,
                                      kcal: $0.row.energyKcal, liftSessionID: nil) }
        all += liftSessions.map {
            NoopFitnessSession(id: $0.id, start: Date(timeIntervalSince1970: Double($0.startTs)),
                               durationS: Double(($0.endTs ?? $0.startTs) - $0.startTs),
                               title: $0.programName ?? "Strength", kind: .strength, kcal: nil, liftSessionID: $0.id)
        }
        let week = (0..<7).compactMap { i -> NoopFitnessSnapshot.WeekDay? in
            guard let d = cal.date(byAdding: .day, value: i, to: monday) else { return nil }
            return .init(date: d, sessions: all.filter { cal.isDate($0.start, inSameDayAs: d) }.sorted { $0.start < $1.start })
        }

        snapshot = NoopFitnessSnapshot(
            week: week, routines: routines, cardioLoad: cardioReading, muscularLoad: muscularReading,
            activeSeconds: active, activeKcal: kcal, vo2Max: vo2, heartRateRecovery: hrr,
            cardioFocus: CardioFocus.breakdown(secondsInZones: zoneTotals.map { $0 * 60 }),
            zoneMinutes: zoneTotals, zoneNames: ["Resting", "Easy", "Steady", "Hard", "All out"],
            totalSets: setSeries, topExercise: top.map { ($0.name, $0.series) },
            freshness: MuscleFreshness.readings(events: muscleEvents, asOf: now),
            periodDays: period)
    }

    static func kind(_ sport: String) -> FitnessCardioKind {
        let s = sport.lowercased()
        if s.contains("walk") { return .walking }
        if s.contains("hik") { return .hiking }
        if s.contains("stair") { return .stairs }
        if s.contains("ellip") { return .elliptical }
        switch CardioModality.of(sport: sport) {
        case .foot: return .running
        case .cycling: return .cycling
        case .swimming: return .swimming
        case .rowing: return .rowing
        case .other, .unknown, .strength: return .other
        }
    }

    /// Movements whose load is the lifter's own body. Matched on the logged name, since the Lift log
    /// stores names as typed.
    static func isBodyweight(_ exercise: String) -> Bool {
        let s = exercise.lowercased()
        return ["pull up", "pull-up", "pullup", "chin up", "chin-up", "chinup", "dip", "push up", "push-up",
                "pushup", "muscle up", "inverted row"].contains { s.contains($0) }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
#endif
