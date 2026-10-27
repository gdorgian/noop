import SwiftUI

// MARK: - Editable pages
//
// Every page is a list of sections the wearer can remove, add back and reorder. The page lists its
// sections in default order; the layout keeps the wearer's order per page. A section added in a
// later build is not one the wearer removed, so it is slotted in at its default place the first
// time the page sees it. Editing happens on the live page: each section gets a remove disc and can
// be dragged, and the page's own spacing is kept, with no titles added between sections.
//
// A page opens in its original look: only sections marked `onByDefault` are on it until the wearer
// adds others. Alternative designs sit in the Add sheet.

struct NoopPageSection: Identifiable, Hashable {
    let id: String
    let title: String
    /// One line for the Add sheet and for the placeholder an empty section shows while editing.
    let detail: String
    var removable = true
    /// On the page before the wearer changes anything. Alternative designs are off, waiting in Add.
    var onByDefault = true
    /// Stays interactive while the page is being edited, for a section with its own controls in edit
    /// mode (hiding cards inside it, say). Others are drawn but not touchable while editing.
    var liveWhileEditing = false
    /// A small tile that takes half the page's width; two in a row sit side by side.
    var half = false
}

@MainActor
final class NoopPageLayout: ObservableObject {
    let page: String
    let catalog: [NoopPageSection]
    @Published private(set) var order: [String]
    /// Default-on sections a later build added to a page the wearer had already arranged. They are
    /// offered on the page ("New on this page") instead of slipped in, so an arranged page never
    /// changes behind the wearer's back (26 Oct 2026). Fresh pages simply have them.
    @Published private(set) var suggestions: [String] = []

    private var orderKey: String { Self.orderKey(page) }
    private var knownKey: String { "noop.layout.\(page).known" }
    private var versionKey: String { "noop.layout.\(page).version" }
    private var resetObserver: NSObjectProtocol?

    static func orderKey(_ page: String) -> String { "noop.layout.\(page)" }

    /// Raised when the meaning of a saved layout changes. Version 2: alternative sections became
    /// off by default, so layouts saved before then (which held every section) start over.
    static let version = 2

    init(page: String, catalog: [NoopPageSection]) {
        self.page = page
        self.catalog = catalog
        let defaults = UserDefaults.standard
        let ids = catalog.filter(\.onByDefault).map(\.id)
        if defaults.integer(forKey: "noop.layout.\(page).version") < Self.version {
            defaults.removeObject(forKey: "noop.layout.\(page)")
            defaults.removeObject(forKey: "noop.layout.\(page).known")
            defaults.set(Self.version, forKey: "noop.layout.\(page).version")
        }
        if let saved = defaults.string(forKey: "noop.layout.\(page)") {
            let allIDs = catalog.map(\.id)
            let known = Set((defaults.string(forKey: "noop.layout.\(page).known") ?? saved).split(separator: ",").map(String.init))
            var result = saved.split(separator: ",").map(String.init).filter { allIDs.contains($0) || Self.isSpacer($0) }
            // Sections that cannot be removed are always present.
            for (index, section) in catalog.enumerated() where !section.removable && !result.contains(section.id) {
                result.insert(section.id, at: min(index, result.count))
            }
            order = result
            suggestions = ids.filter { !known.contains($0) && !result.contains($0) }
        } else {
            order = ids
        }
        resetObserver = NotificationCenter.default.addObserver(forName: Self.resetAll, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.useDefault() }
        }
    }

    deinit {
        if let resetObserver { NotificationCenter.default.removeObserver(resetObserver) }
    }

    func section(_ id: String) -> NoopPageSection? { catalog.first { $0.id == id } ?? Self.spacerSection(id) }

    // MARK: Space and dividers
    //
    // A page can hold any number of blank spaces and thin dividers (testers, 27 Oct 2026). Each one is its own
    // entry, `noop.space.<n>` or `noop.divider.<n>`, so several can sit in one page; the page never draws them
    // itself, the editable list does.

    static let spacePrefix = "noop.space."
    static let dividerPrefix = "noop.divider."

    static func isSpacer(_ id: String) -> Bool { id.hasPrefix(spacePrefix) || id.hasPrefix(dividerPrefix) }

    /// How tall a space is. The size rides in the id (`noop.space.s.<n>`); an id without one, saved
    /// before sizes existed, is medium.
    enum SpaceSize: String, CaseIterable {
        case small = "s", medium = "m", large = "l"
        var height: CGFloat { switch self { case .small: 12; case .medium: 28; case .large: 56 } }
        var title: String { switch self { case .small: "Small space"; case .medium: "Space"; case .large: "Large space" } }
    }

    static func spaceSize(_ id: String) -> SpaceSize {
        let rest = id.dropFirst(spacePrefix.count)
        guard rest.count > 2, rest.dropFirst().first == "." else { return .medium }
        return SpaceSize(rawValue: String(rest.prefix(1))) ?? .medium
    }

    static func newSpacerID(divider: Bool, size: SpaceSize = .medium) -> String {
        let n = String(UUID().uuidString.prefix(8)).lowercased()
        return divider ? dividerPrefix + n : spacePrefix + size.rawValue + "." + n
    }

    static func spacerSection(_ id: String) -> NoopPageSection? {
        if id.hasPrefix(spacePrefix) {
            let size = spaceSize(id)
            return NoopPageSection(id: id, title: size.title, detail: "A blank gap, \(Int(size.height)) points tall")
        }
        if id.hasPrefix(dividerPrefix) { return NoopPageSection(id: id, title: "Divider", detail: "A thin line between sections") }
        return nil
    }

    func save(_ newOrder: [String]) {
        order = newOrder
        UserDefaults.standard.set(newOrder.joined(separator: ","), forKey: orderKey)
        // A section still on offer stays unknown, so saving an edit does not quietly decline it.
        UserDefaults.standard.set(catalog.map(\.id).filter { !suggestions.contains($0) }.joined(separator: ","), forKey: knownKey)
        UserDefaults.standard.set(Self.version, forKey: versionKey)
    }

    var defaultOrder: [String] { catalog.filter(\.onByDefault).map(\.id) }

    /// Put an offered section in at its default place: after the nearest default section above it.
    func acceptSuggestion(_ id: String) {
        suggestions.removeAll { $0 == id }
        var result = order
        let ids = defaultOrder
        if let index = ids.firstIndex(of: id), !result.contains(id) {
            let before = ids[..<index].last { result.contains($0) }
            let at = before.flatMap { result.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
            result.insert(id, at: at)
        }
        save(result)
    }

    /// Decline an offered section: it stays in Add, and is not offered again.
    func declineSuggestion(_ id: String) {
        suggestions.removeAll { $0 == id }
        save(order)
    }

    /// Forget the arrangement: the page shows its default, as on a fresh install.
    func useDefault() {
        UserDefaults.standard.removeObject(forKey: orderKey)
        UserDefaults.standard.removeObject(forKey: knownKey)
        suggestions = []
        order = defaultOrder
    }

    /// Posted to put every open page back on its default at once (the new-look choice).
    static let resetAll = Notification.Name("noop.layout.resetAll")

    /// Whether the wearer has a saved arrangement for `page` that differs from `catalog`'s default.
    static func hasArrangement(page: String, catalog: [NoopPageSection]) -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: "noop.layout.\(page).version") >= version,
              let saved = defaults.string(forKey: orderKey(page)) else { return false }
        let allIDs = Set(catalog.map(\.id))
        let order = saved.split(separator: ",").map(String.init).filter { allIDs.contains($0) || isSpacer($0) }
        return order != catalog.filter(\.onByDefault).map(\.id)
    }

    /// Every page back on its default: the saved arrangements are forgotten, and pages already open
    /// redraw at once.
    static func resetAllToDefault(pages: [String]) {
        for page in pages {
            UserDefaults.standard.removeObject(forKey: orderKey(page))
            UserDefaults.standard.removeObject(forKey: "noop.layout.\(page).known")
        }
        NotificationCenter.default.post(name: resetAll, object: nil)
    }
}

