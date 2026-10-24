import SwiftUI

// MARK: - Aura orb
//
// The body-age orb. Its outline is a closed curve through N points on a circle, each pushed out by
// its own radial offset; once a second every offset picks a new random target and eases there over
// six seconds, so the overlapping moves never settle and never repeat. A worse score adds points and
// widens the offsets, so a calm reading is a soft round blob and a poor one is lumpy and restless.
// The body is a two-colour wash under a dark well that clears toward the rim, with a wide blurred
// halo outside it. Embers drift inside the outline, the whole field turning once every thirty
// seconds; a sideways drag spins it, and it carries on from where it was left.

struct NoopAuraOrb: View {
    /// 0 calm … 1 restless: drives the point count and how far the outline moves.
    var shapeScore: Double
    /// 0 green (younger) … 0.5 teal (on your age) … 1 amber (older).
    var colorScore: Double
    var paused = false
    /// How far past the frame the drifting embers may travel, as a multiple of the frame side.
    var drift: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offsets = NoopAuraVector(Array(repeating: 0, count: 5))
    @State private var spinOffset: Double = 0
    @State private var dragAngle: Double?

    private var segmentCount: Int { NoopAuraOrbModel.segmentCount(shapeScore) }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let scale = side / NoopAuraOrbModel.referenceSide
            let shape = NoopAmoebaShape(offsets: offsets, inset: NoopAuraOrbModel.inset(shapeScore) * scale, unit: scale)
            let palette = NoopAuraOrbModel.palette(colorScore)
            let wash = LinearGradient(colors: [palette.top, palette.bottom], startPoint: .top, endPoint: .bottom)
            ZStack {
                // Halo.
                shape
                    .stroke(wash, lineWidth: 15 * scale)
                    .blur(radius: 50 * scale)
                    .opacity(0.59)
                // Body, then the dark well over it.
                shape.fill(wash)
                shape.fill(RadialGradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.6),
                    .init(color: .clear, location: 1)
                ], center: .center, startRadius: 0, endRadius: side / 2))
                // A fine lit edge.
                shape.stroke(wash, lineWidth: 1.2 * scale).opacity(0.85)
                // Embers.
                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: paused || reduceMotion)) { timeline in
                    let t = (paused || reduceMotion) ? 4.0 : NoopAuraOrbModel.clock(timeline.date)
                    let spin = (dragAngle ?? NoopAuraOrbModel.naturalSpin(t)) + spinOffset
                    Canvas { context, size in
                        NoopAuraEmbers.draw(in: &context, size: size, t: t, spin: spin, scale: scale)
                    }
                }
                .clipShape(shape)
            }
            .frame(width: side, height: side)
            // Embers drifting out across the page, behind the orb; a background may overflow the frame.
            .background {
                if drift > 0 {
                    TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: paused || reduceMotion)) { timeline in
                        let t = (paused || reduceMotion) ? 4.0 : NoopAuraOrbModel.clock(timeline.date)
                        let spin = (dragAngle ?? NoopAuraOrbModel.naturalSpin(t)) + spinOffset
                        Canvas { context, size in
                            NoopAuraDrift.draw(in: &context, size: size, t: t, spin: spin, scale: scale,
                                               rim: side / 2 - NoopAuraOrbModel.inset(shapeScore) * scale,
                                               reach: side * drift, tint: palette.bottom)
                        }
                    }
                    .frame(width: side * (1 + 2 * drift), height: side * (1 + 2 * drift))
                    .allowsHitTesting(false)
                }
            }
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .modifier(NoopAuraSpinGesture(center: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2),
                                          dragAngle: $dragAngle, spinOffset: $spinOffset))
        }
        .task(id: segmentCount) { await morph() }
        .accessibilityHidden(true)
    }

    /// Once a second, every offset takes a new random target and eases there over six seconds.
    private func morph() async {
        let count = segmentCount
        offsets = NoopAuraOrbModel.randomOffsets(count: count, score: shapeScore)
        guard !paused, !reduceMotion else { return }
        while !Task.isCancelled {
            withAnimation(.easeInOut(duration: 6)) {
                offsets = NoopAuraOrbModel.randomOffsets(count: count, score: shapeScore)
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }
}

enum NoopAuraOrbModel {
    /// The side the offsets below are measured against; other sizes scale them.
    static let referenceSide: CGFloat = 260

    static func clock(_ date: Date) -> Double { date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600) }
    /// One full turn every thirty seconds.
    static func naturalSpin(_ t: Double) -> Double { t / 30 * 2 * .pi }

    /// Five points when calm, fourteen in the middle, up to twenty-five when restless.
    static func segmentCount(_ score: Double) -> Int {
        let s = min(max(score, 0), 1)
        let n = s > 0.5 ? 2 * (s - 0.5) * 11 + 14 : 2 * s * 9 + 5
        return Int(n.rounded())
    }

    /// The outline is drawn this far inside the frame, which leaves room for outward offsets.
    static func inset(_ score: Double) -> CGFloat { CGFloat(27.2 - 7.4 * min(max(score, 0), 1)) }

    static func randomOffsets(count: Int, score: Double) -> NoopAuraVector {
        let s = min(max(score, 0), 1)
        let lower = -27.4 * s, upper = 27.2 - 7.4 * s
        return NoopAuraVector((0..<count).map { _ in Double.random(in: lower...upper) })
    }

    /// Green under your age, amber over it, the blues only in the year either side of it.
    /// With no age yet it sits at green, the same as an unmeasured page.
    static func colorScore(yearsDifference d: Double?) -> Double {
        guard let d else { return 0 }
        return d >= 0 ? 2.0 / 3.0 + min(d, 1) / 3 : max(0, 1.0 / 3.0 * (1 + d))
    }

    /// Green under your age, through teal and blue, to amber over it; each a pair washed top to bottom.
    private static let palettes: [(UInt32, UInt32)] = [
        (0x00F19F, 0x79FFBF), (0x00F19F, 0x70C0FF), (0x69D3DD, 0x70C0FF), (0xFFA722, 0xFFE66A)
    ]

    static func palette(_ score: Double) -> (top: Color, bottom: Color) {
        let s = min(max(score, 0), 1) * Double(palettes.count - 1)
        let i = min(Int(s), palettes.count - 2), t = s - Double(i)
        let a = palettes[i], b = palettes[i + 1]
        return (mix(a.0, b.0, t), mix(a.1, b.1, t))
    }

    private static func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> Color {
        func c(_ v: UInt32, _ shift: UInt32) -> Double { Double((v >> shift) & 0xFF) / 255 }
        return Color(red: c(a, 16) + (c(b, 16) - c(a, 16)) * t,
                     green: c(a, 8) + (c(b, 8) - c(a, 8)) * t,
                     blue: c(a, 0) + (c(b, 0) - c(a, 0)) * t)
    }
}

