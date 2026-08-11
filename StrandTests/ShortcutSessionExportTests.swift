import XCTest
import WhoopStore
import WhoopProtocol
@testable import Strand

/// Pins the pure logic behind the session half of the Shortcuts drop files
/// (`Documents/noop_sleep.txt` / `noop_workouts.txt`): the exact line shapes a Siri Shortcut parses,
/// the SECONDS-precision timestamp (stage bounds sit on a 30 s grid, so minute truncation would
/// collapse and overlap segments), the settle horizon that stops a still-re-staging night from being
/// pinned into Health by a one-way watermark, and the advance-only-on-success watermark itself.
final class ShortcutSessionExportTests: XCTestCase {

    private let utc = TimeZone(secondsFromGMT: 0)!
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var dir: URL!

    /// Realistic unix seconds for the export-level cases. Deliberately NOT the epoch: an unset
    /// watermark reads back as 0 and selection is `startTs > watermark`, so a session starting at 0
    /// is indistinguishable from one already exported. Real straps never emit epoch timestamps; the
    /// pure render tests below still use small numbers because they never touch a watermark.
    private let now = Date(timeIntervalSince1970: 1_700_100_000)
    private let nightStart = 1_700_000_000
    private let nightEnd = 1_700_028_000

    override func setUpWithError() throws {
        suiteName = "ShortcutSessionExportTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(suiteName)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: dir)
    }

    /// Returns per-deviceId rows so the source-union + de-dup behaviour is exercised for real.
    private struct FakeReads: ShortcutSessionReads {
        var sleepByDevice: [String: [CachedSleepSession]] = [:]
        var workoutsByDevice: [String: [WorkoutRow]] = [:]
        var error: Error? = nil
        struct Boom: Error {}

        func sleepSessions(deviceId: String, from: Int, to: Int,
                           limit: Int) async throws -> [CachedSleepSession] {
            if let error { throw error }
            return (sleepByDevice[deviceId] ?? []).filter { $0.startTs >= from && $0.startTs <= to }
        }
        func workouts(deviceId: String, from: Int, to: Int, limit: Int) async throws -> [WorkoutRow] {
            if let error { throw error }
            return (workoutsByDevice[deviceId] ?? []).filter { $0.startTs >= from && $0.startTs <= to }
        }
    }

    private func sleep(_ start: Int, _ end: Int, stages: String? = nil) -> CachedSleepSession {
        CachedSleepSession(startTs: start, endTs: end, efficiency: nil, restingHr: nil,
                           avgHrv: nil, stagesJSON: stages)
    }

    private func workout(_ start: Int, _ end: Int, sport: String = "run",
                         kcal: Double? = nil, avg: Int? = nil, max: Int? = nil,
                         dist: Double? = nil) -> WorkoutRow {
        WorkoutRow(startTs: start, endTs: end, sport: sport, source: "strap", durationS: nil,
                   energyKcal: kcal, avgHr: avg, maxHr: max, strain: nil, distanceM: dist,
                   zonesJSON: nil, notes: nil)
    }

    private func text(_ name: String) throws -> String {
        try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
    }

    // MARK: - Sleep line formatting

    // Stage vocabulary is HealthWriteback.StageKind verbatim, so the Shortcut's mapping matches what
    // the entitled HealthKit path writes for the same night.
    func testSleepRendersOneLinePerStageInterval() {
        let stages = """
        [{"start":100,"end":400,"stage":"light"},{"start":400,"end":700,"stage":"deep"}]
        """
        let lines = ShortcutSessionExport.renderSleep([sleep(100, 700, stages: stages)], timeZone: utc)
        XCTAssertEqual(lines, [
            "light,1970-01-01 00:01:40,1970-01-01 00:06:40",
            "deep,1970-01-01 00:06:40,1970-01-01 00:11:40",
        ])
    }

    // "wake" (stager spelling) and "awake" (importer spelling) both normalise to awake.
    func testSleepWakeSpellingsNormalise() {
        let stages = #"[{"start":0,"end":60,"stage":"wake"},{"start":60,"end":120,"stage":"awake"}]"#
        let lines = ShortcutSessionExport.renderSleep([sleep(0, 120, stages: stages)], timeZone: utc)
        XCTAssertEqual(lines.map { String($0.prefix(5)) }, ["awake", "awake"])
    }

