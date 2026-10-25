import SwiftUI

// MARK: - Header families
//
// The ring style the wearer puts on Today sets the header style of every page behind it: the dials
// lead to WHOOP-style rings on Recovery, Strain and Sleep, the donuts to Bevel-style rings, and any
// other choice (or none) to Noop's own drawings. Only the headers follow; everything below them stays
// as the page has it. A page's Edit page can still add its other drawings as sections.

enum NoopHeroFamily: String {
    case noop, whoop, bevel

    /// The first ring style on Today decides; Today's saved layout is read directly, so a change there
    /// is seen the next time a page opens.
    static var current: NoopHeroFamily {
        let saved = UserDefaults.standard.string(forKey: "noop.layout.today") ?? ""
        let first = saved.split(separator: ",").first { $0.hasPrefix("rings") }
        switch first {
        case "rings-dials": return .whoop
        case "rings-donuts": return .bevel
        default: return .noop
        }
    }
}

extension NoopHeroFamily {
    /// A day's ring colour in the month sheet, in this family's own colours, so the sheet reads like
    /// the header it was opened from.
    func dayColor(_ kind: NoopHeroScore.Kind, _ value: Double) -> Color {
        switch (kind, self) {
        case (.recovery, .whoop):
            return value >= 67 ? Color(hex: 0x16EC06) : value >= 34 ? Color(hex: 0xFFDE00) : Color(hex: 0xFF0026)
        case (.recovery, _):
            return value >= 67 ? Color(hex: 0x5BF0A6) : value >= 34 ? Color(hex: 0xF7D86A) : Color(hex: 0xF57A72)
        case (.strain, .whoop): return Color(hex: 0x0093E7)
        case (.strain, _): return Color(hex: 0xF0A43C)
        case (.sleep, .whoop): return Color(hex: 0x7C93A8)
        case (.sleep, _): return Color(hex: 0x9C8CFF)
        }
    }
}

/// What a score header shows: the figure, its fill, its colours and its word.
struct NoopHeroScore {
    enum Kind { case recovery, strain, sleep }
    let kind: Kind
    /// 0…1 of the ring.
    let fill: Double
    /// The figure as text, nil when not measured.
    let text: String?
    /// Shown after the figure ("%"), empty for none.
    var suffix = "%"
    /// For strain: today's target as fractions of the ring.
    var target: ClosedRange<Double>? = nil
    /// For strain: the target as the wearer reads it ("39 – 77%").
    var targetText: String? = nil
}

// MARK: WHOOP style

/// A large ring with a flat-ended arc from the top on a grey track; in the middle a heavy figure, a
/// tracked label, and for sleep a three-band marker of where the night sits.
struct NoopWhoopStyleHero: View {
    let score: NoopHeroScore
    var recovery: Double? = nil

    private var color: Color {
        switch score.kind {
        case .sleep: return Color(hex: 0x7C93A8)
        case .strain: return Color(hex: 0x0093E7)
        case .recovery:
            guard let r = recovery else { return Color(hex: 0x6E7780) }
            return r >= 67 ? Color(hex: 0x16EC06) : r >= 34 ? Color(hex: 0xFFDE00) : Color(hex: 0xFF0026)
        }
    }

    private var label: String {
        switch score.kind {
        case .sleep: "SLEEP\nPERFORMANCE"
        case .strain: "STRAIN"
        case .recovery: "RECOVERY"
        }
    }

    var body: some View {
        let side = NoopPageHeroMetrics.heroSide
        NoopSlotClock(continuous: false) { _, reveal in
            ZStack {
                // Proportions from the reference: the stroke is about a sixteenth of the ring's width.
                Circle().stroke(Color(hex: 0x3A4148), lineWidth: 17)
                Circle().trim(from: 0, to: min(1, score.fill) * NoopRingValues.spring(reveal))
                    .stroke(color, style: StrokeStyle(lineWidth: 17, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(score.text ?? "--").font(NoopHTMLFont.sans(64, weight: .heavy)).monospacedDigit()
                        if score.text != nil, !score.suffix.isEmpty {
                            Text(score.suffix).font(NoopHTMLFont.sans(30, weight: .heavy))
                        }
                    }
                    .foregroundStyle(score.text == nil ? NoopHTMLColor.faint : NoopHTMLColor.ink)
                    Text(label).font(NoopHTMLFont.sans(NoopType.caption, weight: .bold)).tracking(2)
                        .multilineTextAlignment(.center).foregroundStyle(NoopHTMLColor.inkSoft)
                    if score.kind == .sleep { bands.padding(.top, 4) }
                }
            }
            .padding(8)
        }
        .frame(width: side, height: side)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label.replacingOccurrences(of: "\n", with: " ").capitalized) \(score.text ?? "not measured")\(score.text == nil ? "" : score.suffix)")
    }

    /// Poor, sufficient, optimal: the band the night sits in is lit.
    private var bands: some View {
        let lit = score.fill >= 0.85 ? 2 : score.fill >= 0.7 ? 1 : 0
        return HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Capsule().fill(i == lit ? [Color(hex: 0xF2445B), Color(hex: 0xF5CF3B), Color(hex: 0x2BD94F)][i] : Color.white.opacity(0.18))
                    .frame(width: 20, height: 3)
            }
        }
    }
}

// MARK: Bevel style

/// A thick recessed track with a rounded arc inside it, a raised inner disc, the figure in the score's
/// colour with its word beneath; strain adds a hatched target band and the target written under the
/// ring.
struct NoopBevelStyleHero: View {
    let score: NoopHeroScore

