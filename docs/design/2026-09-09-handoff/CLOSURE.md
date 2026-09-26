# CLOSURE — 8 September, second pass

**One complete replacement pass over `design_handoff_8_september/`. Not a patch.** Every item you
sent is below with the exact files changed and the layer each correction landed in. Two items could
not be fully closed and say so in their own words rather than in a footnote.

**HTML remains authoritative.** Where a correction was a behaviour the HTML did not yet have — the
contextual +, Act 7's voice and key, Act 8's Fix and Save — the **HTML was changed first**, then the
specification, then the Swift, so the precedence rule still holds after this pass. Nothing in the
spec asserts a behaviour the sources do not carry.

---

## The nine-row + table, once

It appears in five files and this is the copy to read:

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

Four present a sheet without leaving the screen. Four navigate. One moves focus.

---

# P0 — approved product behaviour

## 1 · The contextual + is restored

**Corrected in HTML, specification and Swift.**

| File | Change |
| --- | --- |
| `app/Noop Act 6 - Your Ages.dc.html` | `tabLog: tab('day','log')` → `addToRecord: tab('plumbing','record')`, and the + button's handler with it |
| `app/Noop Act 7 - Svea.dc.html` | the + calls `focusAsk`, which arrives on `coach` and focuses the Ask field. No navigation |
| `app/Noop Act 8 - Goals and Labs.dc.html` | the + calls `goPicker` → `goal/picker` |
| `app/Noop - Full App.dc.html` | `go(act, screen)` carries the nine rows as its header comment; `'log'` survives only as a named route no act now asks for |
| `spec/20-primitives.md` | §10's *"The + opens the log sheet, it does not navigate"* → the nine-row table |
| `spec/30-routes.md` | the tab table's + row, and a new **§The +** holding the table. The *"an act without a log sheet routes the + to `day/today`"* paragraph is gone |
| `spec/32-nav-addendum.md` | *"What does not change"* and Change 1 both rewritten; the 31 August fix is marked superseded rather than deleted |
| `spec/34-implement-31-august.md` | the build note and its code block |
| `spec/swift/NoopSpecPrimitives.swift` | §10's header note is the nine rows; `onAdd`'s doc says *the act's own add action*, never *the log sheet* |

Acts 1, 2, 3, 4, 5 and 9 already had the right action in HTML and are unchanged — only the false
universal rule described them wrongly. **The `onAdd` closure stays**, as you allowed: it is the
right shape, because four of the nine present a sheet in place and cannot be a navigation.

## 2 · Act 7 complete

**Corrected in HTML, specification and Swift-adjacent wiring.**
`app/Noop Act 7 - Svea.dc.html` · `spec/acts/46-act7-svea.md` (rewritten) · `spec/50-wiring.md`

- **Voice is exactly Plain / Quiet / Direct / Off.** Four chips, four notes.
- **Off suppresses proactive speech and proactive contact.** It holds the three *how often it speaks
  first* rows at Never, dims them to 38 % and makes them inert; the brief is not fetched; `coach`'s
  brief card carries a ***Not briefed · off*** eyebrow and an honest one-line body instead of a
  brief written in a default voice. Turning a voice back on restores the previous setting.
- **The API key has no Reveal.** The row shows the final four characters and offers **Replace**.
  `keyShown` state and the `toggleKey` handler are deleted from the source; the sub-line already
  said Noop cannot read the key back out, and a Reveal button contradicted it.
- **Deep Insights is confirmed separately.** Tapping the preset no longer changes the grant map: it
  raises an amber card naming sensitive journal topics and lab results, and only *Turn sensitive
  topics on* applies it. Essentials and Personal still apply on one tap.
- **Proactive Briefs are specified in full** — §7.3b: the permission is named on the row that grants
  it, a strip below restates what happens (Noop wakes, builds the same granted summary, calls your
  provider, **posts no notification**), the state is **persisted with the choice** rather than asked
  for again, and **disabling revokes in the same write**. There is no OS permission to request,
  because this is Noop's own background work; no copy may promise a time, because iOS may delay it.
