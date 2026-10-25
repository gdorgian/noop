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
    /// 0–100 (the app's strain scale, StrainScorer).
    var strain: Double?
    /// Asleep against need, 0–1 (capped; over the need reads full).
    var sleep: Double?
    var sleepMinutes: Double?
    /// The night's stage runs, for the segmented sleep ring.
    var sleepRuns: [NoopRestRecord.StageRun]?

    var recoveryFill: Double { min(1, max(0, (recovery ?? 0) / 100)) }
    var strainFill: Double { min(1, max(0, (strain ?? 0) / 100)) }
    var sleepFill: Double { min(1, max(0, sleep ?? 0)) }

    /// The same readings with every ring drawn `k` of the way: how the draw-in grows them.
    func scaled(_ k: Double) -> NoopRingValues {
        var v = self
        v.recovery = recovery.map { $0 * k }
        v.strain = strain.map { $0 * k }
        v.sleep = sleep.map { $0 * k }
        return v
    }

    /// A draw-in with a slight overshoot, from an eased 0…1.
    static func spring(_ x: Double) -> Double { x + 0.1 * sin(.pi * x) * x }

    static let recoveryColor = Color(hex: 0x3DE6A5)
    static let strainCool = NoopHTMLColor.blue
    static let strainHot = Color(hex: 0xFF8A3D)
    static let sleepColor = Color(hex: 0x9AA5FF)
}

enum NoopRingStyle { case living, segmented, donuts, dials, gyro }

/// Strain as the wearer chose to read it: the stored 0–100 value on the app's 0–100 or WHOOP's 0–21
/// scale (You › Units), one decimal.
func noopStrainText(_ v: Double) -> String { UnitFormatter.effortDisplay(v, scale: noopEffortScale) }

var noopEffortScale: EffortScale {
    EffortScale(rawValue: UserDefaults.standard.string(forKey: UnitPrefs.effortScaleKey) ?? "") ?? .hundred
}

/// Which score a ring or its label opens.
enum NoopRingMetric { case recovery, strain, sleep }

struct NoopTodayRings: View {
    let values: NoopRingValues
    let style: NoopRingStyle
    /// Opens a score's own page; a tap on the drawing itself opens recovery.
    var open: (NoopRingMetric) -> Void = { _ in }
    private var action: () -> Void { { open(.recovery) } }

