import Foundation
import CoreGraphics

// MARK: - Aura chart geometry (pure)
//
// Every Aura chart's arithmetic, kept out of its view for the same reason `AuraGaugeMath` is: these
// screens are app-target SwiftUI that no default CI job compiles, whereas `Packages/**` is tested on
// every push. Anything here that can be wrong in a way a reader would not notice — an off-by-one in a
// hit test, a bar that scales past its box, a band that inverts — belongs in this file with a test.

public enum AuraChartMath {

    /// Normalises `value` into 0…1 against a fixed ceiling. Values above the ceiling clamp rather than
    /// overflowing their container, which is what keeps one freak night from drawing outside the card.
    public static func fraction(_ value: Double, ceiling: Double) -> Double {
        guard ceiling > 0, value.isFinite else { return 0 }
        return min(max(value / ceiling, 0), 1)
    }

    /// Height of a bar for `value` inside a track of `height`, against a fixed ceiling.
    public static func barHeight(_ value: Double, ceiling: Double, height: CGFloat) -> CGFloat {
        height * CGFloat(fraction(value, ceiling: ceiling))
    }

    /// Height of a bar that must stay visible even at zero — the rest-debt strip, where a clear day is
    /// still a tick on the axis rather than a gap.
    public static func barHeight(_ value: Double, ceiling: Double, height: CGFloat, minimum: CGFloat) -> CGFloat {
        max(minimum, barHeight(value, ceiling: ceiling, height: height))
    }

    // MARK: Trend line

    /// Maps a series into points inside `size`, against an explicit value window. An explicit window
    /// (rather than auto-fitting to the data) is deliberate: the trend chart's whole claim is "you
    /// against your own normal", and a self-scaling axis would make every range look identically varied.
    public static func points(
        _ values: [Double],
        in size: CGSize,
        window: ClosedRange<Double>
    ) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let span = max(window.upperBound - window.lowerBound, 0.0001)
        let n = values.count
        return values.enumerated().map { i, v in
            let x = n > 1 ? size.width * CGFloat(i) / CGFloat(n - 1) : size.width / 2
            let norm = (min(max(v, window.lowerBound), window.upperBound) - window.lowerBound) / span
            return CGPoint(x: x, y: size.height - size.height * CGFloat(norm))
        }
    }

    /// The index whose point is nearest `x`. Used by the trend chart's tap targets, so an out-of-range
    /// tap resolves to an end point rather than nothing.
    public static func nearestIndex(toX x: CGFloat, count: Int, width: CGFloat) -> Int? {
        guard count > 0, width > 0 else { return nil }
        guard count > 1 else { return 0 }
        let step = width / CGFloat(count - 1)
        let raw = Int((x / step).rounded())
        return min(max(raw, 0), count - 1)
    }

    /// Whether the tooltip for a point at `y` must flip below it to stay inside the plot. Above is the
    /// default; a high point would otherwise push the bubble over the card's own header.
    public static func tooltipGoesBelow(pointY: CGFloat, plotHeight: CGFloat) -> Bool {
        pointY < plotHeight * 0.44
    }

    /// Horizontal placement of the tooltip as a fraction of the plot width, clamped away from both edges
    /// so a bubble anchored to the first or last point still renders inside the card.
    public static func tooltipX(pointX: CGFloat, plotWidth: CGFloat) -> Double {
        guard plotWidth > 0 else { return 0.5 }
        return min(0.9, max(0.1, Double(pointX / plotWidth)))
    }

    // MARK: Dot columns

    /// Opacity of a dot in a column of `count` out of `ceiling`. Taller columns read stronger, which is
    /// what gives the variability chart its shape without any axis labels.
    public static func dotOpacity(count: Int, ceiling: Int) -> Double {
        guard ceiling > 0 else { return 1 }
        return 0.38 + 0.62 * min(1, Double(count) / Double(ceiling))
    }

    // MARK: Battery ring

    /// Sweep of the battery arc in degrees for a 0…1 charge.
    public static func batterySweep(fraction: Double) -> Double {
        360 * min(max(fraction.isFinite ? fraction : 0, 0), 1)
    }

    // MARK: Typical-range bar

    /// Clamps a driver's position (0…100, "where you sit in your own range") into the bar, leaving room
    /// for the dot's radius at both ends so a value at an extreme is not drawn half outside the track.
    public static func rangePosition(_ percent: Double, dotInset: Double = 0) -> Double {
        let p = percent.isFinite ? percent : 50
        return min(100 - dotInset, max(dotInset, p))
    }
}
