import XCTest
@testable import StrandAnalytics

/// SleepNeed — TONIGHT'S sleep need (WHOOP's STRUCTURE, NOOP's baseline, trial-tunable weights).
///
/// The owner-settled data-flow rule these tests pin: the DEBT ledger keeps measuring against the
/// `#242` baseline only; tonight's need is a one-way derivative of the ledger (never an input to
/// `SleepDebt`, `personalizedNeedHours` or Rest scoring). The headline invariant: hold sleep fixed
/// and raise yesterday's strain — the ledger is unchanged and tonight's need rises by EXACTLY the
/// add-on (owner's words, pinned as tests).
final class SleepNeedTests: XCTestCase {

    // MARK: strain add-on

    func testStrainAddOnRampsAboveTheFloorOnly() {
        XCTAssertEqual(SleepNeed.strainAddOn(strain: nil), 0)        // no data → no guess
        XCTAssertEqual(SleepNeed.strainAddOn(strain: 10), 0)         // clamped at the floor
        XCTAssertEqual(SleepNeed.strainAddOn(strain: 30), 0)         // AT the floor: still zero
        XCTAssertEqual(SleepNeed.strainAddOn(strain: 65),
                       SleepNeed.strainAddOnCapMinutes * (65.0 - 30.0) / 70.0, accuracy: 1e-12)
        XCTAssertEqual(SleepNeed.strainAddOn(strain: 100), SleepNeed.strainAddOnCapMinutes)
        XCTAssertEqual(SleepNeed.strainAddOn(strain: 400), SleepNeed.strainAddOnCapMinutes, "clamped from above too")
    }

    // MARK: repayment reads the ledger's balance, never re-carries it

    func testRepaymentIsTheLedgerBalanceAtFullShareAndCapped() {
        // Balance −90 → 90 owed, uncapped share of 1.0 → 90.
        let t = SleepNeed.tonight(baseMinutes: 480, strain: 65, ledgerDebtBalanceMin: -90)
        XCTAssertEqual(t.repaymentMin, 90, accuracy: 1e-12)
        // A heavy balance is CAPPED, not compounded: −300 → 120, NOT 300.
        XCTAssertEqual(SleepNeed.tonight(baseMinutes: 480, strain: 65, ledgerDebtBalanceMin: -300)
            .repaymentMin, SleepNeed.maxRepaymentMinutes, accuracy: 1e-12)
        // The ledger never reports a surplus, but a positive balance still owes nothing —
        // and must never REDUCE the need (that would move the reference).
        XCTAssertEqual(SleepNeed.tonight(baseMinutes: 480, strain: 65, ledgerDebtBalanceMin: 40)
            .repaymentMin, 0, accuracy: 1e-12)
        XCTAssertEqual(SleepNeed.tonight(baseMinutes: 480, strain: 65, ledgerDebtBalanceMin: nil)
            .repaymentMin, 0, accuracy: 1e-12, "nil ledger (unscored) owes nothing")
    }

    // MARK: the owner's pinning invariant

    func testRaisingStrainLeavesRepaymentUntouchedAndMovesOnlyTheAddOn() {
        // Sleep and ledger fixed, yesterday's effort 30 → 100: repayment identical, total rises
        // by exactly the add-on (60 − 0).
        let quiet = SleepNeed.tonight(baseMinutes: 480, strain: 30, ledgerDebtBalanceMin: -90, napMinutesNotInLedger: 15)
        let hard = SleepNeed.tonight(baseMinutes: 480, strain: 100, ledgerDebtBalanceMin: -90, napMinutesNotInLedger: 15)
        XCTAssertEqual(hard.repaymentMin, quiet.repaymentMin, accuracy: 1e-12)
        XCTAssertEqual(hard.totalMin - quiet.totalMin,
                       SleepNeed.strainAddOn(strain: 100) - SleepNeed.strainAddOn(strain: 30), accuracy: 1e-12)
        XCTAssertEqual(hard.strainAddOnMin, SleepNeed.strainAddOnCapMinutes, accuracy: 1e-12)
        XCTAssertEqual(quiet.strainAddOnMin, 0, accuracy: 1e-12)
    }

    // MARK: nap credit covers only the not-yet-ledgered naps

    func testTotalSubtractsNapCreditAndFloorsAtZero() {
        // 480 base + 30 add-on + 90 repayment − 20 naps = 580.
        XCTAssertEqual(SleepNeed.tonight(baseMinutes: 480, strain: 65, ledgerDebtBalanceMin: -90,
                                         napMinutesNotInLedger: 20).totalMin, 580, accuracy: 1e-12)
        // Naps can't push the number negative: an absurd nap total floors at 0 (never −minutes).
        // nap > the whole need still leaves the wearer owed THE NIGHT's remainder at zero,
        // which honestly reads ahead of a negative.
        XCTAssertEqual(SleepNeed.tonight(baseMinutes: 480, strain: 30, ledgerDebtBalanceMin: 0,
                                         napMinutesNotInLedger: 900).totalMin, 0, accuracy: 1e-12)
        // A malformed negative nap total is ignored, like `SleepDebt.creditedSleepMin` does.
        XCTAssertEqual(SleepNeed.tonight(baseMinutes: 480, strain: 30, ledgerDebtBalanceMin: 0,
                                         napMinutesNotInLedger: -5).napCreditMin, 0, accuracy: 1e-12)
    }
}
