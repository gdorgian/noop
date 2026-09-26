# Act 1 — The night

*Screen specs. Read `00-RULES.md` and `20-primitives.md` first: a line here like "list card, three
rows" carries the full anatomy from the primitive, and the primitive is binding.*

Tags: `[static]` fixed by design · `[bound]` real data · `[formula]` derived · `[proto]` do not build.

Lavender (`NoopPalette.rest`) is the hue throughout. **Five screens**, home is `rest`.

---

## 1.1 `rest` — home

**Header** — home style: `padding 58 / 20 / 4`, `HStack(spacing: 14)`, `.top`.
- Left, `VStack(spacing: 4)`: greeting `rowLabel` 13.5 `textSecondary` `[formula]` (time-of-day
  from the clock); headline `headline` 23 / Outfit 400 / tracking −0.46 / line-height 1.15 `[formula]`
  — the night's verdict in the design's voice, chosen by score band.
- Right, `HStack(spacing: 9)`, `padding(.top, 4)`: **strap battery chip** `[bound]` → `plumbing/strap`;
  **day chip** (calendar glyph + short date) → expands the day navigator inline.

**Sleep figure** — hero card, radius 24.
- Caption `LAST NIGHT` `[static]`, in `blushLabel`? **No** — lavender: `NoopSpecTokens.lavenderText`
  at caption weight.
- Duration `heroNumeral` 52 / Outfit 200 / tracking −1.56 / tabular `[bound]`, in `textPrimary`.
  Unit ("h", "m") at `rowFigure` 17 in `textQuiet`, baseline-aligned.
- Beside it, a delta chip `[formula]`: "7m over your need" — lavender chip, sign always present.
- Below: one plain sentence `[formula]`, `body` 13.5 line-height 1.5 `textBody`. → `night/why`.

**Hypnogram** — standard card. Four stage bars `[bound]`, lavender at alpha `1 / .6 / .82 / .26`
for Deep / Light / REM / Awake, labels `captionMicro` 9.5 uppercase tracking +1.14 `textTertiary`.
The existing `Hypnogram.swift` component covers this — re-tint it, do not rebuild it.

**Tonight's plan** — row card, lavender tint (`tint(NoopPalette.rest)`) → `night/tonight`.
Label `cardTitle` 14/600; sub-line `[formula]` the bedtime anchor and what it buys.

**Sleep debt** — row card → `night/debt`. Value `rowFigure` 17 tabular `[bound]`, chevron.

**Tab bar**, Rest active.

**States** — Loading: cards at final size, figures replaced by pilled placeholders, no shimmer.
Empty (no night recorded): the hero card carries one sentence `[static]` *"No night recorded. The
strap needs to be worn while you sleep."*, the hypnogram and debt cards are **unavailable** (38 %,
non-interactive).

---

## 1.2 `tonight` — the plan

Header: back → `rest`, parent label `Rest` `[static]`.
Title `screenTitle` 25 tracking −0.625 `[static]` *Tonight*.

1. **Bedtime anchor** — hero card. The anchor time `heroNumeral` 52 `[bound]`; below it what it is
   based on `[formula]`, `body` 13.5.
2. **Wind-down** — list card, rows for each nudge `[bound]`, each with a lavender-hued toggle
   (`NoopSpecToggle(hue: NoopPalette.rest)`) and a sub-line saying what it costs `[static]`.
3. **What tonight puts back** — lavender-tinted card, one sentence `[formula]`.
4. Footnote `finePrint` 11 line-height 1.55 `textDim` `[static]`.

---

## 1.3 `why` — why last night scored that

Header: back → `rest`, parent `Rest`.

1. The score restated `heroNumeral` `[bound]` + state chip `[formula]`.
2. **List card, one row per contributor** `[bound]`: label, sub-line, and the contribution as a
   signed figure `rowFigure` 17 tabular in lavender (positive) or `effort` (negative).
   Amber here means *this is what cost you*, which is the one legitimate decorative-looking use —
   it genuinely needs attention.
3. **What would move it** — standard card, two or three sentences `[static]` phrasing, `[formula]`
   selection.
4. Footnote `[static]`.

---

## 1.4 `debt` — the running debt

Header: back → `rest`, parent `Rest`.

1. Debt total `heroNumeral` `[bound]`, "over the last 14 nights" `bodySmall` 13 `textQuiet` `[static]`.
2. **Fourteen-night strip** — standard card. One bar per night `[bound]`, lavender where the need
   was met, `track` where it was not; `captionMicro` day letters. Bars 6 wide, radius 3, gap 4.
