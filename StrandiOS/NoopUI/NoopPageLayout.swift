import SwiftUI

// MARK: - Editable pages
//
// Every page is a list of sections the wearer can remove, add back and reorder. The page lists its
// sections in default order; the layout keeps the wearer's order per page. A section added in a
// later build is not one the wearer removed, so it is slotted in at its default place the first
// time the page sees it. Editing happens on the live page: each section gets a remove disc and can
// be dragged, and the page's own spacing is kept, with no titles added between sections.

struct NoopPageSection: Identifiable, Hashable {
    let id: String
    let title: String
    /// One line for the Add sheet and for the placeholder an empty section shows while editing.
    let detail: String
    var removable = true
}

@MainActor
final class NoopPageLayout: ObservableObject {
    let page: String
    let catalog: [NoopPageSection]
    @Published private(set) var order: [String]

    private var orderKey: String { "noop.layout.\(page)" }
    private var knownKey: String { "noop.layout.\(page).known" }

    init(page: String, catalog: [NoopPageSection]) {
        self.page = page
        self.catalog = catalog
        let defaults = UserDefaults.standard
        let ids = catalog.map(\.id)
        guard let saved = defaults.string(forKey: "noop.layout.\(page)") else {
            order = ids
            return
        }
        let known = Set((defaults.string(forKey: "noop.layout.\(page).known") ?? saved).split(separator: ",").map(String.init))
        var result = saved.split(separator: ",").map(String.init).filter(ids.contains)
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
    }

    var defaultOrder: [String] { catalog.map(\.id) }
}

/// The edit session a page holds: the order being edited, kept apart until Save.
struct NoopPageEditing {
    var active = false
    var draft: [String] = []
    var adding = false
}

/// Lays out a page's sections in the wearer's order. While editing, every section carries a remove
/// disc and can be dragged onto another to take its place, and the foot of the page offers Add and
/// Reset; otherwise the foot offers Edit.
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

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(editing.active ? editing.draft : layout.order, id: \.self) { id in
                if editing.active {
                    editable(id)
                } else if !isEmpty(id) {
                    section(id)
                }
            }
            foot.padding(.top, 14)
        }
        .coordinateSpace(name: "noop.sections")
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
                section(id).allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .scaleEffect(dragging == id ? 1.03 : 1)
        .shadow(color: .black.opacity(dragging == id ? 0.5 : 0), radius: 18, y: 8)
        .overlay(alignment: .topLeading) {
            if (info?.removable ?? true) && dragging == nil {
                Button {
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
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("noop.sections")) } action: { frames[id] = $0 }
        .offset(y: dragging == id ? dragStartMid + dragTranslation - (frames[id]?.midY ?? dragStartMid) : 0)
        .zIndex(dragging == id ? 1 : 0)
        .modifier(NoopReorderPress { phase in carry(id, phase) })
    }

    /// Hold to pick a section up, move to carry it; it takes the place of whichever section its
    /// middle passes, and settles where it is when the finger lifts.
    private func carry(_ id: String, _ phase: NoopReorderPress.Phase) {
        switch phase {
        case .began:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
                UISelectionFeedbackGenerator().selectionChanged()
            }
        case .ended:
            withAnimation(.spring(duration: 0.3)) {
                dragging = nil
                dragTranslation = 0
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
                    withAnimation(.easeInOut(duration: 0.25)) { editing.draft = layout.defaultOrder }
                }
            }
        } else {
            NoopActionButton(title: "Edit page", variant: .secondary, size: .medium) {
                editing.draft = layout.order
                withAnimation(.easeInOut(duration: 0.22)) { editing.active = true }
            }
        }
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

@available(iOS 18.0, *)
private struct NoopReorderRecognizer: UIGestureRecognizerRepresentable {
    let onChange: (NoopReorderPress.Phase) -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let press = UILongPressGestureRecognizer()
        press.minimumPressDuration = 0.35
        press.allowableMovement = 10
        return press
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        let y = recognizer.location(in: recognizer.view?.window).y
        switch recognizer.state {
        case .began:
            context.coordinator.startY = y
            onChange(.began)
        case .changed:
            onChange(.moved(y - context.coordinator.startY))
        default:
            onChange(.ended)
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    final class Coordinator { var startY: CGFloat = 0 }
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
                        withAnimation(.easeInOut(duration: 0.22)) { editing.active = false }
                    }
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NoopControlSize.small.height / 2))
                    Spacer()
                    NoopActionButton(title: "Save", size: .small, fullWidth: false) {
                        layout.save(editing.draft)
                        withAnimation(.easeInOut(duration: 0.22)) { editing.active = false }
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
