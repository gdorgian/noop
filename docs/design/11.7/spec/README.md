# Noop — implementation spec

Everything needed to build the redesign 1:1 in `Strand/` + `Packages/StrandDesign/`. Read in order.

## Precedence — the HTML wins

**The prototype is the specification.** Where the HTML and any written spec disagree — a number, a
layout, a state, a route, a piece of copy, or a **behaviour** — the HTML is right and the written
spec is the bug. Tell me and I will fix the spec; do not build the written version.

The one exception is not an exception to that rule, it is a question: if an HTML destination is
**fake, dead, or contradicts another screen**, that is a defect in that specific door. Ask about
**that destination** and get an answer for it. Do not fall back on the written spec, and do not
generalise from one broken door into a rule about the others.

Among the written files, `00-RULES.md` wins — if a screen spec contradicts it, the screen spec is
the bug. But both lose to the HTML.

## Foundations

| File | What |
| --- | --- |
| `00-RULES.md` | **Start here.** The twelve things that make a faithful build look cheap, the provenance legend, Dynamic Type reflow, the nine recurring states. |
| `10-tokens.md` | What already exists in `NoopPalette`, what is additive, what to stop using. |
| `13-branch-corrected-foundation.md` | **Read before either of the two below.** The active branch deleted the old Aura layer in `1ecb5712`, so the pack now ships its own palette-only `NoopPalette.swift`; what is deliberately not restored, and the three font problems with the resource path and the registration order. |
| `12-palette-bindings.md` | **Every `NoopPalette` property with its value**, `controlFill` in full, the two greens and which is which, and — read this first if the build fails — where the five Swift files have to live for those names to resolve. |
| `20-primitives.md` | The fifteen primitives. Build these once; the screen specs assume them. |
| `30-routes.md` | Every route, back map, tap target, sheet and piece of surviving state. |
| `50-wiring.md` | **What feeds every bound value**, screen by screen, against the real codebase — plus the six things that need a new derivation before they can be built. |
| `34-implement-31-august.md` | **The 31 August change set, in build order** — the three dead nav paths, `today`'s third card state, `effort/across`, and the confidence chip applied. One page per change, with its acceptance walk. |
| `80-not-in-this-release.md` | **What is deliberately not built**, and the `Later` convention that keeps it honest on screen. Read before filing a missing feature as a bug. |
| `90-aura-11.7.md` | **The reply to the v11.7 merge note** — the five answers engineering asked for, the thirteen new screens and the tenth act, in four waves. Read before starting anything the merge brought in. The five answers are approved (17 September); §5's six questions are open. |
| `70-copy.md` | **The copy law.** Twelve rules, the banned vocabulary, how to lift a string without drift, the honesty gates and the noise thresholds. Read before typing a sentence. |

## The build document

**`Noop - Build Document.dc.html`** at the project root — the long form of `70-copy.md`, printable.
It carries what the act specs deliberately do not: the generated-string tables (every sentence the
app writes itself, as a template with slots), the full schedule-vocabulary pair table, the 69-screen
inventory with the door each screen is reached through, and the fourteen-point per-screen QA list.
On a **sentence** it agrees with the prototype, and both win over an act spec.

## Swift

Additive to `StrandDesign`, in its naming and doc-comment style. Nothing existing changes.

**All six go in `Packages/StrandDesign/Sources/StrandDesign/Aura/`.** Not in the app target, not in
a new `NoopUI/` group: the palette is public *in the StrandDesign module*, so an app-target copy
fails to compile on every colour reference. The Swift sources need no `project.yml` entry —
SPM globs the package. **The fonts do need one:** they go in
`Sources/StrandDesign/Resources/Fonts/`, and their old `UIAppFonts` and app-resource references
have to come out of `project.yml` / `Info.plist` before `xcodegen generate`. Full reasoning in
`13-branch-corrected-foundation.md`; the steps are in `00-RULES.md` §6.

