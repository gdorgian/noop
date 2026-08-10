import Foundation

/// When the wearer is normally AWAKE, as local hours — the one input the sleep detector's daytime
/// false-sleep guard (#90) and the selector's cold-start band (#547) both need.
///
/// ## Why this is a setting and not a constant
///
/// The guard exists because a long, still, sedentary stretch (a desk, a sofa) is gravity-
/// indistinguishable from a nap, so a window centred in the wearer's waking hours is held to a
/// stricter bar: long enough to be a real nap AND showing a genuine cardiac dip. That reasoning is
/// sound, but it is anchored to *when the wearer is awake*, which the code previously hardcoded to
/// 11:00–20:00 — a day-worker's schedule.
///
/// For a night-shift wearer the two bars are inverted: their real sleep sits in the middle of the
/// hardcoded band and is held to the strict bar, while their sedentary evening hours get the lax
/// one. Detection often survives (a real night dips well below baseline) but day attribution and the
/// cold-start midsleep anchor do not — upstream's anchor is 03:30, which penalises every one of
/// their nights.
///
/// ## The complement is structural
///
/// The detector's "overnight onset" window and the selector's cold-start band are, by definition,
/// the complement of the awake band — a fact #547 previously had to maintain by hand across two
/// pairs of constants (and had already drifted once, the [10:00, 11:00) off-by-one that release
/// notes record). Deriving all four from this one value makes them impossible to desynchronise.
///
/// ## Concurrency
///
/// `current` is set ONCE at launch from the app layer, before any analytics run, and read-only
/// thereafter. It is deliberately not an actor or a lock: the analytics package is pure and
/// synchronous by design, and every read is on the hot staging path.
public struct SleepSchedule: Equatable, Sendable {

    /// Local hour (inclusive) from which the wearer is normally awake.
    public let awakeStartHour: Int
    /// Local hour (exclusive) until which the wearer is normally awake. May be LESS than
    /// `awakeStartHour`, in which case the band wraps midnight — see `SleepStager.hourInBand`.
    public let awakeEndHour: Int

    /// Hours outside `0...23`, or a degenerate band where start == end, fall back to `.dayWorker`
    /// rather than silently producing an always-false (or always-true) band predicate.
    public init(awakeStartHour: Int, awakeEndHour: Int) {
        let valid = (0...23).contains(awakeStartHour)
            && (0...23).contains(awakeEndHour)
            && awakeStartHour != awakeEndHour
        self.awakeStartHour = valid ? awakeStartHour : 11
        self.awakeEndHour = valid ? awakeEndHour : 20
    }

    /// Upstream's shipped assumption: awake 11:00–20:00, so overnight is 20:00 → 11:00. Every
    /// constant derived from this reproduces the pre-setting values exactly.
    public static let dayWorker = SleepSchedule(awakeStartHour: 11, awakeEndHour: 20)

    /// The schedule the detector and selector currently read. Defaults to `.dayWorker`, so a host
    /// that never sets it behaves exactly as before.
    public static var current: SleepSchedule = .dayWorker

    /// The wearer's SLEEP window — the complement of the awake band, as `[start, end)` local hours.
    /// This is what the cold-start overnight band and the detector's overnight-onset test use.
    public var sleepWindow: (startHour: Int, endHour: Int) { (awakeEndHour, awakeStartHour) }
}
