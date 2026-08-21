import XCTest
import WhoopProtocol
@testable import WhoopStore

final class WhoopRRTransportSelectionTests: XCTestCase {
    private let base = 1_750_000_000

    func testPureSelectorSuppressesLiveOnlyNearObservedHistoryAndPreservesInternalGap() {
        let rows = [
            RRInterval(ts: base - 3, rrMs: 810, srcChannel: .whoopStandardBLE), // before: keep
            RRInterval(ts: base - 2, rrMs: 811, srcChannel: .whoopStandardBLE), // tolerance: drop
            RRInterval(ts: base, rrMs: 812, srcChannel: .whoopHistorical),
            RRInterval(ts: base + 1, rrMs: 813, srcChannel: .whoopRealtime),    // local overlap: drop
            RRInterval(ts: base + 5, rrMs: 814, srcChannel: .whoopRealtime),    // internal gap: keep
            RRInterval(ts: base + 10, rrMs: 819, srcChannel: .whoopHistorical),
            RRInterval(ts: base + 12, rrMs: 815, srcChannel: .whoopStandardBLE), // tolerance: drop
            RRInterval(ts: base + 13, rrMs: 816, srcChannel: .whoopRealtime),   // after: keep
        ]

        let selected = RRScoringTransportSelector.select(rows)
        XCTAssertEqual(selected.map(\.rrMs), [810, 812, 814, 819, 816])
        XCTAssertEqual(selected.map(\.srcChannel), [
            .whoopStandardBLE, .whoopHistorical, .whoopRealtime,
            .whoopHistorical, .whoopRealtime,
        ])
    }

    func testPureSelectorFallsBackToLiveTransportsWhenHistoryIsAbsent() {
        let rows = [
            RRInterval(ts: base, rrMs: 800, srcChannel: .whoopStandardBLE),
            RRInterval(ts: base + 1, rrMs: 810, srcChannel: .whoopRealtime),
        ]
        XCTAssertEqual(RRScoringTransportSelector.select(rows), rows)
    }

    func testStorePrefersLocalHistoryAndKeepsLiveBeforeInternalGapAndAfter() async throws {
        let store = try await WhoopStore.inMemory()
        try await store.upsertDevice(id: "whoop", mac: nil, name: nil)
        let rows = [
            RRInterval(ts: base - 3, rrMs: 790, srcChannel: .whoopStandardBLE),
            RRInterval(ts: base, rrMs: 800, srcChannel: .whoopHistorical),
            RRInterval(ts: base + 1, rrMs: 801, srcChannel: .whoopStandardBLE),
            RRInterval(ts: base + 5, rrMs: 805, srcChannel: .whoopRealtime),
            RRInterval(ts: base + 10, rrMs: 810, srcChannel: .whoopHistorical),
            RRInterval(ts: base + 12, rrMs: 812, srcChannel: .whoopStandardBLE),
            RRInterval(ts: base + 13, rrMs: 813, srcChannel: .whoopRealtime),
        ]
        _ = try await store.insert(Streams(rr: rows), deviceId: "whoop")

        let stored = try await store.rrRowsWithChannelForTest(deviceId: "whoop")
        XCTAssertEqual(stored.count, rows.count, "selection must never delete either transport")

        let scored = try await store.rrIntervals(
            deviceId: "whoop", from: base - 10, to: base + 20, limit: 100)
        XCTAssertEqual(scored.map(\.rrMs), [790, 800, 805, 810, 813])
        XCTAssertEqual(scored.map(\.srcChannel), [
            .whoopStandardBLE, .whoopHistorical, .whoopRealtime,
            .whoopHistorical, .whoopRealtime,
        ])
    }

    func testStoreUsesLiveTransportsWhenNoHistoricalRowsExist() async throws {
        let store = try await WhoopStore.inMemory()
        try await store.upsertDevice(id: "whoop", mac: nil, name: nil)
        let rows = [
            RRInterval(ts: base, rrMs: 800, srcChannel: .whoopStandardBLE),
            RRInterval(ts: base + 1, rrMs: 810, srcChannel: .whoopRealtime),
        ]
        _ = try await store.insert(Streams(rr: rows), deviceId: "whoop")
        let scored = try await store.rrIntervals(
            deviceId: "whoop", from: base - 1, to: base + 2, limit: 100)
        // Compare the fields this test is about. Upstream widened the read to round-trip `ord` (#1008
        // diagnostics), so a whole-struct compare against hand-built rows now trips on the stored default.
        XCTAssertEqual(scored.map(\.ts), rows.map(\.ts))
        XCTAssertEqual(scored.map(\.rrMs), rows.map(\.rrMs))
        XCTAssertEqual(scored.map(\.srcChannel), rows.map(\.srcChannel))
    }

