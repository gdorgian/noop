#if os(iOS)
import SwiftUI
import StrandDesign

// MARK: - Aura Rest
//
// Sleep, answered in the order a person actually asks: how was my latest recorded night, how does that
// compare to recent nights, what happened inside it, and what does that mean. The chart is tappable, and the two
// cards below it re-read for whichever night is selected — so the screen is one story about one night,
// not a dashboard of seven.

struct AuraRestReferenceContent: View {
    private let reading: AuraRestReading
    private let onOpenWhy: (Int) -> Void
    private let onOpenDebt: () -> Void
    private let onOpenTonight: () -> Void

    /// Stable onset id of the night selected in the week chart. Defaults to the most recent.
    @State private var selectedNightID: Int
    @State private var shapeOpen = false
    @State private var selectedStage: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var motion = NoopMotionState.shared

    private var poseStill: Bool { motion.poseStill(reduceMotion) }

    init(
        reading: AuraRestReading,
        onOpenWhy: @escaping (Int) -> Void,
        onOpenDebt: @escaping () -> Void,
        onOpenTonight: @escaping () -> Void
    ) {
        self.reading = reading
        self.onOpenWhy = onOpenWhy
        self.onOpenDebt = onOpenDebt
        self.onOpenTonight = onOpenTonight
        _selectedNightID = State(initialValue: reading.nights.last?.id ?? 0)
    }

    /// The selected night, or nil if there are none. Optional rather than force-indexed: an empty week
    /// is a legitimate state once this reads real data (a new user, a fresh install).
    private var night: AuraRestReading.NightReading? {
        guard !reading.nights.isEmpty else { return nil }
        return reading.nights.first(where: { $0.id == selectedNightID }) ?? reading.nights.last
    }

    var body: some View {
        VStack(spacing: 10) {
            nightHero
            sevenNightsCard
            shapeCard
            whyCard
            debtSummaryCard
            tonightCard
        }
        .onChangeCompat(of: reading.nights.map(\.id)) { _ in
            guard reading.nights.contains(where: { $0.id == selectedNightID }) else {
                selectedNightID = reading.nights.last?.id ?? 0
                selectedStage = nil
                return
            }
        }
    }

    // MARK: Against your recorded normal

