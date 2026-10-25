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
            // A paused clock (off screen, or reported so while a section was being added) shows the
            // finished drawing: a draw-in frozen at its first frame would read as no data.
            content(reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600),
                    reduceMotion || !onScreen ? 1 : reveal)
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

/// A figure that counts up from zero the first time it appears, its digits rolling into place.
struct NoopCountUp: View {
    let value: Double
    var format: (Double) -> String = { "\(Int($0.rounded()))" }
    var font: Font

    @State private var shown: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(format(shown))
            .font(font)
            .monospacedDigit()
            .contentTransition(.numericText(value: shown))
            .onAppear {
                guard shown == 0 else { return }
                if reduceMotion { shown = value; return }
                withAnimation(.spring(response: 1.1, dampingFraction: 0.9)) { shown = value }
            }
            .onChange(of: value) { _, v in withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) { shown = v } }
            .accessibilityLabel(format(value))
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
        context.fill(shape, with: .color(Self.calm.opacity(0.07 * reveal)))
        context.stroke(shape.trimmedPath(from: 0, to: reveal), with: .color(.white.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 1, lineJoin: .round))
        // The stars, each landing in turn on a spring: a small solid point in a fine ring. One
        // outside its zone is warm, and its ring breathes.
        for (i, v) in ordered.enumerated() {
            let local = max(0, min(1, reveal * Double(n + 2) - Double(i)))
            guard local > 0 else { continue }
            // A damped spring from 0 to 1: a little overshoot, then settled.
            let appear = 1 - exp(-6 * local) * cos(9 * local)
            let p = point(i, radius(v) * (0.6 + 0.4 * reveal))
            let color = v.outside ? Self.watch : Color.white
            let ringR = CGFloat(7 + (v.outside ? 2.5 * (0.5 + 0.5 * sin(t * 2.4)) : 0)) * CGFloat(appear)
            context.stroke(Path(ellipseIn: CGRect(x: p.x - ringR, y: p.y - ringR, width: 2 * ringR, height: 2 * ringR)),
                           with: .color(color.opacity(0.45)), lineWidth: 1)
            let s = CGFloat(3 * appear)
            context.fill(Path(ellipseIn: CGRect(x: p.x - s, y: p.y - s, width: 2 * s, height: 2 * s)), with: .color(color))
            // Label just outside the rim.
            let lp = point(i, 1.0 + 0.02)
            let anchor: UnitPoint = abs(cos(angle(i))) < 0.3 ? (sin(angle(i)) < 0 ? .bottom : .top)
                : (cos(angle(i)) > 0 ? .leading : .trailing)
            let label = Text("\(Self.short[v.key] ?? v.name)  ").font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
                .foregroundStyle(NoopHTMLColor.muted)
                + Text(format(v)).font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                .foregroundStyle(v.outside ? Self.watch : NoopHTMLColor.ink)
            context.opacity = min(1, local * 1.5)
            context.draw(label, at: lp, anchor: anchor)
            context.opacity = 1
        }
    }
}

// MARK: - Last night · Tide
//
// The night as water over a sea bed whose depth is the depth of sleep. Nothing moves for its own
// sake: the surface is still once drawn in. Put a finger on it to read the night — a line follows
// it with the time and the stage, the bed under it brightens, and the phone ticks at each change
// of stage.

struct NoopSleepTide: View {
    let night: NoopRestRecord.Night
    let needMin: Double
    let action: () -> Void

    @State private var scrub: Double?

    private static let deep = Color(hex: 0x4B4FC9)
    private static let surface = Color(hex: 0x8FB6FF)
    /// How far down each stage sits: awake at the surface, deep at the floor.
    private static let depth: [Double] = [0.06, 0.48, 0.3, 0.94]
    private static let names = ["Awake", "Light", "REM", "Deep"]

