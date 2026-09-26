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

No pressed-state scale. Pressed = fill one step brighter, 120 ms. Nothing below 44 pt is tappable.

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
- Row: `HStack(spacing: 3)`, `padding 6`, radius **26**, fill `tabBarFill` over a 20 pt gaussian
  blur, 0.5 pt `tabBarBorder`, shadow `0 8 26 rgba(0,0,0,.5)`, `allowsHitTesting(true)`.
- Inactive tab: `frame(maxWidth: .infinity)`, height 46, radius **20**, no fill, icon only.
- Active tab: same, `flex 1.7` (i.e. 1.7 × an inactive tab's width), fill `NoopPalette.accent`
  solid, icon + label `buttonLabel` 12.5/600 `onAura`, `HStack(spacing: 7)`.
- Centre **+**: 44 pt circle, `margin .horizontal 2`, fill `accent`, shadow
  `0 4 14 rgba(23,162,230,.4)`, a 23 pt Outfit 300 "+" in `onAura`.
- Five destinations: Today · Trends · **+** · Rest · You. The + opens the log sheet, it does not
  navigate. **Wire all five in all nine acts** — one was found dead in Act 6.

## 11 · The orb `[formula]`

Five concentric layers, all centred, all on the same 16 s box-breathing clock. Sizes are diameters.

| Layer | Ø | What |
| --- | --- | --- |
| Glow | 268 | `radial-gradient(circle, accent 40 %, accent 0 % at 68 %)`, blur 6, `boxGlow` |
| Ring | 224 | 1 pt border `auraPale 50 %`, `boxRing` |
| Body | 176 | `radial-gradient(circle at 38 % 32 %, #9FE2FB, #2FB2F0 55 %, #0A5F92)`, `boxOrb` |
| Inner shade | 176 | `inset 0 −8 24 rgba(4,42,66,.5)` — an `Ellipse` overlay, blurred, masked to the circle |
| Sheen | 176 | `conic-gradient(from 200deg …)`, `mix-blend-mode: overlay`, `drift` 24 s linear |

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

**The whole orb is a tap target** → `day/charge`. There is **no numeric readout under the orb.**

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

- Enters from `translateY(102%)` → 0 on `NoopSpecMotion.sheet`. 102 % so its shadow clears.
- Radius 26 top corners, `.continuous`, fill `NoopPalette.card`, 0.5 pt `cardBorder`.
- A 36 × 4 grab handle, radius 2, `white 18 %`, 10 pt from the top, centred.
- Swipe-back closes an open sheet **before** it walks the back map (RULES / routes).
- Filters inside a sheet **persist across open and close** — they are screen state, not sheet state.

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
