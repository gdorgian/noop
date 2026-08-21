#if os(iOS)
import SwiftUI
import UIKit
import WhoopStore
import StrandAnalytics
import StrandDesign

/// iOS navigation shell. macOS uses a `NavigationSplitView` sidebar (`RootView`); on iPhone the
/// natural analogue is a `TabView` with the most-used screens as tabs and everything else under a
/// "More" list. Every screen is the same `StrandDesign`-built view the macOS app uses.
struct RootTabView: View {
    /// External entry points must wait until the mandatory first-run gates have completed. The root owns
    /// that state; keeping it explicit here prevents this shell's window-level sheet from covering a gate.
    let homeScreenQuickActionsEnabled: Bool

    @EnvironmentObject private var repo: Repository
    /// Cross-screen navigation requests (e.g. Live → "Manage devices"). Devices isn't a tab — it lives
    /// behind the More list — so a request presents it as a sheet, matching the quick-action screens.
    @EnvironmentObject private var router: NavRouter
    /// The AI coach engine (injected at the app root), so the draggable floating Coach button can present
    /// the chat from the shell.
    @EnvironmentObject private var coach: AICoachEngine

    /// Whether the draggable floating Coach button is one of the user's chosen entry points.
    @AppStorage(CoachEntryPrefs.floatingButtonKey) private var coachFloatingButtonEnabled = true
    /// Master switch (#R7): hides the floating Coach button when the coach UI is turned off.
    @AppStorage(CoachEntryPrefs.uiEnabledKey) private var coachUIEnabled = true
    /// Feature-level switch, independent of Today placement. A fresh installation keeps the Coach
    /// inactive until the person has chosen to enable it in More → AI Coach.
    @AppStorage(CoachFeaturePrefs.enabledKey) private var coachFeatureEnabled = false
    @State private var showCoach = false
    /// The scene-local receiver for actions chosen from NOOP's Home Screen icon menu.
    @EnvironmentObject private var homeScreenQuickActions: HomeScreenQuickActionSceneDelegate

    /// Which quick-action screen the centre FAB is presenting (nil = sheet closed).
    @State private var quickAction: QuickAction?
    /// Presents the Devices manager (pair / switch bands) when a screen asks the shell to open it.
    @State private var showDevices = false
    /// Live Sessions (silent guardian). Owned by the SHELL now, not by Today: the entry moved off the Today
    /// dashboard into the quick-action menu, and the guardian wants the full screen, so it presents as a
    /// cover here rather than as one of the `quickAction` sheets.
    @State private var showLiveSession = false
    /// A routed v5 pillar screen (Insights hub / Lab Book / fused record / Rhythm) presented as a sheet
    /// when a hub row deep-links to it via NavRouter. nil = closed.
    @State private var routedPillar: NavRouter.Destination?
    /// Selected tab — bound so tab switches can crossfade (README §Motion: ~240ms opacity swap
    /// between tab roots, calm easing). Defaults to Today.
    @State private var selectedTab: Int = 0
    /// One `NavigationPath` per tab, indexed by tab tag. Re-tapping the already-active tab pops
    /// that tab's stack to its root (#135) by clearing its path — an animated pop that leaves the
    /// root view alive, so an at-root re-tap keeps scroll position and never re-runs `.task`
    /// (#198; the #197 resetID/`.id()` rebuild reset both). Requires the tab roots' first-hop
    /// links to push `TabRoute`/`MoreDestination` VALUES — closure-destination links bypass the path.
    @State private var tabPaths: [NavigationPath] = Array(repeating: NavigationPath(), count: 4)
    /// One scroll-to-top token per tab. Bumped when the user re-taps the active tab while it's ALREADY
    /// at its root — the other half of the iOS convention #197/#198 left unserved (an at-root re-tap was
    /// a no-op). Threaded into each tab's root via `\.scrollToTopSignal`; ScreenScaffold / LiquidTodayView
    /// scroll to their top anchor when their tab's token changes.
    @State private var scrollTop: [Int] = Array(repeating: 0, count: 4)
    /// Which More-tab groups are expanded (S2). Insights + Body stay open at rest; Data + App collapse to
    /// just their header until tapped. Persisted (#860 item 2): the user's open/closed choice must SURVIVE
    /// leaving and re-entering the More tab (and relaunch), not reset to the seed every visit. Backed by an
    /// `@AppStorage` CSV string (keyed identically to the Android `MoreSectionPrefs`), bridged to a
    /// `Set<String>` through `MoreSectionPrefs` so the section logic below is unchanged.
    @AppStorage(MoreSectionPrefs.storageKey) private var expandedMoreSectionsCSV = MoreSectionPrefs.defaultCSV
    private var expandedMoreSections: Set<String> { MoreSectionPrefs.decode(expandedMoreSectionsCSV) }

    /// The More index's filter text. Deliberately NOT persisted: a search is a momentary question,
    /// and coming back to the tab to find it still filtered would read as the app having lost rows.
    @State private var moreQuery = ""
    /// The More sheet's own navigation path, so a pushed screen pops back into the index.
    @State private var morePath = NavigationPath()
    /// Whitespace alone is not a search — it would blank the index for a stray space.
    private var isSearchingMore: Bool { !SearchMatch.tokens(moreQuery).isEmpty }

    /// V8 liquid redesign is the default Today; the Settings toggle lets a user fall back to the classic
    /// Today if they prefer it (keyed identically to the SettingsView toggle). Default ON.
    @AppStorage("noop.liquidTodayEnabled") private var liquidTodayEnabled = true

    /// The Today tab root, honouring the liquid/classic preference.
    ///
    /// The Heute-screen redesign (StrandiOS/Redesign/) used to take priority here when its own
    /// `noop.heuteRedesignEnabled` flag was on — removed along with its Settings toggle, since the
    /// prototype never got past off-by-default/untested-on-a-real-strap. Its code is left in place,
    /// just unreached from here, so no persisted `true` from an earlier build can resurrect it.
    @ViewBuilder private var todayTabRoot: some View {
        if liquidTodayEnabled { LiquidTodayView() }
        else { TodayView() }
    }

