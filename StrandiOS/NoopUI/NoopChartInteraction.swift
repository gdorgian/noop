import SwiftUI
import Charts

// MARK: - Every chart's touch
//
// One template for how any chart in Aura answers a finger (27 Oct 2026), so no chart has to build its
// own and none is left behind:
//
//  • Press and drag to scrub: a rule glides under the finger, snaps to the readings, and a light
//    detent marks each one. The value rides above the rule; let go and it fades.
//  • Pinch to zoom along time, around the pinch. The chart is laid out again at the wider size, so
//    lines stay their own weight rather than being stretched as a picture.
//  • While zoomed, one finger still reads; two fingers (or the pinch itself) move along, with
//    momentum and a soft edge, and a thin bar shows where you are. Double tap, or pinch back, to return.
//
// `noopChart(x:)` gives a Swift Charts chart all of it. `noopChartZoom()` gives any drawing (a Canvas,
// a hand-built plot) the zoom and pan.

/// What the scrub shows above the rule: the reading, and under it when it was.
struct NoopChartReadout {
    var value: String
    var detail: String? = nil
    /// The reading's height on the chart's y axis, for a dot on the line.
    var y: Double? = nil
    /// The dot's glow.
    var tint: Color = .white
}

extension View {
    /// Scrub, zoom and pan for a Swift Charts chart whose x axis is `X`.
    ///
    /// - Parameters:
    ///   - snap: the x of each reading, for the rule to snap to and a detent per reading. Without it the
    ///     rule follows the finger and ticks every few points.
    ///   - readout: the value to show for the x under the rule. Without it a date axis shows its time.
    func noopChart<X: Plottable & Comparable>(x: X.Type, snap: [X]? = nil, zoom: Bool = true,
                                              readout: ((X) -> NoopChartReadout?)? = nil) -> some View {
        modifier(NoopChartScrubber(snap: snap, readout: readout))
            .modifier(NoopChartZoom(enabled: zoom))
    }

    /// Zoom and pan alone, for any chart that is not a Swift Charts chart, or one with its own scrub.
    func noopChartZoom(maxZoom: CGFloat = 6) -> some View {
        modifier(NoopChartZoom(maxZoom: maxZoom))
    }
}

// MARK: Shared state between scrub and zoom

private struct NoopChartWindowKey: EnvironmentKey {
    /// The visible stretch of the chart, in the chart's own coordinates, while zoomed.
    static let defaultValue: ClosedRange<CGFloat>? = nil
}

private struct NoopChartScrubbingKey: EnvironmentKey {
    static let defaultValue: Binding<Bool>? = nil
}

private extension EnvironmentValues {
    var noopChartWindow: ClosedRange<CGFloat>? {
        get { self[NoopChartWindowKey.self] }
        set { self[NoopChartWindowKey.self] = newValue }
    }
    var noopChartScrubbing: Binding<Bool>? {
        get { self[NoopChartScrubbingKey.self] }
        set { self[NoopChartScrubbingKey.self] = newValue }
    }
}

// MARK: - Scrub

private struct NoopChartScrubber<X: Plottable & Comparable>: ViewModifier {
    let snap: [X]?
    let readout: ((X) -> NoopChartReadout?)?

