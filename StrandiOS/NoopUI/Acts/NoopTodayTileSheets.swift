import SwiftUI
import Charts
import StrandAnalytics
import WhoopStore

// MARK: - Tile sheets
//
// Tapping one of Today's small tiles opens its sheet rather than a page (25 Oct 2026): the figure at
// full size, one picture of how it got there, three facts, and a way on to the full page. Every sheet
// shares one frame, the floating sheet the rest of the app uses. The seeded shell draws the design's
// example person; with measured data, anything missing says so instead of being filled in.

/// The frame every tile sheet shares: a close button and title, the figure, the picture, the facts, the
/// way on.
struct NoopTileSheetFrame<Picture: View>: View {
    let tile: NoopTodayTile
    var tint: (Color, Color)? = nil
    let figure: String
    var unit: String? = nil
    let caption: String
    var facts: [(label: String, value: String)] = []
    var beat: Int? = nil
    /// The way on: a label and what it does. Nil leaves the sheet without one.
    var openTitle: String?
    var primary = false
    var open: (() -> Void)?
    @ViewBuilder var picture: Picture

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Text(tile.section.title).font(NoopHTMLFont.sans(NoopType.body, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.ink)
                HStack {
                    NoopCloseButton { dismiss() }
                    Spacer()
                }
            }
            .padding(.top, 22).padding(.bottom, 22)

            HStack(alignment: .center, spacing: 14) {
                NoopGlossTile(symbol: tile.symbol, tint: tint ?? tile.tint, side: 52, beat: beat)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(figure)
                            .font(NoopHTMLFont.outfit(NoopType.title1, weight: .medium))
                            .tracking(-0.8)
                            .foregroundStyle(NoopHTMLColor.ink)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .lineLimit(1).minimumScaleFactor(0.6)
                        if let unit {
                            Text(unit).font(NoopHTMLFont.sans(NoopType.subhead, weight: .medium))
                                .foregroundStyle(NoopHTMLColor.copy)
                        }
                    }
                    Text(caption)
                        .font(NoopHTMLFont.sans(NoopType.footnote))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, 20)

            picture
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)

            // A row of nothing but dashes says nothing; it waits until one fact is known.
            if facts.contains(where: { $0.value != "—" }) {
                HStack(spacing: 0) {
                    ForEach(Array(facts.enumerated()), id: \.offset) { index, fact in
                        if index > 0 {
                            Rectangle().fill(NoopHTMLColor.border).frame(width: 0.5).padding(.vertical, 12)
                        }
                        VStack(spacing: 3) {
                            Text(fact.value).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.ink).monospacedDigit()
                                .lineLimit(1).minimumScaleFactor(0.75)
                            Text(fact.label).font(NoopHTMLFont.sans(NoopType.caption))
                                .foregroundStyle(NoopHTMLColor.copy).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                }
                .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous)
                    .strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
                .padding(.bottom, 18)
            }

            if let openTitle, let open {
                NoopActionButton(title: openTitle, variant: primary ? .primary : .secondary) {
                    NoopHaptics.play(.tick)
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { open() }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }
}

/// One tile's sheet.
struct NoopTodayTileSheet: View {
    let tile: NoopTodayTile
    @ObservedObject var navigation: NoopNavigation
    let day: NoopDayRecord?
    let liveBPM: Int?
    let weights: [BodyMeasurementRow]

    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var fitness: NoopFitnessSettings
    @AppStorage(UnitPrefs.systemKey) private var unitSystemRaw = UnitSystem.metric.rawValue

    private var seeded: Bool { day == nil }

    var body: some View {
        switch tile {
        case .heart: heartSheet
        case .effort: effortSheet
        case .steps: stepsSheet
        case .calories: caloriesSheet
        case .stress: stressSheet
        case .bedtime: bedtimeSheet
        case .debt: debtSheet
        case .workout: workoutSheet
        case .weight: weightSheet
        case .cycle: cycleSheet
        case .breathe: breatheSheet
        }
    }

    // MARK: Heart

    private var heartPoints: [(time: Date, bpm: Double)] {
        if seeded { return Self.demoHeart }
        return (day?.dayHRPoints ?? []).map { (Date(timeIntervalSince1970: TimeInterval($0.ts)), $0.bpm) }
    }

