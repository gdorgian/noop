#if !os(watchOS)
import SwiftUI

// MARK: - Aura charts
//
// The chart vocabulary the six detail screens share. Each one is deliberately plain: no gridlines beyond
// a pair of hairlines, no axis furniture, no legend. A chart in Aura exists to be glanced at and, where
// it holds more than one day, tapped — every richer read lives in the sentence underneath it.

// MARK: Sleep bars

/// A week of nights with the user's own average struck through as a dashed line. Only the SELECTED night
/// shows its value, so the average line never strikes through a number.
public struct AuraSleepBars: View {
    public struct Night: Identifiable {
        public let id: Int
        public let day: String
        public let hours: Double

        public init(id: Int, day: String, hours: Double) {
            self.id = id
            self.day = day
            self.hours = hours
        }
    }

    private let nights: [Night]
    private let selected: Int
    private let average: Double
    private let ceiling: Double
    private let onSelect: (Int) -> Void

    /// - Parameter ceiling: the fixed top of the scale. Fixed rather than data-derived so a bad week does
    ///   not silently rescale itself into looking like a good one.
    public init(
        nights: [Night],
        selected: Int,
        average: Double,
        ceiling: Double = 8.4,
        onSelect: @escaping (Int) -> Void
    ) {
        self.nights = nights
        self.selected = selected
        self.average = average
        self.ceiling = ceiling
        self.onSelect = onSelect
    }

    private static let barArea: CGFloat = 112
    private static let dayLabelArea: CGFloat = 21

    public var body: some View {
        ZStack(alignment: .bottom) {
            averageLine
            HStack(alignment: .bottom, spacing: 7) {
                ForEach(nights) { night in
                    bar(night)
                }
            }
        }
        .frame(height: 158)
    }

