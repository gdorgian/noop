import Charts
import StrandAnalytics
import SwiftUI

// MARK: - Rest, night-detail sections
//
// Five more sections for the Sleep page (27 Oct 2026), off until the wearer adds them from the edit bar:
//   • Sleep period — in bed and asleep, then six reads of the night, each rated Poor to Excellent.
//   • Sleep stages — the night as a stepped hypnogram you can scrub, and each stage against its usual share.
//   • Time to fall asleep — lying down to asleep, on a fast · normal · late track.
//   • Sleeping vitals — heart rate, HRV, breathing and oxygen across the night.
//   • Sleep needed — what the night asked of you, and how that was worked out.
// They add to the page; nothing already on it changes.

private enum NoopNightStage {
    static let color: [Color] = [Color(hex: 0xF2A27A), NoopHTMLColor.nightLight, Color(hex: 0x4FB8E8), Color(hex: 0x5D6BC4)]
    static let name = ["Awake", "Light", "REM", "Deep"]
    /// Top to bottom on the hypnogram: awake, REM, light, deep.
    static let lane = [0, 2, 1, 3]
    static func minutes(_ s: NoopRestRecord.StageMinutes, _ stage: Int) -> Double { [s.awake, s.light, s.rem, s.deep][stage] }
}

private func noopClock(_ date: Date) -> String { AppClock.hourMinuteFormatter().string(from: date) }

/// The night's edges: lying down to getting up when the bed is known, else the recorded span.
private func noopNightEdges(_ night: NoopRestRecord.Night) -> (start: Date, end: Date)? {
    if let bed = night.bed { return (bed.inBed, bed.outOfBed) }
    if let span = night.span { return (span.lowerBound, span.upperBound) }
    return nil
}

/// A card in the night-detail sections: Rest's own card, so they sit with the page's other cards.
private struct NoopNightCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }
}

// MARK: - Ratings

enum NoopNightRating: Int, Comparable {
    case poor, fair, good, excellent

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    var title: String { ["Poor", "Fair", "Good", "Excellent"][rawValue] }

    var fill: LinearGradient {
        let colors: [Color]
        switch self {
        case .poor: colors = [Color(hex: 0xE9785A), Color(hex: 0xF29A72)]
        case .fair: colors = [Color(hex: 0xD9A23A), Color(hex: 0xF0C25C)]
        case .good: colors = [Color(hex: 0x3FBF9A), Color(hex: 0x6ED8B4)]
        case .excellent: colors = [Color(hex: 0x8C8CF0), Color(hex: 0x8FD3F5)]
        }
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }

    /// Rated by the highest band the value reaches; bands are listed excellent, good, fair.
    static func atLeast(_ value: Double, _ bands: (Double, Double, Double)) -> Self {
        value >= bands.0 ? .excellent : value >= bands.1 ? .good : value >= bands.2 ? .fair : .poor
    }

    /// Rated by the lowest band the value stays under, for reads where less is better.
    static func atMost(_ value: Double, _ bands: (Double, Double, Double)) -> Self {
        value <= bands.0 ? .excellent : value <= bands.1 ? .good : value <= bands.2 ? .fair : .poor
    }
}

/// The six reads of a night. Bands follow adult sleep norms (stage shares from polysomnography reviews,
/// efficiency ≥ 85 % as healthy, a nocturnal heart-rate dip of 10 % or more as normal), not any one app's.
struct NoopNightReads {
    struct Read: Identifiable {
        let id: String
        let title: String
        let glyph: String
        let rating: NoopNightRating?
        /// How far along the bar is filled, 0–1.
        let fill: Double
        /// What the rating was drawn from, in figures.
        let figure: String
        let about: String
    }

