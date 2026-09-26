# The fifteen primitives

*Foundations pack, 3 of 5. Build these once. Every screen spec in this pack is then a list of
primitives and their content, which is why the screen specs are short — if a screen spec looks
too thin, it is because the primitive already carries the detail.*

All values in points, at the 402 × 874 reference. Tags per RULES §0: `[static]` `[bound]`
`[formula]` `[proto]`. Swift in `spec/swift/NoopSpecPrimitives.swift` and
`spec/swift/NoopChargeGauge.swift`.

---

## 1 · Card

The container everything sits in. Three sizes of the same thing.

| | Fill | Radius | Padding | Border |
| --- | --- | --- | --- | --- |
| Standard | `NoopPalette.card` | 22 | `16` | 0.5 `cardBorder` |
| Row card | `NoopPalette.card` | 22 | `15` v · `16` h | 0.5 `cardBorder` |
| Hero card | `NoopPalette.card` | 24 | `20` top · `18` h · `18` bottom | 0.5 `cardBorder` |
| List card | `NoopPalette.card` | 22 | `6` v · `16` h — **rows own their own 11 v** | 0.5 `cardBorder` |

**No shadow. No gradient. `.continuous`. `.strokeBorder`, inset.** Do not use `NoopPanelSurface`
or `.noopPanel()` — both add a gradient and an elevation this design does not have.

That is a rule about **this primitive**, not about the app. The app has a registry of legitimate
gradients and shadows — ambient hero glow, the orb's six layers, the 158° directional accent card,
chart band fills, the coach/lavender card, the file-preview page, the tab bar and the two sheet
shadows — read off the HTML and listed in `10-tokens.md` §*Gradients and shadows, as built*. **Do
not go through the app deleting gradients.** A flat standard card is the point; a flat app is not.

A **tinted** card is the same shape with `NoopSpecTokens.tint(hue)` as the fill and
`tintBorder(hue)` as the border. Never both a tint and the standard card fill.

## 2 · List card + row

The workhorse. Roughly half of all 69 screens are a stack of these.

- Card: as above, `padding 6 / 16`.
- Row: `HStack(spacing: 12)`, `alignment: .center`, `padding .vertical 11`,
  **`minHeight 62`** (a two-line row) to `70` (a row with a sub-line and a value).
- A 0.5 pt `hairline` divider on the **top** of every row **except the first**. Draw it as an
  overlay on the row, not a `Divider()` — `Divider` inherits an inset and a system colour.
- Label `rowLabel` 13.5 `textPrimary`. Sub-line `subline` 11.5 `textQuiet`, line-height 1.45.
- Trailing value `chipValue` or `rowFigure`, then a chevron if the row navigates.
- The whole row is the tap target, `.contentShape(Rectangle())`. Never just the label.

**Every row that changes something states what it costs in its sub-line.** `[static]` copy — the
sub-lines are written, not generated.

## 3 · Screen header (pushed screens)

One shape, everywhere. `[static]` geometry.

- Insets `56 / 18 / 8 / 18`. Row `HStack(spacing: 12)`.
- **Back button**: 34 pt circle, `controlFill`, 0.5 pt `controlBorder`. Inside, a 9 × 9 chevron
  drawn from 1.6 pt left + bottom borders rotated 45°, `offset(x: -2)`.
  **The chevron does not shrink** — it is not a system `chevron.left` glyph and must not be
  swapped for one; the SF Symbol is a different weight and optical size.
  **The circle stays 34 pt and the hit target is at least 44 × 44.** The extra 5 pt a side is
  `.contentShape` around the button, not a bigger circle — RULES §11's floor applies to the back
  control like everything else, and a 34 pt tap target is the one place this design would fail it.
- To its right, the **parent screen's name** at 13.5 `textSecondary` (`#939C97`). Not the current
  screen's name. This is a "where you came from" label.
- Screen title, when the screen has one, is `screenTitle` 25 / Outfit 400 / tracking −0.625,
  in the content column below the header, not in it.

**Home screens do not use this header.** Today's is `padding 58 / 20 / 4`, `HStack(spacing: 14)`,
`alignment: .top`, greeting + headline in a `VStack(spacing: 4)` on the left, chips on the right
with `padding(.top, 4)`.

## 4 · Toggle

Never `SwiftUI.Toggle`. The split timing is the whole character of the control.

- Track 46 × 28, radius 14 `.continuous`. Off: `NoopPalette.track` (white 13 %). On: the hue of
  the surrounding context at full strength.
