#if os(iOS)
import SwiftUI
import Charts
import WhoopStore
import StrandAnalytics

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
    /// Durations in hours read as "7h 08m", the way the rest of the app writes them.
    var isDuration = false
    /// When set, readings come from this catalogue series instead of the daily rows.
    var series: Series? = nil
    /// Who the zones are standardized for, when they come from a population reference.
    var zoneCaption: String? = nil

    struct Series {
        let key: String
        let source: String
        /// Stored value → shown value (minutes → hours for a duration).
        var transform: (Double) -> Double = { $0 }
    }

    func format(_ v: Double) -> String {
        if isDuration {
            let m = Int((v * 60).rounded())
            return m >= 60 ? "\(m / 60)h \(String(format: "%02d", m % 60))m" : "\(m)m"
        }
        return decimals == 0 ? "\(Int(v.rounded()))" : String(format: "%.\(decimals)f", v)
    }

    /// The unit beside a value; a duration carries its own.
    var shownUnit: String { isDuration ? "" : unit }
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
    /// The same move in the measure's own units.
    var delta: Double? = nil
    var id: Int { days }

    static func all(_ points: [NoopMetricPoint], spans: [Int] = [3, 7, 14, 30, 90]) -> [NoopMetricTrend] {
        let cal = Calendar.current
        let byDay = Dictionary(points.map { (cal.startOfDay(for: $0.date), $0.value) }, uniquingKeysWith: { a, _ in a })
        guard let last = byDay.keys.max() else { return spans.map { .init(days: $0, change: nil, line: []) } }
        // A daily measure averages the readings in the week; a sparse one (weigh-ins, body fat) has
        // fewer than three, so the week takes its latest reading in the four months before instead.
        let sortedDays = byDay.keys.sorted()
        func rolling(_ end: Date) -> Double? {
            let vs = (0..<7).compactMap { byDay[cal.date(byAdding: .day, value: -$0, to: end) ?? end] }
            if vs.count >= 3 { return vs.reduce(0, +) / Double(vs.count) }
            guard let floor = cal.date(byAdding: .day, value: -120, to: end),
                  let day = sortedDays.last(where: { $0 <= end && $0 > floor }) else { return nil }
            return byDay[day]
        }
        return spans.map { span in
            let line = (0...span).reversed().compactMap { rolling(cal.date(byAdding: .day, value: -$0, to: last) ?? last) }
            guard let now = rolling(last), let then = rolling(cal.date(byAdding: .day, value: -span, to: last) ?? last),
                  then != 0, line.count >= 2 else { return .init(days: span, change: nil, line: line) }
            return .init(days: span, change: (now - then) / abs(then), line: line, delta: now - then)
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

    static let asleep = NoopMetric(
        id: "asleep", title: "Time asleep", short: "Asleep", unit: "h", decimals: 1,
        about: "Every minute staged as sleep in your main night, without the time awake in bed. Most adults need seven to nine hours; your own need is on Rest.",
        value: { $0.totalSleepMin.map { $0 / 60 } }, isDuration: true)

    static let efficiency = NoopMetric(
        id: "efficiency", title: "Sleep efficiency", short: "Efficiency", unit: "%",
        zones: [.init(label: "Restless", range: 0..<80, color: NoopHTMLColor.warm),
                .init(label: "Normal", range: 80..<90, color: NoopHTMLColor.night),
                .init(label: "Efficient", range: 90..<101, color: NoopHTMLColor.green)],
        scale: 50...100,
        about: "The share of your time in bed spent asleep. Above 85 % is considered good; it falls with long wakes in the night and long lie-ins awake.",
        value: { $0.efficiency.map { $0 <= 1 ? $0 * 100 : $0 } })

    static let deep = NoopMetric(
        id: "deep", title: "Deep sleep", short: "Deep", unit: "h", decimals: 1,
        about: "The slowest, most restorative stage, mostly in the first half of the night. It shrinks with alcohol, late meals and a warm room.",
        value: { $0.deepMin.map { $0 / 60 } }, isDuration: true)

    static let rem = NoopMetric(
        id: "rem", title: "REM sleep", short: "REM", unit: "h", decimals: 1,
        about: "The dreaming stage, mostly in the second half of the night, so a short night cuts it first.",
        value: { $0.remMin.map { $0 / 60 } }, isDuration: true)

    static let disturbances = NoopMetric(
        id: "wakes", title: "Disturbances", short: "Wakes", unit: "", higherIsBetter: false,
        about: "How many times sleep was broken by a wake long enough to stage. A few a night is normal.",
        value: { $0.disturbances.map(Double.init) })

    static let sleep: [NoopMetric] = [.asleep, .efficiency, .deep, .rem, .disturbances, .respiration]
}

// MARK: - Sheet

/// Opens the shared sheet on one metric of a group: `navigation.metricSheet = .init(metricID: "hrv")`.
struct NoopMetricSheetRequest: Identifiable, Equatable {
    var metricID: String
    /// Which chips open beside it: "vitals" or "sleep".
    var group: String = "vitals"
    /// For group "marker": the other catalogue ids to offer as chips beside it, in order (a page's
    /// whole Trends list). Empty opens the one measure alone.
    var peers: [String] = []
    var id: String { group + "." + metricID }

    var metrics: [NoopMetric] {
        switch group {
        case "sleep": NoopMetric.sleep
        case "marker" where !peers.isEmpty:
            peers.compactMap { id in MetricCatalog.all.first { $0.id == id }.map(NoopMetric.init(marker:)) }
        case "marker": MetricCatalog.all.first { $0.id == metricID }.map { [NoopMetric(marker: $0)] } ?? NoopMetric.vitals
        default: NoopMetric.vitals
        }
    }
}

extension NoopMetric {
    /// Percent measures the store keeps as a 0–1 fraction; read back as a percentage.
    static let fractionKeys: Set<String> = ["sleep_efficiency"]

    /// Any catalogue measure as a sheet metric: Trends' pinned markers and their See all list.
    init(marker d: MetricDescriptor) {
        let minutes = d.unit == "min"
        let norms = NoopMarkerNorms.ranges(for: d.key, profile: .current)
        // Mass and temperature are stored in kg and °C; show them in the wearer's units. Neither has
        // norm zones, so only the values and the label change.
        let defaults = UserDefaults.standard
        let system = UnitSystem(rawValue: defaults.string(forKey: UnitPrefs.systemKey) ?? "") ?? .metric
        let fahrenheit = UnitPrefs.resolveTemperature(system: system,
                                                       override: defaults.string(forKey: UnitPrefs.temperatureKey) ?? "") == .fahrenheit
        let pounds = d.unit == "kg" && system == .imperial
        let toF = d.unit == "°C" && fahrenheit
        let unit = minutes ? "h" : pounds ? "lb" : toF ? "°F" : d.unit
        let transform: (Double) -> Double = minutes ? { $0 / 60 }
            : d.unit == "%" && Self.fractionKeys.contains(d.key) ? { $0 <= 1 ? $0 * 100 : $0 }
            : pounds ? UnitFormatter.kgToPounds
            // Skin temperature is either an absolute wrist reading or a deviation; only the first takes +32.
            : toF ? { VitalBands.isAbsoluteSkinTemp($0) ? UnitFormatter.celsiusToFahrenheit($0) : UnitFormatter.celsiusDeltaToFahrenheit($0) }
            : { $0 }
        self.init(id: d.id, title: d.auraTitle, short: d.auraTitle, unit: unit, decimals: minutes ? 1 : d.decimals,
                  higherIsBetter: d.higherIsBetter, zones: norms?.zones ?? [], scale: norms?.scale,
                  about: d.description ?? "\(d.auraTitle), from \(d.sourceLabel).",
                  value: { _ in nil }, isDuration: minutes,
                  series: .init(key: d.key, source: d.source, transform: transform),
                  zoneCaption: norms?.caption)
    }
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
    /// Readings of a catalogue-series metric, loaded when it is selected.
    @State private var seriesPoints: [NoopMetricPoint] = []
    /// A day chosen on the calendar: the period ends there instead of today.
    @State private var anchor: Date?
    @State private var choosingDay = false
    /// How far the figure has slid under the title, 0 to 1.
    @State private var collapse: CGFloat = 0
    /// The period bar is holding at the top.
    @State private var pinned = false

    private var metric: NoopMetric { metrics.first { $0.id == selectedID } ?? metrics[0] }

    /// Every reading of the selected metric, oldest first.
    private var all: [NoopMetricPoint] {
        if metric.series != nil { return seriesPoints }
        return days.compactMap { d in
            guard let v = metric.value(d), let date = Self.dayFormatter.date(from: d.day) else { return nil }
            return NoopMetricPoint(date: date, value: v)
        }.sorted { $0.date < $1.date }
    }

    private var window: ClosedRange<Date> {
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: -range.days * offset, to: cal.startOfDay(for: anchor ?? Date())) ?? Date()
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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: NoopSpace.l, pinnedViews: [.sectionHeaders]) {
                hero
                    // The figure gives way as it slides under the title.
                    .opacity(1 - collapse)
                    .scaleEffect(1 - 0.05 * collapse, anchor: .topLeading)
                    .blur(radius: 4 * collapse)
                if metrics.count > 1 { chips }
                chartCard
                // The period stays to hand while the cards below are read (27 Oct 2026).
                Section {
                    if !metric.zones.isEmpty { zonesCard }
                    trendsCard
                    aboutCard
                } header: {
                    NoopMetricRangeBar(range: $range, offset: $offset, canGoBack: canGoBack,
                                       anchored: anchor != nil, calendar: { choosingDay = true })
                        .padding(.vertical, NoopSpace.xs)
                        .background {
                            if pinned {
                                NoopHTMLColor.canvas
                                    .padding(.horizontal, -NoopSpace.l)
                                    .mask(LinearGradient(stops: [.init(color: .black, location: 0.75), .init(color: .clear, location: 1)],
                                                         startPoint: .top, endPoint: .bottom))
                                    .padding(.top, -200)
                            }
                        }
                        .onGeometryChange(for: Bool.self) { $0.frame(in: .scrollView).minY <= 1 } action: { pinned = $0 }
                }
            }
            .padding(.horizontal, NoopSpace.l)
            .padding(.top, NoopSpace.xs)
            .padding(.bottom, NoopSpace.xxl)
        }
        .scrollIndicators(.hidden)
        .modifier(NoopScrollCollapse(collapse: $collapse))
        .safeAreaInset(edge: .top, spacing: 0) {
            topBar
                .background(NoopHTMLColor.canvas.opacity(collapse > 0.02 ? 1 : 0))
                // Content fades into the bar rather than meeting it at a line.
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [NoopHTMLColor.canvas, NoopHTMLColor.canvas.opacity(0)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 22)
                        .offset(y: 22)
                        .opacity(collapse)
                        .allowsHitTesting(false)
                }
        }
        .background(NoopHTMLColor.canvas.ignoresSafeArea())
        .sheet(isPresented: $choosingDay) {
            NoopMetricDayPicker(anchor: $anchor, range: range, earliest: all.first?.date)
                .noopFloatingSheet(height: 520)
        }
        .task(id: "\(repo.refreshSeq)|\(selectedID)") { await load() }
        .onChange(of: selectedID) { _, _ in picked = nil; openOnLatest() }
        .onChange(of: range) { _, _ in picked = nil; offset = 0 }
        .onChange(of: offset) { _, _ in picked = nil }
        .onChange(of: anchor) { _, _ in picked = nil; offset = 0 }
    }

    private var canGoBack: Bool {
        guard let first = all.first?.date else { return false }
        return first < window.lowerBound
    }

    // MARK: Parts

    private var topBar: some View {
        NoopMetricTopBar(title: metric.title) { dismiss() }
    }

    private var hero: some View {
        let status = focus.flatMap { statusText($0.value) }
        return NoopMetricHero(
            value: focus.map { metric.format($0.value) } ?? "—",
            unit: focus == nil || metric.shownUnit.isEmpty ? nil : metric.shownUnit,
            caption: focus.map { $0.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()) }
                ?? "No readings in this period",
            status: status,
            range: status == nil ? nil : normal.map {
                "\(metric.format($0.low))–\(metric.format($0.high))\(metric.unit == "%" ? "%" : "")"
            })
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

    /// Bevel's range card: the zones as a segmented bar with your reading marked on it, the name of the
    /// zone it falls in, and who the zones are standardized for.
    private var zonesCard: some View {
        let reading = focus?.value
        let current = reading.flatMap { v in metric.zones.first { $0.range.contains(v) } }
        let lo = metric.scale?.lowerBound ?? metric.zones.first?.range.upperBound ?? 0
        let hi = metric.scale?.upperBound ?? metric.zones.last?.range.lowerBound ?? 100
        func at(_ v: Double) -> CGFloat { CGFloat((min(max(v, lo), hi) - lo) / max(hi - lo, 0.0001)) }
        return VStack(alignment: .leading, spacing: NoopSpace.s) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .topLeading) {
                    ForEach(Array(metric.zones.enumerated()), id: \.offset) { _, z in
                        let a = at(max(z.range.lowerBound, lo)), b = at(min(z.range.upperBound, hi))
                        let on = current?.label == z.label
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(z.color.opacity(on ? 0.9 : 0.22))
                            .frame(width: max(4, (b - a) * w - 4), height: 18)
                            .offset(x: a * w + 2, y: 8)
                    }
                    if let reading {
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 10))
                            .rotationEffect(.degrees(180))
                            .foregroundStyle(NoopHTMLColor.ink)
                            .offset(x: at(reading) * w - 5, y: 0)
                    }
                }
            }
            .frame(height: 28)
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    ForEach(Array(metric.zones.dropFirst().enumerated()), id: \.offset) { i, z in
                        let x = at(z.range.lowerBound) * geo.size.width
                        Text(zoneEdge(z.range.lowerBound, first: i == 0, last: i == metric.zones.count - 2))
                            .font(NoopHTMLFont.sans(NoopType.caption))
                            .monospacedDigit()
                            .foregroundStyle(NoopHTMLColor.copy)
                            .fixedSize()
                            .offset(x: min(max(0, x - 4), geo.size.width - 44))
                    }
                }
            }
            .frame(height: 18)
            VStack(alignment: .leading, spacing: 3) {
                (Text("Your range is ").foregroundColor(NoopHTMLColor.ink)
                 + Text(current?.label ?? "not known yet").foregroundColor(current?.color ?? NoopHTMLColor.muted))
                    .font(NoopHTMLFont.sans(NoopType.body, weight: .semibold))
                if let caption = metric.zoneCaption {
                    Text(caption).font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium)).foregroundStyle(NoopHTMLColor.inkSoft)
                }
                if let d = focus?.date {
                    Text("Reading of \(d.formatted(.dateTime.day().month(.abbreviated).year()))")
                        .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.muted)
                }
            }
            .padding(.top, NoopSpace.xxs)
        }
        .padding(NoopSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private func zoneEdge(_ v: Double, first: Bool, last: Bool) -> String {
        let unit = metric.unit == "%" ? "%" : ""
        return metric.format(v) + unit
    }

    private var trendsCard: some View {
        NoopMetricTrendCard(points: all.filter { $0.date <= window.upperBound }, higherIsBetter: metric.higherIsBetter,
                            format: { metric.format($0) + (metric.shownUnit.isEmpty ? "" : (metric.shownUnit == "%" ? "%" : " \(metric.shownUnit)")) },
                            title: metric.title)
    }

    private var aboutCard: some View {
        NoopMetricCard(title: "About \(metric.title.lowercased())") {
            Text(metric.about).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.inkSoft)
                .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            if let normal {
                Text("Your normal, the middle of your last 30 days, is \(metric.format(normal.low))–\(metric.format(normal.high)) \(metric.shownUnit).")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func load() async {
        // `repo.days` is the app's merged daily list — the strap's computed days and imported history —
        // the same rows Today and Trends read. (`dailyMetrics(fromDay:)` reads imported rows only.)
        days = repo.days
        if !metrics.contains(where: { $0.id == selectedID }), let first = metrics.first { selectedID = first.id }
        if let s = metric.series {
            let rows = await repo.exploreSeries(key: s.key, source: s.source, fullHistory: true)
            seriesPoints = rows.compactMap { r in Self.dayFormatter.date(from: r.day).map { NoopMetricPoint(date: $0, value: s.transform(r.value)) } }
        }
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

/// The sheet's header, padded for a full-width sheet. Every metric sheet, Fitness's too.
struct NoopMetricTopBar: View {
    let title: String
    let close: () -> Void

    var body: some View {
        NoopSheetHeader(title: title, close: close)
        .padding(.horizontal, NoopSpace.l)
        .padding(.top, NoopSpace.l)
        .padding(.bottom, NoopSpace.s)
    }
}

/// The figure at the top of a metric: value and unit, its date or period, and on the right where it sits
/// (a status in its colour) with the range it is judged against.
struct NoopMetricHero: View {
    let value: String
    var unit: String? = nil
    let caption: String
    var comparison: String? = nil
    var status: (text: String, color: Color)? = nil
    /// The range beside the status, drawn with a swatch of the chart's band.
    var range: String? = nil
    /// A plain line under the status when there is no range.
    var trailing: String? = nil

    @Environment(\.noopAccent) private var accent

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(NoopHTMLFont.outfit(NoopType.title1 + 8, weight: .medium)).monospacedDigit()
                        .foregroundStyle(NoopHTMLColor.ink)
                        .contentTransition(.numericText())
                        .lineLimit(1).minimumScaleFactor(0.6)
                    if let unit {
                        Text(unit).font(NoopHTMLFont.sans(NoopType.subhead, weight: .medium)).foregroundStyle(NoopHTMLColor.copy)
                    }
                }
                Text(caption).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                if let comparison {
                    Text(comparison).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.muted)
                }
            }
            Spacer(minLength: NoopSpace.s)
            VStack(alignment: .trailing, spacing: 4) {
                if let status {
                    Text(status.text).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(status.color)
                }
                if let range {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2).fill(accent.fill.opacity(0.25)).frame(width: 14, height: 10)
                        Text(range).font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium)).monospacedDigit()
                            .foregroundStyle(NoopHTMLColor.inkSoft)
                    }
                    .accessibilityLabel("Range \(range)")
                } else if let trailing {
                    Text(trailing).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: value)
    }
}

