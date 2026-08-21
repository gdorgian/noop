#if os(iOS)
import SwiftUI
import StrandDesign

// MARK: - Aura shell
//
// The chrome all seven Aura screens share: the fixed canvas and its ambient wash, the header, the
// scrolling content, and the floating pill bar. Screens themselves are pure content — they own no
// background, no header and no navigation.
//
// The shell is deliberately NOT a `TabView`. The direction's bar is a floating pill that overlaps the
// content and shows a label only on the active tab, which the platform bar cannot express. It also
// carries seven destinations behind five tabs: Band and You hang off the header.

struct AuraShell: View {
    /// Which screen is showing. Owned by the app shell so a deep link (`NavRouter`) can move Aura
    /// without the router needing to know anything about it.
    @Binding var screen: AuraScreen

    /// Opens the app's full surface — Coach, Live, Workouts, Health, Lab Book, Backup and the rest.
    /// Aura reimplements none of those, so this is how they stay reachable.
    let onOpenMore: () -> Void
    let onOpenSettings: () -> Void
    let onOpenDevices: () -> Void
    let onSync: () -> Void
    let onSyncHealth: () -> Void
    /// Opens the coach from Today's Svea card.
    let onOpenCoach: () -> Void
    /// Starts a Live Session from the Effort screen.
    let onStartLiveSession: () -> Void

    /// Today's body state. Fixed until the screens are wired to `Repository`; it drives the orb's colour
    /// and the gauge marker's position.
    private let bodyState: AuraBodyState
    /// Today's live repository snapshot. Aura owns its presentation only; assembling the snapshot stays
    /// in `RootTabView`, outside the design layer and away from BLE/HealthKit ownership.
    private let todayReading: AuraTodayReading
    /// Rest's presentation snapshot, derived from the same canonical SleepModel as the incumbent screen.
    private let restReading: AuraRestReading
    /// Charge's snapshot, derived from the canonical recovery row, baselines and driver contract.
    private let chargeReading: AuraChargeReading
    /// Effort's snapshot, derived from today's stored strain, recovery target and reconciled workouts.
    private let effortReading: AuraEffortReading
    /// Trends' snapshot, derived from real Charge history and the canonical sleep-debt ledger.
    private let trendsReading: AuraTrendsReading
    /// You's snapshot, derived from the persisted local profile and repository history.
    private let profileReading: AuraProfileReading
    /// Body Age / Fitness Age, reached as a detail route off Trends.
    private let ageReading: AuraAgeReading

    /// Written out rather than synthesized: a struct with any `private` stored property gets a PRIVATE
    /// memberwise initializer, which the app shell in another file could not call.
    init(
        screen: Binding<AuraScreen>,
        bodyState: AuraBodyState = .restored,
        todayReading: AuraTodayReading,
        restReading: AuraRestReading,
        chargeReading: AuraChargeReading,
        effortReading: AuraEffortReading,
        trendsReading: AuraTrendsReading,
        profileReading: AuraProfileReading,
        ageReading: AuraAgeReading,
        onOpenMore: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onOpenDevices: @escaping () -> Void,
        onSync: @escaping () -> Void,
        onOpenCoach: @escaping () -> Void,
        onStartLiveSession: @escaping () -> Void,
        onSyncHealth: @escaping () -> Void
    ) {
        self._screen = screen
        self.bodyState = bodyState
        self.todayReading = todayReading
        self.restReading = restReading
        self.chargeReading = chargeReading
        self.effortReading = effortReading
        self.trendsReading = trendsReading
        self.profileReading = profileReading
        self.ageReading = ageReading
        self.onOpenMore = onOpenMore
        self.onOpenSettings = onOpenSettings
        self.onOpenDevices = onOpenDevices
        self.onSync = onSync
        self.onSyncHealth = onSyncHealth
        self.onOpenCoach = onOpenCoach
        self.onStartLiveSession = onStartLiveSession
        #if DEBUG
        self._routeStack = State(initialValue: AuraRoute.debugLaunchRoute.map { [$0] } ?? [])
        #endif
    }

    private static let topAnchorID = "auraShell.top"

    /// Bumped when the user taps the tab they are already on. That is the iOS convention #197/#198
    /// established for the platform tab bar; Aura's own bar has to serve it itself, since the shell is no
    /// longer a `TabView` and the `scrollToTopSignal` environment key no longer reaches it.
    @State private var scrollToTopToken = 0
    @State private var routeStack: [AuraRoute] = []

