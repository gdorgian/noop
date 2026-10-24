import StrandAnalytics
import SwiftUI

// MARK: - Today, alternative sections
//
// Other ways to show the same Today readings, each its own section the wearer can pick instead of
// (or beside) the original card:
//   • Vitals · Constellation — the five overnight vitals as stars around your own zone.
//   • Last night · Tide — the night drawn as water, its depth the depth of sleep.
//   • Energy · Reservoir — the day's burn filling a vessel toward where it is heading by midnight.
// Each draws itself in when it first appears and keeps a slow living motion after, paused off screen
// and still under Reduce Motion.

/// Shared appearance and pause logic for the animated slots.
struct NoopSlotClock<Content: View>: View {
    @ViewBuilder var content: (_ t: Double, _ reveal: Double) -> Content

    @State private var onScreen = true
    /// When it first came into view; the draw-in runs from there.
    @State private var appeared: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var revealDuration: Double { 1.5 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !onScreen || reduceMotion)) { timeline in
            let since = appeared.map { timeline.date.timeIntervalSince($0) } ?? 0
            let x = min(1, max(0, since / revealDuration))
            // Ease out: quick start, long settle.
            let reveal = 1 - pow(1 - x, 3)
            content(reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600),
                    reduceMotion ? 1 : reveal)
        }
        .onAppear { if appeared == nil { appeared = Date() } }
        .modifier(NoopSlotVisibility(onScreen: $onScreen))
    }
}

struct NoopSlotVisibility: ViewModifier {
    @Binding var onScreen: Bool
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) { content.onScrollVisibilityChange(threshold: 0.02) { onScreen = $0 } } else { content }
    }
}

struct NoopSlotCard<Content: View>: View {
    var tint: Color
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background {
                NoopCSSLinearGradient(colors: [tint.opacity(0.13), tint.opacity(0.02)])
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(tint.opacity(0.22), lineWidth: 0.5))
    }
}

// MARK: - Vitals · Constellation

struct NoopVitalsConstellation: View {
    let vitals: [NoopVital]
    let action: () -> Void

    private static let calm = NoopHTMLColor.blueLight
    private static let watch = Color(hex: 0xF3B45C)
    private static let short = ["rhr": "Resting", "hrv": "HRV", "resp": "Breathing", "spo2": "Oxygen", "skin": "Skin"]

    private var ordered: [NoopVital] {
        NoopVital.designOrder.compactMap { key in vitals.first { $0.key == key } }
    }
    private var outCount: Int { ordered.filter(\.outside).count }

