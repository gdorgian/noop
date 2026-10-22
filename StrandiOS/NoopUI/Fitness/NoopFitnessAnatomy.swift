#if os(iOS)
import SwiftUI
import StrandFitness

/// Front and back figures with one smooth shape per muscle group. Noop's own drawing: every outline
/// is a closed Catmull-Rom curve through a handful of points on a 100 × 212 grid, drawn for the
/// figure's right side and mirrored. Muscles are coloured by the caller; the body sits behind them.
struct NoopFitnessBodyMap: View {
    let color: (FitnessMuscleGroup) -> Color
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 10 : 22) {
            figure(Self.frontMuscles, label: "Front")
            figure(Self.backMuscles, label: "Back")
        }
    }

    private func figure(_ muscles: [Shape], label: String) -> some View {
        VStack(spacing: 8) {
            Canvas { ctx, size in
                let s = min(size.width / 100, size.height / 212)
                let dx = (size.width - 100 * s) / 2
                let t = CGAffineTransform(translationX: dx, y: 0).scaledBy(x: s, y: s)
                for part in Self.silhouette {
                    for path in part.paths() { ctx.fill(path.applying(t), with: .color(Color.white.opacity(0.07))) }
                }
                for m in muscles {
                    let fill = m.group.map(color) ?? Color.white.opacity(0.1)
                    for path in m.paths() {
                        let p = path.applying(t)
                        ctx.fill(p, with: .color(fill))
                        ctx.stroke(p, with: .color(NoopHTMLColor.canvas.opacity(0.9)), lineWidth: max(0.8, s * 0.55))
                    }
                }
            }
            .aspectRatio(100 / 212, contentMode: .fit)
            if !compact {
                Text(label).font(NoopHTMLFont.sans(11, weight: .semibold)).foregroundStyle(NoopHTMLColor.muted)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Geometry

    struct Shape {
        let group: FitnessMuscleGroup?
        let points: [CGPoint]
        var mirrored = true

        init(_ group: FitnessMuscleGroup?, _ pts: [(CGFloat, CGFloat)], mirrored: Bool = true) {
            self.group = group
            self.points = pts.map { CGPoint(x: $0.0, y: $0.1) }
            self.mirrored = mirrored
        }

        func paths() -> [Path] {
            let a = NoopFitnessBodyMap.smooth(points)
            guard mirrored else { return [a] }
            return [a, NoopFitnessBodyMap.smooth(points.map { CGPoint(x: 100 - $0.x, y: $0.y) })]
        }
    }

    /// A closed curve through every point (centripetal-ish Catmull-Rom as cubic Béziers).
    static func smooth(_ p: [CGPoint]) -> Path {
        var path = Path()
        guard p.count > 2 else { return path }
        let n = p.count
        path.move(to: p[0])
        for i in 0..<n {
            let p0 = p[(i - 1 + n) % n], p1 = p[i], p2 = p[(i + 1) % n], p3 = p[(i + 2) % n]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        path.closeSubpath()
        return path
    }

    static func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> [(CGFloat, CGFloat)] {
        (0..<8).map { i in
            let a = Double(i) / 8 * 2 * .pi
            return (cx + rx * CGFloat(cos(a)), cy + ry * CGFloat(sin(a)))
        }
    }

    static let silhouette: [Shape] = [
        Shape(nil, ellipse(50, 13, 8.5, 10.5), mirrored: false),
        Shape(nil, [(44, 20), (56, 20), (57, 31), (43, 31)], mirrored: false),
        Shape(nil, [(50, 29), (40, 30), (29, 33), (23, 39), (25, 52), (29, 68), (31, 82), (33, 93), (40, 99), (50, 101),
                    (60, 99), (67, 93), (69, 82), (71, 68), (75, 52), (77, 39), (71, 33), (60, 30)], mirrored: false),
        Shape(nil, [(25, 36), (19, 42), (16.5, 55), (17.5, 68), (22.5, 70), (26.5, 60), (28.5, 46)]),
        Shape(nil, [(17.5, 67), (13.5, 79), (11.5, 94), (14.5, 99), (18.5, 97), (22, 84), (23.5, 70)]),
        Shape(nil, ellipse(13.5, 105, 3.8, 7)),
        Shape(nil, [(34, 91), (30, 104), (30.5, 128), (33.5, 146), (42, 147), (47, 128), (49.5, 102), (44, 96)]),
        Shape(nil, [(32.5, 145), (30.5, 160), (33, 184), (35.5, 198), (42, 198), (43.5, 181), (45, 160), (43, 145)]),
        Shape(nil, ellipse(39, 203, 5.5, 3.8)),
    ]

    static let frontMuscles: [Shape] = [
        Shape(.neck, [(45.5, 21), (49, 22), (49, 30), (44.5, 30)]),
        Shape(.traps, [(40, 31.5), (46, 30), (46.5, 33), (36, 35)]),
        Shape(.shoulders, [(29.5, 34.5), (24.5, 38.5), (22, 46.5), (25.5, 50), (29.5, 44.5), (33, 37.5)]),
        Shape(.chest, [(34.5, 37), (48.5, 36.5), (49.3, 43.5), (48.5, 50), (41, 52.5), (33.5, 49.5), (31.5, 43)]),
        Shape(.biceps, [(24.5, 49.5), (21.2, 56), (21, 63.5), (23.8, 67.8), (26.8, 62), (27.8, 53)]),
        Shape(.forearms, [(20.2, 70.5), (16.2, 80), (14.8, 91.5), (17.5, 95), (20.8, 85.5), (23, 73.5)]),
        Shape(.obliques, [(36, 55), (42, 54), (43, 69), (42, 83), (38, 80), (35.2, 68)]),
        Shape(.abs, [(44.6, 53.5), (49.2, 53.5), (49.2, 60.5), (44.6, 61)]),
        Shape(.abs, [(44.4, 62.5), (49.2, 62.5), (49.2, 69.5), (44.4, 69.8)]),
        Shape(.abs, [(44.3, 71.3), (49.2, 71.3), (49.2, 78.5), (44.6, 78.8)]),
        Shape(.abs, [(45, 80.2), (49.2, 80.2), (49.2, 89.5), (46.6, 88)]),
        Shape(.hipFlexors, [(38.5, 85.5), (43.5, 86.5), (46, 94), (42, 96.5), (39, 92)]),
        Shape(.quads, [(33.5, 98), (41, 97.5), (44.5, 106), (45.5, 125), (43, 139.5), (37.2, 141), (33, 129.5), (32, 112)]),
        Shape(.adductors, [(44.6, 99), (48.6, 101), (48.4, 117), (46.4, 121), (45.4, 108)]),
        Shape(.tibialis, [(35.6, 150), (39.6, 149), (40.8, 165), (39.2, 185), (36.8, 184), (35, 166)]),
        Shape(.calves, [(41.4, 150.5), (44.2, 152.5), (44.4, 168), (42, 175)]),
    ]

    static let backMuscles: [Shape] = [
        Shape(.neck, [(45.5, 20), (49, 21), (49, 27), (45, 28)]),
        Shape(.traps, [(50, 26), (43, 31), (36, 35.5), (42, 40), (47, 48), (50, 57), (53, 48), (58, 40), (64, 35.5), (57, 31)],
              mirrored: false),
        Shape(.shoulders, [(29.5, 34.5), (24.5, 38.5), (22, 46.5), (25.5, 50), (29.5, 44.5), (34, 38)]),
        Shape(.upperBack, [(41.5, 42), (46.5, 47.5), (48.5, 56.5), (44, 58), (37.5, 51)]),
        Shape(.lats, [(32.5, 46), (39.5, 51), (45.5, 60.5), (45.5, 72), (40, 78.5), (34, 68), (31, 56)]),
        Shape(.triceps, [(23.5, 48.5), (20.5, 56), (21, 65.5), (24.8, 68), (27.2, 60), (28.2, 50.5)]),
        Shape(.forearms, [(20.2, 70.5), (16.2, 80), (14.8, 91.5), (17.5, 95), (20.8, 85.5), (23, 73.5)]),
        Shape(.lowerBack, [(46.5, 63), (49.3, 61), (49.3, 86), (44, 86.5), (42.5, 77)]),
        Shape(.abductors, [(31.5, 82.5), (36.5, 82), (35, 92.5), (31.5, 93)]),
        Shape(.glutes, [(36, 84.5), (48.8, 87), (49.3, 98), (46.5, 104.5), (38.5, 104.5), (33.6, 96.5)]),
        Shape(.hamstrings, [(33.2, 106.5), (46, 106.5), (46.3, 127), (43.3, 142), (37.2, 142.5), (33, 128)]),
        Shape(.calves, [(32.5, 148), (43, 148), (44.2, 164), (40.4, 182), (35.4, 180), (31.4, 163)]),
    ]
}
#endif
