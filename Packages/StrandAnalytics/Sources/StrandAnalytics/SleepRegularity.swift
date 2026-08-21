import Foundation

// MARK: - Sleep Regularity Index
//
// `VitalityEngine.sleepConsistency` measures regularity as `1 − coefficient of variation` over nightly
// DURATIONS. That was the honest answer while durations were all the app could reach, and its own
// comment says so — but it cannot see the thing regularity actually means. Someone who sleeps exactly
// seven hours every night, starting at 22:00 on weekdays and 03:00 at weekends, scores a perfect 1.0
// under the duration proxy while living in two different time zones a week.
//
// NOOP stores every sleep session's start and end, so the real measure is available.
//
// ## The method
//
// Sleep Regularity Index (Phillips et al., Sci Rep 2017): sample the wearer's state — asleep or awake —
// at a fixed resolution, then ask how often the state at time *t* matches the state at *t + 24 h*.
//
//     SRI = 100 × (2 × P(match) − 1)
//
// 100 is a perfectly repeating day. 0 is a coin flip. Negative means anti-correlated with itself, which
// in practice only happens on very short windows or shift work.
//
// This is a percentage-of-agreement measure, not a variance measure, which is why it catches the
// weekend-shift case the duration proxy misses: the hours match, the clock does not.
//
// ## What this implementation does NOT claim
//
//   • It reads sessions, not epochs. A nap the stager never recorded is invisible here, exactly as it is
//     everywhere else in the app.
//   • It uses UTC-anchored absolute time. A wearer who crosses time zones inside the window has a
//     genuinely irregular 24-hour cycle by this measure — which is the correct answer for a circadian
//     statistic, even though it is not the answer a "did I keep my routine" question would want.
//   • Minute resolution. The published index uses one-minute bins; going finer measures the stager's
//     boundary noise rather than the wearer's rhythm.

public enum SleepRegularity {

    /// Minimum consecutive days before an index is reported. Each day contributes one 24-hour comparison,
    /// so a 7-day window yields 6 of them — below that, one unusual night dominates the answer.
    public static let minimumDays = 7

    /// Resolution of the state vector, in seconds. One minute, matching the published index.
    static let binSeconds = 60

    /// The Sleep Regularity Index over a window of sleep sessions, on the published −100…100 scale.
    ///
    /// - Parameters:
    ///   - sessions: sleep sessions as `(start, end)` unix seconds. Order does not matter; overlapping
    ///     sessions are handled by union, so a split night counts once rather than twice.
    ///   - windowDays: how many days back from the newest session to measure. Clamped to what the data
    ///     actually spans.
    /// - Returns: nil when the window holds fewer than `minimumDays` days of coverage.
    public static func index(sessions: [(start: Int, end: Int)], windowDays: Int = 14) -> Double? {
        let valid = sessions.filter { $0.end > $0.start }
        guard let newest = valid.map(\.end).max(), let oldest = valid.map(\.start).min() else { return nil }

        // Anchor the window on the last full day of data and walk back. Using the newest END rather than
        // "now" means a wearer who has not synced today still gets a reading over the days they did wear.
        let windowSeconds = windowDays * 86_400
        let start = max(oldest, newest - windowSeconds)
        let spannedDays = (newest - start) / 86_400
        guard spannedDays >= minimumDays else { return nil }

        // One bin per minute across the window, true when asleep. Built by marking session intervals
        // rather than by scanning sessions per bin, so cost is linear in the sessions, not their product.
        let binCount = (newest - start) / binSeconds
        guard binCount > 0 else { return nil }
        var asleep = [Bool](repeating: false, count: binCount)
        for session in valid {
            let from = max(session.start, start)
            let to = min(session.end, newest)
            guard to > from else { continue }
            let firstBin = (from - start) / binSeconds
            let lastBin = min((to - start) / binSeconds, binCount - 1)
            guard firstBin <= lastBin else { continue }
            for bin in firstBin...lastBin { asleep[bin] = true }
        }

        // Compare each bin with the bin exactly 24 h later.
        let dayBins = 86_400 / binSeconds
        guard binCount > dayBins else { return nil }
        var matches = 0
        for bin in 0..<(binCount - dayBins) where asleep[bin] == asleep[bin + dayBins] {
            matches += 1
        }
        let comparisons = binCount - dayBins
        let agreement = Double(matches) / Double(comparisons)
        return 100 * (2 * agreement - 1)
    }

    /// The same measure on the 0…1 scale `VitalityEngine.Inputs.sleepConsistency` expects, where 1 is
    /// perfectly regular.
    ///
    /// Negative SRI clamps to 0 rather than wrapping: a wearer whose rhythm is anti-correlated with
    /// itself is maximally irregular, and there is nothing below that worth distinguishing.
    public static func consistency(sessions: [(start: Int, end: Int)], windowDays: Int = 14) -> Double? {
        index(sessions: sessions, windowDays: windowDays).map { min(max($0 / 100, 0), 1) }
    }
}
