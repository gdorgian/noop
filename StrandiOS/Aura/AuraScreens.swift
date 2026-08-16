import SwiftUI
import StrandDesign
import WhoopStore

// MARK: - The remaining four Aura tabs
//
// Rest / Charge / Effort / Trends, transcribed from the Aura · dark direction. Same rule as Today: the
// layout is the design's, the values are NOOP's, and anything the app cannot yet compute is left visibly
// empty rather than filled with a plausible number.

// MARK: - Shared pieces

/// The page header every Aura tab carries: a greeting line over a headline, per the design's HEAD map.
struct AuraHeader: View {
    let greet: String
    let headline: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(greet).font(Aura.text(13.5)).foregroundStyle(Aura.inkCoach)
            Text(headline)
                .font(Aura.display(23, .regular)).kerning(-0.46)
                .foregroundStyle(Aura.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
    }
}

/// A standard Aura card: `#141817`, .5pt hairline, 24pt radius.
struct AuraCard<Content: View>: View {
    var radius: CGFloat = Aura.cardRadius
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Aura.card)
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Aura.cardBorder, lineWidth: 0.5))
            )
    }
}

/// A big stat: a label over an Outfit numeral and its unit. The design's `Avg sleep 6.8 h` block.
struct AuraStat: View {
    let label: String
    let value: String
    let unit: String
    var size: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(Aura.text(11.5)).foregroundStyle(Aura.inkMuted)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(Aura.display(size, .light)).kerning(-size * 0.035)
                    .foregroundStyle(Aura.ink)
                if !unit.isEmpty {
                    Text(unit).font(Aura.text(13)).foregroundStyle(Aura.inkFaint)
                }
            }
        }
    }
}

/// The design's scroll body: page padding, tab-bar clearance, and the standard 12pt card gap.
struct AuraScroll<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(spacing: Aura.cardGap) {
                content()
                Color.clear.frame(height: 96)   // floating tab-bar clearance
            }
            .padding(.horizontal, Aura.screenHPadding)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Rest

struct AuraRestView: View {
    @EnvironmentObject var repo: Repository

    private var nights: [DailyMetric] { Array(repo.days.suffix(7)) }
    private var last: DailyMetric? { repo.days.last(where: { ($0.totalSleepMin ?? 0) > 0 }) }
    private var avgHours: Double? {
        let vals = nights.compactMap { $0.totalSleepMin }.filter { $0 > 0 }
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / Double(vals.count) / 60
    }

    var body: some View {
        AuraScroll {
            AuraHeader(greet: String(localized: "Last night"),
                       headline: last?.totalSleepMin.map {
                           String(localized: "You slept \(Int($0) / 60)h \(Int($0) % 60)m")
                       } ?? String(localized: "No night recorded"))

            HStack(spacing: 8) {
                AuraCard { AuraStat(label: String(localized: "Avg sleep"),
                                    value: avgHours.map { String(format: "%.1f", $0) } ?? "—", unit: "h") }
                AuraCard { AuraStat(label: String(localized: "Deep sleep"),
                                    value: last?.deepMin.map { String(format: "%.1f", $0 / 60) } ?? "—",
                                    unit: "h") }
            }

            // Week bars against the wearer's own average — the design draws the average as a dashed rule
            // across the bars, which is what makes a single night readable as short or long FOR THEM.
            AuraCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(String(localized: "This week")).font(Aura.text(13, .medium))
                            .foregroundStyle(Aura.ink)
                        Spacer()
                        Text(String(localized: "Tap a night")).font(Aura.text(11.5))
                            .foregroundStyle(Aura.inkFaint)
                    }
                    AuraNightBars(nights: nights, average: avgHours)
                        .frame(height: 110)
                }
            }

            // Stage split. Empty rather than estimated when a night carries no staged segments.
            AuraCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "Stages")).font(Aura.text(13, .medium))
                        .foregroundStyle(Aura.ink)
                    stageRow(String(localized: "Deep"), last?.deepMin, Color(hex: "#8B99D6"))
                    stageRow(String(localized: "REM"), last?.remMin, Aura.restored)
                    stageRow(String(localized: "Light"), last?.lightMin, Color(hex: "#4E9C86"))
                }
            }
        }
    }

    private func stageRow(_ name: String, _ minutes: Double?, _ tint: Color) -> some View {
        HStack(spacing: 10) {
            Circle().fill(tint).frame(width: 7, height: 7)
            Text(name).font(Aura.text(13)).foregroundStyle(Aura.inkSoft)
            Spacer()
            Text(minutes.map { "\(Int($0) / 60)h \(Int($0) % 60)m" } ?? "—")
                .font(Aura.display(15, .regular)).foregroundStyle(Aura.ink)
        }
    }
}