    var body: some View {
        NoopSlotCard(tint: Self.deep) {
            VStack(alignment: .leading, spacing: 12) {
                Button(action: action) {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        NoopCountUp(value: night.asleepMin, format: { NoopRestRecord.duration($0) },
                                    font: NoopHTMLFont.outfit(NoopType.title1, weight: .light))
                            .foregroundStyle(NoopHTMLColor.ink)
                        Text(deltaText).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                        Spacer()
                        NoopFixedChevron(direction: .right, color: NoopHTMLColor.chevronDim)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(NoopHTMLPressStyle())
                GeometryReader { geo in
                    NoopSlotClock { _, reveal in
                        Canvas { context, size in draw(&context, size, reveal: reveal) }
                    }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            let f = min(1, max(0, g.location.x / max(1, geo.size.width)))
                            if let old = scrub, stage(at: old) != stage(at: f) { NoopHaptics.play(.tick) }
                            if scrub == nil { NoopHaptics.play(.lift) }
                            scrub = f
                        }
                        .onEnded { _ in withAnimation(.easeOut(duration: 0.25)) { scrub = nil } })
                }
                .frame(height: 112)
                HStack {
                    if let f = scrub {
                        Text(timeText(f)).monospacedDigit().foregroundStyle(NoopHTMLColor.ink)
                        Text(Self.names[stage(at: f)]).foregroundStyle(stageColor(stage(at: f)))
                    } else {
                        Text(night.asleepWindow).monospacedDigit().foregroundStyle(NoopHTMLColor.faint)
                    }
                    Spacer()
                    Text("Deep \(NoopRestRecord.duration(night.stages.deep)) · REM \(NoopRestRecord.duration(night.stages.rem))")
                        .monospacedDigit().foregroundStyle(NoopHTMLColor.faint)
                }
                .font(NoopHTMLFont.sans(NoopType.caption))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Last night, \(NoopRestRecord.duration(night.asleepMin)) asleep, \(deltaText)")
    }

    private var deltaText: String {
        guard needMin > 0 else { return "asleep" }
        let d = (night.asleepMin - needMin).rounded()
        return d >= 0 ? "\(NoopRestRecord.duration(d)) over your need" : "\(NoopRestRecord.duration(-d)) short"
    }

    private func stageColor(_ st: Int) -> Color { st == 0 ? Color.white.opacity(0.7) : NoopTodayNightCard.stageColors[st] }

    private func timeText(_ f: Double) -> String {
        guard let span = night.span else { return "" }
        let d = span.lowerBound.addingTimeInterval(span.upperBound.timeIntervalSince(span.lowerBound) * f)
        return AppClock.hourMinuteFormatter().string(from: d)
    }

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

    private func stage(at f: Double) -> Int { runs.first { f >= $0.from && f < $0.to }?.stage ?? runs.last?.stage ?? 0 }

    private func draw(_ context: inout GraphicsContext, _ size: CGSize, reveal: Double) {
        let w = Double(size.width), h = Double(size.height)
        let top = 4.0, floor = h - 3
        func y(_ d: Double) -> Double { top + d * (floor - top) }
        let n = 180, k = 5
        let raw = (0...n).map { Self.depth[stage(at: Double($0) / Double(n))] }
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
        water.move(to: CGPoint(x: 0, y: top))
        for p in pts { water.addLine(to: p) }
        water.addLine(to: CGPoint(x: w, y: top)); water.closeSubpath()

        var clipped = context
        clipped.clip(to: Path(CGRect(x: 0, y: 0, width: w * reveal, height: h)))
        clipped.fill(water, with: .linearGradient(Gradient(stops: [
            .init(color: Self.surface.opacity(0.22), location: 0),
            .init(color: Self.deep.opacity(0.42), location: 0.6),
            .init(color: Color(hex: 0x1C1F5E).opacity(0.9), location: 1)
        ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        var surface = Path(); surface.move(to: CGPoint(x: 0, y: top)); surface.addLine(to: CGPoint(x: w, y: top))
        clipped.stroke(surface, with: .color(Self.surface.opacity(0.55)), lineWidth: 1)

        // The bed, coloured by stage; the stretch under a finger is brighter and thicker.
        let focus = scrub.map { stage(at: $0) }
        var i = 0
        while i < n {
            let st = stage(at: Double(i) / Double(n))
            var seg = Path(); seg.move(to: pts[i])
            var j = i + 1
            while j <= n {
                seg.addLine(to: pts[j])
                if j == n || stage(at: Double(j) / Double(n)) != st { break }
                j += 1
            }
            let dim = focus != nil && focus != st
            clipped.stroke(seg, with: .color(stageColor(st).opacity(dim ? 0.3 : 1)),
                           style: StrokeStyle(lineWidth: dim ? 1.6 : 2.4, lineCap: .round, lineJoin: .round))
            i = j
        }
        // The reading line.
        if let f = scrub {
            let x = f * w
            let idx = min(n, max(0, Int((f * Double(n)).rounded())))
            var line = Path(); line.move(to: CGPoint(x: x, y: top)); line.addLine(to: pts[idx])
            context.stroke(line, with: .color(.white.opacity(0.7)), lineWidth: 1)
            let p = pts[idx]
            context.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), with: .color(.white))
        }
    }
}

// MARK: - Energy · Reservoir
//
// The day's burn as liquid in a glass, rendered on the GPU. The level springs up to what has been
// burned; the surface stays level as the phone tilts and sloshes when it moves, then settles. The
// resting share is the deeper layer, the moving share above it; a fine line marks midnight's
// projection.

struct NoopEnergyReservoir: View {
    let summary: DailyEnergySummary
    let action: () -> Void

    private static let basalColor = Color(hex: 0x2D7FF0)
    private static let activeColor = Color(hex: 0x6FE3F5)

    @State private var level: Double = 0
    @State private var onScreen = true
    @State private var lastTilt: Double = 0
    @State private var slosh: Double = 0
    /// Whether this view holds the shared tilt sensor, so appear and disappear stay paired.
    @State private var holdsMotion = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var burned: Double { summary.totalBurnedSoFar ?? 0 }
    /// Nothing measured yet today: the glass stands empty, with the modelled day at rest marked.
    private var measured: Bool { summary.totalBurnedSoFar != nil }
    private var active: Double { summary.activeBurnedSoFar ?? 0 }
    private var basal: Double { summary.basalBurnedSoFar ?? burned }
    private var capacity: Double {
        max(burned * 1.05, summary.projectedRangeKcal?.upperBound ?? summary.projectedTotalBurn ?? summary.estimatedBMR24h ?? burned * 1.5, 1)
            * (measured ? 1 : 1.2)
    }

    var body: some View {
        Button(action: action) {
            NoopSlotCard(tint: Self.basalColor) {
                HStack(alignment: .center, spacing: 20) {
                    glass.frame(width: 96, height: 148)
                    if !measured {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nothing measured yet today")
                                .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                            Text(summary.estimatedBMR24h.map { "A day at rest would come to about \($0.formatted(.number.precision(.fractionLength(0)))) kcal. The glass fills as the strap records." }
                                 ?? "The glass fills as the strap records.")
                                .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            NoopCountUp(value: burned, format: { $0.formatted(.number.precision(.fractionLength(0))) },
                                        font: NoopHTMLFont.outfit(NoopType.title1, weight: .light))
                                .foregroundStyle(NoopHTMLColor.ink)
                            Text("kcal").font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                        }
                        Text(summary.projectedTotalBurn.map { "of about \($0.formatted(.number.precision(.fractionLength(0)))) by midnight" }
                             ?? "since midnight")
                            .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                        Spacer().frame(height: 6)
                        legend("Resting", basal, Self.basalColor)
                        legend("Moving", active, Self.activeColor)
                    }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(NoopHTMLPressStyle())
        .onAppear {
            if reduceMotion { level = 1; return }
            withAnimation(.spring(response: 1.4, dampingFraction: 0.72)) { level = 1 }
        }
    }

    private var glass: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !onScreen || reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
            let tilt = reduceMotion ? 0 : LiquidMotion.shared.tilt
            let fill = min(1, burned / capacity) * level
            let share = burned > 0 ? basal / burned : 1
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white.opacity(0.04))
                Rectangle()
                    .colorEffect(ShaderLibrary.noopLiquid(
                        .float2(CGSize(width: 96, height: 148)), .float(Float(t)), .float(Float(fill)),
                        .float(Float(-tan(tilt) * 96 / 148)), .float(Float(slosh + 0.25 * max(0, 1 - level))),
                        .float(Float(share)), .color(Self.basalColor), .color(Self.activeColor)))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                if let p = summary.projectedTotalBurn ?? (measured ? nil : summary.estimatedBMR24h) {
                    GeometryReader { g in
                        Rectangle().fill(Color.white.opacity(0.35)).frame(height: 1)
                            .padding(.horizontal, 10)
                            .offset(y: g.size.height * (1 - p / capacity))
                    }
                }
                RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            }
            .onChange(of: timeline.date) {
                // The slosh grows with how fast the phone turns and dies away over a second or so.
                let turn = abs(tilt - lastTilt)
                slosh = min(1.4, slosh * 0.94 + turn * 9)
                lastTilt = tilt
            }
        }
        .onAppear { if !holdsMotion { holdsMotion = true; LiquidMotion.shared.acquire() } }
        .onDisappear { if holdsMotion { holdsMotion = false; LiquidMotion.shared.release() } }
        .modifier(NoopSlotVisibility(onScreen: $onScreen))
    }

    private func legend(_ name: String, _ kcal: Double, _ color: Color) -> some View {
        HStack(spacing: 7) {
            Capsule().fill(color).frame(width: 12, height: 4)
            Text(name).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
            Text(kcal.formatted(.number.precision(.fractionLength(0)))).font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                .monospacedDigit().foregroundStyle(NoopHTMLColor.ink)
        }
    }
}
