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

// MARK: - Noop redesign spec tokens
//
// The companion to `NoopPalette`. The split: `NoopPalette` holds base values a second design could
// reuse; this file holds THIS design's own vocabulary. Nothing here duplicates a palette token —
// where the palette has the value, the screen specs name the palette property directly and this
// file stays silent.
//
// SCHEME-INVARIANT, for the reason `NoopPalette` documents: these screens are a designed
// dark scene, not a dark *mode*. Use `NoopPalette.text*` and `NoopSpecTokens.*` inside them and
// never `StrandPalette`, `NoopVisualStyle` or `HeuteRedesignPalette` — all three flip with the
// system appearance (or with the user's chart style) and would strand light-mode ink on this
// fixed-dark canvas.
//
// Reference geometry is 402 × 874 pt (iPhone 16 Pro logical). One prototype CSS pixel = one point.

public enum NoopSpecTokens {

    // MARK: Surfaces the palette does not carry

    /// Inset panels sitting inside a card — one step quieter than the card itself.
    public static let subtleFill = Color.white.opacity(0.04)
    /// Hairline on a control (chip, back button, secondary button). Fractionally stronger than
    /// `NoopPalette.cardBorder`, because a control has to read as tappable.
    public static let controlBorder = Color.white.opacity(0.09)
    /// The heavier end of the control hairline, for a control that sits on a tinted surface.
    public static let controlBorderStrong = Color.white.opacity(0.10)
    /// Row divider inside a list card. Same value as `cardBorder`, named separately because it is
    /// a different job and the two have drifted apart in review before.
    public static let hairline = Color.white.opacity(0.06)

    /// Tab bar fill, painted OVER a blurred backdrop — not a SwiftUI Material laid on top of this
    /// fill, which adds its own vibrancy tint over a tint. See RULES §5 and `NoopGlass`.
    public static let tabBarFill = Color(hex: "#171C1A").opacity(0.82)
    public static let tabBarBorder = Color.white.opacity(0.09)
    /// The prototype's backdrop radius: `backdrop-filter: blur(20px)`, in all nine act sources.
    /// **Read by exactly one thing** — `NoopGlass(radius:)` in `NoopSpecPrimitives.swift`, which
    /// asserts on it in DEBUG. It is a measurement to check the platform blur against, not a
    /// parameter: UIKit exposes no settable radius. Full reasoning at §10a there.
    public static let tabBarBlurRadius: CGFloat = 20

    // MARK: Text

    /// The design's *secondary* text — body copy and values. `NoopPalette.textSecondary` is the
    /// design's *tertiary*; the two vocabularies disagree and the screen specs use the design's.
    public static let textBody = Color(hex: "#C6CEC9")
    /// Ink for type on a filled aura-blue button. Darker than `NoopPalette.onAccent` because the
    /// fill underneath is the full-strength accent, not a tint.
    public static let onAura = Color(hex: "#04121A")

    // MARK: Hues
    //
    // Each hue means exactly one thing, and the meaning is the part that keeps getting broken:
    //   aura   — the strap, the day, live data, the primary action
    //   blush  — YOU: identity, body, the person. Never a warning.
    //   rest   — sleep, night (`NoopPalette.rest`)
    //   green  — done, confirmed, written
    //   effort — needs attention (`NoopPalette.effort`). Never decoration.
    //   hot    — critical, nearly out

    /// Aura on a dark surface: fills, small figures, the widget ring.
    public static let auraLight = Color(hex: "#8FD3F5")
    /// Aura type sitting on an aura tint.
    public static let auraPale = Color(hex: "#9FE2FB")

    public static let blush = Color(hex: "#E08A9B")
    public static let blushSoft = Color(hex: "#F6D3DA")
    /// Blush at uppercase-caption weight, where full blush would shout.
    public static let blushLabel = Color(hex: "#C08E98")

    /// Lavender type on a lavender tint. The lavender itself is `NoopPalette.rest`.
    public static let lavenderText = Color(hex: "#C9D0EE")