    private var nightHero: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(String(localized: "Against your need"))
                    .font(.custom("Instrument Sans", fixedSize: 10).weight(.semibold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(AuraPalette.textTertiary)
                Spacer(minLength: 8)
                Text(night?.window ?? String(localized: "No recorded night"))
                    .font(.custom("Instrument Sans", fixedSize: 10.5).monospacedDigit())
                    .foregroundStyle(AuraPalette.textDim)
            }

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AuraPalette.rest.opacity(0.42), AuraPalette.rest.opacity(0)],
                            center: .center,
                            startRadius: 16,
                            endRadius: 142
                        )
                    )
                    .frame(width: 290, height: 290)
                    .blur(radius: 18)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AuraPalette.accent.opacity(0.16), AuraPalette.accent.opacity(0)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 98
                        )
                    )
                    .frame(width: 196, height: 196)
                    .blur(radius: 10)

                AuraRestSpecks()
                    .frame(width: 250, height: 250)

                AuraRestNeedRing(
                    samples: night?.hypnogram ?? [],
                    completion: ringCompletion,
                    available: night != nil && reading.sleepNeedMinutes > 0,
                    selectedStage: selectedStage
                )
                .frame(width: 232, height: 232)

                VStack(spacing: 0) {
                    Text(night.map { Self.durationText($0.hours * 60) } ?? "—")
                        .font(.custom("Outfit", fixedSize: 46).weight(.ultraLight))
                        .tracking(-1.8)
                        .monospacedDigit()
                        .foregroundStyle(AuraPalette.textPrimary)
                        .shadow(color: .black.opacity(0.6), radius: 12, y: 2)
                    Text(String(localized: "asleep"))
                        .font(.custom("Instrument Sans", fixedSize: 10.5).weight(.semibold))
                        .tracking(2.1)
                        .textCase(.uppercase)
                        .foregroundStyle(Color(hex: "#93A0A6"))
                        .padding(.top, 8)
                    Text(deltaLabel)
                        .font(.custom("Instrument Sans", fixedSize: 10.5).weight(.semibold))
                        .foregroundStyle(deltaTint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(deltaTint.opacity(0.12)))
                        .padding(.top, 9)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 250)
            .contentShape(Rectangle())
            .onTapGesture {
                if let id = night?.id { onOpenWhy(id) }
            }
            .overlay(alignment: .bottom) {
                Text(referenceCaption)
                    .font(.custom("Instrument Sans", fixedSize: 10.5))
                    .foregroundStyle(AuraPalette.textDim)
                    .offset(y: 2)
            }

            Button {
                if let id = night?.id { onOpenWhy(id) }
            } label: {
                HStack(spacing: 10) {
                    Text(ringRead)
                        .font(.custom("Instrument Sans", fixedSize: 12.5))
                        .foregroundStyle(Color(hex: "#C6CEC9"))
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: "#9AA7E0"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .auraCard(cornerRadius: 20)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    private var ringCompletion: CGFloat {
        guard let night, reading.sleepNeedMinutes > 0 else { return 0 }
        return CGFloat(min(max((night.hours * 60) / reading.sleepNeedMinutes, 0), 1))
    }

    private var deltaMinutes: Int? {
        guard let night, reading.sleepNeedMinutes > 0 else { return nil }
        return Int((night.hours * 60 - reading.sleepNeedMinutes).rounded())
    }

    private var deltaLabel: String {
        guard let deltaMinutes else { return String(localized: "need unavailable") }
        if abs(deltaMinutes) < 5 { return String(localized: "at your need") }
        let amount = Self.durationText(Double(abs(deltaMinutes)))
        return deltaMinutes > 0
            ? String(localized: "\(amount) over")
            : String(localized: "\(amount) under")
    }

    private var deltaTint: Color {
        guard let deltaMinutes else { return AuraPalette.textQuiet }
        return deltaMinutes < -5 ? Color(hex: "#F2B45C") : Color(hex: "#C9D0EE")
    }

    private var referenceCaption: String {
        guard reading.sleepNeedMinutes > 0 else { return String(localized: "sleep need unavailable") }
        return String(localized: "the ring closes at your need · \(Self.durationText(reading.sleepNeedMinutes))")
    }

    private var ringRead: String {
        guard night != nil else {
            return String(localized: "Wear your strap overnight to draw the shape of your night.")
        }
        guard let deltaMinutes else {
            return String(localized: "Sleep need is unavailable. See what the night recorded.")
        }
        if deltaMinutes >= -7 {
            return String(localized: "A closed ring. See what the night was made of")
        }
        return String(localized: "The ring stops short by \(abs(deltaMinutes)) minutes — see why last night went that way")
    }

    // MARK: Seven nights

    private var sevenNightsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(String(localized: "Your last seven")).auraOverline()
                Spacer(minLength: 8)
                Text(averageCaption)
                    .font(.custom("Instrument Sans", fixedSize: 10.5))
                    .foregroundStyle(AuraPalette.textDim)
                    .multilineTextAlignment(.trailing)
            }

            if reading.nights.isEmpty {
                Text(String(localized: "No recorded nights yet."))
                    .font(.custom("Instrument Sans", fixedSize: 13))
                    .foregroundStyle(AuraPalette.textQuiet)
                    .frame(maxWidth: .infinity, minHeight: 86, alignment: .center)
            } else {
                GeometryReader { geometry in
                    let needHours = reading.sleepNeedMinutes / 60
                    let ceiling = max(8.4, reading.nights.map(\.hours).max() ?? 0, needHours)
                    let barArea: CGFloat = 92
                    let needHeight = barArea * CGFloat(min(max(needHours / ceiling, 0), 1))

                    ZStack(alignment: .bottom) {
                        if needHours > 0 {
                            AuraDashedRule()
                                .stroke(AuraPalette.rest.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                                .frame(width: geometry.size.width, height: 1)
                                .padding(.bottom, 21 + needHeight)
                                .allowsHitTesting(false)
                        }

                        HStack(alignment: .bottom, spacing: 6) {
                            ForEach(reading.nights) { item in
                                let isSelected = item.id == selectedNightID
                                Button {
                                    withAnimation(NoopMotion.gated(NoopMotion.value, reduced: poseStill)) {
                                        selectedNightID = item.id
                                        selectedStage = nil
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        Spacer(minLength: 0)
                                        Text(isSelected ? String(format: "%.1fh", item.hours) : "")
                                            .font(.custom("Outfit", fixedSize: 10.5).weight(.medium))
                                            .monospacedDigit()
                                            .foregroundStyle(AuraPalette.textPrimary)
                                            .padding(.horizontal, isSelected ? 7 : 0)
                                            .frame(height: 18)
                                            .background(
                                                Capsule(style: .continuous)
                                                    .fill(isSelected ? Color(hex: "#6E7DB8").opacity(0.90) : .clear)
                                            )
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(
                                                isSelected
                                                    ? AnyShapeStyle(LinearGradient(
                                                        colors: [Color(hex: "#A9B6E8"), Color(hex: "#6E7DB8")],
                                                        startPoint: .top,
                                                        endPoint: .bottom))
                                                    : AnyShapeStyle(Color.white.opacity(0.08))
                                            )
                                            .frame(height: max(3, barArea * CGFloat(min(max(item.hours / ceiling, 0), 1))))
                                            .shadow(
                                                color: isSelected ? Color(hex: "#6E7DB8").opacity(0.35) : .clear,
                                                radius: 9,
                                                y: 6
                                            )
                                        Text(item.day)
                                            .font(.custom("Instrument Sans", fixedSize: 11).weight(isSelected ? .semibold : .regular))
                                            .foregroundStyle(isSelected ? AuraPalette.textPrimary : AuraPalette.textDim)
                                            .frame(height: 15)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(item.day), \(String(format: "%.1f", item.hours)) hours")
                                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                            }
                        }
                    }
                }
                .frame(height: 132)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 13)
        .auraCard(cornerRadius: 22)
    }

    private var averageCaption: String {
        reading.sleepNeedMinutes > 0
            ? String(localized: "dashes — your own need, \(Self.durationText(reading.sleepNeedMinutes))")
            : String(localized: "sleep need unavailable")
    }

    // MARK: Shape of the selected night

    private var shapeCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "The shape of it")).auraOverline()
                Spacer(minLength: 8)
                Text(night?.window ?? "—")
                    .font(.custom("Instrument Sans", fixedSize: 11).monospacedDigit())
                    .foregroundStyle(AuraPalette.textDim)
            }

            Text(night?.note ?? String(localized: "No sleep staging is available yet."))
                .font(.custom("Instrument Sans", fixedSize: 14))
                .lineSpacing(3)
                .foregroundStyle(AuraPalette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                withAnimation(NoopMotion.gated(.easeInOut(duration: 0.2), reduced: poseStill)) {
                    shapeOpen.toggle()
                }
            } label: {
                VStack(spacing: 9) {
                    if let stages = night?.stages, !stages.isEmpty {
                        AuraRestStageStrip(stages: stages, selectedStage: selectedStage)
                            .frame(height: 10)
                    } else {
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 10)
                    }

                    HStack(spacing: 8) {
                        Text(stageSummary)
                            .font(.custom("Instrument Sans", fixedSize: 11.5))
                            .foregroundStyle(AuraPalette.textFaint)
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        Text(shapeOpen ? String(localized: "Hide the night") : String(localized: "See the whole night"))
                            .font(.custom("Instrument Sans", fixedSize: 11.5).weight(.semibold))
                            .foregroundStyle(AuraPalette.rest)
                    }
                }
            }
            .buttonStyle(.plain)

            if shapeOpen {
                VStack(alignment: .leading, spacing: 12) {
                    if let samples = night?.hypnogram, !samples.isEmpty {
                        AuraRestInteractiveHypnogram(stages: samples, selectedStage: selectedStage)

                        HStack {
                            ForEach(Array((night?.hypnogramAxis ?? []).enumerated()), id: \.offset) { index, label in
                                Text(label)
                                    .font(.custom("Instrument Sans", fixedSize: 10.5).monospacedDigit())
                                    .foregroundStyle(AuraPalette.textDim)
                                if index < (night?.hypnogramAxis.count ?? 0) - 1 { Spacer(minLength: 4) }
                            }
                        }
                    } else {
                        Text(String(localized: "Stage timing is unavailable for this recorded night."))
                            .font(.custom("Instrument Sans", fixedSize: 11.5))
                            .foregroundStyle(AuraPalette.textDim)
                    }

                    VStack(spacing: 6) {
                        ForEach(night?.stages ?? []) { stage in
                            interactiveStageRow(stage)
                        }

                        Text(stageHint)
                            .font(.custom("Instrument Sans", fixedSize: 10.5))
                            .foregroundStyle(AuraPalette.textDim)
                            .padding(.top, 2)
                            .padding(.leading, 4)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 17)
        .padding(.top, 17)
        .padding(.bottom, 15)
        .auraCard(cornerRadius: 22)
    }

    private var stageSummary: String {
        guard let stages = night?.stages, !stages.isEmpty else {
            return String(localized: "Sleep-stage detail unavailable")
        }
        return stages.prefix(3).map { "\($0.name) \($0.duration)" }.joined(separator: " · ")
    }

    private var stageHint: String {
        guard let selectedStage,
              let stage = night?.stages.first(where: { Self.stageCode($0.id) == selectedStage }) else {
            return String(localized: "Tap a stage to isolate it")
        }
        return String(localized: "Showing \(stage.name) only — tap again to show all")
    }

    private func interactiveStageRow(_ stage: AuraRestReading.Stage) -> some View {
        let code = Self.stageCode(stage.id)
        let selected = code != nil && selectedStage == code
        let dimmed = selectedStage != nil && !selected
        let tint = code.map { AuraRestNeedRing.color(for: $0) } ?? stage.tint

        return Button {
            guard let code else { return }
            withAnimation(NoopMotion.gated(.easeInOut(duration: 0.18), reduced: poseStill)) {
                selectedStage = selected ? nil : code
            }
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(tint)
                    .frame(width: 10, height: 10)
                    .shadow(color: selected ? Color.white.opacity(0.10) : .clear, radius: 0, x: 0, y: 0)

                Text(stage.name)
                    .font(.custom("Instrument Sans", fixedSize: 12).weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? AuraPalette.textPrimary : AuraPalette.textTertiary)
                    .frame(width: 40, alignment: .leading)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous).fill(Color.white.opacity(0.06))
                        Capsule(style: .continuous)
                            .fill(tint)
                            .frame(width: geometry.size.width * min(max(stage.fraction, 0), 1))
                    }
                }
                .frame(height: 6)

                Text(stage.duration)
                    .font(.custom("Instrument Sans", fixedSize: 12).monospacedDigit())
                    .foregroundStyle(AuraPalette.textPrimary)
                    .frame(width: 52, alignment: .trailing)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Color.white.opacity(0.06) : .clear)
            )
            .opacity(dimmed ? 0.45 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    fileprivate static func stageCode(_ id: String) -> Int? {
        switch id.lowercased() {
        case "awake": return 0
        case "light": return 1
        case "rem": return 2
        case "deep": return 3
        default: return nil
        }
    }

    /// The selected night's own note, followed by the line that turns the dashed average into a claim.
    private var restNote: String {
        guard let night else { return reading.averageNote }
        return "\(night.note) \(reading.averageNote)"
    }

    private var whyCard: some View {
        Button {
            if let id = night?.id { onOpenWhy(id) }
        } label: {
            disclosureCard(
                icon: "moon.zzz.fill",
                tint: AuraPalette.rest,
                title: String(localized: "Why this night"),
                subtitle: restNote,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
    }

    private var debtSummaryCard: some View {
        Button(action: onOpenDebt) {
            disclosureCard(
                icon: "moon.stars.fill",
                tint: reading.debtIsDebt ? Color(hex: "#F2B45C") : AuraPalette.rest,
                title: String(localized: "Sleep debt"),
                subtitle: reading.debtNightCount > 0
                    ? reading.debtHeadline + ". " + reading.debtExplanation
                    : String(localized: "No recorded nights yet."),
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
        .disabled(reading.debtNightCount == 0)
        .opacity(reading.debtNightCount == 0 ? 0.38 : 1)
    }

    private var tonightCard: some View {
        Button(action: onOpenTonight) {
            VStack(alignment: .leading, spacing: 11) {
                Text(String(localized: "Tonight"))
                    .font(.custom("Instrument Sans", fixedSize: 10).weight(.semibold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(AuraPalette.accent)
                Text(String(localized: "Plan your next night"))
                    .font(.custom("Outfit", fixedSize: 27).weight(.light))
                    .tracking(-0.7)
                    .foregroundStyle(AuraPalette.textPrimary)
                Text(tonightExplanation)
                    .font(.custom("Instrument Sans", fixedSize: 13))
                    .lineSpacing(3)
                    .foregroundStyle(Color(hex: "#B7C3C9"))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 7) {
                    Text(String(localized: "Decide it"))
                        .font(.custom("Instrument Sans", fixedSize: 13).weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(AuraPalette.onAccent)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AuraPalette.accent))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.top, 19)
        .padding(.bottom, 17)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(
                    colors: [AuraPalette.accent.opacity(0.17), AuraPalette.accent.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(AuraPalette.accent.opacity(0.30), lineWidth: 0.5)
                )
        )
        .padding(.top, 4)
    }

    private var tonightExplanation: String {
        guard reading.sleepNeedMinutes > 0 else {
            return String(localized: "Choose a wake time to plan tonight. Sleep need is not available yet.")
        }
        return String(localized: "Choose a wake time to calculate a sleep window from your current need of \(Self.durationText(reading.sleepNeedMinutes)).")
    }

    private func disclosureCard(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        showsChevron: Bool
    ) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tint.opacity(0.13)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.custom("Instrument Sans", fixedSize: 14.5).weight(.semibold))
                    .foregroundStyle(AuraPalette.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.custom("Instrument Sans", fixedSize: 12))
                    .lineSpacing(3)
                    .foregroundStyle(AuraPalette.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AuraPalette.textDim)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .auraCard(cornerRadius: 20)
    }

    private static func durationText(_ minutes: Double) -> String {
        let rounded = max(0, Int(minutes.rounded()))
        return String(localized: "\(rounded / 60)h \(rounded % 60)m")
    }
}

// MARK: - Rest artwork

private struct AuraRestInteractiveHypnogram: View {
    let stages: [Int]
    let selectedStage: Int?

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(stages.enumerated()), id: \.offset) { _, rawStage in
                let stage = min(max(rawStage, 0), AuraHypnogram.stageColors.count - 1)
                let selected = selectedStage == nil || selectedStage == stage
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(selected ? AuraHypnogram.stageColors[stage] : Color.white.opacity(0.07))
                    .frame(minWidth: 3)
                    .frame(height: AuraHypnogram.stageHeights[stage])
                    .shadow(
                        color: selectedStage == stage ? AuraHypnogram.stageColors[stage].opacity(0.65) : .clear,
                        radius: 5
                    )
            }
        }
        .frame(height: 84, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

/// The collapsed HTML card shows four duration-proportional blocks, not a miniature epoch chart.
private struct AuraRestStageStrip: View {
    let stages: [AuraRestReading.Stage]
    let selectedStage: Int?

    var body: some View {
        GeometryReader { geometry in
            let total = max(stages.reduce(0) { $0 + max($1.minutes, 0) }, 1)
            let gaps = CGFloat(max(stages.count - 1, 0)) * 2
            let usable = max(geometry.size.width - gaps, 0)

            HStack(spacing: 2) {
                ForEach(stages) { stage in
                    let code = AuraRestReferenceContent.stageCode(stage.id)
                    Rectangle()
                        .fill(
                            selectedStage == nil || selectedStage == code
                                ? code.map { AuraRestNeedRing.color(for: $0) } ?? stage.tint
                                : Color.white.opacity(0.09)
                        )
                        .frame(width: usable * CGFloat(max(stage.minutes, 0) / total))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .accessibilityHidden(true)
    }
}

/// A luminous, stage-coloured ring. Its closure point is the same population-anchored, upper-quartile
/// sleep-need estimate used by NOOP's tested debt ledger.
private struct AuraRestNeedRing: View {
    let samples: [Int]
    let completion: CGFloat
    let available: Bool
    let selectedStage: Int?

    var body: some View {
        let used = min(max(completion, 0), 1)
        return ZStack {
            AuraRestArc(from: 0, to: 1)
                .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 17, lineCap: .round))

            if available {
                if samples.isEmpty {
                    AuraRestArc(from: 0, to: used)
                        .stroke(AuraPalette.rest, style: StrokeStyle(lineWidth: 17, lineCap: .round))
                        .shadow(color: AuraPalette.rest.opacity(0.65), radius: 9)
                } else {
                    ForEach(Array(samples.enumerated()), id: \.offset) { index, rawStage in
                        let stage = min(max(rawStage, 0), 3)
                        let start = used * CGFloat(index) / CGFloat(samples.count)
                        let end = used * CGFloat(index + 1) / CGFloat(samples.count)
                        let gap = min(0.0012, max((end - start) * 0.12, 0))
                        let tint = selectedStage == nil || selectedStage == stage
                            ? Self.color(for: stage)
                            : Color.white.opacity(0.08)
                        AuraRestArc(from: start + gap, to: max(start + gap, end - gap))
                            .stroke(
                                tint,
                                style: StrokeStyle(lineWidth: Self.lineWidth(for: stage), lineCap: .round)
                            )
                            .shadow(color: tint.opacity(selectedStage == nil || selectedStage == stage ? 0.60 : 0), radius: 8)
                    }
                }

                GeometryReader { geometry in
                    let angle = (138 + 264 * Double(used)) * Double.pi / 180
                    let radius = max(0, min(geometry.size.width, geometry.size.height) / 2 - 20)
                    Circle()
                        .fill(AuraPalette.textPrimary)
                        .frame(width: 6.4, height: 6.4)
                        .position(
                            x: geometry.size.width / 2 + CGFloat(cos(angle)) * radius,
                            y: geometry.size.height / 2 + CGFloat(sin(angle)) * radius
                        )
                }
            }
        }
        .accessibilityHidden(true)
    }

    private static func lineWidth(for stage: Int) -> CGFloat {
        switch stage {
        case 3: return 18
        case 2: return 14
        case 1: return 10
        default: return 5
        }
    }

    static func color(for stage: Int) -> Color {
        let colors = [
            Color.white.opacity(0.22),
            Color(hex: "#9AA7E0"),
            Color(hex: "#4FB8E8"),
            Color(hex: "#5D6BC4"),
        ]
        return colors[min(max(stage, 0), colors.count - 1)]
    }
}

private struct AuraRestArc: Shape {
    let from: CGFloat
    let to: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // The SVG viewBox is 232pt, but its authored radius is 96pt.
        let radius = max(0, min(rect.width, rect.height) / 2 - 20)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(138 + 264 * Double(from)),
            endAngle: .degrees(138 + 264 * Double(to)),
            clockwise: false
        )
        return path
    }
}

/// Deterministic points are decoration only: no point count or position encodes a health value.
private struct AuraRestSpecks: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spinning = false

    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<42, id: \.self) { index in
                let angle = Double(index) * 2.3999632297
                let radius = 91 + CGFloat((index * 17) % 28)
                let size = CGFloat(1.1 + Double((index * 13) % 22) / 10)
                Circle()
                    .fill(Color(hex: "#D6DEFF").opacity(0.16 + Double((index * 7) % 40) / 100))
                    .frame(width: size, height: size)
                    .shadow(color: AuraPalette.rest.opacity(0.70), radius: size * 1.3)
                    .position(
                        x: geometry.size.width / 2 + CGFloat(cos(angle)) * radius,
                        y: geometry.size.height / 2 + CGFloat(sin(angle)) * radius
                    )
            }
        }
        .rotationEffect(.degrees(spinning ? 360 : 0))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 90).repeatForever(autoreverses: false)) {
                spinning = true
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Reading

struct AuraRestReading {
    struct Stage: Identifiable {
        let id: String
        let name: String
        let duration: String
        /// Canonical stage duration in minutes. Presentation bars use this value instead of parsing
        /// localized duration text back into a number.
        let minutes: Double
        /// Share of the widest stage bar, not of the night — the bars compare stages to each other.
        let fraction: Double
        let tint: Color
    }

    struct NightReading: Identifiable {
        let id: Int
        /// Local civil day on which the session ended, used to validate recency claims.
        let wakeDayKey: String
        let day: String
        let dateLabel: String
        let hours: Double
        /// The persisted/resolved 0–100 Rest score for this exact wake day. Nil remains honest.
        let score: Double?
        let note: String
        let window: String
        let hypnogram: [Int]
        let hypnogramAxis: [String]
        /// Persisted per-epoch sleep stages. Empty means the source supplied totals only; the UI must
        /// not reconstruct a plausible-looking timeline from those totals.
        let stageIntervals: [SleepInterval]
        /// Wall-clock onset paired with `stageIntervals`, used by the real Hypnogram time axis.
        let nightStart: Date?
        let stages: [Stage]

        init(
            id: Int,
            wakeDayKey: String,
            day: String,
            dateLabel: String,
            hours: Double,
            score: Double?,
            note: String,
            window: String,
            hypnogram: [Int],
            hypnogramAxis: [String],
            stageIntervals: [SleepInterval] = [],
            nightStart: Date? = nil,
            stages: [Stage]
        ) {
            self.id = id
            self.wakeDayKey = wakeDayKey
            self.day = day
            self.dateLabel = dateLabel
            self.hours = hours
            self.score = score
            self.note = note
            self.window = window
            self.hypnogram = hypnogram
            self.hypnogramAxis = hypnogramAxis
            self.stageIntervals = stageIntervals
            self.nightStart = nightStart
            self.stages = stages
        }
    }

    struct DebtNight: Identifiable {
        let id: String
        let date: String
        let slept: String
        let change: String
        let addedDebt: Bool
        let sleptMinutes: Double
        let deltaMinutes: Double
    }

    let nights: [NightReading]
    let isLoading: Bool
    let periodTitle: String
    let latestNightTitle: String
    let personalAverage: Double
    let averageNote: String
    let averageSleepValue: String
    let averageDeepValue: String
    let sleepNeedMinutes: Double
    let sleepNeedIsPersonalized: Bool
    let sleepNeedSampleCount: Int
    let debtHeadline: String
    let debtExplanation: String
    let debtIsDebt: Bool
    let debtBalanceMinutes: Double
    let debtNeedMinutes: Double
    let debtNightCount: Int
    let debtNights: [DebtNight]

    var headline: String {
        guard let latest = nights.last else { return String(localized: "No sleep recorded yet") }
        return String(localized: "You slept \(AuraRestReading.durationText(latest.hours * 60))")
    }

    private static func durationText(_ minutes: Double) -> String {
        let rounded = max(0, Int(minutes.rounded()))
        return String(localized: "\(rounded / 60)h \(rounded % 60)m")
    }

    #if DEBUG
    /// Visual-regression fixture only. Release builds always use AuraRestReading.live.
    /// The figures are internally consistent so no interaction reveals a contradictory value.
    static let prototype = AuraRestReading(
        nights: [
            NightReading(id: 0, wakeDayKey: "2026-08-10", day: "S", dateLabel: "10/8", hours: 5.5, score: nil,
                  note: String(localized: "5h 30m of sleep was recorded."), window: "01:12 – 06:42", hypnogram: [], hypnogramAxis: [], stages: []),
            NightReading(id: 1, wakeDayKey: "2026-08-11", day: "M", dateLabel: "11/8", hours: 7.3, score: nil,
                  note: String(localized: "7h 18m of sleep was recorded."), window: "23:02 – 06:20", hypnogram: [], hypnogramAxis: [], stages: []),
            NightReading(id: 2, wakeDayKey: "2026-08-12", day: "T", dateLabel: "12/8", hours: 5.5, score: nil,
                  note: String(localized: "5h 30m of sleep was recorded."), window: "23:48 – 05:18", hypnogram: [], hypnogramAxis: [], stages: []),
            NightReading(id: 3, wakeDayKey: "2026-08-13", day: "W", dateLabel: "13/8", hours: 6.1, score: nil,
                  note: String(localized: "6h 06m of sleep was recorded."), window: "23:36 – 05:42", hypnogram: [], hypnogramAxis: [], stages: []),
            NightReading(id: 4, wakeDayKey: "2026-08-14", day: "T", dateLabel: "14/8", hours: 7.0, score: nil,
                  note: String(localized: "7h 00m of sleep was recorded."), window: "23:20 – 06:20", hypnogram: [], hypnogramAxis: [], stages: []),
            NightReading(id: 5, wakeDayKey: "2026-08-15", day: "F", dateLabel: "15/8", hours: 6.6, score: nil,
                  note: String(localized: "6h 36m of sleep was recorded."), window: "00:04 – 06:40", hypnogram: [], hypnogramAxis: [], stages: []),
            NightReading(id: 6, wakeDayKey: "2026-08-16", day: "S", dateLabel: "16/8", hours: 7.2, score: nil,
                  note: String(localized: "Deep sleep came early in this recorded night."), window: "23:14 – 06:41",
                  hypnogram: prototypeHypnogram, hypnogramAxis: ["23:14", "01:30", "04:00", "06:41"], stages: prototypeStages),
        ],
        isLoading: false,
        periodTitle: String(localized: "Recent nights"),
        latestNightTitle: String(localized: "Latest recorded night"),
        personalAverage: 2712.0 / 420.0,
        averageNote: String(localized: "Across these 7 recorded nights, average sleep was 6h 27m."),
        averageSleepValue: "6.5",
        averageDeepValue: "1.6",
        sleepNeedMinutes: 425,
        sleepNeedIsPersonalized: false,
        sleepNeedSampleCount: 7,
        debtHeadline: String(localized: "4h 23m debt"),
        debtExplanation: String(localized: "Running balance across 7 recorded nights against a 7h 05m nightly need. Short nights add debt; longer nights pay it back."),
        debtIsDebt: true,
        debtBalanceMinutes: -263,
        debtNeedMinutes: 425,
        debtNightCount: 7,
        debtNights: [
            DebtNight(id: "2026-08-10", date: "10/8", slept: "5h 30m slept", change: "+1h 35m debt", addedDebt: true, sleptMinutes: 330, deltaMinutes: -95),
            DebtNight(id: "2026-08-11", date: "11/8", slept: "7h 18m slept", change: "−13m debt", addedDebt: false, sleptMinutes: 438, deltaMinutes: 13),
            DebtNight(id: "2026-08-12", date: "12/8", slept: "5h 30m slept", change: "+1h 35m debt", addedDebt: true, sleptMinutes: 330, deltaMinutes: -95),
            DebtNight(id: "2026-08-13", date: "13/8", slept: "6h 06m slept", change: "+59m debt", addedDebt: true, sleptMinutes: 366, deltaMinutes: -59),
            DebtNight(id: "2026-08-14", date: "14/8", slept: "7h 00m slept", change: "+5m debt", addedDebt: true, sleptMinutes: 420, deltaMinutes: -5),
            DebtNight(id: "2026-08-15", date: "15/8", slept: "6h 36m slept", change: "+29m debt", addedDebt: true, sleptMinutes: 396, deltaMinutes: -29),
            DebtNight(id: "2026-08-16", date: "16/8", slept: "7h 12m slept", change: "−7m debt", addedDebt: false, sleptMinutes: 432, deltaMinutes: 7),
        ]
    )

    private static let prototypeHypnogram = [
        1, 1, 2, 3, 3, 3, 2, 2, 3, 3, 2, 1, 0, 1, 2, 3, 3,
        2, 2, 1, 1, 2, 2, 3, 2, 1, 0, 1, 1, 2, 2, 1, 1, 0,
    ]

    private static let prototypeStages = [
        Stage(id: "deep", name: String(localized: "Deep"), duration: "1h 34m", minutes: 94,
              fraction: 94.0 / 222.0, tint: NoopSpecTokens.lavender),
        Stage(id: "rem", name: String(localized: "REM"), duration: "1h 48m", minutes: 108,
              fraction: 108.0 / 222.0, tint: NoopSpecTokens.lavender.opacity(0.82)),
        Stage(id: "light", name: String(localized: "Light"), duration: "3h 42m", minutes: 222,
              fraction: 1, tint: NoopSpecTokens.lavender.opacity(0.60)),
        Stage(id: "awake", name: String(localized: "Awake"), duration: "8m", minutes: 8,
              fraction: 8.0 / 222.0, tint: NoopSpecTokens.lavender.opacity(0.26)),
    ]
    #endif
}
#endif
