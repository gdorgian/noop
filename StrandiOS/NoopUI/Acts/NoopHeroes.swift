import SwiftUI

// MARK: - Page heroes
//
// The second and third heroes for each score page (the first is each page's own). All draw into the
// template's square, from the page's own numbers, and settle once drawn in: motion is the data
// arriving or a slow signal of the body (a pulse at the resting rate, a breath), never decoration.

private func noopHeroFigure(_ value: String?, _ label: String, suffix: String = "") -> some View {
    VStack(spacing: 0) {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(value ?? "—").font(NoopHTMLFont.outfit(NoopType.title1 + 14, weight: .light)).monospacedDigit()
            if value != nil, !suffix.isEmpty { Text(suffix).font(NoopHTMLFont.outfit(NoopType.title3, weight: .light)) }
        }
        .foregroundStyle(value == nil ? NoopHTMLColor.faint : NoopHTMLColor.ink)
        Text(label).font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).tracking(1.4)
            .foregroundStyle(NoopHTMLColor.inkSoft)
    }
    .shadow(color: .black.opacity(0.45), radius: 8)
}

// MARK: Recovery

/// Recovery as a flower that opens as far as the score.
struct NoopRecoveryBloom: View {
    let fill: Double
    let tint: Color
    let deep: Color
    let value: Double?

    var body: some View {
        let side = NoopPageHeroMetrics.heroSide
        NoopSlotClock { t, reveal in
            ZStack {
                Rectangle().colorEffect(ShaderLibrary.noopBloom(.float2(CGSize(width: side, height: side)), .float(Float(t)),
                                                                .float(Float(fill * NoopRingValues.spring(reveal))),
                                                                .color(tint), .color(deep)))
                noopHeroFigure(value.map { "\(Int($0.rounded()))" }, "RECOVERED", suffix: "%")
            }
        }
        .frame(width: side, height: side)
        .accessibilityLabel(value.map { "Recovery \(Int($0.rounded())) percent" } ?? "Recovery not measured yet")
    }
}

/// Recovery as one clean ring; rings of light leave the centre at your resting heart rate.
struct NoopRecoveryPulse: View {
    let fill: Double
    let tint: Color
    let value: Double?
    let restingBPM: Double?

    var body: some View {
        let side = NoopPageHeroMetrics.heroSide
        NoopSlotClock { t, reveal in
            Canvas { context, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let R = size.width / 2 - 12
                // Beats: one ring per beat at the resting rate, spreading and fading.
                let period = 60 / max(40, restingBPM ?? 60)
                for k in 0..<3 {
                    let phase = ((t / period) + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                    let r = R * 0.32 + (R * 0.62) * phase
                    context.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                                   with: .color(tint.opacity(0.28 * (1 - phase) * reveal)), lineWidth: 1.2)
                }
                // Track and the score.
                context.stroke(Path(ellipseIn: CGRect(x: c.x - R, y: c.y - R, width: 2 * R, height: 2 * R)),
                               with: .color(.white.opacity(0.07)), lineWidth: 10)
                let f = fill * NoopRingValues.spring(reveal)
                guard f > 0.002 else { return }
                var arc = Path()
                arc.addArc(center: c, radius: R, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * f), clockwise: false)
                var glow = context
                glow.addFilter(.blur(radius: 8))
                glow.stroke(arc, with: .color(tint.opacity(0.6)), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                context.stroke(arc, with: .color(tint), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            }
            .overlay { noopHeroFigure(value.map { "\(Int($0.rounded()))" }, "RECOVERED", suffix: "%") }
        }
        .frame(width: side, height: side)
        .accessibilityLabel(value.map { "Recovery \(Int($0.rounded())) percent" } ?? "Recovery not measured yet")
    }
}

// MARK: Strain

/// Strain on a three-quarter gauge with today's target marked; the needle swings in on a spring.
struct NoopStrainGauge: View {
    let level: Double
    let value: Double?
    /// Target as fractions of the scale, from the morning's recovery; nil draws none.
    let target: ClosedRange<Double>?

