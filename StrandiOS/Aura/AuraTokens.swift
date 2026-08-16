import SwiftUI

// MARK: - Aura design tokens
//
// A verbatim transcription of the palette and metrics in the "Aura · dark" direction of the Noop design
// project (Noop.dc.html). These are deliberately literal hex values rather than `StrandPalette` tokens:
// the brief is a 1:1 reproduction of a specific generated design, and mapping each colour onto the
// nearest existing token is exactly how a faithful copy becomes an approximation. They live in ONE file
// so the design remains diffable against its source, and so nothing outside `StrandiOS/Aura` inherits
// them by accident.
//
// The old Today keeps `StrandPalette` untouched. These two screens are meant to coexist while the new
// one is finished and wired, and only then does the old one go.
enum Aura {

    // MARK: Surfaces
    /// Page canvas. Near-black with a green cast, not pure black.
    static let page = Color(hex: "#0A0C0B")
    /// Standard card fill.
    static let card = Color(hex: "#141817")
    /// Hairline on every card. .5pt in the design.
    static let cardBorder = Color.white.opacity(0.06)
    /// The Svea card's own gradient + border, which is the one card the design tints.
    static let sveaTop = Color(hex: "#18211E")
    static let sveaBottom = Color(hex: "#121615")

    // MARK: Ink
    static let ink = Color(hex: "#EDF1EF")
    /// Body copy under a heading.
    static let inkSoft = Color(hex: "#8B958F")
    /// Row labels and card overlines.
    static let inkMuted = Color(hex: "#7F8A85")
    /// Units, and the dimmest label rank.
    static let inkFaint = Color(hex: "#6C7570")
    /// The coaching sentence under the state word, and chevron glyphs.
    static let inkCoach = Color(hex: "#939C97")
    /// Ink used ON the accent banner and the Accept button — the page colour, inverted onto blue.
    static let onAccent = Color(hex: "#08120F")

    // MARK: Body-state accents (DKSTATE)
    /// The four measured states, with the fraction the design places each at. Blue at the top is the
    /// point: green/red is a verdict on the wearer, depleted → restored describes a body.
    static let restored = Color(hex: "#17A2E6")   // frac .84
    static let ready    = Color(hex: "#F2B45C")   // frac .60
    static let strained = Color(hex: "#F0742C")   // frac .38
    static let depleted = Color(hex: "#E0705C")   // frac .16

    /// Pillar accents. Rest is the design's indigo; Effort its amber; Charge takes the state accent.
    static let restAccent   = Color(hex: "#8B99D6")
    static let effortAccent = Color(hex: "#F2B45C")

    /// The state accent for a 0...1 charge fraction, stepping through the four states at the design's
    /// own thresholds rather than interpolating — the design names four states, so a value belongs to
    /// one of them rather than sitting between two.
    static func accent(forCharge frac: Double?) -> Color {
        guard let frac else { return inkFaint }
        switch frac {
        case ..<0.27:  return depleted
        case ..<0.49:  return strained
        case ..<0.72:  return ready
        default:       return restored
        }
    }

    /// The word the design shows under the orb for each state.
    static func stateLabel(forCharge frac: Double?) -> String {
        guard let frac else { return String(localized: "No data") }
        switch frac {
        case ..<0.27:  return String(localized: "Depleted")
        case ..<0.49:  return String(localized: "Strained")
        case ..<0.72:  return String(localized: "Ready")
        default:       return String(localized: "Restored")
        }
    }

    // MARK: Type
    // The design sets numerals in Outfit, which NOOP does not bundle and which cannot ship with an
    // anonymous sideload without adding a font licence to the repo. `.rounded` is the closest system
    // face: same geometric, low-contrast character, and it carries the tabular figures the design's
    // numerals rely on. Weights and tracking are the design's.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    // MARK: Metrics
    static let screenHPadding: CGFloat = 20
    static let cardRadius: CGFloat = 24
    static let pillarRadius: CGFloat = 20
    static let cardGap: CGFloat = 12
}
