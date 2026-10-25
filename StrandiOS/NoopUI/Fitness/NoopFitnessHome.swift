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
    @State private var weekOffset = 0
    /// The page is arranged with the shared editor; cardio and strength stay live while editing so
    /// their cards can be hidden or shown in place.
    @StateObject private var pageLayout = NoopPageLayout(page: "fitness", catalog: NoopFitnessSettings.Section.allCases.map {
        NoopPageSection(id: $0.rawValue, title: $0.title, detail: Self.sectionDetail($0),
                        liveWhileEditing: !$0.cards.isEmpty)
    })
    @State private var pageEditing = NoopPageEditing()
    /// Cards hidden when editing began, put back if the edit is cancelled.
    @State private var hiddenAtStart: Set<NoopFitnessSettings.Card> = []
    @State private var savesAtStart = 0
    private var editing: Bool { pageEditing.active }
    @State private var planning = false
    @State private var allRoutines = false

    var body: some View {
        NoopScreen(topInset: 58) {
            VStack(alignment: .leading, spacing: 0) {
                NoopScreenHeader("Fitness", eyebrow: Self.dayTitle(selectedDay), tabRoot: true) {
                    HStack(spacing: 8) {
                        NoopFitnessIconButton(glyph: .ruler) { navigation.push(.fitnessBody) }
                            .accessibilityLabel("Body measurements and photos")
                        NoopFitnessIconButton(glyph: .calendar) { navigation.push(.fitnessCalendar) }
                            .accessibilityLabel("Calendar")
                        if !editing {
                            NoopFitnessIconButton(glyph: .grid) { beginEditing() }
                                .accessibilityLabel("Edit Fitness")
                        }
                    }
                }
                if let s = fitness.snapshot {
                    content(s)
                        .sheet(isPresented: $planning) { NoopFitnessPlanSheet(routines: s.routines).environmentObject(layout).noopSheet() }
                } else {
                    Text(fitness.isLoading ? "Reading your training…" : "")
                        .font(NoopHTMLFont.sans(NoopType.footnote))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .padding(.top, 40)
                }
            }
        }
        .noopEditBar($pageEditing, layout: pageLayout)
        .onAppear {
            // Carry an order arranged with the old editor into the shared one, once.
            if UserDefaults.standard.string(forKey: "noop.layout.fitness") == nil,
               layout.sections != NoopFitnessSettings.Section.allCases {
                pageLayout.save(layout.sections.map(\.rawValue))
            }
        }
        .onChange(of: pageLayout.order) { _, order in
            layout.sections = order.compactMap(NoopFitnessSettings.Section.init(rawValue:))
        }
        .onChange(of: pageEditing.active) { _, active in
            if !active, pageEditing.saves == savesAtStart { layout.hidden = hiddenAtStart }
        }
        .sheet(isPresented: $allRoutines) {
            NoopFitnessRoutineGrid(navigation: navigation, routines: fitness.snapshot?.routines ?? []).noopSheet()
        }
        .overlay(alignment: .top) {
            if let toast = layout.routineToast {
                Text(toast).font(NoopHTMLFont.sans(NoopType.subhead)).foregroundStyle(NoopHTMLColor.ink)
                    .padding(12).background(NoopHTMLColor.cardRaised, in: Capsule()).padding(.top, 50)
            }
        }
        .sensoryFeedback(.success, trigger: layout.routineToast)
        .task(id: layout.routineToast) {
            guard layout.routineToast != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { layout.routineToast = nil }
        }
    }

    @ViewBuilder
    private func content(_ s: NoopFitnessSnapshot) -> some View {
        NoopFitnessWeekStrip(week: week(s), plans: layout.plans, selected: $selectedDay)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 24).onEnded { v in
                guard abs(v.translation.width) > abs(v.translation.height) else { return }
                withAnimation(NoopMotion.swap) { shiftWeek(v.translation.width < 0 ? 1 : -1) }
            })
            .sensoryFeedback(.selection, trigger: weekOffset)
            .padding(.bottom, weekOffset == 0 ? 14 : 10)
        if weekOffset == 0, !editing {
            NoopFitnessStreakRow(sessions: s.history.sessions, now: s.history.now)
                .padding(.bottom, reviewReady(s) == nil ? 22 : 10)
            if let last = reviewReady(s) {
                Button {
                    navigation.fitnessReportStart = last
                    navigation.push(.fitnessReport)
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "sparkles").font(.system(size: 16, weight: .semibold)).foregroundStyle(NoopHTMLColor.voltInk)
                            .frame(width: 40, height: 40).background(NoopHTMLColor.volt, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your \(last.formatted(.dateTime.month(.wide))) review")
                                .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                            Text("Workouts, records and where the sets went")
                                .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(NoopHTMLColor.chevronDim)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(LinearGradient(colors: [NoopHTMLColor.volt.opacity(0.12), NoopHTMLColor.card],
                                               startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(NoopHTMLColor.volt.opacity(0.2), lineWidth: 0.6))
                }
                .buttonStyle(NoopHTMLPressStyle())
                .padding(.bottom, 22)
            }
        }
        if weekOffset != 0 {
            Button { withAnimation(NoopMotion.swap) { weekOffset = 0; selectedDay = Calendar.current.startOfDay(for: Date()) } } label: {
                Text(weekOffset < 0 ? "Back to this week ›" : "‹ Back to this week")
                    .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(NoopHTMLColor.blueLight)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(NoopHTMLPressStyle())
            .padding(.bottom, 16)
        }
        NoopEditableSections(layout: pageLayout, editing: $pageEditing, spacing: 0) { id in
            if let section = NoopFitnessSettings.Section(rawValue: id) {
                if editing && !section.cards.isEmpty {
                    cardEditor(section, s).padding(.bottom, 14)
                } else {
                    // A section is several views; one block, so it moves and is removed as one.
                    VStack(alignment: .leading, spacing: 0) { self.section(section, s) }
                }
            }
        }
        if editing {
            Button { navigation.push(.fitnessEdit) } label: {
                Text("Fitness settings").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.inkSoft).frame(maxWidth: .infinity).frame(minHeight: 46)
            }
            .buttonStyle(NoopHTMLPressStyle())
        }
    }

    /// In the first week of a month, last month's review — when last month had any training to review.
    private func reviewReady(_ s: NoopFitnessSnapshot) -> Date? {
        let cal = Calendar.current
        guard cal.component(.day, from: s.history.now) <= 7,
              let thisMonth = cal.dateInterval(of: .month, for: s.history.now)?.start,
              let last = cal.date(byAdding: .month, value: -1, to: thisMonth),
              s.history.sessions.contains(where: { cal.isDate($0.start, equalTo: last, toGranularity: .month) })
        else { return nil }
        return last
    }

    private func beginEditing() {
        hiddenAtStart = layout.hidden
        savesAtStart = pageEditing.saves
        NoopHaptics.prepare()
        NoopHaptics.play(.enterEdit)
        pageEditing.draft = pageLayout.order
        withAnimation(.easeInOut(duration: 0.22)) { pageEditing.active = true }
    }

    static func sectionDetail(_ section: NoopFitnessSettings.Section) -> String {
        switch section {
        case .activity: "The sessions and plans of the chosen day"
        case .routines: "Your routines, to start in one tap"
        case .load: "Cardio and muscular load against your normal"
        case .cardio: "Active time, energy, VO₂ max, recovery, focus and zones"
        case .strength: "Sets, volume and how fresh each muscle is"
        }
    }

    /// A section's cards while the page is being arranged, each with a badge to hide or show it.
    @ViewBuilder
    private func cardEditor(_ section: NoopFitnessSettings.Section, _ s: NoopFitnessSnapshot) -> some View {
        let small = section.cards.filter { $0 != .freshness }
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title.uppercased()).font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).tracking(1.2)
                .foregroundStyle(NoopHTMLColor.inkSoft).padding(.leading, 26)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(small, id: \.self) { card in
                    editableCard(card) {
                        if section == .cardio { cardioCard(card, s) } else { strengthCard(card, s) }
                    }
                }
            }
            if section.cards.contains(.freshness) {
                editableCard(.freshness) { NoopFitnessFreshnessCard(readings: s.freshness) }
            }
        }
    }

    // MARK: Edit in place

    /// What a section without cards holds, in one line, so the arranged page stays short.
    /// A card in edit mode: dimmed when hidden, with a badge to hide or show it.
    private func editableCard<C: View>(_ card: NoopFitnessSettings.Card, @ViewBuilder _ content: () -> C) -> some View {
        let shown = layout.isShown(card)
        return content()
            .allowsHitTesting(false)
            .opacity(shown ? 1 : 0.32)
            .overlay(alignment: .topLeading) {
                Button {
                    withAnimation(NoopMotion.swap) {
                        if shown { layout.hidden.insert(card) } else { layout.hidden.remove(card) }
                    }
                } label: {
                    Image(systemName: shown ? "minus.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 22)).symbolRenderingMode(.palette)
                        .foregroundStyle(.white, shown ? NoopHTMLColor.red : NoopHTMLColor.green)
                        .background(Circle().fill(NoopHTMLColor.canvas).padding(2))
                }
                .offset(x: -7, y: -7)
                .accessibilityLabel(shown ? "Hide \(card.title)" : "Show \(card.title)")
            }
    }

    private func newRoutine() {
        navigation.fitnessRoutineID = nil
        navigation.push(.fitnessRoutineEdit)
    }

    private func open(_ metric: NoopFitnessMetric) {
        navigation.fitnessMetric = metric
        navigation.fitnessExercise = metric == .volume ? fitness.snapshot?.topExercise?.name : nil
        navigation.push(.fitnessDetail)
    }

    @ViewBuilder
    private func section(_ section: NoopFitnessSettings.Section, _ s: NoopFitnessSnapshot) -> some View {
        switch section {
        case .activity:
            sectionTitle(Calendar.current.isDateInToday(selectedDay) ? "Today" : Self.dayTitle(selectedDay)) {
                NoopFitnessIconButton(glyph: .plus, compact: true) { navigation.plus() }
                    .accessibilityLabel("Start or log")
            }
            if Calendar.current.isDateInToday(selectedDay) { NoopActivityOffer().padding(.bottom, 10) }
            activity(s)
            Button { navigation.push(.across) } label: {
                HStack(spacing: 6) {
                    Text("Every session").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                    Text("· all of them, in aggregate").font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                    Spacer()
                    NoopFixedChevron(direction: .right, color: NoopHTMLColor.chevronDim)
                }
                .foregroundStyle(NoopHTMLColor.ink)
                .padding(.horizontal, 4)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(NoopHTMLPressStyle())
            .padding(.bottom, 20)
        case .routines:
            sectionTitle("Routines") {
                if !s.routines.isEmpty {
                    NoopActionButton(title: "See all", variant: .plain, size: .small, fullWidth: false) { allRoutines = true }
                }
                Menu {
                    Button { newRoutine() } label: { Label("New routine", systemImage: "plus") }
                    Button { navigation.push(.fitnessProgram) } label: { Label("Build a program for me", systemImage: "sparkles") }
                    Button { planning = true } label: { Label("Plan a routine", systemImage: "calendar.badge.plus") }
                    Button { allRoutines = true } label: { Label("All routines", systemImage: "list.bullet") }
                    Button { navigation.push(.liftImport) } label: { Label("Import from another app", systemImage: "square.and.arrow.down") }
                } label: {
                    NoopFitnessIconGlyph(glyph: .plus, compact: true)
                }
                .accessibilityLabel("Routines")
            }
            if s.routines.isEmpty {
                Button { newRoutine() } label: {
                    Text("Build a routine to start it in one tap and plan it on the calendar.")
                        .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(NoopHTMLColor.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                }
                .buttonStyle(NoopHTMLPressStyle())
                .padding(.bottom, 10)
                Button { navigation.push(.fitnessProgram) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles").font(.system(size: 13, weight: .semibold)).foregroundStyle(NoopHTMLColor.volt)
                        Text("Or let Noop build a program for you").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                            .foregroundStyle(NoopHTMLColor.ink)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(NoopHTMLColor.chevronDim)
                    }
                    .padding(.horizontal, 16).frame(minHeight: 48)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                            .contextMenu {
                                Button { navigation.fitnessRoutineID = r.id; navigation.push(.fitnessRoutine) } label: {
                                    Label("Open", systemImage: "list.bullet.rectangle")
                                }
                                Button { navigation.fitnessRoutineID = r.id; navigation.push(.fitnessRoutineEdit) } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button { planning = true } label: { Label("Plan on the calendar", systemImage: "calendar") }
                            }
                        }
                        Button { allRoutines = true } label: {
                            VStack(spacing: 8) {
                                NoopFixedChevron(direction: .right, color: NoopHTMLColor.inkSoft)
                                    .frame(width: 38, height: 38).background(Color.white.opacity(0.06), in: Circle())
                                Text("All routines").font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(NoopHTMLColor.inkSoft)
                            }
                            .frame(width: 112).frame(maxHeight: .infinity)
                            .fitnessCard()
                        }
                        .buttonStyle(NoopHTMLPressStyle())
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
                let day = min(selectedDay, Date())
                tap(.cardioLoad) { NoopFitnessLoadCard(title: "Cardio", reading: s.history.load(.cardio, asOf: day), decimals: 1) }
                tap(.muscularLoad) { NoopFitnessLoadCard(title: "Muscular", reading: s.history.load(.muscular, asOf: day), decimals: 0) }
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
                if s.activeSeconds.total > 0 || s.activeSeconds.previousTotal > 0 {
                    NoopFitnessTotalCard(title: "Active time", value: Self.duration(s.activeSeconds.total),
                                         caption: "last \(s.periodDays) days", series: s.activeSeconds, tint: NoopHTMLColor.blue)
                } else {
                    NoopFitnessEmptyCard(title: "Active time", line: "No workouts in the last \(s.periodDays) days")
                }
            }
        case .activeEnergy:
            tap(.activeEnergy) {
                if s.activeKcal.total > 0 || s.activeKcal.previousTotal > 0 {
                    NoopFitnessTotalCard(title: "Active energy", value: "\(Int(s.activeKcal.total.rounded()).formatted()) kcal",
                                         caption: "last \(s.periodDays) days", series: s.activeKcal, tint: NoopHTMLColor.blue)
                } else {
                    NoopFitnessEmptyCard(title: "Active energy", line: "Comes from your workouts' energy")
                }
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
                                         caption: Int(s.totalSets.total) == 1 ? "working set" : "working sets", series: s.totalSets, tint: NoopHTMLColor.blush)
                } else {
                    NoopFitnessEmptyCard(title: "All muscles", line: "Log a lift to see your sets")
                }
            }
        case .volume:
            tap(.volume) {
                if let top = s.topExercise {
                    NoopFitnessTotalCard(title: top.name, value: NoopFitnessFormat.kg(top.volume.total),
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
        let day = week(s).first { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) }
        let sessions = day?.sessions ?? []
        let planned = layout.plans.filter { p in
            Calendar.current.isDate(p.date, inSameDayAs: selectedDay) && !sessions.contains { $0.routineID == p.routineID }
        }
        if sessions.isEmpty, !planned.isEmpty {
            VStack(spacing: 8) {
                ForEach(planned) { plan in
                    Button {
                        navigation.fitnessRoutineID = plan.routineID
                        navigation.push(.fitnessRoutine)
                    } label: {
                        HStack(spacing: 13) {
                            NoopCanonicalGlyph(name: .weight, size: 17, color: NoopHTMLColor.volt)
                                .frame(width: 42, height: 42)
                                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .strokeBorder(NoopHTMLColor.volt.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("PLANNED").font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).tracking(1.1).foregroundStyle(NoopHTMLColor.volt)
                                Text(plan.routineName).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                            }
                            Spacer()
                            NoopFixedChevron(direction: .right, color: NoopHTMLColor.chevronDim)
                        }
                        .fitnessCard()
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                }
            }
        } else if sessions.isEmpty {
            HStack(spacing: 13) {
                NoopCanonicalGlyph(name: .moon, size: 18, color: NoopHTMLColor.copy)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.05), in: Circle())
                Text(Calendar.current.isDateInToday(selectedDay) ? "Rest day so far" : "Rest day")
                    .font(NoopHTMLFont.sans(NoopType.subhead, weight: .medium))
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
        NoopSectionHeader(text).padding(.bottom, NoopSpace.xxs)
    }

    /// The app's section header (NoopSystem): label, then trailing controls at the small control size.
    private func sectionTitle<T: View>(_ text: String, @ViewBuilder trailing: () -> T) -> some View {
        NoopSectionHeader(title: text, trailing: trailing).padding(.bottom, NoopSpace.xxs)
    }

    /// The seven days of the week `weekOffset` weeks from this one, Monday first, from the full history.
    private func week(_ s: NoopFitnessSnapshot) -> [NoopFitnessSnapshot.WeekDay] {
        guard weekOffset != 0 else { return s.week }
        var cal = Calendar.current
        cal.firstWeekday = 2
        let base = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let monday = cal.date(byAdding: .weekOfYear, value: weekOffset, to: base) ?? base
        return (0..<7).compactMap { i in
            guard let d = cal.date(byAdding: .day, value: i, to: monday) else { return nil }
            return .init(date: d, sessions: s.history.sessions.filter { cal.isDate($0.start, inSameDayAs: d) }.sorted { $0.start < $1.start })
        }
    }

    private func shiftWeek(_ by: Int) {
        let next = weekOffset + by
        guard next <= 4, next >= -56 else { return }
        weekOffset = next
        let cal = Calendar.current
        selectedDay = cal.date(byAdding: .weekOfYear, value: by, to: selectedDay) ?? selectedDay
        if weekOffset == 0 { selectedDay = cal.startOfDay(for: Date()) }
    }

    static func dayTitle(_ d: Date) -> String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return f.string(from: d)
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
                            .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
                            .foregroundStyle(NoopHTMLColor.muted)
                        Text("\(Calendar.current.component(.day, from: day.date))")
                            .font(NoopHTMLFont.outfit(NoopType.body, weight: isToday ? .medium : .regular))
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
                .fill(day.sessions.first.map { NoopFitnessSessionRow.tint($0).opacity(0.2) } ?? Color.white.opacity(0.04))
            if day.sessions.isEmpty && planned {
                Circle().strokeBorder(NoopHTMLColor.volt.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                NoopCanonicalGlyph(name: .weight, size: 12, color: NoopHTMLColor.volt.opacity(0.8))
            } else if day.sessions.isEmpty {
                Circle().strokeBorder(Color.white.opacity(future ? 0.12 : 0.0),
                                      style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            } else if let first = day.sessions.first {
                NoopCanonicalGlyph(name: NoopFitnessSessionRow.glyph(first), size: 14, color: NoopFitnessSessionRow.tint(first))
            }
        }
        .frame(width: 26, height: 26)
        .overlay(alignment: .topTrailing) {
            if day.sessions.count > 1 {
                Text("\(day.sessions.count)")
                    .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .bold)).foregroundStyle(NoopHTMLColor.canvas)
                    .frame(width: 14, height: 14).background(NoopHTMLColor.ink, in: Circle())
                    .offset(x: 5, y: -4)
            }
        }
    }

    static func letter(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEEE"
        return f.string(from: d)
    }
}

