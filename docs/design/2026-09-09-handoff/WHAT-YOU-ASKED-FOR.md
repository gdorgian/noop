# What you asked for, and where it landed

> **Superseded in part, 8 September (second pass).** The fifteen items you sent back after reading
> this file are answered in **`CLOSURE.md`**, which is the current record and takes precedence over
> anything below it. Corrections made there and *not* rewritten in this file are marked inline.

**8 September. Second replacement pack — supersedes the 7 September one, which is deleted.**
Everything in this file is in `design_handoff_8_september/`. It is a **complete replacement pack**,
not a patch: take the whole folder. Keep `design_handoff_1_september/` until you have approved this.

---

## The seven blockers you found on 7 September

Each one was a place where the pack contradicted its own canonical HTML. **The HTML was right every
time.** All seven are corrected in this pack.

| | Blocker | Correction |
| --- | --- | --- |
| 1 | Mind is not gone — mood is the Journal's first input | `[thin]`, in Part 3 §B. *Missing with no substitute* is now **one** item: Beat Rhythm. `60-parity.md` Part 0 records the mistake |
| 2 | Orb routing was backwards, and the sheen and charge overlays were missing | **Sphere Ø 176 → `day/breathe`; surround → `day/charge`, both plain taps, no long press.** Seven layers, including the two charge-driven warm layers and the 24 s sheen. `20-primitives.md` §11, `NoopSpecPrimitives.swift` §11 |
| 3 | Tab bar hardcoded a blue active tab; its 20 pt blur was unused | Active fill and its ink are **passed in per act**, with the nine-act hue table read off the sources. The blur is now really applied, via `NoopGlass` — and §10a says plainly why UIKit cannot take the 20 pt as a parameter |
| 4 | The sheet primitive was incomplete | Scrim, 3 pt backdrop blur, outside-tap dismissal, upward shadow, and **both HTML variants** (log 30 / panel 28) at measured values |
| 5 | `NoopCharge` still computed `wake − drains` | Removed. `NoopCharge` takes `charge` **precomputed**; the sum survives only as `#if DEBUG demoSeed`. `50-wiring.md` Part 1 §1 states the rule |
| 6 | Automation and notification firmware claims were inaccurate | `notifs` ships **`[later]`** — no permission asked, no *saved to strap* state, a Later chip where the toggle was. Automations are **app-mediated**, and only the Smart Alarm may claim a closed app |
| 7 | Stale counts and references | Act 5 is 21 routes; fourteen no-back screens; the standalone pointer is this pack's; nine font faces; one breath duration (16 s, in `NoopSpecMotion` only); and `NoopPalette` shares a **purpose** with `AuraPalette`, not a name |

---

## The six asks from 1 September

| | Ask | State |
| --- | --- | --- |
| 0 | **Navigation: swipe-back must match the visible back button** | **Done.** Source HTML first, standalone regenerated, then `30-routes.md` synchronised |
| 1 | **Build Document is 65 screens and omits `inbox`, `across`, `apple`, `automations`** | **Done.** 69, with the four rows and the split stated on the page |
| 2 | **16 missing act-spec sections** | **Done.** All sixteen, at the same depth as their neighbours |
| 3 | **Genuinely rerun the parity audit against all 69** | **Done.** Rev 3, walked screen by screen. `Part 0` is the list of what Rev 2 got wrong |
| 4 | **Remove invented Charge semantics from the design layer** | **Done.** And the slot is respecified so it cannot recur |
| 5 | **Fifteen primitives · false rename story · explicit imports · Instrument Serif licence** | **Done, with one caveat** — see *Two things to know* below |

---

## 0 · Navigation

The rule is now one sentence, in `30-routes.md` §Swipe back: **swipe-back does exactly what the
visible back button does; where a screen has no back button, swipe-back does nothing.** One map,
walked by both the header chevron and the gesture. **Do not keep a second map for gestures** — every
divergence we found was a map entry that had drifted from the header it was supposed to mirror,
invisible until someone swiped instead of tapping.

Four destinations were wrong:

| Screen | Was | Is |
| --- | --- | --- |
| `heart` | → `vitals` | → `today` — its chevron always read Today |
| `ready` | → `pick` | → `session` |
| `picker` | *no entry* — a live chevron over a dead swipe | → `labs` |
| `labs` | → `goal` | → `plumbing/you` — it is a **root**, not a child of `goal` |

Two cross-act ones were implicit and are now explicit: `building` → `picture/trends`,
`health` → `plumbing/you`. `goal` → `plumbing/you` and `index` → `picture/trends` were already
right and are now written down.

