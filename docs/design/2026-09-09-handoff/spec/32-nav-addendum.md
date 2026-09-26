# Navigation addendum — the ways in

*Rev 3. Rev 1 audited the spec; the implementer audited the running app and sent back a
screen-by-screen reply. Most of the differences are **drift, not error** — screens that gained doors
during implementation, and doors the spec assumed that were never built. This revision folds his
findings in and re-costs the work. Changes marked **[rev 2]** moved; **[rev 3]** marks what has changed since, now that six of the nine are built.*

*Apply after the build in progress. Still a patch, not a rewrite: no change here touches a layout
that already exists.*

## Status · rev 3, 29 August

**Six of the nine changes are done. Nothing in this addendum is blocked.**

| | Change | State |
| --- | --- | --- |
| 1 | Two doors into the effort | **built** — Act 3 is no longer dark |
| 2+3 | Session ownership, the live bar, the landing | **built** — the state move landed first, as scoped. Verified: the session survives leaving `live` and switching tabs with the clock unbroken; the bar reads Paused; on end it disappears and `detail` opens full-screen, its back reading `today` for that arrival only |
| 4 | A logged session opens its own record | **built** — sessions carry an identity. One fixture session deliberately has none, so the pre-identity case stays visible with no chevron |
| 5 | Health hub | **built** — the row carries a heart, so it aligns with *How this is figured* directly beneath it |
| 6 | `svea/memory` | not built, correctly — read-only finding |
| 7 | The lab photo pick | **three pieces, re-costed [rev 3]** — the strips the design assumes were never built. Rects out of Vision, the row's strip, then the card. Panels sent 29–30 August; not a blocker, and it waits on the OCR being owned |
| 8.1 | Under seven nights | **built** — `ages` renders `building` in its own place |
| 8.2 | First run | **closed** — the shipped four-step wizard is blessed; the spec was behind the build. See Change 8 |
| 9 | Routes the spec omitted | spec-side only — nothing to implement |

**Three screens are dark, one act entirely.** The worst is unchanged and confirmed against the
build: because every other screen in Act 3 hangs off `effort/session`, and nothing in the app
navigates to it, the whole act is unreachable. Every tab button calls `select(tab:)`, which resets to
`today`, `trends`, `rest` or `you`; the **+** only pushes `pick` when you are *already inside* Act 3,
so it can never be the way in. Six screens, no door.

## The audit

| Screen | Route in, as built | Verdict |
| --- | --- | --- |
| `effort/session` | none | **dark** — and Act 3 hangs off it, so all six screens are unreachable |
| `effort/detail` | none | **dark** — no route on ending a session, none from `history` |
| `ages/health` | only named by the tab-tint switch | **dark** — nothing routes to it |
| `effort/live`, `effort/intervals` | Start on `ready` | reachable, and leaving does not strand the session — it **ends** it → Change 2 |
| `history` rows | plain rows, no chevron, no tap | inert, and they carry no session identity → Change 4 |
| `svea/memory` | **two** doors: a Memory button in the `coach` header, and Settings → Svea → Memory | **[rev 2]** already reachable — do not build → Change 6 |
| `labs/review` | an *Add results* button on `labs`, straight to the confirm list | **[rev 2]** reachable, but the door skips the photo pick → Change 7 |
| `ages/building`, `plumbing/onboard` | not referenced anywhere in the app | **[rev 2]** not "correctly unreachable" — never wired at all → Change 8 |
| `plumbing/zones`, `plumbing/devices` | built | correct — missing from §30's table only → Change 9 |

## How to read this

**Change 1 is the only launch blocker.** Changes 2+3 are one job, not two. Changes 6 and 9 are
read-only: nobody should build them.

