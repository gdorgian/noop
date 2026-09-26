import SwiftUI
// No UIKit and no CoreText here on purpose: SwiftUI is complete for this file. Only
// NoopSpecType.swift needs either, and it imports both explicitly.

// MARK: - NoopPalette — the base palette for the redesign
//
// WHERE THIS FILE GOES: Packages/StrandDesign/Sources/StrandDesign/Aura/NoopPalette.swift
//
// WHAT THIS IS. The base colour and metric values for the redesigned screens: surfaces, the text
// ramp, three hues, the orb stops, the radii and spacings. Seventy lines of constants and nothing
// else — no components, no screens, no body-state type, no copy, no behaviour, and no motion
// durations. It carries ONE gradient ramp, the orb's; the app's other gradients are card and glow
// treatments rather than palette values, and they are registered in spec/10-tokens.md
// §Gradients and shadows, as built. Do not read "one ramp here" as "one gradient in the app".
//
// It supplies the values the old `AuraPalette` happened to hold, which commit 1ecb5712 deleted along
// with the rest of the Aura layer. It is NOT that file back under a new name: the old layer is
// intentionally gone and nothing in this pack depends on any other part of it.
//
// WHAT IT DELIBERATELY DOES NOT RESTORE. The old components, charts, orb view and screens, and the
// old body-state type with its four cases, its verdict/coaching/session strings and its per-state
// ramps. This redesign supersedes all of it: copy is governed by `spec/70-copy.md` and the
// generated-string tables in `Noop - Build Document.dc.html`, and the temperature ramp is
// `NoopSpecTokens.chargeColor(charge:)` driven by one scalar. The old type had four hard-coded
// states; the redesign interpolates. Restoring it would put two ramps in the app.
//
// SCHEME-INVARIANT. These screens are a designed dark scene, not a dark *mode* — canvas, cards, type
// and glow are lit as one composition. Nothing here is a `Color(light:dark:)` pair, and nothing in
// an Aura screen may use `StrandPalette`, `NoopVisualStyle` or `HeuteRedesignPalette`: all three flip
// with the system appearance (or the user's chart style) and would strand light-mode ink on this
// fixed-dark canvas. A light Aura was never specified, so none is guessed at here.
//
// NO DEPENDENCIES. Every value is an explicit sRGB literal through the private helper below, so this
// file compiles on its own — it does not need `Color(hex:)` from `Palette.swift`, and it cannot
// collide with that extension. (The other four files in the pack DO use `Color(hex:)`; see
// spec/13-branch-corrected-foundation.md.)

public enum NoopPalette {

    // MARK: Surfaces

    /// The scene canvas — near-black, faintly green, never pure black.
    public static let canvas = srgb(10, 12, 11)              // #0A0C0B
    /// Standard card fill. Cards float just clear of the canvas rather than being outlined.
    public static let card = srgb(20, 24, 23)                // #141817
    /// Hairline around a card. Half-point at the use site, so it reads as an edge, not a border.
    public static let cardBorder = Color.white.opacity(0.06)
    /// Fill for a secondary control: back-button disc, secondary/destructive button, unselected
    /// range chip, `Soon` chip, Svea's ask field. One rung of a six-step ladder — see
    /// spec/12-palette-bindings.md before substituting a neighbour.
    public static let controlFill = Color.white.opacity(0.07)
    /// The unlit portion of a track — gauge ticks, pillar bars, week bars, a toggle that is off.
    public static let track = Color.white.opacity(0.13)

    // NO COACH SURFACE TOKENS. `coachSurfaceTop` #18211E and `coachSurfaceBottom` #121615 were here
    // and are DELETED (8 September). They named a near-black vertical ramp that appears in no act
    // source. The treatment actually on `today` and in `svea/coach` is the 158° directional accent
    // card — lavender at 16 % over lavender at 3 %, 0.5 pt lavender-30 % border — which is a card
    // treatment, not a pair of surface colours: see NoopAccentCard in NoopSpecPrimitives.swift and
    // spec/10-tokens.md §Gradients and shadows, as built. Re-pointing the tokens was rejected: a
    // token called *coach surface* whose value is a different composition is worse than no token.