    var body: some View {
        Button(action: action) {
            NoopSlotCard(tint: outCount > 0 ? Self.watch : Self.calm) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        NoopSectionLabel("Vitals", color: outCount > 0 ? Self.watch : Self.calm)
                        Spacer()
                        Text(summary).font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                            .foregroundStyle(outCount > 0 ? Self.watch : Self.calm)
                    }
                    if ordered.count >= 3 {
                        NoopSlotClock { t, reveal in
                            Canvas { context, size in draw(&context, size, t: t, reveal: reveal) }
                        }
                        .frame(height: 250)
                    } else {
                        Text("Your five overnight signals appear here after a recorded night.")
                            .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                            .padding(.vertical, 20)
                    }
                }
            }
        }
        .buttonStyle(NoopHTMLPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vitals, \(summary). " + ordered.map { "\($0.name) \(format($0))" }.joined(separator: ", "))
    }

    private var summary: String {
        let words = ["all in zone", "one to watch", "two to watch", "three to watch", "four to watch", "five to watch"]
        return words[min(5, outCount)]
    }

    private func format(_ v: NoopVital) -> String {
        String(format: "%.\(v.decimals)f", v.value) + (v.unit == "%" || v.unit.hasPrefix("/") ? v.unit : " " + v.unit)
    }

    /// Where a reading sits: the zone is the band between 0.42 and 0.78 of the radius; a reading's
    /// place across its zone maps into that band, and outside it drifts in or out past the edge.
    private func radius(_ v: NoopVital) -> Double {
        let span = max(v.high - v.low, 0.0001)
        let f = (v.value - v.low) / span
        return 0.42 + 0.36 * min(1.35, max(-0.35, f))
    }

    private func draw(_ context: inout GraphicsContext, _ size: CGSize, t: Double, reveal: Double) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let R = Double(min(size.width, size.height)) / 2 - 22
        let n = ordered.count
        func angle(_ i: Int) -> Double { -Double.pi / 2 + Double(i) / Double(n) * 2 * .pi }
        func point(_ i: Int, _ r: Double) -> CGPoint {
            CGPoint(x: c.x + CGFloat(cos(angle(i)) * r * R), y: c.y + CGFloat(sin(angle(i)) * r * R))
        }
        // The zone: a soft annulus that breathes very slightly, with faint spokes.
        let breathe = 1 + 0.012 * sin(t * 0.8)
        var band = Path()
        band.addEllipse(in: CGRect(x: c.x - CGFloat(0.78 * R * breathe), y: c.y - CGFloat(0.78 * R * breathe),
                                   width: CGFloat(1.56 * R * breathe), height: CGFloat(1.56 * R * breathe)))
        band.addEllipse(in: CGRect(x: c.x - CGFloat(0.42 * R), y: c.y - CGFloat(0.42 * R),
                                   width: CGFloat(0.84 * R), height: CGFloat(0.84 * R)))
        context.fill(band, with: .color(Self.calm.opacity(0.07 * reveal)), style: FillStyle(eoFill: true))
        for r in [0.42, 0.78] {
            let rr = CGFloat(r * R)
            context.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: 2 * rr, height: 2 * rr)),
                           with: .color(.white.opacity(0.07 * reveal)), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
        }
        for i in 0..<n {
            var spoke = Path(); spoke.move(to: c); spoke.addLine(to: point(i, 1.0))
            context.stroke(spoke, with: .color(.white.opacity(0.05 * reveal)), lineWidth: 1)
        }
        // The shape the five make, drawn in around the circle.
        var shape = Path()
        for i in 0...n {
            let p = point(i % n, radius(ordered[i % n]) * (0.6 + 0.4 * reveal))
            if i == 0 { shape.move(to: p) } else { shape.addLine(to: p) }
        }
        context.fill(shape, with: .radialGradient(Gradient(colors: [Self.calm.opacity(0.02), Self.calm.opacity(0.16 * reveal)]),
                                                 center: c, startRadius: 0, endRadius: CGFloat(R)))
        context.stroke(shape.trimmedPath(from: 0, to: reveal), with: .color(Self.calm.opacity(0.55)),
                       style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
        // The stars, each appearing in turn; one outside its zone pulses warm.
        for (i, v) in ordered.enumerated() {
            let appear = max(0, min(1, reveal * Double(n + 2) - Double(i)))
            guard appear > 0 else { continue }
            let p = point(i, radius(v) * (0.6 + 0.4 * reveal))
            let color = v.outside ? Self.watch : Self.calm
            let pulse = v.outside ? 0.5 + 0.5 * sin(t * 3.2 + Double(i)) : 0.5 + 0.5 * sin(t * 1.1 + Double(i) * 1.7)
            let g = CGFloat((v.outside ? 16 : 11) + 5 * pulse) * CGFloat(appear)
            var glow = context
            glow.blendMode = .plusLighter
            glow.fill(Path(ellipseIn: CGRect(x: p.x - g, y: p.y - g, width: 2 * g, height: 2 * g)),
                      with: .radialGradient(Gradient(colors: [color.opacity(0.75), color.opacity(0)]),
                                            center: p, startRadius: 0, endRadius: g))
            let s = CGFloat(3.6 * appear)
            context.fill(Path(ellipseIn: CGRect(x: p.x - s, y: p.y - s, width: 2 * s, height: 2 * s)), with: .color(.white))
            // Label just outside the rim.
            let lp = point(i, 1.0 + 0.02)
            let anchor: UnitPoint = abs(cos(angle(i))) < 0.3 ? (sin(angle(i)) < 0 ? .bottom : .top)
                : (cos(angle(i)) > 0 ? .leading : .trailing)
            let label = Text("\(Self.short[v.key] ?? v.name)  ").font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
                .foregroundStyle(NoopHTMLColor.muted)
                + Text(format(v)).font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                .foregroundStyle(v.outside ? Self.watch : NoopHTMLColor.ink)
            context.opacity = appear
            context.draw(label, at: lp, anchor: anchor)
            context.opacity = 1
        }
    }
}

// MARK: - Last night · Tide

struct NoopSleepTide: View {
    let night: NoopRestRecord.Night
    let needMin: Double
    let action: () -> Void

    private static let deep = Color(hex: 0x4B4FC9)
    private static let surface = Color(hex: 0x8FB6FF)

