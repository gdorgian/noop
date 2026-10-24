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

enum NoopRingStyle { case living, segmented, donuts, dials, gyro }

struct NoopTodayRings: View {
    let values: NoopRingValues
    let style: NoopRingStyle
    var action: () -> Void = {}

    @State private var onScreen = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        switch style {
        case .donuts: NoopDonutRings(values: values, action: action)
        case .dials: NoopDialRings(values: values, action: action)
        case .gyro: NoopGyroRings(values: values, action: action)
        case .living, .segmented: concentric
        }
    }

    private var concentric: some View {
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
                    default:
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

// MARK: - Donuts
//
// Three rings side by side in one card, each a thick arc in a recessed track whose rounded tip glows,
// the number in a slightly raised middle. Strain also shows today's target as a hatched band with a
// bright tick at each end: lighter after a low recovery, harder after a high one.

private struct NoopDonutRings: View {
    let values: NoopRingValues
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                column("Strain", fill: values.strainFill, value: values.strain.map { _ in values.strainFill * 100 },
                       colors: [Color(hex: 0xFFE3A3), Color(hex: 0xF5B451)], target: strainTarget)
                divider
                column("Recovery", fill: values.recoveryFill, value: values.recovery,
                       colors: [Color(hex: 0xE6F27A), Color(hex: 0x9BD93A)], target: nil)
                divider
                column("Sleep", fill: values.sleepFill, value: values.sleep.map { min(1, $0) * 100 },
                       colors: [Color(hex: 0xB7C8FF), Color(hex: 0x5B52E0)], target: nil)
            }
            .padding(.vertical, 18)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    /// Today's strain target, as fractions of the ring: easier after a low recovery.
    private var strainTarget: ClosedRange<Double>? {
        guard let r = values.recovery else { return nil }
        let mid = 0.25 + 0.45 * min(1, max(0, r / 100))
        return (mid - 0.09)...(mid + 0.09)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.07)).frame(width: 0.5).padding(.vertical, 4)
    }

    private func column(_ title: String, fill: Double, value: Double?, colors: [Color], target: ClosedRange<Double>?) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Canvas { context, size in
                    NoopDonut.draw(in: &context, size: size, fill: fill, colors: colors, target: target)
                }
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(value.map { "\(Int($0.rounded()))" } ?? "--")
                        .font(NoopHTMLFont.sans(NoopType.title2, weight: .semibold))
                        .monospacedDigit()
                    Text("%").font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                }
                .foregroundStyle(value == nil ? NoopHTMLColor.faint : NoopHTMLColor.ink)
            }
            .frame(width: 98, height: 98)
            Text(title).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
        }
        .frame(maxWidth: .infinity)
    }
}

private enum NoopDonut {
    static func draw(in context: inout GraphicsContext, size: CGSize, fill: Double, colors: [Color], target: ClosedRange<Double>?) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let outer = min(size.width, size.height) / 2
        let width: CGFloat = 12, r = outer - 9
        func arc(_ from: Double, _ to: Double, radius: CGFloat = r) -> Path {
            var p = Path()
            p.addArc(center: c, radius: radius, startAngle: .radians(-.pi / 2 + from * 2 * .pi),
                     endAngle: .radians(-.pi / 2 + to * 2 * .pi), clockwise: false)
            return p
        }
        // A rim, the recessed track, and a slightly raised middle.
        context.fill(Path(ellipseIn: CGRect(x: c.x - outer, y: c.y - outer, width: 2 * outer, height: 2 * outer)),
                     with: .color(.white.opacity(0.05)))
        context.stroke(arc(0, 1), with: .color(.black.opacity(0.28)), lineWidth: width)
        var shade = context
        shade.addFilter(.blur(radius: 2))
        shade.stroke(arc(0, 1, radius: r - width / 2 + 1), with: .color(.black.opacity(0.35)), lineWidth: 2)
        let inner = r - width / 2 - 1
        context.fill(Path(ellipseIn: CGRect(x: c.x - inner, y: c.y - inner, width: 2 * inner, height: 2 * inner)),
                     with: .color(.white.opacity(0.06)))
        // The target band: hatched, with a bright tick at each end.
        if let target {
            var band = context
            band.clip(to: arc(target.lowerBound, target.upperBound).strokedPath(StrokeStyle(lineWidth: width)))
            band.fill(arc(target.lowerBound, target.upperBound).strokedPath(StrokeStyle(lineWidth: width)),
                      with: .color(colors[1].opacity(0.35)))
            var lines = Path()
            var x = c.x - outer
            while x < c.x + outer {
                lines.move(to: CGPoint(x: x, y: c.y + outer)); lines.addLine(to: CGPoint(x: x + 2 * outer, y: c.y - outer))
                x += 4
            }
            band.stroke(lines, with: .color(.black.opacity(0.35)), lineWidth: 1.4)
            for end in [target.lowerBound, target.upperBound] {
                let a = -.pi / 2 + end * 2 * .pi
                var tick = Path()
                tick.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * (r - width / 2 - 1), y: c.y + CGFloat(sin(a)) * (r - width / 2 - 1)))
                tick.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * (r + width / 2 + 1), y: c.y + CGFloat(sin(a)) * (r + width / 2 + 1)))
                context.stroke(tick, with: .color(.white), lineWidth: 2)
            }
        }
        guard fill > 0.004 else { return }
        // The arc, shaded along its length, with a glowing tip.
        let gradient = Gradient(colors: [colors[0], colors[1]])
        let shading = GraphicsContext.Shading.conicGradient(gradient, center: c, angle: .radians(-.pi / 2))
        context.stroke(arc(0, fill), with: shading, style: StrokeStyle(lineWidth: width, lineCap: .round))
        let a = -.pi / 2 + fill * 2 * .pi
        let tip = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
        var glow = context
        glow.addFilter(.blur(radius: 5))
        glow.fill(Path(ellipseIn: CGRect(x: tip.x - width / 2, y: tip.y - width / 2, width: width, height: width)),
                  with: .color(colors[1].opacity(0.9)))
        context.fill(Path(ellipseIn: CGRect(x: tip.x - width / 2, y: tip.y - width / 2, width: width, height: width)),
                     with: .color(colors[1]))
    }
}

