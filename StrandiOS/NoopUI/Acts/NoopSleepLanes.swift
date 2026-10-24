import StrandDesign
import SwiftUI

// MARK: - Sleep lanes
//
// The night as one lane per stage, each run of a stage drawn at its true length, under the night's
// heart rate. The pulse line takes the colour of the stage the night was in at that moment, so a
// drop into deep sleep reads in the line itself. Tapping a lane picks that stage out of both.

struct NoopSleepLanes: View {
    let runs: [NoopRestRecord.StageRun]
    let span: ClosedRange<Date>
    let minutes: NoopRestRecord.StageMinutes
    /// The night's heart rate, oldest first; empty while loading or when none was recorded.
    let heart: [(time: Date, bpm: Double)]
    @Binding var selected: Int?

    private static let names = ["Awake", "Light", "REM", "Deep"]
    /// Top to bottom: awake, REM, light, deep.
    private static let order = [0, 2, 1, 3]

    var body: some View {
        VStack(spacing: NoopSpace.xs) {
            if heart.count >= 2 { NoopSleepPulse(runs: runs, span: span, heart: heart, selected: selected) }
            ForEach(Self.order, id: \.self) { stage in lane(stage) }
        }
    }

    private func lane(_ stage: Int) -> some View {
        let color = NoopTodayNightCard.stageColors[stage]
        let total = max(1, minutes.asleep + minutes.awake)
        let value = [minutes.awake, minutes.light, minutes.rem, minutes.deep][stage]
        let on = selected == nil || selected == stage
        return Button {
            withAnimation(.easeOut(duration: 0.18)) { selected = selected == stage ? nil : stage }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Self.names[stage].uppercased())
                        .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text("\(Int((value / total * 100).rounded()))%")
                        .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(stage == 0 ? NoopHTMLColor.inkSoft : color)
                    Spacer()
                    Text(NoopRestRecord.duration(value))
                        .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(NoopHTMLColor.ink)
                }
                NoopSleepLaneTrack(runs: runs.filter { $0.stage == stage },
                                   color: stage == 0 ? Color.white.opacity(0.75) : color)
                    .frame(height: 20)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(selected == stage ? 0.07 : 0.035), in: RoundedRectangle(cornerRadius: 14))
            .opacity(on ? 1 : 0.4)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoopPlainHitStyle())
        .accessibilityLabel("\(Self.names[stage]), \(NoopRestRecord.duration(value))")
        .accessibilityAddTraits(selected == stage ? .isSelected : [])
    }
}

/// One stage's runs on a faintly hatched track.
private struct NoopSleepLaneTrack: View {
    let runs: [NoopRestRecord.StageRun]
    let color: Color

    var body: some View {
        Canvas { context, size in
            let track = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 6)
            context.fill(track, with: .color(.white.opacity(0.03)))
            var hatch = context
            hatch.clip(to: track)
            var lines = Path()
            var x = -size.height
            while x < size.width {
                lines.move(to: CGPoint(x: x, y: size.height))
                lines.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += 5
            }
            hatch.stroke(lines, with: .color(.white.opacity(0.05)), lineWidth: 1)
            for run in runs {
                let x0 = CGFloat(run.from) * size.width, w = max(2, CGFloat(run.to - run.from) * size.width)
                let rect = CGRect(x: x0, y: 0, width: w, height: size.height)
                context.fill(Path(roundedRect: rect, cornerRadius: min(3, w / 2)), with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }
}

/// The night's heart rate, each stretch coloured by the stage the night was in, with its low marked.
private struct NoopSleepPulse: View {
    let runs: [NoopRestRecord.StageRun]
    let span: ClosedRange<Date>
    let heart: [(time: Date, bpm: Double)]
    let selected: Int?

    private var low: (time: Date, bpm: Double)? { heart.min { $0.bpm < $1.bpm } }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("HEART RATE")
                    .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(NoopHTMLColor.muted)
                Spacer()
                if let low {
                    Text("Low \(Int(low.bpm.rounded())) bpm at \(AppClock.hourMinuteFormatter().string(from: low.time))")
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .monospacedDigit()
                        .foregroundStyle(NoopHTMLColor.copy)
                }
            }
            chart.frame(height: 92)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
    }

    private var chart: some View {
        Canvas { context, size in
            let values = heart.map(\.bpm)
            let lo = ((values.min() ?? 50) - 2).rounded(.down), hi = ((values.max() ?? 80) + 2).rounded(.up)
            let length = span.upperBound.timeIntervalSince(span.lowerBound)
            func x(_ t: Date) -> CGFloat { CGFloat(t.timeIntervalSince(span.lowerBound) / length) * size.width }
            func y(_ v: Double) -> CGFloat { size.height * CGFloat(1 - (v - lo) / max(1, hi - lo)) }
            // Quiet guides on round beats, labelled at the right end so the line keeps the lanes' width.
            let step: Double = hi - lo > 30 ? 10 : 5
            var v = (lo / step).rounded(.up) * step
            while v < hi {
                var g = Path()
                g.move(to: CGPoint(x: 0, y: y(v))); g.addLine(to: CGPoint(x: size.width, y: y(v)))
                context.stroke(g, with: .color(.white.opacity(0.06)), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                context.draw(Text("\(Int(v))").font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint),
                             at: CGPoint(x: size.width, y: y(v) - 2), anchor: .bottomTrailing)
                v += step
            }
            // The line, segment by segment in its stage's colour.
            func stage(at t: Date) -> Int {
                let f = t.timeIntervalSince(span.lowerBound) / length
                return runs.first { f >= $0.from && f < $0.to }?.stage ?? 0
            }
            func color(_ s: Int) -> Color {
                let base = s == 0 ? Color.white.opacity(0.7) : NoopTodayNightCard.stageColors[s]
                return selected == nil || selected == s ? base : Color.white.opacity(0.12)
            }
            var i = 0
            while i < heart.count - 1 {
                let s = stage(at: heart[i].time)
                var path = Path()
                path.move(to: CGPoint(x: x(heart[i].time), y: y(heart[i].bpm)))
                var j = i + 1
                while j < heart.count {
                    // A gap of more than five minutes is a gap, not a line.
                    if heart[j].time.timeIntervalSince(heart[j - 1].time) > 300 { break }
                    path.addLine(to: CGPoint(x: x(heart[j].time), y: y(heart[j].bpm)))
                    if stage(at: heart[j].time) != s { break }
                    j += 1
                }
                context.stroke(path, with: .color(color(s)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                i = j
            }
            if let low, selected == nil {
                let p = CGPoint(x: x(low.time), y: y(low.bpm))
                context.fill(Path(ellipseIn: CGRect(x: p.x - 3.5, y: p.y - 3.5, width: 7, height: 7)), with: .color(.white))
            }
        }
        .accessibilityLabel(low.map { "Heart rate through the night, lowest \(Int($0.bpm.rounded())) beats per minute" } ?? "Heart rate through the night")
    }
}
