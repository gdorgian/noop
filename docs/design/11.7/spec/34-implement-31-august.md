# The 31 August change set — how to build it

*One page per change, in build order. Everything here is additive to what `spec/` already
describes; where a number appears twice, `00-RULES.md` and `10-tokens.md` win.*

Four things landed on 31 August:

| # | Change | Kind | Files it touches in the prototype |
| --- | --- | --- | --- |
| 1 | Three dead or trapping nav paths | fix | Acts 2, 3, 6, 7, 8 + the app shell |
| 2 | `today`'s session card, third state | new state | Act 2 + the app shell |
| 3 | `effort/across` — every session, in aggregate | **new screen** | Act 3 (+ a row on Act 5's `history`) |
| 4 | The confidence chip, applied | **new primitive** | Acts 1, 2, 6 (the pattern, then everywhere) |

Read `20-primitives.md` §15 and `00-RULES.md` §13 before change 4. Read
`acts/42-act3-effort.md` §3.7 before change 3.

---

# 1 · The three dead paths

All three are the same class of bug: a control that exists, looks live, and goes nowhere. None of
them is visible until someone taps it, which is why `30-routes.md` now names the **+** as a tab and
`32-nav-addendum.md` carries the tap-through as rev 4.

## 1a · The + was inert in Acts 6, 7 and 8

**Symptom.** The centre **+** in the tab bar had no action at all on `ages`, `coach` and `goal` —
the three acts with no sheet of their own. Handover checklist item 3 failed from three of nine acts.

**Rule.** The + is a tab. It is never decoration, and an act that has no log sheet of its own does
**not** get a silent one.

**Build.** The + opens the log sheet over the current screen wherever that sheet exists (Act 2's
`today`, Act 1's journal, Act 4's logged sheet, Act 5's add sheet). From an act without one it is a
**tab-level arrival on Today with the sheet already up** — not a push, and not a bare navigation
that leaves the user to find the + again.

```
+  →  tab Today, route day/today, present the log sheet on arrival
```

In SwiftUI: the tab-level route carries an `openSheet: .log` intent; `TodayView` presents on
`.onAppear` of that intent and clears it, so a second + re-presents. In the prototype this is a
`sheet` + `sheetSeq` pair on the shell — the sequence number is what makes the second tap work, and
a build that keys off the value alone will fire once and never again.

**Motion.** The tab crossfade of `Noop Motion Pass` (`swap`, 200 ms), then the sheet's own
presentation — in that order, never simultaneously.

## 1b · Act 3 trapped you

**Symptom.** On `effort/session` the lit Today tab called the act's own root, so from Act 3 there
was **no tab-bar route back to `day/today`**. Only the swipe got you out.

**Rule.** *A lit tab still has to move.* Act 3 is a tab-level arrival inside the Today tab
(`32-nav-addendum.md` Change 2+3), so the lit tab has two jobs and they are ordered:

```
from effort/pick, effort/detail, effort/across   →  pop to effort/session      (the act's root)
from effort/session                              →  leave for day/today        (the tab's root)
```

This is the iOS pop-to-root convention with one extra step, because the tab has two roots. The same
shape applies to any act reached inside another act's tab: Act 7's lit Svea slot already does it,
Act 6's parent slots already do it.

## 1c · The Today tab from Act 9

Already correct — `tabTrends` leaves for `picture/trends` rather than re-rooting inside Act 9. Left
here as the reference implementation of 1b.

---

# 2 · `today`'s session card, third state

**Symptom.** The card had two states (a session to do / a rest day) where
`32-nav-addendum.md` asks for three. The finished session was the one part of Change 2+3's landing
never built, and `today` is the screen the app opens on.

**The three states.**

| State | Kicker | Title | Line | Tap |
| --- | --- | --- | --- | --- |
| Planned | `Today's session` | the session's name | what it is and what it costs | `effort/session` |
| Rest | `Today's session` | `Rest` | nothing today, and why that is a decision | `effort/session` |
| **Done** | `Today's session` | **the workout's name** | **its cost in the body-state currency** | **`effort/detail`** |

**The line, precisely.** `42 min · 18 of today's charge, and 12 minutes on tonight's need.` Both
figures come from the session record, not from a fresh computation: the charge cost is what
`day/charge`'s ledger already priced this session at (`ActivityCostEngine` as a prior — `50-wiring.md`
Trap 3), and the sleep-need minutes are what `effort/detail` already shows. **The card and `detail`
must never disagree**; if they can, read both off one record.

**One record, read three times.** The card, `effort/detail`'s header, and the last-session row on
`session` all read the **same** finished record — name, minutes, distance, and *when*. The first
build of this got caught by exactly the failure the rule names: `detail` kept a static header
("Yesterday, 17:04 · 42 min · 14.8 km") while the card described a session finished moments ago, so
a session you had just ended was labelled *yesterday* and carried a distance the live screen never
showed. The fix is not to correct the two strings; it is to **delete the second source**. In the
app: the session store holds the record and every one of the three reads it. A screen that computes
its own copy will drift again the next time someone changes the pace model.

**Where the state lives.** Above the screen. In the prototype the shell owns the running session
(so leaving `live` cannot destroy it) and now also remembers the one that **ended**; the card reads
it as a prop. In the app that is the session store, not `TodayView` state — the card has to survive a
tab switch, a backgrounding and a relaunch on the same day, and it resets at the day boundary the
rest of `today` uses.

**Acceptance.** Checklist items 8 and 9: end a session → `detail` full-screen → back → `today` shows
the finished card → tap it → `detail` again.

---

# 3 · `effort/across` — every session, in aggregate

Full screen spec: **`acts/42-act3-effort.md` §3.7**. Bindings: **`50-wiring.md`**, three new rows.
Routes: **`30-routes.md`** (back map `across → session`, four cross-act rows).
Closes **`60-parity.md` Part 3 §A.5**, which was the last [gone] item anyone could reach by tapping.

**What it is.** The across-time view Act 3 never had. `effort/detail` answers "what did that session
cost me"; `plumbing/history` is a flat log; neither answers **"how much did I ride this month"**.

**Reuse, do not re-invent.** It is Act 9's range control in Act 3's hue, in Act 9's position — under
the header, above the first card. Build the control once for both acts.

```
7D   30D   90D   1Y   All          ← 1Y is dimmed and not tappable at 258 days of record
```

**The range rule is the whole screen's honesty.** A window the record cannot fill is **present,
dimmed and inert** — never an empty chart, never a padded average. Under the control: the days
behind the window; and when the window holds fewer than three sessions, that sentence replaces the
averages rather than sitting beside them.

**Sections, in order.** Four tiles (sessions · moving time · load · distance) → the cost card → per
sport → session by session → the footnote.

**Two deliberate departures from `WorkoutsView`.** Both are product positions, not omissions:

1. **No calorie total.** Noop keeps none (`you/position`), and the footnote says so out loud.
2. **The days you did *not* train are counted**, in the cost card, as `n of N`. A rest day is a
   training decision — the same position `session`'s *Rather not today?* card takes.

**The cost card is the Noop half of this screen.** `WorkoutsView` sums what you did; `across` also
sums **what it cost** — charge spent across the window, minutes added to the nights after. Priced
the way the day prices it, from the same prior. If only half of this screen can ship, ship this card
with the tiles and let the per-sport breakdown wait.

**The source chip per row** is the importer that wrote the row, not a brand badge: `strap` in accent
tint, `imported` / `Health` in neutral. The strap only knows the days since it was paired — on a real
account most of the record arrived through the import hub, and a row that cannot say where it came
from is a row a user cannot trust.

**Data note for the prototype.** Every figure is summed from one deterministic 258-day record, the
same span Act 9 works from — so the range control is real. In the app the query is `WorkoutsView`'s
own; do not re-derive load per sport, `StrainScorer` already has it.

---

# 4 · The confidence chip, applied

**Read first:** `20-primitives.md` §15 (the component), `00-RULES.md` §13 (the rule),
`10-tokens.md` §The confidence ramp (the values), and `Noop Confidence - D Hue Ramp.dc.html` for it
at true size. Decision and argument: `60-parity.md` Part 5 §C ¶1.

**Why it is a rule and not a nicety.** `ScoreConfidence` is computed for all eight latent engines and
was surfaced nowhere, against a design that shows point values almost everywhere. A modelled figure
shown flat is the one thing in this pack that is actively dishonest rather than merely thin.

**Build order.**

1. **The component, once.** Two rungs, hue-parameterised, dot-only fallback for small cards. Do not
   let three screens each grow their own.
2. **The rung, from `ScoreConfidence`.** `calibrating` / `building` / `solid` — and `solid` renders
   nothing at all.
3. **The withholding.** While calibrating, the figure is replaced by the count. Where an act already
   has a pre-baseline screen (`ages/building`), that screen keeps the job and the chip is all `ages`
   carries.
4. **Then the three placements below**, which are the pattern for the remaining five engines.

| Screen | Hue | What it qualifies | Engine | Calibrating label |
| --- | --- | --- | --- | --- |
| `night/rest` | `rest` lavender | your own sleep need, learned over ninety nights | `SleepNeed` baseline | `21 of 90 nights` |
| `day/charge` | `accent` aura | *why you woke with that number* | `RecoveryScorer.chargeDrivers` | `2 of 4 days` |
| `ages/ages` | green | body age | `BioAge.score(...)` evidence completeness | `6 of 28 instruments` |

**The label names the reason, never the rung.** "3 of 4 nights", not "Calibrating". The ramp carries
the rung; the count is the only part a person can act on.

**Amber is not available to it.** `effort` amber means *needs attention* and `hot` means *critical*.
The illness signal (`day/charge`, Part 6 item 5) and a calibrating driver list land on the **same
screen** — one colour cannot mean both "act on this" and "ignore this for now".

**Tappable, to the explainer.** `ages/method` is the only one that exists today. The other seven
engines need the same screen, which is `60-parity.md` Part 3 §B's *How scoring works* row: build the
chip's tap target now, point it at `method` where it applies, and leave it inert rather than
chevroned elsewhere.

---

# Acceptance — walk this on a device

Checklist 1–13 in `32-nav-addendum.md` still stands. These are the new ones:

1. **+** from `ages`, `coach` and `goal` → Today, log sheet up. Dismiss, tap **+** again → up again.
2. `effort/session` → lit Today tab → `day/today`. Then `today` → session card → `session` →
   `pick` → lit Today tab → `session` (one pop), then again → `day/today`.
3. End a session → `today`'s card names the workout and its cost → tap → `detail`.
4. `session` → *Every session, in aggregate* → each of 7D / 30D / 90D / All changes every figure on
   the screen. **1Y does not respond.** 7D on a quiet week says so instead of averaging.
5. `across` → any session row → `detail`. Footer row → `history`. `history` → the aggregate row →
   back to `across`.
6. Set confidence to `building` then `calibrating` on `rest`, `charge` and `ages`: chip in the
   screen's own hue both times, never amber, and nothing at all on `solid`.