3. **How it clears** — lavender-tinted card, one sentence `[formula]`.
4. Footnote `[static]`: debt is not a moral ledger.

**States** — fewer than 14 nights: the strip renders the nights it has, left-aligned, and the
sentence becomes `[static]` *"Still building a picture. Fourteen nights makes this honest."*


---

## 1.5 `alarm` — the smart alarm

**New.** Reached from the Smart alarm row on `tonight`, and from nowhere else — it is a decision
about tonight, so it lives inside tonight's plan rather than beside it in Settings.

Header: back → `tonight`, parent `Tonight` `[static]`. **The chevron goes to `tonight`, not to
`rest`**, and swipe-back follows it (`30-routes.md`).

1. **The wake time** — a hero row, centred, `HStack(spacing: 16)`.
   - Two 40 pt circles, 0.5 pt border `NoopPalette.rest` at 34 %, a 13 × 1.6 bar in `#C9CEE8`
     inside each (the later one adds the crossing 1.6 × 13 bar). Earlier / later, in
     **five-minute steps**.
   - Between them the time at `heroNumeral` **82** / Outfit 200 / tracking −0.045 em / line-height
     0.94 / tabular `[bound]`. This is the largest numeral in the app, deliberately: it is the one
     figure a person reads in the dark.
2. **How early it may wake you** — caption `[static]` + segmented control, **four windows**
   `[static]`. The window is how far *before* the set time the strap may fire. Not a snooze and
   not a tolerance — a window it is allowed to hunt inside for a light stage.
3. **It runs on the strap, not the phone** — lavender-tinted card, `tint(NoopPalette.rest)`,
   0.5 pt `tintBorder(rest)`. Title `cardTitle` 13.5/600; body `[static]`: Noop hands the window
   to the band before you sleep, and it buzzes your wrist even if the phone is off, flat, silenced
   or in another room.

   **This card is the reason the screen exists.** It is the one alarm on the phone that is not the
   phone's, and a user who does not know that will keep setting a second one.
4. **When it will not fire** — standard card, one row per failure `[bound]`, each with a 5 pt
   `effort`-amber dot and one sentence `[static]`. Amber here is *attention*, correctly used:
   these are the conditions under which a person oversleeps. **Every failure mode is named before
   it happens.** An alarm that silently does not fire is worse than no alarm, and the honest place
   to say so is here, not in a notification the morning after.
5. **Arm** — primary. Arming is a **separate, reversible act** from setting the time: setting
   commits nothing to the strap. The committed state is `tonight`'s in-place pattern — a green
   tick and a **Change** affordance, never a toast.

**States** — not armed: the set stands, the primary reads **Arm it**, nothing has been written to
the band. Armed: the row states the window it holds and which strap holds it `[formula]`. Strap
disconnected: the primary is unavailable at 38 % and the sub-line says the window cannot be handed
over until the band is in range `[static]`. It does **not** silently fall back to a phone alarm —
that is a different promise.

**Wiring** — `SmartAlarmView`'s firmware path, per `60-parity.md` Part 3 §A.7. The regression that
once dropped this row and left Alarms unreachable on iPhone is the measure of how much it is
missed.

---

## The serif — Act 1 owns it, and only Act 1

Instrument Serif is in the app, not just in the prototype's margins. It has exactly three roles,
all defined by this act, and the sizes are not interchangeable with the sans scale. Two screens
outside Act 1 reuse a role without adding one: `day/bsweep`'s pacing cue takes `serifNote` at 17,
and `plumbing/imported` sets one word in `serifEmphasis`.

| Where | Role | Value |
| --- | --- | --- |
| `why` headline | `NoopSpecType.serifHeadline` | 29 / Serif Regular / tracking −0.29 / line-height 1.22 / `textPrimary` |
| `tonight` stop note | `NoopSpecType.serifNote` | 16.5 / Serif Regular / line-height 1.45 / `textBody` |
| A measured phrase inside body copy | `NoopSpecType.serifEmphasis` | 16 / Serif **Italic**, inline in 14.5 sans |

Both the day-worker and night-worker variants of `why` use the headline and the inline italic; the
strings differ, the treatment does not.

**The italic runs at 16 inside 14.5 copy on purpose.** Instrument Serif's x-height is smaller than
Instrument Sans's, so setting the emphasis at the body size makes it look like a mistake rather than
an emphasis. Do not "fix" the 1.5 pt difference.

**Do not substitute the sans anywhere on this list.** The serif is the whole reason `why` reads as a
note written to the person rather than a report generated about them, and it is the one screen in
the app where that distinction is the design.
