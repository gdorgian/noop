# Routes, back maps and tap targets

*Foundations pack, 4 of 5. Every navigable thing in all nine acts — **69 screens**. If a tap in the
build goes nowhere, it is on this page. The counts and the maps below are read off the standalone
HTML, which is the specification.*

**The inventory: 69 screens, nine acts.** 5 · 12 · 7 · 4 · 21 · 5 · 5 · 6 · 4.

## The shape of navigation

Four tab-level destinations plus an add sheet. Each destination is an **act** — a home screen and
a stack of pushed screens above it. The tab bar is visible on **home screens only**; a pushed
screen replaces it with the 116 pt bottom inset still in place (RULES §8).

| Tab | Act | Home screen |
| --- | --- | --- |
| Today | 2 · The day | `today` |
| Trends | 4 · The bigger picture | `trends` |
| **+** | — | **contextual** — the act's own add action. §*The +* below |
| Rest | 1 · The night | `rest` |
| You | 5 · The plumbing | `you` |

Acts 3 (effort), 6 (ages), 7 (Svea) and 8 (goals) have no tab of their own — they are reached from
cards and rows inside the four tabs. Their home screens still show the tab bar, because a tab tap
must always work from them.

**Wire all five tabs in all nine acts.** A dead `tabTrends` was found in Act 6 during review; the
same shape of bug is invisible until someone taps it. **The + is a tab and counts:** the 31 August
pass found it inert in Acts 6, 7 and 8.

## The + — nine actions, one per act

**The + adds the thing the act you are standing in is about.** It is *not* "open Today's log". That
sentence was written into four files as a universal rule; it is true of Act 2 alone, and applied
everywhere it replaces four in-act sheets and four real destinations with one wrong door.

| Act · home | The + adds | Where it lands |
| --- | --- | --- |
| 1 night · `rest` | tonight's journal entry | the **Journal sheet**, in-act |
| 2 day · `today` | anything loggable today | the **Log sheet**, in-act |
| 3 effort · `session` | a session | `effort/pick` — the session picker |
| 4 picture · `trends` | a look at what is recorded | the **logged / recovery sheet**, in-act |
| 5 plumbing · `you` | a fact about you | the **Add sheet**, in-act |
| 6 ages · `ages` | a measurement the estimate needs | `plumbing/record` — *Add to your record* |
| 7 svea · `coach` | a question | **focuses the Ask field** — in-act, no navigation |
| 8 goals · `goal` `labs` | a lab result | `goal/picker` — *Add lab results* |
| 9 instrument · `index` | nothing; it reads | `plumbing/history` |

Four of the nine present a sheet **without leaving the screen** — those four are not navigations and
must not push. Four navigate. One (Act 7) moves focus to a field already on the screen. **It never
does nothing.**

An earlier pass routed Acts 6, 7 and 8 to `day/today` with the log sheet up, which is the only
part of this table the sources contradicted; `app/Noop - Full App.dc.html` carries the same nine
rows in `go(act, screen)` and no act asks for `'log'` any more.

**A lit tab still has to move.** From an act reached inside another act's tab, tapping the lit tab
pops to that act's own root; from the root it leaves for the tab's real root. Act 3 was trapping:
the lit Today tab returned to `effort/session` from `session`, so `day/today` was unreachable
without a swipe.

## Back maps

The "up" destination for every pushed screen. Swipe-back and the header button use the same map.

### Act 1 · The night — 5
```
rest (home)
tonight → rest        why → rest        debt → rest       alarm → tonight
```

### Act 2 · The day — 12
```
today (home)
charge → today        day → today       vitals → today    stress → today
heart → today         inbox → today     breathe → today
bcatalog → breathe    bplayer → breathe bsweep → breathe  bfound → breathe
```
The four `b*` screens are Breathe: the catalogue, the player, the resonance sweep and its result.
**All four return to `breathe`, not to each other** — including `bplayer`, which is reached
*through* `bcatalog`. Backing out of a finished session to the catalogue you picked it from is the
wrong door; you are done, and the act's root is where done lands.

### Act 3 · The effort — 7
```
session (home)
pick → session        ready → session   detail → session  across → session
live · intervals      — NO back chevron, and NO map entry
```
**`live` and `intervals` have no back.** You are in the effort; the only ways out are pause and
end. A back chevron there is an invitation to lose a session by accident.

`ready → session`, not `→ pick`. `ready` is reached from both, its chevron reads *Today's
session*, and a swipe that landed on `pick` would contradict the chevron on the arrival that did
not come through it.

### Act 4 · The bigger picture — 4
```
trends (home)
capacity → trends     rhythm → trends   year → trends
```

