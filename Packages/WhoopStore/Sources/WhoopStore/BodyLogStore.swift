import Foundation
import GRDB

// MARK: - v50 store: body measurements and progress photos (Aura)
//
// Same idiom as the lift log: plain Codable rows, raw `Row` decode, upserts keyed by id. Values are
// stored in one unit per kind — kilograms for weight, percent for body fat, centimetres for every
// circumference — and converted at the edge.

/// What was measured. The raw value is what is stored; never rename a case.
public enum BodyMeasurementKind: String, Codable, CaseIterable, Sendable {
    case weight, bodyFat
    case neck, shoulders, chest, waist, hips
    case leftBicep, rightBicep, leftForearm, rightForearm
    case leftThigh, rightThigh, leftCalf, rightCalf

    public enum Unit: Sendable { case mass, percent, length }

    public var unit: Unit {
        switch self {
        case .weight: .mass
        case .bodyFat: .percent
        default: .length
        }
    }

    public var title: String {
        switch self {
        case .weight: "Weight"
        case .bodyFat: "Body fat"
        case .neck: "Neck"
        case .shoulders: "Shoulders"
        case .chest: "Chest"
        case .waist: "Waist"
        case .hips: "Hips"
        case .leftBicep: "Left arm"
        case .rightBicep: "Right arm"
        case .leftForearm: "Left forearm"
        case .rightForearm: "Right forearm"
        case .leftThigh: "Left thigh"
        case .rightThigh: "Right thigh"
        case .leftCalf: "Left calf"
        case .rightCalf: "Right calf"
        }
    }

    /// A plausible range in the stored unit, so a slip of the finger is refused rather than kept.
    public var plausible: ClosedRange<Double> {
        switch self {
        case .weight: 20...400
        case .bodyFat: 2...70
        case .neck: 20...70
        case .shoulders: 70...200
        case .chest, .waist, .hips: 40...220
        case .leftBicep, .rightBicep: 15...70
        case .leftForearm, .rightForearm: 15...55
        case .leftThigh, .rightThigh: 25...110
        case .leftCalf, .rightCalf: 20...70
        }
    }
}

public struct BodyMeasurementRow: Equatable, Codable, Sendable {
    public var id: String
    public var deviceId: String
    /// Unix seconds.
    public var ts: Int
    public var kind: BodyMeasurementKind
    /// Kilograms, percent or centimetres, by `kind.unit`.
    public var value: Double
    public var note: String?

    public init(id: String, deviceId: String, ts: Int, kind: BodyMeasurementKind, value: Double, note: String? = nil) {
        self.id = id
        self.deviceId = deviceId
        self.ts = ts
        self.kind = kind
        self.value = value
        self.note = note
    }

    static func decode(_ row: Row) -> BodyMeasurementRow? {
        guard let kind = BodyMeasurementKind(rawValue: row["kind"] ?? "") else { return nil }
        return BodyMeasurementRow(id: row["id"], deviceId: row["deviceId"], ts: row["ts"], kind: kind,
                                  value: row["value"], note: row["note"])
    }
}

public struct ProgressPhotoRow: Identifiable, Equatable, Codable, Sendable {
    public enum Pose: String, Codable, CaseIterable, Sendable { case front, side, back }

    public var id: String
    public var deviceId: String
    /// Unix seconds.
    public var ts: Int
    public var pose: Pose?
    /// The image's file name inside the app's ProgressPhotos folder.
    public var fileName: String
    public var note: String?

    public init(id: String, deviceId: String, ts: Int, pose: Pose?, fileName: String, note: String? = nil) {
        self.id = id
        self.deviceId = deviceId
        self.ts = ts
        self.pose = pose
        self.fileName = fileName
        self.note = note
    }

    static func decode(_ row: Row) -> ProgressPhotoRow {
        ProgressPhotoRow(id: row["id"], deviceId: row["deviceId"], ts: row["ts"],
                         pose: (row["pose"] as String?).flatMap(Pose.init(rawValue:)),
                         fileName: row["fileName"], note: row["note"])
    }
}

extension WhoopStore {

    @discardableResult
    public func upsertBodyMeasurements(_ rows: [BodyMeasurementRow]) async throws -> Int {
        guard !rows.isEmpty else { return 0 }
        return try syncWrite { db in
            for r in rows {
                try db.execute(sql: """
                    INSERT INTO bodyMeasurement (id, deviceId, ts, kind, value, note) VALUES (?, ?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET ts = excluded.ts, kind = excluded.kind,
                        value = excluded.value, note = excluded.note
                    """, arguments: [r.id, r.deviceId, r.ts, r.kind.rawValue, r.value, r.note])
            }
            return rows.count
        }
    }

    /// Every measurement on this device, oldest first. A kind this build does not know is skipped.
    public func bodyMeasurements(deviceId: String) async throws -> [BodyMeasurementRow] {
        try syncRead { db in
            try Row.fetchAll(db, sql: "SELECT * FROM bodyMeasurement WHERE deviceId = ? ORDER BY ts ASC, id ASC",
                             arguments: [deviceId]).compactMap(BodyMeasurementRow.decode)
        }
    }

    @discardableResult
    public func deleteBodyMeasurement(id: String) async throws -> Bool {
        try syncWrite { db in
            try db.execute(sql: "DELETE FROM bodyMeasurement WHERE id = ?", arguments: [id])
            return db.changesCount > 0
        }
    }

    @discardableResult
    public func upsertProgressPhoto(_ r: ProgressPhotoRow) async throws -> Bool {
        try syncWrite { db in
            try db.execute(sql: """
                INSERT INTO progressPhoto (id, deviceId, ts, pose, fileName, note) VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET ts = excluded.ts, pose = excluded.pose,
                    fileName = excluded.fileName, note = excluded.note
                """, arguments: [r.id, r.deviceId, r.ts, r.pose?.rawValue, r.fileName, r.note])
            return true
        }
    }

    /// Every progress photo, newest first.
    public func progressPhotos(deviceId: String) async throws -> [ProgressPhotoRow] {
        try syncRead { db in
            try Row.fetchAll(db, sql: "SELECT * FROM progressPhoto WHERE deviceId = ? ORDER BY ts DESC, id DESC",
                             arguments: [deviceId]).map(ProgressPhotoRow.decode)
        }
    }

    @discardableResult
    public func deleteProgressPhoto(id: String) async throws -> Bool {
        try syncWrite { db in
            try db.execute(sql: "DELETE FROM progressPhoto WHERE id = ?", arguments: [id])
            return db.changesCount > 0
        }
    }
}