// MARK: - Cards

struct NoopFitnessCardBackground: ViewModifier {
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
    func fitnessCard() -> some View { modifier(NoopFitnessCardBackground()) }
}

struct NoopFitnessIconGlyph: View {
    let glyph: NoopCanonicalGlyphName
    var compact = false

    var body: some View {
        // Header and section-header icon buttons are one size everywhere (NoopControlSize.small).
        let size: NoopControlSize = .small
        NoopIconDiscShape(size: size) {
            NoopCanonicalGlyph(name: glyph, size: size.icon, color: NoopHTMLColor.inkSoft)
        }
    }
}

struct NoopFitnessIconButton: View {
    let glyph: NoopCanonicalGlyphName
    /// Beside a section label: a 30 pt circle sized to the label beside it, with the full 44 pt hit area.
    /// The 40 pt default belongs to the page header, beside the screen title.
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            NoopFitnessIconGlyph(glyph: glyph, compact: compact)
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

/// A session in a list: a lift opens its record; a manual or detected session opens the editor, and a
/// long press offers to delete it. Imported history is read-only.
/// Weeks in a row with a workout (`TrainingStreak`), the last eight weeks as dots, and what this week
/// still needs. Short detected bouts do not count: a streak is for training the lifter chose to do.
struct NoopFitnessStreakRow: View {
    let sessions: [NoopFitnessSession]
    let now: Date

