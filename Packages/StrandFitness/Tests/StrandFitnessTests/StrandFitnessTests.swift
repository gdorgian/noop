import XCTest
@testable import StrandFitness

final class StrandFitnessTests: XCTestCase {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    let phys = FitnessPhysiology(restingHeartRate: 50, measuredMaxHeartRate: 190, sex: .male)
    let t0 = Date(timeIntervalSince1970: 1_760_000_000)

    // MARK: Zones

    func testZonesFollowHeartRateReserve() {
        // Reserve span is 140, so 50 % of reserve is 120 bpm and 90 % is 176 bpm.
        XCTAssertEqual(HeartRateZones.zone(for: 119, physiology: phys), 0)
        XCTAssertEqual(HeartRateZones.zone(for: 120, physiology: phys), 1)
        XCTAssertEqual(HeartRateZones.zone(for: 150, physiology: phys), 3)
        XCTAssertEqual(HeartRateZones.zone(for: 176, physiology: phys), 5)
        // A lower resting rate moves every boundary down with it.
        let fitter = FitnessPhysiology(restingHeartRate: 40, measuredMaxHeartRate: 190)
        XCTAssertEqual(HeartRateZones.zone(for: 115, physiology: fitter), 1)
        XCTAssertEqual(HeartRateZones.zone(for: 115, physiology: phys), 0)
    }

    func testMaxHeartRateFallsBackToAgeThenDefault() {
        XCTAssertEqual(FitnessPhysiology(restingHeartRate: 55, ageYears: 40).maxHeartRate, 180, accuracy: 0.001)
        XCTAssertEqual(FitnessPhysiology(restingHeartRate: 55).maxHeartRate, 190)
        XCTAssertEqual(HeartRateZones.method(for: FitnessPhysiology(restingHeartRate: 55)), .defaultMax)
    }

    func testSecondsInZonesCapsGaps() {
        let s = [FitnessHeartRateSample(ts: 0, bpm: 145), FitnessHeartRateSample(ts: 10, bpm: 145),
                 FitnessHeartRateSample(ts: 300, bpm: 180)]
        let z = HeartRateZones.secondsInZones(s, physiology: phys)
        XCTAssertEqual(z[2], 25)   // 10 s, then a 290 s gap capped at 15 s
        XCTAssertEqual(z[5], 1)
    }

    // MARK: Cardio load

    func testTrimpRisesSteeplyWithIntensity() {
        func session(_ hr: Double) -> FitnessCardioSession {
            FitnessCardioSession(id: "x", start: t0, durationS: 3600, modality: .running, averageHeartRate: hr)
        }
        let easy = CardioLoad.trimp(session(120), physiology: phys)
        let hard = CardioLoad.trimp(session(176), physiology: phys)
        // 60 min at r = 0.5: 60 × 0.5 × 0.64 × e^0.96 ≈ 50.1
        XCTAssertEqual(easy, 50.1, accuracy: 0.2)
        XCTAssertGreaterThan(hard, easy * 2.5)
        XCTAssertEqual(CardioLoad.trimp(session(40), physiology: phys), 0)
    }

    func testTrainingLoadStatusesTrackTheRatio() {
        XCTAssertEqual(TrainingLoad.status(acute: 70, chronic: 100), .detraining)
        XCTAssertEqual(TrainingLoad.status(acute: 90, chronic: 100), .maintaining)
        XCTAssertEqual(TrainingLoad.status(acute: 120, chronic: 100), .productive)
        XCTAssertEqual(TrainingLoad.status(acute: 140, chronic: 100), .fatigued)
    }

