import Foundation
import SwiftUI

enum NoopAct: Int, CaseIterable {
    case night = 1
    case day
    case effort
    case picture
    case plumbing
    case ages
    case svea
    case goals
    case instrument
}

enum NoopTab: String, CaseIterable, Identifiable {
    case today = "Today"
    case trends = "Trends"
    case rest = "Rest"
    case you = "You"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .trends: "chart.bar.xaxis"
        case .rest: "moon"
        case .you: "person"
        }
    }

    var root: NoopRoute {
        switch self {
        case .today: .today
        case .trends: .trends
        case .rest: .rest
        case .you: .you
        }
    }
}

/// Canonical HTML routes. Notification mirroring is intentionally absent: the user removed that
/// feature because the strap firmware has no support for it.

/// §10's six curves, named so a transition can be referred to rather than re-typed. Nothing here
/// is new: four of them simply had no name, which is why they were being missed.
enum NoopMotion {
    /// Every pushed screen. 300 ms, 9 pt rise + fade.
    static let enter = Animation.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.3)
    /// Full-screen covers and sheets — anything arriving from the bottom edge over what stays.
    static let coverIn = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.34)
    static let coverOut = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.3)
    /// Content changing inside a container that stays: the session card's three states, the paused
    /// word, the tab tint, and a tab-level arrival — which came from nowhere, so it does not rise.
    static let swap = Animation.easeInOut(duration: 0.22)
    static let arrive = Animation.easeInOut(duration: 0.2)
    /// Things arriving into the chrome rather than over it: the live bar, and the bottom inset
    /// growing with it — one animation, two properties.
    static let settle = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.26)
    /// Anything that snaps into a detent.
    static let overshoot = Animation.timingCurve(0.34, 1.25, 0.64, 1, duration: 0.24)
    // `tick` is linear and continuous — the elapsed numeral, the import fill, the charge drain.
    // It is deliberately not an Animation: easing a clock makes it run fast in the middle.

    /// How the last route change arrived, which is what decides whether the screen rises.
    enum Arrival {
        case pushed
        case arrived
        case coverIn
        case coverOut
    }
}

enum NoopRoute: String, CaseIterable, Identifiable {
    // Act 1
    case rest, tonight, why, debt, alarm
    // Act 2
    case today, inbox, charge, day, vitals, stress, heart
    // Act 3
    case session, pick, ready, live, intervals, detail, across
    // Act 4
    case trends, capacity, rhythm, year
    // Act 5
    case you, record, zones, history, strap, devices, data, settings, widgets, lab, onboard, pair, position
    // Act 6
    case ages, building, driver, method, health
    // Act 7
    case coach, gate, setup, consent, memory
    // Act 8
    case goal, setGoal = "set", labs, picker, review, marker
    // Act 9
    case instrumentIndex = "index", instrumentMetric = "metric", instrumentCompare = "compare", instrumentEffects = "effects"

    var id: String { rawValue }

    var act: NoopAct {
        switch self {
        case .rest, .tonight, .why, .debt, .alarm: .night
        case .today, .inbox, .charge, .day, .vitals, .stress, .heart: .day
        case .session, .pick, .ready, .live, .intervals, .detail, .across: .effort
        case .trends, .capacity, .rhythm, .year: .picture
        case .you, .record, .zones, .history, .strap, .devices, .data, .settings, .widgets, .lab, .onboard, .pair,
             .position: .plumbing
        case .ages, .building, .driver, .method, .health: .ages
        case .coach, .gate, .setup, .consent, .memory: .svea
        case .goal, .setGoal, .labs, .picker, .review, .marker: .goals
        case .instrumentIndex, .instrumentMetric, .instrumentCompare, .instrumentEffects: .instrument
        }
    }