- Knob 24 pt circle `textPrimary` (`#EDF1EF`), at `top 2 / left 2`, `offset(x: 18)` when on.
- Track animates on `NoopSpecMotion.toggleTrack` (220 ms, material curve). Knob animates on
  `NoopSpecMotion.toggleKnob` (240 ms, slight overshoot). **Two curves, one control.**
- Context hues: aura for the strap, blush for identity, green for Apple Health, lavender for
  sleep. The hue is a parameter — a toggle never picks its own colour.
- Tap target is the whole row (§2), not the 46 pt track.

## 5 · Segmented control

- Wrapper: `padding 4`, radius 14, fill `white 5 %`.
- Option: `frame(maxWidth: .infinity)`, height 32, radius 11 `.continuous`.
- Selected: hue at **20 %** fill, **42 %** border (0.5 pt), label 11.5 / **600**, colour = the
  hue's *text* variant (`auraPale` / `blushSoft` / `lavenderText`).
- Unselected: no fill, no border, label 11.5 / 400 `textSecondary`.
- Transition `NoopSpecMotion.segment` on fill, border and colour together — 180 ms.
- `whiteSpace: nowrap` in the prototype → `.lineLimit(1)`, and at `accessibilityLarge` the whole
  control becomes a vertical list of 44 pt rows (RULES §11).

## 6 · Chip

- 10.5–12 pt label, `padding 5–6 v / 10–11 h`, radius 9–10 `.continuous`.
- Hue at **12 %** over base, 0.5 pt border of the hue at **22–30 %**.
- Numeric chips are `.monospacedDigit()`. Delta chips carry a sign, always (`+3`, `−7`, never `3`).

## 7 · Buttons

| | Height | Radius | Fill | Label |
| --- | --- | --- | --- | --- |
| Primary | 48 | 17 | `NoopPalette.accent` solid | `buttonLabel` 12.5/600 `onAura` |
| Secondary | 44 | 15 | `controlFill` + 0.5 `controlBorder` | `buttonLabel` 12.5/600 `textBody` |
| Destructive | 44 | 15 | `controlFill` + 0.5 `controlBorder` | 12.5/600 `hot` |

No pressed-state scale. **Pressed = a white overlay from 7 % to 10 %, 120 ms** — measured, and the
one state a hand-rolled button always misses. Nothing below 44 pt is tappable.

**Height, radius, accent and ink are all parameters.** The table above is the three defaults, not
the three buttons the app has: `goal/set`'s commit is 52 / 18, `goal/picker`'s camera is 54 / 18 in
amber on `#1E1405`, the review row's Save is 42 / 14, and Act 7's test is 44 / 15 in lavender. One
blue 48 pt button cannot represent them, and a build that ships one has redrawn four screens.

## 8 · Uppercase caption

`caption` 10/600, tracking **+1.2**, uppercased, `textTertiary` (`#8B958F`). Sits 0 pt above its
card with a `VStack(spacing: 8)` between caption and card. On a coloured section it takes the
hue's *label* variant (`blushLabel`, etc.). **The tracking is not optional** — RULES §1.

## 9 · Strap battery chip `[bound]`

Device battery, **not** Charge. Top-right of every home screen; tapping it goes to `plumbing/strap`.

- Pill: height 30, `padding .horizontal 11`, radius 15, `HStack(spacing: 7)`, fill `controlFill`,
  0.5 pt `controlBorderStrong`.
- Glyph body 21 × 11, radius 3.4, **1 pt** border `Color(hex:"#EDF1EF").opacity(0.4)`.
- Fill: inset 1.2 pt all round, radius 2.2, width `(21 − 2.4) × level`, colour `auraLight`.
- Nub 1.6 × 4.4, radius `0 1.5 1.5 0`, `leading 1`. Glyph + nub in an `HStack(spacing: 1)`.
- Label: the percentage, `chipValue` 12/600 tabular, `textBody`.
- **≤ 20 %**: glyph border, nub, fill and label all → `NoopPalette.effort`; pill tints
  `effort 12 %` / border `effort 34 %`. **≤ 10 %**: the same, in `hot`.

Deliberately quiet. It is a status indicator, not a feature — do not add a chevron.

## 10 · Tab bar

Floating, over the content, on every home screen.