    var body: some View {
        let side = NoopPageHeroMetrics.heroSide
        NoopSlotClock { _, reveal in
            Canvas { context, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2 + 10)
                let R = size.width / 2 - 18
                let start = 135.0, sweep = 270.0
                func angle(_ f: Double) -> Angle { .degrees(start + sweep * f) }
                func arc(_ a: Double, _ b: Double, _ r: CGFloat) -> Path {
                    var p = Path(); p.addArc(center: c, radius: r, startAngle: angle(a), endAngle: angle(b), clockwise: false); return p
                }
                // Ticks.
                for i in 0...54 {
                    let f = Double(i) / 54, a = angle(f).radians
                    let major = i % 9 == 0
                    var tick = Path()
                    tick.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * (R + 8), y: c.y + CGFloat(sin(a)) * (R + 8)))
                    tick.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * (R + (major ? 16 : 12)), y: c.y + CGFloat(sin(a)) * (R + (major ? 16 : 12))))
                    context.stroke(tick, with: .color(.white.opacity(major ? 0.35 : 0.14)), lineWidth: major ? 1.5 : 1)
                }
                context.stroke(arc(0, 1, R), with: .color(.white.opacity(0.07)), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                if let target {
                    context.stroke(arc(target.lowerBound, target.upperBound, R), with: .color(Color(hex: 0xF5B451).opacity(0.28)),
                                   style: StrokeStyle(lineWidth: 14, lineCap: .butt))
                }
                let f = level * NoopRingValues.spring(reveal)
                if f > 0.002 {
                    context.stroke(arc(0, f, R), with: .linearGradient(Gradient(colors: [Color(hex: 0xF5D27A), Color(hex: 0xFF6A3D)]),
                                                                       startPoint: CGPoint(x: c.x - R, y: c.y + R), endPoint: CGPoint(x: c.x + R, y: c.y - R)),
                                   style: StrokeStyle(lineWidth: 14, lineCap: .round))
                }
                // Needle.
                let a = angle(f).radians
                var needle = Path()
                needle.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * (R - 26), y: c.y + CGFloat(sin(a)) * (R - 26)))
                needle.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * (R + 6), y: c.y + CGFloat(sin(a)) * (R + 6)))
                context.stroke(needle, with: .color(.white), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
            .overlay { noopHeroFigure(value.map { String(format: "%.0f", $0) }, "STRAIN").offset(y: 10) }
        }
        .frame(width: side, height: side)
        .accessibilityLabel(value.map { "Strain \(Int($0.rounded())) of 100" } ?? "No strain yet")
    }
}

/// The day's heart rate wrapped round a circle: one bar per stretch of the day, as tall as the pulse
/// above resting and coloured by how hard it was, drawn in from midnight.
struct NoopStrainDayRing: View {
    let points: [(time: Date, bpm: Double)]
    let resting: Double?
    let value: Double?

    var body: some View {
        let side = NoopPageHeroMetrics.heroSide
        NoopSlotClock { _, reveal in
            Canvas { context, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let inner = size.width / 2 * 0.52, outer = size.width / 2 - 6
                let midnight = Calendar.current.startOfDay(for: Date())
                let n = 96
                var bins = [Double](repeating: 0, count: n), counts = [Int](repeating: 0, count: n)
                for p in points {
                    let f = p.time.timeIntervalSince(midnight) / 86_400
                    guard f >= 0, f < 1 else { continue }
                    let i = Int(f * Double(n)); bins[i] += p.bpm; counts[i] += 1
                }
                let rest = resting ?? 60
                for i in 0..<n {
                    let a = (Double(i) / Double(n)) * 2 * .pi - .pi / 2
                    var tick = Path()
                    let r0 = inner
                    if counts[i] == 0 {
                        tick.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * r0, y: c.y + CGFloat(sin(a)) * r0))
                        tick.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * (r0 + 3), y: c.y + CGFloat(sin(a)) * (r0 + 3)))
                        context.stroke(tick, with: .color(.white.opacity(0.1)), lineWidth: 2)
                        continue
                    }
                    guard Double(i) / Double(n) <= reveal else { continue }
                    let bpm = bins[i] / Double(counts[i])
                    let lift = min(1, max(0.04, (bpm - rest) / 80))
                    let r1 = r0 + (outer - r0) * CGFloat(lift)
                    tick.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * r0, y: c.y + CGFloat(sin(a)) * r0))
                    tick.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * r1, y: c.y + CGFloat(sin(a)) * r1))
                    let color = lift > 0.6 ? Color(hex: 0xFF6A3D) : lift > 0.3 ? Color(hex: 0xF5B451) : Color(hex: 0xF5D27A).opacity(0.7)
                    context.stroke(tick, with: .color(color), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                }
                // Now.
                let nowF = Date().timeIntervalSince(midnight) / 86_400
                let na = nowF * 2 * .pi - .pi / 2
                let np = CGPoint(x: c.x + CGFloat(cos(na)) * (inner - 10), y: c.y + CGFloat(sin(na)) * (inner - 10))
                context.fill(Path(ellipseIn: CGRect(x: np.x - 3, y: np.y - 3, width: 6, height: 6)), with: .color(.white))
            }
            .overlay { noopHeroFigure(value.map { String(format: "%.0f", $0) }, "STRAIN") }
        }
        .frame(width: side, height: side)
        .accessibilityLabel(value.map { "Strain \(Int($0.rounded())) of 100, with today's heart rate around it" } ?? "No strain yet")
    }
}

// MARK: Trends

