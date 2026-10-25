import Foundation

// DailyRhythm.swift — the shape of the wearer's day, from the strap's own motion (WHOOP 5.0 / MG
// `dynamic_acceleration`, stored per second as `gravitySample.dynAccel`).
//
// Five readings, every one of them scale-free, so none depends on how the strap's motion number relates to
// the units a study used:
//
//  • The 24-hour profile: mean motion per clock hour across the window, shown relative to its own peak.
//  • Peak time (acrophase) from a single-component cosinor fit, τ = 24 h, over every observed minute.
//  • Rhythm strength: the cosinor amplitude over its MESOR (relative amplitude).
//  • Interdaily stability (IS, van Someren 1999): how alike the days are, 0 (unrelated) to 1 (identical).
//  • Intradaily variability (IV): how broken up the day is, near 0 for one smooth wave, up to about 2 for noise.
//
// What it does NOT give is a "rhythm age". The published CosinorAge model (Shim, Fleisch & Barata,
// npj Digital Medicine 2024) maps MESOR and amplitude in milli-g of ENMO onto years, and the strap's motion
// number is not ENMO. Without a measured conversion for this wearer the years would be a guess dressed as a
// number, so none is computed.
//
// Coverage decides whether the readings mean anything: a 24-hour fit on days worn only while awake cuts
// the trough out of the wave. A day counts with 16 hours observed; the window needs `minimumDays` of them and
// no more than `maxBlindHours` consecutive clock hours that were never observed (the strap's charge).

public enum DailyRhythm {

    public static let minutesPerDay = 1440
    /// Observed minutes for a day to count: two thirds of it.
    public static let minimumMinutesPerDay = 960
    /// Counting days needed for a reading.
    public static let minimumDays = 5
    /// Consecutive never-observed clock hours tolerated across the window.
    public static let maxBlindHours = 2
    /// Pooled minutes a clock hour needs before it counts as observed.
    public static let minimumMinutesPerHour = 30

    /// One local day of per-minute mean motion; nil where nothing was recorded.
    public struct Day: Equatable, Sendable {
        public let key: String
        public let minutes: [Double?]
        public init(key: String, minutes: [Double?]) {
            precondition(minutes.count == DailyRhythm.minutesPerDay)
            self.key = key
            self.minutes = minutes
        }
        public var observed: Int { minutes.reduce(0) { $0 + ($1 == nil ? 0 : 1) } }
        public var counts: Bool { observed >= DailyRhythm.minimumMinutesPerDay }
    }

    public struct Reading: Equatable, Sendable {
        /// Mean motion per clock hour 0…23, divided by the highest hour, so the peak hour is 1.
        public let profile: [Double]
        /// Minute of the day the fitted wave peaks.
        public let peakMinute: Int
        /// Cosinor amplitude over MESOR.
        public let relativeAmplitude: Double
        /// Interdaily stability, 0…1.
        public let stability: Double
        /// Intradaily variability, about 0…2.
        public let fragmentation: Double
        /// Days that counted.
        public let days: Int
        /// The quietest five consecutive hours, as the hour they start (the rest of the wave).
        public let quietStartHour: Int
    }

    public enum Outcome: Equatable, Sendable {
        case reading(Reading)
        /// Too few counting days so far: how many there are.
        case gathering(days: Int)
        /// Enough days, but a stretch of the clock is never observed: its length in hours.
        case blindSpot(hours: Int)
        /// A day too flat to have a peak (amplitude under a tenth of the mean).
        case flat
    }

