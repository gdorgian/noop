# Act 5 — The plumbing

***Twenty-one screens**, the most of any act — and eight of them are the two doors
(`60-parity.md` Part 1) plus the three surfaces the audit closed on 1 September.
`00-RULES.md` and `20-primitives.md` are binding.*

Tags: `[static]` fixed by design · `[bound]` real data · `[formula]` derived · `[proto]` do not build.

Blush (`NoopSpecTokens.blush`) is the hue for anything about **you**. It is never a warning.
Home is `you`.

---

## 5.1 `you` — the body clock

**Header** — home style. Battery chip + day chip.

**The body clock** — hero card, radius 24, 306 tall. A **24-hour ring** `[bound]`:
- Ring track: `NoopPalette.track`, stroke 6, radius 118.
- The **sleep window** as a lavender arc `[bound]`, stroke 6, `NoopPalette.rest`.
- The **bedtime anchor** as a 2 × 12 tick `[bound]` in `lavenderText`.
- The **usual wake** as the same tick in `auraLight` `[bound]`.
- A **live now-marker** `[bound]`: a 7 pt circle in `accent` with a 1 pt `auraPale 50 %` halo ring
  (the second of the app's two 1 pt strokes).
- Hour marks every 3 h, `captionMicro` 9.5 tracking +1.14 `textDim`.
- **The portrait at its centre** `[bound]`, 96 circle → `plumbing/record`.
  **No photo badge on the ring.** Setting a photo lives in the + sheet and in `record`. If the
  build has a camera badge on the ring, remove it.

**Rows** — list card, each → its screen: Your record · Your strap · Your ages · Svea · Goals ·
History · Settings `[static]` labels, blush-hued glyphs, sub-lines `[formula]` (e.g. the strap row
shows battery and last sync). **The last row of the hub card is *What Noop will not ask you*** →
`plumbing/position` (§5.14), and the trailing note on this screen gives up its enumeration to it.

**Tab bar**, You active.

**States** — no photo: the centre shows the user's **initials** at `sectionHead` 19 in `blushSoft`
on `tint(blush)`.

`ProfileAvatarView.swift` does **not** do this yet — an earlier draft of this spec said it did, and
that was wrong. Its current no-photo fallback is `BrandMark`. **Extend it** with an initials case
and make that the default fallback here; keep `BrandMark` only where an existing caller relies on
it. One or two initials, uppercased, from the display name — first letter of the first and last
word, one letter if there is only one word, and the empty-name case falls back to `BrandMark`
rather than an empty disc.

The reason this is not cosmetic: this is the identity card at the top of **You**, and a brand mark
in the portrait slot makes a person's own record read as a placeholder for someone else's. The
initials are the one thing on the screen that is unambiguously *theirs*.

---

## 5.2 `record` — your record

Header: back → `you`, parent `You` `[static]`. Title `screenTitle` 25 `[static]` *Your record*.

List cards, grouped, `VStack(spacing: 12)`:
1. **Photo** row `[bound]` — 44 circle thumb, label, "Change" / "Add" `[formula]`.
2. **Date of birth** `[bound]`, **Sex** `[bound]` (segmented), **Height**, **Weight**, **Waist
   (optional)** `[bound]`.
   **Imperial entry when Units is imperial** `[formula]`: feet+inches and pounds fields, not a
   converted metric field. `SettingsView.swift` already has `measureField` / `poundsField` /
   `feetInchesField` — reuse them, do not re-implement.
3. **Measured maximum** heart rate `[bound]` (`hrMaxField` exists) with a sub-line `[static]` saying
   what it changes.
4. **Custom zones** row → `plumbing/zones`.
5. **Step calibration** — both calibrations `[bound]` (walk and run), each a row with its own state.

Footnote `[static]`.

**States** — a field never set: the value slot reads `[static]` *"Not set"* in `textDim`, not a zero.
Committed: the value updates in place and a green tick appears for 2 s. No toast.

---

## 5.3 `zones` — custom zones

Header: back → `record`, parent `Your record`.
1. Five zone rows `[bound]`: name, range, colour swatch 12 circle. Editable bounds.
2. **Reset to default** secondary button, sub-line `[static]` saying what it discards.
3. Footnote `[static]`.

---

## 5.4 `history` — everything recorded

Header: back → `you`, parent `You`.
1. Segmented filter `[static]`: All / Sleep / Heart / Training / Manual. Persists.
2. List card, one row per record `[bound]`, grouped by day with `caption` 10 uppercase day headers.
3. Empty: one sentence `[static]`, no illustration.

---

## 5.5 `strap` — your strap

Header: back → `you`, parent `You`. Title `screenTitle` `[static]` *Your strap*.

1. **The battery ring** — hero card. Ring radius 62, stroke 8, track `NoopPalette.track`,
   progress `auraLight` `[bound]`; level `heroNumeral` 52 tabular at its centre with `%` at
   `rowFigure` 17. **≤ 20 % amber, ≤ 10 % hot**, ring and numeral together — the same rule as the chip.
   Below: estimated days left `[formula]`.
2. **Connection + secure link** — list card, two rows `[bound]`, each with a state chip
   (green connected / amber not).
3. **Sync now** and **Sync Apple Health** — **two separate acts with their own state** `[bound]`.
   Each is a row with a trailing state: idle (label "Sync"), running (a 14 pt spinner, label
   "Syncing"), done (green check, "Synced just now", reverting after 2 s).
   Apple Health's toggle hue is **green** (RULES §9).
4. **Sensors** — list card, one row per sensor `[bound]`, each **priced in battery hours** in its
   sub-line `[formula]` — this is the act's version of "every switch says what it costs".
5. **Buzz strength** — segmented `[static]`: Light / Medium / Strong.
6. **Buzz to find** — row with a button `[static]` *"Buzz it"*, confirming in green.
7. **Buzz for phone notifications** → `plumbing/notifs`. Value slot shows the live summary
   `[formula]`: `{n} of 8 apps · {pattern}` · or `mirroring off` · or `needs notification access`.
8. **Apple Health** → `plumbing/apple` (§5.15). The card carries a **one-line state of the
   bridge** `[formula]`, so a refused kind is visible before the page is opened.
9. **Automations** → `plumbing/automations` (§5.16) — also reachable from `settings`. **The count
   of what is armed rides the row** `[formula]`, so the drawer never hides how much is on.
10. **How you wear it** → `plumbing/position`? **No.** That route does not exist: `position` is
    *What Noop will not ask you*, off `you`. The strap-wearing guidance is a card **on this
    screen**, not a push.
11. **The strap log** — standard card: **Copy**, **Save**, and a **daily auto-export** toggle
    `[bound]`, each sub-line stating what it writes `[static]`.
12. **Manage straps** → `plumbing/devices`.
13. Footnote `[static]`.

**States** — disconnected: the ring goes `track` with an em-dash, every sensor row is unavailable
at 38 %, and Sync says `[static]` *"Nothing to sync — the strap is not connected."*

---

## 5.6 `notifs` — buzz for notifications

**New.** Reached from `strap` and from Settings → *What may interrupt you*.
Header: back → `strap`, parent `Your strap` `[static]`.

### Permission is a first-class state

`nAccess` is read **live on every appearance**, never cached.

| State | Card | Button |
| --- | --- | --- |
| **Not granted** | aura tint. Title `[static]` *"Noop needs notification access"*; body `[static]` *"Without it the strap cannot know a notification arrived. One tap in iOS Settings, and reversible from there whenever you like."* | primary, filled aura: `[static]` **Allow notification access** |
| **Granted** | green tint (`tint(greenSurface)`). Title `[static]` *"Notification access granted"*; body `[static]` *"iOS hands Noop the app name and the time it arrived. Nothing else, and nothing leaves this phone."* | secondary: `[static]` **Review in iOS Settings** |

While not granted, **everything below the card is at 38 % opacity and non-interactive.**
Do not hide it — the user should see what they are unlocking.

### Controls

1. **Mirror phone notifications** — master toggle, aura hue `[bound]`.
   On sub-line `[static]`: *"About four percent of the strap's day, and nothing while the list below
   is empty."*
   Off sub-line `[static]`: *"Noop still buzzes for its own things — bedtime, sessions, battery."*

2. **Which ones reach your wrist** — caption `[static]` + list card, eight rows.
   The app list should be built from **real installed apps with notification permission** `[bound]`;
   the eight below are `[proto]` **placeholders**, but their *intent* is `[static]`: chat and calls
   on, feeds and newsletters off.

   | App | Default | Sub-line `[static]` |
   | --- | --- | --- |
   | Messages | **on** | Anyone who can already reach you. A group thread counts once. |
   | Phone calls | **on** | Incoming only, and only while it is still ringing. |
   | Calendar | **on** | The ten-minute warning, not the invitation. |
   | WhatsApp | **on** | Direct messages and mentions. Not every group line. |
   | Mail | off | Noisy by nature. Off is the honest default. |
   | Slack | off | Held outside your active hours whatever you pick here. |
   | Reminders | **on** | The ones with a time on them. |
   | Everything else | off | One buzz for any other app your phone already allows. |

   Below the card, a **live line** `[formula]`, `subline` 11.5 `textQuiet`:
   - `{n} apps allowed. Everything else stays on the phone.`
   - none allowed → `[static]` *"Nothing is allowed through, so nothing buzzes. This is a valid setting."*
   - master off → `[static]` *"Mirroring is off, so nothing in this list reaches your wrist yet."*

3. **How it buzzes** — segmented `[static]`: **One buzz** / **Two short** (default) / **Long**.
   A note under it changes per option `[static]`: *easy to miss, easy to live with* · *the one people
   keep* · *hard to miss, harder to ignore*.
   **Feel it on the strap** secondary button — fires **the currently selected pattern**, not a
   generic one — and confirms in green `[static]`: *"Sent — that is how it will feel."*

4. **Conditions** — list card, four toggles `[bound]`, sub-lines `[static]`:
   - *Only when the phone is locked* (**on**) — "If you are already looking at the screen, your wrist adds nothing."
   - *Follow iPhone Focus* (**on**) — "Sleep, Work and Do Not Disturb all apply here first."
   - *Hold them during quiet hours* (**on**) — "Nothing between your bedtime anchor and your usual wake."
   - *Repeat once after two minutes* (off) — "One more buzz if you have not picked the phone up."

5. **Footnote**, verbatim `[static]`: *"Mirroring costs about four percent of the strap's day, and
   nothing at all while the list is empty. Noop never reads what a notification says — only which
   app sent it, so it knows whether to buzz."*

### Implementation notes

- iOS has no public API handing an app another app's notifications. The route that delivers the
  designed behaviour is the strap as an **ANCS** consumer over BLE: the strap subscribes to the
  phone's notification stream, and this screen supplies the allow-list and the pattern.
- If ANCS is the route, the allow-list and conditions must be **synced to strap firmware** — the
  strap decides at buzz time, offline. So this screen is **editing device configuration** and needs
  a **"saved to strap"** state on the sync path (a 12th state, in addition to RULES §12's nine).
- The privacy sentence is a **promise**: read only the originating bundle identifier and the
  timestamp. Never the payload — not even in debug logs.
- The 4 % figure is `[proto]`. Measure it and put the real number in the copy.

---

## 5.7 `devices` — manage straps

Header: back → `strap`, parent `Your strap`.
1. List card, one row per known strap `[bound]`: name, firmware, last seen, a state chip.
2. **Rename** and **Forget** per row; Forget's sub-line states the consequence `[static]`, and it is
   one of the app's two confirmations.
3. **Pair a new strap** primary → `plumbing/pair`.

---

## 5.8 `pair` — pairing

Header: back → `devices`, parent `Manage straps`.
A three-step flow `[bound]`, one card per step with the current step's card active and the others at
38 %. States: searching, found, pairing, paired (green), failed (amber, with a plain reason).

---

## 5.9 `data` — your data

Header: back → `settings`, parent `Settings`.
1. **What is recorded** — list card `[static]`, one row per data class, each with a sub-line saying
   why it exists.
2. **What leaves the phone** — standard card, one paragraph `[static]`. If nothing does, say so.
3. **Delete** — destructive button. **A confirmation** (one of the two), whose sheet states exactly
   what is destroyed and that it cannot be undone `[static]`.
4. Footnote `[static]`.

---

## 5.10 `settings` — settings

Header: back → `you`, parent `You`. Title `screenTitle` `[static]` *Settings*.

**Eleven groups**, each a caption + list card, `VStack(spacing: 12)`. Every switch's sub-line says
what it costs `[static]` — in battery hours, in attention, or in what stops working.

Groups `[static]`: Profile · Units (segmented, metric/imperial) · Appearance (segmented, Dark /
Light / System — **Dark is the designed default**) · Strap · Power saving · Effort scale ·
Streak · What may interrupt you → `plumbing/notifs` · **Automations → `plumbing/automations`** ·
Widgets → `plumbing/widgets` · The Lab → `plumbing/lab` · Your data → `plumbing/data` · About.

Above the groups, a **search field** `[static]` — 44 pt, radius 15, `controlFill` + 0.5 pt
`controlBorder`, a glyph and one placeholder. `60-parity.md` Part 3 §B records the loss of the
More index's search; this restores it for the one catalog large enough to need it.

**The `Later` group, at the foot** — the nine drawer utilities from `60-parity.md` Part 3 §C, each
dimmed, each with a neutral **Later** chip **where the chevron would be**, and **no control to
touch**. Never a live switch with nothing behind it (RULES §13 ¶4). Neutral, not amber: amber is
reserved for attention and this is not a warning. The same treatment applies to individual options
where part of a row ships — **Light** and **System** appearance against a shipped Dark, **System**
and **Deutsch** against a shipped English, each with the reason in the row's own sub-line.

**The Lab** sits below the groups as its own lavender-tinted card rather than a row, because it is
the one destination in Settings that is not needed to use Noop and should not read as peer to
units and appearance.

**Appearance note**: designed values exist for **dark only**. Light is an open question (RULES
questions §4); ship the setting, and until light is designed, Light and System resolve to the dark
scene rather than half-flipping tokens.

---

## 5.11 `widgets` — widgets

**New.** Header: back → `settings`, parent `Settings`.

Three widgets, each answering exactly one question. All three read **the last sync** and must
**never wake the strap**.

Preview cards on this screen: **146 tall**, radius 26, fill `rgba(10,12,11,.74)`, 0.5 pt
`controlBorder`, shadow `0 12 30 rgba(0,0,0,.45)`, `padding 15` — one of only three shadows in the
app (RULES / tokens).

| Widget | Family | Contents |
| --- | --- | --- |
| **Charge** | `systemSmall` | `CHARGE` caption `[static]` + level dot; level at **44** / Outfit 200 `[bound]` with `of {wake}` at 11 `textQuiet`; a **6** pt bar whose pale stretch is the waking charge and whose fill is what is left (§13); the state label `[bound]` — **the same gated slot as `day/charge`**, per `41-act2-day.md` §2.2. With nothing bound it restates the level. It is never derived from a bucket. |
| **Last night** | `systemMedium` | `LAST NIGHT` `[static]` in lavender; duration at **32** / Outfit 200 `[bound]`; "7m over your need" `[formula]`; one plain sentence `[formula]`; divider; four stage bars — Deep 40 / Light 62 / REM 34 / Awake 9 pt wide, lavender at alpha 1 / .6 / .82 / .26 — with **8.5** pt labels; the charge figure at **24** in `auraLight` |
| **Charge glance** | `accessoryCircular` + `accessoryInline` | circular: 74 pt, ring r 32 stroke 6, track `white 16 %`, progress `auraLight` at `C × level`, level at **22** with `CHG`; inline: dot + `Charge 56 · slept 7h 12m` `[bound]` |

Footnote, verbatim `[static]`: *"Long-press your Home Screen, tap the +, and search Noop. All three
read the last sync — they never wake the strap on their own."*

**Note**: 8.5 pt labels are below RULES §1's 9.5 floor — they are permitted **only** inside a
widget, where the system's own type is smaller. Nowhere in the app proper.

---

## 5.12 `lab` — the Lab

Header: back → `settings`, parent `Settings`.

1. **Experimental readings** — list card `[bound]`, each row a `PuffinExperiment` flag with its own
   sub-line saying what it costs and what it is not.
2. **Strap-writing probes** — list card. Each row is **badged** (a `Soon` or `Gated` chip in
   `controlFill`) and states **its gate reason** `[static]` in the sub-line. A gated row is the
   **coming-soon** state from RULES §12: label at 38 %, chip, no chevron, not tappable.
3. **Diagnostic exports** — list card: every export `[bound]`, each with what it contains.
   Raw-CSV export exists in the codebase (#322/#276) — reuse it.
4. Footnote `[static]`: the Lab is not supported and may change.

---

## 5.13 `onboard` — first run

Header: none. Reached from `you` only as a re-entry `[bound]`; normally the app's first screen.
**No back chevron and no swipe-back** — there is nothing behind it (`30-routes.md`).
A card stack `[bound]`, one per step, each with a primary button.

The shipped four-step wizard **is** this card stack and is blessed as built
(`32-nav-addendum.md` Change 8): *What Noop does* · *When do you usually sleep?* ·
*Connect your strap* (which **is** `plumbing/pair`, so the final step's push is satisfied a step
early — correct, because step 4 can then state whether pairing actually worked) · the closer.
`[static]` copy throughout; no marketing voice, no exclamation marks anywhere in this app.

**Step 2's answer has to be read, not just recorded.** *The only question that changes the whole
app* is a promise the build has to keep: answer rotating shifts or permanent nights and every
screen that says *night* follows it. If it is stored and nothing reads it, drop the claim from the
copy rather than keeping the sentence.

`onboard` keeps its **inline** *What Noop will not ask you* panel, rendering the same five strings
as §5.14. A row that re-entered the wizard would land on step 1 behind a primary button marching
toward pairing again, which is why that panel became a screen off `you` instead.

---

## 5.14 `position` — what Noop will not ask you

**New.** The last row of `you`'s hub card. Header: back → `you`, parent `You` `[static]`.
Title `screenTitle` 25 `[static]` *What Noop will not ask you*; sub-line `[static]`: five things
this app has no opinion about, **each one missing on purpose, and here is the purpose**.

1. **The five denials** — list card, `padding 2 / 16`. Row: `HStack(spacing: 13)`, `.top`.
   - Leading: a **17 pt struck-through circle**, drawn — `viewBox 0 0 20 20`, `circle r 7.4` and a
     `line 5,15 → 15,5`, both 1.5 pt, both `#C08E98` (blush's own line weight), `marginTop 1`.
     Drawn, not an SF Symbol: `nosign` is heavier and reads as a prohibition against the user.
   - Title `cardTitle` 14/600 `textPrimary`; the reason `subline` 12.5 / 1.55 `textQuiet`.
   - **Every denial carries its reason in the row.** A list of five refusals with no reasons is a
     product being difficult; with reasons it is a product with a position.
   - The five, verbatim `[static]`: no weight goal, no calorie target, no step count, no daily
     score, no comparison.
2. **What it does ask** — blush-tinted card, `tint(blush)` at 7 % / border 20 %. Title
   `cardTitle` 13.5/600; body `[static]`: six facts about your body, once, and one question about
   when you sleep. **Everything else on your screens is measured or worked out.**

   This card is what stops the screen reading as a manifesto: it is the one place in the app that
   states the *total* size of what was asked.
3. **Footnote**, verbatim `[static]`: *"These are positions, not features waiting to be built. If
   one of them ever arrives, it will arrive with a reason on this screen."*

**No primary button.** Nothing to accept, nothing to configure. Drawn at true size in
`Noop You - What Noop Will Not Ask`.

---

## 5.15 `apple` — Apple Health

**New.** Reached from the Apple Health card on `strap`. Header: back → `strap`, parent
`Your strap` `[static]`. Title `screenTitle` 25 `[static]` *Apple Health*, sub-line `[formula]`.

**This is the export diagnostic the parity audit asked for, in Noop's register rather than as a
log** (`60-parity.md` Part 3 §A.10).

1. **The two directions** — two cards side by side, `HStack(spacing: 10)`, each `flex 1`,
   radius 20, `padding 15 / 15 / 13`. Caption, then the count at `sectionHead` 26 / Outfit 300
   tabular `[bound]`, then one sub-line `[formula]`. *Noop writes* and *Noop takes* — and the
   taking side is deliberately small: steps, **and only on days the strap could not estimate
   them**.
2. **An imported score never becomes your score** — aura-tinted card, `tint(accent)` at 7 % /
   border 20 %. Title 12.5/600 in `auraPale`; body `[static]`. Another app's readiness or sleep
   score is kept under **its own name** and never shown as Charge, Effort or Rest.

   This card appears on both `apple` and `import` (§5.17). It is the same promise, and it is the
   first question a migrating user asks, so it is stated on both doors rather than once.
3. **Every kind, and what happened to it** — caption `[static]` + a right-aligned diagnostic note
   `finePrint` 11 `[formula]`, then a list card with **one row per HealthKit kind** `[bound]`.
   Per row: a leading state mark, the kind name `rowLabel` 13.5, a right-aligned figure, and a
   sub-line. **Three honest outcomes, not two:**

   | Outcome | Row carries |
   | --- | --- |
   | **allowed** | a written count and a timestamp |
   | **refused** | **the corrective action in the row** — a 29 pt amber button, `effort` at 14 % / border 34 %, label 11.5/600 |
   | **not asked** | its own state, said plainly. Not folded into either of the others |
4. **The sentence that makes the page necessary**, verbatim `[static]`: *"iOS never tells an app
   that a read was refused — a denied kind and a kind with no data look identical from in here.
   That is why this page counts what was written rather than claiming everything worked."*

   **Read this twice before building the page.** It is why the design counts writes instead of
   showing a green tick per kind, and it is a thing the original app never says.
5. **Where your steps came from** — standard card. A 14-day bar row, `height 60`,
   `HStack(spacing: 3)`, `.bottom`, each bar coloured by **which source wrote that day**
   `[bound]`; then a two-item legend — `accent` for the strap, `#5B7C8D` for the phone; then one
   sentence `[formula]` naming how many days came from the phone and why. **Nothing else on the
   page fills a gap that way**, and the sentence says so.
6. **Health holds these, Noop does not use them** — caption `[static]` + list card, one row per
   unused kind `[bound]`, **each saying why** `[static]`, with what Health holds right-aligned.
   An unused kind with no reason reads as an oversight.
7. **Bring history in** → `plumbing/import`. Row card. The page hands off for anything wanted as
   **history** rather than as a **feed** — the distinction the whole of Part 1 turns on.

**States** — bridge off: the two direction cards read an em-dash, every kind row shows *not asked*,
and the page's sub-line says the bridge has not been authorised `[static]`. The unused list still
renders: it is a statement of position, not a status.

---

## 5.16 `automations` — automations

**New.** One door off `settings`, and the row carries **how many are on** `[formula]`.
Header: back → `settings`, parent `Settings` `[static]`. Title `screenTitle` 25 `[static]`
*Automations*, sub-line `[formula]`.

**Every automation here runs on the strap.** They keep working with the phone in another room and
with Noop closed — which is also why turning one on **costs battery rather than attention**, and
why each sub-line is priced in battery rather than in interruptions.

### The strap as a button

Caption + group note `[formula]`, then a list card `[bound]`: **double tap**, **off-wrist**,
**back-on-wrist**, each with a Shortcut option. Toggle rows per §4, aura hue.

### A ceiling, and a nudge

One list card holding a compound control — this is the part of the screen with real behaviour.

1. **Buzz if I go over** — toggle. Sub-line, verbatim `[static]`: *"One buzz when you cross it,
   then nothing until you have been under for a full minute."* The hysteresis is the design: a
   ceiling that re-fires on every wobble across the line is a ceiling nobody keeps on.
2. **When on**, a divided section opens (0.5 pt `hairline` top border) carrying, in order:
   - **mode** — segmented `[static]`: profile zone / fixed bpm.
   - **zone** — segmented `[bound]`, when mode is *profile zone*.
   - **bpm** — a centred stepper when mode is *fixed*: two 34 pt circles, `controlFill` + 0.5 pt
     `controlBorder`, minus and plus drawn as 11 × 1.6 bars; between them the value at
     `sectionHead` 30 / Outfit 300 tabular, `minWidth 104` so the row does not reflow as digits
     change.
   - **Arms at {n} bpm** — a blush-tinted note, radius 14, `padding 11 / 13`: an uppercase eyebrow
     carrying **the resolved number** `[formula]` and one sentence saying **why it moves**
     `[formula]`.

   **The ceiling resolves to a real bpm before it arms, and the screen states the resolved
   number.** A zone is a percentage of a maximum that itself changes; an armed ceiling is a
   boundary in beats. Showing the zone alone would leave the user unable to say what the strap
   will actually do.
3. **Target-zone coach** — toggle, at the foot of the same card. Sub-line carries its **tap
   vocabulary** `[static]`: one tap in the zone, two to push, three to ease off — and names it as
   **the only thing in Noop that buzzes more than once**.

### The passive three

List card `[bound]`: **move reminder**, **stress check-ins** (after an HRV dip), **illness early
warning**.

**The illness row says out loud where its finding lands** `[static]`: in `day/charge`'s ledger,
priced like any other drain, **not as a banner**. That is the more honest register for a signal
that is often a hangover (`60-parity.md` Part 6 item 5), and it is the reason amber stays reserved
for attention on that screen.

**Footnote**, verbatim `[static]`: *"Every automation here runs on the strap. They keep working
with the phone in another room, and they keep working with Noop closed — which is also why turning
one on costs battery rather than attention."*

**Implementation note** — like `notifs`, this screen is **editing device configuration**: the
whole set must be synced to strap firmware, so it needs the **saved to strap** state on its sync
path, not just a toggle that flips.

**Wiring** — `AutomationsView`. Everything here exists; the ceiling's zone-to-bpm resolution is
the one piece that must not be re-implemented in the view.

---

## 5.17 `import` — bring your history in

**New, and the app's front door** (`60-parity.md` Part 1). Reached from `data`. On a sideloaded,
account-free app this is the most load-bearing screen there is: without it, a fresh install is an
empty app with no way in.

Header: back → `data`, parent `Your data` `[static]`. Title `sectionHead` 23 / Outfit 400
`[static]` *Bring your history in*.

1. **The drop target** — **one** target, radius 28, a **1 pt dashed** border `blush 34 %` on
   `blush 5 %`, `padding 24 / 20 / 20`, centred column, `gap 12`. A 46 pt circle in `blush 13 %` /
   border 30 % with a glyph; title `sectionHead` 19 centred; one sentence `[static]`,
   `maxWidth 19em`; then a **46 pt primary in blush** — *Choose a file or folder*; then
   `finePrint` 11 `[static]` noting that sharing to Noop from Files or Mail works too.

   **This is not a source picker, and that is the design.** `ImportCoordinator.detectAndImport`
   takes one URL and works out what it is — by content, not by filename, so a renamed or re-zipped
   export still routes correctly. **One drop target is a smaller screen than one row per source,
   not a bigger one.** A build that ships twelve brand rows has misread the code.

   The dashed border is the app's **only** dashed border. It is the one place a dashed edge means
   what dashed edges mean.
2. **Stored on this phone** — caption + standard card `[bound]`: days and sleeps as two figures at
   `sectionHead` 26 / Outfit 200 tabular with their units between, then the span
   `finePrint` 11.5 tabular. What is already here, before anything is added.
3. **What it can read** — caption + list card, one row per format family `[bound]`: the family
   `rowLabel` 13, and **what to export from that app** `finePrint` 11 / 1.45. A chevron per row.
   **This list is a reference, not a menu** — the sentence under it says so `[static]`: read by
   content, not by filename.
4. **Your scores stay yours** — one closing paragraph `[static]`, `finePrint` 11.5 / 1.55
   `textTertiary`. Noop recomputes Rest, Charge and Effort from the raw heart rate, variability
   and sleep it finds; a brand's own score is kept **for reference** and never shown as one of
   yours — **so your numbers here will not match your old app's.**

   That last clause is the whole point of the paragraph. A migrating user's first question is why
   their old numbers moved, and answering it before they ask is what buys the rest of the app
   credibility.

**The flow is a flow, not a stack**: `import` → `reading` → `imported` **or** `rejected`, and none
of the three carries a back chevron.

---

## 5.18 `reading` — reading a file

**No header chevron. No swipe-back.** In its place, a two-line title block:
*Reading* `rowLabel` 13.5 `textSecondary`, then the source `sectionHead` 23 / Outfit 400 `[bound]`.

1. **Progress** — the percentage at `heroNumeral` **44** / Outfit 200 / tracking −0.04 tabular
   `[bound]` with `%` at `rowFigure` 15, and the **current filename** right-aligned in
   `finePrint` 11.5 **monospaced** `[bound]`. Then a 12 pt track, radius 6, `white 6 %`, with the
   fill in blush.
2. **The method**, one sentence `[static]`: streaming it a piece at a time and aggregating as it
   goes, **so a file this size never has to fit in memory**. A user handing over seven years of
   history wants to know the app will not fall over.
3. **Found so far** — caption + list card, one row per category `[bound]`, count right-aligned,
   **rising as it reads**. Live counts, not a spinner: an indeterminate progress bar on a
   multi-minute read is indistinguishable from a hang.
4. **Stop** — secondary, 46 pt. Sub-line `[static]`: **stopping keeps what has been written
   already**, and nothing here leaves the phone — there is no server to send it to.

**States** — the exits are forward only: on completion → `imported`; on a file it cannot use →
`rejected`. On **Stop** → `import`, which is a forward move to the drop target, not a back.

---

## 5.19 `imported` — what was written

**No header chevron. No swipe-back.** Title block: *Imported · {source}* `rowLabel` 13.5
`[bound]`, then the headline `sectionHead` 23 `[formula]`.

1. **The result** — the day count at `heroNumeral` **44** / Outfit 200 tabular `[bound]` with its
   unit, the **span** below it `finePrint` 12 tabular `[bound]`, and a 34 pt blush confirmation
   disc right-aligned. One tick, not a celebration.
2. **By category** — caption + list card, **one row per category** `[bound]`: the category, a
   note, and the count right-aligned. `ImportSummary` gives `recordCount`, `earliest`, `latest`
   and `countsByCategory`, so **the result state is a per-category count and never a single
   success tick.**
3. **The blank-versus-zero rule**, verbatim `[static]`: *"Only what the export carried was
   written. What it did not carry stays blank rather than becoming a zero — a missing night and a
   bad night should never look alike."*

   **This is the most important sentence on the screen.** Unknown stays nil. A zero-filled gap
   corrupts every average downstream and is invisible once written.
4. **Done** — primary in blush → `data`. **Import something else** — secondary → `import`.
   Both forward.
5. **What happens next** `[static]`: Rest and Charge are being recomputed from what came in, and
   **the first fourteen days carry a *building* chip while the baselines catch up** — the word
   *building* set inline in `serifEmphasis` at 14. This is the confidence chip (§15) doing exactly
   the job it exists for, named at the moment it will first appear.

---

## 5.20 `rejected` — the wrong file

**No header chevron. No swipe-back.** Title block: *Nothing was written* `rowLabel` 13.5, then
what the file actually was, `sectionHead` 23 `[formula]`.

1. **The finding** — amber card, `tint(effort)` at 8 % / border 26 %, radius 24. A glyph and the
   **path, in monospace**, `word-break: break-all` `[bound]`; then the diagnosis `[formula]`,
   `body` 13 / 1.55.

   **The error is specific and one is a worked example.** Hand it Oura's raw `heartrate.csv` and
   it does not say *no usable data*: it says that file is the raw heart-rate log, one row per
   reading, with no daily summary to attach to a date — and then *"There is nothing wrong with the
   file; it is the wrong one of the set."* The error state needs **room for a sentence and a
   corrective action**, not an icon and a retry.
2. **Two ways out** — caption + list card, one row per fix `[bound]`: what to do `rowLabel` 13,
   and why `finePrint` 11.5 / 1.45. Chevron each. Then one sentence naming **which fix is better
   and why** `[formula]`. A choice between two corrections with no recommendation is a shrug.
3. **Choose another file** — primary in blush → `import`.
4. **Nothing changed**, verbatim intent `[static]`: your stored days are untouched — **a rejected
   file is read, judged and dropped.** Amber here is attention, correctly used: something needs
   doing. It is not a failure state and does not read as one.

---

## 5.21 `backup` — backup and sync

**New, and the door out** (`60-parity.md` Part 1). Reached from `data`.
Header: back → `data`, parent `Your data` `[static]`. Title `sectionHead` 23 `[static]`
*Backup and sync*.

**On an app with no account and no cloud, this file is the only way a history reaches another
phone.** Losing the phone means losing the history, and nothing else in the design prevents that.

1. **Last snapshot** — standard card, radius 24. Caption; the age `sectionHead` 21 / Outfit 300
   `[formula]`; the destination and size `finePrint` 11.5 `[bound]`. Right-aligned, a **schedule
   chip** in blush at 12 % / border 30 % with a 5 pt dot `[bound]`. Below a 0.5 pt `hairline`
   divider: the next run and the retention `[formula]`.

   **`BackupSync` gives this screen a *scheduled* state, not just a button** — automatic folder or
   iCloud snapshots with retention, pruning and a staleness check. A screen with only a button
   would throw that away.
2. **Take one now** — caption + list card, **two rows**, one per format `[bound]`, each with an
   upload glyph:
   - **`.noopbak`** — the lossless one. A zip of the full SQLite database, a `settings.json` and a
     manifest recording **which build wrote it**. The phone-to-phone path.
   - **The WHOOP four-CSV zip** — the interoperable one. Re-imports into Noop and into upstream's
     Android build.
3. **The tagging promise**, verbatim intent `[static]`: in the CSV, anything Noop worked out itself
   is tagged `noop (APPROXIMATE)` — set in monospace — and **skipped on the way back in**; Apple
   Health rows are **left out entirely** so they cannot be mis-attributed to a strap.

   **That tagging is a designed honesty guarantee and the screen has to say it.** Both importers
   skip those rows; a user who does not know that will think an export lost data.
4. **On a new phone** — caption + one row card → the restore path. Sub-line `[static]`: replaces
   everything on this phone, and **it will tell you which build wrote the file first**. Restore is
   a **first-class path**, not a footnote under export.
5. **Why it ships with Act 5**, verbatim intent `[static]`: there is no account and no server, so
   this file is the only way your history reaches another phone.

**Import and export are the same two formats read in opposite directions**, which is why §5.17 and
this screen are one family off `data` rather than two features in different drawers.
