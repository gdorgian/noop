import XCTest

final class WidgetSnapshotTests: XCTestCase {
    func testAltStoreProvisionedGroupWinsOverBuildTimeIdentifier() {
        let configured = "group.com.noopapp.noop.staging"
        let remapped = configured + ".TEAM123456"

        XCTAssertEqual(
            WidgetSnapshot.resolveSuiteName(infoDictionary: [
                "AppGroupIdentifier": configured,
                "ALTAppGroups": [remapped]
            ]),
            remapped
        )
    }

    func testXcodeBuildFallsBackToConfiguredGroup() {
        XCTAssertEqual(
            WidgetSnapshot.resolveSuiteName(infoDictionary: [
                "AppGroupIdentifier": "group.example.noop"
            ]),
            "group.example.noop"
        )
    }

    func testUnrelatedAltStoreGroupsDoNotOverrideConfiguredGroup() {
        XCTAssertEqual(
            WidgetSnapshot.resolveSuiteName(infoDictionary: [
                "AppGroupIdentifier": "group.example.noop",
                "ALTAppGroups": [
                    "group.example.first",
                    "group.example.second"
                ]
            ]),
            "group.example.noop"
        )
    }

    func testSingleProvisionedGroupIsUsableWithoutConfiguredIdentifier() {
        XCTAssertEqual(
            WidgetSnapshot.resolveSuiteName(infoDictionary: [
                "ALTAppGroups": ["group.example.noop.TEAM123456"]
            ]),
            "group.example.noop.TEAM123456"
        )
    }

