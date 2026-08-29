#if os(iOS)
import SwiftUI

// MARK: - Biomarkers hero (Act 8, `labs`)
//
// A horizontal double helix whose seven rungs ARE the seven markers, in list order. A rung and its
// two end nodes go amber when that marker sits outside the laboratory's band. Replaces the radar +
// speck field that stood here before; the numeral and the marker list below carry the same reading,
// so the helix is never the only place a state is visible.
//
// Geometry, timings and colours are the design handoff's (design_handoff_labs_helix/README.md §2).
// Two deliberate departures from the handoff's reference implementation, both noted at their site:
// the rung keeps a hairline floor rather than collapsing to nothing, and halos are drawn as radial
// gradients rather than per-node blur filters.

struct NoopHelixMarker: Identifiable {
    let id: String
    let outOfBand: Bool
}

struct NoopHelixHero: View {
    /// Seven, in the same order as the list below the hero.
    let markers: [NoopHelixMarker]

    /// The only knob worth exposing. Handoff range 4…18.
    var secondsPerTurn: Double = 9
    var columns: Int = 58
    var turns: Double = 2.4
    var amplitude: CGFloat = 36
    var height: CGFloat = 210

    /// The bright pulse crossing left → right, and the whole-helix sway. Deliberately
    /// incommensurate with each other and with the rotation so they never beat together.
    private let waveCycle: Double = 3.6
    private let waveLead: Double = 2.9
    private let swayCycle: Double = 17
    private let glowCycle: Double = 9

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var anyOut: Bool { markers.contains(where: \.outOfBand) }

