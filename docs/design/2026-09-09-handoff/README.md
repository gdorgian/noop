# Noop — design handoff, 8 September

> **9 September addendum — read `spec/48-designer-answers-9-september.md` first.** It settles the
> four source-of-truth questions the coders left with the designer: the API-key flow's five states,
> nine fields for manual lab entry (and the nine markers `labs` now keeps), one formula for the goal
> safety build with every figure computed from it, and proactive Svea's default, delivery language,
> rate limits and pause-vs-revoke semantics. It landed in the HTML first — Acts 7 and 8 — with the
> spec following; the standalone is regenerated. Nothing else in the pack was reopened.

> **Then read `CLOSURE.md`.** It is the second-pass record: fifteen numbered items from the coder
> review, each mapped to the files changed and to whether the fix landed in the HTML, the
> specification, the Swift, or all three. Where it disagrees with anything else in the pack, it wins
> (after the HTML itself).

**Complete replacement pack.** Supersedes the 7 September pack, which is deleted, and the
1 September one, which you should keep until this is approved. Take the whole folder.

Open **`Noop app - standalone (open me).html`** first. It is the specification. Where anything
written here contradicts it, the HTML wins — including on behaviour. **Every correction below came
from that rule being applied to this pack**: seven places where the written spec disagreed with the
HTML, and the HTML was right in all seven.

---

## What changed on 8 September

**`WHAT-YOU-ASKED-FOR.md` has the blocker-by-blocker table.** In short:

1. **Mind is `[thin]`, not `[gone]`** — mood is the Journal's first input; only its correlation
   reporting is missing. *Missing with no substitute* is one item, Beat Rhythm.
2. **The orb has two plain taps** — the Ø 176 sphere opens Breathe, the surround opens Charge, and
   there is no long press anywhere in Noop. Its two charge-driven layers and its sheen are specified.
3. **The tab bar takes the act's hue and its ink as parameters**, with the nine-act table; the 20 pt
   backdrop is really applied, and §10a states what UIKit can and cannot do with a radius.
4. **The sheet primitive is complete** — scrim, 3 pt blur, outside-tap dismissal, upward shadow, and
   both real variants at measured values.
5. **No Charge arithmetic in the design layer.** `NoopCharge` accepts the precomputed level; the
   old `wake − Σ drains` is a `#if DEBUG` demo seed.
6. **Automation and notification claims match what exists.** `notifs` is `[later]`; automations run
   through the app; only the Smart Alarm claims to work with Noop closed.
7. **Stale counts fixed** — 21 routes in Act 5, fourteen no-back screens, nine font faces, one
   breath duration (16 s), this pack's standalone in `spec/README.md`, and the `AuraPalette`
   name claim. A further pass on 8 September cleared thirteen more: **thirteen** rules in
   `00-RULES.md` (not twelve), **six** Swift files (not five), Act 1 as **five** screens, *missing
   with no substitute* as **one** item, no motion durations in `NoopPalette`, and every app-wide
   “only two confirmations” claim replaced by a confirmation named next to the behaviour that needs
   one. `CLOSURE.md` item 13.

---

## What changed on 7 September, since 1 September

### 1 · Navigation — swipe-back now matches the visible chevron, everywhere

The rule, and it is the whole rule: **swipe-back does exactly what the back button does; where
there is no back button, swipe-back does nothing.** One map, walked by both. Do not keep a second
map for gestures — every divergence found in review was a map entry that had drifted from the
header it was supposed to mirror, invisible until someone swiped instead of tapping.

Corrected in the source HTML first, then the standalone regenerated, then `spec/30-routes.md`
synchronised to it.

| Screen | Was | Is |
| --- | --- | --- |
| `heart` | → `vitals` | → `today` — its chevron always read Today |
| `ready` | → `pick` | → `session` |
| `picker` | *no entry* — a live chevron and a dead swipe | → `labs` |
| `labs` | → `goal` | → `plumbing/you` — it is a root, not a child of `goal` |
| `goal` | → `plumbing/you` ✓ | unchanged, now stated |
| `building` | → `ages` | → `picture/trends` |
| `health` | → `ages` | → `plumbing/you` |
| `index` | → `picture/trends` ✓ | unchanged, now stated |

**Swipe-back disabled** (no chevron, no map entry, and the two facts are the same fact):
`live` · `intervals` · `reading` · `imported` · `rejected` · `onboard` · `gate` — plus the seven
home screens, as before. Seven map entries were deleted to get there.

Files: all nine act sources, `spec/30-routes.md` §Swipe back.

### 2 · The Build Document is 69 screens

Header, §7's opening line, and the inventory. It was 65 and omitted `inbox`, `across`, `apple` and
`automations`. The split is now stated on the page: **5 · 12 · 7 · 4 · 21 · 5 · 5 · 6 · 4**.

§9 *Deliberately not built* also loses two rows that were built (Automations, Workouts in
aggregate) and gains three that genuinely are not.

### 3 · Sixteen missing act-spec sections written