    // MARK: Text — a six-step ramp down from the state label to axis ticks
    //
    // The design's own vocabulary and these property names disagree by one rung, and the mapping in
    // spec/10-tokens.md is binding: `textSecondary` here is the design's TERTIARY. The design's
    // secondary (#C6CEC9) is `NoopSpecTokens.textBody`.

    public static let textPrimary = srgb(237, 241, 239)      // #EDF1EF
    public static let textSecondary = srgb(147, 156, 151)    // #939C97
    public static let textTertiary = srgb(139, 149, 143)     // #8B958F
    public static let textQuiet = srgb(127, 138, 133)        // #7F8A85
    public static let textFaint = srgb(108, 117, 112)        // #6C7570
    /// Axis labels and other type that should be present but never read first.
    public static let textDim = srgb(87, 96, 92)             // #57605C

    /// Ink for type sitting ON an accent TINT. Ink on a full-strength accent fill is
    /// `NoopSpecTokens.onAura` (#04121A), which is darker on purpose.
    public static let onAccent = srgb(8, 18, 15)             // #08120F

    // MARK: Hues — each means exactly one thing, and the meaning is the part that breaks

    /// The chrome accent: the strap, the day, live data, the primary action. FIXED — it does not
    /// follow body state. A screen that recolours its chrome with the body spends the signal on
    /// furniture; the orb is the only thing that changes colour.
    public static let accent = srgb(23, 162, 230)            // #17A2E6
    /// Sleep, night.
    public static let rest = srgb(139, 153, 214)             // #8B99D6
    /// Needs attention. Never decoration, and never confidence — see spec/10-tokens.md.
    public static let effort = srgb(242, 180, 92)            // #F2B45C

    // MARK: The orb
    //
    // Replaces the deleted body-state type's `restored.orbStops`, which the spec used to point at.
    // Three stops, mid at 55 %, lit from upper-left so it reads as a sphere rather than a disc.
    // The redesign draws ONE
    // orb ramp and takes its colour from `NoopSpecTokens.chargeColor(charge:)` — there is no
    // per-state variant to restore.

    public static let orbStops: [Gradient.Stop] = [
        .init(color: srgb(159, 226, 251), location: 0),       // #9FE2FB
        .init(color: srgb(47, 178, 240), location: 0.55),     // #2FB2F0
        .init(color: srgb(10, 95, 146), location: 1),         // #0A5F92
    ]

    // MARK: Metrics

    public static let cardRadius: CGFloat = 24
    public static let tileRadius: CGFloat = 22
    public static let pillarRadius: CGFloat = 20
    public static let controlRadius: CGFloat = 14
    /// Horizontal page margin for an Aura screen.
    public static let screenPadding: CGFloat = 20
    /// Vertical gap between stacked cards.
    public static let cardGap: CGFloat = 12
    // THE TWO ORB DURATIONS ARE NOT HERE ANY MORE, and that is the fix for a real contradiction:
    // this file said breathDuration = 6 while NoopSpecMotion said 16, and both were public. The
    // breath is 16 s — four 4 s box phases (20-primitives.md §11) — so the 6 was simply wrong, and
    // a duplicated timing is how it survived. Timings live in ONE type:
    //
    //   NoopSpecMotion.breathDuration  16 s   one whole breath
    //   NoopSpecMotion.breathPhase      4 s   in · hold · out · hold
    //   NoopSpecMotion.sheenDuration   24 s   one sheen rotation, incommensurate on purpose

    // MARK: -

    /// 0–255 sRGB, so this file needs no hex initialiser from anywhere else.
    private static func srgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: 1)
    }
}