    private var dates: [Date] {
        sessions.filter { !$0.detected || $0.kind == .strength || $0.durationS >= 20 * 60 }.map(\.start)
    }

    var body: some View {
        let r = TrainingStreak.reading(sessionDates: dates, now: now)
        let tint = r.weeks == 0 ? NoopHTMLColor.copy : r.atRisk ? NoopHTMLColor.amber : NoopHTMLColor.warm
        HStack(spacing: 13) {
            Image(systemName: r.weeks == 0 ? "flame" : "flame.fill")
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(tint)
                .symbolEffect(.bounce, value: r.weeks)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(r.weeks == 0 ? "No streak yet" : "\(r.weeks)-week streak")
                    .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                    .contentTransition(.numericText())
                Text(subtitle(r)).font(NoopHTMLFont.sans(NoopType.caption))
                    .foregroundStyle(r.atRisk ? NoopHTMLColor.amber : NoopHTMLColor.copy)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            HStack(spacing: 4) {
                ForEach(Array(lastWeeks.enumerated()), id: \.offset) { i, trained in
                    let current = i == lastWeeks.count - 1
                    Circle()
                        .fill(trained ? tint : Color.white.opacity(current ? 0.0 : 0.10))
                        .overlay(Circle().strokeBorder(current && !trained ? tint.opacity(0.7) : .clear,
                                                       style: StrokeStyle(lineWidth: 1, dash: [2, 2])))
                        .frame(width: 8, height: 8)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
        .accessibilityElement(children: .combine)
    }

    private func subtitle(_ r: TrainingStreak.Reading) -> String {
        if r.weeks == 0 { return "Train once this week to start one." }
        let best = r.best > r.weeks ? " · best \(r.best)" : ""
        if r.thisWeekDone {
            return "\(r.thisWeekCount) \(r.thisWeekCount == 1 ? "workout" : "workouts") this week\(best)"
        }
        return r.daysLeft <= 1 ? "Train today to keep it" : "Train in the next \(r.daysLeft) days to keep it"
    }

    /// Eight weeks, oldest first, this week last: whether each had a workout.
    private var lastWeeks: [Bool] {
        let cal = Calendar.current
        guard let thisWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        let starts = Set(dates.filter { $0 <= now }.compactMap { cal.dateInterval(of: .weekOfYear, for: $0)?.start })
        return (0..<8).reversed().map { back in
            cal.date(byAdding: .weekOfYear, value: -back, to: thisWeek).map(starts.contains) ?? false
        }
    }
}

struct NoopFitnessSessionButton: View {
    let session: NoopFitnessSession
    @ObservedObject var navigation: NoopNavigation
    let returnRoute: NoopRoute
    var showsDate = false
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var model: AppModel
    @State private var editing: WorkoutRow?
    @State private var confirming: WorkoutRow?
    @State private var showingLift = false
    @EnvironmentObject private var liftFlow: NoopLiftFlowModel
    @State private var confirmDelete = false

    var body: some View {
        Button {
            if let lift = session.liftSessionID {
                navigation.selectedLiftSessionID = lift
                navigation.liftDetailReturnRoute = returnRoute
                showingLift = true
            } else if session.editable {
                confirming = session.row
            }
        } label: {
            NoopFitnessSessionRow(session: session, showsDate: showsDate)
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(session.liftSessionID == nil && !session.editable)
        .contextMenu {
            if session.editable {
                Button("Edit details") { confirming = session.row }
                Button("Delete", role: .destructive) { confirmDelete = true }
            }
        }
        .confirmationDialog(session.detected ? "Delete this detected activity?" : "Delete this session?",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                guard let row = session.row else { return }
                Task {
                    await repo.deleteWorkout(row)
                    NoopFitnessModel.markChanged()
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
                    NoopFitnessModel.markChanged()
                    await model.intelligence.analyzeRecent()
                    await repo.refresh()
                }
            }
            .environmentObject(repo)
            .noopSheet()
        }
        .sheet(isPresented: $showingLift) {
            NoopLiftDetailScreen(navigation: navigation, flow: liftFlow, asSheet: true)
                .environmentObject(repo)
                .noopSheet()
        }
        .sheet(item: Binding(get: { confirming.map(NoopEditTarget.init) }, set: { confirming = $0?.row })) { target in
            NoopActivityConfirmSheet(row: target.row)
                .environmentObject(repo)
                .environmentObject(model)
                .noopSheet()
        }
    }
}

private struct NoopEditTarget: Identifiable {
    let row: WorkoutRow
    var id: String { "\(row.source):\(row.startTs):\(row.sport)" }
}

struct NoopFitnessSessionRow: View {
    let session: NoopFitnessSession
    var showsDate = false

    var body: some View {
        let tint = Self.tint(session)
        HStack(spacing: 13) {
            NoopCanonicalGlyph(name: Self.glyph(session), size: 18, color: tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(when).font(NoopHTMLFont.sans(NoopType.caption, weight: .medium)).foregroundStyle(NoopHTMLColor.copy)
                    if session.detected {
                        Text("detected")
                            .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).foregroundStyle(NoopHTMLColor.volt)
                            .padding(.horizontal, 6).frame(minHeight: 17)
                            .background(NoopHTMLColor.volt.opacity(0.12), in: Capsule())
                    }
                }
                Text(session.title)
                    .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.ink)
                    .lineLimit(1)
                HStack(spacing: 10) {
                    chip("clock", NoopFitnessHome.duration(session.durationS))
                    if let e = session.row?.strain, e > 0 { chip("bolt.fill", String(format: "%.1f", e), tint: NoopHTMLColor.volt) }
                    if let k = session.kcal, k > 0 { chip("flame.fill", "\(Int(k.rounded()))", tint: NoopHTMLColor.amber) }
                    if let hr = session.row?.avgHr, hr > 0 { chip("heart.fill", "\(hr)", tint: NoopHTMLColor.red) }
                }
            }
            Spacer(minLength: 4)
            if session.liftSessionID != nil || session.editable {
                NoopFixedChevron(direction: .right, color: NoopHTMLColor.chevronDim)
            }
        }
        .fitnessCard()
        .accessibilityElement(children: .combine)
    }

