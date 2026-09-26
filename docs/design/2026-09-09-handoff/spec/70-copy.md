# The copy law

*Foundations pack. Read with `00-RULES.md`, which wins on anything visual. This file wins on
sentences.* The full version, with every generated-string table, is
**`Noop - Build Document.dc.html`** — open it, or print it to PDF. This is the short form for the
repo.

## Why this file exists

The copy is the product. Noop's whole claim is that it will not overstate what it knows, and that
claim lives entirely in sentences. A build can have every hex, radius and curve right and still ship
a different product, because someone rewrote *no real change* as *stable*, or *not enough yet* as
*keep going*, or added an exclamation mark to a line that was deliberately flat.

## The twelve rules

1. **A `[static]` string is a literal, like a hex code.** Type it exactly. Do not shorten it to fit,
   do not sentence-case a lowercase label, do not expand a contraction, do not swap an em dash for a
   hyphen. If it does not fit, the layout is wrong.
2. **Never invent a sentence for a state you have not been given.** A missing state is a spec gap
   and it blocks the screen. Not `Something went wrong`.
3. **No exclamation marks, anywhere.** There are zero in the prototype.
4. **The app never congratulates and never scolds.** It reports. The nearest it comes to praise is
   naming what happened and its consequence.
5. **Second person, present tense.** An imperative only where there is exactly one action.
6. **Numbers are written the way a person would say them.** `7h 12m`, `23:18`, `8,400`, `+0.52`,
   `84 nights`. True minus sign (U+2212) in deltas.
7. **Uncertainty is stated in the sentence**, in words, at the foot of the screen it appears on —
   never as an info icon.
8. **The app never claims cause.** Association only. `because` is allowed only about something the
   user did, never about something the app inferred.
9. **A refusal is a designed answer**: cannot · why · what instead. Three parts, never red.
10. **Numbers in copy come from the same call as numbers on screen.** Compute once, format twice.
11. **Empty is not zero.** `0` is measured as none; absent is `—` with a reason.
12. **Localisation happens centrally or not at all.** Translate the template, keep the slots, keep
    the gates. A locale that reads more encouraging than English is a broken locale.

## Banned vocabulary

optimal · optimise · perfect · score · grade · rating · streak · badge · achievement · level up ·
insight · AI · smart · powered by · should · must · need to (as advice) · failed · missed · poor
performance · data · dataset · metrics (user-facing) · `Loading…` · `Please wait` · `Oops`

Say instead: *your record*, *your nights*, *signals*, *what it moves with*, *what actually moves
you*, *your need* (sleep quantity only).

## How to lift a string

There are ~2,400 user-visible strings and they are **not** retyped in the spec — a retyped string is
a string that can drift. Every static string exists exactly once, in the prototype act file.

1. Open the act file (`Noop Act N - ….dc.html`). Search for the screen's `sc-if` block —
   `isCharge`, `isMetric`, `isAlarm`. Everything for that screen is inside it, **in visual order**.
2. Copy the strings out in that order. Keep the order: it is the reading order, and reordering cards
   changes the argument the screen makes.
3. For each `{{ hole }}`, find the key in `renderVals()`. A plain value is static copy held in code
   (the branch varies, the words do not). A concatenation is `[formula]` — implement the template
   from the build document §5, not the example output.
4. Diff against the prototype with both on screen, and read the sentences aloud.

**Do not transcribe from a screenshot.** Every apostrophe is U+2019, every prose dash is an em dash
with no surrounding spaces, every minus is U+2212. OCR gets all three wrong and the result looks
right while not being the product.

## The honesty gates

A gate is product logic, not a tuning parameter. If it fails, the screen renders the designed
refusal — not a weaker version of the claim.

| Claim | Gate |
| --- | --- |
| A trend has a direction | \|change\| > the signal's noise threshold |
| A trend is worth calling | window longer than six weeks |
| A correlation exists | n ≥ 21 aligned days **and** \|r\| ≥ 0.22 |
| A fit line may be drawn | \|r\| ≥ 0.28 and n ≥ 21 |
| A behaviour may be ranked | ≥ 5 days with **and** ≥ 5 without |
| A ranked effect is real | \|effect\| ≥ 3.5 % of the target mean |
| Two group means differ | ≥ 3 points of readiness |
| A dose figure is yours | ≥ 40 of your own nights |
| A night may be read | no gap > 20 min in the window; ≥ 85 % worn |
| Body age may be shown | 14 nights, ≥ 10 worn |
| A biomarker may state a value | read confidence ≥ 0.75, else *as read* |

### Noise thresholds

`rhr 1.2 bpm` · `hrv 3.2 ms` · `sleep 0.32 h` · `drift 7 min` · `deep 1.4 %` · `rem 1.6 %` ·
`breath 0.32` · `temp 0.09 °C` · `spo2 0.4 %` · `readiness 4` · `stress 9 min` · `steps 700` ·
`load 8` · `capacity 0.5` · `body age 0.4 yr` · `weight 0.5 kg` · `behaviour 0.4 /week`

## The nine recurring states

`ordinary` · `thin` · `flat` · `absent` · `partial night` · `declined` · `uncomfortable` ·
`borrowed` · `building`. Six of the nine are ordinary Tuesday, not error paths. Each has a designed
sentence; see the build document §6.

## Schedule vocabulary

One profile answer changes vocabulary in **five acts** (4, 6, 8, 9 and 5's profile row). Hold it as
a `ScheduleTerms` struct with one instance per schedule, injected at the screen root — do not scatter
`if isNightShift` through view bodies. The complete pair table is in the build document §4; the
prototype holds them in a `TERMS` map per act for exactly this reason.

Getting this wrong tells a shift worker to go to bed at the same hour every night, which is the most
alienating thing a wearable does.
