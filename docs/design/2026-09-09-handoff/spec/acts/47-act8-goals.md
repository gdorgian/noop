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

   **One calculation, and nothing on this screen may contradict it.** The verdict, the evidence
   bars, the safety line and the commit confirmation all read the same function — it is in the
   HTML at the top of `renderVals()`:

   ```
   weekly build   = (peak ÷ now) ^ (1 ÷ building weeks) − 1
   building weeks = weeks to the date − 2 easy weeks − 1 taper week
   ```

   The tolerance is **this person's own history, not a rule of thumb**: `absorbed = 5%` is the
   steepest weekly build their last two blocks took without a poor night, and `ceiling = 10%` is
   the line above which Noop will not build a route at all. Those two numbers are the only
   thresholds; the copy names them and nothing else.

   The three verdicts differ in **one input** — the peak the finish they asked for requires, off
   the same 34 km a week and the same eleven weeks (eight of them building):

   | Ask | Peak | Build | Verdict |
   | --- | --- | --- | --- |
   | Half marathon, finish comfortably | 48 km | **4.4 %** | inside the absorbed 5 % — *the data says yes* |
   | Half marathon under two hours | 55 km | **6.2 %** | over 5 %, under 10 % — *possible, with one condition* |
   | Half marathon under 1:45 | 75 km | **10.4 %** | over the 10 % ceiling — *the data says not by then* |

   Every alternative the fix line offers is the same function re-run and quoted: 55 km across
   twelve building weeks (23 November) is **4.1 %**; 75 km across twenty-six (8 February) is
   **3.1 %**. **No figure may be written by hand into copy.**

   **The evidence bars are real ratios**, not verdict-coloured guesses: longest run ÷ the long run
   the route needs, weekly volume ÷ the peak, and the absorbed 5 % ÷ the build this asks for.
4. **Save** primary, 52 / 18.

   **An unrealistic goal is allowed. It is confirmed first.** Noop's verdict has three states and
   they behave differently on Save:

   | Verdict | Save |
   | --- | --- |
   | *The data says yes* | commits on one tap. Green in place for 2 s, then back to `goal` |
   | *Possible, with one condition* | raises a confirmation naming the build it needs |
   | *The data says not by then* | raises a confirmation naming what it would cost |

   The confirmation is a card, not a dialogue: the verdict restated `[formula]`, one `[static]`
   sentence saying Noop will still build the route it *can* build and that the difference will be on
   the journey screen every time it is opened, then **Save it anyway** / **Change the date**. Only
   *Save it anyway* commits.

   **The app does not refuse the goal.** Refusing would make the screen a gate and the person a
   supplicant; this design's position is that you may aim at anything and the app will not lie about
   it. What it will not do is *save it silently* — the button on those two verdicts already reads
   **Commit anyway**, and a button that admits it is overriding a verdict has to be answered, not
   just tapped.

---

## 8.3 `labs` — biomarkers

Header: back → **`plumbing/you`**, parent `You` `[static]`. **`labs` is a second root, not a child
of `goal`** — it is entered from `you`, its chevron reads *You*, and both the button and the swipe
leave the act (`30-routes.md`). This line said `goal` / *Goals*, which is the parent the user never
passed through.
1. Segmented filter `[bound]`: panels.
2. List card, one row per marker `[bound]` → `goal/marker`: name, value `rowFigure` tabular, unit,
   and a **band** showing the reference range with your value's dot (as in `day/vitals`).
   In-range dots get no colour treatment — **being in range is not a finding**.
3. **Add results** row → `goal/picker`. **Not straight to `review`** — the picker is the missing
   step, and `review` renders what was read off a specific image (`32-nav-addendum.md` Change 7).
   The same rule binds the two other doors into this family: **the + on `goal` and `labs` enters
   `goal/picker`** (`30-routes.md` §*The +*), and **Act 5's *A lab result to import* row on the Add
   sheet enters `goal/picker`** — it used to open `review` directly, which handed the user a
   fabricated set of read values for a photograph they had never taken.
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
4. **Enter results by hand** — row card. Sub-line `[static]`: all nine markers, no photo, every row
   optional, and **the confirm step drops its strips, because there is no page to check against.**

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
**Reached two ways, and they are not the same screen.**

| Route | Image card | Strips | Confidence chips | Rows start |
| --- | --- | --- | --- | --- |
| **Photo** — *Take a photo* or a library tile on `picker` | yes, 132 pt | yes, per row with a rect | yes | with the read value, pending |
| **By hand** — *Enter results* on `picker` | **none at all** | none | **none** | **empty, open for typing** |

The by-hand route **fabricates nothing**. No image card (not an empty one, not a placeholder), no
strips, no *Check this* chips, and no pre-filled values: the eyebrow reads *entered, not measured*,
the title says nine fields with nothing filled in for you, and each row starts collapsed at `—`
with *not filled in* beneath it.

**Nine fields — settled, and they are the nine markers `labs` keeps**, so a typed value always has
somewhere to live. In the order a printed panel runs them:

