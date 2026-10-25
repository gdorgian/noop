#if os(iOS)
import SwiftUI
import Charts

/// The running cardio session in the Fitness style: the clock and sport, live heart rate inside its
/// zone ring, where it sits across the five zones, the last minutes of pulse, and the figures so far.
/// Fed plain values so the recorder and the design fixture draw through the same view.
struct NoopFitnessCardioLive: View {
    struct Figure: Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

    let sport: String
    let symbol: String
    let elapsed: Int
    let bpm: Int?
    let paused: Bool
    /// 1…5, or 0 when unknown.
    let zone: Int
    let zoneNames: [String]
    let zoneRanges: [(Int, Int)]
    let target: Int?
    /// Recent pulse, oldest first, at most a few minutes.
    let recent: [Int]
    let figures: [Figure]
    let footnote: String?
    /// Under a minute: finishing now saves nothing, and the prompt says so.
    var tooShort = false
    /// The session's goal: how far along (0…1), in words ("12:40 of 30:00"), and whether it is reached.
    /// With a goal, the ring around the pulse fills toward it instead of following the heart rate.
    var goalFraction: Double? = nil
    var goalLabel: String? = nil
    var goalReached = false
    /// Opens the goal and zone sheet. Nil where no goal can be set (the design fixture).
    var goalAction: (() -> Void)? = nil
    let pauseAction: () -> Void
    let endAction: () -> Void

    @State private var confirmEnd = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var zoneLabel: String {
        let name = zoneNames[safe: zone - 1] ?? ""
        return name.isEmpty || name.lowercased().hasPrefix("zone") ? "Zone \(zone)" : "\(name) · zone \(zone)"
    }

    private var tint: Color { zone > 0 ? NoopFitnessZonesCard.colors[zone - 1] : NoopHTMLColor.blueLight }

