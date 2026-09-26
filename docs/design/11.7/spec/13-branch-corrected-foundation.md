# The branch-corrected foundation

*Foundations pack, 2c of 5. Written 7 September, after the coders reported that `1ecb5712` deleted
the whole Aura layer on the active branch and `f729e6c8` genuinely has no `AuraPalette.swift`.
Supersedes the placement instruction in `12-palette-bindings.md`; everything else in that file
— the values, `controlFill`, the two greens — still stands.*

---

## What I got wrong, and what actually happened

I read the fork at `829e7aa5`, where `AuraPalette.swift` is present, and concluded the build failure
was purely a module-placement bug. That was right about `829e7aa5` and wrong about your branch: the
commit you are on deleted the file. **Your diagnosis is correct — moving the five files into
`StrandDesign/Aura/` alone cannot compile.** I could not verify this myself; `f729e6c8` is not
reachable from the fork I can read, so the rest of this file takes your report as given.

Placement is still necessary — the files still belong in the package, for the reasons in
`12-palette-bindings.md` — it is just no longer sufficient.

## What ships with this file

**`spec/swift/NoopPalette.swift`** — a new, palette-only file. It goes at:

```
Packages/StrandDesign/Sources/StrandDesign/Aura/NoopPalette.swift
```

It is about seventy lines of constants and it shares a **name** with the deleted file and nothing
else. What it contains, and only this:

- the five surfaces (`canvas`, `card`, `cardBorder`, `controlFill`, `track`) and the two coach-card
  gradient stops
- the six-step text ramp plus `onAccent`
- the three hues (`accent`, `rest`, `effort`)
- `orbStops` — three stops, replacing the one thing the pack read off the old body-state type
- the metrics (four radii, `screenPadding`, `cardGap`, `breathDuration`, `sheenDuration`)

**Not restored, deliberately, as asked:** the old `AuraComponents`, `AuraCharts`, `AuraOrb`, the
Aura screens, and the old body-state type in every part — its four cases, its verdict / coaching /
session / rationale strings, its per-state ramps, glow and shadow values.

The last one is worth being explicit about, because it is the only place the redesign *needed*
something from the old layer. `10-tokens.md` used to point at that type's `restored.orbStops`. That
reference is now `NoopPalette.orbStops`, and the rest is not coming back on purpose: the old type
hard-codes **four** discrete body states, and this redesign **interpolates** — one scalar,
`NoopSpecTokens.chargeColor(charge:)`, drives the orb, the gauge ticks, the hero numeral, the state
chip and the bar. Two ramps in one app is how five elements end up disagreeing by a shade. The
verdict and instruction copy that lived on the old type is superseded by `70-copy.md` and the
generated-string tables of `Noop - Build Document.dc.html`; every functional reference to it in
`50-wiring.md`, `42-act3-effort.md` and `46-act7-svea.md` has been repointed.

### The name — and it is not a rename

**Nothing was renamed.** Correcting this because the pack said "renamed pack-wide to `NoopPalette`"
in three places, and that sentence sends a coder looking for a rename commit that does not exist —
or worse, looking for the old file to rename.

What actually happened: `1ecb5712` **deleted** `AuraPalette.swift` along with the rest of the Aura
layer. `NoopPalette.swift` is a **new file, written for this pack**, that supplies the subset of
values the redesign read off the deleted one. It shares a purpose with `AuraPalette` and nothing
else — not its type, not its members beyond the subset, not its component layer, not the body-state
type. There is no migration path from one to the other and none is wanted.

So: the pack says `NoopPalette` because that is the only palette it has ever shipped with. The name
is not inherited and not a substitute for the old one; the old system was removed on purpose, and
keeping its name would have left the ambiguity behind. Every remaining mention of `AuraPalette` in
the pack is **historical**, in a sentence that says so.

### It has no dependencies

Every value in it is an explicit 0–255 sRGB literal through a private helper, so it does **not** use
`Color(hex:)` and cannot collide with the `public extension Color` in `Palette.swift`.

`NoopSpecTokens` does use `Color(hex:)`, which you have confirmed survives as public in
`Packages/StrandDesign/Sources/StrandDesign/Palette.swift`. Nothing further to do there.

### After this, the compile order is

1. Move the six files (the five spec sources + `NoopPalette.swift`) into
   `Packages/StrandDesign/Sources/StrandDesign/Aura/`.
2. Delete `NoopUI/Spec/`.
3. No `project.yml` edit and no new target **for these six sources** — `Package.swift` declares no
   `sources:`, so SPM globs the directory. Both app targets and `NOOPiOSWidgets` already link
   `StrandDesign`. (The font move below *is* a project change; do not read this line as covering it.)
4. `import SwiftUI` on all six is then complete.

---

## The fonts — three separate problems, all real

### 1. Wrong bundle

`00-RULES.md` §6 was right that the files belong in `StrandDesign`'s resources and did not say why,
so it read as a preference. It is not. `NoopSpecType.registerFonts()` looks in `Bundle.module`,
which is the **package** bundle — it cannot see `StrandiOS/Resources/Fonts`, so with the files where
they are today registration finds nothing no matter what it is named. And `NOOPiOSWidgets` links
`StrandDesign` without linking the app, so a Charge widget built against app-target fonts renders in
San Francisco even once the app itself is fine.

Move them to:

```
Packages/StrandDesign/Sources/StrandDesign/Resources/Fonts/
```

