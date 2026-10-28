#if os(iOS)
import SwiftUI

// MARK: - While iOS asks, later on

/// The page behind a permission question that onboarding left for the moment it is used: what it is for
/// and what it is never used for, on screen while iOS asks. It opens, then asks through `ask`, so the
/// question arrives over it; the caller closes it once iOS has its answer. It can't be swiped away, so it
/// never stands in for the answer. Shown only while the permission is undecided; either answer carries on.
struct NoopPermissionPrimer: View {
    enum Kind {
        /// The route of an outdoor workout.
        case location
        /// A question for Svea, spoken: Speech Recognition first, then the Microphone.
        case voice
    }

    let kind: Kind
    /// Puts the system question up. Called once, after the sheet has settled.
    let ask: () -> Void

    @State private var asked = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The tallest alert this sheet sits behind, measured on iOS 27 at the default text size: Speech
    /// Recognition's (Apple's paragraph above the purpose) for voice, the three-button one for location.
    /// iOS grows its alert with the text size, so this grows with it.
    @ScaledMetric(relativeTo: .body) private var locationAlert: CGFloat = 390
    @ScaledMetric(relativeTo: .body) private var voiceAlert: CGFloat = 470

    var body: some View {
        GeometryReader { geo in
            // iOS centres its alert on the screen, not on this sheet: the heading goes in the band above
            // it and the lines in the band below. Each band drops detail until it fits, so nothing sits
            // under the alert on a small phone or at a large text size.
            let sheet = geo.frame(in: .global)
            let screenMid = (sheet.maxY + geo.safeAreaInsets.bottom) / 2
            let alert = (kind == .voice ? voiceAlert : locationAlert) + 24
            let above = max(0, screenMid - alert / 2 - sheet.minY)
            let below = max(0, sheet.maxY - (screenMid + alert / 2))
            ZStack {
                scene
                VStack(spacing: 0) {
                    ViewThatFits(in: .vertical) {
                        heading(withDetail: true)
                        heading(withDetail: false)
                        Color.clear
                    }
                    .frame(height: above, alignment: .top)
                    Spacer(minLength: 0)
                    ViewThatFits(in: .vertical) {
                        lineList(withDetail: true)
                        lineList(withDetail: false)
                        summary
                        Color.clear
                    }
                    .frame(height: below, alignment: .bottom)
                }
                .padding(.horizontal, 22)
            }
        }
        .foregroundStyle(NoopHTMLColor.ink)
        .interactiveDismissDisabled()
        .noopSheet()
        .task {
            guard !asked else { return }
            asked = true
            try? await Task.sleep(for: .milliseconds(450))
            ask()
        }
    }

    // MARK: Copy

    private struct Line {
        let symbol: String
        let tint: Color
        let title: String
        let detail: String
    }

    private var title: String {
        switch kind {
        case .location: "Location, for your route"
        case .voice: "Your voice, for Svea"
        }
    }

    private var detail: String {
        switch kind {
        case .location: "Your session is recording. Location adds the route: distance, pace and a map."
        case .voice: "Hold the mic and ask out loud. Your words become text on this iPhone."
        }
    }

    private var lines: [Line] {
        switch kind {
        case .location:
            [Line(symbol: "point.topleft.down.to.point.bottomright.curvepath", tint: NoopHTMLColor.blueLight,
                  title: "Only while a session runs", detail: "From Start to Finish, never otherwise."),
             Line(symbol: "iphone", tint: NoopHTMLColor.green,
                  title: "Kept on this iPhone", detail: "Unless you export or back it up yourself."),
             Line(symbol: "person.2.slash", tint: NoopHTMLColor.blush,
                  title: "Never shared or tracked", detail: "Not sent to Svea, and never sold.")]
        case .voice:
            [Line(symbol: "hand.tap", tint: Color(hex: 0xB79CF0),
                  title: "Only while you hold the mic", detail: "Let go and it stops listening."),
             Line(symbol: "waveform", tint: NoopHTMLColor.green,
                  title: "Turned into text here", detail: "On this iPhone. Only the text you send goes out."),
             Line(symbol: "doc.badge.ellipsis", tint: NoopHTMLColor.blush,
                  title: "Never a recording", detail: "No audio file, and no audio leaves the phone.")]
        }
    }

    // MARK: Layout

    // iOS dims everything behind its alert, so the copy here is a step brighter and larger than a
    // page's would be.

