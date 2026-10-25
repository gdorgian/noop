import SwiftUI

// MARK: - Score page template
//
// The top of every score page is the same frame: a title row (back, title, date), an animated hero
// at one fixed height, then two stat tiles. Only the hero's drawing and the tiles' figures change
// from page to page, so Recovery, Strain, Sleep, Trends and You read as one family. Below it, a
// page's own sections, then its Trends list.

enum NoopPageHeroMetrics {
    /// The hero's drawing area. Every page's hero is drawn into exactly this square.
    static let heroSide: CGFloat = 264
    /// Space from the title row to the hero, and from the hero to the tiles.
    static let gap: CGFloat = 14
}

struct NoopScorePageHeader<Hero: View>: View {
    var theme: NoopPageTheme? = nil
    let title: String
    let date: String
    let tiles: [(label: String, value: String)]
    var back: (() -> Void)? = nil
    @ViewBuilder var hero: Hero

    var body: some View {
        VStack(spacing: NoopPageHeroMetrics.gap) {
            ZStack {
                VStack(spacing: 2) {
                    Text(title).font(NoopHTMLFont.outfit(NoopType.title3)).foregroundStyle(NoopHTMLColor.ink)
                    Text(date).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                }
                if let back {
                    HStack {
                        Button(action: back) {
                            NoopIconDiscShape(size: .small) {
                                Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                            }
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                        .accessibilityLabel("Back")
                        Spacer()
                    }
                }
            }
            hero.frame(maxWidth: .infinity)
            HStack(spacing: 10) {
                ForEach(Array(tiles.enumerated()), id: \.offset) { _, tile in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tile.label).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                        Text(tile.value).font(NoopHTMLFont.outfit(NoopType.title3)).monospacedDigit()
                            .foregroundStyle(NoopHTMLColor.ink).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .noopRaisedCard(radius: 18)
                }
            }
        }
        .background(alignment: .top) {
            if let theme {
                NoopPageBackdrop(theme: theme)
                    .frame(width: UIScreen.main.bounds.width)
                    .offset(y: -140)
            }
        }
    }
}

extension View {
    /// A card raised off the page, as Bevel's are: a cool slate fill, a fine light edge on top and a
    /// soft shadow below.
    func noopRaisedCard(radius: CGFloat = 20) -> some View {
        self
            .background(Color(hex: 0x1C1F26), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.10), Color.white.opacity(0.02)],
                                             startPoint: .top, endPoint: .bottom), lineWidth: 0.75))
            .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
    }
}

// MARK: - Trends list

/// A page's measures as rows (where it stands, its value, ninety days as a line); each opens the
/// chart sheet with the whole list as chips across the top.
struct NoopTrendsList: View {
    @ObservedObject var navigation: NoopNavigation
    var title = "Trends"
    let ids: [String]

    @EnvironmentObject private var repo: Repository
    @StateObject private var store = NoopMarkerStore()

    private var shown: [String] { ids.filter { NoopMarkers.descriptor($0) != nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: NoopSpace.s) {
            Text(title)
                .font(NoopHTMLFont.outfit(NoopType.title3)).tracking(-0.4)
                .foregroundStyle(NoopHTMLColor.ink)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 2)
            ForEach(shown, id: \.self) { id in
                if let d = NoopMarkers.descriptor(id) {
                    Button {
                        navigation.metricSheet = NoopMetricSheetRequest(metricID: id, group: "marker", peers: shown)
                    } label: {
                        NoopMarkerRow(descriptor: d, reading: store.readings[id], loaded: store.loaded)
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                }
            }
        }
        .task(id: "\(repo.refreshSeq)|\(ids.joined(separator: ","))") { await store.load(ids: shown, repo: repo) }
    }
}

// MARK: - Backdrop and hero pager

/// A page's colours for the backdrop and its cards.
struct NoopPageTheme {
    let sky: Color
    let ridge: Color
    var stars = false

    static let sleep = NoopPageTheme(sky: Color(hex: 0x7B6BE0), ridge: Color(hex: 0x3B2F7A), stars: true)
    static let recovery = NoopPageTheme(sky: Color(hex: 0x3FC9A0), ridge: Color(hex: 0x1C4F49))
    static let strain = NoopPageTheme(sky: Color(hex: 0xF0A04B), ridge: Color(hex: 0x5A3418))
    static let trends = NoopPageTheme(sky: Color(hex: 0x00E59A), ridge: Color(hex: 0x15403A))
    static let you = NoopPageTheme(sky: Color(hex: 0xE08A9B), ridge: Color(hex: 0x4A2430))
}

/// The dusk scene behind the top of a score page, drawn on the GPU and paused off screen.
struct NoopPageBackdrop: View {
    let theme: NoopPageTheme
    var height: CGFloat = 520

    var body: some View {
        NoopSlotClock { t, _ in
            GeometryReader { g in
                Rectangle().colorEffect(ShaderLibrary.noopBackdrop(
                    .float2(g.size), .float(Float(t)), .color(theme.sky), .color(theme.ridge), .float(theme.stars ? 1 : 0)))
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Three ways to draw a page's hero, swiped between; the choice is kept per page. Dots under the
/// hero say which is showing, and each change ticks.
struct NoopHeroPager<A: View, B: View, C: View>: View {
    let page: String
    let names: [String]
    /// The hero's square side; a page whose own hero is a different size passes it.
    var side: CGFloat = NoopPageHeroMetrics.heroSide
    @ViewBuilder var first: A
    @ViewBuilder var second: B
    @ViewBuilder var third: C

    @AppStorage private var choice: Int

    init(page: String, names: [String], side: CGFloat = NoopPageHeroMetrics.heroSide,
         @ViewBuilder first: () -> A, @ViewBuilder second: () -> B, @ViewBuilder third: () -> C) {
        self.page = page
        self.names = names
        self.side = side
        self.first = first()
        self.second = second()
        self.third = third()
        _choice = AppStorage(wrappedValue: 0, "noop.hero.\(page)")
    }

    var body: some View {
        VStack(spacing: 8) {
            TabView(selection: $choice) {
                first.frame(width: side, height: side).tag(0)
                second.frame(width: side, height: side).tag(1)
                third.frame(width: side, height: side).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: side)
            .onChange(of: choice) { NoopHaptics.play(.pass) }
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(Color.white.opacity(i == choice ? 0.85 : 0.22))
                        .frame(width: i == choice ? 16 : 6, height: 6)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: choice)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Style \(choice + 1) of 3, \(names[min(choice, names.count - 1)])")
            .accessibilityAdjustableAction { dir in
                switch dir {
                case .increment: choice = min(2, choice + 1)
                case .decrement: choice = max(0, choice - 1)
                default: break
                }
            }
        }
    }
}