    static func make(_ night: NoopRestRecord.Night, needMin: Double, dip: Double?) -> [Read] {
        let asleep = night.asleepMin
        let need = max(1, needMin)
        var reads: [Read] = []

        let time = asleep / need
        reads.append(Read(id: "time", title: "Time asleep", glyph: "clock.fill",
                          rating: needMin > 0 ? .atLeast(time, (0.95, 0.85, 0.7)) : nil, fill: time,
                          figure: needMin > 0 ? "\(NoopRestRecord.duration(asleep)) of the \(NoopRestRecord.duration(needMin)) you need"
                                              : "\(NoopRestRecord.duration(asleep)) asleep",
                          about: "Light, REM and deep together, against your own need."))

        reads.append(Read(id: "dip", title: "Heart rate dip", glyph: "bolt.heart.fill",
                          rating: dip.map { .atLeast($0, (0.15, 0.10, 0.05)) }, fill: (dip ?? 0) / 0.2,
                          figure: dip.map { "Pulse fell \(Int(($0 * 100).rounded()))% from before bed to asleep" }
                              ?? "Needs the strap on in the hour before bed",
                          about: "A bigger drop means the body settled into restoring sleep."))

        // The stages against the share of your need they usually fill in a healthy adult night.
        let remTarget = need * 0.22, deepTarget = need * 0.17
        let share = { (m: Double) in asleep > 0 ? Int((m / asleep * 100).rounded()) : 0 }
        reads.append(Read(id: "rem", title: "REM sleep", glyph: "eye.fill",
                          rating: .atLeast(night.stages.rem / remTarget, (0.95, 0.8, 0.6)), fill: night.stages.rem / remTarget,
                          figure: "\(NoopRestRecord.duration(night.stages.rem)), \(share(night.stages.rem))% of your sleep",
                          about: "Dreaming sleep, where memory and mood are sorted."))
        reads.append(Read(id: "deep", title: "Deep sleep", glyph: "zzz",
                          rating: .atLeast(night.stages.deep / deepTarget, (0.95, 0.8, 0.6)), fill: night.stages.deep / deepTarget,
                          figure: "\(NoopRestRecord.duration(night.stages.deep)), \(share(night.stages.deep))% of your sleep",
                          about: "The slowest sleep, where the body repairs."))

        let efficiency = night.bed?.efficiency ?? (asleep / max(1, asleep + night.stages.awake))
        reads.append(Read(id: "efficiency", title: "Efficiency", glyph: "gauge.with.dots.needle.67percent",
                          rating: .atLeast(efficiency, (0.94, 0.9, 0.85)), fill: (efficiency - 0.6) / 0.4,
                          figure: "Asleep \(Int((efficiency * 100).rounded()))% of the time in bed",
                          about: "How much of your time in bed went to sleep."))

        let breaks = interruptions(night)
        reads.append(Read(id: "continuity", title: "Continuity", glyph: "moon.zzz.fill",
                          rating: .atMost(breaks.minutes, (10, 20, 35)), fill: 1 - breaks.minutes / 60,
                          figure: breaks.count == 0 ? "Slept through without waking"
                              : "Woke \(breaks.count) \(breaks.count == 1 ? "time" : "times"), \(NoopRestRecord.duration(breaks.minutes)) in all",
                          about: "Waking between falling asleep and the final wake."))
        return reads
    }

    /// Awake runs between the first and the last sleep, at least a minute long.
    static func interruptions(_ night: NoopRestRecord.Night) -> (count: Int, minutes: Double) {
        guard let runs = night.runs, let span = night.span,
              let first = runs.firstIndex(where: { $0.stage != 0 }),
              let last = runs.lastIndex(where: { $0.stage != 0 }), first < last else {
            return (0, night.bed?.interruptionsMin ?? 0)
        }
        let total = span.upperBound.timeIntervalSince(span.lowerBound) / 60
        let wakes = runs[first...last].filter { $0.stage == 0 }.map { ($0.to - $0.from) * total }.filter { $0 >= 1 }
        return (wakes.count, wakes.reduce(0, +))
    }
}

// MARK: - Sleep period

struct NoopSleepPeriodSection: View {
    let night: NoopRestRecord.Night
    let needMin: Double

    @EnvironmentObject private var model: AppModel
    @State private var dip: Double?
    @State private var picked: String?
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var reads: [NoopNightReads.Read] { NoopNightReads.make(night, needMin: needMin, dip: dip) }