/// The edit session a page holds: the order being edited, kept apart until Save.
struct NoopPageEditing {
    var active = false
    var draft: [String] = []
    var adding = false
    /// Counts saves; each one drops a ripple on the page.
    var saves = 0
    /// Set when Add was opened from the free half beside a lone tile: the sheet offers tiles only,
    /// and the one picked goes in beside it.
    var addBeside: String?
    /// A section being dragged out of the Add sheet onto the page.
    var incoming: String?
}

/// Lays out a page's sections in the wearer's order. While editing, every section carries a remove
/// disc and can be held and carried to a new place, and the foot of the page offers Add and Reset;
/// otherwise the foot offers Edit. Each step answers with its own tap: picked up, passed, dropped,
/// removed, added, reset.
struct NoopEditableSections<Section: View>: View {
    @ObservedObject var layout: NoopPageLayout
    @Binding var editing: NoopPageEditing
    var spacing: CGFloat = 10
    /// Whether a section has nothing to show right now; it is skipped, or drawn as a placeholder
    /// while editing so it can still be moved or removed.
    var isEmpty: (String) -> Bool = { _ in false }
    /// Fixed content after the last section and before Edit page: part of the page, never part of
    /// its arrangement (You's Settings, 27 Oct 2026). Hidden while editing.
    var trailing: AnyView? = nil
    @ViewBuilder let section: (String) -> Section

    /// The section being carried, where its middle was when it was picked up, and how far the
    /// finger has moved since. Each section's frame is kept so the carried one can swap places as its
    /// middle passes another's.
    @State private var dragging: String?
    @State private var dragStartMid: CGPoint = .zero
    /// How far the finger has moved, kept out of the page's own state: it changes every frame of a
    /// carry, and as state it redrew every section on the page each frame.
    @StateObject private var carryMotion = NoopCarryMotion()
    @State private var frames: [String: CGRect] = [:]
    /// Where the page sits on screen, so a save's wave starts in the middle of what is in view.
    /// Where the sections sit on screen, read only when Save sends its wave. Kept in a reference
    /// rather than state: it changes on every scroll frame, and as state it re-rendered the whole
    /// page each frame (thousands of updates a second while scrolling, profiled 25 Oct 2026).
    @State private var screenFrame = NoopFrameBox()
    /// The wave running through the page after a drop or a save, and how far through it is (0 to 1),
    /// animated linearly so every section reads its own push from the same moment.
    @State private var wave: NoopSurfaceWave?
    @State private var waveProgress: Double = 0
    /// Where a section carried out of the Add sheet is, on screen.
    @StateObject private var incomingDrag = NoopIncomingDrag()

    /// What the page draws, in order: its sections, and while editing a "+ Add" in the free half
    /// beside a tile that has no partner.
    private var entries: [String] {
        let ids = editing.active ? editing.draft : layout.order.filter { !isEmpty($0) }
        guard editing.active else { return ids }
        var result: [String] = []
        var index = 0
        while index < ids.count {
            let id = ids[index]
            result.append(id)
            if isHalf(id) {
                if index + 1 < ids.count, isHalf(ids[index + 1]) {
                    result.append(ids[index + 1])
                    index += 1
                } else if dragging == nil {
                    result.append(Self.besidePrefix + id)
                }
            }
            index += 1
        }
        return result
    }

    private static var besidePrefix: String { "noop.add-beside." }
    private func isHalf(_ id: String) -> Bool {
        id.hasPrefix(Self.besidePrefix) || (layout.section(id)?.half ?? false)
    }

