import SwiftUI

// MARK: - Trends · Markers
//
// The measures you pin to Trends, any of the catalogue's, seven by default. Each row reads where the
// measure is heading, its latest value and a short line of its recent readings; tapping it opens the
// shared metric sheet. Edit pins, unpins and orders them; See all browses every measure with data.

enum NoopMarkers {
    static let storageKey = "noop.trends.pinnedMarkers"
    static let defaults = [
        "apple-health:weight", "my-whoop:hrv", "my-whoop:rhr", "apple-health:body_fat",
        "apple-health:lean_mass", "my-whoop:vo2max_est", "my-whoop:sleep_total_min"
    ]

    static func decode(_ raw: String) -> [String] { raw.isEmpty ? defaults : raw.split(separator: ",").map(String.init) }
    static func encode(_ ids: [String]) -> String { ids.isEmpty ? "none" : ids.joined(separator: ",") }
    static func descriptor(_ id: String) -> MetricDescriptor? { MetricCatalog.all.first { $0.id == id } }
}

/// One marker's readings, reduced to what its row shows.
struct NoopMarkerReading {
    enum Direction { case increasing, decreasing, stabilizing }
    let latest: Double?
    let direction: Direction?
    /// Daily readings of the last 90 days and their 7-day rolling line, oldest first.
    let line: [Double]
    let trend: [Double]

    /// Where the 7-day average is heading: the latest week against the week 14 days before, called a
    /// move only when it clears half the spread of the readings themselves.
    init(_ points: [NoopMetricPoint]) {
        latest = points.last?.value
        let recent = points.suffix(90)
        line = recent.map(\.value)
        trend = recent.indices.compactMap { i in
            let window = recent[max(recent.startIndex, i - 6)...i].map(\.value)
            return window.count >= 3 ? window.reduce(0, +) / Double(window.count) : nil
        }
        guard let last = points.last?.date, points.count >= 5 else { direction = nil; return }
        let cal = Calendar.current
        func mean(endingDaysAgo d: Int) -> Double? {
            guard let end = cal.date(byAdding: .day, value: -d, to: last),
                  let start = cal.date(byAdding: .day, value: -7, to: end) else { return nil }
            let vs = points.filter { $0.date > start && $0.date <= end }.map(\.value)
            return vs.isEmpty ? nil : vs.reduce(0, +) / Double(vs.count)
        }
        guard let now = mean(endingDaysAgo: 0), let then = mean(endingDaysAgo: 14) else { direction = nil; return }
        let vs = points.suffix(60).map(\.value)
        let m = vs.reduce(0, +) / Double(vs.count)
        let sd = (vs.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(max(1, vs.count - 1))).squareRoot()
        let move = now - then
        direction = abs(move) <= max(sd * 0.5, abs(m) * 0.003) ? .stabilizing : move > 0 ? .increasing : .decreasing
    }
}

@MainActor
final class NoopMarkerStore: ObservableObject {
    @Published private(set) var readings: [String: NoopMarkerReading] = [:]
    @Published private(set) var withData: Set<String> = []
    @Published private(set) var loaded = false

    func load(ids: [String], repo: Repository) async {
        var next: [String: NoopMarkerReading] = [:]
        for id in ids {
            guard let d = NoopMarkers.descriptor(id) else { continue }
            next[id] = NoopMarkerReading(await Self.points(d, repo: repo, days: 400))
        }
        readings = next
        loaded = true
    }

    /// Which catalogue measures have any readings, for Edit and See all.
    func loadAvailability(repo: Repository) async {
        guard let all = await repo.exploreAllSeries() else { return }
        withData = Set(all.filter { !$0.value.isEmpty }.map(\.key))
    }

    static func points(_ d: MetricDescriptor, repo: Repository, days: Int) async -> [NoopMetricPoint] {
        let metric = NoopMetric(marker: d)
        let rows = await repo.exploreSeries(key: d.key, source: d.source, days: days)
        return rows.compactMap { r in
            NoopMetricSheet.dayFormatter.date(from: r.day).map { NoopMetricPoint(date: $0, value: metric.series?.transform(r.value) ?? r.value) }
        }
    }
}

// MARK: Section

struct NoopTrendsMarkersSection: View {
    @ObservedObject var navigation: NoopNavigation
    /// Rows (the default) or a two-column grid of tiles.
    var tiles = false
    @EnvironmentObject private var repo: Repository
    @StateObject private var store = NoopMarkerStore()
    @AppStorage(NoopMarkers.storageKey) private var pinnedRaw = ""
    @State private var editing = false
    @State private var browsing = false

