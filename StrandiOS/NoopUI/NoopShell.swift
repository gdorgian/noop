import SwiftUI
import UIKit
import WhoopStore
import StrandDesign

/// The canonical HTML contains a complete, deterministic example person so every state can be
/// reviewed in Simulator. Those values are permitted only in an explicitly seeded Debug process.
/// A Release build cannot enter the prototype branch, even if a launch argument is injected.
enum NoopContentPolicy {
    static var allowsPrototypeContent: Bool {
        #if DEBUG
        CommandLine.arguments.contains("--demo-seed")
        #else
        false
        #endif
    }
}

struct NoopAppShell: View {
    @ObservedObject var navigation: NoopNavigation
    @EnvironmentObject private var liftSession: LiftSessionController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var labDraft = NoopLabReviewDraft()
    @StateObject private var liftFlow = NoopLiftFlowModel()
    @State private var dragTranslation: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let viewportWidth = min(proxy.size.width, UIScreen.main.bounds.width)
            ZStack {
                NoopHTMLColor.canvas.ignoresSafeArea()
                ambientGlow

                screen
                    .accessibilityHidden(navigation.overlay != nil)
                    // Every HTML `.scr` enters from opacity 0 / y +9 on the full child route.
                    // Durable Act state lives in navigation/scene storage, outside this visual identity.
                    .id(navigation.route.rawValue)
                    .transition(
                        .asymmetric(
                            // A push rises 9 pt. A tab-level arrival did not come from anywhere,
                            // so it crossfades in place and the tab bar's tint carries the change.
                            insertion: screenInsertion,
                            removal: screenRemoval
                        )
                    )

                if !navigation.route.hidesBottomBar {
                    VStack(spacing: 6) {
                        Spacer()
                        // Change 2. Directly above the tab bar, on every screen, while a session runs
                        // or is paused. Not dismissible: a running session the app has quietly
                        // forgotten is worse than a bar that will not go away.
                        if liftSession.isActive {
                            NoopLiftLiveBar(navigation: navigation)
                                .frame(width: max(0, viewportWidth - 28))
                                .transition(.asymmetric(
                                    insertion: reduceMotion
                                        ? .opacity
                                        : .move(edge: .bottom).combined(with: .opacity),
                                    removal: .identity
                                ))
                        } else if navigation.sessionRunning {
                            NoopCardioLiveBar(navigation: navigation)
                                .frame(width: max(0, viewportWidth - 28))
                                .transition(.asymmetric(
                                    insertion: reduceMotion
                                        ? .opacity
                                        : .move(edge: .bottom).combined(with: .opacity),
                                    removal: .identity
                                ))
                        }
                        NoopBottomNavigation(navigation: navigation)
                            .frame(width: max(0, viewportWidth - 28))
                            .padding(.bottom, 26)
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .ignoresSafeArea(.keyboard)
                    .accessibilityHidden(navigation.overlay != nil)
                    .zIndex(5)
                }

                if let overlay = navigation.overlay {
                    NoopOverlayHost(overlay: overlay, navigation: navigation)
                        .frame(width: viewportWidth, height: proxy.size.height)
                        .zIndex(20)
                }
            }
            .frame(width: viewportWidth, height: proxy.size.height)
            .clipped()
            .foregroundStyle(NoopHTMLColor.ink)
            .font(NoopHTMLFont.sans(14))
            .preferredColorScheme(.dark)
            .contentShape(Rectangle())
            .simultaneousGesture(backGesture)
            // Content ends above the bar: its 46 pt plus the 6 pt gap.
            .environment(\.noopLiveBarInset,
                         (liftSession.isActive || navigation.sessionRunning)
                            && !navigation.route.hidesBottomBar ? 52 : 0)
        }
        .frame(width: UIScreen.main.bounds.width)
        // Every act uses the canonical 402 x 874 canvas behind both system bars. Their
        // own HTML paddings place content at y=58/56 and the nav 26pt from the true bottom.
        .ignoresSafeArea(
            .container,
            edges: navigation.route.act == .night || navigation.route.act == .day || navigation.route.act == .effort || navigation.route.act == .picture || navigation.route.act == .plumbing || navigation.route.act == .ages || navigation.route.act == .svea || navigation.route.act == .goals || navigation.route.act == .instrument || navigation.route.act == .lift ? .all : []
        )
        .onChange(of: navigation.route) { oldRoute, newRoute in
            if oldRoute == .review, newRoute != .review {
                labDraft.scrub()
            }
        }
    }

    private var screenInsertion: AnyTransition {
        if reduceMotion { return .opacity }
        switch navigation.arrival {
        case .coverIn:
            return .move(edge: .bottom)
        case .pushed:
            return .opacity.combined(with: .offset(y: 9))
        case .arrived, .coverOut:
            return .opacity
        }
    }

    private var screenRemoval: AnyTransition {
        guard !reduceMotion else { return .identity }
        return navigation.arrival == .coverOut ? .move(edge: .bottom) : .identity
    }

    @ViewBuilder
    private var screen: some View {
        switch navigation.route.act {
        case .night: NoopAct1Screens(navigation: navigation)
        case .day: NoopAct2Screens(navigation: navigation)
        case .effort: NoopAct3Screens(navigation: navigation)
        case .picture: NoopAct4Screens(navigation: navigation)
        case .plumbing: NoopAct5Screens(navigation: navigation)
        case .ages: NoopAct6Screens(navigation: navigation)
        case .svea: NoopAct7Screens(navigation: navigation)
        case .goals: NoopAct8Screens(navigation: navigation, labDraft: labDraft)
        case .instrument: NoopAct9Screens(navigation: navigation, data: .prototype)
        case .lift: NoopAct10Screens(navigation: navigation, flow: liftFlow)
        }
    }

    private var ambientColor: Color { NoopAmbient.color(for: navigation.route, warmEffort: usesWarmEffortAmbient) }

    private var ambientOpacity: Double { NoopAmbient.opacity(for: navigation.route, warmEffort: usesWarmEffortAmbient) }

    private var usesWarmEffortAmbient: Bool {
        !navigation.workoutChosenByUser || navigation.selectedWorkout == .intervals || navigation.selectedWorkout == .strength
    }

    @ViewBuilder
    private var ambientGlow: some View {
        if navigation.route.act == .night {
            NoopNightAmbientGlow()
        } else {
            VStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(
                                    color: ambientColor.opacity(ambientOpacity),
                                    location: 0
                                ),
                                .init(
                                    color: ambientColor.opacity(0),
                                    location: 0.7
                                )
                            ],
                            center: .center,
                            startRadius: 0,
                                    endRadius: usesLargeAmbientGeometry ? 319 : 312
                        )
                    )
                    .frame(
                        width: usesLargeAmbientGeometry ? 480 : 470,
                        height: usesLargeAmbientGeometry ? 420 : 410
                    )
                    .blur(radius: 18)
                    .offset(y: usesLargeAmbientGeometry ? -170 : -150)
                Spacer()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.5), value: navigation.route.rawValue)
        }
    }

    private var usesLargeAmbientGeometry: Bool {
        navigation.route.act == .ages || navigation.route.act == .svea || navigation.route.act == .goals
    }

    private var backGesture: some Gesture {
        DragGesture(minimumDistance: 22, coordinateSpace: .local)
            .onChanged { value in
                dragTranslation = value.translation
            }
            .onEnded { value in
                navigation.handleBackSwipe(
                    startX: value.startLocation.x,
                    translation: value.translation
                )
                dragTranslation = .zero
            }
    }
}

/// Change 2 · the live bar. Left the workout, centre the ticking clock, right the pulse — or
/// `Paused` where the pulse was. Tapping it returns to the session's own screen.
private struct NoopCardioLiveBar: View {
    @ObservedObject var navigation: NoopNavigation
    /// Production: the recorder's clock and the strap's pulse instead of the fixture's.
    var measured = false
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var live: LiveState

    private var model: Act3WorkoutModel { navigation.selectedWorkout.act3 }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let elapsed = navigation.sessionElapsed(at: timeline.date)
            let shown = measured
                ? Int(app.activeWorkout?.elapsed(at: timeline.date) ?? 0)
                : navigation.sessionElapsedDisplay(at: timeline.date)
            Button { navigation.push(measured ? .live : navigation.liveRoute) } label: {
                HStack(spacing: 12) {
                    Text(measured ? (app.activeWorkout?.sport ?? "Session") : model.name)
                        .font(NoopHTMLFont.sans(13, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.ink)
                        .lineLimit(1)
                    Text(Self.clock(shown))
                        .font(NoopHTMLFont.sans(13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(NoopHTMLColor.blueLight)
                    Spacer(minLength: 4)
                    if measured ? (app.activeWorkout?.isPaused ?? false) : navigation.sessionPaused {
                        Text("Paused")
                            .font(NoopHTMLFont.sans(12, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x7F8A85))
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(measured ? (live.heartRate.map(String.init) ?? "\u{2014}")
                                          : "\(Self.bpm(model: model, elapsed: elapsed))")
                                .font(NoopHTMLFont.sans(13, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(NoopHTMLColor.ink)
                            Text("bpm")
                                .font(NoopHTMLFont.sans(11))
                                .foregroundStyle(Color(hex: 0x7F8A85))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 46)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(NoopHTMLColor.blue.opacity(0.32), lineWidth: 0.5))
            }
            .buttonStyle(NoopHTMLPressStyle())
        }
    }

    private static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// The same fixture pulse the live screen draws, so the bar and the screen agree.
    private static func bpm(model: Act3WorkoutModel, elapsed: Int) -> Int {
        let middle = Double(model.low + model.high) / 2
        return Int((middle + 9 * sin(Double(elapsed) / 7) + 4 * sin(Double(elapsed) / 2.4)).rounded())
    }
}

/// Act 10's one in-app projection of the root-owned Lift session. It has no controls and no local
/// clock. Tapping it returns to `lift-live`; every displayed value comes from the controller that
/// also drives the Lock Screen and Dynamic Island.
private struct NoopLiftLiveBar: View {
    @ObservedObject var navigation: NoopNavigation
    @EnvironmentObject private var session: LiftSessionController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(UnitPrefs.systemKey) private var unitSystemRaw = UnitSystem.metric.rawValue

    private var unitSystem: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: reduceMotion || session.isPaused)) { timeline in
            if let presentation = session.presentation(system: unitSystem) {
                Button {
                    session.isPresented = true
                    navigation.reset(to: .liftLive)
                } label: {
                    HStack(spacing: 11) {
                        Circle()
                            .fill(dotColor(presentation))
                            .frame(width: 8, height: 8)
                            .opacity(dotOpacity(at: timeline.date, presentation: presentation))

                        Text(presentation.exercise)
                            .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                            .foregroundStyle(presentation.isPaused
                                ? NoopHTMLColor.inkSoft : NoopHTMLColor.ink)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer(minLength: 0)

                        Text(clock(presentation))
                            .font(clockFont(presentation))
                            .tracking(presentation.isPaused || presentation.isReady ? 0 : -0.34)
                            .monospacedDigit()
                            .foregroundStyle(clockColor(presentation))
                            .lineLimit(1)
                            .fixedSize()

                        Text(setLabel(presentation))
                            .font(NoopHTMLFont.sans(12, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(presentation.isPaused
                                ? Color(hex: 0x7F8A85) : NoopHTMLColor.muted)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .frame(maxWidth: .infinity)
                    .background {
                        ZStack {
                            NoopGlass(radius: 20)
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(fillColor(presentation))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(borderColor(presentation), lineWidth: 0.5)
                    }
                    .shadow(color: Color.black.opacity(0.45), radius: 13, y: 8)
                    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(NoopHTMLPressStyle())
                .accessibilityLabel("Open the running lift session")
            }
        }
        .frame(height: 46)
    }

    private func fillColor(_ p: LiftSessionController.Presentation) -> Color {
        if p.isPaused { return Color.white.opacity(0.06) }
        if p.isResting && !p.isReady { return Color.white.opacity(0.07) }
        return NoopHTMLColor.blue.opacity(0.14)
    }

    private func borderColor(_ p: LiftSessionController.Presentation) -> Color {
        if p.isPaused { return Color.white.opacity(0.16) }
        if p.isResting && !p.isReady { return Color.white.opacity(0.17) }
        return NoopHTMLColor.blue.opacity(0.40)
    }

    private func dotColor(_ p: LiftSessionController.Presentation) -> Color {
        if p.isPaused { return Color(hex: 0x7F8A85) }
        if p.isResting && !p.isReady { return NoopHTMLColor.blueLight }
        return NoopHTMLColor.blue
    }

    private func clockColor(_ p: LiftSessionController.Presentation) -> Color {
        if p.isPaused { return Color(hex: 0x7F8A85) }
        if p.isResting || p.isReady { return NoopHTMLColor.blueLight }
        return NoopHTMLColor.ink
    }

    private func clockFont(_ p: LiftSessionController.Presentation) -> Font {
        if p.isPaused || p.isReady { return NoopHTMLFont.sans(13, weight: .semibold) }
        return NoopHTMLFont.outfit(17, weight: .regular)
    }

    private func dotOpacity(at date: Date,
                            presentation: LiftSessionController.Presentation) -> Double {
        guard !reduceMotion, !presentation.isPaused else { return 1 }
        let phase = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: 1.1) / 1.1
        return 0.45 + 0.55 * (0.5 - 0.5 * cos(phase * 2 * .pi))
    }

    private func clock(_ p: LiftSessionController.Presentation) -> String {
        if p.isPaused { return "Paused" }
        if p.isReady { return "Ready" }
        if p.isResting, let remaining = session.engine?.restRemaining(now: session.now) {
            return format(remaining)
        }
        guard let engine = session.engine else { return "0:00" }
        return format(max(0, session.now - engine.stageStartedAt))
    }

    private func setLabel(_ p: LiftSessionController.Presentation) -> String {
        guard let engine = session.engine else { return "" }
        if p.isResting && !p.isReady { return "rest" }

        let slot: LiftSlot?
        if p.isReady, let current = engine.currentSlot {
            slot = engine.slotAfter(current)
        } else {
            slot = engine.currentSlot ?? engine.nextPendingSlot
        }
        guard let slot, let item = engine.planItem(for: slot) else {
            return "\(p.setsDone)/\(p.setsPlanned)"
        }
        return "Set \(slot.setIndex)/\(item.targetSets)"
    }

    private func format(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        return String(format: "%d:%02d", safe / 60, safe % 60)
    }
}

/// Each act's ambient glow — one rule, read by the seeded shell and the production shell alike.
enum NoopAmbient {
    static func color(for route: NoopRoute, warmEffort: Bool) -> Color {
        switch route.act {
        case .night: NoopHTMLColor.night
        case .picture: NoopHTMLColor.green
        // Act 6 keeps the same green ambient on every child screen. The Health branch changes
        // only the selected navigation pill to warm; the canonical HTML never recolours the aura.
        case .ages: NoopHTMLColor.green
        case .plumbing:
            switch route {
            case .strap, .devices, .pair: NoopHTMLColor.blue
            case .lab: NoopHTMLColor.night
            default: NoopHTMLColor.blush
            }
        case .svea: NoopHTMLColor.night
        case .goals: NoopHTMLColor.warm
        case .instrument: NoopHTMLColor.night
        case .effort: warmEffort ? NoopHTMLColor.warm : NoopHTMLColor.blue
        // PROVISIONAL, and the same value the default would have given. Stated explicitly so the
        // act's ambient is a named decision design can change rather than an inherited accident.
        case .lift: NoopHTMLColor.blue
        default: NoopHTMLColor.blue
        }
    }

    static func opacity(for route: NoopRoute, warmEffort: Bool) -> Double {
        switch route.act {
        case .picture, .ages, .goals: 0.15
        case .instrument: 0.16
        case .svea: 0.16
        case .effort: warmEffort ? 0.15 : 0.17
        case .plumbing:
            switch route {
            case .strap, .devices, .pair: 0.14
            default: 0.13
            }
        default: 0.17
        }
    }
}

/// Act 1's slow lavender glow, shared by both shells so the measured Rest screen sits on exactly the
/// ambient the seeded one does.
struct NoopNightAmbientGlow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 9)
            let wave = (1 - cos(elapsed / 9 * 2 * .pi)) / 2
            VStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: NoopHTMLColor.night.opacity(0.20), location: 0),
                                .init(color: NoopHTMLColor.night.opacity(0), location: 0.70)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 312
                        )
                    )
                    .frame(width: 470, height: 430)
                    .blur(radius: 18)
                    .opacity(reduceMotion ? 0.72 : 0.55 + wave * 0.35)
                    .offset(y: -170)
                Spacer()
            }
            // The 470 pt ellipse is wider than the phone. A flexible frame lets it draw past the
            // edges without widening the shell, which pushed the + sheets and the terms gate off-screen.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// Fail-closed production surface. It deliberately renders only values present in the local record;