/// The trend table, for any dated series: the 7-day average now against the same span before.
struct NoopMetricTrendCard: View {
    let points: [NoopMetricPoint]
    var higherIsBetter: Bool? = true
    /// Given a formatter, changes read in the measure's own units and the card opens with the latest
    /// trend and a 30-day projection, as Bevel's Trends Analysis does. Without one, changes are percents.
    var format: ((Double) -> String)? = nil
    var title: String? = nil

    var body: some View {
        let trends = NoopMetricTrend.all(points)
        let lastDay = points.last?.date
        NoopMetricCard(title: format == nil ? "Trend" : "Trends analysis",
                       subtitle: format == nil
                         ? (lastDay.map { "Your 7-day average up to \($0.formatted(.dateTime.day().month(.abbreviated))), against the same span before" }
                            ?? "Your 7-day average, against the same span before")
                         : lastDay.map { "Last reading on \($0.formatted(.dateTime.day().month(.abbreviated).year()))" }) {
            if let format {
                headline(format)
                    .padding(.bottom, NoopSpace.xs)
            }
            VStack(spacing: 0) {
                ForEach(Array(trends.enumerated()), id: \.element.id) { i, t in
                    HStack(spacing: NoopSpace.s) {
                        Text("\(t.days)-day").font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium)).foregroundStyle(NoopHTMLColor.ink)
                            .frame(width: 64, alignment: .leading)
                        changeLabel(t)
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
            if format != nil {
                Text("Based on 7-day rolling averages.")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.muted)
            }
        }
    }