    /// One question at a time: while the new-look choice is open on Today, no page offers sections.
    @AppStorage(NoopDefaults.lookChoiceKey) private var lookChoice = ""
    private var offersSuggestions: Bool { !lookChoice.isEmpty || !NoopDefaults.lookChoicePendingAtLaunch }

    var body: some View {
        NoopSectionFlow(spacing: spacing) {
            if !editing.active, offersSuggestions, let id = layout.suggestions.first, let info = layout.section(id) {
                suggestionCard(info)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
            ForEach(entries, id: \.self) { id in
                Group {
                    if id.hasPrefix(Self.besidePrefix) {
                        addBeside(String(id.dropFirst(Self.besidePrefix.count)))
                    } else if editing.active {
                        editable(id)
                    } else {
                        draw(id)
                    }
                }
                .layoutValue(key: NoopHalfWidth.self, value: isHalf(id))
                // Each section's place in the page, measured before any carry or wave moves it.
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { frames[id] = proxy.frame(in: .named("noop.sections")) }
                            .onChange(of: proxy.frame(in: .named("noop.sections"))) { _, frame in frames[id] = frame }
                    }
                }
                .modifier(NoopWaveMotion(wave: wave, id: id, frame: frames[id], progress: waveProgress))
                // Like the Home Screen: hold any section to start editing and carry it in the same
                // press; while editing, a short hold is enough. The press sits on the page's own
                // element, so it survives the switch into editing mid-gesture.
                .modifier(NoopReorderPress(enabled: editing.active && !id.hasPrefix(Self.besidePrefix),
                                           holdSeconds: 0.18) { phase in carry(id, phase) })
                // Outside editing, a hold on any section starts it, alongside the section's own taps.
                .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                    guard !editing.active else { return }
                    NoopHaptics.prepare()
                    NoopHaptics.play(.enterEdit)
                    editing.draft = layout.order
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { editing.active = true }
                }, including: editing.active ? .subviews : .all)
                // Layering and removal belong to the ForEach's own children, or the lifted card
                // would draw under the sections after it.
                .zIndex(dragging == id ? 1 : 0)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
            if let trailing, !editing.active { trailing }
            foot.padding(.top, 14)
        }
        // Room for Cancel and Save, so the first section's remove disc never sits under them.
        .padding(.top, editing.active ? 52 : 0)
        .coordinateSpace(name: "noop.sections")
        // A section carried out of the Add sheet: the page makes room under the finger as it moves.
        // Only this small observer follows the finger, so the page is not redrawn every frame.
        .background(NoopIncomingObserver(drag: incomingDrag) { point in
            place(incomingAt: CGPoint(x: point.x - screenFrame.rect.minX, y: point.y - screenFrame.rect.minY))
        })
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { screenFrame.rect = $0 }
        .onChange(of: editing.saves) {
            let middle = UIScreen.main.bounds.midY - screenFrame.rect.minY
            send(NoopSurfaceWave(origin: CGRect(x: 0, y: middle, width: screenFrame.rect.width, height: 0)))
        }
        // Leaving the page mid-edit (another tab) drops the unsaved edit rather than keeping it open.
        .onDisappear { if editing.active { editing.active = false } }
        #if DEBUG
        .onAppear {
            if CommandLine.arguments.contains("--noop-edit-page"), !editing.active {
                editing.draft = layout.order
                editing.active = true
            }
        }
        #endif
        .fullScreenCover(isPresented: $editing.adding, onDismiss: {
            editing.addBeside = nil
            // Landed: the page answers with its wave from where it went.
            if let id = incomingDrag.landed, let frame = frames[id] {
                send(NoopSurfaceWave(origin: frame, delay: 0.05, source: id))
            }
            incomingDrag.landed = nil
        }) {
            NoopAddSectionSheet(layout: layout, editing: $editing, drag: incomingDrag, isEmpty: isEmpty,
                                section: { id in AnyView(draw(id)) })
        }
    }

    /// One section a later build added, offered on a page the wearer had already arranged.
    private func suggestionCard(_ info: NoopPageSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.blueLight)
                    .frame(width: 30, height: 30)
                    .background(NoopHTMLColor.blue.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("New on this page")
                        .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(NoopHTMLColor.blueLight)
                    Text(info.title)
                        .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(info.detail)
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                NoopActionButton(title: "Not now", variant: .secondary, size: .small, fullWidth: true) {
                    NoopHaptics.play(.cancel)
                    withAnimation(.smooth(duration: 0.3)) { layout.declineSuggestion(info.id) }
                }
                NoopActionButton(title: "Add it", size: .small, fullWidth: true) {
                    NoopHaptics.play(.add)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) { layout.acceptSuggestion(info.id) }
                }
            }
        }
        .padding(16)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(NoopHTMLColor.blue.opacity(0.24), lineWidth: 0.5))
        .accessibilityElement(children: .contain)
    }

    /// A page section, or a space or divider the wearer put in.
    @ViewBuilder
    private func draw(_ id: String) -> some View {
        if NoopPageLayout.isSpacer(id) {
            NoopLayoutSpacer(divider: id.hasPrefix(NoopPageLayout.dividerPrefix),
                             height: NoopPageLayout.spaceSize(id).height, editing: editing.active)
        } else {
            section(id)
        }
    }

    @ViewBuilder
    private func editable(_ id: String) -> some View {
        let info = layout.section(id)
        Group {
            if isEmpty(id) {
                NoopSectionPlaceholder(title: info?.title ?? id, detail: info?.detail ?? "")
            } else {
                draw(id).allowsHitTesting(info?.liveWhileEditing ?? false)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        // Cards are see-through; a lifted one is backed with the page so nothing shows through it.
        .background {
            if dragging == id {
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(NoopHTMLColor.canvas)
            }
        }
        .scaleEffect(dragging == id ? 1.06 : 1)
        // The gap a section coming from the Add sheet will land in; the drag itself carries its look.
        .opacity(editing.incoming == id ? 0 : dragging == id ? 0.94 : 1)
        .shadow(color: .black.opacity(dragging == id ? 0.55 : 0), radius: 22, y: 12)
        .overlay(alignment: .topLeading) {
            if (info?.removable ?? true) && dragging == nil {
                Button {
                    NoopHaptics.play(.remove)
                    withAnimation(.easeInOut(duration: 0.22)) { editing.draft.removeAll { $0 == id } }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(NoopHTMLColor.ink)
                        .frame(width: 24, height: 24)
                        .background(Color(hex: 0x3A3F45), in: Circle())
                        .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 1))
                        .noopHitTarget()
                }
                .buttonStyle(NoopPlainHitStyle())
                .offset(x: -8, y: -8)
                .accessibilityLabel("Remove \(info?.title ?? id)")
            }
        }
        .modifier(NoopJiggle(active: editing.active && dragging != id, seed: id.hashValue,
                             amplitude: (layout.section(id)?.half ?? false) ? 1.1 : 0.35))
        .modifier(NoopCarryOffset(motion: carryMotion, active: dragging == id,
                                  base: CGSize(width: dragStartMid.x - (frames[id]?.midX ?? dragStartMid.x),
                                               height: dragStartMid.y - (frames[id]?.midY ?? dragStartMid.y))))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(info?.title ?? id)
        .accessibilityAction(named: "Move up") { move(id, by: -1) }
        .accessibilityAction(named: "Move down") { move(id, by: 1) }
    }

    /// Starts a wave and clears it once it has died away, so the page stops redrawing.
    private func send(_ newWave: NoopSurfaceWave) {
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) {
            wave = newWave
            waveProgress = 0
        }
        DispatchQueue.main.async {
            withAnimation(.linear(duration: NoopSurfaceWave.duration)) { waveProgress = 1 }
        }
    }

    /// One place up or down, for VoiceOver, which cannot hold and carry.
    private func move(_ id: String, by step: Int) {
        guard let from = editing.draft.firstIndex(of: id) else { return }
        let to = from + step
        guard editing.draft.indices.contains(to) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { editing.draft.swapAt(from, to) }
    }

    /// Hold to pick a section up, move to carry it; it takes the place of whichever section its
    /// middle passes, and settles where it is when the finger lifts.
    private func carry(_ id: String, _ phase: NoopReorderPress.Phase) {
        switch phase {
        case .began:
            if !editing.active {
                NoopHaptics.prepare()
                editing.draft = layout.order
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { editing.active = true }
            }
            guard editing.draft.contains(id) else { return }
            NoopHaptics.play(.lift)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                dragging = id
                dragStartMid = frames[id].map { CGPoint(x: $0.midX, y: $0.midY) } ?? .zero
                carryMotion.translation = .zero
            }
        case .moved(let delta):
            guard dragging == id else { return }
            carryMotion.translation = delta
            let point = CGPoint(x: dragStartMid.x + delta.width, y: dragStartMid.y + delta.height)
            let others = editing.draft.filter { $0 != id }
            let target = others.filter { Self.isBefore(frames[$0], point) }.count
            if editing.draft.firstIndex(of: id) != target {
                // The others make way the way Home Screen icons do: a quick, soft spring.
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    var order = others
                    order.insert(id, at: min(target, order.count))
                    editing.draft = order
                }
                NoopHaptics.play(.pass)
            }
        case .ended:
            guard dragging == id else { return }
            withAnimation(.spring(response: 0.36, dampingFraction: 0.72)) {
                dragging = nil
                carryMotion.translation = .zero
            }
            // It lands like a drop: the page moves out from its edges, and the phone feels it.
            NoopHaptics.play(.land)
            if let landed = frames[id] {
                send(NoopSurfaceWave(origin: landed, delay: 0.12, source: id))
            }
        }
    }

    /// The gallery layer appears at once; its own panel springs up and its dim fades in.
    static func presentGallery(_ editing: Binding<NoopPageEditing>) {
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) { editing.wrappedValue.adding = true }
    }

    /// Puts the section coming from the Add sheet where the finger is, the rest making way.
    private func place(incomingAt point: CGPoint) {
        guard let id = editing.incoming else { return }
        let others = editing.draft.filter { $0 != id }
        let target = others.filter { Self.isBefore(frames[$0], point) }.count
        guard editing.draft.firstIndex(of: id) != target else { return }
        let first = !editing.draft.contains(id)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            var order = others
            order.insert(id, at: min(target, order.count))
            editing.draft = order
        }
        NoopHaptics.play(first ? .lift : .pass)
    }

    /// Whether a section sits before the carried one's middle: one wholly above it, or one beside it
    /// in the same row and to its left. A full-width section is passed at its middle.
    private static func isBefore(_ frame: CGRect?, _ point: CGPoint) -> Bool {
        guard let frame else { return false }
        if point.y > frame.maxY { return true }
        if point.y < frame.minY { return false }
        let full = frame.width > UIScreen.main.bounds.width * 0.66
        return full ? frame.midY < point.y : frame.midX < point.x
    }

    /// The free half beside a lone tile while editing: Add, offering tiles that go in beside it.
    private func addBeside(_ id: String) -> some View {
        Button {
            NoopHaptics.play(.tick)
            editing.addBeside = id
            NoopEditableSections.presentGallery($editing)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus").font(.system(size: 14, weight: .semibold))
                Text("Add").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
            }
            .foregroundStyle(NoopHTMLColor.inkSoft)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: NoopSlotPill.height)
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            .contentShape(Capsule())
        }
        .buttonStyle(NoopHTMLPressStyle())
        .accessibilityLabel("Add a tile beside \(layout.section(id)?.title ?? id)")
    }

    @ViewBuilder
    private var foot: some View {
        if editing.active {
            VStack(spacing: 12) {
                // Always offered: a space or a divider can be added however many sections are on the page.
                do {
                    Button { editing.addBeside = nil; NoopEditableSections.presentGallery($editing) } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 17, weight: .semibold))
                            Text("Add section").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                        }
                        .foregroundStyle(NoopHTMLColor.inkSoft)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 92)
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                }
                NoopActionButton(title: "Reset to default", variant: .plain, size: .small) {
                    NoopHaptics.play(.add)
                    withAnimation(.easeInOut(duration: 0.25)) { editing.draft = layout.defaultOrder }
                }
            }
        } else {
            NoopActionButton(title: "Edit page", variant: .secondary, size: .medium) {
                NoopHaptics.prepare()
                NoopHaptics.play(.enterEdit)
                editing.draft = layout.order
                withAnimation(.easeInOut(duration: 0.22)) { editing.active = true }
            }
        }
    }
}

