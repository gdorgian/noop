import Foundation

/// Presentation geometry for recorded history. Missing values keep their time slot and break
/// the line; values in different units are never joined or implicitly converted.
struct DatedChartSeries: Equatable, Sendable {
    struct Sample: Equatable, Sendable {
        let date: Date
        let value: Double?
    }

    struct Observation: Equatable, Sendable {
        let date: Date
        let value: Double
        let unit: String
    }

    struct Point: Equatable, Sendable {
        let date: Date
        let value: Double
        /// Fraction of the complete dated window, including empty slots.
        let x: Double
    }

    let samples: [Sample]

    init(samples: [Sample]) {
        self.samples = samples.enumerated()
            .filter { $0.element.date.timeIntervalSinceReferenceDate.isFinite }
            .sorted {
                $0.element.date == $1.element.date
                    ? $0.offset < $1.offset
                    : $0.element.date < $1.element.date
            }
            .map { item in
                let value = item.element.value.flatMap { $0.isFinite ? $0 : nil }
                return Sample(date: item.element.date, value: value)
            }
    }

    /// A date without a corresponding value stays missing. Extra undated values cannot be plotted.
    init(dates: [Date], values: [Double?]) {
        self.init(samples: dates.enumerated().map { index, date in
            Sample(date: date, value: values.indices.contains(index) ? values[index] : nil)
        })
    }

    init(observations: [Observation], unit: String) {
        let key = Self.unitKey(unit)
        self.init(samples: observations.map {
            Sample(date: $0.date, value: key != nil && Self.unitKey($0.unit) == key ? $0.value : nil)
        })
    }

    /// Only authored fixture values use index-based dates. Recorded history supplies real dates.
    static func fixture(_ values: [Double]) -> Self {
        Self(samples: values.enumerated().map {
            Sample(date: Date(timeIntervalSince1970: Double($0.offset)), value: $0.element)
        })
    }

    static func unitKey(_ unit: String) -> String? {
        // Unit prefixes are case-sensitive: mIU and MIU must not be treated as equivalent.
        let key = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : key
    }

    var values: [Double] { samples.compactMap(\.value) }

    var segments: [[Point]] {
        guard let first = samples.first?.date, let last = samples.last?.date else { return [] }
        let duration = last.timeIntervalSince(first)
        var segments: [[Point]] = []
        var current: [Point] = []
        for sample in samples {
            guard let value = sample.value else {
                if !current.isEmpty { segments.append(current); current.removeAll(keepingCapacity: true) }
                continue
            }
            // An isolated reading is anchored at the latest edge, not stretched into a flat line.
            let x = duration > 0 ? sample.date.timeIntervalSince(first) / duration : 1
            current.append(Point(date: sample.date, value: value, x: x))
        }
        if !current.isEmpty { segments.append(current) }
        return segments
    }

    var points: [Point] { segments.flatMap { $0 } }
}


extension DatedChartSeries {
    /// Calendar-week means from the same daily measurements used by the detail view.
    /// Empty weeks remain missing; the final (partial) week excludes future observations.
    func weeklyAverages(startingOn starts: [Date], through day: Date, calendar: Calendar) -> [Double?] {
        guard let cutoff = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day)) else {
            return starts.map { _ in nil }
        }
        return starts.map { start in
            guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: start) else { return nil }
            let end = min(nextWeek, cutoff)
            let values = samples.compactMap { sample -> Double? in
                guard sample.date >= start, sample.date < end else { return nil }
                return sample.value
            }
            guard !values.isEmpty else { return nil }
            return values.reduce(0) { $0 + $1 / Double(values.count) }
        }
    }
}
