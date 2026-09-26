# Act 3 — The effort

*Screen specs. `00-RULES.md` and `20-primitives.md` are binding; a line like "list card, three rows"
carries the primitive's full anatomy.*

Tags: `[static]` fixed by design · `[bound]` real data · `[formula]` derived · `[proto]` do not build.

Amber (`NoopPalette.effort`) is the hue — and this is the one act where amber is not "attention",
it is the pillar's identity. Six screens, home is `session`. Reached from `today` and from the
tab bar's + is **not** this act (that is the log sheet).

---

## 3.1 `session` — today's recommended session

**Header** — home style, `padding 58 / 20 / 4`. Battery chip + day chip on the right.
Greeting `[formula]`, headline `headline` 23 `[formula]`.

**The recommendation** — hero card, radius 24, amber tint (`tint(NoopPalette.effort)`).
- Caption `TODAY'S SESSION` `[static]`.
- The session `sectionHead` 19 / Outfit 400 / −0.38 `textPrimary` `[bound]`.
- The receipt `body` 13.5 / 1.5 `textBody` `[bound]` — plain language, **no units**. The value is
  `EffortFeasibility`; the *wording* is governed by `70-copy.md` (rule 3, no units in a receipt;
  rule 7, the receipt names what was measured, never the metric) and the sentence templates in
  `Noop - Build Document.dc.html`. There is no string constant to copy from — the old body-state
  type was deleted in `1ecb5712` and its wording is superseded.
- Two buttons, `HStack(spacing: 10)`: **Start** primary (48, radius 17, `accent`) → `effort/ready`;
  **Swap** secondary (44, radius 15) → `effort/pick`.
  Note the primary is **aura**, not amber: a primary action is always aura (RULES §9).

**What you have done this week** — standard card. Seven bars `[bound]`, amber at the day's load,
`track` where nothing. Labels `captionMicro`.

**Last session** — row card → `effort/detail`. Sport glyph (`SportIcon.swift` exists — use it),
label, date, load figure `rowFigure` tabular `[bound]`.

**Tab bar** — **Today is lit**, aura `#17A2E6` with `#04121A` ink, on every screen of this act
that shows the bar: the effort act has no tab of its own and is arrived at under Today (§10's hue
table). Hidden entirely on `live` and `intervals`. All five wired.

**States** — rest day recommended: the hero card's session is `[bound]` *"Rest day — walk if you
want, that's all"* and **Start is replaced** by a single secondary **Log something anyway**.
No strap data: the card is unavailable at 38 % with `[static]` *"A session needs a night behind it."*

---

## 3.2 `pick` — the alternatives

Header: back → `session`, parent `Today's session` `[static]`.
Title `screenTitle` 25 `[static]` *Swap it*.

List card, one row per alternative `[bound]`, `minHeight 70`: sport glyph, label `rowLabel` 13.5,
sub-line `subline` 11.5 `textQuiet` with **what it costs in charge** `[formula]` — this is the act's
version of "every switch says what it costs".
Tapping a row selects it and returns to `session` (it does not push).

Footnote `[static]`.

---

## 3.3 `ready` — the pre-flight

Header: back → `session`, parent `Today's session`.

1. **The session restated** — hero card, amber tint, the target `heroNumeral` `[bound]` (duration or
   load), with its unit.
2. **Strap check** — list card, three rows `[bound]`: connection, battery, sensors ready. Each row's
   trailing slot is a state chip: green `check` when ready, amber when not.
   **Unavailable state matters here**: a not-ready row is amber with a one-line reason, and the
   Start button below goes secondary and says **Start anyway**.
3. **Start** — primary button, full width, 48, radius 17 → `effort/live`.
4. Footnote `[static]`.

---

## 3.4 `live` — the live face

**No header, no tab bar.** Full-bleed, `NoopPalette.canvas`. Swipe-back is **disabled** here — a
session must be ended deliberately.

1. Elapsed `heroNumeral` 52 tabular `[bound]`, centred, `padding .top 72`.
2. Live heart rate `sectionHead` 19 tabular `[bound]` with the heart glyph; the `heartbeat` keyframe
   on the glyph, **stopped under Reduce Motion**.
3. Zone strip `[bound]` — five segments, the live zone filled in the zone's colour
   (`custom zones` from `plumbing/zones` if set, defaults otherwise).
