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
            hero.frame(width: NoopPageHeroMetrics.heroSide, height: NoopPageHeroMetrics.heroSide)
            HStack(spacing: 10) {
                ForEach(Array(tiles.enumerated()), id: \.offset) { _, tile in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tile.label).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                        Text(tile.value).font(NoopHTMLFont.outfit(NoopType.title3)).monospacedDigit()
                            .foregroundStyle(NoopHTMLColor.ink).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
                }
            }
        }
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
