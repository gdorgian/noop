import Foundation
import WhoopProtocol

// WakeWindow.swift — the light-sleep EARLY-WAKE sweep (the "smart wake window").
//
// This is a behaviour COPY, not an accuracy port: WHOOP's strap decides "light sleep" with its own
// onboard accelerometer + HR features, which are not observable from the app side and were not
// decompiled. Nothing here is a WHOOP constant. What IS copied is the SHAPE of the feature: in a
// short window that ends at the wake time, a gentle buzz may pull the wearer up early instead of the
// full-strength firmware alarm at the wake moment.
//
// Honest input limits: the sweep runs IN APP, and it sees only the banked HR stream. So it fires on
// a wakeable-looking HR pattern, not on a measured sleep stage, and it only runs while the app is
// alive (macOS runs reliably; iOS checks while foregrounded/the sweep timer is alive). The FIRMWARE
// alarm stays armed at the full wake time — the window can only move waking EARLIER, never later,
// and the strap still owns the final minute (policy never fires inside it, so the last-minute
// firmware buzz is never doubled).
//
// Every numeric rule below is TRIAL-TUNABLE and marked as such; nothing was extracted from a binary.

enum WakeWindow {

    // MARK: bounds

    static let minWindowMinutes = 5
    static let maxWindowMinutes = 90
    /// Never fire within this many seconds of the wake time: the strap's own firmware alarm owns the
    /// final minute, and an app buzz there would double-hit.
    static let firmwareHandoverSeconds: TimeInterval = 60
    /// How much history the sweep reads (seconds). One store read per tick; the OLD portion is the
    /// overnight floor, the NEW portion is the window being judged.
    static let lookbackSeconds: TimeInterval = 3_600
    /// The NEW window's length (seconds) — recent behaviour this minute is judged against the floor.
    static let recentSeconds: TimeInterval = 900

    // MARK: trial-tunable rules (NOT WHOOP constants — the trial tunes these)

    /// Recent floor above the overnight floor by this much ⇒ restless/light/awake pattern.
    static let restlessElevationBpm = 3.0
    /// Recent HR rising at this rate (bpm per 10 min) ⇒ waking up anyway.
    static let risingBpmPer10Min = 1.5
    /// Recent HR jitter at least this much (bpm, years-style stddev) ⇒ light/fragmenting sleep.
    static let restlessStdDevBpm = 3.0
    /// Inside the last stretch of the window the sweep fires regardless of pattern — a still-deep
    /// sleeper gets pulled up gently by the ramp rather than abruptly by the firmware alarm.
    static let rampSeconds: TimeInterval = 600
    /// Enough data to judge: at 1 Hz 240 samples is four minutes; at a sparse cadence, enough
    /// to still carry a floor. Below it the sweep stays silent rather than buzz a guess.
    static let minSamples = 20
    static let minSpanSeconds: TimeInterval = 240

    // MARK: decision

    struct Decision: Equatable {
        let fire: Bool
        /// Haptic loop count of the gentle buzz (1 early / 2 on the ramp). 0 when not firing.
        let buzzLoops: Int
        let reason: String
    }

    /// Pure, side-effect-free, unit-tested. `recent` may be EMPTY or nil-spanning — every data
    /// shortfall is a no-fire with its reason named, never a buzz guessed.
    static func evaluate(now: Date, wake: Date, windowMinutes: Int, recent: [HRSample]) -> Decision {
        let windowSeconds = TimeInterval(min(max(windowMinutes, minWindowMinutes), maxWindowMinutes) * 60)
        let remaining = wake.timeIntervalSince(now)
        // Outside the window (strictly before its start) — nothing to decide today, keep waiting.
        // +1 s of slack absorbs timer-ticking jitter so "60 s window" never skips its own last tick.
        if remaining > windowSeconds + 1 {
            return Decision(fire: false, buzzLoops: 0, reason: "before window")
        }
        // Past the hand-over point: the strap's firmware alarm is the nearer wake now.
        if remaining <= firmwareHandoverSeconds {
            return Decision(fire: false, buzzLoops: 0, reason: "inside firmware handover")
        }
        // The window's judged slice: samples within `recentSeconds` of NOW.
        let nowS = Int(now.timeIntervalSince1970)
        let recentOnly = recent.filter { $0.ts > nowS - Int(recentSeconds) }
        guard recentOnly.count >= minSamples,
              let firstTs = recentOnly.first?.ts,
              Double(nowS - firstTs) >= minSpanSeconds else {
            return Decision(fire: false, buzzLoops: 0, reason: "insufficient recent HR data")
        }
        let bpm = recentOnly.map { Double($0.bpm) }.sorted()
        let recentFloor = mean(Array(bpm.prefix(bpm.count / 3)))
        // The overnight floor rests in the history OLDER than the recent window.
        let older = recent.filter { $0.ts <= nowS - Int(recentSeconds) }.map { Double($0.bpm) }.sorted()
        let overnightFloor = older.isEmpty ? recentFloor : mean(Array(older.prefix(older.count / 3)))
        let elevation = recentFloor - overnightFloor
        // Slope over the recent window, bpm per 10 minutes (time-ordered thirds).
        let ordered = recentOnly.sorted { $0.ts < $1.ts }
        let leading = ordered.prefix(ordered.count / 3).map { Double($0.bpm) }
        let trailing = ordered.suffix(ordered.count / 3).map { Double($0.bpm) }
        let spanMin = max(Double(nowS - firstTs) / 60.0, 1)
        let slope = (mean(trailing) - mean(leading)) / spanMin * 10.0
        let meanBpm = mean(bpm)
        let stdDev = (bpm.map { ($0 - meanBpm) * ($0 - meanBpm) }.reduce(0, +) / Double(bpm.count)).squareRoot()

        let restless = elevation >= restlessElevationBpm
            || slope >= risingBpmPer10Min
            || stdDev >= restlessStdDevBpm
        if restless {
            return Decision(fire: true, buzzLoops: 1, reason: String(format: "wakeable HR pattern (floor +%.1f bpm, slope %+.1f bpm/10min, sd %.1f)", elevation, slope, stdDev))
        }
        // Ramp: at the window's end even a still-deep pattern gets its gentle pull.
        if remaining <= rampSeconds {
            return Decision(fire: true, buzzLoops: 2, reason: String(format: "ramp (still %.1f min to wake, floor +%.1f bpm, sd %.1f)", remaining / 60, elevation, stdDev))
        }
        return Decision(fire: false, buzzLoops: 0, reason: String(format: "stable deep-looking pattern (floor +%.1f bpm, slope %+.1f, sd %.1f)", elevation, slope, stdDev))
    }

    private static func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
}
