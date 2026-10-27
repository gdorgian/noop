import SwiftUI
import Charts
import StrandAnalytics
import StrandFitness
import StrandTraining
import WhoopStore

// MARK: - Session page parts (23 Oct 2026)
//
// One look for every session page — a lift, a logged activity, a detected one: a hero with the
// activity's own orb, section headings in title case, one card of figures, an effort ring, and a Heart
// section (the line over the zone floors and the time in each zone). Built once here so the lift record
// and the activity sheet cannot drift apart.

/// The page's opening: a glowing orb with the activity's symbol, the kind in the accent colour, the
/// name large, then when and where it was recorded.
struct NoopSessionHero: View {
    let symbol: String
    let kind: String
    let title: String
    let when: String
    var source: String = "Noop Aura"
    var badge: String? = nil
    var tint: Color = NoopHTMLColor.volt
    /// The symbol's colour on the tinted disc.
    var ink: Color = NoopHTMLColor.voltInk
    /// Just saved: the ring closes around the disc once (`NoopCelebrationRing`).
    var celebrate = false
    /// A card to share, beside the disc.
    var share: NoopShareContent? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
            ZStack {
                Circle().fill(RadialGradient(colors: [tint.opacity(0.42), tint.opacity(0)], center: .center,
                                             startRadius: 20, endRadius: 50))
                    .frame(width: 100, height: 100)
                Circle()
                    .fill(LinearGradient(colors: [tint, tint.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                    .shadow(color: tint.opacity(0.35), radius: 10, y: 4)
                    .frame(width: 72, height: 72)
                Image(systemName: symbol).font(.system(size: 31, weight: .semibold))
                    .foregroundStyle(ink)
                    .symbolEffect(.bounce, value: celebrate)
                if celebrate { NoopCelebrationRing(tint: tint) }
            }
            .frame(width: 100, height: 100)
            .padding(.leading, -14)
            .padding(.top, 6)
            Spacer()
            if let share { NoopShareButton(content: share).padding(.top, 14) }
            }
            HStack(spacing: 8) {
                Text(kind).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(tint)
                if let badge {
                    Text(badge).font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).foregroundStyle(tint)
                        .padding(.horizontal, 7).frame(minHeight: 18).background(tint.opacity(0.13), in: Capsule())
                }
            }
            Text(title).font(NoopHTMLFont.outfit(NoopType.title1, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                .lineLimit(2).minimumScaleFactor(0.75)
            VStack(alignment: .leading, spacing: 6) {
                Label(when, systemImage: "calendar").labelStyle(NoopSessionMetaLabel())
                Label(source, systemImage: "dot.radiowaves.left.and.right").labelStyle(NoopSessionMetaLabel())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NoopSessionMetaLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon.font(.system(size: 13)).foregroundStyle(NoopHTMLColor.faint).frame(width: 18)
            configuration.title.font(NoopHTMLFont.sans(NoopType.subhead)).foregroundStyle(NoopHTMLColor.copy).monospacedDigit()
        }
    }
}

/// A section's heading: a title-case name, an optional line under it, and an optional trailing control.
struct NoopSessionHeading<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(NoopHTMLFont.outfit(NoopType.title3, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                if let subtitle {
                    Text(subtitle).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                }
            }
            Spacer()
            trailing
        }
        .padding(.top, 10)
    }
}

extension NoopSessionHeading where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// The page's surface: one rounded card.
struct NoopSessionCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }
}

/// A small card header: a symbol and a muted name, as each card opens.
struct NoopSessionCardTitle: View {
    let symbol: String
    let title: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(NoopHTMLColor.copy)
            Text(title).font(NoopHTMLFont.sans(NoopType.subhead, weight: .medium)).foregroundStyle(NoopHTMLColor.copy)
        }
    }
}

/// Figures two to a row in one card: a muted label over a large number with its unit.
struct NoopSessionFigures: View {
    struct Item: Hashable {
        let label: String
        let value: String
        var unit: String? = nil
    }
    let items: [Item]

