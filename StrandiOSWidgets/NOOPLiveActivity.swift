import WidgetKit
import SwiftUI
import ActivityKit
import StrandDesign

/// Four presentations of one timestamped sensor sample. No inferred trace or stale figure.
struct NOOPLiveActivity: Widget {
    private let blue = Color(.sRGB, red: 23 / 255, green: 162 / 255, blue: 230 / 255, opacity: 1)
    private let amber = Color(.sRGB, red: 242 / 255, green: 180 / 255, blue: 92 / 255, opacity: 1)
    private let quiet = Color(.sRGB, red: 127 / 255, green: 138 / 255, blue: 133 / 255, opacity: 1)
    private let secondary = Color(.sRGB, red: 198 / 255, green: 206 / 255, blue: 201 / 255, opacity: 1)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NOOPActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Color(.sRGB, red: 20 / 255, green: 24 / 255, blue: 23 / 255, opacity: 1))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        mark(context, size: 7)
                        Text("Live heart rate")
                            .font(.custom(NoopSpecType.Face.sansSemiBold, fixedSize: 11.5))
                            .foregroundStyle(secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(zoneLabel(context))
                        .font(.custom(NoopSpecType.Face.sansSemiBold, fixedSize: 12))
                        .foregroundStyle(ink(context))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 9) {
                        figure(context, size: 40)
                        zoneStrip(context)
                        status(context)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 3)
                }
            } compactLeading: {
                mark(context, size: 7).frame(width: 18, height: 18)
            } compactTrailing: {
                if let bpm = freshBPM(context) {
                    Text(bpm.formatted())
                        .font(.custom(NoopSpecType.Face.outfitRegular, fixedSize: 13.5))
                        .tracking(-0.27)
                        .monospacedDigit()
                        .foregroundStyle(ink(context))
                        .lineLimit(1)
                }
            } minimal: {
                minimalMark(context)
            }
        }
    }

    private func lockScreen(_ context: ActivityViewContext<NOOPActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                mark(context, size: 7)
                Text("Noop · Live heart rate")
                    .font(.custom(NoopSpecType.Face.sansSemiBold, fixedSize: 10))
                    .tracking(1.3)
                    .textCase(.uppercase)
                    .foregroundStyle(Color(.sRGB, red: 147 / 255, green: 156 / 255, blue: 151 / 255, opacity: 1))
            }
            HStack(alignment: .lastTextBaseline, spacing: 14) {
                figure(context, size: 46)
                Spacer(minLength: 0)
                Text(zoneLabel(context))
                    .font(.custom(NoopSpecType.Face.sansSemiBold, fixedSize: 12))
                    .foregroundStyle(freshBPM(context) == nil ? quiet : overCeiling(context) ? amber : secondary)
                    .lineLimit(1)
            }
            VStack(alignment: .leading, spacing: 8) {
                zoneStrip(context)
                status(context)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
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
            .foregroundStyle(ink(context))
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func zoneStrip(_ context: ActivityViewContext<NOOPActivityAttributes>) -> some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { zone in
                Capsule()
                    .fill(freshBPM(context) != nil && context.state.zoneNumber == zone
                          ? ink(context) : Color.white.opacity(0.12))
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
                (Text("Updated ") + Text(sampledAt, style: .relative))
                    .font(.custom(NoopSpecType.Face.sansRegular, fixedSize: 12))
                    .foregroundStyle(secondary)
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
    private func mark(_ context: ActivityViewContext<NOOPActivityAttributes>, size: CGFloat) -> some View {
        if freshBPM(context) == nil {
            Circle().stroke(quiet, lineWidth: 1.4).frame(width: size, height: size)
        } else {
            Circle()
                .fill(ink(context))
                .shadow(color: ink(context).opacity(0.7), radius: 4.5)
                .frame(width: size, height: size)
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
            Circle()
                .fill(ink(context))
                .frame(width: 26, height: 26)
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

    private func ink(_ context: ActivityViewContext<NOOPActivityAttributes>) -> Color {
        if freshBPM(context) == nil { return quiet }
        return overCeiling(context) ? amber : blue
    }

    private func zoneLabel(_ context: ActivityViewContext<NOOPActivityAttributes>) -> String {
        guard freshBPM(context) != nil else { return "No reading" }
        if overCeiling(context) { return "Over your ceiling" }
        guard let zone = context.state.zoneNumber else { return "Zone unavailable" }
        if zone == 0 { return "Below Zone 1" }
        guard (1...5).contains(zone) else { return "Zone unavailable" }
        switch zone {
        case 1: return "Zone 1 · easy"
        case 3: return "Zone 3 · steady"
        default: return "Zone \(zone)"
        }
    }
}