// MARK: - Dials
//
// Three plain dials in a row: a thin track, a thin arc from the top, the number in heavy type in the
// middle, and a tracked capital label with a chevron. Recovery takes the colour of its band.

private struct NoopDialRings: View {
    let values: NoopRingValues
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                dial("Sleep", fill: values.sleepFill, text: values.sleep.map { "\(Int((min(1, $0) * 100).rounded()))" },
                     percent: true, color: Color(hex: 0x7FA6C4))
                dial("Recovery", fill: values.recoveryFill, text: values.recovery.map { "\(Int($0.rounded()))" },
                     percent: true, color: recoveryColor)
                dial("Strain", fill: values.strainFill, text: values.strain.map { String(format: "%.1f", $0) },
                     percent: false, color: Color(hex: 0x1E9BF0))
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private var recoveryColor: Color {
        guard let r = values.recovery else { return .white }
        return r >= 67 ? Color(hex: 0x2BE36A) : r >= 34 ? Color(hex: 0xF7D23E) : Color(hex: 0xF2445B)
    }

    private func dial(_ title: String, fill: Double, text: String?, percent: Bool, color: Color) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 7)
                Circle().trim(from: 0, to: fill)
                    .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(text ?? "--").font(NoopHTMLFont.sans(NoopType.title2, weight: .heavy)).monospacedDigit()
                    if percent { Text("%").font(NoopHTMLFont.sans(NoopType.subhead, weight: .heavy)) }
                }
                .foregroundStyle(text == nil ? NoopHTMLColor.faint : NoopHTMLColor.ink)
            }
            .frame(width: 92, height: 92)
            HStack(spacing: 5) {
                Text(title.uppercased())
                    .font(NoopHTMLFont.sans(NoopType.footnote, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(NoopHTMLColor.ink)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .heavy)).foregroundStyle(NoopHTMLColor.muted)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Gyro
//
// Aura's own: the three rings as tilted orbits around a glowing core, slowly turning like a
// gyroscope. Each orbit's lit length is its score, ending in a bright bead; the half of an orbit
// that passes behind the core is dimmer and thinner, the half in front brighter and fuller, so the
// three read as one object in space rather than three flat circles.

private struct NoopGyroRings: View {
    let values: NoopRingValues
    let action: () -> Void

    @State private var onScreen = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                ZStack {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !onScreen || reduceMotion)) { timeline in
                        Canvas { context, size in
                            NoopGyro.draw(in: &context, size: size, values: values,
                                          t: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600))
                        }
                    }
                    VStack(spacing: 0) {
                        Text(values.recovery.map { "\(Int($0.rounded()))" } ?? "—")
                            .font(NoopHTMLFont.outfit(NoopType.title1)).monospacedDigit()
                            .foregroundStyle(NoopHTMLColor.ink)
                        Text("RECOVERY").font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).tracking(1.2)
                            .foregroundStyle(NoopHTMLColor.muted)
                    }
                }
                .frame(height: 260)
                HStack(spacing: 0) {
                    legend("Recovery", values.recovery.map { "\(Int($0.rounded()))%" }, NoopGyro.colors[0])
                    legend("Strain", values.strain.map { String(format: "%.1f", $0) }, NoopGyro.colors[1])
                    legend("Sleep", values.sleepMinutes.map { NoopRestRecord.duration($0) }, NoopGyro.colors[2])
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoopHTMLPressStyle())
        .modifier(NoopGyroVisibility(onScreen: $onScreen))
    }

    private func legend(_ title: String, _ value: String?, _ color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 6) {
                Capsule().fill(color).frame(width: 12, height: 3)
                Text(title.uppercased()).font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).tracking(1.1)
                    .foregroundStyle(NoopHTMLColor.muted)
            }
            Text(value ?? "—").font(NoopHTMLFont.outfit(NoopType.title3)).monospacedDigit().foregroundStyle(NoopHTMLColor.ink)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct NoopGyroVisibility: ViewModifier {
    @Binding var onScreen: Bool
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) { content.onScrollVisibilityChange(threshold: 0.02) { onScreen = $0 } } else { content }
    }
}