The screens existed in the HTML with no written spec. All sixteen now have one, at the same depth
as their neighbours.

| Act | Added |
| --- | --- |
| 1 | §1.5 `alarm` |
| 2 | §2.7 `inbox` · §2.8 `breathe` · §2.9 `bcatalog` · §2.10 `bplayer` · §2.11 `bsweep` · §2.12 `bfound` |
| 5 | §5.14 `position` · §5.15 `apple` · §5.16 `automations` · §5.17 `import` · §5.18 `reading` · §5.19 `imported` · §5.20 `rejected` · §5.21 `backup` |
| 8 | §8.6 `picker` |

The screen counts in each act's header are corrected with them: Act 1 is five, Act 2 twelve, Act 5
twenty-one, Act 8 six.

### 4 · The parity audit genuinely re-run — Rev 3

Walked screen by screen against all 69, not re-read with the count changed. **`spec/60-parity.md`
Part 0 is the list of what Rev 2 got wrong**, so nobody has to diff two revisions of a long page.

Nine entries. Eight were stale — Breathe, the import hub, backup, Explore, Compare, Insights, Smart
Alarm and the illness signal were all described as absent and are all built. One was a real error
of scope: **Act 9 is one of the nine acts, not "the second release".** Filing a quarter of the
archive as later *and* filing Explore, Compare and Insights as gone was double-counting the same
absence, and both halves were false.

Consequences: *Missing with no substitute* falls from 19 to **1** (Beat Rhythm). Part 1 is no
longer a blocker. Part 5's eight latent engines are seven placed and one deliberately dark. Part 6
has no second-release section and one new before-launch item — **walk a clean install**, because
half the engines say nothing for two to six weeks and that is now something you can open and look
at.

### 5 · Invented Charge semantics removed from the design layer

The design layer owns the **slot**, its type and its **absent state**. It does not own the verdict.

Removed, and not to be reintroduced at any confidence tier: the **70 / 50 / 30 bucket verdicts**,
the **14-day minimum**, the **±8 threshold**, *"Normal for this hour"*, *"Lower than most days at
this hour"*, *"Keep tonight easy"*, *"go to bed early"*, *"Nothing tonight but sleep"*, and
`charge + 26` as tonight's recovery. Gone for good, separately: **"the evening you had planned"** —
Noop reads no calendar and will not, so no input could ever earn it back.

What replaces them:

| Slot | Absent behaviour |
| --- | --- |
| `chargeVerdict` | falls back to a restatement of the level — `"{charge} left"`. Never blank, never a guess |
| `chargeNote` | **omitted.** The sentence ends after the arithmetic, and that is the finished string |
| `rechargeTo` | **the whole card is not built.** Not a card with an em-dash in it |

Fake examples are a **build configuration, not a fallback**: `#if DEBUG` **and** `--demo-seed`,
both. A debug build handed to a reviewer without the flag shows the real absent states, because
those are what a new user sees. In the prototype the seed is a prop (`demoSeed`, default on) so a
reviewer can switch it off and read the omitted state.

**The confidence chip is not a licence.** It qualifies a number the app *has*. It cannot make an
unevidenced sentence honest.

Files: `spec/swift/NoopSpecTokens.swift` (`ChargeEvidence`, `chargeWords`, `chargeSentence`,
`showsRechargeCard`, `demoChargeEvidence`), `spec/acts/41-act2-day.md` §2.2 *The evidence gate*,
Act 2 and Act 5 sources, `Noop - Build Document.dc.html` §9.

### 6 · The pack is normalised to fifteen primitives

It said *fourteen* in four places while `20-primitives.md` said fifteen — which is how a build
ships fourteen and nobody notices which one is missing.

`NoopSpecPrimitives.swift` now opens with an **index of all fifteen**, each with its § and the file
it lives in. Four had no implementation anywhere and now do: **§10 tab bar**, **§11 the orb**,
**§14 the bottom sheet**, **§15 the confidence chip**.

### 6b · Four defects in this turn's own new code, caught in review

Recorded because three of them were code contradicting a comment written twelve lines above it,
which is the class of bug a reader trusts the comment about.

| Where | Was | Is |
| --- | --- | --- |
| §14 bottom sheet | `.transition(.offset(y: 1.02))` — `offset` takes **points**, so the sheet entered from 1.02 pt and the entrance vanished | the height is measured with a `GeometryReader` and the offset derived from it, so 102 % is 102 % of something |
| §10 tab bar | `.layoutPriority(on ? 1.7 : 1)` on five `maxWidth: .infinity` children — priority orders ideal sizing, it is not a proportional grow, so all five rendered equal | widths measured: `(width − 72) / 4.7`, active × 1.7. The arithmetic is in the comment |
| §11 the orb | `easeInOut.repeatForever(autoreverses: true)` — right 16 s round trip, **no Hold plateau**, so the orb turned while the phase word said Hold | `KeyframeAnimator`, five tracks, four 4 s segments — in · **HOLD** · out · **HOLD**, the holds as `LinearKeyframe` so they occupy real time |
| Act 2 demo seed | a fixed seed against a live `charge` slider: drag it and the verdict stayed put | pinned to its one scenario (92 at 15.6 h); move either slider and it falls through to the omitted state |
| Act 2 demo seed, **again** | the pin was on the **inputs** while the copy was written for a charge near 92 — but wake 92 at 15.6 h derives `charge = 44`, so the pin froze the lie as the **default** view: *"Plenty left"* in the away-from-healthy mauve, and a recharge card claiming one night is worth **+44** | the copy is rewritten against the charge the scenario actually produces. Verdict is now a **restatement** (*"Just under half left"*), so it cannot disagree with the level colour; `rechargeTo` is 86, not 88 |

