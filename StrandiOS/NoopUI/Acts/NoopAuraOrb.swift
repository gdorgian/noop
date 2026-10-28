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
    /// The turn is held while a finger is down and carries on from there after.
    @State private var spinOffset: Double = 0
    @State private var heldSpin: Double?
    /// A finger on the orb, in its own coordinates. While it is down, embers are born there.
    @State private var touch: CGPoint?
    /// Where embers were being born, over the last few seconds: each mark holds from its time until
    /// the next. A nil point is the centre. An ember keeps the birthplace it had, so one born under the
    /// finger flies on from there after the finger has moved or lifted.
    @State private var emitterTrail: [(t: Double, p: CGPoint?)] = []
    /// Off screen (scrolled away or another tab) nothing animates, so the orb costs nothing there.
    @State private var onScreen = true

    private var still: Bool { paused || reduceMotion || !onScreen }
    private var segmentCount: Int { NoopAuraOrbModel.segmentCount(shapeScore) }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let scale = side / NoopAuraOrbModel.referenceSide
            let shape = NoopAmoebaShape(offsets: offsets, inset: NoopAuraOrbModel.inset(shapeScore) * scale, unit: scale)
            let palette = NoopAuraOrbModel.palette(colorScore)
            let wash = LinearGradient(colors: [palette.top, palette.bottom], startPoint: .top, endPoint: .bottom)
            ZStack {
                // Halo. Blurred at a quarter of the size and scaled up: the same soft glow for a
                // sixteenth of the pixels, which matters because the outline moves every frame.
                let q: CGFloat = 0.25, pad = 50 * scale * q * 2.5
                NoopAmoebaShape(offsets: offsets, inset: NoopAuraOrbModel.inset(shapeScore) * scale * q, unit: scale * q)
                    .stroke(wash, lineWidth: 15 * scale * q)
                    .frame(width: side * q, height: side * q)
                    .blur(radius: 50 * scale * q)
                    .padding(pad)
                    .drawingGroup()
                    .scaleEffect(1 / q)
                    .frame(width: side, height: side)
                    .opacity(0.59)
                // Body, then the dark well over it, the lit edge and the embers, drawn together on the
                // GPU: the outline moves every frame, and as plain layers these gradients were repainted
                // on the CPU each frame, a fifth of the main thread on Trends (profiled 25 Oct 2026).
                // The halo above stays outside, so the group's bounds never clip its glow.
                ZStack {
                shape.fill(wash)
                shape.fill(RadialGradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.6),
                    .init(color: .clear, location: 1)
                ], center: .center, startRadius: 0, endRadius: side / 2))
                // A fine lit edge.
                shape.stroke(wash, lineWidth: 1.2 * scale).opacity(0.85)
                // Embers.
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: still)) { timeline in
                    let t = (paused || reduceMotion) ? 4.0 : NoopAuraOrbModel.clock(timeline.date)
                    let spin = heldSpin ?? (NoopAuraOrbModel.naturalSpin(t) + spinOffset)
                    let trail = emitterTrail
                    Canvas { context, size in
                        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                        // Where the finger has been in the last two seconds: specks there are pushed aside.
                        let pushes = trail.compactMap { m in m.p.map { (t: m.t, p: $0) } }.filter { t - $0.t < 2 }
                        NoopAuraEmbers.draw(in: &context, size: size, t: t, spin: spin, scale: scale, tint: palette.bottom,
                                            pushes: pushes) { born in
                            trail.last { $0.t <= born }?.p ?? centre
                        }
                    }
                }
                .clipShape(shape)
                }
                .frame(width: side, height: side)
                .drawingGroup()
            }
            .frame(width: side, height: side)
            // Embers drifting out across the page, behind the orb; a background may overflow the frame.
            .background {
                if drift > 0 {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: still)) { timeline in
                        let t = (paused || reduceMotion) ? 4.0 : NoopAuraOrbModel.clock(timeline.date)
                        let spin = heldSpin ?? (NoopAuraOrbModel.naturalSpin(t) + spinOffset)
                        Canvas { context, size in
                            NoopAuraDrift.draw(in: &context, size: size, t: t, spin: spin, scale: scale,
                                               rim: side / 2 - NoopAuraOrbModel.inset(shapeScore) * scale,
                                               reach: side * drift, tint: palette.bottom)
                        }
                        .drawingGroup()
                    }
                    .frame(width: side * (1 + 2 * drift), height: side * (1 + 2 * drift))
                    .allowsHitTesting(false)
                }
            }
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .modifier(NoopAuraTouch(touch: $touch))
            .onChange(of: touch) { old, new in
                let natural = NoopAuraOrbModel.naturalSpin(NoopAuraOrbModel.clock(Date()))
                let now = NoopAuraOrbModel.clock(Date())
                let local = new.map { CGPoint(x: $0.x - (geo.size.width - side) / 2, y: $0.y - (geo.size.height - side) / 2) }
                emitterTrail.removeAll { now - $0.t > 8 || $0.t > now }
                emitterTrail.append((t: now, p: local))
                if (old == nil) != (new == nil) {
                    if new != nil { heldSpin = natural + spinOffset }
                    else { spinOffset = (heldSpin ?? natural) - natural; heldSpin = nil }
                }
            }
        }
        .task(id: [segmentCount, onScreen ? 1 : 0]) { await morph() }
        .onAppear { onScreen = true }
        .onDisappear { onScreen = false }
        .modifier(NoopAuraVisibility(onScreen: $onScreen))
        .accessibilityHidden(true)
    }

    /// Once a second, every offset takes a new random target and eases there over six seconds.
    private func morph() async {
        let count = segmentCount
        offsets = NoopAuraOrbModel.randomOffsets(count: count, score: shapeScore)
        guard !still else { return }
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

/// Embers, as WHOOP's particle system emits them: born tiny at the emission point, under the age
/// unless a finger is down, then thrown outward in a slow spiral, slowing as they go, growing on the
/// way and fading out near the rim, the whole field turning once every thirty seconds. Each lives two
/// and a half to four seconds. `emitter` gives the birthplace for a birth time.
enum NoopAuraEmbers {
    static func draw(in context: inout GraphicsContext, size: CGSize, t: Double, spin: Double, scale: CGFloat,
                     tint: Color = .white, pushes: [(t: Double, p: CGPoint)] = [], emitter: (Double) -> CGPoint) {
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        let r = Double(min(size.width, size.height)) / 2
        context.blendMode = .plusLighter
        for i in 0..<230 {
            let h = { (k: Int) in NoopAuraMath.hash(i * 13 + k) }
            let life = 2.5 + 1.5 * h(1)
            let p = ((t + h(2) * life * 7) / life).truncatingRemainder(dividingBy: 1)
            let origin = emitter(t - p * life)
            let travel = 1 - (1 - p) * (1 - p)
            // From the age they start on a ring clear of the number and its label; from a finger, at it.
            let fromAge = abs(origin.x - centre.x) < 0.5 && abs(origin.y - centre.y) < 0.5
            let start = fromAge ? 0.4 : 0.03
            let dist = r * (start + (0.5 + 0.48 * sqrt(h(3)) - start) * travel)
            let angle = h(4) * 2 * .pi + spin + (h(5) < 0.5 ? 1 : -1) * 0.5 * travel
            var x = origin.x + CGFloat(cos(angle) * dist), y = origin.y + CGFloat(sin(angle) * dist)
            // The finger repels, as WHOOP's negative attraction does: a speck that was already out when
            // the finger passed is pushed to the edge of a clear ring around that point, like sand.
            let born = t - p * life
            let clear = r * (0.17 + 0.05 * h(8))
            for m in pushes where m.t > born + 0.1 {
                let dx = Double(x - m.p.x), dy = Double(y - m.p.y)
                let d = (dx * dx + dy * dy).squareRoot()
                guard d < clear else { continue }
                let ux = d > 0.001 ? dx / d : cos(h(9) * 2 * .pi), uy = d > 0.001 ? dy / d : sin(h(9) * 2 * .pi)
                x = m.p.x + CGFloat(ux * clear); y = m.p.y + CGFloat(uy * clear)
            }
            let big = h(6) > 0.88
            let grown = 0.2 + 0.8 * travel
            let s = Double(scale) * (big ? 4.5 + 4.5 * h(7) : 1.3 + 2.4 * h(7)) * grown
            // They fade in as they appear and out before the rim, in the orb's own light colour.
            let alpha = NoopAuraMath.step(0, 0.18, p) * (1 - NoopAuraMath.step(0.72, 1, p)) * (big ? 0.45 : 0.95)
            guard alpha > 0.02 else { continue }
            let rect = CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s)
            if big {
                // A soft out-of-focus glint: a lit middle fading to its edge.
                context.fill(Path(ellipseIn: rect), with: .radialGradient(
                    Gradient(colors: [tint.opacity(alpha), tint.opacity(alpha * 0.55), tint.opacity(0)]),
                    center: CGPoint(x: x, y: y), startRadius: 0, endRadius: s / 2))
            } else {
                context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(alpha)))
                context.fill(Path(ellipseIn: rect.insetBy(dx: s * 0.3, dy: s * 0.3)), with: .color(.white.opacity(alpha * 0.5)))
            }
        }
    }
}