| # | Field | Unit | Reference band `labs` holds |
| --- | --- | --- | --- |
| 1 | Haemoglobin | g/L | 130–170 |
| 2 | Ferritin | µg/L | 30–400 |
| 3 | Vitamin D | nmol/L | 50–125 |
| 4 | ApoB | g/L | 0.5–1.0 |
| 5 | HbA1c | mmol/mol | 20–42 |
| 6 | hs-CRP | mg/L | 0–3 |
| 7 | TSH | mIU/L | 0.4–4.0 |
| 8 | ALT | U/L | 10–50 |
| 9 | Creatine kinase | U/L | 30–200 |

The **photo** route is unrelated to that count: it shows **whatever the sheet printed** — four rows
in the prototype's demo sheet, and the title says four because four were read. Nine is the by-hand
list; four is one photograph.

**One input open at a time.** A collapsed row offers **Type it in** / **Leave it out**; the open row
is the same input the photo route uses, with **Use this value** / **Cancel**, and its note says the
value is stored as entered rather than read. Cancel closes without deciding; *Leave it out* is the
explicit decline and both are undoable.
A row left alone is not stored. This is what `50-wiring.md` Part 1 §5 means by shipping the by-hand
path while `review`'s OCR has no owner — **the by-hand path may ship; invented OCR results may
not.**

1. The imported image `[bound]` in an inset card, radius 20, height **132** fixed — first thing on
   the screen, above the amber eyebrow. **Photo route only.** Drawn at true size with its four states, its behaviour and
   what is *not* bound to it, in `Noop Labs Review - Image Card`. Build from that panel, not from
   this line.
2. **What was read** — one card per detected marker `[bound]`, each flagged with a confidence state:
   confident (plain), uncertain (amber chip `[static]` *Check this*).

   **Three actions per row, and they stay: Confirm · Fix · Discard.** Confirm accepts the read value.
   Discard forgets the row. **Fix opens a value editor** — a real one:

   - A numeric field, pre-filled with the read value, `inputMode: decimal`, 40 pt, at Outfit 300 / 19
     so the number being corrected is the largest thing in the card. The unit sits beside it,
     unchanged: the user is correcting a value, not a unit.
   - **Use this value** commits and stores the row as *corrected*; it is inert while the field is
     empty, because an empty correction is not a correction. **Cancel** leaves the row pending, at
     the read value, with all three actions back.
   - A `[static]` line names what is being replaced: *Read as "O.78". What you type replaces it, and
     the row is stored as corrected — not as read.*
   - The displayed value, the settled-state line and the saved row all show the **corrected** number.

   **Setting a row's label to "edited" is not Fix.** The first implementation flipped a state string
   and stored the read value anyway, so the one screen whose whole job is to let someone correct a
   misread of their own blood work could not correct anything. If the field is not editable, the
   screen does not work — nothing else on it matters.
   Each row also carries **a strip of the page it was read from** — a crop of the imported image at
   that line's rect, drawn at true size with its geometry, its no-rect fallback and the copy rule in
   `Noop Labs Review - The Strip`. **[rev 3]** This is new work, not a kept prototype detail: the
   build's OCR joins Vision's observations into one string and discards every `boundingBox`, so the
   rect has to survive the extractor before a row can draw anything. Where no rect exists — CSV
   imports, rows logged before the change, a line that failed to resolve — the row shows the raw text
   chip instead, labelled *as read* rather than *from the page*. That is a normal state, not an error.
   The screen's copy may only claim a strip for rows that have one.
3. **Save**, in the pinned summary bar with the count beside it (42 / 14, amber).

   **Save with zero confirmed rows is a no-op.** Not a toast, not a bounce back to `picker`, not a
   save of nothing: the button is dead — `white 7 %` fill, `#57605C` ink, no pointer — and the line
   beside it says what would make it live (*"Confirm or fix a row — Save does nothing until then"*,
   or on the by-hand route *"Type a value and use it — Save does nothing until then"*). A dead
   button that explains itself is the honest version of a disabled one.

   **What Save does, exactly:**
   - **Confirmed rows are saved** at the sheet's date and **appear in Biomarkers** (`goal/labs`) and
     in `goal/marker`'s history for that marker. A confirmed row is indistinguishable from one typed
     by hand — both are the user's own assertion.
   - **Corrected rows are saved as corrected**, at the value the user typed, never at the read value.
     The stored row records that it was corrected; the strip it was read from is not stored.
   - **Discarded rows are forgotten** — not as a value, and not as *"you declined this"*. There is no
     rejected-candidate list.
   - **The photo and the OCR draft are deleted.** Both on Save and on leaving without saving: the
     image, the read text, every rect and every pending correction. There is no half-finished import
     to return to, and the screen's own footnote promises exactly this.

4. **Discard** — the per-row action, not a screen-level one. The screen-level exit is the chevron,
   and it drops the draft (above).
5. Footnote `[static]`: nothing is saved until you save it, discarded rows are not remembered, and
   nothing was uploaded.

---

## 8.5 `marker` — one marker

Header: back → `labs`, parent `Biomarkers`.
1. Name, value `heroNumeral` 52 tabular `[bound]`, unit at `rowFigure` 17 `textQuiet`.
2. The band `[bound]`, full width, with the reference range labelled at both ends `captionMicro`.
3. History `[bound]` — `TrendChart.swift`, re-tinted.
4. **What it is** — standard card, `body` 13.5 `[static]` per marker, plain language.
5. Footnote `[static]`: not a diagnosis, and what to do with it.