    /// Clear the selection indicator UIKit derives from the bar's tint. With NOOP's gold accent the
    /// native bar would otherwise fill a gold capsule behind the active icon; `.tint` should colour the
    /// icon and label, nothing behind them.
    ///
    /// Deliberately the ONLY override. The pre-merge fork code also called
    /// `configureWithOpaqueBackground` here — that would opt the bar out of iOS 26's Liquid Glass and
    /// leave it looking dated, which is the opposite of why this shell went back to the platform bar.
    init(homeScreenQuickActionsEnabled: Bool) {
        self.homeScreenQuickActionsEnabled = homeScreenQuickActionsEnabled
        let appearance = UITabBarAppearance()
        appearance.selectionIndicatorTintColor = .clear
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    /// Native tab selection binding. SwiftUI sends taps on the already-selected item through the
    /// setter, which lets the system tab bar retain the app's refresh / pop-to-root / scroll-to-top
    /// convention without placing a custom hit-testing layer over the platform bar.
    private var nativeTabSelection: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { tag in
                if tag == selectedTab {
                    reselectTab(tag)
                } else {
                    selectedTab = tag
                }
            }
        )
    }

    /// Re-tapping the active tab refreshes that page's data (2026-07-02) and, from a subpage, pops that
    /// tab's stack back to its root (#135) — an animated pop via the path, NOT a rebuild. At the root the
    /// pop is skipped, so scroll position survives and the refresh doesn't double with a re-run of the
    /// root's `.task` (#198).
    private func reselectTab(_ tag: Int) {
        Task { await repo.refresh() }
        if !tabPaths[tag].isEmpty {
            tabPaths[tag] = NavigationPath()   // on a subpage: animated pop back to the root
        } else {
            scrollTop[tag] += 1                // already at root: scroll to the top (#198 follow-up)
        }
    }

    /// The anywhere-swipe tab-switch drag (2026-07-02). Held as a property so the attachment site can
    /// enable or disable it through a `GestureMask` instead of attaching it conditionally: a conditional
    /// attachment changes view identity, and this condition toggles on every push and pop, which would
    /// rebuild the tab roots underneath it. The same class of rebuild is what #197 caused with an
    /// `.id()` reset and #198 had to undo — it lost scroll position and re-ran `.task`.
    ///
    /// Only a decisive horizontal flick switches tabs, and Today is carved out because it uses
    /// horizontal swipe to change DAYS. Both thresholds are unchanged from the original gesture.
    private var tabSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { v in
                // Today (tab 0) uses horizontal swipe to change DAYS, so tab-swipe is off there.
                guard selectedTab != 0 else { return }
                let dx = v.translation.width, dy = v.translation.height
                guard abs(dx) > 60, abs(dx) > abs(dy) * 1.6 else { return }
                let next = min(3, max(0, selectedTab + (dx < 0 ? 1 : -1)))
                if next != selectedTab {
                    withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.24)) { selectedTab = next }
                }
            }
    }

    /// Aura Today reads the profile for its greeting and avatar initial. Live strap state is deliberately
    /// observed only by tiny header leaves inside `AuraHeader`; observing the 1 Hz `LiveState` here would
    /// invalidate the entire shell, charts and scroll view for every heart-rate packet.
    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var ble: BLEManager
    @EnvironmentObject private var health: HealthKitBridge
    /// The More index, presented as a sheet from the Aura You screen — Aura's five-slot bar has no tab
    /// for it, and every row it held stays reachable.
    @State private var showMore = false
    /// Full Settings, opened from the You screen's rows and tiles.
    @State private var showSettings = false

    /// The newest SCORED day, falling back to the newest row. A wearer opening the app before the first
    /// analytics pass of the morning has today's row present but unscored, and blanking the screen for
    /// that window reads as data loss rather than as "not computed yet".
    private var auraDay: DailyMetric? { repo.days.last(where: { $0.recovery != nil }) ?? repo.days.last }

    /// Aura's visual shell receives one immutable snapshot assembled from the same repository and live
    /// state as the incumbent screens. Keeping this adaptation here prevents any UI-only redesign from
    /// reaching into BLE, storage, analytics or HealthKit ownership.
    private var auraTodayReading: AuraTodayReading {
        AuraTodayReading.live(
            day: auraDay,
            effortDay: repo.today,
            history: Array(repo.days.suffix(14)),
            displayName: profile.displayName ?? "",
            effortScale: UnitPrefs.resolveEffortScale(auraEffortScaleRaw)
        )
    }

    /// The Rest screen uses NOOP's existing full-session union so computed WHOOP 5.0 nights, imported
    /// history and split sleeps resolve exactly as they do in the incumbent Sleep screen.
    @State private var auraSleepSessions: [CachedSleepSession] = []
    @State private var auraHabitualMidsleepSec: Int?
    @State private var auraStressSeries: [(day: String, value: Double)] = []
    @State private var auraRestSeries: [(day: String, value: Double)] = []
    @State private var auraWorkouts: [WorkoutRow] = []
    /// The weekly age series, written Saturday-keyed by IntelligenceEngine under the computed `-noop`
    /// source. Loaded alongside the other Aura snapshots; the Age screen reads them back, never recomputes.
    @State private var auraBodyAgeSeries: [(day: String, value: Double)] = []
    @State private var auraFitnessAgeSeries: [(day: String, value: Double)] = []
    @State private var auraVo2maxSeries: [(day: String, value: Double)] = []
    /// The five-domain Fitness Age. Recomputed on each refresh rather than persisted: it is a pure
    /// function of data already stored, and the HealthKit half can change without NOOP being told.
    @State private var auraDomainResult: BioAge.DomainResult?
    @AppStorage(UnitPrefs.effortScaleKey) private var auraEffortScaleRaw = EffortScale.hundred.rawValue
    @AppStorage(UnitPrefs.systemKey) private var auraUnitSystemRaw = UnitSystem.metric.rawValue
    @AppStorage(UnitPrefs.temperatureKey) private var auraTemperatureRaw = ""

    private var auraRestReading: AuraRestReading {
        AuraRestReading.live(
            days: repo.days,
            sessions: auraSleepSessions.isEmpty ? repo.sleeps : auraSleepSessions,
            habitualMidsleepSec: auraHabitualMidsleepSec
        )
    }

    private var auraChargeReading: AuraChargeReading {
        AuraChargeReading.live(
            day: auraDay,
            history: repo.days,
            stressSeries: auraStressSeries,
            restSeries: auraRestSeries
        )
    }

    /// Effort stays on today's logical-day row. Only the target may carry the latest scored recovery,
    /// matching NOOP's existing coupled read without ever passing yesterday's strain off as today's.
    private var auraEffortReading: AuraEffortReading {
        AuraEffortReading.live(
            day: repo.today,
            targetRecovery: Repository.widgetAnchor(days: repo.days)?.recovery,
            history: repo.days,
            workouts: auraWorkouts,
            scale: UnitPrefs.resolveEffortScale(auraEffortScaleRaw)
        )
    }

    /// Body Age / Fitness Age. The driver breakdown is the only live calculation, and it aggregates
    /// through the SAME builder the stored headline used, so the explanation cannot contradict the number.
    private var auraAgeReading: AuraAgeReading {
        let last7 = Array(repo.days.suffix(7))
        return .live(
            bodyAgeSeries: auraBodyAgeSeries,
            fitnessAgeSeries: auraFitnessAgeSeries,
            vo2maxSeries: auraVo2maxSeries,
            days: last7,
            sleepSessions: auraSleepSessions.map { (start: $0.effectiveStartTs, end: $0.endTs) },
            domainResult: auraDomainResult,
            readiness: FitnessAgeEngine.assessReadiness(
                hasAge: profile.age > 0,
                hasSex: !profile.sex.isEmpty,
                rhrDays: last7.compactMap { $0.restingHr }.count,
                activityDays: last7.compactMap { $0.strain }.count,
                hasHeightWeight: profile.heightCm > 0 && profile.weightKg > 0,
                hasWaist: profile.waistCm > 0),
            chronologicalAge: profile.age,
            sex: profile.sex)
    }

    private var auraTrendsReading: AuraTrendsReading {
        AuraTrendsReading.live(
            days: repo.days,
            sessions: auraSleepSessions.isEmpty ? repo.sleeps : auraSleepSessions,
            habitualMidsleepSec: auraHabitualMidsleepSec
        )
    }

    private var auraProfileReading: AuraProfileReading {
        let unitSystem = UnitSystem(rawValue: auraUnitSystemRaw) ?? .metric
        return AuraProfileReading.live(
            displayName: profile.displayName ?? "",
            age: profile.age,
            sex: profile.sex,
            earliestDay: repo.freshness.earliestDay,
            unitSystem: unitSystem,
            temperature: UnitPrefs.resolveTemperature(system: unitSystem, override: auraTemperatureRaw)
        )
    }
    /// Cross-screen navigation requests (e.g. Live → "Manage devices"). Devices isn't a tab — it lives
    @State private var auraScreen: AuraScreen = {
        #if DEBUG
        AuraScreen.debugLaunchScreen
        #else
        .today
        #endif
    }()
    /// The More index, presented as a sheet from the Aura You screen — it is no longer a tab.
    private var auraUsesPrototypeData: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--aura-prototype")
        #else
        false
        #endif
    }


    var body: some View {
        // The iPhone shell is the Aura design: seven screens behind a floating pill bar that AuraShell
        // owns, replacing the platform TabView the liquid design used. The pill bar overlaps content and
        // labels only its active tab, neither of which a native tab bar can express.
        //
        // Everything the Aura screens do NOT cover — Coach, Live, Workouts, Health, Lab Book, Backup,
        // Settings, Devices — is still reached from the You screen, which opens the More index as a
        // sheet. Nothing that was reachable before became unreachable here.
        AuraShell(
            screen: $auraScreen,
            bodyState: auraUsesPrototypeData ? .restored : AuraBodyState.forCharge(auraDay?.recovery),
            todayReading: auraUsesPrototypeData ? .prototype : auraTodayReading,
            restReading: auraUsesPrototypeData ? .prototype : auraRestReading,
            chargeReading: auraUsesPrototypeData ? .prototype : auraChargeReading,
            effortReading: auraUsesPrototypeData ? .prototype : auraEffortReading,
            trendsReading: auraUsesPrototypeData ? .prototype : auraTrendsReading,
            profileReading: auraUsesPrototypeData ? .prototype : auraProfileReading,
            ageReading: auraUsesPrototypeData ? .prototype : auraAgeReading,
            onOpenMore: { showMore = true },
            onOpenSettings: { showSettings = true },
            onOpenDevices: { showDevices = true },
            onSync: {
                ble.syncNow()
                Task { await repo.refresh() }
            },
            onSyncHealth: {
                Task {
                    health.refreshAuthIfPreviouslyGranted()
                    if health.auth == .unknown || health.auth == .denied {
                        await health.requestAuthorization()
                    }
                    await health.sync()
                    await repo.refresh()
                }
            }
        )
        .tint(StrandPalette.accent)
        .task {
            await repo.refresh()
            // Backup & Sync: on-launch catch-up (see RootView). Detached + utility priority so a
            // 100MB+ whole-DB ZIP never blocks startup; gated on the auto toggle (default OFF). (Must-fix #4.)
            let backupRepo = repo
            Task.detached(priority: .utility) {
                await FolderBackup.catchUpIfDue(checkpoint: { await backupRepo.checkpointForBackup() })
            }
        }
        .task(id: repo.refreshSeq) {
            async let sessions = repo.allSleepSessions(days: 60)
            async let habitual = repo.habitualMidsleepSec()
            async let stress = repo.series(key: "stress", source: Repository.whoopSource, days: 60)
            async let rest = repo.exploreSeries(
                key: "sleep_performance",
                source: Repository.whoopSource,
                days: 60
            )
            async let workouts = repo.workoutRows(days: 8)
            // Weekly, so a year of history is ~52 points — cheap to read whole and it makes the Body Age
            // trend show a real direction instead of the last fortnight.
            async let bodyAge = repo.exploreSeries(key: "body_age", source: Repository.whoopSource, days: 400)
            async let fitnessAge = repo.exploreSeries(key: "fitness_age", source: Repository.whoopSource, days: 400)
            async let vo2max = repo.exploreSeries(key: "vo2max_est", source: Repository.whoopSource, days: 400)
            let loaded = await (sessions, habitual, stress, rest, workouts)
            let ages = await (bodyAge, fitnessAge, vo2max)
            guard !Task.isCancelled else { return }
            auraSleepSessions = loaded.0
            auraHabitualMidsleepSec = loaded.1
            auraStressSeries = loaded.2
            auraRestSeries = loaded.3
            auraWorkouts = loaded.4
            auraBodyAgeSeries = ages.0
            auraFitnessAgeSeries = ages.1
            auraVo2maxSeries = ages.2

            // The five-domain Fitness Age. The strap half comes from rows already loaded; the phone half
            // is read from HealthKit, and returns empty unless the wearer granted it — in which case the
            // score simply reports fewer instruments and lower confidence rather than failing.
            let phone = await health.bioAgePhoneMetrics()
            guard !Task.isCancelled else { return }
            auraDomainResult = BioAge.score(
                chronologicalAge: profile.age,
                sex: profile.sex,
                days: Array(repo.days.suffix(30)),
                restScores: auraRestSeries.suffix(30).map(\.value),
                body: .init(heightCm: profile.heightCm > 0 ? profile.heightCm : nil,
                            weightKg: profile.weightKg > 0 ? profile.weightKg : nil),
                phone: phone)
        }
        // Quick-action sheet presents with the calm easing (~0.42s) per the README sheet spec —
        // the easing is applied where `quickAction` is set (see `presentQuickAction`), keeping the
        // animation scoped to the sheet rather than the whole shell.
        .sheet(item: $quickAction) { action in
            quickActionDestination(action)
        }
        // Live's "Manage devices" affordance (and any future cross-screen link to Devices) routes here:
        // present the Devices manager in its own nav stack, the same way the quick-action screens do.
        .sheet(isPresented: $showDevices) {
            devicesScreen
        }
        // v5 pillar deep-links (Insights hub / Lab Book / fused record / Rhythm) present as a sheet in
        // their own nav stack — the same idiom the quick-action + Devices screens use on iPhone.
        .sheet(item: $routedPillar) { dest in
            pillarScreen(dest)
        }
        // The More index. It was a tab under the liquid shell; Aura's bar has five slots and none to
        // spare, so the You screen opens it here instead. Same rows, same pushed destinations.
        .sheet(isPresented: $showMore) {
            // Aura's five-slot bar has no tab for the More index, so the You screen opens it as a sheet.
            // It is the SAME builder the tab shell uses — same rows, same search field, same pushed
            // destinations — just hosted in its own stack rather than a tab's.
            moreTab(path: $morePath, scrollSignal: 0)
        }
        // Full Settings, opened from the You screen's rows and tiles.
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .background(StrandPalette.surfaceBase.ignoresSafeArea())
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showSettings = false }
                                .foregroundStyle(StrandPalette.accent)
                        }
                    }
            }
        }
        // Live Sessions (silent guardian, beta). The liquid Today owned this cover; with Aura Today in
        // its place the shell presents it, so a `NavRouter` deep link still reaches the session screen.
        .fullScreenCover(isPresented: $showLiveSession) {
            LiveSessionView(onClose: { showLiveSession = false })
        }
        // Honour a router request: Devices keeps its dedicated sheet; the v5 pillars route through the
        // shared pillar sheet. Cleared so the same tap can fire again later.
        .onChange(of: router.requestedDestination) { _, dest in
            switch dest {
            case .devices:
                showDevices = true
                router.requestedDestination = nil
            case .insightsHub, .labBook, .fusedRecord, .rhythm:
                routedPillar = dest
                router.requestedDestination = nil
            case .trends:
                // Trends is one of Aura's five tabs (not a pillar sheet) — switch the shell to it.
                withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.24)) { auraScreen = .trends }
                router.requestedDestination = nil
            case .activeWorkout:
                // The Today active-workout indicator opens Live through the quick-action Live sheet; once
                // it's up, LiveView consumes the one-shot `presentActiveWorkout` flag and presents the
                // in-exercise screen. Calm sheet easing, matching the other quick-action presents.
                withAnimation(Self.sheetEase) { quickAction = .live }
                router.requestedDestination = nil
            case .liveSession:
                // The liquid Today carried the Start-session entry; Aura Today has no such control, so a
                // deep link opens the session screen itself rather than landing on a screen that cannot
                // start one. (Restoring a first-class Aura entry point for Live Sessions is outstanding.)
                showLiveSession = true
                router.requestedDestination = nil
            case .breathe:
                // DX's fork added a Breathe deep link. Aura has no breathing screen of its own, so the
                // request opens the one the More index already carries rather than being dropped.
                withAnimation(Self.sheetEase) { showMore = true }
                morePath.append(MoreDestination.breathe)
                router.requestedDestination = nil
            case .dataSources:
                // The "no data yet" empty states offer a button here rather than directions. The More
                // index already carries the import hub, so the sheet is the honest destination.
                withAnimation(Self.sheetEase) { showMore = true }
                morePath.append(MoreDestination.dataSources)
                router.requestedDestination = nil
            case .sleep:
                // Raised when the coach withholds a brief because last night's wake time looks truncated.
                // Rest IS one of Aura's five tabs, so this switches the shell rather than opening a sheet.
                withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.24)) { auraScreen = .rest }
                router.requestedDestination = nil
            case .journal:
                // The #627 Today journal widget opens the journal through the quick-action Journal sheet
                // (InsightsView), matching the FAB's "Log journal" action. Calm sheet easing.
                withAnimation(Self.sheetEase) { quickAction = .journal }
                router.requestedDestination = nil
            case nil:
                break
            }
        }
        // A screen's top-bar "+" routes here: open the quick-action sheet, then clear the flag.
        .onChange(of: router.quickActionsRequested) { _, req in
            if req {
                withAnimation(Self.sheetEase) { quickAction = .menu }
                router.quickActionsRequested = false
            }
        }
        // A cold-launch selection is already pending when this shell appears; a warm selection arrives
        // through the change callback. Both route through the same screens as the centre FAB.
        .onAppear {
            presentPendingHomeScreenQuickActionIfPossible()
        }
        .onChange(of: homeScreenQuickActions.pendingAction) { _, _ in
            presentPendingHomeScreenQuickActionIfPossible()
        }
        .onChange(of: homeScreenQuickActionsEnabled) { _, _ in
            presentPendingHomeScreenQuickActionIfPossible()
        }
    }

    /// Mandatory launch gates defer an external action. Once the shell is available, an explicit Home
    /// Screen choice supersedes any ordinary shell sheet; choosing the already-open destination simply
    /// consumes the request and leaves that screen in place.
    private func presentPendingHomeScreenQuickActionIfPossible() {
        guard homeScreenQuickActionsEnabled,
              let action = homeScreenQuickActions.pendingAction else { return }

        let destination: QuickAction = switch action {
        case .liveHeartRate: .live
        case .startWorkout: .workout
        case .logJournal: .journal
        case .breathe: .breathe
        }
        homeScreenQuickActions.consume(action)
        withAnimation(Self.sheetEase) {
            showDevices = false
            routedPillar = nil
            quickAction = destination
        }
    }

    /// A routed v5 pillar screen wrapped in its own nav stack + Done button (mirrors `quickScreen`).
    @ViewBuilder
    private func pillarScreen(_ dest: NavRouter.Destination) -> some View {
        NavigationStack {
            Group {
                switch dest {
                case .insightsHub: InsightsHubView()
                case .labBook: LabBookView()
                case .fusedRecord: FusedRecordHost()
                case .rhythm: RhythmHost(onClose: { routedPillar = nil })
                case .devices: DevicesView()
                // .trends is never presented as a pillar sheet on iPhone (it's a primary tab — the
                // requestedDestination handler switches `selectedTab` instead), but the switch must stay
                // exhaustive. Fall back to Trends inside the sheet host if it ever arrives here.
                case .trends: TrendsView()
                // .activeWorkout routes through the quick-action Live sheet (handled above); this keeps the
                // switch exhaustive and falls back to Live if it ever reaches the pillar host.
                case .activeWorkout: LiveView()
                // .liveSession routes to the Today tab (handled above — its Start entry owns the cover);
                // this keeps the switch exhaustive and falls back to Today if it ever reaches the host.
                case .liveSession: LiquidTodayView()
                // .breathe routes through the quick-action sheet (handled above); this keeps the switch
                // exhaustive and falls back to BreathingView directly if it ever reaches the host.
                case .breathe: BreathingView()
                // .journal opens through the quick-action Journal sheet (handled above); this keeps the
                // switch exhaustive and falls back to the journal's Insights host if it ever reaches here.
                case .journal: InsightsView()
                // .dataSources is pushed onto the More tab's own stack (handled above); this keeps the
                // switch exhaustive and falls back to the screen itself if it ever reaches the host.
                case .dataSources: DataSourcesView()
                // .sleep switches to the Sleep tab (handled above); this keeps the switch exhaustive and
                // falls back to the screen itself if it ever reaches the host.
                case .sleep: SleepView()
                }
            }
            // The Trends/Today fallbacks above emit TabRoute value pushes (#198), which need a
            // destination registered in THIS sheet's stack to resolve.
            .tabRouteDestinations()
            .background(StrandPalette.surfaceBase.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            // #1027: same fix as quickScreen — the pillar screens draw the full-bleed liquid sky, so a
            // transparent nav bar keeps it edge-to-edge instead of an opaque band clipping the top on scroll.
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { routedPillar = nil }
                        .foregroundStyle(StrandPalette.accent)
                }
            }
        }
    }

    /// Calm-easing curve (cubic-bezier(0.22,1,0.36,1)) at the README sheet-present duration.
    private static let sheetEase = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.42)

    // MARK: - Quick-action sheet

    /// Routes a chosen quick action to the existing screen, or shows the action menu itself.
    @ViewBuilder
    private func quickActionDestination(_ action: QuickAction) -> some View {
        switch action {
        case .menu:
            QuickActionSheet { picked in
                // Swap the menu for the chosen destination on the next runloop so the sheet
                // re-presents cleanly (avoids dismiss/re-present races). Calm easing on re-present.
                quickAction = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    // The guardian is a full-screen cover, not one of the sheet destinations — route it to
                    // its own presentation flag rather than back through `quickAction`.
                    if picked == .liveSession { showLiveSession = true }
                    else { withAnimation(Self.sheetEase) { quickAction = picked } }
                }
            }
            .presentationDetents([.height(416)])
            .presentationDragIndicator(.hidden)
        case .live:
            quickScreen(LiveView())
        case .workout:
            quickScreen(WorkoutsView())
        case .journal:
            quickScreen(InsightsView())
        case .breathe:
            quickScreen(BreathingView())
        case .liveSession:
            // Never reached: the picker routes the guardian to `showLiveSession` (a full-screen cover), so
            // this arm only keeps the switch exhaustive.
            EmptyView()
        }
    }

    /// Wraps a routed quick-action screen in its own nav stack so it has a title bar + the
    /// shared surface background, matching how the More-tab links present these same views.
    private func quickScreen<V: View>(_ view: V) -> some View {
        NavigationStack {
            view
                .background(StrandPalette.surfaceBase.ignoresSafeArea())
                .navigationBarTitleDisplayMode(.inline)
                // #1027: these screens draw a full-bleed liquid sky (ScreenScaffold topBackground) that runs
                // edge-to-edge under a transparent bar — exactly how the tab roots present it. An OPAQUE
                // surfaceBase toolbar background sat on top of that sky and, as the content scrolled up, its
                // extended status-bar band CLIPPED the sky + the in-content header ("Live Body Console").
                // Hiding the bar background lets the sky stay continuous under the floating Done button.
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { quickAction = nil }
                            .foregroundStyle(StrandPalette.accent)
                    }
                }
        }
    }

    /// The Devices manager wrapped in its own nav stack + Done button (mirrors `quickScreen`, but
    /// dismisses the dedicated `showDevices` sheet rather than the quick-action item).
    private var devicesScreen: some View {
        NavigationStack {
            DevicesView()
                .background(StrandPalette.surfaceBase.ignoresSafeArea())
                .navigationBarTitleDisplayMode(.inline)
                // #1027: same fix as quickScreen — Devices draws the full-bleed liquid sky, so a transparent
                // nav bar keeps it edge-to-edge instead of an opaque band clipping the top on scroll.
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showDevices = false }
                            .foregroundStyle(StrandPalette.accent)
                    }
                }
        }
    }

    private func tab<V: View>(_ view: V, _ title: LocalizedStringKey, _ icon: String,
                              path: Binding<NavigationPath>, scrollSignal: Int) -> some View {
        // Each primary tab gets its OWN NavigationStack so the in-content NavigationLinks (e.g. the Today
        // dashboard card rows) both navigate AND render opaque. An ORPHANED NavigationLink (no
        // NavigationStack ancestor) renders its whole label in a disabled/translucent state — that was
        // washing the Today cards over the hero scene and dimming their text to grey (2026-06-23).
        // The root view hides the system nav bar (each screen draws its own in-content header); pushed
        // detail screens get their own nav bar + back button. The stack is bound to the tab's path so a
        // re-tap of the active tab can pop it to the root (#135/#198); the roots' first-hop links push
        // TabRoute values, registered here ONCE per stack (a double registration double-pushes, #38).
        NavigationStack(path: path) {
            view
                .background(StrandPalette.surfaceBase.ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
                .tabRouteDestinations()
        }
        // Drive this tab's root scroll-to-top on an at-root re-tap (#198 follow-up); read by ScreenScaffold
        // / LiquidTodayView inside. Only THIS tab's token changes on its reselect, so the others don't scroll.
        .environment(\.scrollToTopSignal, scrollSignal)
        .tabItem { Label(title, systemImage: icon) }
    }

    // The "More" tab is the app's catch-all index. It was a plain SwiftUI `List` with system large-title
    // + system title-case section headers, so it didn't match any other page (which all use ScreenScaffold
    // + SectionHeader's UPPERCASE overline + the 28pt section rhythm). Rebuilt on the shared page chrome:
    // ScreenScaffold for the title1 "More" + subtitle, a `SectionHeader` overline per group, and the group's
    // rows in a single grouped NoopCard with hairline dividers — the same row idiom Settings/Health use.
    private func moreTab(path: Binding<NavigationPath>, scrollSignal: Int) -> some View {
        NavigationStack(path: path) {
            ScreenScaffold(title: "More", subtitle: "Everything else, one tap away",
                           onRefresh: { await repo.refresh() },
                           topBackground: liquidScaffoldSky()) {
                // The index is a lot of rows across four groups, two of which rest collapsed — so the
                // field comes FIRST, before the reader has to decide which group a screen lives in.
                // It also reaches into Settings (see `moreSearchResults`), which is where "where do I
                // turn X on?" actually ends.
                NoopLiquidGlassSearchField(
                    text: $moreQuery,
                    prompt: String(localized: "Search screens and settings"),
                    accessibilityLabel: String(localized: "Search screens and settings")
                )

                if isSearchingMore {
                    moreSearchResults
                } else {
                    // The rows themselves live in `MoreCatalog` — the search has to read them, and a
                    // @ViewBuilder closure cannot be read. Group order, titles and the persisted
                    // open/closed state are unchanged.
                    ForEach(MoreCatalog.groups) { group in
                        moreSection(group)
                    }
                }
            }
            // The rows push MoreDestination VALUES so a re-tap of the More tab can pop them off the
            // bound path (#135/#198). Each destination keeps the per-screen wrapper the rows used to
            // apply inline (surfaceBase background, inline title bar, hidden bar background):
            // #1027 — a pushed sky-scaffold screen (Live, Workouts, Health, …) draws a full-bleed liquid
            // sky; an opaque surfaceBase nav-bar band sat over it and clipped the top on scroll. A hidden
            // bar background keeps the sky edge-to-edge. On the flat (no-sky) screens this is visually
            // identical at rest — the destination's own surfaceBase background shows through the bar.
            .navigationDestination(for: MoreDestination.self) { route in
                route.destination
                    .background(StrandPalette.surfaceBase.ignoresSafeArea())
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
        }
        // Scroll the More index to the top on an at-root re-tap (#198 follow-up); read by its ScreenScaffold.
        .environment(\.scrollToTopSignal, scrollSignal)
        .tabItem { Label("More", systemImage: "ellipsis") }
    }

    /// One titled, COLLAPSIBLE group in the More index (S2): the app's overline (UPPERCASE) becomes a
    /// tappable header with a disclosure chevron; tapping it expands/collapses the grouped rows card.
    /// Insights + Body default open, Data + App default collapsed (the `expandedMoreSections` seed) so the
    /// list is shorter at rest without dropping a single row. The grouped card is unchanged: a single
    /// `NoopCard` holding a `VStack(spacing: 0)` whose `MoreRow`s draw their own hairlines, clipped to the
    /// card's rounded shape so the last divider is trimmed inside the corners. Same idiom Settings/Health use.
    @ViewBuilder
    private func moreSection(_ group: MoreGroup) -> some View {
        let title = group.title
        let isOpen = expandedMoreSections.contains(title)
        VStack(alignment: .leading, spacing: 10) {
            // Tappable overline header: the same ALL-CAPS tracked label as before, now with a trailing
            // chevron that rotates open. A plain Button (not a SwiftUI DisclosureGroup) so the header keeps
            // the exact strandOverline styling and the card layout below stays identical to before.
            Button {
                withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.24)) {
                    // Persist the toggle via the CSV-backed @AppStorage so the choice survives leaving and
                    // re-entering the More tab and relaunch (#860 item 2). MoreSectionPrefs owns encode/decode.
                    var open = expandedMoreSections
                    if isOpen { open.remove(title) } else { open.insert(title) }
                    expandedMoreSectionsCSV = MoreSectionPrefs.encode(open)
                }
            } label: {
                HStack(spacing: 6) {
                    Text(title).strandOverline()
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(StrandPalette.textTertiary)
                        .rotationEffect(.degrees(isOpen ? 0 : -90))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(title))
            .accessibilityValue(Text(isOpen ? String(localized: "Expanded") : String(localized: "Collapsed")))
            .accessibilityHint(Text(isOpen ? String(localized: "Double tap to collapse") : String(localized: "Double tap to expand")))

            if isOpen {
                // Zero internal padding so each MoreRow owns its own comfortable insets + height; the rows
                // supply their own hairline separators (drawn at the bottom of every row but the last via the
                // divider overlay) so the group reads as one continuous grouped list, matching Settings/Health.
                NoopCard(padding: 0, cornerRadius: NoopMetrics.groupedRadius) {
                    VStack(spacing: 0) {
                        ForEach(group.entries) { entry in MoreRow(entry) }
                    }
                        // Clip the rows column to the card's rounded shape so the last row's bottom hairline is
                        // trimmed inside the corners (the card draws its surface in the BACKGROUND and doesn't
                        // clip content itself, so without this the final divider would run past the rounded edge).
                        .clipShape(RoundedRectangle(cornerRadius: NoopMetrics.groupedRadius, style: .continuous))
                }
            }
        }
    }

    /// The flat result list shown while the field has text.
    ///
    /// Flat on purpose: the groups (and their collapsed state) are exactly what the search exists to
    /// bypass — a hit hiding inside a closed "Data" group would be the bug this feature is meant to
    /// fix. Screens come first, then Settings sections, each labelled so a hit's home is never a guess.
    @ViewBuilder
    private var moreSearchResults: some View {
        let screens = MoreCatalog.matching(moreQuery)
        let settings = SettingsSearchCatalog.matching(moreQuery)

        if screens.isEmpty && settings.isEmpty {
            // An honest dead end rather than a blank screen. No "did you mean" — the matcher is
            // deliberately not fuzzy, so there is nothing truthful to suggest.
            VStack(alignment: .leading, spacing: 6) {
                Text("Nothing matches “\(moreQuery)”.")
                    .font(StrandFont.headline)
                    .foregroundStyle(StrandPalette.textPrimary)
                Text("Try a shorter word, or the name of the screen you're after.")
                    .font(StrandFont.subhead)
                    .foregroundStyle(StrandPalette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 24)
        } else {
            if !screens.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Screens").strandOverline()
                    NoopCard(padding: 0, cornerRadius: NoopMetrics.groupedRadius) {
                        VStack(spacing: 0) {
                            ForEach(screens) { entry in MoreRow(entry) }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: NoopMetrics.groupedRadius, style: .continuous))
                    }
                }
            }
            if !settings.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Settings").strandOverline()
                    NoopCard(padding: 0, cornerRadius: NoopMetrics.groupedRadius) {
                        VStack(spacing: 0) {
                            ForEach(settings) { entry in
                                // Carry the query into Settings so the pushed screen opens already
                                // filtered to this section — otherwise the tap would land the reader
                                // back in the same 15-card wall they were searching to avoid.
                                MoreRow(entry.title, "gearshape.fill", .settingsSearch(moreQuery),
                                        caption: "in Settings", colorKey: "settings")
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: NoopMetrics.groupedRadius, style: .continuous))
                    }
                }
            }
        }
    }
}

