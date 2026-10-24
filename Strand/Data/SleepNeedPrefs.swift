import Foundation

/// A sleep need the wearer sets by hand, overriding the estimated one.
///
/// The estimate (`AnalyticsEngine.Rest.personalizedNeedHours`) is floored at the ~8 h adult target and
/// only ever adjusts up, so a wearer whose schedule cannot fit 8 h accrues debt every night with no way
/// to say so. This is that way. Stored in minutes; 0 (or absent) means "use the estimate".
enum SleepNeedPrefs {

    static let key = "noop.sleepNeed.userMinutes"

    /// The choices offered, in minutes: 6 h to 9 h in half-hour steps.
    static let choices: [Int] = Array(stride(from: 360, through: 540, by: 30))

    /// The wearer's chosen need in minutes, or nil when they have not set one. A stored value outside
    /// `choices`' range is ignored, so a corrupt default can never produce a zero or absurd need.
    static func userMinutes(_ defaults: UserDefaults = .standard) -> Double? {
        let stored = defaults.integer(forKey: key)
        guard let first = choices.first, let last = choices.last, (first...last).contains(stored) else { return nil }
        return Double(stored)
    }

    /// The need to measure against: the wearer's when set, otherwise `estimatedMinutes`.
    static func resolve(estimatedMinutes: Double, _ defaults: UserDefaults = .standard) -> Double {
        userMinutes(defaults) ?? estimatedMinutes
    }
}