    func testSeparateBatchExactLiveCollisionPromotesToHistoryAndAdoptsHistoricalOrder() async throws {
        for (offset, liveSource) in [RRSourceChannel.whoopStandardBLE, .whoopRealtime].enumerated() {
            let device = "whoop-collision-\(offset)"
            let ts = base + offset
            let store = try await WhoopStore.inMemory()
            try await store.upsertDevice(id: device, mac: nil, name: nil)

            _ = try await store.insert(Streams(rr: [
                RRInterval(ts: ts, rrMs: 800, srcChannel: liveSource),
            ]), deviceId: device)
            let promoted = try await store.insert(Streams(rr: [
                RRInterval(ts: ts, rrMs: 810, srcChannel: .whoopHistorical),
                RRInterval(ts: ts, rrMs: 800, srcChannel: .whoopHistorical),
            ]), deviceId: device)

            XCTAssertEqual(promoted.rr, 2, "one history insert + one provenance promotion are writes")
            let stored = try await store.rrRowsWithChannelForTest(deviceId: device)
            XCTAssertEqual(stored.map(\.rrMs), [810, 800], "the collided row adopts historical ord")
            XCTAssertEqual(stored.map(\.srcChannel), [
                RRSourceChannel.whoopHistorical.rawValue,
                RRSourceChannel.whoopHistorical.rawValue,
            ])

            // A later live replay neither demotes history nor changes its historical emission order.
            let replay = try await store.insert(Streams(rr: [
                RRInterval(ts: ts, rrMs: 800, srcChannel: liveSource),
            ]), deviceId: device)
            XCTAssertEqual(replay.rr, 0)
            let ords = try await store.rrOrdValuesForTest(deviceId: device, ts: ts)
            XCTAssertEqual(ords, [0, 1])
            let scored = try await store.rrIntervals(deviceId: device, from: ts, to: ts, limit: 10)
            XCTAssertEqual(scored.map(\.rrMs), [810, 800])
            XCTAssertEqual(Set(scored.compactMap(\.srcChannel)), [.whoopHistorical])
        }
    }

    func testConflictPromotionDoesNotRelabelOuraOrLegacyRows() async throws {
        let store = try await WhoopStore.inMemory()
        try await store.upsertDevice(id: "non-whoop-conflicts", mac: nil, name: nil)
        _ = try await store.insert(Streams(rr: [
            RRInterval(ts: base, rrMs: 800, srcChannel: .greenQuality),
            RRInterval(ts: base + 1, rrMs: 801),
        ]), deviceId: "non-whoop-conflicts")
        _ = try await store.insert(Streams(rr: [
            RRInterval(ts: base, rrMs: 800, srcChannel: .whoopHistorical),
            RRInterval(ts: base + 1, rrMs: 801, srcChannel: .whoopHistorical),
        ]), deviceId: "non-whoop-conflicts")

        let stored = try await store.rrRowsWithChannelForTest(deviceId: "non-whoop-conflicts")
        XCTAssertEqual(stored.map(\.srcChannel), [RRSourceChannel.greenQuality.rawValue, nil])
    }

    func testOuraAndLegacyRowsAreUnaffectedByWhoopEnvelope() async throws {
        let store = try await WhoopStore.inMemory()
        try await store.upsertDevice(id: "mixed-fixture", mac: nil, name: nil)
        let rows = [
            RRInterval(ts: base, rrMs: 800, srcChannel: .whoopHistorical),
            RRInterval(ts: base + 1, rrMs: 801),
            RRInterval(ts: base + 2, rrMs: 802, srcChannel: .greenQuality),
            RRInterval(ts: base + 3, rrMs: 803, srcChannel: .ibiAmplitude),
            RRInterval(ts: base + 4, rrMs: 804, srcChannel: .spo2Ibi),
        ]
        _ = try await store.insert(Streams(rr: rows), deviceId: "mixed-fixture")
        let scored = try await store.rrIntervals(
            deviceId: "mixed-fixture", from: base, to: base + 10, limit: 100)

        XCTAssertEqual(scored.map(\.rrMs), [800, 801, 802, 803])
        XCTAssertEqual(scored.map(\.srcChannel), [
            .whoopHistorical, nil, .greenQuality, .ibiAmplitude,
        ])
    }
}
