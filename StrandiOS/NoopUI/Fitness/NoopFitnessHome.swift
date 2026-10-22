#if os(iOS)
import SwiftUI
import StrandFitness
import WhoopStore

// MARK: - Fitness home

/// The Fitness tab: this week, today's activity, routines, training load, cardio and strength.
struct NoopFitnessHome: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var fitness: NoopFitnessModel
    @ObservedObject var layout: NoopFitnessSettings
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var profile: ProfileStore
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 0) {
                NoopScreenHeader("Fitness", eyebrow: Self.weekTitle) {
                    HStack(spacing: 8) {
                        NoopFitnessIconButton(glyph: .calendar) { navigation.push(.fitnessCalendar) }
                            .accessibilityLabel("Calendar")
                        NoopFitnessIconButton(glyph: .grid) { navigation.push(.fitnessEdit) }
                            .accessibilityLabel("Edit Fitness")
                    }
                }
                if let s = fitness.snapshot {
                    content(s)
                } else {
                    Text(fitness.isLoading ? "Reading your training…" : "")
                        .font(NoopHTMLFont.sans(13))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .padding(.top, 40)
                }
            }
        }
    }

    @ViewBuilder
    private func content(_ s: NoopFitnessSnapshot) -> some View {
        NoopFitnessWeekStrip(week: s.week, plans: layout.plans, selected: $selectedDay)
            .padding(.bottom, 22)
        ForEach(layout.sections) { section in
            self.section(section, s)
        }
        Button { navigation.push(.fitnessEdit) } label: {
            Text("Edit Fitness")
                .font(NoopHTMLFont.sans(14.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.inkSoft)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(NoopHTMLColor.borderStrong, lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
        .padding(.top, 6)
    }

    private func newRoutine() {
        navigation.fitnessRoutineID = nil
        navigation.push(.fitnessRoutineEdit)
    }

    private func open(_ metric: NoopFitnessMetric) {
        navigation.fitnessMetric = metric
        navigation.push(.fitnessDetail)
    }

    @ViewBuilder
    private func section(_ section: NoopFitnessSettings.Section, _ s: NoopFitnessSnapshot) -> some View {
        switch section {
        case .activity:
            sectionTitle("Activity") {
                NoopFitnessIconButton(glyph: .plus) { navigation.push(.pick) }
            }
            activity(s)
                .padding(.bottom, 26)
        case .routines:
            sectionTitle("Routines") {
                NoopFitnessIconButton(glyph: .plus) { newRoutine() }
                    .accessibilityLabel("New routine")
            }
            if s.routines.isEmpty {
                Button { newRoutine() } label: {
                    Text("Build a routine to start it in one tap and plan it on the calendar.")
                        .font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(NoopHTMLColor.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                }
                .buttonStyle(NoopHTMLPressStyle())
                .padding(.bottom, 26)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(s.routines) { r in
                            NoopFitnessRoutineCard(routine: r) {
                                navigation.fitnessRoutineID = r.id
                                navigation.push(.fitnessRoutine)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, -20)
                .padding(.bottom, 26)
            }
        case .load:
            sectionTitle("Training load")
            HStack(spacing: 10) {
                tap(.cardioLoad) { NoopFitnessLoadCard(title: "Cardio", reading: s.cardioLoad, decimals: 1) }
                tap(.muscularLoad) { NoopFitnessLoadCard(title: "Muscular", reading: s.muscularLoad, decimals: 0) }
            }
            .padding(.bottom, 26)
        case .cardio:
            let cards = section.cards.filter(layout.isShown)
            if !cards.isEmpty {
                sectionTitle("Cardio")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(cards, id: \.self) { card in cardioCard(card, s) }
                }
                .padding(.bottom, 26)
            }
        case .strength:
            let cards = section.cards.filter(layout.isShown)
            if !cards.isEmpty {
                sectionTitle("Strength")
                let small = cards.filter { $0 != .freshness }
                if !small.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(small, id: \.self) { card in strengthCard(card, s) }
                    }
                    .padding(.bottom, 10)
                }
                if cards.contains(.freshness) {
                    Button { navigation.push(.fitnessMuscles) } label: { NoopFitnessFreshnessCard(readings: s.freshness) }
                        .buttonStyle(NoopHTMLPressStyle())
                }
                Spacer().frame(height: 26)
            }
        }
    }

    private func tap<C: View>(_ metric: NoopFitnessMetric, @ViewBuilder _ card: () -> C) -> some View {
        Button { open(metric) } label: { card() }
            .buttonStyle(NoopHTMLPressStyle())
    }

    @ViewBuilder
    private func cardioCard(_ card: NoopFitnessSettings.Card, _ s: NoopFitnessSnapshot) -> some View {
        switch card {
        case .activeTime:
            tap(.activeTime) {
                NoopFitnessTotalCard(title: "Active time", value: Self.duration(s.activeSeconds.total),
                                     caption: "last \(s.periodDays) days", series: s.activeSeconds, tint: NoopHTMLColor.blue)
            }
        case .activeEnergy:
            tap(.activeEnergy) {
                NoopFitnessTotalCard(title: "Active energy", value: "\(Int(s.activeKcal.total.rounded()).formatted()) kcal",
                                     caption: "last \(s.periodDays) days", series: s.activeKcal, tint: NoopHTMLColor.blue)
            }
        case .vo2: tap(.vo2) { NoopFitnessVO2Card(readings: s.vo2Max) }
        case .recovery: tap(.recovery) { NoopFitnessRecoveryCard(reading: s.heartRateRecovery) }
        case .focus: tap(.focus) { NoopFitnessFocusCard(breakdown: s.cardioFocus) }
        case .zones: tap(.zones) { NoopFitnessZonesCard(minutes: s.zoneMinutes, names: s.zoneNames) }
        default: EmptyView()
        }
    }

    @ViewBuilder
    private func strengthCard(_ card: NoopFitnessSettings.Card, _ s: NoopFitnessSnapshot) -> some View {
        switch card {
        case .sets:
            tap(.sets) {
                if s.totalSets.total > 0 {
                    NoopFitnessTotalCard(title: "All muscles", value: "\(Int(s.totalSets.total))",
                                         caption: "working sets", series: s.totalSets, tint: NoopHTMLColor.blush)
                } else {
                    NoopFitnessEmptyCard(title: "All muscles", line: "Log a lift to see your sets")
                }
            }
        case .volume:
            tap(.volume) {
                if let top = s.topExercise {
                    NoopFitnessTotalCard(title: top.name, value: "\(Int(top.volume.total.rounded()).formatted()) kg",
                                         caption: "total volume", series: top.volume, tint: NoopHTMLColor.blush)
                } else {
                    NoopFitnessEmptyCard(title: "Volume", line: "Log a lift to see it here")
                }
            }
        default: EmptyView()
        }
    }

    @ViewBuilder
    private func activity(_ s: NoopFitnessSnapshot) -> some View {
        let day = s.week.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) }
        let sessions = day?.sessions ?? []
        if sessions.isEmpty {
            HStack(spacing: 13) {
                NoopCanonicalGlyph(name: .moon, size: 18, color: NoopHTMLColor.copy)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.05), in: Circle())
                Text(Calendar.current.isDateInToday(selectedDay) ? "Rest day so far" : "Rest day")
                    .font(NoopHTMLFont.sans(14.5, weight: .medium))
                    .foregroundStyle(NoopHTMLColor.inkSoft)
                Spacer()
            }
            .padding(16)
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(NoopHTMLColor.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
        } else {
            VStack(spacing: 8) {
                ForEach(sessions) { session in
                    NoopFitnessSessionButton(session: session, navigation: navigation, returnRoute: .fitness)
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        sectionTitle(text) { EmptyView() }
    }

    private func sectionTitle<T: View>(_ text: String, @ViewBuilder trailing: () -> T) -> some View {
        HStack {
            Text(text)
                .font(NoopHTMLFont.outfit(19))
                .foregroundStyle(NoopHTMLColor.ink)
            Spacer()
            trailing()
        }
        .padding(.bottom, 10)
    }

    static var weekTitle: String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return f.string(from: Date())
    }

    /// Every small card shares one height so a two-column row never looks ragged.
    static let cardHeight: CGFloat = 132

    static func duration(_ seconds: Double) -> String {
        let m = Int(seconds / 60)
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }
}

