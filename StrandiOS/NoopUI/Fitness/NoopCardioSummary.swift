#if os(iOS)
import SwiftUI
import MapKit
import WhoopStore

// MARK: - Route

/// The route on a quiet dark map: the line in Aura blue, a dot where it started and a ring where it ended.
/// Not interactive — a glance, not a map app — so it never fights the sheet's scroll.
struct NoopRouteCard: View {
    let points: [RouteMath.LatLng]
    let distanceM: Double

    private var coordinates: [CLLocationCoordinate2D] {
        points.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
    }

    private var region: MKCoordinateRegion {
        let lats = points.map(\.lat), lons = points.map(\.lon)
        let center = CLLocationCoordinate2D(latitude: ((lats.min() ?? 0) + (lats.max() ?? 0)) / 2,
                                            longitude: ((lons.min() ?? 0) + (lons.max() ?? 0)) / 2)
        // Room around the line, and never closer than a few streets.
        let span = MKCoordinateSpan(latitudeDelta: max(0.004, ((lats.max() ?? 0) - (lats.min() ?? 0)) * 1.5),
                                    longitudeDelta: max(0.004, ((lons.max() ?? 0) - (lons.min() ?? 0)) * 1.5))
        return MKCoordinateRegion(center: center, span: span)
    }

    var body: some View {
        NoopSessionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    NoopSessionCardTitle(symbol: "map.fill", title: "Route")
                    Spacer()
                    Text("\(NoopCardioGoalText.km(distanceM)) km")
                        .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(NoopHTMLColor.ink)
                }
                Map(initialPosition: .region(region), interactionModes: []) {
                    MapPolyline(coordinates: coordinates)
                        .stroke(NoopHTMLColor.blueLight.opacity(0.35), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                    MapPolyline(coordinates: coordinates)
                        .stroke(NoopHTMLColor.blueLight, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    if let first = coordinates.first {
                        Annotation("Start", coordinate: first, anchor: .center) {
                            Circle().fill(NoopHTMLColor.green).frame(width: 12, height: 12)
                                .overlay(Circle().strokeBorder(Color.black.opacity(0.6), lineWidth: 2))
                        }
                        .annotationTitles(.hidden)
                    }
                    if let last = coordinates.last, coordinates.count > 1 {
                        Annotation("Finish", coordinate: last, anchor: .center) {
                            Circle().strokeBorder(NoopHTMLColor.ink, lineWidth: 3).frame(width: 14, height: 14)
                                .background(Circle().fill(Color.black.opacity(0.7)))
                        }
                        .annotationTitles(.hidden)
                    }
                }
                .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
                .environment(\.colorScheme, .dark)
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .allowsHitTesting(false)
                .accessibilityLabel("Route map, \(NoopCardioGoalText.km(distanceM)) kilometres")
            }
        }
    }
}

// MARK: - Splits

/// One bar per kilometre, longest for the slowest, so the shape of the session reads at once; the fastest
/// whole kilometre is lit.
struct NoopSplitsCard: View {
    let splits: [RouteSplits.Split]

    /// The fastest whole kilometre, lit only when it really was quicker than the rest (by two seconds).
    private var fastest: Int? {
        let whole = splits.filter { $0.meters >= 999 }
        guard let best = whole.min(by: { $0.pace < $1.pace }),
              let next = whole.filter({ $0.index != best.index }).map(\.pace).min(),
              next - best.pace >= 2 else { return nil }
        return best.index
    }