    private var pinned: [String] { NoopMarkers.decode(pinnedRaw).filter { NoopMarkers.descriptor($0) != nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: NoopSpace.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("Markers")
                    .font(NoopHTMLFont.outfit(NoopType.title3))
                    .tracking(-0.4)
                    .foregroundStyle(NoopHTMLColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Edit") { editing = true }
                    .font(NoopHTMLFont.sans(NoopType.subhead, weight: .medium))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .underline()
                    .noopHitTarget()
            }
            .padding(.horizontal, 2)

            if tiles {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Array(pinned.enumerated()), id: \.element) { index, id in
                        if let d = NoopMarkers.descriptor(id) {
                            Button { navigation.metricSheet = NoopMetricSheetRequest(metricID: id, group: "marker") } label: {
                                NoopMarkerTile(row: NoopMarkerRow(descriptor: d, reading: store.readings[id], loaded: store.loaded),
                                               delay: Double(index) * 0.07)
                            }
                            .buttonStyle(NoopHTMLPressStyle())
                        }
                    }
                }
            } else {
            ForEach(pinned, id: \.self) { id in
                if let d = NoopMarkers.descriptor(id) {
                    Button { navigation.metricSheet = NoopMetricSheetRequest(metricID: id, group: "marker") } label: {
                        NoopMarkerRow(descriptor: d, reading: store.readings[id], loaded: store.loaded)
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                }
            }
            }

            if pinned.isEmpty {
                Text("No markers pinned. Edit to choose the ones you want here.")
                    .font(NoopHTMLFont.sans(NoopType.footnote))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .padding(.vertical, NoopSpace.s)
            }

            Button { browsing = true } label: {
                HStack(spacing: 6) {
                    Text("See all")
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                }
                .font(NoopHTMLFont.sans(NoopType.subhead, weight: .medium))
                .foregroundStyle(NoopHTMLColor.copy)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
            }
            .buttonStyle(NoopHTMLPressStyle())
        }
        .task(id: "\(repo.refreshSeq)|\(pinnedRaw)") { await store.load(ids: pinned, repo: repo) }
        .sheet(isPresented: $editing) {
            NoopMarkersEditSheet(pinnedRaw: $pinnedRaw, store: store)
                .environmentObject(repo)
                .noopSheet()
        }
        .sheet(isPresented: $browsing) {
            NoopMarkersBrowseSheet(store: store)
                .environmentObject(repo)
                .noopSheet()
        }
    }
}

struct NoopMarkerRow: View {
    let descriptor: MetricDescriptor
    let reading: NoopMarkerReading?
    let loaded: Bool

    private var metric: NoopMetric { NoopMetric(marker: descriptor) }

    var body: some View {
        HStack(spacing: NoopSpace.m) {
            VStack(alignment: .leading, spacing: 6) {
                Text(descriptor.title)
                    .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    status
                    Text("\u{2022}").font(.system(size: 9)).foregroundStyle(NoopHTMLColor.muted)
                    Text(value)
                        .font(NoopHTMLFont.sans(NoopType.subhead, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(reading?.latest == nil ? NoopHTMLColor.muted : NoopHTMLColor.ink)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            Spacer(minLength: NoopSpace.s)
            NoopMarkerSpark(line: reading?.line ?? [], trend: reading?.trend ?? [])
                .frame(width: 92, height: 44)
        }
        .padding(.horizontal, NoopSpace.m)
        .padding(.vertical, 15)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    fileprivate var value: String {
        guard let v = reading?.latest else { return "\u{2014}" }
        let unit = metric.shownUnit
        return metric.format(v) + (unit.isEmpty ? "" : (unit == "%" ? "%" : " \(unit)"))
    }

    @ViewBuilder fileprivate var status: some View {
        if let v = reading?.latest, let zone = metric.zones.first(where: { $0.range.contains(v) }) {
            Text(zone.label).font(NoopHTMLFont.sans(NoopType.subhead, weight: .medium)).foregroundStyle(zone.color)
        } else {
            direction
        }
    }

    @ViewBuilder private var direction: some View {
        let (word, symbol): (String, String) = {
            switch reading?.direction {
            case .increasing: ("Increasing", "arrow.up.circle.fill")
            case .decreasing: ("Decreasing", "arrow.down.circle.fill")
            case .stabilizing: ("Stabilizing", "arrow.right.circle.fill")
            case nil: (loaded ? "No trend yet" : "Loading", "xmark.circle.fill")
            }
        }()
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 14))
            Text(word).font(NoopHTMLFont.sans(NoopType.subhead))
        }
        .foregroundStyle(reading?.direction == nil ? NoopHTMLColor.muted : NoopHTMLColor.copy)
    }
}

/// The readings as a line, their 7-day average dotted over it, a dotted floor and a lit last point.
struct NoopMarkerSpark: View {
    let line: [Double]
    let trend: [Double]

