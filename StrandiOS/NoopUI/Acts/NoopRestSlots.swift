import SwiftUI

// MARK: - Rest, alternative "Your sleep" sections
//
// Four more ways to show last night, each a section the wearer can pick:
//   • Sleep · Dial — the night as an arc on a twelve-hour clock face, cut into its stages.
//   • Sleep · Performance — one thin gauge of sleep against need, with hours and stage rows.
//   • Sleep · Ledger — the night as plain figures on a grid, over a stage strip.
//   • Sleep · Aurora — the night as an aurora: curtains of light across the hours, as tall as the
//     sleep was deep, coloured by stage and slowly flowing.

private enum NoopSleepPalette {
    static let stage: [Color] = [Color.white.opacity(0.55), NoopHTMLColor.nightLight, Color(hex: 0x4FB8E8), Color(hex: 0x5D6BC4)]
    static let names = ["Awake", "Light", "REM", "Deep"]
    static func minutes(_ s: NoopRestRecord.StageMinutes, _ stage: Int) -> Double { [s.awake, s.light, s.rem, s.deep][stage] }
}

/// The night's runs, or its totals laid out in a typical order when no timeline was kept.
private func noopNightRuns(_ night: NoopRestRecord.Night) -> [NoopRestRecord.StageRun] {
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

private func noopNeedLine(_ asleep: Double, _ need: Double) -> String {
    guard need > 0 else { return "asleep" }
    let d = (asleep - need).rounded()
    return d >= 0 ? "\(NoopRestRecord.duration(d)) over your need" : "\(NoopRestRecord.duration(-d)) short of your need"
}

// MARK: Dial

struct NoopSleepDialSection: View {
    let night: NoopRestRecord.Night
    let needMin: Double
    let action: () -> Void

    private static let accent = Color(hex: 0x9C8CFF)

    var body: some View {
        Button(action: action) {
            NoopSlotCard(tint: Self.accent) {
                VStack(spacing: 16) {
                    HStack {
                        NoopSectionLabel("Your sleep", color: Self.accent)
                        Spacer()
                        Text(night.asleepWindow).font(NoopHTMLFont.sans(NoopType.caption)).monospacedDigit()
                            .foregroundStyle(NoopHTMLColor.faint)
                    }
                    ZStack {
                        NoopSlotClock { _, reveal in
                            Canvas { context, size in draw(&context, size, reveal: reveal) }
                        }
                        VStack(spacing: 2) {
                            Text(NoopRestRecord.duration(night.asleepMin))
                                .font(NoopHTMLFont.outfit(NoopType.title1, weight: .regular)).monospacedDigit()
                                .foregroundStyle(NoopHTMLColor.ink)
                            Text(needMin > 0 ? "of \(NoopRestRecord.duration(needMin)) needed" : "asleep")
                                .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                        }
                    }
                    .frame(width: 236, height: 236)
                    HStack(spacing: 10) {
                        chip("Efficiency", night.bed.map { "\(Int(($0.efficiency * 100).rounded()))%" } ?? "—")
                        chip("Deep", NoopRestRecord.duration(night.stages.deep))
                        chip("REM", NoopRestRecord.duration(night.stages.rem))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private func chip(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).monospacedDigit().foregroundStyle(NoopHTMLColor.ink)
            Text(title).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func draw(_ context: inout GraphicsContext, _ size: CGSize, reveal: Double) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let R = min(size.width, size.height) / 2
        let r = R - 16
        // A twelve-hour face: hour ticks and four numerals.
        for h in 0..<60 {
            let a = Double(h) / 60 * 2 * .pi - .pi / 2
            let major = h % 5 == 0
            var tick = Path()
            tick.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * (R - 1), y: c.y + CGFloat(sin(a)) * (R - 1)))
            tick.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * (R - (major ? 6 : 3)), y: c.y + CGFloat(sin(a)) * (R - (major ? 6 : 3))))
            context.stroke(tick, with: .color(.white.opacity(major ? 0.3 : 0.1)), lineWidth: major ? 1.5 : 1)
        }
        context.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                       with: .color(.white.opacity(0.06)), lineWidth: 18)
        guard let span = night.span ?? night.bed.map({ $0.fellAsleep...$0.finalWake }) else { return }
        let cal = Calendar.current
        func hourAngle(_ d: Date) -> Double {
            let comps = cal.dateComponents([.hour, .minute], from: d)
            let h = Double((comps.hour ?? 0) % 12) + Double(comps.minute ?? 0) / 60
            return h / 12 * 2 * .pi - .pi / 2
        }
        let a0 = hourAngle(span.lowerBound)
        var sweep = hourAngle(span.upperBound) - a0
        if sweep <= 0 { sweep += 2 * .pi }
        let drawn = sweep * reveal
        for run in noopNightRuns(night) {
            let from = a0 + run.from * sweep, to = min(a0 + run.to * sweep, a0 + drawn)
            guard to > from else { continue }
            var arc = Path()
            arc.addArc(center: c, radius: r, startAngle: .radians(from), endAngle: .radians(to), clockwise: false)
            context.stroke(arc, with: .color(NoopSleepPalette.stage[run.stage]), style: StrokeStyle(lineWidth: 18, lineCap: .butt))
        }
        // Soft rounded ends, a moon at bedtime and a sun at waking.
        for (angle, symbol) in [(a0, "moon.fill"), (a0 + drawn, "sun.max.fill")] {
            let p = CGPoint(x: c.x + CGFloat(cos(angle)) * r, y: c.y + CGFloat(sin(angle)) * r)
            context.fill(Path(ellipseIn: CGRect(x: p.x - 13, y: p.y - 13, width: 26, height: 26)), with: .color(Color(hex: 0x1B1D2B)))
            context.draw(Image(systemName: symbol), in: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14))
        }
    }
}