    @State private var onScreen = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        switch style {
        case .donuts: NoopDonutRings(values: values, open: open)
        case .dials: NoopDialRings(values: values, open: open)
        case .gyro: NoopGyroRings(values: values, open: open)
        case .living, .segmented: concentric
        }
    }

    private var concentric: some View {
        Button(action: action) {
            VStack(spacing: 18) {
                ZStack {
                    switch style {
                    case .living:
                        NoopSlotClock { t, reveal in
                            let v = values.scaled(NoopRingValues.spring(reveal))
                            Rectangle().colorEffect(ShaderLibrary.noopFlowRings(
                                .float2(CGSize(width: 252, height: 252)), .float(Float(t)),
                                .float(Float(v.recoveryFill)), .float(Float(v.strainFill)), .float(Float(v.sleepFill)),
                                .color(Color(hex: 0x1FC98A)), .color(Color(hex: 0x8FFFD0)),
                                .color(Color(hex: 0xFFC46B)), .color(NoopRingValues.strainHot),
                                .color(Color(hex: 0x6F7BFF)), .color(NoopRingValues.sleepColor)))
                        }
                    default:
                        NoopSlotClock { _, reveal in
                            Canvas { context, size in
                                NoopSegmentedRings.draw(in: &context, size: size, values: values.scaled(NoopRingValues.spring(reveal)))
                            }
                        }
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
            if let r = values.recovery {
                NoopCountUp(value: r, font: NoopHTMLFont.outfit(NoopType.title1)).foregroundStyle(NoopHTMLColor.ink)
            } else {
                Text("—").font(NoopHTMLFont.outfit(NoopType.title1)).foregroundStyle(NoopHTMLColor.faint)
            }
            Text("RECOVERY")
                .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(NoopHTMLColor.muted)
        }
    }

    private var legend: some View {
        HStack(alignment: .top, spacing: 0) {
            Button { open(.recovery) } label: { row("Recovery", values.recovery.map { "\(Int($0.rounded()))%" }, NoopRingValues.recoveryColor) }
                .buttonStyle(NoopHTMLPressStyle())
            Button { open(.strain) } label: { row("Strain", values.strain.map { noopStrainText($0) }, NoopRingValues.strainHot) }
                .buttonStyle(NoopHTMLPressStyle())
            Button { open(.sleep) } label: { row("Sleep", values.sleepMinutes.map { NoopRestRecord.duration($0) }, NoopRingValues.sleepColor) }
                .buttonStyle(NoopHTMLPressStyle())
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
        parts.append(values.strain.map { "strain \(noopStrainText($0))" } ?? "no strain yet")
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
    let open: (NoopRingMetric) -> Void

    var body: some View {
        do {
            HStack(spacing: 0) {
                column(.strain, "Strain", fill: values.strainFill, value: values.strain.map { _ in values.strainFill * 100 },
                       colors: [Color(hex: 0xFFE3A3), Color(hex: 0xF5B451)], target: strainTarget)
                divider
                column(.recovery, "Recovery", fill: values.recoveryFill, value: values.recovery,
                       colors: [Color(hex: 0xE6F27A), Color(hex: 0x9BD93A)], target: nil)
                divider
                column(.sleep, "Sleep", fill: values.sleepFill, value: values.sleep.map { min(1, $0) * 100 },
                       colors: [Color(hex: 0xB7C8FF), Color(hex: 0x5B52E0)], target: nil)
            }
            .padding(.top, 8).padding(.bottom, 12)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
        }
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

    private func column(_ metric: NoopRingMetric, _ title: String, fill: Double, value: Double?, colors: [Color], target: ClosedRange<Double>?) -> some View {
        Button { open(metric) } label: { columnBody(title, fill: fill, value: value, colors: colors, target: target) }
            .buttonStyle(NoopHTMLPressStyle())
    }

    private func columnBody(_ title: String, fill: Double, value: Double?, colors: [Color], target: ClosedRange<Double>?) -> some View {
        // Bevel's proportions, measured: a 112 pt ring, the figure in a medium weight a shade under
        // white, the name in a softer grey under it.
        VStack(spacing: 10) {
            ZStack {
                // The well, track and target are drawn once; the arc and its tip are shapes animated by
                // SwiftUI, so the draw-in never depends on a timeline being on screen.
                Canvas { context, size in
                    NoopDonut.draw(in: &context, size: size, fill: 0, colors: colors, target: target)
                }
                NoopDonutArc(fill: fill, colors: colors)
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    if let value {
                        NoopCountUp(value: value, font: NoopHTMLFont.sans(27, weight: .medium))
                    } else {
                        Text("--").font(NoopHTMLFont.sans(27, weight: .medium))
                    }
                    Text("%").font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium))
                }
                .foregroundStyle(value == nil ? NoopHTMLColor.faint : NoopHTMLColor.ink.opacity(0.9))
            }
            .frame(width: 112, height: 112)
            Text(title).font(NoopHTMLFont.sans(NoopType.subhead, weight: .medium)).foregroundStyle(NoopHTMLColor.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }
}

private enum NoopDonut {
    static func draw(in context: inout GraphicsContext, size: CGSize, fill: Double, colors: [Color], target: ClosedRange<Double>?) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let outer = min(size.width, size.height) / 2
        let width: CGFloat = 15, r = outer - 9.5
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
        context.stroke(arc(0, fill), with: noopArcShading(colors[0], colors[1], center: c, fill: fill, radius: r, lineWidth: width),
                       style: StrokeStyle(lineWidth: width, lineCap: .round))
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
    let open: (NoopRingMetric) -> Void

    var body: some View {
        do {
            HStack(spacing: 0) {
                dial(.sleep, "Sleep", fill: values.sleepFill, text: values.sleep.map { "\(Int((min(1, $0) * 100).rounded()))" },
                     percent: true, color: Color(hex: 0x7FA6C4))
                dial(.recovery, "Recovery", fill: values.recoveryFill, text: values.recovery.map { "\(Int($0.rounded()))" },
                     percent: true, color: recoveryColor)
                dial(.strain, "Strain", fill: values.strainFill, text: values.strain.map { noopStrainText($0) },
                     percent: false, color: Color(hex: 0x0093E7))
            }
            .padding(.vertical, 10)
        }
    }

    private var recoveryColor: Color {
        guard let r = values.recovery else { return .white }
        return r >= 67 ? Color(hex: 0x16EC06) : r >= 34 ? Color(hex: 0xFFDE00) : Color(hex: 0xFF0026)
    }

    private func dial(_ metric: NoopRingMetric, _ title: String, fill: Double, text: String?, percent: Bool, color: Color) -> some View {
        Button { open(metric) } label: { dialBody(title, fill: fill, text: text, percent: percent, color: color) }
            .buttonStyle(NoopHTMLPressStyle())
    }

    private func dialBody(_ title: String, fill: Double, text: String?, percent: Bool, color: Color) -> some View {
        // WHOOP's Home, measured on a 440 pt screen: an 88 pt ring with a 6 pt rounded arc on a grey
        // track, a 28 pt heavy figure, and an 11 pt tracked label just under the ring.
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(Color(hex: 0x3A4148), lineWidth: 6)
                NoopSlotClock { _, reveal in
                    Circle().trim(from: 0, to: min(1, fill * NoopRingValues.spring(reveal)))
                        .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(text ?? "--").font(NoopHTMLFont.sans(28, weight: .heavy)).monospacedDigit()
                    if percent { Text("%").font(NoopHTMLFont.sans(17, weight: .heavy)) }
                }
                .foregroundStyle(text == nil ? NoopHTMLColor.faint : NoopHTMLColor.ink)
            }
            .padding(3)
            .frame(width: 88, height: 88)
            HStack(spacing: 4) {
                Text(title.uppercased())
                    .font(NoopHTMLFont.sans(11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(NoopHTMLColor.ink)
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .heavy)).foregroundStyle(NoopHTMLColor.muted)
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
    let open: (NoopRingMetric) -> Void
    private var action: () -> Void { { open(.recovery) } }

    @State private var onScreen = true
    @State private var appeared: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 0…1 over the first 1.6 s on screen, eased out.
    private func gyroReveal(_ now: Date) -> Double {
        if reduceMotion || !onScreen { return 1 }
        let x = min(1, max(0, (appeared.map { now.timeIntervalSince($0) } ?? 0) / 1.6))
        return 1 - pow(1 - x, 3)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                ZStack {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !onScreen || reduceMotion)) { timeline in
                        Canvas { context, size in
                            NoopGyro.draw(in: &context, size: size, values: values.scaled(NoopRingValues.spring(gyroReveal(timeline.date))),
                                          t: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600))
                        }
                    }
                    VStack(spacing: 0) {
                        if let r = values.recovery {
                            NoopCountUp(value: r, font: NoopHTMLFont.outfit(NoopType.title1)).foregroundStyle(NoopHTMLColor.ink)
                        } else {
                            Text("—").font(NoopHTMLFont.outfit(NoopType.title1)).foregroundStyle(NoopHTMLColor.faint)
                        }
                        Text("RECOVERY").font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).tracking(1.2)
                            .foregroundStyle(NoopHTMLColor.muted)
                    }
                }
                .frame(height: 260)
                HStack(spacing: 0) {
                    Button { open(.recovery) } label: { legend("Recovery", values.recovery.map { "\(Int($0.rounded()))%" }, NoopGyro.colors[0]) }
                        .buttonStyle(NoopHTMLPressStyle())
                    Button { open(.strain) } label: { legend("Strain", values.strain.map { noopStrainText($0) }, NoopGyro.colors[1]) }
                        .buttonStyle(NoopHTMLPressStyle())
                    Button { open(.sleep) } label: { legend("Sleep", values.sleepMinutes.map { NoopRestRecord.duration($0) }, NoopGyro.colors[2]) }
                        .buttonStyle(NoopHTMLPressStyle())
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoopHTMLPressStyle())
        .modifier(NoopGyroVisibility(onScreen: $onScreen))
        .onAppear { if appeared == nil { appeared = Date() } }
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

/// The donut's arc: shaded from start to end, a glowing rounded tip, springing out from the top when
/// it first appears.
private struct NoopDonutArc: View {
    let fill: Double
    let colors: [Color]

    @State private var drawn: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { g in
            let side = min(g.size.width, g.size.height)
            let r = side / 2 - 9.5, width: CGFloat = 11
            let f = min(1, max(0, fill)) * drawn
            ZStack {
                if f > 0.004 {
                    Circle()
                        .trim(from: 0, to: f)
                        .stroke(AngularGradient(stops: [.init(color: colors[0], location: 0), .init(color: colors[1], location: max(0.01, f))],
                                                center: .center, startAngle: .degrees(-2), endAngle: .degrees(358)),
                                style: StrokeStyle(lineWidth: width, lineCap: .round))
                        .frame(width: 2 * r, height: 2 * r)
                        .rotationEffect(.degrees(-90))
                    Circle().fill(colors[1])
                        .frame(width: width, height: width)
                        .shadow(color: colors[1].opacity(0.9), radius: 5)
                        .offset(y: -r)
                        .rotationEffect(.degrees(360 * f))
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .allowsHitTesting(false)
        .onAppear {
            if reduceMotion { drawn = 1 } else { withAnimation(.spring(response: 1.2, dampingFraction: 0.8).delay(0.1)) { drawn = 1 } }
        }
    }
}
