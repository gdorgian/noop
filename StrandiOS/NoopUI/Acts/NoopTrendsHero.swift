import StrandAnalytics
import SwiftUI

// MARK: - Trends hero
//
// The top of Trends: the page name, the body-age orb, and the pace-of-aging card rising out of the
// orb's glow, closed by the door to Your ages.

struct NoopTrendsHero: View {
    /// Which drawing holds the age: 0 the orb, 1 tree rings, 2 a breathing field.
    var style = 0
    var bodyAge: Double?
    var chronoAge: Int
    var pace: AgingPace.Result?
    var paceWeeks: Int
    /// Shown in the orb while there is no age yet.
    var waitingReason: String
    var openAges: () -> Void

    /// Edge to edge: the orb's frame is the full screen width, past the page gutters.
    /// Sized so the visible orb (the frame less its inset for the moving outline) matches the other
    /// pages' heroes; the drifting specks still reach past it.
    private var orbSide: CGFloat { min(UIScreen.main.bounds.width, NoopPageHeroMetrics.heroSide / 0.79) }
    /// How far the card rises behind the orb.
    private var overlap: CGFloat { orbSide * 0.36 }
    /// Type inside the orb follows its size.
    private var typeScale: CGFloat { orbSide / 330 }

    private var yearsDifference: Double? {
        guard let bodyAge, chronoAge > 0 else { return nil }
        return bodyAge - Double(chronoAge)
    }

    /// Green under your age, amber over it, the blues only in the year either side of it.
    private var colorScore: Double { NoopAuraOrbModel.colorScore(yearsDifference: yearsDifference) }

    /// A faster pace makes the outline lumpier; without a pace yet, the distance from your age does.
    private var shapeScore: Double {
        if let pace, pace.isDefensible { return min(max((pace.pace - 0.4) / 2.0, 0), 1) }
        return min(max(0.3 + (yearsDifference ?? 0) / 12, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .top) {
            paceCard
                .padding(.top, orbSide - overlap)
            Color.clear
                .frame(height: orbSide)
                .overlay { orb.frame(width: orbSide, height: orbSide) }
        }
    }

    // MARK: Orb

    private var orb: some View {
        let palette = NoopAuraOrbModel.palette(colorScore)
        return ZStack {
            Group {
                switch style {
                case 1: NoopAgeTreeRings(bodyAge: bodyAge, chronoAge: chronoAge, palette: palette)
                case 2: NoopAgeField(palette: palette, shapeScore: shapeScore)
                default: NoopAuraOrb(shapeScore: shapeScore, colorScore: colorScore, paused: bodyAge == nil, drift: 0.55)
                }
            }
            .transition(.opacity)
            VStack(spacing: 6) {
                // Whole years, as Your ages reads the same estimate (its band is ±5 years).
                Text(bodyAge.map { "\(Int($0.rounded()))" } ?? "\u{2014}")
                    .font(NoopHTMLFont.outfit(50 * typeScale, weight: .semibold))
                    .tracking(-0.5)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text("BODY AGE")
                    .font(NoopHTMLFont.sans(NoopType.caption * typeScale, weight: .semibold))
                    .tracking(2.2)
                    .foregroundStyle(.white)
                Text(deltaLine)
                    .font(NoopHTMLFont.sans(NoopType.subhead * typeScale, weight: .semibold))
                    .foregroundStyle(bodyAge == nil ? NoopHTMLColor.copy : palette.bottom)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
            .shadow(color: .black.opacity(0.6), radius: 10)
            .frame(maxWidth: orbSide * 0.55)
            .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(bodyAge.map { "Body age \(Int($0.rounded())), \(deltaLine)" } ?? "Body age, \(waitingReason)")
    }

    private var deltaLine: String {
        guard bodyAge != nil else { return waitingReason }
        guard let d = yearsDifference else { return "from the last 7 days" }
        let years = Int(d.rounded())
        if years == 0 { return "right on your age" }
        return "\(abs(years)) \(abs(years) == 1 ? "year" : "years") \(years > 0 ? "older" : "younger")"
    }

    // MARK: Pace card

    private var paceIsShown: Bool { pace?.isDefensible == true }

    private var paceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("PACE OF AGING")
                    .font(NoopHTMLFont.sans(11.5, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(NoopHTMLColor.ink)
                Spacer(minLength: 8)
                statusChip
            }
            .padding(.top, overlap - 14)

            ZStack(alignment: .top) {
                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        Circle().fill(Color.white.opacity(0.28))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.45), lineWidth: 1))
                            .frame(width: 13, height: 13)
                        Text("Slow")
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Text("Fast")
                        NoopAuraFastGlyph().frame(width: 15, height: 15)
                    }
                }
                .font(NoopHTMLFont.sans(13, weight: .medium))
                .foregroundStyle(NoopHTMLColor.copy)