    private var heartSheet: some View {
        let points = heartPoints
        let bpms = points.map(\.bpm)
        let now: Int? = seeded ? 64 : (liveBPM.flatMap { $0 > 0 ? $0 : nil } ?? bpms.last.map { Int($0.rounded()) })
        let live = seeded || (liveBPM ?? 0) > 0
        return NoopTileSheetFrame(
            tile: tile, figure: now.map(String.init) ?? "—", unit: now == nil ? nil : "bpm",
            caption: now == nil ? "No heart rate since the strap came off." : live ? "Live from your strap." : "Your last reading today.",
            facts: bpms.isEmpty ? [] : [("Lowest", "\(Int(bpms.min()!.rounded()))"),
                                       ("Average", "\(Int((bpms.reduce(0, +) / Double(bpms.count)).rounded()))"),
                                       ("Highest", "\(Int(bpms.max()!.rounded()))")],
            beat: live ? now : nil,
            openTitle: "Open heart rate", open: { navigation.push(.heart) }
        ) {
            if points.count > 1 {
                Self.lineChart(points.map { ($0.time, $0.bpm) }, tint: tile.tint, height: 120,
                               labels: (Self.time.string(from: points.first!.time), "Now"), scrub: true, unit: "bpm")
            } else {
                Self.emptyPicture("Today's line fills in as the strap records.")
            }
        }
    }

    // MARK: Effort

    private var effortSheet: some View {
        let rings = seeded ? NoopAct2Screens.demoRings : (day?.rings ?? NoopRingValues())
        let strain = rings.strain
        let target = rings.strainTarget
        let sessions = seeded ? 1 : (day?.ribbonSessions.count ?? 0)
        let caption: String = {
            guard let strain else { return "Effort builds from your heart rate as the day goes." }
            guard let target else { return "Today's effort so far." }
            let s = strain / 100
            if s < target.lowerBound { return "Below today's target. \(Int(((target.lowerBound - s) * 100).rounded())) to go." }
            if s > target.upperBound { return "Past today's target. Recovery will ask for more tonight." }
            return "Inside today's target. A good place to stop or to hold."
        }()
        return NoopTileSheetFrame(
            tile: tile, figure: strain.map { "\(Int($0.rounded()))" } ?? "—", caption: caption,
            facts: [("Target", target.map { "\(Int(($0.lowerBound * 100).rounded()))–\(Int(($0.upperBound * 100).rounded()))" } ?? "—"),
                    ("Recovery", rings.recovery.map { "\(Int($0.rounded()))%" } ?? "—"),
                    ("Sessions", "\(sessions)")],
            openTitle: "Open effort", open: { navigation.push(.strain) }
        ) {
            NoopTargetRing(value: (strain ?? 0) / 100, band: target, tint: tile.tint)
                .frame(width: 150, height: 150)
                .padding(.vertical, 4)
        }
    }

    // MARK: Steps

    private var stepsDays: [(day: Date, steps: Int)] {
        if seeded {
            return Self.demoSteps.enumerated().map { index, value in
                (Calendar.current.date(byAdding: .day, value: index - Self.demoSteps.count + 1, to: Date()) ?? Date(), value)
            }
        }
        return repo.days.suffix(14).compactMap { d in
            guard let steps = d.steps, let date = Self.dayKey.date(from: d.day) else { return nil }
            return (date, steps)
        }
    }

