# The thirteen things that make a faithful build look cheap

*Foundations pack, 1 of 5. Read this before touching a screen. It is ordered by how much
damage each mistake does, and every item is a thing that is currently wrong in the build.*

Target: **402 × 874 pt** (iPhone 16 Pro logical size). Every number in this pack is in **points**,
and 1 prototype CSS pixel = 1 point. No conversion, no scaling — see §11 for other widths.

---

## Provenance legend — used on every value in this pack

Your coder's biggest silent risk is shipping a prototype fiction as a real feature. So every
value and every sentence in the screen specs carries one of these tags:

| Tag | Meaning | What the coder does with it |
| --- | --- | --- |
| `[static]` | Fixed by design. A literal. | Type it exactly. Never compute it. |
| `[bound]` | Comes from real data. | Wire it. The prototype's value is a stand-in. |
| `[formula]` | Derived — the formula is given. | Implement the formula, not the number. |
| `[proto]` | Prototype-only scaffolding. | **Do not build.** Frame, fake clock, fake device. |

A sentence tagged `[static]` is **final copy**. Rewording it is a bug, the same as a wrong hex.
If a `[static]` string reads awkwardly in your locale, raise it — do not fix it locally.

---

## 1 · Tracking is in points, not ems — and it is on nearly everything

This is the single largest source of drift. The prototype writes `letter-spacing: -.02em`;
SwiftUI's `.tracking()` takes **points**. `em` is relative to the font size, so:

```
tracking(pt) = size(pt) × em
```

| Where | CSS | Size | `.tracking()` |
| --- | --- | --- | --- |
| Hero numeral | `-.03em` | 52 | `-1.56` |
| Screen title | `-.025em` | 25 | `-0.625` |
| Headline | `-.02em` | 23 | `-0.46` |
| Section head | `-.02em` | 19 | `-0.38` |
| Row figure | `-.02em` | 17 | `-0.34` |
| Uppercase caption | `.12em` | 10 | `+1.2` |
| Micro caption | `.12em` | 9.5 | `+1.14` |
| Breathing word | `.11em` | 12.5 | `+1.375` |

Everything else is `0`. Do **not** use `.kerning()` — it does not apply to the trailing edge of
a run and gives a different result on centred text. Use `.tracking()`.

The positive tracking on uppercase captions matters as much as the negative on numerals. A
10 pt uppercase label with no tracking is the most common "close but cheap" tell in the build.

## 2 · Line height needs `lineSpacing`, and `lineSpacing` is not line height

CSS `line-height: 1.5` sets the **total** height of a line box. SwiftUI's `lineSpacing` adds
space **between** lines, on top of the font's own line height. They are not the same number.

```swift
// lineSpacing = (size × cssLineHeight) − uiFont.lineHeight
extension Font { … }   // see NoopSpecType.swift, which does this arithmetic for you
```

Never hard-code `lineSpacing: 1.5`. Multi-line body copy set with the default line spacing
reads roughly 4 pt tight per line, which is why cards in the build come out shorter than the
spec and the rhythm between them collapses.

Also set `.lineSpacing` **before** `.frame`, and give every multi-line string
`.fixedSize(horizontal: false, vertical: true)` — otherwise SwiftUI will truncate to one line
inside a stack that has a proposed height.

## 3 · Borders are 0.5 pt, inset, and drawn with `strokeBorder`

- `.stroke` centres the line on the shape's edge, so half of it renders **outside** the frame
  and the visible radius grows. `.strokeBorder` insets it. Cards drawn with `.stroke` are the
  reason edges look soft and radii look wrong.
- `0.5` means **0.5 points** — a literal. It is not `1 / displayScale`. On a 3× screen that
  would be 0.333 pt and the edge disappears.
- Exactly two things in the app are 1 pt: the **strap battery glyph** outline and the **orb
  halo ring**. Everything else is 0.5.

```swift
RoundedRectangle(cornerRadius: 22, style: .continuous)
    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
```

## 4 · Every corner is `.continuous`

`RoundedRectangle(cornerRadius:)` defaults to `.circular`. CSS `border-radius` is closer to
Apple's continuous curve, and at radius 22–26 the difference is plainly visible: circular
corners look pinched and the card reads as a web div. Pass `style: .continuous` **every time**,
including on `.clipShape`, `.strokeBorder`, `.background` and `.contentShape`.