    var body: some View {
        VStack(spacing: 10) {
            NoopNightCard {
                HStack(spacing: 10) {
                    Image(systemName: "bed.double.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.faint)
                    Text("Sleep period")
                        .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Spacer(minLength: 8)
                    if let edges = noopNightEdges(night) {
                        Text("\(noopClock(edges.start)) – \(noopClock(edges.end))")
                            .font(NoopHTMLFont.sans(NoopType.subhead, weight: .medium))
                            .foregroundStyle(NoopHTMLColor.inkSoft)
                            .monospacedDigit()
                    }
                }
            }

            NoopNightCard(padding: 0) {
                HStack(spacing: 0) {
                    figure("Time in bed", night.bed?.inBedMin ?? (night.asleepMin + night.stages.awake))
                    Rectangle().fill(NoopHTMLColor.border).frame(width: 1).padding(.vertical, 18)
                    figure("Time asleep", night.asleepMin)
                }
            }

            NoopNightCard(padding: 0) {
                VStack(spacing: 0) {
                    let all = reads
                    ForEach(0..<3, id: \.self) { row in
                        if row > 0 { Rectangle().fill(NoopHTMLColor.border).frame(height: 1).padding(.horizontal, 16) }
                        HStack(spacing: 0) {
                            tile(all[row * 2], index: row * 2)
                            Rectangle().fill(NoopHTMLColor.border).frame(width: 1).padding(.vertical, 16)
                            tile(all[row * 2 + 1], index: row * 2 + 1)
                        }
                    }
                    if let read = all.first(where: { $0.id == picked }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(read.figure)
                                .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.ink)
                            Text(read.about)
                                .font(NoopHTMLFont.sans(NoopType.caption))
                                .foregroundStyle(NoopHTMLColor.copy)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding([.horizontal, .bottom], 12)
                        .id(read.id)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: -6)), removal: .opacity))
                    }
                }
            }
        }
        .onAppear {
            guard !shown else { return }
            if reduceMotion { shown = true } else { withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.1)) { shown = true } }
        }
        .task(id: night.dayKey) { await loadDip() }
    }

    private func figure(_ label: String, _ minutes: Double) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium))
                .foregroundStyle(NoopHTMLColor.faint)
            NoopCountUp(value: minutes, format: { NoopRestRecord.duration($0) },
                        font: NoopHTMLFont.outfit(NoopType.title2, weight: .medium))
                .foregroundStyle(NoopHTMLColor.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func tile(_ read: NoopNightReads.Read, index: Int) -> some View {
        let on = picked == read.id
        return Button {
            NoopHaptics.play(.tick)
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { picked = on ? nil : read.id }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: read.glyph)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(on ? NoopHTMLColor.ink : NoopHTMLColor.faint)
                    .symbolEffect(.bounce, value: on)
                    .frame(height: 22)
                Text(read.rating?.title ?? "—")
                    .font(NoopHTMLFont.outfit(NoopType.title3, weight: .medium))
                    .foregroundStyle(NoopHTMLColor.ink)
                    .contentTransition(.opacity)
                Text(read.title)
                    .font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium))
                    .foregroundStyle(NoopHTMLColor.faint)
                bar(read, index: index)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoopHTMLPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(read.figure)
    }

    private func bar(_ read: NoopNightReads.Read, index: Int) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                if let rating = read.rating {
                    Capsule().fill(rating.fill)
                        .frame(width: proxy.size.width * (shown ? min(1, max(0.06, read.fill)) : 0))
                        .animation(reduceMotion ? nil : .spring(response: 0.9, dampingFraction: 0.82).delay(0.12 + Double(index) * 0.06), value: shown)
                }
            }
        }
        .frame(width: 112, height: 5)
    }

    /// The fall from the pulse in the hour before bed (median, so a walk to the bedroom does not count)
    /// to the average while asleep.
    private func loadDip() async {
        dip = nil
        guard let bed = night.bed else { return }
        let before = await model.repo.timelineSeries(metric: .hr, from: Int(bed.inBed.timeIntervalSince1970) - 3600,
                                                     to: Int(bed.inBed.timeIntervalSince1970), targetPoints: 120)
        let asleep = await model.repo.timelineSeries(metric: .hr, from: Int(bed.fellAsleep.timeIntervalSince1970),
                                                     to: Int(bed.finalWake.timeIntervalSince1970), targetPoints: 240)
        let pre = before.points.map(\.value).filter { $0 > 25 }.sorted()
        let during = asleep.points.map(\.value).filter { $0 > 25 }
        guard pre.count >= 10, during.count >= 10 else { return }
        let awake = pre[pre.count / 2], sleeping = during.reduce(0, +) / Double(during.count)
        withAnimation(.easeOut(duration: 0.25)) { dip = max(0, (awake - sleeping) / awake) }
    }
}

// MARK: - Sleep stages

struct NoopSleepStagesSection: View {
    let night: NoopRestRecord.Night
    /// The other recorded nights, for each stage's usual share.
    let history: [NoopRestRecord.Night]

    @State private var focus: Int?
    @State private var scrubRun: Int?
    @State private var scrubbing = false
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var runs: [NoopRestRecord.StageRun] { night.runs ?? [] }

