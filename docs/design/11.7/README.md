# Handoff: Noop Aura 11.7

**Date:** 20 September 2026
**Supersedes:** `design_handoff_8_september`
**Repo:** `gdorgian/noop`, branch `main`
**Against:** `spec/90-aura-11.7.md` §13

---

## What this is

Everything design has drawn for 11.7, plus the implementation spec pack the
drawings are specified against, plus the two working documents that record
what was decided and why.

**Nothing in here is blocking.** Six build-time items sit with engineering and
are listed at the end of this file and in full in
`notes/FOR ENGINEERING - Noop Aura 11.7 open items.txt`.

## About the design files

The `.dc.html` files are **design references**, not production code. They are
prototypes: real interactions, real copy, real measurements, running in a
browser. The task is to **recreate them in the iOS app** using its existing
SwiftUI patterns, `StrandDesign` components and `NoopPalette` — not to port
the HTML.

Open any of them directly in a browser. They are self-contained apart from
`app/support.js`, which must sit beside them.

## Precedence

**The HTML wins everywhere, including behaviour.** This is the owner's rule and
it has not changed. Where a drawing and a written spec disagree, the drawing is
right and the spec file needs correcting.

One qualification: a *fake* or *contradictory* destination in a drawing is a
question about that destination. It is not a licence to fall back on the
written spec, and not a licence to generalise from it.

**Every user-facing string is written once, in the act or artefact file it
belongs to.** Lift copy from those files, never from this README and never from
the summary documents — those paraphrase, and a paraphrase that reaches a
screen is a bug nobody can trace.

## Fidelity

**High.** Final colours, type, spacing, measurements and copy. Recreate the UI
to match. Where a drawing states a pixel value, it is a measured value and not
an approximation.

---

## What changed in 11.7

Five waves. If you built from the 8 September handoff, this is the delta.

### Wave 4/5 · The app icon set — geometry corrected twice

`app/Noop Icon Set.dc.html`

Five icons: **Titanium** (default), **Aura**, **Navy**, **Breathe**, **Orb**.

The mark's geometry is now `Tools/make_icon.py`'s own constants, confirmed by
engineering on 19 September and measured against the shipped 1024 to within a
pixel. On a 1024 tile, centre (512, 512):

| | Fraction of tile | px |
| --- | --- | --- |
| Ring outer radius | 0.39 | 399.36 |
| Ring stroke width | 0.135 | 138.24 |
| Core dot radius | 0.090 | 92.16 |

The arc is **302°**, the gap **centred at twelve o'clock**, cap centres 29°
either side of top, caps **round** at half the stroke — so the visible gap draws
at 33.9°, not the 58° between cap centres.

Two earlier design numbers were wrong and are corrected: the gap is *not*
tilted 23° off the vertical, and the ink is 302°, not 280.5°. Both errors came
from design's angular scan of a PNG rather than from the script. Anything
quoting a 337° gap centre is stale.

Ring gradient runs along the sweep, not across the tile: `#FCEBA8` at the pale
cap (upper-left), `#E8B84B` at the bottom, `#C8902F` at the deep cap
(upper-right). Core `#E8B84B` with a 35% `#FCEBA8` sheen over its upper part.
Ground `#0A1322` → `#05080F` vertical, plus a 60% `#17263E` glow centred
halfway across and 40% down, reaching 72% of the tile.

Navy is the shipped file and re-renders from the repo's script. Breathe and Orb
must be **exported from the app's own orb source**, frozen — Breathe at the top
of an inhale. Two orbs maintained separately drift silently; if they cannot
share a source, ship four icons.

Blued A does not ship. `make_icon.py` draws Blued B only; A has no generator, a
different ring and its gap elsewhere.

### Wave 4 · Terms and the first-launch gate

`app/Noop Act 5 - The Plumbing.dc.html` → `plumbing/terms`

At **version 2.0**. The nine section headings are verbatim from `TERMS.md`. The
preamble and the closing note are printed **unnumbered** — they frame the
document rather than being part of it, which is what keeps "the nine sections"
true in the attestation.

**The document and the gate say "Noop Aura". The app stays "Noop".** That
divergence is deliberate, not a half-finished pass.

Two sections changed between 1.1 and 2.0 — **07 and 08**, and only those:

- **07 Your acknowledgment** — rewritten. One blanket box became four
  statements, each ticked on its own before Accept unlocks.
- **08 WHOOP personnel** — retitled and changed. The polite request is now
  backed by the first statement in §7.

The gate's four ticks are **§7's four, not design's**: not WHOOP staff; own
device, own data, own risk; unofficial, as-is, not a medical device; liability
waiver. Design's earlier "I have read these terms" tick is gone — it was not in
the document, and nothing gated on reading anyway.

Accepting records **which version and when**, on the device. The gate line says
so. If the app does not write that record, tell design and the line comes out.

Nothing gates on scroll depth. How far someone scrolled is not consent.

### Wave 4C · The lift live activity

`app/Noop Lift Live Activity.dc.html`