### Act 5 · The plumbing — 21
```
you (home)
record → you          history → you     strap → you       settings → you
data → you            position → you    zones → record
notifs → strap        devices → strap   apple → strap     pair → devices
widgets → settings    lab → settings    automations → settings
import → data         backup → data
reading · imported · rejected           — the import flow, NO back
onboard                                 — first run, NO back
```
**The import flow is a flow, not a stack.** `import → reading → imported` or `→ rejected`; none of
the three carries a back chevron, because backing into a read that is half-done means either
re-running it or lying about it. The exits are forward: from `imported` to what was written, from
`rejected` to the specific fix.

### Act 6 · Your ages — 5
```
ages (home)
driver → ages         method → ages
building → Trends     health → You      — these two LEAVE the act
```
`building` and `health` are entered from outside Act 6 and their chevrons say so: `building`
from Trends, `health` from You. Both the button and the swipe cross out of the act. Sending
either to `ages` puts the user somewhere they were never standing.

### Act 7 · Svea — 5
```
coach (home)
setup → coach         consent → setup   memory → coach
gate                  — no back chevron, no map entry; the way on is setup
```
Note `consent → setup`, not `→ coach`: consent is a step inside setting a provider up.

### Act 8 · Goals and labs — 6
```
goal → You            labs → You        — two roots, both LEAVE the act
set → goal            review → labs     marker → labs     picker → labs
```
Act 8 has **two** roots, both entered from `you`, and both carry a chevron reading *You* — so
both the button and the swipe leave for You. **`labs` is not under `goal`**: a swipe on `labs`
that landed on `goal` would invent a parent the user never passed through.

`picker → labs`, which the build's map was missing entirely. Cancelling from the picker adds
nothing, and the photo is not remembered.

### Act 9 · The instrument — 4
```
index → Trends        — the act's root LEAVES the act
metric → index        compare → index   effects → index
```
`index` is reached from the foot of `trends` and its chevron reads *Trends*, so the swipe goes
there too. Act 9 is the fourth act with no tab of its own whose root leaves on back — the others
are Act 6's two entered screens and Act 8's two roots.

## Swipe back

**The rule, and it is the whole rule: swipe-back does exactly what the visible back button does.
Where a screen has no back button, swipe-back does nothing.**

That is one sentence because it has to be testable in one pass: put the chevron and the swipe on
the same map and there is no second behaviour to get wrong. Every divergence found in review was
the same shape — a map entry that had drifted from the header it was supposed to mirror, invisible
until someone swiped instead of tapping.

Identical on every screen. `[static]` thresholds:

```
on pointer up:  navigate back when  dx > 78  &&  |dy| < 58
```

Attached to the **scroll container**, not the screen. Order of precedence:
1. If a sheet is open, close the sheet. Do not navigate.
2. Otherwise walk the back map — which is the same map the header chevron walks. One map, one
   source. Do not maintain a second one for gestures.
3. No entry in the map means **do nothing**. Not a fallback to the act's root, not a cross-tab
   jump, not the previous screen in a history stack. Nothing.

### The screens with no back, and therefore no swipe

Fourteen, in five groups — the five rows below. A screen on this list has no chevron in its header
and no entry in its act's map, and the two facts are the same fact. (This paragraph said *eleven*
over a table of fourteen. Count the rows, not the sentence.)

| Screens | Why |
| --- | --- |
| `rest` `today` `session` `trends` `you` `ages` `coach` | **Home screens.** A tab root has no up. Swipe does not cross tabs. |
| `live` `intervals` | **You are in the effort.** The only ways out are pause and end. |
| `reading` `imported` `rejected` | **The import flow is a flow, not a stack.** Backing into a half-done read means re-running it or lying about it. The exits are forward. |
| `onboard` | **First run.** There is nothing behind it yet. |
| `gate` | **No provider is set.** The way on is `setup`; there is nothing to go back to. |

### The screens whose back leaves their act

Five. Their chevron names a destination in another act, and the swipe follows it — this is not an
exception to the rule above, it is the rule applied to a screen that was entered from elsewhere.

| Screen | Chevron reads | Goes to |
| --- | --- | --- |
| `building` | Trends | `picture/trends` |
| `health` | You | `plumbing/you` |
| `goal` | You | `plumbing/you` |
| `labs` | You | `plumbing/you` |
| `index` | Trends | `picture/trends` |

### The four that were wrong, and are now right

Recorded because each was invisible to tapping and only a swipe exposed it.

| Screen | Was | Is |
| --- | --- | --- |
| `heart` | → `vitals` | → `today` — its chevron always read Today |
| `ready` | → `pick` | → `session` |
| `picker` | *no entry* — swipe did nothing under a live chevron | → `labs` |
| `labs` | → `goal` | → `plumbing/you` — it is a root, not a child of `goal` |

And four that had entries they should never have had: `onboard`, `reading`, `imported`,
`rejected` — all four chevron-less, all four swiping backwards out of a flow. Plus `gate`,
`live` and `intervals`, whose entries are likewise gone.