// MARK: Performance

struct NoopSleepPerformanceSection: View {
    let night: NoopRestRecord.Night
    let needMin: Double
    let action: () -> Void

    private static let tint = Color(hex: 0x7FA6C4)

    private var performance: Double { needMin > 0 ? min(1, night.asleepMin / needMin) : 0 }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 22) {
                    NoopSlotClock { _, reveal in
                        ZStack {
                            Circle().stroke(Color.white.opacity(0.1), lineWidth: 7)
                            Circle().trim(from: 0, to: performance * reveal)
                                .stroke(Self.tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 0) {
                                HStack(alignment: .firstTextBaseline, spacing: 0) {
                                    Text("\(Int((performance * 100 * reveal).rounded()))")
                                        .font(NoopHTMLFont.sans(NoopType.title1, weight: .heavy)).monospacedDigit()
                                    Text("%").font(NoopHTMLFont.sans(NoopType.subhead, weight: .heavy))
                                }
                                .foregroundStyle(NoopHTMLColor.ink)
                                Text("SLEEP").font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .bold)).tracking(1.6)
                                    .foregroundStyle(NoopHTMLColor.muted)
                            }
                        }
                    }
                    .frame(width: 128, height: 128)
                    VStack(alignment: .leading, spacing: 14) {
                        figure("HOURS OF SLEEP", clock(night.asleepMin))
                        figure("SLEEP NEEDED", needMin > 0 ? clock(needMin) : "—")
                    }
                }
                VStack(spacing: 10) {
                    ForEach([0, 1, 3, 2], id: \.self) { stage in row(stage) }
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private func clock(_ minutes: Double) -> String {
        let m = Int(minutes.rounded())
        return "\(m / 60):" + String(format: "%02d", m % 60)
    }

    private func figure(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(NoopHTMLFont.sans(NoopType.title2, weight: .heavy)).monospacedDigit().foregroundStyle(NoopHTMLColor.ink)
            Text(label).font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .bold)).tracking(1.4).foregroundStyle(NoopHTMLColor.muted)
        }
    }

    private func row(_ stage: Int) -> some View {
        let total = max(1, night.stages.asleep + night.stages.awake)
        let m = NoopSleepPalette.minutes(night.stages, stage)
        return HStack(spacing: 12) {
            Text(NoopSleepPalette.names[stage].uppercased())
                .font(NoopHTMLFont.sans(NoopType.caption, weight: .bold)).tracking(1.3)
                .foregroundStyle(NoopHTMLColor.ink).frame(width: 64, alignment: .leading)
            GeometryReader { p in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(Self.tint).frame(width: max(4, p.size.width * m / total))
                }
            }
            .frame(height: 7)
            Text(clock(m)).font(NoopHTMLFont.sans(NoopType.caption, weight: .bold)).monospacedDigit()
                .foregroundStyle(NoopHTMLColor.ink).frame(width: 44, alignment: .trailing)
            Text("\(Int((m / total * 100).rounded()))%").font(NoopHTMLFont.sans(NoopType.caption)).monospacedDigit()
                .foregroundStyle(NoopHTMLColor.muted).frame(width: 36, alignment: .trailing)
        }
    }
}