    /// The highlighted destination follows the cross-Act grammar of the HTML.
    var tab: NoopTab {
        switch self {
        case .rest, .tonight, .why, .debt, .alarm:
            .rest
        case .today, .inbox, .charge, .day, .vitals, .stress, .heart,
             .session, .pick, .ready, .live, .intervals, .detail, .across,
             .coach, .gate, .setup, .consent, .memory:
            .today
        case .trends, .capacity, .rhythm, .year,
             .ages, .building, .driver, .method, .health,
             .instrumentIndex, .instrumentMetric, .instrumentCompare, .instrumentEffects:
            .trends
        case .you, .record, .zones, .history, .strap, .devices, .data, .settings,
             .widgets, .lab, .onboard, .pair, .position,
             .goal, .setGoal, .labs, .picker, .review, .marker:
            .you
        }
    }

    var hidesBottomBar: Bool {
        switch self {
        case .ready, .live, .intervals, .onboard, .pair: true
        default: false
        }
    }
}

enum NoopWorkout: String, CaseIterable, Identifiable, Codable {
    case steadyRide = "Steady ride"
    case intervals = "Intervals"
    case longWalk = "Long walk"
    case strength = "Strength"
    case easySwim = "Easy swim"

    var id: String { rawValue }

    var minutes: Int {
        switch self {
        case .steadyRide: 42
        case .intervals: 34
        case .longWalk: 55
        case .strength: 38
        case .easySwim: 30
        }
    }

    var zone: String {
        switch self {
        case .steadyRide: "Zone 2 · 112–128"
        case .intervals: "6 × 2 min · Zone 4"
        case .longWalk: "Easy · below 112"
        case .strength: "Controlled sets"
        case .easySwim: "Zone 2 · 108–124"
        }
    }

    var symbol: String {
        switch self {
        case .steadyRide: "bicycle"
        case .intervals: "timer"
        case .longWalk: "figure.walk"
        case .strength: "dumbbell"
        case .easySwim: "figure.pool.swim"
        }
    }
}

/// The one completed-session record shared by Today, Session and Detail.  Keeping the measured
/// facts together prevents those three surfaces from silently recomputing different answers.
struct NoopFinishedSessionRecord: Codable, Equatable {
    let day: String
    let workout: NoopWorkout
    let endedAt: Date
    let durationSeconds: Int
    let distanceKilometres: Double?
    let chargeCost: Int?
    let sleepNeedMinutes: Int?

    var minutes: Int {
        max(1, Int((Double(durationSeconds) / 60).rounded()))
    }

    func whenLabel(relativeTo now: Date = Date()) -> String {
        if now.timeIntervalSince(endedAt) < 5 * 60 { return "Just now" }
        return endedAt.formatted(date: .omitted, time: .shortened)
    }

    var distanceLabel: String? {
        distanceKilometres.map { value in
            value.formatted(.number.precision(.fractionLength(1)))
        }
    }
}

enum NoopCoachVoice: String, CaseIterable, Identifiable {
    case plain = "Plain"
    case quiet = "Quiet"
    case direct = "Direct"
    case off = "Off"
    var id: String { rawValue }
}

enum NoopGoalKind: String, CaseIterable, Identifiable {
    case distance = "A distance"
    case pace = "A pace"
    case sleep = "Sleep regularity"
    case composition = "Body composition"
    var id: String { rawValue }
}

/// The six one-tap observations in Act 2, kept in the same order as the canonical HTML.
enum NoopDayLogKind: String, CaseIterable, Identifiable, Codable {
    case coffee = "Coffee"
    case water = "Water"
    case meal = "Meal"
    case alcohol = "Alcohol"
    case intimacy = "Intimacy"
    case nap = "Nap"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .coffee: "caffeine clock starts"
        case .water: "a glass"
        case .meal: "anything substantial"
        case .alcohol: "one drink"
        case .intimacy: "private, on device"
        case .nap: "twenty minutes or more"
        }
    }
}

private struct NoopStoredDayLog: Codable {
    let day: String
    let counts: [String: Int]
}

enum NoopDataState: String {
    case idle, reading, written, rejected
}

enum NoopOverlay: Identifiable, Equatable {
    case nightJournal
    case dayLog
    case loggedItems
    case addRecord
    case goalEditor
    case deepInsightsConfirmation
    case destructiveConfirmation(String)
    case importCatalog

