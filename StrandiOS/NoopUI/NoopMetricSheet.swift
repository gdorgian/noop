#if os(iOS)
import SwiftUI
import Charts
import WhoopStore

// NoopMetricSheet — the one template every metric opens in.
//
// Modelled on how Bevel presents a measure, and drawn in the handoff's vocabulary: a close button and a
// centred title; the selected value, its date and where it sits against your own normal; a chip per
// related measure; a chart of the period with your normal band, an average line and points coloured by
// zone; the period bar; then the same three cards for every metric — what the zones mean, how the
// trend has moved over 3 to 90 days, and what the number is. A new metric is a `NoopMetric` value, never a
// new screen.

// MARK: - Model

/// One measure the sheet can show.
struct NoopMetric: Identifiable {
    /// A named zone of the value: "Poor", "Normal", "Optimal".
    struct Zone {
        let label: String
        let range: Range<Double>
        let color: Color
    }

    let id: String
    let title: String
    /// Short chip label.
    let short: String
    let unit: String
    var decimals = 0
    /// True when up is good, false when down is good, nil when neither (it only matters to the arrows).
    var higherIsBetter: Bool? = true
    /// Fixed zones (Recovery). Empty: the sheet colours by your own normal instead.
    var zones: [Zone] = []
    /// The chart's fixed scale, when the measure has one (0–100 for a percentage).
    var scale: ClosedRange<Double>? = nil
    let about: String
    /// The daily value from a stored day.
    let value: (DailyMetric) -> Double?

    func format(_ v: Double) -> String {
        decimals == 0 ? "\(Int(v.rounded()))" : String(format: "%.\(decimals)f", v)
    }
}

/// A dated reading.
struct NoopMetricPoint: Identifiable, Equatable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// Your own normal: the middle of the last 30 days' readings (mean ± one standard deviation).
struct NoopMetricNormal: Equatable {
    let low: Double
    let high: Double
    let mean: Double

    init?(_ values: [Double]) {
        guard values.count >= 5 else { return nil }
        let m = values.reduce(0, +) / Double(values.count)
        let sd = (values.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(values.count - 1)).squareRoot()
        mean = m
        low = m - sd
        high = m + sd
    }

    enum Status { case below, within, above }
    func status(_ v: Double) -> Status { v < low ? .below : v > high ? .above : .within }
}

/// How the 7-day average moved over a span: the latest week's mean against the week `days` ago.
struct NoopMetricTrend: Identifiable {
    let days: Int
    let change: Double?
    let line: [Double]
    var id: Int { days }

    static func all(_ points: [NoopMetricPoint], spans: [Int] = [3, 7, 14, 30, 90]) -> [NoopMetricTrend] {
        let cal = Calendar.current
        let byDay = Dictionary(points.map { (cal.startOfDay(for: $0.date), $0.value) }, uniquingKeysWith: { a, _ in a })
        guard let last = byDay.keys.max() else { return spans.map { .init(days: $0, change: nil, line: []) } }
        func rolling(_ end: Date) -> Double? {
            let vs = (0..<7).compactMap { byDay[cal.date(byAdding: .day, value: -$0, to: end) ?? end] }
            return vs.count >= 3 ? vs.reduce(0, +) / Double(vs.count) : nil
        }
        return spans.map { span in
            let line = (0...span).reversed().compactMap { rolling(cal.date(byAdding: .day, value: -$0, to: last) ?? last) }
            guard let now = rolling(last), let then = rolling(cal.date(byAdding: .day, value: -span, to: last) ?? last),
                  then != 0, line.count >= 2 else { return .init(days: span, change: nil, line: line) }
            return .init(days: span, change: (now - then) / abs(then), line: line)
        }
    }
}

// MARK: - Metric catalogue