    // A session with no placement information yields ONE unspecified block spanning the night rather
    // than fabricated stage positions — the same honest fallback the HealthKit bridge makes.
    func testSleepWithoutStageTimingFallsBackToOneUnspecifiedBlock() {
        XCTAssertEqual(ShortcutSessionExport.renderSleep([sleep(0, 600)], timeZone: utc),
                       ["unspecified,1970-01-01 00:00:00,1970-01-01 00:10:00"])
        // The aggregate minute-dict shape carries no positions either.
        XCTAssertEqual(ShortcutSessionExport.renderSleep(
            [sleep(0, 600, stages: #"{"deep":30,"light":90}"#)], timeZone: utc),
                       ["unspecified,1970-01-01 00:00:00,1970-01-01 00:10:00"])
    }

    // #318: a hand-corrected onset drives the exported span; startTs stays the immutable key.
    func testSleepUsesEditedOnsetForTheSpan() {
        let s = CachedSleepSession(startTs: 0, endTs: 600, efficiency: nil, restingHr: nil,
                                   avgHrv: nil, stagesJSON: nil, userEdited: true,
                                   startTsAdjusted: 300)
        XCTAssertEqual(ShortcutSessionExport.renderSleep([s], timeZone: utc),
                       ["unspecified,1970-01-01 00:05:00,1970-01-01 00:10:00"])
    }

    func testSleepDropsZeroLengthSessions() {
        XCTAssertTrue(ShortcutSessionExport.renderSleep([sleep(500, 500)], timeZone: utc).isEmpty)
    }

    // MARK: - Workout line formatting

    func testWorkoutAllFields() {
        let lines = ShortcutSessionExport.renderWorkouts(
            [workout(0, 1800, sport: "run", kcal: 412.6, avg: 148, max: 176, dist: 5321.4)],
            timeZone: utc)
        XCTAssertEqual(lines, ["run,1970-01-01 00:00:00,1970-01-01 00:30:00,413,148,176,5321"])
    }

    // Empty fields MUST keep their commas — the Shortcut relies on fixed column positions.
    func testWorkoutEmptyFieldsKeepCommas() {
        XCTAssertEqual(ShortcutSessionExport.renderWorkouts([workout(0, 60)], timeZone: utc),
                       ["run,1970-01-01 00:00:00,1970-01-01 00:01:00,,,,"])
    }

    // A comma inside the sport label would shift every later column for that row.
    func testWorkoutSportCommasAreSanitised() {
        let lines = ShortcutSessionExport.renderWorkouts(
            [workout(0, 60, sport: "strength, upper")], timeZone: utc)
        XCTAssertEqual(lines, ["strength upper,1970-01-01 00:00:00,1970-01-01 00:01:00,,,,"])
    }

    func testWorkoutBlankSportFallsBackToLabel() {
        XCTAssertEqual(ShortcutSessionExport.renderWorkouts([workout(0, 60, sport: "")], timeZone: utc),
                       ["workout,1970-01-01 00:00:00,1970-01-01 00:01:00,,,,"])
    }

    // MARK: - Selection: watermark + settle horizon

    func testSelectExcludesAtOrBelowWatermark() {
        let all = [sleep(100, 200), sleep(300, 400), sleep(500, 600)]
        XCTAssertEqual(ShortcutSessionExport.selectSleep(all, watermark: 300, horizon: 10_000)
                        .map(\.startTs), [500])
    }

    // A night that has not been over for `settleSeconds` is held back: it is still being re-staged as
    // history offloads, and the one-way watermark would pin the worse version into Health forever.
    func testSelectHoldsBackUnsettledSessions() {
        let all = [sleep(100, 200), sleep(300, 9_000)]
        XCTAssertEqual(ShortcutSessionExport.selectSleep(all, watermark: 0, horizon: 1_000)
                        .map(\.startTs), [100])
    }

    func testSelectSortsOldestFirst() {
        let all = [sleep(500, 600), sleep(100, 200), sleep(300, 400)]
        XCTAssertEqual(ShortcutSessionExport.selectSleep(all, watermark: 0, horizon: 10_000)
                        .map(\.startTs), [100, 300, 500])
    }

    // MARK: - Sources

    // Sleep/workouts are NOOP-COMPUTED rows, so they live under the "-noop" sibling. Reading only the
    // raw strap id (as the window exporter does) would export nothing at all.
    func testSourceIdsIncludeComputedSibling() {
        XCTAssertEqual(ShortcutSessionExport.sourceIds(deviceId: "abc"), ["abc", "abc-noop"])
    }

    func testExportReadsTheComputedSiblingAndDeDupes() async throws {
        let night = sleep(nightStart, nightEnd)
        let source = FakeReads(sleepByDevice: ["dev": [night], "dev-noop": [night]])
        let outcome = await ShortcutSessionExport.export(
            source: source, deviceId: "dev", now: now,
            defaults: defaults, directory: dir, timeZone: utc)
        XCTAssertEqual(outcome, .written(sleepLines: 1, workoutLines: 0))
        // One line, not two — the same night from both sources collapses on its natural key. The
        // literal stamp rendering is pinned by testTimestampUsesGivenZone.
        XCTAssertEqual(try text(ShortcutSessionExport.sleepFileName),
                       "unspecified,\(ShortcutSessionExport.stamp(nightStart, utc))," +
                       "\(ShortcutSessionExport.stamp(nightEnd, utc))")
    }

    // MARK: - File semantics

    // No header, no trailing newline (a trailing "\n" gives split-by-newline an empty last row).
    func testFileHasNoHeaderOrTrailingNewline() async throws {
        let source = FakeReads(sleepByDevice: ["dev-noop": [
            sleep(nightStart, nightEnd),
            sleep(nightEnd + 3_600, nightEnd + 7_200),
        ]])
        _ = await ShortcutSessionExport.export(
            source: source, deviceId: "dev", now: now,
            defaults: defaults, directory: dir, timeZone: utc)
        let body = try text(ShortcutSessionExport.sleepFileName)
        XCTAssertEqual(body.components(separatedBy: "\n").count, 2)
        XCTAssertFalse(body.hasSuffix("\n"))
    }

    // The Shortcut has no dedup and fires on every app close, so a file left holding yesterday's rows
    // would re-log them into Health on the next run. Nothing new => truncate to empty.
    func testSecondRunWithNothingNewTruncatesBothFiles() async throws {
        let source = FakeReads(sleepByDevice: ["dev-noop": [sleep(nightStart, nightEnd)]],
                               workoutsByDevice: ["dev-noop": [workout(nightEnd + 3_600,
                                                                      nightEnd + 5_400)]])
        let first = await ShortcutSessionExport.export(source: source, deviceId: "dev", now: now,
                                                       defaults: defaults, directory: dir, timeZone: utc)
        XCTAssertEqual(first, .written(sleepLines: 1, workoutLines: 1))

        // Nothing has confirmed these rows yet, so a second export must RE-OFFER them, not destroy them.
        let second = await ShortcutSessionExport.export(source: source, deviceId: "dev", now: now,
                                                        defaults: defaults, directory: dir, timeZone: utc)
        XCTAssertEqual(second, .written(sleepLines: 1, workoutLines: 1))
        XCTAssertFalse(try text(ShortcutSessionExport.sleepFileName).isEmpty)

        // Only once the Shortcut confirms do they stop being offered.
        ShortcutSessionExport.confirm(defaults: defaults)
        let third = await ShortcutSessionExport.export(source: source, deviceId: "dev", now: now,
                                                       defaults: defaults, directory: dir, timeZone: utc)
        XCTAssertEqual(third, .nothingNew)
        XCTAssertEqual(try text(ShortcutSessionExport.sleepFileName), "")
        XCTAssertEqual(try text(ShortcutSessionExport.workoutFileName), "")
    }

    // A watermark that moved past a FAILED write would silently drop that span from Health forever.
    func testWatermarksDoNotAdvanceOnFailure() async {
        var source = FakeReads(sleepByDevice: ["dev-noop": [sleep(0, 600)]])
        source.error = FakeReads.Boom()
        let outcome = await ShortcutSessionExport.export(
            source: source, deviceId: "dev", now: Date(timeIntervalSince1970: 100_000),
            defaults: defaults, directory: dir, timeZone: utc)
        guard case .failure = outcome else { return XCTFail("expected .failure, got \(outcome)") }
        XCTAssertEqual(defaults.integer(forKey: ShortcutSessionExport.sleepWatermarkKey), 0)
        XCTAssertEqual(defaults.integer(forKey: ShortcutSessionExport.workoutWatermarkKey), 0)
    }

    func testResetWatermarksReEmits() async throws {
        let source = FakeReads(sleepByDevice: ["dev-noop": [sleep(nightStart, nightEnd)]])
        _ = await ShortcutSessionExport.export(source: source, deviceId: "dev", now: now,
                                               defaults: defaults, directory: dir, timeZone: utc)
        ShortcutSessionExport.resetWatermarks(defaults: defaults)
        let again = await ShortcutSessionExport.export(source: source, deviceId: "dev", now: now,
                                                       defaults: defaults, directory: dir, timeZone: utc)
        XCTAssertEqual(again, .written(sleepLines: 1, workoutLines: 0))
    }

    // The two streams watermark independently: a new workout must not be gated by an unchanged night.
    func testSleepAndWorkoutWatermarksAreIndependent() async throws {
        var source = FakeReads(sleepByDevice: ["dev-noop": [sleep(nightStart, nightEnd)]])
        _ = await ShortcutSessionExport.export(source: source, deviceId: "dev", now: now,
                                               defaults: defaults, directory: dir, timeZone: utc)
        ShortcutSessionExport.confirm(defaults: defaults)   // the night is logged and acknowledged
        source.workoutsByDevice = ["dev-noop": [workout(nightEnd + 3_600, nightEnd + 5_400)]]
        let second = await ShortcutSessionExport.export(source: source, deviceId: "dev", now: now,
                                                        defaults: defaults, directory: dir, timeZone: utc)
        XCTAssertEqual(second, .written(sleepLines: 0, workoutLines: 1))
    }

    // Timestamps render in the GIVEN zone — production passes the device-local one.
    func testTimestampUsesGivenZone() {
        XCTAssertEqual(ShortcutSessionExport.stamp(3_600, utc), "1970-01-01 01:00:00")
        XCTAssertEqual(ShortcutSessionExport.stamp(3_600, TimeZone(secondsFromGMT: 3_600)!),
                       "1970-01-01 02:00:00")
    }
}