/// The week's nights as bars with the personal average drawn across them.
struct AuraNightBars: View {
    let nights: [DailyMetric]
    let average: Double?

    var body: some View {
        GeometryReader { geo in
            let maxH = max(nights.compactMap { $0.totalSleepMin }.max() ?? 480, 480)
            ZStack(alignment: .bottom) {
                if let average {
                    let y = geo.size.height * (1 - CGFloat(average * 60 / maxH))
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(Aura.inkFaint.opacity(0.8))
                }
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(nights.enumerated()), id: \.offset) { _, n in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Aura.restAccent)
                                .frame(height: max(4, geo.size.height * CGFloat((n.totalSleepMin ?? 0) / maxH) - 18))
                            Text(Self.weekday(n.day)).font(Aura.text(10))
                                .foregroundStyle(Aura.inkFaint)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    /// Single-letter weekday from a `YYYY-MM-DD` key, without constructing a Date per bar.
    static func weekday(_ day: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: day) else { return "" }
        let idx = Calendar.current.component(.weekday, from: d) - 1
        return [String(localized: "S"), String(localized: "M"), String(localized: "T"),
                String(localized: "W"), String(localized: "T"), String(localized: "F"),
                String(localized: "S")][max(0, min(6, idx))]
    }
}

// MARK: - Charge

struct AuraChargeView: View {
    @EnvironmentObject var repo: Repository

    private var day: DailyMetric? { repo.days.last(where: { $0.avgHrv != nil }) ?? repo.days.last }
    private var hrvSeries: [Double] { repo.days.suffix(30).compactMap { $0.avgHrv } }
    private var normal: Double? {
        guard hrvSeries.count >= 3 else { return nil }
        return hrvSeries.reduce(0, +) / Double(hrvSeries.count)
    }

    var body: some View {
        AuraScroll {
            AuraHeader(greet: String(localized: "Right now"),
                       headline: String(localized: "Your body is settled"))

            AuraCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(day?.avgHrv.map { String(Int($0.rounded())) } ?? "—")
                            .font(Aura.display(44, .light)).kerning(-1.5)
                            .foregroundStyle(Aura.ink)
                        Text("ms").font(Aura.text(15)).foregroundStyle(Aura.inkFaint)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            minMax(String(localized: "max"), hrvSeries.max())
                            minMax(String(localized: "min"), hrvSeries.min())
                        }
                    }
                    Text(String(localized: "Variability through the day"))
                        .font(Aura.text(11.5)).foregroundStyle(Aura.inkMuted)
                    // The design's dot-column chart: one column per reading rather than a line, so a
                    // sparse day reads as sparse instead of being joined into a continuous curve.
                    AuraDotColumns(values: hrvSeries.suffix(24).map { $0 }, tint: Aura.restored)
                        .frame(height: 92)
                }
            }

            AuraCard {
                HStack {
                    Text(String(localized: "Your normal")).font(Aura.text(13))
                        .foregroundStyle(Aura.inkSoft)
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(normal.map { String(Int($0.rounded())) } ?? "—")
                            .font(Aura.display(20, .regular)).foregroundStyle(Aura.ink)
                        Text("ms").font(Aura.text(11)).foregroundStyle(Aura.inkFaint)
                    }
                }
            }
        }
    }

    private func minMax(_ label: String, _ v: Double?) -> some View {
        HStack(spacing: 5) {
            Text(v.map { String(Int($0.rounded())) } ?? "—")
                .font(Aura.display(13, .regular)).foregroundStyle(Aura.inkSoft)
            Text(label).font(Aura.text(10)).foregroundStyle(Aura.inkFaint)
        }
    }
}