| | Change | Touches | Size |
| --- | --- | --- | --- |
| 1 | The effort gets two doors | `today`, log sheet, `detail` | half a day |
| 2+3 | **[rev 2]** Session ownership, the live bar, and where a finished session lands | the shell, `live`, `detail`, `today` | **one job — the state move is most of it** |
| 4 | **[rev 2]** A logged session opens its own record | `history` rows **and the history record** | a data change, not an hour |
| 5 | Health hub | one row on `ages` | 20 min |
| 6 | **[rev 2]** Svea's memory | nothing — already has two doors | — |
| 7 | **[rev 2]** The lab photo pick, which the existing door skips | `labs` add action | half a day |
| 8 | **[rev 2]** Two screens that were never wired | `ages`, first run | needs a decision first |
| 9 | Routes the spec omitted | nothing — spec-side only | — |

# Change 1 · The effort gets two doors

**Not a tab.** The tab bar stays at five. The effort is one decision a day, not a place to browse,
and a sixth tab would say otherwise.

Two doors instead, each in the place a person is already standing when the question comes up.

## Door one — the session card on `today`

`today` already answers *can I train*. The recommendation card is the door to acting on it.

**Placement** `[static]` — directly below the day's shape card, above the Heart · Vitals · Stress
tiles. Full width, same 16 pt card gutter as its neighbours.

**Content** — the same recommendation `effort/session` opens with, cut to three lines:

| Slot | Source | Example |
| --- | --- | --- |
| Eyebrow | `[static]` | Today's session |
| Title | `[bound]` the recommended workout's name | Easy 40 min |
| Line | `[bound]` its one-line note | Zone 2. What today can take without borrowing from tomorrow. |
| Right | `[static]` chevron | › |

**Tap** anywhere on the card → `effort/session`.

**When there is no session to recommend** — a rest day, or the body-state read is low enough that
Act 3 recommends nothing — the card does not disappear. It changes to:

- Eyebrow: Today's session
- Title `[bound]`: Rest
- Line `[static]`: Nothing today. Tomorrow is the earliest this pays off.
- Tap → `effort/session` still. The screen carries the reasoning; the card must not become the
  only place the user can read it.

An empty slot where a card was yesterday reads as a bug. The card is always present.

## Door two — the log sheet

The **+** keeps logging. It gains one row at the top, above the log grid, separated by a rule:

- **Start a session** `[static]`, with the same chevron as a push row.
- Tap → dismiss the sheet, then → `effort/session`.

This is the global shortcut: reachable from all five tabs without going home first. Note for
implementation: this is a *tab-level* arrival, not a push onto the current tab — the same reset
`select(tab:)` performs, with `session` as the destination.

## What does not change

- The **+** is still **the add action**, not a session button — and it is **contextual**: the act's
  own sheet in Acts 1, 2, 4 and 5; `effort/pick`, `plumbing/record`, `goal/picker` and
  `plumbing/history` in Acts 3, 6, 8 and 9; and **focus on the Ask field** in Act 7. The nine rows
  are in `30-routes.md` §*The +*. It was written here as "opens the log sheet" for every act, which
  is true of Act 2 only.
- No long-press. Nothing in Noop is long-press-only. **The orb is two plain taps, not a press:**
  the Ø 176 sphere opens `day/breathe`, the surround opens `day/charge` (§30, cross-act routes).
  A long press on the orb was specified in `NoopSpecPrimitives.swift` and exists in no screen.
- `effort/session` keeps its existing tab bar, Swap and Start. §30's Act 3 back map is unchanged.

## Routes to add to §30

| From | Tap | To |
| --- | --- | --- |
| `today` | today's session card | `effort/session` |
| log sheet | Start a session | `effort/session` |

`effort/session` has no back map entry, because it is a tab-level arrival, not a push. Swipe-back
on it does nothing — same rule as any home screen (§30, *Swipe back*, step 3).

# Change 2+3 · Session ownership, the live bar, and the landing **[rev 2]**

Rev 1 said a user who leaves `live` "loses the session with no way back to it". The build is worse:
**the session clock is state owned by the Act 3 screen, and the shell destroys a screen when you
navigate away.** Leaving `live` does not strand a running session. It ends it. There is nothing
running to go back to.