    var body: some View {
        VStack(spacing: 0) {
            header
            if goalAction != nil || goalLabel != nil { goalChip.padding(.top, 14) }
            Spacer(minLength: 10)
            pulse
            Spacer(minLength: 10)
            zoneBar.padding(.bottom, 14)
            if recent.count > 3 { sparkline.frame(height: 54).padding(.bottom, 14) }
            figureGrid
            controls.padding(.top, 18)
            if let footnote {
                Text(footnote).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint).padding(.top, 8)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 58)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RadialGradient(colors: [tint.opacity(paused ? 0.05 : 0.2), .clear], center: .init(x: 0.5, y: 0.34),
                           startRadius: 10, endRadius: 330)
                .animation(.easeInOut(duration: 0.8), value: zone)
        )
        .background(NoopHTMLColor.canvas.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: goalReached) { _, reached in reached }
        .alert(tooShort ? "End without saving?" : "Finish \(sport.lowercased())?", isPresented: $confirmEnd) {
            Button("Keep going", role: .cancel) { }
            if tooShort {
                Button("Discard", role: .destructive, action: endAction)
            } else {
                Button("Finish", action: endAction)
            }
        } message: {
            Text(tooShort
                 ? "Under a minute is not kept. Keep going to save it."
                 : "It is saved with its heart rate, Effort and route. Then rate how hard it was.")
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.clock(elapsed)).font(NoopHTMLFont.outfit(NoopType.title1, weight: .light)).monospacedDigit()
                    .foregroundStyle(paused ? NoopHTMLColor.copy : NoopHTMLColor.ink)
                HStack(spacing: 6) {
                    Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                    Text(paused ? "Paused" : sport).font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).lineLimit(1)
                }
                .foregroundStyle(paused ? NoopHTMLColor.copy : NoopHTMLColor.blueLight)
            }
            Spacer()
            if let target, zoneRanges.indices.contains(target - 1) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TARGET").font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).tracking(1.1).foregroundStyle(NoopHTMLColor.muted)
                    Text("\(zoneNames[safe: target - 1] ?? "Zone \(target)") · \(zoneRanges[target - 1].0)–\(zoneRanges[target - 1].1)")
                        .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(NoopFitnessZonesCard.colors[target - 1])
                }
            }
        }
    }

    /// "Set a goal", or the goal and how far along it is; a tap opens the goal sheet.
    private var goalChip: some View {
        Button { goalAction?() } label: {
            HStack(spacing: 7) {
                Image(systemName: goalReached ? "checkmark.circle.fill" : goalLabel == nil ? "flag" : "flag.checkered")
                    .font(.system(size: 12, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                Text(goalReached ? "Goal reached" : goalLabel ?? "Set a goal")
                    .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).monospacedDigit()
                    .contentTransition(.numericText())
            }
            .foregroundStyle(goalReached ? NoopHTMLColor.green : goalLabel == nil ? NoopHTMLColor.inkSoft : NoopHTMLColor.blueLight)
            .padding(.horizontal, 12).frame(height: 32)
            .background((goalReached ? NoopHTMLColor.green : NoopHTMLColor.blueLight).opacity(goalLabel == nil ? 0.0 : 0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(goalLabel == nil ? 0.12 : 0), lineWidth: 0.6))
            .noopHitTarget()
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(goalAction == nil)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(NoopMotion.swap, value: goalReached)
    }

    private var ringFraction: Double {
        if let goalFraction { return goalReached ? 1 : max(0.004, goalFraction) }
        return bpm.map { min(1, max(0.04, Double($0 - 40) / 160)) } ?? 0
    }

    private var ringTint: Color {
        if goalReached { return NoopHTMLColor.green }
        return goalFraction != nil ? NoopHTMLColor.blueLight : tint
    }

    private var pulse: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.06), lineWidth: 12)
            Circle()
                .trim(from: 0, to: ringFraction)
                .stroke(AngularGradient(colors: [ringTint.opacity(0.5), ringTint], center: .center),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: goalReached ? NoopHTMLColor.green.opacity(0.45) : .clear, radius: 14)
                .animation(.easeOut(duration: 0.6), value: ringFraction)
                .animation(.easeInOut(duration: 0.5), value: goalReached)
            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(bpm.map(String.init) ?? "—")
                        .font(NoopHTMLFont.outfit200(88)).monospacedDigit()
                        .foregroundStyle(NoopHTMLColor.ink)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.3), value: bpm)
                    Image(systemName: "heart.fill").font(.system(size: 17)).foregroundStyle(NoopHTMLColor.red)
                        .scaleEffect(paused || reduceMotion || bpm == nil ? 1 : 1.12)
                        .animation(paused || reduceMotion || bpm == nil ? .default
                                   : .easeInOut(duration: 60 / Double(max(bpm ?? 60, 40)) / 2).repeatForever(autoreverses: true),
                                   value: bpm == nil)
                }
                Text(bpm == nil ? "Waiting for heart rate" : zone > 0 ? zoneLabel : "bpm")
                    .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(bpm == nil ? NoopHTMLColor.copy : tint)
            }
        }
        .frame(width: 250, height: 250)
        .accessibilityElement()
        .accessibilityLabel(bpm.map { "\($0) beats per minute, zone \(zone)" } ?? "Waiting for heart rate")
    }

    private var zoneBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { z in
                    let on = z == zone
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(NoopFitnessZonesCard.colors[z - 1].opacity(on ? 1 : 0.28))
                        .frame(height: on ? 12 : 7)
                        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(target == z ? NoopHTMLColor.ink.opacity(0.8) : .clear, lineWidth: 1))
                        .animation(.spring(duration: 0.4), value: zone)
                }
            }
            .frame(height: 12)
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { z in
                    Text(zoneRanges[safe: z - 1].map { "\($0.0)" } ?? "")
                        .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .medium)).foregroundStyle(NoopHTMLColor.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var sparkline: some View {
        Chart(Array(recent.enumerated()), id: \.offset) { i, v in
            AreaMark(x: .value("t", i), yStart: .value("low", (recent.min() ?? 0) - 4), yEnd: .value("bpm", v))
                .foregroundStyle(LinearGradient(colors: [tint.opacity(0.3), tint.opacity(0)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.monotone)
            LineMark(x: .value("t", i), y: .value("bpm", v))
                .foregroundStyle(tint).lineStyle(StrokeStyle(lineWidth: 1.8)).interpolationMethod(.monotone)
        }
        .chartXAxis(.hidden).chartYAxis(.hidden)
        .chartYScale(domain: Double((recent.min() ?? 60) - 4)...Double((recent.max() ?? 120) + 4))
    }

    private var figureGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(figures) { f in
                VStack(spacing: 3) {
                    Text(f.value).font(NoopHTMLFont.outfit(NoopType.title3)).monospacedDigit().foregroundStyle(NoopHTMLColor.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(f.label).font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .medium)).foregroundStyle(NoopHTMLColor.copy)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button(action: pauseAction) {
                HStack(spacing: 8) {
                    Image(systemName: paused ? "play.fill" : "pause.fill").font(.system(size: 15, weight: .semibold))
                    Text(paused ? "Resume" : "Pause").font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                }
                .foregroundStyle(NoopHTMLColor.ink)
                .frame(maxWidth: .infinity).frame(minHeight: 56)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(NoopHTMLPressStyle())
            Button { confirmEnd = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill").font(.system(size: 14, weight: .semibold))
                    Text("Finish").font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                }
                .foregroundStyle(NoopHTMLColor.blueInk)
                .frame(maxWidth: .infinity).frame(minHeight: 56)
                .background(NoopHTMLColor.blueLight, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(NoopHTMLPressStyle())
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: paused)
    }

    static func clock(_ s: Int) -> String {
        s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }

    static func symbol(for sport: String) -> String {
        if let exact = NoopSportGroups.exactSymbol(sport) { return exact }
        let s = sport.lowercased()
        if s.contains("treadmill") { return "figure.run.treadmill" }
        if s.contains("run") { return "figure.run" }
        if s.contains("walk") { return "figure.walk" }
        if s.contains("hik") { return "figure.hiking" }
        if s.contains("indoor cycle") { return "figure.indoor.cycle" }
        if s.contains("cycl") || s.contains("ride") { return "figure.outdoor.cycle" }
        if s.contains("open-water") { return "figure.open.water.swim" }
        if s.contains("swim") { return "figure.pool.swim" }
        if s.contains("row") { return "figure.rower" }
        if s.contains("hiit") || s.contains("interval") { return "figure.highintensity.intervaltraining" }
        if s.contains("yoga") { return "figure.yoga" }
        if s.contains("ellip") { return "figure.elliptical" }
        if s.contains("core") { return "figure.core.training" }
        if s.contains("strength") || s.contains("weight") || s.contains("lift") || s.contains("gym") {
            return "figure.strengthtraining.traditional"
        }
        if s.contains("functional") || s.contains("crossfit") { return "figure.strengthtraining.functional" }
        if s.contains("pilates") { return "figure.pilates" }
        if s.contains("danc") { return "figure.dance" }
        if s.contains("box") || s.contains("kickbox") { return "figure.boxing" }
        if s.contains("martial") { return "figure.martial.arts" }
        if s.contains("climb") { return "figure.climbing" }
        if s.contains("tennis") || s.contains("padel") { return "figure.tennis" }
        if s.contains("basketball") { return "figure.basketball" }
        if s.contains("soccer") || s.contains("football") { return "figure.soccer" }
        if s.contains("stretch") || s.contains("mobility") { return "figure.flexibility" }
        if s.contains("stair") { return "figure.stair.stepper" }
        if s.contains("ski") { return "figure.skiing.downhill" }
        if s.contains("surf") { return "figure.surfing" }
        return "figure.mixed.cardio"
    }
}
#endif