    var body: some View {
        let slowest = max(1, splits.map(\.pace).max() ?? 1)
        let quickest = splits.map(\.pace).min() ?? 0
        NoopSessionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    NoopSessionCardTitle(symbol: "flag.2.crossed.fill", title: "Splits")
                    Spacer()
                    Text("per km").font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                }
                VStack(spacing: 7) {
                    ForEach(splits, id: \.index) { s in
                        let lit = s.index == fastest
                        HStack(spacing: 10) {
                            Text(s.meters >= 999 ? "\(s.index)" : "\(NoopCardioGoalText.km(s.meters))")
                                .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).monospacedDigit()
                                .foregroundStyle(NoopHTMLColor.copy)
                                .frame(width: 30, alignment: .leading)
                            GeometryReader { g in
                                // Scaled between the quickest and slowest so differences of seconds still show.
                                let span = max(1, slowest - quickest * 0.85)
                                let f = (s.pace - quickest * 0.85) / span
                                Capsule()
                                    .fill(lit ? NoopHTMLColor.blueLight : NoopHTMLColor.blueLight.opacity(0.35))
                                    .frame(width: max(12, g.size.width * min(1, max(0.08, f))))
                                    .frame(maxHeight: .infinity, alignment: .center)
                            }
                            .frame(height: 10)
                            Text(NoopCardioGoalText.clock(Int(s.pace.rounded())))
                                .font(NoopHTMLFont.sans(NoopType.caption, weight: lit ? .bold : .semibold)).monospacedDigit()
                                .foregroundStyle(lit ? NoopHTMLColor.blueLight : NoopHTMLColor.ink)
                                .frame(width: 52, alignment: .trailing)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Kilometre \(s.index), \(NoopCardioGoalText.clock(Int(s.pace.rounded()))) per kilometre\(lit ? ", fastest" : "")")
                    }
                }
            }
        }
    }
}

// MARK: - Against your recent sessions

/// This session beside the last few of the same sport: longer or shorter, a lower or higher heart rate, a
/// faster or slower pace. Only differences big enough to mean something are said.
struct NoopCompareCard: View {
    struct Line: Identifiable {
        let id: String
        let symbol: String
        let text: String
        /// True when the change is the good direction for most people (longer, faster, lower heart rate at
        /// the same work), which only sets the arrow's colour.
        let good: Bool
    }

    let sport: String
    let count: Int
    let lines: [Line]

    var body: some View {
        NoopSessionCard {
            VStack(alignment: .leading, spacing: 12) {
                NoopSessionCardTitle(symbol: "chart.line.uptrend.xyaxis",
                                     title: "Against your last \(count) \(count == 1 ? "session" : "sessions")")
                ForEach(lines) { l in
                    HStack(spacing: 10) {
                        Image(systemName: l.symbol).font(.system(size: 11, weight: .bold))
                            .foregroundStyle(l.good ? NoopHTMLColor.green : NoopHTMLColor.warm)
                            .frame(width: 24, height: 24)
                            .background((l.good ? NoopHTMLColor.green : NoopHTMLColor.warm).opacity(0.13), in: Circle())
                        Text(l.text).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.ink)
                            .monospacedDigit()
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    /// The lines worth saying, or none. `recent` are earlier sessions of the same sport, newest first.
    static func lines(for row: WorkoutRow, recent: [WorkoutRow]) -> [Line] {
        guard !recent.isEmpty else { return [] }
        var out: [Line] = []
        func mean(_ xs: [Double]) -> Double? { xs.isEmpty ? nil : xs.reduce(0, +) / Double(xs.count) }
        // Moving time, as saved: a paused stretch is not part of the session.
        func moving(_ r: WorkoutRow) -> Double { r.durationS ?? Double(r.endTs - r.startTs) }
        let duration = moving(row)
        if let avg = mean(recent.map(moving)) {
            let d = (duration - avg) / 60
            if abs(d) >= 2 {
                out.append(.init(id: "time", symbol: d > 0 ? "arrow.up" : "arrow.down",
                                 text: "\(Int(abs(d).rounded())) min \(d > 0 ? "longer" : "shorter") than usual", good: d > 0))
            }
        }
        if let m = row.distanceM, m > 200, duration > 0,
           let avgPace = mean(recent.compactMap { r in
               guard let rm = r.distanceM, rm > 200 else { return nil }
               return moving(r) / (rm / 1000)
           }) {
            let pace = duration / (m / 1000)
            let d = pace - avgPace
            if abs(d) >= 5 {
                out.append(.init(id: "pace", symbol: d < 0 ? "hare.fill" : "tortoise.fill",
                                 text: "\(NoopCardioGoalText.clock(Int(abs(d).rounded()))) /km \(d < 0 ? "faster" : "slower")", good: d < 0))
            }
        }
        if let hr = row.avgHr, let avgHr = mean(recent.compactMap { $0.avgHr.map(Double.init) }) {
            let d = Double(hr) - avgHr
            if abs(d) >= 3 {
                out.append(.init(id: "hr", symbol: d < 0 ? "heart" : "heart.fill",
                                 text: "Heart rate \(Int(abs(d).rounded())) bpm \(d < 0 ? "lower" : "higher") on average", good: d < 0))
            }
        }
        return out
    }
}
#endif