    var body: some View {
        NoopNightCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Sleep stages")
                    .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.ink)
                if let span = night.span, !runs.isEmpty {
                    hypnogram(span)
                    HStack {
                        chip("moon.fill", noopClock(night.bed?.fellAsleep ?? span.lowerBound))
                        Spacer()
                        chip("sun.max.fill", noopClock(night.bed?.finalWake ?? span.upperBound))
                    }
                }
                HStack(spacing: 8) {
                    if typical != nil {
                        Image(systemName: "line.diagonal").rotationEffect(.degrees(45)).font(.system(size: 11, weight: .bold))
                        Text("Your usual range")
                    }
                    Spacer()
                    Text("In bed ").foregroundStyle(NoopHTMLColor.faint)
                        + Text(NoopRestRecord.duration(night.bed?.inBedMin ?? (night.asleepMin + night.stages.awake))).foregroundStyle(NoopHTMLColor.ink)
                }
                .font(NoopHTMLFont.sans(NoopType.caption, weight: .medium))
                .foregroundStyle(NoopHTMLColor.faint)
                .monospacedDigit()
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach([0, 2, 1, 3], id: \.self) { stage in stageCard(stage) }
                }
            }
        }
        .onAppear {
            guard !shown else { return }
            if reduceMotion { shown = true } else { withAnimation(.spring(response: 1.1, dampingFraction: 0.88).delay(0.15)) { shown = true } }
        }
        .onChange(of: night.dayKey) { _, _ in focus = nil; scrubRun = nil }
    }

    private func chip(_ glyph: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: glyph).font(.system(size: 11, weight: .semibold))
            Text(text).monospacedDigit()
        }
        .font(NoopHTMLFont.sans(NoopType.caption, weight: .medium))
        .foregroundStyle(NoopHTMLColor.inkSoft)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    // MARK: Hypnogram

    private func hypnogram(_ span: ClosedRange<Date>) -> some View {
        let total = span.upperBound.timeIntervalSince(span.lowerBound)
        return GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .topLeading) {
                NoopSlotClock(continuous: false) { _, reveal in
                    Canvas { context, canvasSize in
                        draw(&context, canvasSize, reveal: reveal)
                    }
                }
                .padding(.top, 10)
                .contentShape(Rectangle())
                .gesture(press(width: size.width))
                if let index = scrubRun, runs.indices.contains(index) {
                    let run = runs[index]
                    let x = size.width * (run.from + run.to) / 2
                    Rectangle()
                        .fill(LinearGradient(colors: [.white.opacity(0), .white.opacity(0.5), .white.opacity(0.5), .white.opacity(0)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 1, height: size.height - 4)
                        .position(x: x, y: 10 + (size.height - 10) / 2)
                        .allowsHitTesting(false)
                    let from = span.lowerBound.addingTimeInterval(run.from * total)
                    let to = span.lowerBound.addingTimeInterval(run.to * total)
                    HStack(spacing: 6) {
                        Circle().fill(NoopNightStage.color[run.stage]).frame(width: 7, height: 7)
                        Text(NoopNightStage.name[run.stage]).font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                            .foregroundStyle(NoopHTMLColor.ink)
                        Text("\(noopClock(from)) – \(noopClock(to))").font(NoopHTMLFont.sans(NoopType.caption))
                            .foregroundStyle(NoopHTMLColor.copy).monospacedDigit()
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                    .fixedSize()
                    .alignmentGuide(.leading) { d in -min(max(0, x - d.width / 2), size.width - d.width) }
                    .offset(y: -34)
                    .contentTransition(.numericText())
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .bottom)))
                }
            }
        }
        .frame(height: 180)
        .animation(reduceMotion ? nil : .interactiveSpring(response: 0.22, dampingFraction: 0.86), value: scrubRun)
        .accessibilityElement()
        .accessibilityLabel("Sleep stages from \(noopClock(span.lowerBound)) to \(noopClock(span.upperBound))")
    }

    private func draw(_ context: inout GraphicsContext, _ size: CGSize, reveal: Double) {
        let laneH = size.height / 4
        let thick = laneH * 0.58
        // Guides between the lanes.
        for i in 1..<4 {
            var line = Path()
            line.move(to: CGPoint(x: 0, y: laneH * CGFloat(i)))
            line.addLine(to: CGPoint(x: size.width, y: laneH * CGFloat(i)))
            context.stroke(line, with: .color(.white.opacity(0.06)), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
        }
        context.clip(to: Path(CGRect(x: 0, y: -4, width: size.width * reveal, height: size.height + 8)))
        func mid(_ stage: Int) -> CGFloat { laneH * (CGFloat(NoopNightStage.lane[stage]) + 0.5) }
        func alpha(_ index: Int, _ stage: Int) -> Double {
            if let scrubRun { return scrubRun == index ? 1 : 0.3 }
            if let focus { return focus == stage ? 1 : 0.22 }
            return 1
        }
        // Risers first, so the bars sit over them.
        for i in runs.indices.dropFirst() {
            let a = runs[i - 1], b = runs[i]
            let x = size.width * b.from
            let rect = CGRect(x: x - 0.75, y: min(mid(a.stage), mid(b.stage)), width: 1.5, height: abs(mid(a.stage) - mid(b.stage)))
            let top = NoopNightStage.lane[a.stage] < NoopNightStage.lane[b.stage] ? a.stage : b.stage
            let bottom = top == a.stage ? b.stage : a.stage
            context.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [NoopNightStage.color[top].opacity(0.55), NoopNightStage.color[bottom].opacity(0.55)]),
                startPoint: CGPoint(x: x, y: rect.minY), endPoint: CGPoint(x: x, y: rect.maxY)))
        }
        for (i, run) in runs.enumerated() {
            let x0 = size.width * run.from, x1 = max(x0 + 1.5, size.width * run.to)
            let rect = CGRect(x: x0, y: mid(run.stage) - thick / 2, width: x1 - x0, height: thick)
            let color = NoopNightStage.color[run.stage]
            context.opacity = alpha(i, run.stage)
            context.fill(Path(roundedRect: rect, cornerRadius: min(4, (x1 - x0) / 2)), with: .linearGradient(
                Gradient(colors: [color, color.opacity(0.72)]),
                startPoint: CGPoint(x: x0, y: rect.minY), endPoint: CGPoint(x: x0, y: rect.maxY)))
            context.opacity = 1
        }
    }

    /// A short press arms the scrub so a swipe across the card still scrolls the page, as on every chart.
    private func press(width: CGFloat) -> some Gesture {
        LongPressGesture(minimumDuration: 0.14, maximumDistance: 14)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                if !scrubbing { scrubbing = true; NoopHaptics.play(.grab) }
                guard let drag, width > 0 else { return }
                let f = min(max(0, drag.location.x / width), 0.9999)
                if let index = runs.firstIndex(where: { f >= $0.from && f < $0.to }), index != scrubRun {
                    if scrubRun != nil { NoopHaptics.play(.tick) }
                    scrubRun = index
                }
            }
            .onEnded { _ in
                scrubbing = false
                withAnimation(.easeOut(duration: 0.22)) { scrubRun = nil }
            }
    }

    // MARK: Stage cards

    /// Each stage's usual share of the night, from the other recorded nights: the middle half of them.
    private var typical: [ClosedRange<Double>]? {
        let others = history.filter { $0.dayKey != night.dayKey }
        guard others.count >= 3 else { return nil }
        return (0..<4).map { stage in
            let shares = others.map { n -> Double in
                let all = n.stages.asleep + n.stages.awake
                return all > 0 ? NoopNightStage.minutes(n.stages, stage) / all : 0
            }.sorted()
            let lo = shares[Int(Double(shares.count - 1) * 0.25)], hi = shares[Int((Double(shares.count - 1) * 0.75).rounded())]
            return lo...max(lo + 0.01, hi)
        }
    }

    private func stageCard(_ stage: Int) -> some View {
        let all = max(1, night.stages.asleep + night.stages.awake)
        let minutes = NoopNightStage.minutes(night.stages, stage)
        let share = minutes / all
        let color = NoopNightStage.color[stage]
        let on = focus == stage
        let range = typical?[stage]
        return Button {
            NoopHaptics.play(.tick)
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { focus = on ? nil : stage }
        } label: {
            HStack(alignment: .center, spacing: 6) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(NoopNightStage.name[stage])
                        .font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium))
                        .foregroundStyle(NoopHTMLColor.faint)
                    NoopCountUp(value: minutes, format: { NoopRestRecord.duration($0) },
                                font: NoopHTMLFont.outfit(NoopType.body, weight: .medium))
                        .foregroundStyle(NoopHTMLColor.ink)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text("\(Int((share * 100).rounded()))%")
                        .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                        .foregroundStyle(color)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle().stroke(Color.white.opacity(0.07), lineWidth: 5)
                    if let range {
                        Circle().trim(from: range.lowerBound, to: range.upperBound)
                            .stroke(Color.white.opacity(0.16), style: StrokeStyle(lineWidth: 5))
                            .rotationEffect(.degrees(-90))
                        ForEach([range.lowerBound, range.upperBound], id: \.self) { edge in
                            Capsule().fill(Color.white.opacity(0.85)).frame(width: 2, height: 9)
                                .offset(y: -22)
                                .rotationEffect(.degrees(edge * 360))
                        }
                    }
                    Circle().trim(from: 0, to: shown ? max(0.008, share) : 0)
                        .stroke(LinearGradient(colors: [color.opacity(0.7), color], startPoint: .top, endPoint: .bottom),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: color.opacity(on ? 0.6 : 0), radius: 6)
                }
                .frame(width: 44, height: 44)
            }
            .padding(12)
            .background(on ? color.opacity(0.1) : Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(on ? color.opacity(0.45) : Color.white.opacity(0.05), lineWidth: on ? 1 : 0.5))
            .opacity(focus == nil || on ? 1 : 0.55)
        }
        .buttonStyle(NoopHTMLPressStyle())
        .accessibilityLabel("\(NoopNightStage.name[stage]), \(NoopRestRecord.duration(minutes)), \(Int((share * 100).rounded())) percent")
    }
}

