#if os(iOS)
import SwiftUI
import StrandDesign

// MARK: - Aura Trends
//
// The only screen where a chart is the point. Even so it closes with "the read" — a paragraph that says
// what the shape means — because a line going up is not, on its own, an instruction.

struct AuraTrendsView: View {
    private let reading: AuraTrendsReading
    /// Trends is where a multi-week view belongs, so the two age readings hang off it rather than
    /// taking one of the five tab slots.
    private let onOpenAge: () -> Void

    @State private var range: AuraTrendsReading.Range = .sixWeeks

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var motion = NoopMotionState.shared

    private var poseStill: Bool { motion.poseStill(reduceMotion) }

    init(reading: AuraTrendsReading, onOpenAge: @escaping () -> Void = {}) {
        self.reading = reading
        self.onOpenAge = onOpenAge
    }

    private var series: AuraTrendsReading.Series { reading.series(for: range) }

    var body: some View {
        VStack(spacing: 9) {
            agePortal
            periodSelector
            verdictCard
            signalRows
            coverageCard
            overviewCard
            debtCard

            Text(String(localized: "Noop only calls a direction when the recorded values support it. Short windows stay descriptive."))
                .font(TrendsDesign.ui(11.5))
                .lineSpacing(3)
                .foregroundStyle(AuraPalette.textDim)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
                .padding(.top, 3)
        }
    }

    // MARK: Body Age portal

