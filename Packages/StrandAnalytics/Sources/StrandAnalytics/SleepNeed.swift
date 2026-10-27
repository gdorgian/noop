import Foundation

// SleepNeed.swift — TONIGHT'S sleep need by WHOOP's STRUCTURE, with NOOP's own baseline.
//
// This is a BEHAVIOUR COPY, not an accuracy port: WHOOP's own baseline weights, its strain curve and
// its night-share debt term were not decompiled, so every numeric weight below is a TRIAL-TUNABLE
// estimate and marked as such. What IS copied is the SHAPE (WHOOP iOS 5.65.1's sleep-need pipeline):
//
//     tonightNeed = baselineNeed            // personalized, #242 need (SleepModel.debtNeedMin)
//                 + strainAddOn             // yesterday's effort raises tonight's need
//                 + repayment               // what the debt ledger already says is still owed
//                 − napCredit               // naps banked today, before tonight's scoring pass
//
// The OWNER-SETTLED data-flow rule (one-way, ledger → target):
//   * `SleepDebt.ledger` keeps measuring against `debtNeedMin`'s BASELINE — no strain term, no debt
//     term — so the ledger can never measure itself. `SleepDebt` already folds its 55 % carry into
//     the running balance, so `repayment` reads the ledger's existing estimate at full share (a
//     SECOND carry on top would double-count; that is why `repaymentShare` is 1.0 and the cap, not
//     a re-carry, is what bounds it).
//   * The strain add-on never enters the ledger either — "one need across every debt surface".
//   * `napCredit` covers ONLY naps not yet in the ledger (today's, before tonight's scoring pass);
//     naps AFTER the pass are already sleep-obtained inside `SleepDebt.creditedSleepMin`, so
//     subtracting those here would count them twice.
//   * Nothing downstream reads tonightNeed back into `SleepDebt`, `personalizedNeedHours` or Rest
//     scoring. It is a derived, display-only value.
//
// The pinning invariant the tests hold: with sleep fixed, raising yesterday's strain changes
// tonightNeed by exactly the add-on and leaves the ledger untouched.
public enum SleepNeed {

    // MARK: - Trial-tunable weights (NOT WHOOP constants — the trial tunes these)

    /// Effort (0–100 axis, the stored `DailyMetric.strain`) below which yesterday earns no add-on:
    /// quiet days must not move tonight's need.
    public static let strainAddOnFloorEffort = 30.0
    /// The add-on at FULL effort (100 on the 0–100 axis). Linear ramp between floor and 100, capped
    /// here; WHOOP's real curve is proprietary and likely non-linear — the trial reshapes it.
    public static let strainAddOnCapMinutes = 60.0
    /// Share of the ledger's actionable debt `repayment` carries into tonight. 1.0 = the balance
    /// exactly as the ledger computed it (its own 55 % night-carry already happened inside the
    /// ledger) — NOT a second, stacked compounding.
    public static let repaymentShare = 1.0
    /// Cap the repayment term so one heavy debt asks for a longer night, never an absurd one
    /// (WHOOP's Sleep Coach similarly bounds its recommendation).
    public static let maxRepaymentMinutes = 120.0

    // MARK: - The recipe

    /// One night's tonight-need read-out, piecewise so a surface can name its parts.
    public struct Tonight: Equatable, Sendable {
        /// The personalized baseline this night is computed from (minutes) — `debtNeedMin`.
        public let baseMin: Double
        /// Yesterday's-effort add-on (minutes).
        public let strainAddOnMin: Double
        /// The debt ledger's still-owed estimate, carried into tonight (minutes).
        public let repaymentMin: Double
        /// Today's not-yet-ledgered naps (minutes) — reduces what the night still owes.
        public let napCreditMin: Double
        /// The display number: `max(0, base + addOn + repayment − napCredit)`.
        public var totalMin: Double {
            max(0, baseMin + strainAddOnMin + repaymentMin - napCreditMin)
        }

        public init(baseMin: Double, strainAddOnMin: Double, repaymentMin: Double, napCreditMin: Double) {
            self.baseMin = baseMin
            self.strainAddOnMin = strainAddOnMin
            self.repaymentMin = repaymentMin
            self.napCreditMin = napCreditMin
        }
    }

    /// The add-on one night of effort (0–100 stored Effort axis) demands of tonight's sleep.
    /// Linear between `strainAddOnFloorEffort` (zero) and full effort (the cap); nil strain (no
    /// readable effort for yesterday) earns nothing — never guess a need from missing data.
    public static func strainAddOn(strain: Double?) -> Double {
        guard let strain else { return 0 }
        let clamped = min(max(strain, strainAddOnFloorEffort), 100.0)
        let share = (clamped - strainAddOnFloorEffort) / (100.0 - strainAddOnFloorEffort)
        return share * strainAddOnCapMinutes
    }

    /// The full recipe. `debtBalanceMin` is the LEDGER's signed balance (negative = debt, per the
    /// ledger's own convention); a positive balance (surplus, which the ledger never reports) is
    /// treated as zero repayment, never as a reduced need.
    public static func tonight(baseMinutes: Double,
                               strain: Double?,
                               ledgerDebtBalanceMin: Double?,
                               napMinutesNotInLedger: Double = 0) -> Tonight {
        let debt = ledgerDebtBalanceMin ?? 0
        let owed = debt < 0 ? -debt : 0
        let repayment = min(owed * repaymentShare, maxRepaymentMinutes)
        let nap = max(napMinutesNotInLedger, 0)
        return Tonight(baseMin: baseMinutes,
                       strainAddOnMin: strainAddOn(strain: strain),
                       repaymentMin: repayment,
                       napCreditMin: nap)
    }
}
