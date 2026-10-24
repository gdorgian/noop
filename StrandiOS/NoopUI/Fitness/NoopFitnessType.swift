#if os(iOS)
import SwiftUI

/// Fitness's type scale. Every size on a Fitness screen is one of these, named after the iOS text style it
/// stands in for, so the module reads as one system: eight steps instead of the thirty half-point sizes it
/// had grown. Nothing is below 11 pt, Apple's iOS minimum.
enum NoopType {
    /// Uppercase section labels, chart axes, badges. Pair with tracking.
    static let eyebrow: CGFloat = 11
    /// Secondary lines under a value or row: units, dates, captions.
    static let caption: CGFloat = 12
    /// Supporting copy and metadata.
    static let footnote: CGFloat = 13
    /// Row titles, buttons, table values.
    static let subhead: CGFloat = 15
    /// Primary body text and card titles.
    static let body: CGFloat = 17
    /// Values inside cards.
    static let title3: CGFloat = 22
    /// Page and hero values.
    static let title2: CGFloat = 28
    /// Screen titles and the largest numbers.
    static let title1: CGFloat = 34
}

extension View {
    /// Keeps a small-looking control at the 44 × 44 pt hit area iOS asks for, without changing how it looks.
    func noopHitTarget() -> some View {
        frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
    }
}
#endif
