# Act 2 — The day

*Screen specs. Read `00-RULES.md` and `20-primitives.md` first: a line here like "list card, three
rows" carries the full anatomy from the primitive, and the primitive is binding.*

Tags: `[static]` fixed by design · `[bound]` real data · `[formula]` derived · `[proto]` do not build.

Aura blue is the hue. **Twelve screens**, home is `today`. This act carries the Charge model, so
`20-primitives.md` §11–13 is load-bearing here — and §2.2's evidence gate governs every word that
appears beside a Charge number anywhere in the app, including the widget.

---

## 2.1 `today` — home

The most specified screen in the app. Order matters; so does the absence of things.

**Header** — `padding 58 / 20 / 4`, `HStack(spacing: 14)`, `.top`.
- Left `VStack(spacing: 4)`: greeting `rowLabel` 13.5 `textSecondary` `[formula]`; headline
  `headline` 23 / Outfit 400 / −0.46 / 1.15 `[formula]`.
- Right `HStack(spacing: 9)`, `.top 4`: **strap battery chip** → `plumbing/strap`; **day chip**
  → toggles the day navigator.

**Day navigator** — when open: `padding 12 / 20 / 2`, horizontal scroll, `HStack(spacing: 6)`,
seven day cells `[bound]`. Selected cell fills `accent` at 20 %, border 42 %. Picking a past day:
- the greeting becomes the long date `[formula]`,
- a banner appears `[static]`: *"Looking back — nothing here is live."* with a **Today** escape,
- every live figure shows its recorded value or an em-dash. **Read-only.**

**The orb block** — 318 tall, centred. In z-order: charge gauge (§12), glow 268, ring 224, orb 176,
sheen. On the orb: pulse `heroNumeral` 52 in `#F6FDFF` `[bound]`, breathing word `breathWord` 12.5
tracking +1.375 `[formula]`.
**No numeric readout under the orb.** This was tried and removed — if the build has one, delete it.
The whole orb is a tap target → `day/charge`.

**The state line** — directly under the block, `padding .horizontal 20`, tappable → `day/charge`,
with a small chevron at the end so the tap is discoverable.
- Label `sectionHead` 19 / Outfit 400 / −0.38 in the level colour `[bound]` — see the evidence
  gate in §2.2. **Not derived from the number.**
- Sentence `body` 13.5 / 1.5 `textBody`, verbatim shape `[static]`:
  **"You woke with {wake} and you have {charge} left.{ body}"**
  The first sentence is arithmetic the app holds itself and **always renders**. `{body}` is bound
  and **omitted entirely** when analytics supplies nothing — the full stop lands after "left."
  `{charge}` counts down with the arrival drain. This is where the number lives on Today.

**Last night** — row card → `night/why`. One line `[bound]`, duration + delta chip.

**Svea prompt** — standard card, gradient `coachSurfaceTop → coachSurfaceBottom` (the one
exception to "no gradients" — it already exists in `NoopPalette`) → `svea/coach`.
One instruction `[bound]`, then the receipt `bodySmall` `textQuiet`.

**The day's shape** — standard card → `day/day`. A 24-hour strip `[bound]`.

**Heart · Vitals · Stress** — three row cards, `VStack(spacing: 12)`. Each: glyph, label
`cardTitle` 14/600, value `rowFigure` 17 tabular `[bound]`, chevron. Heart's value is **live**, which
is why there is no separate live-HR destination in the tab bar.

**Tab bar**, Today active (`flex 1.7`, filled `accent`, icon + label).

**States** — Loading: the orb renders, the gauge renders at `wake` with no lit ticks until data
arrives, figures pilled. Strap not worn today: gauge shows ghost ticks only, state line reads
`[static]` *"Nothing to spend yet — the strap has not been worn today."*

---

## 2.2 `charge` — where it went

Reached by tapping the orb **or** the state line. Not in the tab bar, not in a menu.

Header: back → `today`, parent `Today` `[static]`.

1. **Hero** — `HStack`, `.top`.
   Left `VStack(spacing: 2)`: caption `CHARGE LEFT` `[static]`; then `HStack(alignment: .lastTextBaseline, spacing: 5)`
   — level `heroNumeral` 52 in the level colour `[formula]`, then `of {wake}` `bodySmall` 13
   `textQuiet` `[bound]`.
   Right: the state label as a chip in the level hue `[bound]` — the evidence gate below.

### The evidence gate — what the design layer may say about a Charge number

**This governs §2.1's state line, this screen's hero chip and sentence, and `plumbing/widgets`'
Charge widget. It is the same slot in three places and it is bound in all three.**