/// the richly populated canonical person remains a Debug-only visual fixture in `NoopAppShell`.
/// As individual canonical screens gain verified adapters they can replace this route-by-route, but
/// Release must never silently fall back to the fixture.
struct NoopVerifiedAppShell: View {
    @ObservedObject var navigation: NoopNavigation
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var liftSession: LiftSessionController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var labDraft = NoopLabReviewDraft()
    @StateObject private var instrumentStore = NoopInstrumentLiveStore()
    @StateObject private var liftFlow = NoopLiftFlowModel()
    @StateObject private var restStore = NoopRestStore()
    @StateObject private var dayStore = NoopDayStore()
    @StateObject private var trendsStore = NoopTrendsStore()
    @StateObject private var youStore = NoopYouStore()
    @StateObject private var historyStore = NoopHistoryStore()
    @StateObject private var effortStore = NoopEffortStore()
    @StateObject private var agesStore = NoopAgesStore()
    /// Today's day-log counts as last written to the journal, and the day they belong to.
    @State private var journalSynced: [NoopDayLogKind: Int] = [:]
    @State private var journalSyncedDay: String?
    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var model: AppModel
    /// Observed so the Rest header's battery chip redraws when the strap reports a new charge.
    @EnvironmentObject private var live: LiveState

    /// The four Act 8 screens that are safe to show outside the fixture shell.
    ///
    /// They read the Lab Book directly and render an absent state wherever it holds nothing — no
    /// demo band, no clinic, no invented date, no trend from a single point. The rest of the
    /// canonical shell is still fixture-backed, so it stays behind `--demo-seed`; routing these
    /// four here is what replaces the generic Local-record list with the screens the design
    /// actually specifies.
    private static let canonicalLabRoutes: Set<NoopRoute> = [.labs, .picker, .review, .marker, .goal, .setGoal]

    /// Breathe runs on the real protocol catalog, the strap's buzz and `ResonanceEngine`. With no
    /// strap it paces on screen and says so; with no sweep it says there is no pace yet. Nothing on
    /// it is a fixture outside `--demo-seed`, so it is safe here too.
    private static let canonicalBreatheRoutes: Set<NoopRoute> = [.breathe, .bcatalog, .bplayer, .bsweep, .bfound]

    /// Act 5's data door is backed by the real importers, local store and backup engines. Its Debug
    /// fixture lives inside `NoopDataScreen`; the same view fails closed onto measured values here.
    private static let canonicalDataRoutes: Set<NoopRoute> = [
        .data, .importHistory, .reading, .imported, .rejected, .backup
    ]

    /// Act 9's catalog is static, but every value and every relationship comes from the local record.
    /// The prototype person never crosses this boundary.
    private static let canonicalInstrumentRoutes: Set<NoopRoute> = [
        .instrumentIndex, .instrumentMetric, .instrumentCompare, .instrumentEffects,
        .instrumentRaw, .instrumentCapture
    ]

    /// Act 10 is canonical from the start. The Lift Log is not a prototype fixture: the session, the
    /// engine, the persistence and the 1,324-exercise catalogue are all real, local and already
    /// shipping — so these routes belong on the measured side of the boundary rather than behind
    /// `--demo-seed`. The screens themselves are placeholders until design lands them; being
    /// canonical is what makes `--noop-route lift-live` reach one in an ordinary Debug build.
    private static let canonicalLiftRoutes: Set<NoopRoute> = [
        .liftLive, .liftLibrary, .liftProgram, .liftDetail,
        .liftEdit, .liftImport, .liftReview, .liftMuscles
    ]

    /// Act 1's home. Measured from the same sleep pipeline the classic Sleep tab uses; a night with no
    /// record stays absent, and sentences design has written only for the example person are omitted.
    private static let canonicalNightRoutes: Set<NoopRoute> = [.rest, .debt, .alarm, .tonight]

    /// Act 2's home. Charge left and every sentence written only for the example person are absent.
    private static let canonicalDayRoutes: Set<NoopRoute> = [.today, .vitals, .stress, .heart, .day, .inbox]

    /// Act 4's home: four weekly lines and the attendance grid from the stored daily rows. Body age
    /// stays out until its engine is chosen.
    private static let canonicalPictureRoutes: Set<NoopRoute> = [.trends, .capacity, .rhythm]

    /// Act 6 on one engine (`VitalityEngine`): hero, band, drivers and history from the same call.
    /// Driver detail, the method page and the health hub have no production source and stay out.
    private static let canonicalAgesRoutes: Set<NoopRoute> = [.ages, .building, .driver]

    /// Act 3 on the stored sessions and the real recorder. The prescription (what today can take,
    /// what a session would cost) has no engine and stays out.
    private static let canonicalEffortRoutes: Set<NoopRoute> = [.session, .pick, .ready, .live, .intervals, .detail, .across]

    /// Act 7 runs on the real coach engine, grants and memory; its prototype conversation is gated on
    /// `--demo-seed` inside the act.
    private static let canonicalSveaRoutes: Set<NoopRoute> = [.coach, .gate, .setup, .consent, .memory]

    /// Act 5's hub: the wearer's own name, photo, usual sleep window and need. The rest of Act 5 is
    /// wired separately, screen by screen.
    private static let canonicalYouRoutes: Set<NoopRoute> = [.you, .record, .zones, .settings, .lab, .position, .strap, .history, .devices, .notifs, .apple, .widgets, .automations]

    private var usesCanonicalCanvas: Bool {
        navigation.route == .energy
            || Self.canonicalNightRoutes.contains(navigation.route)
            || Self.canonicalDayRoutes.contains(navigation.route)
            || Self.canonicalPictureRoutes.contains(navigation.route)
            || Self.canonicalEffortRoutes.contains(navigation.route)
            || Self.canonicalAgesRoutes.contains(navigation.route)
            || Self.canonicalSveaRoutes.contains(navigation.route)
            || Self.canonicalYouRoutes.contains(navigation.route)
            || Self.canonicalLabRoutes.contains(navigation.route)
            || Self.canonicalBreatheRoutes.contains(navigation.route)
            || Self.canonicalDataRoutes.contains(navigation.route)
            || Self.canonicalInstrumentRoutes.contains(navigation.route)
            || Self.canonicalLiftRoutes.contains(navigation.route)
    }

    var body: some View {
        ZStack {
            NoopHTMLColor.canvas.ignoresSafeArea()
            verifiedAmbientGlow

            Group {
                if navigation.route == .energy {
                    NoopVerifiedEnergyScreen(navigation: navigation)
                } else if Self.canonicalSveaRoutes.contains(navigation.route) {
                    NoopAct7Screens(navigation: navigation)
                } else if Self.canonicalYouRoutes.contains(navigation.route) {
                    NoopAct5Screens(navigation: navigation, you: youStore.record,
                                    battery: WidgetSnapshot.activeBatteryPct(from: model),
                                    history: historyStore.record)
                } else if Self.canonicalAgesRoutes.contains(navigation.route) {
                    NoopAct6Screens(navigation: navigation, measured: agesStore.record)
                } else if Self.canonicalEffortRoutes.contains(navigation.route) {
                    NoopAct3Screens(navigation: navigation, effort: effortStore.record,
                                    battery: WidgetSnapshot.activeBatteryPct(from: model))
                } else if Self.canonicalPictureRoutes.contains(navigation.route) {
                    NoopAct4Screens(navigation: navigation, trends: trendsStore.record,
                                    battery: WidgetSnapshot.activeBatteryPct(from: model),
                                    ages: agesStore.record)
                } else if Self.canonicalDayRoutes.contains(navigation.route) {
                    NoopAct2Screens(navigation: navigation, day: dayStore.record,
                                    battery: WidgetSnapshot.activeBatteryPct(from: model),
                                    liveBPM: live.connected ? live.heartRate : nil,
                                    displayName: profile.displayName)
                } else if Self.canonicalNightRoutes.contains(navigation.route) {
                    NoopAct1Screens(navigation: navigation, rest: restStore.record,
                                    battery: WidgetSnapshot.activeBatteryPct(from: model))
                } else if Self.canonicalLabRoutes.contains(navigation.route) {
                    NoopAct8Screens(navigation: navigation, labDraft: labDraft)
                } else if Self.canonicalBreatheRoutes.contains(navigation.route) {
                    NoopBreatheScreens(navigation: navigation)
                } else if Self.canonicalDataRoutes.contains(navigation.route) {
                    NoopDataScreen(navigation: navigation)
                } else if Self.canonicalInstrumentRoutes.contains(navigation.route) {
                    NoopAct9Screens(navigation: navigation, data: instrumentStore.data)
                } else if Self.canonicalLiftRoutes.contains(navigation.route) {
                    NoopAct10Screens(navigation: navigation, flow: liftFlow)
                } else {
                    NoopVerifiedRouteScreen(
                        route: navigation.route,
                        repo: repo,
                        backAction: verifiedBack
                    )
                }
            }
                .id(navigation.route.rawValue)
                .transition(
                    .asymmetric(
                        insertion: reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 9)),
                        removal: .identity
                    )
                )

            if !navigation.route.hidesBottomBar {
                VStack(spacing: 6) {
                    Spacer()
                    if liftSession.isActive {
                        NoopLiftLiveBar(navigation: navigation)
                            .frame(width: max(0, UIScreen.main.bounds.width - 28))
                            .transition(reduceMotion
                                ? .opacity
                                : .move(edge: .bottom).combined(with: .opacity))
                    } else if model.activeWorkout != nil {
                        NoopCardioLiveBar(navigation: navigation, measured: true)
                            .frame(width: max(0, UIScreen.main.bounds.width - 28))
                    }
                    NoopBottomNavigation(navigation: navigation)
                        .frame(width: max(0, UIScreen.main.bounds.width - 28))
                        .padding(.bottom, 26)
                }
                .ignoresSafeArea(edges: .bottom)
                .zIndex(5)
            }