    var body: some View {
        Group {
            if let route = routeStack.last {
                detail(route)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                rootShell
                    .transition(.opacity)
            }
        }
        .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.28), value: routeStack)
    }

    private var rootShell: some View {
        ZStack(alignment: .bottom) {
            background

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: AuraPalette.cardGap) {
                        Color.clear.frame(height: 0).id(Self.topAnchorID)

                        AuraHeader(
                            screen: screen,
                            greeting: headerGreeting,
                            headline: headerHeadline,
                            initial: todayReading.initial,
                            onOpenBand: { go(.band) },
                            onOpenProfile: { go(.profile) }
                        )

                        // The strain/illness early-warning banner and the live-workout indicator. Both
                        // belong to the SHELL, not to Today: the liquid rewrite once dropped the banner
                        // and a raised health alert was left with no home-screen surface at all, which is
                        // the one regression this redesign must not repeat. Both render nothing unless
                        // something is actually raised, so they cost the normal case nothing.
                        //
                        // They are drawn in the Titanium palette rather than Aura's, since they are shared
                        // leaves — an Aura-native treatment for them is outstanding.
                        if screen == .today {
                            HealthAlertBanner()
                            ActiveWorkoutIndicatorSection()
                        }

                        content
                            // A fresh identity per screen so each one gets the house fade-and-rise on
                            // arrival instead of the layout visibly rearranging in place.
                            .id(screen)
                            .transition(.opacity)

                        Color.clear.frame(height: 110)
                    }
                    .padding(.horizontal, AuraPalette.screenPadding)
                }
                .scrollIndicators(.hidden)
                .onChangeCompat(of: scrollToTopToken) { _ in
                    withAnimation(.easeOut(duration: 0.35)) { proxy.scrollTo(Self.topAnchorID, anchor: .top) }
                }
                .onChangeCompat(of: screen) { _ in
                    // A new screen always starts at its own top; carrying Today's scroll offset into
                    // Trends would drop the user into the middle of a chart.
                    proxy.scrollTo(Self.topAnchorID, anchor: .top)
                }
            }

            AuraTabBar(selection: screen) { go($0) }
                .padding(.bottom, 8)
        }
    }

    // MARK: Screens

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .today:
            AuraTodayView(
                state: bodyState,
                reading: todayReading,
                onNavigate: { go($0) },
                onOpenSignal: { push(.metric($0.id)) },
                onOpenCoach: onOpenCoach
            )
        case .rest:
            AuraRestView(reading: restReading)
        case .charge:
            AuraChargeView(reading: chargeReading)
        case .effort:
            AuraEffortView(reading: effortReading, onStartLiveSession: onStartLiveSession)
        case .trends:
            AuraTrendsView(reading: trendsReading, onOpenAge: { push(.age) })
        case .band:
            AuraBandView(
                onManageDevices: { push(.manageStraps) },
                onSync: onSync,
                onSyncHealth: onSyncHealth
            )
        case .profile:
            AuraProfileView(
                reading: profileReading,
                onEditProfile: { push(.editProfile) },
                onOpenNotifications: { push(.notifications) },
                onOpenUnits: { push(.units) },
                onOpenExport: { push(.export) },
                onOpenMore: { push(.more) },
                onOpenTracking: { push(.tracking) },
                onOpenPrivacy: { push(.privacy) },
                onOpenSettings: { push(.settings) }
            )
        }
    }

    /// Every production headline comes from its live reading. Prototype readings remain available only
    /// to isolated design previews; AuraShell requires callers to provide all six snapshots.
    private var headerGreeting: String {
        switch screen {
        case .today: return todayReading.greeting
        case .effort: return effortReading.greeting
        case .band: return String(localized: "Your band")
        case .profile: return String(localized: "Account")
        default: return screen.greeting
        }
    }

    private var headerHeadline: String {
        switch screen {
        case .today:
            return todayReading.headline
        case .rest:
            return restReading.headline
        case .charge:
            return chargeReading.headline
        case .effort:
            return effortReading.headline
        case .trends:
            return trendsReading.headline
        case .band:
            // Rendered by a LiveState-isolated leaf in AuraHeader.
            return String(localized: "Band status")
        case .profile:
            return todayReading.profileName.isEmpty
                ? String(localized: "Your profile")
                : todayReading.profileName
        }
    }

    // MARK: Aura detail routes

    @ViewBuilder
    private func detail(_ route: AuraRoute) -> some View {
        switch route {
        case .metric(let id):
            if let signal = todayReading.signals.first(where: { $0.id == id }) {
                AuraDetailScaffold(title: signal.name, subtitle: metricSubtitle(id), onBack: pop) {
                    AuraMetricDetailView(signal: signal)
                }
            } else {
                AuraDetailScaffold(title: String(localized: "Signal"), onBack: pop) {
                    AuraNoteBanner(text: String(localized: "This signal is not available yet."), tint: AuraPalette.accent)
                }
            }
        case .editProfile:
            AuraDetailScaffold(title: String(localized: "Your profile"),
                               subtitle: String(localized: "Name and photo stay on this iPhone."), onBack: pop) {
                AuraProfileEditorView()
            }
        case .notifications:
            AuraDetailScaffold(title: String(localized: "Notifications"),
                               subtitle: String(localized: "Live heart rate, reminders and strap alerts."), onBack: pop) {
                AuraNotificationsView()
            }
        case .units:
            AuraDetailScaffold(title: String(localized: "Units"),
                               subtitle: String(localized: "Change presentation without changing stored data."), onBack: pop) {
                AuraUnitsView()
            }
        case .export:
            AuraDetailScaffold(title: String(localized: "Export data"),
                               subtitle: String(localized: "Apple Health, portable backups and imports."), onBack: pop) {
                AuraExportView()
            }
        case .more:
            AuraDetailScaffold(title: String(localized: "Everything else"),
                               subtitle: String(localized: "The deeper NOOP toolkit, kept within reach."), onBack: pop) {
                AuraMoreView(onOpenAllTools: onOpenMore)
            }
        case .tracking:
            AuraDetailScaffold(title: String(localized: "What NOOP tracks"),
                               subtitle: String(localized: "Direct WHOOP signals, on-device estimates and Health output."), onBack: pop) {
                AuraTrackingView()
            }
        case .privacy:
            AuraDetailScaffold(title: String(localized: "Privacy"),
                               subtitle: String(localized: "Where your data lives and when it leaves."), onBack: pop) {
                AuraPrivacyView()
            }
        case .settings:
            AuraDetailScaffold(title: String(localized: "Settings"),
                               subtitle: String(localized: "Every everyday preference, separated by purpose."), onBack: pop) {
                AuraSettingsIndexView(
                    onOpenNotifications: { push(.notifications) },
                    onOpenUnits: { push(.units) },
                    onOpenExport: { push(.export) },
                    onOpenTracking: { push(.tracking) },
                    onOpenPrivacy: { push(.privacy) },
                    onOpenAdvanced: onOpenSettings
                )
            }
        case .age:
            AuraDetailScaffold(title: String(localized: "Your ages"),
                               subtitle: String(localized: "Weekly · on this device"),
                               onBack: pop) {
                AuraAgeView(reading: ageReading)
            }
        case .manageStraps:
            AuraDetailScaffold(title: String(localized: "Manage strap"),
                               subtitle: String(localized: "WHOOP 5.0 connection, controls and diagnostics."), onBack: pop) {
                AuraManageStrapsView(onOpenDeviceManager: onOpenDevices)
            }
        }
    }

    private func metricSubtitle(_ id: String) -> String {
        switch id {
        case "hr": return String(localized: "Live now, with resting history below")
        case "hrv": return String(localized: "Nightly variability against your own history")
        case "resp": return String(localized: "Nightly breathing estimate from clean R–R intervals")
        case "sleep": return String(localized: "Asleep duration, not time in bed")
        default: return String(localized: "Your recent readings")
        }
    }

    private func push(_ route: AuraRoute) {
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.28)) {
            routeStack.append(route)
        }
    }

    private func pop() {
        guard !routeStack.isEmpty else { return }
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.28)) {
            _ = routeStack.removeLast()
        }
    }

    private func go(_ destination: AuraScreen) {
        // Tapping the screen you are already on scrolls it back to the top, rather than doing nothing.
        guard destination != screen else {
            scrollToTopToken += 1
            return
        }
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.24)) { screen = destination }
    }

    // MARK: Background

    /// The canvas plus a single ambient wash bled behind the header, tinted by body temperature. Fixed
    /// behind the scroll rather than inside it, so pulling the content never drags the atmosphere along.
    private var background: some View {
        AuraPalette.canvas
            .overlay(alignment: .top) {
                Ellipse()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: bodyState.orbTint.opacity(bodyState.ambientOpacity), location: 0),
                                .init(color: bodyState.orbTint.opacity(0), location: 0.7),
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 230
                        )
                    )
                    .frame(width: 460, height: 400)
                    .offset(y: -140)
                    .blur(radius: 18)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
#endif
