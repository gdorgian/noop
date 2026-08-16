import SwiftUI
import StrandDesign
import WhoopStore

// MARK: - AuraTodayView — the Aura · dark Today, transcribed
//
// A 1:1 reproduction of the Today screen in the "Aura · dark" direction of the Noop design project,
// wired to NOOP's own data. It exists ALONGSIDE `LiquidTodayView` rather than replacing it: the old
// Today stays untouched and reachable while this one is finished and verified, and only then does the
// old one go. Switched by `Settings → Today style`.
//
// Section order and every metric below is the design's:
//   orb → state word + coach → 3 pillars → Svea session → signals list → info banner
struct AuraTodayView: View {

    @EnvironmentObject var repo: Repository

    /// Today's row, or the newest scored one. The design shows a filled screen; a wearer opening the app
    /// mid-morning before a sync has today's row empty, so falling back to the newest scored day keeps
    /// the screen meaningful rather than blanking it.
    private var day: DailyMetric? { repo.days.last(where: { $0.recovery != nil }) ?? repo.days.last }
    private var chargeFrac: Double? { day?.recovery.map { $0 / 100 } }
    private var accent: Color { Aura.accent(forCharge: chargeFrac) }

    var body: some View {
        ScrollView {
            VStack(spacing: Aura.cardGap) {
                hero
                stateBlock
                pillars
                sveaCard
                signalsCard
                banner
                Color.clear.frame(height: 90)   // floating tab-bar clearance
            }
            .padding(.horizontal, Aura.screenHPadding)
            .padding(.top, 8)
        }
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                Aura.page
                // The design's ambient: a 460×400 radial of the state accent, pulled above the top edge
                // and blurred, so the page itself carries the body state before a value is read.
                Ellipse()
                    .fill(RadialGradient(colors: [accent.opacity(0.16), accent.opacity(0)],
                                         center: .center, startRadius: 0, endRadius: 230))
                    .frame(width: 460, height: 400)
                    .blur(radius: 18)
                    .offset(y: -140)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()
        }
        .accessibilityHidden(false)
    }

    // MARK: Hero

    private var hero: some View {
        AuraOrb(fraction: chargeFrac, accent: accent, animated: !repo.days.isEmpty)
            .frame(height: 272)
            .accessibilityElement()
            .accessibilityLabel(Text("\(Aura.stateLabel(forCharge: chargeFrac)). Charge \(day?.recovery.map { String(Int($0.rounded())) } ?? String(localized: "no data yet"))."))
    }

    /// The state word and its coaching line. `margin: -6px 0 22px` in the design — the word tucks up into
    /// the open bottom of the ring's arc rather than sitting below the full square.
    private var stateBlock: some View {
        VStack(spacing: 8) {
            Text(Aura.stateLabel(forCharge: chargeFrac))
                .font(Aura.display(34, .light))
                .kerning(-1.02)                   // -.03em at 34pt
                .foregroundStyle(Aura.ink)
            Text(coachLine)
                .font(Aura.text(14.5))
                .lineSpacing(4)
                .foregroundStyle(Aura.inkCoach)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 290)
        }
        .padding(.top, -6)
        .padding(.bottom, 10)
    }

    // MARK: Pillars

    private var pillars: some View {
        HStack(spacing: 8) {
            pillar(String(localized: "Rest"), sleepText, "", sleepFrac, Aura.restAccent)
            pillar(String(localized: "Charge"), day?.avgHrv.map { String(Int($0.rounded())) } ?? "—",
                   day?.avgHrv == nil ? "" : "ms", day?.avgHrv.map { min($0 / 120, 1) }, accent)
            pillar(String(localized: "Effort"), day?.strain.map { String(format: "%.1f", $0 / 100 * 21) } ?? "—",
                   day?.strain == nil ? "" : "/21", day?.strain.map { $0 / 100 }, Aura.effortAccent)
        }
    }

    private func pillar(_ key: String, _ value: String, _ unit: String,
                        _ frac: Double?, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(key.uppercased())
                .font(Aura.text(10, .semibold))
                .kerning(1.2)                     // .12em at 10pt
                .foregroundStyle(Aura.inkFaint)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(Aura.display(20, .regular)).kerning(-0.5)
                    .foregroundStyle(Aura.ink)
                if !unit.isEmpty {
                    Text(unit).font(Aura.text(11)).foregroundStyle(Aura.inkFaint)
                }
            }
            // The design's track is a 115° hatch, not a flat trough — it reads as an unfilled MEASURE
            // rather than as an empty bar, which matters when the fill is short.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    AuraHatch().fill(Color.white.opacity(0.07))
                    Capsule().fill(tint)
                        .frame(width: geo.size.width * min(max(frac ?? 0, 0), 1))
                }
                .clipShape(Capsule())
            }
            .frame(height: 7)
        }
        .padding(.horizontal, 12).padding(.top, 13).padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Aura.pillarRadius, style: .continuous).fill(Aura.card)
                .overlay(RoundedRectangle(cornerRadius: Aura.pillarRadius, style: .continuous)
                    .strokeBorder(Aura.cardBorder, lineWidth: 0.5))
        )
    }

    // MARK: Svea

    /// The session card. NOTE: NOOP has no session-planning engine — nothing computes a recommended
    /// workout, and Accept / Swap / Rest have nothing behind them yet. The card is transcribed so the
    /// layout is complete, and its title and reason are wired to the readiness verdict and synthesis
    /// sentence NOOP does compute, which is the closest honest source. The three buttons are inert
    /// pending a real recommender; they are deliberately NOT faked into looking functional.
    private var sveaCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: "#8FDCFA"), Color(hex: "#0B6FA8")],
                                         center: .init(x: 0.34, y: 0.30), startRadius: 0, endRadius: 14))
                    .frame(width: 22, height: 22)
                    .shadow(color: Aura.restored.opacity(0.5), radius: 6)
                Text(String(localized: "Svea · today's call").uppercased())
                    .font(Aura.text(10, .semibold)).kerning(1.4)
                    .foregroundStyle(Aura.inkMuted)
            }
            .padding(.bottom, 12)

            Text(sessionTitle)
                .font(Aura.text(19, .medium)).kerning(-0.23).lineSpacing(3)
                .foregroundStyle(Aura.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)

            Text(sessionWhy)
                .font(Aura.text(13.5)).lineSpacing(3)
                .foregroundStyle(Aura.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 16)

            HStack(spacing: 8) {
                Text(String(localized: "Accept"))
                    .font(Aura.text(14.5, .semibold)).foregroundStyle(Aura.onAccent)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(accent))
                ForEach([String(localized: "Swap"), String(localized: "Rest")], id: \.self) { label in
                    Text(label)
                        .font(Aura.text(14, .medium)).foregroundStyle(Aura.ink)
                        .padding(.horizontal, 17).frame(height: 46)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.07)))
                }
            }
        }
        .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Aura.cardRadius, style: .continuous)
                .fill(LinearGradient(colors: [Aura.sveaTop, Aura.sveaBottom],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: Aura.cardRadius, style: .continuous)
                    .strokeBorder(Aura.restored.opacity(0.2), lineWidth: 0.5))
        )
    }

    // MARK: Signals

    private var signalsCard: some View {
        VStack(spacing: 0) {
            signalRow(String(localized: "Heart rate"), day?.restingHr.map(Double.init), "bpm",
                      Aura.depleted, series("rhr"))
            signalRow(String(localized: "Variability"), day?.avgHrv, "ms", accent, series("hrv"))
            signalRow(String(localized: "Breathing"), day?.respRateBpm, "rpm", Aura.restAccent,
                      series("resp"), decimals: 1)
            signalRow(String(localized: "Sleep"), day?.totalSleepMin.map { $0 / 60 }, "h",
                      Aura.effortAccent, series("sleep"), decimals: 1)
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Aura.cardRadius, style: .continuous).fill(Aura.card)
                .overlay(RoundedRectangle(cornerRadius: Aura.cardRadius, style: .continuous)
                    .strokeBorder(Aura.cardBorder, lineWidth: 0.5))
        )
    }

    private func signalRow(_ name: String, _ value: Double?, _ unit: String, _ tint: Color,
                           _ points: [Double], decimals: Int = 0) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(Aura.text(11.5)).foregroundStyle(Aura.inkMuted)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value.map { decimals > 0 ? String(format: "%.\(decimals)f", $0)
                                                  : String(Int($0.rounded())) } ?? "—")
                        .font(Aura.display(18, .regular)).kerning(-0.36)
                        .foregroundStyle(Aura.ink)
                    Text(unit).font(Aura.text(11)).foregroundStyle(Aura.inkFaint)
                }
            }
            Spacer(minLength: 8)
            AuraSpark(values: points, tint: tint).frame(width: 56, height: 22)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Aura.inkCoach)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.white.opacity(0.07)))
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }

    // MARK: Banner

    private var banner: some View {
        HStack(alignment: .top, spacing: 11) {
            Text("i").font(Aura.text(11, .bold)).foregroundStyle(Aura.onAccent)
                .frame(width: 19, height: 19)
                .overlay(Circle().strokeBorder(Aura.onAccent.opacity(0.55), lineWidth: 1.4))
                .padding(.top, 1)
            Text(bannerLine)
                .font(Aura.text(14, .medium)).lineSpacing(3)
                .foregroundStyle(Aura.onAccent)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 17).padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(accent))
    }

    // MARK: - Copy, wired to real values

    private var sleepText: String {
        guard let m = day?.totalSleepMin else { return "—" }
        return "\(Int(m) / 60)h \(Int(m) % 60)m"
    }
    private var sleepFrac: Double? { day?.totalSleepMin.map { min($0 / 480, 1) } }

    private var coachLine: String {
        guard let pct = day?.recovery else {
            return String(localized: "Wear the strap overnight and NOOP will read your body in the morning.")
        }
        switch pct {
        case ..<27:  return String(localized: "Your body is running on empty. Today is for recovering, not earning.")
        case ..<49:  return String(localized: "Several signals are down. Keep the load light and let them come back.")
        case ..<72:  return String(localized: "You are in decent shape. A normal day's work will land well.")
        default:     return String(localized: "Everything is where it should be. This is a day to spend.")
        }
    }

    private var sessionTitle: String {
        guard let pct = day?.recovery else { return String(localized: "No reading yet") }
        return pct < 49 ? String(localized: "Easy movement, nothing structured")
                        : String(localized: "A normal session is well within range")
    }

    private var sessionWhy: String {
        let hrv = day?.avgHrv.map { "HRV \(Int($0.rounded()))ms" } ?? String(localized: "HRV unavailable")
        let rhr = day?.restingHr.map { "RHR \($0)bpm" } ?? String(localized: "RHR unavailable")
        let charge = day?.recovery.map { "Charge \(Int($0.rounded()))" } ?? "—"
        return "\(charge), \(hrv), \(rhr)."
    }

    private var bannerLine: String {
        guard let m = day?.totalSleepMin else {
            return String(localized: "Connect your strap to start reading your nights.")
        }
        return String(localized: "You slept \(Int(m)) minutes. Your readings below are from that night.")
    }

    /// Trailing series for a signal's sparkline, oldest → newest, over the last 14 scored days.
    private func series(_ key: String) -> [Double] {
        let rows = repo.days.suffix(14)
        switch key {
        case "rhr":   return rows.compactMap { $0.restingHr.map(Double.init) }
        case "hrv":   return rows.compactMap { $0.avgHrv }
        case "resp":  return rows.compactMap { $0.respRateBpm }
        case "sleep": return rows.compactMap { $0.totalSleepMin.map { $0 / 60 } }
        default:      return []
        }
    }
}