    /// How far down each stage sits: awake at the surface, deep at the floor.
    private static let depth: [Double] = [0.08, 0.5, 0.32, 0.92]

    var body: some View {
        Button(action: action) {
            NoopSlotCard(tint: Self.deep) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        NoopSectionLabel("Last night", color: Self.surface)
                        Spacer()
                        Text(night.asleepWindow).font(NoopHTMLFont.sans(NoopType.caption)).monospacedDigit()
                            .foregroundStyle(NoopHTMLColor.faint)
                    }
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text(NoopRestRecord.duration(night.asleepMin))
                            .font(NoopHTMLFont.outfit(NoopType.title1, weight: .light)).monospacedDigit()
                            .foregroundStyle(NoopHTMLColor.ink)
                        Text(deltaText).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                    }
                    NoopSlotClock { t, reveal in
                        Canvas { context, size in draw(&context, size, t: t, reveal: reveal) }
                    }
                    .frame(height: 120)
                    HStack(spacing: 14) {
                        legend("Deep", night.stages.deep, NoopTodayNightCard.stageColors[3])
                        legend("REM", night.stages.rem, NoopTodayNightCard.stageColors[2])
                        legend("Light", night.stages.light, NoopTodayNightCard.stageColors[1])
                        legend("Awake", night.stages.awake, .white.opacity(0.5))
                    }
                }
            }
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private var deltaText: String {
        guard needMin > 0 else { return "asleep" }
        let d = (night.asleepMin - needMin).rounded()
        return d >= 0 ? "\(NoopRestRecord.duration(d)) over your need" : "\(NoopRestRecord.duration(-d)) short"
    }

    private func legend(_ name: String, _ minutes: Double, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(name) \(NoopRestRecord.duration(minutes))").font(NoopHTMLFont.sans(NoopType.eyebrow)).monospacedDigit()
                .foregroundStyle(NoopHTMLColor.copy)
        }
    }

    /// The night's runs, or the totals laid out in a typical order when no timeline was kept.
    private var runs: [NoopRestRecord.StageRun] {
        if let runs = night.runs, !runs.isEmpty { return runs }
        let s = night.stages
        let total = max(1, s.deep + s.rem + s.light + s.awake)
        var at = 0.0, out: [NoopRestRecord.StageRun] = []
        for (stage, m) in [(1, s.light * 0.3), (3, s.deep * 0.6), (1, s.light * 0.3), (2, s.rem * 0.4), (3, s.deep * 0.4),
                           (1, s.light * 0.4), (2, s.rem * 0.6), (0, s.awake)] where m > 0 {
            out.append(.init(stage: stage, from: at, to: at + m / total)); at += m / total
        }
        return out
    }

    private func draw(_ context: inout GraphicsContext, _ size: CGSize, t: Double, reveal: Double) {
        let w = Double(size.width), h = Double(size.height)
        let top = 10.0, floor = h - 4
        func y(_ d: Double) -> Double { top + d * (floor - top) }
        // The sea bed: the night's depth at every point, smoothed over about a twentieth of the night
        // so brief changes soften into the shape rather than spiking.
        let rs = runs
        let n = 160
        func stage(at f: Double) -> Int { rs.first { f >= $0.from && f < $0.to }?.stage ?? 0 }
        let raw = (0...n).map { Self.depth[stage(at: Double($0) / Double(n))] }
        let k = 6
        let smooth: [Double] = (0...n).map { i in
            var sum = 0.0, wsum = 0.0
            for j in max(0, i - k)...min(n, i + k) {
                let wt = exp(-Double((j - i) * (j - i)) / Double(k * k) * 2)
                sum += raw[j] * wt; wsum += wt
            }
            return sum / wsum
        }
        let pts = (0...n).map { CGPoint(x: Double($0) / Double(n) * w, y: y(smooth[$0])) }
        var water = Path()
        water.move(to: CGPoint(x: 0, y: 0))
        for p in pts { water.addLine(to: p) }
        water.addLine(to: CGPoint(x: w, y: 0)); water.closeSubpath()

        var clipped = context
        clipped.clip(to: Path(CGRect(x: 0, y: 0, width: w * reveal, height: h)))
        // Light falls off with depth.
        clipped.fill(water, with: .linearGradient(Gradient(stops: [
            .init(color: Self.surface.opacity(0.32), location: 0),
            .init(color: Self.deep.opacity(0.5), location: 0.55),
            .init(color: Color(hex: 0x20236B).opacity(0.85), location: 1)
        ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        // Caustics: slow bright ripples drifting across the water.
        var light = clipped
        light.blendMode = .plusLighter
        light.clip(to: water)
        for kk in 0..<5 {
            var ripple = Path()
            let baseY = h * (0.15 + 0.17 * Double(kk))
            for i in 0...60 {
                let x = Double(i) / 60 * w
                let yy = baseY + 4 * sin(x / 38 + t * (0.6 + 0.15 * Double(kk)) + Double(kk))
                if i == 0 { ripple.move(to: CGPoint(x: x, y: yy)) } else { ripple.addLine(to: CGPoint(x: x, y: yy)) }
            }
            light.stroke(ripple, with: .color(.white.opacity(0.045 - 0.006 * Double(kk))), lineWidth: 6)
        }
        // The bed's edge, coloured by the stage underneath each stretch.
        var i = 0
        while i < n {
            let st = stage(at: Double(i) / Double(n))
            var seg = Path()
            seg.move(to: pts[i])
            var j = i + 1
            while j <= n {
                seg.addLine(to: pts[j])
                if j == n || stage(at: Double(j) / Double(n)) != st { break }
                j += 1
            }
            let color = st == 0 ? Color.white.opacity(0.6) : NoopTodayNightCard.stageColors[st]
            clipped.stroke(seg, with: .color(color), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            i = j
        }
        // The surface, moving.
        var surface = Path()
        for i in 0...80 {
            let x = Double(i) / 80 * w
            let yy = 3 + 2.2 * sin(x / 22 + t * 1.6) + 1.2 * sin(x / 9 - t * 2.3)
            if i == 0 { surface.move(to: CGPoint(x: x, y: yy)) } else { surface.addLine(to: CGPoint(x: x, y: yy)) }
        }
        clipped.stroke(surface, with: .color(Self.surface.opacity(0.7)), lineWidth: 1.3)
        // The deepest moment, marked with a small rising bubble.
        if let deepest = rs.filter({ $0.stage == 3 }).max(by: { ($0.to - $0.from) < ($1.to - $1.from) }) {
            let x = (deepest.from + deepest.to) / 2 * w
            let rise = (t * 0.25).truncatingRemainder(dividingBy: 1)
            let floorY = Double(pts[min(n, Int((deepest.from + deepest.to) / 2 * Double(n)))].y)
            let by = floorY - rise * (floorY - top)
            let r = 2.2 + 1.5 * rise
            clipped.stroke(Path(ellipseIn: CGRect(x: x - r + 3 * sin(t * 2), y: by - r, width: 2 * r, height: 2 * r)),
                           with: .color(.white.opacity(0.55 * (1 - rise))), lineWidth: 1)
        }
    }
}

// MARK: - Energy · Reservoir

struct NoopEnergyReservoir: View {
    let summary: DailyEnergySummary
    let action: () -> Void

    private static let basal = Color(hex: 0x2D7FF0)
    private static let active = Color(hex: 0x6FE3F5)

    private var burned: Double { summary.totalBurnedSoFar ?? 0 }
    private var basal: Double { summary.basalBurnedSoFar ?? burned }
    private var active: Double { summary.activeBurnedSoFar ?? 0 }
    private var capacity: Double {
        max(burned * 1.05, summary.projectedRangeKcal?.upperBound ?? summary.projectedTotalBurn ?? summary.estimatedBMR24h ?? burned * 1.5, 1)
    }

    var body: some View {
        Button(action: action) {
            NoopSlotCard(tint: Self.basal) {
                HStack(alignment: .center, spacing: 18) {
                    NoopSlotClock { t, reveal in
                        Canvas { context, size in draw(&context, size, t: t, reveal: reveal) }
                    }
                    .frame(width: 104, height: 150)
                    VStack(alignment: .leading, spacing: 8) {
                        NoopSectionLabel("Energy", color: Self.active)
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            Text(burned.formatted(.number.precision(.fractionLength(0))))
                                .font(NoopHTMLFont.outfit(NoopType.title1, weight: .light)).monospacedDigit()
                                .foregroundStyle(NoopHTMLColor.ink)
                            Text("kcal").font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                        }
                        if let p = summary.projectedTotalBurn {
                            Text("heading for about \(p.formatted(.number.precision(.fractionLength(0)))) by midnight")
                                .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            legend("resting", basal, Self.basal)
                            legend("moving", active, Self.active)
                        }
                        .padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private func legend(_ name: String, _ kcal: Double, _ color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text("\(name) \(kcal.formatted(.number.precision(.fractionLength(0))))")
                .font(NoopHTMLFont.sans(NoopType.eyebrow)).monospacedDigit().foregroundStyle(NoopHTMLColor.copy)
        }
    }

    private func draw(_ context: inout GraphicsContext, _ size: CGSize, t: Double, reveal: Double) {
        let w = Double(size.width), h = Double(size.height)
        let vessel = Path(roundedRect: CGRect(x: 1, y: 1, width: w - 2, height: h - 2), cornerRadius: 26, style: .continuous)
        context.fill(vessel, with: .color(.white.opacity(0.04)))
        // Where the day is heading: a faint line at the projection, the range as a soft band.
        if let range = summary.projectedRangeKcal {
            let y0 = h * (1 - range.upperBound / capacity), y1 = h * (1 - range.lowerBound / capacity)
            context.fill(Path(CGRect(x: 0, y: y0, width: w, height: max(1, y1 - y0))), with: .color(.white.opacity(0.04)))
        }
        if let p = summary.projectedTotalBurn {
            var line = Path(); let y = h * (1 - p / capacity)
            line.move(to: CGPoint(x: 8, y: y)); line.addLine(to: CGPoint(x: w - 8, y: y))
            context.stroke(line, with: .color(.white.opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
        }
        var inside = context
        inside.clip(to: vessel)
        let level = min(1, burned / capacity) * reveal
        let activeShare = burned > 0 ? active / burned : 0
        func surfacePath(_ fill: Double, phase: Double, amp: Double) -> Path {
            var p = Path()
            let base = h * (1 - fill)
            p.move(to: CGPoint(x: 0, y: h))
            for i in 0...40 {
                let x = Double(i) / 40 * w
                let y = base + amp * sin(x / 16 + t * 1.8 + phase) + amp * 0.5 * sin(x / 7 - t * 2.6 + phase)
                p.addLine(to: CGPoint(x: x, y: y))
            }
            p.addLine(to: CGPoint(x: w, y: h)); p.closeSubpath()
            return p
        }
        // The whole burn as the lighter, moving layer; the resting part beneath it in deeper blue.
        inside.fill(surfacePath(level, phase: 0, amp: 2.6), with: .linearGradient(
            Gradient(colors: [Self.active.opacity(0.85), Self.active.opacity(0.55)]),
            startPoint: CGPoint(x: 0, y: h * (1 - level)), endPoint: CGPoint(x: 0, y: h)))
        inside.fill(surfacePath(level * (1 - activeShare), phase: 1.3, amp: 1.6), with: .linearGradient(
            Gradient(colors: [Self.basal.opacity(0.95), Color(hex: 0x123A86)]),
            startPoint: CGPoint(x: 0, y: h * (1 - level)), endPoint: CGPoint(x: 0, y: h)))
        // Bubbles rising through it.
        var fizz = inside
        fizz.blendMode = .plusLighter
        for i in 0..<9 {
            let hsh = NoopAuraMath.hash(i * 37 + 11)
            let speed = 0.12 + 0.1 * NoopAuraMath.hash(i * 13 + 5)
            let p = (t * speed + hsh).truncatingRemainder(dividingBy: 1)
            let y = h - p * h * level
            guard y > h * (1 - level) + 4 else { continue }
            let x = w * (0.15 + 0.7 * NoopAuraMath.hash(i * 7 + 3)) + 3 * sin(t * 2 + Double(i))
            let r = 1.2 + 1.8 * NoopAuraMath.hash(i * 3 + 1)
            fizz.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                        with: .color(.white.opacity(0.35 * (1 - p))), lineWidth: 0.8)
        }
        // A glint down the side of the glass.
        context.stroke(vessel, with: .color(.white.opacity(0.14)), lineWidth: 1)
        var glint = Path()
        glint.move(to: CGPoint(x: 10, y: 30)); glint.addLine(to: CGPoint(x: 10, y: h - 30))
        context.stroke(glint, with: .linearGradient(Gradient(colors: [.white.opacity(0), .white.opacity(0.18), .white.opacity(0)]),
                                                    startPoint: CGPoint(x: 0, y: 30), endPoint: CGPoint(x: 0, y: h - 30)),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }
}