    var body: some View {
        NoopSessionCard {
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                      alignment: .leading, spacing: 20) {
                ForEach(items, id: \.self) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.label).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(item.value).font(NoopHTMLFont.outfit(NoopType.title2, weight: .medium)).foregroundStyle(NoopHTMLColor.ink)
                                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                            if let unit = item.unit {
                                Text(unit).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// A ring with a number inside, beside a title and a line: the session's effort, or how hard it felt.
struct NoopSessionRingRow: View {
    let value: String
    let fraction: Double
    let title: String
    let line: String
    var colors: [Color] = [NoopHTMLColor.volt, Color(hex: 0xF2B45C), Color(hex: 0xEF7A5A)]
    var chevron = false

    var body: some View {
        NoopSessionCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.07), lineWidth: 6)
                    Circle().trim(from: 0, to: max(0.02, min(1, fraction)))
                        .stroke(AngularGradient(colors: colors, center: .center, startAngle: .degrees(0),
                                                endAngle: .degrees(360 * max(0.02, min(1, fraction)))),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(value).font(NoopHTMLFont.outfit(NoopType.title3, weight: .semibold)).foregroundStyle(colors.last ?? NoopHTMLColor.ink)
                        .monospacedDigit().minimumScaleFactor(0.6)
                }
                .frame(width: 62, height: 62)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(NoopHTMLFont.sans(NoopType.body, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                    Text(line).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if chevron { NoopFixedChevron(direction: .right, color: NoopHTMLColor.chevronDim) }
            }
        }
    }
}

/// The Heart section: average, lowest and highest, the line over the zone floors, and the time in each
/// zone — "Zone 0" is everything under Zone 1, so a quiet stretch is counted, not dropped.
struct NoopSessionHeart: View {
    let start: Int
    let end: Int
    var source: String = ""
    /// The charts page shows the heart-rate card alone, taller.
    var chartOnly = false
    var chartHeight: CGFloat = 190

    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var profile: ProfileStore
    @State private var curve: [HRBucket] = []
    @State private var minutes: [Double] = []
    @State private var loaded = false
    @State private var selected: Date?
    @State private var recovery: HeartRateRecovery.Result?

    static let zoneColors: [Color] = [Color(hex: 0x7C8C96), Color(hex: 0x4FB8E8), Color(hex: 0x6FCFB4),
                                      NoopHTMLColor.volt, Color(hex: 0xF2B45C), Color(hex: 0xEF7A5A)]