The seed is worth naming plainly, because it went wrong three times in the same place. It was a
bucket formula; then a fixed string against a moving number; then a pin that held the fixed string
at exactly the state it was false in. **A seed is one scenario, and every string in it has to be
true at the value that scenario produces — which is a derived value, not the sliders that feed it.**
The verdict slot is also now specified as a *restatement* rather than a judgement, so a seeded
verdict and the level colour can never contradict each other again.

### 7 · Imports made explicit, and the palette note corrected

`NoopSpecType.swift` imports **CoreText** (for `CTFontManagerRegisterFontsForURL`) and **UIKit**
(for `UIFont`, guarded by `canImport`). `NoopSpecPrimitives.swift` imports UIKit for the tab bar's
blur. The other four sources carry a one-line note saying SwiftUI is complete for them and why.

**Nothing was renamed.** The pack said *"renamed pack-wide to `NoopPalette`"*, which sends a coder
looking for a rename commit that does not exist. `1ecb5712` **deleted** `AuraPalette.swift`;
`NoopPalette.swift` is a **new file** supplying the subset of values the redesign read off it.
Corrected in `spec/13-branch-corrected-foundation.md`.

### 8 · The missing Instrument Serif licence — and the other two

`StrandDesign/Resources/Fonts/` now holds **all three** OFL licences. `OFL-InstrumentSerif.txt` was
missing; `OFL-Outfit.txt` and `OFL-InstrumentSans.txt` were named in the spec but not present
either. SIL OFL §2 requires the licence to travel with every copy and §5 requires the whole
distribution to stay under it, so a fork with the serif cuts and no serif licence is a
redistribution violation, not a tidiness problem.

The four `.ttf` binaries cannot ship in a design pack. `StrandDesign/Resources/Fonts/README.md`
names each file, the faces it must expose, where it goes and why not the app bundle.

---

## If you filed the report this pack answers

Read **`WHAT-YOU-ASKED-FOR.md`** first. It is your six asks, each with where it landed, plus the two
things you should know before starting — the four font binaries we cannot ship, and the four new
primitives that have never been compiled.

## What is in this folder

```
WHAT-YOU-ASKED-FOR.md                  the reply, blocker by blocker — start here
Noop app - standalone (open me).html   the specification
ios-frame.jsx  noop-gauge.js           the standalone's two siblings — keep them beside it

app/                                   the editable sources
  Noop - Full App.dc.html              the shell; imports the nine acts
  Noop Act 1…9                         one file per act
  Noop - Build Document.dc.html        the printable build doc — 69 screens
  Noop Screen Map.dc.html
  support.js  ios-frame.jsx  noop-gauge.js  doc-page.js

spec/
  README.md          what to read, in order
  00-RULES.md        READ FIRST — the twelve things that make a faithful build look cheap
  10-tokens.md       every colour, size and radius
  12-palette-bindings.md
  13-branch-corrected-foundation.md  READ BEFORE THE SWIFT — where it goes, and why
  20-primitives.md   the fifteen primitives — build these once, first
  30-routes.md       every route, back map, tap target, sheet, surviving state
  32-nav-addendum.md the ways in
  34-implement-31-august.md
  50-wiring.md       what feeds every bound value
  60-parity.md       Rev 3 — re-run against all 69
  70-copy.md         the copy law
  80-not-in-this-release.md
  acts/40…48         all 69 screens, act by act
  swift/             six sources, additive to StrandDesign

StrandDesign/Resources/Fonts/          three OFL licences + where the four binaries go
```

## Reading order

1. `spec/00-RULES.md`
2. `spec/13-branch-corrected-foundation.md` — before touching the Swift or the fonts
3. `spec/20-primitives.md` — build the fifteen once
4. `spec/30-routes.md` §Swipe back — the navigation decision, in full
5. `spec/acts/40…48` — the screens
6. `spec/60-parity.md` Part 0 — what the previous audit got wrong, and Part 6's clean-install test

## Precedence

**The HTML wins everywhere, including behaviour.** Where an HTML destination is fake, dead or
contradicts another screen, that is a question about *that specific destination* — ask, and get an
answer for it. Do not fall back on the written spec, and do not infer a general rule from one
broken door.