The design owns the **slot**, its type and its **absent state**. It does not own the verdict.
There is no approved derivation from a charge number to a word, to a comparison against a personal
norm, or to advice about an evening — so the design layer computes none, and a build that invents
one has shipped a claim the app cannot stand behind.

| Slot | Type | Absent |
| --- | --- | --- |
| `chargeVerdict` | **a restatement of the level**, in words — never a judgement | the slot falls back to the level itself — `"{charge} left"`. Never blank, never a guess |
| `chargeNote` | one or two evidence-backed sentences | **omitted.** The sentence ends after the arithmetic |
| `rechargeTo` | the morning level a night in bed is modelled to reach | **the whole card in §5 is omitted** |

**The verdict is a restatement, not a judgement**, and that is a constraint rather than a
preference. The level colour is already on the screen — the hero numeral, the gauge ticks, the chip
fill — and it moves up the warm ramp as the charge falls. A worded judgement can therefore
*contradict* it: "Plenty left" set in the away-from-healthy mauve is two elements of one composition
saying opposite things, and the reader believes the colour. A restatement makes no claim, so it
cannot disagree with anything.

**A demo seed is one scenario, and every string in it must be true at the charge that scenario
produces.** The charge is *derived* (`charge = wake − spent(hour)`), so pinning a seed to the
inputs and authoring its copy for a different charge freezes a false reading in place — which is
exactly how this went wrong twice. Pin the scenario, then write the copy against what it renders.

**Omitted means omitted — not softened, not hedged, not a placeholder.** A shorter card is the
correct output for a thinner day. RULES §13's confidence ladder qualifies a number the app *has*;
this gate governs a sentence the app **does not have**, and the two are not interchangeable: a
chip cannot make an unevidenced claim honest.

**Removed 7 September, and not to be reintroduced:**

| Gone | Why it was never earnable |
| --- | --- |
| The 70 / 50 / 30 bucket verdicts | A bucket boundary is a design decision presented as a physiological one. The verdict must come from analytics or not at all. |
| "Normal for this hour" · "Lower than most days at this hour" | Both claim a **personal per-hour norm**. A norm needs a window, and the window is analytics' to set — not a constant in a token file. |
| A 14-day minimum, a ±8-point threshold | Invented in the design layer. Whatever gates a comparison belongs with whoever computes it, with a derivation behind it. |
| "Keep tonight easy" · "go to bed early" · "Nothing tonight but sleep" | Advice, from a number that contains no plan, no bedtime and no evening. |
| "Enough for the evening you had planned" | **Gone for good.** Noop reads no calendar and will not (`80-not-in-this-release.md`), so there is no input that could ever earn it back. |
| `charge + 26` as tonight's recovery | Arithmetic dressed as a projection. `{n}` is a **model output** or the card does not render. |

**Fake examples are a build configuration, not a fallback.** Canonical strings for screenshots and
the demo build exist behind **both** `#if DEBUG` **and** `--demo-seed`. If a seeded string is
reachable in a release build, that is the bug the gate exists to prevent. In the prototype the
seed is a prop (`demoSeed`, default on) precisely so a reviewer can switch it off and read the
omitted state — which is the state that ships on day one, before any baseline exists.
2. **The bar** — `NoopChargeBar`, height 12, radius 6. Track `white 6 %`, ghost fill to `wake` at
   `auraPale 16 %`, live fill to `charge` in the level colour, 500 ms ease.
3. **The sentence** — `body` 13.5 / 1.5, the same verbatim shape as Today, under the same gate.
4. **`WHERE IT WENT`** caption `[static]` + list card, one row per visible drain `[bound]`:
   label `rowLabel` 13.5, sub-line `subline` 11.5 `textQuiet`, cost as `−14` `rowFigure` 17 / Outfit 400
   tabular in the level colour. A drain appears only once `startedAt <= now` and `cost > 0`.
5. **Tonight puts it back** — lavender-tinted card. Title `cardTitle` `[static]`; body `[formula]`
   *"{bedtime duration} in bed gets you back to about {n} by morning. Sleep is the only thing that
   does it."* — `{n}` is `rechargeTo`, a **model output**, not `charge + 26`. With no forecast the
   card is **not rendered**.
6. **Footnote**, verbatim `[static]`:
   *"Charge is spent, not scored. It starts where your night left it and everything you do takes a
   piece — so a low evening is not a failure, it is the day showing up in the number."*

