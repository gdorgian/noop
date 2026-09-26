import SwiftUI
// No UIKit and no CoreText here on purpose: SwiftUI is complete for this file. Only
// NoopSpecType.swift needs either, and it imports both explicitly.

// WHERE THIS FILE GOES: Packages/StrandDesign/Sources/StrandDesign/Aura/
//
// Inside the StrandDesign package, beside NoopPalette.swift. Commit 1ecb5712 deleted the old Aura
// layer — AuraPalette.swift with it — so the palette now travels with this pack as NoopPalette:
// a palette-only file, no components and no body-state type. `import SwiftUI` is then complete and no target dependency or
// project.yml entry is needed (SPM globs Sources/StrandDesign/). Compiled into an app target instead,
// every `NoopPalette` reference fails with "cannot find in scope", which looks exactly like a missing
// palette file. See spec/13-branch-corrected-foundation.md, then spec/12-palette-bindings.md.

// MARK: - Noop redesign motion
//
// Six curves cover all 69 screens. Two of them are missed most often and both are visible:
// the 9 pt screen-enter rise, and the toggle's split timing (track and knob on DIFFERENT curves).
// A stock `Toggle` gets neither, which is most of why controls in the build feel generic.
//
// Every duration below is the prototype's, and the prototype is the spec. Reduce Motion overrides
// are at the bottom and are not optional — see RULES §10.

public enum NoopSpecMotion {

    /// Screen enter: 9 pt rise + fade, 300 ms. Pair with `NoopSpecMotion.enterTransition`.
    public static let enter = Animation.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.30)
    /// The rise distance that goes with `enter`.
    public static let enterRise: CGFloat = 9

    /// Bottom sheet: `translateY(102%)` → 0. 102 % so the sheet's own shadow clears the edge.
    public static let sheet = Animation.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.34)

    /// Toggle TRACK — a plain material curve, 220 ms.
    public static let toggleTrack = Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.22)
    /// Toggle KNOB — 240 ms with a slight overshoot. The knob arrives after the track has changed
    /// colour, which is what makes the control feel physical.
    public static let toggleKnob = Animation.timingCurve(0.34, 1.25, 0.64, 1, duration: 0.24)

    /// Segmented pick: background, border and colour together, 180 ms ease.
    public static let segment = Animation.easeInOut(duration: 0.18)

    /// One charge gauge tick changing state: 280 ms, background + opacity.
    public static let gaugeTick = Animation.easeInOut(duration: 0.28)
    /// The charge bar's width.
    public static let chargeBar = Animation.easeInOut(duration: 0.50)
    /// The arrival drain on Today: wake → now, 1150 ms ease-out-cubic. ON ARRIVAL ONLY — never on
    /// a value change while the screen is already up, and never when returning from a pushed screen.
    public static let chargeDrain = Animation.timingCurve(0.215, 0.61, 0.355, 1, duration: 1.15)

    /// Box breathing: 16 s, four 4 s phases (In · Hold · Out · Hold).
    public static let breathDuration: Double = 16
    public static let breathPhase: Double = 4
    /// The orb's specular sheen, a 24 s linear rotation at `.overlay` blend. Incommensurate with
    /// the breath on purpose, so the two never resynchronise into a visible beat.
    public static let sheenDuration: Double = 24

    // MARK: Reduce Motion

    /// Screen enter under Reduce Motion: a plain 200 ms fade, no rise.
    public static let enterReduced = Animation.easeOut(duration: 0.20)
    /// The charge drain under Reduce Motion: the final value, faded in over 200 ms. Do not animate
    /// the numeral or the ticks.
    public static let chargeDrainReduced = Animation.easeOut(duration: 0.20)
    /// Under Reduce Motion the orb holds at this scale — the midpoint of its breath — while the
    /// phase WORD keeps advancing on the same 4 s cadence. The information survives; the movement
    /// does not.
    public static let breathHeldScale: CGFloat = 1.0
}