/// Every screen the More index links to, as a `Hashable` value the tab's `NavigationPath` can carry
/// (#198): a closure-destination push would bypass the path and be un-poppable on tab re-tap. The
/// per-screen chrome the old inline links applied lives at the single `navigationDestination(for:)`
/// registration in `moreTab`.
enum MoreDestination: Hashable {
    case insightsHub, intelligence, coach, coachSettings, goalJourney, insights, explore, compare
    case live, workouts, health, labBook, stress, breathe, intervals, rhythm
    case fusedRecord, appleHealth, miBand, dataSources, backupSync, shortcutsExport, noopLimitations
    case alarms, automations, testCentre, siriShortcuts, powerSaving, settings
    /// Settings opened from a search hit, carrying the query so the screen lands already filtered to
    /// the matching section. Distinct from `.settings` (the plain row) so an ordinary tap on the
    /// Settings row still opens the whole screen.
    case settingsSearch(String)

    @ViewBuilder var destination: some View {
        switch self {
        case .insightsHub:     InsightsHubView()
        case .intelligence:    IntelligenceView()
        case .coach:           CoachView()
        // More already owns the bound NavigationStack. Reuse it so opening Coach settings performs one
        // path update, not a nested NavigationAuthority update that poisons every later More-row tap.
        case .coachSettings:   CoachSettingsView(usesHostNavigation: true)
        case .goalJourney:     CoachGoalJourneyScreen()
        case .insights:        InsightsView()
        case .explore:         MetricExplorerView()
        case .compare:         CompareView()
        case .live:            LiveView()
        case .workouts:        WorkoutsView()
        case .health:          HealthView()
        case .labBook:         LabBookView()
        case .stress:          StressView()
        case .breathe:         BreathingView()
        case .intervals:       IntervalTimerView()
        case .rhythm:          RhythmHost()
        case .fusedRecord:     FusedRecordHost()
        case .appleHealth:     AppleHealthView()
        case .miBand:          XiaomiBandView()
        case .dataSources:     DataSourcesView()
        case .noopLimitations: NoopLimitationsView()
        case .backupSync:      BackupSyncView()
        case .shortcutsExport: ShortcutExportSettingsView()
        case .alarms:          SmartAlarmView()
        case .automations:     AutomationsView()
        case .testCentre:      TestCentreView()
        case .siriShortcuts:   SiriShortcutsSettingsView()
        case .powerSaving:     PowerSavingView()
        case .settings:        SettingsView()
        case .settingsSearch(let query): SettingsView(searchSeed: query)
        }
    }
}


