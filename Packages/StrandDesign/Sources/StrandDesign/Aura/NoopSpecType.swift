import SwiftUI
import CoreText

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Noop Aura type scale
//
// StrandDesign bundles the variable Outfit and Instrument Sans files. CoreText exposes their named
// instances under the exact PostScript names below; using those instances preserves the handoff's 200 /
// 300 / 400 / 500 / 600 weights without asking SwiftUI to approximate a variable-font axis.

public enum NoopSpecType {

    public enum Face {
        // These are the PostScript names CoreText exposes for the named instances in the
        // bundled variable fonts. They deliberately look different from the CSS family/weight
        // names in the handoff; the rendered faces are the same Outfit weights.
        public static let outfitExtraLight = "Outfit-Thin_ExtraLight"
        public static let outfitLight = "Outfit-Thin_Light"
        public static let outfitRegular = "Outfit-Thin_Regular"
        public static let outfitMedium = "Outfit-Thin_Medium"
        public static let sansRegular = "InstrumentSans-Regular"
        public static let sansMedium = "InstrumentSans-Regular_Medium"
        public static let sansSemiBold = "InstrumentSans-Regular_SemiBold"
    }

    public enum Role: Sendable {
        case heroNumeral
        case screenTitle
        case headline
        case sectionHead
        case rowFigure
        case cardTitle
        case rowLabel
        case rowLabelStrong
        case body
        case bodySmall
        case buttonLabel
        case chipValue
        case subline
        case finePrint
        case caption
        case captionMicro
        case breathWord

        fileprivate var font: Font {
            switch self {
            case .heroNumeral:
                return .custom(Face.outfitExtraLight, fixedSize: 52).monospacedDigit()
            case .screenTitle:
                return .custom(Face.outfitRegular, size: 25, relativeTo: .title2)
            case .headline:
                return .custom(Face.outfitRegular, size: 23, relativeTo: .title3)
            case .sectionHead:
                return .custom(Face.outfitRegular, size: 19, relativeTo: .headline)
            case .rowFigure:
                return .custom(Face.outfitRegular, fixedSize: 17).monospacedDigit()
            case .cardTitle:
                return .custom(Face.sansSemiBold, size: 14, relativeTo: .subheadline)
            case .rowLabel:
                return .custom(Face.sansRegular, size: 13.5, relativeTo: .subheadline)
            case .rowLabelStrong:
                return .custom(Face.sansSemiBold, size: 13.5, relativeTo: .subheadline)
            case .body:
                return .custom(Face.sansRegular, size: 13.5, relativeTo: .footnote)
            case .bodySmall:
                return .custom(Face.sansRegular, size: 13, relativeTo: .footnote)
            case .buttonLabel:
                return .custom(Face.sansSemiBold, size: 12.5, relativeTo: .footnote)
            case .chipValue:
                return .custom(Face.sansSemiBold, fixedSize: 12).monospacedDigit()
            case .subline:
                return .custom(Face.sansRegular, size: 11.5, relativeTo: .caption)
            case .finePrint:
                return .custom(Face.sansRegular, size: 11, relativeTo: .caption)
            case .caption:
                return .custom(Face.sansSemiBold, fixedSize: 10)
            case .captionMicro:
                return .custom(Face.sansSemiBold, fixedSize: 9.5)
            case .breathWord:
                return .custom(Face.sansSemiBold, fixedSize: 12.5)
            }
        }

        fileprivate var tracking: CGFloat {
            switch self {
            case .heroNumeral: return -1.56
            case .screenTitle: return -0.625
            case .headline: return -0.46
            case .sectionHead: return -0.38
            case .rowFigure: return -0.34
            case .caption: return 1.2
            case .captionMicro: return 1.14
            case .breathWord: return 1.375
            default: return 0
            }
        }

        fileprivate var lineSpacing: CGFloat {
            switch self {
            case .headline:
                return NoopSpecType.lineSpacing(size: 23, cssLineHeight: 1.15)
            case .body:
                return NoopSpecType.lineSpacing(size: 13.5, cssLineHeight: 1.5)
            case .bodySmall:
                return NoopSpecType.lineSpacing(size: 13, cssLineHeight: 1.55)
            case .subline:
                return NoopSpecType.lineSpacing(size: 11.5, cssLineHeight: 1.45)
            case .finePrint:
                return NoopSpecType.lineSpacing(size: 11, cssLineHeight: 1.55)
            default:
                return 0
            }
        }

        fileprivate var maximumDynamicTypeSize: DynamicTypeSize? {
            switch self {
            case .screenTitle, .headline, .sectionHead, .cardTitle:
                return .xxxLarge
            case .rowLabel, .rowLabelStrong, .body, .bodySmall, .buttonLabel, .subline, .finePrint:
                return .accessibility5
            default:
                return nil
            }
        }

        fileprivate var uppercase: Bool {
            switch self {
            case .caption, .captionMicro, .breathWord: return true
            default: return false
            }
        }
    }

    /// SwiftUI adds line spacing to a font's natural line height; CSS line-height is the whole box.
    public static func lineSpacing(size: CGFloat, cssLineHeight: CGFloat) -> CGFloat {
        #if canImport(UIKit)
        let natural = UIFont(name: Face.sansRegular, size: size)?.lineHeight ?? size * 1.2
        #elseif canImport(AppKit)
        let natural = NSFont(name: Face.sansRegular, size: size)?.boundingRectForFont.height ?? size * 1.2
        #else
        let natural = size * 1.2
        #endif
        return max(0, size * cssLineHeight - natural)
    }

    /// Registers the two bundled variable files. UIAppFonts also registers them in the iOS host, but
    /// package previews and tests do not get that main-bundle declaration.
    public static func registerFonts() {
        #if canImport(UIKit) || canImport(AppKit)
        for resource in ["Outfit", "InstrumentSans"] {
            let url = Bundle.module.url(forResource: resource, withExtension: "ttf", subdirectory: "Fonts")
                ?? Bundle.module.url(forResource: resource, withExtension: "ttf")
            if let url {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }

        #if DEBUG
        let names = [
            Face.outfitExtraLight, Face.outfitLight, Face.outfitRegular, Face.outfitMedium,
            Face.sansRegular, Face.sansMedium, Face.sansSemiBold,
        ]
        #if canImport(UIKit)
        assert(names.allSatisfy { UIFont(name: $0, size: 12) != nil },
               "Noop Aura fonts did not expose every required named instance")
        #elseif canImport(AppKit)
        assert(names.allSatisfy { NSFont(name: $0, size: 12) != nil },
               "Noop Aura fonts did not expose every required named instance")
        #endif
        #endif
        #endif
    }
}

private struct NoopSpecTextModifier: ViewModifier {
    let role: NoopSpecType.Role

    @ViewBuilder
    func body(content: Content) -> some View {
        let styled = content
            .font(role.font)
            .tracking(role.tracking)
            .lineSpacing(role.lineSpacing)
            .textCase(role.uppercase ? .uppercase : nil)
            .fixedSize(horizontal: false, vertical: true)

        if let maximum = role.maximumDynamicTypeSize {
            styled.dynamicTypeSize(...maximum)
        } else {
            styled
        }
    }
}

public extension View {
    func noopText(_ role: NoopSpecType.Role) -> some View {
        modifier(NoopSpecTextModifier(role: role))
    }
}