    /// The latest 7-day average beside where a straight line through the last 30 days would put it
    /// 30 days on. No projection from fewer than ten readings, and never past a bound of the readings
    /// seen so far by more than their own span.
    private func headline(_ format: (Double) -> String) -> some View {
        let recentWeek = points.suffix(7).map(\.value)
        let last = recentWeek.isEmpty ? nil : recentWeek.reduce(0, +) / Double(recentWeek.count)
        let projected = Self.projection(points)
        return HStack(alignment: .top, spacing: 0) {
            stat("Last \(title.map { $0.lowercased() } ?? "") trend", last.map(format) ?? "\u{2014}")
            Rectangle().fill(NoopHTMLColor.border).frame(width: 0.5, height: 48)
                .padding(.horizontal, NoopSpace.m)
            stat("30-day projection", projected.map(format) ?? "\u{2014}")
        }
    }

    static func projection(_ points: [NoopMetricPoint]) -> Double? {
        guard let end = points.last?.date,
              let start = Calendar.current.date(byAdding: .day, value: -30, to: end) else { return nil }
        // Thirty days of a daily measure; a sparse one falls back to its readings of the last ninety.
        var recent = points.filter { $0.date > start }
        if recent.count < 10, let wide = Calendar.current.date(byAdding: .day, value: -90, to: end) {
            recent = points.filter { $0.date > wide }
            guard recent.count >= 4 else { return nil }
        }
        let xs = recent.map { $0.date.timeIntervalSince(end) / 86_400 }, ys = recent.map(\.value)
        let mx = xs.reduce(0, +) / Double(xs.count), my = ys.reduce(0, +) / Double(ys.count)
        let sxx = xs.map { ($0 - mx) * ($0 - mx) }.reduce(0, +)
        guard sxx > 0 else { return my }
        let slope = zip(xs, ys).map { ($0 - mx) * ($1 - my) }.reduce(0, +) / sxx
        let value = my + slope * (30 - mx)
        let all = points.map(\.value)
        guard let lo = all.min(), let hi = all.max() else { return value }
        return min(max(value, lo - (hi - lo)), hi + (hi - lo))
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.replacingOccurrences(of: "  ", with: " "))
                .font(NoopHTMLFont.sans(NoopType.caption, weight: .medium)).foregroundStyle(NoopHTMLColor.copy)
                .lineLimit(1).minimumScaleFactor(0.8)
            Text(value).font(NoopHTMLFont.outfit(NoopType.title2, weight: .medium)).monospacedDigit()
                .foregroundStyle(NoopHTMLColor.ink).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tone(up: Bool) -> Color {
        guard let better = higherIsBetter else { return NoopHTMLColor.blueLight }
        return up == better ? NoopHTMLColor.green : NoopHTMLColor.warm
    }

