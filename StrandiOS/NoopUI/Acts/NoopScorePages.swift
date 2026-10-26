import StrandAnalytics
import WhoopStore
import SwiftUI

// MARK: - Recovery and Strain pages
//
// Both follow the score page template: title, an animated Aura hero at the template's size, two
// tiles, then the page's Trends list. Recovery's hero is liquid in a glass sphere filled to the
// score and coloured by its band; it keeps level as the phone tilts. Strain's is heat rising inside
// a ring as high as the day's strain, around the figure.

private let noopRecoveryIDs = ["my-whoop:recovery", "my-whoop:hrv", "my-whoop:rhr", "my-whoop:resp_rate",
                               "my-whoop:spo2", "my-whoop:skin_temp"]
private let noopStrainIDs = ["my-whoop:strain", "my-whoop:hr_zones_all_min", "my-whoop:avg_hr", "my-whoop:energy_kcal",
                             "my-whoop:steps", "my-whoop:hr_zones45_min", "my-whoop:strength_min"]
/// Sleep's list for Rest: consistency first, then the score and the night's measures.
let noopSleepTrendIDs = ["my-whoop:sleep_consistency", "my-whoop:sleep_performance", "my-whoop:sleep_total_min",
                         "my-whoop:sleep_rem_min", "my-whoop:sleep_deep_min", "my-whoop:sleep_efficiency",
                         "my-whoop:restorative_pct", "my-whoop:sleep_debt_min", "my-whoop:in_bed_min"]

/// The stored day key for a day `offset` days back.
private func noopDayKey(_ offset: Int) -> String {
    let d = Calendar.current.date(byAdding: .day, value: -offset, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    return Repository.localDayKey(d)
}

struct NoopRecoveryPage: View {
    @ObservedObject var navigation: NoopNavigation
    let day: NoopDayRecord?
    @EnvironmentObject private var repo: Repository

    private var offset: Int { navigation.scoreDayOffset }
    private var metric: DailyMetric? { repo.days.last { $0.day == noopDayKey(offset) } }
    private var recovery: Double? { offset == 0 ? (day?.rings.recovery ?? metric?.recovery) : metric?.recovery }
    /// The band's light and deep colour: the liquid is the deep one at the floor, lighter at the top.
    private var band: (light: Color, deep: Color) {
        guard let r = recovery else { return (Color(hex: 0x7A8590), Color(hex: 0x3A4148)) }
        return r >= 67 ? (Color(hex: 0x5BF0A6), Color(hex: 0x0E6B47))
            : r >= 34 ? (Color(hex: 0xF7D86A), Color(hex: 0x7A5A12)) : (Color(hex: 0xF57A72), Color(hex: 0x7A2321))
    }
    private var hrv: Double? { offset == 0 ? (day?.vitals.first { $0.key == "hrv" }?.value ?? metric?.avgHrv) : metric?.avgHrv }
    private var rhr: Double? { offset == 0 ? (day?.vitals.first { $0.key == "rhr" }?.value ?? metric?.restingHr.map(Double.init)) : metric?.restingHr.map(Double.init) }

    /// The page's sections: the header that follows Today's ring style, Noop's other drawings
    /// waiting in Add section, the figures and the Trends list.
    static let sections: [NoopPageSection] = [
        NoopPageSection(id: "hero", title: "Header", detail: "Matches the ring style on Today"),
        NoopPageSection(id: "hero-bloom", title: "Header · Bloom", detail: "A flower that opens as far as the score", onByDefault: false),
        NoopPageSection(id: "hero-pulse", title: "Header · Pulse", detail: "One ring, with pulses at your resting heart rate", onByDefault: false),
        NoopPageSection(id: "hero-sphere", title: "Header · Sphere", detail: "Liquid in a glass, filled to the score", onByDefault: false),
        NoopPageSection(id: "tiles", title: "Resting HRV and heart rate", detail: "The night's figures"),
        NoopPageSection(id: "trends", title: "Trends", detail: "Recovery and its signals as charts")
    ]
    @StateObject private var layout = NoopPageLayout(page: "recovery", catalog: NoopRecoveryPage.sections)
    @State private var editing = NoopPageEditing()

    private var score: NoopHeroScore {
        NoopHeroScore(kind: .recovery, fill: (recovery ?? 0) / 100, text: recovery.map { "\(Int($0.rounded()))" })
    }

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 0) {
                NoopScorePageTitle(theme: .recovery, title: "Recovery", dayOffset: $navigation.scoreDayOffset,
                                   ring: { date in
                                       repo.days.last { $0.day == Repository.localDayKey(date) }?.recovery
                                           .map { (min(1, $0 / 100), NoopHeroFamily.current.dayColor(.recovery, $0)) }
                                   },
                                   back: { navigation.back(or: .today) })
                NoopEditableSections(layout: layout, editing: $editing, spacing: 0) { id in section(id) }
            }
        }
        .noopEditBar($editing, layout: layout) { navigation.push(.settingsScores) }
    }

    @ViewBuilder
    private func section(_ id: String) -> some View {
        let fill = (recovery ?? 0) / 100
        switch id {
        case "hero":
            NoopScoreHero {
                switch NoopHeroFamily.current {
                case .whoop: NoopWhoopStyleHero(score: score, recovery: recovery)
                case .bevel: NoopBevelStyleHero(score: score)
                case .noop: NoopRecoverySphere(fill: fill, color: band.light, deep: band.deep, value: recovery)
                }
            }
            .id("recovery-hero-\(offset)")
            .modifier(NoopDaySwipe(offset: $navigation.scoreDayOffset))
        case "hero-bloom":
            NoopScoreHero { NoopRecoveryBloom(fill: fill, tint: band.light, deep: band.deep, value: recovery) }
                .id("bloom-\(offset)").modifier(NoopDaySwipe(offset: $navigation.scoreDayOffset))
        case "hero-pulse":
            NoopScoreHero { NoopRecoveryPulse(fill: fill, tint: band.light, value: recovery, restingBPM: rhr) }
                .id("pulse-\(offset)").modifier(NoopDaySwipe(offset: $navigation.scoreDayOffset))
        case "hero-sphere":
            NoopScoreHero { NoopRecoverySphere(fill: fill, color: band.light, deep: band.deep, value: recovery) }
                .id("sphere-\(offset)").modifier(NoopDaySwipe(offset: $navigation.scoreDayOffset))
        case "tiles":
            NoopStatTiles(tiles: [("Resting HRV", hrv.map { "\(Int($0.rounded())) ms" } ?? "—"),
                                  ("Resting HR", rhr.map { "\(Int($0.rounded())) bpm" } ?? "—")])
                .padding(.bottom, 28)
        case "trends":
            NoopTrendsList(navigation: navigation, ids: noopRecoveryIDs)
        default:
            EmptyView()
        }
    }
}