extension NoopMetric {
    static let recovery = NoopMetric(
        id: "recovery", title: "Recovery", short: "Recovery", unit: "%",
        zones: [.init(label: "Poor", range: 0..<34, color: NoopHTMLColor.red),
                .init(label: "Normal", range: 34..<67, color: NoopHTMLColor.warm),
                .init(label: "Optimal", range: 67..<101, color: NoopHTMLColor.green)],
        scale: 0...100,
        about: "How ready your body is for strain today, from last night's heart rate variability, resting heart rate and sleep, each against your own recent baseline.",
        value: { $0.recovery })

    static let hrv = NoopMetric(
        id: "hrv", title: "Heart rate variability", short: "HRV", unit: "ms",
        about: "The beat-to-beat variation in your heart rhythm during sleep. Higher than your own normal usually means you are well recovered; a run of low nights often comes before illness or after hard training.",
        value: { $0.avgHrv })

    static let restingHR = NoopMetric(
        id: "rhr", title: "Resting heart rate", short: "Resting HR", unit: "bpm", higherIsBetter: false,
        about: "Your lowest sustained heart rate while asleep. It falls as fitness improves and rises with stress, illness, alcohol and late meals.",
        value: { $0.restingHr.map(Double.init) })

    static let respiration = NoopMetric(
        id: "resp", title: "Respiratory rate", short: "Respiration", unit: "/min", decimals: 1, higherIsBetter: nil,
        about: "Breaths per minute while asleep. It is very stable from night to night, so a rise of one or more breaths above your normal is worth noticing.",
        value: { $0.respRateBpm })

    static let spo2 = NoopMetric(
        id: "spo2", title: "Blood oxygen", short: "SpO₂", unit: "%", decimals: 1,
        about: "The average oxygen saturation of your blood during sleep. Most healthy readings sit between 95 and 100 %.",
        value: { $0.spo2Pct })

    static let skinTemp = NoopMetric(
        id: "temp", title: "Skin temperature", short: "Skin temp", unit: "°C", decimals: 1, higherIsBetter: nil,
        about: "How far your skin temperature during sleep sat from your own baseline. A sustained rise can come with illness, the menstrual cycle or a warm room.",
        value: { $0.skinTempDevC })

    /// The measures that open together, as chips on one sheet.
    static let vitals: [NoopMetric] = [.recovery, .hrv, .restingHR, .respiration, .spo2, .skinTemp]
}

// MARK: - Sheet

/// Opens the shared sheet on one metric of a group: `navigation.metricSheet = .init(metricID: "hrv")`.
struct NoopMetricSheetRequest: Identifiable, Equatable {
    var metricID: String
    var group: String = "vitals"
    var id: String { group + "." + metricID }

    var metrics: [NoopMetric] { NoopMetric.vitals }
}

/// The period the chart shows.
enum NoopMetricRange: String, CaseIterable, Identifiable {
    case month = "30D", quarter = "3M", half = "6M", year = "1Y"
    var id: String { rawValue }
    var days: Int { switch self { case .month: 30; case .quarter: 91; case .half: 182; case .year: 365 } }
}

struct NoopMetricSheet: View {
    let metrics: [NoopMetric]
    @State var selectedID: String
    @EnvironmentObject private var repo: Repository
    @Environment(\.dismiss) private var dismiss
    @Environment(\.noopAccent) private var accent

    @State private var days: [DailyMetric] = []
    @State private var range: NoopMetricRange = .month
    @State private var offset = 0
    @State private var picked: Date?

    private var metric: NoopMetric { metrics.first { $0.id == selectedID } ?? metrics[0] }

    /// Every reading of the selected metric, oldest first.
    private var all: [NoopMetricPoint] {
        days.compactMap { d in
            guard let v = metric.value(d), let date = Self.dayFormatter.date(from: d.day) else { return nil }
            return NoopMetricPoint(date: date, value: v)
        }.sorted { $0.date < $1.date }
    }