**States** — no drains yet: the list card is replaced by one sentence `[static]` *"Nothing has come
off it yet today."* Past day: the bar and ledger show the recorded end-of-day values; the "tonight"
card is hidden.

---

## 2.3 `day` — the day's shape

Header: back → `today`, parent `Today`.
1. A 24-hour timeline `[bound]`: activity, stress minutes, sleep window. Hour ticks
   `captionMicro` `textDim`.
2. List card, one row per logged event `[bound]`, time as `rowFigure` tabular.
3. Footnote `[static]`.

---

## 2.4 `vitals` — five vitals

Header: back → `today`, parent `Today`.

Five standard cards, `VStack(spacing: 12)`. Each card:
- Label `cardTitle` 14/600 + value `rowFigure` 17 tabular `[bound]` + delta chip `[formula]` (signed).
- **The band**: a horizontal track showing *your own normal zone* as a shaded stretch `[bound]`,
  your baseline as a **pale line inside it** `[bound]`, and today's dot on top `[bound]`.
  Band height 8, radius 4; shade = the vital's hue at 14 %; baseline line 1 wide `auraPale 50 %`;
  dot 7 circle in the vital's hue.
- **If the dot is inside the shade there is nothing to read**, and the footnote says so `[static]`.

Footnote, verbatim intent `[static]`: a dot inside your own range is not a finding.

---

## 2.5 `stress` — stressed minutes

Header: back → `today`, parent `Today`.
1. Total stressed minutes `heroNumeral` `[bound]` + a chip against your normal `[formula]`.
2. A day strip `[bound]`, amber where stressed — **amber here is attention, correctly used**.
3. List card, one row per stretch `[bound]`: time span, duration, what was happening if known.
4. Footnote `[static]`.

---

## 2.6 `heart` — the live pulse

Header: back → `today`, parent `Today`.
1. The live figure `heroNumeral` 52 tabular `[bound]`, with the `heartbeat` / `heartglow` keyframes
   on the glyph beside it (0 / 9 / 18 / 27 / 42 / 100 % — in `00-RULES` §10's spirit: this one is a
   1 s loop, and it **stops entirely under Reduce Motion**).
2. A rolling trace `[bound]` — `OverviewHRChart.swift` already does this; re-tint, do not rebuild.
3. Resting, max today, HRV as three row cards `[bound]`.
4. Footnote `[static]`.

**States** — no live connection: the figure becomes an em-dash and a sub-line `[static]` says the
strap is not connected; the trace shows the last recorded window, labelled as not live.

Also on this screen: the **spot reading** card, between the zone breakdown and the heart rows —
`SpotHrvReading`, four states, specified in `60-parity.md` Part 5 §B. A bounded minute that
navigates away is a minute nobody sits still for, so it is a card here and not a push.

---

## 2.7 `inbox` — updates

**New.** Reached from the **bell** in `today`'s header, badged with the unread count.
Header: back → `today`, parent `Today` `[static]`. Title `screenTitle` 25 `[static]` *Updates*,
with one sub-line `[formula]` counting what is waiting.

**Three row kinds, and they behave differently.** This is the whole screen — a single list of
undifferentiated notices would be a notification centre, which is the thing this is not.

| Kind | Carries | Unread dot |
| --- | --- | --- |
| **Proposal** | Accept · Change · Decline, **in the row** — 29 pt high, `controlFill` + 0.5 pt `controlBorder`, label 11.5/600 | yes |
| **Hint** | nothing to decide. No buttons | **no** |
| **Status** | a card you swiped away, with **Put it back** on it | yes |

- Grouped by age: `caption` 10 uppercase group head `[formula]` + a right-aligned group note
  `finePrint` 11 `textDim`.
- List card per group, `padding 2 / 16`. Row: a leading 5 pt dot slot (empty for a hint), then a
  `VStack(spacing: 5)` — the kind label with a right-aligned relative timestamp `captionMicro`
  10.5 tabular `textDim`, then the body `subline` 12 / 1.55 `textQuiet`.
- **A proposal resolves in place** and then replaces its buttons with one line naming **what
  accepting actually changed** `[formula]`. It does not vanish: a decision whose consequence you
  cannot see is a decision you will not trust next time.
- **The swipe-away is cosmetic, and the screen says so** `[static]` — the finding stays priced in
  `day/charge`'s ledger either way. Putting the card back changes nothing about the arithmetic.

**Footnote**, verbatim `[static]`: *"A proposal waits here until you answer it, and answering it
here is the same as answering it on the card. Nothing in this list is a notification — the bell
only fills, it never buzzes."*