    @State private var selected: X?
    @State private var lastTickX: CGFloat?
    @Environment(\.noopChartWindow) private var window
    @Environment(\.noopChartScrubbing) private var scrubbing
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.chartOverlay { proxy in
            GeometryReader { geo in
                let plot = proxy.plotFrame.map { geo[$0] } ?? CGRect(origin: .zero, size: geo.size)
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(press(proxy: proxy, plot: plot))
                    if let selected, let x = proxy.position(forX: selected) {
                        let text = readout?(selected) ?? defaultReadout(selected, proxy: proxy)
                        rule(at: plot.minX + x, plot: plot)
                        if let y = text?.y, let py = proxy.position(forY: y) {
                            Circle().fill(.white)
                                .frame(width: 9, height: 9)
                                .shadow(color: text?.tint ?? .white, radius: 6)
                                .position(x: plot.minX + x, y: plot.minY + py)
                                .allowsHitTesting(false)
                                .transition(.scale(scale: 0.4).combined(with: .opacity))
                        }
                        if let text {
                            bubble(text, at: plot.minX + x, plot: plot, width: geo.size.width)
                        }
                    }
                }
            }
        }
    }

    /// A short press arms the scrub, so a swipe past the chart still scrolls the page. Zoomed in, the
    /// chart is what the finger came for: it reads at once.
    private func press(proxy: ChartProxy, plot: CGRect) -> some Gesture {
        LongPressGesture(minimumDuration: window == nil ? 0.14 : 0, maximumDistance: 14)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                if scrubbing?.wrappedValue != true {
                    scrubbing?.wrappedValue = true
                    NoopHaptics.play(.grab)
                }
                guard let drag else { return }
                move(to: drag.location.x - plot.minX, proxy: proxy)
            }
            .onEnded { _ in
                scrubbing?.wrappedValue = false
                lastTickX = nil
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) { selected = nil }
            }
    }

    private func move(to x: CGFloat, proxy: ChartProxy) {
        let clamped = min(max(0, x), proxy.plotSize.width)
        if let snap, !snap.isEmpty {
            guard let nearest = snap.min(by: { a, b in
                abs((proxy.position(forX: a) ?? .infinity) - clamped) < abs((proxy.position(forX: b) ?? .infinity) - clamped)
            }) else { return }
            if nearest != selected {
                NoopHaptics.play(.tick)
                withAnimation(reduceMotion ? nil : .interactiveSpring(response: 0.18, dampingFraction: 0.86)) { selected = nearest }
            }
        } else if let value: X = proxy.value(atX: clamped) {
            // No readings to snap to: a detent every few points, so the drag still has texture.
            if lastTickX.map({ abs($0 - clamped) >= 9 }) ?? true {
                if lastTickX != nil { NoopHaptics.play(.tick) }
                lastTickX = clamped
            }
            selected = value
        }
    }

    private func rule(at x: CGFloat, plot: CGRect) -> some View {
        Rectangle()
            .fill(LinearGradient(colors: [.white.opacity(0.0), .white.opacity(0.55), .white.opacity(0.55), .white.opacity(0.0)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: 1, height: plot.height + 12)
            .position(x: x, y: plot.midY)
            .allowsHitTesting(false)
            .transition(.opacity)
    }

    private func bubble(_ text: NoopChartReadout, at px: CGFloat, plot: CGRect, width: CGFloat) -> some View {
        let visible = window ?? 0...width
        return NoopChartBubble(readout: text)
            .fixedSize()
            .alignmentGuide(.leading) { d in
                // Centred on the rule, held inside what is on screen.
                let left = px - d.width / 2
                return -min(max(left, visible.lowerBound + 2), visible.upperBound - d.width - 2)
            }
            .alignmentGuide(.top) { d in -(plot.minY - d.height - 6) }
            .allowsHitTesting(false)
            .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .bottom)))
    }

    /// A date axis says when; anything else needs the chart's own readout.
    private func defaultReadout(_ x: X, proxy: ChartProxy) -> NoopChartReadout? {
        guard let date = x as? Date else { return nil }
        let first: Date? = proxy.value(atX: 0)
        let last: Date? = proxy.value(atX: proxy.plotSize.width)
        let span = (last ?? date).timeIntervalSince(first ?? date)
        return NoopChartReadout(value: span < 36 * 3600
                                ? date.formatted(date: .omitted, time: .shortened)
                                : date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
    }
}

/// The value above a scrub's rule.
struct NoopChartBubble: View {
    let readout: NoopChartReadout