    private func chip(_ symbol: String, _ text: String, tint: Color = NoopHTMLColor.copy) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(tint)
            Text(text).font(NoopHTMLFont.sans(NoopType.caption, weight: .medium)).foregroundStyle(NoopHTMLColor.inkSoft).monospacedDigit()
        }
    }

    private var when: String {
        showsDate
            ? session.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
            : session.start.formatted(date: .omitted, time: .shortened)
    }

    static func glyph(_ session: NoopFitnessSession) -> NoopCanonicalGlyphName {
        if session.kind == .strength { return .weight }
        let t = session.title.lowercased()
        if t.contains("swim") { return .wave }
        if t.contains("cycl") || t.contains("bike") || t.contains("spin") { return .bike }
        if t.contains("walk") || t.contains("hik") { return .walk }
        return .run
    }

    /// One colour per kind of session, the same on the strip, the rows and the calendar.
    static func tint(_ session: NoopFitnessSession) -> Color {
        switch glyph(session) {
        case .weight: NoopHTMLColor.volt
        case .wave: NoopHTMLColor.blueLight
        case .bike: NoopHTMLColor.blue
        case .walk: NoopHTMLColor.green
        default: NoopHTMLColor.blush
        }
    }
}

struct NoopFitnessRoutineCard: View {
    let routine: NoopFitnessSnapshot.Routine
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                NoopCanonicalGlyph(name: .weight, size: 18, color: NoopHTMLColor.volt)
                    .padding(.bottom, 22)
                Text("Strength")
                    .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.volt)
                Text(routine.name)
                    .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.ink)
                    .lineLimit(1)
                Text("\(routine.exercises) \(routine.exercises == 1 ? "exercise" : "exercises") · \(routine.sets) \(routine.sets == 1 ? "set" : "sets")")
                    .font(NoopHTMLFont.sans(NoopType.caption))
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
            Text(title).font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium)).foregroundStyle(NoopHTMLColor.copy)
            Text("No data").font(NoopHTMLFont.outfit(NoopType.title3)).foregroundStyle(NoopHTMLColor.muted)
            Text(line).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.muted)
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
            Text(title).font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium)).foregroundStyle(NoopHTMLColor.copy)
            Text(reading.status.title)
                .font(NoopHTMLFont.outfit(NoopType.title3))
                .foregroundStyle(reading.status.color)
            NoopFitnessGauge(reading: reading, decimals: decimals)
                .frame(height: 118)
                .padding(.top, 8)
            // Calibrating has no baseline yet, so its optimal band is 0–0: say what it is waiting for instead.
            Text(reading.status == .calibrating ? "Needs a few weeks of sessions"
                 : "Optimal \(fmt(reading.optimal.lowerBound))–\(fmt(reading.optimal.upperBound))")
                .font(NoopHTMLFont.sans(NoopType.caption))
                .multilineTextAlignment(.center)
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
                if reading.status != .calibrating {
                    arc(c, r, f(reading.optimal.lowerBound), f(reading.optimal.upperBound))
                        .stroke(NoopHTMLColor.green.opacity(0.55), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                }
                arc(c, r, 0, f(reading.acute))
                    .stroke(reading.status.color.opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                if reading.acute > 0 {
                    let a = angle(f(reading.acute))
                    Circle()
                        .fill(NoopHTMLColor.ink)
                        .frame(width: 11, height: 11)
                        .position(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                }
                Text(reading.acute > 0 ? String(format: "%.\(decimals)f", reading.acute) : "–")
                    .font(NoopHTMLFont.outfit(NoopType.title2))
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
            Text(title).font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium)).foregroundStyle(NoopHTMLColor.copy).lineLimit(1)
            Text(value).font(NoopHTMLFont.outfit(NoopType.title3)).foregroundStyle(NoopHTMLColor.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(caption).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.muted)
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
                Text("VO₂ max").font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium)).foregroundStyle(NoopHTMLColor.copy)
                Text(String(format: "%.1f", last.value)).font(NoopHTMLFont.outfit(NoopType.title3)).foregroundStyle(NoopHTMLColor.ink)
                Text("ml/kg/min · from Health").font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.muted)
                NoopFitnessLineChart(values: Self.weekly(readings), tint: NoopHTMLColor.green)
                    .frame(height: 46)
                    .padding(.top, 12)
            }
            .frame(minHeight: NoopFitnessHome.cardHeight, alignment: .topLeading)
            .fitnessCard()
        } else {
            NoopFitnessEmptyCard(title: "VO₂ max", line: "Comes from Apple Health")
        }
    }

    /// One mean per week over the last half year: daily estimates jump by a point or more from walk
    /// to walk, which drew as noise rather than a trend.
    static func weekly(_ readings: [(date: Date, value: Double)]) -> [Double] {
        let cal = Calendar.current
        let from = cal.date(byAdding: .weekOfYear, value: -26, to: Date()) ?? .distantPast
        var weeks: [(Date, [Double])] = []
        for r in readings where r.date >= from {
            let w = cal.dateInterval(of: .weekOfYear, for: r.date)?.start ?? r.date
            if weeks.last?.0 == w { weeks[weeks.count - 1].1.append(r.value) } else { weeks.append((w, [r.value])) }
        }
        return weeks.map { $0.1.reduce(0, +) / Double($0.1.count) }
    }
}

