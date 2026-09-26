# Tokens — what exists, what to add, what to stop using

*Foundations pack, 2 of 5. Companion to `NoopSpecTokens.swift`, which is the machine-readable
version of this table and the thing to actually compile.*

## The rule

Colour lives in two files, both shipped by this pack and both in
`Packages/StrandDesign/Sources/StrandDesign/Aura/`:

- **`NoopPalette.swift`** — the base palette. Surfaces, the text ramp, the three hues, `orbStops`,
  the metrics. (It supplies the values the deleted `AuraPalette` held; see
  `13-branch-corrected-foundation.md`.)
- **`NoopSpecTokens.swift`** — everything the palette does not carry, plus the tinted-card rule and
  the charge ramp.

The split is not arbitrary: `NoopPalette` is values a second design could reuse, `NoopSpecTokens` is
this design's own vocabulary. Neither is a `Color(light:dark:)` pair.

**Do not use `StrandPalette`, `NoopVisualStyle` or `HeuteRedesignPalette` on any screen in this
pack.** All three are `Color(light:dark:)` pairs or chart-style-dependent, and these screens are
a fixed dark scene. This is the `#1013` trap — light-mode ink stranded on a fixed-dark canvas.

## In `NoopPalette` — use as-is

| Design token | Property | Value |
| --- | --- | --- |
| Base | `canvas` | `#0A0C0B` |
| Card | `card` | `#141817` |
| Card border | `cardBorder` | `white 6 %` |
| Control fill | `controlFill` | `white 7 %` |
| Track (off) | `track` | `white 13 %` |
| Coach card top | `coachSurfaceTop` | `#18211E` |
| Coach card bottom | `coachSurfaceBottom` | `#121615` |
| Text primary | `textPrimary` | `#EDF1EF` |
| Text tertiary | `textSecondary` | `#939C97` |
| Label | `textTertiary` | `#8B958F` |
| Muted | `textQuiet` | `#7F8A85` |
| Dim | `textFaint` | `#6C7570` |
| Row chevron (graphical, never type) | `chevronDim` | `#57605C` |
| Ink on an accent tint | `onAccent` | `#08120F` |
| Aura blue | `accent` | `#17A2E6` |
| Lavender | `rest` | `#8B99D6` |
| Amber | `effort` | `#F2B45C` |
| Card radius | `cardRadius` | `24` |
| Inset radius | `pillarRadius` | `20` |
| Standard card radius | `tileRadius` | `22` |
| Control radius | `controlRadius` | `14` |
| Screen padding | `screenPadding` | `20` |
| Card gap | `cardGap` | `12` |
| Orb breath | `breathDuration` | `6` s |
| Orb sheen | `sheenDuration` | `24` s |

**Bindings, verbatim, are in `12-palette-bindings.md`** — every property above with its value,
where the five Swift files go so these names resolve, and `controlFill` in full. Read it before
filing a token as missing.

Two names differ from the design's own vocabulary and that is fine — the mapping above is
binding. `NoopPalette.textSecondary` is the design's **tertiary** text; the design's *secondary*
(`#C6CEC9`) is not in the palette and is added below.

## Added by `NoopSpecTokens`

