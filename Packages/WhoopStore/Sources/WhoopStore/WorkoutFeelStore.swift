import Foundation
import GRDB

// MARK: - v51 store: how a cardio session felt (Aura)
//
// The wearer's own 1–10 read of a recorded session, given on the "How hard was that?" sheet when it
// ends. A lift keeps its rating on `liftSession.sessionRpe`; a cardio session is a `workout` row, which
// has no such column and is rebuilt field by field across the app (#1444), so the rating lives beside
// it, keyed by the session's start second. Renaming the activity later does not lose it.

public struct WorkoutFeelRow: Equatable, Codable, Sendable {
    public var deviceId: String
    /// The workout's `startTs`, unix seconds.
    public var startTs: Int
    /// 1…10.
    public var rating: Double
    /// When it was given, unix seconds.
    public var ts: Int

    public init(deviceId: String, startTs: Int, rating: Double, ts: Int) {
        self.deviceId = deviceId
        self.startTs = startTs
        self.rating = rating
        self.ts = ts
    }
}

extension WhoopStore {

    public func upsertWorkoutFeel(_ r: WorkoutFeelRow) async throws {
        try syncWrite { db in
            try db.execute(sql: """
                INSERT INTO workoutFeel (deviceId, startTs, rating, ts) VALUES (?, ?, ?, ?)
                ON CONFLICT(deviceId, startTs) DO UPDATE SET rating = excluded.rating, ts = excluded.ts
                """, arguments: [r.deviceId, r.startTs, min(10, max(1, r.rating)), r.ts])
        }
    }

    public func workoutFeel(deviceId: String, startTs: Int) async throws -> WorkoutFeelRow? {
        try syncRead { db in
            try Row.fetchOne(db, sql: "SELECT * FROM workoutFeel WHERE deviceId = ? AND startTs = ?",
                             arguments: [deviceId, startTs])
                .map { WorkoutFeelRow(deviceId: $0["deviceId"], startTs: $0["startTs"], rating: $0["rating"], ts: $0["ts"]) }
        }
    }
}
