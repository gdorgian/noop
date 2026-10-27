import XCTest
@testable import WhoopProtocol

final class AuraReleaseTests: XCTestCase {

    private func release(_ tag: String, pre: Bool = false) -> AuraRelease {
        let p = AuraRelease.parseTag(tag)!
        return AuraRelease(version: p.version, build: p.build, prerelease: pre, name: tag,
                           url: URL(string: "https://example.com/\(tag)")!, notes: "")
    }

    func testParsesAuraTags() {
        XCTAssertEqual(AuraRelease.parseTag("v12.0.0-aura.1220")?.version, "12.0.0")
        XCTAssertEqual(AuraRelease.parseTag("v12.0.0-aura.1220")?.build, 1220)
        XCTAssertNil(AuraRelease.parseTag("v12.0.0"))
        XCTAssertNil(AuraRelease.parseTag("v12.0.0-dx"))
    }

    func testSameVersionNewerBuildIsAnnounced() {
        // The bug: 12.0.0 (1206) installed, 12.0.0 beta (1220) out, and the bell said nothing.
        let out = AuraRelease.announcements([release("v12.0.0-aura.1220", pre: true), release("v12.0.0-aura.1206")],
                                            installedBuild: 1206)
        XCTAssertEqual(out.map(\.build), [1220])
        XCTAssertEqual(out.first?.kind(installedVersion: "12.0.0"), .beta)
    }

    func testNothingWhenCaughtUp() {
        XCTAssertTrue(AuraRelease.announcements([release("v12.0.0-aura.1206")], installedBuild: 1225).isEmpty)
    }

    func testOneRowPerChannelAndBetaOnlyPastStable() {
        let all = [release("v12.0.0-aura.1220", pre: true), release("v12.0.0-aura.1230", pre: true),
                   release("v12.1.0-aura.1240"), release("v13.0.0-aura.1250", pre: true)]
        XCTAssertEqual(AuraRelease.announcements(all, installedBuild: 1210).map(\.build), [1250, 1240])
        let older = [release("v12.0.0-aura.1220", pre: true), release("v12.1.0-aura.1240")]
        XCTAssertEqual(AuraRelease.announcements(older, installedBuild: 1210).map(\.build), [1240])
    }

    func testMajorAgainstInstalled() {
        XCTAssertEqual(release("v13.0.0-aura.1300").kind(installedVersion: "12.0.0"), .major)
        XCTAssertEqual(release("v12.1.0-aura.1300").kind(installedVersion: "12.0.0"), .release)
    }
}