    func testTrainingLoadCalibratesOnlyWithEnoughRecentHistory() {
        let today = cal.startOfDay(for: t0)
        func days(_ offsets: [Int]) -> [Date] { offsets.map { cal.date(byAdding: .day, value: -$0, to: today)! } }
        let steady = days(Array(stride(from: 0, to: 42, by: 4)))   // 11 sessions, latest today
        let load = Dictionary(uniqueKeysWithValues: steady.map { ($0, 40.0) })
        let r = TrainingLoad.reading(dailyLoad: load, sessionDates: steady, asOf: today, calendar: cal)
        XCTAssertNotEqual(r.status, .calibrating)
        XCTAssertEqual(r.optimal.lowerBound, 0.8 * r.chronic, accuracy: 1e-9)
        XCTAssertEqual(r.gaugeMax, 1.4 * r.optimal.upperBound, accuracy: 1e-9)

        let thin = days([0, 5, 10])
        XCTAssertEqual(TrainingLoad.reading(dailyLoad: load, sessionDates: thin, asOf: today, calendar: cal).status,
                       .calibrating)
        let stale = days(Array(30..<42))   // plenty of sessions, none in the last four weeks
        XCTAssertEqual(TrainingLoad.reading(dailyLoad: load, sessionDates: stale, asOf: today, calendar: cal).status,
                       .calibrating)
    }

    func testAcuteLoadRespondsToARecentBlock() {
        let today = cal.startOfDay(for: t0)
        var load: [Date: Double] = [:]
        for i in 0..<42 { load[cal.date(byAdding: .day, value: -i, to: today)!] = 20 }
        let base = TrainingLoad.reading(dailyLoad: load, sessionDates: [], asOf: today, calendar: cal)
        for i in 0..<7 { load[cal.date(byAdding: .day, value: -i, to: today)!] = 40 }
        let block = TrainingLoad.reading(dailyLoad: load, sessionDates: [], asOf: today, calendar: cal)
        XCTAssertEqual(base.acute, 20, accuracy: 1e-9)
        XCTAssertEqual(block.acute, 40, accuracy: 1e-9)
        XCTAssertEqual(block.chronic, (35 * 20 + 7 * 40) / 42, accuracy: 1e-9)
    }

    // MARK: Muscular load

    func testSetStimulusTracksProximityToFailure() {
        XCTAssertEqual(MuscularLoad.stimulus(repsInReserve: 0), 1)
        XCTAssertEqual(MuscularLoad.stimulus(repsInReserve: 3), 1)
        XCTAssertEqual(MuscularLoad.stimulus(repsInReserve: 8), 0.5, accuracy: 1e-9)
        XCTAssertEqual(MuscularLoad.stimulus(repsInReserve: 30), 0.3)
    }

    func testWeightedSetsAreJudgedAgainstTheLiftersBest() {
        func set(_ w: Double, _ r: Int, _ m: Double) -> FitnessStrengthSet {
            FitnessStrengthSet(date: t0.addingTimeInterval(m * 60), exerciseId: "bench",
                               primaryMuscleId: "chest", secondaryMuscleIds: ["triceps", "front_delts"],
                               weightKg: w, reps: r)
        }
        // A top set to near-failure, then a light back-off set far from it.
        let scored = MuscularLoad.score([set(100, 5, 0), set(50, 5, 5)])
        XCTAssertEqual(scored[0].stimulus, 1)
        XCTAssertLessThan(scored[1].stimulus, 0.5)
        XCTAssertEqual(scored[0].muscleLoad["chest"], 10)
        XCTAssertEqual(scored[0].muscleLoad["triceps"], 5)
    }

    func testReportedRepsInReserveWins() {
        let s = FitnessStrengthSet(date: t0, exerciseId: "row", primaryMuscleId: "lats",
                                   weightKg: 20, reps: 5, reportedRepsInReserve: 1)
        XCTAssertEqual(MuscularLoad.score([s])[0].stimulus, 1)
    }

    // MARK: Freshness

    func testFreshnessRecoversWithEachMusclesHalfLife() {
        let session: [(date: Date, muscleLoad: [String: Double])] = [(t0, ["quadriceps": 40, "calves": 40])]
        let next = MuscleFreshness.readings(events: session, asOf: t0.addingTimeInterval(18 * 3600), calendar: cal)
        let quads = next.first { $0.group == .quads }!, calves = next.first { $0.group == .calves }!
        // Calves (18 h half-life) are further back than quads (36 h) after the same session.
        XCTAssertGreaterThan(calves.percent, quads.percent)
        XCTAssertEqual(calves.percent, 100 * (1 - 20.0 / 60), accuracy: 0.01)
        XCTAssertEqual(quads.status, .calibrating)
        let later = MuscleFreshness.readings(events: session, asOf: t0.addingTimeInterval(7 * 86_400), calendar: cal)
        XCTAssertGreaterThan(later.first { $0.group == .quads }!.percent, 95)
        XCTAssertEqual(next.first { $0.group == .chest }!.percent, 100)
    }