/// Whether a section is a half-width tile, read by `NoopSectionFlow`.
struct NoopHalfWidth: LayoutValueKey {
    static let defaultValue = false
}

/// The page's sections top to bottom; two half-width tiles in a row share it, a lone one keeps its
/// half and leaves the other free.
struct NoopSectionFlow: Layout {
    var spacing: CGFloat
    /// The gap between two tiles in a row.
    static let gap: CGFloat = 10

    static func halfWidth(of width: CGFloat) -> CGFloat { max(0, (width - gap) / 2) }

    private struct Row { var members: [Int]; var half: Bool }

    private func rows(_ subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var index = 0
        while index < subviews.count {
            if subviews[index][NoopHalfWidth.self] {
                if index + 1 < subviews.count, subviews[index + 1][NoopHalfWidth.self] {
                    rows.append(Row(members: [index, index + 1], half: true))
                    index += 2
                } else {
                    rows.append(Row(members: [index], half: true))
                    index += 1
                }
            } else {
                rows.append(Row(members: [index], half: false))
                index += 1
            }
        }
        return rows
    }

    private func heights(_ rows: [Row], width: CGFloat, _ subviews: Subviews) -> [CGFloat] {
        rows.map { row in
            let w = row.half ? Self.halfWidth(of: width) : width
            return row.members.map { subviews[$0].sizeThatFits(ProposedViewSize(width: w, height: nil)).height }.max() ?? 0
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? UIScreen.main.bounds.width - 40
        let rows = rows(subviews)
        let total = heights(rows, width: width, subviews).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: total)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(subviews)
        let heights = heights(rows, width: bounds.width, subviews)
        var y = bounds.minY
        for (row, height) in zip(rows, heights) {
            let w = row.half ? Self.halfWidth(of: bounds.width) : bounds.width
            for (slot, member) in row.members.enumerated() {
                var x = bounds.minX + CGFloat(slot) * (w + Self.gap)
                // A section narrower than the page sits in its middle, as it did in the old stack.
                if !row.half {
                    let fitted = subviews[member].sizeThatFits(ProposedViewSize(width: w, height: nil)).width
                    x += max(0, (w - fitted) / 2)
                }
                subviews[member].place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                                       proposal: ProposedViewSize(width: w, height: height))
            }
            y += height + spacing
        }
    }
}