/// The design's dot-column variability chart — a stack of dots per reading, brightest at the value.
struct AuraDotColumns: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let mn = values.min() ?? 0, mx = values.max() ?? 1
            let range = (mx - mn) == 0 ? 1 : (mx - mn)
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                    let frac = CGFloat((v - mn) / range)
                    VStack(spacing: 3) {
                        Spacer(minLength: 0)
                        ForEach(0..<max(1, Int(frac * 7) + 1), id: \.self) { i in
                            Circle()
                                .fill(tint.opacity(0.35 + 0.65 * Double(i) / 7))
                                .frame(width: 3.5, height: 3.5)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: geo.size.height, alignment: .bottom)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Effort

struct AuraEffortView: View {
    @EnvironmentObject var repo: Repository

    private var day: DailyMetric? { repo.days.last }
    /// The design shows effort against a target on a 0–12 scale.
    private var effort: Double? { day?.strain.map { $0 / 100 * 12 } }
    private static let target: Double = 12

    var body: some View {
        AuraScroll {
            AuraHeader(greet: String(localized: "Today"),
                       headline: String(localized: "Effort so far today"))

            AuraCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(effort.map { String(format: "%.1f", $0) } ?? "—")
                            .font(Aura.display(44, .light)).kerning(-1.5)
                            .foregroundStyle(Aura.ink)
                        Text(String(localized: "of a \(Int(Self.target)) target"))
                            .font(Aura.text(13)).foregroundStyle(Aura.inkFaint)
                    }
                    // The design's slider: the day's effort as a filled track with a knob at the value.
                    AuraSlider(fraction: effort.map { min($0 / Self.target, 1) }, tint: Aura.effortAccent)
                        .frame(height: 26)
                }
            }

            AuraCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "Load this week")).font(Aura.text(13, .medium))
                        .foregroundStyle(Aura.ink)
                    AuraWeekLoad(days: Array(repo.days.suffix(7)))
                        .frame(height: 74)
                }
            }
        }
    }
}

/// The effort slider: hatched remainder, filled measure, and a knob at the value.
struct AuraSlider: View {
    let fraction: Double?
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let f = CGFloat(min(max(fraction ?? 0, 0), 1))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.07)).frame(height: 8)
                Capsule().fill(tint).frame(width: geo.size.width * f, height: 8)
                Circle().fill(Aura.ink)
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.4), radius: 4)
                    .offset(x: max(0, geo.size.width * f - 9))
            }
            .frame(maxHeight: .infinity)
        }
    }
}

/// Week load bars, tinted by each day's own effort.
struct AuraWeekLoad: View {
    let days: [DailyMetric]

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, d in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(d.strain == nil ? Color.white.opacity(0.07) : Aura.effortAccent)
                            .frame(height: max(4, geo.size.height * CGFloat((d.strain ?? 0) / 100) - 16))
                        Text(AuraNightBars.weekday(d.day)).font(Aura.text(10))
                            .foregroundStyle(Aura.inkFaint)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Trends

struct AuraTrendsView: View {
    @EnvironmentObject var repo: Repository

    private var charge: [Double] { repo.days.suffix(30).compactMap { $0.recovery } }
    private var band: ClosedRange<Double>? {
        guard charge.count >= 5 else { return nil }
        let mean = charge.reduce(0, +) / Double(charge.count)
        let sd = (charge.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(charge.count)).squareRoot()
        return (mean - sd)...(mean + sd)
    }

    var body: some View {
        AuraScroll {
            AuraHeader(greet: String(localized: "Your own normal"),
                       headline: String(localized: "Where you're trending"))

            AuraCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(String(localized: "Charge")).font(Aura.text(13, .medium))
                            .foregroundStyle(Aura.ink)
                        Spacer()
                        Text(String(localized: "Band is your own normal"))
                            .font(Aura.text(11)).foregroundStyle(Aura.inkFaint)
                    }
                    // The design's crosshair chart: the personal band shaded behind the line, so every
                    // point is read against the wearer's own spread rather than an absolute scale.
                    AuraBandChart(values: charge, band: band, tint: Aura.restored)
                        .frame(height: 132)
                }
            }
        }
    }
}

/// A line over a shaded personal-normal band.
struct AuraBandChart: View {
    let values: [Double]
    let band: ClosedRange<Double>?
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let mn = min(values.min() ?? 0, band?.lowerBound ?? 0)
            let mx = max(values.max() ?? 1, band?.upperBound ?? 1)
            let range = (mx - mn) == 0 ? 1 : (mx - mn)
            let y: (Double) -> CGFloat = { geo.size.height * (1 - CGFloat(($0 - mn) / range)) }

            ZStack {
                if let band {
                    Rectangle()
                        .fill(tint.opacity(0.12))
                        .frame(height: max(2, y(band.lowerBound) - y(band.upperBound)))
                        .position(x: geo.size.width / 2,
                                  y: (y(band.lowerBound) + y(band.upperBound)) / 2)
                }
                Path { p in
                    guard values.count >= 2 else { return }
                    for (i, v) in values.enumerated() {
                        let x = geo.size.width * CGFloat(i) / CGFloat(values.count - 1)
                        i == 0 ? p.move(to: CGPoint(x: x, y: y(v)))
                               : p.addLine(to: CGPoint(x: x, y: y(v)))
                    }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
