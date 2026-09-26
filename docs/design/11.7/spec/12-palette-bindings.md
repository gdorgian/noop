# The palette bindings — `NoopPalette`, verbatim

*Foundations pack, 2b of 5. Rewritten 7 September for the post-`1ecb5712` branch. This file is the
canonical answer on colour identifiers. Where it and any other spec file disagree, this one wins.*

---

## The palette is `NoopPalette`, and this pack ships it

```
Packages/StrandDesign/Sources/StrandDesign/Aura/NoopPalette.swift
```

The old `AuraPalette` is gone — commit `1ecb5712` deleted the whole Aura layer, and nothing in this
pack depends on any of it. `NoopPalette` is a **palette-only** file, about seventy lines of
constants: five surfaces, the two coach-card gradient stops, the six-step text ramp, `onAccent`,
three hues, `orbStops`, and the metrics. No components, no screens, no body-state type, no copy, no
behaviour.

Every value in it is an explicit 0–255 sRGB literal through a private helper, so the file has **no
dependencies at all** — in particular it does not use `Color(hex:)` and therefore cannot collide
with the `public extension Color` in `Palette.swift`. (`NoopSpecTokens` does use `Color(hex:)`; that
extension is confirmed present and public.)

### It has to live in the package, not the app target

This is the second half of the original build failure and it still applies. `NoopPalette` is
`public` **in the `StrandDesign` module**. Put it — or any of the five spec sources — under an
app-target source path such as `NoopUI/Spec/` and `xcodegen generate` compiles them into `NOOPiOS` /
`Strand`, where the name is not in scope; the compiler says *cannot find 'NoopPalette' in scope*,
which reads exactly like a missing file.

All six files go in `Packages/StrandDesign/Sources/StrandDesign/Aura/`. Then:

- **`import SwiftUI` is complete.** Everything is same-module.
- **No `project.yml` change and no new target — for the Swift sources.** `Package.swift` declares
  `.target(name: "StrandDesign", resources: [.process("Resources")])` with no `path` or `sources`,
  so SPM globs everything under `Sources/StrandDesign/`. The **fonts** are a different matter: they
  move into that same tree, and their old `UIAppFonts` and app-resource references must be removed
  from `project.yml` / `Info.plist` and the project regenerated. `00-RULES.md` §6 has the steps.
- **`xcodegen generate` never sees them.** Package sources are compiled by SPM, not listed in the
  pbxproj. The failure mode cannot recur.
- Both app targets already carry `- package: StrandDesign`, and so does `NOOPiOSWidgets` — which
  matters for the Charge widget.

Delete `NoopUI/Spec/` afterwards.

---

## Every `NoopPalette` symbol, with its value

Bind to the property, never to the hex.

### Surfaces

| Property | Value | What it is |
| --- | --- | --- |
| `NoopPalette.canvas` | `#0A0C0B` | Scene base. Near-black, faintly green. |
| `NoopPalette.card` | `#141817` | Standard card fill. |
| `NoopPalette.cardBorder` | `Color.white.opacity(0.06)` | Hairline around a card. |
| `NoopPalette.controlFill` | `Color.white.opacity(0.07)` | The body of a control. See below. |
| `NoopPalette.track` | `Color.white.opacity(0.13)` | Unlit track — gauge ticks, pillar bars, week bars. |
| `NoopPalette.coachSurfaceTop` | `#18211E` | Svea card gradient, top. |
| `NoopPalette.coachSurfaceBottom` | `#121615` | Svea card gradient, bottom. The app's one card gradient. |

### Text

| Property | Value | The design calls it |
| --- | --- | --- |
| `NoopPalette.textPrimary` | `#EDF1EF` | primary |
| `NoopPalette.textSecondary` | `#939C97` | **tertiary** — the vocabularies disagree; see below |
| `NoopPalette.textTertiary` | `#8B958F` | label |
| `NoopPalette.textQuiet` | `#7F8A85` | muted |
| `NoopPalette.textFaint` | `#6C7570` | dim |
| `NoopPalette.chevronDim` | `#57605C` | row chevron only — retired for type, 3.0:1 |
| `NoopPalette.onAccent` | `#08120F` | ink on an accent **tint** |

The design's own *secondary* text (`#C6CEC9`) has no palette property and is
`NoopSpecTokens.textBody`. Ink on a **full-strength** accent fill is `NoopSpecTokens.onAura`
(`#04121A`), which is darker than `onAccent` on purpose.

### Hues

| Property | Value | Means |
| --- | --- | --- |
| `NoopPalette.accent` | `#17A2E6` | The strap, the day, live data, the primary action |
| `NoopPalette.rest` | `#8B99D6` | Sleep, night |
| `NoopPalette.effort` | `#F2B45C` | Needs attention. Never decoration |

### Metrics

| Property | Value |
| --- | --- |
| `NoopPalette.cardRadius` | `24` |
| `NoopPalette.tileRadius` | `22` |
| `NoopPalette.pillarRadius` | `20` |
| `NoopPalette.controlRadius` | `14` |
| `NoopPalette.screenPadding` | `20` |
| `NoopPalette.cardGap` | `12` |
| `NoopPalette.breathDuration` | `6` s — one orb breath |
| `NoopPalette.sheenDuration` | `24` s — one sheen rotation, deliberately incommensurate |

