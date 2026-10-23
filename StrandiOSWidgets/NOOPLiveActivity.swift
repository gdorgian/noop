import WidgetKit
import SwiftUI
import ActivityKit
import StrandDesign

/// Four presentations of one timestamped sensor sample. No inferred trace or stale figure.
struct NOOPLiveActivity: Widget {
    /// The heart rate to draw: none once iOS has marked the banner stale (upstream 12.0). Each push is fresh
    /// for `LiveActivityController.staleAfter`, so a stale banner means the readings stopped.
    static func shownBpm(_ context: ActivityViewContext<NOOPActivityAttributes>) -> Int? {
        context.isStale ? nil : context.state.bpm
    }

    private let blue = Color(.sRGB, red: 23 / 255, green: 162 / 255, blue: 230 / 255, opacity: 1)
    private let amber = Color(.sRGB, red: 242 / 255, green: 180 / 255, blue: 92 / 255, opacity: 1)
    private let quiet = Color(.sRGB, red: 127 / 255, green: 138 / 255, blue: 133 / 255, opacity: 1)
    private let secondary = Color(.sRGB, red: 198 / 255, green: 206 / 255, blue: 201 / 255, opacity: 1)
    private let heartRed = Color(.sRGB, red: 255 / 255, green: 69 / 255, blue: 86 / 255, opacity: 1)
    /// Zone colours, Resting/Zone 1 to Zone 5, as the Fitness zones show them.
    private let zoneColors: [Color] = [
        Color(.sRGB, red: 143 / 255, green: 211 / 255, blue: 245 / 255, opacity: 1),
        Color(.sRGB, red: 23 / 255, green: 162 / 255, blue: 230 / 255, opacity: 1),
        Color(.sRGB, red: 46 / 255, green: 204 / 255, blue: 128 / 255, opacity: 1),
        Color(.sRGB, red: 242 / 255, green: 180 / 255, blue: 92 / 255, opacity: 1),
        Color(.sRGB, red: 240 / 255, green: 116 / 255, blue: 44 / 255, opacity: 1),
    ]

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NOOPActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Color(.sRGB, red: 10 / 255, green: 13 / 255, blue: 13 / 255, opacity: 0.86))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // The top corners of the expanded island are curved: wide labels there are clipped
                // (a reported "Below Zone ." and "'Ipdated"). The brand and zone sit inset and drop
                // below the camera when they do not fit beside it; the bottom row keeps a side margin.
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        heart(context, size: 13)
                        Text("Noop Aura")
                            .font(.custom(NoopSpecType.Face.sansSemiBold, fixedSize: 12))
                            .foregroundStyle(secondary)
                            .lineLimit(1)
                    }
                    .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(zoneLabel(context))
                        .font(.custom(NoopSpecType.Face.sansSemiBold, fixedSize: 12))
                        .foregroundStyle(zoneInk(context))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 9) {
                        figure(context, size: 40)
                        track(context)
                        status(context)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.top, 2)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                heart(context, size: 14)
                    .padding(.leading, 2)
            } compactTrailing: {
                if let bpm = freshBPM(context) {
                    Text(bpm.formatted())
                        .font(.custom(NoopSpecType.Face.outfitRegular, fixedSize: 14))
                        .tracking(-0.27)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.trailing, 2)
                } else {
                    Text("–")
                        .font(.custom(NoopSpecType.Face.outfitRegular, fixedSize: 14))
                        .foregroundStyle(quiet)
                }
            } minimal: {
                minimalMark(context)
            }
            .keylineTint(heartRed)
        }
    }

    /// The Noop Aura heart: red while readings arrive, an outline once they stop.
    @ViewBuilder
    private func heart(_ context: ActivityViewContext<NOOPActivityAttributes>, size: CGFloat) -> some View {
        Image(systemName: freshBPM(context) == nil ? "heart" : "heart.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(freshBPM(context) == nil ? quiet : heartRed)
            .shadow(color: freshBPM(context) == nil ? .clear : heartRed.opacity(0.55), radius: 4)
    }

    /// The lock-screen banner, seen many times a day: an aura orb that takes the colour of the zone you
    /// are in, the figure large and light beside it, and one track from resting to Zone 5 with the
    /// current band lit. Nothing on it moves except when a reading arrives.
    private func lockScreen(_ context: ActivityViewContext<NOOPActivityAttributes>) -> some View {
        let tone = auraTone(context)
        return HStack(alignment: .center, spacing: 16) {
            orb(context, tone: tone)
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if freshBPM(context) != nil {
                        figure(context, size: 44)
                    } else {
                        Text(context.state.lastBPM.map { "\($0)" } ?? "\u{2013}")
                            .font(.custom(NoopSpecType.Face.outfitLight, fixedSize: 44))
                            .foregroundStyle(quiet)
                    }
                    Spacer(minLength: 4)
                    Text(zoneLabel(context))
                        .font(.custom(NoopSpecType.Face.sansSemiBold, fixedSize: 11))
                        .tracking(0.9)
                        .textCase(.uppercase)
                        .foregroundStyle(zoneInk(context))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                track(context)
                HStack(spacing: 0) {
                    status(context)
                    Spacer(minLength: 6)
                    Text("Noop Aura")
                        .font(.custom(NoopSpecType.Face.sansSemiBold, fixedSize: 10.5))
                        .tracking(0.6)
                        .foregroundStyle(quiet)
                }
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 18)
        .padding(.vertical, 16)
        .background(alignment: .leading) {
            RadialGradient(colors: [tone.opacity(freshBPM(context) == nil ? 0.10 : 0.34), tone.opacity(0)],
                           center: .init(x: 0.12, y: 0.5), startRadius: 4, endRadius: 190)
        }
    }

    /// The zone colour the banner wears: resting mint, the five zone colours, amber over the ceiling,
    /// grey once readings stop.
    private func auraTone(_ context: ActivityViewContext<NOOPActivityAttributes>) -> Color {
        guard freshBPM(context) != nil else { return quiet }
        if overCeiling(context) { return amber }
        guard let z = context.state.zoneNumber, (1...5).contains(z) else { return restingTone }
        return zoneColors[z - 1]
    }

    private var restingTone: Color { Color(.sRGB, red: 120 / 255, green: 214 / 255, blue: 196 / 255, opacity: 1) }

    /// A soft sphere of the zone colour with the heart at its centre.
    private func orb(_ context: ActivityViewContext<NOOPActivityAttributes>, tone: Color) -> some View {
        let live = freshBPM(context) != nil
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [tone.opacity(live ? 0.55 : 0.18), tone.opacity(live ? 0.16 : 0.05), .clear],
                                     center: .center, startRadius: 2, endRadius: 34))
            Circle()
                .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.32), tone.opacity(0.18)],
                                             startPoint: .top, endPoint: .bottom), lineWidth: 0.75)
                .padding(9)
            Image(systemName: live ? "heart.fill" : "heart")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(live ? heartRed : quiet)
                .shadow(color: live ? heartRed.opacity(0.7) : .clear, radius: 6)
        }
        .frame(width: 64, height: 64)
    }

    /// Resting and the five zones as one quiet track; the band you are in is lit and carries a dot.
    private func track(_ context: ActivityViewContext<NOOPActivityAttributes>) -> some View {
        let live = freshBPM(context) != nil
        let current = live ? min(max(context.state.zoneNumber ?? 0, 0), 5) : -1
        let tones = [restingTone] + zoneColors
        return HStack(spacing: 3) {
            ForEach(0..<6, id: \.self) { band in
                Capsule()
                    .fill(band == current ? tones[band] : band < current ? tones[band].opacity(0.4) : Color.white.opacity(0.1))
                    .frame(maxWidth: .infinity)
                    .frame(height: 5)
                    .overlay {
                        if band == current {
                            Circle().fill(.white).frame(width: 9, height: 9)
                                .shadow(color: tones[band].opacity(0.9), radius: 5)
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func figure(_ context: ActivityViewContext<NOOPActivityAttributes>, size: CGFloat) -> some View {
        if let bpm = freshBPM(context) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(bpm.formatted())
                    .font(.custom(NoopSpecType.Face.outfitLight, fixedSize: size))
                    .tracking(-size * 0.035)
                    .monospacedDigit()
                Text("bpm")
                    .font(.custom(NoopSpecType.Face.sansSemiBold, fixedSize: 13))
            }
            .foregroundStyle(overCeiling(context) ? amber : .white)
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func zoneStrip(_ context: ActivityViewContext<NOOPActivityAttributes>) -> some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { zone in
                Capsule()
                    .fill(freshBPM(context) != nil && (context.state.zoneNumber ?? 0) >= zone
                          ? zoneColors[zone - 1].opacity(context.state.zoneNumber == zone ? 1 : 0.45)
                          : Color.white.opacity(0.12))
                    .frame(maxWidth: .infinity)
                    .frame(height: 4)
            }
        }
    }

    @ViewBuilder
    private func status(_ context: ActivityViewContext<NOOPActivityAttributes>) -> some View {
        if freshBPM(context) != nil, let sampledAt = context.state.sampledAt {
            if overCeiling(context), let ceiling = context.state.ceilingBPM {
                (Text("Zone \(context.state.zoneNumber ?? 0) · \(ceiling) is the ceiling you set · Updated ")
                 + Text(sampledAt, style: .relative))
                    .font(.custom(NoopSpecType.Face.sansRegular, fixedSize: 12))
                    .foregroundStyle(secondary)
                    .lineLimit(2)
            } else {
                (Text("Live \u{00B7} ") + Text(sampledAt, style: .relative) + Text(" ago"))
                    .font(.custom(NoopSpecType.Face.sansRegular, fixedSize: 12))
                    .foregroundStyle(secondary)
                    .monospacedDigit()
            }
        } else if let lastBPM = context.state.lastBPM,
                  let lastAt = context.state.lastSampledAt {
            (Text("Last \(lastBPM) bpm, ") + Text(lastAt, style: .relative)
             + Text(context.state.bonded ? ". Waiting for a new reading." : ". The strap is out of range."))
                .font(.custom(NoopSpecType.Face.sansRegular, fixedSize: 12))
                .foregroundStyle(secondary)
                .lineLimit(2)
        } else {
            Text("No timestamped reading yet.")
                .font(.custom(NoopSpecType.Face.sansRegular, fixedSize: 12))
                .foregroundStyle(secondary)
        }
    }

    @ViewBuilder
    private func minimalMark(_ context: ActivityViewContext<NOOPActivityAttributes>) -> some View {
        if freshBPM(context) == nil {
            Circle()
                .stroke(quiet.opacity(0.75), lineWidth: 2)
                .overlay(Capsule().fill(quiet).frame(width: 9, height: 2.5))
                .frame(width: 26, height: 26)
        } else {
            Image(systemName: "heart.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(heartRed)
        }
    }

    private func freshBPM(_ context: ActivityViewContext<NOOPActivityAttributes>) -> Int? {
        guard !context.isStale, context.state.bonded,
              context.state.sampledAt != nil,
              let bpm = context.state.bpm, (1...300).contains(bpm) else { return nil }
        return bpm
    }

    private func overCeiling(_ context: ActivityViewContext<NOOPActivityAttributes>) -> Bool {
        guard let bpm = freshBPM(context), let ceiling = context.state.ceilingBPM else { return false }
        return bpm > ceiling
    }

    private func zoneInk(_ context: ActivityViewContext<NOOPActivityAttributes>) -> Color {
        guard freshBPM(context) != nil else { return quiet }
        if overCeiling(context) { return amber }
        guard let z = context.state.zoneNumber, (1...5).contains(z) else { return secondary }
        return zoneColors[z - 1]
    }

    private func zoneLabel(_ context: ActivityViewContext<NOOPActivityAttributes>) -> String {
        guard freshBPM(context) != nil else { return "No reading" }
        if overCeiling(context) { return "Over your ceiling" }
        guard let zone = context.state.zoneNumber else { return "Zone unavailable" }
        // Under Zone 1 (50% of maximum) is ordinary resting and daily-life heart rate, not a zone.
        if zone == 0 { return "Resting" }
        guard (1...5).contains(zone) else { return "Zone unavailable" }
        switch zone {
        case 1: return "Zone 1 · easy"
        case 3: return "Zone 3 · steady"
        default: return "Zone \(zone)"
        }
    }
}
