import SwiftUI
import StrandDesign

// MARK: - Shared ActivityStatus sheet (StrandPalette-styled)
//
// The activity-status concept (Active / Sick / Injured / On break, with a validity window and a silent
// reset) is screen-neutral. This shared sheet lets both Today presentations offer the same set/duration
// flow without duplicating it. Applying a choice writes through `ActivityStatusStore`.
//
// Cross-platform: `Strand/Screens` compiles into both the macOS Strand and the iOS NOOPiOS targets, so
// this stays free of `UIKit`/`AppKit` and uses only shared SwiftUI + design tokens.

struct SharedActivityStatusSheet: View {
    @Binding var status: ActivityStatus
    @Environment(\.dismiss) private var dismiss

    @State private var pendingState: ActivityStatus.State
    @State private var pendingDuration: DurationChoice = .untilChanged
    @State private var customDate = Date()

    init(status: Binding<ActivityStatus>) {
        _status = status
        _pendingState = State(initialValue: status.wrappedValue.state)
    }

    /// The duration choices offered, 1:1 onto `ActivityStatus.Duration`. Kept local to the sheet so the
    /// picker's UI order is independent of the model enum's declaration order.
    enum DurationChoice: CaseIterable {
        case untilChanged, today, threeDays, thisWeek, custom

        var label: String {
            switch self {
            case .untilChanged: return String(localized: "Until changed")
            case .today:        return String(localized: "Today")
            case .threeDays:    return String(localized: "3 days")
            case .thisWeek:     return String(localized: "This week")
            case .custom:       return String(localized: "Custom date")
            }
        }

        var duration: ActivityStatus.Duration {
            switch self {
            case .untilChanged: return .untilChanged
            case .today:        return .today
            case .threeDays:    return .threeDays
            case .thisWeek:     return .thisWeek
            case .custom:       return .custom(Date())   // overridden with customDate at apply time
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                Text("Activity status")
                    .font(StrandFont.headline)
                    .foregroundStyle(StrandPalette.textPrimary)
                    .padding(.bottom, 12)

                ForEach(ActivityStatus.State.allCases, id: \.self) { state in
                    stateRow(state)
                }

                durationSection

                Button(action: apply) {
                    Text("Apply")
                        .font(StrandFont.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .foregroundStyle(StrandPalette.goldDeepText)
                        .background(StrandPalette.accent, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding(.top, 18)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .background(StrandPalette.surfaceBase)
    }

    private func stateRow(_ state: ActivityStatus.State) -> some View {
        let selected = pendingState == state
        return Button { pendingState = state } label: {
            HStack(spacing: 12) {
                Image(systemName: state.symbolName)
                    .foregroundStyle(StrandPalette.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(StrandPalette.surfaceRaised, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.displayName)
                        .font(StrandFont.subhead)
                        .foregroundStyle(StrandPalette.textPrimary)
                    Text(state.subtitle)
                        .font(StrandFont.caption)
                        .foregroundStyle(StrandPalette.textTertiary)
                }
                Spacer()
                Circle()
                    .strokeBorder(selected ? radioColor(state) : StrandPalette.textTertiary, lineWidth: 1.6)
                    .frame(width: 19, height: 19)
                    .overlay {
                        if selected { Circle().fill(radioColor(state)).padding(3) }
                    }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Each state gets its own fixed Apple Health-style colour (green/red/orange/yellow) rather than
    /// collapsing the three exception states onto one shared warning tone — see `ActivityStatusColors`.
    private func radioColor(_ state: ActivityStatus.State) -> Color {
        ActivityStatusColors.color(for: state.rawValue)
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Valid for")
                .font(StrandFont.overline)
                .tracking(StrandFont.overlineTracking)
                .foregroundStyle(StrandPalette.textTertiary)
                .padding(.horizontal, 8)

            // A handful of short pills; a plain wrapping HStack is enough.
            FlowRow(spacing: 8) {
                ForEach(DurationChoice.allCases, id: \.self) { choice in
                    Button(choice.label) { pendingDuration = choice }
                        .buttonStyle(DurationPillStyle(selected: pendingDuration == choice))
                }
            }
            .padding(.horizontal, 8)

            if pendingDuration == .custom {
                DatePicker("", selection: $customDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .padding(.horizontal, 8)
                    .padding(.top, 2)
            }
        }
        .padding(.top, 14)
        .overlay(alignment: .top) { Rectangle().fill(StrandPalette.hairline).frame(height: 1) }
    }

    private func apply() {
        let now = Date()
        let duration: ActivityStatus.Duration = pendingDuration == .custom ? .custom(customDate) : pendingDuration.duration
        status = ActivityStatus(state: pendingState, validUntil: duration.validUntil(from: now), setAt: now)
        ActivityStatusStore.save(status)
        dismiss()
    }
}

private struct DurationPillStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(StrandFont.caption)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .foregroundStyle(selected ? StrandPalette.textPrimary : StrandPalette.textSecondary)
            .background(selected ? StrandPalette.accentMuted : StrandPalette.surfaceRaised, in: Capsule())
            .overlay(Capsule().strokeBorder(StrandPalette.hairline, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// A minimal wrapping row — the duration row only ever has 5 short pills, so a simple row suffices.
private struct FlowRow<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content
    var body: some View {
        HStack(spacing: spacing) { content() }
    }
}

// MARK: - Compact status chip (shared trigger)

/// A small tappable status chip for the two Today screens' headers/synthesis: an icon + the state label,
/// tinted by its own fixed Apple Health-style colour (green/red/orange/yellow, `ActivityStatusColors`).
/// Opens the shared sheet as a compact labelled button.
struct ActivityStatusChipCompact: View {
    @Binding var status: ActivityStatus
    @State private var showSheet = false

    private var tint: Color {
        ActivityStatusColors.color(for: status.state.rawValue)
    }

    var body: some View {
        Button { showSheet = true } label: {
            HStack(spacing: 5) {
                Image(systemName: status.state.symbolName)
                    .font(.system(size: 11, weight: .semibold))
                Text(status.state.displayName)
                    .font(StrandFont.overlineScaled(11))
                    .tracking(0.6)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Activity status: \(status.state.displayName)"))
        .accessibilityHint(Text("Double tap to change"))
        .sheet(isPresented: $showSheet) {
            SharedActivityStatusSheet(status: $status)
                .presentationDetents([.medium, .large])
        }
    }
}