    var id: String {
        switch self {
        case .nightJournal: "night-journal"
        case .importCatalog: "import-catalog"
        case .dayLog: "day-log"
        case .loggedItems: "logged-items"
        case .addRecord: "add-record"
        case .goalEditor: "goal-editor"
        case .deepInsightsConfirmation: "deep-insights"
        case .destructiveConfirmation(let value): "destructive-\(value)"
        }
    }
}

struct NoopSessionDetailSelection {
    let workout: NoopWorkout
    let headerLine: String?
    let durationLabel: String?
    let load: Int?

    init(
        workout: NoopWorkout,
        headerLine: String? = nil,
        durationLabel: String? = nil,
        load: Int? = nil
    ) {
        self.workout = workout
        self.headerLine = headerLine
        self.durationLabel = durationLabel
        self.load = load
    }
}

@MainActor
final class NoopNavigation: ObservableObject {
    private static let coachVoiceKey = "noop.html.svea-voice"
    private static let dayLogKey = "noop.html.day-log"
    private static let finishedSessionKey = "noop.html.finished-session"

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private let defaults: UserDefaults
    private var pendingSheetTransition: UUID?

    @Published private(set) var path: [NoopRoute] = [.today]
    @Published var overlay: NoopOverlay?
    @Published var selectedWorkout: NoopWorkout = .steadyRide
    @Published var workoutChosenByUser = false

    // Change 2+3. The session is owned above the tab bar, not by `live`: the shell destroys a screen
    // when you navigate away, so a clock held by the screen ends the session the moment a tab is
    // tapped. Held here, the live bar can carry it across every screen in the app.
    /// How the current route was reached. A push rises; a tab-level arrival crossfades in place.
    @Published var arrival: NoopMotion.Arrival = .arrived

    @Published var sessionStartedAt: Date?
    @Published var sessionPaused = false
    @Published var sessionPausedElapsed = 0
    @Published private(set) var finishedSession: NoopFinishedSessionRecord?
    /// The exact record selected from Act 3's session/across screens. It must outlive the source
    /// screen because the shell intentionally recreates child screens on every route change.
    @Published var detailSession: NoopSessionDetailSelection?
    /// Change 4. The session a `history` row opened, so `detail` renders that one.
    @Published var historyWorkout: NoopWorkout?

    /// `plumbing/data` is one screen with two doors and three transient states between them.
    /// Reading, written and rejected are what the screen BECOMES during an import — never routes.
    @Published var dataState: NoopDataState = .idle
    @Published var importStartedAt: Date?

    func beginImport(at date: Date) {
        importStartedAt = date
        dataState = .reading
    }

    var sessionRunning: Bool { sessionStartedAt != nil }

    /// A completed session is meaningful only on the same app-day that produced it.
    var finishedSessionToday: NoopFinishedSessionRecord? {
        guard let finishedSession,
              finishedSession.day == Self.dayFormatter.string(from: Date()) else { return nil }
        return finishedSession
    }

    var finishedWorkout: NoopWorkout? { finishedSessionToday?.workout }

    func beginSession(at date: Date) {
        // The bar rises and the bottom inset grows 52 in the same frames. If the inset lags,
        // the last card jumps.
        withAnimation(NoopMotion.settle) {
            sessionStartedAt = date
            sessionPausedElapsed = 0
            sessionPaused = false
            finishedSession = nil
            defaults.removeObject(forKey: Self.finishedSessionKey)
        }
    }

    func sessionElapsed(at date: Date) -> Int {
        guard let started = sessionStartedAt else { return 0 }
        return sessionPaused ? sessionPausedElapsed : max(0, Int(date.timeIntervalSince(started)))
    }

    /// The canonical fixture opens part-way into a steady ride, so its clock starts at 14:32. The
    /// live bar and the live screen read the same number rather than disagreeing by that offset.
    private var sessionDisplayOffset: Int { selectedWorkout.act3.isIntervals ? 0 : 872 }