            if let overlay = navigation.overlay {
                // Every sheet is the designed one. Those that carry figures read the wearer's record in
                // Release (day log, night journal, logged items, goal editor); the rest are catalogs,
                // confirmations of real actions, or navigation.
                NoopOverlayHost(overlay: overlay, navigation: navigation)
                    .zIndex(20)
            }
        }
        .foregroundStyle(NoopHTMLColor.ink)
        .font(NoopHTMLFont.sans(14))
        .preferredColorScheme(.dark)
        .contentShape(Rectangle())
        .simultaneousGesture(verifiedBackGesture)
        .environment(\.noopLiveBarInset,
                     (liftSession.isActive || navigation.sessionRunning || model.activeWorkout != nil)
                        && !navigation.route.hidesBottomBar ? 52 : 0)
        // Canonical pages measure their 56 pt header inset from the full 402 x 874 canvas, exactly
        // like the fixture shell. Without this, SwiftUI first removes the status-bar safe area and
        // NoopScreen adds 56 pt again, putting every verified Lab/Breathe page about 60 pt too low.
        .ignoresSafeArea(.container, edges: usesCanonicalCanvas ? .top : [])
        .task(id: instrumentLoadKey) {
            guard instrumentLoadKey != nil else { return }
            await instrumentStore.load(from: repo)
        }
        .task(id: restLoadKey) {
            guard restLoadKey != nil else { return }
            await restStore.load(from: repo)
        }
        .task(id: "\(repo.loaded)-\(Repository.localDayKey(Date()))") {
            guard repo.loaded else { return }
            await loadJournal()
        }
        .onChange(of: navigation.dayLogCounts) { _, counts in
            writeDayLog(counts)
        }
        .onChange(of: navigation.nightJournalRevision) { _, _ in
            writeNightJournal()
        }
        .task(id: youLoadKey) {
            guard youLoadKey != nil else { return }
            await youStore.load(from: repo)
            if navigation.route == .history { await historyStore.load(from: repo) }
        }
        .task(id: trendsLoadKey) {
            guard trendsLoadKey != nil else { return }
            await trendsStore.load(from: repo)
        }
        .task(id: agesLoadKey) {
            guard agesLoadKey != nil else { return }
            await agesStore.load(from: repo, profile: profile)
        }
        .task(id: effortLoadKey) {
            guard effortLoadKey != nil else { return }
            await effortStore.load(from: repo)
        }
        .task(id: dayLoadKey) {
            guard dayLoadKey != nil else { return }
            await dayStore.load(from: repo, profile: profile)
        }
    }

    private var youLoadKey: String? {
        Self.canonicalYouRoutes.contains(navigation.route)
            ? "\(navigation.route.rawValue)-\(repo.loaded)-\(repo.refreshSeq)" : nil
    }

    private var trendsLoadKey: String? {
        Self.canonicalPictureRoutes.contains(navigation.route) ? "\(repo.loaded)-\(repo.refreshSeq)" : nil
    }

    private var agesLoadKey: String? {
        Self.canonicalAgesRoutes.contains(navigation.route) || navigation.route == .trends
            ? "\(repo.loaded)-\(repo.refreshSeq)" : nil
    }

    private var effortLoadKey: String? {
        Self.canonicalEffortRoutes.contains(navigation.route) ? "\(repo.loaded)-\(repo.refreshSeq)" : nil
    }

    private var dayLoadKey: String? {
        Self.canonicalDayRoutes.contains(navigation.route) ? "\(repo.loaded)-\(repo.refreshSeq)" : nil
    }

    private var restLoadKey: String? {
        Self.canonicalNightRoutes.contains(navigation.route) ? "\(repo.loaded)-\(repo.refreshSeq)" : nil
    }

    // MARK: Journal — the + sheets write the wearer's record

    private static let nightJournalDayKey = "noop.nightJournal.savedDay"
    private static let nightJournalAtKey = "noop.nightJournal.savedAt"

    /// Today's journal, mood and night-journal state from the stores. The day log's counts are the
    /// journal's numeric answers under the tile names; the night journal's drinks are the same
    /// "Alcohol" answer, so the two sheets never disagree.
    private func loadJournal() async {
        let day = Repository.localDayKey(Date())
        let entries = await repo.journalEntries(days: 2).filter { $0.day == day }
        var counts: [NoopDayLogKind: Int] = [:]
        for kind in NoopDayLogKind.allCases {
            guard let entry = entries.first(where: { $0.question == kind.rawValue }), entry.answeredYes else { continue }
            counts[kind] = max(1, Int((entry.numericValue ?? 1).rounded()))
        }
        journalSynced = counts
        journalSyncedDay = day
        navigation.loadDayLogCounts(counts)

        let defaults = UserDefaults.standard
        let savedToday = defaults.string(forKey: Self.nightJournalDayKey) == day
        let mood = await repo.mood(day: day)
        navigation.nightJournalMood = mood.map { $0 - 1 } ?? -1
        if let drinks = counts[.alcohol] {
            navigation.nightJournalDrinks = min(drinks, 3)
        } else {
            navigation.nightJournalDrinks = entries.contains { $0.question == NoopDayLogKind.alcohol.rawValue } ? 0 : -1
        }
        navigation.nightJournalNotes = Set(NoopNightJournalSheet.noteItems.filter { note in
            entries.contains { $0.question == note && $0.answeredYes }
        })
        navigation.nightJournalSaved = savedToday
        let at = defaults.double(forKey: Self.nightJournalAtKey)
        navigation.nightJournalSavedAt = savedToday && at > 0 ? Date(timeIntervalSince1970: at) : nil
    }

    /// Writes only what changed since the last write. A new day starts from nothing, so a count
    /// carried over from yesterday is never written as a "no" for today.
    private func writeDayLog(_ counts: [NoopDayLogKind: Int]) {
        let day = Repository.localDayKey(Date())
        let previous = journalSyncedDay == day ? journalSynced : [:]
        journalSynced = counts
        journalSyncedDay = day
        for kind in NoopDayLogKind.allCases {
            let now = counts[kind, default: 0], before = previous[kind, default: 0]
            guard now != before else { continue }
            if kind == .coffee, now > before {
                // The tile's promise: a coffee starts the caffeine clock.
                for _ in before..<now { CaffeineLogStore.shared.log(at: Date()) }
            }
            Task {
                if now > 0 {
                    await repo.saveJournalNumeric(day: day, question: kind.rawValue, value: Double(now))
                } else {
                    await repo.saveJournalAnswer(day: day, question: kind.rawValue, answeredYes: false)
                }
            }
        }
    }

    /// Save writes mood, drinks and the four notes; Delete removes the mood and answers the notes no.
    /// Unchosen fields (-1) are not written.
    private func writeNightJournal() {
        let day = Repository.localDayKey(Date())
        let defaults = UserDefaults.standard
        let saved = navigation.nightJournalSaved
        if saved {
            defaults.set(day, forKey: Self.nightJournalDayKey)
            defaults.set((navigation.nightJournalSavedAt ?? Date()).timeIntervalSince1970, forKey: Self.nightJournalAtKey)
        } else {
            defaults.removeObject(forKey: Self.nightJournalDayKey)
            defaults.removeObject(forKey: Self.nightJournalAtKey)
        }
        let mood = navigation.nightJournalMood
        let drinks = navigation.nightJournalDrinks
        let notes = navigation.nightJournalNotes
        if saved, drinks >= 0 {
            var counts = navigation.dayLogCounts
            counts[.alcohol] = drinks > 0 ? drinks : nil
            navigation.loadDayLogCounts(counts)   // written by writeDayLog through onChange
        }
        Task {
            if saved, mood >= 0 {
                await repo.saveMood(day: day, value: mood + 1)
            } else if !saved, let store = await repo.storeHandle() {
                _ = try? await store.deleteMetricSeriesPoint(deviceId: MoodStore.moodDeviceId, day: day,
                                                             key: MoodStore.moodKey)
            }
            for note in NoopNightJournalSheet.noteItems {
                await repo.saveJournalAnswer(day: day, question: note, answeredYes: saved && notes.contains(note))
            }
        }
    }

    private var instrumentLoadKey: Int? {
        Self.canonicalInstrumentRoutes.contains(navigation.route) ? repo.refreshSeq : nil
    }

    @ViewBuilder
    private var verifiedAmbientGlow: some View {
        if usesCanonicalCanvas && navigation.route.act == .night {
            NoopNightAmbientGlow()
        } else if usesCanonicalCanvas {
            let act = navigation.route.act
            let isLab = act == .ages || act == .svea || act == .goals
            // Amber meant "above what today can take" — a verdict production has no engine for.
            let warmEffort = false
            let color = NoopAmbient.color(for: navigation.route, warmEffort: warmEffort)
            let opacity = NoopAmbient.opacity(for: navigation.route, warmEffort: warmEffort)
            VStack {
                Ellipse()
                    .fill(RadialGradient(
                        stops: [
                            .init(color: color.opacity(opacity), location: 0),
                            .init(color: color.opacity(0), location: 0.7)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: isLab ? 319 : 312
                    ))
                    .frame(width: isLab ? 480 : 470, height: isLab ? 420 : 410)
                    .blur(radius: 18)
                    .offset(y: isLab ? -170 : -150)
                Spacer()
            }
            // Wider than the phone; see NoopNightAmbientGlow.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    private func verifiedBack() {
        if navigation.canGoBack {
            navigation.back()
            return
        }

        switch navigation.route.act {
        case .effort:
            navigation.reset(to: .session)
        case .plumbing:
            navigation.reset(to: .you)
        default:
            navigation.reset(to: navigation.route.tab.root)
        }
    }

    private var verifiedBackGesture: some Gesture {
        DragGesture(minimumDistance: 22, coordinateSpace: .local)
            .onEnded { value in
                guard value.startLocation.x <= 32,
                      value.translation.width > 78,
                      abs(value.translation.height) < 58 else { return }

                // Sheets always close before the route is considered, even on the three forward-only
                // import states. This is the same precedence as the primary shell.
                if navigation.overlay != nil {
                    navigation.back()
                    return
                }

                switch navigation.route {
                case .labs:
                    // Labs is an Act 8 root whose drawn chevron leaves the act rather than walking
                    // an arbitrary history stack.
                    navigation.reset(to: .you)
                case .picker, .review, .marker:
                    navigation.back(or: .labs)
                case .breathe:
                    navigation.back(or: .today)
                case .bcatalog, .bplayer, .bsweep, .bfound:
                    navigation.back(or: .breathe)
                case .data:
                    navigation.back(or: .you)
                case .importHistory, .backup:
                    navigation.back(or: .data)
                case .reading, .imported, .rejected:
                    // These are forward-only states and draw no back control.
                    return
                case .instrumentIndex:
                    navigation.reset(to: .trends)
                case .instrumentMetric, .instrumentCompare, .instrumentEffects:
                    navigation.back(or: .instrumentIndex)
                case .instrumentRaw:
                    navigation.back(or: .instrumentIndex)
                case .instrumentCapture:
                    navigation.back(or: .instrumentRaw)
                default:
                    // Keep the fail-closed placeholder's existing behaviour until that route gets
                    // its own verified production screen.
                    guard navigation.route.hidesBottomBar else { return }
                    verifiedBack()
                }
            }
    }
}

private struct NoopVerifiedRouteScreen: View {
    let route: NoopRoute
    @ObservedObject var repo: Repository
    let backAction: () -> Void

    private var latest: DailyMetric? { repo.days.last }

    var body: some View {
        NoopScreen {
            VStack(alignment: .leading, spacing: 14) {
                if route.hidesBottomBar {
                    NoopBackHeader(label: route.act == .effort ? "Session" : "You", action: backAction)
                }
                NoopScreenHeader(title, eyebrow: eyebrow)

                if !repo.loaded {
                    NoopHTMLCard {
                        HStack(spacing: 12) {
                            ProgressView().tint(NoopHTMLColor.blue)
                            Text("Loading your local record…")
                                .font(NoopHTMLFont.sans(13.5, weight: .medium))
                                .foregroundStyle(NoopHTMLColor.inkSoft)
                        }
                    }
                } else if let latest {
                    recordedCard(latest)
                } else {
                    NoopHTMLCard {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("No recorded measurements")
                                .font(NoopHTMLFont.sans(14.5, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.ink)
                            Text("This screen will remain empty until a measured, imported, or user-entered value is available.")
                                .font(NoopHTMLFont.sans(12.5))
                                .foregroundStyle(NoopHTMLColor.copy)
                                .lineSpacing(3)
                        }
                    }
                }
            }
        }
    }

    private func recordedCard(_ day: DailyMetric) -> some View {
        NoopHTMLCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    NoopSectionLabel("Local record")
                    Spacer()
                    Text(day.day)
                        .font(NoopHTMLFont.sans(11))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .monospacedDigit()
                }

                verifiedMetric("Sleep", day.totalSleepMin.map(formatMinutes), unit: "")
                verifiedMetric("Recovery", day.recovery.map { String(Int($0.rounded())) }, unit: "%")
                verifiedMetric("Effort", day.strain.map { $0.formatted(.number.precision(.fractionLength(1))) }, unit: "")
                verifiedMetric("Resting heart rate", day.restingHr.map(String.init), unit: "bpm")
                verifiedMetric("Heart-rate variability", day.avgHrv.map { String(Int($0.rounded())) }, unit: "ms")
                verifiedMetric("Breathing rate", day.respRateBpm.map { $0.formatted(.number.precision(.fractionLength(1))) }, unit: "/min")
                verifiedMetric("Blood oxygen", day.spo2Pct.map { $0.formatted(.number.precision(.fractionLength(0...1))) }, unit: "%")
                verifiedMetric("Skin-temperature deviation", day.skinTempDevC.map { String(format: "%+.1f", $0) }, unit: "°C")

                Text("Values without a recorded source are omitted.")
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(NoopHTMLColor.faint)
            }
        }
    }

    @ViewBuilder
    private func verifiedMetric(_ name: String, _ value: String?, unit: String) -> some View {
        if let value {
            HStack(alignment: .firstTextBaseline) {
                Text(name)
                    .font(NoopHTMLFont.sans(13))
                    .foregroundStyle(NoopHTMLColor.copy)
                Spacer()
                Text(value)
                    .font(NoopHTMLFont.outfit(20, weight: .light))
                    .foregroundStyle(NoopHTMLColor.ink)
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit)
                        .font(NoopHTMLFont.sans(10.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                }
            }
        }
    }

    private func formatMinutes(_ value: Double) -> String {
        let minutes = max(0, Int(value.rounded()))
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private var eyebrow: String {
        switch route.act {
        case .night: "The night"
        case .day: "The day"
        case .effort: "The effort"
        case .picture: "The bigger picture"
        case .plumbing: "The plumbing"
        case .ages: "Your ages"
        case .svea: "Svea"
        case .goals: "Goals and labs"
        case .instrument: "The instrument"
        case .lift: "The lift"
        }
    }

    private var title: String {
        switch route {
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
        case .widgets: "Widgets"
        case .lab: "The Lab"
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
        case .instrumentIndex: "Ask it something"
        case .instrumentMetric: "One signal"
        case .instrumentCompare: "Two at once"
        case .instrumentEffects: "What moves you"
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
        }
    }
}

enum NoopCanonicalGlyphName {
    case today, trends, moon, you, spark
    case cup, drop, plate, glass, heart, bed
    case lungs, bolt, clock, check, bike, walk, weight, wave, timer
    case pause, play, stop
    case read, scale, alarm, bell, screen, watch, cloud
    case shield, download, upload, trash, globe, ruler, sparkSingle, camera
    case person, sync, link, copy, share, x, flask, search, file
    case plus, grid, key, chart, gauge, mic, ask, overlay, chat
}

/// The HTML uses one 24 × 24 stroked SVG alphabet throughout. Drawing those paths directly keeps
/// line weight, cap shape, and proportions stable instead of substituting unrelated SF Symbols.
struct NoopCanonicalGlyph: View {
    let name: NoopCanonicalGlyphName
    var size: CGFloat = 19
    var color: Color = Color(hex: 0x7F8A85)