// MARK: - Time to fall asleep

struct NoopFallAsleepSection: View {
    let night: NoopRestRecord.Night

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Zero means the night starts asleep — no in-bed time was recorded, so there is nothing to time.
    private var minutes: Double? { night.bed.map(\.latencyMin).flatMap { $0 >= 1 ? $0 : nil } }

    /// Fast under 10 minutes, normal 10–20, late beyond; each takes a third of the track.
    private var position: Double {
        guard let m = minutes else { return 0.5 }
        if m < 10 { return 0.04 + m / 10 * 0.29 }
        if m <= 20 { return 0.33 + (m - 10) / 10 * 0.34 }
        return min(0.96, 0.67 + (m - 20) / 25 * 0.29)
    }

    private var zone: Int? { minutes.map { $0 < 10 ? 0 : $0 <= 20 ? 1 : 2 } }

    var body: some View {
        NoopNightCard {
            VStack(spacing: 16) {
                HStack {
                    Text("Time to fall asleep")
                        .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Spacer()
                }
                if let m = minutes {
                    NoopCountUp(value: m.rounded(), format: { v in
                        let n = Int(v.rounded()); return n == 1 ? "1 minute" : "\(n) minutes"
                    }, font: NoopHTMLFont.outfit(NoopType.title3, weight: .medium))
                    .foregroundStyle(NoopHTMLColor.ink)
                } else {
                    Text("No reading for this night")
                        .font(NoopHTMLFont.outfit(NoopType.body, weight: .medium))
                        .foregroundStyle(NoopHTMLColor.copy)
                }
                track
                HStack {
                    label("Fast", 0, .leading)
                    Spacer()
                    label("Normal", 1, .center)
                    Spacer()
                    label("Late", 2, .trailing)
                }
                Text(caption)
                    .font(NoopHTMLFont.sans(NoopType.caption))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear {
            guard !shown else { return }
            if reduceMotion { shown = true } else { withAnimation(.spring(response: 1.0, dampingFraction: 0.72).delay(0.2)) { shown = true } }
        }
    }

    private var track: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(stops: [
                        .init(color: NoopHTMLColor.nightLight.opacity(0.12), location: 0),
                        .init(color: NoopHTMLColor.nightLight.opacity(0.45), location: 0.33),
                        .init(color: Color(hex: 0xA9B4F5).opacity(0.9), location: 0.5),
                        .init(color: NoopHTMLColor.nightLight.opacity(0.45), location: 0.67),
                        .init(color: NoopHTMLColor.nightLight.opacity(0.12), location: 1)
                    ], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 8)
                if minutes != nil {
                    ZStack {
                        Circle().fill(NoopHTMLColor.nightLight.opacity(0.25)).frame(width: 30, height: 30).blur(radius: 4)
                        Circle().fill(Color(hex: 0x1D2230)).frame(width: 24, height: 24)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                        Circle().fill(.white).frame(width: 12, height: 12)
                    }
                    .offset(x: (shown ? position : 0) * w - 15)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 30)
        .accessibilityHidden(true)
    }

    private func label(_ text: String, _ index: Int, _ alignment: Alignment) -> some View {
        Text(text)
            .font(NoopHTMLFont.sans(NoopType.footnote, weight: zone == index ? .semibold : .medium))
            .foregroundStyle(zone == index ? NoopHTMLColor.ink : NoopHTMLColor.faint)
    }

    private var caption: String {
        switch zone {
        case 0: return "Asleep almost at once. Very fast, night after night, can mean you are short of sleep."
        case 1: return "Ten to twenty minutes is the healthy middle."
        case 2: return "It took a while to drift off. Screens, caffeine or a late meal can push this out."
        default: return "Needs the strap on from when you lie down."
        }
    }
}

// MARK: - Sleeping vitals

struct NoopSleepVitalsSection: View {
    let night: NoopRestRecord.Night

