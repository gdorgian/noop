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
    private let banner = LiftBanner()

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiftActivityAttributes.self) { context in
            banner.lockScreen(context.state)
                .activityBackgroundTint(NoopPalette.canvas)
                .activitySystemActionForegroundColor(NoopPalette.textPrimary)
                .widgetURL(URL(string: "noop://lift-live"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        banner.stateMark(context.state, size: 7)
                        Text(context.state.programName)
                            .font(NoopSpecType.subline.weight(.semibold))
                            .foregroundStyle(banner.bodyInk)
                            .lineLimit(1)
                    }
                    // Inset from the island's curved top corners, which clip anything flush to them.
                    .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    banner.clock(context.state, compact: false)
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    banner.expandedBottom(context.state)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 4)
                }
            } compactLeading: {
                banner.stateMark(context.state, size: 7)
                    .frame(width: 18, height: 18)
            } compactTrailing: {
                banner.clock(context.state, compact: true)
                    .frame(minWidth: 36, alignment: .trailing)
            } minimal: {
                banner.stateMark(context.state, size: 8)
                    .frame(width: 22, height: 22)
            }
            .widgetURL(URL(string: "noop://lift-live"))
        }
    }
}
