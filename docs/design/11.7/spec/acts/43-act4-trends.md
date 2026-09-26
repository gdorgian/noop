# Act 4 — The bigger picture

*Screen specs. `00-RULES.md` and `20-primitives.md` are binding; a line like "list card, three rows"
carries the primitive's full anatomy.*

Tags: `[static]` fixed by design · `[bound]` real data · `[formula]` derived · `[proto]` do not build.

Aura for the chrome, per-line hues for the four lines. Four screens, home is `trends`.

---

## 4.1 `trends` — home

**Header** — home style. Battery chip + day chip.

**The window** — segmented control, `padding 4`, radius 14: **Six weeks / Six months / The year**
`[static]`. Default six months.
The window **decides the verdict**: at the shortest window the headline literally reads `[static]`
*"Too early to say."* — do not substitute a real-sounding verdict.

**The verdict** — hero card. Headline `headline` 23 / −0.46 / 1.15 `[formula]`, then one sentence
`body` 13.5 `[formula]`.

**Four lines** — four standard cards, `VStack(spacing: 12)`, each → its own screen.
Each card: label `cardTitle` 14/600, current value `rowFigure` 17 tabular `[bound]`, a signed delta
chip `[formula]`, a sparkline `[bound]` (`Sparkline.swift` exists), and **its own verdict** in one
line `bodySmall` 13 `textQuiet` `[formula]`. Four lines, four verdicts — not one shared one.
→ `trends/capacity`, `trends/rhythm`, `trends/year`, and the fourth is body age → `ages/ages`.

**Body age** — row card, green aura reading `[bound]`. **Use the original aura graphic.** An
"acrylic pour" treatment exists behind the prototype's `ageGraphic` tweak — it is `[proto]` and
**not** the default; do not build it.

**The + / log sheet** — the tab bar's + opens **Everything you logged** as a bottom sheet over this
screen (§14). Filters **All / Sleep / Heart / Training / Manual** `[static]`, live, and they
**persist across open and close**.

**Tab bar**, Trends active.

**States** — under six weeks of data: every card renders, the verdict is `[static]` *"Too early to
say."*, the sparklines show what exists, and the delta chips are replaced by an em-dash.

---

## 4.2 `capacity` — what you can take

Header: back → `trends`, parent `Trends` `[static]`.
1. The figure `heroNumeral` 52 tabular `[bound]` + signed delta chip.
2. The trend chart `[bound]` — `TrendChart.swift`, re-tinted to aura.
3. **What moved it** — list card `[bound]`, each row a contributor with a signed `rowFigure`.
4. **What it means** — standard card, one paragraph `body` 13.5 / 1.5 `[formula]`.
5. Footnote `[static]`.

---

## 4.3 `rhythm` — your rhythm

Same skeleton as `capacity`, lavender-hued (this line is about sleep timing).
The chart is a **phase plot** `[bound]`: bedtime and wake over the window, with the drift called out
in one sentence `[formula]`.

---

## 4.4 `year` — the year

Header: back → `trends`, parent `Trends`.
1. A year heat strip `[bound]` — one cell per day, aura at the day's charge, `track` where nothing.
   Cells 5 square, radius 1.5, gap 2. `StrandDesign`'s year heat strip already exists — re-tint.
2. Month labels `captionMicro` 9.5 tracking +1.14 `textDim`.
3. **The year in three numbers** `[bound]` — three row cards.
4. Footnote `[static]`.