    func testFreshnessCapacityIsPersonal() {
        // Someone who trains chest at 60 points a session, three days a week, has a 90-point capacity.
        let days = (0..<6).map { t0.addingTimeInterval(-Double($0) * 2.5 * 86_400) }
        let events = days.map { (date: $0, muscleLoad: ["chest": 60.0]) }
        let r = MuscleFreshness.readings(events: events, asOf: t0, calendar: cal).first { $0.group == .chest }!
        XCTAssertNotEqual(r.status, .calibrating)
        XCTAssertGreaterThan(r.percent, 1)
        XCTAssertEqual(MuscleFreshness.status(percent: 80), .recovered)
        XCTAssertEqual(MuscleFreshness.status(percent: 55), .fatigued)
        XCTAssertEqual(MuscleFreshness.status(percent: 20), .depleted)
    }

    func testCatalogueIdsFoldIntoGroups() {
        XCTAssertEqual(FitnessMuscleGroup.forMuscleId("side_delts"), .shoulders)
        XCTAssertEqual(FitnessMuscleGroup.forMuscleId("outer_quadriceps"), .quads)
        XCTAssertNil(FitnessMuscleGroup.forMuscleId("unknown"))
    }

    // MARK: Cardio focus, recovery, totals

    func testCardioFocusIgnoresZoneZero() {
        let b = CardioFocus.breakdown(secondsInZones: [9999, 60, 60, 30, 30, 20])
        XCTAssertEqual(b.trainingSeconds, 200)
        XCTAssertEqual(b.shares[.lowAerobic]!, 0.6, accuracy: 1e-9)
        XCTAssertEqual(b.dominant, .lowAerobic)
        XCTAssertNil(CardioFocus.breakdown(secondsInZones: [100, 0, 0, 0, 0, 0]).dominant)
    }

    func testHeartRateRecoveryNeedsBothReadings() {
        let end = t0
        let s = [FitnessHeartRateSample(ts: end.timeIntervalSince1970 + 2, bpm: 160),
                 FitnessHeartRateSample(ts: end.timeIntervalSince1970 + 58, bpm: 135)]
        XCTAssertEqual(HeartRateRecovery.oneMinute(end: end, samples: s), 25)
        XCTAssertEqual(HeartRateRecovery.band(25), .good)
        XCTAssertNil(HeartRateRecovery.oneMinute(end: end, samples: Array(s.prefix(1))))
    }

    func testPeriodTotalsAlignCurrentAndPrevious() {
        let today = cal.startOfDay(for: t0)
        let v: [(date: Date, value: Double)] = [
            (today, 30), (cal.date(byAdding: .day, value: -2, to: today)!, 10),
            (cal.date(byAdding: .day, value: -8, to: today)!, 5),
        ]
        let s = PeriodTotals.cumulative(v, days: 7, asOf: t0, calendar: cal)
        XCTAssertEqual(s.current, [0, 0, 0, 0, 10, 10, 40])
        XCTAssertEqual(s.previousTotal, 5)
    }

    func testBodyweightVolumeIncludesTheLifter() {
        let pullUp = FitnessStrengthSet(date: t0, exerciseId: "pull_up", primaryMuscleId: "lats",
                                        secondaryMuscleIds: ["biceps"], reps: 10, includesBodyweight: true)
        XCTAssertEqual(StrengthTotals.volumeKg(pullUp, bodyMassKg: 75), 750)
        XCTAssertEqual(StrengthTotals.setsPerGroup([pullUp])[.biceps], 0.5)
    }
}