    enum Vital: Int, CaseIterable, Identifiable {
        case hr, hrv, resp, spo2
        var id: Int { rawValue }
        var metric: Repository.TimelineMetric { [.hr, .hrv, .respiration, .spo2][rawValue] }
        var short: String { ["HR", "HRV", "RR", "SpO₂"][rawValue] }
        var title: String { ["Sleeping heart rate", "Sleeping HRV", "Sleeping breathing", "Sleeping oxygen"][rawValue] }
        var unit: String { ["bpm", "ms", "br/min", "%"][rawValue] }
        var average: String { ["Average heart rate", "Average HRV", "Average breathing rate", "Average SpO₂"][rawValue] }
        var glyph: String { ["heart.fill", "waveform.path.ecg", "lungs.fill", "drop.fill"][rawValue] }
        var tint: Color { [Color(hex: 0xF06A9B), Color(hex: 0x4FC3B0), Color(hex: 0xA98BF0), Color(hex: 0x4FA3E8)][rawValue] }
        var floor: Double { [25, 3, 4, 70][rawValue] }
    }

    @EnvironmentObject private var model: AppModel
    @State private var vital: Vital = .hr
    @State private var series: [Vital: [(time: Date, value: Double)]] = [:]
    @State private var loaded = false
    @Namespace private var pill