// MARK: - Week strip

struct NoopFitnessWeekStrip: View {
    let week: [NoopFitnessSnapshot.WeekDay]
    var plans: [NoopFitnessSettings.Plan] = []
    @Binding var selected: Date

    var body: some View {
        HStack(spacing: 6) {
            ForEach(week) { day in
                let isSelected = Calendar.current.isDate(day.date, inSameDayAs: selected)
                let isToday = Calendar.current.isDateInToday(day.date)
                let future = day.date > Date()
                Button { selected = day.date } label: {
                    VStack(spacing: 6) {
                        Text(Self.letter(day.date))
                            .font(NoopHTMLFont.sans(10.5, weight: .semibold))
                            .foregroundStyle(NoopHTMLColor.muted)
                        Text("\(Calendar.current.component(.day, from: day.date))")
                            .font(NoopHTMLFont.outfit(17, weight: isToday ? .medium : .regular))
                            .foregroundStyle(isToday ? NoopHTMLColor.blueLight : NoopHTMLColor.ink)
                        dayMark(day, future: future)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isSelected ? Color.white.opacity(0.07) : .clear,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isSelected ? NoopHTMLColor.borderStrong : .clear, lineWidth: 0.6))
                }
                .buttonStyle(NoopHTMLPressStyle())
            }
        }
    }

    @ViewBuilder
    private func dayMark(_ day: NoopFitnessSnapshot.WeekDay, future: Bool) -> some View {
        let strength = day.sessions.contains { $0.kind == .strength }
        let cardio = day.sessions.contains { $0.kind == .cardio }
        let planned = plans.contains { Calendar.current.isDate($0.date, inSameDayAs: day.date) }
        ZStack {
            Circle()
                .fill(day.sessions.isEmpty ? Color.white.opacity(0.04) : NoopHTMLColor.warm.opacity(0.22))
            if day.sessions.isEmpty && planned {
                Circle().strokeBorder(NoopHTMLColor.warm.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                NoopCanonicalGlyph(name: .weight, size: 12, color: NoopHTMLColor.warm.opacity(0.8))
            } else if day.sessions.isEmpty {
                Circle().strokeBorder(Color.white.opacity(future ? 0.12 : 0.0),
                                      style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            } else {
                NoopCanonicalGlyph(name: strength && !cardio ? .weight : .run, size: 14, color: NoopHTMLColor.warm)
            }
        }
        .frame(width: 26, height: 26)
    }

    static func letter(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEEE"
        return f.string(from: d)
    }
}

// MARK: - Cards

private struct NoopFitnessCardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }
}