    private var zoneSet: HRZoneSet { profile.hrZoneSet }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if curve.count >= 2, chartOnly {
                rateCard
            } else if curve.count >= 2 {
                NoopSessionHeading(title: "Heart")
                rateCard
                if !minutes.isEmpty { zonesCard; focusCard }
                recoveryCard
            } else if loaded, !chartOnly {
                NoopSessionHeading(title: "Heart")
                Text("No heart rate was recorded during this session.")
                    .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
            }
        }
        .task(id: "\(start):\(end)") { await load() }
    }

    private var rateCard: some View {
        let values = curve.map(\.bpm)
        let lowest = curve.map(\.minBpm).filter { $0 > 0 }.min() ?? values.min() ?? 0
        let highest = curve.map(\.maxBpm).max() ?? values.max() ?? 0
        let average = values.reduce(0, +) / Double(max(1, values.count))
        // The range follows the session's own pulse, reaching up to the next zone floor above its peak, so
        // an easy session is not pressed flat under five empty floors.
        let lo = max(40, lowest - 6)
        let nextFloor = zoneSet.zones.map(\.lower).first { $0 > highest }
        let hi = max(highest + 6, (nextFloor ?? highest) + 4)
        let shown = zoneSet.zones.map(\.lower).enumerated().filter { $0.element >= lo && $0.element <= hi }
        let floors = shown.map(\.element)
        return NoopSessionCard {
            VStack(alignment: .leading, spacing: 14) {
                NoopSessionCardTitle(symbol: "heart.fill", title: "Heart rate")
                HStack(spacing: 0) {
                    figure("Avg", average)
                    figure("Min", lowest)
                    figure("Max", highest)
                }
                Chart {
                    ForEach(shown, id: \.offset) { i, low in
                        RuleMark(y: .value("Zone \(i + 1)", low))
                            .foregroundStyle(Self.zoneColors[min(i + 1, 5)].opacity(0.55))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    }
                    if let p = picked {
                        RuleMark(x: .value("Time", date(p.ts)))
                            .foregroundStyle(Color.white.opacity(0.35)).lineStyle(StrokeStyle(lineWidth: 1))
                        PointMark(x: .value("Time", date(p.ts)), y: .value("bpm", p.bpm))
                            .symbolSize(60).foregroundStyle(NoopHTMLColor.ink)
                    }
                    // A dropout of two minutes or more mid-session reads as a gap, not a line across it.
                    NoopGapAwareLine(points: curve.map { (date($0.ts), $0.bpm) }, tint: Color(hex: 0x6FCFB4), floor: lo,
                                     minimumGap: 120,
                                     lineStyle: AnyShapeStyle(gradient(lo: lo, hi: hi)),
                                     areaStyle: AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x6FCFB4).opacity(0.16), .clear],
                                                                             startPoint: .top, endPoint: .bottom)))
                }
                .chartYScale(domain: lo...hi)
                .chartXScale(domain: date(start)...date(end))
                .chartPlotStyle { $0.clipped() }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard let frame = proxy.plotFrame else { return }
                                    if let d: Date = proxy.value(atX: value.location.x - geo[frame].origin.x) { selected = d }
                                }
                                .onEnded { _ in withAnimation(.easeOut(duration: 0.2)) { selected = nil } })
                    }
                }
                .overlay(alignment: .top) { scrubLabel }
                .sensoryFeedback(.selection, trigger: picked?.ts)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: floors) { _ in
                        AxisValueLabel().font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint)
                    }
                }
                .chartXAxis {
                    // Clock times for a long session; for a short one they would all read the same minute,
                    // so the axis counts time into the session instead.
                    // The first and last labels hang inward from the plot's edges; centred on the edge, the
                    // last one ran past the card and Charts dropped it.
                    AxisMarks(values: [date(start), date((start + end) / 2), date(end)]) { value in
                        AxisValueLabel(anchor: value.index == 0 ? .topLeading
                                       : value.index == value.count - 1 ? .topTrailing : .top,
                                       collisionResolution: .disabled) {
                            if let d = value.as(Date.self) {
                                Text(end - start < 20 * 60
                                     ? Self.elapsed(Int(d.timeIntervalSince1970) - start)
                                     : AppClock.hourMinuteFormatter().string(from: d))
                            }
                        }
                        .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint)
                    }
                }
                .frame(height: chartHeight)
                .noopChartZoom()
            }
        }
    }

    static func elapsed(_ s: Int) -> String {
        s <= 0 ? "0:00" : String(format: "%d:%02d", s / 60, s % 60)
    }

    /// The bucket under the finger while the chart is held.
    private var picked: HRBucket? {
        guard let selected else { return nil }
        let t = Int(selected.timeIntervalSince1970)
        return curve.min { abs($0.ts - t) < abs($1.ts - t) }
    }

    @ViewBuilder private var scrubLabel: some View {
        if let p = picked {
            HStack(spacing: 6) {
                Text("\(Int(p.bpm.rounded())) bpm").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                Text(AppClock.hourMinuteFormatter().string(from: date(p.ts))).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
            }
            .monospacedDigit()
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(NoopHTMLColor.cardRaised, in: Capsule())
            .offset(y: -6)
            .transition(.opacity)
        }
    }

    private func figure(_ label: String, _ bpm: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(Int(bpm.rounded()))").font(NoopHTMLFont.outfit(NoopType.title2, weight: .medium)).foregroundStyle(NoopHTMLColor.ink).monospacedDigit()
                Text("bpm").font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The line takes each zone's colour above that zone's floor.
    private func gradient(lo: Double, hi: Double) -> LinearGradient {
        func at(_ bpm: Double) -> CGFloat { CGFloat(1 - min(1, max(0, (bpm - lo) / (hi - lo)))) }
        var stops: [Gradient.Stop] = [.init(color: Self.zoneColors[0], location: 1)]
        for (i, low) in zoneSet.zones.map(\.lower).enumerated() {
            stops.append(.init(color: Self.zoneColors[min(i, 5)], location: at(low)))
            stops.append(.init(color: Self.zoneColors[min(i + 1, 5)], location: at(low)))
        }
        stops.append(.init(color: Self.zoneColors[5], location: 0))
        return LinearGradient(stops: stops.sorted { $0.location < $1.location }, startPoint: .top, endPoint: .bottom)
    }

    private var zonesCard: some View {
        let total = max(1, minutes.reduce(0, +))
        let zones = zoneSet.zones
        return NoopSessionCard {
            VStack(alignment: .leading, spacing: 0) {
                NoopSessionCardTitle(symbol: "list.bullet.clipboard", title: "Heart rate zones").padding(.bottom, 12)
                HStack {
                    Text("Zone").frame(width: 40, alignment: .leading)
                    Spacer()
                    Text("%").frame(width: 46, alignment: .trailing)
                    Text("Time").frame(width: 56, alignment: .trailing)
                    Text("bpm").frame(width: 72, alignment: .trailing)
                }
                .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.faint).padding(.bottom, 6)
                ForEach((0..<minutes.count).reversed(), id: \.self) { i in
                    let m = minutes[i]
                    let range: String = i == 0
                        ? "<\(Int(zones.first?.lower ?? 0))"
                        : i == zones.count ? ">\(Int(zones[i - 1].lower))"
                        : "\(Int(zones[i - 1].lower))–\(Int(zones[i - 1].upper))"
                    HStack(spacing: 10) {
                        Text("\(i)").font(NoopHTMLFont.sans(NoopType.body, weight: .semibold))
                            .foregroundStyle(m > 0 ? NoopHTMLColor.ink : NoopHTMLColor.faint).frame(width: 20, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.06))
                                Capsule().fill(Self.zoneColors[min(i, 5)])
                                    .frame(width: m > 0 ? max(8, geo.size.width * m / total) : 0)
                            }
                        }
                        .frame(height: 8)
                        Text("\(Int((m / total * 100).rounded()))%").frame(width: 46, alignment: .trailing)
                        Text(clock(m)).frame(width: 56, alignment: .trailing)
                        Text(range).foregroundStyle(NoopHTMLColor.faint).frame(width: 72, alignment: .trailing)
                    }
                    .font(NoopHTMLFont.sans(NoopType.subhead, weight: .medium)).monospacedDigit()
                    .foregroundStyle(m > 0 ? NoopHTMLColor.ink : NoopHTMLColor.faint)
                    .frame(height: 46)
                    if i > 0 { Divider().overlay(NoopHTMLColor.border) }
                }
            }
        }
    }

    /// What the session trained, from the same zone minutes and by the same rule as the Fitness tab's
    /// Cardio focus (`CardioFocus`), so the two never disagree.
    private var focusCard: some View {
        let split = CardioFocus.breakdown(secondsInZones: minutes.dropFirst().map { $0 * 60 })
        let colors: [CardioFocus.Band: Color] = [.lowAerobic: Self.zoneColors[2], .highAerobic: Self.zoneColors[3],
                                                 .anaerobic: Self.zoneColors[5]]
        let bands = CardioFocus.Band.allCases.reversed()
        return NoopSessionCard {
            VStack(alignment: .leading, spacing: 0) {
                NoopSessionCardTitle(symbol: "scope", title: "Cardio focus").padding(.bottom, 12)
                ForEach(Array(bands.enumerated()), id: \.offset) { i, band in
                    let share = split.shares[band] ?? 0
                    HStack(spacing: 10) {
                        Text(band.title).frame(width: 104, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.06))
                                Capsule().fill(colors[band] ?? NoopHTMLColor.ink)
                                    .frame(width: share > 0 ? max(8, geo.size.width * share) : 0)
                            }
                        }
                        .frame(height: 8)
                        Text("\(Int((share * 100).rounded()))%").frame(width: 46, alignment: .trailing)
                        Text(clock(share * split.trainingSeconds / 60)).frame(width: 56, alignment: .trailing)
                    }
                    .font(NoopHTMLFont.sans(NoopType.subhead, weight: .medium)).monospacedDigit()
                    .foregroundStyle(share > 0 ? NoopHTMLColor.ink : NoopHTMLColor.faint)
                    .frame(height: 46)
                    if i < bands.count - 1 { Divider().overlay(NoopHTMLColor.border) }
                }
                Text(split.dominant.map { "Mostly \($0.title.lowercased()) work." }
                     ?? "No time at Zone 2 or above, so none of it counts as aerobic training.")
                    .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 10)
            }
        }
    }

    /// How far the pulse fell in the first minute after the session ended — the standard recovery read.
    /// It needs the session to end hard (Zone 3 or above) and the strap on for the minutes after.
    private var recoveryCard: some View {
        let drop1 = recovery.flatMap { r in r.after1Minute.map { r.endHR - $0 } }
        let bands: [(String, Int)] = [("Poor", 0), ("Fair", 12), ("Good", 20), ("Great", 30), ("Superior", 40)]
        return NoopSessionCard {
            VStack(alignment: .leading, spacing: 14) {
                NoopSessionCardTitle(symbol: "arrow.down.heart.fill", title: "Heart rate recovery")
                if let r = recovery, r.hasMeasurement {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(drop1.map { "−\($0)" } ?? "—").font(NoopHTMLFont.outfit(NoopType.title1, weight: .medium))
                            .foregroundStyle(NoopHTMLColor.ink).monospacedDigit()
                        Text("bpm in the first minute").font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                    }
                    HStack(spacing: 18) {
                        step("End", r.endHR)
                        if let v = r.after1Minute { step("1 min", v) }
                        if let v = r.after2Minutes { step("2 min", v) }
                        if let v = r.after5Minutes { step("5 min", v) }
                    }
                } else {
                    Text("Shown when a session ends at Zone 3 or above and the strap stays on for a few minutes after.")
                        .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // The scale only means something beside a reading; without one it was an empty bar.
                if drop1 != nil {
                    VStack(spacing: 6) {
                        HStack(spacing: 3) {
                            ForEach(Array(bands.enumerated()), id: \.offset) { i, b in
                                let next = i + 1 < bands.count ? bands[i + 1].1 : Int.max
                                let here = drop1.map { $0 >= b.1 && $0 < next } ?? false
                                Capsule().fill(here ? Self.zoneColors[min(i + 1, 5)] : Color.white.opacity(0.07)).frame(height: 7)
                            }
                        }
                        HStack(spacing: 3) {
                            ForEach(bands, id: \.0) { b in
                                Text(b.0).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }
        }
    }

    private func step(_ label: String, _ bpm: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
            Text("\(bpm)").font(NoopHTMLFont.sans(NoopType.body, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink).monospacedDigit()
        }
    }

    private func clock(_ minutes: Double) -> String {
        let s = Int((minutes * 60).rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func date(_ ts: Int) -> Date { Date(timeIntervalSince1970: TimeInterval(ts)) }

    private func load() async {
        guard end > start else { return }
        // A bucket is stamped at its floor, which for the first one falls before the session began; drawn
        // there, the line ran off the card's left edge. Each point sits inside the session's window.
        curve = await repo.workoutHrBuckets(from: start, to: end, source: source).map {
            HRBucket(ts: min(end, max(start, $0.ts)), bpm: $0.bpm, minBpm: $0.minBpm, maxBpm: $0.maxBpm, conf: $0.conf)
        }
        // Zone 0 is the time under Zone 1: the window minus what the five zones counted.
        if let zones = await repo.workoutZoneMinutes(from: start, to: end, zoneSet: zoneSet, source: source) {
            let counted = zones.reduce(0, +)
            minutes = [max(0, Double(end - start) / 60 - counted)] + zones
        } else if !curve.isEmpty {
            // Heart rate was recorded but never reached Zone 1: the whole session is Zone 0, not "no zones".
            minutes = [Double(end - start) / 60] + Array(repeating: 0, count: zoneSet.zones.count)
        } else {
            minutes = []
        }
        recovery = await repo.workoutHeartRateRecovery(from: start, to: end, maxHR: zoneSet.maxHR, source: source)
        loaded = true
    }
}

extension NoopFitnessExerciseChoice {
    /// The catalogue entry for a logged exercise name, so a record can show the exercise's picture.
    /// The catalogue entry for a logged exercise name, or a plain choice carrying the muscles the set
    /// was logged under — so any logged exercise can open its page, catalogued or not.
    static func named(_ name: String, primary: LiftMuscle?, secondaries: [LiftMuscle]) -> NoopFitnessExerciseChoice {
        lookup(name) ?? .init(name: name, primary: primary, secondaries: secondaries, equipment: nil, isYours: true)
    }

    static func lookup(_ name: String) -> NoopFitnessExerciseChoice? {
        let key = NoopFitnessExercisePicker.fold(name)
        guard let known = TrainingExerciseLibrary.all
            .first(where: { NoopFitnessExercisePicker.fold($0.title) == key }) else { return nil }
        return .choice(known)
    }
}

/// Effort on the selected scale, the ring's fill, and a plain line for how much load it was.
enum NoopSessionEffort {
    static func describe(_ stored: Double) -> (value: String, fraction: Double, line: String) {
        let scale = UnitPrefs.resolveEffortScale(UserDefaults.standard.string(forKey: UnitPrefs.effortScaleKey) ?? "")
        let shown = UnitFormatter.effortDisplay(stored, scale: scale)
        let line = stored < 25 ? "Light load from this session"
            : stored < 50 ? "Moderate load from this session"
            : stored < 75 ? "High load from this session"
            : "Very high load from this session"
        return (shown, stored / 100, line)
    }
}

/// Which muscles a session worked: the leading muscle, a ring of the shares and a row for each. A lift
/// credits its sets; a cardio session shows the activity's typical split, said as such in `note`.
struct NoopSessionMuscles<Footer: View>: View {
    let shares: [(muscle: LiftMuscle, share: Double)]
    var note: String? = nil
    @ViewBuilder var footer: Footer

    // A generic type cannot hold a static stored property, so the palette is computed.
    static var muscleColors: [Color] {
        [Color(hex: 0x4FB8E8), Color(hex: 0x6FCFB4), NoopHTMLColor.volt,
         Color(hex: 0xB69CFF), Color(hex: 0xF2B45C), Color(hex: 0xEF7A9A)]
    }

    var body: some View {
        let top = shares[0]
        return NoopSessionCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        NoopSessionCardTitle(symbol: "chart.pie.fill", title: "Muscle breakdown")
                        Text(top.muscle.displayName).font(NoopHTMLFont.outfit(NoopType.title2, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                        Text("\(Int((top.share * 100).rounded()))% of the work").font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                        if let note {
                            Text(note).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.faint)
                        }
                    }
                    Spacer()
                    ZStack {
                        ForEach(Array(shares.enumerated()), id: \.offset) { i, s in
                            let before = shares.prefix(i).map(\.share).reduce(0, +)
                            Circle().trim(from: before + 0.012, to: max(before + 0.013, before + s.share - 0.012))
                                .stroke(Self.muscleColors[i % 6], style: StrokeStyle(lineWidth: 9, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                        }
                    }
                    .frame(width: 78, height: 78)
                }
                ForEach(Array(shares.enumerated()), id: \.offset) { i, s in
                    HStack(spacing: 12) {
                        Group {
                            if let group = FitnessMuscleGroup.forMuscleId(s.muscle.rawValue) {
                                NoopFitnessMuscleThumb(group: group, tint: Self.muscleColors[i % 6]).padding(.vertical, 3)
                            } else {
                                Circle().fill(Self.muscleColors[i % 6]).frame(width: 10, height: 10)
                            }
                        }
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.05), in: Circle())
                        Text(s.muscle.displayName).font(NoopHTMLFont.sans(NoopType.subhead, weight: .medium)).foregroundStyle(NoopHTMLColor.ink)
                            .frame(width: 108, alignment: .leading).lineLimit(1)
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.06))
                                Capsule().fill(Self.muscleColors[i % 6]).frame(width: max(8, g.size.width * s.share / top.share))
                            }
                        }
                        .frame(height: 9)
                        Text("\(Int((s.share * 100).rounded()))%").font(NoopHTMLFont.sans(NoopType.subhead)).foregroundStyle(NoopHTMLColor.copy)
                            .monospacedDigit().frame(width: 42, alignment: .trailing)
                    }
                    if i < shares.count - 1 { Divider().overlay(NoopHTMLColor.border) }
                }
                footer
            }
        }
    }
}