    public static let green = Color(hex: "#8FE3B4")
    /// Green as a surface, which is a different hue from green as type. Anything with real area:
    /// the lit Trends tab, a chart line and its fill, series B, a filled provenance dot.
    public static let greenSurface = Color(red: 46/255, green: 204/255, blue: 128/255)
    /// Ink ON `greenSurface`. Measured against #2ECC80 (9.2:1) — neither white nor `onAura` is.
    public static let onGreen = Color(hex: "#04140C")

    /// Critical / nearly out. The end of the charge ramp and the ≤10 % battery state.
    public static let hot = Color(hex: "#F0742C")

    // MARK: Metrics

    /// Radius ladder. `.continuous` at every use site — RULES §4.
    public enum Radius {
        public static let panel: CGFloat = 26        // panels, tab bar
        public static let hero: CGFloat = 24         // hero card  (= NoopPalette.cardRadius)
        public static let card: CGFloat = 22         // standard card (= NoopPalette.tileRadius)
        public static let inset: CGFloat = 20        // inset card (= NoopPalette.pillarRadius)
        public static let insetAlt: CGFloat = 21
        public static let buttonPrimary: CGFloat = 17
        public static let buttonSecondary: CGFloat = 15
        public static let control: CGFloat = 14      // (= NoopPalette.controlRadius)
        public static let controlSmall: CGFloat = 13
        public static let segment: CGFloat = 11
        public static let chip: CGFloat = 10
        public static let chipSmall: CGFloat = 9
        public static let bar: CGFloat = 6
        public static let barThin: CGFloat = 3
    }

    /// 0.5 pt, a literal — NOT `1 / displayScale`. Drawn with `.strokeBorder`, never `.stroke`.
    public static let hairlineWidth: CGFloat = 0.5
    /// The only two 1 pt strokes in the app: the strap battery glyph and the orb halo ring.
    public static let glyphStrokeWidth: CGFloat = 1

    /// Clears the floating tab bar. Every scroll view ends with this — a literal, not a safe-area
    /// inset and not a `Spacer`.
    public static let scrollBottomInset: CGFloat = 116

    /// Screen header: 56 above (below the status bar), 18 at the sides, 8 below.
    public static let headerInsets = EdgeInsets(top: 56, leading: 18, bottom: 8, trailing: 18)
    /// Gap between the back button and the parent screen's name.
    public static let headerGap: CGFloat = 12
    /// Content column gap for editorial screens; settings-like screens use `NoopPalette.cardGap`.
    public static let editorialGap: CGFloat = 15

    // MARK: The tinted-card rule
    //
    // Every tinted surface in the app is the hue at 7–12 % over base with a 0.5 pt border of the
    // hue at 22–34 %. Computed, never eyeballed — inconsistent tints are otherwise the result.

    public static func tint(_ hue: Color, _ opacity: Double = 0.09) -> Color {
        hue.opacity(opacity)
    }

    public static func tintBorder(_ hue: Color, _ opacity: Double = 0.24) -> Color {
        hue.opacity(opacity)
    }

    // MARK: The charge heat ramp
    //
    // ONE scalar drives the orb, the gauge ticks, the hero numeral, the state chip and the bar.
    // Compute `heat` once per render and pass the resulting colour down; recomputing it per
    // component is how the five elements end up disagreeing by a shade.
    //
    // Deliberately does NOT pass through green (green means "done" elsewhere) and does not
    // desaturate through grey — the blush stop exists to keep the midpoint attractive, because the
    // audience for this design is health-anxious and a grey-to-red ramp reads as a diagnosis.

    /// `clamp((58 − charge) / 40, 0, 1)`
    public static func heat(charge: Double) -> Double {
        min(max((58 - charge) / 40, 0), 1)
    }

    private static let ramp: [(stop: Double, r: Double, g: Double, b: Double)] = [
        (0.00,  47, 178, 240),   // aura
        (0.50, 224, 138, 155),   // blush
        (0.78, 242, 180,  92),   // amber
        (1.00, 240, 116,  44),   // hot
    ]

