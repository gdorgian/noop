import Foundation
import SwiftUI
import WhoopStore

/// Exact dates carried from a weekly summary into the existing daily metric explorer.
struct NoopInstrumentOverviewWindow: Equatable {
    let start: Date
    let end: Date
    let metricKey: String
    let weeklySummary: String?
    let deviceId: String
}

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
    case lift
    case fitness
}

enum NoopTab: String, CaseIterable, Identifiable {
    case today = "Today"
    case trends = "Trends"
    case fitness = "Fitness"
    case you = "You"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .trends: "chart.bar.xaxis"
        case .fitness: "figure.run"
        case .you: "person"
        }
    }

    var root: NoopRoute {
        switch self {
        case .today: .today
        case .trends: .trends
        case .fitness: .fitness
        case .you: .you
        }
    }
}

/// Canonical HTML routes. The notification design remains reachable as an explicitly inert
/// “Later” screen; no mirroring permission or firmware capability is implied by the route.

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

    /// Returns `animation` normally, or nil (instant, no animation) when Reduce Motion is on, so a
    /// `withAnimation` / `.animation(_:value:)` call site snaps straight to the final frame.
    ///
    /// Mirrors `StrandDesign.NoopMotion.gated`. This shell-level `NoopMotion` shadows that one inside the
    /// app module, so a shared screen calling `NoopMotion.gated(...)` would otherwise resolve here and
    /// fail to compile on iOS while compiling fine on macOS.
    @inline(__always)
    static func gated(_ animation: Animation, reduced: Bool) -> Animation? {
        reduced ? nil : animation
    }

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
    case today, inbox, charge, day, energy, vitals, stress, heart, recovery, strain
    case breathe, bcatalog, bplayer, bsweep, bfound
    // Act 3
    case session, pick, ready, live, intervals, detail, across
    // Act 4
    case trends, capacity, rhythm, year
    // Act 5
    case diagnostics = "lab-diagnostics"
    case you, record, zones, history, strap, notifs, devices, apple, data, settings, widgets, lab, automations, onboard, pair, position
    case importHistory = "import", reading, imported, rejected, backup
    // Utilities that left "Later" (21 Oct 2026): each is an Aura page over an engine that already ships.
    case howItWorks = "how-noop-works", limitations = "strap-limitations", siri = "siri-shortcuts"
    case shortcutExport = "shortcut-export", storage, digest = "weekly-digest", report = "trends-report"
    case fused = "fused-record", hydration
    // Settings pages (26 Oct 2026): one route each, so back, the edge swipe and a deep link behave
    // as they do for every other Act 5 screen. The Strap page is the hub's strap card.
    case settingsToday = "settings-today", settingsSleep = "settings-sleep", settingsFitness = "settings-fitness"
    case settingsScores = "settings-scores", settingsYou = "settings-you", settingsStrap = "settings-strap"
    case settingsAlerts = "settings-notifications", settingsSvea = "settings-svea", settingsData = "settings-data"
    case settingsLook = "settings-look", settingsLater = "settings-later", settingsAbout = "settings-about"
    // Act 6
    case ages, building, driver, method, health
    // Act 7
    case coach, gate, setup, consent, memory
    // Act 8
    case goal, setGoal = "set", labs, picker, review, marker
    // Act 9
    case instrumentIndex = "index", instrumentMetric = "metric", instrumentCompare = "compare", instrumentEffects = "effects"
    case instrumentRaw = "instrument-raw", instrumentCapture = "instrument-capture"
    // Act 10. Every raw value is PREFIXED, because `NoopRoute` is one flat enum across all ten acts
    // and four of Act 10's names are already spoken for: `live` and `detail` by Act 3, `review` by
    // Act 8, and `"import"` by Act 5's `importHistory`. Swift would reject the duplicates outright,
    // and the raw value is load-bearing beyond compilation — it is the view identity the shell
    // animates on and the `--noop-route` argument design launches with. The prefix also makes that
    // argument read the way the screen is named: `--noop-route lift-live`.
    case liftLive = "lift-live", liftLibrary = "lift-library", liftProgram = "lift-program"
    case liftDetail = "lift-detail", liftEdit = "lift-edit", liftImport = "lift-import"
    case liftReview = "lift-review", liftMuscles = "lift-muscles"
    // Fitness (22 Oct 2026): the training home that replaces the Effort and Lift tab-level entry.
    case fitness
    case fitnessDetail = "fitness-detail", fitnessMuscles = "fitness-muscles", fitnessEdit = "fitness-edit"
    case fitnessRoutine = "fitness-routine", fitnessCalendar = "fitness-calendar"
    case fitnessRoutineEdit = "fitness-routine-edit"
    case fitnessBody = "fitness-body", fitnessReport = "fitness-report", fitnessProgram = "fitness-program"

    var id: String { rawValue }

    var act: NoopAct {
        switch self {
        case .rest, .tonight, .why, .debt, .alarm: .night
        case .today, .inbox, .charge, .day, .energy, .vitals, .stress, .heart, .recovery, .strain,
             .breathe, .bcatalog, .bplayer, .bsweep, .bfound: .day
        case .session, .pick, .ready, .live, .intervals, .detail, .across: .effort
        case .trends, .capacity, .rhythm, .year: .picture
        case .you, .record, .zones, .history, .strap, .notifs, .devices, .apple, .data, .settings,
             .widgets, .lab, .diagnostics, .automations, .onboard, .pair, .position, .importHistory, .reading,
             .imported, .rejected, .backup,
             .howItWorks, .limitations, .siri, .shortcutExport, .storage, .digest, .report, .fused, .hydration,
             .settingsToday, .settingsSleep, .settingsFitness, .settingsScores, .settingsYou, .settingsStrap, .settingsAlerts, .settingsSvea, .settingsData, .settingsLook, .settingsLater, .settingsAbout: .plumbing
        case .ages, .building, .driver, .method, .health: .ages
        case .coach, .gate, .setup, .consent, .memory: .svea
        case .goal, .setGoal, .labs, .picker, .review, .marker: .goals
        case .instrumentIndex, .instrumentMetric, .instrumentCompare, .instrumentEffects,
             .instrumentRaw, .instrumentCapture: .instrument
        case .liftLive, .liftLibrary, .liftProgram, .liftDetail, .liftEdit, .liftImport,
             .liftReview, .liftMuscles: .lift
        case .fitness, .fitnessDetail, .fitnessMuscles, .fitnessEdit, .fitnessRoutine, .fitnessCalendar,
             .fitnessRoutineEdit, .fitnessBody, .fitnessReport, .fitnessProgram: .fitness
        }
    }

    /// The highlighted destination follows the cross-Act grammar of the HTML.
    var tab: NoopTab {
        switch self {
        // Rest left the tab bar for Fitness (22 Oct 2026); last night is a row on Today.
        case .rest, .tonight, .why, .debt, .alarm,
             .today, .inbox, .charge, .day, .energy, .vitals, .stress, .heart, .recovery, .strain,
             .breathe, .bcatalog, .bplayer, .bsweep, .bfound,
             .coach, .gate, .setup, .consent, .memory:
            .today
        case .trends, .capacity, .rhythm, .year,
             .ages, .building, .driver, .method, .health,
             .instrumentIndex, .instrumentMetric, .instrumentCompare, .instrumentEffects,
             .instrumentRaw, .instrumentCapture:
            .trends
        case .you, .record, .zones, .history, .strap, .notifs, .devices, .apple, .data, .settings,
             .widgets, .lab, .diagnostics, .automations, .onboard, .pair, .position, .importHistory, .reading,
             .imported, .rejected, .backup,
             .howItWorks, .limitations, .siri, .shortcutExport, .storage, .digest, .report, .fused, .hydration,
             .settingsToday, .settingsSleep, .settingsFitness, .settingsScores, .settingsYou, .settingsStrap, .settingsAlerts, .settingsSvea, .settingsData, .settingsLook, .settingsLater, .settingsAbout,
             .goal, .setGoal, .labs, .picker, .review, .marker:
            .you
        // Act 10 is deliberately not a sixth tab. A lift is an effort, so it lights the same key
        // Act 3 does. Act 3's sessions moved here from Today on 23 Oct 2026: training has one home.
        case .session, .pick, .ready, .live, .intervals, .detail, .across,
             .liftLive, .liftLibrary, .liftProgram, .liftDetail, .liftEdit, .liftImport,
             .liftReview, .liftMuscles, .fitness, .fitnessDetail, .fitnessMuscles, .fitnessEdit,
             .fitnessRoutine, .fitnessCalendar, .fitnessRoutineEdit, .fitnessBody, .fitnessReport, .fitnessProgram:
            .fitness
        }
    }

    var hidesBottomBar: Bool {
        switch self {
        case .ready, .live, .intervals, .onboard, .pair, .bplayer, .bsweep,
             .liftLive, .liftProgram, .liftEdit, .liftImport, .liftReview, .fitnessRoutineEdit: true
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
    /// A saved lift: its stored session id and program name. Absent on cardio (and on records
    /// written before lifts were recorded here, which decode with both nil).
    var liftSessionID: String? = nil
    var liftTitle: String? = nil

    var minutes: Int {
        max(0, Int((Double(durationSeconds) / 60).rounded()))
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
    case instrumentSignalPickerA
    case instrumentSignalPickerB

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
        case .instrumentSignalPickerA: "instrument-signal-a"
        case .instrumentSignalPickerB: "instrument-signal-b"
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

    @Published private(set) var path: [NoopRoute] = [.today] {
        didSet {
            forgetScroll(from: oldValue)
            if !metricSheetPresented && !path.contains(where: { $0.act == .instrument }) { instrumentOverviewWindow = nil }
        }
    }
    let scrollMemory = NoopScrollMemory()
    /// The current screen's slot in `scrollMemory`.
    var scrollKey: String { "\(path.count)-\(route.rawValue)" }

    /// Back keeps the offset of the screen returned to; any forward move (push, replace, tab) starts
    /// the arriving screen at the top and forgets everything deeper.
    private func forgetScroll(from old: [NoopRoute]) {
        let goingBack = path.count < old.count && Array(old.prefix(path.count)) == path
        let keep = goingBack ? path.count : path.count - 1
        scrollMemory.offsets = scrollMemory.offsets.filter { entry in
            (Int(entry.key.split(separator: "-").first ?? "") ?? 0) <= keep
        }
    }
    @Published var metricSheetPresented = false
    /// The Fitness detail open as a sheet over the Fitness page (the reference's pattern: swipe down and
    /// it is gone, the page underneath never left). Nil when none is.
    @Published var fitnessSheet: NoopRoute?
    @Published var addSheetPresented = false
    /// Settings search, kept across a result's round trip so Back lands on the same results.
    @Published var settingsQuery = ""
    /// The row a search result opened. Its page scrolls to it and glows it once.
    @Published var settingsFocus: String?
    @Published var settingsFocusGlowed = false
    /// The metric the shared metric sheet (`NoopMetricSheet`) is open on; nil when closed.
    @Published var metricSheet: NoopMetricSheetRequest?
    /// The day Recovery and Strain show, in days back from today; shared, so stepping back on one and
    /// opening the other keeps the day.
    @Published var scoreDayOffset = 0
    static let fitnessSheetRoutes: Set<NoopRoute> = [.fitnessDetail, .fitnessMuscles]
    /// A metric inspection keeps the presenting page mounted, including its scroll position.
    func dismissMetricSheet() {
        metricSheetPresented = false
        if !path.contains(where: { $0.act == .instrument }) { instrumentOverviewWindow = nil }
    }

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
    /// Production: the stored session `detail` shows (a row tapped, or the one just saved).
    @Published var liveDetailRow: WorkoutRow?
    /// A cardio session just saved: Fitness shows "How hard was that?" and then the session.
    @Published var cardioFinish: WorkoutRow?
    /// The lift just saved, so its page opens with the finish ring once.
    var justFinishedLiftID: String?

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
    private var sessionDisplayOffset: Int {
        guard NoopContentPolicy.allowsPrototypeContent else { return 0 }
        return selectedWorkout.act3.isIntervals ? 0 : 872
    }

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
        finishSessionArrival()
    }

    /// A real recorder may have resumed from disk after the picker state was reset, or may have
    /// started from the native workout catalogue with a sport absent from the five HTML templates.
    /// Never write the picker default as that session's name or substitute its example duration.
    func endRecordedSession(workout: NoopWorkout?, row: WorkoutRow?, at endedAt: Date = Date()) {
        liveDetailRow = row
        if let workout, let row {
            let record = NoopFinishedSessionRecord(
                day: Self.dayFormatter.string(from: endedAt), workout: workout, endedAt: endedAt,
                durationSeconds: max(0, Int((row.durationS ?? Double(row.endTs - row.startTs)).rounded())),
                distanceKilometres: row.distanceM.map { $0 / 1000 },
                chargeCost: nil, sleepNeedMinutes: nil
            )
            finishedSession = record
            if let data = try? JSONEncoder().encode(record) {
                defaults.set(data, forKey: Self.finishedSessionKey)
            }
        } else {
            finishedSession = nil
            defaults.removeObject(forKey: Self.finishedSessionKey)
        }
        // Upstream 12.0 discards a session under a minute (#2278): there is no row to land on, so the
        // wearer goes back to Session rather than to an empty detail screen.
        // A finished session goes back to Fitness, where it now sits in Today, and asks how it felt the
        // way a finished lift does. Under a minute nothing was saved and there is nothing to ask about.
        sessionStartedAt = nil
        sessionPaused = false
        sessionPausedElapsed = 0
        reset(to: .fitness)
        cardioFinish = row
    }

    private func finishSessionArrival() {
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
    /// A lift saved from the Lift Log is today's session too, so Today's card reads it rather than
    /// an earlier ride.
    func recordFinishedLift(sessionID: String, title: String?, durationSeconds: Int, at endedAt: Date = Date()) {
        var record = NoopFinishedSessionRecord(
            day: Self.dayFormatter.string(from: endedAt), workout: .strength, endedAt: endedAt,
            durationSeconds: max(0, durationSeconds), distanceKilometres: nil,
            chargeCost: nil, sleepNeedMinutes: nil)
        record.liftSessionID = sessionID
        record.liftTitle = title
        finishedSession = record
        if let data = try? JSONEncoder().encode(record) {
            defaults.set(data, forKey: Self.finishedSessionKey)
        }
    }

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
    // Release starts empty (-1 = not chosen); the example choices are the Debug design fixture only.
    // The production shell loads the day's saved answers from the journal and mood stores.
    @Published var nightJournalMood = NoopContentPolicy.allowsPrototypeContent ? 3 : -1
    @Published var nightJournalDrinks = NoopContentPolicy.allowsPrototypeContent ? 0 : -1
    @Published var nightJournalNotes: Set<String> = NoopContentPolicy.allowsPrototypeContent ? ["Screens in bed"] : []
    /// When the night journal was saved; nil when the entry came from the store without a time.
    @Published var nightJournalSavedAt: Date?
    /// Bumped by the sheet's Save and Delete so the production shell writes the entry once.
    @Published var nightJournalRevision = 0
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
    @Published var instrumentOverviewWindow: NoopInstrumentOverviewWindow?
    @Published var instrumentRawSessionID: String?
    // Debug-only raw capture fixture state survives the route identity change between the two pages.
    @Published var instrumentDemoRawArmedAt: Date?
    @Published var instrumentDemoRawDeletedIDs: Set<String> = []
    @Published var instrumentCompareAKey = "hrv"
    @Published var instrumentCompareBKey = "reg"
    @Published var instrumentCompareShift = 0
    @Published private(set) var labPhotoRequestID = 0
    /// Act 10 route payloads live above the per-route views for the same reason the running
    /// session does: the shell deliberately recreates a screen whenever its route changes.
    @Published var selectedLiftProgramID: String?
    @Published var selectedLiftSessionID: String?
    /// Which card a Fitness detail page opens on, and which routine the routine page shows.
    @Published var fitnessMetric: NoopFitnessMetric = .cardioLoad
    @Published var fitnessRoutineID: String?
    /// The exercise a strength detail page opens on; nil shows every muscle.
    @Published var fitnessExercise: String?
    /// The month the review page opens on; consumed when it appears. Nil opens this month.
    @Published var fitnessReportStart: Date?
    /// Open the review on a week rather than a month.
    var fitnessReportWeek = false
    /// A lift opened from the shared workout history, by its start time (the saved workout row and the
    /// lift session share it). Consumed by `lift-detail` when it loads.
    @Published var liftDetailStartTs: Int?
    @Published var liftDetailReturnRoute: NoopRoute = .today

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
        if let flag = arguments.firstIndex(of: "--noop-metric"), arguments.indices.contains(flag + 1) {
            let id = arguments[flag + 1]
            metricSheet = NoopMetricSheetRequest(metricID: id,
                                                 group: id.contains(":") ? "marker"
                                                     : NoopMetric.sleep.contains { $0.id == id } && id != "resp" ? "sleep" : "vitals")
        }
        if path.last == .instrumentMetric {
            path = [.instrumentIndex]
            metricSheetPresented = true
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
        if let flag = arguments.firstIndex(of: "--noop-fitness-metric"), arguments.indices.contains(flag + 1) {
            let all: [NoopFitnessMetric] = [.cardioLoad, .muscularLoad, .activeTime, .activeEnergy, .vo2,
                                            .recovery, .focus, .zones, .sets, .volume]
            if let m = all.first(where: { "\($0)" == arguments[flag + 1] }) { fitnessMetric = m }
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
           let flag = arguments.firstIndex(of: "--noop-instrument-metric"),
           arguments.indices.contains(flag + 1) {
            instrumentMetricKey = arguments[flag + 1]
        }
        if NoopContentPolicy.allowsPrototypeContent,
           let flag = arguments.firstIndex(of: "--noop-instrument-a"),
           arguments.indices.contains(flag + 1) {
            instrumentCompareAKey = arguments[flag + 1]
        }
        if NoopContentPolicy.allowsPrototypeContent,
           let flag = arguments.firstIndex(of: "--noop-instrument-b"),
           arguments.indices.contains(flag + 1) {
            instrumentCompareBKey = arguments[flag + 1]
        }
        if NoopContentPolicy.allowsPrototypeContent,
           let flag = arguments.firstIndex(of: "--noop-instrument-shift"),
           arguments.indices.contains(flag + 1),
           let requestedShift = Int(arguments[flag + 1]) {
            instrumentCompareShift = min(2, max(0, requestedShift))
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
            case "instrument-signal-a": overlay = .instrumentSignalPickerA
            case "instrument-signal-b": overlay = .instrumentSignalPickerB
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
    /// Shared reports and sleep consistency retain the tab from which they were opened.
    var selectedTab: NoopTab {
        switch route {
        case .digest, .report, .rhythm, .capacity: path.first?.tab ?? route.tab
        case .labs, .picker, .review, .marker, .instrumentIndex, .instrumentMetric, .instrumentCompare, .instrumentEffects:
            path.first?.tab ?? route.tab
        default: route.tab
        }
    }

    var canGoBack: Bool { path.count > 1 }

    /// Whether an edge swipe has somewhere to go, so the screen may follow the finger. Spec
    /// 30-routes "screens with no back": the act homes have no up, and the forward-only states
    /// draw no chevron. Every other screen walks the back map. A sheet always closes first.
    var hasSwipeBack: Bool {
        if overlay != nil { return true }
        switch route {
        case .you, .reading, .imported, .rejected, .onboard, .liftLive:
            return false   // handleBackSwipe returns without acting on these
        case .rest, .today, .session, .trends, .ages, .coach:
            return canGoBack
        default:
            return true
        }
    }
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

    /// Replaces today's counts with what the journal holds (production shell only).
    func loadDayLogCounts(_ counts: [NoopDayLogKind: Int]) {
        dayLogCounts = counts.filter { $0.value > 0 }
        persistDayLog()
    }

    /// A tab-level arrival. It did not come from anywhere, so it crossfades rather than rises,
    /// and the tab bar's tint travels over the same 200 ms — that tint move is the only signal
    /// that the tab changed, and without it a crossfade reads as a dropped frame.
    /// Screens retired by Fitness (25 Oct 2026): the old "Today's session" picker, its ready page and the
    /// Lift Log's Programs list. Their routes stay so deep links, widgets and back gestures still resolve;
    /// every one of them now lands on Fitness, where training starts.
    static func retired(_ route: NoopRoute) -> Bool {
        [.session, .pick, .ready, .liftLibrary].contains(route)
    }

    func reset(to route: NoopRoute) {
        let route = Self.retired(route) ? .fitness : route
        if route == .instrumentMetric { presentMetricSheet(); return }
        metricSheetPresented = false
        fitnessSheet = nil
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

    /// Every metric opens on the last 30 days, the way the reference does, rather than inheriting whatever
    /// span the page underneath was showing (six months of daily values is unreadable at phone width).
    /// The range bar inside the sheet still changes it.
    private func presentMetricSheet() {
        instrumentOverviewWindow = nil
        UserDefaults.standard.set("30", forKey: "noop.act9.range")
        metricSheetPresented = true
    }

    func select(tab: NoopTab) {
        reset(to: tab.root)
    }

    func push(_ route: NoopRoute) {
        if Self.retired(route) { reset(to: .fitness); return }
        pendingSheetTransition = nil
        overlay = nil
        if route == .instrumentMetric { presentMetricSheet(); return }
        if Self.fitnessSheetRoutes.contains(route) { fitnessSheet = route; return }
        guard self.route != route else { return }
        let inspectingMetric = metricSheetPresented
        let fitnessReturn = fitnessSheet
        metricSheetPresented = false
        fitnessSheet = nil
        arrival = .pushed
        withAnimation(NoopMotion.enter) {
            // Leave a return point for Compare/Relationships opened from the sheet, and for a session
            // opened from a Fitness sheet, so Back reopens the sheet it came from.
            path += (inspectingMetric ? [.instrumentMetric] : []) + (fitnessReturn.map { [$0] } ?? []) + [route]
        }
    }

    /// Enter a route through the parent drawn by the canonical HTML. Cross-section links can open
    /// a child from somewhere else, but its visible chevron and the edge swipe must still reveal
    /// the same parent.
    func enter(_ route: NoopRoute, from parent: NoopRoute) {
        if route == .instrumentMetric { push(route); return }
        metricSheetPresented = false
        fitnessSheet = nil
        pendingSheetTransition = nil
        overlay = nil
        guard self.route != route else { return }
        arrival = .pushed
        // Owner decision (21 Oct 2026): back returns to where the wearer actually came from. The
        // canonical parent is only the fallback for a screen with no history behind it (a deep link,
        // a fresh launch); it no longer rewrites a real path — Settings → Buzz for notifications used
        // to come back to Your strap.
        withAnimation(NoopMotion.enter) {
            if path.isEmpty { path = [parent, route] } else { path.append(route) }
        }
    }

    /// A finished session's summary sits directly on `parent`: back goes there, not through the
    /// pickers that led into the session.
    func land(on route: NoopRoute, over parent: NoopRoute) {
        metricSheetPresented = false
        fitnessSheet = nil
        pendingSheetTransition = nil
        overlay = nil
        arrival = .pushed
        withAnimation(NoopMotion.enter) { path = [parent, route] }
    }

    func replace(with route: NoopRoute) {
        if Self.retired(route) { reset(to: .fitness); return }
        if route == .instrumentMetric { push(route); return }
        metricSheetPresented = false
        fitnessSheet = nil
        pendingSheetTransition = nil
        overlay = nil
        arrival = .pushed
        withAnimation(NoopMotion.enter) {
            if path.isEmpty { path = [route] } else { path[path.count - 1] = route }
        }
    }

    func back() {
        if metricSheetPresented { dismissMetricSheet(); return }
        if fitnessSheet != nil { fitnessSheet = nil; return }
        pendingSheetTransition = nil
        if overlay != nil {
            withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.32)) { overlay = nil }
            return
        }
        guard path.count > 1 else { return }
        withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.3)) {
            var returning = Array(path.dropLast())
            if returning.last == .instrumentMetric {
                metricSheetPresented = true
                returning.removeLast()
            } else if let last = returning.last, Self.fitnessSheetRoutes.contains(last), returning.count > 1 {
                fitnessSheet = last
                returning.removeLast()
            }
            path = returning
        }
    }

    /// Return to `route` if it is already on the path, dropping everything above it; otherwise put
    /// it in place of the current screen. Breathe's sessions land on its root, not on whatever
    /// screen happened to open them.
    func unwind(to route: NoopRoute) {
        metricSheetPresented = false
        fitnessSheet = nil
        pendingSheetTransition = nil
        overlay = nil
        guard let index = path.lastIndex(of: route) else { replace(with: route); return }
        guard index < path.count - 1 else { return }
        withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.3)) {
            path.removeSubrange((index + 1)..<path.count)
        }
    }

    /// Follow the real entry path; the canonical parent is only a fallback for a root arrival.
    func back(or fallback: NoopRoute) {
        if metricSheetPresented || canGoBack || overlay != nil { back() }
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

    /// The tab-bar + (23 Oct 2026): one Add sheet from every screen. It used to do ten different
    /// things by act, so the same key started a session on one page and opened a journal on the
    /// next, and from Today's session it led to a fixed list with no way to log a workout.
    func plus() {
        pendingSheetTransition = nil
        withAnimation(NoopMotion.swap) { overlay = nil }
        addSheetPresented = true
    }

    /// Runs `action` once the Add sheet has finished sliding away, so an in-shell overlay or a push
    /// doesn't animate underneath a sheet that is still on screen.
    func afterAddSheet(_ action: @escaping () -> Void) {
        addSheetPresented = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: action)
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

        // A sheet always closes first, including on a screen whose route itself has no back action.
        if overlay != nil {
            back()
            return
        }

        // Act 5's visible chevrons are canonical destinations, not merely whatever happens to sit
        // underneath the current route in an in-memory path. Supplying the same fallback here makes
        // a direct launch, a cross-act entrance and a tapped chevron agree. The three import-result
        // states deliberately have no chevron and therefore no swipe exit.
        switch route {
        case .you, .reading, .imported, .rejected, .onboard:
            return
        case .record, .history, .strap, .settings, .data, .position:
            back(or: .you)
        case .zones:
            back(or: .record)
        case .notifs, .devices, .apple:
            back(or: .strap)
        case .pair:
            back(or: .devices)
        case .howItWorks, .limitations, .siri, .shortcutExport, .storage, .digest, .report, .fused, .hydration:
            back(or: .settings)
        case .widgets, .lab, .diagnostics, .automations,
             .settingsToday, .settingsSleep, .settingsFitness, .settingsScores, .settingsYou, .settingsStrap, .settingsAlerts, .settingsSvea, .settingsData, .settingsLook, .settingsLater, .settingsAbout:
            back(or: .settings)
        case .importHistory, .backup:
            back(or: .data)
        case .energy:
            back(or: .today)
        case .instrumentIndex:
            back(or: .trends)
        case .instrumentMetric, .instrumentCompare, .instrumentEffects:
            back(or: .instrumentIndex)
        case .instrumentRaw:
            back(or: .instrumentIndex)
        case .instrumentCapture:
            back(or: .instrumentRaw)
        case .liftLive:
            return
        case .liftLibrary:
            back(or: .fitness)
        case .liftProgram:
            back(or: .liftLibrary)
        case .liftDetail:
            back(or: liftDetailReturnRoute)
        case .liftEdit:
            back(or: .liftDetail)
        case .liftImport:
            back(or: .liftLibrary)
        case .liftReview:
            back(or: .liftImport)
        case .liftMuscles:
            back(or: .liftDetail)
        default:
            back()
        }
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


extension NoopRoute {
    /// The screen's own name, as its header and a back chevron pointing at it say it.
    var screenTitle: String {
        switch self {
        case .rest: "Last night"
        case .tonight: "Tonight"
        case .why: "Why"
        case .debt: "Sleep debt"
        case .alarm: "Smart alarm"
        case .today: "Today"
        case .inbox: "Updates"
        case .charge: "Charge"
        case .day: "The day so far"
        case .energy: "What today has cost"
        case .vitals: "Vitals"
        case .stress: "Stress"
        case .heart: "Heart"
        case .recovery: "Recovery"
        case .strain: "Strain"
        case .breathe: "Breathe"
        case .bcatalog: "Eighteen ways to breathe"
        case .bplayer: "Breathing"
        case .bsweep: "Finding your pace"
        case .bfound: "Your pace"
        case .session: "Session"
        case .pick: "Choose a session"
        case .ready: "Ready"
        case .live: "Live session"
        case .intervals: "Intervals"
        case .detail: "Session detail"
        case .across: "Every session"
        case .trends: "Trends"
        case .capacity: "Capacity"
        case .rhythm: "Rhythm"
        case .year: "The year"
        case .you: "You"
        case .record: "Your record"
        case .zones: "Your zones"
        case .history: "History"
        case .strap: "Your strap"
        case .notifs: "Buzz for notifications"
        case .devices: "Manage straps"
        case .apple: "Apple Health"
        case .data: "Your data"
        case .importHistory: "Bring your history in"
        case .reading: "Reading a file"
        case .imported: "What was written"
        case .rejected: "The wrong file"
        case .backup: "Backup and sync"
        case .position: "What Noop will not ask you"
        case .settings: "Settings"
        case .settingsToday: "Today settings"
        case .settingsSleep: "Sleep settings"
        case .settingsFitness: "Fitness settings"
        case .settingsScores: "Trends and scores settings"
        case .settingsYou: "You settings"
        case .settingsStrap: "Strap settings"
        case .settingsAlerts: "Notifications"
        case .settingsSvea: "Svea settings"
        case .settingsData: "Data and connections"
        case .settingsLook: "Look and feel"
        case .settingsLater: "On the way"
        case .settingsAbout: "About Noop"
        case .widgets: "Widgets"
        case .howItWorks: "How Noop works"
        case .limitations: "Strap limitations"
        case .siri: "Siri and Shortcuts"
        case .shortcutExport: "Shortcuts export"
        case .storage: "Storage"
        case .digest: "Weekly digest"
        case .report: "Trends report"
        case .fused: "Your data, fused"
        case .hydration: "Hydration"
        case .lab: "The Lab"
        case .diagnostics: "Diagnostics"
        case .automations: "Automations"
        case .onboard: "Welcome"
        case .pair: "Pair a strap"
        case .ages: "Your ages"
        case .building: "Building your ages"
        case .driver: "Driver"
        case .method: "How it is figured"
        case .health: "Health"
        case .coach: "Svea"
        case .gate: "Connect a provider"
        case .setup: "Provider setup"
        case .consent: "Data access"
        case .memory: "Memory"
        case .goal: "Goals"
        case .setGoal: "Set a goal"
        case .labs: "Biomarkers"
        case .picker: "Photograph the report"
        case .review: "Review lab results"
        case .marker: "Biomarker"
        case .instrumentIndex: "All signals"
        case .instrumentMetric: "One signal"
        case .instrumentCompare: "Compare signals"
        case .instrumentEffects: "Relationships"
        case .instrumentRaw: "Raw capture"
        case .instrumentCapture: "Capture"
        // Act 10 · The Lift.
        case .liftLive: "Lift session"
        case .liftLibrary: "Lift Log"
        case .liftProgram: "Program"
        case .liftDetail: "Lift detail"
        case .liftEdit: "Edit session"
        case .liftImport: "Import a program"
        case .liftReview: "Review the import"
        case .liftMuscles: "Muscles"
        case .fitness: "Fitness"
        case .fitnessDetail: "Fitness"
        case .fitnessMuscles: "Muscle groups"
        case .fitnessEdit: "Edit Fitness"
        case .fitnessRoutine: "Routine"
        case .fitnessCalendar: "Calendar"
        case .fitnessRoutineEdit: "Edit routine"
        case .fitnessBody: "Body"
        case .fitnessReport: "Review"
        case .fitnessProgram: "Build a program"
        }
    }
}

extension NoopNavigation {
    /// The name of the screen a back would return to, or nil when there is no history behind this one
    /// (then a header keeps its designed label, which names the canonical parent back(or:) falls to).
    var previousScreenTitle: String? {
        guard path.count > 1 else { return nil }
        let parent = path[path.count - 2]
        if parent == .instrumentMetric { return NoopInstrumentData.title(for: instrumentMetricKey) ?? parent.screenTitle }
        return parent.screenTitle
    }
}

private struct NoopBackLabelKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    /// Set by the shell: where a back chevron actually leads, so its label matches the real path.
    var noopBackLabel: String? {
        get { self[NoopBackLabelKey.self] }
        set { self[NoopBackLabelKey.self] = newValue }
    }
}