/// A section's share of the wave: nudged along the page and breathing in scale as it passes.
/// A rectangle SwiftUI does not watch: writing it never re-renders anything.
final class NoopFrameBox {
    var rect: CGRect = .zero
}

private struct NoopWaveMotion: ViewModifier, Animatable {
    var wave: NoopSurfaceWave?
    var id: String
    var frame: CGRect?
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let motion = reduceMotion || progress >= 1 ? nil
            : wave?.motion(of: id, frame: frame, elapsed: progress * NoopSurfaceWave.duration)
        content
            .scaleEffect(motion?.scale ?? 1)
            .offset(y: motion?.dy ?? 0)
    }
}

/// Hold, then move: a short still press picks a section up, so a swipe that starts on one fails it
/// and the page scrolls. Reports how far the finger has moved vertically since the press began.
private struct NoopReorderPress: ViewModifier {
    enum Phase { case began, moved(CGSize), ended }
    var enabled = true
    var holdSeconds: Double = 0.35
    let onChange: (Phase) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), enabled {
            content.gesture(NoopReorderRecognizer(holdSeconds: holdSeconds, onChange: onChange))
        } else {
            content
        }
    }
}

/// The Home Screen's jiggle while a page is being edited: each section rocks a little on its own
/// beat, tiles more than whole cards.
private struct NoopJiggle: ViewModifier {
    let active: Bool
    let seed: Int
    let amplitude: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        // One timeline that pauses rather than two branches, so a section keeps its own state
        // as editing starts and ends.
        let rocking = active && !reduceMotion
        TimelineView(.animation(minimumInterval: nil, paused: !rocking)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = Double(abs(seed % 1000)) / 1000 * .pi * 2
            content.rotationEffect(.degrees(rocking ? amplitude * sin(t * 2 * .pi * 3.4 + phase) : 0))
        }
    }
}

