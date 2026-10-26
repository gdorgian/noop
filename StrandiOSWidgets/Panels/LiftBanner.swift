import SwiftUI
import AppIntents
import StrandDesign

/// The lift banner's views, apart from its ActivityKit wiring so the Debug widget board can draw them
/// inside the app (`--noop-widget-board`) — a Live Activity cannot be inspected anywhere else.
/// Weights are volt green across Noop Aura; cardio and every other sport are Aura blue.
struct LiftBanner {
    let aura = Color(.sRGB, red: 210 / 255, green: 240 / 255, blue: 74 / 255, opacity: 1)
    let auraInk = Color(.sRGB, red: 22 / 255, green: 28 / 255, blue: 5 / 255, opacity: 1)
    let bodyInk = Color(.sRGB, red: 198 / 255, green: 206 / 255, blue: 201 / 255, opacity: 1)
    let disabledInk = NoopPalette.textQuiet

    func lockScreen(_ state: LiftActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                stateMark(state, size: 8)
                Text("Noop Aura · \(state.programName)")
                    .font(NoopSpecType.captionMicro)
                    .tracking(NoopSpecType.Tracking.captionMicro)
                    .textCase(.uppercase)
                    .foregroundStyle(NoopPalette.textSecondary)
                    .lineLimit(1)
            }

            HStack(alignment: .lastTextBaseline, spacing: 14) {
                Text(state.exercise)
                    .font(.custom(NoopSpecType.Face.outfitLight, fixedSize: 22))
                    .foregroundStyle(NoopPalette.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                clock(state, compact: false)
            }

            if isRunningRest(state) {
                // Resting: the status and the two rest buttons share one row, so the banner stays well
                // inside the height iOS gives a Lock Screen Live Activity.
                HStack(spacing: 8) {
                    Text(state.status)
                        .font(.custom(NoopSpecType.Face.sansRegular, fixedSize: 12.5))
                        .foregroundStyle(bodyInk)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    restControls
                }
            } else {
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
                    }
                }
                progress(state, showsLabel: false)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    /// A rest is counting down: not paused, not yet over.
    func isRunningRest(_ state: LiftActivityAttributes.ContentState) -> Bool {
        guard state.isResting, !state.isPaused, !state.isReady, let end = state.restEndsAt else { return false }
        return end > .now
    }

    /// +30 s and Skip act in place; they change only the rest, never a set. Starting the next set stays a
    /// tap in the app or on the strap.
    var restControls: some View {
        HStack(spacing: 6) {
            Button(intent: AddLiftRestIntent()) {
                Text("+30 s")
                    .font(.custom(NoopSpecType.Face.sansSemiBold, fixedSize: 13))
                    .monospacedDigit()
                    .foregroundStyle(NoopPalette.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Color.white.opacity(0.13), in: Capsule())
            }
            .buttonStyle(.plain)
            Button(intent: SkipLiftRestIntent()) {
                Label("Skip", systemImage: "forward.end.fill")
                    .font(.custom(NoopSpecType.Face.sansSemiBold, fixedSize: 13))
                    .foregroundStyle(auraInk)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(aura, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    func expandedBottom(_ state: LiftActivityAttributes.ContentState) -> some View {
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

            if isRunningRest(state) {
                restControls
            } else {
                progress(state, showsLabel: false)
            }
        }
        .padding(.top, 2)
    }

    func progress(_ state: LiftActivityAttributes.ContentState,
                          showsLabel: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            // No GeometryReader: in some Live Activity regions it is proposed an unbounded width,
            // the computed fill width was not finite, and SwiftUI's placement assertion killed the
            // widget extension every time a lift session started — so the activity never appeared.
            // A leading-anchored scale needs no measured width.
            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(height: 3)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    // Never a zero scale: at the first set nothing is done, and scaling to 0 is a singular
                    // transform that lays the capsule out at a NaN origin, which kills the extension and
                    // leaves the banner a black box (26 Oct 2026, on device). Empty, it is simply not drawn.
                    Capsule()
                        .fill(stateInk(state))
                        .scaleEffect(x: max(0.001, progressFraction(state)), y: 1, anchor: .leading)
                        .opacity(progressFraction(state) > 0 ? 1 : 0)
                }

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
    func clock(_ state: LiftActivityAttributes.ContentState,
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
            // A system timer, laid out the way the cardio banner's is: no fixed size and no tracking. With
            // `.fixedSize()` a ticking timer gave the Lock Screen an empty black banner (26 Oct 2026).
            Text(timerInterval: min(state.stageStartedAt, end)...end, countsDown: true)
                .font(.custom(NoopSpecType.Face.outfitLight,
                              fixedSize: compact ? 13.5 : 31))
                .monospacedDigit()
                .foregroundStyle(bodyInk)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .frame(maxWidth: compact ? 52 : 110, alignment: .trailing)
        } else {
            Text(timerInterval: state.stageStartedAt...Date.distantFuture, countsDown: false)
                .font(.custom(NoopSpecType.Face.outfitLight,
                              fixedSize: compact ? 13.5 : 31))
                .monospacedDigit()
                .foregroundStyle(stateInk(state))
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .frame(maxWidth: compact ? 52 : 110, alignment: .trailing)
        }
    }

    @ViewBuilder
    func stateMark(_ state: LiftActivityAttributes.ContentState,
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

    func stateInk(_ state: LiftActivityAttributes.ContentState) -> Color {
        if state.isPaused { return disabledInk }
        if state.isResting && !state.isReady { return bodyInk }
        return aura
    }

    func progressFraction(_ state: LiftActivityAttributes.ContentState) -> CGFloat {
        guard state.setsPlanned > 0 else { return 0 }
        return min(1, max(0, CGFloat(state.setsDone) / CGFloat(state.setsPlanned)))
    }

    func duration(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        return String(format: "%d:%02d", safe / 60, safe % 60)
    }
}