    /// Trends currently receives no `AuraAgeReading`. The handoff puts Body Age in this hero, but
    /// repeating a number from another store would risk showing a different weekly snapshot. This keeps
    /// the supplied green-aura composition while making the whole hero the door to the coherent snapshot.
    private var agePortal: some View {
        Button(action: onOpenAge) {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(localized: "Body Age"))
                        .font(TrendsDesign.ui(10, weight: .semibold))
                        .tracking(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(AuraPalette.textTertiary)
                    Spacer()
                    Text(String(localized: "Updated weekly"))
                        .font(TrendsDesign.ui(10.5))
                        .foregroundStyle(AuraPalette.textDim)
                }

                TrendsAgeAura(reduceMotion: poseStill)
                    .frame(height: 238)
                    .overlay {
                        VStack(spacing: 7) {
                            Text(String(localized: "Your ages"))
                                .font(TrendsDesign.number(34, weight: .light))
                                .foregroundStyle(AuraPalette.textPrimary)
                            Text(String(localized: "VIEW LATEST"))
                                .font(TrendsDesign.ui(10, weight: .semibold))
                                .tracking(2)
                                .foregroundStyle(TrendsDesign.mint)
                        }
                    }

                HStack(spacing: 10) {
                    Text(String(localized: "Body Age, Fitness Age, exact drivers and how they are figured"))
                        .font(TrendsDesign.ui(12.5))
                        .lineSpacing(2)
                        .foregroundStyle(AuraPalette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TrendsDesign.mint)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 54)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AuraPalette.card)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(AuraPalette.cardBorder, lineWidth: 0.5)
                        }
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens your weekly Body Age and Fitness Age estimates"))
    }

    // MARK: Period and verdict

    private var periodSelector: some View {
        HStack(spacing: 4) {
            ForEach(AuraTrendsReading.Range.allCases) { option in
                let selected = option == range
                Button {
                    withAnimation(NoopMotion.gated(NoopMotion.value, reduced: poseStill)) {
                        range = option
                    }
                } label: {
                    Text(option.label)
                        .font(TrendsDesign.ui(12, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? AuraPalette.textPrimary : AuraPalette.textQuiet)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(selected ? Color.white.opacity(0.10) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
                }
        )
        .padding(.top, 5)
    }

    private var verdictCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "Charge direction"))
                    .font(TrendsDesign.ui(10, weight: .semibold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(AuraPalette.accent)
                Spacer()
                Text(series.chargeNote)
                    .font(TrendsDesign.ui(10.5))
                    .foregroundStyle(AuraPalette.textDim)
            }

            Text(reading.headline)
                .font(TrendsDesign.number(32, weight: .light))
                .tracking(-1)
                .foregroundStyle(AuraPalette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if series.values.count > 1 {
                Sparkline(
                    values: series.values,
                    gradient: Gradient(colors: [AuraPalette.accent, AuraPalette.accent]),
                    lineWidth: 1.9,
                    showsArea: false,
                    showsHead: true,
                    showsHover: false
                )
                .frame(height: 52)
                .accessibilityHidden(true)
            }

            Text(series.read)
                .font(TrendsDesign.ui(13.5))
                .lineSpacing(4)
                .foregroundStyle(Color(hex: "#B4C9BE"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#14201B"), AuraPalette.card],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(TrendsDesign.ageGreen.opacity(0.22), lineWidth: 0.5)
                }
        )
    }

    private var overviewCard: some View {
        HStack(spacing: 9) {
            compactStat(
                label: String(localized: "30-day avg Charge"),
                value: reading.averageCharge,
                unit: reading.averageCharge == "—" ? "" : "%",
                tint: AuraPalette.accent
            )
            compactStat(
                label: String(localized: "30-day avg sleep"),
                value: reading.averageSleep,
                unit: reading.averageSleep == "—" ? "" : "h",
                tint: AuraPalette.rest
            )
        }
    }

    private func compactStat(label: String, value: String, unit: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(TrendsDesign.ui(10, weight: .semibold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(AuraPalette.textFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(TrendsDesign.number(28, weight: .light))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                if !unit.isEmpty {
                    Text(unit)
                        .font(TrendsDesign.ui(11))
                        .foregroundStyle(AuraPalette.textFaint)
                }
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AuraPalette.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(AuraPalette.cardBorder, lineWidth: 0.5)
                }
        )
    }

    // MARK: Signal cards

    private var signalRows: some View {
        VStack(spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "Last 30 days"))
                    .font(TrendsDesign.ui(10, weight: .semibold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(AuraPalette.textFaint)
                Spacer()
                Text(String(localized: "Latest recorded values"))
                    .font(TrendsDesign.ui(10.5))
                    .foregroundStyle(AuraPalette.textDim)
            }
            .padding(.horizontal, 2)

            ForEach(reading.metrics) { metric in
                metricCard(metric)
            }
        }
    }

    private func metricCard(_ metric: AuraTrendsReading.Metric) -> some View {
        let comparison = metricComparison(metric)
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(metric.name)
                        .font(TrendsDesign.ui(13))
                        .foregroundStyle(AuraPalette.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(metric.value)
                            .font(TrendsDesign.number(26, weight: .light))
                            .monospacedDigit()
                            .foregroundStyle(AuraPalette.textPrimary)
                        Text(metric.value == "—" ? "" : metric.unit)
                            .font(TrendsDesign.ui(11))
                            .foregroundStyle(AuraPalette.textFaint)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 6) {
                    if let comparison {
                        Text(comparison.label)
                            .font(TrendsDesign.ui(10.5, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(comparison.tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(comparison.tint.opacity(0.11), in: Capsule())
                    } else {
                        Text(String(localized: "Not enough data"))
                            .font(TrendsDesign.ui(10.5, weight: .medium))
                            .foregroundStyle(AuraPalette.textDim)
                    }

                    if metric.series.count > 1 {
                        Sparkline(
                            values: metric.series,
                            gradient: Gradient(colors: [metric.tint, metric.tint]),
                            lineWidth: 1.9,
                            showsArea: false,
                            showsHead: true,
                            showsHover: false
                        )
                        .frame(width: 108, height: 34)
                        .accessibilityHidden(true)
                    }
                }
            }

            Text(signalRead(metric))
                .font(TrendsDesign.ui(11.5))
                .lineSpacing(2)
                .foregroundStyle(AuraPalette.textQuiet)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AuraPalette.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(AuraPalette.cardBorder, lineWidth: 0.5)
                }
        )
        .accessibilityElement(children: .combine)
    }

    private func metricComparison(_ metric: AuraTrendsReading.Metric) -> (label: String, tint: Color)? {
        guard let first = metric.series.first, let last = metric.series.last, metric.series.count > 1 else {
            return nil
        }
        let delta = last - first
        let decimals = metric.value.contains(".") ? 1 : 0
        let format = decimals == 0 ? "%+.0f" : "%+.1f"
        let label = String(format: format, delta) + (metric.unit.isEmpty ? "" : " \(metric.unit)")
        return (label, abs(delta) < 0.000_1 ? AuraPalette.textQuiet : metric.tint)
    }

    private func signalRead(_ metric: AuraTrendsReading.Metric) -> String {
        guard metric.series.count > 1 else {
            return metric.series.isEmpty
                ? String(localized: "No recorded values in the last 30 days.")
                : String(localized: "One recorded value; a direction would not be meaningful yet.")
        }
        return String(localized: "Change from the first to the latest of \(metric.series.count) recorded values. Noop does not infer a cause from this line.")
    }

    // MARK: Coverage

    private var coverageCard: some View {
        let shown = min(series.values.count, 84)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "Recorded Charge"))
                    .font(TrendsDesign.ui(10, weight: .semibold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(AuraPalette.textFaint)
                Spacer()
                Text(String(localized: "\(series.values.count) readings"))
                    .font(TrendsDesign.ui(11))
                    .monospacedDigit()
                    .foregroundStyle(AuraPalette.textDim)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 12), spacing: 4) {
                ForEach(0..<84, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(index >= 84 - shown ? TrendsDesign.ageGreen.opacity(0.72) : Color.white.opacity(0.055))
                        .frame(height: 8)
                }
            }
            .accessibilityHidden(true)

            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(TrendsDesign.ageGreen.opacity(0.72)).frame(width: 9, height: 9)
                Text(String(localized: "one recorded value"))
                    .font(TrendsDesign.ui(11))
                    .foregroundStyle(AuraPalette.textQuiet)
            }

            Text(String(localized: "The grid counts up to the latest 84 available readings. It does not invent dates for gaps that are not present in this snapshot."))
                .font(TrendsDesign.ui(11.5))
                .lineSpacing(3)
                .foregroundStyle(AuraPalette.textQuiet)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AuraPalette.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(AuraPalette.cardBorder, lineWidth: 0.5)
                }
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: Rest debt

    private var debtCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "Rest debt"))
                    .font(TrendsDesign.ui(10, weight: .semibold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(AuraPalette.textFaint)
                Spacer()
                Text(reading.debtVerdict)
                    .font(TrendsDesign.ui(11.5, weight: .medium))
                    .foregroundStyle(AuraPalette.rest)
            }
            if reading.debt.isEmpty {
                Text(String(localized: "No nights with sleep data yet."))
                    .font(TrendsDesign.ui(13.5))
                    .foregroundStyle(AuraPalette.textQuiet)
                    .frame(maxWidth: .infinity, minHeight: 82, alignment: .center)
            } else {
                AuraDebtBars(values: reading.debt)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AuraPalette.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(AuraPalette.cardBorder, lineWidth: 0.5)
                }
        )
    }
}

