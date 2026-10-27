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

/// A Button when there is somewhere to go, the bare label when there is not, so a card never presses
/// into nothing.
struct NoopOptionalButton<Label: View>: View {
    let action: (() -> Void)?
    @ViewBuilder let label: Label

    var body: some View {
        if let action { Button(action: action) { label } } else { label }
    }
}

struct NoopSleepDialSection: View {
    let night: NoopRestRecord.Night
    let needMin: Double
    /// What a tap opens; nil leaves the card a plain card.
    var action: (() -> Void)? = nil

    private static let accent = Color(hex: 0x9C8CFF)

    var body: some View {
        NoopOptionalButton(action: action) {
            NoopSlotCard(tint: Self.accent) {
                VStack(spacing: 16) {
                    HStack {
                        NoopSectionLabel("Your sleep", color: Self.accent)
                        Spacer()
                        Text(night.asleepWindow).font(NoopHTMLFont.sans(NoopType.caption)).monospacedDigit()
                            .foregroundStyle(NoopHTMLColor.faint)
                    }
                    ZStack {
                        NoopSlotClock(continuous: false) { _, reveal in
                            Canvas { context, size in draw(&context, size, reveal: reveal) }
                        }
                        VStack(spacing: 2) {
                            NoopCountUp(value: night.asleepMin, format: { NoopRestRecord.duration($0) },
                                        font: NoopHTMLFont.outfit(NoopType.title1, weight: .regular))
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
    /// What a tap opens; nil leaves the card a plain card.
    var action: (() -> Void)? = nil

    private static let tint = Color(hex: 0x7FA6C4)

    private var performance: Double {
        if let score = night.score { return min(1, max(0, score / 100)) }
        return needMin > 0 ? min(1, night.asleepMin / needMin) : 0
    }

    var body: some View {
        NoopOptionalButton(action: action) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 22) {
                    NoopSlotClock(continuous: false) { _, reveal in
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
    /// What a tap opens; nil leaves the card a plain card.
    var action: (() -> Void)? = nil

    var body: some View {
        NoopOptionalButton(action: action) {
            NoopHTMLCard(radius: 22, padding: 18) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        NoopSectionLabel("Your sleep", color: NoopHTMLColor.nightLight)
                        Spacer()
                        Text(noopNeedLine(night.asleepMin, needMin)).font(NoopHTMLFont.sans(NoopType.caption))
                            .foregroundStyle(NoopHTMLColor.copy)
                    }
                    NoopSlotClock(continuous: false) { _, reveal in
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
    /// What a tap opens; nil leaves the card a plain card.
    var action: (() -> Void)? = nil

    /// How high each stage reaches: awake barely lifts off the horizon, deep reaches the top.
    private static let height: [Float] = [0.08, 0.42, 0.62, 0.95]

    var heightsForHero: [Float] { heights }

    /// The night's depth at 64 points, softened so the crown flows rather than steps.
    private var heights: [Float] {
        let runs = noopNightRuns(night)
        func stage(at f: Double) -> Int { runs.first { f >= $0.from && f < $0.to }?.stage ?? runs.last?.stage ?? 0 }
        let n = 64
        let raw = (0..<n).map { Self.height[stage(at: (Double($0) + 0.5) / Double(n))] }
        return (0..<n).map { i in
            var sum: Float = 0, wsum: Float = 0
            for j in max(0, i - 2)...min(n - 1, i + 2) {
                let wt = exp(-Float((j - i) * (j - i)) / 2.5)
                sum += raw[j] * wt; wsum += wt
            }
            return sum / wsum
        }
    }

    var body: some View {
        NoopOptionalButton(action: action) {
            ZStack(alignment: .topLeading) {
                NoopSlotClock { t, reveal in
                    GeometryReader { g in
                        Rectangle()
                            .colorEffect(ShaderLibrary.noopAurora(
                                .float2(g.size), .float(Float(t)), .float(Float(reveal)), .floatArray(heights)))
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    NoopCountUp(value: night.asleepMin, format: { NoopRestRecord.duration($0) },
                                font: NoopHTMLFont.outfit(NoopType.title1 + 8, weight: .ultraLight))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(noopNeedLine(night.asleepMin, needMin)).font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                .padding(20)
                Text(night.asleepWindow).font(NoopHTMLFont.sans(NoopType.eyebrow)).monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(20)
            }
            .frame(height: 300)
            .background(Color(hex: 0x04060B), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: Glass

/// Last night as layered liquid in a glass: deep settled at the bottom, then REM, light and awake,
/// filled to the night against the need. A fine line marks the need. The liquid keeps level as the
/// phone tilts and sloshes when it moves; the layers below barely stir.
struct NoopSleepGlassSection: View {
    let night: NoopRestRecord.Night
    let needMin: Double
    /// What a tap opens; nil leaves the card a plain card.
    var action: (() -> Void)? = nil

    var body: some View {
        NoopOptionalButton(action: action) {
            NoopSlotCard(tint: Color(hex: 0x5D6BC4)) {
                HStack(alignment: .center, spacing: 22) {
                    NoopSleepGlass(night: night, needMin: needMin).frame(width: 110, height: 190)
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            NoopCountUp(value: night.asleepMin, format: { NoopRestRecord.duration($0) },
                                        font: NoopHTMLFont.outfit(NoopType.title1, weight: .light))
                                .foregroundStyle(NoopHTMLColor.ink)
                            Text(noopNeedLine(night.asleepMin, needMin)).font(NoopHTMLFont.sans(NoopType.caption))
                                .foregroundStyle(NoopHTMLColor.copy)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach([0, 1, 2, 3], id: \.self) { stage in
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 2).fill(NoopSleepPalette.stage[stage]).frame(width: 10, height: 10)
                                    Text(NoopSleepPalette.names[stage]).font(NoopHTMLFont.sans(NoopType.caption))
                                        .foregroundStyle(NoopHTMLColor.copy)
                                    Spacer(minLength: 4)
                                    Text(NoopRestRecord.duration(NoopSleepPalette.minutes(night.stages, stage)))
                                        .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).monospacedDigit()
                                        .foregroundStyle(NoopHTMLColor.ink)
                                }
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

/// The glass itself: layered liquid filled toward the need line, springing full when it appears and
/// keeping level as the phone tilts.
struct NoopSleepGlass: View {
    let night: NoopRestRecord.Night
    let needMin: Double

    @State private var level: Double = 0
    @State private var onScreen = true
    @State private var lastTilt: Double = 0
    @State private var slosh: Double = 0
    /// Whether this view holds the shared tilt sensor, so appear and disappear stay paired.
    @State private var holdsMotion = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The glass holds a little more than the need, so a night over it still fits.
    private var capacity: Double { max(night.asleepMin + night.stages.awake, needMin * 1.15, 1) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !onScreen || reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
            let tilt = reduceMotion ? 0 : LiquidMotion.shared.tilt
            let s = night.stages
            let total = max(1, s.deep + s.rem + s.light + s.awake)
            let fill = min(1, (s.deep + s.rem + s.light + s.awake) / capacity) * level
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color.white.opacity(0.04))
                Rectangle()
                    .colorEffect(ShaderLibrary.noopLayeredLiquid(
                        .float2(CGSize(width: 110, height: 190)), .float(Float(t)), .float(Float(fill)),
                        .float(Float(-tan(tilt) * 110 / 190)), .float(Float(slosh + 0.25 * max(0, 1 - level))),
                        .float(Float(s.deep / total)), .float(Float((s.deep + s.rem) / total)),
                        .float(Float((s.deep + s.rem + s.light) / total)),
                        .color(NoopSleepPalette.stage[3]), .color(NoopSleepPalette.stage[2]),
                        .color(NoopSleepPalette.stage[1]), .color(Color(hex: 0x9AA0B8))))
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                if needMin > 0 {
                    GeometryReader { g in
                        let y = g.size.height * (1 - needMin / capacity)
                        Rectangle().fill(Color.white.opacity(0.55)).frame(width: g.size.width - 20, height: 1)
                            .position(x: g.size.width / 2, y: y)
                        Text("need").font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(Color.white.opacity(0.6))
                            .position(x: g.size.width - 24, y: y - 9)
                    }
                }
                RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            }
            .onChange(of: timeline.date) {
                let turn = abs(tilt - lastTilt)
                slosh = min(1.4, slosh * 0.94 + turn * 9)
                lastTilt = tilt
            }
        }
        .onAppear { if !holdsMotion { holdsMotion = true; LiquidMotion.shared.acquire() } }
        .onDisappear { if holdsMotion { holdsMotion = false; LiquidMotion.shared.release() } }
        .modifier(NoopSlotVisibility(onScreen: $onScreen))
        .onAppear {
            if reduceMotion { level = 1 } else { withAnimation(.spring(response: 1.6, dampingFraction: 0.75)) { level = 1 } }
        }
    }
}

// MARK: - Rest heroes

/// The aurora as a round hero: the night's curtains inside a dark disc, the time asleep over them.
struct NoopSleepAuroraHero: View {
    let night: NoopRestRecord.Night
    let needMin: Double
    var side: CGFloat = 250

    var body: some View {
        let section = NoopSleepAuroraSection(night: night, needMin: needMin)
        NoopSlotClock { t, reveal in
            ZStack {
                Circle().fill(RadialGradient(colors: [Color(hex: 0x141833), Color(hex: 0x05060C)], center: .center,
                                             startRadius: 0, endRadius: side / 2))
                Rectangle()
                    .colorEffect(ShaderLibrary.noopAurora(.float2(CGSize(width: side, height: side)), .float(Float(t)),
                                                         .float(Float(reveal)), .floatArray(section.heightsForHero)))
                    .clipShape(Circle())
                Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                VStack(spacing: 2) {
                    NoopCountUp(value: night.asleepMin, format: { NoopRestRecord.duration($0) },
                                font: NoopHTMLFont.outfit(NoopType.title1 + 6, weight: .light))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(noopNeedLine(night.asleepMin, needMin)).font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .offset(y: -side * 0.16)
                .shadow(color: .black.opacity(0.5), radius: 8)
            }
        }
        .frame(width: side, height: side)
    }
}

/// The layered glass as a hero: the night's stages settled in a glass filled toward the need line.
struct NoopSleepGlassHero: View {
    let night: NoopRestRecord.Night
    let needMin: Double

    var body: some View {
        HStack(spacing: 22) {
            NoopSleepGlass(night: night, needMin: needMin).frame(width: 110, height: 190)
            VStack(alignment: .leading, spacing: 4) {
                NoopCountUp(value: night.asleepMin, format: { NoopRestRecord.duration($0) },
                            font: NoopHTMLFont.outfit(NoopType.title1, weight: .light))
                    .foregroundStyle(NoopHTMLColor.ink)
                Text(noopNeedLine(night.asleepMin, needMin)).font(NoopHTMLFont.sans(NoopType.caption))
                    .foregroundStyle(NoopHTMLColor.copy)
            }
        }
    }
}