    /// Freeze for Reduce Motion, in the background, and in Low Power Mode. Navigating away from
    /// `labs` destroys this view outright (NoopShell swaps on `.id(route)`), so a pushed screen
    /// stops the timeline without needing to be detected here.
    private var paused: Bool {
        reduceMotion || scenePhase != .active || ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: paused)) { timeline in
            // Frozen at a quarter turn: rungs near full extension, nothing moving.
            let t = paused
                ? secondsPerTurn * 0.25
                : timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                glow(t: t)
                Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                    draw(context: &context, size: size, t: t)
                }
            }
        }
        .frame(height: height)
        // The numeral ("5 of 7 in band") and each marker row already announce the reading.
        .accessibilityHidden(true)
    }

    // MARK: Glow

    /// 340 × 210 blurred radial behind everything, breathing 0.65 ↔ 1 over 9 s. Amber whenever any
    /// marker is out of band. Driven from the timeline rather than a `.repeatForever` animation so
    /// the frozen state is exact rather than wherever the animation happened to be.
    private func glow(t: Double) -> some View {
        let hue = anyOut ? NoopHTMLColor.warm : NoopHTMLColor.green
        let breath = paused
            ? 0.85
            : 0.65 + 0.35 * (1 - cos(2 * Double.pi * t / glowCycle)) / 2
        return RadialGradient(
            stops: [
                .init(color: hue.opacity(0.17), location: 0),
                .init(color: hue.opacity(0), location: 0.65)
            ],
            center: .center,
            startRadius: 0,
            endRadius: 170
        )
        .frame(width: 340, height: 210)
        .blur(radius: 24)
        .opacity(breath)
        .allowsHitTesting(false)
    }

    // MARK: Drawing

    private func draw(context: inout GraphicsContext, size: CGSize, t: Double) {
        let omega = 2 * Double.pi / secondsPerTurn
        // The sway moves the strands and rungs together; the dust stays put, as in the prototype.
        let sway = paused ? 0 : 7 * sin(2 * Double.pi * t / swayCycle)
        let midY = size.height / 2
        let inset: CGFloat = 20
        let usableWidth = size.width - inset * 2
        let originX = inset + CGFloat(sway)

        drawDust(context: &context, size: size, t: t)

        // ── rungs, behind the nodes ──────────────────────────────────────────
        for (index, marker) in markers.enumerated() {
            let f = fraction(for: index)
            let phase = omega * t + f * turns * 2 * .pi
            let x = originX + usableWidth * CGFloat(f)
            let hue = marker.outOfBand ? NoopHTMLColor.warm : NoopHTMLColor.green
            let flash = wave(f: f, t: t)

            // The handoff draws the rung between the two strands, which makes it vanish entirely at
            // the two crossings each turn — the prototype instead floors it at scaleY(.03) with an
            // opacity ramp of .2 → .95, and the acceptance list requires "collapse to a hairline …
            // never disappear entirely". Floored here to match.
            let extent = max(0.03, abs(sin(phase)))
            let dy = amplitude * CGFloat(extent)
            let presence = 0.2 + 0.75 * extent

            let top = CGPoint(x: x, y: midY - dy)
            let bottom = CGPoint(x: x, y: midY + dy)
            var line = Path()
            line.move(to: top)
            line.addLine(to: bottom)

            let edge = marker.outOfBand ? 0.12 : 0.06
            let peak = marker.outOfBand ? 0.95 : 0.50
            context.stroke(
                line,
                with: .linearGradient(
                    Gradient(colors: [
                        hue.opacity(edge * presence),
                        hue.opacity((peak + 0.05 * flash) * presence),
                        hue.opacity(edge * presence)
                    ]),
                    startPoint: top,
                    endPoint: bottom
                ),
                lineWidth: marker.outOfBand ? 2.4 : 1.4
            )

            // The wave flashing past. Blurred, but there are at most seven of these per frame.
            if flash > 0.01 {
                var flashContext = context
                flashContext.addFilter(.blur(radius: marker.outOfBand ? 5 : 3.5))
                flashContext.stroke(
                    line,
                    with: .color(hue.opacity(0.9 * flash * presence)),
                    lineWidth: marker.outOfBand ? 3.2 : 2
                )
            }
        }

        // ── strands: two lagging ghosts, then the node ───────────────────────
        // The trail is what turns dot columns into ribbons; the handoff is emphatic that it stays.
        for column in 0..<columns {
            let f = Double(column) / Double(columns - 1)
            let x = originX + usableWidth * CGFloat(f)
            let base = omega * t + f * turns * 2 * .pi
            let diameter = 2.2 + CGFloat(hash(column)) * 1.4
            let flash = wave(f: f, t: t)

            for strand in 0..<2 {
                let phase = base + Double(strand) * .pi
                for ghost in stride(from: 2, through: 1, by: -1) {
                    node(
                        &context,
                        x: x,
                        midY: midY,
                        phase: phase - Double(ghost) * 0.045 * 2 * .pi,
                        diameter: diameter * (1 - 0.22 * CGFloat(ghost)),
                        color: Self.ghost.opacity(0.30 - 0.09 * Double(ghost)),
                        halo: nil
                    )
                }
                node(
                    &context,
                    x: x,
                    midY: midY,
                    phase: phase,
                    diameter: diameter,
                    color: Self.nodeFill.opacity(0.90 + 0.10 * flash),
                    halo: (NoopHTMLColor.green.opacity(0.70), flash)
                )
            }
        }

        // ── the seven marker nodes, on top ───────────────────────────────────
        for (index, marker) in markers.enumerated() {
            let f = fraction(for: index)
            let x = originX + usableWidth * CGFloat(f)
            let base = omega * t + f * turns * 2 * .pi
            let flash = wave(f: f, t: t)
            let fill = marker.outOfBand ? Self.warmLight : Self.greenLight
            let hue = marker.outOfBand ? NoopHTMLColor.warm : NoopHTMLColor.green
            for strand in 0..<2 {
                node(
                    &context,
                    x: x,
                    midY: midY,
                    phase: base + Double(strand) * .pi,
                    diameter: marker.outOfBand ? 6.6 : 5.4,
                    color: fill,
                    halo: (hue.opacity(0.85), flash)
                )
            }
        }
    }

    /// Rung positions. The handoff's `0.06 + k × 0.147` lands seven rungs across the width; the
    /// even spread is a guard for a marker list that is a fixed seven today but need not stay so.
    private func fraction(for index: Int) -> Double {
        guard markers.count != 7 else { return 0.06 + Double(index) * 0.147 }
        guard markers.count > 1 else { return 0.5 }
        return 0.06 + Double(index) * (0.88 / Double(markers.count - 1))
    }

    /// One node. `sin(phase)` places it; `cos(phase)` is the depth term that makes a flat sine
    /// field read as a rotating helix — 1.20 × at the front, 0.58 × at the back.
    ///
    /// The halo is a radial gradient rather than a blurred layer. A blur filter per node would mean
    /// ~130 offscreen passes per frame at 60 fps for a soft disc that a gradient renders in one.
    private func node(
        _ context: inout GraphicsContext,
        x: CGFloat,
        midY: CGFloat,
        phase: Double,
        diameter: CGFloat,
        color: Color,
        halo: (Color, Double)?
    ) {
        let y = midY + amplitude * CGFloat(sin(phase))
        let depth = cos(phase)
        let scale = 0.89 + 0.31 * CGFloat(depth)
        let alpha = 0.64 + 0.36 * depth
        let radius = diameter * scale / 2

        if let (haloColor, flash) = halo {
            let haloRadius = radius * 3.2
            let rect = CGRect(
                x: x - haloRadius,
                y: y - haloRadius,
                width: haloRadius * 2,
                height: haloRadius * 2
            )
            let strength = haloColor.opacity(alpha * (0.55 + 0.45 * flash))
            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: strength, location: 0),
                        .init(color: strength.opacity(0), location: 1)
                    ]),
                    center: CGPoint(x: x, y: y),
                    startRadius: radius * 0.6,
                    endRadius: haloRadius
                )
            )
        }

        context.fill(
            Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
            with: .color(color.opacity(alpha))
        )
    }

    /// 16 specks drifting ±6 pt on their own 8–17 s cycles, desynchronised by hash.
    private func drawDust(context: inout GraphicsContext, size: CGSize, t: Double) {
        for index in 0..<16 {
            let diameter = 1 + CGFloat(hash(index + 77)) * 2
            let x = CGFloat(hash(index + 12)) * size.width
            let period = 8 + hash(index + 5) * 9
            let u = paused
                ? 0.25
                : ((t / period) + hash(index + 2)).truncatingRemainder(dividingBy: 1)
            let y = (0.06 + CGFloat(hash(index + 64)) * 0.88) * size.height
                + 6 * CGFloat(sin(2 * .pi * u))
            let alpha = 0.12 + 0.48 * (0.5 + 0.5 * sin(2 * .pi * u))
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
                with: .color(Self.nodeFill.opacity(alpha * 0.5))
            )
        }
    }

    /// The bright wave: column `f` peaks at `frac((t + f × 2.9) / 3.6) == 0.84`. Returns 0…1.
    private func wave(f: Double, t: Double) -> Double {
        guard !paused else { return 0 }
        let u = ((t + f * waveLead) / waveCycle).truncatingRemainder(dividingBy: 1)
        let ramp = max(0, 1 - abs(u - 0.84) / 0.12)
        return ramp * ramp
    }

    /// Deterministic per-index jitter — the prototype's generator, so sizes match the mock.
    private func hash(_ n: Int) -> Double {
        let x = sin(Double(n) * 127.1 + 311.7) * 43_758.5453
        return x - x.rounded(.down)
    }

    // Green and amber come from the shared tokens; these are the tints that exist only here.
    private static let greenLight = Color(hex: 0xE8FFF4)
    private static let ghost = Color(hex: 0x8CEFC0)
    private static let nodeFill = Color(hex: 0xCEFFE7)
    private static let warmLight = Color(hex: 0xF6DCB4)
}
#endif
