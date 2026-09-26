# Act 9 · The instrument

*Screens: `instrument/index`, `instrument/metric`, `instrument/compare`, `instrument/effects`.
Prototype: `Noop Act 9 - The Instrument.dc.html`. Hue: lavender `#8B99D6` — this act does not use
the green accent for its own values, only for the second series on `compare`.*

Four engines were already written and had never had a screen. The gap they close is one gap, so it
gets one place: **a returning user could read the morning, the night and the training decision, and
had no way to ask the data a question they did not think of in advance.**

---

## 0 · Doors, and the tab argument

`[static]` Two doors, both in the first cut:

1. **Foot of `picture/trends`** — a row in the existing links card, lavender icon:
   *Ask it something* / *every signal you keep, and what moves it* → `instrument/index`.
2. **From `svea/coach`** — inside an answer card, below the memory row, a lavender-tinted row:
   *Open variability in the instrument* / *84 nights, what it moves with, and at which lag — the
   engines answer this better than I can* → `instrument/metric` on the metric the answer was about.

**No sixth tab.** The bar stays at five for the same reason Act 3 has no tab: a tab is for a place
you stand every day. It earns one only if post-launch usage says the instrument became the second
home — a measurement, not a design call, and a reversible one.

## 1 · The range control — build this once

Same component, same position on all four screens: **directly under the header, above the first
card**. Four segments: `30`, `90`, `365`, `All`.

- A range the record cannot fill is **present, at 38 % opacity, with no press state** — the app's
  existing convention for a row that cannot act.
- Under the control, always: the count of nights **actually behind the answer** `[formula]`.
  Not only when it disagrees with the range.
  - `< All` → `"{worn} nights actually behind this answer. You asked for {requested}."`
  - `All` → `"{worn} nights actually behind this answer, of {total} on record"`
  - range exceeds record → `"nights on record — there is no more history than this"`
- Segment geometry: `flex:1`, 11 pt vertical padding, radius 12, inside a 3 pt-padded track,
  radius 15. Total height ≥ 44 pt. Selected: `rgba(139,153,214,.20)` fill, text `#C6CEE8`.
- **Changing range never re-animates a chart from zero.** Values interpolate on swap, 220 ms.
  The shape is the subject and a rebuild loses it.

## 2 · `instrument/index`

Header row back to *Trends*. Title `screenTitle` 25 `[static]` *Ask it something*; sub `[static]`
*Every signal Noop keeps, with the one number that says whether it has moved. Open any of them to
see what it moves with.*

Then: the range control · a filter chip row (`All`, `Night`, `Day`, `Effort`, `Body`, `Logged`;
the `Logged` group renders under the heading **What you log**) · one list card per group · a doors
card · the footnote.

**Row**, min-height 68, chevron, tappable to `metric`:

| Element | Provenance | Notes |
| --- | --- | --- |
| Name | `[static]` per signal | `reg` is schedule-dependent — see `00-RULES` §schedule and the build document §4 |
| Value | `[bound]` | Last non-null in the window, formatted per signal (`7h 12m`, `8,400`, `2 dp`) |
| Unit | `[static]` | Behaviours read `days a week` |
| Chip | `[formula]` | `no real change` · `{n} nights so far` (thin) · `±{delta}` · behaviours `about the same` / `±{n} a week` |
| Sparkline | `[bound]` | 86 × 26, down-sampled to ≤ 46 points, gaps interpolated. Stroke: grey when flat or thin, lavender for a neutral signal, green/amber by direction otherwise |

22 signals, in five groups: Night 9, Day 3, Effort 1, Body 3, Logged 6.

## 3 · `instrument/metric` — the dossier

Header back to *Every signal*. Title = signal name. Hero numeral 52 `[bound]` + unit. Then a read
sentence `[formula]` (thin / flat / moved variants — build document §5.2), the range control, and:

1. **Chart card.** Three-day min/max band `rgba(139,153,214,.13)`, line 2 pt `#8B99D6`, last point
   3.6 r. A least-squares fit as a dashed `rgba(237,241,239,.42)` line, **drawn only when the change
   clears its noise threshold and n ≥ 21**. Axis labels per range. Note `[static]`.