Circles stay circles: use `Circle()`, not a rounded rect with radius = half the side.

## 5 · The tab bar is not `.ultraThinMaterial`

Spec: fill `rgba(23,28,26,.82)` over a **20 pt gaussian blur** of what is behind it, plus a
0.5 pt `rgba(255,255,255,.09)` top border, radius 26 continuous.

`.ultraThinMaterial` is a vibrancy effect with its own tint and a much larger blur radius; it
lightens the bar and desaturates the content behind it. Two acceptable routes:

1. `.background(.ultraThinMaterial.opacity(…))` **plus** `Color(hex:"#171C1A").opacity(0.82)`
   on top — cheapest, and acceptable if the resulting bar matches the reference at 82 %.
2. A `UIVisualEffectView` wrapping `UIBlurEffect(style: .systemChromeMaterialDark)` with a
   `CAFilter` gaussian radius of 20, tinted as specified — exact, and what the design assumes.

Whichever route: the **container** is `allowsHitTesting(false)` and only the inner row takes
touches, so the bar never eats a scroll that starts near the bottom of the screen.

## 6 · Fonts must be bundled, registered, and asked for by PostScript name

Outfit (200/300/400/500) and Instrument Sans (400/500/600) — **never** fetched at runtime.

The files must sit in the **package's** resources:

```
Packages/StrandDesign/Sources/StrandDesign/Resources/Fonts/
```

not `StrandiOS/Resources/Fonts`, which is where the repo keeps them today. `registerFonts()` reads
`Bundle.module` — a package bundle cannot see an app target's resources — and `NOOPiOSWidgets` links
`StrandDesign` without the app, so a widget built against app-target fonts renders in San Francisco.
`Package.swift` already declares `resources: [.process("Resources")]`, so moving the files needs no
manifest change.

**Files are not faces.** The repo ships two *variable* files, `Outfit.ttf` and `InstrumentSans.ttf`,
and this design names seven *faces*. Registration is per file; `Font.custom` asks per face — so
register the files first, then validate the names (`NoopSpecType.registerFonts()` now does exactly
that, in that order).

**Four font files, three licences.** Outfit and Instrument Sans ship as variable files, both
verified to expose all their named instances; Instrument Serif has no variable build and ships as
its two static cuts. Move all of this into that folder:

```
Outfit.ttf                    OFL-Outfit.txt
InstrumentSans.ttf            OFL-InstrumentSans.txt
InstrumentSerif-Regular.ttf   OFL-InstrumentSerif.txt
InstrumentSerif-Italic.ttf
```

Every licence travels with its fonts — SIL OFL requires it, and a build-from-source fork will look
for them next to the files. The static one-file-per-face set for Outfit/Sans is not needed;
`registerFonts()` still looks for it first, so dropping it in later would need no code change.

**Instrument Serif is used in the app**, not only in the prototype's margins: `night/why`'s
headline, `night/tonight`'s stop note, and an italicised measured phrase inline in both `why`
variants. Three roles in `NoopSpecType`, listed in `acts/40-act1-night.md`. Do not substitute the
sans for any of them.

**Moving the files is a project change, not a no-op.** `Package.swift` needs no edit — SPM globs
`Sources/StrandDesign/Resources` — but the app target's own copies have to go, or you ship the same
faces twice and they can drift to different versions:

1. Delete the font files from `StrandiOS/Resources/Fonts`.
2. Remove their `UIAppFonts` entries from `StrandiOS/Resources/Info.plist` (and the generated
   `properties:` block in `project.yml`, which is what rewrites that plist).
3. Remove any app-target resource reference to that folder in `project.yml`.
4. `xcodegen generate`.

`UIAppFonts` and `CTFontManagerRegisterFontsForURL` are two different registration mechanisms;
leaving both in place means whichever wins is a build-order accident.

**Register in both processes.** `Bundle.module` is per-process and the widget is a separate one:
call `NoopSpecType.registerFonts()` from `StrandiOSApp.init()` *and* from the widget bundle's
`@main` `init()`. It is idempotent. Register in the app only and the Charge widget renders in San
Francisco — and widget snapshots are taken when nobody is watching, so it is slow to notice.

