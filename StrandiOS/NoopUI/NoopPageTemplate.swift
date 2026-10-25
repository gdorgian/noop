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

/// A score page's fixed top: back, title, and the day picker; behind it the page's dusk scene, or
/// for the WHOOP-style family a plain slate fall-off, as that app keeps its pages.
struct NoopScorePageTitle: View {
    let theme: NoopPageTheme
    let title: String
    @Binding var dayOffset: Int
    var maxBack = 365
    /// Each day's ring for the month sheet.
    let ring: (Date) -> NoopDayRing?
    /// Nil for a tab's own page, which has nowhere to go back to.
    var back: (() -> Void)? = nil

    @State private var calendarOpen = false
    private var family: NoopHeroFamily { NoopHeroFamily.current }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Text(title).font(NoopHTMLFont.outfit(NoopType.title3)).foregroundStyle(NoopHTMLColor.ink)
                if let back {
                HStack {
                    NoopBackButton(action: back)
                    Spacer()
                }
                }
            }
            NoopDayPill(offset: $dayOffset, maxBack: maxBack) { calendarOpen = true }
        }
        .padding(.bottom, NoopPageHeroMetrics.gap)
        .background(alignment: .top) {
            Group {
                if family == .whoop {
                    LinearGradient(colors: [Color(hex: 0x283038), Color(hex: 0x1A1F24).opacity(0.6), .clear],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 560)
                        .noopStretchesOnPull(height: 560)
                } else {
                    NoopPageBackdrop(theme: theme)
                }
            }
            .frame(width: UIScreen.main.bounds.width)
            .offset(y: -140)
            .allowsHitTesting(false)
        }
        .sheet(isPresented: $calendarOpen) {
            NoopDayCalendarSheet(offset: $dayOffset, maxBack: maxBack, title: title, ring: ring)
                .noopFloatingSheet(height: NoopDayCalendarSheet.height)
        }
    }
}

/// A score page's hero, centred at the standard size.
struct NoopScoreHero<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(width: NoopPageHeroMetrics.heroSide, height: NoopPageHeroMetrics.heroSide)
            .frame(maxWidth: .infinity)
            .padding(.bottom, NoopPageHeroMetrics.gap)
    }
}

/// Two figures under the hero, as raised cards.
struct NoopStatTiles: View {
    let tiles: [(label: String, value: String)]

    var body: some View {
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
                        NoopMarkerRow(descriptor: d, reading: store.readings[id], loaded: store.loaded, raised: true)
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
    /// The landscape the Bevel-style family paints behind this page (see `noopScene`).
    var scene: Float = 0

    static let sleep = NoopPageTheme(sky: Color(hex: 0x7B6BE0), ridge: Color(hex: 0x3B2F7A), stars: true, scene: 0)
    static let recovery = NoopPageTheme(sky: Color(hex: 0x3FC9A0), ridge: Color(hex: 0x1C4F49), scene: 1)
    static let strain = NoopPageTheme(sky: Color(hex: 0xF0A04B), ridge: Color(hex: 0x5A3418), scene: 2)
    static let trends = NoopPageTheme(sky: Color(hex: 0x00E59A), ridge: Color(hex: 0x15403A), scene: 3)
    static let you = NoopPageTheme(sky: Color(hex: 0xE08A9B), ridge: Color(hex: 0x4A2430), scene: 4)
}

/// The dusk scene behind the top of a score page, drawn on the GPU and paused off screen. The
/// Bevel-style family paints a full landscape instead.
struct NoopPageBackdrop: View {
    let theme: NoopPageTheme
    var height: CGFloat = 520

    private var painted: Bool { NoopHeroFamily.current == .bevel }

    var body: some View {
        NoopSlotClock { t, reveal in
            GeometryReader { g in
                if painted {
                    Rectangle().colorEffect(ShaderLibrary.noopScene(.float2(g.size), .float(Float(t)), .float(theme.scene)))
                        .opacity(reveal)
                } else {
                    Rectangle().colorEffect(ShaderLibrary.noopBackdrop(
                        .float2(g.size), .float(Float(t)), .color(theme.sky), .color(theme.ridge), .float(theme.stars ? 1 : 0)))
                        .opacity(reveal)
                }
            }
        }
        .frame(height: painted ? height + 80 : height)
        .frame(maxWidth: .infinity)
        .noopStretchesOnPull(height: painted ? height + 80 : height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