    @ViewBuilder
    private func changeLabel(_ t: NoopMetricTrend) -> some View {
        if let change = t.change, abs(change) < 0.01 {
            HStack(spacing: 6) {
                Image(systemName: "equal").font(.system(size: 11, weight: .bold)).foregroundStyle(NoopHTMLColor.canvas)
                    .frame(width: 20, height: 20).background(NoopHTMLColor.muted, in: Circle())
                Text("No change").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(NoopHTMLColor.inkSoft)
            }
        } else if let change = t.change {
            let up = change >= 0
            HStack(spacing: 6) {
                Image(systemName: up ? "arrow.up" : "arrow.down")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(NoopHTMLColor.canvas)
                    .frame(width: 20, height: 20).background(tone(up: up), in: Circle())
                Text(amount(t, up: up))
                    .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).monospacedDigit().foregroundStyle(NoopHTMLColor.ink)
            }
        } else {
            Text("Not enough data").font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.muted)
        }
    }

    private func amount(_ t: NoopMetricTrend, up: Bool) -> String {
        if let format, let d = t.delta { return (up ? "+" : "\u{2212}") + format(abs(d)) }
        return "\(up ? "+" : "\u{2212}")\(Int((abs(t.change ?? 0) * 100).rounded()))%"
    }
}

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
    /// The period ends on a chosen day rather than today.
    var anchored = false
    /// Opens the calendar; nil leaves it out.
    var calendar: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: NoopSpace.xs) {
            NoopIconButton(systemImage: "chevron.left", size: .small, label: "Earlier") { offset += 1 }
                .disabled(!canGoBack).opacity(canGoBack ? 1 : 0.35)
            NoopTabs(options: NoopMetricRange.allCases.map { ($0.rawValue, $0) }, selection: $range)
            if let calendar {
                NoopIconButton(systemImage: anchored ? "calendar.badge.clock" : "calendar", size: .small,
                               label: "Choose a day", action: calendar)
            }
            NoopIconButton(systemImage: "chevron.right", size: .small, label: "Later") { offset -= 1 }
                .disabled(offset == 0).opacity(offset == 0 ? 0.35 : 1)
        }
        .sensoryFeedback(.selection, trigger: offset)
    }
}