### The orb

`NoopPalette.orbStops` — `#9FE2FB` at 0, `#2FB2F0` at 0.55, `#0A5F92` at 1. Exactly the three stops
`10-tokens.md` specifies; reuse it rather than rebuilding the gradient. There is **one** orb ramp in
the app and its colour comes from `NoopSpecTokens.chargeColor(charge:)`; there is no per-state
variant.

---

## `controlFill` — the exact binding

```swift
NoopPalette.controlFill      // Color.white.opacity(0.07)
```

It sits in a six-step ladder of white overlays that are each 1–3 % apart, which is why substituting
one for another is a real bug and an invisible one in a screenshot:

| Token | Value | Job |
| --- | --- | --- |
| `NoopSpecTokens.subtleFill` | white 4 % | An inset panel **inside** a card |
| `NoopPalette.cardBorder` | white 6 % | The edge of a card |
| `NoopPalette.controlFill` | white 7 % | The **body of a control** |
| `NoopSpecTokens.controlBorder` | white 9 % | The edge of a control |
| `NoopSpecTokens.controlBorderStrong` | white 10 % | A control's edge on a tinted surface |
| `NoopPalette.track` | white 13 % | The unlit part of a track |

Everywhere `controlFill` is specified, verbatim:

- The **34 pt back-button circle** (`20-primitives.md` §3, `NoopSpecPrimitives.swift`)
- **Secondary and destructive buttons** (§7) — `controlFill` + 0.5 pt `controlBorder`
- The **strap battery chip** (§13) — `controlFill` + 0.5 pt `controlBorderStrong`
- **Unselected range chips** (7D/30D/90D/1Y/All)
- The **`Soon` / `Gated` chip** in the coming-soon state (`00-RULES.md` §12,
  `44-act5-plumbing.md` §2)
- The **confidence chip's fallback**, when the host screen passes no hue (`NoopChargeGauge.swift`)
- Svea's **ask field** (`46-act7-svea.md` §2) — re-tinted from `NoopLiquidGlassSearchField.swift`,
  radius 14, and its glass treatment dropped

A pressed control is this fill **one step brighter** for 120 ms — white 7 % → white 10 %. No scale
transform (`20-primitives.md` §7).

---

## The two greens — and they are not interchangeable

Both live in `NoopSpecTokens`:

```swift
NoopSpecTokens.green         // #8FE3B4                      — green as TYPE
NoopSpecTokens.greenSurface  // rgb(46, 204, 128) = #2ECC80  — green as a SURFACE
NoopSpecTokens.onGreen       // #04140C                      — ink ON greenSurface
```

Green means **done, confirmed, written**. One meaning, two renderings, and which one you use is
decided by *how much area it covers*, not by taste:

**`green` `#8FE3B4`** — anything the eye reads as ink or a mark: a done label, a ticked figure, a
synced/confirmed string, a small icon tint, a status dot up to ~6 pt. Nothing larger.
Use sites in the prototype: the `Sent — that is how it will feel` label, the two log buttons'
labels and icons, the recalibrate row's key line, the bell when notification access is granted, the
synced state of the sync button, the `Reconnect` label and tick.

**`greenSurface` `#2ECC80`** — anything that is a fill or a stroke of real weight: the lit
**Trends** tab pill, a chart line and its area fill, series B on `instrument/compare`, the
"without it" bar on `instrument/effects`, a filled provenance dot, the confidence chip's hue on
`ages/*`.

**`onGreen` `#04140C`** — type and glyphs sitting on a `greenSurface` fill. Not white, not
`onAura`: this one is measured against `#2ECC80` (9.2:1) and the other two are not.

Why not one token: `#8FE3B4` spread across a 46 pt tab pill reads as washed mint and stops meaning
*done*; `#2ECC80` at 13 px / 600 on `#141817` is a saturated mid-green on near-black, which
halates at type sizes even though it passes contrast. This is the same split the app makes between
`accent` and `auraLight`, and between `rest` and `lavenderText`.

**A green surface is never *needs attention* and never *critical*.** Those are `NoopPalette.effort`
and `NoopSpecTokens.hot`, and green may not stand in for either — see `10-tokens.md`, the
confidence ramp.

---

## Corrections carried in this file

1. **`10-tokens.md`, the confidence ramp table** named the `ages/*` hue as `green` at
   `46,204,128`. Those are two different tokens: the hue for a *tint* is `greenSurface`. Fixed.
2. That same row named its light text as a bare `#9EF0CC`, which is not a token and appears
   nowhere else in the spec or the prototype. It is now `green` `#8FE3B4`. **`#9EF0CC` is
   withdrawn; do not implement it.**
3. `NoopSpecTokens.onGreen` (`#04140C`) added — the ink on a green surface. It was an unnamed
   literal in the prototype's Trends tab.