Surfaces: `subtleFill`, `controlBorder`, `hairline`, `tabBarFill`, `tabBarBorder`.
Text: `textBody` (`#C6CEC9`, the design's secondary), `onAura` (`#04121A`), `onGreen` (`#04140C`).
Hues: `auraLight` (`#8FD3F5`), `auraPale` (`#9FE2FB`), `blush` (`#E08A9B`), `blushSoft` (`#F6D3DA`),
`blushLabel` (`#C08E98`), `lavenderText` (`#C9D0EE`), `green` (`#8FE3B4`, green as **type**),
`greenSurface` (`#2ECC80`, green as a **surface** — the two are not interchangeable; see
`12-palette-bindings.md`), `hot` (`#F0742C`).
Metrics: the full radius ladder, the border widths, the 116 pt bottom padding, the header insets.
Functions: `tint(_:)` and `tintBorder(_:)` for the tinted-card rule, and `chargeColor(_:)` for
the heat ramp.

## The tinted-card rule — one function, not per-card literals

Every tinted surface in the app is the same recipe: **the hue at 7–12 % over base, with a 0.5 pt
border of the hue at 22–34 %.** Cards in the build that were eyeballed instead of computed are
why tints read inconsistently.

```swift
.background(NoopSpecTokens.tint(NoopPalette.rest))              // 9 %
.overlay(shape.strokeBorder(NoopSpecTokens.tintBorder(NoopPalette.rest), lineWidth: 0.5))  // 24 %
```

Use the defaults (9 % / 24 %) unless a screen spec names different percentages.

## Gradients

> **Superseded for Acts 6–9.** This section said *the orb, and nothing else*. That held for Acts
> 1–5. There are now **four** kinds of gradient — the orb, the body-age aura, the tinted-verdict
> wash at 158°, and the screen-top ambient bloom — and all four are written out at exact values in
> **`Noop - Build Document.dc.html` §10.3**. Everything below still stands for the orb, and the
> closing rule still stands everywhere else: **cards, buttons, chips, rows and the tab bar have no
> gradient.**

The orb:

```
radial-gradient(circle at 38% 32%, #9FE2FB, #2FB2F0 55%, #0A5F92)
shadow  0 18 52  rgba(11,111,168,.55)
inner   inset 0 -8 24 rgba(4,42,66,.5)
numeral #F6FDFF, text-shadow 0 2 16 rgba(4,30,48,.55)
```

`NoopPalette.orbStops` is exactly these three stops at exactly these locations — reuse it. (It used
to be `AuraBodyState.restored.orbStops`; that type was deleted in 1ecb5712 and is deliberately not
restored — see `13-branch-corrected-foundation.md`.) The inner shadow has no SwiftUI equivalent; it is an
`.overlay(Ellipse().fill(LinearGradient(…)).blur(…))` masked to the circle, specified in the
orb primitive.

There are **no other gradients in the app** beyond the four named in the build document §10.3.
If a card, button, chip, row or tab bar in the build has one, delete it.

## Shadows — three, and cards have none

| Where | Value |
| --- | --- |
| Widget on a wallpaper | `0 12 30 rgba(0,0,0,.45)` |
| A floating badge | `0 3 10 rgba(0,0,0,.5)` |
| The orb | its own glow, above |

**Cards have no shadow.** `NoopPanelSurface` in `NoopVisualStyle.swift` applies one by default —
do not use it on these screens. Use `NoopSpecCard`.

---

## The confidence ramp **[new, 31 August]**

No new colours — the chip in `20-primitives.md` §15 is the **tinted-card rule applied twice**, at
the floor and the ceiling of its own range, in whichever hue the host screen already owns.

```
calibrating:  fill hue 7 %    border hue 22 %   dot hue 42 %   label textTertiary
building:     fill hue 12 %   border hue 30 %   dot hue 75 %   label the hue's light text
solid:        no chip
```

| Host | Hue token | RGB | Light text |
| --- | --- | --- | --- |
| `night/*` | `rest` | `139,153,214` | `lavenderText` `#C9D0EE` |
| `day/*`, `effort/*` | `accent` | `23,162,230` | `auraLight` `#9FE2FB` |
| `ages/*` | `greenSurface` | `46,204,128` | `green` `#8FE3B4` |
| `plumbing/you` body clock | `blush` | `224,138,155` | `blushSoft` `#F6D3DA` |

**Amber (`effort`) and `hot` are not on this list and never will be** — they are reserved for
*needs attention* and *critical*. The illness signal and a calibrating score can land on the same
screen, and one colour cannot mean both "act on this" and "ignore this for now".