extension View {
    fileprivate func fitnessCard() -> some View { modifier(NoopFitnessCardBackground()) }
}

struct NoopFitnessIconButton: View {
    let glyph: NoopCanonicalGlyphName
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            NoopCanonicalGlyph(name: glyph, size: 15, color: NoopHTMLColor.inkSoft)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.06), in: Circle())
                .overlay(Circle().stroke(NoopHTMLColor.borderStrong, lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

/// A session in a list: a lift opens its record; a manual or detected session opens the editor, and a
/// long press offers to delete it. Imported history is read-only.
struct NoopFitnessSessionButton: View {
    let session: NoopFitnessSession
    @ObservedObject var navigation: NoopNavigation
    let returnRoute: NoopRoute
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var model: AppModel
    @State private var editing: WorkoutRow?
    @State private var confirmDelete = false

    var body: some View {
        Button {
            if let lift = session.liftSessionID {
                navigation.selectedLiftSessionID = lift
                navigation.liftDetailReturnRoute = returnRoute
                navigation.push(.liftDetail)
            } else if session.editable {
                editing = session.row
            }
        } label: {
            NoopFitnessSessionRow(session: session)
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(session.liftSessionID == nil && !session.editable)
        .contextMenu {
            if session.editable {
                Button("Edit details") { editing = session.row }
                Button("Delete", role: .destructive) { confirmDelete = true }
            }
        }
        .confirmationDialog(session.detected ? "Delete this detected activity?" : "Delete this session?",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                guard let row = session.row else { return }
                Task {
                    await repo.deleteWorkout(row)
                    await repo.refresh()
                }
            }
        } message: {
            Text(session.detected ? "It will not be detected again." : "This removes it from your record.")
        }
        .sheet(item: Binding(get: { editing.map(NoopEditTarget.init) }, set: { editing = $0?.row })) { target in
            ManualWorkoutSheet(editing: target.row, reviewingSuggestion: session.detected) { row, replacing in
                Task {
                    await repo.saveManualWorkout(row, replacing: replacing)
                    await model.intelligence.analyzeRecent()
                    await repo.refresh()
                }
            }
            .environmentObject(repo)
        }
    }
}

private struct NoopEditTarget: Identifiable {
    let row: WorkoutRow
    var id: String { "\(row.source):\(row.startTs):\(row.sport)" }
}

struct NoopFitnessSessionRow: View {
    let session: NoopFitnessSession

    var body: some View {
        HStack(spacing: 13) {
            NoopCanonicalGlyph(name: Self.glyph(session), size: 18, color: NoopHTMLColor.warm)
                .frame(width: 38, height: 38)
                .background(NoopHTMLColor.warm.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .font(NoopHTMLFont.sans(14.5, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.ink)
                Text(detail)
                    .font(NoopHTMLFont.sans(12))
                    .foregroundStyle(NoopHTMLColor.copy)
            }
            Spacer()
            if session.detected {
                Text("detected")
                    .font(NoopHTMLFont.sans(10.5, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.warm)
                    .padding(.horizontal, 8).frame(height: 22)
                    .background(NoopHTMLColor.warm.opacity(0.12), in: Capsule())
            }
            if session.liftSessionID != nil || session.editable {
                NoopFixedChevron(direction: .right, color: NoopHTMLColor.chevronDim)
            }
        }
        .fitnessCard()
    }

    static func glyph(_ session: NoopFitnessSession) -> NoopCanonicalGlyphName {
        if session.kind == .strength { return .weight }
        let t = session.title.lowercased()
        if t.contains("swim") { return .wave }
        if t.contains("cycl") || t.contains("bike") || t.contains("spin") { return .bike }
        if t.contains("walk") || t.contains("hik") { return .walk }
        return .run
    }

    private var detail: String {
        let time = session.start.formatted(date: .omitted, time: .shortened)
        var parts = [time, NoopFitnessHome.duration(session.durationS)]
        if let k = session.kcal { parts.append("\(Int(k.rounded())) kcal") }
        return parts.joined(separator: " · ")
    }
}

struct NoopFitnessRoutineCard: View {
    let routine: NoopFitnessSnapshot.Routine
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                NoopCanonicalGlyph(name: .weight, size: 18, color: NoopHTMLColor.warm)
                    .padding(.bottom, 22)
                Text("Strength")
                    .font(NoopHTMLFont.sans(11.5, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.warm)
                Text(routine.name)
                    .font(NoopHTMLFont.sans(15, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.ink)
                    .lineLimit(1)
                Text("\(routine.exercises) \(routine.exercises == 1 ? "exercise" : "exercises") · \(routine.sets) \(routine.sets == 1 ? "set" : "sets")")
                    .font(NoopHTMLFont.sans(12))
                    .foregroundStyle(NoopHTMLColor.copy)
            }
            .frame(width: 168, alignment: .leading)
            .fitnessCard()
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

struct NoopFitnessEmptyCard: View {
    let title: String
    let line: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(NoopHTMLFont.sans(13, weight: .medium)).foregroundStyle(NoopHTMLColor.copy)
            Text("No data").font(NoopHTMLFont.outfit(21)).foregroundStyle(NoopHTMLColor.muted)
            Text(line).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.muted)
            Spacer(minLength: 0)
        }
        .frame(minHeight: NoopFitnessHome.cardHeight, alignment: .topLeading)
        .fitnessCard()
    }
}

// MARK: Training load

extension AcuteChronicLoad.Status {
    var title: String {
        switch self {
        case .calibrating: "Calibrating"
        case .detraining: "Detraining"
        case .maintaining: "Maintaining"
        case .productive: "Productive"
        case .fatigued: "Fatigued"
        }
    }

    var color: Color {
        switch self {
        case .calibrating: NoopHTMLColor.copy
        case .detraining: NoopHTMLColor.night
        case .maintaining: NoopHTMLColor.blueLight
        case .productive: NoopHTMLColor.green
        case .fatigued: NoopHTMLColor.warm
        }
    }
}

struct NoopFitnessLoadCard: View {
    let title: String
    let reading: AcuteChronicLoad.Reading
    let decimals: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(NoopHTMLFont.sans(13, weight: .medium)).foregroundStyle(NoopHTMLColor.copy)
            Text(reading.status.title)
                .font(NoopHTMLFont.outfit(20))
                .foregroundStyle(reading.status.color)
            NoopFitnessGauge(reading: reading, decimals: decimals)
                .frame(height: 118)
                .padding(.top, 8)
            Text("Optimal \(fmt(reading.optimal.lowerBound))–\(fmt(reading.optimal.upperBound))")
                .font(NoopHTMLFont.sans(11.5))
                .foregroundStyle(NoopHTMLColor.copy)
                .frame(maxWidth: .infinity)
        }
        .fitnessCard()
    }

    private func fmt(_ v: Double) -> String { String(format: "%.\(decimals)f", v) }
}

/// A 270° gauge: the track, the optimal band in green, and the current acute load as a dot.
struct NoopFitnessGauge: View {
    let reading: AcuteChronicLoad.Reading
    let decimals: Int

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height * 1.15)
            let r = size / 2 - 8
            let c = CGPoint(x: geo.size.width / 2, y: r + 8)
            let top = max(reading.gaugeMax, 0.0001)
            let f = { (v: Double) in min(1, max(0, v / top)) }
            ZStack {
                arc(c, r, 0, 1).stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                arc(c, r, f(reading.optimal.lowerBound), f(reading.optimal.upperBound))
                    .stroke(NoopHTMLColor.green.opacity(0.55), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                arc(c, r, 0, f(reading.acute))
                    .stroke(reading.status.color.opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                let a = angle(f(reading.acute))
                Circle()
                    .fill(NoopHTMLColor.ink)
                    .frame(width: 11, height: 11)
                    .position(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                Text(String(format: "%.\(decimals)f", reading.acute))
                    .font(NoopHTMLFont.outfit(26))
                    .foregroundStyle(NoopHTMLColor.ink)
                    .position(c)
            }
        }
    }

    private func angle(_ f: Double) -> Double { (135 + 270 * f) * .pi / 180 }

    private func arc(_ c: CGPoint, _ r: CGFloat, _ a: Double, _ b: Double) -> Path {
        var p = Path()
        p.addArc(center: c, radius: r, startAngle: .radians(angle(a)), endAngle: .radians(angle(b)), clockwise: false)
        return p
    }
}

// MARK: Running totals

struct NoopFitnessTotalCard: View {
    let title: String
    let value: String
    let caption: String
    let series: PeriodTotals.Series
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(NoopHTMLFont.sans(13, weight: .medium)).foregroundStyle(NoopHTMLColor.copy).lineLimit(1)
            Text(value).font(NoopHTMLFont.outfit(21)).foregroundStyle(NoopHTMLColor.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(caption).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.muted)
            NoopFitnessCumulativeChart(series: series, tint: tint)
                .frame(height: 46)
                .padding(.top, 12)
        }
        .frame(minHeight: NoopFitnessHome.cardHeight, alignment: .topLeading)
        .fitnessCard()
    }
}