    private var colors: [Color] {
        switch score.kind {
        case .strain: [Color(hex: 0xFFE3A3), Color(hex: 0xF0A43C)]
        case .recovery: [Color(hex: 0xE6F27A), Color(hex: 0x8BCB3C)]
        case .sleep: [Color(hex: 0xB9B3FF), Color(hex: 0x7468E0)]
        }
    }

    private var word: String {
        switch score.kind {
        case .strain: "Strain"
        case .recovery: "Recovered"
        case .sleep: "Quality"
        }
    }

    var body: some View {
        let side = NoopPageHeroMetrics.heroSide
        VStack(spacing: 10) {
            NoopSlotClock(continuous: false) { _, reveal in
                ZStack {
                    Canvas { context, size in draw(&context, size, reveal: reveal) }
                    VStack(spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text(score.text ?? "--").font(NoopHTMLFont.sans(54, weight: .semibold)).monospacedDigit()
                            if score.text != nil, !score.suffix.isEmpty {
                                Text(score.suffix).font(NoopHTMLFont.sans(26, weight: .semibold))
                            }
                        }
                        .foregroundStyle(score.text == nil ? NoopHTMLColor.faint : colors[1])
                        Text(word).font(NoopHTMLFont.sans(NoopType.subhead)).foregroundStyle(NoopHTMLColor.copy)
                    }
                }
            }
            .frame(width: side - (score.targetText == nil ? 0 : 26), height: side - (score.targetText == nil ? 0 : 26))
            if let t = score.targetText {
                (Text("Target Strain: ").foregroundStyle(NoopHTMLColor.copy) + Text(t).foregroundStyle(NoopHTMLColor.ink))
                    .font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium))
            }
        }
        .frame(width: side, height: side)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(word) \(score.text ?? "not measured")\(score.text == nil ? "" : score.suffix)")
    }

    private func draw(_ context: inout GraphicsContext, _ size: CGSize, reveal: Double) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let outer = min(size.width, size.height) / 2
        let width = outer * 0.2, r = outer - width / 2 - 6
        func arc(_ a: Double, _ b: Double) -> Path {
            var p = Path()
            p.addArc(center: c, radius: r, startAngle: .radians(-.pi / 2 + a * 2 * .pi), endAngle: .radians(-.pi / 2 + b * 2 * .pi), clockwise: false)
            return p
        }
        // The outer disc, a little lighter than the page.
        context.fill(Path(ellipseIn: CGRect(x: c.x - outer, y: c.y - outer, width: 2 * outer, height: 2 * outer)),
                     with: .linearGradient(Gradient(colors: [Color(hex: 0x2C303A), Color(hex: 0x1D2028)]),
                                           startPoint: CGPoint(x: c.x, y: c.y - outer), endPoint: CGPoint(x: c.x, y: c.y + outer)))
        // The recessed track: darker, with a shadow along its inner top edge.
        context.stroke(arc(0, 1), with: .color(Color(hex: 0x14161C)), lineWidth: width)
        var shade = context
        shade.addFilter(.blur(radius: 3))
        shade.stroke(arc(0, 1).offsetBy(dx: 0, dy: 2), with: .color(.black.opacity(0.45)), lineWidth: 3)
        // The raised inner disc.
        let inner = r - width / 2 - 4
        var lift = context
        lift.addFilter(.shadow(color: .black.opacity(0.5), radius: 8, y: 4))
        lift.fill(Path(ellipseIn: CGRect(x: c.x - inner, y: c.y - inner, width: 2 * inner, height: 2 * inner)),
                  with: .linearGradient(Gradient(colors: [Color(hex: 0x30343F), Color(hex: 0x23262E)]),
                                        startPoint: CGPoint(x: c.x, y: c.y - inner), endPoint: CGPoint(x: c.x, y: c.y + inner)))
        context.stroke(Path(ellipseIn: CGRect(x: c.x - inner, y: c.y - inner, width: 2 * inner, height: 2 * inner)),
                       with: .color(.white.opacity(0.06)), lineWidth: 1)
        // Strain's target: hatched, inside the track.
        if let t = score.target {
            let band = arc(t.lowerBound * reveal, t.upperBound * reveal).strokedPath(StrokeStyle(lineWidth: width - 8, lineCap: .round))
            var hatch = context
            hatch.clip(to: band)
            hatch.fill(band, with: .color(colors[1].opacity(0.22)))
            var lines = Path()
            var x = c.x - outer
            while x < c.x + outer {
                lines.move(to: CGPoint(x: x, y: c.y + outer)); lines.addLine(to: CGPoint(x: x + 2 * outer, y: c.y - outer))
                x += 5
            }
            hatch.stroke(lines, with: .color(colors[1].opacity(0.5)), lineWidth: 1.2)
        }
        // The score: a rounded arc inside the track, shaded along its length.
        let f = min(1, score.fill) * NoopRingValues.spring(reveal)
        guard f > 0.004 else { return }
        context.stroke(arc(0, f), with: noopArcShading(colors[0], colors[1], center: c, fill: f, radius: r, lineWidth: width - 8),
                       style: StrokeStyle(lineWidth: width - 8, lineCap: .round))
    }
}

/// A colour run along a rounded arc from the top: it starts under the start cap and ends under the
/// end cap, so neither cap picks up the other end's colour where a full-circle gradient wraps.
func noopArcShading(_ from: Color, _ to: Color, center: CGPoint, fill: Double, radius: CGFloat, lineWidth: CGFloat) -> GraphicsContext.Shading {
    let cap = Double(lineWidth / 2 / max(radius, 1))
    let span = min(1, (fill * 2 * .pi + 2 * cap) / (2 * .pi))
    return .conicGradient(Gradient(stops: [.init(color: from, location: 0), .init(color: to, location: span)]),
                          center: center, angle: .radians(-.pi / 2 - cap))
}