**Seven map entries were deleted** so the chevron-less screens genuinely do nothing:
`live` · `intervals` · `reading` · `imported` · `rejected` · `onboard` · `gate`. Four of those had
a back entry with no chevron above it, which is how a swipe walked backwards out of a half-finished
import.

`30-routes.md` now carries three tables you can test against directly: the **fourteen** screens
with no back, the five whose back leaves their act, and the four that were wrong.

---

## 1 · The Build Document

Header, §7's opening line and the inventory. The split is stated on the page so a miscount is
visible: **5 · 12 · 7 · 4 · 21 · 5 · 5 · 6 · 4 = 69**.

§9 *Deliberately not built* also loses two rows that are built (Automations, Workouts in aggregate)
and gains three that genuinely are not.

---

## 2 · The sixteen act-spec sections

| Act | Added |
| --- | --- |
| 1 | §1.5 `alarm` |
| 2 | §2.7 `inbox` · §2.8 `breathe` · §2.9 `bcatalog` · §2.10 `bplayer` · §2.11 `bsweep` · §2.12 `bfound` |
| 5 | §5.14 `position` · §5.15 `apple` · §5.16 `automations` · §5.17 `import` · §5.18 `reading` · §5.19 `imported` · §5.20 `rejected` · §5.21 `backup` |
| 8 | §8.6 `picker` |

Each act's header count is corrected with them — Act 1 five, Act 2 twelve, Act 5 twenty-one,
Act 8 six.

Three of these carry a behaviour you cannot infer from the layout, so read them before building:

- **§5.16 `automations`** — the heart-rate ceiling **resolves to a real bpm before it arms**, and
  the resolved number is on the screen. A zone is a percentage of a maximum that itself moves; an
  armed ceiling is a boundary in beats. Do not re-implement that resolution in the view.
- **§5.15 `apple`** — the page counts what was **written**, not what succeeded, because iOS never
  tells an app a read was refused. *Not asked* is an honest third state, not a variant of refused.
- **§5.19 `imported`** — unknown stays **nil**, never zero. A missing night and a bad night must not
  look alike, and a zero-filled gap is invisible once written and corrupts every average downstream.

**Corrected, 8 September — this paragraph was wrong.** `automations` is **app configuration**: it
runs in Noop, not on the strap, so it has no *saved to strap* state and nothing on it may claim to
work with the app closed. `notifs` ships **`[later]`** — no permission request, no *saved to strap*
state, no strap-battery cost, no live control — and no transport for it has an owner, so this pack
names none. The one feature that genuinely keeps working with Noop closed is the **Smart Alarm**,
which is separately supported and unaffected. `44-act5-plumbing.md` §5.6 and §5.16, `50-wiring.md`
Part 1 §4, `CLOSURE.md` item 12.

---

## 3 · The parity audit, Rev 3

Re-run against all 69, not re-read with the count changed. **Start at `Part 0`**, which is the list
of what Rev 2 got wrong, so you do not have to diff two revisions of a long page.

Nine entries. Eight were **stale rather than mistaken** — Breathe, the import hub, backup, Explore,
Compare, Insights, Smart Alarm and the illness signal were all described as absent and are all
built. One was a real error of scope: **Act 9 is one of the nine acts, not "the second release".**
Filing a quarter of the archive as later *and* filing Explore, Compare and Insights as gone was
double-counting the same absence, and both halves were false.

Consequences worth knowing:

- *Missing with no substitute* falls from **19 to 1** — Beat Rhythm, and nothing else. (This line
  read *19 to 2* while the section below it said *one item, not two*. One is the count: Mind is
  `[thin]`, with its input intact.)
- **Part 1 is no longer a blocker.** It stays at the front because it is the section a build most
  needs to get right, not because it is outstanding.
- Part 5's eight latent engines are now **seven placed and one deliberately dark**.
- Part 6 has **no second-release section** and **one new before-launch item**.

### The one new before-launch item, and it is a test rather than a screen

**Walk a clean install.** Install, import nothing, and read all 69 screens on day one. Half the
engines say nothing for two to six weeks, and until they were surfaced that was theoretical. It is
now something you can open the app and look at. `ages/building` and `plumbing/imported` were
designed for that state; the rest were not, and the period they will look broken in is exactly the
period someone is deciding whether to keep the app.

### Two things got worse, honestly

