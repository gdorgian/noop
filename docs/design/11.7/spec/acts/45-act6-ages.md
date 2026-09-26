# Act 6 — Your ages

*Screen specs. `00-RULES.md` and `20-primitives.md` are binding.*

Tags: `[static]` fixed by design · `[bound]` real data · `[formula]` derived · `[proto]` do not build.

**Your ages owns every estimate in the app.** That call was made deliberately — the Health hub does
not carry its own age figure. Five screens, home is `ages`. Green for body age, blush for identity.

---

## 6.1 `ages` — home

**Header** — home style, battery chip + day chip.

1. **The aura reading** — hero card, radius 24. The **original aura graphic** `[bound]`, green.
   Body age `heroNumeral` 52 tabular `[bound]`, "against 37 on paper" `bodySmall` 13 `textQuiet`
   `[bound]`. **The acrylic-pour treatment is `[proto]`** — behind the prototype's `ageGraphic`
   tweak, not the default, do not build.
2. **Fitness age** — row card `[bound]`, its own figure and signed delta chip.
3. **The drivers** — list card, one row per driver `[bound]` → `ages/driver`: label, its
   contribution as a signed `rowFigure` 17 tabular (green where it helps, `effort` where it costs),
   sub-line `[formula]`.
4. **How this is figured** — row card → `ages/method`.
5. **Health** — row card → `ages/health`.

**Tab bar** — all five wired. **`tabTrends` was found dead in this act** — check it first.

**States** — **first week**: the whole screen is replaced by `ages/building` (below). Do not show a
provisional number.

---

## 6.2 `building` — the honest first-week state

Header: back → `ages`, parent `Your ages` `[static]`.

Not an empty state — a **screen with content**. Hero card: `[static]` *"Still building your ages."*
plus a body paragraph explaining what is being gathered and when a figure appears `[formula]`
(nights recorded, nights needed).
Then a progress row per input `[bound]` — nights of sleep, days worn, a measured maximum — each with
a green check when satisfied.
Footnote `[static]`: a number too early is worse than no number.

---

## 6.3 `driver` — one driver

Header: back → `ages`, parent `Your ages`.
1. The driver named, its contribution `heroNumeral` 52 signed `[bound]`.
2. Its trend `[bound]` — `TrendChart.swift`, re-tinted.
3. **What would move it** — standard card, `body` 13.5 `[formula]`, plain language, no units in the
   opening sentence.
4. Footnote `[static]`.

---

## 6.4 `method` — how it is figured

Header: back → `ages`, parent `Your ages`.
Editorial screen: column gap **15** (not 12). One card per figure `[static]`, each explaining the
derivation in `body` 13.5 / 1.5, with the inputs listed as a chip row (wrapping, never scrolling).
Footnote `[static]`: these are estimates, and what that means.

---

## 6.5 `health` — the health hub

Header: back → `ages`, parent `Your ages`.
List cards of readings `[bound]`, grouped. Each row: label, value `rowFigure` tabular, a band showing
your own normal (as in `day/vitals` §2.4).
**No age figure here** — it lives in `ages`.