// MARK: - Pieces

/// The design's 115° hatched track: `repeating-linear-gradient(115deg, rgba(255,255,255,.07) 0 3px,
/// transparent 3px 6px)`. Drawn as a Shape rather than an image so it stays crisp at any width.
struct AuraHatch: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let step: CGFloat = 6
        let slant = rect.height / tan(115 * .pi / 180)
        var x = -abs(slant)
        while x < rect.width + abs(slant) {
            p.move(to: CGPoint(x: x, y: rect.maxY))
            p.addLine(to: CGPoint(x: x + slant, y: rect.minY))
            p.addLine(to: CGPoint(x: x + slant + 3, y: rect.minY))
            p.addLine(to: CGPoint(x: x + 3, y: rect.maxY))
            p.closeSubpath()
            x += step
        }
        return p
    }
}

/// The signal-row sparkline: a 56×22 polyline, stroke 1.6, round caps and joins — the design's `spark()`
/// helper, which normalises to the series' own min/max rather than to a fixed scale.
struct AuraSpark: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            Path { p in
                guard values.count >= 2 else { return }
                let mn = values.min() ?? 0, mx = values.max() ?? 1
                let range = (mx - mn) == 0 ? 1 : (mx - mn)
                for (i, v) in values.enumerated() {
                    let x = geo.size.width * CGFloat(i) / CGFloat(values.count - 1)
                    let y = geo.size.height - (CGFloat((v - mn) / range) * (geo.size.height - 2)) - 1
                    i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(tint, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}