/// The press itself, in UIKit so it can drive the page's scroll view: held near the top or bottom of
/// the screen, the page scrolls under the finger, faster the closer it is to the edge, and the carried
/// section moves with it.
@available(iOS 18.0, *)
private struct NoopReorderRecognizer: UIGestureRecognizerRepresentable {
    var holdSeconds: Double
    let onChange: (NoopReorderPress.Phase) -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let press = UILongPressGestureRecognizer()
        press.minimumPressDuration = holdSeconds
        press.allowableMovement = 10
        return press
    }

    func updateUIGestureRecognizer(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        context.coordinator.onChange = onChange
        recognizer.minimumPressDuration = holdSeconds
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        let coordinator = context.coordinator
        coordinator.onChange = onChange
        switch recognizer.state {
        case .began: coordinator.begin(recognizer)
        case .changed: coordinator.move(recognizer)
        default: coordinator.end()
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator(onChange: onChange) }

    @MainActor
    final class Coordinator: NSObject {
        var onChange: (NoopReorderPress.Phase) -> Void
        private weak var scrollView: UIScrollView?
        private var startY: CGFloat = 0
        private var startX: CGFloat = 0
        private var startOffset: CGFloat = 0
        private var fingerY: CGFloat = 0
        private var fingerX: CGFloat = 0
        private var link: CADisplayLink?
        private var scrolling = false

        /// The band at each end of the screen where holding scrolls, and the fastest it goes.
        private static let edge: CGFloat = 120
        private static let topClear: CGFloat = 110
        private static let bottomClear: CGFloat = 120
        private static let maxSpeed: CGFloat = 900

        init(onChange: @escaping (NoopReorderPress.Phase) -> Void) { self.onChange = onChange }

        func begin(_ recognizer: UILongPressGestureRecognizer) {
            scrollView = recognizer.view?.window.flatMap { Self.pageScroller(in: $0, at: recognizer.location(in: $0)) }
            fingerY = recognizer.location(in: recognizer.view?.window).y
            fingerX = recognizer.location(in: recognizer.view?.window).x
            startY = fingerY
            startX = fingerX
            startOffset = scrollView?.contentOffset.y ?? 0
            onChange(.began)
            let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
            link.add(to: .main, forMode: .common)
            self.link = link
        }

        func move(_ recognizer: UILongPressGestureRecognizer) {
            fingerY = recognizer.location(in: recognizer.view?.window).y
            fingerX = recognizer.location(in: recognizer.view?.window).x
            report()
        }

        func end() {
            link?.invalidate()
            link = nil
            scrolling = false
            onChange(.ended)
        }

        /// The deepest vertically scrolling view under the finger: the page, not a chart inside it.
        private static func pageScroller(in root: UIView, at point: CGPoint) -> UIScrollView? {
            var found: UIScrollView?
            func visit(_ view: UIView) {
                guard !view.isHidden, view.alpha > 0.01 else { return }
                if let scroll = view as? UIScrollView, scroll.isScrollEnabled,
                   scroll.contentSize.height > scroll.bounds.height + 1,
                   scroll.bounds.contains(scroll.convert(point, from: root)) {
                    found = scroll
                }
                view.subviews.forEach(visit)
            }
            visit(root)
            return found
        }

        /// How far the section has travelled in the page: the finger's move plus the page's.
        private func report() {
            let scrolled = (scrollView?.contentOffset.y ?? startOffset) - startOffset
            onChange(.moved(CGSize(width: fingerX - startX, height: fingerY - startY + scrolled)))
        }

        @objc private func tick(_ link: CADisplayLink) {
            guard let scrollView, let window = scrollView.window else { return }
            let height = window.bounds.height
            let top = Self.topClear + Self.edge, bottom = height - Self.bottomClear - Self.edge
            var speed: CGFloat = 0
            if fingerY < top { speed = -Self.maxSpeed * min(1, (top - fingerY) / Self.edge) }
            if fingerY > bottom { speed = Self.maxSpeed * min(1, (fingerY - bottom) / Self.edge) }
            let maxOffset = max(-scrollView.adjustedContentInset.top,
                                scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
            let minOffset = -scrollView.adjustedContentInset.top
            let current = scrollView.contentOffset.y
            let next = min(maxOffset, max(minOffset, current + speed * CGFloat(link.targetTimestamp - link.timestamp)))
            let moving = abs(next - current) > 0.5
            if moving != scrolling {
                // A soft bump when the page starts to carry along, and again when it reaches an end.
                NoopHaptics.play(moving ? .edge : .tick)
                scrolling = moving
            }
            guard moving else { return }
            scrollView.contentOffset.y = next
            report()
        }
    }
}

/// A section with nothing to show yet, drawn while editing so it can still be placed.
private struct NoopSectionPlaceholder: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.inkSoft)
            Text(detail).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.faint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }
}

/// The sections not on the page, each shown as it would look, with a button to add it.
private struct NoopAddSectionSheet<Section: View>: View {
    @ObservedObject var layout: NoopPageLayout
    @Binding var editing: NoopPageEditing
    let drag: NoopIncomingDrag
    let isEmpty: (String) -> Bool
    let section: (String) -> Section
    @Environment(\.dismiss) private var dismiss
    /// The section held and being carried out onto the page, and where the finger is.
    @State private var lifted: NoopPageSection?
    @State private var fingerAt: CGPoint = .zero
    @State private var sheetOrigin: CGPoint = .zero
    /// The panel is up; it springs in after the layer appears and drops before it goes.
    @State private var shown = false
    /// Down while a preview is held; a touch the system takes away still lands what it carried.
    @GestureState private var holding = false