    /// The level colour for a charge value. Linear interpolation in sRGB between the four stops.
    /// Below 3 % heat it returns the brand accent exactly, so a healthy day is unambiguously blue.
    public static func chargeColor(charge: Double) -> Color {
        let h = heat(charge: charge)
        guard h >= 0.03 else { return NoopPalette.accent }
        guard let upper = ramp.firstIndex(where: { $0.stop >= h }), upper > 0 else {
            return Color(red: ramp[0].r/255, green: ramp[0].g/255, blue: ramp[0].b/255)
        }
        let a = ramp[upper - 1], b = ramp[upper]
        let t = (h - a.stop) / (b.stop - a.stop)
        return Color(
            red:   (a.r + (b.r - a.r) * t) / 255,
            green: (a.g + (b.g - a.g) * t) / 255,
            blue:  (a.b + (b.b - a.b) * t) / 255
        )
    }

    /// The orb's charge core, Ø 176: the same ramp, as the three stops the sphere is filled with.
    /// The deep stop is the level colour at `(0.5, 0.42, 0.34)` of its channels — the prototype's
    /// `Math.round(warm[0] * 0.5)` and its two siblings, kept here so the ramp arithmetic lives in
    /// ONE place. Empty below 3 % heat: no warm layer at all, and the aura sphere shows through.
    public static func chargeCoreStops(charge: Double) -> [Gradient.Stop] {
        let h = heat(charge: charge)
        guard h >= 0.03 else { return [] }
        guard let upper = ramp.firstIndex(where: { $0.stop >= h }), upper > 0 else { return [] }
        let a = ramp[upper - 1], b = ramp[upper]
        let t = (h - a.stop) / (b.stop - a.stop)
        let r = a.r + (b.r - a.r) * t, g = a.g + (b.g - a.g) * t, bl = a.b + (b.b - a.b) * t
        let warm = Color(red: r/255, green: g/255, blue: bl/255)
        let deep = Color(red: (r * 0.5)/255, green: (g * 0.42)/255, blue: (bl * 0.34)/255)
        return [
            .init(color: warm.opacity(0.98), location: 0),
            .init(color: warm.opacity(0.86), location: 0.55),
            .init(color: deep.opacity(0.98), location: 1),
        ]
    }

    // MARK: The words that go with the level
    //
    // THE DESIGN LAYER OWNS THE SLOT. IT DOES NOT OWN THE VERDICT.
    //
    // Every earlier version of this function derived words from the charge number. The last one
    // still did it behind a gate: 70/50/30 buckets for the label, a `minimumNormDays` of 14 and a
    // `normDeltaThreshold` of 8 for the comparison, and a `hasUsualBedtime` flag for the advice.
    // All of those constants were invented here, in a design token file, and none of them has an
    // approved analytic or scientific derivation behind it. A bucket boundary presented as a fact
    // about a body is the same class of error as inventing the sentence outright — it just looks
    // more like arithmetic.
    //
    // So the rule is now flat and there is nothing to gate:
    //
    //   * The LABEL always renders. With no verdict bound it is a RESTATEMENT of the number and
    //     nothing else. It claims nothing, so it needs no evidence.
    //   * The NOTE renders only when analytics supplies one. Absent, it is OMITTED — not softened,
    //     not hedged, omitted. A shorter card is the correct output for a thinner day.
    //   * The RECHARGE figure is a model output. Absent, the whole card that holds it is not built.
    //
    // Removed 7 September and not to be reintroduced anywhere, at any confidence tier:
    //
    //   "Plenty left" / "Enough for the evening" / "Running low" / "Nearly out" as DERIVED labels
    //   "Normal for this hour."                     — claims a personal per-hour norm
    //   "Lower than most days at this hour."        — same
    //   "Higher than most days at this hour."       — same
    //   "Keep tonight easy."                        — advice, from a number holding no plan
    //   "Keep tonight easy and go to bed early."    — advice, plus a bedtime we may not know
    //   "You are running on the last of it. Nothing tonight but sleep."
    //   `minimumNormDays = 14`, `normDeltaThreshold = 8`
    //   `charge + 26` as tonight's recovery         — arithmetic dressed as a projection
    //
    // Gone for good, separately from the rest: "the evening you had planned". Noop reads no
    // calendar and will not, per spec/80-not-in-this-release.md, so no input could ever earn it.
    //
    // The confidence chip (spec/20-primitives.md §15) does NOT make any of this shippable. It
    // qualifies a number the app HAS. It cannot qualify a sentence the app does not have.

