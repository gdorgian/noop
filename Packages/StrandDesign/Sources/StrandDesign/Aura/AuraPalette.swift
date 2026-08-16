import SwiftUI

// MARK: - Aura palette — the body-state design language
//
// Aura answers one brief: "Whoop is too complicated". The home screen therefore carries NO score. The
// body gets one colour, one sentence and one instruction; every number lives a tap deeper, on the screen
// the user went looking for. These tokens are what that costs in colour.
//
// SCHEME-INVARIANT ON PURPOSE. Every other surface in NOOP is a `Color(light:dark:)` pair that flips with
// the system appearance. Aura does not: it is a designed dark scene — canvas, cards, type and glow are lit
// as one composition, the way a photo viewer is — and the direction was specified dark throughout. Pinning
// the scene is therefore not the #1160 mistake (a near-black card marooned on an otherwise light screen);
// there is no light surface for these to disagree with, because the whole screen is the scene. A light Aura
// was never specified, so none is guessed at here.
//
// Consequently: use `AuraPalette.text*` inside an Aura screen, NOT `StrandPalette.text*`. The latter flips
// to dark ink in Light mode and would vanish against this fixed-dark canvas — the same trap #1013 records.

public enum AuraPalette {

    // MARK: Surfaces

    /// The scene canvas — near-black, faintly green, never pure black.
    public static let canvas = Color(hex: "#0A0C0B")
    /// Standard card fill. Cards float just clear of the canvas rather than being outlined.
    public static let card = Color(hex: "#141817")
    /// Hairline around a card. Half-point at the use site, so it reads as an edge and not a border.
    public static let cardBorder = Color.white.opacity(0.06)
    /// Fill for secondary controls (Swap / Rest buttons, chevron discs, unselected range chips).
    public static let controlFill = Color.white.opacity(0.07)
    /// The unlit portion of a track — gauge ticks, pillar bars, week bars.
    public static let track = Color.white.opacity(0.13)

    /// The coaching card's gradient, which lifts it off the flat card fill so Svea's call reads as the
    /// screen's one instruction rather than one more panel.
    public static let coachSurfaceTop = Color(hex: "#18211E")
    public static let coachSurfaceBottom = Color(hex: "#121615")

    // MARK: Text — a five-step ramp down from the state label to axis ticks

    public static let textPrimary = Color(hex: "#EDF1EF")
    public static let textSecondary = Color(hex: "#939C97")
    public static let textTertiary = Color(hex: "#8B958F")
    public static let textQuiet = Color(hex: "#7F8A85")
    public static let textFaint = Color(hex: "#6C7570")
    /// Axis labels and other type that should be present but never read first.
    public static let textDim = Color(hex: "#57605C")

    /// Ink for type sitting ON an accent fill (the info banner, the Accept button, the active tab).
    public static let onAccent = Color(hex: "#08120F")

    // MARK: Pillar identity
    //
    // Rest and Effort keep their own hue across every Aura screen so a colour means the same thing
    // wherever it appears. Charge has no fixed colour — it takes the body state's accent, because Charge
    // IS the body state.

    public static let rest = Color(hex: "#8B99D6")
    public static let effort = Color(hex: "#F2B45C")

    // MARK: Metrics

    public static let cardRadius: CGFloat = 24
    public static let pillarRadius: CGFloat = 20
    public static let tileRadius: CGFloat = 22
    public static let controlRadius: CGFloat = 14
    /// Horizontal page margin for an Aura screen.
    public static let screenPadding: CGFloat = 20
    /// Vertical gap between stacked cards.
    public static let cardGap: CGFloat = 12
    /// One breath of the orb. Slow enough to read as breathing rather than as a pulse — an earlier
    /// heartbeat cut (1.03s, ≈58bpm) was rejected in review as too fast to sit under a resting screen.
    public static let breathDuration: Double = 6
    /// One rotation of the orb's specular sheen. Deliberately incommensurate with `breathDuration`, so
    /// the two never resynchronise into a visible beat.
    public static let sheenDuration: Double = 24
}

// MARK: - Aura body state
//
// The four states the orb can show. This is a TEMPERATURE, not a traffic light: it runs cool-blue when
// the body has room and warms through amber to clay as it runs out. Nothing in the ramp goes red — the
// audience for this direction is explicitly health-anxious, and a red screen is the thing that made them
// bounce off the incumbent.

public enum AuraBodyState: String, CaseIterable, Identifiable, Sendable {
    case restored
    case ready
    case strained
    case depleted

    public var id: String { rawValue }

    /// The state's accent. Chrome across the whole screen follows this — tabs, banners, the Accept
    /// button, the trend line — so the app is visibly a different temperature on a bad day.
    public var accent: Color {
        switch self {
        case .restored: return Color(hex: "#17A2E6")
        case .ready:    return Color(hex: "#F2B45C")
        case .strained: return Color(hex: "#F0742C")
        case .depleted: return Color(hex: "#E0705C")
        }
    }

