import WidgetKit
import SwiftUI
import ActivityKit
import StrandDesign

/// Aura's one Lift presentation on the Lock Screen and in every Dynamic Island size.
///
/// There are deliberately no controls here. A tap opens `lift-live`, where Pause, Next and Finish
/// have enough context to be safe. Every word, clock anchor and progress value comes from the same
/// `LiftSessionController.Presentation` that feeds the in-app bar.
struct LiftLiveActivity: Widget {
    private let aura = NoopPalette.accent
    private let bodyInk = Color(.sRGB, red: 198 / 255, green: 206 / 255, blue: 201 / 255, opacity: 1)
    private let disabledInk = NoopPalette.textQuiet

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiftActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(NoopPalette.canvas)
                .activitySystemActionForegroundColor(NoopPalette.textPrimary)
                .widgetURL(URL(string: "noop://lift-live"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        stateMark(context.state, size: 7)
                        Text(context.attributes.programName)
                            .font(NoopSpecType.subline.weight(.semibold))
                            .foregroundStyle(bodyInk)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    clock(context.state, compact: false)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(context.state)
                }
            } compactLeading: {
                stateMark(context.state, size: 7)
                    .frame(width: 18, height: 18)
            } compactTrailing: {
                clock(context.state, compact: true)
                    .frame(minWidth: 36, alignment: .trailing)
            } minimal: {
                stateMark(context.state, size: 8)
                    .frame(width: 22, height: 22)
            }
            .widgetURL(URL(string: "noop://lift-live"))
        }
    }

    private func lockScreen(_ context: ActivityViewContext<LiftActivityAttributes>) -> some View {
        let state = context.state
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                stateMark(state, size: 8)
                Text("Noop · \(context.attributes.programName)")
                    .font(NoopSpecType.captionMicro)
                    .tracking(NoopSpecType.Tracking.captionMicro)
                    .textCase(.uppercase)
                    .foregroundStyle(NoopPalette.textSecondary)
                    .lineLimit(1)
            }

            HStack(alignment: .lastTextBaseline, spacing: 14) {
                Text(state.exercise)
                    .font(.custom(NoopSpecType.Face.outfitLight, fixedSize: 22))
                    .tracking(-0.44)
                    .foregroundStyle(NoopPalette.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                clock(state, compact: false)
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(state.status)
                    .font(.custom(NoopSpecType.Face.sansRegular, fixedSize: 12.5))
                    .foregroundStyle(bodyInk)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let detail = state.detail {
                    Text(detail)
                        .font(.custom(NoopSpecType.Face.sansSemiBold, fixedSize: 12.5))
                        .monospacedDigit()
                        .foregroundStyle(NoopPalette.textPrimary)
                        .lineLimit(1)
                        .fixedSize()
                }
            }

            progress(state, showsLabel: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
    }

    private func expandedBottom(_ state: LiftActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.exercise)
                .font(.custom(NoopSpecType.Face.outfitLight, fixedSize: 23))
                .tracking(-0.575)
                .foregroundStyle(NoopPalette.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(state.status)
                    .font(.custom(NoopSpecType.Face.sansRegular, fixedSize: 12.5))
                    .foregroundStyle(bodyInk)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let detail = state.detail {
                    Text(detail)
                        .font(.custom(NoopSpecType.Face.sansSemiBold, fixedSize: 12.5))
                        .monospacedDigit()
                        .foregroundStyle(NoopPalette.textPrimary)
                        .lineLimit(1)
                        .fixedSize()
                }
            }

            progress(state, showsLabel: false)
        }
        .padding(.top, 2)
    }

    private func progress(_ state: LiftActivityAttributes.ContentState,
                          showsLabel: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(stateInk(state))
                        .frame(width: proxy.size.width * progressFraction(state))
                }
            }
            .frame(height: 3)

            if showsLabel {
                Text(state.progress)
                    .font(.custom(NoopSpecType.Face.sansRegular, fixedSize: 11))
                    .monospacedDigit()
                    .foregroundStyle(NoopPalette.textQuiet)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func clock(_ state: LiftActivityAttributes.ContentState,
                       compact: Bool) -> some View {
        if state.isReady && !state.isPaused {
            Text("Ready")
                .font(.custom(NoopSpecType.Face.outfitRegular,
                              fixedSize: compact ? 12.5 : 20))
                .tracking(compact ? -0.31 : -0.5)
                .foregroundStyle(stateInk(state))
                .lineLimit(1)
                .fixedSize()
        } else if state.isPaused {
            Text(duration(state.heldClockSeconds ?? 0))
                .font(.custom(NoopSpecType.Face.outfitLight,
                              fixedSize: compact ? 13.5 : 31))
                .tracking(compact ? -0.34 : -0.775)
                .monospacedDigit()
                .foregroundStyle(disabledInk)
                .lineLimit(1)
                .fixedSize()
        } else if state.isResting, let end = state.restEndsAt, end > .now {
            Text(timerInterval: .now...end, countsDown: true)
                .font(.custom(NoopSpecType.Face.outfitLight,
                              fixedSize: compact ? 13.5 : 31))
                .tracking(compact ? -0.34 : -0.775)
                .monospacedDigit()
                .foregroundStyle(bodyInk)
                .lineLimit(1)
                .fixedSize()
        } else {
            Text(timerInterval: state.stageStartedAt...state.stageStartedAt.addingTimeInterval(86_400),
                 countsDown: false)
                .font(.custom(NoopSpecType.Face.outfitLight,
                              fixedSize: compact ? 13.5 : 31))
                .tracking(compact ? -0.34 : -0.775)
                .monospacedDigit()
                .foregroundStyle(stateInk(state))
                .lineLimit(1)
                .fixedSize()
        }
    }

    @ViewBuilder
    private func stateMark(_ state: LiftActivityAttributes.ContentState,
                           size: CGFloat) -> some View {
        if state.isPaused {
            Circle()
                .stroke(disabledInk, lineWidth: 1.4)
                .frame(width: size, height: size)
        } else if state.isReady {
            Circle()
                .stroke(aura, lineWidth: 1.5)
                .background(Circle().fill(aura.opacity(0.15)))
                .shadow(color: aura.opacity(0.7), radius: 4.5)
                .frame(width: size, height: size)
        } else {
            Circle()
                .fill(stateInk(state))
                .shadow(color: state.isResting ? .clear : aura.opacity(0.7), radius: 4.5)
                .frame(width: size, height: size)
        }
    }

    private func stateInk(_ state: LiftActivityAttributes.ContentState) -> Color {
        if state.isPaused { return disabledInk }
        if state.isResting && !state.isReady { return bodyInk }
        return aura
    }

    private func progressFraction(_ state: LiftActivityAttributes.ContentState) -> CGFloat {
        guard state.setsPlanned > 0 else { return 0 }
        return min(1, max(0, CGFloat(state.setsDone) / CGFloat(state.setsPlanned)))
    }

    private func duration(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        return String(format: "%d:%02d", safe / 60, safe % 60)
    }
}