    private var stepsSheet: some View {
        let days = stepsDays
        let today = days.last.flatMap { Calendar.current.isDateInToday($0.day) ? $0.steps : nil }
        let past = days.filter { !Calendar.current.isDateInToday($0.day) }.map(\.steps).filter { $0 > 0 }.sorted()
        let usual = past.count >= 3 ? past[past.count / 2] : nil
        let caption: String = {
            guard let today else { return "Steps arrive with the strap's next sync." }
            guard let usual else { return "Your usual day appears after a few more." }
            let pct = Int((Double(today) / Double(max(1, usual)) * 100).rounded())
            return pct >= 100 ? "Past your usual day already." : "\(pct)% of your usual day."
        }()
        return NoopTileSheetFrame(
            tile: tile, figure: today?.formatted() ?? "—", unit: today == nil ? nil : "steps", caption: caption,
            facts: [("Usual", usual?.formatted() ?? "—"), ("Best", past.last?.formatted() ?? "—"), ("Days", "\(days.count)")],
            openTitle: "Open your day", open: { navigation.push(.day) }
        ) {
            if days.count > 1 {
                Chart {
                    ForEach(days, id: \.day) { d in
                        BarMark(x: .value("Day", d.day, unit: .day), y: .value("Steps", d.steps))
                            .foregroundStyle(Calendar.current.isDateInToday(d.day) ? tile.tint.0 : Color.white.opacity(0.16))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    if let usual {
                        RuleMark(y: .value("Usual", usual))
                            .foregroundStyle(Color.white.opacity(0.45))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 110)
                Self.axisLabels("\(days.count) days ago", "Today").padding(.top, 6)
            } else {
                Self.emptyPicture("Two weeks of days draw here.")
            }
        }
    }

    // MARK: Calories

    private var caloriesSheet: some View {
        let energy = day?.energy
        let resting = seeded ? 1080.0 : energy?.basalBurnedSoFar
        let active = seeded ? 340.0 : energy?.activeBurnedSoFar
        let total = seeded ? 1420.0 : energy?.totalBurnedSoFar
        let projected = seeded ? 2380.0 : energy?.projectedTotalBurn
        return NoopTileSheetFrame(
            tile: tile, figure: total.map { Int($0.rounded()).formatted() } ?? "—", unit: total == nil ? nil : "kcal",
            caption: total == nil ? "Calories come from your heart rate and your profile." : "Burned since midnight.",
            facts: [("Resting", resting.map { Int($0.rounded()).formatted() } ?? "—"),
                    ("Active", active.map { Int($0.rounded()).formatted() } ?? "—"),
                    ("By midnight", projected.map { "~" + Int($0.rounded()).formatted() } ?? "—")],
            openTitle: "Open energy", open: { navigation.push(.energy) }
        ) {
            if let resting, let active, resting + active > 0 {
                let whole = max(projected ?? 0, resting + active)
                GeometryReader { proxy in
                    let w = proxy.size.width
                    HStack(spacing: 3) {
                        Capsule().fill(Color.white.opacity(0.28)).frame(width: max(6, w * resting / whole))
                        Capsule().fill(LinearGradient(colors: [tile.tint.0, tile.tint.1], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(6, w * active / whole))
                        Spacer(minLength: 0)
                    }
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                }
                .frame(height: 14)
                .padding(.vertical, 8)
            } else {
                Self.emptyPicture("Resting and active split here.")
            }
        }
    }

    // MARK: Stress

    private var stressSheet: some View {
        let hours: [(start: Date, step: Int?)] = seeded ? Self.demoStress : (day?.stressHours ?? [])
        let level: Double? = seeded ? 0.6 : day?.stressLevel
        let step = level.map(NoopDayRecord.stressStep)
        let counts = (0..<4).map { s in hours.filter { $0.step == s }.count }
        return NoopTileSheetFrame(
            tile: tile, tint: step.map { Self.stressTints[$0] }, figure: step.map { NoopDayRecord.stressNames[$0] } ?? "—",
            caption: step == nil ? "Stress is read hour by hour once there is enough signal." : "Where your last scored hour sat.",
            facts: [("Settled", "\(counts[0])h"), ("Engaged", "\(counts[1])h"), ("Pushed or more", "\(counts[2] + counts[3])h")],
            openTitle: "Open stress", open: { navigation.push(.stress) }
        ) {
            if hours.contains(where: { $0.step != nil }) {
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(Array(hours.enumerated()), id: \.offset) { _, hour in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(hour.step.map { Self.stressTints[$0].0 } ?? Color.white.opacity(0.08))
                            .frame(height: CGFloat(18 + (hour.step ?? 0) * 22))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 90, alignment: .bottom)
                Self.axisLabels(hours.first.map { Self.time.string(from: $0.start) } ?? "", "Now")
                    .padding(.top, 6)
            } else {
                Self.emptyPicture("Each hour of today appears here.")
            }
        }
    }

    // MARK: Bedtime

    /// Tonight's bedtime: the hour you usually wake over the last week's nights, with your need counted
    /// back from it. The tile and its sheet both read this one answer.
    static func bedtimePlan(day: NoopDayRecord?) -> (bed: Int, wake: Int, need: Double, nights: [(start: Date, end: Date)])? {
        let need = day == nil ? 425.0 : (day?.rest.needMin ?? 0)
        let nights: [(start: Date, end: Date)] = day == nil ? demoNights
            : (day?.rest.slots.compactMap { night in night.map { ($0.span?.lowerBound ?? $0.endDate.addingTimeInterval(-$0.asleepMin * 60), $0.span?.upperBound ?? $0.endDate) } } ?? [])
        guard need > 0, !nights.isEmpty else { return nil }
        let wakes = nights.map { minuteOfDay($0.end) }.sorted()
        let wake = wakes[wakes.count / 2]
        return (((wake - Int(need.rounded())) % 1440 + 1440) % 1440, wake, need, nights)
    }

    private var bedtimeSheet: some View {
        let plan = Self.bedtimePlan(day: day)
        let debt = seeded ? 80.0 : day?.rest.debt.last?.minutes
        let need = plan?.need ?? (day?.rest.needMin ?? 0)
        return NoopTileSheetFrame(
            tile: tile, figure: plan.map { Self.clock($0.bed) } ?? "—",
            caption: plan.map { "Asleep by then, you wake at your usual \(Self.clock($0.wake)) with your need met." }
                ?? "Your bedtime appears after the first night the strap records.",
            facts: [("Usual wake", plan.map { Self.clock($0.wake) } ?? "—"), ("Your need", need > 0 ? Self.duration(need) : "—"),
                    ("Debt", debt.map { $0 < 10 ? "None" : Self.duration($0) } ?? "—")],
            openTitle: "Open tonight", open: { navigation.push(.tonight) }
        ) {
            if let plan {
                NoopNightsStrip(nights: plan.nights, bed: plan.bed, tint: tile.tint)
            } else {
                Self.emptyPicture("Your last week of nights lines up here.")
            }
        }
    }

    // MARK: Sleep debt

    private var debtSheet: some View {
        let series: [Double] = seeded ? Self.demoDebt : (day?.rest.debt.suffix(14).map(\.minutes) ?? [])
        let debt = series.last
        let lastNight = seeded ? 7.0 : day?.rest.nightDeltas.last?.minutes
        let need = seeded ? 425.0 : day?.rest.needMin
        // Against a week ago, so one night's wobble does not flip it.
        let weekAgo = series.count >= 2 ? series[max(0, series.count - 8)] : nil
        let trend: String? = weekAgo.map { then in
            let now = series.last!
            return now < then - 10 ? "Shrinking" : now > then + 10 ? "Growing" : "Holding"
        }
        return NoopTileSheetFrame(
            tile: tile, figure: debt.map { $0 < 10 ? "None" : Self.duration($0) } ?? "—",
            caption: debt == nil ? "Debt is counted once there are a few nights to weigh."
                : (debt ?? 0) < 10 ? "You owe your sleep nothing right now." : "Sleep you owe, weighted toward recent nights.",
            facts: [("Last night", lastNight.map { ($0 >= 0 ? "+" : "−") + Self.duration(abs($0)) } ?? "—"),
                    ("Your need", need.map { $0 > 0 ? Self.duration($0) : "—" } ?? "—"),
                    ("Trend", trend ?? "—")],
            openTitle: "Open sleep debt", open: { navigation.push(.debt) }
        ) {
            if series.count > 1 {
                let now = Date()
                Self.lineChart(series.enumerated().map { (Calendar.current.date(byAdding: .day, value: $0.offset - series.count + 1, to: now) ?? now, $0.element) },
                               tint: tile.tint, height: 100, labels: ("\(series.count) nights ago", "Today"))
            } else {
                Self.emptyPicture("Two weeks of debt draw here.")
            }
        }
    }

    // MARK: Workout

    private var workoutSheet: some View {
        let calendar = Calendar.current
        let week: [(day: Date, names: [String])] = (0..<7).compactMap { offset in
            guard let d = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date())) else { return nil }
            if seeded { return (d, [0, 2, 4].contains(offset) ? [["Upper body", "Lower body", "Full body"][offset / 2]] : []) }
            return (d, fitness.plans(on: d).map(\.routineName))
        }
        let today = week.first?.names.first
        let planned = week.filter { !$0.names.isEmpty }.count
        return NoopTileSheetFrame(
            tile: tile, figure: today ?? "Rest day",
            caption: today == nil ? (planned == 0 ? "Nothing planned this week. Plan routines in Fitness." : "Nothing today. Your next one is below.")
                : "Planned for today.",
            facts: [], openTitle: "Open Fitness", open: { navigation.reset(to: .fitness) }
        ) {
            VStack(spacing: 0) {
                ForEach(Array(week.enumerated()), id: \.offset) { index, entry in
                    HStack(spacing: 12) {
                        Text(index == 0 ? "Today" : Self.weekday.string(from: entry.day))
                            .font(NoopHTMLFont.sans(NoopType.footnote, weight: index == 0 ? .semibold : .regular))
                            .foregroundStyle(index == 0 ? NoopHTMLColor.ink : NoopHTMLColor.copy)
                            .frame(width: 58, alignment: .leading)
                        Circle().fill(entry.names.isEmpty ? Color.white.opacity(0.12) : tile.tint.0).frame(width: 7, height: 7)
                        Text(entry.names.isEmpty ? "Rest" : entry.names.joined(separator: ", "))
                            .font(NoopHTMLFont.sans(NoopType.footnote, weight: entry.names.isEmpty ? .regular : .semibold))
                            .foregroundStyle(entry.names.isEmpty ? NoopHTMLColor.faint : NoopHTMLColor.ink)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 9)
                    if index < week.count - 1 { Rectangle().fill(NoopHTMLColor.border).frame(height: 0.5) }
                }
            }
        }
    }

    // MARK: Weight

    private var weightSheet: some View {
        let units = UnitSystem(rawValue: unitSystemRaw) ?? .metric
        let rows: [(time: Date, kg: Double)] = seeded ? Self.demoWeight
            : weights.map { (Date(timeIntervalSince1970: TimeInterval($0.ts)), $0.value) }
        let latest = rows.last
        let monthAgo = latest.map { $0.time.addingTimeInterval(-30 * 86_400) }
        let then = monthAgo.flatMap { cutoff in rows.last { $0.time <= cutoff } ?? rows.first }
        let change = latest.flatMap { l in then.map { l.kg - $0.kg } }
        let shown: (Double) -> String = { UnitFormatter.massFromKilograms($0, system: units) }
        let display = units == .imperial ? 2.20462 : 1.0
        return NoopTileSheetFrame(
            tile: tile, figure: latest.map { shown($0.kg) } ?? "—",
            caption: latest == nil ? "Log a weight and the trend starts here." : "Logged \(Self.relative(latest!.time)).",
            facts: [("30 days", change.map { String(format: "%@%.1f %@", $0 >= 0 ? "+" : "−", abs($0 * display), UnitFormatter.massUnit(units)) } ?? "—"),
                    ("Lowest", rows.map(\.kg).min().map(shown) ?? "—"),
                    ("Highest", rows.map(\.kg).max().map(shown) ?? "—")],
            openTitle: latest == nil ? "Log a weight" : "Open body", primary: latest == nil,
            open: { navigation.push(.fitnessBody) }
        ) {
            if rows.count > 1 {
                Self.lineChart(rows.map { ($0.time, $0.kg * display) }, tint: tile.tint, height: 110,
                               labels: (Self.shortDate.string(from: rows.first!.time), Self.shortDate.string(from: rows.last!.time)))
            } else {
                Self.emptyPicture("Each weigh-in draws a point here.")
            }
        }
    }

    // MARK: Cycle

    private var cycleSheet: some View {
        let result = seeded ? nil : app.cyclePhase
        let enabled = seeded || app.cycleAwarenessEnabled
        let phase: String = {
            if seeded { return "Follicular" }
            guard enabled else { return "Off" }
            switch result?.phase {
            case .follicular: return "Follicular"
            case .periOvulatory: return "Ovulation"
            case .luteal: return "Luteal"
            case .unknown: return "Unclear"
            case .learning, nil: return "Learning"
            }
        }()
        let dayText: String = {
            if seeded { return "8–10" }
            guard let low = result?.cycleDayLow, let high = result?.cycleDayHigh else { return "—" }
            return low == high ? "\(low)" : "\(low)–\(high)"
        }()
        let length = seeded ? "29 days" : result?.cycleLengthDays.map { "\($0) days" } ?? "—"
        let confidence = seeded ? "Building" : result.map { $0.confidence.rawValue.prefix(1).uppercased() + $0.confidence.rawValue.dropFirst() } ?? "—"
        let next: String = {
            if seeded { return "Nov 12–15" }
            guard let window = result?.nextPeriodWindow,
                  let a = Self.dayKey.date(from: window.earliestDay), let b = Self.dayKey.date(from: window.latestDay) else { return "—" }
            return Self.shortDate.string(from: a) + "–" + Self.shortDate.string(from: b)
        }()
        return NoopTileSheetFrame(
            tile: tile, figure: phase,
            caption: !enabled ? "Cycle awareness reads your phase from skin temperature. Turn it on in You."
                : seeded ? "Read from your skin temperature." : (result?.note ?? "Read from your skin temperature, night by night."),
            facts: enabled ? [("Length", length), ("Next period", next), ("Confidence", confidence)] : [],
            openTitle: enabled ? "Open You" : "Set up in You", primary: !enabled, open: { navigation.reset(to: .you) }
        ) {
            VStack(spacing: 14) {
                if enabled {
                    NoopCycleArc(day: seeded ? 9 : result?.cycleDayLow, length: seeded ? 29 : result?.cycleLengthDays, tint: tile.tint)
                        .frame(height: 120)
                        .overlay(alignment: .bottom) {
                            VStack(spacing: 2) {
                                Text(dayText == "—" ? "—" : "Day \(dayText)")
                                    .font(NoopHTMLFont.outfit(NoopType.title3, weight: .medium))
                                    .foregroundStyle(NoopHTMLColor.ink)
                                Text(length == "—" ? "Cycle length still learning" : "of about \(length)")
                                    .font(NoopHTMLFont.sans(NoopType.caption))
                                    .foregroundStyle(NoopHTMLColor.copy)
                            }
                            .padding(.bottom, 6)
                        }
                }
                Text(CyclePhaseEngine.awarenessLine)
                    .font(NoopHTMLFont.sans(NoopType.caption))
                    .foregroundStyle(NoopHTMLColor.faint)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: Breathe

    private var breatheSheet: some View {
        NoopTileSheetFrame(
            tile: tile, figure: "One minute",
            caption: "In for four, out for six. A minute is enough to settle your pulse.",
            facts: [], openTitle: "Begin", primary: true, open: { navigation.push(.breathe) }
        ) {
            NoopBreathePreview(tint: tile.tint).frame(height: 150)
        }
    }

    // MARK: Pieces

    static func lineChart(_ points: [(Date, Double)], tint: (Color, Color), height: CGFloat,
                          labels: (String, String)? = nil, scrub: Bool = false, unit: String = "") -> some View {
        NoopTileLineChart(points: points, tint: tint, height: height, labels: labels, scrub: scrub, unit: unit)
    }

    /// The two ends of a picture's time, under it.
    static func axisLabels(_ start: String, _ end: String) -> some View {
        HStack {
            Text(start)
            Spacer()
            Text(end)
        }
        .font(NoopHTMLFont.sans(NoopType.eyebrow))
        .foregroundStyle(NoopHTMLColor.faint)
    }

    static func emptyPicture(_ text: String) -> some View {
        Text(text)
            .font(NoopHTMLFont.sans(NoopType.footnote))
            .foregroundStyle(NoopHTMLColor.faint)
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous)
                .strokeBorder(NoopHTMLColor.border, style: StrokeStyle(lineWidth: 0.5, dash: [4, 3])))
    }

    static let stressTints: [(Color, Color)] = [
        (Color(hex: 0x7FE6D6), Color(hex: 0x1F9C8F)),
        (Color(hex: 0x8FC2FF), Color(hex: 0x2F6FD6)),
        (Color(hex: 0xFFD47A), Color(hex: 0xD9921A)),
        (Color(hex: 0xFF8A7A), Color(hex: 0xC83A3A))
    ]

    static func minuteOfDay(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func clock(_ minuteOfDay: Int) -> String {
        let date = Calendar.current.date(bySettingHour: minuteOfDay / 60, minute: minuteOfDay % 60, second: 0, of: Date()) ?? Date()
        return time.string(from: date)
    }

    static func duration(_ minutes: Double) -> String {
        let m = Int(minutes.rounded())
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }

    static func relative(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "today" }
        if Calendar.current.isDateInYesterday(date) { return "yesterday" }
        return "on " + shortDate.string(from: date)
    }

    static let time: DateFormatter = { let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("jj:mm"); return f }()
    static let hour: DateFormatter = { let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("j"); return f }()
    static let weekday: DateFormatter = { let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("EEE d"); return f }()
    static let shortDate: DateFormatter = { let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("MMM d"); return f }()
    static let dayKey: DateFormatter = {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"; return f
    }()

    // MARK: The seeded shell's example person

    static let demoHeart: [(time: Date, bpm: Double)] = {
        let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(6.5 * 3600)
        let shape: [Double] = [54, 56, 62, 71, 68, 66, 74, 92, 118, 104, 82, 72, 69, 67, 70, 76, 73, 68, 66, 64]
        return shape.enumerated().map { (start.addingTimeInterval(Double($0.offset) * 2400), $0.element) }
    }()
    static let demoSteps = [8120, 6400, 9850, 7300, 5100, 11240, 7900, 8800, 6900, 7400, 10100, 7600, 7020, 6240]
    static let demoDebt: [Double] = [150, 132, 140, 118, 104, 96, 110, 98, 92, 88, 95, 84, 82, 80]
    static let demoWeight: [(time: Date, kg: Double)] = {
        let values = [79.4, 79.1, 79.3, 78.9, 79.0, 78.7, 78.8, 78.5, 78.6, 78.4]
        return values.enumerated().map { (Date().addingTimeInterval(Double($0.offset - values.count + 1) * 6 * 86_400), $0.element) }
    }()
    static let demoStress: [(start: Date, step: Int?)] = {
        let steps: [Int?] = [0, 0, 1, 1, 2, 1, 0, nil, 1, 2, 1, 1]
        let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(7 * 3600)
        return steps.enumerated().map { (start.addingTimeInterval(Double($0.offset) * 3600), $0.element) }
    }()
    static let demoNights: [(start: Date, end: Date)] = {
        let starts = [23.2, 22.9, 23.6, 23.1, 22.8, 23.4, 23.2]
        let ends = [6.7, 6.6, 7.1, 6.8, 6.5, 6.9, 6.7]
        let today = Calendar.current.startOfDay(for: Date())
        return zip(starts, ends).enumerated().map { index, pair in
            let day = today.addingTimeInterval(Double(index - 7) * 86_400)
            return (day.addingTimeInterval(pair.0 * 3600), day.addingTimeInterval((24 + pair.1) * 3600))
        }
    }()
}

// MARK: - Sheet pictures

/// Effort's ring at size: the target band lighter on the track, a white tick at its middle, the day's
/// effort in the tile's colour.
struct NoopTargetRing: View {
    let value: Double
    let band: ClosedRange<Double>?
    let tint: (Color, Color)
    @State private var shown = 0.0

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let line = side * 0.09
            ZStack {
                Circle().stroke(Color.white.opacity(0.08), lineWidth: line)
                if let band {
                    Circle().trim(from: band.lowerBound, to: band.upperBound)
                        .stroke(Color.white.opacity(0.2), lineWidth: line)
                        .rotationEffect(.degrees(-90))
                }
                Circle().trim(from: 0, to: max(0.001, min(1, shown)))
                    .stroke(AngularGradient(colors: [tint.1, tint.0], center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * max(0.05, shown))),
                            style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: tint.1.opacity(0.5), radius: 8)
                if let band {
                    Capsule().fill(.white).frame(width: 3, height: line * 1.5)
                        .offset(y: -(side - line) / 2)
                        .rotationEffect(.degrees(360 * (band.lowerBound + band.upperBound) / 2))
                }
            }
            .padding(line / 2)
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { withAnimation(.smooth(duration: 0.9).delay(0.1)) { shown = value } }
    }
}

