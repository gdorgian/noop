#if os(iOS)
import SwiftUI

/// iOS-only bridge from the app lifecycle into the canonical HTML-derived shell.
/// macOS keeps its existing NavigationSplitView and never compiles StrandiOS/.
struct RootTabView: View {
    let homeScreenQuickActionsEnabled: Bool

    @EnvironmentObject private var router: NavRouter
    @EnvironmentObject private var homeScreenQuickActions: HomeScreenQuickActionSceneDelegate
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var model: AppModel
    @StateObject private var navigation = NoopNavigation()
    @State private var resetInProgress = false
    @State private var resetError: String?

    var body: some View {
        Group {
            if NoopContentPolicy.allowsPrototypeContent {
                NoopAppShell(navigation: navigation)
            } else {
                NoopVerifiedAppShell(navigation: navigation)
            }
        }
            .onChange(of: router.requestedDestination) { _, destination in
                guard let destination else { return }
                route(destination)
                router.requestedDestination = nil
            }
            .onChange(of: router.quickActionsRequested) { _, requested in
                guard requested else { return }
                navigation.plus()
                router.quickActionsRequested = false
            }
            .onReceive(NotificationCenter.default.publisher(for: .noopOpenCoachCheckIn)) { _ in
                navigation.reset(to: .coach)
            }
            .onReceive(NotificationCenter.default.publisher(for: .noopOpenCoachCard)) { _ in
                navigation.reset(to: .coach)
            }
            .onReceive(NotificationCenter.default.publisher(for: .noopDeleteAllLocalData)) { _ in
                guard !resetInProgress else { return }
                resetInProgress = true
                Task { @MainActor in
                    let succeeded = await NoopLocalReset.perform(model: model)
                    resetInProgress = false
                    if succeeded {
                        navigation.reset(to: .today)
                    } else {
                        resetError = "Noop could not remove the complete local record. The remaining record is still visible; try again."
                    }
                }
            }
            .onAppear { consumeHomeScreenActionIfPossible() }
            .onChange(of: homeScreenQuickActions.pendingAction) { _, _ in
                consumeHomeScreenActionIfPossible()
            }
            .onChange(of: homeScreenQuickActionsEnabled) { _, _ in
                consumeHomeScreenActionIfPossible()
            }
            .task(id: repo.refreshSeq) {
                await NoopScheduleInference.applyIfReady(repo: repo)
            }
            .overlay {
                if resetInProgress {
                    ZStack {
                        NoopHTMLColor.canvas.opacity(0.9).ignoresSafeArea()
                        VStack(spacing: 13) {
                            ProgressView().tint(NoopHTMLColor.blue)
                            Text("Deleting your local record…")
                                .font(NoopHTMLFont.sans(13, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.ink)
                        }
                    }
                    .zIndex(100)
                }
            }
            .alert("Couldn’t delete everything", isPresented: Binding(
                get: { resetError != nil },
                set: { if !$0 { resetError = nil } }
            )) {
                Button("Done") { resetError = nil }
            } message: {
                Text(resetError ?? "")
            }
    }

    private func route(_ destination: NavRouter.Destination) {
        switch destination {
        case .devices:
            navigation.push(.devices)
        case .insightsHub, .trends:
            navigation.reset(to: .trends)
        case .labBook:
            navigation.push(.labs)
        case .fusedRecord:
            navigation.push(.record)
        case .rhythm:
            navigation.push(.rhythm)
        case .activeWorkout:
            navigation.push(navigation.selectedWorkout == .intervals ? .intervals : .live)
        case .liveSession:
            navigation.push(.session)
        case .breathe:
            navigation.push(.stress)
        case .journal:
            navigation.show(.dayLog)
        case .dataSources:
            navigation.push(.data)
        case .sleep:
            navigation.reset(to: .rest)
        }
    }

    private func consumeHomeScreenActionIfPossible() {
        guard homeScreenQuickActionsEnabled,
              let action = homeScreenQuickActions.pendingAction else { return }
        homeScreenQuickActions.consume(action)
        switch action {
        case .liveHeartRate:
            navigation.push(.heart)
        case .startWorkout:
            navigation.push(.session)
        case .logJournal:
            navigation.show(.dayLog)
        case .breathe:
            navigation.push(.stress)
        }
    }
}

/// Legacy catalog value retained only because MoreCatalog remains a source-level index used by
/// existing tooling. The old More UI is gone; none of these cases render the canonical shell.
enum MoreDestination: Hashable {
    case insightsHub, intelligence, coach, coachSettings, goalJourney, insights, explore, compare
    case live, workouts, health, labBook, stress, breathe, intervals, rhythm
    case fusedRecord, appleHealth, miBand, dataSources, backupSync, shortcutsExport, noopLimitations
    case alarms, automations, testCentre, siriShortcuts, powerSaving, settings
    case settingsSearch(String)
}
#endif