**States** — empty: one centred card, `padding 26 / 18`, title `[static]` *"Nothing waiting"* and
one sentence carrying the **dedupe promise** `[static]` — nothing is repeated, and a run of the
same finding counts once. No illustration.

**Wiring** — `UpdateStore`, `UpdatesInboxView`. Deduped and capped upstream so a recompute loop
cannot spam it. The cap is not a design value and must not be re-implemented here.

---

## 2.8 `breathe` — the act's fifth push, and the flagship

**New.** Reached by the **orb** on `today` — the orb becomes its door instead of a decoration.
§11's box-breathing orb paces nothing; **this** screen is where a pacer, a buzz and a measurement
live.

Header: back → `today`, parent `Today`. **The Breathe family has its own header chevron**: an
8 × 8 up-left rotated chevron in a 34 pt circle with a 0.5 pt border and **no fill**. `bplayer`
and `bsweep` replace it with a **×**, because they are sessions and the gesture is *close*, not
*back*.

1. **The pacer hero** — 292 tall, centred, three layers on a **10 s** `auraBreathe` cycle:
   glow Ø 280 (`radial-gradient(circle, accent 20 %, accent 0 % at 66 %)`), ring Ø 214 (1 pt
   `auraPale 28 %`), body Ø 150 (the orb gradient, `shadow 0 18 52 rgba(11,111,168,.55)`).
   On it: the rate at `heroNumeral` **38** / Outfit 200 `[bound]` in `#F6FDFF` with the orb's
   text-shadow, and the unit at 10.5 / 600 / tracking +0.1 em uppercase at 72 % white.
2. **Title and line** — `sectionHead` 23 / Outfit 400 `[formula]`, one sentence `[formula]`.
3. **Start · {protocol}** — primary, 54 pt, radius 18 → `day/bplayer`.
4. **The current protocol** — row card → `day/bcatalog`, trailing **Change** `[static]` + chevron.
5. **Find my pace** — aura-tinted card → `day/bsweep`. Eyebrow `[formula]`, title `sectionHead`
   19, one line `[formula]`. **The sweep is a mode inside Breathe, not a feature beside it**
   (`60-parity.md` Part 5 §A).
6. **After a sweep** `[bound]` — list card, three rows of what the sweep changed. Absent before
   the first sweep. This is the hand-off §A calls the part to get right: what Breathe is before a
   sweep, and what changes on it afterwards.
7. **Footnote**, verbatim `[static]`: *"A pace that suits your physiology. Nothing here treats
   anything, and the strap does the counting so you can shut your eyes."*

**The never** — nothing on any of these five screens treats, diagnoses or claims a clinical
effect. That footnote is not decoration.

---

## 2.9 `bcatalog` — eighteen ways to breathe

Header: back → `breathe`, parent `Breathe`. Title `[static]` *Eighteen ways to breathe*; sub-line
`[static]`: all of them already in the catalog, **grouped by what they are for, because eighteen
in one list is a menu nobody reads**.

- One caption + list card per group `[bound]`. Row: name `rowLabel` 13 (**600 when selected**), a
  sub-line naming what it is for in plain words `[static]`, and the pattern as a right-aligned
  tabular figure.
- The selected row's weight change is the only selection treatment. No tick, no chip.
- **A group may carry a warning** `[bound]` — one sentence below its card in `effort` amber
  `[static]`. The advanced-tempo groups have one and it is not optional.
- Tapping a row picks it and goes straight on → `day/bplayer`.

**`bplayer` returns to `breathe`, not here** (`30-routes.md`). Backing out of a finished session
to the catalogue you picked it from is the wrong door: you are done, and the act's root is where
done lands.

**Wiring** — `BreathProtocol`, `BreathProtocolCatalog`. Golden-vector tested; the eighteen and
their tempos are **not** design values.

---

## 2.10 `bplayer` — the pacer

A **session**, not a screen: full height, `flex` column, **no tab bar**.

Header, `padding 56 / 18 / 0`: a **×** in a 34 pt bordered circle → `breathe`; a
`VStack(spacing: 1)` with the protocol name `rowLabel` 13/600 and *{elapsed} of {length}*
`captionMicro` 11 tabular `[bound]`; then a **buzz chip** — aura at 12 % / border 24 %, a live dot
and `[static]` *"Buzzing the cue"*.

**The buzz chip is a promise about hardware.** The strap buzzes the cue — one pulse on inhale, two
on exhale, silent holds — so the loop between cue, body and graphic *is* the feature. With no
strap connected the chip states that instead and the screen still paces visually.