/// This period against the one before it, both as running totals: the previous period in grey.
struct NoopFitnessCumulativeChart: View {
    let series: PeriodTotals.Series
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let top = max(series.total, series.previousTotal, 0.0001)
            ZStack {
                line(series.previous, top: top, in: geo.size)
                    .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
                line(series.current, top: top, in: geo.size)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))
                if let last = series.current.last {
                    Circle().fill(tint).frame(width: 7, height: 7)
                        .position(x: geo.size.width, y: geo.size.height * (1 - last / top))
                }
            }
        }
    }

    private func line(_ values: [Double], top: Double, in size: CGSize) -> Path {
        var p = Path()
        guard values.count > 1 else { return p }
        for (i, v) in values.enumerated() {
            let pt = CGPoint(x: size.width * Double(i) / Double(values.count - 1), y: size.height * (1 - v / top))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        return p
    }
}

/// A plain line from the lowest reading to the highest, for values that are levels rather than totals.
struct NoopFitnessLineChart: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let lo = values.min() ?? 0, hi = values.max() ?? 1
            let span = max(hi - lo, 0.0001)
            let y = { (v: Double) in geo.size.height * (1 - (v - lo) / span) }
            ZStack {
                Path { p in
                    for (i, v) in values.enumerated() {
                        let pt = CGPoint(x: geo.size.width * Double(i) / Double(max(1, values.count - 1)), y: y(v))
                        i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                    }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                if let last = values.last {
                    Circle().fill(tint).frame(width: 7, height: 7).position(x: geo.size.width, y: y(last))
                }
            }
        }
        .clipped()
    }
}

