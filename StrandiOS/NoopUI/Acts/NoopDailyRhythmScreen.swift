#if os(iOS)
import SwiftUI
import StrandAnalytics

/// Daily rhythm: the shape of the wearer's last week of days, read from the strap's own motion
/// (`DailyRhythm`). A 24-hour dial of when they move, their peak, how strong and how regular the rhythm is,
/// and how broken up the days are. No age: the page says why.
struct NoopDailyRhythmScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var outcome: DailyRhythm.Outcome?
    @State private var noMotion = false
    @State private var drawn = false

    private static let lookbackDays = 8

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NoopSpace.l) {
                NoopSheetHeader(title: "Daily rhythm") { dismiss() }
                VStack(alignment: .leading, spacing: 6) {
                    Text("When you move across the day, read from your strap over the last week.")
                        .font(NoopHTMLFont.sans(NoopType.footnote))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content
                Text("There is no rhythm age here. The published method turns movement into years on a scale your strap does not record in, and Noop will not guess the conversion. It will show one when it can measure that scale on you.")
                    .font(NoopHTMLFont.sans(NoopType.eyebrow))
                    .foregroundStyle(NoopHTMLColor.faint)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, NoopSpace.l)
            .padding(.bottom, NoopSpace.xxl)
        }
        .background(NoopHTMLColor.canvas.ignoresSafeArea())
        .environment(\.noopAccent, NoopAccent.of(NoopHTMLColor.blush))
        .task { await load() }
    }

    // MARK: - States

    @ViewBuilder private var content: some View {
        if noMotion {
            notice("No movement recorded yet", "WHOOP 5.0 and MG straps record how much you move every second, and the dial is drawn from that. With one on, it fills in over a week. A 4.0 records only which way it points, which cannot show a rhythm reliably.", symbol: "applewatch")
        } else {
            switch outcome {
            case nil:
                ProgressView().tint(NoopHTMLColor.blush).frame(maxWidth: .infinity, minHeight: 280)
            case .gathering(let days):
                VStack(spacing: NoopSpace.m) {
                    NoopDailyRhythmDial(profile: Array(repeating: 0.06, count: 24), peakMinute: nil, quietStart: nil, drawn: drawn)
                        .frame(height: 280)
                    notice("\(days) of \(DailyRhythm.minimumDays) days so far",
                           "A day counts once the strap has been worn for sixteen hours of it, night included. Keep it on and the dial fills in.",
                           symbol: "hourglass", progress: Double(days) / Double(DailyRhythm.minimumDays))
                }
            case .blindSpot(let hours):
                notice("The same \(hours) hours are missing every day",
                       "The strap seems to come off at the same time each day, often to charge. Charging at a different time on a couple of days lets Noop see the whole clock.",
                       symbol: "clock.badge.exclamationmark")
            case .flat:
                notice("No clear rhythm this week", "Movement was about the same at every hour, so there is no peak to show. A normal week of days and nights brings it back.", symbol: "waveform.path")
            case .reading(let r):
                reading(r)
            }
        }
    }

    private func reading(_ r: DailyRhythm.Reading) -> some View {
        VStack(alignment: .leading, spacing: NoopSpace.m) {
            NoopDailyRhythmDial(profile: r.profile, peakMinute: r.peakMinute, quietStart: r.quietStartHour, drawn: drawn)
                .frame(height: 300)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Your day peaks at \(Self.clock(minute: r.peakMinute)); quietest from \(Self.clock(minute: r.quietStartHour * 60))")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: NoopSpace.xs + 1), GridItem(.flexible())], spacing: NoopSpace.xs + 1) {
                tile(Self.clock(minute: r.peakMinute), "Peak", "when your day is at its busiest")
                tile(Self.clock(minute: r.quietStartHour * 60), "Quiet from", "the stillest five hours begin")
                tile(Self.strength(r.relativeAmplitude), "Day and night", "how far apart they are")
                tile(Self.regularity(r.stability), "Day to day", "how alike your days are")
            }
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Broken up").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                    Text(Self.fragmentationLine(r.fragmentation))
                        .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text(String(format: "%.2f", r.fragmentation))
                    .font(NoopHTMLFont.outfit(NoopType.title3, weight: .light))
                    .foregroundStyle(NoopHTMLColor.inkSoft)
                    .monospacedDigit()
            }
            .padding(NoopSpace.m)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
            Text("From \(r.days) full days of wear.")
                .font(NoopHTMLFont.sans(NoopType.eyebrow))
                .foregroundStyle(NoopHTMLColor.faint)
        }
    }

    private func tile(_ value: String, _ title: String, _ line: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(NoopHTMLFont.outfit(NoopType.title3, weight: .light))
                .foregroundStyle(NoopHTMLColor.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(title).font(NoopHTMLFont.sans(NoopType.caption, weight: .medium)).foregroundStyle(NoopHTMLColor.inkSoft)
            Text(line).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(NoopSpace.m)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private func notice(_ title: String, _ line: String, symbol: String, progress: Double? = nil) -> some View {
        VStack(alignment: .leading, spacing: NoopSpace.s) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(NoopHTMLColor.blush)
            Text(title).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
            Text(line).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            if let progress { NoopProgressBar(progress: progress, color: NoopHTMLColor.blush, height: 4) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(NoopSpace.m)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    // MARK: - Data

    private func load() async {
        #if DEBUG
        if CommandLine.arguments.contains("--noop-rhythm-sample") {
            outcome = DailyRhythm.read(Self.sampleDays())
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.1)) { drawn = true }
            return
        }
        #endif
        let now = Date()
        let from = Int(Calendar.current.startOfDay(for: now).timeIntervalSince1970) - Self.lookbackDays * 86_400
        let utcMinutes = await model.repo.motionMinuteMeans(from: from, to: Int(now.timeIntervalSince1970))
        guard !utcMinutes.isEmpty else {
            noMotion = true
            outcome = .gathering(days: 0)
            withAnimation(.easeOut(duration: 0.6)) { drawn = true }
            return
        }
        let zone = TimeZone.current
        let local = utcMinutes.map { m -> (localMinute: Int, value: Double) in
            let offset = zone.secondsFromGMT(for: Date(timeIntervalSince1970: TimeInterval(m.minute * 60))) / 60
            return (m.minute + offset, m.mean)
        }
        let days = DailyRhythm.days(minuteMeans: local) { "\($0)" }
        outcome = DailyRhythm.read(days)
        withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.1)) { drawn = true }
    }

    #if DEBUG
    /// Seven worn days peaking mid-afternoon with a little noise, for the screen without a strap.
    static func sampleDays() -> [DailyRhythm.Day] {
        (0..<7).map { i in
            DailyRhythm.Day(key: "s\(i)", minutes: (0..<1440).map { m -> Double? in
                let w = 2 * Double.pi * Double(m - (15 * 60 + 20)) / 1440
                let base = 0.04 + 0.032 * cos(w) + 0.008 * cos(2 * w)
                return max(0.002, base + Double((m * 7919 + i * 104729) % 97) / 97 * 0.012 - 0.006)
            })
        }
    }
    #endif

    // MARK: - Words

    static func clock(minute: Int) -> String {
        let m = ((minute % 1440) + 1440) % 1440
        var c = DateComponents(); c.hour = m / 60; c.minute = m % 60
        let date = Calendar.current.date(from: c) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    static func strength(_ ra: Double) -> String { ra >= 0.75 ? "Wide apart" : ra >= 0.45 ? "Clear" : "Close" }
    static func regularity(_ s: Double) -> String { s >= 0.65 ? "Regular" : s >= 0.4 ? "Fairly regular" : "Varied" }
    static func fragmentationLine(_ v: Double) -> String {
        v < 0.6 ? "Smooth: long stretches of rest and of activity."
            : v < 1.0 ? "Some breaks: the day switches between moving and still now and then."
            : "Often broken: short bursts of movement and stillness through the day."
    }
}