1. **The pacer** — a 300 box: a Ø 296 1 pt `white 5 %` outline, then glow / ring / orb driven by
   **the protocol's own tempo** `[bound]`, not a fixed 16 s clock. On it the phase word
   `sectionHead` 27 / Outfit 300 and the phase count `rowFigure` 15 / Outfit 300 tabular at 75 %
   white.
2. **Your heart, against the pace** — caption `[static]`, then the swing figure `rowFigure` 20 /
   Outfit 300 tabular `[bound]` with *bpm swing* `[static]`. Below, a **96 pt** card, radius 20,
   `padding 10 / 12`, holding one SVG at `viewBox 0 0 340 76`, `preserveAspectRatio: none`:
   - the pace band — `fill accent 10 %`
   - the pace line — 1.2 pt `auraPale 34 %`, **dashed 3 4**
   - the heart line — 2 pt `#9FE2FB`, round caps and joins
3. **The reading**, verbatim `[static]`: *"The dashed line is the pace you are following. The
   bright one is your heart answering it — the bigger the swing, the better this pace fits you."*
   Two lines, one dashed and one solid, and one sentence saying which is which. Without it the
   graphic is decoration.
4. **End the session** — secondary, 52 pt.

**Reduce Motion** — the pacer holds at scale 1.0 and the phase word keeps advancing on the
protocol's cadence. The trace still draws: it is data, not animation.

**Wiring** — `BreathProtocolPlayer`, live BPM and rolling RMSSD from the strap.

---

## 2.11 `bsweep` — finding your pace

A **session**, and the one thing in the pack that is an **activity rather than a display**
(`60-parity.md` Part 5 §A). Header: **×** → `breathe`; title `[static]` *Finding your pace*,
sub-line the step `[formula]`.

1. **The pacer** — a 250 box, the same three layers, **paced at the candidate rate under test**
   `[bound]`. On it the rate `heroNumeral` **34** / Outfit 200 tabular and *breaths / min*
   uppercase.
2. **The cue** — one centred sentence in **Instrument Serif** at `serifNote` **17** / 1.45
   `textBody` `[formula]`. The serif is deliberate and is the only role-level use outside Act 1
   (`40-act1-night.md`): a pacing cue is spoken *to* the person, not reported *at* them.
3. **How hard your heart swung at each** — caption `[static]` + a **132 pt** bar row,
   `HStack(spacing: 8)`, `.bottom`. Per candidate `[bound]`: the figure above, the bar, the rate
   below. The winner is the only one at full strength.
4. **Stop — keep what it has** — secondary → `day/bfound`.
5. **The bargain**, centred `finePrint` 11 `[static]`: ten minutes, five paces, ninety seconds
   each, and **stopping early keeps every pace it finished**.

**Absence is a result** (RULES §12, `60-parity.md` Part 5 §C ¶5). A sweep that finds no clear peak
says so on `bfound`. It does not pick the least-bad candidate.

**Wiring** — `ResonanceEngine`. Built, tested, and until now unsurfaced (`50-wiring.md` Part 4).

---

## 2.12 `bfound` — your pace

Header: back → `breathe`, parent `Breathe`.

1. **The result**, centred: eyebrow `[static]` *Your pace* in `auraPale`; the rate at
   `heroNumeral` **76** / Outfit 200 / tracking −0.045 / line-height 0.95 tabular `[bound]` with
   its unit at `rowFigure` 14; then one sentence `[formula]` giving the in/out seconds **and how
   much harder the heart swung here than at anything else it tried**. That comparison is the
   evidence for the number and travels with it.
2. **The curve it found** — standard card, caption `[static]`, one SVG at `viewBox 0 0 320 128`:
   the response curve 1.6 pt `auraPale 30 %`; a 1 pt **dashed 3 4** drop-line at the peak; 4 pt
   dots per candidate in `#3E6B80` and a **6.5 pt** dot in `auraPale` at the peak; the rate
   labelled at the peak and at both ends, `captionMicro` 10.
3. **What it changed** — list card `[bound]`, one row per consequence, value right-aligned in
   `auraPale` tabular. The same facts `breathe` §6 shows: one set of facts in two places, not two.
4. **Breathe at {rate}** — primary → `day/bplayer`.
5. **Footnote** `[static]`: worth testing again after a few months, or if the resting pulse moves.
   **"It is a pace that suits your physiology, not a treatment for anything."**

**States** — no clear peak: the hero shows no rate, the curve renders with no peak dot, and the
sentence says the sweep found nothing that cleared the others `[static]`. The primary becomes
**Try again** → `bsweep`. It never asserts a pace it did not measure.