    private var points: [(time: Date, value: Double)] { series[vital] ?? [] }

    /// A moving average over the readings, for the line through the dots.
    private var trend: [(time: Date, value: Double)] {
        let p = points
        guard p.count > 4 else { return p }
        let half = max(2, p.count / 40)
        return p.indices.map { i in
            let lo = max(0, i - half), hi = min(p.count - 1, i + half)
            let slice = p[lo...hi]
            return (p[i].time, slice.reduce(0) { $0 + $1.value } / Double(slice.count))
        }
    }

    var body: some View {
        NoopNightCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(vital.title)
                    .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.ink)
                    .contentTransition(.opacity)
                if loaded && points.isEmpty {
                    empty
                } else {
                    headline
                    chart
                }
                if let span = night.span {
                    HStack {
                        edge("moon.fill", noopClock(span.lowerBound))
                        Spacer()
                        edge("sun.max.fill", noopClock(night.bed?.finalWake ?? span.upperBound))
                    }
                }
                tabs
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: vital)
        .task(id: night.dayKey) { await load() }
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(NoopHTMLColor.faint)
            Text("No strap readings for this night")
                .font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium))
                .foregroundStyle(NoopHTMLColor.copy)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var headline: some View {
        let values = points.map(\.value)
        let avg = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let avg {
                    NoopCountUp(value: avg, format: { String(format: "%.1f", $0) },
                                font: NoopHTMLFont.outfit(NoopType.title1, weight: .medium))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(vital.unit)
                        .font(NoopHTMLFont.outfit(NoopType.title3, weight: .medium))
                        .foregroundStyle(NoopHTMLColor.faint)
                } else {
                    Text(loaded ? "No readings" : " ")
                        .font(NoopHTMLFont.outfit(NoopType.title3, weight: .medium))
                        .foregroundStyle(NoopHTMLColor.copy)
                }
            }
            Text(vital.average.uppercased())
                .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(NoopHTMLColor.faint)
        }
    }

    private var chart: some View {
        let values = points.map(\.value)
        let lo = values.min() ?? 0, hi = values.max() ?? 1
        let pad = max(1, (hi - lo) * 0.12)
        let tint = vital.tint
        return Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                PointMark(x: .value("Time", p.time), y: .value(vital.short, p.value))
                    .symbolSize(14)
                    .foregroundStyle(tint.opacity(0.6))
            }
            ForEach(Array(trend.enumerated()), id: \.offset) { _, p in
                LineMark(x: .value("Time", p.time), y: .value("Trend", p.value), series: .value("s", "trend"))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(Color(hex: 0xB49BFF))
            }
        }
        .chartYScale(domain: (lo - pad)...(hi + pad))
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4])).foregroundStyle(Color.white.opacity(0.12))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.0f", v)).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint)
                    }
                }
            }
        }
        .noopChart(x: Date.self, snap: points.map(\.time)) { time in
            guard let p = points.first(where: { $0.time == time }) else { return nil }
            return NoopChartReadout(value: String(format: "%.1f %@", p.value, vital.unit), detail: noopClock(p.time),
                                    y: p.value, tint: tint)
        }
        .padding(.top, 36)
        .frame(height: 236)
        .id(vital)
        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .bottom)))
        .opacity(points.isEmpty ? 0.3 : 1)
    }

    private func edge(_ glyph: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: glyph).font(.system(size: 11, weight: .semibold))
            Text(text).monospacedDigit()
        }
        .font(NoopHTMLFont.sans(NoopType.caption, weight: .medium))
        .foregroundStyle(NoopHTMLColor.inkSoft)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var tabs: some View {
        HStack(spacing: 8) {
            ForEach(Vital.allCases) { v in
                let on = v == vital
                let empty = loaded && (series[v]?.isEmpty ?? true)
                Button {
                    guard !on else { return }
                    NoopHaptics.play(.tick)
                    vital = v
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: v.glyph)
                            .font(.system(size: 17, weight: .semibold))
                            .symbolEffect(.bounce, value: on)
                        Text(v.short)
                            .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                    }
                    .foregroundStyle(on ? NoopHTMLColor.ink : v.tint.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background {
                        if on {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(v.tint.opacity(0.14))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(v.tint, lineWidth: 1.5))
                                .matchedGeometryEffect(id: "pill", in: pill)
                        } else {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(v.tint.opacity(0.28), lineWidth: 1)
                        }
                    }
                    .opacity(empty ? 0.4 : 1)
                }
                .buttonStyle(NoopHTMLPressStyle())
                .disabled(empty)
                .accessibilityLabel(v.title)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    private func load() async {
        guard let span = night.span else { return }
        let from = Int(span.lowerBound.timeIntervalSince1970), to = Int(span.upperBound.timeIntervalSince1970)
        var out: [Vital: [(time: Date, value: Double)]] = [:]
        for v in Vital.allCases {
            let s = await model.repo.timelineSeries(metric: v.metric, from: from, to: to, targetPoints: 260)
            out[v] = s.points.filter { $0.value.isFinite && $0.value >= v.floor }.map { (time: $0.date, value: $0.value) }
        }
        series = out
        loaded = true
        if out[vital]?.isEmpty ?? true, let first = Vital.allCases.first(where: { !(out[$0]?.isEmpty ?? true) }) { vital = first }
    }
}

