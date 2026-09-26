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
| ~~Coach card top~~ | ~~`coachSurfaceTop`~~ | ~~`#18211E`~~ — **deleted 8 September** |
| ~~Coach card bottom~~ | ~~`coachSurfaceBottom`~~ | ~~`#121615`~~ — **deleted 8 September** |
| Text primary | `textPrimary` | `#EDF1EF` |
| Text tertiary | `textSecondary` | `#939C97` |
| Label | `textTertiary` | `#8B958F` |
| Muted | `textQuiet` | `#7F8A85` |
| Dim | `textFaint` | `#6C7570` |
| Faint | `textDim` | `#57605C` |
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
| Orb breath | `NoopSpecMotion.breathDuration` | `16` s — four 4 s box phases |
| Orb breath phase | `NoopSpecMotion.breathPhase` | `4` s |
| Orb sheen | `NoopSpecMotion.sheenDuration` | `24` s |

**The two durations moved out of `NoopPalette` on 8 September.** It carried `breathDuration = 6`
while `NoopSpecMotion` carried `16`; the breath is 16, and one timing cannot live in two files.

**The coach card is not a near-black vertical ramp.** `#18211E → #121615` appears in no act source.
The treatment actually on `today` and in `svea/coach` is the **158° directional accent card** —
lavender at 16 % over lavender at 3 %, with a 0.5 pt lavender border. Both tokens are deleted rather
than re-pointed: a token whose name says *coach surface* and whose value is a different composition
is worse than no token, and the gradient belongs to the card treatment in the registry below, not to
one screen. `46-act7-svea.md` and `41-act2-day.md` carry the corrected values.

**Bindings, verbatim, are in `12-palette-bindings.md`** — every property above with its value,
where the **six** Swift files go so these names resolve, and `controlFill` in full. Read it before
filing a token as missing.
---

## Gradients and shadows, as built

**There is no "only four gradients" rule, and the one this pack used to state was false.** The
canonical HTML uses gradients in six named places and shadows in nine; a build that goes through the
app deleting them is not following the design, it is stripping it. What is true is narrower and is a
rule about **one primitive**: the standard card (§1 of `20-primitives.md`) has no gradient and no
shadow. Everything below is read off the act sources.

### Gradients

| # | Where | Exactly |
| --- | --- | --- |
| 1 | **Ambient hero glow** — behind the top of a home screen | `radial-gradient(circle, hue α, hue 0 70%)`, `blur(18)`, `border-radius: 50%`, `pointer-events: none`, centred (`left 50%` + `translateX(-50%)`) |
| 2 | **The orb**, six layers | `20-primitives.md` §11 — glow, ring, body, inner shade, charge glow, charge core, sheen |
| 3 | **158° directional accent card** | `linear-gradient(158deg, rgba(hue,.16), rgba(hue,.03))` + 0.5 pt `rgba(hue,.30)`. Radius **20** on `today`'s Svea prompt, **24** on Act 7's own rows. A state-driven variant swaps the first stop for `rgba(242,180,92,.16)` when the card is reporting attention |
| 4 | **160° brief card** — `svea/coach`'s top card | the same idea one degree off and one step quieter: `linear-gradient(160deg, rgba(139,153,214,.14), rgba(139,153,214,.03))` + 0.5 pt `rgba(139,153,214,.30)`, radius 26 |
| 5 | **Chart band fills** | the area under a trend line at `rgba(hue,.10)`, under a 1.9 pt stroke — `ages/ages`, `goal/marker`, `instrument/*` |
| 6 | **File preview** — the lab page and its row strips | page `linear-gradient(163deg,#DFD9CB,#CFC8B7 58%,#BEB6A3)`; row strip `linear-gradient(160deg,#E2DCCE,#CBC4B3)`; the card's vignette `radial-gradient(120% 90% at 30% 25%, transparent 30%, rgba(0,0,0,.34))` and a `linear-gradient(to top, rgba(4,6,5,.9), transparent)` scrim at its foot |

Two more that are gradients but read as marks rather than surfaces, and are equally not optional:
the **picked radio** (`radial-gradient(circle,#DDE3F6 0 32%, hue 34%)`) and the **pulse glow** behind
a live bpm (`radial-gradient(circle, rgba(23,162,230,.34), transparent 70%)` on `today`'s tile,
`.28` on `day/heart`'s hero, `.30` at 210 × 150 on `effort/live`). `svea/gate`'s orb is its own
seven-stop radial and is specified in `46-act7-svea.md` §7.2.

**The ambient glow, per act** — the geometry is measured, and Acts 3 and 5 deliberately have none:

| Act | Size | Top | Hue at |
| --- | --- | --- | --- |
| 1 night | 470 × 430 | −170 | `139,153,214` @ **.20**, and **animated**: `glowPulse 9s ease-in-out infinite`, opacity .55 ↔ .9 |
| 2 day | 470 × 410 | −150 | `23,162,230` @ .17 |
| 3 effort | — | — | **none** |
| 4 picture | 470 × 410 | −150 | `46,204,128` @ .15 |
| 5 plumbing | — | — | **none** |
| 6 ages | 480 × 420 | −170 | `46,204,128` @ .15 |
| 7 svea | 480 × 420 | −170 | `139,153,214` @ .16 |
| 8 goals | 480 × 420 | −170 | `242,180,92` @ .15 |
| 9 instrument | 470 × 410 | −150 | `139,153,214` @ .16 |

Act 1's is the only animated one. Everywhere else the glow is static — it is depth, not motion.

### Shadows

| Where | Exactly |
| --- | --- |
| Tab bar | `0 8 26 rgba(0,0,0,.5)` |
| The **+** | `0 4 14 rgba(23,162,230,.4)` |
| Log sheet | `0 −20 50 rgba(0,0,0,.5)` — **upward** |
| Panel sheet | `0 −14 44 rgba(0,0,0,.6)` — upward |
| Ask field / review summary bar | `0 8 26 rgba(0,0,0,.45)` |
| Orb charge core | `0 18 52` at 42 % of the level colour |
| Gauge marker | `drop-shadow(0 0 6 rgba(0,0,0,.5))` |
| Live bpm numeral | `text-shadow 0 2 16 rgba(4,30,48,.55)` |
| Dots and specks | `0 0 10px hue`, and `0 0 (size × 2.6)px hue` on a speck |

**CSS blur radius is twice SwiftUI's.** `0 8 26` is `radius: 13`; `0 −20 50` is `radius: 25`.


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