Do all of this **before** validating anything against the prototype: a silent SF fallback makes
every metric in `60-parity.md` look wrong for the wrong reason.

- `Font.custom("Outfit-ExtraLight", size: 52)` — the **PostScript** name, not "Outfit ExtraLight".
  Verify each with `CTFontCopyPostScriptName`; a wrong name silently falls back to San Francisco,
  which is exactly what a "font size is off" bug looks like.
- `Font.custom(_:size:)` **scales with Dynamic Type by default**. For the fixed-metric parts of
  the design (§11) use `Font.custom(_:fixedSize:)`, and opt individual roles back in explicitly.
- Outfit's cap height sits lower than SF's. A numeral vertically centred by SwiftUI's default
  baseline will look 1–2 pt low inside a gauge; the affected components in this pack carry an
  explicit `.baselineOffset` or `.alignmentGuide`.

## 7 · Tabular numerals on everything that changes in place

`.monospacedDigit()` on every figure that updates: the pulse, the charge level, percentages,
durations, deltas, costs. Without it a counting-down numeral jitters horizontally and the whole
screen looks unstable — this is the "cheap" feeling in one detail.

Non-changing numbers in body copy stay proportional.

## 8 · Spacing is gaps, not padding, and 116 pt of it lives at the bottom

- Card columns are `VStack(spacing: 12)` (settings-like) or `14`–`16` (editorial). Never per-card
  `.padding(.bottom)`.
- Screen header: `.padding(EdgeInsets(top: 56, leading: 18, bottom: 8, trailing: 18))`, header
  row `HStack(spacing: 12)`.
- Screen content: `.padding(.horizontal, 20)`, `.padding(.top, 8)`.
- **Every scroll view ends with 116 pt of bottom padding.** Not `Spacer()`, not safe-area inset —
  a literal 116, because the tab bar floats over the content. Screens that miss this have their
  last card half-hidden and it reads as a broken build.

## 9 · Colour: use `NoopPalette`, never `StrandPalette`, on any of these screens

`StrandPalette.text*` is a `Color(light:dark:)` pair. These screens are a **fixed dark scene** —
the palette note in `NoopPalette.swift` already says this. Using `StrandPalette` inside an Aura
screen means type flips to dark ink for a user in Light appearance and vanishes.

`NoopPalette` already carries most of what this design needs. The additions this redesign
requires are in `NoopSpecTokens.swift` and are **additive** — nothing existing changes.

Colours that are off by a shade are nearly always one of three things: a `StrandPalette` token
substituted for an `NoopPalette` one; an opacity applied to the wrong layer (tint over base, not
tint over card); or a hue used for the wrong meaning. On meaning, the rule is absolute:

- **Aura blue** = the strap, the day, live data, the primary action.
- **Blush** = *you*. Identity, body, the person. **Never a warning.**
- **Lavender** = sleep, night, rest.
- **Green** = done, confirmed, written.
- **Amber** = something needs attention. Never decoration.
- **Hot** = critical, nearly out.

## 10 · Motion is specified, and "no animation" is a visible bug

Six curves cover the whole app; they are in `NoopSpecMotion`. The two that are most often
missed:

- **Screen enter** — 9 pt rise + fade, 300 ms `cubic-bezier(.22,.61,.36,1)`. Every pushed screen.
  In SwiftUI: `.transition(.modifier(active:identity:))` with `.animation(NoopSpecMotion.enter)`.
- **Toggle knob** — 240 ms with a slight overshoot (`cubic-bezier(.34,1.25,.64,1)`), while the
  **track** crossfades over 220 ms on a plain ease-in-out. Two different curves on one control.
  A stock `Toggle` gets neither and is the reason controls feel generic.

**Reduce Motion** (`@Environment(\.accessibilityReduceMotion)`): the box-breathing orb stops
scaling and holds at its mid scale with the phase word still advancing; the sheen stops; the
charge-drain arrival animation is replaced by the final value with a 200 ms opacity fade; screen
enter becomes a plain 200 ms fade with no rise. Everything else keeps its timing.

## 11 · Fixed metrics, real Dynamic Type

The design is authored at fixed point sizes and **stays fixed** as the device gets wider — a
wider phone gets wider gutters and longer cards, never bigger type. Off the 402 pt reference:

- Horizontal padding stays 20. Cards stretch. Nothing re-flows into columns.
- The Charge gauge block (318 pt tall, 306 pt box) is **centred, never scaled**. On a 375 pt-wide
  phone it still measures 306; the gutters absorb the difference.
- Fixed-width elements (46 pt tab targets, 34 pt back button, 46 × 28 toggle) never scale.

Dynamic Type is supported by **reflow, not resize**:

| Type role | Behaviour |
| --- | --- |
| Body, sub-lines, row labels, footnotes | Scale with Dynamic Type, from xSmall to **AX5**. |
| Screen titles, section heads, card titles | Scale, capped at **xxxLarge**. |
| Hero numerals, gauge figures, the pulse, chip values, uppercase captions | **Fixed.** They are part of a drawn composition; a scaled numeral breaks the gauge. |

Reflow rules at `accessibilityLarge` and above:
1. Row cards go from `HStack` to `VStack(alignment: .leading, spacing: 4)`; the trailing value
   moves under the label. `min-height` becomes `min-height`, not a fixed height — rows grow.
2. Segmented controls become a vertical list of full-width options, each 44 pt tall, same fills.
3. Chip rows wrap (`Layout` or a wrapping `HStack`), never truncate, never scroll horizontally.
4. Delta chips and values keep their fixed size but gain `.minimumScaleFactor(1)` — i.e. they do
   not shrink; the label beside them wraps instead.
5. The four-line sentence under a hero can grow without limit; the card grows with it.

Every screen spec in this pack names anything that departs from these defaults.

## 12 · States are part of the screen, not an afterthought

Nine states recur across the app. A screen spec lists only the ones that screen actually has,
but if a screen touches data or a device, assume it has all of the relevant ones:

| State | Rule |
| --- | --- |
| **Loading** | Never a spinner on a card. The card renders at final size with its figures replaced by a 0.5 pt-bordered pill at `rgba(255,255,255,.04)`, no shimmer. Text stays. |
| **Empty** | One sentence in `textQuiet`, in the card, at body size. No illustration, no "get started" button unless the spec names one. |
| **Unavailable** | The card renders, dimmed to 38 %, non-interactive, with a one-line reason. Never hidden — the user should see what they are missing. |
| **Off** | The switch reads off and the sub-line changes to what off costs. Rows below it stay visible and enabled unless the spec says otherwise. |
| **Denied** (permission) | The two-state access card (aura tint / green tint) at the top; everything below at 38 % and non-interactive. |
| **Committed** (saved) | Green confirmation in place, for 2 s, then back. No toast, no alert. |
| **Coming soon** | Row present, label at 38 %, a `Soon` chip in `controlFill`, no chevron, not tappable. |
| **Reduced motion** | See §10. |
| **Past day** (read-only) | Day navigator only: the banner, the long date, and every live figure replaced by its recorded value or an em-dash. |

---

## 13 · A thin number is never shown as a point value **[new, 31 August]**

`ScoreConfidence` is computed for all eight latent engines and was surfaced nowhere. A modelled
figure carries the **confidence chip** (`20-primitives.md` §15) whenever it is not solid, and while
it is *calibrating* the figure is **withheld** and the count takes its place — the behaviour the
shipping app already has and the redesign had lost.

Three consequences a build gets wrong if this is left to each screen:

1. **The chip is in the host screen's hue.** Never amber, never `hot` — those two mean *act on this*
   and *critical*, and confidence means neither. §9's palette rule and `10-tokens.md`'s tinted-card
   range give every value the chip needs.
2. **Solid is plain.** No chip on a settled number. Chipping everything is the same failure as
   scoring everything.
3. **It is one component, not one per screen.** Eight engines report on one ladder; build §15 once.

---

## What to do next

1. Drop in `NoopSpecTokens.swift`, `NoopSpecType.swift`, `NoopSpecMotion.swift`.
2. Build the primitives in `20-primitives.md` once, and use them everywhere. Fifteen
   primitives account for roughly nine tenths of all 69 screens; a screen spec is then a list
   of primitives and their content, which is why the screen specs are short.
3. Only then start on the acts, in order.

If a screen spec and this document disagree, **this document wins** and the disagreement is a
bug in the spec — tell me and I will fix it.