    func sessionElapsedDisplay(at date: Date) -> Int {
        sessionElapsed(at: date) + sessionDisplayOffset
    }

    func toggleSessionPause(at date: Date) {
        guard let started = sessionStartedAt else { return }
        // The heart rate crossfades to the word in place. The numeral simply stops, at full
        // contrast — a dimmed clock reads as a disconnected strap.
        withAnimation(NoopMotion.swap) {
            if sessionPaused {
                sessionStartedAt = date.addingTimeInterval(TimeInterval(-sessionPausedElapsed))
                sessionPaused = false
            } else {
                sessionPausedElapsed = max(0, Int(date.timeIntervalSince(started)))
                sessionPaused = true
            }
        }
    }

    /// The session ends, the bar goes, and `detail` opens on what was just done.
    func endSession(_ workout: NoopWorkout, at endedAt: Date = Date()) {
        let measuredSeconds = sessionElapsed(at: endedAt)
        let isDemo = NoopContentPolicy.allowsPrototypeContent
        // The prototype deliberately holds a tap-through session at its canonical measured record;
        // synthetic values remain unreachable outside an explicit Debug `--demo-seed` process.
        let durationSeconds = isDemo && measuredSeconds < 120
            ? workout.minutes * 60
            : max(60, measuredSeconds)
        let minutes = max(1, Int((Double(durationSeconds) / 60).rounded()))
        let detailDistance = Double(workout.act3.detail.distance)
        let record = NoopFinishedSessionRecord(
            day: Self.dayFormatter.string(from: endedAt),
            workout: workout,
            endedAt: endedAt,
            durationSeconds: durationSeconds,
            distanceKilometres: isDemo ? detailDistance : nil,
            chargeCost: isDemo ? Int((Double(minutes) * 0.43).rounded()) : nil,
            sleepNeedMinutes: isDemo ? Int((Double(minutes) * 0.29).rounded()) : nil
        )
        finishedSession = record
        if let data = try? JSONEncoder().encode(record) {
            defaults.set(data, forKey: Self.finishedSessionKey)
        }
        detailSession = nil
        historyWorkout = nil
        overlay = nil
        arrival = .coverIn
        withAnimation(NoopMotion.coverIn) {
            path = [.detail]
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) { [weak self] in
            guard let self, self.route == .detail else { return }
            self.arrival = .arrived
        }
        // The bar is never animated out. It is removed once `detail` is already over it, so the
        // user never sees it go and the inset shrinks in covered frames.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            self.sessionStartedAt = nil
            self.sessionPaused = false
            self.sessionPausedElapsed = 0
        }
    }

    /// A session-end landing is a cover, not a push. Its back action therefore reveals Today by
    /// dismissing the landing down the same edge it arrived from.
    func dismissFinishedSessionDetail() {
        if canGoBack {
            back()
            return
        }
        guard route == .detail, finishedSessionToday != nil else {
            reset(to: .today)
            return
        }
        arrival = .coverOut
        withAnimation(NoopMotion.coverOut) {
            path = [.today]
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.arrival = .arrived
        }
    }

    /// The live workout's own screen — intervals get theirs.
    var liveRoute: NoopRoute { selectedWorkout.act3.isIntervals ? .intervals : .live }
    @Published var selectedRestDay = 0
    @Published var selectedTodayDay = 0
    /// Updates is recreated when its route changes, so transient decisions must live above the
    /// screen just like an in-progress session. Release proposals still write their real stores;
    /// these values only preserve the current navigation session and Debug design fixture.
    @Published var inboxDecisionValues: [String: String] = [:]
    @Published var inboxRestored = false
    @Published var nightJournalSaved = false
    // The journal sheet is recreated on every + tap. Keep its committed choices with the
    // navigation owner so Edit restores what was saved and Cancel discards only the draft.
    @Published var nightJournalMood = 3
    @Published var nightJournalDrinks = 0
    @Published var nightJournalNotes: Set<String> = ["Screens in bed"]
    @Published private(set) var dayLogCounts: [NoopDayLogKind: Int]
    @Published var askFocusRequest = 0
    @Published var coachVoice: NoopCoachVoice {
        didSet { defaults.set(coachVoice.rawValue, forKey: Self.coachVoiceKey) }
    }
    @Published var selectedGoal: NoopGoalKind = .distance
    @Published var selectedMarker = "Ferritin"
    /// Act 9 carries the chosen signal above its four routes so a dossier opened from Trends or
    /// Svea survives the shell's deliberate per-route view recreation.
    @Published var instrumentMetricKey = "hrv"
    @Published var instrumentCompareAKey = "hrv"
    @Published var instrumentCompareBKey = "reg"
    @Published var instrumentCompareShift = 0
    @Published private(set) var labPhotoRequestID = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        coachVoice = defaults.string(forKey: Self.coachVoiceKey)
            .flatMap(NoopCoachVoice.init(rawValue:)) ?? .plain

        let today = Self.dayFormatter.string(from: Date())
        if let data = defaults.data(forKey: Self.dayLogKey),
           let stored = try? JSONDecoder().decode(NoopStoredDayLog.self, from: data),
           stored.day == today {
            dayLogCounts = NoopDayLogKind.allCases.reduce(into: [:]) { result, kind in
                if let count = stored.counts[kind.rawValue], count > 0 {
                    result[kind] = count
                }
            }
        } else {
            dayLogCounts = [:]
        }

        if let data = defaults.data(forKey: Self.finishedSessionKey),
           let stored = try? JSONDecoder().decode(NoopFinishedSessionRecord.self, from: data),
           stored.day == today {
            finishedSession = stored
        } else {
            finishedSession = nil
            defaults.removeObject(forKey: Self.finishedSessionKey)
        }

        #if DEBUG
        let arguments = CommandLine.arguments
        if let flag = arguments.firstIndex(of: "--noop-route"),
           arguments.indices.contains(flag + 1),
           let requestedRoute = NoopRoute(rawValue: arguments[flag + 1]) {
            path = [requestedRoute]
        }
        if let flag = arguments.firstIndex(of: "--noop-workout"),
           arguments.indices.contains(flag + 1) {
            workoutChosenByUser = true
            switch arguments[flag + 1] {
            case "intervals": selectedWorkout = .intervals
            case "walk": selectedWorkout = .longWalk
            case "strength": selectedWorkout = .strength
            case "swim": selectedWorkout = .easySwim
            default: selectedWorkout = .steadyRide
            }
        }
        if let flag = arguments.firstIndex(of: "--noop-data"),
           arguments.indices.contains(flag + 1),
           let requested = NoopDataState(rawValue: arguments[flag + 1]) {
            dataState = requested
            if requested == .reading { importStartedAt = Date() }
        }
        if let flag = arguments.firstIndex(of: "--noop-goal"),
           arguments.indices.contains(flag + 1),
           let requestedGoal = NoopGoalKind(rawValue: arguments[flag + 1]) {
            selectedGoal = requestedGoal
        }
        if NoopContentPolicy.allowsPrototypeContent,
           let flag = arguments.firstIndex(of: "--noop-overlay"),
           arguments.indices.contains(flag + 1) {
            switch arguments[flag + 1] {
            case "night-journal": overlay = .nightJournal
            case "day-log": overlay = .dayLog
            case "logged-items": overlay = .loggedItems
            case "add-record": overlay = .addRecord
            case "goal-editor": overlay = .goalEditor
            case "deep-insights": overlay = .deepInsightsConfirmation
            case "destructive": overlay = .destructiveConfirmation("your account and data")
            default: break
            }
        }
        if NoopContentPolicy.allowsPrototypeContent,
           arguments.contains("--noop-night-journal") {
            overlay = .nightJournal
        }
        if NoopContentPolicy.allowsPrototypeContent,
           arguments.contains("--noop-finished-session") {
            selectedWorkout = .steadyRide
            finishedSession = NoopFinishedSessionRecord(
                day: today,
                workout: .steadyRide,
                endedAt: Date(),
                durationSeconds: 42 * 60,
                distanceKilometres: 14.8,
                chargeCost: 18,
                sleepNeedMinutes: 12
            )
        }
        // Deterministic Simulator QA for the context-sensitive centre action. This is compiled
        // only into Debug and still requires the explicit demo seed, so Release cannot expose a
        // prototype sheet or synthetic route state.
        if NoopContentPolicy.allowsPrototypeContent,
           arguments.contains("--noop-plus") {
            plus()
        }
        #endif
    }

    var route: NoopRoute { path.last ?? .today }
    var canGoBack: Bool { path.count > 1 }
    var dayLogSaved: Bool { !dayLogCounts.isEmpty }

    /// Canonical chip labels for Act 2's Today screen, derived only from observations the user made.
    var dayLogChips: [String] {
        NoopDayLogKind.allCases.compactMap { kind in
            guard let count = dayLogCounts[kind], count > 0 else { return nil }
            return kind.rawValue + (count > 1 ? " ×\(count)" : "")
        }
    }

    func dayLogCount(for kind: NoopDayLogKind) -> Int {
        dayLogCounts[kind, default: 0]
    }

    func addDayLog(_ kind: NoopDayLogKind) {
        refreshDayLogIfNeeded()
        var next = dayLogCounts
        next[kind, default: 0] += 1
        dayLogCounts = next
        persistDayLog()
    }

    func clearDayLog() {
        dayLogCounts = [:]
        persistDayLog()
    }

    /// A tab-level arrival. It did not come from anywhere, so it crossfades rather than rises,
    /// and the tab bar's tint travels over the same 200 ms — that tint move is the only signal
    /// that the tab changed, and without it a crossfade reads as a dropped frame.
    func reset(to route: NoopRoute) {
        pendingSheetTransition = nil
        overlay = nil
        arrival = .arrived
        withAnimation(NoopMotion.arrive) {
            path = [route]
        }
    }

    /// The + door: the sheet goes down on `cover`, then 60 ms of nothing, then the arrival.
    /// Overlapping them shows a push behind a dismissing sheet.
    func dismissSheetThenArrive(at route: NoopRoute) {
        dismissSheet(then: route, pushed: false)
    }

    /// A sheet choice preserves the page it came from, after the sheet finishes closing.
    func dismissSheetThenPush(_ route: NoopRoute) {
        dismissSheet(then: route, pushed: true)
    }

    private func dismissSheet(then route: NoopRoute, pushed: Bool) {
        let transition = UUID()
        pendingSheetTransition = transition
        withAnimation(NoopMotion.coverOut) { overlay = nil }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) { [weak self] in
            guard let self, self.pendingSheetTransition == transition else { return }
            self.pendingSheetTransition = nil
            // The picker has a canonical parent regardless of which sheet opened it, so it goes
            // through its own door rather than being pushed onto the screen behind the sheet.
            if route == .picker { self.enterLabPicker() }
            else if pushed { self.push(route) }
            else { self.reset(to: route) }
        }
    }

    func select(tab: NoopTab) {
        reset(to: tab.root)
    }

    func push(_ route: NoopRoute) {
        pendingSheetTransition = nil
        overlay = nil
        guard self.route != route else { return }
        arrival = .pushed
        withAnimation(NoopMotion.enter) {
            path.append(route)
        }
    }

    func replace(with route: NoopRoute) {
        pendingSheetTransition = nil
        overlay = nil
        arrival = .pushed
        withAnimation(NoopMotion.enter) {
            if path.isEmpty { path = [route] } else { path[path.count - 1] = route }
        }
    }

    func back() {
        pendingSheetTransition = nil
        if overlay != nil {
            withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.32)) { overlay = nil }
            return
        }
        guard path.count > 1 else { return }
        withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.3)) {
            path.removeLast()
        }
    }

    /// Follow the real entry path; the canonical parent is only a fallback for a root arrival.
    func back(or fallback: NoopRoute) {
        if canGoBack || overlay != nil { back() }
        else { reset(to: fallback) }
    }

    func show(_ overlay: NoopOverlay) {
        pendingSheetTransition = nil
        withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.3)) { self.overlay = overlay }
    }

    func dismissOverlay() {
        pendingSheetTransition = nil
        withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.3)) { overlay = nil }
    }

    /// The one door into `goal/picker`.
    ///
    /// 47-act8-goals.md §8.3 names three entrances — *Add results* on `labs`, the + on either of
    /// Act 8's roots, and Act 5's *A lab result to import* row — and every one of them has to end
    /// up in the same place, because 30-routes.md fixes the canonical parent at `picker → labs`.
    /// Seating the stack on `labs` first is what makes the header chevron and the swipe agree: a
    /// bare `push` from `you` or `goal` would leave the swipe popping back to whichever screen the
    /// user happened to be standing on, which is the exact drift the route pass was cleaning up.
    func enterLabPicker() {
        pendingSheetTransition = nil
        overlay = nil
        guard route != .picker else { return }
        arrival = .pushed
        withAnimation(NoopMotion.enter) {
            if route == .labs {
                path.append(.picker)
            } else {
                // One state change, one arrival. Calling reset() and then push() here started two
                // competing animations and briefly rendered Labs between the source and Picker.
                path = [.labs, .picker]
            }
        }
    }

    func plus() {
        switch route.act {
        case .night:
            show(.nightJournal)
        case .day:
            refreshDayLogIfNeeded()
            show(.dayLog)
        case .effort:
            push(.pick)
        case .picture:
            show(.loggedItems)
        case .plumbing:
            show(.addRecord)
        case .ages:
            // 30-routes.md §The +: Act 6 has no add sheet of its own, so the + navigates to
            // `plumbing/record` — "a measurement the estimate needs". It is one of the four rows
            // that navigate, not one of the four that present in place.
            // `record`'s visible chevron says You. Make that its actual stack parent too; pushing
            // it on top of Ages made an edge swipe return to Ages while the chevron returned to You.
            reset(to: .record)
        case .svea:
            reset(to: .coach)
            askFocusRequest += 1
        case .goals:
            // 30-routes.md §The +: from either of Act 8's two roots the + enters `goal/picker`.
            // It must not raise a photo-source dialogue — the picker is the screen carrying the
            // privacy sentence and the by-hand route.
            //
            enterLabPicker()
        case .instrument:
            reset(to: .history)
        }
    }

    func consumeLabPhotoRequest() {
        labPhotoRequestID = 0
    }

    func selectWorkout(_ workout: NoopWorkout) {
        selectedWorkout = workout
        workoutChosenByUser = true
        push(.ready)
    }

    /// Called by the root swipe recognizer. Sheets always close before navigation, matching the
    /// resolved Night Journal and Day Log behavior.
    func handleBackSwipe(startX: CGFloat, translation: CGSize) {
        // Match the native iOS back gesture: only a drag that starts at the leading edge may pop.
        // A screen-wide recognizer steals horizontal chart, picker, and slider gestures.
        guard startX <= 32,
              translation.width > 78,
              abs(translation.height) < 58 else { return }
        back()
    }

    private func refreshDayLogIfNeeded() {
        let today = Self.dayFormatter.string(from: Date())
        guard let data = defaults.data(forKey: Self.dayLogKey),
              let stored = try? JSONDecoder().decode(NoopStoredDayLog.self, from: data),
              stored.day == today else {
            if !dayLogCounts.isEmpty {
                dayLogCounts = [:]
                persistDayLog()
            }
            return
        }
    }

    private func persistDayLog() {
        let stored = NoopStoredDayLog(
            day: Self.dayFormatter.string(from: Date()),
            counts: Dictionary(uniqueKeysWithValues: dayLogCounts.map { ($0.key.rawValue, $0.value) })
        )
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: Self.dayLogKey)
    }
}