**Beat Rhythm** was `[thin]` on the strength of a name collision with `trends/rhythm`. Walked
properly it is `[gone]` — `RhythmView` is beat-to-beat regularity and `trends/rhythm` is circadian
timing. **Do not wire one into the other.** That is the only downgrade, and *missing with no
substitute* is therefore **one** item, not two.

**Mind is `[thin]`, and this file said `[gone]` — you were right.** Mood is the Journal's first
question (`night/journal`, the *How was it* row, five states). What is missing is the **reporting**:
its correlations against Charge, Rest and HRV have no screen. That is worth a decision, but it is a
thin capability with the input intact, not an absence.

Those two are the only capabilities left with no screen and no row.

---

## 4 · Charge semantics — what to delete, and what replaces it

You were right, and it went deeper than the strings.

**Deleted, and not to be reintroduced at any confidence tier:** the **70 / 50 / 30 bucket
verdicts**, the **14-day minimum**, the **±8-point threshold**, *"Normal for this hour"*, *"Lower
than most days at this hour"*, *"Keep tonight easy"*, *"go to bed early"*, *"Nothing tonight but
sleep"*, and **`charge + 26`** as tonight's recovery. Gone for good, separately from the rest:
**"the evening you had planned"** — Noop reads no calendar and will not, so no input could ever earn
it back.

**The design layer owns the slot, its type and its absent state. It does not own the verdict.**

| Slot | Absent behaviour |
| --- | --- |
| `chargeVerdict` | falls back to a restatement of the level — `"{charge} left"`. Never blank, never a guess |
| `chargeNote` | **omitted.** The sentence ends after the arithmetic, and that is the finished string — not a truncated one |
| `rechargeTo` | **the whole card is not built.** Not a card with an em-dash in it |

The arithmetic half of the sentence always renders, because the app holds both numbers itself and it
is not a claim about anything it cannot see.

`NoopSpecTokens` now exposes `ChargeEvidence`, `chargeWords(charge:evidence:)`,
`chargeSentence(wake:charge:evidence:)` and `showsRechargeCard(evidence:)`. Analytics owns every
field. **A `nil` field is the specified output, not an error and not a gap** — on a fresh install it
is all of them.

### Three constraints that came out of this

1. **The verdict is a restatement, never a judgement.** The level colour is already on screen — hero
   numeral, gauge ticks, chip fill — and climbs the warm ramp as the charge falls. A worded
   judgement can therefore *contradict* it: "Plenty left" in the away-from-healthy mauve is two
   elements of one composition saying opposite things, and the reader believes the colour. A
   restatement cannot disagree with anything.
2. **Fake examples are a build configuration, not a fallback.** `#if DEBUG` **and** `--demo-seed`,
   both. A debug build handed to a reviewer without the flag must show the real absent states,
   because those are what a new user sees. `demoChargeEvidence()` returns `.none` unless both hold,
   so the fall-through is the honest path rather than the seeded one.
3. **A seed is one scenario, and every string in it must be true at the charge that scenario
   produces.** `charge` is derived (`wake − spent(hour)`), so pinning a seed to the *inputs* and
   authoring its copy for a different charge freezes a false reading in place. We got this wrong
   twice before it was right; the seeded scenario is now documented in the code as *woke with 92,
   44 left at 15.6 h*.

**The confidence chip is not a licence for any of this.** It qualifies a number the app *has*. It
cannot make an unevidenced sentence honest — where there is no evidence the words are **omitted**,
not chipped.

Full rule: `spec/acts/41-act2-day.md` §2.2 *The evidence gate*. It governs `today`'s state line,
`day/charge`'s hero and sentence, **and** the Charge widget — one slot in three places, bound in all
three.

---

## 5 · The pack, the imports, the palette note and the licences

### Fifteen primitives, and four of them had no implementation

It said *fourteen* in four places while `20-primitives.md` said fifteen — which is how a build ships
fourteen and nobody notices which one is missing. `NoopSpecPrimitives.swift` now opens with an
**index of all fifteen**, each with its § and the file it lives in.

Four had no implementation anywhere and now do: **§10 tab bar**, **§11 the orb**, **§14 the bottom
sheet**, **§15 the confidence chip**. Three of them encode something an HStack will not reproduce:

- **§10** — the active tab is **1.7 ×** an inactive one. `layoutPriority` does not do this; it orders
  who gets ideal size first. The widths are measured: `(width − 72) / 4.7`, active × 1.7.
- **§11** — the orb **holds at peak from 25 % to 50 %**. That plateau is the *Hold* of box breathing
  and the phase word advances on its own 4 s cadence against it. A two-phase `autoreverses` loop has
  the right 16 s round trip and no hold, and the two desynchronise within a cycle.
