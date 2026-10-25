#if os(iOS)
import SwiftUI

// MARK: - The moment a session is saved

/// Drawn around a session's icon disc the first time its page opens after saving: a ring that closes
/// once, a few sparks that leave and fade, and a single success tap. Shown once, then the page is a page.
struct NoopCelebrationRing: View {
    let tint: Color
    var diameter: CGFloat = 88

    @State private var drawn = false
    @State private var burst = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: drawn ? 1 : 0)
                .stroke(AngularGradient(colors: [tint.opacity(0.2), tint, tint], center: .center),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: diameter, height: diameter)
                .shadow(color: tint.opacity(drawn ? 0.6 : 0), radius: 8)
            ForEach(0..<8, id: \.self) { i in
                let angle = Angle.degrees(Double(i) * 45 + 22.5)
                Capsule()
                    .fill(tint)
                    .frame(width: 3, height: i.isMultiple(of: 2) ? 9 : 6)
                    .offset(y: -(diameter / 2 + (burst ? 20 : 6)))
                    .rotationEffect(angle)
                    .opacity(burst ? 0 : (drawn ? 1 : 0))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            if reduceMotion { drawn = true; return }
            withAnimation(.easeOut(duration: 0.85).delay(0.15)) { drawn = true }
            withAnimation(.easeOut(duration: 0.7).delay(0.9)) { burst = true }
        }
        .sensoryFeedback(.success, trigger: drawn) { _, now in now }
    }
}

// MARK: - Share card

/// What a share card shows. Built by the page that knows the session.
struct NoopShareContent {
    let symbol: String
    let tint: Color
    let ink: Color
    let kind: String
    let title: String
    let when: String
    /// Up to four figures: value and label.
    let figures: [(value: String, label: String)]
    /// Route points in latitude/longitude, drawn as the shape of the route when there is one.
    var route: [RouteMath.LatLng] = []
}

/// A 4:5 card for Messages and stories: the session, its figures, and the shape of the route if it had one.
/// Drawn by SwiftUI into an image, so it is the same type and colour as the app.
struct NoopShareCard: View {
    let content: NoopShareContent

    var body: some View {
        ZStack(alignment: .topLeading) {
            NoopHTMLColor.canvas
            RadialGradient(colors: [content.tint.opacity(0.32), .clear], center: .init(x: 0.15, y: 0.05),
                           startRadius: 10, endRadius: 520)
            if content.route.count >= 2 {
                NoopRouteShape(points: content.route)
                    .stroke(content.tint, style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                    .shadow(color: content.tint.opacity(0.6), radius: 18)
                    .padding(.horizontal, 110).padding(.top, 470).padding(.bottom, 420)
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: content.symbol).font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(content.ink)
                        .frame(width: 116, height: 116).background(content.tint, in: Circle())
                    VStack(alignment: .leading, spacing: 6) {
                        Text(content.kind.uppercased()).font(NoopHTMLFont.sans(30, weight: .semibold)).tracking(3)
                            .foregroundStyle(content.tint)
                        Text(content.when).font(NoopHTMLFont.sans(32)).foregroundStyle(NoopHTMLColor.copy)
                    }
                }
                Text(content.title).font(NoopHTMLFont.outfit(132, weight: .light)).foregroundStyle(NoopHTMLColor.ink)
                    .lineLimit(2).minimumScaleFactor(0.6)
                    .padding(.top, 48)
                Spacer()
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(content.figures.prefix(4).enumerated()), id: \.offset) { _, f in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(f.value).font(NoopHTMLFont.outfit(84, weight: .light)).monospacedDigit()
                                .foregroundStyle(NoopHTMLColor.ink).lineLimit(1).minimumScaleFactor(0.6)
                            Text(f.label).font(NoopHTMLFont.sans(28, weight: .medium)).foregroundStyle(NoopHTMLColor.copy)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1).padding(.vertical, 30)
                HStack {
                    Text("Noop Aura").font(NoopHTMLFont.sans(32, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                    Spacer()
                    Text("measured on the wrist").font(NoopHTMLFont.sans(26)).foregroundStyle(NoopHTMLColor.faint)
                }
            }
            .padding(84)
        }
        .frame(width: 1080, height: 1350)
    }
}

/// A route's shape scaled into its frame, north up, its aspect kept.
struct NoopRouteShape: Shape {
    let points: [RouteMath.LatLng]

    func path(in rect: CGRect) -> Path {
        guard points.count >= 2 else { return Path() }
        let midLat = (points.map(\.lat).min()! + points.map(\.lat).max()!) / 2
        let k = cos(midLat * .pi / 180)
        let xs = points.map { $0.lon * k }, ys = points.map(\.lat)
        let w = max(1e-9, xs.max()! - xs.min()!), h = max(1e-9, ys.max()! - ys.min()!)
        let scale = min(rect.width / w, rect.height / h)
        let ox = rect.minX + (rect.width - w * scale) / 2, oy = rect.minY + (rect.height - h * scale) / 2
        var p = Path()
        for (i, pt) in points.enumerated() {
            let x = ox + (pt.lon * k - xs.min()!) * scale
            let y = oy + (ys.max()! - pt.lat) * scale
            if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
        }
        return p
    }
}

/// "Share" for a finished session: the card is drawn into a named PNG ("Running · Noop Aura.png") and
/// handed to the share sheet. Redrawn when what it shows changes — the route arrives after the page opens.
struct NoopShareButton: View {
    let content: NoopShareContent
    @State private var file: URL?

    private var key: String {
        "\(content.title)|\(content.when)|\(content.route.count)|" + content.figures.map { $0.value + $0.label }.joined()
    }

    var body: some View {
        Group {
            if let file {
                ShareLink(item: file, preview: SharePreview(content.title, image: Image(uiImage: UIImage(contentsOfFile: file.path) ?? UIImage()))) {
                    label
                }
            } else {
                label.opacity(0.5)
            }
        }
        .buttonStyle(NoopHTMLPressStyle())
        .task(id: key) {
            let renderer = ImageRenderer(content: NoopShareCard(content: content).environment(\.colorScheme, .dark))
            renderer.scale = 1
            guard let data = renderer.uiImage?.pngData() else { return }
            let name = "\(content.title) · Noop Aura.png".replacingOccurrences(of: "/", with: "-")
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            if (try? data.write(to: url, options: .atomic)) != nil { file = url }
        }
    }

    private var label: some View {
        Label("Share", systemImage: "square.and.arrow.up")
            .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
            .foregroundStyle(NoopHTMLColor.ink)
            .padding(.horizontal, 14).frame(height: 36)
            .background(Color.white.opacity(0.09), in: Capsule())
            .noopHitTarget()
    }
}
#endif
