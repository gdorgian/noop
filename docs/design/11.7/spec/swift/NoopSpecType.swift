import SwiftUI
import CoreText          // CTFontManagerRegisterFontsForURL — registerFonts() below
#if canImport(UIKit)
import UIKit             // UIFont, for line-height maths and for validating registered faces
#endif

// WHERE THIS FILE GOES: Packages/StrandDesign/Sources/StrandDesign/Aura/
//
// Inside the StrandDesign package, beside NoopPalette.swift. Commit 1ecb5712 deleted the old Aura
// layer — AuraPalette.swift with it — so the palette now travels with this pack as NoopPalette:
// a palette-only file, no components and no body-state type. `import SwiftUI` is then complete and no target dependency or
// project.yml entry is needed (SPM globs Sources/StrandDesign/). Compiled into an app target instead,
// every `NoopPalette` reference fails with "cannot find in scope", which looks exactly like a missing
// palette file. See spec/13-branch-corrected-foundation.md, then spec/12-palette-bindings.md.

// MARK: - Noop redesign type scale
//
// Three families:
//   Outfit            200/300/400/500 — every numeral, every screen title, every large figure
//   Instrument Sans   400/500/600     — all UI text, labels, body copy, buttons
//   Instrument Serif  Regular, Italic — the editorial voice in Act 1, IN THE APP
//
// An earlier version of this header said the serif was prototype commentary only. That was wrong.
// `night/why` sets its headline in Instrument Serif Regular at 29, `night/tonight` sets its stop
// note at 16.5, and both night-worker and day-worker bodies italicise a measured phrase inline at
// 16. Three roles, below. Do not substitute the sans: the serif IS the difference between a screen
// that reads as a note written to you and one that reads as a report.
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
// FILES ARE NOT FACES. Two VARIABLE files ship — Outfit.ttf and InstrumentSans.ttf — and this file
// names seven FACES. Registration is per file; `Font.custom` asks per face. An earlier version of
// `registerFonts()` looked for a .ttf named after each PostScript name and so registered nothing at
// all, then asserted on fonts it had never given a chance. Register the files, THEN validate.
//
// Both files are confirmed to expose all seven named instances, so the static one-file-per-face set
// is not needed. It stays in `FontFile` as a zero-cost fallback: drop the seven static TTFs into the
// same folder and they take precedence, no code change.
//
// The fonts live in the PACKAGE's resources (`Sources/StrandDesign/Resources/Fonts/`), with both OFL
// licences beside them — not in `StrandiOS/Resources/Fonts`, because `Bundle.module` is a package
// bundle and cannot see an app target's resources.
//
// CALL THIS TWICE. `Bundle.module` is per-process and the widget is a separate process: once from
// `StrandiOSApp.init()` and once from the widget bundle's `@main` `init()`. Registering in the app
// alone leaves the Charge widget in San Francisco. See spec/00-RULES.md §6.

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
        public static let serifRegular     = "InstrumentSerif-Regular"
        public static let serifItalic      = "InstrumentSerif-Italic"

        public static let all = [outfitExtraLight, outfitLight, outfitRegular, outfitMedium,
                                 sansRegular, sansMedium, sansSemiBold,
                                 serifRegular, serifItalic]
        /// Family names, for the DEBUG dump.
        public static let families = ["Outfit", "Instrument Sans", "Instrument Serif"]
    }

    /// The font FILES to register, by basename. The variable pair is what ships and carries all
    /// seven named instances; the static set is an unused fallback that costs nothing to keep.
    public enum FontFile {
        /// What ships. Four files: two variable (each confirmed to expose all of its named
        /// instances) and the serif's two static cuts, which have no variable build.
        public static let shipped = ["Outfit", "InstrumentSans",
                                     "InstrumentSerif-Regular", "InstrumentSerif-Italic"]
        /// Optional override: one file per face, filename == PostScript name. Registered first if
        /// present, so dropping the static Outfit/Sans cuts in later needs no code change.
        public static let staticInstances = Face.all
        /// Where they sit in the package resource bundle, beside OFL-Outfit.txt,
        /// OFL-InstrumentSans.txt and OFL-InstrumentSerif.txt.
        public static let subdirectory = "Fonts"
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

    // The serif, in the app. Act 1 only — see `acts/40-act1-night.md`.

    /// 29 / Serif Regular / tracking −0.29 / line-height 1.22 — `night/why`'s headline. The one
    /// sentence on that screen that is written *to* the reader rather than reported at them.
    public static let serifHeadline = Font.custom(Face.serifRegular, size: 29, relativeTo: .title2)
    /// 16.5 / Serif Regular / line-height 1.45 — `night/tonight`'s stop note.
    public static let serifNote = Font.custom(Face.serifRegular, size: 16.5, relativeTo: .body)
    /// 16 / Serif Italic — a measured phrase italicised inline inside 14.5 sans body copy. It runs
    /// larger than the copy around it because the serif's x-height is smaller; matching the sans
    /// size makes the emphasis read as a typo.
    public static let serifEmphasis = Font.custom(Face.serifItalic, size: 16, relativeTo: .body)

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
        public static let serifHeadline: CGFloat = -0.29 // 29 × −.01
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

    /// Registers every font FILE found in the package bundle, then validates the seven face names.
    /// Idempotent.
    ///
    /// Call before the first view is built, in BOTH processes — `StrandiOSApp.init()` and the widget
    /// bundle's `@main` `init()`. Order matters and was wrong before: nothing can be validated until
    /// the files are registered, and the files are not named after the faces.
    public static func registerFonts() {
        #if canImport(UIKit)
        guard !didRegister else { return }
        didRegister = true

        // Static instances first if anyone dropped them in; then the four files that ship, which
        // cover all nine faces on their own. Duplicate registration of the same face is a no-op.
        for basename in FontFile.staticInstances + FontFile.shipped {
            guard let url = url(for: basename) else { continue }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            error?.release()
        }

        validateFaces()
        #endif
    }

    #if canImport(UIKit)
    private nonisolated(unsafe) static var didRegister = false

    /// `.process` on a directory keeps its subpath in some toolchain versions and flattens it in
    /// others, so look in both places rather than betting on one.
    private static func url(for basename: String) -> URL? {
        Bundle.module.url(forResource: basename, withExtension: "ttf", subdirectory: FontFile.subdirectory)
            ?? Bundle.module.url(forResource: basename, withExtension: "ttf")
            ?? Bundle.module.url(forResource: basename, withExtension: "otf", subdirectory: FontFile.subdirectory)
            ?? Bundle.module.url(forResource: basename, withExtension: "otf")
    }

    /// Reports what actually registered. A wrong face name falls back to San Francisco in silence,
    /// which is indistinguishable from "the font size is off" — so in DEBUG this prints the names
    /// CoreText really has, and the fix is to paste those into `Face` or ship the static instances.
    private static func validateFaces() {
        let missing = Face.all.filter { UIFont(name: $0, size: 12) == nil }
        guard !missing.isEmpty else { return }
        #if DEBUG
        print("‼️ Noop: these faces did not resolve: \(missing.joined(separator: ", "))")
        for family in Face.families {
            let have = UIFont.fontNames(forFamilyName: family)
            print("   family \"\(family)\" exposes: \(have.isEmpty ? "— nothing registered —" : have.joined(separator: ", "))")
        }
        print("   A variable file registers ONE family; its named instances are only addressable if")
        print("   the file carries them. The two variable files were verified to carry theirs — so an")
        print("   empty list here means the FILES are missing from the package bundle (check they are")
        print("   in Sources/StrandDesign/Resources/Fonts/), and a short list means the font drop")
        print("   changed. Remedy for the latter: add the static instances to that folder. RULES §6.")
        assertionFailure("Noop: \(missing.count) of \(Face.all.count) faces unavailable. See the console dump.")
        #endif
    }
    #endif
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