    /// Hold a preview to lift it; the sheet steps aside and it follows the finger onto the page.
    private func carryOut(_ info: NoopPageSection) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .updating($holding) { _, state, _ in state = true }
            .onChanged { value in
                guard case .second(true, let moving) = value, let moving else { return }
                if lifted == nil {
                    NoopHaptics.play(.lift)
                    editing.addBeside = nil
                    editing.incoming = info.id
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { lifted = info }
                }
                fingerAt = moving.location
                drag.point = moving.location
            }
            .onEnded { _ in land() }
    }

    /// The same carry, driven by the system's long press so the gallery scrolls freely under a
    /// moving finger and only a still hold picks a preview up, as the Home Screen's gallery does.
    private func carry(_ info: NoopPageSection, _ phase: NoopCarryOutPhase) {
        switch phase {
        case .moved(let point):
            if lifted == nil {
                NoopHaptics.play(.lift)
                editing.addBeside = nil
                editing.incoming = info.id
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { lifted = info }
            }
            fingerAt = point
            drag.point = point
        case .ended:
            land()
        }
    }

    private func land() {
                guard let info = lifted else { return }
                if !editing.draft.contains(info.id) { editing.draft.append(info.id) }
                drag.landed = info.id
                drag.point = nil
                NoopHaptics.play(.land)
                // The layer goes at once, so the tile seems to drop straight into its place.
                var still = Transaction()
                still.disablesAnimations = true
                withTransaction(still) {
                    editing.incoming = nil
                    lifted = nil
                    editing.adding = false
                }
    }

    private var missing: [NoopPageSection] { layout.catalog.filter { !editing.draft.contains($0.id) } }
    private var tiles: [NoopPageSection] { missing.filter(\.half) }
    private var sections: [NoopPageSection] { missing.filter { !$0.half } }
    /// A fresh space and divider each time the sheet opens, so each one added is its own entry.
    @State private var spacers: [NoopPageSection] =
        NoopPageLayout.SpaceSize.allCases.map { NoopPageLayout.spacerSection(NoopPageLayout.newSpacerID(divider: false, size: $0))! }
        + [NoopPageLayout.spacerSection(NoopPageLayout.newSpacerID(divider: true))!]

    private func add(_ info: NoopPageSection) {
        NoopHaptics.play(.add)
        withAnimation(.easeInOut(duration: 0.22)) {
            if let beside = editing.addBeside, let at = editing.draft.firstIndex(of: beside) {
                editing.draft.insert(info.id, at: at + 1)
            } else {
                editing.draft.append(info.id)
            }
        }
        editing.addBeside = nil
        close()
    }

    /// Down and away like a sheet, then the layer goes.
    private func close() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.92)) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) { editing.adding = false }
        }
    }

    var body: some View {
        // A full-screen layer with a panel drawn as a sheet, so the panel can slide away while a
        // section is carried out of it and the page shows underneath, as the Home Screen's gallery does.
        ZStack(alignment: .bottom) {
            Color.black.opacity(lifted == nil && shown ? 0.4 : 0)
                .ignoresSafeArea()
                .onTapGesture { close() }
            panel
                .offset(y: lifted == nil && shown ? 0 : UIScreen.main.bounds.height)
        }
        .onAppear { withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { shown = true } }
        .overlay(alignment: .topLeading) {
            if let lifted {
                let width = UIScreen.main.bounds.width - 40
                section(lifted.id).allowsHitTesting(false)
                    .frame(width: lifted.half ? NoopSectionFlow.halfWidth(of: width) : width)
                    .scaleEffect(1.06)
                    .shadow(color: .black.opacity(0.55), radius: 22, y: 12)
                    .position(x: fingerAt.x - sheetOrigin.x, y: fingerAt.y - sheetOrigin.y)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).origin } action: { sheetOrigin = $0 }
        .presentationBackground(.clear)
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: lifted == nil)
        .onChange(of: holding) { _, down in if !down { land() } }
    }

    private var panel: some View {
        VStack(spacing: 0) {
            NoopSheetHeader(title: editing.addBeside == nil ? "Add section" : "Add a tile") { close() }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 10)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // Tiles first, two to a row as they sit on the page; then whole sections.
                    if !tiles.isEmpty {
                        if editing.addBeside == nil && !sections.isEmpty { NoopSectionLabel("Tiles") }
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: NoopSectionFlow.gap),
                                            GridItem(.flexible(), spacing: NoopSectionFlow.gap)],
                                  alignment: .leading, spacing: 18) {
                            ForEach(tiles) { info in
                                    VStack(alignment: .leading, spacing: 8) {
                                        section(info.id).allowsHitTesting(false)
                                        HStack(spacing: 5) {
                                            Image(systemName: "plus.circle.fill").font(.system(size: 14))
                                            Text(info.title).font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                                                .lineLimit(1).minimumScaleFactor(0.8)
                                        }
                                        .foregroundStyle(NoopHTMLColor.inkSoft)
                                        .padding(.leading, 6)
                                    }
                                    .contentShape(Rectangle())
                                    .modifier(NoopGalleryItem(info: info, add: add, fallback: carryOut(info)) { carry(info, $0) })
                                    .accessibilityLabel("Add \(info.title)")
                            }
                        }
                    }
                    if editing.addBeside == nil && !sections.isEmpty {
                        if !tiles.isEmpty { NoopSectionLabel("Sections").padding(.top, 6) }
                        ForEach(sections) { info in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(info.title).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                                            .foregroundStyle(NoopHTMLColor.ink)
                                        Spacer()
                                        Image(systemName: "plus.circle.fill").font(.system(size: 20))
                                            .foregroundStyle(NoopHTMLColor.inkSoft)
                                    }
                                    if isEmpty(info.id) {
                                        NoopSectionPlaceholder(title: info.title, detail: info.detail)
                                    } else {
                                        section(info.id).allowsHitTesting(false)
                                    }
                                }
                                .contentShape(Rectangle())
                                .modifier(NoopGalleryItem(info: info, add: add, fallback: carryOut(info)) { carry(info, $0) })
                        }
                    }
                    if editing.addBeside == nil {
                        NoopSectionLabel("Space and lines").padding(.top, 6)
                        ForEach(spacers) { info in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(info.title).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                                        .foregroundStyle(NoopHTMLColor.ink)
                                    Text(info.detail).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.faint)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill").font(.system(size: 20))
                                    .foregroundStyle(NoopHTMLColor.inkSoft)
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                            .modifier(NoopGalleryItem(info: info, add: add, fallback: carryOut(info)) { carry(info, $0) })
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollDisabled(lifted != nil)
        }
        .frame(maxWidth: .infinity)
        .background(NoopHTMLColor.canvas,
                    in: UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous))
        .padding(.top, 58)
        .ignoresSafeArea(edges: .bottom)
    }
}