    var body: some View {
        Canvas { context, canvasSize in
            let scale = min(canvasSize.width, canvasSize.height) / 24
            let path = canonicalPath.applying(CGAffineTransform(scaleX: scale, y: scale))
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(
                    lineWidth: 1.7 * scale,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var canonicalPath: Path {
        var path = Path()
        switch name {
        case .today:
            path.move(to: CGPoint(x: 12, y: 3)); path.addLine(to: CGPoint(x: 12, y: 5))
            path.move(to: CGPoint(x: 12, y: 19)); path.addLine(to: CGPoint(x: 12, y: 21))
            path.move(to: CGPoint(x: 4.2, y: 12)); path.addLine(to: CGPoint(x: 2, y: 12))
            path.move(to: CGPoint(x: 22, y: 12)); path.addLine(to: CGPoint(x: 20, y: 12))
            path.move(to: CGPoint(x: 5.6, y: 5.6)); path.addLine(to: CGPoint(x: 4.2, y: 4.2))
            path.move(to: CGPoint(x: 19.8, y: 19.8)); path.addLine(to: CGPoint(x: 18.4, y: 18.4))
            path.move(to: CGPoint(x: 18.4, y: 5.6)); path.addLine(to: CGPoint(x: 19.8, y: 4.2))
            path.move(to: CGPoint(x: 4.2, y: 19.8)); path.addLine(to: CGPoint(x: 5.6, y: 18.4))
            path.addEllipse(in: CGRect(x: 7.5, y: 7.5, width: 9, height: 9))
        case .trends:
            path.move(to: CGPoint(x: 4, y: 18)); path.addLine(to: CGPoint(x: 4, y: 9))
            path.move(to: CGPoint(x: 9.5, y: 18)); path.addLine(to: CGPoint(x: 9.5, y: 5))
            path.move(to: CGPoint(x: 15, y: 18)); path.addLine(to: CGPoint(x: 15, y: 12))
            path.move(to: CGPoint(x: 20.5, y: 18)); path.addLine(to: CGPoint(x: 20.5, y: 9))
        case .moon:
            path.move(to: CGPoint(x: 20, y: 14.5))
            addCircularArc(&path, from: CGPoint(x: 20, y: 14.5), to: CGPoint(x: 9.5, y: 4), radius: 8.5, largeArc: false, sweep: true)
            addCircularArc(&path, from: CGPoint(x: 9.5, y: 4), to: CGPoint(x: 20, y: 14.5), radius: 8.5, largeArc: true, sweep: false)
            path.closeSubpath()
        case .you:
            path.addEllipse(in: CGRect(x: 8.8, y: 4.5, width: 6.4, height: 6.4))
            path.move(to: CGPoint(x: 5.5, y: 19.5))
            path.addCurve(to: CGPoint(x: 12, y: 14.2), control1: CGPoint(x: 5.5, y: 16.2), control2: CGPoint(x: 8.4, y: 14.2))
            path.addCurve(to: CGPoint(x: 18.5, y: 19.5), control1: CGPoint(x: 15.6, y: 14.2), control2: CGPoint(x: 18.5, y: 16.2))
        case .spark:
            path.move(to: CGPoint(x: 12, y: 3.5))
            path.addLine(to: CGPoint(x: 13.9, y: 8.6))
            path.addLine(to: CGPoint(x: 19, y: 10.5))
            path.addLine(to: CGPoint(x: 13.9, y: 12.4))
            path.addLine(to: CGPoint(x: 12, y: 17.5))
            path.addLine(to: CGPoint(x: 10.1, y: 12.4))
            path.addLine(to: CGPoint(x: 5, y: 10.5))
            path.addLine(to: CGPoint(x: 10.1, y: 8.6))
            path.closeSubpath()
            path.move(to: CGPoint(x: 18.5, y: 16.5))
            path.addLine(to: CGPoint(x: 19.3, y: 18.5))
            path.addLine(to: CGPoint(x: 21.3, y: 19.3))
            path.addLine(to: CGPoint(x: 19.3, y: 20.1))
            path.addLine(to: CGPoint(x: 18.5, y: 22.1))
            path.addLine(to: CGPoint(x: 17.7, y: 20.1))
            path.addLine(to: CGPoint(x: 15.7, y: 19.3))
            path.addLine(to: CGPoint(x: 17.7, y: 18.5))
            path.closeSubpath()
        case .watch:
            path.move(to: CGPoint(x: 8.6, y: 4.4)); path.addLine(to: CGPoint(x: 15.4, y: 4.4)); path.addLine(to: CGPoint(x: 16.1, y: 7.5))
            path.move(to: CGPoint(x: 8.6, y: 19.6)); path.addLine(to: CGPoint(x: 15.4, y: 19.6)); path.addLine(to: CGPoint(x: 16.1, y: 16.5))
            path.addEllipse(in: CGRect(x: 6.6, y: 6.6, width: 10.8, height: 10.8))
            path.move(to: CGPoint(x: 12, y: 10)); path.addLine(to: CGPoint(x: 12, y: 12.4)); path.addLine(to: CGPoint(x: 13.8, y: 13.6))
        case .cloud:
            path.move(to: CGPoint(x: 7.6, y: 18)); path.addLine(to: CGPoint(x: 16.8, y: 18))
            path.addCurve(
                to: CGPoint(x: 17.1, y: 11.6),
                control1: CGPoint(x: 19.4, y: 17.8),
                control2: CGPoint(x: 19.6, y: 13.2)
            )
            path.addCurve(
                to: CGPoint(x: 8, y: 9.7),
                control1: CGPoint(x: 14.8, y: 7.2),
                control2: CGPoint(x: 10.3, y: 7.4)
            )
            path.addCurve(
                to: CGPoint(x: 7.6, y: 18),
                control1: CGPoint(x: 3.2, y: 9.8),
                control2: CGPoint(x: 2.7, y: 17.7)
            )
            path.closeSubpath()
        case .cup:
            path.move(to: CGPoint(x: 4.5, y: 8)); path.addLine(to: CGPoint(x: 15.5, y: 8))
            path.addLine(to: CGPoint(x: 15.5, y: 13))
            addCircularArc(&path, from: CGPoint(x: 15.5, y: 13), to: CGPoint(x: 4.5, y: 13), radius: 5.5, largeArc: false, sweep: true)
            path.addLine(to: CGPoint(x: 4.5, y: 8)); path.closeSubpath()
            path.move(to: CGPoint(x: 15.5, y: 9)); path.addLine(to: CGPoint(x: 18, y: 9))
            addCircularArc(&path, from: CGPoint(x: 18, y: 9), to: CGPoint(x: 18, y: 13.8), radius: 2.4, largeArc: false, sweep: true)
            path.addLine(to: CGPoint(x: 15.5, y: 13.8))
            path.move(to: CGPoint(x: 4, y: 20)); path.addLine(to: CGPoint(x: 17, y: 20))
        case .drop:
            path.move(to: CGPoint(x: 12, y: 3.6))
            path.addCurve(to: CGPoint(x: 17, y: 12.3), control1: CGPoint(x: 15.2, y: 7.3), control2: CGPoint(x: 17, y: 9.9))
            addCircularArc(&path, from: CGPoint(x: 17, y: 12.3), to: CGPoint(x: 7, y: 12.3), radius: 5, largeArc: false, sweep: true)
            path.addCurve(to: CGPoint(x: 12, y: 3.6), control1: CGPoint(x: 7, y: 9.9), control2: CGPoint(x: 8.8, y: 7.3))
            path.closeSubpath()
        case .plate:
            path.addEllipse(in: CGRect(x: 4.6, y: 4.6, width: 14.8, height: 14.8))
            path.addEllipse(in: CGRect(x: 9.2, y: 9.2, width: 5.6, height: 5.6))
        case .glass:
            path.move(to: CGPoint(x: 7, y: 4.5)); path.addLine(to: CGPoint(x: 17, y: 4.5))
            path.addLine(to: CGPoint(x: 15.6, y: 11.6))
            addCircularArc(&path, from: CGPoint(x: 15.6, y: 11.6), to: CGPoint(x: 12, y: 14), radius: 3.9, largeArc: false, sweep: true)
            addCircularArc(&path, from: CGPoint(x: 12, y: 14), to: CGPoint(x: 8.4, y: 11.6), radius: 3.9, largeArc: false, sweep: true)
            path.addLine(to: CGPoint(x: 7, y: 4.5)); path.closeSubpath()
            path.move(to: CGPoint(x: 12, y: 14)); path.addLine(to: CGPoint(x: 12, y: 19.5))
            path.move(to: CGPoint(x: 9, y: 19.5)); path.addLine(to: CGPoint(x: 15, y: 19.5))
        case .heart:
            path.move(to: CGPoint(x: 12, y: 20))
            path.addCurve(to: CGPoint(x: 5, y: 10.6), control1: CGPoint(x: 12, y: 20), control2: CGPoint(x: 5, y: 15.4))
            addCircularArc(&path, from: CGPoint(x: 5, y: 10.6), to: CGPoint(x: 12, y: 8), radius: 3.8, largeArc: false, sweep: true)
            addCircularArc(&path, from: CGPoint(x: 12, y: 8), to: CGPoint(x: 19, y: 10.6), radius: 3.8, largeArc: false, sweep: true)
            path.addCurve(to: CGPoint(x: 12, y: 20), control1: CGPoint(x: 19, y: 15.4), control2: CGPoint(x: 12, y: 20))
            path.closeSubpath()
        case .bed:
            path.move(to: CGPoint(x: 3, y: 19)); path.addLine(to: CGPoint(x: 3, y: 13))
            path.addLine(to: CGPoint(x: 16, y: 13))
            path.addCurve(to: CGPoint(x: 20, y: 17), control1: CGPoint(x: 18.7, y: 13), control2: CGPoint(x: 20, y: 14.3))
            path.addLine(to: CGPoint(x: 20, y: 19))
            path.move(to: CGPoint(x: 3, y: 13)); path.addLine(to: CGPoint(x: 3, y: 7))
            path.addEllipse(in: CGRect(x: 5.5, y: 7.5, width: 4, height: 4))
            path.move(to: CGPoint(x: 3, y: 19)); path.addLine(to: CGPoint(x: 20, y: 19))
        case .lungs:
            path.move(to: CGPoint(x: 12, y: 4)); path.addLine(to: CGPoint(x: 12, y: 12))
            path.move(to: CGPoint(x: 8.6, y: 20))
            path.addCurve(to: CGPoint(x: 5, y: 16.6), control1: CGPoint(x: 6.6, y: 20), control2: CGPoint(x: 5, y: 18.6))
            path.addCurve(to: CGPoint(x: 7.5, y: 9.9), control1: CGPoint(x: 5, y: 13.9), control2: CGPoint(x: 5.9, y: 11.5))
            path.addCurve(to: CGPoint(x: 9.6, y: 10.8), control1: CGPoint(x: 8.3, y: 9), control2: CGPoint(x: 9.6, y: 9.6))
            path.addLine(to: CGPoint(x: 9.6, y: 17.7))
            path.addCurve(to: CGPoint(x: 8.6, y: 20), control1: CGPoint(x: 9.6, y: 19), control2: CGPoint(x: 9.1, y: 20))
            path.closeSubpath()
            path.move(to: CGPoint(x: 15.4, y: 20))
            path.addCurve(to: CGPoint(x: 19, y: 16.6), control1: CGPoint(x: 17.4, y: 20), control2: CGPoint(x: 19, y: 18.6))
            path.addCurve(to: CGPoint(x: 16.5, y: 9.9), control1: CGPoint(x: 19, y: 13.9), control2: CGPoint(x: 18.1, y: 11.5))
            path.addCurve(to: CGPoint(x: 14.4, y: 10.8), control1: CGPoint(x: 15.7, y: 9), control2: CGPoint(x: 14.4, y: 9.6))
            path.addLine(to: CGPoint(x: 14.4, y: 17.7))
            path.addCurve(to: CGPoint(x: 15.4, y: 20), control1: CGPoint(x: 14.4, y: 19), control2: CGPoint(x: 14.9, y: 20))
            path.closeSubpath()
        case .bolt:
            path.move(to: CGPoint(x: 13.2, y: 3)); path.addLine(to: CGPoint(x: 6, y: 13.6))
            path.addLine(to: CGPoint(x: 10.6, y: 13.6)); path.addLine(to: CGPoint(x: 9.8, y: 21))
            path.addLine(to: CGPoint(x: 17.4, y: 10.2)); path.addLine(to: CGPoint(x: 12.7, y: 10.2))
            path.closeSubpath()
        case .clock:
            path.move(to: CGPoint(x: 12, y: 7.6)); path.addLine(to: CGPoint(x: 12, y: 12.5)); path.addLine(to: CGPoint(x: 15, y: 14.5))
            path.addEllipse(in: CGRect(x: 4.4, y: 4.4, width: 15.2, height: 15.2))
        case .check:
            path.move(to: CGPoint(x: 5, y: 12.8)); path.addLine(to: CGPoint(x: 9.6, y: 17.4)); path.addLine(to: CGPoint(x: 19, y: 7.6))
        case .bike:
            path.addEllipse(in: CGRect(x: 3.5, y: 12.5, width: 6, height: 6))
            path.addEllipse(in: CGRect(x: 14.5, y: 12.5, width: 6, height: 6))
            path.move(to: CGPoint(x: 6.8, y: 15.5)); path.addLine(to: CGPoint(x: 11.6, y: 15.5)); path.addLine(to: CGPoint(x: 14.6, y: 8.3))
            path.move(to: CGPoint(x: 12.4, y: 8.3)); path.addLine(to: CGPoint(x: 16.5, y: 8.3)); path.addLine(to: CGPoint(x: 17.9, y: 15.5))
            path.move(to: CGPoint(x: 9.4, y: 8.3)); path.addLine(to: CGPoint(x: 13.4, y: 8.3))
        case .walk:
            path.addEllipse(in: CGRect(x: 11.8, y: 4.2, width: 2.8, height: 2.8))
            path.move(to: CGPoint(x: 12.4, y: 8.6)); path.addLine(to: CGPoint(x: 10, y: 13.2)); path.addLine(to: CGPoint(x: 12.7, y: 14.8)); path.addLine(to: CGPoint(x: 13.3, y: 20))
            path.move(to: CGPoint(x: 10, y: 13.2)); path.addLine(to: CGPoint(x: 8, y: 20))
            path.move(to: CGPoint(x: 14.4, y: 10.2)); path.addLine(to: CGPoint(x: 17.2, y: 12))
        case .weight:
            path.move(to: CGPoint(x: 4, y: 9)); path.addLine(to: CGPoint(x: 4, y: 15))
            path.move(to: CGPoint(x: 7, y: 6.5)); path.addLine(to: CGPoint(x: 7, y: 17.5))
            path.move(to: CGPoint(x: 17, y: 6.5)); path.addLine(to: CGPoint(x: 17, y: 17.5))
            path.move(to: CGPoint(x: 20, y: 9)); path.addLine(to: CGPoint(x: 20, y: 15))
            path.move(to: CGPoint(x: 7, y: 12)); path.addLine(to: CGPoint(x: 17, y: 12))
        case .wave:
            path.move(to: CGPoint(x: 3, y: 10))
            path.addCurve(to: CGPoint(x: 9, y: 10), control1: CGPoint(x: 5, y: 8), control2: CGPoint(x: 7, y: 12))
            path.addCurve(to: CGPoint(x: 15, y: 10), control1: CGPoint(x: 11, y: 8), control2: CGPoint(x: 13, y: 12))
            path.addCurve(to: CGPoint(x: 21, y: 10), control1: CGPoint(x: 17, y: 8), control2: CGPoint(x: 19, y: 12))
            path.move(to: CGPoint(x: 3, y: 16))
            path.addCurve(to: CGPoint(x: 9, y: 16), control1: CGPoint(x: 5, y: 14), control2: CGPoint(x: 7, y: 18))
            path.addCurve(to: CGPoint(x: 15, y: 16), control1: CGPoint(x: 11, y: 14), control2: CGPoint(x: 13, y: 18))
            path.addCurve(to: CGPoint(x: 21, y: 16), control1: CGPoint(x: 17, y: 14), control2: CGPoint(x: 19, y: 18))
        case .timer:
            path.move(to: CGPoint(x: 12, y: 7.6)); path.addLine(to: CGPoint(x: 12, y: 12.5)); path.addLine(to: CGPoint(x: 15, y: 14.5))
            path.addEllipse(in: CGRect(x: 4.4, y: 4.4, width: 15.2, height: 15.2))
            path.move(to: CGPoint(x: 9.6, y: 2.6)); path.addLine(to: CGPoint(x: 14.4, y: 2.6))
        case .pause:
            path.move(to: CGPoint(x: 9.5, y: 6)); path.addLine(to: CGPoint(x: 9.5, y: 18))
            path.move(to: CGPoint(x: 14.5, y: 6)); path.addLine(to: CGPoint(x: 14.5, y: 18))
        case .play:
            path.move(to: CGPoint(x: 8.5, y: 5.5)); path.addLine(to: CGPoint(x: 18, y: 12)); path.addLine(to: CGPoint(x: 8.5, y: 18.5)); path.closeSubpath()
        case .stop:
            path.addRect(CGRect(x: 7.5, y: 7.5, width: 9, height: 9))
        case .read:
            path.move(to: CGPoint(x: 5, y: 4.5)); path.addLine(to: CGPoint(x: 11, y: 4.5))
            path.addCurve(to: CGPoint(x: 13, y: 6.5), control1: CGPoint(x: 12.1, y: 4.5), control2: CGPoint(x: 13, y: 5.4))
            path.addLine(to: CGPoint(x: 13, y: 20))
            path.addCurve(to: CGPoint(x: 11.4, y: 18.4), control1: CGPoint(x: 13, y: 19.1), control2: CGPoint(x: 12.3, y: 18.4))
            path.addLine(to: CGPoint(x: 5, y: 18.4)); path.closeSubpath()
            path.move(to: CGPoint(x: 19, y: 4.5)); path.addLine(to: CGPoint(x: 14.6, y: 4.5))
            path.addCurve(to: CGPoint(x: 12.6, y: 6.5), control1: CGPoint(x: 13.5, y: 4.5), control2: CGPoint(x: 12.6, y: 5.4))
            path.addLine(to: CGPoint(x: 12.6, y: 20))
            path.addCurve(to: CGPoint(x: 14.2, y: 18.4), control1: CGPoint(x: 12.6, y: 19.1), control2: CGPoint(x: 13.3, y: 18.4))
            path.addLine(to: CGPoint(x: 19, y: 18.4)); path.closeSubpath()
        case .scale:
            path.move(to: CGPoint(x: 12, y: 4.5)); path.addLine(to: CGPoint(x: 12, y: 19.5))
            path.move(to: CGPoint(x: 4.5, y: 19.5)); path.addLine(to: CGPoint(x: 19.5, y: 19.5))
            path.move(to: CGPoint(x: 7, y: 8.5)); path.addLine(to: CGPoint(x: 4, y: 14)); path.addLine(to: CGPoint(x: 10, y: 14)); path.closeSubpath()
            path.move(to: CGPoint(x: 17, y: 8.5)); path.addLine(to: CGPoint(x: 14, y: 14)); path.addLine(to: CGPoint(x: 20, y: 14)); path.closeSubpath()
            path.move(to: CGPoint(x: 7, y: 8.5)); path.addLine(to: CGPoint(x: 12, y: 7)); path.addLine(to: CGPoint(x: 17, y: 8.5))
        case .alarm:
            path.move(to: CGPoint(x: 12, y: 8.6)); path.addLine(to: CGPoint(x: 12, y: 13)); path.addLine(to: CGPoint(x: 15, y: 14.7))
            path.addEllipse(in: CGRect(x: 4, y: 5.2, width: 16, height: 16))
            path.move(to: CGPoint(x: 5.4, y: 3.4)); path.addLine(to: CGPoint(x: 3.2, y: 5.2))
            path.move(to: CGPoint(x: 18.6, y: 3.4)); path.addLine(to: CGPoint(x: 20.8, y: 5.2))
        case .bell:
            path.move(to: CGPoint(x: 18, y: 15.2)); path.addLine(to: CGPoint(x: 18, y: 11))
            path.addCurve(to: CGPoint(x: 6, y: 11), control1: CGPoint(x: 18, y: 3), control2: CGPoint(x: 6, y: 3))
            path.addLine(to: CGPoint(x: 6, y: 15.2)); path.addLine(to: CGPoint(x: 4.4, y: 17.6)); path.addLine(to: CGPoint(x: 19.6, y: 17.6)); path.closeSubpath()
            path.move(to: CGPoint(x: 10, y: 20.4)); path.addCurve(to: CGPoint(x: 14, y: 20.4), control1: CGPoint(x: 10.7, y: 22.4), control2: CGPoint(x: 13.3, y: 22.4))
        case .screen:
            path.addRect(CGRect(x: 4, y: 5.5, width: 16, height: 9.5))
            path.move(to: CGPoint(x: 9.5, y: 19.5)); path.addLine(to: CGPoint(x: 14.5, y: 19.5))
            path.move(to: CGPoint(x: 12, y: 15)); path.addLine(to: CGPoint(x: 12, y: 19.5))
        case .shield:
            path.move(to: CGPoint(x: 12, y: 3.5)); path.addLine(to: CGPoint(x: 5.5, y: 6))
            path.addLine(to: CGPoint(x: 5.5, y: 12))
            path.addCurve(to: CGPoint(x: 12, y: 20.5), control1: CGPoint(x: 5.5, y: 16), control2: CGPoint(x: 8.3, y: 18.9))
            path.addCurve(to: CGPoint(x: 18.5, y: 12), control1: CGPoint(x: 15.7, y: 18.9), control2: CGPoint(x: 18.5, y: 16))
            path.addLine(to: CGPoint(x: 18.5, y: 6)); path.closeSubpath()
        case .download:
            path.move(to: CGPoint(x: 12, y: 4.6)); path.addLine(to: CGPoint(x: 12, y: 14.4))
            path.move(to: CGPoint(x: 8.2, y: 11)); path.addLine(to: CGPoint(x: 12, y: 14.8)); path.addLine(to: CGPoint(x: 15.8, y: 11))
            path.move(to: CGPoint(x: 5, y: 19.4)); path.addLine(to: CGPoint(x: 19, y: 19.4))
        case .upload:
            path.move(to: CGPoint(x: 12, y: 19.4)); path.addLine(to: CGPoint(x: 12, y: 9.6))
            path.move(to: CGPoint(x: 8.2, y: 13)); path.addLine(to: CGPoint(x: 12, y: 9.2)); path.addLine(to: CGPoint(x: 15.8, y: 13))
            path.move(to: CGPoint(x: 5, y: 4.6)); path.addLine(to: CGPoint(x: 19, y: 4.6))
        case .trash:
            path.move(to: CGPoint(x: 5.5, y: 7.5)); path.addLine(to: CGPoint(x: 18.5, y: 7.5))
            path.move(to: CGPoint(x: 9.6, y: 7.5)); path.addLine(to: CGPoint(x: 9.6, y: 5.3)); path.addLine(to: CGPoint(x: 14.4, y: 5.3)); path.addLine(to: CGPoint(x: 14.4, y: 7.5))
            path.move(to: CGPoint(x: 7.2, y: 7.5)); path.addLine(to: CGPoint(x: 8.1, y: 19.5)); path.addLine(to: CGPoint(x: 15.9, y: 19.5)); path.addLine(to: CGPoint(x: 16.8, y: 7.5))
            path.move(to: CGPoint(x: 10.6, y: 11)); path.addLine(to: CGPoint(x: 10.6, y: 16))
            path.move(to: CGPoint(x: 13.4, y: 11)); path.addLine(to: CGPoint(x: 13.4, y: 16))
        case .globe:
            path.addEllipse(in: CGRect(x: 4, y: 4, width: 16, height: 16))
            path.move(to: CGPoint(x: 4.4, y: 12)); path.addLine(to: CGPoint(x: 19.6, y: 12))
            path.move(to: CGPoint(x: 12, y: 4))
            path.addCurve(to: CGPoint(x: 15.3, y: 12), control1: CGPoint(x: 14.2, y: 6.3), control2: CGPoint(x: 15.3, y: 9))
            path.addCurve(to: CGPoint(x: 12, y: 20), control1: CGPoint(x: 15.3, y: 15), control2: CGPoint(x: 14.2, y: 17.7))
            path.addCurve(to: CGPoint(x: 8.7, y: 12), control1: CGPoint(x: 9.8, y: 17.7), control2: CGPoint(x: 8.7, y: 15))
            path.addCurve(to: CGPoint(x: 12, y: 4), control1: CGPoint(x: 8.7, y: 9), control2: CGPoint(x: 9.8, y: 6.3))
        case .ruler:
            path.move(to: CGPoint(x: 4, y: 14.6)); path.addLine(to: CGPoint(x: 14.6, y: 4)); path.addLine(to: CGPoint(x: 20, y: 9.4)); path.addLine(to: CGPoint(x: 9.4, y: 20)); path.closeSubpath()
            path.move(to: CGPoint(x: 8, y: 10.6)); path.addLine(to: CGPoint(x: 10, y: 12.6))
            path.move(to: CGPoint(x: 11, y: 7.6)); path.addLine(to: CGPoint(x: 13, y: 9.6))
        case .sparkSingle:
            path.move(to: CGPoint(x: 12, y: 3.5)); path.addLine(to: CGPoint(x: 13.6, y: 9))
            path.addLine(to: CGPoint(x: 19, y: 10.6)); path.addLine(to: CGPoint(x: 13.6, y: 12))
            path.addLine(to: CGPoint(x: 12, y: 17.5)); path.addLine(to: CGPoint(x: 10.4, y: 12))
            path.addLine(to: CGPoint(x: 5, y: 10.6)); path.addLine(to: CGPoint(x: 10.4, y: 9)); path.closeSubpath()
        case .camera:
            path.move(to: CGPoint(x: 4.5, y: 8.4)); path.addLine(to: CGPoint(x: 7.5, y: 8.4)); path.addLine(to: CGPoint(x: 8.9, y: 6.4))
            path.addLine(to: CGPoint(x: 15.1, y: 6.4)); path.addLine(to: CGPoint(x: 16.5, y: 8.4)); path.addLine(to: CGPoint(x: 19.5, y: 8.4))
            path.addLine(to: CGPoint(x: 19.5, y: 18.4)); path.addLine(to: CGPoint(x: 4.5, y: 18.4)); path.closeSubpath()
            path.addEllipse(in: CGRect(x: 8.8, y: 10.4, width: 6.4, height: 6.4))
        case .person:
            path.addEllipse(in: CGRect(x: 8.6, y: 4.2, width: 6.8, height: 6.8))
            path.move(to: CGPoint(x: 5, y: 20))
            path.addCurve(to: CGPoint(x: 12, y: 14.4), control1: CGPoint(x: 5, y: 16.5), control2: CGPoint(x: 8.1, y: 14.4))
            path.addCurve(to: CGPoint(x: 19, y: 20), control1: CGPoint(x: 15.9, y: 14.4), control2: CGPoint(x: 19, y: 16.5))
        case .sync:
            path.move(to: CGPoint(x: 19.4, y: 12))
            addCircularArc(&path, from: CGPoint(x: 19.4, y: 12), to: CGPoint(x: 6.7, y: 17.2), radius: 7.4, largeArc: false, sweep: true)
            path.move(to: CGPoint(x: 4.6, y: 12))
            addCircularArc(&path, from: CGPoint(x: 4.6, y: 12), to: CGPoint(x: 17.3, y: 6.8), radius: 7.4, largeArc: false, sweep: true)
            path.move(to: CGPoint(x: 17.3, y: 4)); path.addLine(to: CGPoint(x: 17.3, y: 7)); path.addLine(to: CGPoint(x: 14.3, y: 7))
            path.move(to: CGPoint(x: 6.7, y: 20)); path.addLine(to: CGPoint(x: 6.7, y: 17)); path.addLine(to: CGPoint(x: 9.7, y: 17))
        case .link:
            path.move(to: CGPoint(x: 10, y: 13.6))
            addCircularArc(&path, from: CGPoint(x: 10, y: 13.6), to: CGPoint(x: 15.1, y: 13.6), radius: 3.6, largeArc: false, sweep: false)
            path.addLine(to: CGPoint(x: 17.7, y: 11))
            addCircularArc(&path, from: CGPoint(x: 17.7, y: 11), to: CGPoint(x: 12.6, y: 5.9), radius: 3.6, largeArc: false, sweep: false)
            path.addLine(to: CGPoint(x: 11.6, y: 6.9))
            path.move(to: CGPoint(x: 14, y: 10.4))
            addCircularArc(&path, from: CGPoint(x: 14, y: 10.4), to: CGPoint(x: 8.9, y: 10.4), radius: 3.6, largeArc: false, sweep: false)
            path.addLine(to: CGPoint(x: 6.3, y: 13))
            addCircularArc(&path, from: CGPoint(x: 6.3, y: 13), to: CGPoint(x: 11.4, y: 18.1), radius: 3.6, largeArc: false, sweep: false)
            path.addLine(to: CGPoint(x: 12.4, y: 17.1))
        case .copy:
            path.move(to: CGPoint(x: 9, y: 9)); path.addLine(to: CGPoint(x: 9, y: 5.5)); path.addLine(to: CGPoint(x: 19, y: 5.5)); path.addLine(to: CGPoint(x: 19, y: 16)); path.addLine(to: CGPoint(x: 15.5, y: 16))
            path.addRect(CGRect(x: 5, y: 8.5, width: 10, height: 10.5))
        case .share:
            path.move(to: CGPoint(x: 12, y: 15.4)); path.addLine(to: CGPoint(x: 12, y: 4.6))
            path.move(to: CGPoint(x: 8.4, y: 8)); path.addLine(to: CGPoint(x: 12, y: 4.6)); path.addLine(to: CGPoint(x: 15.6, y: 8))
            path.move(to: CGPoint(x: 5.4, y: 13.6)); path.addLine(to: CGPoint(x: 5.4, y: 19)); path.addLine(to: CGPoint(x: 18.6, y: 19)); path.addLine(to: CGPoint(x: 18.6, y: 13.6))
        case .x:
            path.addEllipse(in: CGRect(x: 4.4, y: 4.4, width: 15.2, height: 15.2))
            path.move(to: CGPoint(x: 9.2, y: 9.2)); path.addLine(to: CGPoint(x: 14.8, y: 14.8))
            path.move(to: CGPoint(x: 14.8, y: 9.2)); path.addLine(to: CGPoint(x: 9.2, y: 14.8))
        case .flask:
            path.move(to: CGPoint(x: 9.4, y: 4)); path.addLine(to: CGPoint(x: 14.6, y: 4))
            path.move(to: CGPoint(x: 10.2, y: 4)); path.addLine(to: CGPoint(x: 10.2, y: 9.2)); path.addLine(to: CGPoint(x: 5.8, y: 18.2))
            path.addCurve(to: CGPoint(x: 7, y: 20.2), control1: CGPoint(x: 5.4, y: 19), control2: CGPoint(x: 6, y: 20.2))
            path.addLine(to: CGPoint(x: 17, y: 20.2))
            path.addCurve(to: CGPoint(x: 18.2, y: 18.2), control1: CGPoint(x: 18, y: 20.2), control2: CGPoint(x: 18.6, y: 19))
            path.addLine(to: CGPoint(x: 13.8, y: 9.2)); path.addLine(to: CGPoint(x: 13.8, y: 4))
            path.move(to: CGPoint(x: 8.4, y: 14.6)); path.addLine(to: CGPoint(x: 15.6, y: 14.6))
        case .search:
            path.addEllipse(in: CGRect(x: 4.6, y: 4.6, width: 12.8, height: 12.8))
            path.move(to: CGPoint(x: 15.6, y: 15.6)); path.addLine(to: CGPoint(x: 19.6, y: 19.6))
        case .file:
            path.move(to: CGPoint(x: 6.5, y: 4)); path.addLine(to: CGPoint(x: 13.5, y: 4)); path.addLine(to: CGPoint(x: 18, y: 8.5))
            path.addLine(to: CGPoint(x: 18, y: 20)); path.addLine(to: CGPoint(x: 6.5, y: 20)); path.closeSubpath()
            path.move(to: CGPoint(x: 13.2, y: 4)); path.addLine(to: CGPoint(x: 13.2, y: 9)); path.addLine(to: CGPoint(x: 17.8, y: 9))
        case .plus:
            path.move(to: CGPoint(x: 12, y: 5.4)); path.addLine(to: CGPoint(x: 12, y: 18.6))
            path.move(to: CGPoint(x: 5.4, y: 12)); path.addLine(to: CGPoint(x: 18.6, y: 12))
        case .grid:
            path.addRect(CGRect(x: 4.6, y: 4.6, width: 6, height: 6))
            path.addRect(CGRect(x: 13.4, y: 4.6, width: 6, height: 6))
            path.addRect(CGRect(x: 4.6, y: 13.4, width: 6, height: 6))
            path.addRect(CGRect(x: 13.4, y: 13.4, width: 6, height: 6))
        case .key:
            path.move(to: CGPoint(x: 15.4, y: 4.6))
            addCircularArc(&path, from: CGPoint(x: 15.4, y: 4.6), to: CGPoint(x: 12.2, y: 12.5), radius: 4.6, largeArc: true, sweep: false)
            path.addLine(to: CGPoint(x: 11, y: 13.7)); path.addLine(to: CGPoint(x: 9.4, y: 13.5)); path.addLine(to: CGPoint(x: 9.1, y: 15.2))
            path.addLine(to: CGPoint(x: 7.4, y: 15.4)); path.addLine(to: CGPoint(x: 7.6, y: 17.1)); path.addLine(to: CGPoint(x: 5.8, y: 17.4))
            path.addLine(to: CGPoint(x: 4.5, y: 18.7)); path.addLine(to: CGPoint(x: 4.5, y: 20.1)); path.addLine(to: CGPoint(x: 6.9, y: 20.1)); path.addLine(to: CGPoint(x: 14, y: 13))
            addCircularArc(&path, from: CGPoint(x: 14, y: 13), to: CGPoint(x: 15.4, y: 4.6), radius: 4.6, largeArc: true, sweep: false)
            path.move(to: CGPoint(x: 16.6, y: 8.2)); path.addLine(to: CGPoint(x: 16.61, y: 8.2))
        case .chart:
            path.move(to: CGPoint(x: 4.6, y: 4.6)); path.addLine(to: CGPoint(x: 4.6, y: 19.4)); path.addLine(to: CGPoint(x: 19.4, y: 19.4))
            path.move(to: CGPoint(x: 8, y: 16.4)); path.addLine(to: CGPoint(x: 8, y: 11))
            path.move(to: CGPoint(x: 12, y: 16.4)); path.addLine(to: CGPoint(x: 12, y: 7.6))
            path.move(to: CGPoint(x: 16, y: 16.4)); path.addLine(to: CGPoint(x: 16, y: 13))
        case .gauge:
            path.move(to: CGPoint(x: 4.6, y: 17.4))
            addCircularArc(&path, from: CGPoint(x: 4.6, y: 17.4), to: CGPoint(x: 19.4, y: 17.4), radius: 8, largeArc: true, sweep: true)
            path.move(to: CGPoint(x: 12, y: 12.4)); path.addLine(to: CGPoint(x: 15.4, y: 9))
        case .mic:
            path.addRoundedRect(
                in: CGRect(x: 9.2, y: 4, width: 5.6, height: 10),
                cornerSize: CGSize(width: 2.8, height: 2.8)
            )
            path.move(to: CGPoint(x: 5.8, y: 11.6))
            addCircularArc(&path, from: CGPoint(x: 5.8, y: 11.6), to: CGPoint(x: 18.2, y: 11.6), radius: 6.2, largeArc: false, sweep: true)
            path.move(to: CGPoint(x: 12, y: 17.8)); path.addLine(to: CGPoint(x: 12, y: 20.2))
            path.move(to: CGPoint(x: 9.2, y: 20.2)); path.addLine(to: CGPoint(x: 14.8, y: 20.2))
        case .ask:
            path.addEllipse(in: CGRect(x: 4.4, y: 4.4, width: 12.4, height: 12.4))
            path.move(to: CGPoint(x: 15.2, y: 15.2)); path.addLine(to: CGPoint(x: 20, y: 20))
        case .overlay:
            path.move(to: CGPoint(x: 3, y: 16.4))
            path.addCurve(to: CGPoint(x: 11.6, y: 7.4), control1: CGPoint(x: 6.4, y: 16.4), control2: CGPoint(x: 7.6, y: 7.4))
            path.addCurve(to: CGPoint(x: 20, y: 13.8), control1: CGPoint(x: 15.6, y: 7.4), control2: CGPoint(x: 16.4, y: 13.8))
            path.move(to: CGPoint(x: 3, y: 8.6))
            path.addCurve(to: CGPoint(x: 11.6, y: 17.6), control1: CGPoint(x: 6.4, y: 8.6), control2: CGPoint(x: 7.6, y: 17.6))
        case .chat:
            path.move(to: CGPoint(x: 12, y: 4.4))
            path.addCurve(to: CGPoint(x: 4.4, y: 10.4), control1: CGPoint(x: 7.7, y: 4.4), control2: CGPoint(x: 4.4, y: 7))
            path.addCurve(to: CGPoint(x: 7.4, y: 15.3), control1: CGPoint(x: 4.4, y: 12.4), control2: CGPoint(x: 5.6, y: 14.2))
            path.addLine(to: CGPoint(x: 6.6, y: 19)); path.addLine(to: CGPoint(x: 10.3, y: 17))
            path.addCurve(to: CGPoint(x: 12, y: 17.2), control1: CGPoint(x: 10.9, y: 17.1), control2: CGPoint(x: 11.5, y: 17.2))
            path.addCurve(to: CGPoint(x: 19.6, y: 11.3), control1: CGPoint(x: 16.3, y: 17.2), control2: CGPoint(x: 19.6, y: 14.6))
            path.addCurve(to: CGPoint(x: 12, y: 4.4), control1: CGPoint(x: 19.6, y: 7.9), control2: CGPoint(x: 16.3, y: 4.4))
        }
        return path
    }

    /// SVG circular-arc endpoint conversion. All canonical icon arcs are unrotated circles, so
    /// this preserves the source masks exactly while SwiftUI receives cubic path segments.
    private func addCircularArc(
        _ path: inout Path,
        from start: CGPoint,
        to end: CGPoint,
        radius requestedRadius: CGFloat,
        largeArc: Bool,
        sweep: Bool
    ) {
        let halfDX = (start.x - end.x) / 2
        let halfDY = (start.y - end.y) / 2
        let chordFactor = sqrt(halfDX * halfDX + halfDY * halfDY) / requestedRadius
        let radius = requestedRadius * max(1, chordFactor)
        let numerator = max(0, radius * radius - halfDX * halfDX - halfDY * halfDY)
        let denominator = max(.leastNonzeroMagnitude, halfDX * halfDX + halfDY * halfDY)
        let sign: CGFloat = largeArc == sweep ? -1 : 1
        let coefficient = sign * sqrt(numerator / denominator)
        let center = CGPoint(
            x: (start.x + end.x) / 2 + coefficient * halfDY,
            y: (start.y + end.y) / 2 - coefficient * halfDX
        )

        let startAngle = atan2((start.y - center.y) / radius, (start.x - center.x) / radius)
        var delta = atan2(
            (start.x - center.x) * (end.y - center.y) - (start.y - center.y) * (end.x - center.x),
            (start.x - center.x) * (end.x - center.x) + (start.y - center.y) * (end.y - center.y)
        )
        if sweep, delta < 0 { delta += 2 * .pi }
        if !sweep, delta > 0 { delta -= 2 * .pi }

        let segmentCount = max(1, Int(ceil(abs(delta) / (.pi / 2))))
        let segmentDelta = delta / CGFloat(segmentCount)
        for index in 0..<segmentCount {
            let angle0 = startAngle + CGFloat(index) * segmentDelta
            let angle1 = angle0 + segmentDelta
            let alpha = 4 / 3 * tan(segmentDelta / 4)
            let point0 = CGPoint(x: center.x + radius * cos(angle0), y: center.y + radius * sin(angle0))
            let point1 = CGPoint(x: center.x + radius * cos(angle1), y: center.y + radius * sin(angle1))
            let control0 = CGPoint(x: point0.x - alpha * radius * sin(angle0), y: point0.y + alpha * radius * cos(angle0))
            let control1 = CGPoint(x: point1.x + alpha * radius * sin(angle1), y: point1.y - alpha * radius * cos(angle1))
            path.addCurve(to: point1, control1: control0, control2: control1)
        }
    }
}

struct NoopBottomNavigation: View {
    @ObservedObject var navigation: NoopNavigation

    var body: some View {
        GeometryReader { proxy in
            let tabBudget = max(0, proxy.size.width - 12 - 48 - 12)
            let unit = tabBudget / 4.7

            HStack(spacing: 3) {
                tab(.today, unit: unit)
                tab(.trends, unit: unit)

                Button { navigation.plus() } label: {
                    Group {
                        if navigation.route.act == .picture || navigation.route.act == .instrument {
                            NoopCanonicalGlyph(name: .spark, size: 21, color: NoopHTMLColor.blueInk)
                        } else {
                            Text("+")
                                .font(NoopHTMLFont.outfit(23, weight: .light))
                                .offset(y: -1)
                        }
                    }
                    .foregroundStyle(NoopHTMLColor.blueInk)
                    .frame(width: 44, height: 44)
                    .background(NoopHTMLColor.blue, in: Circle())
                    .shadow(color: NoopHTMLColor.blue.opacity(0.4), radius: 7, y: 4)
                }
                .buttonStyle(NoopHTMLPressStyle())
                .padding(.horizontal, 2)
                .accessibilityLabel(navigation.route.act == .picture || navigation.route.act == .instrument ? "Everything you logged" : "Add")

                tab(.rest, unit: unit)
                tab(.you, unit: unit)
            }
            .padding(6)
        }
        .frame(height: 58)
        .frame(maxWidth: .infinity)
        .background(Color(hex: 0x171C1A, alpha: 0.82), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(NoopHTMLColor.borderStrong, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.5), radius: 13, y: 8)
    }

    private func tab(_ tab: NoopTab, unit: CGFloat) -> some View {
        let sveaSlot = navigation.route.act == .svea && tab == .today
        let selected = navigation.route.tab == tab
        let tint: Color = {
            guard selected else { return NoopHTMLColor.copy }
            switch navigation.route.act {
            case .night: return NoopHTMLColor.night
            case .picture: return NoopHTMLColor.green
            case .plumbing: return NoopHTMLColor.blush
            case .ages: return NoopHTMLColor.green
            case .svea: return NoopHTMLColor.night
            // Act 3 keeps the Today key in the shared Aura blue. Amber belongs to the effort
            // content itself; the prototype never moves the global navigation key into that hue.
            case .effort: return NoopHTMLColor.blue
            case .goals: return NoopHTMLColor.warm
            case .instrument: return NoopHTMLColor.night
            default: return NoopHTMLColor.blue
            }
        }()

        return Button {
            if sveaSlot { navigation.reset(to: .coach) }
            else { navigation.select(tab: tab) }
        } label: {
            HStack(spacing: 7) {
                NoopCanonicalGlyph(
                    name: sveaSlot ? .spark : glyph(for: tab),
                    size: sveaSlot ? 18 : 19,
                    color: selected ? selectedInk : Color(hex: 0x7F8A85)
                )
                if selected {
                    Text(sveaSlot ? "Svea" : tab.rawValue)
                        .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                }
            }
            .foregroundStyle(selected ? selectedInk : Color(hex: 0x7F8A85))
            .frame(width: unit * (selected ? 1.7 : 1), height: 46)
            .background(selected ? tint : .clear, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .animation(NoopMotion.arrive, value: navigation.route.act)
        }
        .buttonStyle(NoopHTMLPressStyle())
        .accessibilityLabel(sveaSlot ? "Svea" : tab.rawValue)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func glyph(for tab: NoopTab) -> NoopCanonicalGlyphName {
        switch tab {
        case .today: .today
        case .trends: .trends
        case .rest: .moon
        case .you: .you
        }
    }

    private var selectedInk: Color {
        switch navigation.route.act {
        case .night: Color(hex: 0x0D1120)
        case .picture: Color(hex: 0x04140C)
        case .plumbing: NoopHTMLColor.blushInk
        case .ages: Color(hex: 0x04140C)
        case .effort: NoopHTMLColor.blueInk
        case .goals: NoopHTMLColor.warmInk
        case .instrument: Color(hex: 0x0B0E1A)
        default: NoopHTMLColor.blueInk
        }
    }
}

// MARK: - Canonical bottom sheets

private struct NoopOverlayHost: View {
    let overlay: NoopOverlay
    @ObservedObject var navigation: NoopNavigation

    @ViewBuilder
    var body: some View {
        switch overlay {
        case .nightJournal:
            NoopNightJournalSheet(navigation: navigation)
        case .importCatalog:
            NoopImportCatalogSheet(navigation: navigation)
        case .dayLog:
            NoopDayLogSheet(navigation: navigation)
        case .loggedItems:
            NoopLoggedItemsSheet(navigation: navigation)
        case .addRecord:
            NoopAddRecordSheet(navigation: navigation)
        case .goalEditor:
            NoopGoalEditorSheet(navigation: navigation)
        case .deepInsightsConfirmation:
            NoopDeepInsightsConfirmation(navigation: navigation)
        case .destructiveConfirmation(let item):
            NoopDestructiveConfirmation(item: item, navigation: navigation)
        case .instrumentSignalPickerA:
            NoopInstrumentSignalPickerSheet(navigation: navigation, slot: .first)
        case .instrumentSignalPickerB:
            NoopInstrumentSignalPickerSheet(navigation: navigation, slot: .second)
        }
    }
}

private struct NoopAddRecordSheet: View {
    @ObservedObject var navigation: NoopNavigation

    var body: some View {
        GeometryReader { proxy in
            let viewportWidth = min(proxy.size.width, UIScreen.main.bounds.width)
            ZStack(alignment: .bottom) {
                NoopBackdropBlur(style: .regular, intensity: 0.18)
                Color(hex: 0x040605, alpha: 0.66)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: navigation.dismissOverlay)

                VStack(alignment: .leading, spacing: 12) {
                    Capsule()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 38, height: 4)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Add to your record")
                            .font(NoopHTMLFont.outfit(21, weight: .regular))
                            .tracking(-0.525)
                            .foregroundStyle(NoopHTMLColor.ink)
                        Text("The four things Noop cannot work out by watching you.")
                            .font(.custom("Instrument Sans", fixedSize: 12))
                            .foregroundStyle(Color(hex: 0x7F8A85))
                            .modifier(NoopSheetLineBox(fontSize: 12, ratio: 1.55))
                    }
                    .padding(.horizontal, 2)
                    .padding(.top, 6)
                    .padding(.bottom, 2)

                    VStack(spacing: 7) {
                        choice("Body measurements", "height, weight, and the optional waist", .ruler, "RECORD", .record)
                        choice("Profile photo", "stays on this phone, never uploaded", .camera, "NOT SET", .record)
                        choice("Date of birth and sex", "the two facts the models need", .person, "RECORD", .record)
                        // 47-act8-goals.md §8.3: this row enters `goal/picker`, not `review`.
                        // Entering `review` handed the user a set of read values for a photograph
                        // they had never taken. The sub-line is the HTML's — it no longer promises
                        // a read, because the by-hand route does not involve one.
                        choice("A lab result to import", "photograph the sheet, or type the numbers in by hand", .file, "LABS", .picker)
                    }

                    Button(action: navigation.dismissOverlay) {
                        Text("Not now")
                            .font(.custom("Instrument Sans", fixedSize: 13.5))
                            .foregroundStyle(Color(hex: 0x7F8A85))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: max(0, viewportWidth - 36), alignment: .leading)
                .padding(.top, 12)
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
                .background(NoopHTMLColor.card, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
                .overlay(alignment: .top) {
                    UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                        .stroke(NoopHTMLColor.borderStrong, lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.6), radius: 22, y: -14)
            }
            .frame(width: viewportWidth, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func choice(
        _ title: String,
        _ detail: String,
        _ symbol: NoopCanonicalGlyphName,
        _ chip: String,
        _ route: NoopRoute
    ) -> some View {
        Button {
            navigation.dismissSheetThenPush(route)
        } label: {
            HStack(spacing: 13) {
                NoopCanonicalGlyph(name: symbol, size: 21, color: NoopHTMLColor.blush)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom("Instrument Sans", fixedSize: 14).weight(.semibold))
                        .foregroundStyle(NoopHTMLColor.ink)
                        .modifier(NoopSheetLineBox(fontSize: 14, ratio: 18 / 14))
                    Text(detail)
                        .font(.custom("Instrument Sans", fixedSize: 11.5))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                        .multilineTextAlignment(.leading)
                        .modifier(NoopSheetLineBox(fontSize: 11.5, ratio: 1.45))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(chip)
                    .font(.custom("Instrument Sans", fixedSize: 10).weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(Color(hex: 0x8B958F))
                    .fixedSize()
            }
            // Include the reference border's layout space around its 15 × 16 px padding.
            .padding(.horizontal, 17)
            .padding(.vertical, 15)
            .frame(minHeight: 18 + 2 + 11.5 * 1.45 * (route == .review ? 2 : 1) + 32)
            .background(NoopHTMLColor.blush.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(NoopHTMLColor.blush.opacity(0.2), lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
        .frame(maxWidth: .infinity)
    }
}

private struct NoopSheetLineBox: ViewModifier {
    let fontSize: CGFloat
    let ratio: CGFloat

    func body(content: Content) -> some View {
        let nativeHeight = UIFont(name: "Instrument Sans", size: fontSize)?.lineHeight ?? fontSize * 1.22
        let leading = max(0, fontSize * ratio - nativeHeight)
        content
            .lineSpacing(leading)
            .padding(.vertical, leading / 2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct NoopNightJournalSheet: View {
    @ObservedObject var navigation: NoopNavigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var presented = false
    @State private var mood = 3
    @State private var drinks = 0
    @State private var notes: Set<String> = ["Screens in bed"]
    private let moods = ["Rough", "Off", "Fine", "Good", "Great"]
    static let noteItems = ["Coffee after 2pm", "Big meal late", "Screens in bed", "Hard day"]
    private var noteItems: [String] { Self.noteItems }

    init(navigation: NoopNavigation) {
        self.navigation = navigation
        _mood = State(initialValue: navigation.nightJournalMood)
        _drinks = State(initialValue: navigation.nightJournalDrinks)
        _notes = State(initialValue: navigation.nightJournalNotes)
    }

    var body: some View {
        GeometryReader { proxy in
            let viewportWidth = min(proxy.size.width, UIScreen.main.bounds.width)
            ZStack(alignment: .bottom) {
                NoopBackdropBlur(style: .regular, intensity: 0.18)
                Color(hex: 0x040606, alpha: 0.62)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: navigation.dismissOverlay)

                VStack(alignment: .leading, spacing: 18) {
                    Capsule()
                        .fill(Color.white.opacity(0.20))
                        .frame(width: 38, height: 4)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Log the day")
                            .font(NoopHTMLFont.outfit(23, weight: .regular))
                            .tracking(-0.46)
                            .foregroundStyle(NoopHTMLColor.ink)
                        Text("Ten seconds. Skip anything.")
                            .font(.custom("Instrument Sans", fixedSize: 12.5))
                            .foregroundStyle(Color(hex: 0x7F8A85))
                    }

                    Button { navigation.dismissSheetThenArrive(at: .session) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Start a session")
                                    .font(NoopHTMLFont.sans(14, weight: .semibold))
                                    .foregroundStyle(NoopHTMLColor.ink)
                                if NoopContentPolicy.allowsPrototypeContent {
                                    Text("Today’s recommendation, from wherever you are")
                                        .font(.custom("Instrument Sans", fixedSize: 11.5))
                                        .foregroundStyle(Color(hex: 0x7F8A85))
                                }
                            }
                            Spacer(minLength: 4)
                            NoopA4CSSChevron(direction: .right, color: NoopHTMLColor.chevronDim)
                        }
                        .padding(.horizontal, 2)
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 0.5)
                        }
                    }
                    .buttonStyle(NoopHTMLPressStyle())

                    VStack(alignment: .leading, spacing: 10) {
                        Text("HOW WAS IT")
                            .font(NoopHTMLFont.sans(11, weight: .semibold))
                            .tracking(1.1)
                            .foregroundStyle(NoopHTMLColor.muted)
                        HStack(spacing: 7) {
                            ForEach(moods.indices, id: \.self) { index in
                                Button { mood = index } label: {
                                    VStack(spacing: 8) {
                                        Circle()
                                            .fill(index == mood ? NoopHTMLColor.blue : Color.white.opacity(0.16))
                                            .frame(width: 14 + CGFloat(index) * 2.5, height: 14 + CGFloat(index) * 2.5)
                                        Text(moods[index])
                                            .font(.custom("Instrument Sans", fixedSize: 10.5).weight(index == mood ? .semibold : .medium))
                                            .foregroundStyle(index == mood ? NoopHTMLColor.ink : Color(hex: 0x7F8A85))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 74)
                                    .background(index == mood ? NoopHTMLColor.blue.opacity(0.14) : Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(index == mood ? NoopHTMLColor.blue.opacity(0.5) : NoopHTMLColor.border, lineWidth: 0.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 9) {
                            NoopCanonicalGlyph(name: .glass, size: 15, color: NoopHTMLColor.muted)
                            Text("DRINKS")
                                .font(NoopHTMLFont.sans(11, weight: .semibold))
                                .tracking(1.1)
                                .foregroundStyle(NoopHTMLColor.muted)
                        }
                        HStack(spacing: 7) {
                            ForEach(Array(["None", "1", "2", "3+"].enumerated()), id: \.offset) { index, label in
                                Button { drinks = index } label: {
                                    Text(label)
                                        .font(.custom("Instrument Sans", fixedSize: 13.5).weight(index == drinks ? .semibold : .medium))
                                        .foregroundStyle(index == drinks ? NoopHTMLColor.blueInk : NoopHTMLColor.copy)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 48)
                                        .background(index == drinks ? (index == 0 ? NoopHTMLColor.blue : Color(hex: 0xF2B45C)) : Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 15))
                                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(index == drinks ? .clear : NoopHTMLColor.border, lineWidth: 0.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    NoopFlowLayout(spacing: 7) {
                        ForEach(noteItems, id: \.self) { item in
                            let selected = notes.contains(item)
                            Button {
                                if selected { notes.remove(item) } else { notes.insert(item) }
                            } label: {
                                HStack(spacing: 9) {
                                    NoopCanonicalGlyph(name: journalGlyph(item), size: 17, color: selected ? Color(hex: 0xF2B45C) : Color(hex: 0x7F8A85))
                                    Text(item)
                                        .font(NoopHTMLFont.sans(13, weight: .medium))
                                        .foregroundStyle(selected ? NoopHTMLColor.ink : NoopHTMLColor.copy)
                                }
                                .padding(.horizontal, 15)
                                .frame(height: 48)
                                .background(selected ? Color(hex: 0xF2B45C).opacity(0.13) : Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 15))
                                .overlay(RoundedRectangle(cornerRadius: 15).stroke(selected ? Color(hex: 0xF2B45C).opacity(0.45) : NoopHTMLColor.border, lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(spacing: 10) {
                        Button {
                            navigation.nightJournalMood = mood
                            navigation.nightJournalDrinks = drinks
                            navigation.nightJournalNotes = notes
                            navigation.nightJournalSaved = true
                            navigation.nightJournalSavedAt = Date()
                            navigation.nightJournalRevision += 1
                            navigation.dismissOverlay()
                        } label: {
                            Text("Save")
                                .font(NoopHTMLFont.sans(15, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.blueInk)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(NoopHTMLColor.blue, in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(NoopHTMLPressStyle())

                        Button {
                            if navigation.nightJournalSaved {
                                let fixture = NoopContentPolicy.allowsPrototypeContent
                                navigation.nightJournalSaved = false
                                navigation.nightJournalMood = fixture ? 3 : -1
                                navigation.nightJournalDrinks = fixture ? 0 : -1
                                navigation.nightJournalNotes = fixture ? ["Screens in bed"] : []
                                navigation.nightJournalSavedAt = nil
                                navigation.nightJournalRevision += 1
                            }
                            navigation.dismissOverlay()
                        } label: {
                            Text(navigation.nightJournalSaved ? "Delete this entry" : "Nothing to log tonight")
                                .font(.custom("Instrument Sans", fixedSize: 13.5))
                                .foregroundStyle(navigation.nightJournalSaved ? NoopHTMLColor.red : Color(hex: 0x7F8A85))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }
                .frame(width: max(0, viewportWidth - 40), alignment: .leading)
                .padding(.top, 12)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                .background(NoopHTMLColor.card)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30))
                .overlay { NoopDayLogSheetTopBorder().stroke(Color.white.opacity(0.1), lineWidth: 0.5) }
                .shadow(color: .black.opacity(0.5), radius: 25, y: -20)
                .offset(y: presented ? 0 : proxy.size.height * 1.02)
            }
            .onAppear {
                if reduceMotion {
                    presented = true
                } else {
                    withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.3)) { presented = true }
                }
            }
        }
        .ignoresSafeArea()
        .transition(.identity)
    }

    private func journalGlyph(_ item: String) -> NoopCanonicalGlyphName {
        switch item {
        case "Coffee after 2pm": .cup
        case "Big meal late": .plate
        case "Screens in bed": .screen
        default: .sparkSingle
        }
    }
}

private struct NoopDayLogSheet: View {
    @ObservedObject var navigation: NoopNavigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var presented = false

    var body: some View {
        GeometryReader { proxy in
            let viewportWidth = min(proxy.size.width, UIScreen.main.bounds.width)
            ZStack(alignment: .bottom) {
                NoopBackdropBlur(style: .regular, intensity: 0.18)
                Color(hex: 0x040606, alpha: 0.62)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: navigation.dismissOverlay)

                VStack(alignment: .leading, spacing: 16) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 38, height: 4)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Log it")
                            .font(NoopHTMLFont.outfit(23, weight: .regular))
                            .tracking(-0.46)
                            .foregroundStyle(NoopHTMLColor.ink)
                        Text("One tap each. Tap twice for two.")
                            .font(NoopHTMLFont.sans(12.5))
                            .foregroundStyle(Color(hex: 0x7F8A85))
                    }
                    .frame(height: 48, alignment: .top)

                    // Change 1, door two. The global shortcut: reachable from all five tabs without
                    // going home first. The + still opens this sheet — it does not become a session
                    // button. `reset` makes it a tab-level arrival, and clears this overlay on the way.
                    Button { navigation.dismissSheetThenArrive(at: .session) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Start a session")
                                    .font(NoopHTMLFont.sans(14, weight: .semibold))
                                    .foregroundStyle(NoopHTMLColor.ink)
                                if NoopContentPolicy.allowsPrototypeContent {
                                    Text("Today’s recommendation, from wherever you are")
                                        .font(NoopHTMLFont.sans(11.5))
                                        .foregroundStyle(Color(hex: 0x7F8A85))
                                }
                            }
                            Spacer(minLength: 4)
                            NoopChevron()
                        }
                        .padding(.horizontal, 2)
                        .padding(.top, 2)
                        .padding(.bottom, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(NoopHTMLColor.border)
                                .frame(height: 0.5)
                        }
                    }
                    .buttonStyle(NoopHTMLPressStyle())

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 0)],
                        spacing: 8
                    ) {
                        ForEach(NoopDayLogKind.allCases) { kind in
                            dayLogTile(kind)
                        }
                    }

                    if NoopContentPolicy.allowsPrototypeContent {
                        Text("Everything logged here turns up in tonight's read — that is the only reason the app asks.")
                            .font(NoopHTMLFont.sans(11.5))
                            .foregroundStyle(NoopHTMLColor.faint)
                            .lineSpacing(4.6)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(height: 37, alignment: .top)
                    }

                    VStack(spacing: 8) {
                        Button("Done", action: navigation.dismissOverlay)
                            .font(NoopHTMLFont.sans(15, weight: .semibold))
                            .foregroundStyle(NoopHTMLColor.blueInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(NoopHTMLColor.blue, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .buttonStyle(NoopHTMLPressStyle())

                        Button {
                            navigation.clearDayLog()
                            navigation.dismissOverlay()
                        } label: {
                            Text("Clear today")
                                .font(NoopHTMLFont.sans(13))
                                .foregroundStyle(Color(hex: 0x7F8A85))
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: max(0, viewportWidth - 40), alignment: .leading)
                .padding(.top, 12)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                .background(NoopHTMLColor.card)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30))
                .overlay {
                    NoopDayLogSheetTopBorder()
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.5), radius: 25, y: -20)
                .offset(y: presented ? 0 : proxy.size.height * 1.02)
            }
            .onAppear {
                if reduceMotion {
                    presented = true
                } else {
                    withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.3)) {
                        presented = true
                    }
                }
            }
        }
        .ignoresSafeArea()
        .transition(.identity)
    }

    private func dayLogTile(_ kind: NoopDayLogKind) -> some View {
        let count = navigation.dayLogCount(for: kind)
        let active = count > 0

        return Button {
            withAnimation(.easeOut(duration: 0.18)) {
                navigation.addDayLog(kind)
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 8) {
                    NoopCanonicalGlyph(
                        name: glyph(for: kind),
                        size: 22,
                        color: active ? NoopHTMLColor.blue : Color(hex: 0x7F8A85)
                    )
                    Spacer(minLength: 0)
                    if active {
                        Text("\(count)")
                            .font(NoopHTMLFont.sans(12, weight: .semibold))
                            .foregroundStyle(NoopHTMLColor.blueInk)
                            .monospacedDigit()
                            .frame(minWidth: 22)
                            .padding(.horizontal, 7)
                            .frame(height: 22)
                            .background(NoopHTMLColor.blue, in: Capsule())
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.rawValue)
                        .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                        .foregroundStyle(active ? NoopHTMLColor.ink : NoopHTMLColor.inkSoft)
                    Text(kind.subtitle)
                        .font(NoopHTMLFont.sans(10.5))
                        .foregroundStyle(NoopHTMLColor.muted)
                        .lineLimit(1)
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 100)
            .background(
                active ? NoopHTMLColor.blue.opacity(0.12) : Color.white.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(active ? NoopHTMLColor.blue.opacity(0.4) : Color.white.opacity(0.07), lineWidth: 0.5)
            )
            .animation(.easeOut(duration: 0.18), value: active)
        }
        .buttonStyle(.plain)
    }

    private func glyph(for kind: NoopDayLogKind) -> NoopCanonicalGlyphName {
        switch kind {
        case .coffee: .cup
        case .water: .drop
        case .meal: .plate
        case .alcohol: .glass
        case .intimacy: .heart
        case .nap: .bed
        }
    }
}

private struct NoopDayLogSheetTopBorder: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + 30))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + 30, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - 30, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + 30),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        return path
    }
}

private struct NoopLoggedItemsSheet: View {
    @ObservedObject var navigation: NoopNavigation
    @SceneStorage("noop.trends.logged-filter") private var storedFilter = NoopLoggedFilter.all.rawValue
    @EnvironmentObject private var repo: Repository
    /// Release: the wearer's own last three days. The example list is the Debug design fixture only.
    @State private var liveDays: [NoopLoggedDay] = []

    private var filter: NoopLoggedFilter {
        get { NoopLoggedFilter(rawValue: storedFilter) ?? .all }
        nonmutating set { storedFilter = newValue.rawValue }
    }

    private var filteredDays: [NoopLoggedDay] {
        (NoopContentPolicy.allowsPrototypeContent ? NoopLoggedDay.canonical : liveDays).compactMap { day in
            let items = day.items.filter { filter.includes($0.kind) }
            return items.isEmpty ? nil : NoopLoggedDay(label: day.label, items: items)
        }
    }

    private var filteredCount: Int {
        filteredDays.reduce(0) { $0 + $1.items.count }
    }

    var body: some View {
        GeometryReader { proxy in
            let viewportWidth = min(proxy.size.width, UIScreen.main.bounds.width)
            ZStack(alignment: .bottom) {
                NoopBackdropBlur(style: .regular, intensity: 0.18)
                Color(hex: 0x040605, alpha: 0.66)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: navigation.dismissOverlay)

                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 11) {
                        Capsule()
                            .fill(Color.white.opacity(0.16))
                            .frame(width: 38, height: 4)
                            .frame(maxWidth: .infinity)

                        HStack(alignment: .bottom, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Everything you logged")
                                    .font(NoopHTMLFont.outfit(21, weight: .regular))
                                    .tracking(-0.52)
                                Text("\(filteredCount) in the last three days · \(filter.summarySuffix)")
                                    .font(.custom("Instrument Sans", fixedSize: 11.5))
                                    .foregroundStyle(Color(hex: 0x7F8A85))
                            }
                            Spacer(minLength: 8)
                            Button(action: navigation.dismissOverlay) {
                                NoopLoggedCloseGlyph()
                                    .frame(width: 32, height: 32)
                                    .background(Color.white.opacity(0.07), in: Circle())
                            }
                            .buttonStyle(NoopHTMLPressStyle())
                            .accessibilityLabel("Close")
                        }

                        HStack(spacing: 6) {
                            ForEach(NoopLoggedFilter.allCases, id: \.self) { item in
                                Button { filter = item } label: {
                                    Text(item.rawValue)
                                        .font(.custom("Instrument Sans", fixedSize: 11.5).weight(.medium))
                                        .foregroundStyle(filter == item ? Color(hex: 0x8FEFC0) : NoopHTMLColor.copy)
                                        .padding(.horizontal, 13)
                                        .frame(height: 35)
                                        .background(filter == item ? NoopHTMLColor.green.opacity(0.18) : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
                                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(filter == item ? NoopHTMLColor.green.opacity(0.4) : Color.white.opacity(0.07), lineWidth: 0.5))
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(filter == item ? .isSelected : [])
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(filteredDays) { day in
                                loggedDay(day)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 6)
                    }
                    .scrollIndicators(.hidden)

                    Button {
                        navigation.dismissSheetThenPush(.history)
                    } label: {
                        HStack(spacing: 8) {
                            Text("Open the full list")
                            NoopA4CSSChevron(direction: .right, color: Color(hex: 0x8FEFC0))
                        }
                        .font(.custom("Instrument Sans", fixedSize: 13.5).weight(.semibold))
                        .foregroundStyle(Color(hex: 0x8FEFC0))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(NoopHTMLColor.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(NoopHTMLColor.green.opacity(0.3), lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
                .frame(width: viewportWidth)
                .frame(maxHeight: proxy.size.height * 0.74)
                .background(NoopHTMLColor.card, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
                .overlay(alignment: .top) {
                    UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                        .stroke(NoopHTMLColor.borderStrong, lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.6), radius: 22, y: -14)
            }
        }
        .ignoresSafeArea()
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .task {
            guard !NoopContentPolicy.allowsPrototypeContent else { return }
            liveDays = await NoopLoggedDay.recorded(from: repo)
        }
    }

    private func loggedDay(_ day: NoopLoggedDay) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(day.label)
                    .font(.custom("Instrument Sans", fixedSize: 11.5).weight(.semibold))
                    .foregroundStyle(NoopHTMLColor.inkSoft)
                Spacer()
                Text(day.summary)
                    .font(.custom("Instrument Sans", fixedSize: 10.5))
                    .foregroundStyle(NoopHTMLColor.faint)
            }
            .padding(.horizontal, 2)

            VStack(spacing: 0) {
                ForEach(Array(day.items.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 12) {
                        NoopCanonicalGlyph(name: item.glyph, size: 17, color: item.tint)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name)
                                .font(NoopHTMLFont.sans(13, weight: item.kind == .log ? .regular : .semibold))
                                .foregroundStyle(item.kind == .log ? NoopHTMLColor.inkSoft : NoopHTMLColor.ink)
                            Text(item.detail)
                                .font(.custom("Instrument Sans", fixedSize: 10.5))
                                .foregroundStyle(Color(hex: 0x7F8A85))
                                .lineLimit(1)
                                .minimumScaleFactor(0.86)
                        }
                        Spacer(minLength: 6)
                        Text(item.figure)
                            .font(NoopHTMLFont.sans(11))
                            .foregroundStyle(Color(hex: 0x7F8A85))
                            .monospacedDigit()
                    }
                    .frame(minHeight: 50)
                    if index < day.items.count - 1 { Color.white.opacity(0.055).frame(height: 1) }
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(NoopHTMLColor.border, lineWidth: 0.5))
        }
    }
}

private enum NoopLoggedFilter: String, CaseIterable {
    case all = "All"
    case sessions = "Sessions"
    case sleep = "Sleep"
    case logs = "Logs"

    var summarySuffix: String {
        self == .all ? "everything" : "\(rawValue.lowercased()) only"
    }

    func includes(_ kind: NoopLoggedKind) -> Bool {
        switch self {
        case .all: true
        case .sessions: kind == .session
        case .sleep: kind == .sleep
        case .logs: kind == .log
        }
    }
}

private enum NoopLoggedKind: String {
    case session
    case sleep
    case log
}

private struct NoopLoggedItem {
    let kind: NoopLoggedKind
    let name: String
    let detail: String
    let figure: String
    let glyph: NoopCanonicalGlyphName

    var tint: Color {
        switch kind {
        case .session: NoopHTMLColor.green
        case .sleep: NoopHTMLColor.night
        case .log: Color(hex: 0x7F8A85)
        }
    }
}

private struct NoopLoggedDay: Identifiable {
    var id: String { label }
    let label: String
    let items: [NoopLoggedItem]

    var summary: String {
        let sessions = items.filter { $0.kind == .session }.count
        let sleeps = items.filter { $0.kind == .sleep }.count
        let logs = items.filter { $0.kind == .log }.count
        var parts: [String] = []
        if sessions > 0 { parts.append("\(sessions) \(sessions == 1 ? "session" : "sessions")") }
        if sleeps > 0 { parts.append(sleeps == 1 ? "sleep" : "\(sleeps) sleeps") }
        if logs > 0 { parts.append("\(logs) \(logs == 1 ? "log" : "logs")") }
        return parts.joined(separator: " · ")
    }

    /// The last three local days from the record: sessions as recorded, the night that ended that
    /// day (time asleep from its stages), and journal entries answered yes. Nothing is estimated;
    /// a day with none of these is left out, as in the design.
    @MainActor
    static func recorded(from repo: Repository, now: Date = Date()) async -> [NoopLoggedDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let clock = AppClock.hourMinuteFormatter()
        let workouts = await repo.workoutRows(days: 4)
        let journal = await repo.journalEntries(days: 4)
        let rest = NoopRestStore()
        await rest.load(from: repo)
        let nights = rest.record.slots.compactMap { $0 }
        let coffee = CaffeineLogStore.shared.intakes
        let longDate = DateFormatter()
        longDate.locale = Locale(identifier: "en_GB")
        longDate.dateFormat = "EEEE d MMMM"

        var days: [NoopLoggedDay] = []
        for offset in 0..<3 {
            guard let start = calendar.date(byAdding: .day, value: -offset, to: today),
                  let end = calendar.date(byAdding: .day, value: 1, to: start) else { continue }
            let span = Int(start.timeIntervalSince1970)..<Int(end.timeIntervalSince1970)
            var items: [NoopLoggedItem] = []
            for workout in workouts.filter({ span.contains($0.startTs) }).sorted(by: { $0.startTs > $1.startTs }) {
                var detail = clock.string(from: Date(timeIntervalSince1970: TimeInterval(workout.startTs)))
                    + " · \(workout.noopMinutes) min"
                if let avg = workout.avgHr { detail += " · avg \(avg) bpm" }
                items.append(.init(kind: .session, name: workout.sport, detail: detail, figure: "",
                                   glyph: workout.sport.localizedCaseInsensitiveContains("cycl") ? .bike : .bolt))
            }
            if let night = nights.last(where: { $0.endDate >= start && $0.endDate < end }) {
                let minutes = Int(night.asleepMin.rounded())
                items.append(.init(kind: .sleep, name: "Slept \(minutes / 60)h \(minutes % 60)m",
                                   detail: night.window.replacingOccurrences(of: "–", with: "→"),
                                   figure: "", glyph: .bed))
            }
            let dayKey = Repository.localDayKey(start)
            for entry in journal.filter({ $0.day == dayKey && $0.answeredYes }) {
                let count = entry.numericValue.map { Int($0.rounded()) } ?? 1
                var detail = ""
                if entry.question == NoopDayLogKind.coffee.rawValue {
                    detail = coffee.filter { $0.at >= start && $0.at < end }
                        .sorted { $0.at < $1.at }
                        .map { clock.string(from: $0.at) }
                        .joined(separator: " · ")
                }
                items.append(.init(kind: .log, name: entry.question, detail: detail,
                                   figure: count > 1 ? "×\(count)" : "", glyph: glyph(forLog: entry.question)))
            }
            guard !items.isEmpty else { continue }
            let label = offset == 0 ? "Today" : offset == 1 ? "Yesterday" : longDate.string(from: start)
            days.append(NoopLoggedDay(label: label, items: items))
        }
        return days
    }

    private static func glyph(forLog name: String) -> NoopCanonicalGlyphName {
        switch NoopDayLogKind(rawValue: name) {
        case .coffee: .cup
        case .water: .drop
        case .meal: .plate
        case .alcohol: .glass
        case .nap: .bed
        case .intimacy: .heart
        case nil: .check
        }
    }

    static let canonical: [NoopLoggedDay] = [
        .init(label: "Today", items: [
            .init(kind: .session, name: "Steady ride", detail: "17:04 · 42 min · avg 126 bpm", figure: "load 48", glyph: .bike),
            .init(kind: .log, name: "Coffee", detail: "07:20", figure: "", glyph: .cup),
            .init(kind: .log, name: "Water", detail: "09:40 · 11:15", figure: "×2", glyph: .drop),
            .init(kind: .log, name: "Meal", detail: "12:05", figure: "", glyph: .plate)
        ]),
        .init(label: "Yesterday", items: [
            .init(kind: .sleep, name: "Slept 7h 12m", detail: "23:18 → 06:41 · 7 min over your need", figure: "", glyph: .bed),
            .init(kind: .log, name: "Coffee", detail: "07:15 · 13:40", figure: "×2", glyph: .cup),
            .init(kind: .log, name: "Alcohol", detail: "20:30 · one glass", figure: "", glyph: .drop)
        ]),
        .init(label: "Monday 18 August", items: [
            .init(kind: .session, name: "6 × 1 min hard", detail: "18:10 · 22 min · max 174 bpm", figure: "load 86", glyph: .bolt),
            .init(kind: .sleep, name: "Slept 6h 48m", detail: "23:52 → 06:40 · 24 min under", figure: "", glyph: .bed),
            .init(kind: .log, name: "Nap", detail: "15:10 · 26 min", figure: "", glyph: .bed)
        ])
    ]
}

private struct NoopLoggedCloseGlyph: View {
    var body: some View {
        Canvas { context, _ in
            var path = Path()
            path.move(to: CGPoint(x: 7, y: 7)); path.addLine(to: CGPoint(x: 17, y: 17))
            path.move(to: CGPoint(x: 17, y: 7)); path.addLine(to: CGPoint(x: 7, y: 17))
            let scale: CGFloat = 14 / 24
            context.stroke(
                path.applying(CGAffineTransform(scaleX: scale, y: scale)),
                with: .color(NoopHTMLColor.inkSoft),
                style: StrokeStyle(lineWidth: 1.7 * scale, lineCap: .round)
            )
        }
        .frame(width: 14, height: 14)
    }
}

struct NoopDeepInsightsConfirmation: View {
    @ObservedObject var navigation: NoopNavigation

    var body: some View {
        NoopBottomSheet(title: "Allow Deep Insights?", dismiss: navigation.dismissOverlay) {
            VStack(alignment: .leading, spacing: 16) {
                Text("This adds sensitive journal entries to the context Svea may read. Nothing is sent until you ask Svea or enable a proactive brief.")
                    .font(NoopHTMLFont.sans(13))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .lineSpacing(4)
                Button("Allow sensitive journal access") { navigation.dismissOverlay() }
                    .buttonStyle(NoopHTMLButtonStyle(kind: .primary, fullWidth: true))
                Button("Not now") { navigation.dismissOverlay() }
                    .buttonStyle(NoopHTMLButtonStyle(kind: .quiet, fullWidth: true))
            }
        }
    }
}

struct NoopDestructiveConfirmation: View {
    let item: String
    @ObservedObject var navigation: NoopNavigation

    var body: some View {
        NoopBottomSheet(title: "Delete \(item)?", dismiss: navigation.dismissOverlay) {
            VStack(alignment: .leading, spacing: 16) {
                Text("This cannot be undone.")
                    .font(NoopHTMLFont.sans(13))
                    .foregroundStyle(NoopHTMLColor.copy)
                Button("Delete") {
                    navigation.dismissOverlay()
                    if item == "your account and data" {
                        NotificationCenter.default.post(name: .noopDeleteAllLocalData, object: nil)
                    }
                }
                    .buttonStyle(NoopHTMLButtonStyle(kind: .destructive, fullWidth: true))
                Button("Cancel") { navigation.dismissOverlay() }
                    .buttonStyle(NoopHTMLButtonStyle(kind: .quiet, fullWidth: true))
            }
        }
    }
}

/// Tiny wrapping layout used by the HTML chip rows.
struct NoopFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