/// Body age as tree rings: one ring per year from the centre out, the years up to your real age in
/// the page's green, the years past it in amber, the last ring a fraction for the part-year. They
/// grow outward when shown, like a trunk laying down its years.
struct NoopAgeTreeRings: View {
    let bodyAge: Double?
    let chronoAge: Int
    let palette: (top: Color, bottom: Color)

    var body: some View {
        NoopSlotClock { t, reveal in
            Canvas { context, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let R = min(size.width, size.height) * 0.40
                let years = max(1, bodyAge ?? Double(max(chronoAge, 1)))
                let shownYears = years * reveal
                let total = max(years, Double(chronoAge)) + 2
                let step = R / CGFloat(total)
                let whole = Int(shownYears)
                for y in 0...whole {
                    let isPart = y == whole
                    let f = isPart ? shownYears - Double(whole) : 1
                    guard f > 0.01 else { continue }
                    // Rings wobble a little, more in older years, like real growth rings.
                    let base = CGFloat(Double(y) + f) * step
                    var ring = Path()
                    for i in 0...90 {
                        let a = Double(i) / 90 * 2 * .pi
                        let wob = 1 + 0.018 * sin(a * 3 + Double(y) * 1.7) + 0.012 * sin(a * 7 - Double(y))
                        let p = CGPoint(x: c.x + CGFloat(cos(a) * wob) * base, y: c.y + CGFloat(sin(a) * wob) * base)
                        if i == 0 { ring.move(to: p) } else { ring.addLine(to: p) }
                    }
                    let past = chronoAge > 0 && y >= chronoAge
                    let color = past ? Color(hex: 0xFFB54A) : palette.bottom
                    let bright = 0.18 + 0.5 * (Double(y) / total)
                    context.stroke(ring, with: .color(color.opacity(bright * (isPart ? f : 1))), lineWidth: y % 5 == 4 ? 1.6 : 0.9)
                }
                // Your real age, a fine dashed circle.
                if chronoAge > 0 {
                    let r = CGFloat(chronoAge) * step
                    context.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                                   with: .color(.white.opacity(0.45 * reveal)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                }
                // A faint living glow at the heart.
                let g = R * 0.5 * CGFloat(1 + 0.04 * sin(t * 0.9))
                context.fill(Path(ellipseIn: CGRect(x: c.x - g, y: c.y - g, width: 2 * g, height: 2 * g)),
                             with: .radialGradient(Gradient(colors: [palette.top.opacity(0.18), .clear]), center: c, startRadius: 0, endRadius: g))
            }
        }
    }
}

/// Body age as a breathing field of the orb's colours: a mesh whose points drift slowly, rounder and
/// calmer when the pace is slow, more restless when it is fast.
struct NoopAgeField: View {
    let palette: (top: Color, bottom: Color)
    let shapeScore: Double

    var body: some View {
        NoopSlotClock { t, reveal in
            GeometryReader { g in
                let side = min(g.size.width, g.size.height) * 0.82
                Group {
                    if #available(iOS 18.0, *) {
                        let w = 0.06 + 0.10 * shapeScore
                        let pts: [SIMD2<Float>] = (0..<16).map { i in
                            let x = Double(i % 4) / 3, y = Double(i / 4) / 3
                            let edge = x == 0 || x == 1 || y == 0 || y == 1
                            let dx = edge ? 0 : w * sin(t * 0.6 + Double(i) * 1.3)
                            let dy = edge ? 0 : w * cos(t * 0.5 + Double(i) * 0.9)
                            return SIMD2(Float(x + dx), Float(y + dy))
                        }
                        // Lit at the rim, dark in the middle where the age sits.
                        let dark = Color(hex: 0x040807)
                        MeshGradient(width: 4, height: 4, points: pts, colors: [
                            dark, palette.top.opacity(0.55), palette.bottom.opacity(0.45), dark,
                            palette.bottom.opacity(0.5), dark, dark, palette.top.opacity(0.45),
                            palette.top.opacity(0.45), dark, dark, palette.bottom.opacity(0.5),
                            dark, palette.bottom.opacity(0.45), palette.top.opacity(0.55), dark
                        ])
                    } else {
                        RadialGradient(colors: [palette.top, palette.bottom.opacity(0.4), .clear], center: .center,
                                       startRadius: 0, endRadius: side / 2)
                    }
                }
                .frame(width: side, height: side)
                .clipShape(Circle())
                .overlay(Circle().fill(RadialGradient(colors: [.black.opacity(0.7), .black.opacity(0.35), .clear], center: .center,
                                                      startRadius: 0, endRadius: side * 0.42)))
                .overlay(Circle().strokeBorder(palette.bottom.opacity(0.4), lineWidth: 1))
                .scaleEffect(0.85 + 0.15 * reveal)
                .opacity(reveal)
                .position(x: g.size.width / 2, y: g.size.height / 2)
            }
        }
    }
}
