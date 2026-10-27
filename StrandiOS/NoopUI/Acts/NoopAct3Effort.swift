import Foundation
import StrandAnalytics
import StrandDesign
import StrandImport
import SwiftUI
import WhoopStore

struct NoopAct3Screens: View {
    @ObservedObject var navigation: NoopNavigation
    /// The recorded sessions; every screen draws from the record and the real recorder.
    let effort: NoopEffortRecord
    var battery: Int? = nil
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: NoopLiveGlance
    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var liftSession: LiftSessionController
    /// Production: the running session that refused a start, while its refusal is up.
    @State private var refusal: NoopRunningSession?
    /// The goal and zone sheet over a running cardio session.
    @State private var cardioGoalOpen = false


    var body: some View {
        productionBody(effort)
            .overlay {
                if let refusal {
                    NoopSessionRefusal(session: refusal,
                                       goToIt: { self.refusal = nil; refusal.go(navigation: navigation, lift: liftSession) },
                                       notNow: { withAnimation(NoopMotion.swap) { self.refusal = nil } })
                }
            }
    }

    private func back(to fallback: NoopRoute) {
        navigation.canGoBack ? navigation.back() : navigation.reset(to: fallback)
    }
}

private struct Act3BackHeader: View {
    let label: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            NoopBackButton(action: action)
            NoopBackTitle(label)
            Spacer(minLength: 0)
        }
        .frame(minHeight: NoopCloseButton.side)
        .padding(.bottom, 8)
    }
}

private struct Act3ActionButton: View {
    let title: String
    let height: CGFloat
    let radius: CGFloat
    let fontSize: CGFloat
    let primary: Bool
    let action: () -> Void

    init(
        _ title: String,
        height: CGFloat,
        radius: CGFloat,
        fontSize: CGFloat = 13.5,
        primary: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.height = height
        self.radius = radius
        self.fontSize = fontSize
        self.primary = primary
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(NoopHTMLFont.sans(fontSize, weight: primary ? .semibold : .regular))
                .foregroundStyle(primary ? NoopHTMLColor.blueInk : NoopHTMLColor.inkSoft)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(primary ? NoopHTMLColor.blue : Color.clear, in: RoundedRectangle(cornerRadius: radius))
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(primary ? Color.clear : Color.white.opacity(0.14), lineWidth: 0.5)
                )
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

private struct Act3WorkoutGlyph: View {
    let workout: NoopWorkout
    let size: CGFloat
    let color: Color

    private var glyph: NoopCanonicalGlyphName {
        switch workout {
        case .steadyRide: .bike
        case .intervals: .bolt
        case .longWalk: .walk
        case .strength: .weight
        case .easySwim: .wave
        }
    }

    var body: some View {
        NoopCanonicalGlyph(name: glyph, size: size, color: color)
    }
}

private struct Act3LineBoxModifier: ViewModifier {
    let fontSize: CGFloat
    let ratio: CGFloat