Lock Screen card, three Dynamic Island presentations, and the in-app bar on
`lift-live`, all reading **one live session object**. Four states each
(working, resting, ready, paused) plus the Lock Screen's fifth face.

- **Paused freezes, it does not hide.** The clock stays at its held value in
  `#7F8A85`. Hiding it reads as a reset, and a wearer who believes the set
  timer reset will redo the set.
- **The numbers slot is absent** where neither reps nor weight is known — not a
  pair of em dashes. The status line takes the width.
- **The exercise name takes the ellipsis.** The clock and set counter never
  truncate at any size.
- **No controls.** No pause, next set or finish. Deliberate: a Finish button an
  inch from a Lock Screen swipe is a lost session.

### Wave 5 · The heart rate live activity (`NOOPLiveActivity`)

`app/Noop Live Heart Rate Activity.dc.html` — **new**

Sibling of the lift activity: same four slots, same inks, no controls. Built on
the one fact the lift version does not face — a live activity gets an **update
budget**, not a stream.

- **Every reading carries its age.** Seconds, then minutes. Never a bare
  figure; a bare figure claims a freshness the budget cannot supply.
- **No reading means no figure.** The element is not rendered and the status
  line takes the width with the last value and its time. Not greyed, not
  dashed, not held.
- **No sparkline, at any size.** Four points a minute drawn as thirty seconds
  of line is an invention shaped like a measurement.
- **One amber face**, over the ceiling only, and gated on the wearer having
  turned the ceiling on — not on the value.
- **Minimal has three faces, not four.** Resting and working are the same
  answer to the only question that slot can ask.

The bpm is the **activity's own value** — the same one the today orb reads. Two
reads of the same stream drift, and they drift silently.

### Wave 5B · The accessory families

`app/Noop Accessory Widgets.dc.html` — **new**

The five families that do not reduce to the gauge mark: Glanceable, the coach
brief, resting pulse, stress, the lift session.

The governing constraint is not size. Accessory widgets render **monochrome**,
so all three of the set's colour rules stop working at once — amber no longer
means needs-attention, periwinkle no longer marks generated prose, blue no
longer means live. Each has to become a word or leave.

**The accessory mark** is a **closed ring with no core**, at the family's own
0.135 stroke with a 1.5 pt floor. This is a scoped divergence from the icon
set's "open ring reads, closed ring acts" — that rule governs the app icon set,
where Breathe sits beside the instrument in Appearance. Nothing here sits
beside Breathe, so the distinction has no work to do, and closing the ring buys
back the legibility the core cost. It is a **label glyph**: it leads the inline
line and labels the circular, and it never appears alone.

**Ten of fifteen placements are filled. Five are refused, with reasons on the
sheet.** Do not register the refused ones — a family offering a placement it
cannot fill honestly is worse than one offering fewer.

### 20 September · Caption contrast pass

`#57605C` measures **3.0:1** on `#0A0C0B`. No size of type passes with it, and
it was carrying 11 pt captions across thirty files.

**`NoopPalette.textDim` is retired for type.** Roughly 250 instances now use
`textQuiet` (`#7F8A85`, 5.5:1), which was already the tertiary ink in most of
those files — so the pass shortened the ramp rather than adding to it.

The value survives under a **new name, `chevronDim`**, for the row chevron's
1.5–1.6 pt stroke only: a graphical object, fine at 3:1.

`spec/swift/NoopPalette.swift`, `spec/10-tokens.md` and
`spec/12-palette-bindings.md` all agree as of 20 September. **If the codebase
references `textDim` for type, that is a contrast failure, not a missing
token.**

---

## Design tokens

Canonical source: `spec/10-tokens.md`, `spec/12-palette-bindings.md`,
`spec/swift/NoopPalette.swift`. Bind against them; do not retype values.

The ink ramp, after the pass:

| Role | Value | Contrast on `#0A0C0B` |
| --- | --- | --- |
| Primary | `#EDF1EF` | 15.9:1 |
| Secondary | `#C6CEC9` | 11.0:1 |
| Tertiary | `#939C97` | 6.6:1 |
| Quiet · **captions** | `#7F8A85` | 5.5:1 |
| Kickers, uppercase labels | `#6C7570` | 4.1:1 — headline-scale and uppercase only |
| ~~Faint~~ | ~~`#57605C`~~ | **retired for type** |
| Row chevron (graphical) | `#57605C` as `chevronDim` | 3.0:1, permitted |

Accents: aura `#17A2E6` and `#8FD3F5` · lavender `#8B99D6` / `#A9B4E0` ·
amber `#F2B45C`. **Amber means something needs you**, everywhere, and nothing
else may use it.

Disabled / frozen ink: `#7F8A85`.

---

## The files

### `app/` — the drawings