    public static func read(_ days: [Day]) -> Outcome {
        let counting = days.filter(\.counts)
        guard counting.count >= minimumDays else { return .gathering(days: counting.count) }

        // Pooled coverage per clock hour, then the longest cyclic run of unobserved hours.
        var hourMinutes = [Int](repeating: 0, count: 24)
        var hourSum = [Double](repeating: 0, count: 24)
        for d in counting {
            for (m, v) in d.minutes.enumerated() {
                guard let v else { continue }
                hourMinutes[m / 60] += 1
                hourSum[m / 60] += v
            }
        }
        let blind = longestCyclicRun(hourMinutes.map { $0 < minimumMinutesPerHour })
        guard blind <= maxBlindHours else { return .blindSpot(hours: blind) }

        // Cosinor by least squares on [1, cos, sin] over every observed minute of every counting day.
        var xtx = [[Double]](repeating: [0, 0, 0], count: 3)
        var xty = [0.0, 0.0, 0.0]
        for d in counting {
            for (m, v) in d.minutes.enumerated() {
                guard let v else { continue }
                let w = 2 * Double.pi * Double(m) / Double(minutesPerDay)
                let x = [1, cos(w), sin(w)]
                for i in 0..<3 {
                    xty[i] += x[i] * v
                    for j in 0..<3 { xtx[i][j] += x[i] * x[j] }
                }
            }
        }
        guard let beta = solve3(xtx, xty) else { return .flat }
        let mesor = beta[0]
        let amplitude = (beta[1] * beta[1] + beta[2] * beta[2]).squareRoot()
        guard mesor > 0, amplitude / mesor >= 0.10 else { return .flat }
        var phase = atan2(beta[2], beta[1])
        if phase < 0 { phase += 2 * Double.pi }
        let peak = Int((phase / (2 * Double.pi) * Double(minutesPerDay)).rounded()) % minutesPerDay

        // Hourly series for IS / IV: one value per clock hour per counting day, where observed.
        var hourly: [Double?] = []
        for d in counting {
            for h in 0..<24 {
                let slice = d.minutes[(h * 60)..<(h * 60 + 60)].compactMap { $0 }
                hourly.append(slice.count >= minimumMinutesPerHour ? slice.reduce(0, +) / Double(slice.count) : nil)
            }
        }
        let values = hourly.compactMap { $0 }
        let mean = values.reduce(0, +) / Double(max(values.count, 1))
        let total = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        var hourMeans = [Double](repeating: 0, count: 24)
        var hourCounts = [Int](repeating: 0, count: 24)
        for (i, v) in hourly.enumerated() { if let v { hourMeans[i % 24] += v; hourCounts[i % 24] += 1 } }
        for h in 0..<24 where hourCounts[h] > 0 { hourMeans[h] /= Double(hourCounts[h]) }
        let between = (0..<24).reduce(0.0) { $0 + Double(hourCounts[$1]) * pow(hourMeans[$1] - mean, 2) }
        let stability = total > 0 ? min(max(between / total, 0), 1) : 0
        var successive = 0.0, pairs = 0
        for i in 1..<hourly.count {
            if let a = hourly[i - 1], let b = hourly[i] { successive += (b - a) * (b - a); pairs += 1 }
        }
        let variance = total / Double(max(values.count, 1))
        let fragmentation = pairs > 0 && variance > 0 ? (successive / Double(pairs)) / variance : 0

        let profileRaw = (0..<24).map { hourMinutes[$0] > 0 ? hourSum[$0] / Double(hourMinutes[$0]) : 0 }
        let top = profileRaw.max() ?? 0
        let profile = profileRaw.map { top > 0 ? $0 / top : 0 }
        func fiveHours(from start: Int) -> Double {
            var sum = 0.0
            for k in 0..<5 { sum += profileRaw[(start + k) % 24] }
            return sum
        }
        let quiet = (0..<24).min { fiveHours(from: $0) < fiveHours(from: $1) } ?? 0

        return .reading(Reading(profile: profile, peakMinute: peak, relativeAmplitude: amplitude / mesor,
                                stability: stability, fragmentation: fragmentation, days: counting.count,
                                quietStartHour: quiet))
    }

    /// Fold per-minute means (minute index since 1970 in local time → mean) into local days.
    public static func days(minuteMeans: [(localMinute: Int, value: Double)], dayKey: (Int) -> String) -> [Day] {
        var byDay: [Int: [Double?]] = [:]
        for (minute, value) in minuteMeans {
            let day = Int(floor(Double(minute) / Double(minutesPerDay)))
            var row = byDay[day] ?? [Double?](repeating: nil, count: minutesPerDay)
            row[minute - day * minutesPerDay] = value
            byDay[day] = row
        }
        return byDay.keys.sorted().map { Day(key: dayKey($0), minutes: byDay[$0]!) }
    }

    private static func longestCyclicRun(_ flags: [Bool]) -> Int {
        guard flags.contains(false) else { return flags.count }
        var best = 0, run = 0
        for f in flags + flags { run = f ? run + 1 : 0; best = max(best, run) }
        return min(best, flags.count)
    }

    /// Gaussian elimination for the 3×3 normal equations; nil when singular.
    private static func solve3(_ a: [[Double]], _ b: [Double]) -> [Double]? {
        var m = a, v = b
        for c in 0..<3 {
            guard let p = (c..<3).max(by: { abs(m[$0][c]) < abs(m[$1][c]) }), abs(m[p][c]) > 1e-12 else { return nil }
            m.swapAt(c, p); v.swapAt(c, p)
            for r in 0..<3 where r != c {
                let f = m[r][c] / m[c][c]
                for k in c..<3 { m[r][k] -= f * m[c][k] }
                v[r] -= f * v[c]
            }
        }
        return (0..<3).map { v[$0] / m[$0][$0] }
    }
}