    func body(content: Content) -> some View {
        let native = fontSize * 1.22
        let target = fontSize * ratio
        let leading = max(0, target - native)
        content
            .lineSpacing(leading)
            .padding(.vertical, leading / 2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private extension View {
    func act3LineBox(fontSize: CGFloat, ratio: CGFloat) -> some View {
        modifier(Act3LineBoxModifier(fontSize: fontSize, ratio: ratio))
    }
}

private func heartbeatValue(_ phase: Double, points: [(Double, CGFloat)]) -> CGFloat {
    guard let first = points.first else { return 1 }
    if phase <= first.0 { return first.1 }
    for index in 1..<points.count {
        let previous = points[index - 1]
        let next = points[index]
        if phase <= next.0 {
            let span = max(0.0001, next.0 - previous.0)
            let amount = CGFloat((phase - previous.0) / span)
            return previous.1 + (next.1 - previous.1) * amount
        }
    }
    return points.last?.1 ?? first.1
}

// MARK: - Live faces

// MARK: - Act 3 models

struct Act3WorkoutModel {
    let name: String
    let symbol: String
    let duration: Int
    let low: Int
    let high: Int
    let load: Int
    let fit: String
    let isInsideToday: Bool
    let reason: String
    let note: String
    let isIntervals: Bool
    let primaryZone: String
}

extension NoopWorkout {
    var act3: Act3WorkoutModel {
        switch self {
        case .steadyRide:
            Act3WorkoutModel(
                name: "Steady ride", symbol: "bicycle", duration: 40, low: 112, high: 128, load: 48,
                fit: "as planned", isInsideToday: true,
                reason: "Forty minutes, easy the whole way. Hold your pulse between 112 and 128 and let the hills come to you.",
                note: "What today can take without borrowing from tomorrow.", isIntervals: false, primaryZone: "Steady"
            )
        case .intervals:
            Act3WorkoutModel(
                name: "6 × 1 min hard", symbol: "bolt.fill", duration: 22, low: 152, high: 168, load: 86,
                fit: "harder than today allows", isInsideToday: false,
                reason: "Six one-minute efforts with thirty seconds easy between them. This is the session you had planned, and it is still here if you want it.",
                note: "Costs about two days of recovery from where you are this morning.", isIntervals: true, primaryZone: "All out"
            )
        case .longWalk:
            Act3WorkoutModel(
                name: "Long walk", symbol: "figure.walk", duration: 50, low: 92, high: 110, load: 18,
                fit: "well inside today", isInsideToday: true,
                reason: "Fifty easy minutes. Nothing to hold, nothing to hit — it counts as movement and costs you almost nothing.",
                note: "The honest choice on a day your breathing is up.", isIntervals: false, primaryZone: "Easy"
            )
        case .strength:
            Act3WorkoutModel(
                name: "Strength, lower body", symbol: "dumbbell", duration: 35, low: 104, high: 128, load: 62,
                fit: "legs are two days out", isInsideToday: false,
                reason: "Thirty-five minutes of lower body work. Your legs took a real load on Monday and have not finished the job.",
                note: "Better on Friday, when the ride has been paid off.", isIntervals: false, primaryZone: "Steady"
            )
        case .easySwim:
            Act3WorkoutModel(
                name: "Easy swim", symbol: "figure.pool.swim", duration: 30, low: 108, high: 126, load: 42,
                fit: "as good as the ride", isInsideToday: true,
                reason: "Thirty minutes, easy. Same effect as the ride with less through your legs.",
                note: "Swap freely — the recommendation does not mind which one you pick.", isIntervals: false, primaryZone: "Steady"
            )
        }
    }
}

// MARK: - Production (the measured record and the real recorder)

/// The five session templates as plans: a name, a length and a zone the wearer's own bands resolve to
/// beats per minute. What each would "cost today", whether it fits, and why — the prescription the
/// design writes — needs an engine the app does not have and is left out.
extension NoopWorkout {
    static func matchingRecordedSport(_ sport: String) -> NoopWorkout? {
        allCases.first { $0.catalogSport.caseInsensitiveCompare(sport) == .orderedSame }
    }

    /// The profile zone (1–5) the template trains in; nil for a session with no single zone.
    var targetZone: Int? {
        switch self {
        case .steadyRide, .easySwim: 2
        case .longWalk: 1
        case .intervals: 5
        case .strength: nil
        }
    }

    /// The template's band in beats per minute from the wearer's zones; nil without a single zone or
    /// before the zones are the wearer's own.
    @MainActor func band(profile: ProfileStore) -> (low: Int, high: Int)? {
        guard NoopZoneSource.current(profile).trusted, let number = targetZone else { return nil }
        let zones = profile.hrZoneSet.zones
        guard zones.indices.contains(number - 1) else { return nil }
        let z = zones[number - 1]
        return (Int(z.lower.rounded()), Int(z.upper.rounded()))
    }

    /// The catalogue sport the recorder saves the session under.
    var catalogSport: String {
        switch self {
        case .steadyRide: "Cycling"
        case .intervals: "HIIT"
        case .longWalk: "Walking"
        case .strength: "Strength"
        case .easySwim: "Pool swim"
        }
    }
}

private extension NoopAct3Screens {
    @ViewBuilder
    func productionBody(_ effort: NoopEffortRecord) -> some View {
        switch navigation.route {
        case .pick: livePicker
        case .ready: liveReady
        default: liveSession
        }
    }

    /// Profile zones are the wearer's only once the age behind them is confirmed or a max was set.
    var zonesTrusted: Bool { NoopZoneSource.current(profile).trusted }

    /// The template's band in beats per minute from the wearer's zones; nil without a single zone or
    /// before the zones are the wearer's own.
    func band(_ workout: NoopWorkout) -> (low: Int, high: Int)? { workout.band(profile: profile) }

    func bandText(_ workout: NoopWorkout) -> String {
        band(workout).map { "\($0.low)\u{2013}\($0.high)" } ?? "\u{2014}"
    }

    /// The app's own five zones, by number: the design's band names do not line up with them.
    static let zoneNames = (1...5).map(NoopZoneSource.name)

    // MARK: Session home

    // MARK: Picker

    var livePicker: some View {
        NoopScreen(topInset: 56) {
            VStack(spacing: 0) {
                Act3BackHeader(label: "Fitness") { back(to: .fitness) }
                    .padding(.horizontal, -2)
                VStack(spacing: 14) {
                    Text("Choose something else")
                        .font(NoopHTMLFont.outfit(25))
                        .tracking(-0.625)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(spacing: 9) {
                        ForEach(NoopWorkout.allCases) { workout in
                            let selected = navigation.selectedWorkout == workout
                            Button {
                                navigation.selectedWorkout = workout
                                navigation.workoutChosenByUser = true
                                // Strength is a lift: it continues into Act 10's library. Anything
                                // else returns to Fitness, where the suggested session now reads it.
                                if workout == .strength { navigation.push(.liftLibrary) }
                                else { navigation.back(or: .fitness) }
                            } label: {
                                HStack(spacing: 13) {
                                    Act3WorkoutGlyph(workout: workout, size: 21, color: NoopHTMLColor.blue)
                                        .frame(width: 21)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(workout.act3.name).font(NoopHTMLFont.sans(14.5, weight: .semibold))
                                        Text("\(workout.act3.duration) min" + (band(workout).map { " \u{00B7} \($0.low)\u{2013}\($0.high) bpm" } ?? ""))
                                            .font(NoopHTMLFont.sans(11.5))
                                            .foregroundStyle(Color(hex: 0x7F8A85))
                                            .monospacedDigit()
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 15)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(selected ? NoopHTMLColor.blue.opacity(0.09) : NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected ? NoopHTMLColor.blue.opacity(0.34) : NoopHTMLColor.border, lineWidth: 0.5))
                            }
                            .buttonStyle(NoopHTMLPressStyle())
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: Ready

    var liveReady: some View {
        let workout = navigation.selectedWorkout
        let canvasWidth = UIScreen.main.bounds.width
        let canvasHeight = UIScreen.main.bounds.height
        let zone = workout.targetZone
        return VStack(spacing: 0) {
            HStack {
                NoopBackButton { navigation.back(or: .fitness) }
                Spacer()
                NoopSectionLabel("Ready")
                Spacer()
                Color.clear.frame(width: NoopCloseButton.side, height: NoopCloseButton.side)
            }
            .frame(width: max(0, canvasWidth - 36))
            .padding(.top, 56)

            VStack(spacing: 26) {
                VStack(spacing: 9) {
                    Act3WorkoutGlyph(workout: workout, size: 30, color: NoopHTMLColor.blue)
                    Text(workout.act3.name)
                        .font(NoopHTMLFont.outfit(31, weight: .light))
                        .tracking(-0.9)
                        .multilineTextAlignment(.center)
                    Text("\(workout.act3.duration) minutes" + (band(workout).map { " \u{00B7} hold \($0.low)\u{2013}\($0.high) bpm" } ?? ""))
                        .font(NoopHTMLFont.sans(13.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .monospacedDigit()
                }

                if zonesTrusted, let zone {
                    VStack(spacing: 10) {
                        GeometryReader { proxy in
                            HStack(spacing: 3) {
                                ForEach(0..<5, id: \.self) { index in
                                    Rectangle()
                                        .fill(index == zone - 1 ? NoopHTMLColor.blue : Color.white.opacity(0.07))
                                        .frame(width: max(0, (proxy.size.width - 12) / 5))
                                }
                            }
                        }
                        .frame(height: 12)
                        .clipShape(Capsule())
                        HStack(spacing: 3) {
                            ForEach(0..<5, id: \.self) { index in
                                Text(Self.zoneNames[index])
                                    .font(NoopHTMLFont.sans(9.5, weight: index == zone - 1 ? .semibold : .regular))
                                    .foregroundStyle(index == zone - 1 ? NoopHTMLColor.inkSoft : NoopHTMLColor.faint)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        Text("Your target is the lit stretch: \(Self.zoneNames[zone - 1]) is where this session lives.")
                            .font(NoopHTMLFont.sans(12.5))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .lineSpacing(3)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }

                VStack(alignment: .leading, spacing: 11) {
                    if zonesTrusted, zone != nil {
                        liveReadyCheck(.bell, "One buzz if you drift out of the zone, and one when you come back. Nothing else will interrupt you.")
                    }
                    liveReadyCheck(.check, "No ring to close, no medal at the end. The session is done when the minutes are done.")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(NoopHTMLColor.border, lineWidth: 0.5))
            }
            .frame(maxHeight: .infinity)
            .frame(width: max(0, canvasWidth - 48))
            .padding(.top, 20)

            VStack(spacing: 8) {
                Act3ActionButton("Start", height: 60, radius: 20, fontSize: 16, primary: true) {
                    guard !refuseIfRunning() else { return }
                    model.startWorkout(sport: workout.catalogSport, targetZone: zonesTrusted ? zone : nil)
                    navigation.beginSession(at: model.activeWorkout?.start ?? Date())
                    navigation.push(.live)
                }
                .shadow(color: NoopHTMLColor.blue.opacity(0.3), radius: 13, y: 8)
                Button("Not now") { navigation.reset(to: .fitness) }
                    .font(NoopHTMLFont.sans(13))
                    .foregroundStyle(Color(hex: 0x7F8A85))
                    .frame(height: 44)
            }
            .frame(width: max(0, canvasWidth - 48))
            .padding(.top, 18)
            .padding(.bottom, 26)
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .background(NoopHTMLColor.canvas)
    }

    /// Raises the designer's refusal when a session of either kind is running; true when it refused.
    func refuseIfRunning() -> Bool {
        guard let running = NoopRunningSession.current(app: model, lift: liftSession, navigation: navigation) else {
            return false
        }
        withAnimation(NoopMotion.swap) { refusal = running }
        return true
    }

    func liveReadyCheck(_ glyph: NoopCanonicalGlyphName, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            NoopCanonicalGlyph(name: glyph, size: 17, color: NoopHTMLColor.blue).frame(width: 18)
            Text(text)
                .font(NoopHTMLFont.sans(12.5))
                .foregroundStyle(Color(hex: 0xB7C3C9))
                .act3LineBox(fontSize: 12.5, ratio: 1.5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func liveFigures(_ active: AppModel.ActiveWorkout, inZone: String, hasBand: Bool) -> [NoopFitnessCardioLive.Figure] {
        var figures: [NoopFitnessCardioLive.Figure] = []
        // Kept while paused too, so the figures and the ring above them do not jump on Pause.
        if model.gpsRecorder.isRecording || model.gpsRecorder.isPaused {
            figures.append(.init(label: "km", value: String(format: "%.2f", model.gpsRecorder.distanceM / 1000)))
            // Pace over the first few metres is noise (a GPS jitter of 2 m in 7 s read as 48692:20 /km):
            // shown from 50 m on, and never slower than an hour a kilometre.
            let pace = model.gpsRecorder.distanceM >= 50 ? model.gpsRecorder.paceSecPerKm.flatMap { $0 > 0 && $0 < 3600 ? $0 : nil } : nil
            figures.append(.init(label: "pace /km", value: pace.map {
                String(format: "%d:%02d", Int($0) / 60, Int($0) % 60) } ?? "—"))
        }
        figures.append(.init(label: "avg bpm", value: active.avgHr > 0 ? "\(active.avgHr)" : "—"))
        figures.append(.init(label: "Effort", value: String(format: "%.1f", active.liveStrain)))
        figures.append(.init(label: "peak bpm", value: active.peakHr > 0 ? "\(active.peakHr)" : "—"))
        if hasBand { figures.append(.init(label: "in zone", value: inZone)) }
        return figures
    }

    // MARK: Live

    @ViewBuilder var liveSession: some View {
        if let active = model.activeWorkout {
            // The durable recorder owns this face after a relaunch. The selected HTML template may
            // still be its default, or another workout chosen while the original kept running.
            let matched = NoopWorkout.matchingRecordedSport(active.sport)
            let template = (matched ?? .steadyRide).act3
            let target = active.targetZone
            let zones = profile.hrZoneSet.zones
            let band: (low: Int, high: Int)? = {
                guard zonesTrusted, let target, zones.indices.contains(target - 1) else { return nil }
                let zone = zones[target - 1]
                return (Int(zone.lower.rounded()), Int(zone.upper.rounded()))
            }()
            let shown = Act3WorkoutModel(
                name: active.sport, symbol: template.symbol, duration: template.duration,
                low: band?.low ?? 0, high: band?.high ?? 999, load: 0, fit: "", isInsideToday: true,
                reason: "", note: "", isIntervals: false,
                primaryZone: target.map(NoopZoneSource.name) ?? "")
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let elapsed = Int(active.elapsed(at: timeline.date))
            let bpm = live.heartRate
            let samples = active.samples
            let inZone: String = {
                guard let band, !samples.isEmpty else { return "\u{2014}" }
                let inside = samples.filter { $0.bpm >= band.low && $0.bpm < band.high }.count
                return "\(Int((Double(inside) / Double(samples.count) * 100).rounded()))%"
            }()
            let zoneNumber = bpm.map { profile.hrZoneSet.zoneNumber(forBPM: Double($0)) } ?? 0
            let figures = liveFigures(active, inZone: inZone, hasBand: band != nil)
            NoopFitnessCardioLive(
                sport: active.sport, symbol: NoopFitnessCardioLive.symbol(for: active.sport),
                elapsed: elapsed, bpm: bpm, paused: active.isPaused,
                zone: zonesTrusted ? zoneNumber : 0, zoneNames: Self.zoneNames,
                zoneRanges: zones.map { (Int($0.lower.rounded()), Int($0.upper.rounded())) },
                target: zonesTrusted ? target : nil,
                recent: samples.suffix(300).map(\.bpm),
                figures: figures,
                footnote: AppModel.isTooShortToSave(elapsedSeconds: TimeInterval(elapsed)) ? "Under a minute is not kept" : nil,
                tooShort: AppModel.isTooShortToSave(elapsedSeconds: TimeInterval(elapsed)),
                goalFraction: model.workoutGoalProgress(at: timeline.date),
                goalLabel: active.goal.map { goal in
                    switch goal {
                    case .time(let s): "\(NoopCardioGoalText.clock(min(elapsed, s))) of \(NoopCardioGoalText.clock(s))"
                    case .distance(let m): "\(NoopCardioGoalText.km(model.gpsRecorder.distanceM)) of \(NoopCardioGoalText.km(m)) km"
                    }
                },
                goalReached: active.goalReached,
                goalAction: { cardioGoalOpen = true },
                pauseAction: {
                    model.toggleWorkoutPause()
                    navigation.toggleSessionPause(at: timeline.date)
                },
                endAction: {
                    model.endWorkout()
                    let saved = model.lastWorkout
                    navigation.endRecordedSession(workout: matched, row: saved)
                    NoopFitnessModel.markChanged()
                })
            .onChange(of: elapsed) { model.checkWorkoutGoal(at: timeline.date) }
            }
            .sheet(isPresented: $cardioGoalOpen) {
                NoopCardioGoalSheet(sport: active.sport, mode: .edit, goal: active.goal, zone: active.targetZone) { goal, zone in
                    model.setWorkoutGoal(goal)
                    model.setWorkoutTargetZone(zone)
                }
                .environmentObject(profile)
                .noopSheet()
            }
        } else {
            NoopScreen(topInset: 58) {
                VStack(alignment: .leading, spacing: 16) {
                    Act3BackHeader(label: "Fitness") { navigation.back(or: .fitness) }
                    Text("No session is running")
                        .font(NoopHTMLFont.outfit(27, weight: .light))
                    Text("Choose a session when you are ready. Nothing has been recorded here.")
                        .font(NoopHTMLFont.sans(13))
                        .foregroundStyle(NoopHTMLColor.copy)
                }
            }
        }
    }

}