2. **Thin card**, only when n < 21: lavender tint, *Not enough of it yet* + the count and the bar.
3. **What it moves with.** Up to four rows, `[formula]`: name, lag chip, signed r to 2 dp, a bar at
   `|r| / 0.8` of the width, one sentence. Tapping a row opens `compare` pre-loaded with the pair
   **and the lag pre-selected**.
4. **Links card**: *Put it against something* → `compare` · *Ask Svea about this* → `svea/coach`
   (she gets the dossier, not just the number) · *Where it comes from* → `plumbing/data`.
5. Footnote `[static]`.

**A logged behaviour is 0/1 a day.** Its dossier plots a **trailing 7-day rate** (days per week), not
the raw square wave — but correlations below use the raw daily series, which is the honest input.

## 4 · `instrument/compare`

Two slot buttons (A lavender, B green) each opening a signal sheet · the range control · the overlay
card · the fit card · the shift card · footnote.

- Overlay: two independently scaled polylines on one 300 × 130 box. B is dashed `5 4`. Legend names
  both, and appends *· shifted n days* to B when a shift is active.
- **Fit card** `[formula]`: signed r as a 26 pt numeral, n nights with both, and a body that either
  states the strength or explains the refusal. Cleared = `|r| ≥ 0.28 && n ≥ 21`; the card loses its
  lavender gradient and reads *No fit drawn* when it is not.
- **Shift card**: three boxes — `same day`, `+1 day`, `+2 days` — each showing r at that lag.
  Header right: `strongest at {…}`. The note is the act's most useful sentence when the best lag
  is not zero; see build document §5.3.

## 5 · `instrument/effects`

Range control · the ranking · with-and-without · what one more costs · footnote.

| Engine | Gate | Failure state |
| --- | --- | --- |
| `EffectRanker` | ≥ 5 days with **and** ≥ 5 without, per behaviour; effect ≥ 3.5 % of the target mean | *Still learning* (names which side is short, and by how many days) or *Nothing here clears the bar* |
| `BehaviorInsights` | ≥ 5 on each side | *Only {n1} days with it and {n0} without in this window. Noop needs five on each side before it will put two averages next to each other.* |
| `DoseResponseEngine` | none — answers on day one | Borrowed / blending treatment carries the honesty |

**The lag lives in the row.** Three slots — *same day*, *next morning*, *two days* — and the one the
effect lands in is filled (9 pt lavender dot with a glow); the others are hollow rings, `.22` for a
passed slot and `.13` for a future one. *Your evening drink shows up tomorrow morning, not tonight*
is more useful than any ordering, and a ranking that hides it has thrown away its own insight.

**With-and-without**: two rows, each a mean marker on an 8 pt track with a ±1 SD shaded span, the
value and the day count. Then the difference sentence, then the overlap sentence. The overlap is
what stops a small difference reading as a big one.

**Borrowed against earned**: the blend, the states, the hues and the fill widths are in the build
document §5.4. *Colour is ownership.* **If the build cannot hold that distinction, this engine does
not ship** — that is the parity audit's judgement and this act does not reopen it.

## 6 · State review

Props on the prototype, so a reviewer can see the uncomfortable states without waiting for data:

| Prop | Values | What it forces |
| --- | --- | --- |
| `effects` | `ranked` · `learning` · `nothing` | The three EffectRanker outcomes |
| `dose` | `auto` · `borrowed` · `blending` · `yours` · `disagrees` | The four dose treatments |
| `range` | `30` · `90` · `365` · `All` | Recomputes everything; `365` is the dimmed case |
| `schedule` | `day` · `night` | `Bedtime drift` → `Anchor drift` |

`spo2` carries only 19 nights **in the data**, so the thin dossier state is reachable without a prop.

## 7 · Never

- `CorrelationEngine` gets no entry in the UI. It is plumbing for the index, the dossier and the
  overlay; surfacing it would be the fourth settings screen.
- No causal claim, anywhere. The engines write their own plain-language lines, so **the copy review
  is on the engine strings, not on the layout.**
- No relationship drawn faintly because it nearly cleared. It is in or it is out.