struct NoopStrainPage: View {
    @ObservedObject var navigation: NoopNavigation
    let day: NoopDayRecord?
    @EnvironmentObject private var repo: Repository

    private var offset: Int { navigation.scoreDayOffset }
    private var metric: DailyMetric? { repo.days.last { $0.day == noopDayKey(offset) } }
    private var strain: Double? { offset == 0 ? (day?.rings.strain ?? metric?.strain) : metric?.strain }
    private var recoveryForTarget: Double? { offset == 0 ? (day?.rings.recovery ?? metric?.recovery) : metric?.recovery }
    /// The day's target, on the strain scale: easier after a low recovery, harder after a high one.
    private var target: ClosedRange<Double>? {
        guard let r = recoveryForTarget else { return nil }
        let mid = 0.2 + 0.4 * min(1, max(0, r / 100))
        return (mid - 0.08)...(mid + 0.08)
    }
    /// Zero minutes is a reading only once the strap has recorded some of the day.
    private var dayRecorded: Bool { !(day?.ribbonPoints ?? []).isEmpty || !(day?.ribbonSessions ?? []).isEmpty }
    private var exerciseMinutes: Double {
        (day?.ribbonSessions ?? []).reduce(0) { $0 + $1.end.timeIntervalSince($1.start) / 60 }
    }

    static let sections: [NoopPageSection] = [
        NoopPageSection(id: "hero", title: "Header", detail: "Matches the ring style on Today"),
        NoopPageSection(id: "hero-gauge", title: "Header · Gauge", detail: "A gauge with the day's target and a needle", onByDefault: false),
        NoopPageSection(id: "hero-day", title: "Header · Day", detail: "Today's heart rate wrapped round a ring", onByDefault: false),
        NoopPageSection(id: "hero-heat", title: "Header · Heat", detail: "Heat rising as high as the strain", onByDefault: false),
        NoopPageSection(id: "tiles", title: "Exercise and energy", detail: "The day's two figures"),
        NoopPageSection(id: "trends", title: "Trends", detail: "Strain and its parts as charts")
    ]
    @StateObject private var layout = NoopPageLayout(page: "strain", catalog: NoopStrainPage.sections)
    @State private var editing = NoopPageEditing()