// MARK: - Handoff graphic

private enum TrendsDesign {
    static let ageGreen = Color(hex: "#2ECC80")
    static let mint = Color(hex: "#8FEFC0")

    static func number(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Outfit", size: size).weight(weight)
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Instrument Sans", size: size).weight(weight)
    }
}

private struct TrendsAgeAura: View {
    let reduceMotion: Bool
    @State private var breathing = false
    @State private var spinning = false

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [TrendsDesign.ageGreen.opacity(0.30), TrendsDesign.ageGreen.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: side * 0.55
                        )
                    )
                    .frame(width: side * 1.18, height: side * 1.18)
                    .blur(radius: 16)
                    .scaleEffect(breathing ? 1.04 : 0.97)

                TrendsAgeBlob()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color(hex: "#080B0A"), location: 0),
                                .init(color: Color(hex: "#080B0A"), location: 0.33),
                                .init(color: TrendsDesign.ageGreen.opacity(0.10), location: 0.42),
                                .init(color: TrendsDesign.ageGreen.opacity(0.40), location: 0.58),
                                .init(color: Color(hex: "#30CE84").opacity(0.82), location: 0.72),
                                .init(color: Color(hex: "#9EF0CC").opacity(0.42), location: 0.86),
                                .init(color: TrendsDesign.ageGreen.opacity(0), location: 1),
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: side * 0.50
                        )
                    )
                    .frame(width: side * 0.92, height: side * 0.92)
                    .blur(radius: 4.5)
                    .rotationEffect(.degrees(breathing ? 5 : -4))

                TrendsAgeBlob()
                    .fill(
                        RadialGradient(
                            colors: [Color.clear, TrendsDesign.mint.opacity(0.15), Color.clear],
                            center: .center,
                            startRadius: side * 0.18,
                            endRadius: side * 0.49
                        )
                    )
                    .frame(width: side * 0.98, height: side * 0.98)
                    .blur(radius: 9)
                    .rotationEffect(.degrees(breathing ? -9 : 7))

                TrendsAgeSpecks()
                    .frame(width: side * 0.90, height: side * 0.90)
                    .rotationEffect(.degrees(spinning ? 360 : 0))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                breathing = true
            }
            withAnimation(.linear(duration: 52).repeatForever(autoreverses: false)) {
                spinning = true
            }
        }
        .accessibilityHidden(true)
    }
}