    private var window: ClosedRange<Date> {
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: -range.days * offset, to: cal.startOfDay(for: Date())) ?? Date()
        let start = cal.date(byAdding: .day, value: -(range.days - 1), to: end) ?? end
        return start...end.addingTimeInterval(86_399)
    }

    private var shown: [NoopMetricPoint] { all.filter { window.contains($0.date) } }

    /// Your normal as of the latest reading in view: the 30 days up to it, so an old period is judged
    /// against what was normal then, and a gap since the last reading does not empty it.
    private var normal: NoopMetricNormal? {
        let anchor = shown.last?.date ?? all.last { $0.date <= window.upperBound }?.date ?? window.upperBound
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: anchor) ?? anchor
        return NoopMetricNormal(all.filter { $0.date > cutoff && $0.date <= anchor }.map(\.value))
    }

    /// The point the hero reads: the one you touched, else the latest in the window.
    private var focus: NoopMetricPoint? {
        if let picked, let p = shown.min(by: { abs($0.date.timeIntervalSince(picked)) < abs($1.date.timeIntervalSince(picked)) }) { return p }
        return shown.last
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: NoopSpace.l) {
                    hero
                    if metrics.count > 1 { chips }
                    chartCard
                    NoopMetricRangeBar(range: $range, offset: $offset, canGoBack: canGoBack)
                    if !metric.zones.isEmpty { zonesCard }
                    trendsCard
                    aboutCard
                }
                .padding(.horizontal, NoopSpace.l)
                .padding(.top, NoopSpace.xs)
                .padding(.bottom, NoopSpace.xxl)
            }
            .scrollIndicators(.hidden)
        }
        .background(NoopHTMLColor.canvas.ignoresSafeArea())
        .task { await load() }
        .onChange(of: selectedID) { _, _ in picked = nil; openOnLatest() }
        .onChange(of: range) { _, _ in picked = nil; offset = 0 }
        .onChange(of: offset) { _, _ in picked = nil }
    }

    private var canGoBack: Bool {
        guard let first = all.first?.date else { return false }
        return first < window.lowerBound
    }

    // MARK: Parts

    private var topBar: some View {
        ZStack {
            Text(metric.title).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                .lineLimit(1).padding(.horizontal, 60)
            HStack {
                NoopIconButton(systemImage: "xmark", size: .small, label: "Close") { dismiss() }
                Spacer()
            }
        }
        .padding(.horizontal, NoopSpace.l)
        .padding(.top, NoopSpace.l)
        .padding(.bottom, NoopSpace.s)
    }

    private var hero: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(focus.map { metric.format($0.value) } ?? "—")
                        .font(NoopHTMLFont.outfit(NoopType.title1 + 8, weight: .medium)).monospacedDigit()
                        .foregroundStyle(NoopHTMLColor.ink)
                        .contentTransition(.numericText())
                    if focus != nil {
                        Text(metric.unit).font(NoopHTMLFont.sans(NoopType.subhead, weight: .medium)).foregroundStyle(NoopHTMLColor.copy)
                    }
                }
                Text(focus.map { $0.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()) } ?? "No readings in this period")
                    .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
            }
            Spacer(minLength: NoopSpace.s)
            if let focus, let status = statusText(focus.value) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(status.text).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(status.color)
                    if let normal {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2).fill(accent.fill.opacity(0.25)).frame(width: 14, height: 10)
                            Text("\(metric.format(normal.low))–\(metric.format(normal.high))\(metric.unit == "%" ? "%" : "")")
                                .font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium)).monospacedDigit()
                                .foregroundStyle(NoopHTMLColor.inkSoft)
                        }
                        .accessibilityLabel("Your normal range")
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: focus)
    }

    private func statusText(_ v: Double) -> (text: String, color: Color)? {
        if let zone = metric.zones.first(where: { $0.range.contains(v) }) { return (zone.label, zone.color) }
        guard let normal else { return nil }
        switch normal.status(v) {
        case .within: return ("Normal", NoopHTMLColor.inkSoft)
        case .below: return ("Below normal", tone(up: false))
        case .above: return ("Above normal", tone(up: true))
        }
    }

    /// Good moves green, bad moves amber, neutral ones stay quiet.
    private func tone(up: Bool) -> Color {
        guard let better = metric.higherIsBetter else { return NoopHTMLColor.blueLight }
        return up == better ? NoopHTMLColor.green : NoopHTMLColor.warm
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: NoopSpace.xs) {
                ForEach(metrics) { m in
                    NoopChip(title: m.short, isOn: m.id == selectedID) { selectedID = m.id }
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    private var chartCard: some View {
        NoopMetricChart(points: shown, window: window, metric: metric, normal: normal, picked: $picked)
            .frame(height: 260)
            .padding(.vertical, NoopSpace.m)
            .padding(.horizontal, NoopSpace.s)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private var zonesCard: some View {
        NoopMetricCard(title: "\(metric.short) zones") {
            GeometryReader { geo in
                let span = (metric.scale?.upperBound ?? 100) - (metric.scale?.lowerBound ?? 0)
                HStack(spacing: 4) {
                    ForEach(Array(metric.zones.enumerated()), id: \.offset) { _, z in
                        Capsule().fill(z.color)
                            .frame(width: max(8, (geo.size.width - 8) * (min(z.range.upperBound, 100) - z.range.lowerBound) / span))
                    }
                }
            }
            .frame(height: 10)
            VStack(alignment: .leading, spacing: NoopSpace.s) {
                ForEach(Array(metric.zones.enumerated()), id: \.offset) { i, z in
                    HStack(spacing: NoopSpace.s) {
                        Circle().fill(z.color).frame(width: 9, height: 9)
                        Text(z.label).font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium)).foregroundStyle(NoopHTMLColor.ink)
                        Text(zoneRange(z, index: i)).font(NoopHTMLFont.sans(NoopType.footnote)).monospacedDigit()
                            .foregroundStyle(NoopHTMLColor.copy)
                        Spacer()
                        Text(share(of: z)).font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium)).monospacedDigit()
                            .foregroundStyle(NoopHTMLColor.inkSoft)
                    }
                }
            }
            .padding(.top, NoopSpace.xs)
            Text("Share of days in this period.").font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.muted)
        }
    }

    private func zoneRange(_ z: NoopMetric.Zone, index: Int) -> String {
        if index == 0 { return "below \(metric.format(z.range.upperBound))\(metric.unit)" }
        if index == metric.zones.count - 1 { return "\(metric.format(z.range.lowerBound))\(metric.unit) and up" }
        return "\(metric.format(z.range.lowerBound))–\(metric.format(z.range.upperBound))\(metric.unit)"
    }

    private func share(of z: NoopMetric.Zone) -> String {
        guard !shown.isEmpty else { return "—" }
        let n = shown.filter { z.range.contains($0.value) }.count
        return "\(Int((Double(n) / Double(shown.count) * 100).rounded()))%"
    }

    private var trendsCard: some View {
        let trends = NoopMetricTrend.all(all.filter { $0.date <= window.upperBound })
        let lastDay = all.last { $0.date <= window.upperBound }?.date
        return NoopMetricCard(title: "Trend",
                              subtitle: lastDay.map { "Your 7-day average up to \($0.formatted(.dateTime.day().month(.abbreviated))), against the same span before" }
                                ?? "Your 7-day average, against the same span before") {
            VStack(spacing: 0) {
                ForEach(Array(trends.enumerated()), id: \.element.id) { i, t in
                    HStack(spacing: NoopSpace.s) {
                        Text("\(t.days)-day").font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium)).foregroundStyle(NoopHTMLColor.ink)
                            .frame(width: 64, alignment: .leading)
                        changeLabel(t.change)
                        Spacer(minLength: NoopSpace.xs)
                        NoopSparkline(values: t.line,
                                      color: t.change.map { abs($0) < 0.01 ? NoopHTMLColor.muted : tone(up: $0 >= 0) } ?? NoopHTMLColor.muted)
                            .frame(width: 96, height: 28)
                    }
                    .frame(minHeight: 48)
                    .overlay(alignment: .top) {
                        if i > 0 { Rectangle().fill(NoopHTMLColor.border).frame(height: 0.5) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func changeLabel(_ change: Double?) -> some View {
        if let change, abs(change) < 0.01 {
            HStack(spacing: 6) {
                Image(systemName: "equal").font(.system(size: 11, weight: .bold)).foregroundStyle(NoopHTMLColor.canvas)
                    .frame(width: 20, height: 20).background(NoopHTMLColor.muted, in: Circle())
                Text("No change").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(NoopHTMLColor.inkSoft)
            }
        } else if let change {
            let up = change >= 0
            HStack(spacing: 6) {
                Image(systemName: up ? "arrow.up" : "arrow.down")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(NoopHTMLColor.canvas)
                    .frame(width: 20, height: 20).background(tone(up: up), in: Circle())
                Text("\(up ? "+" : "−")\(Int((abs(change) * 100).rounded()))%")
                    .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).monospacedDigit().foregroundStyle(NoopHTMLColor.ink)
            }
        } else {
            Text("Not enough data").font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.muted)
        }
    }

    private var aboutCard: some View {
        NoopMetricCard(title: "About \(metric.title.lowercased())") {
            Text(metric.about).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.inkSoft)
                .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            if let normal {
                Text("Your normal, the middle of your last 30 days, is \(metric.format(normal.low))–\(metric.format(normal.high)) \(metric.unit).")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func load() async {
        let cal = Calendar.current
        let from = cal.date(byAdding: .day, value: -400, to: Date()) ?? Date()
        days = await repo.dailyMetrics(fromDay: Self.dayFormatter.string(from: from), toDay: Self.dayFormatter.string(from: Date()))
        if !metrics.contains(where: { $0.id == selectedID }), let first = metrics.first { selectedID = first.id }
        openOnLatest()
    }

    /// Open on the shortest period that holds the latest reading, so the sheet never starts on an empty chart.
    private func openOnLatest() {
        guard let latest = all.last?.date else { return }
        let age = Calendar.current.dateComponents([.day], from: latest, to: Date()).day ?? 0
        offset = 0
        range = NoopMetricRange.allCases.first { $0.days > age } ?? .year
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

// MARK: - Pieces

/// A titled card below the chart; every section of the sheet is one.
struct NoopMetricCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: NoopSpace.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(NoopHTMLFont.sans(NoopType.body, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                if let subtitle {
                    Text(subtitle).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                }
            }
            content
        }
        .padding(NoopSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }
}

/// The period bar: earlier · 30D 3M 6M 1Y · later.
struct NoopMetricRangeBar: View {
    @Binding var range: NoopMetricRange
    @Binding var offset: Int
    var canGoBack: Bool

    var body: some View {
        HStack(spacing: NoopSpace.xs) {
            NoopIconButton(systemImage: "chevron.left", size: .small, label: "Earlier") { offset += 1 }
                .disabled(!canGoBack).opacity(canGoBack ? 1 : 0.35)
            NoopTabs(options: NoopMetricRange.allCases.map { ($0.rawValue, $0) }, selection: $range)
            NoopIconButton(systemImage: "chevron.right", size: .small, label: "Later") { offset -= 1 }
                .disabled(offset == 0).opacity(offset == 0 ? 0.35 : 1)
        }
        .sensoryFeedback(.selection, trigger: offset)
    }
}

/// A small line for a trend row.
struct NoopSparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            if values.count >= 2, let lo = values.min(), let hi = values.max() {
                let span = max(hi - lo, 0.0001)
                let pts = values.enumerated().map { i, v in
                    CGPoint(x: geo.size.width * CGFloat(i) / CGFloat(values.count - 1),
                            y: geo.size.height * (1 - CGFloat((v - lo) / span)) * 0.8 + geo.size.height * 0.1)
                }
                ZStack {
                    Path { p in
                        p.move(to: CGPoint(x: pts[0].x, y: geo.size.height))
                        pts.forEach { p.addLine(to: $0) }
                        p.addLine(to: CGPoint(x: pts.last!.x, y: geo.size.height))
                    }
                    .fill(LinearGradient(colors: [color.opacity(0.22), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                    Path { p in p.addLines(pts) }
                        .stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                }
            } else {
                Rectangle().fill(NoopHTMLColor.muted.opacity(0.5)).frame(height: 1.5)
                    .frame(maxHeight: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The period chart: your normal as a band, the average as a dotted line with its value, the readings as
/// a line whose points take their zone's colour, and a touch to read any day.
struct NoopMetricChart: View {
    let points: [NoopMetricPoint]
    let window: ClosedRange<Date>
    let metric: NoopMetric
    let normal: NoopMetricNormal?
    @Binding var picked: Date?

    @Environment(\.noopAccent) private var accent

    private var average: Double? {
        points.isEmpty ? nil : points.map(\.value).reduce(0, +) / Double(points.count)
    }

    private var yDomain: ClosedRange<Double> {
        if let s = metric.scale { return s }
        let vs = points.map(\.value) + [normal?.low, normal?.high].compactMap { $0 }
        guard let lo = vs.min(), let hi = vs.max() else { return 0...1 }
        let pad = max((hi - lo) * 0.25, abs(hi) * 0.05, 1)
        return (lo - pad)...(hi + pad)
    }

    private func color(_ v: Double) -> Color {
        if let z = metric.zones.first(where: { $0.range.contains(v) }) { return z.color }
        guard let normal else { return accent.fill }
        switch normal.status(v) {
        case .within: return accent.fill
        case .below: return metric.higherIsBetter == nil ? NoopHTMLColor.blueLight : metric.higherIsBetter! ? NoopHTMLColor.warm : NoopHTMLColor.green
        case .above: return metric.higherIsBetter == nil ? NoopHTMLColor.blueLight : metric.higherIsBetter! ? NoopHTMLColor.green : NoopHTMLColor.warm
        }
    }

    var body: some View {
        if points.isEmpty {
            VStack(spacing: 6) {
                Text("No readings in this period").font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                Text("Step back with the arrows, or choose a longer span.").font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            chart
        }
    }

    private var chart: some View {
        let sparse = points.count <= 45
        return Chart {
            if let normal {
                RectangleMark(xStart: .value("Start", window.lowerBound), xEnd: .value("End", window.upperBound),
                              yStart: .value("Low", normal.low), yEnd: .value("High", normal.high))
                    .foregroundStyle(accent.fill.opacity(0.10))
            }
            ForEach(points) { p in
                LineMark(x: .value("Day", p.date, unit: .day), y: .value(metric.short, p.value))
                    .foregroundStyle(accent.fill.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                if sparse || p.date == picked {
                    PointMark(x: .value("Day", p.date, unit: .day), y: .value(metric.short, p.value))
                        .foregroundStyle(color(p.value))
                        .symbolSize(p.date == picked ? 90 : 34)
                }
            }
            if let average {
                RuleMark(y: .value("Average", average))
                    .foregroundStyle(NoopHTMLColor.inkSoft.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .annotation(position: .top, alignment: .leading, spacing: 4) {
                        Text("Avg \(metric.format(average))\(metric.unit == "%" ? "%" : "")")
                            .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).monospacedDigit()
                            .foregroundStyle(NoopHTMLColor.canvas)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(NoopHTMLColor.inkSoft, in: Capsule())
                    }
            }
            if let picked {
                RuleMark(x: .value("Picked", picked, unit: .day))
                    .foregroundStyle(NoopHTMLColor.inkSoft.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartXScale(domain: window.lowerBound...window.upperBound)
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { v in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                AxisValueLabel().font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.muted)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.muted)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            guard let frame = proxy.plotFrame else { return }
                            let x = g.location.x - geo[frame].origin.x
                            if let d: Date = proxy.value(atX: x) {
                                let near = points.min { abs($0.date.timeIntervalSince(d)) < abs($1.date.timeIntervalSince(d)) }
                                if near?.date != picked { picked = near?.date }
                            }
                        })
            }
        }
        .sensoryFeedback(.selection, trigger: picked)
    }
}
#endif