`Package.swift` needs no edit — it already declares `resources: [.process("Resources")]`. **The app
project does.** Delete the files from `StrandiOS/Resources/Fonts`, remove their `UIAppFonts` entries
from the `Info.plist` (i.e. from the `properties:` block in `project.yml` that generates it), remove
any app-target resource reference to that folder, then `xcodegen generate`. Leaving the old entries
in means the app registers the same faces twice by two different mechanisms — `UIAppFonts` and
`CTFontManagerRegisterFontsForURL` — and which one wins is a build-order accident. It also means two
copies that can drift to different versions of the same face.

### 2. Files are not faces — the registration loop could never have worked

The old loop iterated the seven **PostScript names** and looked for a `.ttf` named after each one.
You have two **variable files**, `Outfit.ttf` and `InstrumentSans.ttf`. No filename ever matched, so
`CTFontManagerRegisterFontsForURL` was never called, and then the `assert` fired on a font that had
not been given a chance to register. Registration is per *file*; `Font.custom` asks per *face*.

`registerFonts()` is rewritten to do it in the only order that works:

- register every font file it can find, static instances first, then the variable pair — looking
  both inside `Fonts/` and flat, because `.process` on a directory preserves the subpath in some
  toolchain versions and flattens it in others
- **then** validate the seven names
- and when one fails, print the names CoreText actually exposes for `Outfit` and `Instrument Sans`,
  so the next step is pasting a real name in rather than another round of guessing

It is idempotent and safe to call from `StrandiOSApp.init` next to the BGTask registrations.

### 3. Variable, settled — the two files ship

You inspected the files and confirmed both expose all seven required PostScript names, so the
variable pair is what ships and the static instances are not needed. What moves into
`Sources/StrandDesign/Resources/Fonts/`:

```
Outfit.ttf                    OFL-Outfit.txt
InstrumentSans.ttf            OFL-InstrumentSans.txt
InstrumentSerif-Regular.ttf   OFL-InstrumentSerif.txt
InstrumentSerif-Italic.ttf
```

Four font files, **three licences**. Outfit and Instrument Sans are the variable pair; **Instrument
Serif has no variable build and ships as its two static cuts** — and it is used *in the app*, not
only in the prototype's margins: `night/why`'s headline, `night/tonight`'s stop note, an italicised
measured phrase inline in both `why` variants, plus two reuses outside Act 1 that add no new role
(`day/bsweep`'s pacing cue at `serifNote`, and one inline italic word on `plumbing/imported`).
Three roles in `NoopSpecType`, listed in `acts/40-act1-night.md`.

**All three licence files ship with this pack**, at
`StrandDesign/Resources/Fonts/` — `OFL-InstrumentSerif.txt` was missing and is now written. SIL OFL
§5 requires the licence to travel with the font in every distribution, so a build-from-source fork
with the serif cuts and no serif licence is a redistribution violation, not a tidiness problem. A
package resource bundle is exactly where such a fork will look.

**The two `.ttf` binaries and the two serif cuts are not in this pack** and cannot be — they are
binaries. `StrandDesign/Resources/Fonts/README.md` names each file, its source and its SHA-check
step; drop the four files in beside the three licences.

`registerFonts()` registers by **filename** and validates the **faces** afterwards — the order the
old version had backwards. The static-instance path stays in the code as a no-cost fallback: if a
future font drop stops exposing a named instance, dropping the seven static files into the same
folder fixes it with no code change, and until then the loop simply finds nothing to register under
those names.

### 4. Registration has to happen twice

`Bundle.module` is per-process, and the widget is a **separate process**. One call in the app does
nothing for the extension. Call `NoopSpecType.registerFonts()` from both:

- `StrandiOS/App/StrandiOSApp.swift` — in `init()`, beside the BGTask registrations, before the
  first view is built
- the widget bundle's `@main` entry in `StrandiOSWidgets/` — same, in `init()`

It is idempotent and cheap, so calling it in both places costs nothing. Skipping the second is how
the Charge widget renders in San Francisco while the app looks right — and widget snapshots are
taken by the system when nobody is watching, so it is not a bug you notice quickly.

---

## Answered, and closed

1. **`Color(hex:)` survives**, public, in `Palette.swift`. `NoopSpecTokens` keeps using it.
2. **Not renamed — newly written.** `NoopPalette.swift` is a new file supplying the subset of values
   the redesign read off the deleted `AuraPalette`. "Renamed" was the wrong word in three places and
   is corrected above.
3. **Four files ship** — the Outfit/Instrument Sans variable pair plus Instrument Serif Regular and
   Italic — with all three OFL licences. The static one-file-per-face set for Outfit/Sans stays in
   the code as an unused fallback. Instrument Serif is app type, not commentary; the header that
   said otherwise is corrected.
4. **All ten reusable files survive** — `Hypnogram`, `OverviewHRChart`, `TrendChart`, `Sparkline`,
   `SportIcon`, `ProfileAvatarView`, `DayNavBar`, `NoopLiquidGlassSearchField`, `YearHeatStrip`
   and the `SettingsView` measurement fields. All are re-tint, not rebuild — with **one exception**:

   **`ProfileAvatarView` needs extending.** `44-act5-plumbing.md` claimed it already draws initials.
   It does not: its no-photo fallback is `BrandMark`. The design's no-photo state is the user's
   initials at `sectionHead` 19 in `blushSoft` on `tint(blush)`, and a brand mark in that slot
   makes an identity card read as a placeholder. Corrected in the act spec and in `50-wiring.md`,
   which now marks that row **extend** rather than wired.

## One precedence correction

The README said the written spec wins on **behaviour** and the prototype wins on **numbers**. That
is not the owner's rule and has been replaced throughout: **the HTML wins everywhere, including
behaviour.** Where an HTML destination is fake, dead or contradicts another screen, that is a
question about *that specific destination* — ask, and get an answer for it; do not fall back on the
written spec and do not infer a general rule from one broken door.
