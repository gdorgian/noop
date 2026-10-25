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