// MARK: VO₂ max, recovery, focus, zones

struct NoopFitnessVO2Card: View {
    let readings: [(date: Date, value: Double)]

    var body: some View {
        if let last = readings.last {
            VStack(alignment: .leading, spacing: 2) {
                Text("VO₂ max").font(NoopHTMLFont.sans(13, weight: .medium)).foregroundStyle(NoopHTMLColor.copy)
                Text(String(format: "%.1f", last.value)).font(NoopHTMLFont.outfit(21)).foregroundStyle(NoopHTMLColor.ink)
                Text("ml/kg/min · from Health").font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.muted)
                NoopFitnessLineChart(values: readings.map(\.value), tint: NoopHTMLColor.green)
                    .frame(height: 46)
                    .padding(.top, 12)
            }
            .frame(minHeight: NoopFitnessHome.cardHeight, alignment: .topLeading)
            .fitnessCard()
        } else {
            NoopFitnessEmptyCard(title: "VO₂ max", line: "Comes from Apple Health")
        }
    }
}

struct NoopFitnessRecoveryCard: View {
    let reading: (date: Date, drop: Double)?

    var body: some View {
        if let reading {
            VStack(alignment: .leading, spacing: 2) {
                Text("Heart rate recovery").font(NoopHTMLFont.sans(13, weight: .medium))
                    .foregroundStyle(NoopHTMLColor.copy).lineLimit(1).minimumScaleFactor(0.85)
                Text("\(Int(reading.drop.rounded())) bpm").font(NoopHTMLFont.outfit(21)).foregroundStyle(NoopHTMLColor.ink)
                Text("in the first minute").font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.muted)
                Text(band(reading.drop))
                    .font(NoopHTMLFont.sans(12, weight: .semibold))
                    .foregroundStyle(reading.drop >= 20 ? NoopHTMLColor.green : NoopHTMLColor.warm)
                    .padding(.top, 14)
                Text(reading.date.formatted(date: .abbreviated, time: .omitted))
                    .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.muted)
            }
            .frame(minHeight: NoopFitnessHome.cardHeight, alignment: .topLeading)
            .fitnessCard()
        } else {
            NoopFitnessEmptyCard(title: "Heart rate recovery", line: "Needs heart rate after a session")
        }
    }

    /// Under 12 bpm is the clinical flag (Cole et al. 1999); the rest are the usual training bands.
    private func band(_ drop: Double) -> String {
        drop < 12 ? "Low" : drop < 20 ? "Fair" : drop < 30 ? "Good" : "Excellent"
    }
}

