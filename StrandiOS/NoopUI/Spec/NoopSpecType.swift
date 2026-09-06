import SwiftUI

// MARK: - Noop redesign type scale
//
// Two families plus one accent:
//   Outfit           200/300/400/500 — every numeral, every screen title, every large figure
//   Instrument Sans  400/500/600     — all UI text, labels, body copy, buttons
//   Instrument Serif italic          — prototype commentary ONLY. Never in the app.
//
// THREE THINGS THIS FILE EXISTS TO STOP GETTING WRONG (RULES §1, §2, §6):
//
// 1. Tracking is in POINTS. The design writes `-.02em`; `.tracking()` wants points, so every role
//    below carries the multiplied value. Use `.tracking()`, never `.kerning()` — kerning skips the
//    trailing edge of a run and differs on centred text.
// 2. `lineSpacing` is not line height. CSS `line-height: 1.5` is the TOTAL line box; SwiftUI adds
//    `lineSpacing` on top of the font's own line height. `NoopSpecType.lineSpacing(_:)` does the
//    subtraction. Hard-coding 1.5 sets copy ~4 pt tight per line and collapses the card rhythm.
// 3. `Font.custom(_:size:)` scales with Dynamic Type; `Font.custom(_:fixedSize:)` does not. The
//    roles below choose deliberately — a scaled hero numeral breaks the charge gauge geometry.
//
// Register the bundled faces once at launch (`NoopSpecType.registerFonts()`) and verify the
// PostScript names on first run in DEBUG: a wrong name falls back to San Francisco silently, which
// is indistinguishable from "the font size is off".

public enum NoopSpecType {

    // MARK: PostScript names — verify, do not guess

    public enum Face {
        public static let outfitExtraLight = "Outfit-ExtraLight"   // 200
        public static let outfitLight      = "Outfit-Light"        // 300
        public static let outfitRegular    = "Outfit-Regular"      // 400
        public static let outfitMedium     = "Outfit-Medium"       // 500
        public static let sansRegular      = "InstrumentSans-Regular"   // 400
        public static let sansMedium       = "InstrumentSans-Medium"    // 500
        public static let sansSemiBold     = "InstrumentSans-SemiBold"  // 600
    }

    // MARK: Roles
    //
    // `.tracking` and `.lineSpacing` are NOT baked into these `Font` values — SwiftUI keeps them as
    // separate view modifiers — so each role has a matching `Tracking` constant and, where the copy
    // wraps, a `lineSpacing` helper. The `.noopText(_:)` modifier applies all three together and is
    // the intended call site.

    /// 52 / Outfit 200 / tracking −1.56 / tabular. FIXED — part of a drawn composition.
    public static let heroNumeral = Font.custom(Face.outfitExtraLight, fixedSize: 52).monospacedDigit()
    /// 25 / Outfit 400 / tracking −0.625. Scales, capped at xxxLarge.
    public static let screenTitle = Font.custom(Face.outfitRegular, size: 25, relativeTo: .title2)
    /// 23 / Outfit 400 / tracking −0.46 / line-height 1.15.
    public static let headline = Font.custom(Face.outfitRegular, size: 23, relativeTo: .title3)
    /// 19 / Outfit 400 / tracking −0.38. Scales, capped at xxxLarge.
    public static let sectionHead = Font.custom(Face.outfitRegular, size: 19, relativeTo: .headline)
    /// 17 / Outfit 400 / tracking −0.34 / tabular. FIXED.
    public static let rowFigure = Font.custom(Face.outfitRegular, fixedSize: 17).monospacedDigit()
    /// 14 / Sans 600.
    public static let cardTitle = Font.custom(Face.sansSemiBold, size: 14, relativeTo: .subheadline)
    /// 13.5 / Sans 400.
    public static let rowLabel = Font.custom(Face.sansRegular, size: 13.5, relativeTo: .subheadline)
    /// 13.5 / Sans 600 — a row label that is also a heading.
    public static let rowLabelStrong = Font.custom(Face.sansSemiBold, size: 13.5, relativeTo: .subheadline)
    /// 13.5 / Sans 400 / line-height 1.5.
    public static let body = Font.custom(Face.sansRegular, size: 13.5, relativeTo: .footnote)
    /// 13 / Sans 400 / line-height 1.55 — the tighter body, for a card that carries a lot of copy.
    public static let bodySmall = Font.custom(Face.sansRegular, size: 13, relativeTo: .footnote)
    /// 12.5 / Sans 600.
    public static let buttonLabel = Font.custom(Face.sansSemiBold, size: 12.5, relativeTo: .footnote)
    /// 12 / Sans 600 / tabular where numeric. FIXED — chips must not reflow the row.
    public static let chipValue = Font.custom(Face.sansSemiBold, fixedSize: 12).monospacedDigit()
    /// 11.5 / Sans 400 / line-height 1.45.
    public static let subline = Font.custom(Face.sansRegular, size: 11.5, relativeTo: .caption)
    /// 11 / Sans 400 / line-height 1.55.
    public static let finePrint = Font.custom(Face.sansRegular, size: 11, relativeTo: .caption)
    /// 10 / Sans 600 / tracking +1.2 / uppercase. FIXED.
    public static let caption = Font.custom(Face.sansSemiBold, fixedSize: 10)
    /// 9.5 / Sans 600 / tracking +1.14 / uppercase. FIXED. The floor — nothing is smaller.
    public static let captionMicro = Font.custom(Face.sansSemiBold, fixedSize: 9.5)
    /// 12.5 / Sans 600 / tracking +1.375 / uppercase — the orb's breathing word.
    public static let breathWord = Font.custom(Face.sansSemiBold, fixedSize: 12.5)