That changes what this change *is*, and the design argument with it.

## The bar is load-bearing, not a convenience

A live bar you can lose is a nicety. A live bar that is the only reason a running session survives an
accidental tab tap is infrastructure — and it only works if **the session is owned above the screen**,
in the shell, not by `live`. So the order of work is:

1. **Move the session out of the screen.** One owner above the tab bar holds the clock, the workout,
   the pause state and the samples. `live` and `intervals` become views onto it. This is the change;
   the bar is what it makes possible.
2. **Then the bar**, below.
3. **Then the landing** (old Change 3), because it reads from the same owner: the session ends, the
   owner emits a finished record, the bar goes, `detail` opens on it.

Costed as one piece of work. Rev 1's "half a day" was the bar alone, which was the easy half.

**Do not ship 2 without 1.** A bar that returns you to a screen whose state has already been thrown
away is a worse lie than no bar.

## The bar

While a session is running or paused, a bar sits **directly above the tab bar** on every screen.

| Property | Value |
| --- | --- |
| Height | `[static]` 46 pt |
| Position | pinned above the tab bar, 6 pt gap; the bottom inset grows by 52 pt while it is up |
| Left | `[bound]` workout name |
| Centre-left | `[formula]` elapsed time, `mm:ss`, tabular figures, ticking |
| Right | `[bound]` live heart rate + `bpm` |
| Tap | → `effort/live`, or `effort/intervals` if the running workout is an interval session |

**Paused** — the elapsed time stops and the bar reads `Paused` where the heart rate was. Same tap.

**It is not dismissible.** No close button. It leaves when the session ends. A running session the
app has quietly forgotten is worse than a bar that will not go away.

**Scroll interaction** — the bar does not hide on scroll. Content ends above it.

Drawn as `Noop Nav Patch - Visual`, panel B.

## The landing

**On end, push `effort/detail` full-screen.** Not a summary card, not a return to `today`. The
session just cost the user something and this is the one moment they will read about it.

- The live bar disappears at the same moment.
- `detail`'s back map entry becomes `detail → today` **for this arrival only** (the user did not come
  from `session`, so sending them there is a lie). From every other arrival, §30's `detail → session`
  stands.
- `today`'s session card now reads the finished session: eyebrow **Today's session**, title `[bound]`
  the workout's name, line `[formula]` its cost in the body-state currency, tap → `effort/detail`.

Drawn as `Noop Nav Patch - Visual`, panel C.

## Route to add to §30

| From | Tap | To |
| --- | --- | --- |
| any screen, session running | the live bar | `effort/live` or `effort/intervals` |

# Change 4 · A logged session opens its own record **[rev 2]**

`history` — **Everything you logged** — lists 142 entries and none of them open. Confirmed inert: the
rows carry no chevron and no tap.

**But there is no key to route on.** A history entry currently carries name, detail, value, kind and
symbol, and nothing that says *which* session it was; `effort/detail` renders from a five-case
workout enum. So this is not a row change:

1. A logged session has to start carrying an **identity**, written at the moment it is logged.
2. `effort/detail` has to render from that identity rather than from the enum.
3. Only then does the row become a push.

Historic rows written before the identity exists will not open, and should keep no chevron — which is
consistent with the rule below rather than an exception to it.

| From | Tap | To |
| --- | --- | --- |
| `history` | a session row *with an identity* | `effort/detail` |
| `history` | a sleep row | `night/why` |

Non-session rows (coffees, shifts, manual notes) stay inert. They have nothing to open, and a row
that does nothing is honest as long as it carries no chevron. **Only rows that navigate get a
chevron.**

Back map: from this arrival, `detail → history`.

# Change 5 · Health hub

Confirmed dark: only the tab-tint switch names `health`, and nothing routes to it.

Add one row to `ages`, below the driver rows, above *How this is figured*:

- Title `[static]`: Health hub
- Sub `[static]`: your record, your markers, and what they add up to
- Tap → `ages/health`