// MARK: Ledger

struct NoopSleepLedgerSection: View {
    let night: NoopRestRecord.Night
    let needMin: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            NoopHTMLCard(radius: 22, padding: 18) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        NoopSectionLabel("Your sleep", color: NoopHTMLColor.nightLight)
                        Spacer()
                        Text(noopNeedLine(night.asleepMin, needMin)).font(NoopHTMLFont.sans(NoopType.caption))
                            .foregroundStyle(NoopHTMLColor.copy)
                    }
                    NoopSlotClock { _, reveal in
                        GeometryReader { p in
                            HStack(spacing: 2) {
                                ForEach([3, 2, 1, 0], id: \.self) { stage in
                                    let total = max(1, night.stages.asleep + night.stages.awake)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(NoopSleepPalette.stage[stage])
                                        .frame(width: max(2, (p.size.width - 6) * NoopSleepPalette.minutes(night.stages, stage) / total * reveal))
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .frame(height: 8)
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 16) {
                        GridRow {
                            cell("Asleep", NoopRestRecord.duration(night.asleepMin), strong: true)
                            cell("In bed", night.bed.map { NoopRestRecord.duration($0.inBedMin) } ?? "—")
                            cell("Efficiency", night.bed.map { "\(Int(($0.efficiency * 100).rounded()))%" } ?? "—")
                        }
                        GridRow {
                            cell("Deep", NoopRestRecord.duration(night.stages.deep), dot: NoopSleepPalette.stage[3])
                            cell("REM", NoopRestRecord.duration(night.stages.rem), dot: NoopSleepPalette.stage[2])
                            cell("Light", NoopRestRecord.duration(night.stages.light), dot: NoopSleepPalette.stage[1])
                        }
                        GridRow {
                            cell("Fell asleep", night.bed.map { AppClock.hourMinuteFormatter().string(from: $0.fellAsleep) } ?? "—")
                            cell("Woke", night.bed.map { AppClock.hourMinuteFormatter().string(from: $0.finalWake) } ?? "—")
                            cell("Awake", NoopRestRecord.duration(night.stages.awake), dot: NoopSleepPalette.stage[0])
                        }
                    }
                }
            }
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private func cell(_ label: String, _ value: String, strong: Bool = false, dot: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                if let dot { Circle().fill(dot).frame(width: 6, height: 6) }
                Text(label).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.muted)
            }
            Text(value)
                .font(strong ? NoopHTMLFont.outfit(NoopType.title3, weight: .regular) : NoopHTMLFont.sans(NoopType.subhead, weight: .medium))
                .monospacedDigit().foregroundStyle(NoopHTMLColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: Aurora

struct NoopSleepAuroraSection: View {
    let night: NoopRestRecord.Night
    let needMin: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                NoopSlotClock { t, reveal in
                    Canvas { context, size in draw(&context, size, t: t, reveal: reveal) }
                }
                VStack(alignment: .leading, spacing: 4) {
                    NoopSectionLabel("Last night", color: Color(hex: 0xB7F5D8))
                    Text(NoopRestRecord.duration(night.asleepMin))
                        .font(NoopHTMLFont.outfit(NoopType.title1 + 10, weight: .ultraLight)).monospacedDigit()
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(noopNeedLine(night.asleepMin, needMin)).font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(NoopHTMLColor.copy)
                }
                .padding(18)
                Text(night.asleepWindow).font(NoopHTMLFont.sans(NoopType.eyebrow)).monospacedDigit()
                    .foregroundStyle(NoopHTMLColor.faint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(14)
            }
            .frame(height: 280)
            .background(Color(hex: 0x05070D), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    /// Curtain colours: deep sleep a violet-green aurora, REM a cyan, light a pale green, awake a
    /// faint white.
    private static let curtain: [(Color, Color)] = [
        (Color.white.opacity(0.5), Color.white.opacity(0)),
        (Color(hex: 0x7CF5B4), Color(hex: 0x2A8F7A)),
        (Color(hex: 0x6FE6FF), Color(hex: 0x3A6FE0)),
        (Color(hex: 0xB28CFF), Color(hex: 0x3BE3A0))
    ]
    private static let height: [Double] = [0.12, 0.45, 0.62, 0.92]

    private func draw(_ context: inout GraphicsContext, _ size: CGSize, t: Double, reveal: Double) {
        let w = Double(size.width), h = Double(size.height)
        // Stars, twinkling.
        for i in 0..<70 {
            let x = NoopAuraMath.hash(i * 3 + 1) * w, y = NoopAuraMath.hash(i * 5 + 2) * h * 0.55
            let tw = 0.3 + 0.7 * (0.5 + 0.5 * sin(t * (0.8 + NoopAuraMath.hash(i) * 2) + Double(i)))
            let s = 0.6 + 1.2 * NoopAuraMath.hash(i * 7)
            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)), with: .color(.white.opacity(0.5 * tw * reveal)))
        }
        // The curtains: one vertical ray every few points across the night, rising from the
        // horizon as high as that moment's sleep was deep, swaying and shimmering.
        let runs = noopNightRuns(night)
        func stage(at f: Double) -> Int { runs.first { f >= $0.from && f < $0.to }?.stage ?? 0 }
        let horizon = h * 0.98
        var glow = context
        glow.blendMode = .plusLighter
        glow.addFilter(.blur(radius: 3))
        let rays = 120
        for i in 0..<rays {
            let f = Double(i) / Double(rays - 1)
            guard f <= reveal else { break }
            // A soft average of nearby depth so the curtain's top edge flows.
            var depth = 0.0, wsum = 0.0
            for k in -4...4 {
                let ff = min(1, max(0, f + Double(k) / Double(rays)))
                let wt = exp(-Double(k * k) / 8)
                depth += Self.height[stage(at: ff)] * wt; wsum += wt
            }
            depth /= wsum
            let st = stage(at: f)
            let sway = 6 * sin(t * 0.7 + f * 9) + 3 * sin(t * 1.3 - f * 17)
            let shimmer = 0.65 + 0.35 * sin(t * 2.1 + f * 40)
            let x = 10 + f * (w - 20) + sway * (1 - f * 0.3)
            let top = horizon - depth * h * 0.78 * (0.94 + 0.06 * sin(t + f * 6))
            var ray = Path()
            ray.move(to: CGPoint(x: x, y: horizon)); ray.addLine(to: CGPoint(x: x + sway * 0.4, y: top))
            let (c0, c1) = Self.curtain[st]
            glow.stroke(ray, with: .linearGradient(Gradient(stops: [
                .init(color: c1.opacity(0), location: 0),
                .init(color: c1.opacity(0.35 * shimmer), location: 0.25),
                .init(color: c0.opacity(0.75 * shimmer), location: 0.8),
                .init(color: c0.opacity(0), location: 1)
            ]), startPoint: CGPoint(x: x, y: horizon), endPoint: CGPoint(x: x, y: top)), lineWidth: 4.2)
        }
        // The horizon line, faintly lit.
        var line = Path()
        line.move(to: CGPoint(x: 0, y: horizon)); line.addLine(to: CGPoint(x: w * reveal, y: horizon))
        context.stroke(line, with: .linearGradient(Gradient(colors: [.clear, Color(hex: 0x7CF5B4).opacity(0.5), .clear]),
                                                   startPoint: .zero, endPoint: CGPoint(x: w, y: 0)), lineWidth: 1)
    }
}