- **The routes are corrected**: `gate` has **no back**; `setup` → `coach`; `consent` → `setup`.
- **The + focuses Ask.**

## 3 · Act 8 complete

**Corrected in HTML, specification and wiring.**
`app/Noop Act 8 - Goals and Labs.dc.html` · `app/Noop Act 5 - The Plumbing.dc.html` ·
`spec/acts/47-act8-goals.md` · `spec/30-routes.md` · `spec/50-wiring.md`

- **An infeasible goal is still allowed, and Save confirms first.** *The data says yes* commits on
  one tap; the other two verdicts raise a card naming the cost, with **Save it anyway** /
  **Change the date**. The app does not refuse the goal.
- **Save with zero confirmed rows is a no-op** — a dead button that says what would make it live,
  not a toast and not a bounce.
- **Confirmed and corrected rows are saved** and update Biomarkers; **discarded rows are forgotten**,
  not stored as a declination.
- **Fix actually corrects the value.** It opens a numeric field pre-filled with the read value at
  Outfit 300 / 19; *Use this value* is inert while empty; the row stores the **typed** number and
  the displayed value, the settled line and the saved row all show it. The old implementation
  flipped a label and stored the read value — the one screen whose whole job is correction could
  not correct anything.
- **Confirm / Fix / Discard is kept**, unchanged in shape.
- **The photo and the OCR draft are deleted** on Save *and* on leaving unsaved — image, read text,
  rects and pending corrections, in the same state write.
- **Both doors enter the picker.** Act 8's + → `goal/picker`; Act 5's *A lab result to import* row
  → `goal/picker`, not `review`. Its sub-line no longer promises a read.
- **`labs` returns to You**, not `goal`.
- **No fabricated OCR.** *Enter results by hand* now enters `review` in a by-hand mode with **no
  image card, no strips, no confidence chips and empty rows**, and the screen's eyebrow, title and
  footnotes change with it. The release may ship this path; it may not ship invented results.

---

# P1 — contradictory routes

## 4 · Route conflicts

**Corrected in specification and in the Build Document. `30-routes.md` was already right in every
case — the stale copies were the act files and the Build Document's inventory.**

| Screen | Was | Is | File |
| --- | --- | --- | --- |
| `intervals` | back → `live`, *"returns to live"* | **no chevron, no map entry** | `spec/acts/42-act3-effort.md` §3.5, Build Document §7 |
| `data` | back → `settings` | back → `you` | `spec/acts/44-act5-plumbing.md` §5.9 |
| `building` | back → `ages` | back → `picture/trends` | `spec/acts/45-act6-ages.md` §6.2, Build Document |
| `health` | back → `ages` | back → `plumbing/you` | `spec/acts/45-act6-ages.md` §6.5, Build Document |
| `gate` | back → `coach` | **no back** | `spec/acts/46-act7-svea.md` §7.2, Build Document |
| `setup` | back → `gate` | back → `coach` | `spec/acts/46-act7-svea.md` §7.3, Build Document |
| `consent` | back → `coach` | back → `setup` | `spec/acts/46-act7-svea.md` §7.4, Build Document |
| `labs` | back → `goal` | back → `plumbing/you` | `spec/acts/47-act8-goals.md` §8.3, Build Document |
| `live` | Door column read `ready` | **no back** | Build Document §7 |

**On one generated matrix.** `spec/30-routes.md` is now the single back map and every act file's
route line points at it instead of restating it. The Build Document's inventory column is retitled
**Door** and carries an explicit paragraph saying a door is not a back destination and that
`30-routes.md` is the answer where the two differ — four of the corrections above were rows there
that had quietly become a second, wrong map. Fully generating the table from the sources is the
right end state and is not something this pack can do; making one file authoritative and the rest
pointers is the part that removes the drift.

---

# P1 — visual system

## 5 · The false "only four gradients" rule is gone

**Corrected in specification, in Swift and in the Build Document.**