- **§14** — the sheet enters from **102 %** of its own **measured** height. `.offset(y:)` takes
  points, so a fractional literal there moves it about a point and the entrance disappears. The 2 %
  is what clears the sheet's own shadow off the screen edge.

### Imports

`NoopSpecType.swift` imports **CoreText** (`CTFontManagerRegisterFontsForURL`) and **UIKit**
(`UIFont`, guarded by `canImport`). `NoopSpecPrimitives.swift` imports UIKit for the tab bar's blur.
The other four sources carry a one-line note saying SwiftUI is complete for them, so the absence is
readable as deliberate.

### The rename story was false

The pack said *"renamed pack-wide to `NoopPalette`"* in three places. **Nothing was renamed.**
`1ecb5712` **deleted** `AuraPalette.swift`; `NoopPalette.swift` is a **new file** supplying the
subset of values the redesign read off it. There is no rename commit to find and no migration path.
Corrected in `13-branch-corrected-foundation.md` §*The name — and it is not a rename*; every
remaining mention of the old name is historical and says so.

### The licences

`StrandDesign/Resources/Fonts/` now holds **all three**. `OFL-InstrumentSerif.txt` was the one you
flagged; `OFL-Outfit.txt` and `OFL-InstrumentSans.txt` were named in the spec but not actually
present either, so all three are written.

This is not tidiness. **SIL OFL §2** requires the copyright notice and licence to travel with every
copy of the font, and **§5** requires the whole distribution to stay under the OFL — so a
build-from-source fork with the serif cuts present and the serif licence absent is a redistribution
violation.

---

## Two things to know before you start

**1 · The four `.ttf` binaries are not in the pack and cannot be.** A design handoff cannot carry
binaries. What ships is the three licences plus
`StrandDesign/Resources/Fonts/README.md`, which names each file, the faces it must expose, where it
goes and why not the app bundle. Drop `Outfit.ttf`, `InstrumentSans.ttf`,
`InstrumentSerif-Regular.ttf` and `InstrumentSerif-Italic.ttf` in beside the licences. This is the
one item on your list we can only partly close.

Three things in that README are load-bearing and were each a real failure:

- `registerFonts()` looks in **`Bundle.module`**, the *package* bundle. It cannot see
  `StrandiOS/Resources/Fonts`, so registration finds nothing there whatever the files are named.
- **Register by filename, then validate the faces** — the order the first version had backwards. It
  looked for a `.ttf` named after each of the seven PostScript names, found none (the files are
  variable), never called `CTFontManagerRegisterFontsForURL`, and then asserted on a font that had
  not been given a chance to register.
- **Call it twice.** `Bundle.module` is per-process and the widget is a separate process. Skipping
  the widget's call is how the Charge widget renders in San Francisco while the app looks right —
  and widget snapshots are taken by the system when nobody is watching.

**2 · The four new primitives have never been compiled.** §10, §11, §14 and §15 are new Swift
written this pass against the spec. The prototype is the proof of the *design*; it is not proof
these compile. Expect a build pass on them, and if anything has to change, change the code and tell
us — the geometry and the timings are the part that is binding, not the SwiftUI spelling.

---

## The four `.ttf` binaries are still an external prerequisite

Unchanged and still open, deliberately: the pack ships the three OFL licences plus
`StrandDesign/Resources/Fonts/README.md`, and **not** `Outfit.ttf`, `InstrumentSans.ttf`,
`InstrumentSerif-Regular.ttf` or `InstrumentSerif-Italic.ttf`. A design handoff cannot carry
binaries. **Font integration is not closed** — it is a coder prerequisite with written instructions,
and `CLOSURE.md` item 15 keeps it on the list rather than ticking it.

## Precedence, unchanged

**The HTML wins everywhere, including behaviour.** Where an HTML destination is fake, dead or
contradicts another screen, that is a question about *that specific destination* — ask, and get an
answer for it. Do not fall back on the written spec, and do not infer a general rule from one broken
door.

## Reading order

1. `spec/00-RULES.md`
2. `spec/13-branch-corrected-foundation.md` — before touching the Swift or the fonts
3. `spec/20-primitives.md` — build the fifteen once, first
4. `spec/30-routes.md` §Swipe back — the navigation decision in full
5. `spec/acts/40…48` — the screens
6. `spec/60-parity.md` **Part 0**, then Part 6's clean-install test