    /// A verdict and its sentences, supplied by whoever computed them. Analytics owns every field;
    /// this type exists so the UI has one shape to render and one shape to be missing.
    ///
    /// A `nil` field is not an error and not a gap. It is the specified output when the evidence for
    /// that claim does not exist yet — which, on a fresh install, is all of them.
    public struct ChargeEvidence: Equatable {
        /// A RESTATEMENT of the level, in words analytics can stand behind. Never a bucket, and
        /// never a judgement.
        ///
        /// The level colour is already on the screen — hero numeral, gauge ticks, chip fill — and it
        /// climbs the warm ramp as the charge falls. A worded judgement can therefore contradict it:
        /// "Plenty left" set in the away-from-healthy mauve is two elements of one composition
        /// saying opposite things, and the reader believes the colour. A restatement makes no claim,
        /// so it cannot disagree with anything.
        public let verdict: String?
        /// One or two sentences, each backed by an input analytics actually holds.
        public let note: String?
        /// The morning level a night in bed is modelled to reach. A model output, never `charge + n`.
        public let rechargeTo: Int?

        public init(verdict: String? = nil, note: String? = nil, rechargeTo: Int? = nil) {
            self.verdict = verdict
            self.note = note
            self.rechargeTo = rechargeTo
        }

        /// Nothing bound. The honest default, and what day one looks like.
        public static let none = ChargeEvidence()
    }

    /// The label, and the sentences under it when they exist.
    ///
    /// - Parameters:
    ///   - charge: the current level. Used ONLY to restate itself when no verdict is bound.
    ///   - evidence: what analytics supplied. Default `.none`.
    ///
    /// `label` is never empty and never a guess. `body` is `nil` whenever the note is absent, and a
    /// `nil` body means the caller renders no second line at all.
    public static func chargeWords(charge: Double,
                                   evidence: ChargeEvidence = .none) -> (label: String, body: String?) {
        let restated = "\(Int(charge.rounded())) left"
        return (evidence.verdict ?? restated, evidence.note)
    }

    /// The state line, verbatim per spec/acts/41-act2-day.md §2.1.
    ///
    /// The arithmetic half always renders — the app holds both numbers itself, so it is not a claim
    /// about anything it cannot see. The note is appended only if there is one; with none, the
    /// sentence ends after "left." and that is the finished string, not a truncated one.
    public static func chargeSentence(wake: Int,
                                      charge: Int,
                                      evidence: ChargeEvidence = .none) -> String {
        let arithmetic = "You woke with \(wake) and you have \(charge) left."
        guard let note = evidence.note, !note.isEmpty else { return arithmetic }
        return arithmetic + " " + note
    }

    /// Whether the "tonight puts it back" card is built at all. It is not a card with an em-dash in
    /// it: with no forecast there is nothing to say, so there is no card.
    public static func showsRechargeCard(evidence: ChargeEvidence) -> Bool {
        evidence.rechargeTo != nil
    }

    /// Canonical example strings, for screenshots and the demo build.
    ///
    /// **DEBUG *and* `--demo-seed`, both.** `#if DEBUG` alone is not the gate: a debug build handed
    /// to a reviewer without the flag must show the real absent states, because those are what a new
    /// user sees. Returns `.none` unless both conditions hold, so the fall-through is the honest
    /// path rather than the seeded one.
    ///
    /// If a seeded string is ever reachable in a release build, that is the bug this exists to
    /// prevent — and the reason it returns `ChargeEvidence` rather than formatted text is so it can
    /// only ever be injected at the same seam analytics uses.
    public static func demoChargeEvidence() -> ChargeEvidence {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--demo-seed") else { return .none }
        // ONE SCENARIO, and every string is written against the charge that scenario PRODUCES —
        // not against the inputs that feed it. `charge` is derived (wake − spent(hour)), so a seed
        // pinned to inputs with copy authored for a different charge freezes a false reading in
        // place. That happened twice: "Plenty left" rendered over a charge of 44, in the mauve, with
        // a recharge figure claiming a single night was worth +44.
        //
        // Written for: woke with 92, 44 left at 15.6 h.
        return ChargeEvidence(
            verdict: "Just under half left",
            note: "A normal day of yours has less left than this by mid-afternoon.",
            rechargeTo: 86
        )
        #else
        return .none
        #endif
    }
}
