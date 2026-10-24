import SwiftUI

// MARK: - Today's rings
//
// Recovery, strain and sleep as three rings, outermost to innermost. Two drawings of the same three
// numbers, offered as separate sections while one is chosen:
//   • Living — each ring is a band of specks streaming toward its head, in the same language as the
//     Trends orb: how far the band reaches is the score, and the band breathes slowly.
//   • Segmented — each ring carries what it is made of: sleep is cut into the night's own stages,
//     strain heats from cool to hot along its length, recovery is a clean gauge over fine ticks.

struct NoopRingValues: Equatable {
    /// 0–100.
    var recovery: Double?
    /// 0–21.
    var strain: Double?
    /// Asleep against need, 0–1 (capped; over the need reads full).
    var sleep: Double?
    var sleepMinutes: Double?
    /// The night's stage runs, for the segmented sleep ring.
    var sleepRuns: [NoopRestRecord.StageRun]?

    var recoveryFill: Double { min(1, max(0, (recovery ?? 0) / 100)) }
    var strainFill: Double { min(1, max(0, (strain ?? 0) / 21)) }
    var sleepFill: Double { min(1, max(0, sleep ?? 0)) }

    static let recoveryColor = Color(hex: 0x3DE6A5)
    static let strainCool = NoopHTMLColor.blue
    static let strainHot = Color(hex: 0xFF8A3D)
    static let sleepColor = Color(hex: 0x9AA5FF)
}

enum NoopRingStyle { case living, segmented }

struct NoopTodayRings: View {
    let values: NoopRingValues
    let style: NoopRingStyle
    var action: () -> Void = {}

    @State private var onScreen = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(spacing: 18) {
                ZStack {
                    switch style {
                    case .living:
                        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !onScreen || reduceMotion)) { timeline in
                            Canvas { context, size in
                                NoopLivingRings.draw(in: &context, size: size, values: values,
                                                     t: reduceMotion ? 2 : timeline.date.timeIntervalSinceReferenceDate
                                                        .truncatingRemainder(dividingBy: 3600))
                            }
                        }
                    case .segmented:
                        Canvas { context, size in NoopSegmentedRings.draw(in: &context, size: size, values: values) }
                    }
                    centre
                }
                .frame(width: 252, height: 252)
                legend
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoopHTMLPressStyle())
        .onScrollVisibilityChangeIfAvailable { onScreen = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var centre: some View {
        VStack(spacing: 0) {
            Text(values.recovery.map { "\(Int($0.rounded()))" } ?? "—")
                .font(NoopHTMLFont.outfit(NoopType.title1))
                .monospacedDigit()
                .foregroundStyle(NoopHTMLColor.ink)
            Text("RECOVERY")
                .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(NoopHTMLColor.muted)
        }
    }

    private var legend: some View {
        HStack(alignment: .top, spacing: 0) {
            row("Recovery", values.recovery.map { "\(Int($0.rounded()))%" }, NoopRingValues.recoveryColor)
            row("Strain", values.strain.map { String(format: "%.1f", $0) }, NoopRingValues.strainHot)
            row("Sleep", values.sleepMinutes.map { NoopRestRecord.duration($0) }, NoopRingValues.sleepColor)
        }
    }

    private func row(_ title: String, _ value: String?, _ color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(title.uppercased())
                    .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(NoopHTMLColor.muted)
            }
            Text(value ?? "—")
                .font(NoopHTMLFont.outfit(NoopType.title3))
                .monospacedDigit()
                .foregroundStyle(NoopHTMLColor.ink)
        }
        .frame(maxWidth: .infinity)
    }

    private var accessibilityText: String {
        var parts: [String] = []
        parts.append(values.recovery.map { "Recovery \(Int($0.rounded())) percent" } ?? "Recovery not measured")
        parts.append(values.strain.map { "strain \(String(format: "%.1f", $0))" } ?? "no strain yet")
        parts.append(values.sleepMinutes.map { "sleep \(NoopRestRecord.duration($0))" } ?? "no sleep recorded")
        return parts.joined(separator: ", ")
    }
}

/// The three ring radii, outermost first, and the band each is drawn in.
private enum NoopRingGeometry {
    static func radii(_ size: CGSize) -> [CGFloat] {
        let r = min(size.width, size.height) / 2
        return [r - 10, r - 34, r - 58]
    }
    static let band: CGFloat = 16
}

// MARK: Living

