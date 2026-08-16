import Foundation
// Explicit rather than leaning on Foundation's re-export, since the layout constants below are CGFloat.
import CoreGraphics

// MARK: - Aura tick-gauge geometry (pure)
//
// The ring of ticks that surrounds the Aura orb encodes body state as a POSITION, never as a score —
// that is the whole point of the direction (the home screen carries no number). All of its geometry is
// pure arithmetic, kept out of the SwiftUI layer so it can be covered by `swift test`, which is the only
// CI that runs on this code: `swift-packages.yml` tests `Packages/**`, while the app targets that draw
// the gauge are compiled by nothing by default (see CLAUDE.md §"The trap").
//
// Angles are degrees, clockwise, zero = straight up — the convention SwiftUI's `rotationEffect` uses, so
// a value here can be handed to a view untransformed.

public enum AuraGaugeMath {

    /// Number of ticks around the arc. Odd, so one tick lands exactly on the arc's midpoint.
    public static let tickCount = 41

    /// Total sweep of the arc in degrees. The 110° left open at the bottom is what stops the ring from
    /// reading as a progress circle — it is an arc with two ends, so a marker on it reads as a position.
    public static let sweep: Double = 250

    /// Angle of the first tick. Symmetric about vertical (`-125 … +125`).
    public static let startAngle: Double = -125

    /// Every fifth tick is drawn longer, giving the eye a scale to read the marker against.
    public static let majorTickStride = 5

    /// Distance from the ring's centre to the centre of a tick, in points.
    public static let tickRadius: CGFloat = 124

    /// Distance from the ring's centre to the centre of the marker. Slightly inside `tickRadius` so the
    /// marker sits against the ticks and points out through them, rather than overlapping them.
    public static let markerRadius: CGFloat = 113

    /// Length of a major / minor tick, in points.
    public static let majorTickLength: CGFloat = 15
    public static let minorTickLength: CGFloat = 9
    public static let tickWidth: CGFloat = 2

    /// The ring's overall square footprint. Large enough to hold `tickRadius` plus half a major tick.
    public static let ringSize: CGFloat = 270

    /// The angle of tick `index`, in degrees clockwise from straight up.
    /// Out-of-range indices are clamped rather than trapping — this feeds a view, not a calculation.
    public static func angle(forTick index: Int) -> Double {
        let i = min(max(index, 0), tickCount - 1)
        return startAngle + (Double(i) / Double(tickCount - 1)) * sweep
    }

    /// The angle the marker sits at for a body-state fraction (0…1 along the arc).
    public static func markerAngle(fraction: Double) -> Double {
        startAngle + clampFraction(fraction) * sweep
    }

    /// The last tick that reads as "lit" for a given fraction. Ticks at or below this index take the
    /// state's accent; the rest stay in the unlit track colour.
    public static func activeIndex(fraction: Double) -> Int {
        Int((clampFraction(fraction) * Double(tickCount - 1)).rounded())
    }

    /// Whether tick `index` is drawn at major length.
    public static func isMajor(tick index: Int) -> Bool {
        index % majorTickStride == 0
    }

    /// Opacity for tick `index`. Lit ticks ramp from faint at the arc's start to full at the marker, which
    /// is what gives the ring its sense of direction; unlit ticks are fully opaque in their own dim colour.
    public static func opacity(forTick index: Int, activeIndex: Int) -> Double {
        guard index <= activeIndex else { return 1 }
        // `activeIndex == 0` would divide by zero — the single lit tick is simply drawn at full strength.
        guard activeIndex > 0 else { return 1 }
        return 0.32 + 0.68 * (Double(index) / Double(activeIndex))
    }

    /// Clamps a caller-supplied fraction into 0…1, so a bad input tilts the marker to an end of the arc
    /// instead of spinning it off the ring.
    public static func clampFraction(_ fraction: Double) -> Double {
        guard fraction.isFinite else { return 0 }
        return min(max(fraction, 0), 1)
    }

    /// Top inset that places a tick of `length` with its centre exactly `radius` from the ring centre,
    /// when the tick is pinned to the top edge of a `ringSize`-square container and that container is
    /// then rotated about its own centre. Keeps the offset arithmetic in one tested place rather than
    /// inline in a `ForEach`.
    public static func topInset(radius: CGFloat, length: CGFloat) -> CGFloat {
        ringSize / 2 - radius - length / 2
    }
}
