#if os(iOS)
import SwiftUI
import Charts

// MARK: - Windows

/// The span a detail page looks at. Short spans are read day by day, three months and the year to date
/// week by week, a year month by month.
enum NoopFitnessRange: String, CaseIterable, Identifiable {
    case week = "7D", month = "30D", quarter = "3M", year = "1Y", ytd = "YTD"
    var id: String { rawValue }
}

struct NoopFitnessWindow: Equatable {
    enum Bucket { case day, week, month }

    let range: NoopFitnessRange
    let start: Date
    /// Exclusive.
    let end: Date
    let bucket: Bucket
    let buckets: [Date]

    static func make(_ range: NoopFitnessRange, offset: Int, now: Date) -> NoopFitnessWindow {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now
        let start: Date, end: Date, bucket: Bucket
        switch range {
        case .week, .month:
            let n = range == .week ? 7 : 30
            end = cal.date(byAdding: .day, value: -n * offset, to: tomorrow) ?? tomorrow
            start = cal.date(byAdding: .day, value: -n, to: end) ?? end
            bucket = .day
        case .quarter:
            let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? cal.startOfDay(for: now)
            let thisEnd = cal.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? tomorrow
            end = cal.date(byAdding: .weekOfYear, value: -13 * offset, to: thisEnd) ?? thisEnd
            start = cal.date(byAdding: .weekOfYear, value: -13, to: end) ?? end
            bucket = .week
        case .year:
            let monthStart = cal.dateInterval(of: .month, for: now)?.start ?? cal.startOfDay(for: now)
            let thisEnd = cal.date(byAdding: .month, value: 1, to: monthStart) ?? tomorrow
            end = cal.date(byAdding: .month, value: -12 * offset, to: thisEnd) ?? thisEnd
            start = cal.date(byAdding: .month, value: -12, to: end) ?? end
            bucket = .month
        case .ytd:
            let year = cal.component(.year, from: now) - offset
            start = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
            end = offset == 0 ? tomorrow : (cal.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? now)
            bucket = .week
        }
        var buckets: [Date] = []
        var d = start
        let step: Calendar.Component = bucket == .day ? .day : bucket == .week ? .weekOfYear : .month
        while d < end && buckets.count < 400 {
            buckets.append(d)
            d = cal.date(byAdding: step, value: 1, to: d) ?? end
        }
        return NoopFitnessWindow(range: range, start: start, end: end, bucket: bucket, buckets: buckets)
    }

    /// The same length of time immediately before.
    var previous: NoopFitnessWindow {
        let cal = Calendar.current
        let length = end.timeIntervalSince(start)
        let prevStart: Date
        switch range {
        case .ytd: prevStart = cal.date(byAdding: .year, value: -1, to: start) ?? start.addingTimeInterval(-length)
        case .year: prevStart = cal.date(byAdding: .month, value: -12, to: start) ?? start.addingTimeInterval(-length)
        default: prevStart = start.addingTimeInterval(-length)
        }
        let shift = start.timeIntervalSince(prevStart)
        return NoopFitnessWindow(range: range, start: prevStart, end: end.addingTimeInterval(-shift), bucket: bucket,
                                 buckets: buckets.map { $0.addingTimeInterval(-shift) })
    }

    func contains(_ d: Date) -> Bool { d >= start && d < end }

    func index(of d: Date) -> Int? {
        guard contains(d) else { return nil }
        return buckets.lastIndex { $0 <= d }
    }

    var title: String {
        let last = end.addingTimeInterval(-1)
        let sameYear = Calendar.current.isDate(start, equalTo: last, toGranularity: .year)
        let a = start.formatted(sameYear ? .dateTime.month(.abbreviated).day() : .dateTime.month(.abbreviated).day().year())
        let b = last.formatted(.dateTime.month(.abbreviated).day().year())
        return "\(a) – \(b)"
    }