# Change 6 · Svea's memory — **withdrawn [rev 2]**

**Already reachable, twice.** The build has a *Memory* button in the `coach` header and a *Memory*
row under Settings → Svea, both unconditional, and `coach` is reachable from the Svea card on
`today`. Rev 1 called this dark because the spec pack does not record either door — the audit read
the spec, and the doors were added during implementation.

**Do not build a third row.** Spec-side fix only: §30 gains the two routes that exist.

| From | Tap | To |
| --- | --- | --- |
| `coach` | Memory, in the header | `svea/memory` |
| `settings` → Svea | Memory | `svea/memory` |

# Change 7 · The lab photo pick, which the existing door skips **[rev 2]**

Retitled, because Rev 1's title would get this built twice. `labs/review` **is** reachable — an *Add
results* button on `labs` opens it today. The door is just not the one specified: the build jumps
straight to the confirm list, **skipping the photo pick entirely**, so `review` renders a list of
markers that were never read off anything.

The work is the missing step, not a new route:

| From | Tap | To |
| --- | --- | --- |
| `labs` | Add results | the picker: camera or photo library |
| the picker | a photo picked | `labs/review`, rendering what was read off *that* image |

`review`'s top card is the imported image `[bound]` (§47), which is the tell that the pick is not
optional: with no photo there is nothing for the card to show and nothing for the per-marker *Check
this* chip to have been derived from.

**[rev 3]** That card is drawn at true size — placement, metrics, four states, and the five
behaviours around retake and full-screen — in **`Noop Labs Review - Image Card`**. Two things in it
are not in §47 and will be hit in the build: the **nothing-read** state (zero candidates: the card
stays and says so, rather than bouncing back to `labs` with a toast) and **tap to full-screen** with
pinch-zoom, which is what someone does when they doubt a number.

## Correction — the strips do not exist **[rev 3]**

Rev 3 first said the per-row page strips were built and would be kept. **That was wrong, and it is
my error.** The prototype has them; the app does not. `NoopOCRCandidate` carries name, value, unit,
raw text and confidence and **no source rect**, and `LabReportImageTextExtractor` joins Vision's
observations into a single string, discarding every `boundingBox` before anything downstream could
keep one. So Change 7 is **three pieces**, in this order:

| | Piece | Cost | Alone |
| --- | --- | --- | --- |
| 1 | Vision observations come back **with their rects**, converted to image space; the parse becomes per-line instead of a regex over a blob | the real cost of this change | invisible, but everything else depends on it |
| 2 | The candidate keeps its rect; the row **cuts and draws the strip** | one optional field, plus the drawing | the screen becomes honest and its copy becomes true — the piece that matters |
| 3 | The image card | cheapest of the three | decoration, which is exactly what I wrongly said it was not |

The strip is drawn at true size — geometry, the right-anchored crop, the no-rect fallback, and the
five rules — in **`Noop Labs Review - The Strip`**. If only one of card and strips can ship, **ship
the strips**: the card orients, the strip is what a person checks a number against.

**One fix that is not blocked on any of it.** The screen today says *“Each row shows the strip of the
page it came from.”* That is false, on the one screen where someone is deciding whether to trust a
number about their own blood. It goes in the current build whatever happens to Change 7 — replaced,
on the interim path, by *“Check each number against your report, fix anything misread, and discard
what you would rather not keep.”* Once strips exist for some rows and not others, the line may only
claim a strip where there is one.

On cancel, from either step, return to `labs` with nothing added.

**Interim, if the OCR is not ready** (`50-wiring.md` holds `review` until someone owns it): keep the
existing straight-to-list door, but title the action **Enter results** rather than *Add results*, and
drop `review`'s image card and confidence chips for that path. A confirm screen for a photo that was
never taken should not be dressed as one.

# Change 8 · Two screens that were never wired **[rev 2]**

Rev 1 filed these as "correctly unreachable — do not add routes". The instruction was right; the
premise was wrong. They are not state-driven arrivals that happen not to be pushed — **they are not
referenced anywhere in the app at all**, and the behaviour behind them is missing:

| Screen | What Rev 1 assumed | What the build does |
| --- | --- | --- |
| `ages/building` | shown instead of `ages` under 7 nights | `ages` never shows the under-seven variant. The screen is unused. |
| `plumbing/onboard` | first run | replaced during implementation by a different screen |
| `plumbing/pair` | first run, and `devices` → Add a strap | correct as specified |

So there is still **no route to add** — but there is a decision to make, and it is not a navigation
one:

1. **`ages/building`** — does the under-seven-nights state ship? If yes, this is a condition in
   `ages`, not a route: `ages` renders `building` in its own place. If no, delete the screen from the
   spec so the next audit does not flag it a third time. My recommendation is that it ships: it is the
   one screen that makes the first week honest, and Part 5 §C ¶2 of the parity audit argues the same
   case for every engine that starts silent.
2. **`plumbing/onboard`** — **[rev 3] blessed. The build is right and the spec was behind it.**

   The shipped four-step wizard *is* 5.13's card stack — one card per step, each with a primary
   button — and it is better than what was specified, on one point that matters: 5.13 never said what
   the steps *are*. The build's do the job in the right order.

   | Step | What it does | Verdict |
   | --- | --- | --- |
   | 1 · *What Noop does* | three quiet promises | keep |
   | 2 · *When do you usually sleep?* | at night mostly / rotating shifts / permanent nights, framed as the only question that changes the whole app | **keep, and see the condition below** |
   | 3 · *Connect your strap* | BLE, no server in the middle | this **is** `plumbing/pair`, so 5.13's *final step's button → pair* is satisfied a step early — correct, because step 4 can then state whether pairing actually worked |
   | 4 · *Your thread starts here.* | the closer | keep |

   Two conditions, neither a redraw:

   - **Step 2's answer has to be read, not just recorded.** *The only question that changes the whole
     app* is a promise the build has to keep: if someone answers rotating shifts or permanent nights,
     every screen that says *night* has to follow it — `night`, `debt`, the ages engines, Svea's
     framing. If it is stored and nothing reads it, the question is a lie and the honest fix is to
     drop the claim from the copy, not to keep the sentence.
   - **The *What Noop will not ask you* panel is a keeper, and it should not only exist at first
     run.** **[closed 30 August — it is a screen, not a wizard re-entry.]** A row that re-enters the
     wizard lands on step 1 behind a primary button marching toward pairing again. Instead: the last
     row of `you`'s hub card opens `you/position`, five denials with a reason each, no primary button.
     The trailing note on `you` gives up its enumeration to it. Drawn as
     **`Noop You - What Noop Will Not Ask`**; `onboard` is unchanged and keeps its inline panel,
     rendering the same five strings. No weight goal, no calorie target, no step count, no daily score,
     no comparison — that is the product's position and it is now readable on a Tuesday.

   Spec-side: 5.13 is now documentation of what shipped. Screens welcome but not needed — the outline
   was enough.

# Change 10 · The four closed on 1 September **[rev 5]**

Built together, all four from the parity audit's remaining list. Routes to add to §30:

| From | Tap | To |
| --- | --- | --- |
| `today` | the bell, top right, badged with the unread count | `day/inbox` |
| `day/inbox` | back | `today` |
| `settings` → Automations | the row, figured with how many are on | `plumbing/automations` |
| `plumbing/automations` | back | `settings` |

Two are not routes. `day/heart` gains the spot-reading card in place — no push, because a bounded minute
that navigates away is a minute you will not sit still for. The drawer's nine utilities gain a **Later**
group at the foot of `settings` whose rows deliberately do **not** navigate: they carry a Later chip
instead of a chevron, which is consistent with the rule that only rows that navigate get one.

# Change 9 · Routes the spec omitted

Built in the prototype, missing from §30's cross-act table. **Spec-side only — nothing to implement.**