    private var level: Double { min(1, (strain ?? 0) / 100) }
    private var score: NoopHeroScore {
        let scale = noopEffortScale
        let factor = UnitFormatter.effortValue(100, scale: scale) / 100
        return NoopHeroScore(kind: .strain, fill: level, text: strain.map(noopStrainText), suffix: "",
                             target: target,
                             targetText: target.map { t in
                                 let lo = t.lowerBound * 100 * factor, hi = t.upperBound * 100 * factor
                                 return scale == .whoop ? String(format: "%.1f – %.1f", lo, hi) : "\(Int(lo.rounded())) – \(Int(hi.rounded()))"
                             })
    }

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 0) {
                NoopScorePageTitle(theme: .strain, title: "Strain", dayOffset: $navigation.scoreDayOffset,
                                   ring: { date in
                                       repo.days.last { $0.day == Repository.localDayKey(date) }?.strain
                                           .map { (min(1, $0 / 100), NoopHeroFamily.current.dayColor(.strain, $0)) }
                                   },
                                   back: { navigation.back(or: .today) })
                NoopEditableSections(layout: layout, editing: $editing, spacing: 0) { id in section(id) }
            }
        }
        .noopEditBar($editing, layout: layout) { navigation.push(.settingsScores) }
    }

    @ViewBuilder
    private func section(_ id: String) -> some View {
        switch id {
        case "hero":
            NoopScoreHero {
                switch NoopHeroFamily.current {
                case .whoop: NoopWhoopStyleHero(score: score)
                case .bevel: NoopBevelStyleHero(score: score)
                case .noop: NoopStrainHeat(level: level, value: strain)
                }
            }
            .id("strain-hero-\(offset)").modifier(NoopDaySwipe(offset: $navigation.scoreDayOffset))
        case "hero-gauge":
            NoopScoreHero { NoopStrainGauge(level: level, value: strain, target: target) }
                .id("gauge-\(offset)").modifier(NoopDaySwipe(offset: $navigation.scoreDayOffset))
        case "hero-day":
            NoopScoreHero {
                NoopStrainDayRing(points: offset == 0 ? (day?.ribbonPoints ?? []) : [],
                                  resting: day?.vitals.first { $0.key == "rhr" }?.value, value: strain)
            }
            .id("day-\(offset)").modifier(NoopDaySwipe(offset: $navigation.scoreDayOffset))
        case "hero-heat":
            NoopScoreHero { NoopStrainHeat(level: level, value: strain) }
                .id("heat-\(offset)").modifier(NoopDaySwipe(offset: $navigation.scoreDayOffset))
        case "tiles":
            if offset == 0 {
                NoopStatTiles(tiles: [("Exercise", dayRecorded ? NoopRestRecord.duration(exerciseMinutes) : "—"),
                                      ("Total energy", day?.energy?.totalBurnedSoFar
                                          .map { "\($0.formatted(.number.precision(.fractionLength(0)))) kcal" } ?? "—")])
                    .padding(.bottom, 28)
            } else {
                NoopStatTiles(tiles: [("Steps", metric?.steps.map { $0.formatted() } ?? "—"),
                                      ("Active energy", metric?.activeKcalEst
                                          .map { "\($0.formatted(.number.precision(.fractionLength(0)))) kcal" } ?? "—")])
                    .padding(.bottom, 28)
            }
        case "trends":
            NoopTrendsList(navigation: navigation, ids: noopStrainIDs)
        default:
            EmptyView()
        }
    }
}

// MARK: Heroes

/// A glass sphere holding liquid to the score, its surface level as the phone tilts.
private struct NoopRecoverySphere: View {
    let fill: Double
    let color: Color
    let deep: Color
    let value: Double?