/// One tappable destination row in the More index. A `NavigationLink` whose label is the standard app row:
/// the SF Symbol icon tinted by its semantic Apple-inspired role, the title in the body text colour, a `Spacer`, and a
/// trailing `chevron.right` in `textTertiary`. ~44pt min height + the card's row insets keep the whole row a
/// comfortable tap target.
struct MoreRow: View {
    let title: LocalizedStringResource
    let icon: String
    let route: MoreDestination
    /// Secondary line under the title. Only the search results use it — to say WHERE a hit lives
    /// ("in Settings"), which a flat result list otherwise leaves the reader to guess.
    var caption: LocalizedStringResource?
    /// Key for the semantic icon colour. Defaults to the route's own name, which is what every
    /// grouped row uses; a search result whose route carries an associated value (`.settingsSearch`)
    /// passes the plain key so it keeps the Settings colour instead of falling off the lookup.
    var colorKey: String?

    init(_ entry: MoreEntry) {
        self.init(entry.title, entry.icon, entry.route)
    }

    init(_ title: LocalizedStringResource,
         _ icon: String,
         _ route: MoreDestination,
         caption: LocalizedStringResource? = nil,
         colorKey: String? = nil) {
        self.title = title; self.icon = icon; self.route = route
        self.caption = caption; self.colorKey = colorKey
    }

