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
    @State private var dragStartMid: CGFloat = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var frames: [String: CGRect] = [:]
    /// Where the page sits on screen, so a save's wave starts in the middle of what is in view.
    @State private var screenFrame: CGRect = .zero
    /// The wave running through the page after a drop or a save, and how far through it is (0 to 1),
    /// animated linearly so every section reads its own push from the same moment.
    @State private var wave: NoopSurfaceWave?
    @State private var waveProgress: Double = 0

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(editing.active ? editing.draft : layout.order, id: \.self) { id in
                Group {
                    if editing.active {
                        editable(id)
                    } else if !isEmpty(id) {
                        section(id)
                    }
                }
                // Each section's place in the page, measured before any carry or wave moves it.
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { frames[id] = proxy.frame(in: .named("noop.sections")) }
                            .onChange(of: proxy.frame(in: .named("noop.sections"))) { _, frame in frames[id] = frame }
                    }
                }
                .modifier(NoopWaveMotion(wave: wave, id: id, frame: frames[id], progress: waveProgress))
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
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { screenFrame = $0 }
        .onChange(of: editing.saves) {
            let middle = UIScreen.main.bounds.midY - screenFrame.minY
            send(NoopSurfaceWave(origin: CGRect(x: 0, y: middle, width: screenFrame.width, height: 0)))
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
        .sheet(isPresented: $editing.adding) {
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
        .scaleEffect(dragging == id ? 1.03 : 1)
        .shadow(color: .black.opacity(dragging == id ? 0.5 : 0), radius: 18, y: 8)
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
        .offset(y: dragging == id ? dragStartMid + dragTranslation - (frames[id]?.midY ?? dragStartMid) : 0)
        .modifier(NoopReorderPress { phase in carry(id, phase) })
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
            NoopHaptics.play(.lift)
            withAnimation(.easeOut(duration: 0.15)) {
                dragging = id
                dragStartMid = frames[id]?.midY ?? 0
                dragTranslation = 0
            }
        case .moved(let dy):
            dragTranslation = dy
            let mid = dragStartMid + dy
            let others = editing.draft.filter { $0 != id }
            let target = others.filter { (frames[$0]?.midY ?? .infinity) < mid }.count
            if editing.draft.firstIndex(of: id) != target {
                withAnimation(.easeInOut(duration: 0.2)) {
                    var order = others
                    order.insert(id, at: min(target, order.count))
                    editing.draft = order
                }
                NoopHaptics.play(.pass)
            }
        case .ended:
            withAnimation(.spring(duration: 0.3)) {
                dragging = nil
                dragTranslation = 0
            }
            // It lands like a drop: the page moves out from its edges, and the phone feels it.
            NoopHaptics.play(.land)
            if let landed = frames[id] {
                send(NoopSurfaceWave(origin: landed, delay: 0.12, source: id))
            }
        }
    }

    @ViewBuilder
    private var foot: some View {
        if editing.active {
            VStack(spacing: 12) {
                if layout.catalog.contains(where: { !editing.draft.contains($0.id) }) {
                    Button { editing.adding = true } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 17, weight: .semibold))
                            Text("Add section").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                        }
                        .foregroundStyle(NoopHTMLColor.inkSoft)
                        .frame(maxWidth: .infinity)
                        .frame(height: 92)
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

/// A section's share of the wave: nudged along the page and breathing in scale as it passes.
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
    enum Phase { case began, moved(CGFloat), ended }
    let onChange: (Phase) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.gesture(NoopReorderRecognizer(onChange: onChange))
        } else {
            content
        }
    }
}

/// The press itself, in UIKit so it can drive the page's scroll view: held near the top or bottom of
/// the screen, the page scrolls under the finger, faster the closer it is to the edge, and the carried
/// section moves with it.
@available(iOS 18.0, *)
private struct NoopReorderRecognizer: UIGestureRecognizerRepresentable {
    let onChange: (NoopReorderPress.Phase) -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let press = UILongPressGestureRecognizer()
        press.minimumPressDuration = 0.35
        press.allowableMovement = 10
        return press
    }

    func updateUIGestureRecognizer(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        context.coordinator.onChange = onChange
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
        private var startOffset: CGFloat = 0
        private var fingerY: CGFloat = 0
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
            startY = fingerY
            startOffset = scrollView?.contentOffset.y ?? 0
            onChange(.began)
            let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
            link.add(to: .main, forMode: .common)
            self.link = link
        }

        func move(_ recognizer: UILongPressGestureRecognizer) {
            fingerY = recognizer.location(in: recognizer.view?.window).y
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
            onChange(.moved(fingerY - startY + scrolled))
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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    NoopIconDiscShape(size: .small) { Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)) }
                }
                .buttonStyle(NoopPlainHitStyle())
                Spacer()
                Text("Add section").font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                Spacer()
                Color.clear.frame(width: NoopControlSize.small.height, height: 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 10)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(layout.catalog.filter { !editing.draft.contains($0.id) }) { info in
                        Button {
                            NoopHaptics.play(.add)
                            withAnimation(.easeInOut(duration: 0.22)) { editing.draft.append(info.id) }
                            dismiss()
                        } label: {
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