    var body: some View {
        Canvas { context, size in
            var floor = Path()
            floor.move(to: CGPoint(x: 0, y: size.height - 1)); floor.addLine(to: CGPoint(x: size.width, y: size.height - 1))
            context.stroke(floor, with: .color(NoopHTMLColor.muted.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [1.5, 3]))
            guard line.count >= 2, let lo = (line + trend).min(), let hi = (line + trend).max() else {
                var flat = Path(); flat.move(to: CGPoint(x: 6, y: size.height * 0.4)); flat.addLine(to: CGPoint(x: size.width - 6, y: size.height * 0.4))
                context.stroke(flat, with: .color(NoopHTMLColor.muted.opacity(0.6)), lineWidth: 1.5)
                return
            }
            let span = max(hi - lo, 0.0001)
            let w = size.width - 8, h = size.height - 10
            func pts(_ vs: [Double]) -> [CGPoint] {
                vs.enumerated().map { CGPoint(x: 2 + w * CGFloat($0.offset) / CGFloat(max(1, vs.count - 1)),
                                              y: 2 + h * (1 - CGFloat(($0.element - lo) / span))) }
            }
            let p = pts(line)
            var path = Path(); path.move(to: p[0]); p.dropFirst().forEach { path.addLine(to: $0) }
            context.stroke(path, with: .color(NoopHTMLColor.inkSoft), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            if trend.count >= 2 {
                let t = pts(trend)
                var tp = Path(); tp.move(to: t[0]); t.dropFirst().forEach { tp.addLine(to: $0) }
                context.stroke(tp, with: .color(NoopHTMLColor.blueLight.opacity(0.8)), style: StrokeStyle(lineWidth: 1.4, dash: [1.5, 2.5]))
            }
            let end = p[p.count - 1]
            context.fill(Path(ellipseIn: CGRect(x: end.x - 5, y: end.y - 5, width: 10, height: 10)), with: .color(NoopHTMLColor.inkSoft))
            context.fill(Path(ellipseIn: CGRect(x: end.x - 2.5, y: end.y - 2.5, width: 5, height: 5)), with: .color(NoopHTMLColor.card))
        }
        .accessibilityHidden(true)
    }
}

// MARK: Edit

struct NoopMarkersEditSheet: View {
    @Binding var pinnedRaw: String
    @ObservedObject var store: NoopMarkerStore
    @EnvironmentObject private var repo: Repository
    @Environment(\.dismiss) private var dismiss
    @State private var pinned: [String] = []
    @State private var query = ""

    private var addable: [MetricDescriptor] {
        MetricCatalog.all.filter { d in
            !pinned.contains(d.id) && store.withData.contains(d.id)
                && (query.isEmpty || d.title.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Edit markers").font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                HStack {
                    Spacer()
                    Button("Done") { pinnedRaw = NoopMarkers.encode(pinned); dismiss() }
                        .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.ink)
                        .noopHitTarget()
                }
            }
            .padding(.horizontal, NoopSpace.l)
            .padding(.vertical, NoopSpace.m)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 15)).foregroundStyle(NoopHTMLColor.muted)
                TextField("Search measures", text: $query)
                    .font(NoopHTMLFont.sans(NoopType.subhead))
                    .foregroundStyle(NoopHTMLColor.ink)
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: NoopRadius.control, style: .continuous))
            .padding(.horizontal, NoopSpace.l)
            .padding(.bottom, NoopSpace.xs)

            List {
                Section {
                    ForEach(pinned, id: \.self) { id in
                        if let d = NoopMarkers.descriptor(id) {
                            row(d, pinned: true)
                        }
                    }
                    .onMove { pinned.move(fromOffsets: $0, toOffset: $1) }
                } header: { header("Pinned") }

                Section {
                    ForEach(addable) { d in row(d, pinned: false) }
                    if addable.isEmpty {
                        Text(store.withData.isEmpty ? "Checking which measures have data\u{2026}" : "Nothing else with data to add.")
                            .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                            .listRowBackground(NoopHTMLColor.card)
                    }
                } header: { header("Add") }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))
        }
        .background(NoopHTMLColor.canvas.ignoresSafeArea())
        .onAppear { pinned = NoopMarkers.decode(pinnedRaw).filter { NoopMarkers.descriptor($0) != nil } }
        .task { await store.loadAvailability(repo: repo) }
    }

    private func header(_ title: String) -> some View {
        Text(title).font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(NoopHTMLColor.copy)
    }

    private func row(_ d: MetricDescriptor, pinned isPinned: Bool) -> some View {
        HStack(spacing: NoopSpace.s) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isPinned { pinned.removeAll { $0 == d.id } } else { pinned.append(d.id) }
                }
            } label: {
                Image(systemName: isPinned ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(isPinned ? NoopHTMLColor.red : NoopHTMLColor.green)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPinned ? "Unpin \(d.title)" : "Pin \(d.title)")
            VStack(alignment: .leading, spacing: 2) {
                Text(d.title).font(NoopHTMLFont.sans(NoopType.subhead, weight: .medium)).foregroundStyle(NoopHTMLColor.ink)
                Text(d.sourceLabel).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
            }
        }
        .frame(minHeight: 44)
        .listRowBackground(NoopHTMLColor.card)
    }
}