## Cross-act routes

The taps that leave the act they started in. These are the ones most likely to be missed, because
each one lives inside a card rather than in a nav bar.

| From | Tap | To |
| --- | --- | --- |
| Any home screen | strap battery chip | `plumbing/strap` |
| `today` | the orb's **surround** — the gauge ring, the halo, the 318 pt block | `day/charge` |
| `today` | the body-state line (it carries a chevron) | `day/charge` |
| `today` | last-night line | `night/why` |
| `today` | Svea prompt | `svea/coach` |
| `today` | day's shape card | `day/day` |
| `today` | Heart · Vitals · Stress tiles | `day/heart` · `day/vitals` · `day/stress` |
| `rest` | tonight's plan card | `night/tonight` |
| `rest` | the score's "why" | `night/why` |
| `rest` | debt line | `night/debt` |
| `session` | Swap | `effort/pick` |
| `session` | Every session, in aggregate | `effort/across` |
| `across` | any session row | `effort/detail` |
| `across` | all N in your history | `plumbing/history` |
| `history` | Every session, in aggregate | `effort/across` |
| `today` | session card, **finished state** | `effort/detail` |
| `session` | Start | `effort/ready` |
| `trends` | any of the four lines | `trends/capacity` · `rhythm` · `year` |
| `trends` | body-age card | `ages/ages` |
| `you` | portrait / body clock centre | `plumbing/record` |
| `you` | strap row | `plumbing/strap` |
| `you` | ages row | `ages/ages` |
| `you` | Svea row | `svea/coach` |
| `you` | goals row | `goal/goal` |
| `strap` | Buzz for phone notifications | `plumbing/notifs` |
| `settings` | What may interrupt you | `plumbing/notifs` |
| `settings` | Widgets | `plumbing/widgets` |
| `settings` | The Lab | `plumbing/lab` |
| `settings` | Your data | `plumbing/data` |
| `ages` | any driver row | `ages/driver` |
| `ages` | how this is figured | `ages/method` |
| `coach` | no provider set | `svea/gate` |
| `goal` | any waypoint | `goal/set` |
| `labs` | any marker | `goal/marker` |
| `labs` | Add results | `goal/picker` |
| `today` | the bell (badged) | `day/inbox` |
| `today` | the orb's **Ø 176 sphere**, a plain tap | `day/breathe` |
| `breathe` | Choose a protocol | `day/bcatalog` |
| `breathe` | Find my pace | `day/bsweep` |
| `bsweep` | when the sweep settles | `day/bfound` |
| `bcatalog` | any protocol | `day/bplayer` |
| `tonight` | Smart alarm row | `night/alarm` |
| `strap` | Automations | `plumbing/automations` |
| `strap` | Apple Health | `plumbing/apple` |
| `strap` | how you wear it | `plumbing/position` |
| `data` | Import | `plumbing/import` |
| `data` | Backup and restore | `plumbing/backup` |
| `import` | a dropped file | `plumbing/reading` → `imported` or `rejected` |
| `index` | any metric | `instrument/metric` |
| `index` | Compare two | `instrument/compare` |
| `index` | What actually moves this | `instrument/effects` |

## Sheets

Sheets are not screens. They open over the current screen, keep it mounted, and are dismissed by
swipe-back before it walks the back map.

| Sheet | Opened by | Notes |
| --- | --- | --- |
| Log / **Everything you logged** | the tab bar **+**, and `trends` | Filters (All / Sleep / Heart / Training / Manual) **persist across open and close** — they are screen state, not sheet state |
| Add photo | `you` +, `record` photo row | |
| Day navigator | the day chip on `today` | Inline, not a sheet — it expands the header |

## State that survives navigation

| State | Scope | Notes |
| --- | --- | --- |
| `tg{}` — every toggle | app | Keyed by label in the prototype; key by a real identifier |
| `prefs{}` — every segmented preference | app | Units, Appearance, Effort scale, buzz pattern |
| `nAccess` — iOS notification authorisation | system | **Not in this release** — `notifs` is `[later]` and asks for nothing. When it ships: read live on every appearance, never cached |
| `sync`, `hsync` | act | Each a 3-state machine: idle → running → done. `done` reverts after 2 s |
| Log filter | act | Persists across sheet open/close |
| `dayOff` / `dayOpen` | screen | Resets to today on leaving `today` |
| `drain` (arrival animation) | screen | Fires **on arrival only** |
| `photo` | app | |

## The drain animation, precisely

The one piece of state whose timing is a design decision rather than a mechanism:

- Fires when `today` **appears from a tab switch or a cold launch**.
- Does **not** fire when returning from `charge`, `vitals`, `heart`, `stress` or `day`.
- Does **not** fire on a data refresh while the screen is up.
- Under Reduce Motion it does not fire at all; the final value fades in over 200 ms.