    var body: some View {
        // Every More row must push through the NavigationStack's bound path. A closure-based special
        // case for Coach Settings bypassed `tabPaths[3]`; after popping it, SwiftUI's internal stack and
        // the binding disagreed, so later value links (Workouts, Health, Biomarkers, …) were ignored.
        NavigationLink(value: route) {
            rowLabel
        }
        .buttonStyle(.plain)
    }

    private var rowLabel: some View {
            HStack(spacing: 14) {
                // Pin the semantic colour directly. A plain inherited tint gets re-resolved by iOS to its
                // default blue a beat after first render — so the icons flashed green→blue (#184). The
                // explicit foreground style prevents that; the title keeps the primary text colour.
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .regular))
                    .appleInspiredForeground(colorKey ?? String(describing: route))
                    .frame(width: 26, alignment: .center)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(StrandFont.body)
                        .foregroundStyle(StrandPalette.textPrimary)
                    if let caption {
                        Text(caption)
                            .font(StrandFont.footnote)
                            .foregroundStyle(StrandPalette.textTertiary)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(StrandPalette.textTertiary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            // Hairline under every row; the grouped container clips the last one's overflow so the bottom
            // edge stays clean (the divider sits inside the card's rounded corners).
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(StrandPalette.hairline)
                    .frame(height: 1)
                    .padding(.leading, 16)
            }
        }
    }