| File | What |
| --- | --- |
| `swift/NoopPalette.swift` | **The palette the pack now ships** — surfaces, the text ramp, three hues, `orbStops`, metrics. Palette only: no components, no screens, no body-state type. Replaces the file `1ecb5712` deleted. |
| `swift/NoopSpecTokens.swift` | The tokens `NoopPalette` does not have, the tinted-card rule, the charge heat ramp and the four state sentences. |
| `swift/NoopSpecType.swift` | The type scale, with tracking in **points** and a `lineSpacing` helper. `.noopText(_:)` is the intended call site. |
| `swift/NoopSpecMotion.swift` | Six curves, and every Reduce Motion override. |
| `swift/NoopSpecPrimitives.swift` | Card, row, header, back chevron, toggle, segmented, chip, buttons, caption, screen scaffold. |
| `swift/NoopChargeGauge.swift` | The Charge model, the 41-tick gauge, the bar, the strap battery chip. |

## Screens

| File | Act | Screens |
| --- | --- | --- |
| `acts/40-act1-night.md` | 1 · The night | **5** — rest, tonight, alarm, why, debt |
| `acts/41-act2-day.md` | 2 · The day | **12** — today, charge, day, vitals, stress, heart, inbox, breathe, bcatalog, bplayer, bsweep, bfound |
| `acts/42-act3-effort.md` | 3 · The effort | **7** — session, pick, ready, live, intervals, detail, across |
| `acts/43-act4-trends.md` | 4 · The bigger picture | **4** — trends, capacity, rhythm, year |
| `acts/44-act5-plumbing.md` | 5 · The plumbing | **21** — you, record, zones, history, strap, notifs, devices, pair, apple, position, automations, data, import, reading, imported, rejected, backup, settings, widgets, lab, onboard |
| `acts/45-act6-ages.md` | 6 · Your ages | **5** — ages, building, driver, method, health |
| `acts/46-act7-svea.md` | 7 · Svea | **5** — coach, gate, setup, consent, memory |
| `acts/47-act8-goals.md` | 8 · Goals and labs | **6** — goal, set, labs, review, picker, marker |
| `acts/48-act9-instrument.md` | 9 · The instrument | **4** — index, metric, compare, effects |

**69 screens, nine acts: 5 · 12 · 7 · 4 · 21 · 5 · 5 · 6 · 4.** Read off the standalone HTML, which
is the specification. If a count anywhere in this pack disagrees with this table, this table is
right and the other place is stale — tell me.

## The living reference

`design_handoff_1_september/Noop app - standalone (open me).html` — the whole app in one offline
file. Keep it open while building; it is not a reference, it is the specification. See
**Precedence** at the top: it wins on numbers, layout, copy and behaviour alike. Where a destination
in it is fake or dead, ask about that destination rather than substituting the written spec.

## Reusing what exists

All of these survived `1ecb5712`. Do not rebuild them — re-tint them: `Hypnogram.swift`,
`OverviewHRChart.swift`, `TrendChart.swift`, `Sparkline.swift`, `SportIcon.swift`,
`DayNavBar.swift`, `NoopLiquidGlassSearchField.swift`, `YearHeatStrip`, and `SettingsView.swift`'s
`measureField` / `poundsField` / `feetInchesField` / `hrMaxField`.

**One exception: `ProfileAvatarView.swift` must be extended**, not just re-tinted. Its no-photo
fallback is `BrandMark`; the design needs the user's initials. See `44-act5-plumbing.md`.

## What this spec does not answer

`50-wiring.md` now carries these, with what the codebase does and does not have behind each one:

1. **The Charge ledger.** The morning number exists (`RecoveryScorer`); nothing decrements it during
   the day. Six decisions have to be made before `day/charge` can be built.
2. **"Back to about {n} by morning"** is answered — `RecoveryForecaster.forecast(...)`, which also
   returns a ± band the design does not currently show.
3. **Should Charge drain live, or recompute on foreground?** The prototype recomputes on arrival,
   which is the safer default.
4. **ANCS.** Not app code at all. `notifs` is firmware plus a strap-config sync, and the app list
   cannot be pre-populated — iOS will not enumerate installed apps.
5. **Light theme** — designed values exist for dark only.