private enum NoopGyro {
    static let colors = [Color(hex: 0x3DE6A5), Color(hex: 0xFF9F5A), Color(hex: 0x8F9BFF)]

    static func draw(in context: inout GraphicsContext, size: CGSize, values: NoopRingValues, t: Double) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let base = min(size.width, size.height) / 2 - 8
        // Radius, tilt from face-on, the turn of its axis, and how fast that axis drifts.
        let orbits: [(r: Double, tilt: Double, phase: Double, drift: Double, fill: Double)] = [
            (Double(base), 1.12, 0.0, 0.05, values.recoveryFill),
            (Double(base) * 0.86, 1.18, 2.1, -0.07, values.strainFill),
            (Double(base) * 0.72, 1.05, 4.2, 0.09, values.sleepFill)
        ]
        typealias Seg = (a: CGPoint, b: CGPoint, depth: Double, lit: Double, k: Int)
        var segs: [Seg] = []
        var beads: [(p: CGPoint, depth: Double, k: Int)] = []
        let steps = 160
        for (k, o) in orbits.enumerated() {
            let spin = o.phase + t * o.drift
            func point(_ th: Double) -> (CGPoint, Double) {
                let x = o.r * cos(th), y = o.r * sin(th) * cos(o.tilt), z = o.r * sin(th) * sin(o.tilt)
                let px = x * cos(spin) - y * sin(spin), py = x * sin(spin) + y * cos(spin)
                return (CGPoint(x: c.x + CGFloat(px), y: c.y + CGFloat(py)), z / o.r)
            }
            let start = -Double.pi / 2
            for i in 0..<steps {
                let u0 = Double(i) / Double(steps), u1 = Double(i + 1) / Double(steps)
                let (a, d0) = point(start + u0 * 2 * .pi), (b, d1) = point(start + u1 * 2 * .pi)
                let lit = u1 <= o.fill ? 0.35 + 0.65 * (u1 / max(o.fill, 0.001)) : 0
                segs.append((a, b, (d0 + d1) / 2, lit, k))
            }
            if o.fill > 0.004 {
                let (p, d) = point(start + o.fill * 2 * .pi)
                beads.append((p, d, k))
            }
        }
        func drawSeg(_ s: Seg) {
            var path = Path(); path.move(to: s.a); path.addLine(to: s.b)
            let front = (s.depth + 1) / 2
            if s.lit > 0 {
                let w = 3 + 5 * front
                context.stroke(path, with: .color(colors[s.k].opacity((0.35 + 0.65 * front) * s.lit)),
                               style: StrokeStyle(lineWidth: w, lineCap: .round))
            } else {
                context.stroke(path, with: .color(.white.opacity(0.04 + 0.08 * front)), lineWidth: 1 + front)
            }
        }
        func drawBead(_ b: (p: CGPoint, depth: Double, k: Int)) {
            let front = (b.depth + 1) / 2, g = 9 + 7 * front
            context.fill(Path(ellipseIn: CGRect(x: b.p.x - g, y: b.p.y - g, width: 2 * g, height: 2 * g)),
                         with: .radialGradient(Gradient(colors: [colors[b.k].opacity(0.9), colors[b.k].opacity(0)]),
                                               center: b.p, startRadius: 0, endRadius: g))
            let s = 3 + 2.5 * front
            context.fill(Path(ellipseIn: CGRect(x: b.p.x - s, y: b.p.y - s, width: 2 * s, height: 2 * s)), with: .color(.white))
        }
        context.blendMode = .plusLighter
        // Behind the core, then the core, then in front of it.
        for s in segs where s.depth < 0 { drawSeg(s) }
        for b in beads where b.depth < 0 { drawBead(b) }
        let core = base * 0.42
        context.fill(Path(ellipseIn: CGRect(x: c.x - core, y: c.y - core, width: 2 * core, height: 2 * core)),
                     with: .radialGradient(Gradient(colors: [colors[0].opacity(0.22), colors[2].opacity(0.08), .clear]),
                                           center: c, startRadius: 0, endRadius: core))
        context.blendMode = .normal
        context.fill(Path(ellipseIn: CGRect(x: c.x - core * 0.62, y: c.y - core * 0.62, width: core * 1.24, height: core * 1.24)),
                     with: .color(NoopHTMLColor.canvas.opacity(0.75)))
        context.blendMode = .plusLighter
        for s in segs where s.depth >= 0 { drawSeg(s) }
        for b in beads where b.depth >= 0 { drawBead(b) }
    }
}
