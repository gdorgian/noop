import Foundation

/// Cardio load of one session: Banister's training impulse (TRIMP, 1991).
///
///     TRIMP = Σ minutes × r × k·e^(b·r)        r = heart-rate reserve fraction, clamped 0…1
///     k, b = 0.64, 1.92 (male) · 0.86, 1.67 (female) · their mean when sex is unknown
///
/// Each heart-rate sample contributes for the time until the next one (capped like the zone count).
/// A session with no stream is scored at its average heart rate for its whole duration.
public enum CardioLoad {
    public static func trimp(_ session: FitnessCardioSession, physiology: FitnessPhysiology,
                             maxGapS: Double = 15) -> Double {
        let (k, b) = coefficients(physiology.sex)
        func perMinute(_ bpm: Double) -> Double {
            let r = min(1, max(0, physiology.reserveFraction(bpm)))
            return r * k * exp(b * r)
        }
        if session.heartRate.isEmpty {
            guard let avg = session.averageHeartRate else { return 0 }
            return session.durationS / 60 * perMinute(avg)
        }
        let s = session.heartRate.sorted { $0.ts < $1.ts }
        var total = 0.0
        for (i, x) in s.enumerated() {
            let next = i + 1 < s.count ? s[i + 1].ts : x.ts + 1
            total += min(max(0, next - x.ts), maxGapS) / 60 * perMinute(x.bpm)
        }
        return total
    }

    static func coefficients(_ sex: FitnessPhysiology.Sex) -> (Double, Double) {
        switch sex {
        case .male: (0.64, 1.92)
        case .female: (0.86, 1.67)
        case .unspecified: (0.75, 1.795)
        }
    }
}

/// Acute against chronic load, the shape both Cardio Load and Muscular Load share.
///
/// - Acute load (ATL) is the mean daily load over the last 7 days, today included.
/// - Chronic load (CTL) is the mean daily load over the last 42 days.
/// - The optimal band is 0.8 × CTL … 1.3 × CTL: the acute:chronic window the sports-science literature
///   associates with adaptation at the lowest injury risk (Gabbett 2016).
///
/// Status by ratio ATL / CTL:
///   below 0.8 detraining · 0.8–1.0 maintaining · 1.0–1.3 productive · above 1.3 fatigued.
///
/// The figure stays `calibrating` until the history can support a chronic baseline: at least
/// `minimumSessions` sessions in the 42 days, and at least one in the last 28.
public enum TrainingLoad {
    public enum Status: String, Sendable, CaseIterable {
        case calibrating, detraining, maintaining, productive, fatigued
    }

    public struct Reading: Equatable, Sendable {
        public let acute: Double
        public let chronic: Double
        public let optimal: ClosedRange<Double>
        /// Top of the gauge: 1.4 × the top of the optimal band, so the band always sits in view.
        public let gaugeMax: Double
        public let status: Status

        public var ratio: Double? { chronic > 0 ? acute / chronic : nil }
    }

    public static let acuteDays = 7
    public static let chronicDays = 42
    public static let optimalRatio: ClosedRange<Double> = 0.8...1.3
    public static let minimumSessions = 10

    /// - Parameters:
    ///   - dailyLoad: load per calendar day, keyed by the start of that day.
    ///   - sessionDates: when each counted session happened, for the calibration rule.
    public static func reading(dailyLoad: [Date: Double], sessionDates: [Date], asOf day: Date,
                               calendar: Calendar = .current) -> Reading {
        let today = calendar.startOfDay(for: day)
        func mean(_ days: Int) -> Double {
            var sum = 0.0
            for i in 0..<days {
                if let d = calendar.date(byAdding: .day, value: -i, to: today) { sum += dailyLoad[d] ?? 0 }
            }
            return sum / Double(days)
        }
        let acute = mean(acuteDays), chronic = mean(chronicDays)
        let optimal = (optimalRatio.lowerBound * chronic)...(optimalRatio.upperBound * chronic)
        let status = isCalibrated(sessionDates, asOf: today, calendar: calendar)
            ? status(acute: acute, chronic: chronic) : .calibrating
        return Reading(acute: acute, chronic: chronic, optimal: optimal,
                       gaugeMax: max(1.4 * optimal.upperBound, acute * 1.05, 1), status: status)
    }

    public static func status(acute: Double, chronic: Double) -> Status {
        guard chronic > 0 else { return acute > 0 ? .fatigued : .detraining }
        let r = acute / chronic
        if r < 0.8 { return .detraining }
        if r < 1.0 { return .maintaining }
        if r <= 1.3 { return .productive }
        return .fatigued
    }

    static func isCalibrated(_ dates: [Date], asOf today: Date, calendar: Calendar) -> Bool {
        guard let start42 = calendar.date(byAdding: .day, value: -(chronicDays - 1), to: today),
              let start28 = calendar.date(byAdding: .day, value: -27, to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: today) else { return false }
        let inWindow = dates.filter { $0 >= start42 && $0 < end }
        return inWindow.count >= minimumSessions && inWindow.contains { $0 >= start28 }
    }

    /// Sums per-session loads into calendar days.
    public static func dailyTotals(_ loads: [(date: Date, load: Double)], calendar: Calendar = .current) -> [Date: Double] {
        var out: [Date: Double] = [:]
        for l in loads { out[calendar.startOfDay(for: l.date), default: 0] += l.load }
        return out
    }
}
