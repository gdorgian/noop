import Foundation

/// Derived chart context only. It never writes measurements or changes a score/baseline.
struct AuraHistoryPresentation: Equatable, Sendable {
    struct Spread: Equatable, Sendable {
        let date: Date
        let low: Double
        let high: Double
        let count: Int
    }
    let series: DatedChartSeries
    enum BandKind: Equatable, Sendable { case observedVariability, estimateUncertainty }
    let bands: [Spread]
    let bandKind: BandKind?
    let lower: Double
    let upper: Double
    var average: Double? { series.average }
    var ticks: [Double] { (0...3).map { let t = Double($0) / 3; return lower * (1 - t) + upper * t } }

    /// Trailing 30 calendar days, including the plotted day: mean ± one sample SD, at least
    /// fourteen recorded days. This is observed variability, not a normal range or forecast.
    init(series: DatedChartSeries, context: DatedChartSeries? = nil, showVariability: Bool = true,
         calendar: Calendar = .current, estimateHalfWidth: Double? = nil, references: [Double] = []) {
        self.series = series
        let context = context ?? series
        var spreads: [Spread] = []
        if let width = estimateHalfWidth, width.isFinite, width >= 0 {
            spreads = series.samples.compactMap { sample in
                guard let value = sample.value, (value - width).isFinite, (value + width).isFinite else { return nil }
                return .init(date: sample.date, low: value - width, high: value + width, count: 0)
            }
            bandKind = .estimateUncertainty
        } else if showVariability {
            bandKind = .observedVariability
            var byDay: [Date: Double] = [:]
            for item in context.samples {
                if let value = item.value { byDay[calendar.startOfDay(for: item.date)] = value }
            }
            let days = byDay.sorted { $0.key < $1.key }
            var lowerIndex = 0, upperIndex = 0
            for sample in series.samples where sample.value != nil {
                guard let first = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: sample.date)),
                      let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: sample.date)) else { continue }
                // One contribution per recorded calendar day. Sparse entry logs don't opt in.
                while lowerIndex < days.count && days[lowerIndex].key < first { lowerIndex += 1 }
                upperIndex = max(upperIndex, lowerIndex)
                while upperIndex < days.count && days[upperIndex].key < end { upperIndex += 1 }
                let values = days[lowerIndex..<upperIndex].map(\.value)
                guard values.count >= 14 else { continue }
                let mean = values.reduce(0) { $0 + $1 / Double(values.count) }
                let variance = values.reduce(0) { $0 + pow($1 - mean, 2) / Double(values.count - 1) }
                let sd = sqrt(variance)
                guard mean.isFinite, sd.isFinite, (mean - sd).isFinite, (mean + sd).isFinite else { continue }
                spreads.append(.init(date: sample.date, low: mean - sd, high: mean + sd, count: values.count))
            }
        }
        else { bandKind = nil }
        bands = spreads
        let all = series.values + spreads.flatMap { [$0.low, $0.high] } + references.filter(\.isFinite)
        let low = all.min() ?? 0, high = all.max() ?? 1
        let pad = high > low ? (high - low) * 0.08 : max(abs(low) * 0.05, 1)
        lower = (low - pad).isFinite ? low - pad : low
        upper = (high + pad).isFinite ? high + pad : high
    }

    func fraction(_ value: Double) -> Double {
        let magnitude = max(abs(lower), abs(upper), 1)
        let span = upper / magnitude - lower / magnitude
        return span > 0 ? (value / magnitude - lower / magnitude) / span : 0.5
    }

    /// A missing observation or unsupported spread splits the translucent band too.
    var bandSegments: [[Spread]] {
        let byDate = Dictionary(bands.map { ($0.date, $0) }, uniquingKeysWith: { _, last in last })
        var output: [[Spread]] = [], segment: [Spread] = []
        for sample in series.samples {
            if let spread = byDate[sample.date], sample.value != nil { segment.append(spread) }
            else if !segment.isEmpty { output.append(segment); segment.removeAll(keepingCapacity: true) }
        }
        if !segment.isEmpty { output.append(segment) }
        return output
    }
}

struct AuraHistoryComparison: Equatable {
    struct Period: Equatable {
        let start: Date
        let end: Date
        let count: Int
        let average: Double?
    }
    let current: Period
    let previous: Period
    var difference: Double? {
        guard let a = current.average, let b = previous.average else { return nil }
        return a - b
    }
    init?(series: DatedChartSeries, start: Date, end: Date, calendar: Calendar = .current) {
        guard start.timeIntervalSince1970.isFinite, end.timeIntervalSince1970.isFinite else { return nil }
        let start = calendar.startOfDay(for: start), end = calendar.startOfDay(for: end)
        guard let length = calendar.dateComponents([.day], from: start, to: end).day, length >= 0,
              let previousEnd = calendar.date(byAdding: .day, value: -1, to: start),
              let previousStart = calendar.date(byAdding: .day, value: -(length + 1), to: start) else { return nil }
        func period(_ first: Date, _ last: Date) -> Period {
            let window = HistoryDateWindow(endingOn: last, dayCount: nil, firstDay: first, calendar: calendar)!
            let samples = series.samples.filter { window.contains($0.date) }
            let chart = DatedChartSeries(samples: samples)
            return .init(start: first, end: last, count: chart.values.count, average: chart.average)
        }
        current = period(start, end); previous = period(previousStart, previousEnd)
    }
}