/// The last week's nights as bars on one clock, with tonight's bedtime drawn across them.
private struct NoopNightsStrip: View {
    let nights: [(start: Date, end: Date)]
    let bed: Int?
    let tint: (Color, Color)

    /// The strip runs from 20:00 to 12:00 the next day.
    private static let from = 20.0 * 60, span = 16.0 * 60

    private func x(_ date: Date, width: CGFloat) -> CGFloat {
        var m = Double(NoopTodayTileSheet.minuteOfDay(date))
        if m < Self.from { m += 1440 }
        return CGFloat((m - Self.from) / Self.span) * width
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let w = proxy.size.width
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 6) {
                        ForEach(Array(nights.enumerated()), id: \.offset) { _, night in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.05)).frame(height: 8)
                                let a = x(night.start, width: w), b = x(night.end, width: w)
                                Capsule().fill(LinearGradient(colors: [tint.0, tint.1], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(8, b - a), height: 8)
                                    .offset(x: a)
                            }
                        }
                    }
                    if let bed {
                        let m = Double(bed) < Self.from ? Double(bed) + 1440 : Double(bed)
                        Rectangle().fill(Color.white.opacity(0.85)).frame(width: 1.5, height: CGFloat(nights.count) * 14 + 4)
                            .offset(x: CGFloat((m - Self.from) / Self.span) * w, y: -4)
                    }
                }
            }
            .frame(height: CGFloat(nights.count) * 14)
            // The clock under it: every four hours from 22:00.
            GeometryReader { proxy in
                ForEach([22, 2, 6, 10], id: \.self) { hour in
                    let m = Double(hour * 60) < Self.from ? Double(hour * 60) + 1440 : Double(hour * 60)
                    Text(NoopTodayTileSheet.hour.string(from: Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()))
                        .font(NoopHTMLFont.sans(NoopType.eyebrow))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .fixedSize()
                        .position(x: CGFloat((m - Self.from) / Self.span) * proxy.size.width, y: 7)
                }
            }
            .frame(height: 14)
        }
    }
}