    func label(_ i: Int) -> String {
        guard let d = buckets[safe: i] else { return "" }
        switch bucket {
        case .day: return d.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        case .week:
            let e = Calendar.current.date(byAdding: .day, value: 6, to: d) ?? d
            return "\(d.formatted(.dateTime.month(.abbreviated).day())) – \(e.formatted(.dateTime.month(.abbreviated).day()))"
        case .month: return d.formatted(.dateTime.month(.wide).year())
        }
    }

    func tick(_ i: Int) -> String {
        guard let d = buckets[safe: i] else { return "" }
        return bucket == .month ? d.formatted(.dateTime.month(.narrow)) : d.formatted(.dateTime.month(.abbreviated).day())
    }

    var unitWord: String { bucket == .day ? "day" : bucket == .week ? "week" : "month" }
}

// MARK: - Measures

/// One figure a detail page can chart: the events behind it and how they combine.
struct NoopFitnessMeasure: Identifiable {
    enum Combine { case sum, mean, max, latest }

    let id: String
    let label: String
    let combine: Combine
    let events: [(date: Date, value: Double)]
    let format: (Double) -> String
    var tint: Color = NoopHTMLColor.blue
    /// Lower is better (a resting rate, a pace).
    var lowerIsBetter = false

    var accumulates: Bool { combine == .sum }

    func perBucket(_ w: NoopFitnessWindow) -> [Double?] {
        var groups = [[Double]](repeating: [], count: w.buckets.count)
        for e in events { if let i = w.index(of: e.date) { groups[i].append(e.value) } }
        return groups.map { g in
            guard !g.isEmpty else { return nil }
            switch combine {
            case .sum: return g.reduce(0, +)
            case .mean: return g.reduce(0, +) / Double(g.count)
            case .max: return g.max()
            case .latest: return g.last
            }
        }
    }

    /// Running total, one point per bucket; empty buckets carry the total forward.
    func running(_ w: NoopFitnessWindow, now: Date) -> [Double?] {
        var total = 0.0
        return zip(w.buckets, perBucket(w)).map { start, v in
            total += v ?? 0
            return start <= now ? total : nil
        }
    }

    /// The window's single figure: its total, average, best or last reading.
    func summary(_ w: NoopFitnessWindow) -> Double? {
        let inside = events.filter { w.contains($0.date) }.sorted { $0.date < $1.date }
        guard !inside.isEmpty else { return combine == .sum ? 0 : nil }
        switch combine {
        case .sum: return inside.reduce(0) { $0 + $1.value }
        case .mean: return inside.reduce(0) { $0 + $1.value } / Double(inside.count)
        case .max: return inside.map(\.value).max()
        case .latest: return inside.last?.value
        }
    }
}

// MARK: - Shared page pieces

/// Header of every detail page: the figure, what it covers, and what it is set against.
struct NoopFitnessInstrumentHeader: View {
    let value: String
    var unit: String? = nil
    let caption: String
    var comparison: String? = nil
    var status: (text: String, color: Color)? = nil
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value).font(NoopHTMLFont.outfit(34)).foregroundStyle(NoopHTMLColor.ink)
                        .contentTransition(.numericText())
                    if let unit { Text(unit).font(NoopHTMLFont.sans(14)).foregroundStyle(NoopHTMLColor.copy) }
                }
                Text(caption).font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.copy)
                if let comparison {
                    Text(comparison).font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.muted)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                if let status {
                    Text(status.text).font(NoopHTMLFont.sans(14, weight: .semibold)).foregroundStyle(status.color)
                }
                if let trailing {
                    Text(trailing).font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy)
                }
            }
        }
        .animation(NoopMotion.swap, value: value)
    }
}

/// A row of figures to switch between, each with its value now and the period before.
struct NoopFitnessMeasureChips: View {
    struct Item: Identifiable {
        let id: String
        let label: String
        let value: String
        var previous: String? = nil
        /// Up, down or flat against the period before, already judged good or bad.
        var trend: (up: Bool, good: Bool)? = nil
        var status: (text: String, color: Color)? = nil
    }