- `spec/10-tokens.md` gains **§Gradients and shadows, as built** — an HTML-derived registry: six
  named gradient families with their measured values, the per-act ambient-glow table (geometry, hue,
  opacity, and the fact that Acts 3 and 5 have none and Act 1's is the only animated one), two mark
  gradients, and nine shadows with the CSS-to-SwiftUI radius conversion.
- `spec/20-primitives.md` §1 keeps *no gradient, no shadow* but says in as many words that it is a
  rule about **that primitive**, with **"do not go through the app deleting gradients"** on the line
  below.
- `app/Noop - Build Document.dc.html` §10.3 is retitled and opens by retracting the claim.

**The dead coach token is deleted, not re-pointed.** `coachSurfaceTop` `#18211E` /
`coachSurfaceBottom` `#121615` appear in no act source. The treatment on `today` and in `svea/coach`
is the **158° directional accent card** — `rgba(139,153,214,.16) → rgba(139,153,214,.03)` over a
0.5 pt `rgba(139,153,214,.30)` border, radius 20 on `today` and 24 in Act 7, with a 160° `.14 → .03`
radius-26 sibling for the brief card. Removed from `spec/swift/NoopPalette.swift` (with the reason
in place of the constants), struck through in `spec/10-tokens.md` and `spec/12-palette-bindings.md`,
and corrected at the call site in `spec/acts/41-act2-day.md` and `spec/acts/46-act7-svea.md`. A
token named *coach surface* whose value is a different composition is worse than no token.

## 6 · The missing visual primitives are in Swift

**Added to Swift, registered in the primitives index, and specified in the tokens registry.**
`spec/swift/NoopSpecPrimitives.swift` (five new treatments at the foot) ·
`spec/swift/NoopSpecMotion.swift` (their periods and their held states)

| | Type | Notes |
| --- | --- | --- |
| A | `NoopAmbientGlow` | hue, opacity, size, top, `pulses`. Blur 18, tail at 70 %, `allowsHitTesting(false)`. The nine-act table is in the header comment |
| B | `NoopAccentCard` | the 158° directional tint, with `.brief(hue:)` for the 160° variant. CSS-angle-to-unit-point conversion is done once, here |
| C | `NoopHeartbeat` / `NoopHeartglow` | **two separate six-stop tracks** at 0 / 9 / 18 / 27 / 42 / 100 %, driven off one date by `NoopPulse` so they cannot slip |
| D | `NoopLiveSessionGlow` | **210 × 150 at .52 s**, aura in zone and `effort` amber off target. Not a scaled copy of `day/heart`'s 120 × 90 |
| E | `NoopPulseTone.effort` | the **dimmer** variant, measured: peak 1.045 / .78 from a .40 floor, against resting's 1.05 / .80 from .45 |

- **Paused freezes.** `NoopPulse(paused:)` holds both tracks and keeps the glow on screen at full
  size; `NoopSpecMotion.pulsePausedFreezes` records the rule and the comment says why (a paused
  session still has a heart rate).
- **Reduce Motion is corrected throughout**: the orb holds at scale **1.0** while the phase word
  keeps advancing on its 4 s cadence; a pulse holds at scale 1.0 and its glow at its **trough**
  opacity rather than disappearing; the ambient pulse stops; the gauge shows its final value.
- **The + bloom and the tab glass are kept** and marked screenshot-match rather than rewritten.

## 7 · `NoopSpecOrb` corrected

**Corrected in Swift.** `spec/swift/NoopSpecPrimitives.swift` §11 / §11a

- **`opGlow` is applied to the charge-driven warm glow.** It was computed and used on layer 1 only,
  so the two Ø 268 glows sat on top of each other with one breathing and one flat — most visible at
  exactly the charge levels the layer exists for.
- **The two taps are mutually exclusive by construction.** The surround's hit region is a new
  `SurroundHitRegion` shape — the 306 × 318 block with the Ø 176 sphere subtracted, even-odd — so
  the regions do not overlap at all. The correctness no longer lives in z-order.
- **Both actions are exposed to accessibility.** Two elements, two labels: *Charge* (with the level
  as its value) on the block, *Breathe* on the sphere. The single `children: .ignore` element that
  labelled only Breathe made the route to Charge unreachable by VoiceOver.
- **One `NoopBreathPacer` phase timeline.** The phase word, the bpm (§11's RSA formula) and all five
  animation tracks are now pure functions of one start date read through one `TimelineView`, so they
  cannot drift. Reduce Motion does not stop the clock — it reads it every 4 s, which is the phase
  cadence, so the word advances while the scales hold. The sheen's 24 s rotation comes off the same
  clock and the `@State spin` is gone.
- **Sphere → Breathe and surround → Charge are preserved**, both plain taps, no long press.

## 8 · `NoopSpecTabBar` corrected

**Corrected in Swift and in the primitives spec.**

- **Act 6 is not "none active".** `ages` (entered from Trends) lights **Trends** in `#2ECC80` /
  `#04140C`; `health` (entered from You) lights **You** in `#F2B45C` / `#1E1405`. Both are 1.7 ×
  pills, so the width always divides by 4.7. The hue table gains both rows and the "nothing lit"
  paragraph is replaced; `nil` survives as a defined behaviour with a note that no shipping act
  passes it.
- **Active/inactive ink reaches the icons.** `NoopSpecTabDestination` forces
  `renderingMode(.template)` and the item applies `foregroundStyle(on ? onAccent : textDim)`. A lit
  tab used to ship a grey glyph inside a saturated pill.
- **Hit testing is implemented**, not just documented: `allowsHitTesting(false)` on the container,
  `true` on the bar row. Without the first, the floating block is an invisible lid over the last row
  of content on every home screen.
- **"The + opens the log sheet" is gone**, replaced by the nine-row table.
- **`NoopGlass` is documented honestly.** It states plainly that **public UIKit accepts no blur
  radius** — `UIBlurEffect` takes a named style and `Material` takes no parameter — so 20 pt cannot
  be implemented as a number by any public API. What ships is the `UIVisualEffectView` /
  `.systemUltraThinMaterialDark` approximation, the 20 pt is a measurement to check against, and the
  adjustable value is `tabBarFill`'s 82 % opacity. The private-`CAFilter` route is **not
  recommended and not documented as an option**; the previous text described it before forbidding
  it, which is still a recommendation.

## 9 · `NoopSpecSheet` corrected

**Corrected in Swift and in the primitives spec.** Four presentations, not one:

| Kind | Where | Cap | Scrolls inside |
| --- | --- | --- | --- |
| `.log` | Acts 1, 2 — the + | its content | no |
| `.panel74` | Act 4 — *Everything you logged* | **74 %** | **yes** |
| `.panel76` | Act 9 — the instrument's sheet | **76 %** | **yes** |
| `.add` | Act 5 — the + on `you` | **none at all** | no |

- **Required internal scrolling** on the two capped panels and none on the two that are their
  content's height.
- **No first-presentation zero-height flash.** The 102 % offset is derived from a measured height,
  so on the first present the height is still 0 and the sheet appeared at its final position without
  travelling. It is now held at zero opacity until measured once.
- **Hidden sheet content is hidden from accessibility.** `accessibilityHidden(!isPresented)` — the
  sheet stays mounted so its filters survive open and close, which is exactly why VoiceOver was
  reading a closed sheet's Save over the screen behind it.
- **Scrim and sheet appear on their specified clocks**: the panel family's scrim on
  `NoopSpecMotion.sheetScrim` (.22 s ease), the sheet on .30 s; the log sheet's scrim arrives with
  the sheet.
- **.34 s → .30 s.** `NoopSpecMotion.sheet` now matches every act source's `sheetUp .3s`, and
  §20 §14 says which value moved and why.

## 10 · Shared controls and type

**Corrected in Swift and in the primitives spec.**

- **Toggle:** the two curves are attached to the two layers — `toggleTrack` on the track fill,
  `toggleKnob` on the knob offset. Stacked on the whole control, the outer modifier governed the
  subtree and the split timing silently did not ship.
- **Button pressed state:** a real one, in a new `NoopButtonStyle` — **white 7 % → 10 %, 120 ms, no
  scale**. It cannot be done from a `Button` body, which is why the old `@State private var pressed`
  was never written to.
- **Height, radius, accent and ink are parameters.** `Kind` supplies defaults only; the doc comment
  lists the five real buttons (42/14, 44/15, 48/17, 52/18, 54/18 amber) that one blue 48 pt button
  could not represent.
- **The back control is 34 × 34 visually with a 44 × 44 target**, the extra padding cancelled in
  layout so the header's 18 pt inset and 12 pt gap still measure off the circle.
- **Dynamic Type caps and role behaviour are implemented**, not just described: a new `NoopRole`
  type carries face, size, text style, tracking **in ems**, CSS line height and a `cap`, and
  `NoopTextRole` applies the cap with `.dynamicTypeSize(...cap)`. Fixed roles have no text style and
  do not scale, which is stated as role behaviour with the reason.
- **Line spacing is recalculated from the scaled size.** `NoopRole.lineSpacing(at:)` reads
  `\dynamicTypeSize`, scales the size through `UIFontMetrics` under the role's cap, and recomputes —
  every previous call site passed the base size, so a role scaling 13.5 → 20 set solid.
- **Instrument Serif is corrected**: used inside the app and **not Act-1-only**; the header names
  the other places the italic runs.
- **Nine faces, not seven.** The registration doc comment, the validation comment and the
  `FontFile` note now separate the three counts they were conflating: **nine faces**, **four files**,
  **seven named instances** inside the two variable ones. Also corrected in
  `StrandDesign/Resources/Fonts/README.md`.

## 11 · Charge implementation boundaries

**Corrected in Swift.** `spec/swift/NoopChargeGauge.swift`

- **`NoopChargeGauge` follows its input after first appearance.** A new `onChange(of: charge)` moves
  `shown` on `chargeBar`'s 500 ms and an `arrived` flag stops it **replaying the arrival drain** —
  that animation means *this is what you have spent since you woke*, and running it on an update
  tells the same story twice. `shown` was set in `onAppear` and nowhere else, so a sync landing
  while Today was up left the ring on the old value under a sentence reading the new one.
- **Clamped at both 0 and 1** — the gauge (`clamped(_:)` on charge and wake), both bar fills, and
  the battery chip's `pct` (used for the fill width, the tint thresholds, the label and the
  accessibility value). `min(…, 100)` alone clamped the top and let a disconnected strap's −1
  through.
- **Demo data needs both gates.** `NoopCharge.demoSeed(...)` is `#if DEBUG` **and** returns `nil`
  unless `--demo-seed` is present (`isDemoSeeded`), so its return type is optional and a caller that
  force-unwraps has visibly removed the gate.
- **No release fallback invents a value** — stated as a comment where someone would add one: no
  `.placeholder`, no `.preview`, no default `charge: 50`, and no non-DEBUG path to the arithmetic.

---

# P1 — notifications

## 12 · Stale firmware claims removed

**Corrected in specification and in the pack documents.** The notification screen ships **`[later]`**:
no permission request, no *saved to strap* claim, no strap-battery cost, no active configuration
controls.

| File | Change |
| --- | --- |
| `spec/acts/44-act5-plumbing.md` | the **"about four percent"** footnote is deleted and replaced with the reason a figure for an unbuilt feature cannot be guessed; *Controls — the design, held for the firmware* → *recorded, and **not built in this release***, with what actually ships listed; the *saved to strap* bullet no longer names a transport |
| `spec/50-wiring.md` | Part 1 §4's firmware bullets rewritten: the mirroring work **has no owner**, and this sheet names no transport, because a named transport in a design document reads as a commitment someone made |
| `spec/README.md` | the ANCS open question → *notification mirroring has no owner*, with Smart Alarm called out as unaffected |
| `WHAT-YOU-ASKED-FOR.md` | the *"both `automations` and `notifs` are editing device configuration — the set syncs to strap firmware"* paragraph is replaced with a correction of itself |
| `app/Noop - Build Document.dc.html` | the `notifs` inventory row states the Later scope |

**Smart Alarm is untouched and keeps its claim.** It arms the strap's own alarm, it is the one
feature that genuinely works with Noop closed, and every file above says so in the same breath as
the removal — precisely so the next pass does not delete it as another firmware claim.
`spec/acts/40-act1-night.md` and `spec/60-parity.md`'s Smart Alarm entries are unchanged.

---

# P2 — pack consistency

## 13 · Stale counts and contradictions

**Corrected across specification, pack documents and one HTML notes column.**

| Claim | Now | File |
| --- | --- | --- |
| "the twelve things" in `00-RULES` | **thirteen** rules, §1–§13, with §0 named as the legend rather than a rule | `spec/README.md`, `app/Noop - Build Document.dc.html` |
| "the five Swift files" | **six** | `spec/README.md`, `spec/10-tokens.md` |
| missing screens: one *and* two | **one** — Beat Rhythm. "19 to 2" → "19 to 1" | `WHAT-YOU-ASKED-FOR.md` |
| Act 1 as four screens | **five** | `app/Noop Act 1 - The Night.dc.html`, `spec/60-parity.md` |
| `NoopPalette` holds motion durations | it holds colour and metrics only; the durations are `NoopSpecMotion`'s | `spec/13-branch-corrected-foundation.md`, and `NoopPalette.swift`'s own header |
| "replacement/rename" vs "new type, not a rename" | both README banners now point at `CLOSURE.md`; the rename correction in `13-branch-corrected-foundation.md` §*The name* stands and is not contradicted | `README.md`, `WHAT-YOU-ASKED-FOR.md` |
| "only two confirmations in the app" | **no global count.** Each confirmation is specified beside the behaviour that needs one — ending a live session, forgetting a strap, deleting data, turning sensitive journal topics on, saving a goal the data will not back | `spec/acts/42-act3-effort.md` §3.4, `spec/acts/44-act5-plumbing.md` §5.7, `spec/acts/46-act7-svea.md` §7.4, `spec/acts/47-act8-goals.md` §8.2 |
| `WHAT-YOU-ASKED-FOR` says notification firmware exists | corrected in place, item 12 | `WHAT-YOU-ASKED-FOR.md` |
| `NoopSpecType` says seven faces | **nine**, with files and named instances separated from faces | `spec/swift/NoopSpecType.swift`, `StrandDesign/Resources/Fonts/README.md` |
| "11 decided screens" over twelve categories | no such total survives; the inventory states its split (5 · 12 · 7 · 4 · 21 · 5 · 5 · 6 · 4 = 69) so a miscount is visible on the page | `app/Noop - Build Document.dc.html` §7 |

**Confirmation counts are not replaced with a new number.** The instruction was the right one: a
global count is a claim about the whole app that any new screen falsifies, and it has now been wrong
twice. Each confirmation is stated where the behaviour is.

## 14 · The release data rule, in one place and referenced

**Added to specification.** `spec/00-RULES.md` gains **§0a · The release data rule**, ahead of every
other rule: every word, measurement and derived value in a release build has a real source or a
defensible calculation; prototype values live **only behind both `#if DEBUG` and `--demo-seed`**; and
the things that may not leak are listed by name — fake API key, OCR result, health or body-age score,
charge, pulse, session measurement, strap battery, notification count. Where the value is absent the
screen renders its **specified absent state**.

It is enforced at three call sites in this pass: `NoopCharge.demoSeed` (item 11), Act 7's key row
(*with nothing stored the row reads "Not set" and Test is inert*, §7.3), and Act 8's by-hand route
(*no invented OCR results*, §8.4). `spec/50-wiring.md` Part 1 §5 carries the strongest form of it,
because that screen exists to be trusted.

## 15 · Fonts remain an open prerequisite

**Not closed, deliberately, and listed as open.** The pack ships the three OFL licences and
`StrandDesign/Resources/Fonts/README.md`; it does **not** ship `Outfit.ttf`, `InstrumentSans.ttf`,
`InstrumentSerif-Regular.ttf` or `InstrumentSerif-Italic.ttf`, because a design handoff cannot carry
binaries. `WHAT-YOU-ASKED-FOR.md` gains a section saying **font integration is not closed** — it is
an external coder prerequisite with written instructions, not a ticked item. The three load-bearing
notes in that README (`Bundle.module`, register-then-validate, call it twice) are unchanged, with the
face-count correction from item 10 applied.

---

# What could not be closed

**1 · The four `.ttf` binaries (item 15).** Not closeable from here. Listed as an open prerequisite
rather than marked done.

**2 · A fully generated route matrix (item 4).** All nine route conflicts are corrected and
`30-routes.md` is now the single authority, with every act file and the Build Document pointing at
it instead of restating it. Generating that table mechanically from the act sources is the right end
state and is outside what this pack can produce — so the duplication is *removed* rather than
*automated*, which fixes the drift but does not prevent a future hand edit from reintroducing it.

**3 · The new and rewritten Swift has not been compiled.** Unchanged from the last pass and it now
covers more code: §10, §11 / §11a, §14, §15, the five visual treatments, `NoopRole` / `NoopTextRole`
and `NoopButtonStyle` are all written against the spec and the sources. **The geometry and the
timings are what is binding, not the SwiftUI spelling** — if something has to change to build,
change the code and tell us.

---

# Regenerated standalone — hash verification

`Noop app - standalone (open me).html` was regenerated from `app/Noop - Full App.dc.html` after every
change above. The bundle stores each source gzipped and base64-encoded in its manifest; each entry
was decoded and compared to the file on disk as a whole string.

**All nine acts are embedded byte-for-byte.**

| Act | Bytes | SHA-256 of the source file | Embedded |
| --- | --- | --- | --- |
| 1 · The Night | 91,906 | `cbfab59db2a28973347a6e9678f290eb5b9a9aefdb932611671a163eb649e5b4` | exact |
| 2 · The Day | 152,780 | `bedf39d3f52db627416a962a3f2a5402cee9080fb9976cdc79b3d5dd0f064f7e` | exact |
| 3 · The Effort | 85,409 | `5099a288a395cfb6a93bd39daee9b5ed308bd7ea79438a465079b3ce8398ff49` | exact |
| 4 · The Bigger Picture | 80,836 | `160b236487de17a07ea6fc02af7999d6a761ea446f3b62b2576f29de9e5a5def` | exact |
| 5 · The Plumbing | 213,462 | `48ed6f5b7746ac94bb57d0d724e067cae1dd3c8b1bd491e68d5485a0bdf4952d` | exact |
| 6 · Your Ages | 78,563 | `fb5b3e2b1c2e5c4466b387f422849ca009cd2dc9f8d756b6869c8fccba0a6be5` | exact |
| 7 · Svea | 75,238 | `65f499fa97c478d67b3af10f4f49ff93630b40fe4cdaac178123be8580bd349e` | exact |
| 8 · Goals and Labs | 93,490 | `507cded532ef8efb9d9418383567f54b5fe2b6d047c229aad3e37ac31bd70b22` | exact |
| 9 · The Instrument | 89,040 | `21054767677600cb692ba888d97a75c93a0f05871c01da5b7ca3d55a8a4caf90` | exact |

To re-verify after any edit: hash the file in `app/` and compare against this table; a changed hash
without a regenerated standalone means the two have diverged. `ios-frame.jsx` and `noop-gauge.js`
sit beside the standalone at the pack root, as before — the bundler does not inline an `x-import`
reached through a sibling component, so those two files travel with it.

---

# Files changed in this pass

**HTML (authoritative, changed first)**
`app/Noop Act 1 - The Night.dc.html` · `app/Noop Act 5 - The Plumbing.dc.html` ·
`app/Noop Act 6 - Your Ages.dc.html` · `app/Noop Act 7 - Svea.dc.html` ·
`app/Noop Act 8 - Goals and Labs.dc.html` · `app/Noop - Full App.dc.html` ·
`app/Noop - Build Document.dc.html` · `Noop app - standalone (open me).html` *(regenerated)*

**Specification**
`spec/00-RULES.md` · `spec/10-tokens.md` · `spec/12-palette-bindings.md` ·
`spec/13-branch-corrected-foundation.md` · `spec/20-primitives.md` · `spec/30-routes.md` ·
`spec/32-nav-addendum.md` · `spec/34-implement-31-august.md` · `spec/50-wiring.md` ·
`spec/60-parity.md` · `spec/README.md` · `spec/acts/41-act2-day.md` · `spec/acts/42-act3-effort.md` ·
`spec/acts/44-act5-plumbing.md` · `spec/acts/45-act6-ages.md` ·
`spec/acts/46-act7-svea.md` *(rewritten)* · `spec/acts/47-act8-goals.md`

**Swift**
`spec/swift/NoopPalette.swift` · `spec/swift/NoopSpecMotion.swift` ·
`spec/swift/NoopSpecPrimitives.swift` · `spec/swift/NoopSpecType.swift` ·
`spec/swift/NoopChargeGauge.swift`

**Pack documents**
`README.md` · `WHAT-YOU-ASKED-FOR.md` · `StrandDesign/Resources/Fonts/README.md` ·
`CLOSURE.md` *(this file)*

---

# Third pass — 9 September, four designer answers

Bounded on request: **only** the four source-of-truth questions were answered, and nothing else in
the pack was reopened or re-audited. Full reasoning and tables in
**`spec/48-designer-answers-9-september.md`**, which is authoritative for these four items.

| # | Question | Answer | Landed in |
| --- | --- | --- | --- |
| 1 | API-key states | Five states — *Not set* / *Entry* / *Set* / *Testing* / *Answered* · *Failed*, with three named failures. **Replace opens the input**, the mask is **derived from the saved string** (no literal suffix), and **no latency is shown anywhere** — `1.2s` is gone with nothing in its place | `app/Noop Act 7 - Svea.dc.html` · `spec/acts/46-act7-svea.md` §7.3.2 · `spec/50-wiring.md` |
| 2 | Manual lab entry: four or nine | **Nine**, and they are the nine markers `labs` keeps — Haemoglobin and Creatine kinase added with bands, so the ring reads *of 9 in band* and a typed value always has somewhere to live. Rows start collapsed, one input open at a time. The photo route still shows **whatever the sheet printed** (four in the demo sheet) | `app/Noop Act 8 - Goals and Labs.dc.html` · `spec/acts/47-act8-goals.md` §8.4 |
| 3 | Goal safety mathematics | One formula — `(peak ÷ now) ^ (1 ÷ building weeks) − 1`, building weeks = weeks − 2 easy − 1 taper — against **5 % absorbed / 10 % ceiling** from this person's own blocks. The three verdicts differ in one input, the peak the finish requires: **4.4 % · 6.2 % · 10.4 %**. `12%` and `19%` are gone, and **no build figure is written into copy** | `app/Noop Act 8 - Goals and Labs.dc.html` · `spec/acts/47-act8-goals.md` §8.2.3 |
| 4 | Proactive Svea | Release default **`never`**. Trigger-based, never-promised delivery (*first wake after 04:00 — usually before you are up, sometimes not at all*), nothing queued or retried. Limits: **one a day** / **one an hour, six a day, none 22:00–wake**. **Never on the row revokes; a voice of Off pauses and restores** | `app/Noop Act 7 - Svea.dc.html` · `spec/acts/46-act7-svea.md` §7.3a–b · `spec/50-wiring.md` |

**One fix outside those four**, because it blocked verifying item 1: Act 7's render crash —
`voiceOff` was read above its own declaration — is fixed by hoisting the declaration. Every other
mechanical HTML/Swift correction on the coders' list remains theirs.

**Files changed in this pass**
`app/Noop Act 7 - Svea.dc.html` · `app/Noop Act 8 - Goals and Labs.dc.html` ·
`Noop app - standalone (open me).html` *(regenerated from `app/Noop - Full App.dc.html`)* ·
`spec/48-designer-answers-9-september.md` *(new)* · `spec/acts/46-act7-svea.md` ·
`spec/acts/47-act8-goals.md` · `spec/50-wiring.md` · `README.md` · `CLOSURE.md`

**Hashes**: the SHA-256 table above predates this pass and no longer matches Acts 7 and 8 or the
standalone. The standalone was regenerated after the last edit and its nine acts were checked to
render; re-hash from the files in `app/` if you need a fresh table.

**Still not closed**, unchanged: the four `.ttf` binaries, the uncompiled Swift, and the fact that
nothing mechanically prevents a hand edit from reintroducing a duplicated route matrix.