/// Where the cycle is: an arc of the cycle's days with a dot on today's.
private struct NoopCycleArc: View {
    let day: Int?
    let length: Int?
    let tint: (Color, Color)

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            let radius = min(w / 2, h) - 10
            let center = CGPoint(x: w / 2, y: h - 4)
            let total = Double(max(21, length ?? 28))
            let at = day.map { min(1, Double($0) / total) }
            ZStack {
                Path { p in p.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false) }
                    .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                if let at {
                    Path { p in p.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(180 + 180 * at), clockwise: false) }
                        .stroke(LinearGradient(colors: [tint.1, tint.0], startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    let angle = Angle.degrees(180 + 180 * at).radians
                    Circle().fill(.white).frame(width: 14, height: 14)
                        .shadow(color: tint.1, radius: 6)
                        .position(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                }
            }
        }
    }
}

/// A calm sphere that breathes four in, six out.
private struct NoopBreathePreview: View {
    let tint: (Color, Color)
    @State private var inhale = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().fill(tint.0.opacity(0.12)).frame(width: 150, height: 150).scaleEffect(inhale ? 1 : 0.7)
            Circle()
                .fill(RadialGradient(colors: [tint.0, tint.1], center: .init(x: 0.35, y: 0.3), startRadius: 4, endRadius: 80))
                .frame(width: 104, height: 104)
                .scaleEffect(inhale ? 1.12 : 0.82)
                .shadow(color: tint.1.opacity(0.6), radius: 18)
            Text(inhale ? "In" : "Out")
                .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).tracking(1.5)
                .foregroundStyle(.white)
                .contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity)
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 4)) { inhale = true }
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                withAnimation(.easeInOut(duration: 6)) { inhale = false }
                try? await Task.sleep(nanoseconds: 6_000_000_000)
            }
        }
    }
}

