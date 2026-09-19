#if os(iOS)
import SwiftUI

// MARK: - Act 10 · The lift

/// The lift is entered from the Today key; like Act 9 it deliberately does not add a tab.
///
/// EVERY SCREEN HERE IS A PLACEHOLDER. The routes exist so design can launch each one against the
/// running build (`--noop-route lift-live`) and so the shell's act grammar — ambient, eyebrow, back,
/// the + — is settled before the drawings land. Each placeholder names its own route and the screen
/// it will replace, so a launch that reaches the wrong one is obvious at a glance rather than
/// looking like an unstyled screen.
///
/// The behaviour these will be dressed over already exists and is already owned above any view, in
/// `LiftSessionController`: the engine, the shared one-second tick, the partially-entered set, the
/// minimised-bar state, and `presentation(system:)`, which resolves the bar and the Lock Screen
/// Live Activity from one place so their wording cannot drift. Wire each screen to that controller
/// rather than copying its state into `NoopNavigation`; a session with two owners is a bar that
/// disagrees with the sheet.
struct NoopAct10Screens: View {
    @ObservedObject var navigation: NoopNavigation

    var body: some View {
        switch navigation.route {
        case .liftLive:
            NoopLiftPlaceholder(route: .liftLive, replaces: "LiftSessionView",
                                note: "The running session. Reads LiftSessionController; the strap's double-tap advances the set.",
                                navigation: navigation)
        case .liftLibrary:
            NoopLiftPlaceholder(route: .liftLibrary, replaces: "LiftLogView",
                                note: "Programs, and the 1,324-exercise catalogue behind them.",
                                navigation: navigation)
        case .liftProgram:
            NoopLiftPlaceholder(route: .liftProgram, replaces: "LiftLogView / LiftProgramEditorSheet",
                                note: "One program. A line carries far more than an exercise name — phase, intensifier, unilateral reps, rest, note.",
                                navigation: navigation)
        case .liftDetail:
            NoopLiftPlaceholder(route: .liftDetail, replaces: "LiftSessionDetailSheet",
                                note: "A finished session. Carries the catalogue attribution line, which is a licence condition.",
                                navigation: navigation)
        case .liftEdit:
            NoopLiftPlaceholder(route: .liftEdit, replaces: "LiftSessionEditSheet",
                                note: "Correcting a session after the fact.",
                                navigation: navigation)
        case .liftImport:
            NoopLiftPlaceholder(route: .liftImport, replaces: "LiftProgramImportSheet",
                                note: "The spreadsheet import. Nothing is written until the review has been seen.",
                                navigation: navigation)
        case .liftReview:
            NoopLiftPlaceholder(route: .liftReview, replaces: "LiftProgramImportSheet (review state)",
                                note: "What the import will create, before it creates it.",
                                navigation: navigation)
        case .liftMuscles:
            NoopLiftPlaceholder(route: .liftMuscles, replaces: "— new —",
                                note: "Credited sets per muscle: a primary set counts 1.0, a secondary 0.5, stabilisers zero. 33 muscles, 7 derived regions.",
                                navigation: navigation)
        default:
            NoopLiftPlaceholder(route: .liftLibrary, replaces: "LiftLogView",
                                note: "Programs, and the 1,324-exercise catalogue behind them.",
                                navigation: navigation)
        }
    }
}

// MARK: - Placeholder

/// Deliberately plain. It states what it is rather than approximating what it will be, because a
/// half-styled placeholder is the one thing worse than an obvious one: it gets screenshotted and
/// compared, and the comparison is meaningless.
private struct NoopLiftPlaceholder: View {
    let route: NoopRoute
    let replaces: String
    let note: String
    @ObservedObject var navigation: NoopNavigation

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Not drawn yet")
                        .font(NoopHTMLFont.outfit(25))
                        .tracking(-0.625)
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(note)
                        .font(NoopHTMLFont.sans(13.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(4.2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    row("Route", route.rawValue)
                    Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                    row("Launch", "--noop-route \(route.rawValue)")
                    Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                    row("Dresses", replaces)
                }
                .padding(16)
                .background(NoopHTMLColor.cardRaised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )

                Button {
                    navigation.reset(to: .today)
                } label: {
                    Text("Back to Today")
                        .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.blueInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(NoopHTMLColor.blue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(NoopHTMLPressStyle())
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(NoopHTMLFont.sans(11.5))
                .foregroundStyle(NoopHTMLColor.muted)
                .frame(width: 66, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(NoopHTMLColor.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
#endif