extension NoopSessionMuscles where Footer == EmptyView {
    init(shares: [(muscle: LiftMuscle, share: Double)], note: String? = nil) {
        self.init(shares: shares, note: note) { EmptyView() }
    }
}

/// A cardio session's muscles, from the same per-activity split the Fitness tab's muscular load uses
/// (`MuscularLoad.cardioMuscleShare`). Not measured: the strap cannot see which muscles moved.
enum NoopCardioMuscles {
    static func shares(for sport: String) -> [(muscle: LiftMuscle, share: Double)]? {
        var byMuscle: [LiftMuscle: Double] = [:]
        for (id, w) in MuscularLoad.cardioMuscleShare(NoopFitnessModel.kind(sport)) {
            if let m = NoopFitnessExerciseChoice.liftMuscle(id) { byMuscle[m, default: 0] += w }
        }
        let total = byMuscle.values.reduce(0, +)
        guard total > 0, byMuscle.count >= 2 else { return nil }
        return byMuscle.map { (muscle: $0.key, share: $0.value / total) }.sorted { $0.share > $1.share }
    }
}

/// Where the session left the user's training: cardio and muscular load on the session's day, read
/// from the same Fitness model and drawn with the same cards as the Fitness tab, plus what this session
/// added to each.
struct NoopSessionLoad: View {
    let row: WorkoutRow

    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var profile: ProfileStore
    @StateObject private var fitness = NoopFitnessModel()

    var body: some View {
        // A stack, not a Group: an empty Group has nothing for `.task` to attach to, so it never loaded.
        VStack(alignment: .leading, spacing: 0) {
            if let history = fitness.snapshot?.history {
                let day = Date(timeIntervalSince1970: TimeInterval(row.startTs))
                let workout = history.workouts.first { $0.startTs == row.startTs }
                let trimp = workout?.trimp ?? 0
                let muscular = MuscularLoad.cardioMuscleLoad(trimp: trimp, kind: NoopFitnessModel.kind(row.sport))
                    .values.reduce(0, +)
                VStack(alignment: .leading, spacing: 12) {
                    NoopSessionHeading(title: "Training load")
                    HStack(spacing: 12) {
                        NoopFitnessLoadCard(title: "Cardio load", reading: history.load(.cardio, asOf: day), decimals: 1)
                        NoopFitnessLoadCard(title: "Muscular load", reading: history.load(.muscular, asOf: day), decimals: 0)
                    }
                    if trimp > 0 {
                        Text("This session added \(String(format: "%.1f", trimp)) to cardio load and \(Int(muscular.rounded())) to muscular load.")
                            .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .task { await fitness.load(repo: repo, profile: profile) }
    }
}