| From | Tap | To |
| --- | --- | --- |
| `record` | Your zones row | `plumbing/zones` |
| `strap` | Manage straps row | `plumbing/devices` |
| `devices` | Add a strap | `plumbing/pair` |

# The 31 August tap-through **[rev 4]**

The checklist below was walked act by act. Three things were dead or trapping, all three fixed in
the same pass; everything else on the list behaved.

1. **The + was inert in Acts 6, 7 and 8** — the three acts with no sheet of their own had a centre
   button with no handler at all, which is checklist item 3 failing from three of nine acts. The
   31 August fix routed all three to `day/today` with the log sheet up. **That fix was wrong and is
   superseded** (8 September): the + is contextual, so Act 6 goes to `plumbing/record`, Act 8 to
   `goal/picker`, and Act 7 focuses its own Ask field without navigating. §30 §*The +* is the table.
   §30's tab rule still names the + as a tab.
2. **Act 3 trapped you** — the lit Today tab called `goSession`, so from `effort/session` there was
   no tab-bar route back to `day/today`. Fixed: from Act 3's root the lit tab leaves for the tab's
   root; from `pick` and `detail` it pops to `session` first.
3. **`today`'s session card had two states, not three** — open decision 2 below, answered by
   building it: the shell now remembers the session that ended and the card carries its name, its
   cost in charge and in minutes on tonight's need, and opens `detail`. Checklist item 9 passes.

# Handover checklist

Tap every one of these on a device.

1. `today` → session card → `effort/session`
2. `today` on a rest day → card still present, still opens
3. **+** → Start a session → sheet dismisses → `effort/session`
4. `session` → Start → `ready` → Start → `live`
5. From `live`, tap the You tab → **the session is still running** → live bar visible → tap it → back
   in `live`, clock unbroken
6. From `live`, tap the You tab, then a second tab, then return — still running. (This is the state
   move, not the bar; test it separately.)
7. Pause a session → bar reads Paused → tap → back in `live`
8. Let a session end → `detail` full-screen → back → `today`
9. `today` after a session → card shows the finished session → opens `detail`
10. `history` → a session row logged **after** the identity change → `detail` → back → `history`
11. `ages` → Health hub → `health`
12. `labs` → Add results → **the picker appears** → pick a photo → `review` shows what was read off it
    → cancel → `labs`
13. All five tabs, from all nine acts, including Act 6 — the dead `tabTrends` noted in §30

Not on this list, deliberately: `coach` → Memory (Change 6, already works — retest only that it still
does).

## Open decisions **[rev 3]**

**None.** Rev 2's two closed with the build; 8.2b closed 30 August as a screen off `you`, drawn in
`Noop You - What Noop Will Not Ask`. What is left is not a decision but three checks:

1. **Does anything read the schedule answer from onboarding step 2?** Answered 30 August — `ages` and
   Svea now read it alongside night, debt, day, effort and trends. Retest in Act 1's vocabulary.
2. **Does `today`'s card render its third state?** **Closed 31 August — built.** The shell holds the
   finished session, the card titles the workout's name, lines its cost in charge and in minutes on
   tonight's need, and opens `detail`. Retest that it survives a tab switch.
3. **Is door two a tab-level arrival?** Not a push onto the current tab. If it became a push, back lies
   from four of five tabs. Ordering and curve in `Noop Motion Pass`.

## Motion **[new, 30 August]**

Every transition introduced above is specified in **`Noop Motion Pass`** — all six of §10's curves
named, and each of the nine new transitions given a curve, a duration, an order of events and a Reduce
Motion answer. Two consequences that change how these changes are built rather than how they look:

- **Both doors into Act 3 are tab-level arrivals, so neither uses the push curve.** They crossfade on
  `swap`, 200 ms, and the tab bar's tint travels to Act 3's amber over the same 200 ms. Without the
  tint move, a card with a chevron that crossfades reads as a dropped frame.
- **The live bar is never animated out.** It is removed behind the incoming full-screen `detail` at
  200 ms, and the bottom inset shrinks while covered.