struct NoopFitnessFocusCard: View {
    let breakdown: CardioFocus.Breakdown

    var body: some View {
        if let dominant = breakdown.dominant {
            VStack(alignment: .leading, spacing: 2) {
                Text("Cardio focus").font(NoopHTMLFont.sans(13, weight: .medium)).foregroundStyle(NoopHTMLColor.copy)
                Text("\(Int(((breakdown.shares[dominant] ?? 0) * 100).rounded()))%")
                    .font(NoopHTMLFont.outfit(21)).foregroundStyle(NoopHTMLColor.ink)
                Text(dominant.title).font(NoopHTMLFont.sans(12, weight: .semibold)).foregroundStyle(color(dominant))
                VStack(spacing: 6) {
                    ForEach(CardioFocus.Band.allCases, id: \.self) { b in
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.06))
                                Capsule().fill(color(b))
                                    .frame(width: max(0, g.size.width * (breakdown.shares[b] ?? 0)))
                            }
                        }
                        .frame(height: 7)
                    }
                }
                .padding(.top, 12)
            }
            .frame(minHeight: NoopFitnessHome.cardHeight, alignment: .topLeading)
            .fitnessCard()
        } else {
            NoopFitnessEmptyCard(title: "Cardio focus", line: "Needs heart rate in a session")
        }
    }

    private func color(_ b: CardioFocus.Band) -> Color {
        switch b {
        case .lowAerobic: NoopHTMLColor.blueLight
        case .highAerobic: NoopHTMLColor.warm
        case .anaerobic: NoopHTMLColor.red
        }
    }
}

