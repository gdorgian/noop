import Foundation

/// Six heart-rate zones on the wearer's heart-rate reserve (Karvonen):
///
///     reserve fraction = (HR − resting) / (max − resting)
///
/// Zone 0 is below 50 % of reserve — moving, but not training. Zones 1–5 are the usual 10-point bands
/// from 50 % to 90 %+. Using the reserve rather than a percentage of max means the same zone asks the
/// same effort of someone whose resting rate is 45 and someone whose is 70.
public enum HeartRateZones {
    public static let lowerBounds: [Double] = [0, 0.5, 0.6, 0.7, 0.8, 0.9]
    public static let count = 6

    public enum Method: Equatable, Sendable {
        /// Max heart rate was measured on the wearer.
        case measuredMax
        /// Max heart rate estimated from age.
        case ageEstimate
        /// Neither was known; zones are a rough guide only.
        case defaultMax
    }

    public static func method(for physiology: FitnessPhysiology) -> Method {
        if let m = physiology.measuredMaxHeartRate, m > physiology.restingHeartRate + 20 { return .measuredMax }
        return physiology.ageYears == nil ? .defaultMax : .ageEstimate
    }

    public static func reserveFraction(_ bpm: Double, physiology: FitnessPhysiology) -> Double {
        let span = physiology.maxHeartRate - physiology.restingHeartRate
        guard span > 0 else { return 0 }
        return (bpm - physiology.restingHeartRate) / span
    }

    public static func zone(for bpm: Double, physiology: FitnessPhysiology) -> Int {
        let f = reserveFraction(bpm, physiology: physiology)
        return lowerBounds.lastIndex(where: { f >= $0 }) ?? 0
    }

    /// The heart-rate range of each zone, in bpm, for display beside the zone names.
    public static func bpmRanges(physiology: FitnessPhysiology) -> [ClosedRange<Double>] {
        let rest = physiology.restingHeartRate, span = physiology.maxHeartRate - rest
        return (0..<count).map { z in
            let lo = z == 0 ? 0 : rest + lowerBounds[z] * span
            let hi = z == count - 1 ? physiology.maxHeartRate : rest + lowerBounds[z + 1] * span
            return lo...max(lo, hi)
        }
    }

    /// Seconds spent in each zone. Each sample holds until the next one, capped at `maxGapS` so a
    /// dropped connection is not counted as minutes at the last reading.
    public static func secondsInZones(_ samples: [FitnessHeartRateSample], physiology: FitnessPhysiology,
                                      maxGapS: Double = 15) -> [Double] {
        var out = [Double](repeating: 0, count: count)
        let sorted = samples.sorted { $0.ts < $1.ts }
        for (i, s) in sorted.enumerated() {
            let next = i + 1 < sorted.count ? sorted[i + 1].ts : s.ts + 1
            out[zone(for: s.bpm, physiology: physiology)] += min(max(0, next - s.ts), maxGapS)
        }
        return out
    }

    /// Seconds in zones for a session: its stream when it has one, otherwise its whole duration in the
    /// zone of its average heart rate.
    public static func secondsInZones(_ session: FitnessCardioSession, physiology: FitnessPhysiology) -> [Double] {
        if !session.heartRate.isEmpty { return secondsInZones(session.heartRate, physiology: physiology) }
        var out = [Double](repeating: 0, count: count)
        if let avg = session.averageHeartRate { out[zone(for: avg, physiology: physiology)] = session.durationS }
        return out
    }
}