    private var averageLine: some View {
        AuraDashedRule()
            .stroke(AuraPalette.accent.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            .frame(height: 1)
            .padding(.bottom, Self.dayLabelArea + AuraChartMath.barHeight(average, ceiling: ceiling, height: Self.barArea))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func bar(_ night: Night) -> some View {
        let isOn = night.id == selected
        return Button { onSelect(night.id) } label: {
            VStack(spacing: 7) {
                Spacer(minLength: 0)
                // The value rides above the bar for the selected night only.
                Text(isOn ? String(format: "%.1fh", night.hours) : "")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AuraPalette.textPrimary)
                    .padding(.horizontal, isOn ? 7 : 0)
                    .frame(height: 18)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isOn ? AuraPalette.rest.opacity(0.9) : .clear)
                    )
                    .fixedSize()
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isOn
                          ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "#A9B6E8"), Color(hex: "#6E7DB8")],
                                                         startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(Color.white.opacity(0.08)))
                    .frame(height: AuraChartMath.barHeight(night.hours, ceiling: ceiling, height: Self.barArea))
                Text(night.day)
                    .font(.system(size: 11.5, weight: isOn ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(isOn ? AuraPalette.textPrimary : AuraPalette.textDim)
                    .frame(height: Self.dayLabelArea - 7)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(night.day), \(String(format: "%.1f", night.hours)) hours"))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

/// A single horizontal rule, used as the dashed personal-average line.
public struct AuraDashedRule: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

// MARK: Hypnogram

/// One night's stages as a bar per sample. Stage 0 is awake and deliberately the shortest bar in the
/// dimmest colour — a wake-up should register as a gap, not as an event.
public struct AuraHypnogram: View {
    private let stages: [Int]

    public init(stages: [Int]) {
        self.stages = stages
    }

    /// Awake · Light · REM · Deep, in ascending bar height.
    public static let stageColors: [Color] = [
        Color.white.opacity(0.12),
        Color(hex: "#48527D"),
        Color(hex: "#6E7DB8"),
        Color(hex: "#9AA7E0"),
    ]
    public static let stageHeights: [CGFloat] = [20, 40, 60, 82]

    public var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(stages.enumerated()), id: \.offset) { _, stage in
                let step = min(max(stage, 0), Self.stageColors.count - 1)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Self.stageColors[step])
                    .frame(minWidth: 3)
                    .frame(height: Self.stageHeights[step])
            }
        }
        .frame(height: 84, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

// MARK: Stage breakdown

/// A labelled stage row with a proportional bar — Deep / REM / Light / Awake.
public struct AuraStageRow: View {
    private let name: String
    private let duration: String
    private let fraction: Double
    private let tint: Color

    public init(name: String, duration: String, fraction: Double, tint: Color) {
        self.name = name
        self.duration = duration
        self.fraction = fraction
        self.tint = tint
    }

    public var body: some View {
        VStack(spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(name)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(AuraPalette.textPrimary)
                Spacer(minLength: 8)
                Text(duration)
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(AuraPalette.textTertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous).fill(Color.white.opacity(0.06))
                    Capsule(style: .continuous)
                        .fill(tint)
                        .frame(width: geo.size.width * AuraChartMath.fraction(fraction, ceiling: 1))
                }
            }
            .frame(height: 7)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: Dot columns

/// Variability through the day as columns of dots, each column offset down from the top so the run of
/// columns traces a shape. Reads as a texture rather than a graph, which is the point — it carries
/// "steady / unsettled" without inviting anyone to read individual values off it.
public struct AuraDotColumns: View {
    private let counts: [Int]
    private let offsets: [Int]
    private let tint: Color
    private let ceiling: Int

    public init(counts: [Int], offsets: [Int], tint: Color, ceiling: Int = 6) {
        self.counts = counts
        self.offsets = offsets
        self.tint = tint
        self.ceiling = ceiling
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 3) {
            ForEach(Array(counts.enumerated()), id: \.offset) { index, count in
                VStack(spacing: 3) {
                    ForEach(0..<max(count, 0), id: \.self) { _ in
                        Capsule(style: .continuous)
                            .fill(tint)
                            .frame(height: 7)
                            .opacity(AuraChartMath.dotOpacity(count: count, ceiling: ceiling))
                    }
                }
                .padding(.top, CGFloat((index < offsets.count ? offsets[index] : 0) * 8))
            }
        }
        .frame(height: 96, alignment: .top)
        .accessibilityHidden(true)
    }
}

// MARK: Trend chart

/// The long-range chart: the user's own normal as a band, the series as a line, and a draggable crosshair
/// with a value bubble. Tapping anywhere on the plot moves the crosshair to the nearest point.
public struct AuraTrendChart: View {
    private let values: [Double]
    private let labels: [String]
    private let selected: Int
    private let window: ClosedRange<Double>
    private let normalRange: ClosedRange<Double>?
    private let bandWidth: Double
    private let onSelect: (Int) -> Void

    public init(
        values: [Double],
        labels: [String],
        selected: Int,
        window: ClosedRange<Double> = 30...92,
        normalRange: ClosedRange<Double>? = nil,
        bandWidth: Double = 9,
        onSelect: @escaping (Int) -> Void
    ) {
        self.values = values
        self.labels = labels
        self.selected = selected
        self.window = window
        self.normalRange = normalRange
        self.bandWidth = bandWidth
        self.onSelect = onSelect
    }

    public var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let points = AuraChartMath.points(values, in: size, window: window)
            let index = min(max(selected, 0), max(values.count - 1, 0))
            let point = points.indices.contains(index) ? points[index] : .zero

            ZStack(alignment: .topLeading) {
                gridlines(size)
                bandShape(size)
                linePath(points)
                    .stroke(AuraPalette.accent,
                            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                if !points.isEmpty {
                    crosshair(at: point, size: size)
                    bubble(at: point, size: size, index: index)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if let hit = AuraChartMath.nearestIndex(toX: value.location.x,
                                                               count: values.count, width: size.width),
                           hit != selected {
                            onSelect(hit)
                        }
                    }
            )
        }
        .frame(height: 140)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummary))
    }

    private var accessibilitySummary: String {
        guard let last = values.last, let low = values.min(), let high = values.max() else {
            return String(localized: "No trend data", bundle: .module)
        }
        return String(localized: "Trend, \(values.count) points, latest \(Int(last)), low \(Int(low)), high \(Int(high))",
                      bundle: .module)
    }

    private func gridlines(_ size: CGSize) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: size.height * 0.3)
            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
            Spacer()
            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
            Spacer().frame(height: size.height * 0.3)
        }
        .accessibilityHidden(true)
    }

    /// The band is the series ± a fixed width — "your own normal", not a statistical envelope.
    private func bandShape(_ size: CGSize) -> some View {
        if let normalRange {
            let lower = AuraChartMath.points([normalRange.lowerBound], in: size, window: window).first?.y ?? size.height
            let upper = AuraChartMath.points([normalRange.upperBound], in: size, window: window).first?.y ?? 0
            let top = min(lower, upper)
            let height = max(abs(lower - upper), 1)
            return Path(CGRect(x: 0, y: top, width: size.width, height: height))
                .fill(AuraPalette.accent.opacity(0.1))
        }
        let upper = AuraChartMath.points(values.map { $0 + bandWidth }, in: size, window: window)
        let lower = AuraChartMath.points(values.map { $0 - bandWidth }, in: size, window: window)
        var path = Path()
        if let first = upper.first {
            path.move(to: first)
            for p in upper.dropFirst() { path.addLine(to: p) }
            for p in lower.reversed() { path.addLine(to: p) }
            path.closeSubpath()
        }
        return path.fill(AuraPalette.accent.opacity(0.1))
    }

    private func linePath(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for p in points.dropFirst() { path.addLine(to: p) }
        return path
    }

    private func crosshair(at point: CGPoint, size: CGSize) -> some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: point.x, y: 0))
                p.addLine(to: CGPoint(x: point.x, y: size.height))
            }
            .stroke(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            Circle()
                .fill(AuraPalette.accent)
                .frame(width: 10, height: 10)
                .overlay(Circle().strokeBorder(AuraPalette.canvas, lineWidth: 3))
                .position(point)
        }
        .accessibilityHidden(true)
    }

    private func bubble(at point: CGPoint, size: CGSize, index: Int) -> some View {
        let below = AuraChartMath.tooltipGoesBelow(pointY: point.y, plotHeight: size.height)
        return VStack(spacing: 1) {
            Text(verbatim: "\(Int(values[index]))")
                .font(.system(size: 15, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(AuraPalette.textPrimary)
            Text(labels.indices.contains(index) ? labels[index] : "")
                .font(.system(size: 10.5))
                .foregroundStyle(AuraPalette.textQuiet)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "#1E2422"))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        )
        .fixedSize()
        .position(x: size.width * CGFloat(AuraChartMath.tooltipX(pointX: point.x, plotWidth: size.width)),
                  y: below ? point.y + 34 : point.y - 34)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: Simple bar strips

/// A row of bars with no labels — the rest-debt strip. Colour steps rather than a gradient, so "clear",
/// "some" and "real" debt are three readable states instead of a continuum nobody can decode.
public struct AuraDebtBars: View {
    private let values: [Double]
    private let ceiling: Double

    public init(values: [Double], ceiling: Double = 2.6) {
        self.values = values
        self.ceiling = ceiling
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color(for: value))
                    .frame(height: AuraChartMath.barHeight(value, ceiling: ceiling, height: 72, minimum: 4))
            }
        }
        .frame(height: 82, alignment: .bottom)
        .accessibilityHidden(true)
    }

    private func color(for value: Double) -> Color {
        if value > 1.5 { return AuraPalette.rest }
        if value > 0.5 { return AuraPalette.rest.opacity(0.5) }
        return AuraPalette.rest.opacity(0.18)
    }
}