    private func heading(withDetail: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(NoopHTMLFont.outfit(NoopType.title2, weight: .light))
                .tracking(-0.8)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .onboardingEntrance(0)
            if withDetail {
                Text(detail)
                    .font(NoopHTMLFont.sans(NoopType.footnote))
                    .foregroundStyle(NoopHTMLColor.inkSoft)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingEntrance(1)
            }
        }
        .padding(.top, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func lineList(withDetail: Bool) -> some View {
        VStack(alignment: .leading, spacing: withDetail ? 14 : 10) {
            ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                HStack(alignment: withDetail ? .top : .center, spacing: 14) {
                    NoopIconDisc(symbol: line.symbol, color: line.tint, size: withDetail ? 38 : 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.title).font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                        if withDetail {
                            Text(line.detail)
                                .font(NoopHTMLFont.sans(NoopType.caption))
                                .foregroundStyle(NoopHTMLColor.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .onboardingEntrance(i + 2)
            }
        }
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The three lines as one sentence, for the sliver a small phone leaves under the tallest alert.
    private var summary: some View {
        Text(lines.map(\.title).joined(separator: " · "))
            .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
            .foregroundStyle(NoopHTMLColor.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onboardingEntrance(2)
    }

    // MARK: Scene

    /// Drawn across the whole sheet, so it shows around the alert: a route being walked for location,
    /// a voice spreading out from the question for Svea. Still under Reduce Motion.
    private var scene: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                switch kind {
                case .location: drawRoute(in: &context, size: size, t: t)
                case .voice: drawVoice(in: &context, size: size, t: t)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func routePath(_ size: CGSize) -> Path {
        var path = Path()
        let w = size.width, h = size.height
        path.move(to: CGPoint(x: -20, y: h * 0.16))
        path.addCurve(to: CGPoint(x: w * 0.55, y: h * 0.42),
                      control1: CGPoint(x: w * 0.45, y: h * 0.05), control2: CGPoint(x: w * 0.05, y: h * 0.38))
        path.addCurve(to: CGPoint(x: w + 20, y: h * 0.86),
                      control1: CGPoint(x: w * 1.05, y: h * 0.47), control2: CGPoint(x: w * 0.2, y: h * 0.8))
        return path
    }

    private func drawRoute(in context: inout GraphicsContext, size: CGSize, t: Double) {
        let path = routePath(size)
        let tint = NoopHTMLColor.blueLight
        context.stroke(path, with: .color(tint.opacity(0.3)),
                       style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2, 9]))
        // The part already walked, solid, and the runner at its head: one pass every twelve seconds.
        let progress = reduceMotion ? 0.62 : (t / 12).truncatingRemainder(dividingBy: 1)
        let walked = path.trimmedPath(from: 0, to: progress)
        context.stroke(walked, with: .color(tint.opacity(0.7)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        if let head = walked.currentPoint {
            context.fill(Path(ellipseIn: CGRect(x: head.x - 14, y: head.y - 14, width: 28, height: 28)),
                         with: .color(tint.opacity(0.18)))
            context.fill(Path(ellipseIn: CGRect(x: head.x - 5, y: head.y - 5, width: 10, height: 10)),
                         with: .color(tint))
        }
    }

    private func drawVoice(in context: inout GraphicsContext, size: CGSize, t: Double) {
        // Bars across the sheet's middle, tallest at the edges of the alert and fading outward, as if the
        // question in the middle were being spoken.
        let tint = Color(hex: 0xB79CF0)
        let mid = size.height / 2
        let step: CGFloat = 9
        let count = Int(size.width / step) + 1
        for i in 0..<count {
            let x = CGFloat(i) * step + 2
            let fromCentre = abs(x - size.width / 2) / (size.width / 2)
            let wave = 0.55 + 0.45 * sin(Double(i) * 0.7 + t * 3.1) * sin(Double(i) * 0.23 - t * 1.7)
            let height = max(6, size.height * 0.46 * CGFloat(wave) * (1 - fromCentre * 0.55))
            let bar = Path(roundedRect: CGRect(x: x, y: mid - height / 2, width: 3.5, height: height),
                           cornerRadius: 1.75)
            context.fill(bar, with: .color(tint.opacity(0.6 * Double(1 - fromCentre * 0.5))))
        }
    }
}
#endif
