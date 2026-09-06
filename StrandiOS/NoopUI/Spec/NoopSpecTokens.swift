import SwiftUI

// MARK: - Noop redesign spec tokens
//
// ADDITIVE to `AuraPalette`. Nothing here replaces an existing token: where Aura already has the
// value the redesign needs, the screen specs name the Aura property directly and this file stays
// silent. What follows is only what Aura does not yet carry.
//
// SCHEME-INVARIANT, for the reason `AuraPalette` already documents: these screens are a designed
// dark scene, not a dark *mode*. Use `AuraPalette.text*` and `NoopSpecTokens.*` inside them and
// never `StrandPalette`, `NoopVisualStyle` or `HeuteRedesignPalette` — all three flip with the
// system appearance (or with the user's chart style) and would strand light-mode ink on this
// fixed-dark canvas.
//
// Reference geometry is 402 × 874 pt (iPhone 16 Pro logical). One prototype CSS pixel = one point.

public enum NoopSpecTokens {

    // MARK: Surfaces not yet in AuraPalette

    /// Inset panels sitting inside a card — one step quieter than the card itself.
    public static let subtleFill = Color.white.opacity(0.04)
    /// Hairline on a control (chip, back button, secondary button). Fractionally stronger than
    /// `AuraPalette.cardBorder`, because a control has to read as tappable.
    public static let controlBorder = Color.white.opacity(0.09)
    /// The heavier end of the control hairline, for a control that sits on a tinted surface.
    public static let controlBorderStrong = Color.white.opacity(0.10)
    /// Row divider inside a list card. Same value as `cardBorder`, named separately because it is
    /// a different job and the two have drifted apart in review before.
    public static let hairline = Color.white.opacity(0.06)

    /// Tab bar fill, painted OVER a 20 pt gaussian blur — not `.ultraThinMaterial`, which carries
    /// its own tint and a much wider radius. See RULES §5.
    public static let tabBarFill = Color(hex: "#171C1A").opacity(0.82)
    public static let tabBarBorder = Color.white.opacity(0.09)
    /// The gaussian radius the tab bar's backdrop is blurred by.
    public static let tabBarBlurRadius: CGFloat = 20

    // MARK: Text

    /// The design's *secondary* text — body copy and values. `AuraPalette.textSecondary` is the
    /// design's *tertiary*; the two vocabularies disagree and the screen specs use the design's.
    public static let textBody = Color(hex: "#C6CEC9")
    /// Ink for type on a filled aura-blue button. Darker than `AuraPalette.onAccent` because the
    /// fill underneath is the full-strength accent, not a tint.
    public static let onAura = Color(hex: "#04121A")

    // MARK: Hues
    //
    // Each hue means exactly one thing, and the meaning is the part that keeps getting broken:
    //   aura   — the strap, the day, live data, the primary action
    //   blush  — YOU: identity, body, the person. Never a warning.
    //   rest   — sleep, night (`AuraPalette.rest`)
    //   green  — done, confirmed, written
    //   effort — needs attention (`AuraPalette.effort`). Never decoration.
    //   hot    — critical, nearly out

    /// Aura on a dark surface: fills, small figures, the widget ring.
    public static let auraLight = Color(hex: "#8FD3F5")
    /// Aura type sitting on an aura tint.
    public static let auraPale = Color(hex: "#9FE2FB")

    public static let blush = Color(hex: "#E08A9B")
    public static let blushSoft = Color(hex: "#F6D3DA")
    /// Blush at uppercase-caption weight, where full blush would shout.
    public static let blushLabel = Color(hex: "#C08E98")

    /// Lavender type on a lavender tint. The lavender itself is `AuraPalette.rest`.
    public static let lavenderText = Color(hex: "#C9D0EE")

    public static let green = Color(hex: "#8FE3B4")
    /// Green as a surface, which is a different hue from green as type.
    public static let greenSurface = Color(red: 46/255, green: 204/255, blue: 128/255)

    /// Critical / nearly out. The end of the charge ramp and the ≤10 % battery state.
    public static let hot = Color(hex: "#F0742C")

    // MARK: Metrics

    /// Radius ladder. `.continuous` at every use site — RULES §4.
    public enum Radius {
        public static let panel: CGFloat = 26        // panels, tab bar
        public static let hero: CGFloat = 24         // hero card  (= AuraPalette.cardRadius)
        public static let card: CGFloat = 22         // standard card (= AuraPalette.tileRadius)
        public static let inset: CGFloat = 20        // inset card (= AuraPalette.pillarRadius)
        public static let insetAlt: CGFloat = 21
        public static let buttonPrimary: CGFloat = 17
        public static let buttonSecondary: CGFloat = 15
        public static let control: CGFloat = 14      // (= AuraPalette.controlRadius)
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
    /// Content column gap for editorial screens; settings-like screens use `AuraPalette.cardGap`.
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
        guard h >= 0.03 else { return AuraPalette.accent }
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

    /// The words that go with the level. `body` is nil at the top of the range, where the act's own
    /// coach line takes the slot instead. Copy is FINAL — rewording is a bug, same as a wrong hex.
    public static func chargeWords(charge: Double) -> (label: String, body: String?) {
        switch charge {
        case 70...:
            return ("Plenty left", nil)
        case 50..<70:
            return ("Enough for the evening",
                    "Normal for this hour. Enough for the evening you had planned.")
        case 30..<50:
            return ("Running low",
                    "Lower than most days at this hour. Keep tonight easy and go to bed early.")
        default:
            return ("Nearly out",
                    "You are running on the last of it. Nothing tonight but sleep.")
        }
    }
}