                valueReadout
                    .frame(height: 26)
                    .padding(.top, 9)
            }
            .padding(.top, 22)

            NoopAuraPaceRuler(pace: paceIsShown ? pace?.pace : nil)
                .padding(.top, 6)

            Button(action: openAges) {
                Text("YOUR AGES")
                    .font(NoopHTMLFont.sans(11.5, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(NoopHTMLColor.ink)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 40)
                    .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(NoopHTMLPressStyle())
            .padding(.top, 24)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background {
            // The card has no top edge: it fades up into the orb's glow.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(stops: [
                    .init(color: Color.white.opacity(0), location: 0),
                    .init(color: Color.white.opacity(0.025), location: 0.4),
                    .init(color: Color.white.opacity(0.06), location: 1)
                ], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(LinearGradient(stops: [
                    .init(color: Color.white.opacity(0), location: 0.25),
                    .init(color: Color.white.opacity(0.08), location: 0.7),
                    .init(color: Color.white.opacity(0.10), location: 1)
                ], startPoint: .top, endPoint: .bottom), lineWidth: 1)
        }
    }

    private var statusChip: some View {
        let text: String
        if let pace, pace.isDefensible {
            text = pace.direction == .slower ? "slower than real time" : pace.direction == .faster ? "faster than real time" : "in step with real time"
        } else if paceWeeks >= AgingPace.minPoints {
            // Enough weeks, but they still disagree too much to put a number on.
            text = "still settling"
        } else {
            text = "\(paceWeeks) of \(AgingPace.minPoints) weeks"
        }
        return HStack(spacing: 6) {
            Circle().fill(NoopHTMLColor.ink).frame(width: 6, height: 6)
            Text(text)
                .font(NoopHTMLFont.sans(11.5, weight: .semibold))
                .foregroundStyle(NoopHTMLColor.inkSoft)
        }
        .padding(.horizontal, 8)
        .frame(height: 20)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    /// The value sits over its own place on the ruler, clear of the two end labels.
    private var valueReadout: some View {
        GeometryReader { geo in
            let value = paceIsShown ? pace?.pace : nil
            let at = CGFloat(((min(max(value ?? 1, -1), 3)) + 1) / 4)
            Text(value.map { $0.formatted(.number.precision(.fractionLength(1))) + "\u{00D7}" } ?? "\u{2014}")
                .font(NoopHTMLFont.outfit(20, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(NoopHTMLColor.ink)
                .fixedSize()
                .position(x: min(max(geo.size.width * at, 80), geo.size.width - 80), y: geo.size.height / 2)
        }
    }
}

/// The "fast" end of the scale drawn as a small lumpy blob, the orb's own restless state.
private struct NoopAuraFastGlyph: View {
    var body: some View {
        let shape = NoopAmoebaShape(offsets: NoopAuraVector([6, -5, 7, -3, 5, -7, 4]), inset: 2.5, unit: 0.2)
        shape.fill(Color.white.opacity(0.28)).overlay(shape.stroke(Color.white.opacity(0.45), lineWidth: 1))
    }
}

/// −1× to 3×: a tick every 1/12×, every whole number brighter; a lit marker at the value.
private struct NoopAuraPaceRuler: View {
    let pace: Double?
    private let ticks = 49

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    ForEach(0..<ticks, id: \.self) { i in
                        Rectangle()
                            .fill(Color.white.opacity(i % 12 == 0 ? 0.38 : 0.17))
                            .frame(width: 2, height: 23)
                            .offset(x: w * CGFloat(i) / CGFloat(ticks - 1) - 1)
                    }
                    if let pace {
                        let at = CGFloat((min(max(pace, -1), 3) + 1) / 4)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white)
                            .frame(width: 2, height: 31)
                            .offset(x: w * at - 1)
                    }
                }
                .frame(height: 31)
            }
            .frame(height: 31)

            HStack {
                Text("\u{2212}1.0\u{00D7}")
                Spacer()
                Text("1.0\u{00D7}")
                Spacer()
                Text("3.0\u{00D7}")
            }
            .font(NoopHTMLFont.sans(11.5, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(NoopHTMLColor.muted)
            .padding(.horizontal, -6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pace.map { "Pace of aging \($0.formatted(.number.precision(.fractionLength(1)))) times real time" } ?? "Pace of aging not available yet")
    }
}