/// A labelled week of effort bars, with today picked out.
public struct AuraWeekBars: View {
    private let values: [Double]
    private let days: [String]
    private let highlighted: Int
    private let ceiling: Double

    public init(values: [Double], days: [String], highlighted: Int, ceiling: Double = 18) {
        self.values = values
        self.days = days
        self.highlighted = highlighted
        self.ceiling = ceiling
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 7) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                let isOn = index == highlighted
                VStack(spacing: 8) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isOn
                              ? AnyShapeStyle(LinearGradient(colors: [AuraPalette.effort, Color(hex: "#F0742C")],
                                                             startPoint: .top, endPoint: .bottom))
                              : AnyShapeStyle(Color.white.opacity(0.09)))
                        .frame(height: AuraChartMath.barHeight(value, ceiling: ceiling, height: 78))
                    Text(days.indices.contains(index) ? days[index] : "")
                        .font(.system(size: 11, weight: isOn ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(isOn ? AuraPalette.textPrimary : AuraPalette.textDim)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 104, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

// MARK: Typical-range bar

/// Where a driver sits inside the user's own range, with a tick for their baseline. The track runs warm
/// to cool left to right, so "further right" always means "more recovered" no matter which driver it is.
public struct AuraRangeBar: View {
    private let position: Double
    private let baseline: Double
    private let tint: Color

    public init(position: Double, baseline: Double, tint: Color) {
        self.position = position
        self.baseline = baseline
        self.tint = tint
    }

    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .topLeading) {
                Capsule(style: .continuous)
                    .fill(LinearGradient(
                        stops: [
                            .init(color: Color(hex: "#E0705C").opacity(0.35), location: 0),
                            .init(color: AuraPalette.effort.opacity(0.35), location: 0.45),
                            .init(color: AuraPalette.accent.opacity(0.4), location: 1),
                        ],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(height: 4)
                    .offset(y: 10)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 2, height: 16)
                    .offset(x: width * CGFloat(AuraChartMath.rangePosition(baseline) / 100) - 1, y: 4)

                Circle()
                    .fill(tint)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(tint.opacity(0.18), lineWidth: 4))
                    .offset(x: width * CGFloat(AuraChartMath.rangePosition(position) / 100) - 7, y: 5)
            }
        }
        .frame(height: 24)
        .accessibilityHidden(true)
    }
}