/// Radial offsets as one animatable value, so SwiftUI eases every point of the outline together.
struct NoopAuraVector: VectorArithmetic {
    var values: [Double]
    init(_ values: [Double]) { self.values = values }

    static var zero: NoopAuraVector { NoopAuraVector([]) }
    static func + (l: NoopAuraVector, r: NoopAuraVector) -> NoopAuraVector { combine(l, r, +) }
    static func - (l: NoopAuraVector, r: NoopAuraVector) -> NoopAuraVector { combine(l, r, -) }
    mutating func scale(by rhs: Double) { values = values.map { $0 * rhs } }
    var magnitudeSquared: Double { values.reduce(0) { $0 + $1 * $1 } }

    private static func combine(_ l: NoopAuraVector, _ r: NoopAuraVector, _ op: (Double, Double) -> Double) -> NoopAuraVector {
        let n = max(l.values.count, r.values.count)
        return NoopAuraVector((0..<n).map { i in
            op(i < l.values.count ? l.values[i] : 0, i < r.values.count ? r.values[i] : 0)
        })
    }
}

/// N points on a circle, each pushed out along its radius by `offsets × unit`, joined by curves whose
/// handles run along the circle's tangent at 4/3·tan(π/2N) of the radius — the length that makes N
/// unmoved points a circle.
struct NoopAmoebaShape: Shape {
    var offsets: NoopAuraVector
    var inset: CGFloat
    var unit: CGFloat = 1