    let items: [Item]
    @Binding var selected: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    Button { withAnimation(NoopMotion.swap) { selected = item.id } } label: { chip(item) }
                        .buttonStyle(NoopHTMLPressStyle())
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func chip(_ item: Item) -> some View {
        let on = item.id == selected
        return VStack(alignment: .leading, spacing: 3) {
            Text(item.label).font(NoopHTMLFont.sans(11.5, weight: .medium)).foregroundStyle(NoopHTMLColor.copy)
            Text(item.value).font(NoopHTMLFont.sans(16, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                .lineLimit(1)
            if let status = item.status {
                Text(status.text).font(NoopHTMLFont.sans(11, weight: .semibold)).foregroundStyle(status.color)
            } else if let prev = item.previous {
                HStack(spacing: 4) {
                    if let t = item.trend {
                        Image(systemName: t.up ? "arrow.up" : "arrow.down")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(t.good ? NoopHTMLColor.green : NoopHTMLColor.warm)
                    }
                    Text(prev).font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.muted).lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 13).padding(.vertical, 10)
        .frame(minWidth: 112, alignment: .leading)
        .background(on ? Color.white.opacity(0.07) : Color.white.opacity(0.03),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(on ? NoopHTMLColor.inkSoft.opacity(0.55) : NoopHTMLColor.border, lineWidth: on ? 1 : 0.5))
    }
}

/// 7D · 30D · 3M · 1Y · YTD, with steps back and forward through time.
struct NoopFitnessRangeBar: View {
    @Binding var range: NoopFitnessRange
    @Binding var offset: Int
    var ranges: [NoopFitnessRange] = NoopFitnessRange.allCases
    var maxOffset = 4

    var body: some View {
        HStack(spacing: 2) {
            step(.left, enabled: offset < maxOffset) { offset += 1 }
            ForEach(ranges) { r in
                Button {
                    withAnimation(NoopMotion.swap) { range = r; offset = 0 }
                } label: {
                    Text(r.rawValue)
                        .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                        .foregroundStyle(range == r ? NoopHTMLColor.ink : NoopHTMLColor.copy)
                        .frame(maxWidth: .infinity).frame(minHeight: 32)
                        .background(range == r ? Color.white.opacity(0.09) : .clear, in: Capsule())
                }
                .buttonStyle(NoopHTMLPressStyle())
            }
            step(.right, enabled: offset > 0) { offset -= 1 }
        }
        .padding(3)
        .background(Color.white.opacity(0.04), in: Capsule())
        .sensoryFeedback(.selection, trigger: offset)
    }

    private func step(_ d: NoopFixedChevron.Direction, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(NoopMotion.swap) { action() } } label: {
            NoopFixedChevron(direction: d, color: enabled ? NoopHTMLColor.inkSoft : NoopHTMLColor.chevronDim)
                .frame(width: 34, height: 32)
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(!enabled)
        .accessibilityLabel(d == .left ? "Earlier" : "Later")
    }
}

/// Sport filter: All, then every activity type that has sessions.
struct NoopFitnessFilterChips: View {
    let options: [String]
    @Binding var selected: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip("All", on: selected == nil) { selected = nil }
                ForEach(options, id: \.self) { o in chip(o, on: selected == o) { selected = o } }
            }
        }
    }