struct NoopFitnessZonesCard: View {
    let minutes: [Double]
    let names: [String]

    var body: some View {
        if let topIndex = minutes.indices.max(by: { minutes[$0] < minutes[$1] }), minutes[topIndex] > 0 {
            VStack(alignment: .leading, spacing: 2) {
                Text("Heart rate zones").font(NoopHTMLFont.sans(13, weight: .medium)).foregroundStyle(NoopHTMLColor.copy)
                Text(names[safe: topIndex]).font(NoopHTMLFont.outfit(21)).foregroundStyle(NoopHTMLColor.ink)
                Text(NoopFitnessHome.duration(minutes[topIndex] * 60))
                    .font(NoopHTMLFont.sans(12, weight: .semibold)).foregroundStyle(Self.colors[topIndex])
                HStack(alignment: .bottom, spacing: 5) {
                    let top = minutes.max() ?? 1
                    ForEach(minutes.indices, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Self.colors[i])
                            .frame(height: max(3, 46 * minutes[i] / top))
                    }
                }
                .frame(height: 46, alignment: .bottom)
                .padding(.top, 12)
            }
            .frame(minHeight: NoopFitnessHome.cardHeight, alignment: .topLeading)
            .fitnessCard()
        } else {
            NoopFitnessEmptyCard(title: "Heart rate zones", line: "Needs heart rate in a session")
        }
    }

    static let colors: [Color] = [Color(hex: 0x4A6B7C), NoopHTMLColor.blueLight, NoopHTMLColor.blue,
                                  NoopHTMLColor.warm, NoopHTMLColor.amber]
}

private extension Array where Element == String {
    subscript(safe i: Int) -> String { indices.contains(i) ? self[i] : "" }
}

// MARK: Muscle freshness

struct NoopFitnessFreshnessCard: View {
    let readings: [MuscleFreshness.Reading]

    var body: some View {
        let shown = Array(readings.sorted { $0.percent < $1.percent }.prefix(6))
        VStack(alignment: .leading, spacing: 14) {
            Text("Muscle freshness").font(NoopHTMLFont.sans(13, weight: .medium)).foregroundStyle(NoopHTMLColor.copy)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 16) {
                ForEach(shown, id: \.group) { r in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(r.group.title).font(NoopHTMLFont.sans(14, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                        Text("\(Int(r.percent.rounded()))% recovered").font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy)
                        NoopFitnessDotMeter(percent: r.percent, color: Self.color(r.provisionalStatus))
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .fitnessCard()
    }

    static func color(_ s: MuscleFreshness.Status) -> Color {
        switch s {
        case .recovered: NoopHTMLColor.green
        case .fatigued: NoopHTMLColor.warm
        case .depleted: NoopHTMLColor.red
        case .calibrating: NoopHTMLColor.copy
        }
    }
}

/// Ten dots, filled up to the reading, the last filled one solid.
struct NoopFitnessDotMeter: View {
    let percent: Double
    let color: Color

    var body: some View {
        let filled = max(1, Int((percent / 10).rounded()))
        HStack(spacing: 4) {
            ForEach(0..<10, id: \.self) { i in
                Capsule()
                    .fill(i < filled ? color.opacity(i == filled - 1 ? 1 : 0.35) : Color.white.opacity(0.06))
                    .frame(width: 8, height: 11)
            }
        }
    }
}
#endif