| File | Covers |
| --- | --- |
| `Noop.dc.html` | The app shell |
| `Noop - Full App.dc.html` | Every act in one frame |
| `Noop Act 1 - The Night.dc.html` | Sleep, the night, tonight |
| `Noop Act 2 - The Day.dc.html` | Today, charge, vitals, stress, live HR |
| `Noop Act 2 - Breathe.dc.html` | The catalogue, pacer, sweep and result |
| `Noop Act 3 - The Effort.dc.html` | Sessions, detail, aggregate |
| `Noop Act 4 - The Bigger Picture.dc.html` | Trends |
| `Noop Act 5 - The Plumbing.dc.html` | Settings, plumbing, widgets, appearance, **terms**, what's new |
| `Noop Act 6 - Your Ages.dc.html` | The age estimates |
| `Noop Act 7 - Svea.dc.html` | The coach, consent, voice, prompts, ask-about-a-chart |
| `Noop Act 8 - Goals and Labs.dc.html` | Goals, journey, lab markers |
| `Noop Act 9 - The Instrument.dc.html` | The instrument and its range control |
| `Noop Act 10 - The Lift.dc.html` | The session, `lift-live`, edit, review, the in-app bar |
| `Noop Lift Live Activity.dc.html` | All four lift presentations |
| `Noop Live Heart Rate Activity.dc.html` | All four heart rate presentations |
| `Noop Widgets - the Aura set.dc.html` | All eight widget families, populated and empty |
| `Noop Accessory Widgets.dc.html` | The accessory mark, ten Lock Screen placements, five refusals |
| `Noop Icon Set.dc.html` | The five app icons and their geometry |
| `Noop Screen Map.dc.html` | Every screen and how it is reached |
| `Noop - Build Document.dc.html` | Primitive measurements at true size |
| `Noop Spec Browser.dc.html` | Redline sheet, primitives at true size |
| `Noop Confidence - *.dc.html` | The confidence chip and its hue ramp |
| `Noop Motion Pass - Six Curves.dc.html` | Durations and easings |
| `Noop Nav Patch - Visual.dc.html` | Navigation corrections |
| `Noop Plumbing - Import and Backup.dc.html` | The import flow and backup |
| `Noop Labs *.dc.html` | Lab review, the strip, the DNA hero |
| `Noop day-charge - *`, `Noop night-tonight - *` | Charge drivers, the smart alarm |
| `Noop You - What We Will Not Ask.dc.html` | The five positions |

### `spec/` — the implementation pack

| File | Covers |
| --- | --- |
| `00-RULES.md` | The fidelity rules, provenance legend, Dynamic Type reflow, nine states |
| `10-tokens.md` | Existing vs additive tokens; what to stop using |
| `12-palette-bindings.md` | Every `NoopPalette` property with its value |
| `20-primitives.md` | The fourteen primitives, incl. §15 the confidence chip |
| `30-routes.md` | Routes, back maps, tap targets, sheets, surviving state |
| `32-nav-addendum.md` | Navigation corrections |
| `acts/40…47` | Every screen, act by act |
| `50-wiring.md` | Every bound value → the repo symbol that feeds it |
| `60-parity.md` | The screens vs the shipping app |
| `swift/*.swift` | Additive `StrandDesign` sources |

### `notes/` — what was decided, and what is still open

| File | Covers |
| --- | --- |
| `FOR ENGINEERING - Noop Aura 11.7 open items.txt` | **Read this second.** The six build-time items, and the answers already folded in |
| `Noop Aura 11.7 - wave 4 drawn.txt` | The running design log for 11.7, including the reasoning behind each late correction |
| `Noop Aura - Act 10 implementation pack -for coders-.txt` | Act 10 in coder terms |
| `Noop Aura 11.7 - status and what is left.txt` | Wave-by-wave status |
| `DESIGN REPLY - Noop Aura 11.7 seven calls answered.txt` | Design's answers to engineering's seven questions |

### `assets/`

`blued-b-navy-1024.png` — the shipped Navy icon, the reference the geometry was
measured against. `blued-a-brushed-titanium-1024.png` — Blued A, archive only,
does not ship.

---

## Still open — six build-time items, none blocking

1. **Bind the per-release change list.** `AppChangelog.swift`, 278 releases.
   Confirmed flat by version with year dividers only, and drawn that way. Needs
   wiring: version → entries, sorted deterministically.
2. **Make the momentum filter a named list.** Lift the card-kind set out of the
   factory switch into one named, explicit list, so a cut kind cannot return as
   a merged switch case. Confirmed *not* month-grouped — the 243-in-one-month
   figure is an import artefact.
3. **Bind the widget count to the registry.** Two places in
   `settings → plumbing → Widgets`. Eight families, named on the screen:
   Glanceable · Live heart rate · The coach brief · Resting pulse · Stress ·
   Lift session · Energy (new) · Rings (new). Resting pulse is a new build, not
   a rename. If the bundle registers a different set, the list changes, not
   just the digit.
4. **Export the Orb icon, do not re-draw it.** Same source as Svea's orb in
   Act 7 — same silhouette, gradient stops and bloom.
5. **One session object for the lift activity**, not four clocks. Lock Screen,
   three Dynamic Island presentations and the in-app bar in the same tick.
6. **The heart rate activity's figure must be the activity's own value** — the
   same one the today orb reads.

Plus the palette change above: **`textDim` no longer exists for type.**

Questions on any of this go back to design rather than getting resolved in
code. Most of them look like copy questions and are actually decisions.