// MARK: - Quick actions (centre FAB)

/// The destinations the centre FAB can present. `.menu` is the action sheet itself; the rest
/// route to existing screens. `Identifiable` so it drives `.sheet(item:)`.
private enum QuickAction: Int, Identifiable {
    case menu, live, workout, journal, breathe, liveSession
    var id: Int { rawValue }
}

/// The bottom sheet of quick actions presented by the centre FAB. Spec bottom sheet: surfaceOverlay
/// fill, gold hairline top edge, grab handle, three flat action rows that route to existing screens.
private struct QuickActionSheet: View {
    /// Called with the picked destination (the host swaps the menu for that screen).
    let onPick: (QuickAction) -> Void

    /// Live Sessions (silent guardian) beta gate — the SAME key Settings and the macOS Today row read.
    /// Off removes the row entirely, exactly as it used to remove the Today Start-session entry.
    @AppStorage(LiveSessionPrefs.betaKey) private var liveSessionsBeta = true
    @AppStorage(AppleInspiredColorsPrefs.enabledKey)
    private var appleInspiredColors = AppleInspiredColorsPrefs.defaultEnabled

    var body: some View {
        VStack(spacing: 0) {
            // Grab handle (36×4) in the slate hairline tone.
            Capsule()
                .fill(StrandPalette.hairlineStrong)
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 14)

            Text("QUICK ACTIONS")
                .font(StrandFont.overline)
                .tracking(StrandFont.overlineTracking)
                .foregroundStyle(StrandPalette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, NoopMetrics.screenHPadding)
                .padding(.bottom, 10)

            VStack(spacing: 8) {
                row("Live HR", icon: "waveform.path.ecg", tint: StrandPalette.metricRose) { onPick(.live) }
                row("Start workout", icon: "figure.run", tint: StrandPalette.effortColor) { onPick(.workout) }
                row("Log journal", icon: "square.and.pencil",
                    tint: AppleInspiredColors.color(for: "journal", enabled: appleInspiredColors)) { onPick(.journal) }
                row("Breathe", icon: "wind", tint: StrandPalette.restColor) { onPick(.breathe) }
                if liveSessionsBeta {
                    // A Live Session is NOT a breathing exercise — it is quiet strap coaching against
                    // today's Charge — so it carries a subtitle here. Sitting one row under "Breathe"
                    // without one, the two would read as duplicates of each other.
                    row("Silent Guardian", icon: "shield.lefthalf.filled", tint: StrandPalette.metricCyan,
                        subtitle: "Quiet strap coaching against today's Charge") { onPick(.liveSession) }
                }
            }
            .padding(.horizontal, NoopMetrics.screenHPadding)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            NoopChromeSurface()
                .overlay(alignment: .top) {
                    // Gold hairline top edge per the bottom-sheet spec.
                    Rectangle()
                        .fill(StrandPalette.gold.opacity(0.35))
                        .frame(height: 1)
                }
                .ignoresSafeArea()
        )
    }

    /// One flat action row: hued line-icon tile + title, inset surface, hairline border. `subtitle` is for
    /// the rare row whose title alone can be mistaken for a neighbour's (see Silent Guardian vs Breathe).
    private func row(_ title: LocalizedStringKey, icon: String, tint: Color,
                     subtitle: LocalizedStringKey? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(StrandPalette.surfaceInset))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(StrandFont.headline)
                        .foregroundStyle(StrandPalette.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(StrandFont.footnote)
                            .foregroundStyle(StrandPalette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(StrandPalette.textTertiary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(NoopPanelSurface(cornerRadius: 14))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}


#endif