    var animatableData: NoopAuraVector {
        get { offsets }
        set { offsets = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let n = offsets.values.count
        guard n >= 3 else { return Path(ellipseIn: rect.insetBy(dx: inset, dy: inset)) }
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let base = Double(min(rect.width, rect.height) / 2 - inset)
        let k = 4.0 / 3.0 * tan(Double.pi / (2 * Double(n)))
        let pts: [(p: CGPoint, tan: CGVector)] = (0..<n).map { i in
            let a = Double(i) / Double(n) * 2 * .pi - .pi / 2
            let r = max(1, base + offsets.values[i] * Double(unit))
            let p = CGPoint(x: c.x + CGFloat(cos(a) * r), y: c.y + CGFloat(sin(a) * r))
            return (p, CGVector(dx: -sin(a) * r * k, dy: cos(a) * r * k))
        }
        var path = Path()
        path.move(to: pts[0].p)
        for i in 1...n {
            let prev = pts[i - 1], cur = pts[i % n]
            path.addCurve(to: cur.p,
                          control1: CGPoint(x: prev.p.x + prev.tan.dx, y: prev.p.y + prev.tan.dy),
                          control2: CGPoint(x: cur.p.x - cur.tan.dx, y: cur.p.y - cur.tan.dy))
        }
        path.closeSubpath()
        return path
    }
}

/// Embers: each lives two to three and a half seconds, born in the lit band and drawn a little toward
/// the core while it shrinks to half; brighter over the rim than over the dark well.
private enum NoopAuraEmbers {
    static func draw(in context: inout GraphicsContext, size: CGSize, t: Double, spin: Double, scale: CGFloat) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let r = Double(min(size.width, size.height)) / 2
        context.blendMode = .plusLighter
        for i in 0..<260 {
            let h = { (k: Int) in NoopAuraMath.hash(i * 13 + k) }
            let life = 2 + 1.5 * h(1)
            let p = ((t + h(2) * life * 7) / life).truncatingRemainder(dividingBy: 1)
            let start = 0.45 + 0.50 * sqrt(h(3))
            let dist = start * (1 - 0.22 * p * p) * r
            let angle = h(4) * 2 * .pi + spin + (h(5) - 0.5) * 0.35 * p
            let x = c.x + CGFloat(cos(angle) * dist), y = c.y + CGFloat(sin(angle) * dist)
            let big = h(6) > 0.86
            let s = Double(scale) * (big ? 4.5 + 5 * h(7) : 1.4 + 2.6 * h(7)) * (1 - 0.5 * p)
            let band = 0.18 + 0.82 * NoopAuraMath.step(0.42, 0.8, dist / r)
            let alpha = NoopAuraMath.step(0, 0.15, p) * (1 - NoopAuraMath.step(0.7, 1, p)) * band * (big ? 0.5 : 0.95)
            guard alpha > 0.02 else { continue }
            let rect = CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s)
            if big {
                context.fill(Path(ellipseIn: rect), with: .radialGradient(
                    Gradient(colors: [.white.opacity(alpha), .white.opacity(alpha * 0.25)]),
                    center: CGPoint(x: x, y: y), startRadius: 0, endRadius: s / 2))
            } else {
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
            }
        }
    }
}