/// Embers that leave the orb: born on the rim, they drift slowly outward over six to eleven seconds,
/// turning with the field at half its pace, and fade as they get farther away.
enum NoopAuraDrift {
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
            let color = h(9) > 0.85 ? Color.white : tint
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

/// Tracks whether the orb is scrolled into view.
private struct NoopAuraVisibility: ViewModifier {
    @Binding var onScreen: Bool

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollVisibilityChange(threshold: 0.02) { onScreen = $0 }
        } else {
            content
        }
    }
}

// MARK: - Touch

/// Hold, then drag: a short still press begins it, so a swipe that starts on the orb fails it and the
/// page scrolls. Reports the finger in the orb's coordinates; nil when lifted.
private struct NoopAuraTouch: ViewModifier {
    @Binding var touch: CGPoint?

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.gesture(NoopAuraTouchRecognizer(touch: $touch))
        } else {
            content
        }
    }
}

@available(iOS 18.0, *)
private struct NoopAuraTouchRecognizer: UIGestureRecognizerRepresentable {
    @Binding var touch: CGPoint?

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let press = UILongPressGestureRecognizer()
        press.minimumPressDuration = 0.12
        press.allowableMovement = 10
        return press
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed: touch = context.converter.localLocation
        default: touch = nil
        }
    }
}