- Container: `padding 0 / 14 / 26`, `allowsHitTesting(false)`, `zIndex 6`.
- Row: `HStack(spacing: 3)`, `padding 6`, radius **26**, fill `tabBarFill` over a blurred
  backdrop, 0.5 pt `tabBarBorder`, shadow `0 8 26 rgba(0,0,0,.5)`, `allowsHitTesting(true)`.
  The prototype is `backdrop-filter: blur(20px)`; **UIKit has no settable radius**, so the shipping
  implementation is `NoopGlass` — a `UIVisualEffectView` on `.systemUltraThinMaterialDark`, with the
  20 pt kept as the value to check against and `tabBarFill`'s 82 % as the compensating opacity.
  Not `.ultraThinMaterial` in SwiftUI: it re-tints an already tinted fill. `NoopSpecPrimitives` §10a.
- Inactive tab: `frame(maxWidth: .infinity)`, height 46, radius **20**, no fill, icon only.
- Active tab: same, `flex 1.7` (i.e. 1.7 × an inactive tab's width), fill **the act's own hue**,
  solid, icon + label `buttonLabel` 12.5/600 in **that hue's ink**, `HStack(spacing: 7)`.
- Centre **+**: 44 pt circle, `margin .horizontal 2`, fill `accent`, shadow
  `0 4 14 rgba(23,162,230,.4)`, a 23 pt Outfit 300 "+" in `onAura`. **Aura in all nine acts** — it
  does not follow the act hue, and it is the only part of the bar that does not.

**The lit tab takes the act's hue, not the brand's.** A hardcoded `accent` paints a blue Rest tab
over Act 1's lavender night. Nor is the hue a property of the destination: Trends is green in Act 4
and lavender in Act 9. Read off the act sources, which are the specification:

| Act · home | Lit tab | Fill | Ink |
| --- | --- | --- | --- |
| 1 night · `rest` | Rest | `rgba(139,153,214,.9)` | `#0D1120` |
| 2 day · `today` | Today | `#17A2E6` | `#04121A` |
| 3 effort · `session` | Today | `#17A2E6` | `#04121A` |
| 4 picture · `trends` | Trends | `#2ECC80` | `#04140C` |
| 5 plumbing · `you` | You | `#E08A9B` | `#2A0E14` |
| 6 ages · `ages` (from Trends) | Trends | `#2ECC80` | `#04140C` |
| 6 ages · `health` (from You) | You | `#F2B45C` | `#1E1405` |
| 7 svea · `coach` | Svea | `#8B99D6` | `#0C1024` |
| 8 goals · `goal` `labs` | You | `#F2B45C` | `#1E1405` |
| 9 instrument · `index` | Trends | `rgba(139,153,214,.9)` | `#0B0E1A` |

**Act 6 is not the "nothing lit" case** — it was written that way here and the source says otherwise.
Act 6 lights the tab it was *entered through*: from Trends, `ages` shows an active **Trends** tab in
the act's green; from You, `health` shows an active **You** tab in amber. The pill is the same 1.7 ×
slot as everywhere else, so the width always divides by 4.7. Acts 7 and 9 are the other
irregularity — the lit slot reads *Svea* and *Trends* in the act's own hue. Build what the act
source shows; **no shipping act passes a nil active tab.**
- Five destinations: Today · Trends · **+** · Rest · You. **Wire all five in all nine acts** — one
  was found dead in Act 6.

**The + is contextual, and this is the whole of it.** It adds the thing the act you are standing in
is about. It is *not* "open Today's log" — that was written here as a universal rule, it is true of
Act 2 alone, and applying it everywhere replaces four in-act sheets and four real destinations with
one wrong door. Read off the nine act sources:

| Act · home | The + adds | Where it lands |
| --- | --- | --- |
| 1 night · `rest` | tonight's journal entry | the **Journal sheet**, in-act |
| 2 day · `today` | anything loggable today | the **Log sheet**, in-act |
| 3 effort · `session` | a session | `effort/pick` — the session picker |
| 4 picture · `trends` | a look at what is recorded | the **logged / recovery sheet**, in-act |
| 5 plumbing · `you` | a fact about you | the **Add sheet**, in-act |
| 6 ages · `ages` | a measurement the estimate needs | `plumbing/record` — *Add to your record* |
| 7 svea · `coach` | a question | **focuses the Ask field** — in-act, no navigation |
| 8 goals · `goal` `labs` | a lab result | `goal/picker` — *Add lab results* |
| 9 instrument · `index` | nothing; it reads | `plumbing/history` |

Four of the nine present a sheet **without leaving the screen**; four navigate; one moves focus. The
+ never does nothing, and it never lands somewhere the act was not about.

**Ink follows the state on the icon as well as the label.** An inactive tab's glyph is
`#7F8A85`; a lit tab's glyph is the act's own ink (`#04121A`, `#04140C`, `#1E1405`, …), the same
colour as its label. A build that tints only the label ships a lit tab with a grey icon in it.

**Hit testing is a wrapper behaviour, not a detail.** The container is
`allowsHitTesting(false)` so the 26 pt bottom band does not eat taps meant for the content behind
it; the bar row itself is `allowsHitTesting(true)`. Both, or the floating bar is a full-width
invisible lid.

## 11 · The orb `[formula]`

Seven layers, all centred, five of them on the same 16 s box-breathing clock. Sizes are diameters.

| Layer | Ø | What |
| --- | --- | --- |
| Glow | 268 | `radial-gradient(circle, accent 40 %, accent 0 % at 68 %)`, blur 6, `boxGlow` |
| Ring | 224 | 1 pt border `auraPale 50 %`, `boxRing` |
| Body | 176 | `radial-gradient(circle at 38 % 32 %, #9FE2FB, #2FB2F0 55 %, #0A5F92)`, `boxOrb` |
| Inner shade | 176 | `inset 0 −8 24 rgba(4,42,66,.5)` — an `Ellipse` overlay, blurred, masked to the circle |
| Charge glow | 268 | the **level's** hue at `0.42 × heat + 0.1`, blur 6, `boxGlow` — **absent below 3 % heat** |
| Charge core | 176 | the level's hue as three stops (`chargeCoreStops`), opacity `min(1, heat × 1.15)`, `boxOrb`, shadow `0 18 52` at 42 % — **absent below 3 % heat** |
| Sheen | 176 | `conic-gradient(from 200deg …)`, `mix-blend-mode: overlay`, `drift` 24 s linear |

**The two charge layers are the point of the orb, not a flourish.** They are how the sphere itself
walks blue → blush → amber → hot as Charge falls, on the same ramp as the ticks and the numeral. An
orb built without them is permanently blue, and the screen's whole signal is gone. Both evaluate
`NoopSpecTokens` **once** per render, with the colour passed down (§12).

Keyframes, all three on `16s ease-in-out infinite`, at 0 / 25 / 50 / 75 / 100 %:

```
boxOrb    scale  .82 → 1.16 → 1.16 → .82 → .82
boxGlow   scale  .86 → 1.24 → 1.24 → .86 → .86   opacity .32 → .8 → .8 → .32 → .32
boxRing   scale  .80 → 1.32 → 1.32 → .80 → .80   opacity .55 → .12 → .12 → .55 → .55
```

On the orb: the live pulse at `heroNumeral` 52 / Outfit 200 in `#F6FDFF` with
`text-shadow 0 2 16 rgba(4,30,48,.55)`, and under it the breathing word
(`In · Hold · Out · Hold`) at `breathWord` 12.5/600 tracking +1.375 uppercase.

Pulse `[formula]`, modelled on respiratory sinus arrhythmia:

```
bpm = 70 − min(7, floor(cycles) × 1.5) + [3, 1, −3, −1][phase]
```

**Reduce Motion**: all three keyframe animations stop, the orb holds at scale 1.0, the sheen
stops, and the phase word keeps advancing on its 4 s cadence.

**Two tap targets, both plain taps.** The **Ø 176 sphere** opens `day/breathe`. The **surround** —
gauge ring, halo, and the 318 pt block they sit in — opens `day/charge`. **There is no long press**
(`32-nav-addendum.md`), and the sphere's hit region sits *above* the surround's, so the inner tap
wins by hit-test order rather than by gesture priority.

There is **no numeric readout under the orb.**

## 12 · Charge gauge `[formula]`

The tick ring around the orb. This is the detail that makes Charge read as a battery instead of a
score, and it is the most order-dependent thing in the app.

- Box 306 × 306, centred in a block **318** tall.
- **41 ticks**, arc **span 250°**, **start −125°** — so the gap is centred at the bottom.
- Each tick 2 wide × 9 tall, radius 2. **Every 5th tick is 15 tall.**
- Placed by `rotationEffect(angle)` then `offset(y: -142)` from centre — rotate, then translate.
- Index of the level's tick: `lit = round(charge / 100 × 40)`.

| Tick | When | Colour |
| --- | --- | --- |
| **Lit** | `i <= lit` | the level colour, opacity ramping **0.32 → 1.0** from the arc's start to the marker |
| **Ghost** | `i > lit && i <= round(wake / 100 × 40)` | `auraPale.opacity(0.28)` |
| **Off** | above both | `white.opacity(0.13)` |

The **ghost ticks are the headroom you woke with and have spent.** They are not decoration and
they are not optional. A build without them has shipped a score.

- **Marker**: a 12 × 9 triangle (`border-left/right 6 transparent`, `border-bottom 9 #EDF1EF`) at
  the level, `offset(y: -131)`, `drop-shadow(0 0 6 rgba(0,0,0,.5))`.
- **On arrival at Today**, and only on arrival: the gauge animates `wake → charge` over
  **1150 ms ease-out-cubic** (`NoopSpecMotion.chargeDrain`) and the numeral in the sentence counts
  down with it. Not on a value change, not on returning from a pushed screen.
  Under Reduce Motion: final value, 200 ms fade, no count.

## 13 · Charge bar `[formula]`

On the Charge screen and in the small widget. Three layers, in this order:

1. Track: full width, height 12 (widget: 6), radius 6, `white 6 %`.
2. **Ghost fill** to `wake`: `auraPale.opacity(0.16)`.
3. Live fill to `charge`: the level colour. Width animates on `chargeBar` (500 ms ease).

Both fills, always. The pale stretch behind the live fill is the same "spent headroom" idea as the
ghost ticks.

## 14 · Bottom sheet

**Four presentations, not one padded 76 %-capped box.** The log sheet plus **three distinct panel
variants**, and the caps are measured, not shared. This section previously carried a set of numbers —
radius 26, a 36 × 4 handle at white 18 % — that matches no source. Read off the act files:

| Panel variant | Where | Cap |
| --- | --- | --- |
| Structured panel · **74 %** | Act 4 — *Everything you logged* off `trends` | `max-height: 74%`, header pinned, list scrolls |
| Structured panel · **76 %** | Act 9 — the instrument's sheet off `index` | `max-height: 76%`, header pinned, list scrolls |
| Simple **Add** panel | Act 5 — the + on `you` | **its content height, no cap at all** |

Forcing the Add sheet through a 76 % cap gives it a scroll view it never fills and a header rule it
does not have; forcing Act 4 to 76 % moves its list two points under the tab bar. Take the cap from
the screen, not from the primitive.

| | Log sheet (Acts 1, 2 — the +) | Panel (Acts 4, 5, 9) |
| --- | --- | --- |
| Radius | 30 top corners, `.continuous` | 28 top corners, `.continuous` |
| Fill | `NoopPalette.card` `#141817` | `#141817` |
| Top edge | 0.5 pt hairline `white 10 %` — a **top border, not a full stroke** | 0.5 pt `white 9 %` |
| Handle | 38 × 4, radius 3, `white 20 %`, centred | 38 × 4, radius 3, `white 16 %` |
| Padding | 12 / 20 / 30 | 12 / 18 / 30 |
| Scrim | `rgba(4,6,6,.62)` | `rgba(4,6,5,.66)`, faded in .22 s ease |
| Backdrop | **3 pt blur** of the screen behind | 3 pt blur |
| Shadow | `0 −20 50 rgba(0,0,0,.5)` | `0 −14 44 rgba(0,0,0,.6)` |
| Height | its content | **per variant** — 74 % (Act 4) · 76 % (Act 9) · content height, uncapped (Act 5's Add) |

Both enter from `translateY(102%)` → 0 on `NoopSpecMotion.sheet` — **.30 s**
`cubic-bezier(.22,.61,.36,1)`, which is the HTML's `sheetUp .3s` and now the Swift token's value too
(it read .34 s). 102 %, not 100 %, so the sheet's own **upward** shadow clears the screen edge — and
the 2 % has to be computed from a **measured** height, because `.offset(y:)` takes points and 1.02 pt
is not an entrance.

**The scrim and the sheet are on different clocks and both are specified.** The panel's scrim fades
in over **.22 s ease** (`scrimIn`) while the sheet travels over .30 s; the log sheet's scrim is there
with the sheet. Do not put both on one animation — the panel's slower scrim under a faster sheet is
what stops the dim reading as a cut.

**The first presentation must not flash.** The 102 % offset is derived from a measured height, so on
the very first present the height is still 0 and the sheet renders **at its final position for one
frame**. Hold it hidden until it has been measured once, then animate — a first-open that appears
without travelling is the bug this creates.

**Hidden sheet content is hidden from accessibility too.** A dismissed sheet that stays mounted for
its state keeps its buttons in the accessibility tree, so VoiceOver reads a closed sheet's Save
button over the screen behind it. `accessibilityHidden(!isPresented)` on the sheet, always.

Four behaviours, none of them decoration:

- **The scrim, with a 3 pt blur under it.** Not a dim. Without it the sheet is a card floating over
  fully legible content, which is what the review saw and called a broken popup.
- **A tap outside dismisses.** The scrim is the target. It is the only dismissal besides the sheet's
  own buttons and the swipe.
- **The upward shadow.** Negative y. It is what the 102 % exists to clear.
- Swipe-back closes an open sheet **before** it walks the back map (RULES / routes).

And: filters inside a sheet **persist across open and close** — they are screen state, not sheet
state, so the binding lives above the modifier, never in it.

---

## 15 · Confidence chip `[formula]` **[new, 31 August]**

The one visual treatment every latent engine needs before its number can be shown at all
(`60-parity.md` Part 5 §C ¶1, drawn at true size in `Noop Confidence - D Hue Ramp`).

**Two rungs, not three. Solid is plain** — no chip. A permanent *Solid* chip would be noise on
every screen a long-term user sees, and `47-act8-goals.md` already sets the precedent (a read
marker is plain when confident, chipped when uncertain).

**The chip is in the host screen's own hue**, never amber: `10-tokens.md` reserves `effort` amber
for *needs attention* and `hot` for *critical*, and confidence is a progress state, not a severity
one. An amber chip would read as a warning about the user's body rather than a note about the app's
arithmetic — which matters most on `day/charge`, where the illness signal is amber on the same screen.

**The ramp is the tinted-card rule's own range** (`10-tokens.md`), floor while calibrating and
ceiling while building — so the chip never introduces a value the design does not already use:

| | Fill | Border 0.5 pt | Dot | Label colour |
| --- | --- | --- | --- | --- |
| Calibrating | hue @ 7 % | hue @ 22 % | hue @ 42 % | `textTertiary` `#8B958F` |
| Building | hue @ 12 % | hue @ 30 % | hue @ 75 % | the hue's own light text |

Geometry: `padding 4 / 9 / 4 / 8`, corner 10 `.continuous`, a 5 pt dot, gap 6, label 10 pt / 600 /
tracking +0.05 em / **tabular**. It sits in the card header's trailing slot, or beside the figure it
qualifies. On a card too small for a label it shrinks to **the dot alone, same corner**.

**The label names the reason, not the rung** — "3 of 4 nights", never "Calibrating". The rung is
carried by the ramp; the number is what the person can act on.

**While calibrating, the score is withheld and the count takes its place.** This is the behaviour
the shipping iPhone app already has ("Learning your baseline, N of 4 nights") and `60-parity.md`
Part 3 §B records as lost. Where an act already has a dedicated pre-baseline screen — `ages/building`
— that screen keeps the job and `ages` only carries the chip.

**Tappable**, to the screen that explains the arithmetic. Today only `ages/method` exists; the
other engines need the same explainer, which is `60-parity.md` Part 3 §B's *How scoring works*
row. Until it exists the chip is inert rather than dishonest — never a dead tap target with a
chevron.

**Bound to `ScoreConfidence`** (`50-wiring.md` Part 5): computed, and until 31 August unsurfaced.
Every one of the eight latent engines reports on this one ladder.

**Where it is drawn in the prototype**, one per hue, each off a `confidence` prop
(`solid` / `building` / `calibrating`):

| Screen | Hue | Qualifies | Calibrating label |
| --- | --- | --- | --- |
| `night/rest` | `rest` lavender `139,153,214` | your own sleep need, learned over ninety nights | `21 of 90 nights` |
| `day/charge` | `accent` aura `23,162,230` | why you woke with that number — `RecoveryScorer.chargeDrivers` | `2 of 4 days` |
| `ages/ages` | the screen's green `46,204,128` | body age, off the existing evidence-completeness prop | `6 of 28 instruments` |

The rest of the eight take the same chip in their host screen's hue when they are surfaced.

## Icons

24 × 24 stroked paths, 1.6–1.8 pt stroke, round caps and joins. `[static]` — lift the path data
from the `GLYPH` map at the top of each act's script block; they are drawn to a consistent optical
weight and the SF Symbol equivalents are not.

Names in use: `today, trends, moon, you, heart, plus, bed, plate, watch, shield, cloud, clock,
clock2, ruler, bell, check, spark, flask, search, battery, sun, wave, file, key, chart, person,
cam, link, copy, share, x, grid, download, upload, globe`.

**No raster assets ship with this design.**
