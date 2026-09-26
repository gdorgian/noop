# Act 8 — Goals and labs

*Screen specs. `00-RULES.md` and `20-primitives.md` are binding.*

Tags: `[static]` fixed by design · `[bound]` real data · `[formula]` derived · `[proto]` do not build.

**Six screens**, home is `goal` — and `labs` is a **second root**, not a child of it
(`30-routes.md`). Aura for chrome; green for anything recorded; amber for the lab family's own
chrome.

---

## 8.1 `goal` — the journey

**Header** — home style.

1. **The route graphic** — hero card `[bound]`: the journey as a path with **waypoints**.
   A waypoint **only ticks when something was recorded** `[static]` rule — never on a projection,
   never on a streak. Ticked: green check on `tint(greenSurface)`. Ahead: `track`, no fill.
   Current: `accent` ring, 1 pt.
2. **The goal restated** — standard card `[bound]`, with its target date and the honest distance
   `[formula]`.
3. **Waypoints** — list card, one row each `[bound]` → `goal/set`.
4. Rows: **Biomarkers** → `goal/labs`.

**States** — no goal set: hero card carries `[static]` one sentence and a primary **Set a goal** →
`goal/set`. Nothing else renders.

---

## 8.2 `set` — setting a goal

Header: back → `goal`, parent `Goals` `[static]`.
1. **What** — segmented `[bound]`.
2. **By when** — a date row `[bound]`.
3. **What it will take** — standard card, `body` 13.5 `[formula]`, and where it conflicts with the
   Charge model it says so plainly `[formula]`.
4. **Save** primary. Committed: green in place for 2 s, then back to `goal`.

---

## 8.3 `labs` — biomarkers

Header: back → `goal`, parent `Goals`.
1. Segmented filter `[bound]`: panels.
2. List card, one row per marker `[bound]` → `goal/marker`: name, value `rowFigure` tabular, unit,
   and a **band** showing the reference range with your value's dot (as in `day/vitals`).
   In-range dots get no colour treatment — **being in range is not a finding**.
3. **Add results** row → `goal/picker`. **Not straight to `review`** — the picker is the missing
   step, and `review` renders what was read off a specific image (`32-nav-addendum.md` Change 7).
4. Footnote `[static]`.

---

## 8.6 `picker` — photograph the report

**New.** The step the build skipped. Reached from **Add results** on `labs`.
Header: back → `labs`, parent `Biomarkers` `[static]`.

1. **The instruction** — title `screenTitle` 25 / Outfit **300** / tracking −0.03 / line-height
   1.24 `[static]` *Photograph the report*; then one sentence `[static]`: one page at a time, flat
   and filling the frame — and **reading happens on this phone: the photo never leaves it, and it
   is dropped when you are done.**

   **The privacy sentence is on the screen where the camera opens**, not in a settings page. This
   is a photograph of a person's blood work; the promise has to be readable at the moment they
   decide to take it.
2. **Take a photo** — primary, 54 pt, radius 18, **amber** (`#F2B45C`) with a camera glyph and a
   12.5/600 label in `#1E1405`. Amber is the lab family's chrome hue here, not attention.
3. **Or pick one you already have** — caption `[static]` + a wrapping tile row,
   `HStack(spacing: 7)`, `flexWrap`. Each tile `[bound]`: a page-shaped inset and a date stamp.
   Recent camera-roll candidates, so a report photographed earlier does not need re-taking.
4. **Enter results by hand** — row card. Sub-line `[static]`: nine fields, no photo, and **the
   confirm step drops its strips, because there is no page to check against.**

   This is the interim path `32-nav-addendum.md` specifies, promoted to a permanent row: it is
   also the honest route for a CSV-shaped entry. The action is named **Enter results**, never
   *Add results*, and `review` reached this way carries **no image card and no confidence chips**.
   A confirm screen for a photo that was never taken should not be dressed as one.
5. **Footnote**, verbatim `[static]`: *"Cancelling here adds nothing, and a photo you back out of
   is not remembered."*

**States** — no camera permission: the primary states what is needed and the corrective action is
in the row, with the library tiles and the by-hand row still live. **Nothing read** (zero
candidates off a picked photo) is `review`'s state, not this screen's: the card stays there and
says so rather than bouncing back here with a toast.

**Wiring** — `50-wiring.md` Part 1 §5 holds `review` until someone owns the OCR. This screen does
not wait on that: the pick, the library and the by-hand route are all buildable now, and the
by-hand path makes `labs` complete without any Vision work at all.

---

## 8.4 `review` — photo import review

Header: back → `labs`, parent `Biomarkers`. Reached from `goal/picker`, and **only** from there —
with no photo there is nothing for the image card to show and nothing for the *Check this* chip to
have been derived from.
1. The imported image `[bound]` in an inset card, radius 20, height **132** fixed — first thing on
   the screen, above the amber eyebrow. Drawn at true size with its four states, its behaviour and
   what is *not* bound to it, in `Noop Labs Review - Image Card`. Build from that panel, not from
   this line.
2. **What was read** — list card, one row per detected marker `[bound]`, each **editable**, each
   flagged with a confidence state: confident (plain), uncertain (amber chip `[static]` *Check this*).
   Each row also carries **a strip of the page it was read from** — a crop of the imported image at
   that line's rect, drawn at true size with its geometry, its no-rect fallback and the copy rule in
   `Noop Labs Review - The Strip`. **[rev 3]** This is new work, not a kept prototype detail: the
   build's OCR joins Vision's observations into one string and discards every `boundingBox`, so the
   rect has to survive the extractor before a row can draw anything. Where no rect exists — CSV
   imports, rows logged before the change, a line that failed to resolve — the row shows the raw text
   chip instead, labelled *as read* rather than *from the page*. That is a normal state, not an error.
   The screen's copy may only claim a strip for rows that have one.
3. **Save** primary; **Discard** secondary, sub-line stating the consequence `[static]`.
4. Footnote `[static]`: nothing is saved until you save it.

---

## 8.5 `marker` — one marker

Header: back → `labs`, parent `Biomarkers`.
1. Name, value `heroNumeral` 52 tabular `[bound]`, unit at `rowFigure` 17 `textQuiet`.
2. The band `[bound]`, full width, with the reference range labelled at both ends `captionMicro`.
3. History `[bound]` — `TrendChart.swift`, re-tinted.
4. **What it is** — standard card, `body` 13.5 `[static]` per marker, plain language.
5. Footnote `[static]`: not a diagnosis, and what to do with it.