    func testSideStoreProfileWorksWithoutAltAppGroupsMetadata() throws {
        let groups = ["group.example.noop.TEAM123456"]
        let plist: [String: Any] = ["Entitlements": ["com.apple.security.application-groups": groups]]
        var cms = Data([0x30, 0x82, 0x00, 0x00])
        cms.append(try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0))
        cms.append(Data([0x00, 0xFF]))
        let extracted = WidgetSnapshot.applicationGroups(inProfile: cms)
        XCTAssertEqual(extracted, groups)
        XCTAssertEqual(WidgetSnapshot.resolveSuiteName(
            infoDictionary: ["AppGroupIdentifier": "group.example.noop"], provisionedGroups: extracted
        ), groups[0])
    }

    func testProfileWinsOverStaleAltStoreMetadata() {
        XCTAssertEqual(WidgetSnapshot.resolveSuiteName(
            infoDictionary: ["AppGroupIdentifier": "group.example.noop",
                             "ALTAppGroups": ["group.example.noop.OLDTEAM"]],
            provisionedGroups: ["group.example.noop.NEWTEAM"]
        ), "group.example.noop.NEWTEAM")
    }

    func testHostAndWidgetSelectSameGroupWithDifferentProfileOrdering() {
        let shared = "group.example.noop.TEAM123456"
        let info: [String: Any] = ["AppGroupIdentifier": "group.example.noop"]
        XCTAssertEqual(WidgetSnapshot.resolveSuiteName(infoDictionary: info,
            provisionedGroups: ["group.other.service", shared]), shared)
        XCTAssertEqual(WidgetSnapshot.resolveSuiteName(infoDictionary: info,
            provisionedGroups: [shared]), shared)
    }

    func testProfilePrefersExactGroupOverPrefixMatches() {
        XCTAssertEqual(WidgetSnapshot.resolveSuiteName(
            infoDictionary: ["AppGroupIdentifier": "group.example.noop"],
            provisionedGroups: ["group.example.noop.TEAM", "group.example.noop"]
        ), "group.example.noop")
    }

    func testAmbiguousProfileDoesNotTrustStaleSignerMetadata() {
        XCTAssertEqual(WidgetSnapshot.resolveSuiteName(
            infoDictionary: ["AppGroupIdentifier": "group.example.noop",
                             "ALTAppGroups": ["group.example.noop.OLDTEAM"]],
            provisionedGroups: ["group.example.noop.TEAM1", "group.example.noop.TEAM2"]
        ), "group.example.noop")
    }

    func testMissingOrMalformedProfilePreservesMetadataFallback() {
        XCTAssertNil(WidgetSnapshot.applicationGroups(inProfile: nil))
        XCTAssertNil(WidgetSnapshot.applicationGroups(inProfile: Data("not a profile".utf8)))
        XCTAssertNil(WidgetSnapshot.applicationGroups(inProfile: Data("<?xml broken </plist>".utf8)))
    }

    func testRuntimeUnavailableSnapshotContainsNoDemoValues() {
        let snapshot = WidgetSnapshot.unavailable

        XCTAssertNil(snapshot.recovery)
        XCTAssertNil(snapshot.bpm)
        XCTAssertNil(snapshot.batteryPct)
        XCTAssertFalse(snapshot.bonded)
    }

    func testLegacyRecoveryIsMaskedWithoutErasingOtherWidgetMeasurements() throws {
        // This is the old on-disk shape: `recovery` held morning Recovery while the widget called it
        // Charge. Upgrading must not display the number, but must preserve the independent fields.
        let legacy = """
        {"recovery":72,"bpm":58,"batteryPct":84,"bonded":true,"updated":0,
         "effort":38,"rest":81,"hrv":64,"restingHr":52}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: legacy)
        let display = decoded.verifiedForDisplay()

        XCTAssertNil(display.recovery)
        XCTAssertEqual(display.bpm, 58)
        XCTAssertEqual(display.batteryPct, 84)
        XCTAssertEqual(display.effort, 38)
        XCTAssertEqual(display.rest, 81)
        XCTAssertEqual(display.hrv, 64)
        XCTAssertEqual(display.restingHr, 52)
        XCTAssertTrue(display.bonded)
    }

    func testOnlyIntradayLedgerSourceMayDisplayCharge() {
        var snapshot = renderedSnapshot()
        XCTAssertNil(snapshot.verifiedForDisplay().recovery)

        snapshot.chargeSource = "morning-recovery"
        XCTAssertNil(snapshot.verifiedForDisplay().recovery)

        snapshot.chargeSource = WidgetSnapshot.morningRecoverySource
        XCTAssertEqual(snapshot.verifiedForDisplay().recovery, 72)

        snapshot.chargeSource = WidgetSnapshot.intradayChargeSource
        XCTAssertEqual(snapshot.verifiedForDisplay().recovery, 72)
    }

    private func renderedSnapshot(updated: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> WidgetSnapshot {
        WidgetSnapshot(recovery: 72, bpm: 58, batteryPct: 84, bonded: true, updated: updated,
                       effort: 38, rest: 81, hrv: 64, restingHr: 52,
                       effortDisplay: "38", effortWhoop: false)
    }

    func testRenderedContentFirstPublishAlwaysChanges() {
        XCTAssertTrue(WidgetSnapshot.renderedContentChanged(from: nil, to: renderedSnapshot()))
    }

    func testRenderedContentIgnoresTimestampOnlyChange() {
        let previous = renderedSnapshot()
        let next = renderedSnapshot(updated: previous.updated.addingTimeInterval(900))

        XCTAssertFalse(WidgetSnapshot.renderedContentChanged(from: previous, to: next))
    }

    func testRenderedContentDetectsLiveFieldChange() {
        let previous = renderedSnapshot()
        var next = previous
        next.bpm = 59

        XCTAssertTrue(WidgetSnapshot.renderedContentChanged(from: previous, to: next))
    }

    func testRenderedContentDetectsScoreFieldChange() {
        let previous = renderedSnapshot()
        var next = previous
        next.rest = 82

        XCTAssertTrue(WidgetSnapshot.renderedContentChanged(from: previous, to: next))
    }

    func testLiveUpdateReusesSnapshotWithinSameLocalDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let previous = renderedSnapshot(updated: Date(timeIntervalSince1970: 1_700_000_000))
        let oneHourLater = previous.updated.addingTimeInterval(3_600)

        XCTAssertFalse(WidgetSnapshot.liveUpdateRequiresFullBuild(
            previous: previous, now: oneHourLater, calendar: calendar))
    }

    func testLiveUpdateRequiresFullBuildAfterLocalDayRollover() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let previous = renderedSnapshot(updated: Date(timeIntervalSince1970: 1_700_000_000))
        let nextDay = previous.updated.addingTimeInterval(86_400)

        XCTAssertTrue(WidgetSnapshot.liveUpdateRequiresFullBuild(
            previous: previous, now: nextDay, calendar: calendar))
        XCTAssertTrue(WidgetSnapshot.liveUpdateRequiresFullBuild(
            previous: nil, now: nextDay, calendar: calendar))
    }
}