    var body: some View {
        VStack(spacing: 1) {
            Text(readout.value)
                .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                .foregroundStyle(NoopHTMLColor.ink)
                .monospacedDigit()
                .contentTransition(.numericText())
            if let detail = readout.detail {
                Text(detail)
                    .font(NoopHTMLFont.sans(NoopType.eyebrow))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(NoopHTMLColor.cardRaised, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
    }
}

// MARK: - Zoom and pan

private struct NoopChartZoom: ViewModifier {
    var enabled = true
    var maxZoom: CGFloat = 6

    @State private var width: CGFloat = 0
    @State private var zoom: CGFloat = 1
    /// The chart's x at the left edge of the frame, in zoomed points.
    @State private var offset: CGFloat = 0
    @State private var pinchStart: (zoom: CGFloat, offset: CGFloat)?
    @State private var panStart: CGFloat?
    @State private var scrubbing = false
    @State private var showsBar = false
    @State private var hitEdge = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var zoomed: Bool { zoom > 1.001 }
    private var maxOffset: CGFloat { max(0, width * (zoom - 1)) }

    func body(content: Content) -> some View {
        if !enabled {
            content
        } else {
            let base = NoopZoomLayout(zoom: zoom, offset: offset) {
                content
                    .environment(\.noopChartWindow, zoomed ? offset...(offset + width) : nil)
                    .environment(\.noopChartScrubbing, $scrubbing)
            }
            // Clip the sides only: a scrub's value may sit above the chart.
            .mask(Rectangle().padding(.vertical, -80))
            .overlay(alignment: .bottom) { if showsBar { bar } }
            .background(GeometryReader { g in Color.clear.onAppear { width = g.size.width }
                .onChange(of: g.size.width) { _, w in width = w } })
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture(count: 2).onEnded { reset() }, including: zoomed ? .all : .subviews)
            // One finger always reads the chart; moving it is two fingers' job (27 Oct 2026: a one-finger
            // pan took the drag that should have shown the reading).
            if #available(iOS 18.0, *) {
                base
                    .gesture(NoopTwoFingerPinch { phase in pinchChanged(phase) })
                    .gesture(NoopTwoFingerPan { phase in panChanged(phase) })
            } else {
                base.simultaneousGesture(magnify)
            }
        }
    }

    /// Where the window sits along the whole chart, while zoomed.
    private var bar: some View {
        let track = width * 0.36
        let thumb = max(14, track / zoom)
        let progress = maxOffset > 0 ? offset / maxOffset : 0
        return Capsule().fill(Color.white.opacity(0.10))
            .frame(width: track, height: 3)
            .overlay(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.55))
                    .frame(width: thumb, height: 3)
                    .offset(x: (track - thumb) * progress)
            }
            .offset(y: 10)
            .transition(.opacity)
            .allowsHitTesting(false)
    }

    /// A pinch zooms around its fingers and, as they move together, carries the chart with them.
    private func pinchChanged(_ phase: NoopTwoFingerPhase) {
        switch phase {
        case let .changed(scale, centroid, startCentroid):
            let start = pinchStart ?? (zoom, offset)
            if pinchStart == nil {
                pinchStart = start
                withAnimation(.easeOut(duration: 0.2)) { showsBar = true }
            }
            var next = start.zoom * scale
            // Past either end the pinch gives, a little, rather than stopping dead.
            if next > maxZoom { next = maxZoom + (next - maxZoom) * 0.2 }
            if next < 1 { next = 1 - (1 - next) * 0.25 }
            let atEdge = next >= maxZoom
            if atEdge && !hitEdge { NoopHaptics.play(.edge) }
            hitEdge = atEdge
            let point = (start.offset + startCentroid.x) / start.zoom
            zoom = next
            offset = clampOffset(point * next - centroid.x, rubber: true)
        case let .ended(velocityX):
            guard pinchStart != nil else { return }
            pinchStart = nil
            hitEdge = false
            if zoom < 1.12 { reset(); return }
            settle(velocityX: velocityX, zoomTo: min(zoom, maxZoom))
        }
    }

    /// Two fingers side by side move a zoomed chart, with momentum.
    private func panChanged(_ phase: NoopTwoFingerPhase) {
        guard zoomed || panStart != nil, pinchStart == nil else { return }
        switch phase {
        case let .changed(_, centroid, startCentroid):
            let start = panStart ?? offset
            if panStart == nil {
                panStart = start
                withAnimation(.easeOut(duration: 0.2)) { showsBar = true }
            }
            offset = clampOffset(start - (centroid.x - startCentroid.x), rubber: true)
        case let .ended(velocityX):
            guard panStart != nil else { return }
            panStart = nil
            settle(velocityX: velocityX, zoomTo: zoom)
        }
    }

    /// Carry on where the fingers were going (Apple's projection, deceleration 0.998) and settle
    /// inside the chart.
    private func settle(velocityX: CGFloat, zoomTo target: CGFloat) {
        let projected = offset - velocityX / 1000 * 0.998 / (1 - 0.998)
        let maxAtTarget = max(0, width * (target - 1))
        let land = min(max(0, projected), maxAtTarget)
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.9)) {
            zoom = target
            offset = land
        }
        hideBarSoon()
    }

    /// Before iOS 18: zoom alone, around where the pinch began.
    private var magnify: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .onChanged { value in
                pinchChanged(.changed(scale: value.magnification, centroid: value.startLocation,
                                      startCentroid: value.startLocation))
            }
            .onEnded { _ in pinchChanged(.ended(velocityX: 0)) }
    }

    private var spring: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.86)
    }

    private func clampOffset(_ x: CGFloat, rubber: Bool) -> CGFloat {
        if x < 0 { return rubber ? -rubberBand(-x) : 0 }
        if x > maxOffset { return rubber ? maxOffset + rubberBand(x - maxOffset) : maxOffset }
        return x
    }

    /// The further past the edge, the less the chart follows (Apple's rubber band, c = 0.55).
    private func rubberBand(_ over: CGFloat) -> CGFloat {
        let d = max(width, 1)
        return over * d * 0.55 / (d + 0.55 * over)
    }

    private func reset() {
        guard zoom != 1 || offset != 0 else { return }
        NoopHaptics.play(.settle)
        withAnimation(spring) { zoom = 1; offset = 0 }
        hideBarSoon()
    }

    private func hideBarSoon() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard pinchStart == nil, panStart == nil else { return }
            withAnimation(.easeOut(duration: 0.35)) { showsBar = false }
        }
    }
}