/// The 24-hour dial: a bar per hour outward from a ring, longer for more movement, warm by day and night-blue
/// by night; the fitted peak as a bright mark, the quiet five hours as a soft arc. Midnight at the top.
private struct NoopDailyRhythmDial: View {
    let profile: [Double]
    let peakMinute: Int?
    let quietStart: Int?
    let drawn: Bool

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let inner = side * 0.25, outer = side * 0.42
            ZStack {
                Circle().stroke(Color.white.opacity(0.06), lineWidth: 1).frame(width: inner * 2, height: inner * 2).position(c)
                if let quietStart {
                    Circle()
                        .trim(from: CGFloat(quietStart) / 24, to: CGFloat(quietStart + 5) / 24)
                        .stroke(NoopHTMLColor.night.opacity(0.35), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: (inner - 12) * 2, height: (inner - 12) * 2)
                        .position(c)
                        .opacity(drawn ? 1 : 0)
                        .animation(.easeOut(duration: 0.6).delay(0.5), value: drawn)
                }
                ForEach(0..<24, id: \.self) { h in
                    let length = (outer - inner) * CGFloat(max(profile[h], 0.04))
                    Capsule()
                        .fill(Self.color(hour: h).opacity(0.35 + 0.65 * profile[h]))
                        .frame(width: max(side * 0.034, 5), height: drawn ? length : 2)
                        .offset(y: -(inner + 6 + (drawn ? length : 2) / 2))
                        .rotationEffect(.degrees(Double(h) / 24 * 360 + 7.5))
                        .position(c)
                        .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(Double(h) * 0.025), value: drawn)
                }
                ForEach([0, 6, 12, 18], id: \.self) { h in
                    Text(String(format: "%02d", h))
                        .font(NoopHTMLFont.sans(NoopType.eyebrow))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .position(Self.point(c, radius: outer + 20, hour: Double(h)))
                }
                if let peakMinute {
                    let p = Self.point(c, radius: inner - 8, hour: Double(peakMinute) / 60)
                    Circle()
                        .fill(NoopHTMLColor.warm)
                        .frame(width: 10, height: 10)
                        .shadow(color: NoopHTMLColor.warm.opacity(0.8), radius: 6)
                        .position(p)
                        .scaleEffect(drawn ? 1 : 0.1, anchor: .center)
                        .opacity(drawn ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.75), value: drawn)
                    VStack(spacing: 2) {
                        Text(NoopDailyRhythmClock.label(peakMinute))
                            .font(NoopHTMLFont.outfit(NoopType.title3, weight: .light))
                            .foregroundStyle(NoopHTMLColor.ink)
                            .monospacedDigit()
                        Text("your peak")
                            .font(NoopHTMLFont.sans(NoopType.eyebrow))
                            .foregroundStyle(NoopHTMLColor.faint)
                    }
                    .position(c)
                    .opacity(drawn ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.6), value: drawn)
                }
            }
        }
    }

    static func point(_ c: CGPoint, radius: CGFloat, hour: Double) -> CGPoint {
        let a = (hour / 24) * 2 * Double.pi - Double.pi / 2
        return CGPoint(x: c.x + radius * CGFloat(cos(a)), y: c.y + radius * CGFloat(sin(a)))
    }

    /// Night hours in the night hue, day hours warm, dusk and dawn between.
    static func color(hour h: Int) -> Color {
        switch h {
        case 0..<6, 22..<24: NoopHTMLColor.night
        case 6..<9, 19..<22: NoopHTMLColor.blush
        default: NoopHTMLColor.warm
        }
    }
}

private enum NoopDailyRhythmClock {
    static func label(_ minute: Int) -> String { NoopDailyRhythmScreen.clock(minute: minute) }
}
#endif
