#if os(iOS)
import Foundation
import SwiftUI

/// How Noop Aura starts (26 Oct 2026): a calm companion with the essentials on show and everything else
/// one tap away. The full list lives in docs/aura/defaults.md; this file holds the parts that are not a
/// plain default value somewhere else: units from the iPhone's region, and the one-time choice an
/// upgrading wearer makes about the new default look of their pages.
@MainActor
enum NoopDefaults {

    // MARK: Units

    /// Imperial only where the iPhone itself is set to US measurements; everywhere else metric. The UK's
    /// own mixed system reads metric for the body, as UK health apps do.
    nonisolated static func unitSystem(for measurement: Locale.MeasurementSystem) -> UnitSystem {
        measurement == .us ? .imperial : .metric
    }

    nonisolated static var regionUnitSystem: UnitSystem { unitSystem(for: Locale.current.measurementSystem) }

    /// Registered, not written: a wearer who never chose keeps following the region, and every reader
    /// of the setting (`@AppStorage` or `UserDefaults`) sees the same answer. Temperature and distance
    /// already follow this setting when unset.
    nonisolated static func register() {
        UserDefaults.standard.register(defaults: [UnitPrefs.systemKey: regionUnitSystem.rawValue])
    }

    // MARK: The new default look

    /// Every editable page and its catalog, for the upgrade choice.
    static var pageCatalogs: [(page: String, catalog: [NoopPageSection])] {
        [
            ("today", NoopAct2Screens.todaySections),
            ("rest", NoopAct1Screens.restSections),
            ("trends", NoopTrendsCatalog.sections),
            ("fitness", NoopFitnessSettings.Section.allCases.map { NoopPageSection(id: $0.rawValue, title: $0.title, detail: "") }),
            ("you", NoopAct5Screens.youCatalog),
            ("recovery", NoopRecoveryPage.sections),
            ("strain", NoopStrainPage.sections)
        ]
    }

    static let lookChoiceKey = "noop.defaults.lookChoice.1219"

    /// Ask once: only a wearer who arranged at least one page differently from the new default, and
    /// only until they answer. A fresh install has nothing arranged and is never asked.
    static var needsLookChoice: Bool {
        guard UserDefaults.standard.string(forKey: lookChoiceKey) == nil else { return false }
        return pageCatalogs.contains { NoopPageLayout.hasArrangement(page: $0.page, catalog: $0.catalog) }
    }

    /// Read once per launch: pages consult it on every draw, and the answer can only go from pending to
    /// answered, which `lookChoiceKey` itself reports. A launch that finds no page arranged is already on
    /// the new look, and says so: otherwise a page the wearer arranges later in this build would bring
    /// the upgrade question on the next launch, as if they had come from an older one.
    static let lookChoicePendingAtLaunch: Bool = {
        let pending = needsLookChoice
        if !pending, UserDefaults.standard.string(forKey: lookChoiceKey) == nil {
            UserDefaults.standard.set("new", forKey: lookChoiceKey)
        }
        return pending
    }()

    static func useNewLook() {
        UserDefaults.standard.set("new", forKey: lookChoiceKey)
        NoopPageLayout.resetAllToDefault(pages: pageCatalogs.map(\.page))
    }

    static func keepPages() {
        UserDefaults.standard.set("kept", forKey: lookChoiceKey)
    }
}

/// The card that asks it, on Today under the header: one question, two answers, never shown again.
struct NoopNewLookCard: View {
    let onAnswer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.blueLight)
                    .frame(width: 34, height: 34)
                    .background(NoopHTMLColor.blue.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aura has a new default look")
                        .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text("Calmer pages with the essentials first. Everything else is still one tap away in Add. Your own arrangement stays unless you switch.")
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                NoopActionButton(title: "Keep my pages", variant: .secondary, size: .small, fullWidth: true) {
                    NoopHaptics.play(.cancel)
                    NoopDefaults.keepPages()
                    onAnswer()
                }
                NoopActionButton(title: "Use the new look", size: .small, fullWidth: true) {
                    NoopHaptics.play(.save)
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { NoopDefaults.useNewLook() }
                    onAnswer()
                }
            }
        }
        .padding(16)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(NoopHTMLColor.blue.opacity(0.26), lineWidth: 0.5))
        .accessibilityElement(children: .contain)
    }
}

/// Offered once, when Noop has learned enough nights to plan a bedtime: the nudge is off until then,
/// because a nudge built on a guess is the noise Aura avoids.
struct NoopBedtimeOfferCard: View {
    let onAnswer: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "moon.stars")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.nightLight)
                    .frame(width: 34, height: 34)
                    .background(NoopHTMLColor.night.opacity(0.16), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("Noop has learned your nights")
                        .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text("Want a quiet nudge thirty minutes before the bedtime that gets you your own sleep need? It follows your usual wake, weekday by weekday.")
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                NoopActionButton(title: "Not now", variant: .secondary, size: .small, fullWidth: true) {
                    NoopHaptics.play(.cancel)
                    onAnswer(false)
                }
                NoopActionButton(title: "Nudge me", size: .small, fullWidth: true) {
                    NoopHaptics.play(.save)
                    onAnswer(true)
                }
            }
        }
        .padding(16)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(NoopHTMLColor.night.opacity(0.26), lineWidth: 0.5))
        .accessibilityElement(children: .contain)
    }
}
#endif