/// Lays its one child out `zoom` times as wide, shifted left by `offset`: the chart is drawn again at
/// the wider size rather than scaled as a picture.
private struct NoopZoomLayout: Layout {
    var zoom: CGFloat
    var offset: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(zoom, offset) }
        set { zoom = newValue.first; offset = newValue.second }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        subviews.first?.sizeThatFits(proposal) ?? .zero
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: CGPoint(x: bounds.minX - offset, y: bounds.minY), anchor: .topLeading,
                              proposal: ProposedViewSize(width: bounds.width * zoom, height: bounds.height))
    }
}

// MARK: - Two-finger gestures

enum NoopTwoFingerPhase {
    case changed(scale: CGFloat, centroid: CGPoint, startCentroid: CGPoint)
    case ended(velocityX: CGFloat)
}

/// A pinch that reports where the fingers are as well as how far apart: SwiftUI's own pinch only
/// says where it began. Recognises alongside the page's scroll, and needs two fingers, so a single
/// finger is always free to read the chart.
@available(iOS 18.0, *)
private struct NoopTwoFingerPinch: UIGestureRecognizerRepresentable {
    let onPhase: (NoopTwoFingerPhase) -> Void

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var start: CGPoint = .zero
        var last: (x: CGFloat, t: TimeInterval) = (0, 0)
        var velocity: CGFloat = 0
        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPinchGestureRecognizer {
        let g = UIPinchGestureRecognizer()
        g.delegate = context.coordinator
        return g
    }

    func handleUIGestureRecognizerAction(_ g: UIPinchGestureRecognizer, context: Context) {
        let c = context.coordinator
        let at = context.converter.localLocation
        let now = ProcessInfo.processInfo.systemUptime
        switch g.state {
        case .began:
            c.start = at
            c.last = (at.x, now)
            c.velocity = 0
            onPhase(.changed(scale: g.scale, centroid: at, startCentroid: at))
        case .changed:
            // A lifted finger moves the centroid in one jump; hold still until both are down again.
            guard g.numberOfTouches == 2 else { return }
            let dt = now - c.last.t
            if dt > 0 { c.velocity = c.velocity * 0.6 + (at.x - c.last.x) / dt * 0.4 }
            c.last = (at.x, now)
            onPhase(.changed(scale: g.scale, centroid: at, startCentroid: c.start))
        case .ended, .cancelled, .failed:
            onPhase(.ended(velocityX: c.velocity))
        default:
            break
        }
    }
}

/// Two fingers moving together, without pinching.
@available(iOS 18.0, *)
private struct NoopTwoFingerPan: UIGestureRecognizerRepresentable {
    let onPhase: (NoopTwoFingerPhase) -> Void

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var start: CGPoint = .zero
        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let g = UIPanGestureRecognizer()
        g.minimumNumberOfTouches = 2
        g.maximumNumberOfTouches = 2
        g.delegate = context.coordinator
        return g
    }

    func handleUIGestureRecognizerAction(_ g: UIPanGestureRecognizer, context: Context) {
        let at = context.converter.localLocation
        switch g.state {
        case .began:
            context.coordinator.start = at
            onPhase(.changed(scale: 1, centroid: at, startCentroid: at))
        case .changed:
            onPhase(.changed(scale: 1, centroid: at, startCentroid: context.coordinator.start))
        case .ended, .cancelled, .failed:
            onPhase(.ended(velocityX: context.converter.localVelocity?.x ?? 0))
        default:
            break
        }
    }
}

// MARK: - Stretches with no readings

/// Where a line's readings stop for a long while. A straight bright line across a month with no
/// readings reads as a month of steady values; the gap is drawn dim and dashed instead, with no fill
/// beneath it (27 Oct 2026).
enum NoopChartGaps {
    /// A silence counts as a gap past four times the usual spacing, and never under `minimum`
    /// (an hour by default; a day's trace passes a shorter one so a strap left off shows).
    static func threshold(_ dates: [Date], minimum: TimeInterval = 3600) -> TimeInterval {
        guard dates.count > 2 else { return .infinity }
        let steps = zip(dates.dropFirst(), dates).map { $0.timeIntervalSince($1) }.sorted()
        return max(steps[steps.count / 2] * 4, minimum)
    }

