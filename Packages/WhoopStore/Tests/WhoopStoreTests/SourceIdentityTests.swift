import XCTest
@testable import WhoopStore

/// Which device a live link's samples belong to (#1881) — the twin of the Kotlin `SourceIdentityTest`,
/// asserting the same inputs and the same answers so the two platforms cannot drift.
///
/// The reported failure is the first case here: with an Oura ring active and a WHOOP merely paired, a
/// WHOOP connection filed 770 `stepSample` and 770 `gravitySample` rows under the ring's id. A ring has no
/// pedometer and no accelerometer, so 100% of those rows were misattributed — and because `hrSample` is
/// written by both paths under one id, contamination there cannot be separated after the fact.
final class SourceIdentityTests: XCTestCase {

    private func row(_ id: String, _ brand: String, _ peripheralId: String?) -> PairedDevice {
        PairedDevice(id: id, brand: brand, model: "m", peripheralId: peripheralId,
                     sourceKind: .liveBLE, capabilities: [.hr], status: .paired,
                     addedAt: 0, lastSeenAt: 0)
    }

    private lazy var ring = row("oura-abc", "Oura", "AA:BB:CC:DD:EE:01")
    private lazy var strap = row("whoop-123", "WHOOP", "AA:BB:CC:DD:EE:02")

    /// The reported bug: the ring is active, the STRAP connected, so the strap's id must win.
    func testStrapConnectingWhileRingActiveIsAttributedToTheStrap() {
        XCTAssertEqual(SourceIdentity.resolve(address: "AA:BB:CC:DD:EE:02",
                                              rows: [ring, strap], currentId: "oura-abc"), "whoop-123")
    }

    /// The legacy single-WHOOP path, and the reason this returns nil rather than guessing: the seeded row
    /// has not adopted an address yet. The coordinator adopts one on this same connect, so the NEXT connect
    /// resolves — and until then the id stays exactly what it is today.
    func testUnadoptedRowLeavesTheIdAlone() {
        let legacy = row("my-whoop", "WHOOP", nil)
        XCTAssertNil(SourceIdentity.resolve(address: "AA:BB:CC:DD:EE:02",
                                            rows: [legacy], currentId: "my-whoop"))
    }

    /// No row carries this address — an unknown strap must never claim an existing device's id.
    func testUnknownAddressLeavesTheIdAlone() {
        XCTAssertNil(SourceIdentity.resolve(address: "FF:FF:FF:FF:FF:FF",
                                            rows: [ring, strap], currentId: "oura-abc"))
    }

    /// The inverse of the bug. If a non-WHOOP row somehow matches, re-pointing the WHOOP path's id at it
    /// would file strap samples under a ring — exactly what #1881 reports, arrived at from the other side.
    func testNonWhoopMatchNeverClaimsTheStrapsSamples() {
        XCTAssertNil(SourceIdentity.resolve(address: "AA:BB:CC:DD:EE:01",
                                            rows: [ring, strap], currentId: "whoop-123"))
    }

    /// Already correct — the common path — must not write.
    func testIdAlreadyCorrectResolvesToNothing() {
        XCTAssertNil(SourceIdentity.resolve(address: "AA:BB:CC:DD:EE:02",
                                            rows: [ring, strap], currentId: "whoop-123"))
    }

    /// Neither OS guarantees the case of a UUID string or a MAC, and old rows may carry either.
    func testAddressMatchingIsCaseInsensitive() {
        XCTAssertEqual(SourceIdentity.resolve(address: "aa:bb:cc:dd:ee:02",
                                              rows: [ring, strap], currentId: "oura-abc"), "whoop-123")
    }

    /// A blank address is a missing address, not a wildcard that matches a blank stored value.
    func testBlankAddressLeavesTheIdAlone() {
        let blank = row("whoop-blank", "WHOOP", "")
        XCTAssertNil(SourceIdentity.resolve(address: "", rows: [blank], currentId: "oura-abc"))
        XCTAssertNil(SourceIdentity.resolve(address: nil, rows: [blank], currentId: "oura-abc"))
        // Whitespace is blank on both platforms — Kotlin's `isNullOrBlank` set the contract.
        let spaces = row("whoop-spaces", "WHOOP", "   ")
        XCTAssertNil(SourceIdentity.resolve(address: "   ", rows: [spaces], currentId: "oura-abc"))
    }

    /// The legacy id is a WHOOP by id even though its brand was never guaranteed.
    func testLegacyRowCountsAsWhoop() {
        let legacy = row("my-whoop", "", "AA:BB:CC:DD:EE:03")
        XCTAssertEqual(SourceIdentity.resolve(address: "AA:BB:CC:DD:EE:03",
                                              rows: [legacy], currentId: "oura-abc"), "my-whoop")
    }

    // MARK: allWhoopsForgotten

    private func with(_ device: PairedDevice, _ status: DeviceStatus) -> PairedDevice {
        var copy = device; copy.status = status; return copy
    }

    /// The reported bug: the strap was forgotten (archived) and nothing replaced it. Launch must not
    /// re-adopt it under the "my-whoop" fallback.
    func testEveryWhoopArchivedAndNothingActiveIsForgotten() {
        let legacy = with(row("my-whoop", "WHOOP", nil), .archived)
        let health = row("apple-health", "Apple", nil)
        XCTAssertTrue(SourceIdentity.allWhoopsForgotten([legacy, with(strap, .archived), health]))
    }

    /// Another WHOOP still paired → the user hasn't released the strap; keep today's behaviour.
    func testOnePairedWhoopIsNotForgotten() {
        XCTAssertFalse(SourceIdentity.allWhoopsForgotten([with(row("my-whoop", "WHOOP", nil), .archived), strap]))
    }

    /// Something active (a re-paired strap, or a ring) → the normal gate decides, not this.
    func testAnActiveDeviceIsNeverForgotten() {
        XCTAssertFalse(SourceIdentity.allWhoopsForgotten([with(strap, .archived), with(ring, .active)]))
    }

    /// No WHOOP rows at all (a ring-only or empty registry) is not "forgotten".
    func testNoWhoopRowsIsNotForgotten() {
        XCTAssertFalse(SourceIdentity.allWhoopsForgotten([]))
        XCTAssertFalse(SourceIdentity.allWhoopsForgotten([ring]))
    }
}