    private func chip(_ t: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(NoopMotion.swap) { action() } } label: {
            Text(t).font(NoopHTMLFont.sans(12, weight: .semibold))
                .foregroundStyle(on ? NoopHTMLColor.canvas : NoopHTMLColor.inkSoft)
                .padding(.horizontal, 12).frame(minHeight: 30)
                .background(on ? NoopHTMLColor.ink : Color.white.opacity(0.06), in: Capsule())
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

/// A table of how the period split: label, amount, share bar and percentage.
struct NoopFitnessBreakdown: View {
    struct Row: Identifiable {
        let label: String
        let amount: String
        let share: Double
        let color: Color
        var id: String { label }
    }

    let title: String
    var columns = ("Status", "Days")
    let rows: [Row]

    var body: some View {
        NoopFitnessPanel(label: title) {
            HStack {
                Text(columns.0).frame(width: 96, alignment: .leading)
                Text(columns.1)
                Spacer()
                Text("Share")
            }
            .font(NoopHTMLFont.sans(10.5, weight: .semibold))
            .foregroundStyle(NoopHTMLColor.muted)
            ForEach(rows) { r in
                HStack(spacing: 10) {
                    HStack(spacing: 7) {
                        Circle().fill(r.color).frame(width: 7, height: 7)
                        Text(r.label).font(NoopHTMLFont.sans(13, weight: .medium)).foregroundStyle(NoopHTMLColor.ink)
                            .lineLimit(1).minimumScaleFactor(0.85)
                    }
                    .frame(width: 96, alignment: .leading)
                    Text(r.amount).font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.inkSoft)
                        .frame(width: 52, alignment: .leading)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.06))
                            Capsule().fill(r.color).frame(width: max(r.share > 0 ? 5 : 0, g.size.width * r.share))
                        }
                    }
                    .frame(height: 6)
                    Text("\(Int((r.share * 100).rounded()))%")
                        .font(NoopHTMLFont.sans(12, weight: .semibold)).foregroundStyle(NoopHTMLColor.copy)
                        .frame(width: 38, alignment: .trailing)
                }
                .padding(.vertical, 3)
            }
        }
    }
}

/// "What is this?" — a short explanation with a coloured key.
struct NoopFitnessExplainer: View {
    let title: String
    let body_: String
    var keys: [(label: String, text: String, color: Color)] = []

    init(_ title: String, _ body: String, keys: [(label: String, text: String, color: Color)] = []) {
        self.title = title
        self.body_ = body
        self.keys = keys
    }

    var body: some View {
        NoopFitnessPanel(label: title) {
            Text(body_).font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.inkSoft)
                .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            ForEach(Array(keys.enumerated()), id: \.offset) { _, k in
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Circle().fill(k.color).frame(width: 7, height: 7).offset(y: -1)
                    (Text(k.label + "  ").font(NoopHTMLFont.sans(13, weight: .semibold)).foregroundColor(NoopHTMLColor.ink)
                     + Text(k.text).font(NoopHTMLFont.sans(13)).foregroundColor(NoopHTMLColor.copy))
                        .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// Sessions in the period, newest first, under a heading per month.
struct NoopFitnessHistoryList: View {
    let sessions: [NoopFitnessSession]
    @ObservedObject var navigation: NoopNavigation
    @State private var newestFirst = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                NoopSectionLabel("Activity history")
                Spacer()
                Button { withAnimation(NoopMotion.swap) { newestFirst.toggle() } } label: {
                    Text(newestFirst ? "Newest first" : "Oldest first")
                        .font(NoopHTMLFont.sans(11.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.blueLight)
                }
                .buttonStyle(NoopHTMLPressStyle())
            }
            if sessions.isEmpty {
                Text("Nothing logged in this period.")
                    .font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy)
                    .padding(.vertical, 6)
            }
            ForEach(months, id: \.month) { group in
                Text(group.month.formatted(.dateTime.month(.wide).year()))
                    .font(NoopHTMLFont.sans(12, weight: .semibold)).foregroundStyle(NoopHTMLColor.muted)
                    .padding(.top, 4)
                ForEach(group.sessions) { s in
                    NoopFitnessSessionButton(session: s, navigation: navigation, returnRoute: .fitnessDetail, showsDate: true)
                }
            }
        }
    }

    private var months: [(month: Date, sessions: [NoopFitnessSession])] {
        let cal = Calendar.current
        let sorted = sessions.sorted { newestFirst ? $0.start > $1.start : $0.start < $1.start }
        var out: [(month: Date, sessions: [NoopFitnessSession])] = []
        for s in sorted {
            let m = cal.dateInterval(of: .month, for: s.start)?.start ?? s.start
            if out.last?.month == m { out[out.count - 1].sessions.append(s) } else { out.append((m, [s])) }
        }
        return out
    }
}

