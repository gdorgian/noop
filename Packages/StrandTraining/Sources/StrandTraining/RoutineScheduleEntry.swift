import Foundation

/// A local calendar entry. Missing time metadata preserves the meaning of older timed entries.
public struct RoutineScheduleEntry: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public let routineID: String
    public let routineName: String
    public let date: Date
    public var includesTime: Bool?

    public init(id: UUID = UUID(), routineID: String, routineName: String, date: Date, includesTime: Bool? = nil) {
        self.id = id; self.routineID = routineID; self.routineName = routineName
        self.date = date; self.includesTime = includesTime
    }

    public func isUpcoming(asOf now: Date, calendar: Calendar = .current) -> Bool {
        includesTime == false ? calendar.startOfDay(for: date) >= calendar.startOfDay(for: now) : date > now
    }
}