struct NoopFitnessRecoveryCard: View {
    let reading: (date: Date, drop: Double)?

    var body: some View {
        if let reading {
            VStack(alignment: .leading, spacing: 2) {
                Text("Heart rate recovery").font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium))
                    .foregroundStyle(NoopHTMLColor.copy).lineLimit(1).minimumScaleFactor(0.85)
                Text("\(Int(reading.drop.rounded())) bpm").font(NoopHTMLFont.outfit(NoopType.title3)).foregroundStyle(NoopHTMLColor.ink)
                Text("in the first minute").font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.muted)
                Text(band(reading.drop))
                    .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                    .foregroundStyle(reading.drop >= 20 ? NoopHTMLColor.green : NoopHTMLColor.warm)
                    .padding(.top, 14)
                Text(reading.date.formatted(date: .abbreviated, time: .omitted))
                    .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.muted)
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
                Text("Cardio focus").font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium)).foregroundStyle(NoopHTMLColor.copy)
                Text("\(Int(((breakdown.shares[dominant] ?? 0) * 100).rounded()))%")
                    .font(NoopHTMLFont.outfit(NoopType.title3)).foregroundStyle(NoopHTMLColor.ink)
                Text(dominant.title).font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(color(dominant))
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
                Text("Heart rate zones").font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium)).foregroundStyle(NoopHTMLColor.copy)
                Text(names[safe: topIndex]).font(NoopHTMLFont.outfit(NoopType.title3)).foregroundStyle(NoopHTMLColor.ink)
                Text(NoopFitnessHome.duration(minutes[topIndex] * 60))
                    .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(Self.colors[topIndex])
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
        let sorted = readings.sorted { $0.percent < $1.percent }
        let shown = Array(sorted.prefix(6))
        let tracked = readings.filter { !$0.untracked }
        // Only muscles with three training days have a reading worth calling ready or tired; the rest are
        // still a guess from a set or two, so they are counted as learning and drawn grey.
        let calibrated = tracked.filter { $0.status != .calibrating }
        let learning = tracked.count - calibrated.count
        let ready = calibrated.filter { $0.status == .recovered }.count
        let tired = calibrated.filter { $0.status == .fatigued || $0.status == .depleted }.count
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Muscle freshness").font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium)).foregroundStyle(NoopHTMLColor.copy)
                    Text(tracked.isEmpty ? "Log a lift to see it"
                         : calibrated.isEmpty ? "Still calibrating your muscles"
                         : tired == 0 ? "Everything is ready" : "\(tired) still recovering · \(ready) ready")
                        .font(NoopHTMLFont.outfit(NoopType.title3)).foregroundStyle(NoopHTMLColor.ink)
                    if learning > 0 {
                        Text("\(learning) \(learning == 1 ? "muscle" : "muscles") still calibrating. Estimated from the sets and cardio you log, it settles after three training days.")
                            .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                NoopFixedChevron(direction: .right, color: NoopHTMLColor.chevronDim)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                ForEach(shown, id: \.group) { r in
                    let tint = Self.color(r.status)
                    HStack(spacing: 10) {
                        NoopFitnessMuscleThumb(group: r.group, tint: tint)
                            .frame(width: 30, height: 46)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(r.group.title).font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                                .lineLimit(1)
                            Text(r.untracked ? "No data" : "\(Int(r.percent.rounded()))%").font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(tint)
                            NoopFitnessDotMeter(percent: r.untracked ? 0 : r.percent, color: tint)
                        }
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
        let filled = percent <= 0 ? 0 : max(1, Int((percent / 10).rounded()))
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