// MARK: See all

struct NoopMarkersBrowseSheet: View {
    @ObservedObject var store: NoopMarkerStore
    @EnvironmentObject private var repo: Repository
    @Environment(\.dismiss) private var dismiss
    @Environment(\.noopAccent) private var accent
    @State private var query = ""
    @State private var open: NoopMetricSheetRequest?

    private var groups: [(String, [MetricDescriptor])] {
        let shown = MetricCatalog.all.filter {
            store.withData.contains($0.id) && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query))
        }
        let order = ["Health", "Heart", "Charge", "Rest", "Effort", "Nutrition", "Mind"]
        return Dictionary(grouping: shown, by: \.category)
            .sorted { (order.firstIndex(of: $0.key) ?? 99) < (order.firstIndex(of: $1.key) ?? 99) }
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        VStack(spacing: 0) {
            NoopMetricTopBar(title: "All markers") { dismiss() }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 15)).foregroundStyle(NoopHTMLColor.muted)
                TextField("Search measures", text: $query)
                    .font(NoopHTMLFont.sans(NoopType.subhead))
                    .foregroundStyle(NoopHTMLColor.ink)
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: NoopRadius.control, style: .continuous))
            .padding(.horizontal, NoopSpace.l)
            .padding(.bottom, NoopSpace.xs)

            List {
                ForEach(groups, id: \.0) { group in
                    Section {
                        ForEach(group.1) { d in
                            Button { open = NoopMetricSheetRequest(metricID: d.id, group: "marker") } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(d.title).font(NoopHTMLFont.sans(NoopType.subhead, weight: .medium)).foregroundStyle(NoopHTMLColor.ink)
                                        Text(d.sourceLabel).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(NoopHTMLColor.muted)
                                }
                                .frame(minHeight: 48)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(NoopHTMLColor.card)
                        }
                    } header: {
                        Text(group.0).font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(NoopHTMLColor.copy)
                    }
                }
                if groups.isEmpty {
                    Text(store.withData.isEmpty ? "Checking which measures have data\u{2026}" : "No measures match.")
                        .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                        .listRowBackground(NoopHTMLColor.card)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .background(NoopHTMLColor.canvas.ignoresSafeArea())
        .task { await store.loadAvailability(repo: repo) }
        .sheet(item: $open) { request in
            NoopMetricSheet(metrics: request.metrics, selectedID: request.metricID)
                .environmentObject(repo)
                .environment(\.noopAccent, accent)
                .noopSheet()
        }
    }
}

/// A pinned marker as a tile: its name, where it stands, its value large, and its last ninety days
/// as a line that draws in, each tile a beat after the one before.
private struct NoopMarkerTile: View {
    let row: NoopMarkerRow
    let delay: Double

    @State private var drawn: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(row.descriptor.title)
                .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                .foregroundStyle(NoopHTMLColor.copy)
                .lineLimit(1)
            Text(row.value)
                .font(NoopHTMLFont.outfit(NoopType.title3))
                .monospacedDigit()
                .foregroundStyle(NoopHTMLColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            spark.frame(height: 34)
            row.status.font(NoopHTMLFont.sans(NoopType.caption, weight: .medium)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
        .onAppear {
            guard drawn == 0 else { return }
            if reduceMotion { drawn = 1; return }
            withAnimation(.spring(response: 1.0, dampingFraction: 0.95).delay(delay)) { drawn = 1 }
        }
    }

    private var spark: some View {
        let line = row.reading?.line ?? []
        return GeometryReader { g in
            if line.count >= 2, let lo = line.min(), let hi = line.max() {
                let span = max(hi - lo, 0.0001)
                let path = Path { p in
                    for (i, v) in line.enumerated() {
                        let pt = CGPoint(x: g.size.width * CGFloat(i) / CGFloat(line.count - 1),
                                         y: g.size.height * (1 - CGFloat((v - lo) / span)) * 0.9 + 2)
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                }
                ZStack {
                    path.trimmedPath(from: 0, to: drawn)
                        .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    if drawn > 0.98, let last = line.last {
                        let y = g.size.height * (1 - CGFloat((last - lo) / span)) * 0.9 + 2
                        Circle().fill(Color.white).frame(width: 5, height: 5).position(x: g.size.width, y: y)
                    }
                }
            } else {
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1).frame(maxHeight: .infinity)
            }
        }
    }
}