4. Load so far `rowFigure` `[bound]`, and **charge spent so far** `[formula]` in the level colour —
   the one place a session shows its cost live.
5. Two buttons, pinned to the bottom with `padding .bottom 26`: **Intervals** secondary →
   `effort/intervals`; **End** destructive-style (44, radius 15, `hot` label) → `effort/detail`.
   End requires a **confirm**: a sheet, two buttons, `[static]` copy. (Confirmations are specified
   next to the behaviour that needs one — there is no app-wide count, and the count this line used
   to carry was wrong the moment a second screen earned one.)

**States** — connection lost mid-session: a banner in amber `[static]` *"Lost the strap — still
timing, no heart rate."* The timer never stops on a connection loss.

---

## 3.5 `intervals` — the interval runner

**No header chevron, and no entry in the back map** (`30-routes.md`) — the same rule as `live`, for
the same reason: you are in the effort, and the ways out are pause and end. Earlier revisions of
this line said *back → `live`* and *it returns to live*; both were wrong, and a back chevron here is
an invitation to lose a session by accident. Tab bar hidden.

1. The current interval `heroNumeral` 52 `[bound]` counting **down**, tabular — the count is why
   tabular matters most here.
2. Work / rest state as a chip in aura (work) or lavender (rest) `[formula]`.
3. The set laid out as a list card `[bound]`: one row per interval, the done ones with a green
   `check`, the current one with the aura marker, the rest at 38 %.
4. **Skip** secondary and **End set** destructive.

---

## 3.6 `detail` — the after-report

Header: back → `session`, parent `Today's session`.

1. Hero: the sport, the date `[bound]`, duration `heroNumeral` 52 tabular.
2. **What it cost** — standard card, the charge cost `rowFigure` in the level colour `[formula]`,
   with one sentence `[formula]` about what it leaves for the evening. This card is the link back
   to the Charge model and should not be dropped.
3. Zone breakdown `[bound]` — five bars, zone colours, `captionMicro` labels.
4. Heart rate trace `[bound]` — `OverviewHRChart.swift`, re-tinted.
5. Splits or intervals, if any `[bound]` — list card.
6. Footnote `[static]`.

---

## 3.7 `across` — every session, in aggregate **[new, 31 August]**

Closes `60-parity.md` Part 3 §A.5. Header: back → `session`, parent `Today's session`.
Reached from a row on `session` (below the last-session row) and from `plumbing/history`.
The tab bar stays up, as on `session`, `pick` and `detail`.

1. **The range control** — 7D / 30D / 90D / 1Y / All `[bound]`. **Act 9's control, in Act 3's hue,
   in Act 9's position**: under the header, above the first card. A window the record cannot fill is
   **present, dimmed and not tappable** (§Act 9 convention) — with 258 days on record, 1Y is dim.
   Under it: the days behind the window and, when the window holds fewer than three sessions, a line
   saying so instead of an average `[formula]`.
2. **Four tiles** `[bound]`, 2 × 2, `detail`'s tile: sessions, moving time (stopped time removed),
   load, distance. **No calorie total** — Noop keeps none, and the footnote says so. Distance obeys
   the units preference.
3. **What it cost** — `detail`'s lavender cost card `[formula]`: charge spent on training across the
   window, minutes added to the nights after, and **the days you did not train** (`n of N`), counted
   on purpose because a rest day is a training decision.
4. **Where the time went** — list card, one row per sport `[bound]`, sorted by time: sport icon,
   name, total time, a share bar against the largest, and sessions / minutes each / load a time.
   Intervals take amber, every other sport `accent`. The card's trailing note names the top sport.
5. **Session by session** — list card, the newest eight of the window `[bound]`, each row: date
   (weekday inside a week, `d Mon` beyond it), sport icon, name, duration · load · distance, and a
   **source chip** — `strap` in accent tint, `imported` or `Health` in neutral, because the strap only
   knows the days since it was paired. Row → `detail`. Footer row → `plumbing/history` for all of them.
6. Footnote `[static]`: you against you — no age-group ranking, no weekly grade, no calorie total.

**States** — **thin**: fewer than three sessions in the window is stated, not averaged.
**Unfillable range**: dimmed and unpickable, never an empty chart.