// MARK: - Chart

/// The chart every measure shares. A running total is drawn against the same period before it; a
/// per-bucket figure as bars (sums) or a line (averages and readings), with the period's average.
/// Dragging across it selects a bucket and the page's header follows.
struct NoopFitnessMeasureChart: View {
    enum Style { case running, bars, line }

    let window: NoopFitnessWindow
    let current: [Double?]
    var previous: [Double?] = []
    let style: Style
    let tint: Color
    var average: Double? = nil
    var format: (Double) -> String = { String(format: "%.0f", $0) }
    @Binding var selection: Int?

    private struct Point: Identifiable {
        let i: Int
        let v: Double
        let series: String
        var id: String { "\(series)-\(i)" }
    }

    var body: some View {
        func points(_ values: [Double?], name: String) -> [Point] {
            var segment = 0
            return values.enumerated().compactMap { i, value in
                guard let value, value.isFinite else { segment += 1; return nil }
                return Point(i: i, v: value, series: "\(name)-\(segment)")
            }
        }
        let cur = points(current, name: "now")
        let prev = points(previous, name: "before")
        let n = max(window.buckets.count, 1)
        let tickEvery = max(1, n / 4)
        return Group {
            if style == .line {
                let dated = DatedChartSeries(dates: window.buckets, values: current)
                VStack(spacing: 8) {
                    NoopHistoryPlot(presentation: .init(series: dated, showVariability: false), tint: tint,
                                    selectedDate: selection.flatMap { window.buckets.indices.contains($0) ? window.buckets[$0] : nil },
                                    valueLabel: format,
                                    onSelect: { date in selection = window.buckets.firstIndex(of: date) })
                    HStack {
                        let indices = Array(Set([0, n / 3, n * 2 / 3, n - 1])).sorted().filter { window.buckets.indices.contains($0) }
                        ForEach(indices, id: \.self) { index in
                            Text(window.tick(index))
                            if index != indices.last { Spacer() }
                        }
                    }
                    .font(NoopHTMLFont.sans(10)).foregroundStyle(NoopHTMLColor.muted)
                    if let average {
                        Text("Average · \(format(average))")
                            .font(NoopHTMLFont.sans(10.5)).foregroundStyle(NoopHTMLColor.copy)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else if cur.isEmpty && prev.isEmpty {
                VStack(spacing: 5) {
                    Text("No data in this period").font(NoopHTMLFont.sans(14, weight: .semibold)).foregroundStyle(NoopHTMLColor.inkSoft)
                    Text("Step back with the arrows, or pick a longer span.")
                        .font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart {
                    if style == .running {
                        ForEach(prev) { p in
                            LineMark(x: .value("Bucket", p.i), y: .value("Value", p.v), series: .value("Series", p.series))
                                .foregroundStyle(NoopHTMLColor.muted.opacity(0.7))
                                .lineStyle(StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                                .interpolationMethod(.monotone)
                        }
                        ForEach(cur) { p in
                            AreaMark(x: .value("Bucket", p.i), y: .value("Value", p.v), series: .value("Series", p.series))
                                .foregroundStyle(LinearGradient(colors: [tint.opacity(0.28), tint.opacity(0)],
                                                                startPoint: .top, endPoint: .bottom))
                                .interpolationMethod(.monotone)
                            LineMark(x: .value("Bucket", p.i), y: .value("Value", p.v), series: .value("Series", p.series))
                                .foregroundStyle(tint)
                                .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                                .interpolationMethod(.monotone)
                        }
                        if let last = cur.last {
                            PointMark(x: .value("Bucket", last.i), y: .value("Value", last.v))
                                .foregroundStyle(tint).symbolSize(55)
                        }
                    } else if style == .bars {
                        ForEach(cur) { p in
                            BarMark(x: .value("Bucket", p.i), y: .value("Value", p.v), width: .ratio(0.62))
                                .foregroundStyle(LinearGradient(colors: [tint, tint.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                                .opacity(selection == nil || selection == p.i ? 1 : 0.35)
                        }
                    } else {
                        ForEach(cur) { p in
                            LineMark(x: .value("Bucket", p.i), y: .value("Value", p.v))
                                .foregroundStyle(tint)
                                .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                                .interpolationMethod(.monotone)
                            PointMark(x: .value("Bucket", p.i), y: .value("Value", p.v))
                                .foregroundStyle(tint).symbolSize(cur.count > 40 ? 0 : 28)
                        }
                    }
                    if style != .running, let average {
                        RuleMark(y: .value("Average", average))
                            .foregroundStyle(NoopHTMLColor.inkSoft.opacity(0.45))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                            .annotation(position: .top, alignment: .leading, spacing: 3) {
                                Text("avg \(format(average))")
                                    .font(NoopHTMLFont.sans(10.5, weight: .semibold))
                                    .foregroundStyle(NoopHTMLColor.inkSoft)
                                    .padding(.horizontal, 6).frame(height: 18)
                                    .background(NoopHTMLColor.cardRaised, in: Capsule())
                            }
                    }
                    if let selection {
                        RuleMark(x: .value("Selected", selection))
                            .foregroundStyle(NoopHTMLColor.inkSoft.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    }
                }
                .chartXScale(domain: -0.5...Double(n) - 0.5)
                .chartXAxis {
                    AxisMarks(values: Array(stride(from: 0, to: n, by: tickEvery))) { v in
                        AxisValueLabel {
                            if let i = v.as(Int.self) {
                                Text(window.tick(i)).font(NoopHTMLFont.sans(10)).foregroundStyle(NoopHTMLColor.muted)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { v in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.06))
                        AxisValueLabel {
                            if let d = v.as(Double.self) {
                                Text(format(d)).font(NoopHTMLFont.sans(9.5)).foregroundStyle(NoopHTMLColor.muted)
                            }
                        }
                    }
                }
                .stickyChartSelection($selection)
            }
        }
    }
}

/// Chart selection that stays where the finger left it, so the header keeps the chosen point;
/// it clears when the page changes period or figure.
struct NoopStickyChartSelection: ViewModifier {
    @Binding var selection: Int?
    @State private var live: Int?

    func body(content: Content) -> some View {
        content
            .chartXSelection(value: $live)
            .onChange(of: live) { if let live { selection = live } }
            .sensoryFeedback(.selection, trigger: selection)
    }
}

extension View {
    func stickyChartSelection(_ selection: Binding<Int?>) -> some View {
        modifier(NoopStickyChartSelection(selection: selection))
    }
}

extension NoopFitnessMeasureChart.Style: Equatable {}

/// "Running total by day" under a chart.
struct NoopFitnessChartCaption: View {
    let text: String
    var body: some View {
        Text(text).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.muted)
            .frame(maxWidth: .infinity)
    }
}

/// Bars or running total, for measures that add up.
struct NoopFitnessStyleToggle: View {
    @Binding var running: Bool
    var body: some View {
        HStack(spacing: 2) {
            button("chart.bar.fill", on: !running) { running = false }
            button("chart.line.uptrend.xyaxis", on: running) { running = true }
        }
        .padding(3)
        .background(Color.white.opacity(0.05), in: Capsule())
    }

    private func button(_ symbol: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(NoopMotion.swap) { action() } } label: {
            Image(systemName: symbol).font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(on ? NoopHTMLColor.ink : NoopHTMLColor.muted)
                .frame(width: 34, height: 26)
                .background(on ? Color.white.opacity(0.1) : .clear, in: Capsule())
        }
        .buttonStyle(NoopHTMLPressStyle())
        .accessibilityLabel(symbol.contains("bar") ? "Per period" : "Running total")
    }
}
#endif
