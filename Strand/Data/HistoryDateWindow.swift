import Foundation

/// Calendar-day boundaries for presentation only. A day is not assumed to be 86,400 seconds.
struct HistoryDateWindow: Equatable {
    let start: Date
    let endDay: Date
    let endExclusive: Date

    init?(endingOn date: Date, dayCount: Int?, firstDay: Date, calendar: Calendar) {
        guard date.timeIntervalSince1970.isFinite, firstDay.timeIntervalSince1970.isFinite,
              dayCount.map({ $0 > 0 && $0 <= 40_000 }) ?? true else { return nil }
        let end = calendar.startOfDay(for: date)
        guard let next = calendar.date(byAdding: .day, value: 1, to: end),
              let start = dayCount.flatMap({ calendar.date(byAdding: .day, value: 1 - $0, to: end) })
                ?? (dayCount == nil ? calendar.startOfDay(for: firstDay) : nil),
              start <= end else { return nil }
        self.start = start
        endDay = end
        endExclusive = next
    }

    func contains(_ date: Date) -> Bool { date >= start && date < endExclusive }

    func indices(in dates: [Date?]) -> [Int] {
        dates.indices.filter { index in dates[index].map(contains) ?? false }
    }

    /// Source day keys are Gregorian even when the user's display calendar is not.
    static func date(dayKey: String, timeZone: TimeZone = .current) -> Date? {
        let parts = dayKey.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let date = calendar.date(from: DateComponents(year: y, month: m, day: d)) else { return nil }
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return components.year == y && components.month == m && components.day == d ? date : nil
    }
}

extension DatedChartSeries {
    var average: Double? {
        let recorded = values
        guard !recorded.isEmpty else { return nil }
        return recorded.reduce(0) { $0 + $1 / Double(recorded.count) }
    }

    func nearestPoint(to fraction: Double) -> Point? {
        guard fraction.isFinite else { return nil }
        let target = min(1, max(0, fraction))
        return points.min { abs($0.x - target) < abs($1.x - target) }
    }
}