// MARK: Effort slider

/// Today's effort against target, on a cool-to-hot track. The knob is a read-out, not a control — effort
/// is measured, not chosen — so it carries no gesture.
public struct AuraEffortSlider: View {
    private let fraction: Double
    private let stops: [(label: String, position: Double)]

    public init(fraction: Double, stops: [(label: String, position: Double)]) {
        self.fraction = fraction
        self.stops = stops
    }

    public var body: some View {
        VStack(spacing: 16) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(LinearGradient(
                            stops: [
                                .init(color: Color(hex: "#0B6FA8"), location: 0),
                                .init(color: AuraPalette.accent, location: 0.34),
                                .init(color: AuraPalette.effort, location: 0.68),
                                .init(color: Color(hex: "#F0742C"), location: 1),
                            ],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(height: 8)

                    ForEach(Array(stops.enumerated()), id: \.offset) { _, stop in
                        Circle()
                            .fill(AuraPalette.canvas.opacity(0.5))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.7), lineWidth: 2))
                            .frame(width: 12, height: 12)
                            .opacity(abs(stop.position / 100 - fraction) < 0.02 ? 0 : 1)
                            .offset(x: width * CGFloat(stop.position / 100) - 6)
                    }

                    Circle()
                        .fill(AuraPalette.textPrimary)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().strokeBorder(AuraPalette.canvas.opacity(0.9), lineWidth: 4))
                        .shadow(color: .black.opacity(0.5), radius: 6, y: 4)
                        .offset(x: width * CGFloat(AuraChartMath.fraction(fraction, ceiling: 1)) - 11)
                }
                .frame(height: 22)
            }
            .frame(height: 22)

            HStack {
                ForEach(Array(stops.enumerated()), id: \.offset) { index, stop in
                    let isOn = abs(stop.position / 100 - fraction) < 0.06
                    Text(stop.label)
                        .font(.system(size: 11.5, weight: isOn ? .semibold : .medium))
                        .foregroundStyle(isOn ? AuraPalette.textPrimary : AuraPalette.textQuiet)
                    if index < stops.count - 1 { Spacer(minLength: 4) }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: Battery ring

/// The band's charge as a ring. Uses the same arc-from-the-top convention as the orb's gauge, so the two
/// circular read-outs in the app agree with each other.
public struct AuraBatteryRing: View {
    private let fraction: Double
    private let percentText: String
    private let caption: String

    public init(fraction: Double, percentText: String, caption: String) {
        self.fraction = fraction
        self.percentText = percentText
        self.caption = caption
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(AngularGradient(
                    stops: [
                        .init(color: Color(hex: "#0B6FA8"), location: 0),
                        .init(color: AuraPalette.accent, location: AuraChartMath.batterySweep(fraction: fraction) / 360),
                        .init(color: Color.white.opacity(0.07),
                              location: AuraChartMath.batterySweep(fraction: fraction) / 360),
                        .init(color: Color.white.opacity(0.07), location: 1),
                    ],
                    center: .center,
                    angle: .degrees(180)))
            Circle()
                .fill(AuraPalette.card)
                .padding(11)
            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(percentText)
                        .font(.system(size: 48, weight: .ultraLight, design: .rounded).monospacedDigit())
                        .foregroundStyle(AuraPalette.textPrimary)
                    Text(verbatim: "%")
                        .font(.system(size: 17))
                        .foregroundStyle(AuraPalette.textQuiet)
                }
                Text(caption)
                    .font(.system(size: 11.5))
                    .foregroundStyle(AuraPalette.textQuiet)
            }
        }
        .frame(width: 172, height: 172)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Band battery \(percentText) percent, \(caption)"))
    }
}
#endif