    /// Where the marker sits along the tick arc (0 = the depleted end, 1 = fully restored).
    public var gaugeFraction: Double {
        switch self {
        case .restored: return 0.84
        case .ready:    return 0.60
        case .strained: return 0.38
        case .depleted: return 0.16
        }
    }

    /// The orb's own body. Lit from upper-left, so it reads as a sphere rather than a disc.
    public var orbStops: [Gradient.Stop] {
        switch self {
        case .restored: return Self.stops("#9FE2FB", "#2FB2F0", "#0A5F92")
        case .ready:    return Self.stops("#F8E0B4", "#E9B96A", "#A97B2C")
        case .strained: return Self.stops("#F6CCA8", "#EE9457", "#B2551F")
        case .depleted: return Self.stops("#F1BDAF", "#DD7A63", "#93372A")
        }
    }

    /// Peak opacity of the halo that breathes with the orb.
    public var glowOpacity: Double {
        switch self {
        case .restored: return 0.44
        case .ready:    return 0.36
        case .strained: return 0.34
        case .depleted: return 0.32
        }
    }

    /// The cast shadow under the orb, and how far it spreads.
    public var orbShadow: (color: Color, radius: CGFloat, y: CGFloat) {
        switch self {
        case .restored: return (Color(hex: "#0B6FA8").opacity(0.55), 26, 18)
        case .ready:    return (Color(hex: "#A97B2C").opacity(0.42), 26, 18)
        case .strained: return (Color(hex: "#B2551F").opacity(0.42), 26, 18)
        case .depleted: return (Color(hex: "#93372A").opacity(0.42), 26, 18)
        }
    }

    /// Opacity of the ambient wash bled behind the screen's header. Faint by design — it should tint
    /// the top of the screen without ever being noticed as a shape.
    public var ambientOpacity: Double {
        switch self {
        case .restored: return 0.16
        case .ready:    return 0.13
        case .strained: return 0.12
        case .depleted: return 0.12
        }
    }

    // MARK: Voice
    //
    // Svea says what to do in one line and offers the receipt second. Never "HRV 45% over baseline" as
    // an opener — that phrasing is the complexity this direction exists to remove.

    /// The verdict. Two words where possible; this is the largest type on the screen.
    public var label: String {
        switch self {
        case .restored: return String(localized: "Well restored", bundle: .module)
        case .ready:    return String(localized: "Steady", bundle: .module)
        case .strained: return String(localized: "Running warm", bundle: .module)
        case .depleted: return String(localized: "Needs a day", bundle: .module)
        }
    }

    /// The instruction that follows the verdict.
    public var coaching: String {
        switch self {
        case .restored:
            return String(localized: "Your body has room today. Good day to ask something of it.", bundle: .module)
        case .ready:
            return String(localized: "Nothing’s off. Train as planned, just don’t chase a record.", bundle: .module)
        case .strained:
            return String(localized: "Keep it light today. One easy session, then leave it alone.", bundle: .module)
        case .depleted:
            return String(localized: "Take the day off. This is the cheapest fix you’ll get.", bundle: .module)
        }
    }

    /// The session Svea proposes for the day.
    public var session: String {
        switch self {
        case .restored: return String(localized: "Strength, moderate — go for a real set", bundle: .module)
        case .ready:    return String(localized: "Zone 2, 45 minutes — keep it conversational", bundle: .module)
        case .strained: return String(localized: "Easy walk or mobility — nothing above a chat pace", bundle: .module)
        case .depleted: return String(localized: "Rest day — walk if you want, that’s all", bundle: .module)
        }
    }

    /// The receipt: why that session, in plain language and without a single unit.
    public var sessionRationale: String {
        switch self {
        case .restored:
            return String(localized: "Heart rhythm is well above your normal, you slept a full night, and yesterday was easy.", bundle: .module)
        case .ready:
            return String(localized: "Everything sits inside your normal range. No reason to hold back, no reason to push.", bundle: .module)
        case .strained:
            return String(localized: "Three harder days in a row and a short night. Not a problem yet, just a full cup.", bundle: .module)
        case .depleted:
            return String(localized: "Heart rhythm is well below your normal and you’re two short nights in. Rest is the session.", bundle: .module)
        }
    }

    /// Three-stop radial ramp, positioned to match the direction's orb (mid stop at 55%).
    private static func stops(_ inner: String, _ mid: String, _ outer: String) -> [Gradient.Stop] {
        [
            .init(color: Color(hex: inner), location: 0),
            .init(color: Color(hex: mid), location: 0.55),
            .init(color: Color(hex: outer), location: 1),
        ]
    }
}