    // MARK: Tracking, in points (size × em)

    public enum Tracking {
        public static let heroNumeral: CGFloat = -1.56   // 52 × −.03
        public static let screenTitle: CGFloat = -0.625  // 25 × −.025
        public static let headline: CGFloat = -0.46      // 23 × −.02
        public static let sectionHead: CGFloat = -0.38   // 19 × −.02
        public static let rowFigure: CGFloat = -0.34     // 17 × −.02
        public static let caption: CGFloat = 1.2         // 10 × .12
        public static let captionMicro: CGFloat = 1.14   // 9.5 × .12
        public static let breathWord: CGFloat = 1.375    // 12.5 × .11
        /// Everything else.
        public static let none: CGFloat = 0
    }

    // MARK: Line height

    /// `lineSpacing` for a CSS line-height multiple: total box minus the font's own line height.
    /// Clamped at zero — a font whose natural line height already exceeds the target never gets
    /// negative spacing (SwiftUI ignores it and the text clips instead).
    public static func lineSpacing(size: CGFloat, cssLineHeight: CGFloat, face: String) -> CGFloat {
        #if canImport(UIKit)
        let natural = UIFont(name: face, size: size)?.lineHeight ?? size * 1.2
        #else
        let natural = size * 1.2
        #endif
        return max(0, size * cssLineHeight - natural)
    }

    // MARK: Registration

    /// Registers the bundled faces. Call once at launch. In DEBUG it asserts every PostScript name
    /// resolves, so a rename in the font files fails loudly instead of silently falling back to SF.
    public static func registerFonts() {
        #if canImport(UIKit)
        let names = [Face.outfitExtraLight, Face.outfitLight, Face.outfitRegular, Face.outfitMedium,
                     Face.sansRegular, Face.sansMedium, Face.sansSemiBold]
        for name in names where UIFont(name: name, size: 12) == nil {
            if let url = Bundle.module.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
            assert(UIFont(name: name, size: 12) != nil,
                   "Noop: font \(name) did not register — check the PostScript name, not the filename.")
        }
        #endif
    }
}

// MARK: - The intended call site

public extension View {
    /// Applies a role's font, tracking and line spacing together, and makes multi-line copy grow
    /// rather than truncate. Use this instead of `.font(…)` on its own — a role applied without its
    /// tracking is the single most common drift in the build.
    func noopText(
        _ font: Font,
        tracking: CGFloat = NoopSpecType.Tracking.none,
        lineSpacing: CGFloat = 0
    ) -> some View {
        self.font(font)
            .tracking(tracking)
            .lineSpacing(lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
    }
}
