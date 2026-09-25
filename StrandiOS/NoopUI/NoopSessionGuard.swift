#if os(iOS)
import SwiftUI

/// The one-session rule (spec 90 §9.1): a cardio session (`AppModel.activeWorkout`) and a lift
/// (`LiftSessionController`) are two owners, and the invariant "never two running" is enforced at
/// each start call. Starting while either runs is refused — never an end-and-start, never a swap.
struct NoopRunningSession: Equatable {
    let name: String
    let started: Date
    let isLift: Bool

    @MainActor static func current(app: AppModel, lift: LiftSessionController, navigation: NoopNavigation) -> NoopRunningSession? {
        // An unsaved lift still owns the one-session slot even if an older snapshot reached a
        // finished engine stage before its database write failed.
        if let start = lift.engine?.startTs {
            return .init(name: lift.programName ?? "Lift", started: Date(timeIntervalSince1970: TimeInterval(start)),
                         isLift: true)
        }
        if let workout = app.activeWorkout {
            // The durable workout is authoritative after a process restart; navigation's selected
            // template may still be the default and can name an entirely different sport.
            return .init(name: workout.sport, started: workout.start, isLift: false)
        }
        return nil
    }

    /// Opens the running session's own screen.
    @MainActor func go(navigation: NoopNavigation, lift: LiftSessionController) {
        if isLift {
            lift.isPresented = true
            navigation.reset(to: .liftLive)
        } else {
            navigation.push(.live)
        }
    }
}

/// The designer's refusal: title, "{workout name} started {time}. Noop keeps one session at a time.",
/// and Go to it · Not now. Nothing destructive inside it.
struct NoopSessionRefusal: View {
    let session: NoopRunningSession
    let goToIt: () -> Void
    let notNow: () -> Void

    var body: some View {
        ZStack {
            Color(hex: 0x060807).opacity(0.66).ignoresSafeArea()
                .onTapGesture(perform: notNow)
            VStack(alignment: .leading, spacing: 13) {
                Text("A session is already running")
                    .font(NoopHTMLFont.outfit(21))
                    .tracking(-0.46)
                    .foregroundStyle(NoopHTMLColor.ink)
                Text("\(session.name) started \(AppClock.hourMinuteFormatter().string(from: session.started)). Noop keeps one session at a time.")
                    .font(NoopHTMLFont.sans(12.5))
                    .foregroundStyle(Color(hex: 0xB7C3C9))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 8) {
                    Button(action: goToIt) {
                        Text("Go to it")
                            .font(NoopHTMLFont.sans(14, weight: .semibold))
                            .foregroundStyle(NoopHTMLColor.ink)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    Button(action: notNow) {
                        Text("Not now")
                            .font(NoopHTMLFont.sans(14))
                            .foregroundStyle(Color(hex: 0xC6CEC9))
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(Color(hex: 0x171C1A), in: RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.6), radius: 30, y: 20)
            .padding(26)
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
        }
    }
}
#endif