    /// Each reading's run: a new run starts after every gap.
    static func runs(_ dates: [Date], minimum: TimeInterval = 3600) -> [Int] {
        let limit = threshold(dates, minimum: minimum)
        var run = 0
        return dates.indices.map { i in
            if i > 0, dates[i].timeIntervalSince(dates[i - 1]) > limit { run += 1 }
            return run
        }
    }

    /// Runs over bucket indices: any skipped bucket is a gap.
    static func runs(indices: [Int]) -> [Int] {
        var run = 0
        return indices.indices.map { i in
            if i > 0, indices[i] - indices[i - 1] > 1 { run += 1 }
            return run
        }
    }

    /// How a gap is drawn on every chart: a dim dashed bridge, no fill under it.
    static let bridgeStyle = Color.white.opacity(0.22)
    static let bridgeStroke = StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [2, 4])
}

/// A line (and its fill) drawn run by run, with each gap bridged by a dim dashed line.
struct NoopGapAwareLine: ChartContent {
    let points: [(date: Date, value: Double)]
    let tint: Color
    /// The fill's floor; nil for no fill.
    var floor: Double? = nil
    var lineWidth: CGFloat = 2
    var interpolation: InterpolationMethod = .monotone
    /// Shortest silence drawn as a gap.
    var minimumGap: TimeInterval = 3600
    /// Styles in place of the tint, for a gradient line or fill.
    var lineStyle: AnyShapeStyle? = nil
    var areaStyle: AnyShapeStyle? = nil

    var body: some ChartContent {
        let runs = NoopChartGaps.runs(points.map(\.date), minimum: minimumGap)
        let bridges = runs.indices.dropFirst().filter { runs[$0] != runs[$0 - 1] }
        ForEach(points.indices, id: \.self) { i in
            if let floor {
                AreaMark(x: .value("Date", points[i].date), yStart: .value("Floor", floor),
                         yEnd: .value("Value", points[i].value), series: .value("Run", "r\(runs[i])"))
                    .foregroundStyle(areaStyle ?? AnyShapeStyle(LinearGradient(colors: [tint.opacity(0.26), tint.opacity(0)],
                                                                                startPoint: .top, endPoint: .bottom)))
                    .interpolationMethod(interpolation)
            }
            LineMark(x: .value("Date", points[i].date), y: .value("Value", points[i].value),
                     series: .value("Run", "r\(runs[i])"))
                .foregroundStyle(lineStyle ?? AnyShapeStyle(tint))
                .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .interpolationMethod(interpolation)
        }
        ForEach(bridges, id: \.self) { i in
            ForEach([i - 1, i], id: \.self) { j in
                LineMark(x: .value("Date", points[j].date), y: .value("Value", points[j].value),
                         series: .value("Run", "gap\(i)"))
                    .foregroundStyle(NoopChartGaps.bridgeStyle)
                    .lineStyle(NoopChartGaps.bridgeStroke)
            }
        }
    }
}

/// The same over bucket indices (a day per bucket, a week per bucket): a skipped bucket is a gap.
struct NoopGapAwareIndexLine: ChartContent {
    let points: [(i: Int, value: Double)]
    let tint: Color
    var floor: Double? = nil
    var lineWidth: CGFloat = 2
    var interpolation: InterpolationMethod = .monotone

    var body: some ChartContent {
        let runs = NoopChartGaps.runs(indices: points.map(\.i))
        let bridges = runs.indices.dropFirst().filter { runs[$0] != runs[$0 - 1] }
        ForEach(points.indices, id: \.self) { k in
            if let floor {
                AreaMark(x: .value("Bucket", points[k].i), yStart: .value("Floor", floor),
                         yEnd: .value("Value", points[k].value), series: .value("Run", "r\(runs[k])"))
                    .foregroundStyle(LinearGradient(colors: [tint.opacity(0.26), tint.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(interpolation)
            }
            LineMark(x: .value("Bucket", points[k].i), y: .value("Value", points[k].value),
                     series: .value("Run", "r\(runs[k])"))
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .interpolationMethod(interpolation)
        }
        ForEach(bridges, id: \.self) { k in
            ForEach([k - 1, k], id: \.self) { j in
                LineMark(x: .value("Bucket", points[j].i), y: .value("Value", points[j].value),
                         series: .value("Run", "gap\(k)"))
                    .foregroundStyle(NoopChartGaps.bridgeStyle)
                    .lineStyle(NoopChartGaps.bridgeStroke)
            }
        }
    }
}