/// A hold that lifts a preview out of the Add gallery. On iOS 18 it is a UIKit long press, which
/// leaves the gallery's scroll view to take any touch that moves first; earlier systems keep the
/// SwiftUI gesture.
/// A preview in the Add gallery: a tap adds it, a still hold lifts it out. Not a Button, whose
/// own touch handling would keep the hold from ever reaching the long press.
private struct NoopGalleryItem<Fallback: Gesture>: ViewModifier {
    let info: NoopPageSection
    let add: (NoopPageSection) -> Void
    let fallback: Fallback
    let onCarry: (NoopCarryOutPhase) -> Void

    func body(content: Content) -> some View {
        content
            .onTapGesture { add(info) }
            .modifier(NoopCarryOutPress(fallback: fallback, onChange: onCarry))
            .accessibilityAddTraits(.isButton)
    }
}

private enum NoopCarryOutPhase { case moved(CGPoint), ended }

private struct NoopCarryOutPress<Fallback: Gesture>: ViewModifier {
    let fallback: Fallback
    let onChange: (NoopCarryOutPhase) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.gesture(NoopCarryOutRecognizer(onChange: onChange))
        } else {
            content.simultaneousGesture(fallback)
        }
    }
}

@available(iOS 18.0, *)
private struct NoopCarryOutRecognizer: UIGestureRecognizerRepresentable {
    let onChange: (NoopCarryOutPhase) -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let press = UILongPressGestureRecognizer()
        press.minimumPressDuration = 0.35
        press.allowableMovement = 10
        return press
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed:
            onChange(.moved(recognizer.location(in: recognizer.view?.window)))
        case .ended, .cancelled, .failed:
            onChange(.ended)
        default:
            break
        }
    }
}

/// The finger's travel during a carry, read only by the carried section's offset.
final class NoopCarryMotion: ObservableObject {
    @Published var translation: CGSize = .zero
}

/// Moves the carried section with the finger, one to one, without redrawing the page around it.
private struct NoopCarryOffset: ViewModifier {
    @ObservedObject var motion: NoopCarryMotion
    let active: Bool
    /// Where it was picked up against where its slot now is.
    let base: CGSize

    func body(content: Content) -> some View {
        content.offset(x: active ? base.width + motion.translation.width : 0,
                       y: active ? base.height + motion.translation.height : 0)
    }
}

/// A section being carried out of the Add sheet: where the finger is on screen, and what landed.
final class NoopIncomingDrag: ObservableObject {
    @Published var point: CGPoint?
    var landed: String?
}

/// Follows the finger for the page without redrawing the page.
private struct NoopIncomingObserver: View {
    @ObservedObject var drag: NoopIncomingDrag
    let moved: (CGPoint) -> Void

    var body: some View {
        Color.clear
            .onChange(of: drag.point) { _, point in if let point { moved(point) } }
    }
}

/// Cancel and Save, floating at the top of a page while it is being edited.
struct NoopEditBar: ViewModifier {
    @Binding var editing: NoopPageEditing
    let layout: NoopPageLayout
    /// Opens this page's own Settings (26 Oct 2026). The arrangement is kept, as Save would.
    var settings: (() -> Void)? = nil

    /// The page draws under the status bar, so the bar measures it itself.
    private static var statusInset: CGFloat {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.windows.first { $0.isKeyWindow }?.safeAreaInsets.top ?? 54
    }

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if editing.active {
                HStack {
                    NoopActionButton(title: "Cancel", variant: .secondary, size: .small, fullWidth: false) {
                        NoopHaptics.play(.cancel)
                        withAnimation(.easeInOut(duration: 0.22)) { editing.active = false }
                    }
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NoopControlSize.small.height / 2))
                    Spacer()
                    if let settings {
                        Button {
                            layout.save(editing.draft)
                            withAnimation(.easeInOut(duration: 0.22)) { editing.active = false }
                            editing.saves += 1
                            NoopHaptics.play(.tick)
                            settings()
                        } label: {
                            NoopIconDiscShape(size: .small) {
                                Image(systemName: "gearshape").font(.system(size: NoopControlSize.small.icon, weight: .medium))
                            }
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                        .accessibilityLabel("Page settings")
                        .accessibilityHint("Keeps this arrangement and opens the page's settings")
                        Spacer()
                    }
                    NoopActionButton(title: "Save", size: .small, fullWidth: false) {
                        layout.save(editing.draft)
                        withAnimation(.easeInOut(duration: 0.22)) { editing.active = false }
                        editing.saves += 1
                        NoopHaptics.play(.save)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 14)
                .background {
                    // Solid behind the buttons, fading out under them, so the page reads as passing beneath.
                    LinearGradient(stops: [.init(color: NoopHTMLColor.canvas, location: 0),
                                           .init(color: NoopHTMLColor.canvas, location: 0.7),
                                           .init(color: NoopHTMLColor.canvas.opacity(0), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea(edges: .top)
                }
                .safeAreaPadding(.top, Self.statusInset)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

extension View {
    func noopEditBar(_ editing: Binding<NoopPageEditing>, layout: NoopPageLayout,
                     settings: (() -> Void)? = nil) -> some View {
        modifier(NoopEditBar(editing: editing, layout: layout, settings: settings))
    }
}

/// A blank gap or a thin line the wearer placed between sections. While editing, a faint outline shows
/// where an empty space is, so it can be held and moved.
struct NoopLayoutSpacer: View {
    let divider: Bool
    var height: CGFloat = 28
    var editing = false

    var body: some View {
        Group {
            if divider {
                Rectangle().fill(NoopHTMLColor.border).frame(height: 0.5)
                    .padding(.horizontal, 6)
                    .frame(height: 18)
            } else {
                Color.clear.frame(height: height)
            }
        }
        .frame(maxWidth: .infinity)
        .overlay {
            if editing {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .accessibilityHidden(!editing)
    }
}