/// A tile sheet's line. With `scrub`, a touch along it reads the value and time under the finger.
struct NoopTileLineChart: View {
    let points: [(Date, Double)]
    let tint: (Color, Color)
    let height: CGFloat
    var labels: (String, String)?
    var scrub = false
    var unit = ""

    @State private var picked: Date?

    private var pickedPoint: (Date, Double)? {
        guard let picked else { return nil }
        return points.min { abs($0.0.timeIntervalSince(picked)) < abs($1.0.timeIntervalSince(picked)) }
    }

    var body: some View {
        let values = points.map(\.1)
        let low = (values.min() ?? 0), high = (values.max() ?? 1)
        let pad = max(1, (high - low) * 0.15)
        VStack(spacing: 6) {
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                    AreaMark(x: .value("Time", p.0), yStart: .value("Floor", low - pad), yEnd: .value("Value", p.1))
                        .foregroundStyle(LinearGradient(colors: [tint.0.opacity(0.32), tint.0.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Time", p.0), y: .value("Value", p.1))
                        .foregroundStyle(tint.0)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                        .interpolationMethod(.monotone)
                }
                if let p = pickedPoint {
                    RuleMark(x: .value("Picked", p.0))
                        .foregroundStyle(NoopHTMLColor.inkSoft.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .annotation(position: .top, spacing: 2, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            Text("\(Int(p.1.rounded()))\(unit.isEmpty ? "" : " " + unit) · \(AppClock.hourMinuteFormatter().string(from: p.0))")
                                .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).monospacedDigit()
                                .foregroundStyle(NoopHTMLColor.canvas)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(NoopHTMLColor.inkSoft, in: Capsule())
                        }
                    PointMark(x: .value("Time", p.0), y: .value("Value", p.1))
                        .symbol { Circle().fill(.white).frame(width: 8, height: 8).shadow(color: tint.1, radius: 5) }
                } else if let last = points.last {
                    PointMark(x: .value("Time", last.0), y: .value("Value", last.1))
                        .symbol { Circle().fill(.white).frame(width: 8, height: 8).shadow(color: tint.1, radius: 5) }
                }
            }
            .chartYScale(domain: (low - pad)...(high + pad))
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .modifier(NoopChartScrub(enabled: scrub, picked: $picked))
            .frame(height: height)
            .padding(.top, scrub ? 18 : 0)
            if let labels { NoopTodayTileSheet.axisLabels(labels.0, labels.1) }
        }
    }
}

/// Touch-to-read on a chart, attached only where asked so other charts keep the sheet's drag.
private struct NoopChartScrub: ViewModifier {
    let enabled: Bool
    @Binding var picked: Date?

    func body(content: Content) -> some View {
        if enabled { content.chartXSelection(value: $picked) } else { content }
    }
}
