# Act 7 — Svea (the coach)

*Screen specs. `00-RULES.md` and `20-primitives.md` are binding.*

Tags: `[static]` fixed by design · `[bound]` real data · `[formula]` derived · `[proto]` do not build.

Four screens plus the coach. Aura for chrome; the coach card is the one gradient
(`coachSurfaceTop → coachSurfaceBottom`, already in `NoopPalette`). Home is `coach`.

---

## 7.1 `coach` — Svea

**Header** — home style.

1. **The call** — hero card with the coach gradient. One instruction `sectionHead` 19 `[bound]`,
   then the receipt `body` 13.5 `textBody` `[bound]`. Both come from `AICoach`; both are written
   to `70-copy.md` and the generated-string tables in `Noop - Build Document.dc.html`. **The
   instruction comes first and the receipt second, always** — a receipt opened with ("HRV 45 % over
   baseline") is the complexity this direction exists to remove. There is no string constant to
   lift: the old body-state type went with the Aura layer in `1ecb5712` and its wording is
   superseded.
2. **Ask** — a text field row `[bound]`: `NoopLiquidGlassSearchField.swift` exists; re-tint to
   `controlFill` + `controlBorder`, radius 14, do not use its glass treatment on this canvas.
3. **Recent** — list card, past exchanges `[bound]`, each → the exchange.
4. Rows: **What she remembers** → `svea/memory` · **What she may use** → `svea/consent`.

**States** — **no provider set**: the screen is replaced by `svea/gate`. Not a banner, not a
disabled field — the gate is the screen.

---

## 7.2 `gate` — no provider

Header: back → `coach`, parent `Svea` `[static]`.
Hero card, aura tint: `[static]` title and a body paragraph saying plainly that Svea needs a
provider and a key, that the key stays on the phone, and what it costs.
Primary button `[static]` **Set up a provider** → `svea/setup`.
Everything else on the screen: nothing. The gate does not pad itself.

---

## 7.3 `setup` — provider and key

Header: back → `gate`, parent `Svea`.
1. **Provider** — segmented `[bound]`.
2. **Key** — a secure field row `[bound]`, sub-line `[static]` stating the key never leaves the phone.
3. **Test** secondary button; states: idle → running → **green** *"Working."* `[static]` or amber with
   the provider's own error, plainly worded `[formula]`.
4. Footnote `[static]`.

---

## 7.4 `consent` — purpose by purpose

Header: back → `coach`, parent `Svea`.
List card, **one toggle per purpose** `[bound]` — not one blanket switch. Each sub-line says exactly
what is sent for that purpose `[static]`. Every one is **revocable**, and revoking states what stops
working `[static]`.
Footnote `[static]`.

---

## 7.5 `memory` — what she remembers

Header: back → `coach`, parent `Svea`.
1. List card of remembered facts `[bound]`, each with a **Forget** action whose sub-line states the
   consequence `[static]`.
2. **Forget everything** destructive button — states what it destroys `[static]`. Not a confirmation
   dialog (only the strap and data deletion get those); the consequence is in the row.
3. Empty: one sentence `[static]`.