private enum NoopLivingRings {
    static func draw(in context: inout GraphicsContext, size: CGSize, values: NoopRingValues, t: Double) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let radii = NoopRingGeometry.radii(size)
        let rings: [(fill: Double, colors: (Color, Color), speed: Double)] = [
            (values.recoveryFill, (NoopRingValues.recoveryColor, Color(hex: 0x8FFFD0)), 0.10),
            (values.strainFill, (NoopRingValues.strainCool, NoopRingValues.strainHot), 0.16),
            (values.sleepFill, (Color(hex: 0x6F7BFF), NoopRingValues.sleepColor), 0.07)
        ]
        context.blendMode = .plusLighter
        for (k, ring) in rings.enumerated() {
            let r = Double(radii[k])
            // The track: fine dots all the way round.
            let dots = Int(r * 2 * .pi / 6)
            for i in 0..<dots {
                let a = Double(i) / Double(dots) * 2 * .pi - .pi / 2
                let p = CGPoint(x: c.x + CGFloat(cos(a) * r), y: c.y + CGFloat(sin(a) * r))
                context.fill(Path(ellipseIn: CGRect(x: p.x - 1, y: p.y - 1, width: 2, height: 2)),
                             with: .color(.white.opacity(0.07)))
            }
            guard ring.fill > 0.005 else { continue }
            let sweep = ring.fill * 2 * .pi
            let breathe = 1 + 0.06 * sin(t * 0.9 + Double(k) * 1.7)
            // The band: specks flowing toward the head, denser and brighter as they near it.
            let count = Int(60 + 220 * ring.fill)
            for i in 0..<count {
                let h = { (n: Int) in NoopAuraMath.hash(k * 7919 + i * 31 + n) }
                let along = (h(1) + t * ring.speed * (0.6 + 0.8 * h(2))).truncatingRemainder(dividingBy: 1)
                let f = pow(along, 0.8)
                let a = -.pi / 2 + f * sweep
                let spread = Double(NoopRingGeometry.band) / 2 * breathe
                let off = (h(3) - 0.5) * 2 * spread * (0.35 + 0.65 * (1 - f * 0.4))
                let rr = r + off
                let p = CGPoint(x: c.x + CGFloat(cos(a) * rr), y: c.y + CGFloat(sin(a) * rr))
                let s = 1.1 + 2.2 * h(4) * (0.5 + f)
                let alpha = (0.25 + 0.7 * f) * (1 - abs(off) / (spread + 1) * 0.6)
                let color = mix(ring.colors.0, ring.colors.1, f)
                context.fill(Path(ellipseIn: CGRect(x: p.x - s / 2, y: p.y - s / 2, width: s, height: s)),
                             with: .color(color.opacity(alpha)))
            }
            // The head: a soft glint where the score ends.
            let ha = -.pi / 2 + sweep
            let hp = CGPoint(x: c.x + CGFloat(cos(ha) * r), y: c.y + CGFloat(sin(ha) * r))
            let g = 10 * breathe
            context.fill(Path(ellipseIn: CGRect(x: hp.x - g, y: hp.y - g, width: 2 * g, height: 2 * g)),
                         with: .radialGradient(Gradient(colors: [ring.colors.1.opacity(0.9), ring.colors.1.opacity(0)]),
                                               center: hp, startRadius: 0, endRadius: g))
            context.fill(Path(ellipseIn: CGRect(x: hp.x - 2.5, y: hp.y - 2.5, width: 5, height: 5)), with: .color(.white))
        }
    }

    private static func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let ra = UIColor(a).cgColor.components ?? [0, 0, 0, 1], rb = UIColor(b).cgColor.components ?? [0, 0, 0, 1]
        func ch(_ i: Int) -> Double { Double(ra[min(i, ra.count - 1)] + (rb[min(i, rb.count - 1)] - ra[min(i, ra.count - 1)]) * t) }
        return Color(red: ch(0), green: ch(1), blue: ch(2))
    }
}

// MARK: Segmented

private enum NoopSegmentedRings {
    static func draw(in context: inout GraphicsContext, size: CGSize, values: NoopRingValues) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let radii = NoopRingGeometry.radii(size)
        let w = NoopRingGeometry.band
        func arc(_ r: CGFloat, _ from: Double, _ to: Double) -> Path {
            var p = Path()
            p.addArc(center: c, radius: r, startAngle: .radians(-.pi / 2 + from * 2 * .pi),
                     endAngle: .radians(-.pi / 2 + to * 2 * .pi), clockwise: false)
            return p
        }
        // Tracks.
        for r in radii {
            context.stroke(arc(r, 0, 1), with: .color(.white.opacity(0.06)), style: StrokeStyle(lineWidth: w))
        }

        // Recovery: fine ticks under a clean gauge.
        let r0 = radii[0]
        for i in 0..<60 {
            let a = -.pi / 2 + Double(i) / 60 * 2 * .pi
            var tick = Path()
            tick.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * (r0 - 3), y: c.y + CGFloat(sin(a)) * (r0 - 3)))
            tick.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * (r0 + 3), y: c.y + CGFloat(sin(a)) * (r0 + 3)))
            context.stroke(tick, with: .color(.white.opacity(i % 5 == 0 ? 0.22 : 0.1)), lineWidth: 1)
        }
        if values.recoveryFill > 0 {
            context.stroke(arc(r0, 0, values.recoveryFill), with: .color(NoopRingValues.recoveryColor),
                           style: StrokeStyle(lineWidth: w - 4, lineCap: .round))
        }

        // Strain: heats along its length.
        if values.strainFill > 0 {
            let gradient = Gradient(stops: [
                .init(color: NoopRingValues.strainCool, location: 0),
                .init(color: Color(hex: 0xB58CFF), location: 0.5),
                .init(color: NoopRingValues.strainHot, location: 1)
            ])
            context.stroke(arc(radii[1], 0, values.strainFill),
                           with: .conicGradient(gradient, center: c, angle: .radians(-.pi / 2)),
                           style: StrokeStyle(lineWidth: w, lineCap: .round))
        }

        // Sleep: the night's own stages, laid along the part of the ring it filled.
        let r2 = radii[2], fill = values.sleepFill
        if fill > 0 {
            if let runs = values.sleepRuns, !runs.isEmpty {
                let colors = NoopTodayNightCard.stageColors
                for run in runs {
                    let from = run.from * fill, to = run.to * fill
                    guard to - from > 0.001 else { continue }
                    context.stroke(arc(r2, from + 0.002, to - 0.002),
                                   with: .color(run.stage == 0 ? Color.white.opacity(0.35) : colors[run.stage]),
                                   style: StrokeStyle(lineWidth: w, lineCap: .butt))
                }
            } else {
                context.stroke(arc(r2, 0, fill), with: .color(NoopRingValues.sleepColor),
                               style: StrokeStyle(lineWidth: w, lineCap: .round))
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func onScrollVisibilityChangeIfAvailable(_ action: @escaping (Bool) -> Void) -> some View {
        if #available(iOS 18.0, *) {
            onScrollVisibilityChange(threshold: 0.02, action)
        } else {
            self
        }
    }
}