    @State private var level: Double = 0
    @State private var onScreen = true
    @State private var lastTilt: Double = 0
    @State private var slosh: Double = 0
    /// Whether this view holds the shared tilt sensor, so appear and disappear stay paired.
    @State private var holdsMotion = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let side = NoopPageHeroMetrics.heroSide
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !onScreen || reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
            let tilt = reduceMotion ? 0 : LiquidMotion.shared.tilt
            ZStack {
                Circle().fill(RadialGradient(colors: [color.opacity(0.10), Color.white.opacity(0.02)],
                                             center: .center, startRadius: 0, endRadius: side / 2))
                Rectangle()
                    .colorEffect(ShaderLibrary.noopLiquid(
                        .float2(CGSize(width: side, height: side)), .float(Float(t)), .float(Float(fill * level)),
                        .float(Float(-tan(tilt))), .float(Float(slosh + 0.3 * max(0, 1 - level))),
                        .float(1), .color(deep), .color(deep)))
                    .clipShape(Circle())
                // Light falls in from the top of the glass and fades with depth.
                Circle().fill(LinearGradient(colors: [color.opacity(0.55), color.opacity(0.0)],
                                             startPoint: .top, endPoint: .bottom))
                    .blendMode(.plusLighter)
                    .mask {
                        Rectangle().colorEffect(ShaderLibrary.noopLiquid(
                            .float2(CGSize(width: side, height: side)), .float(Float(t)), .float(Float(fill * level)),
                            .float(Float(-tan(tilt))), .float(Float(slosh + 0.3 * max(0, 1 - level))),
                            .float(1), .color(.white), .color(.white)))
                    }
                    .clipShape(Circle())
                // Glass: a rim, and a highlight across the upper left.
                Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 1.5)
                Circle().trim(from: 0.58, to: 0.72).stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .padding(14)
                VStack(spacing: 0) {
                    if let value {
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            NoopCountUp(value: value, font: NoopHTMLFont.outfit(NoopType.title1 + 14, weight: .light))
                            Text("%").font(NoopHTMLFont.outfit(NoopType.title3, weight: .light))
                        }
                        .foregroundStyle(NoopHTMLColor.ink)
                    } else {
                        Text("—").font(NoopHTMLFont.outfit(NoopType.title1 + 14, weight: .light)).foregroundStyle(NoopHTMLColor.faint)
                    }
                    Text("RECOVERED").font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).tracking(1.4)
                        .foregroundStyle(NoopHTMLColor.inkSoft)
                }
                .shadow(color: .black.opacity(0.35), radius: 6)
            }
            .onChange(of: timeline.date) {
                let turn = abs(tilt - lastTilt)
                slosh = min(1.4, slosh * 0.94 + turn * 9)
                lastTilt = tilt
            }
        }
        .onAppear {
            if !holdsMotion { holdsMotion = true; LiquidMotion.shared.acquire() }
            if reduceMotion { level = 1 } else { withAnimation(.spring(response: 1.5, dampingFraction: 0.72)) { level = 1 } }
        }
        .onDisappear { if holdsMotion { holdsMotion = false; LiquidMotion.shared.release() } }
        .modifier(NoopSlotVisibility(onScreen: $onScreen))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value.map { "Recovery \(Int($0.rounded())) percent" } ?? "Recovery not measured yet")
    }
}

/// Heat rising inside a ring as high as the day's strain, the ring itself filled to it.
private struct NoopStrainHeat: View {
    let level: Double
    let value: Double?

    var body: some View {
        let side = NoopPageHeroMetrics.heroSide
        NoopSlotClock { t, reveal in
            let shown = level * NoopRingValues.spring(reveal)
            ZStack {
                Circle().fill(Color.white.opacity(0.03)).padding(18)
                Rectangle()
                    .colorEffect(ShaderLibrary.noopHeat(.float2(CGSize(width: side - 36, height: side - 36)),
                                                        .float(Float(t)), .float(Float(shown))))
                    .frame(width: side - 36, height: side - 36)
                    .clipShape(Circle())
                Circle().stroke(Color.white.opacity(0.07), lineWidth: 10)
                Circle().trim(from: 0, to: shown)
                    .stroke(AngularGradient(colors: [Color(hex: 0xF5B451), Color(hex: 0xFF6A3D)], center: .center,
                                            startAngle: .degrees(0), endAngle: .degrees(360 * max(shown, 0.01))),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    if let value {
                        NoopCountUp(value: value, format: { noopStrainText($0) },
                                    font: NoopHTMLFont.outfit(NoopType.title1 + 14, weight: .light))
                            .foregroundStyle(NoopHTMLColor.ink)
                    } else {
                        Text("—").font(NoopHTMLFont.outfit(NoopType.title1 + 14, weight: .light)).foregroundStyle(NoopHTMLColor.faint)
                    }
                    Text("STRAIN").font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).tracking(1.4)
                        .foregroundStyle(NoopHTMLColor.inkSoft)
                }
                .shadow(color: .black.opacity(0.4), radius: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value.map { "Strain \(noopStrainText($0)) of \(UnitFormatter.effortScaleMax(noopEffortScale))" } ?? "No strain yet")
    }
}