// MARK: - Sleep needed

struct NoopSleepNeededSection: View {
    let night: NoopRestRecord.Night
    let rest: NoopRestRecord
    let isLatest: Bool

    @State private var showing = false

    /// The need the night was measured against: your baseline, plus the day before's effort and the
    /// debt you carried into it (`SleepNeed`, the same recipe tonight's need uses).
    private var need: SleepNeed.Tonight {
        let effort = rest.strainByDay.filter { $0.key < night.dayKey }.max { $0.key < $1.key }?.value
        let debt = rest.debt.last { $0.day < night.dayKey }?.minutes ?? 0
        return SleepNeed.tonight(baseMinutes: rest.needMin, strain: effort, ledgerDebtBalanceMin: -debt)
    }

    var body: some View {
        Button {
            NoopHaptics.play(.tick)
            showing = true
        } label: {
            HStack(spacing: 10) {
                Text(isLatest ? "Last night's sleep needed" : "Sleep needed · \(night.shortDate)")
                    .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.ink)
                Spacer(minLength: 8)
                Text(NoopRestRecord.duration(need.totalMin))
                    .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.ink)
                    .monospacedDigit()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.faint)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 60)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(rest.needMin <= 0)
        .sheet(isPresented: $showing) {
            NoopSleepNeededSheet(need: need, asleepMin: night.asleepMin).noopSheet([.medium, .large])
        }
    }
}

private struct NoopSleepNeededSheet: View {
    let need: SleepNeed.Tonight
    let asleepMin: Double

    @Environment(\.dismiss) private var dismiss
    @State private var shown = false

    private var rows: [(String, Double, String)] {
        var r: [(String, Double, String)] = [
            ("Your sleep need", need.baseMin, "What you need on an ordinary day, learned from your own nights."),
            ("Effort the day before", need.strainAddOnMin, "A harder day asks for more sleep to recover. Quiet days add nothing."),
            ("Sleep debt", need.repaymentMin, "Part of what you still owe from recent short nights, up to two hours.")
        ]
        if need.napCreditMin > 0 { r.append(("Naps", -need.napCreditMin, "Sleep already banked in the day.")) }
        return r
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("How sleep needed is worked out")
                        .font(NoopHTMLFont.outfit(NoopType.title3, weight: .medium))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .bold))
                            .foregroundStyle(NoopHTMLColor.inkSoft)
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .accessibilityLabel("Close")
                }

                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                        HStack {
                            Text(row.0).foregroundStyle(NoopHTMLColor.copy)
                            Spacer()
                            Text(signed(row.1, first: i == 0)).foregroundStyle(NoopHTMLColor.ink).monospacedDigit()
                        }
                        .font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium))
                        .padding(.vertical, 11)
                        .opacity(shown ? 1 : 0)
                        .offset(y: shown ? 0 : 8)
                        .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.05 + Double(i) * 0.07), value: shown)
                    }
                    Rectangle().fill(NoopHTMLColor.border).frame(height: 1).padding(.vertical, 6)
                    HStack {
                        Text("Sleep needed")
                        Spacer()
                        NoopCountUp(value: need.totalMin, format: { NoopRestRecord.duration($0) },
                                    font: NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                    }
                    .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.ink)
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))

                Text(verdict)
                    .font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium))
                    .foregroundStyle(NoopHTMLColor.inkSoft)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        (Text(row.0 + ": ").foregroundStyle(NoopHTMLColor.ink).fontWeight(.semibold)
                            + Text(row.2).foregroundStyle(NoopHTMLColor.copy))
                            .font(NoopHTMLFont.sans(NoopType.caption))
                    }
                }
            }
            .padding(20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(NoopHTMLColor.canvas.ignoresSafeArea())
        .onAppear { shown = true }
    }

    private var verdict: String {
        let d = (asleepMin - need.totalMin).rounded()
        if d >= 0 { return "You slept \(NoopRestRecord.duration(asleepMin)), enough to cover it." }
        return "You slept \(NoopRestRecord.duration(asleepMin)), \(NoopRestRecord.duration(-d)) short of it."
    }

    private func signed(_ minutes: Double, first: Bool) -> String {
        let text = NoopRestRecord.duration(abs(minutes))
        if first { return text }
        return minutes < 0 ? "− \(text)" : "+ \(text)"
    }
}
