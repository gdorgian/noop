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

    private var orderKey: String { "noop.layout.\(page)" }
    private var knownKey: String { "noop.layout.\(page).known" }
    private var versionKey: String { "noop.layout.\(page).version" }

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
        guard let saved = defaults.string(forKey: "noop.layout.\(page)") else {
            order = ids
            return
        }
        let allIDs = catalog.map(\.id)
        let known = Set((defaults.string(forKey: "noop.layout.\(page).known") ?? saved).split(separator: ",").map(String.init))
        var result = saved.split(separator: ",").map(String.init).filter(allIDs.contains)
        // New sections go in after the nearest section above them in the default order.
        for (index, id) in ids.enumerated() where !known.contains(id) && !result.contains(id) {
            let before = ids[..<index].last { result.contains($0) }
            let at = before.flatMap { result.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
            result.insert(id, at: at)
        }
        // Sections that cannot be removed are always present.
        for (index, section) in catalog.enumerated() where !section.removable && !result.contains(section.id) {
            result.insert(section.id, at: min(index, result.count))
        }
        order = result
    }

    func section(_ id: String) -> NoopPageSection? { catalog.first { $0.id == id } }

    func save(_ newOrder: [String]) {
        order = newOrder
        UserDefaults.standard.set(newOrder.joined(separator: ","), forKey: orderKey)
        UserDefaults.standard.set(catalog.map(\.id).joined(separator: ","), forKey: knownKey)
        UserDefaults.standard.set(Self.version, forKey: versionKey)
    }

    var defaultOrder: [String] { catalog.filter(\.onByDefault).map(\.id) }
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
    @ViewBuilder let section: (String) -> Section

    /// The section being carried, where its middle was when it was picked up, and how far the
    /// finger has moved since. Each section's frame is kept so the carried one can swap places as its
    /// middle passes another's.
    @State private var dragging: String?
    @State private var dragStartMid: CGPoint = .zero
    @State private var dragTranslation: CGSize = .zero
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

    var body: some View {
        NoopSectionFlow(spacing: spacing) {
            ForEach(entries, id: \.self) { id in
                Group {
                    if id.hasPrefix(Self.besidePrefix) {
                        addBeside(String(id.dropFirst(Self.besidePrefix.count)))
                    } else if editing.active {
                        editable(id)
                    } else {
                        section(id)
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
            foot.padding(.top, 14)
        }
        // Room for Cancel and Save, so the first section's remove disc never sits under them.
        .padding(.top, editing.active ? 52 : 0)
        .coordinateSpace(name: "noop.sections")
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
        .sheet(isPresented: $editing.adding, onDismiss: { editing.addBeside = nil }) {
            NoopAddSectionSheet(layout: layout, editing: $editing, isEmpty: isEmpty, section: section)
                .noopSheet()
        }
    }

    @ViewBuilder
    private func editable(_ id: String) -> some View {
        let info = layout.section(id)
        Group {
            if isEmpty(id) {
                NoopSectionPlaceholder(title: info?.title ?? id, detail: info?.detail ?? "")
            } else {
                section(id).allowsHitTesting(info?.liveWhileEditing ?? false)
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
        .opacity(dragging == id ? 0.94 : 1)
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
        .offset(x: dragging == id ? dragStartMid.x + dragTranslation.width - (frames[id]?.midX ?? dragStartMid.x) : 0,
                y: dragging == id ? dragStartMid.y + dragTranslation.height - (frames[id]?.midY ?? dragStartMid.y) : 0)
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
                dragTranslation = .zero
            }
        case .moved(let delta):
            guard dragging == id else { return }
            dragTranslation = delta
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
                dragTranslation = .zero
            }
            // It lands like a drop: the page moves out from its edges, and the phone feels it.
            NoopHaptics.play(.land)
            if let landed = frames[id] {
                send(NoopSurfaceWave(origin: landed, delay: 0.12, source: id))
            }
        }
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
            editing.adding = true
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
                if layout.catalog.contains(where: { !editing.draft.contains($0.id) }) {
                    Button { editing.addBeside = nil; editing.adding = true } label: {
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
                let x = bounds.minX + CGFloat(slot) * (w + Self.gap)
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
    let isEmpty: (String) -> Bool
    let section: (String) -> Section
    @Environment(\.dismiss) private var dismiss

    private var missing: [NoopPageSection] { layout.catalog.filter { !editing.draft.contains($0.id) } }
    private var tiles: [NoopPageSection] { missing.filter(\.half) }
    private var sections: [NoopPageSection] { missing.filter { !$0.half } }

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
        dismiss()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                NoopCloseButton { dismiss() }
                Spacer()
                Text(editing.addBeside == nil ? "Add section" : "Add a tile").font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                Spacer()
                Color.clear.frame(width: NoopCloseButton.side, height: 1)
            }
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
                                Button { add(info) } label: {
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
                                }
                                .buttonStyle(NoopHTMLPressStyle())
                                .accessibilityLabel("Add \(info.title)")
                            }
                        }
                    }
                    if editing.addBeside == nil && !sections.isEmpty {
                        if !tiles.isEmpty { NoopSectionLabel("Sections").padding(.top, 6) }
                        ForEach(sections) { info in
                            Button { add(info) } label: {
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
                            }
                            .buttonStyle(NoopHTMLPressStyle())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(NoopHTMLColor.canvas)
    }
}

/// Cancel and Save, floating at the top of a page while it is being edited.
struct NoopEditBar: ViewModifier {
    @Binding var editing: NoopPageEditing
    let layout: NoopPageLayout

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
    func noopEditBar(_ editing: Binding<NoopPageEditing>, layout: NoopPageLayout) -> some View {
        modifier(NoopEditBar(editing: editing, layout: layout))
    }
}
