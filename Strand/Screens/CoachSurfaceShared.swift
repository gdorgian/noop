//  CoachSurfaceShared.swift
//  NOOP · Noop Aura
//
//  Coach pieces that other screens depend on, kept OUT of `CoachView.swift`.
//
//  WHY THIS FILE EXISTS. These three used to live inside this fork's `CoachView.swift`. The v11.7 merge
//  keeps upstream's coach screen — the iOS shell draws Svea itself, so that screen renders only on macOS
//  and there is no reason to carry a second copy of it — but `CoachRadius`, the goal-onboarding key and
//  `coachCover` are not screen internals: `CoachPlanView`, `CoachGoalOnboardingFlow`,
//  `CoachGoalJourneyView` and `CoachEntry` all read them.
//
//  Hosting them here rather than re-adding them to the upstream screen means the next upstream sync
//  touches one file this fork does not own, instead of colliding with fork-only declarations buried in
//  it. Behaviour is unchanged: these are the same definitions, moved.

import SwiftUI
import StrandDesign

/// One source of truth for the coach UI's corner radii, so bubbles / composer / cards don't scatter
/// magic numbers. Kept local to Coach rather than added to the shared design system.
enum CoachRadius {
    static let bubble: CGFloat = 18
    static let card: CGFloat = 18
    static let field: CGFloat = 20
    /// The ONE tight corner on the speaker's side. Small enough to read as a tail, large enough not to
    /// look like a clipping bug at the accessibility text sizes.
    static let tail: CGFloat = 5
}

extension CoachView {
    /// Set once the goal-onboarding offer has been made, so it is offered exactly one time and never
    /// re-asked on a later launch. Read by `CoachGoalJourneyView`.
    static let goalOnboardingAskedKey = "coach.goalOnboardingAsked"
}

extension View {
    /// Present the coach chat over a screen: fullScreenCover on iOS, a sheet on macOS (no
    /// fullScreenCover there). The engine is passed in (a `View` extension can't read the caller's
    /// @EnvironmentObject) and re-injected so the presented chat inherits it.
    @ViewBuilder func coachCover(isPresented: Binding<Bool>, coach: AICoachEngine) -> some View {
        let content = NavigationStack {
            CoachView()
                .environmentObject(coach)
                // Opening the chat IS having seen it — that's what clears the badge. Doing it here
                // rather than per-entry-point means every route (Today card, floating button, More tab,
                // notification deep link) clears it identically.
                .onAppear { coach.markCoachMessagesSeen() }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { isPresented.wrappedValue = false }
                    }
                }
        }
        #if os(iOS)
        self.fullScreenCover(isPresented: isPresented) { content }
        #else
        self.sheet(isPresented: isPresented) { content }
        #endif
    }
}
