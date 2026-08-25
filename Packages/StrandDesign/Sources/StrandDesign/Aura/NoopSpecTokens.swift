import SwiftUI

// MARK: - Noop Aura redesign tokens
//
// These tokens are additive to `AuraPalette`. The designer handoff was authored against an older
// palette whose semantic property names no longer match this branch, so this file deliberately aliases
// the CURRENT palette by visual role. Screens should use these role names instead of relying on a stale
// property-name mapping.

public enum NoopSpecTokens {

    // MARK: Surfaces

    public static let canvas = AuraPalette.canvas
    public static let card = AuraPalette.card
    public static let cardBorder = AuraPalette.cardBorder
    public static let subtleFill = Color.white.opacity(0.04)
    public static let controlFill = Color.white.opacity(0.06)
    public static let controlBorder = Color.white.opacity(0.09)
    public static let controlBorderStrong = Color.white.opacity(0.10)
    public static let hairline = Color.white.opacity(0.06)

    /// The binding primitive spec uses 13% white for an off toggle track.
    public static let controlTrack = Color.white.opacity(0.13)

    /// Painted above the tab bar's blur layer.
    public static let tabBarFill = Color(hex: "#171C1A").opacity(0.82)
    public static let tabBarBorder = Color.white.opacity(0.09)
    public static let tabBarBlurRadius: CGFloat = 20

    // MARK: Text

    public static let textPrimary = AuraPalette.textPrimary       // #EDF1EF
    public static let textBody = AuraPalette.textSecondary        // #C6CEC9
    public static let textTertiary = AuraPalette.textTertiary     // #939C97
    public static let textLabel = AuraPalette.textLabel           // #8B958F
    public static let textQuiet = AuraPalette.textQuiet            // #7F8A85
    public static let textDim = AuraPalette.textFaint              // #6C7570
    public static let textFaint = AuraPalette.textDim              // #57605C
    public static let onAura = Color(hex: "#04121A")

    // MARK: Semantic hues

    public static let aura = AuraPalette.accent
    public static let auraLight = Color(hex: "#8FD3F5")
    public static let auraPale = Color(hex: "#9FE2FB")
    public static let blush = Color(hex: "#E08A9B")
    public static let blushSoft = Color(hex: "#F6D3DA")
    public static let blushLabel = Color(hex: "#C08E98")
    public static let lavender = AuraPalette.rest
    public static let lavenderText = Color(hex: "#C9D0EE")
    public static let green = Color(hex: "#8FE3B4")
    public static let greenSurface = Color(red: 46 / 255, green: 204 / 255, blue: 128 / 255)
    public static let attention = AuraPalette.effort
    public static let hot = Color(hex: "#F0742C")

    // MARK: Metrics

    public enum Radius {
        public static let panel: CGFloat = 26
        public static let hero: CGFloat = 24
        public static let card: CGFloat = 22
        public static let inset: CGFloat = 20
        public static let insetAlt: CGFloat = 21
        public static let buttonPrimary: CGFloat = 17
        public static let buttonSecondary: CGFloat = 15
        public static let control: CGFloat = 14
        public static let controlSmall: CGFloat = 13
        public static let segment: CGFloat = 11
        public static let chip: CGFloat = 10
        public static let chipSmall: CGFloat = 9
        public static let bar: CGFloat = 6
        public static let barThin: CGFloat = 3
    }

    public static let hairlineWidth: CGFloat = 0.5
    public static let glyphStrokeWidth: CGFloat = 1
    public static let screenPadding: CGFloat = 20
    public static let cardGap: CGFloat = 12
    public static let editorialGap: CGFloat = 15
    public static let scrollBottomInset: CGFloat = 116
    public static let headerInsets = EdgeInsets(top: 56, leading: 18, bottom: 8, trailing: 18)
    public static let headerGap: CGFloat = 12

    // MARK: Tinted surfaces

    public static func tint(_ hue: Color, opacity: Double = 0.09) -> Color {
        hue.opacity(opacity)
    }

    public static func tintBorder(_ hue: Color, opacity: Double = 0.24) -> Color {
        hue.opacity(opacity)
    }

    // MARK: Charge colour ramp
    //
    // This is presentation only. It does not create or deplete Charge; callers must provide a real
    // stored score. Daytime depletion remains unavailable until a validated model exists.

    public static func chargeHeat(_ charge: Double) -> Double {
        min(max((58 - charge) / 40, 0), 1)
    }

    private static let chargeRamp: [(stop: Double, red: Double, green: Double, blue: Double)] = [
        (0.00, 47, 178, 240),
        (0.50, 224, 138, 155),
        (0.78, 242, 180, 92),
        (1.00, 240, 116, 44),
    ]

    public static func chargeColor(_ charge: Double) -> Color {
        let heat = chargeHeat(charge)
        guard heat >= 0.03 else { return aura }
        guard let upper = chargeRamp.firstIndex(where: { $0.stop >= heat }), upper > 0 else {
            let first = chargeRamp[0]
            return Color(red: first.red / 255, green: first.green / 255, blue: first.blue / 255)
        }

        let lowerStop = chargeRamp[upper - 1]
        let upperStop = chargeRamp[upper]
        let progress = (heat - lowerStop.stop) / (upperStop.stop - lowerStop.stop)
        return Color(
            red: (lowerStop.red + (upperStop.red - lowerStop.red) * progress) / 255,
            green: (lowerStop.green + (upperStop.green - lowerStop.green) * progress) / 255,
            blue: (lowerStop.blue + (upperStop.blue - lowerStop.blue) * progress) / 255
        )
    }
}
