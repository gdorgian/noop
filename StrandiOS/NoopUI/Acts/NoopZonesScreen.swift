#if os(iOS)
import SwiftUI
import StrandAnalytics

/// Your zones: five heart-rate zones built from what the strap has seen on the wearer.
///
/// Until fourteen nights and a confirmed age exist they are an estimate, and the page says so. After that the
/// floor is the wearer's own resting pulse, and a higher held peak is offered as the maximum. The wearer can
/// also set the maximum, or every edge, by hand. Zone edges only change what a heart rate is called; the
/// maximum also feeds Effort, which the page says where it matters.
struct NoopZonesScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var profile: ProfileStore
    @ObservedObject var zones: PersonalZonesModel
    @AppStorage("noop.energy.profileConfirmed") private var profileConfirmed = false

    @State private var selectedZone: Int?
    @State private var editingMax = false
    @State private var maxDraft = 0
    @State private var appeared = false
    @State private var acceptedPulse = 0
    @State private var repoLoaded = false

    private static let colors = NoopSessionHeart.zoneColors

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: NoopSpace.m) {
                NoopBackHeader(label: "Your record") { navigation.back(or: .record) }
                    .padding(.horizontal, -2)
                    .padding(.bottom, -10)
                header
                spectrum
                anchors
                if let offer = zones.offer, trusted { offerCard(offer) }
                if trusted, !zones.peaks.isEmpty { reachedCard }
                modePicker
                zoneRows
                footnote
            }
        }
        // Again once the store finishes loading: opened at launch, the first pass finds nothing to read.
        .task(id: repoLoaded) {
            await zones.refresh(repo: model.repo, profile: profile, force: true)
        }
        .onReceive(model.repo.$loaded) { repoLoaded = $0 }
        .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.86).delay(0.05)) { appeared = true } }
        .sensoryFeedback(.success, trigger: acceptedPulse)
    }

    // MARK: - State

    private var set: HRZoneSet { profile.hrZoneSet }
    private var mode: Mode {
        switch profile.hrZoneConfig.mode {
        case .auto: profile.zonesFromResting ? .personal : .percent
        case .percent, .bpm: .own
        }
    }
    /// An age-formula maximum over an age the wearer never confirmed is not theirs, so no zone is printed.
    private var trusted: Bool { profile.hrMaxOverride > 0 || profileConfirmed }
    private var floor: Double? { profile.zoneRestingFloor > 0 ? profile.zoneRestingFloor : nil }
    private var personalActive: Bool { profile.personalZoneSet != nil }
    private var nightsHave: Int { min(model.repo.days.suffix(ReserveZones.nightsNeeded).compactMap(\.restingHr).count,
                                       ReserveZones.nightsNeeded) }

    private enum Mode: Hashable { case personal, percent, own }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your zones")
                .font(NoopHTMLFont.outfit(NoopType.title2))
                .tracking(-0.6)
                .foregroundStyle(NoopHTMLColor.ink)
            Text(headline)
                .font(NoopHTMLFont.sans(NoopType.footnote))
                .foregroundStyle(NoopHTMLColor.copy)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
    }

    private var headline: String {
        if !trusted { return "Confirm your age on your profile, or set your maximum below, and your zones appear here." }
        switch mode {
        case .own: return "Edges you set yourself. They stay where you put them."
        case .percent: return "Steps of your maximum, the way most watches draw them."
        case .personal:
            if personalActive {
                return profile.hrMaxSource == "measured"
                    ? "Built from your resting pulse and the highest pulse you have held. Both measured on you."
                    : "Built on your own resting pulse. They move when it does."
            }
            return profile.hrMaxOverride > 0
                ? "Steps of your maximum for now. After fourteen nights they stand on your own resting pulse."
                : "Estimated from your age for now. After fourteen nights they stand on your own resting pulse."
        }
    }

    // MARK: - Spectrum

    /// The five zones as one band from the resting floor (or zero) to the maximum, edges printed beneath and
    /// the highest pulse held in six months pinned above. Tapping a zone opens it below.
    private var spectrum: some View {
        // The quiet stretch below Zone 1 gets a short lead-in, not its true width: on a reserve it is half
        // the scale and would squeeze the five zones into the other half.
        let zoneStart = set.zones.first?.lower ?? 0
        let lower = max(floor ?? 0, zoneStart - (set.maxHR - zoneStart) * 0.18)
        let span = max(set.maxHR - lower, 1)
        return NoopHTMLCard(radius: NoopRadius.card, padding: NoopSpace.m) {
            VStack(alignment: .leading, spacing: NoopSpace.s) {
                HStack(alignment: .firstTextBaseline) {
                    NoopSectionLabel("From rest to all out")
                    Spacer()
                    if trusted, let highest = zones.highest {
                        Text("held \(highest.bpm) at most")
                            .font(NoopHTMLFont.sans(NoopType.eyebrow))
                            .foregroundStyle(NoopHTMLColor.faint)
                            .monospacedDigit()
                    }
                }
                GeometryReader { geo in
                    let w = geo.size.width
                    let x: (Double) -> CGFloat = { CGFloat(($0 - lower) / span) * w }
                    ZStack(alignment: .topLeading) {
                        // Below Zone 1: the quiet floor.
                        Capsule().fill(Color.white.opacity(0.05)).frame(height: 18).offset(y: 22)
                        ForEach(Array(set.zones.enumerated()), id: \.offset) { i, z in
                            let start = x(z.lower), end = x(z.upper)
                            let on = selectedZone == nil || selectedZone == i
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Self.colors[i + 1].opacity(trusted ? (on ? 1 : 0.28) : 0.18))
                                .frame(width: max(appeared ? end - start - 2 : 0, 0), height: selectedZone == i ? 24 : 18)
                                .offset(x: start + 1, y: selectedZone == i ? 19 : 22)
                                .animation(.spring(response: 0.55, dampingFraction: 0.82).delay(Double(i) * 0.06), value: appeared)
                                .animation(NoopMotion.swap, value: selectedZone)
                                .contentShape(Rectangle())
                                .onTapGesture { withAnimation(NoopMotion.swap) { selectedZone = selectedZone == i ? nil : i } }
                                .accessibilityLabel("Zone \(i + 1), \(Int(z.lower)) to \(Int(z.upper)) beats per minute")
                        }
                        if trusted, let highest = zones.highest, Double(highest.bpm) > lower {
                            let px = min(max(x(Double(highest.bpm)), 6), w - 6)
                            VStack(spacing: 2) {
                                Image(systemName: "arrowtriangle.down.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(NoopHTMLColor.ink)
                            }
                            .offset(x: px - 5, y: appeared ? 6 : -4)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4), value: appeared)
                        }
                        if trusted {
                            ForEach(Array(edgeLabels(lower: lower).enumerated()), id: \.offset) { _, edge in
                                Text("\(edge.bpm)")
                                    .font(NoopHTMLFont.sans(NoopType.eyebrow))
                                    .foregroundStyle(NoopHTMLColor.faint)
                                    .monospacedDigit()
                                    .fixedSize()
                                    .frame(width: 34)
                                    .offset(x: min(max(x(Double(edge.bpm)) - 17, -6), w - 28), y: 48)
                            }
                        }
                    }
                }
                .frame(height: trusted ? 66 : 44)
            }
        }
    }

    /// Edges worth printing: the floor, each zone's start, the maximum, skipping any too close to the last.
    private func edgeLabels(lower: Double) -> [(bpm: Int, at: Double)] {
        var values = [Int((floor ?? lower).rounded())] + set.zones.map { Int($0.lower.rounded()) } + [Int(set.maxHR.rounded())]
        values = Array(Set(values)).sorted()
        let minGap = max((set.maxHR - lower) * 0.075, 6)
        var kept: [Int] = []
        let top = Int(set.maxHR.rounded())
        for v in values.dropLast() where kept.last.map({ Double(v - $0) >= minGap }) ?? true { kept.append(v) }
        // The maximum always prints; an edge crowding it gives way.
        while let last = kept.last, Double(top - last) < minGap { kept.removeLast() }
        kept.append(top)
        return kept.map { ($0, Double($0)) }
    }

    // MARK: - Anchors

    private var anchors: some View {
        VStack(spacing: NoopSpace.xs + 1) {
            HStack(alignment: .top, spacing: NoopSpace.xs + 1) {
                Button {
                    maxDraft = profile.hrMax
                    withAnimation(NoopMotion.swap) { editingMax.toggle() }
                } label: {
                    anchorCard(value: trusted || profile.hrMaxOverride > 0 ? "\(profile.hrMax)" : "\u{2014}",
                               title: maxTitle, line: maxLine, live: editingMax)
                }
                .buttonStyle(NoopHTMLPressStyle())
                .accessibilityHint("Set your maximum")

                anchorCard(value: floor.map { "\(Int($0.rounded()))" } ?? "\u{2014}",
                           title: "Resting floor",
                           line: floor != nil ? "Middle of your last fourteen nights" : "\(nightsHave) of 14 nights so far",
                           progress: floor == nil ? Double(nightsHave) / Double(ReserveZones.nightsNeeded) : nil)
            }
            .fixedSize(horizontal: false, vertical: true)
            if editingMax { maxEditor.transition(.move(edge: .top).combined(with: .opacity)) }
        }
    }

    private var maxTitle: String {
        if profile.hrMaxOverride > 0 { return profile.hrMaxSource == "measured" ? "Maximum, measured" : "Maximum, yours" }
        return "Maximum, estimated"
    }

    private var maxLine: String {
        if profile.hrMaxOverride > 0 {
            if profile.hrMaxSource == "measured", let day = Self.dayLabel(profile.hrMaxMeasuredDay) {
                return "Held for 30 seconds, \(day)"
            }
            return "Set by you. Tap to change"
        }
        return trusted ? "From your age. Tap to set your own" : "Tap to set your own"
    }

    private func anchorCard(value: String, title: String, line: String, live: Bool = false,
                            progress: Double? = nil) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(NoopHTMLFont.outfit(NoopType.title2, weight: .light))
                    .tracking(-0.8)
                    .foregroundStyle(NoopHTMLColor.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("bpm").font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.muted)
            }
            Text(title).font(NoopHTMLFont.sans(NoopType.caption, weight: .medium)).foregroundStyle(NoopHTMLColor.inkSoft)
            Text(line)
                .font(NoopHTMLFont.sans(NoopType.eyebrow))
                .foregroundStyle(NoopHTMLColor.faint)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            if let progress {
                NoopProgressBar(progress: progress, color: NoopHTMLColor.blush, height: 3)
                    .padding(.top, 3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(NoopSpace.m)
        .background(live ? NoopHTMLColor.blush.opacity(0.08) : NoopHTMLColor.card,
                    in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous)
            .strokeBorder(live ? NoopHTMLColor.blush.opacity(0.32) : NoopHTMLColor.border, lineWidth: 0.5))
    }

    private var maxEditor: some View {
        NoopHTMLCard(radius: NoopRadius.card, padding: NoopSpace.m) {
            VStack(alignment: .leading, spacing: NoopSpace.s) {
                HStack(spacing: NoopSpace.m) {
                    NoopZoneStepper(systemImage: "minus", label: "Lower") { maxDraft = max(maxDraft - 1, 120) }
                    VStack(spacing: 0) {
                        Text("\(maxDraft)")
                            .font(NoopHTMLFont.outfit(NoopType.title1, weight: .light))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(maxDraft)))
                            .animation(.snappy(duration: 0.18), value: maxDraft)
                        Text("beats a minute, at most")
                            .font(NoopHTMLFont.sans(NoopType.eyebrow))
                            .foregroundStyle(NoopHTMLColor.faint)
                    }
                    .frame(maxWidth: .infinity)
                    NoopZoneStepper(systemImage: "plus", label: "Raise") { maxDraft = min(maxDraft + 1, 230) }
                }
                .sensoryFeedback(.selection, trigger: maxDraft)
                Text("Effort scores against this from today. Days already scored keep theirs.")
                    .font(NoopHTMLFont.sans(NoopType.eyebrow))
                    .foregroundStyle(NoopHTMLColor.faint)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: NoopSpace.xs) {
                    if profile.hrMaxOverride > 0 {
                        NoopActionButton(title: "Use the estimate", variant: .secondary, size: .medium) {
                            profile.setManualMax(0)
                            withAnimation(NoopMotion.swap) { editingMax = false }
                        }
                    }
                    NoopActionButton(title: "Set \(maxDraft)", variant: .primary, size: .medium,
                                     enabled: maxDraft != profile.hrMax || profile.hrMaxOverride == 0) {
                        profile.setManualMax(maxDraft)
                        acceptedPulse += 1
                        withAnimation(NoopMotion.swap) { editingMax = false }
                    }
                }
            }
        }
    }

    // MARK: - Offer

    private func offerCard(_ offer: PersonalZonesModel.Offer) -> some View {
        VStack(alignment: .leading, spacing: NoopSpace.s) {
            HStack(spacing: NoopSpace.xs) {
                Image(systemName: "arrow.up.heart.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.blush)
                    .symbolEffect(.pulse, options: .repeat(2), value: appeared)
                Text("A higher maximum, seen on you")
                    .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.ink)
            }
            Text("Your heart held \(offer.bpm) for thirty seconds on two separate days\(Self.dayLabel(offer.day).map { ", first \($0)" } ?? ""). Your zones assume \(profile.hrMax).")
                .font(NoopHTMLFont.sans(NoopType.caption))
                .foregroundStyle(NoopHTMLColor.copy)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Text("Taking it moves every zone up and scores Effort against \(offer.bpm) from today.")
                .font(NoopHTMLFont.sans(NoopType.eyebrow))
                .foregroundStyle(NoopHTMLColor.faint)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: NoopSpace.xs) {
                NoopActionButton(title: "Not now", variant: .secondary, size: .medium) {
                    withAnimation(NoopMotion.swap) { zones.decline(offer, profile: profile) }
                }
                NoopActionButton(title: "Use \(offer.bpm)", variant: .primary, size: .medium) {
                    withAnimation(NoopMotion.swap) { zones.accept(offer, profile: profile) }
                    acceptedPulse += 1
                }
            }
        }
        .padding(NoopSpace.m)
        .background(NoopHTMLColor.blush.opacity(0.08), in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous)
            .strokeBorder(NoopHTMLColor.blush.opacity(0.28), lineWidth: 0.5))
        .transition(.asymmetric(insertion: .scale(scale: 0.97).combined(with: .opacity), removal: .opacity))
    }

    // MARK: - What sessions reached

    /// Every traced session of six months as a dot at its held peak, against the zone bands: where the
    /// wearer actually trains, and how far below the maximum that sits.
    private var reachedCard: some View {
        let lower = set.zones.first?.lower ?? 0
        let top = max(set.maxHR, Double(zones.highest?.bpm ?? 0))
        let span = max(top - lower + 10, 1)
        return NoopHTMLCard(radius: NoopRadius.card, padding: NoopSpace.m) {
            VStack(alignment: .leading, spacing: NoopSpace.s) {
                HStack(alignment: .firstTextBaseline) {
                    NoopSectionLabel("What your sessions held")
                    Spacer()
                    Text("\(zones.peaks.count) in six months")
                        .font(NoopHTMLFont.sans(NoopType.eyebrow))
                        .foregroundStyle(NoopHTMLColor.faint)
                }
                GeometryReader { geo in
                    let h = geo.size.height, w = geo.size.width
                    let y: (Double) -> CGFloat = { h - CGFloat(($0 - (lower - 10)) / span) * h }
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(set.zones.enumerated()), id: \.offset) { i, z in
                            Rectangle()
                                .fill(Self.colors[i + 1].opacity(0.07))
                                .frame(width: w, height: max(y(z.lower) - y(z.upper), 0))
                                .offset(y: y(z.upper))
                        }
                        Rectangle().fill(NoopHTMLColor.ink.opacity(0.35)).frame(width: w, height: 0.5).offset(y: y(set.maxHR))
                        let count = max(zones.peaks.count - 1, 1)
                        ForEach(Array(zones.peaks.enumerated()), id: \.offset) { i, p in
                            let zone = set.zoneNumber(forBPM: Double(p.bpm))
                            Circle()
                                .fill(Self.colors[max(zone, 0)])
                                .frame(width: 7, height: 7)
                                .offset(x: CGFloat(i) / CGFloat(count) * (w - 7), y: min(max(y(Double(p.bpm)) - 3.5, 0), h - 7))
                                .scaleEffect(appeared ? 1 : 0.2)
                                .opacity(appeared ? 1 : 0)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.25 + Double(i) * 0.012), value: appeared)
                        }
                    }
                }
                .frame(height: 96)
                Text(reachedLine)
                    .font(NoopHTMLFont.sans(NoopType.caption))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var reachedLine: String {
        guard let highest = zones.highest else { return "" }
        let gap = profile.hrMax - highest.bpm
        if gap >= 15 {
            return "The most you held is \(highest.bpm), well under \(profile.hrMax). That can mean you rarely go all out, or that your real maximum is lower. A hard uphill effort settles it: Noop picks up what you hold."
        }
        if gap <= -MaxHRSuggestion.margin {
            return zones.offer != nil ? "You have held more than \(profile.hrMax). The card above can make it your maximum."
                : "You have held more than the maximum in use."
        }
        return "Your hardest sessions reach close to your maximum, so your top zones are drawn from real efforts."
    }

    // MARK: - Mode

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: NoopSpace.xs) {
            NoopSectionLabel("How they are built")
            NoopTabs(options: [("Personal", Mode.personal), ("% of max", Mode.percent), ("Your own", Mode.own)],
                     selection: Binding(get: { mode }, set: { setMode($0) }))
            if mode == .personal, !personalActive {
                Text("Personal zones need fourteen nights of resting pulse. Until then they use steps of your maximum.")
                    .font(NoopHTMLFont.sans(NoopType.eyebrow))
                    .foregroundStyle(NoopHTMLColor.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func setMode(_ next: Mode) {
        switch next {
        case .personal:
            profile.zonesFromResting = true
            _ = profile.setHRZoneConfig(.auto)
        case .percent:
            profile.zonesFromResting = false
            _ = profile.setHRZoneConfig(.auto)
        case .own:
            // Start from exactly what is on screen, so switching changes nothing until an edge is moved.
            let bounds = set.zones.map { $0.lower.rounded() }
            _ = profile.setHRZoneConfig(HRZoneConfig(mode: .bpm, percentLowerBounds: profile.hrZoneConfig.percentLowerBounds,
                                                     bpmLowerBounds: bounds))
        }
    }

    // MARK: - Zone rows

    private var zoneRows: some View {
        VStack(spacing: NoopSpace.xs + 1) {
            ForEach(Array(set.zones.enumerated()), id: \.offset) { i, z in
                zoneRow(i, z)
            }
        }
    }

    private func zoneRow(_ i: Int, _ z: HRZone) -> some View {
        let open = selectedZone == i
        let lo = Int(z.lower.rounded()), hi = Int(z.upper.rounded())
        return Button { withAnimation(NoopMotion.swap) { selectedZone = open ? nil : i } } label: {
            VStack(alignment: .leading, spacing: NoopSpace.s) {
                HStack(spacing: 11) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Self.colors[i + 1])
                        .frame(width: 10, height: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Zone \(i + 1) · \(Self.names[i])")
                            .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                            .foregroundStyle(NoopHTMLColor.ink)
                        Text(shareLine(z))
                            .font(NoopHTMLFont.sans(NoopType.caption))
                            .foregroundStyle(NoopHTMLColor.faint)
                    }
                    Spacer()
                    Text(trusted ? "\(lo)\u{2013}\(hi)" : "\u{2014}")
                        .font(NoopHTMLFont.outfit(NoopType.body))
                        .foregroundStyle(NoopHTMLColor.inkSoft)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                if open {
                    Text(Self.uses[i])
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    if mode == .own, trusted { edgeEditor(i, lower: lo) }
                }
            }
            .padding(NoopSpace.m)
            .background(open ? Self.colors[i + 1].opacity(0.07) : NoopHTMLColor.card,
                        in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous)
                .strokeBorder(open ? Self.colors[i + 1].opacity(0.3) : NoopHTMLColor.border, lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private func shareLine(_ z: HRZone) -> String {
        switch set.source {
        case "reserve":
            guard let floor else { return "" }
            let reserve = set.maxHR - floor
            let a = Int(((z.lower - floor) / reserve * 100).rounded()), b = Int(((z.upper - floor) / reserve * 100).rounded())
            return "\(a)\u{2013}\(b)% of your reserve"
        default:
            return "\(Int((z.lower / set.maxHR * 100).rounded()))\u{2013}\(Int((z.upper / set.maxHR * 100).rounded()))% of your maximum"
        }
    }

    /// Nudge one lower edge by a beat. The neighbours bound it, so the zones can never overlap or invert.
    private func edgeEditor(_ i: Int, lower: Int) -> some View {
        let bounds = set.zones.map { $0.lower.rounded() }
        let floorBound = i == 0 ? 60.0 : bounds[i - 1] + 1
        let ceilingBound = i == bounds.count - 1 ? set.maxHR - 1 : bounds[i + 1] - 1
        let move: (Double) -> Void = { delta in
            var next = bounds
            next[i] = min(max(next[i] + delta, floorBound), ceilingBound)
            _ = profile.setHRZoneConfig(HRZoneConfig(mode: .bpm, percentLowerBounds: profile.hrZoneConfig.percentLowerBounds,
                                                     bpmLowerBounds: next))
        }
        return HStack(spacing: NoopSpace.s) {
            Text("Starts at")
                .font(NoopHTMLFont.sans(NoopType.caption))
                .foregroundStyle(NoopHTMLColor.copy)
            Spacer()
            NoopZoneStepper(systemImage: "minus", label: "Lower the edge") { move(-1) }
            Text("\(lower)")
                .font(NoopHTMLFont.outfit(NoopType.title3, weight: .light))
                .monospacedDigit()
                .frame(minWidth: 48)
                .contentTransition(.numericText(value: Double(lower)))
                .animation(.snappy(duration: 0.18), value: lower)
            NoopZoneStepper(systemImage: "plus", label: "Raise the edge") { move(1) }
        }
        .sensoryFeedback(.selection, trigger: lower)
    }

    private var footnote: some View {
        Text("Zones change what Noop calls a heart rate: time in zone, the live readout, the session coach. Only the maximum reaches Effort.")
            .font(NoopHTMLFont.sans(NoopType.eyebrow))
            .foregroundStyle(NoopHTMLColor.faint)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, NoopSpace.xs)
    }

    // MARK: - Copy

    private static let names = ["Recover", "Easy", "Steady", "Hard", "All out"]
    private static let uses = [
        "Walking, an easy spin, the cool-down. It loads almost nothing and helps the day after a hard one.",
        "Talking pace. Where most weekly hours should go: it builds the engine without costing tomorrow.",
        "You can talk, in short sentences. Honest aerobic work, and the zone that tires you more than it feels like.",
        "Breathing hard, a few words at a time. Intervals and climbs. A session here asks for an easy day after.",
        "Seconds to a couple of minutes. Sprints, the end of a race. Rare by design."
    ]

    /// "3 Oct", or nil for an empty or unreadable day.
    static func dayLabel(_ day: String) -> String? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: day) else { return nil }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}

/// A round minus/plus: a tap is one beat, holding repeats.
private struct NoopZoneStepper: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            NoopIconDiscShape(size: .medium) {
                Image(systemName: systemImage).font(.system(size: 16, weight: .semibold))
            }
        }
        .buttonStyle(NoopHTMLPressStyle())
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(label)
    }
}
#endif