/// The period bar's calendar: choose the day a period ends on, see the span it covers, Done or Reset.
struct NoopMetricDayPicker: View {
    @Binding var anchor: Date?
    let range: NoopMetricRange
    let earliest: Date?

    @Environment(\.dismiss) private var dismiss
    @State private var day = Date()

    private var span: String {
        let start = Calendar.current.date(byAdding: .day, value: -(range.days - 1), to: day) ?? day
        let f = Date.FormatStyle().day().month(.abbreviated)
        return "Last \(range.rawValue): \(start.formatted(f)) – \(day.formatted(f.year()))"
    }

    var body: some View {
        VStack(spacing: NoopSpace.m) {
            DatePicker("Period ends", selection: $day, in: (earliest ?? .distantPast)...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(NoopHTMLColor.blueLight)
                .labelsHidden()
            Text(span)
                .font(NoopHTMLFont.sans(NoopType.caption)).monospacedDigit()
                .foregroundStyle(NoopHTMLColor.copy)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.25), value: span)
            NoopActionButton(title: "Done", variant: .secondary) {
                anchor = Calendar.current.isDateInToday(day) ? nil : day
                dismiss()
            }
            NoopActionButton(title: "Reset", variant: .plain, size: .small) {
                anchor = nil
                dismiss()
            }
        }
        .padding(.horizontal, NoopSpace.l)
        .padding(.bottom, NoopSpace.l)
        .onAppear { day = anchor ?? Date() }
        .sensoryFeedback(.selection, trigger: day)
    }
}

/// How far a sheet's figure has slid under its title, 0 to 1 over the first 70 points (iOS 18; still
/// before that).
struct NoopScrollCollapse: ViewModifier {
    @Binding var collapse: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, y in
                collapse = min(max(y / 70, 0), 1)
            }
        } else {
            content
        }
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
        // Fitted to your readings and your normal, not the population scale: a resting HR of 45 on a
        // 50–90 norm scale was squashed into a sliver under the dates. The scale stays on the bar below.
        let values = points.map(\.value)
        let vs = values + [normal?.low, normal?.high].compactMap { $0 }
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
            // Day marks sit at midday; the line is placed to meet them.
            NoopGapAwareLine(points: points.map { (date: Calendar.current.startOfDay(for: $0.date).addingTimeInterval(43_200), value: $0.value) },
                             tint: accent.fill.opacity(0.55))
            ForEach(points) { p in
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
        .clipped()
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
        .noopChartZoom()
    }
}
#endif