/// Embers that leave the orb: born on the rim, they drift slowly outward over six to eleven seconds,
/// turning with the field at half its pace, and fade as they get farther away.
private enum NoopAuraDrift {
    static func draw(in context: inout GraphicsContext, size: CGSize, t: Double, spin: Double, scale: CGFloat,
                     rim: CGFloat, reach: CGFloat, tint: Color) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        context.blendMode = .plusLighter
        for i in 0..<140 {
            let h = { (k: Int) in NoopAuraMath.hash(i * 17 + 5000 + k) }
            let life = 6 + 5 * h(1)
            let p = ((t + h(2) * life * 9) / life).truncatingRemainder(dividingBy: 1)
            let travel = 1 - pow(1 - p, 1.6)
            let dist = Double(rim) * (0.88 + 0.1 * h(3)) + Double(reach) * (0.15 + 0.85 * h(4)) * travel
            let angle = h(5) * 2 * .pi + spin * 0.5 + (h(6) - 0.5) * 0.6 * p
            let x = c.x + CGFloat(cos(angle) * dist), y = c.y + CGFloat(sin(angle) * dist)
            let away = max(0, (dist - Double(rim)) / Double(reach))
            let fade = NoopAuraMath.step(0, 0.12, p) * pow(max(0, 1 - away), 1.4)
            let big = h(7) > 0.85
            let s = Double(scale) * (big ? 3.5 + 4 * h(8) : 1.2 + 2.2 * h(8)) * (1 - 0.35 * travel)
            let alpha = fade * (big ? 0.45 : 0.8)
            guard alpha > 0.02 else { continue }
            let rect = CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s)
            let color = h(9) > 0.5 ? Color.white : tint
            if big {
                context.fill(Path(ellipseIn: rect.insetBy(dx: -s * 0.6, dy: -s * 0.6)), with: .radialGradient(
                    Gradient(colors: [color.opacity(alpha), color.opacity(0)]),
                    center: CGPoint(x: x, y: y), startRadius: 0, endRadius: s * 1.1))
            } else {
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
            }
        }
    }
}

enum NoopAuraMath {
    static func hash(_ n: Int) -> Double {
        let x = sin(Double(n) * 127.1 + 311.7) * 43_758.5453
        return x - floor(x)
    }
    static func smooth(_ x: Double) -> Double { let c = max(0, min(1, x)); return c * c * (3 - 2 * c) }
    static func step(_ a: Double, _ b: Double, _ x: Double) -> Double { smooth((x - a) / (b - a)) }
}

// MARK: - Spin

/// A sideways drag turns the ember field with the finger; vertical drags are left to the page's
/// scroll. On release the field keeps the angle it was left at and carries on turning from there.
private struct NoopAuraSpinGesture: ViewModifier {
    let center: CGPoint
    @Binding var dragAngle: Double?
    @Binding var spinOffset: Double

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.gesture(NoopAuraSpinRecognizer(center: center, dragAngle: $dragAngle, spinOffset: $spinOffset))
        } else {
            content
        }
    }
}

@available(iOS 18.0, *)
private struct NoopAuraSpinRecognizer: UIGestureRecognizerRepresentable {
    let center: CGPoint
    @Binding var dragAngle: Double?
    @Binding var spinOffset: Double

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var startAngle = 0.0
        var startSpin = 0.0
        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            guard let pan = g as? UIPanGestureRecognizer else { return true }
            let v = pan.velocity(in: pan.view)
            return abs(v.x) > abs(v.y) * 1.2
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let p = context.converter.localLocation
        let angle = atan2(Double(p.y - center.y), Double(p.x - center.x))
        let natural = NoopAuraOrbModel.naturalSpin(NoopAuraOrbModel.clock(Date()))
        switch recognizer.state {
        case .began:
            context.coordinator.startAngle = angle
            context.coordinator.startSpin = natural + spinOffset
            spinOffset = 0
            dragAngle = context.coordinator.startSpin
        case .changed:
            var delta = angle - context.coordinator.startAngle
            if delta > .pi { delta -= 2 * .pi } else if delta < -.pi { delta += 2 * .pi }
            dragAngle = context.coordinator.startSpin + delta
        default:
            spinOffset = (dragAngle ?? natural) - natural
            dragAngle = nil
        }
    }
}