private struct TrendsAgeBlob: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.025))
        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.04, y: rect.midY - rect.height * 0.04),
            control1: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.28)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX + rect.width * 0.02, y: rect.maxY - rect.height * 0.02),
            control1: CGPoint(x: rect.maxX - rect.width * 0.01, y: rect.maxY - rect.height * 0.19),
            control2: CGPoint(x: rect.maxX - rect.width * 0.23, y: rect.maxY)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.05, y: rect.midY + rect.height * 0.03),
            control1: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.25)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.025),
            control1: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.25),
            control2: CGPoint(x: rect.minX + rect.width * 0.23, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

private struct TrendsAgeSpecks: View {
    private static let points: [(CGFloat, CGFloat, CGFloat, Double)] = [
        (0.18,0.23,1.5,0.72),(0.28,0.12,1.0,0.45),(0.41,0.08,1.4,0.70),(0.59,0.12,0.9,0.55),
        (0.73,0.18,1.7,0.75),(0.84,0.31,1.1,0.50),(0.90,0.47,1.5,0.62),(0.82,0.63,0.8,0.48),
        (0.75,0.79,1.6,0.72),(0.59,0.88,1.1,0.57),(0.43,0.91,1.8,0.74),(0.29,0.82,0.9,0.50),
        (0.16,0.72,1.5,0.66),(0.10,0.55,1.0,0.54),(0.12,0.38,1.8,0.78),(0.34,0.27,0.7,0.50),
        (0.65,0.27,0.8,0.55),(0.71,0.47,1.0,0.62),(0.58,0.70,0.8,0.50),(0.35,0.67,1.0,0.58),
        (0.25,0.48,0.7,0.45),(0.46,0.19,0.8,0.56),(0.80,0.52,0.7,0.46),(0.49,0.82,0.9,0.52),
    ]

    var body: some View {
        Canvas { context, size in
            for point in Self.points {
                let radius = point.2
                let rect = CGRect(
                    x: size.width * point.0 - radius,
                    y: size.height * point.1 - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.fill(Path(ellipseIn: rect), with: .color(TrendsDesign.mint.opacity(point.3)))
            }
        }
    }
}

// MARK: - Reading

struct AuraTrendsReading {
    struct Metric: Identifiable {
        let id: String
        let name: String
        let value: String
        let unit: String
        let symbol: String
        let tint: Color
        let series: [Double]
    }

    enum Range: String, CaseIterable, Identifiable, Hashable {
        case sixWeeks
        case sixMonths
        case year

        var id: String { rawValue }

        var label: String {
            switch self {
            case .sixWeeks:  return String(localized: "6 weeks")
            case .sixMonths: return String(localized: "6 months")
            case .year:      return String(localized: "1 year")
            }
        }
    }

    struct Series {
        let values: [Double]
        /// One label per point, shown in the crosshair bubble.
        let labels: [String]
        /// Four evenly-spaced axis ticks.
        let axis: [String]
        let read: String
        /// The wearer's trailing-30-day middle 50% Charge range.
        let normalRange: ClosedRange<Double>?
        let chargeNote: String
    }

    let sixWeeks: Series
    let sixMonths: Series
    let year: Series
    let debt: [Double]
    let debtVerdict: String
    let headline: String
    let averageCharge: String
    let averageSleep: String
    let metrics: [Metric]

    func series(for range: Range) -> Series {
        switch range {
        case .sixWeeks:  return sixWeeks
        case .sixMonths: return sixMonths
        case .year:      return year
        }
    }

    #if DEBUG
    static let prototype = AuraTrendsReading(
        sixWeeks: Series(
            values: [62, 71, 58, 49, 66, 74, 81, 77, 64, 55, 68, 79, 84, 88],
            labels: ["3 Aug", "4 Aug", "5 Aug", "6 Aug", "7 Aug", "8 Aug", "9 Aug",
                     "10 Aug", "11 Aug", "12 Aug", "13 Aug", "14 Aug", "15 Aug",
                     String(localized: "Today")],
            axis: ["3 Aug", "7 Aug", "11 Aug", String(localized: "Today")],
            read: String(localized: "Two weeks of steady climbing, and the last three days are your best of the month. You’ve earned a hard session — take it today, not Monday."),
            normalRange: 58...76,
            chargeNote: String(localized: "Your normal 58–76")
        ),
        sixMonths: Series(
            values: [48, 55, 61, 52, 44, 58, 66, 71, 63, 57, 49, 62, 70, 78, 74, 66, 59, 68, 75, 82, 88],
            labels: ["Wk 1", "Wk 1", "Wk 1", "Wk 1", "Wk 2", "Wk 2", "Wk 2", "Wk 2",
                     "Wk 3", "Wk 3", "Wk 3", "Wk 3", "Wk 3", "Wk 4", "Wk 4", "Wk 4",
                     "Wk 4", "Wk 5", "Wk 5", "Wk 5", String(localized: "Today")],
            axis: ["18 Jul", "26 Jul", "4 Aug", String(localized: "Today")],
            read: String(localized: "The dip mid-month was three short nights, not training. Once sleep came back, so did everything else."),
            normalRange: 56...75,
            chargeNote: String(localized: "Your normal 56–75")
        ),
        year: Series(
            values: [40, 46, 52, 49, 58, 63, 57, 51, 62, 70, 66, 59, 68, 74, 71, 65, 72, 79, 84, 88],
            labels: ["May", "May", "May", "Jun", "Jun", "Jun", "Jun", "Jun",
                     "Jul", "Jul", "Jul", "Jul", "Jul", "Aug", "Aug", "Aug",
                     "Aug", "Aug", "Aug", String(localized: "Today")],
            axis: ["19 May", "18 Jun", "18 Jul", String(localized: "Today")],
            read: String(localized: "Up 18 points since May with fewer swings. Whatever you changed in June, keep doing it."),
            normalRange: 55...74,
            chargeNote: String(localized: "Your normal 55–74")
        ),
        debt: [0.4, 1.1, 0.2, 1.8, 2.4, 1.2, 0.6, 0, 0.9, 1.6, 0.8, 0.3, 0, 0],
        debtVerdict: String(localized: "Clear for 2 days"),
        headline: String(localized: "Where you’re trending"),
        averageCharge: "68",
        averageSleep: "6.8",
        metrics: [
            Metric(id: "hrv", name: String(localized: "Variability"), value: "56", unit: "ms",
                   symbol: "waveform.path.ecg", tint: AuraPalette.accent,
                   series: [44, 48, 46, 51, 49, 54, 53, 56]),
            Metric(id: "rhr", name: String(localized: "Resting heart rate"), value: "58", unit: "bpm",
                   symbol: "heart", tint: AuraPalette.effort,
                   series: [61, 60, 62, 59, 58, 59, 58]),
            Metric(id: "resp", name: String(localized: "Breathing"), value: "14.2", unit: "rpm",
                   symbol: "lungs", tint: AuraPalette.rest,
                   series: [14.5, 14.2, 14.3, 14.1, 14.2]),
            Metric(id: "sleep", name: String(localized: "Sleep"), value: "7.2", unit: "h",
                   symbol: "moon", tint: AuraPalette.rest,
                   series: [5.5, 7.3, 5.5, 6.1, 7.0, 6.6, 7.2]),
        ]
    )
    #endif
}
#endif
