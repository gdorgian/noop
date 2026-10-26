#if os(iOS) && DEBUG
import SwiftUI
import WidgetKit

/// Debug-only: `--noop-widget-board [sample|first-day|empty|live] [accented]` renders every panel widget at
/// its real sizes inside the app, so each state can be checked in one screenshot instead of one trip through
/// the widget gallery per size. `live` reads what the app last published to the App Group. The views are the
/// extension's own (compiled into Debug app builds only), drawn on the surface WidgetKit would put behind them.
struct WidgetBoard: View {
    static var requested: WidgetBoard? {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--noop-widget-board") else { return nil }
        let state = args.indices.contains(flag + 1) ? args[flag + 1] : "sample"
        return WidgetBoard(state: state, accented: args.contains("accented"))
    }

    let state: String
    let accented: Bool

    private var panels: WidgetPanels? {
        switch state {
        case "first-day": PanelSamples.firstDay
        case "empty": nil
        case "live": WidgetPanels.load()
        default: PanelSamples.panels
        }
    }

    private var entry: PanelsEntry { PanelsEntry(date: Date(), panels: panels) }
    private var mode: WidgetRenderingMode { accented ? .accented : .fullColor }

    // The sizes this simulator's Home Screen gives each family (iPhone 17 Pro).
    private let small = CGSize(width: 164, height: 164)
    private let medium = CGSize(width: 350, height: 164)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("\(state)\(accented ? " · accented" : "")")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                row(PanelInk.night) { SleepWidgetView(familyOverride: $0, renderingOverride: mode, entry: entry) }
                row(PanelInk.blue) { StepsWidgetView(familyOverride: $0, renderingOverride: mode, entry: entry) }
                row(PanelInk.blue) { VitalsWidgetView(familyOverride: $0, renderingOverride: mode, entry: entry) }
                row(PanelInk.blush) { WeightWidgetView(familyOverride: $0, renderingOverride: mode, entry: entry) }
                row(PanelInk.volt) { WorkoutsWidgetView(familyOverride: $0, renderingOverride: mode, entry: entry) }
                row(PanelInk.blueLight) { TrainWidgetView(familyOverride: $0, entry: entry) }
                row(PanelInk.volt) { ConsistencyWidgetView(familyOverride: $0, renderingOverride: mode, entry: entry) }
                row(PanelInk.warm) { GoalWidgetView(familyOverride: $0, renderingOverride: mode, entry: entry) }
                Text("Lift banner").font(.caption.monospaced()).foregroundStyle(.secondary)
                ForEach(Array(Self.liftStates.enumerated()), id: \.offset) { _, state in
                    LiftBanner().lockScreen(state)
                        .frame(width: 370)
                        .background(Color(hex: "#0A0C0B"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .environment(\.colorScheme, .dark)
                }
                Text("Lock Screen").font(.caption.monospaced()).foregroundStyle(.secondary)
                lockRow { SleepWidgetView(familyOverride: $0, renderingOverride: .vibrant, entry: entry) }
                lockRow { StepsWidgetView(familyOverride: $0, renderingOverride: .vibrant, entry: entry) }
                lockRow { GoalWidgetView(familyOverride: $0, renderingOverride: .vibrant, entry: entry) }
                lockRow { WorkoutsWidgetView(familyOverride: $0, renderingOverride: .vibrant, entry: entry) }
            }
            .padding(16)
        }
        .background(accented ? Color(hex: "#1B2A3A") : Color(hex: "#3A3632"))
    }

    /// The lift banner's three faces: the first set (nothing done yet), a running rest, and paused.
    static var liftStates: [LiftActivityAttributes.ContentState] {
        let now = Date()
        return [
            .init(isResting: false, programName: "Lower B", exercise: "Romanian Deadlift", status: "Warm-up",
                  detail: "8 × 10 kg", progress: "0 of 15 sets done", setsDone: 0, setsPlanned: 15,
                  stageStartedAt: now.addingTimeInterval(-20), restEndsAt: nil),
            .init(isResting: true, programName: "Lower B", exercise: "Romanian Deadlift", status: "Resting after set 1",
                  detail: "6 × 60 kg", progress: "3 of 15 sets done", setsDone: 3, setsPlanned: 15,
                  stageStartedAt: now.addingTimeInterval(-40), restEndsAt: now.addingTimeInterval(110)),
            .init(isResting: true, isPaused: true, programName: "Lower B", exercise: "Leg Press", status: "Paused · set 2",
                  detail: nil, progress: "5 of 15 sets done", setsDone: 5, setsPlanned: 15,
                  stageStartedAt: now, restEndsAt: now.addingTimeInterval(60), heldClockSeconds: 61),
        ]
    }

    private func tile<V: View>(_ size: CGSize, tint: Color, @ViewBuilder _ view: () -> V) -> some View {
        ZStack {
            if !accented { PanelSurface(tint: tint) } else { Color.white.opacity(0.12) }
            view()
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        .foregroundStyle(accented ? Color.white : Color.primary)
    }

    private func row<V: View>(_ tint: Color, @ViewBuilder _ view: @escaping (WidgetFamily) -> V) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            tile(medium, tint: tint) { view(.systemMedium) }
            HStack(spacing: 12) {
                tile(small, tint: tint) { view(.systemSmall) }
                if accented { tile(small, tint: tint) { view(.systemSmall) } }
            }
        }
    }

    private func lockRow<V: View>(@ViewBuilder _ view: @escaping (WidgetFamily) -> V) -> some View {
        HStack(spacing: 10) {
            view(.accessoryCircular).frame(width: 72, height: 72)
            view(.accessoryRectangular).frame(width: 170, height: 72)
            view(.accessoryInline).frame(width: 110, height: 26).lineLimit(1)
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }
}
#endif
