# Act 7 — Svea (the coach)

*Screen specs. `00-RULES.md` and `20-primitives.md` are binding.*

Tags: `[static]` fixed by design · `[bound]` real data · `[formula]` derived · `[proto]` do not build.

**Five screens**, home is `coach`. Lavender (`139,153,214`) for the act's chrome; the ambient hero
glow is 480 × 420 at top −170, lavender at 16 %, blurred 18 (`10-tokens.md` §*Gradients and shadows,
as built*).

**The coach card is the 158° directional accent card**, not a vertical two-stop surface:
`linear-gradient(158deg, rgba(139,153,214,.16), rgba(139,153,214,.03))` over a 0.5 pt
`rgba(139,153,214,.30)` border. On `today` it is radius 20; on this act's own rows, radius 24. The
brief card at the top of `coach` is its 160° sibling at `.14 → .03`, radius 26. **There is no
`coachSurfaceTop → coachSurfaceBottom` gradient anywhere in the app** — that token pair
(`#18211E → #121615`) was a near-black vertical ramp that appears in no source, and it is deleted
(`12-palette-bindings.md`).

## The + focuses the Ask field

Act 7 has its own input, so the + is not a navigation and not a sheet: **it focuses the Ask field
at the foot of `coach`**, arriving there first if you are on another screen in the act. Focused, the
field takes a `rgba(139,153,214,.55)` border, a 3 pt `rgba(139,153,214,.14)` ring and a caret; the
placeholder loses its ellipsis. `30-routes.md` §*The +* is the table for all nine acts.

---

## 7.1 `coach` — Svea

**Header** — home style.

1. **The brief** — the 160° lavender card. Eyebrow `[formula]`: *Today's brief · {time}* when a
   brief was fetched, ***Not briefed · off*** when the voice is Off. Then the brief itself `[bound]`,
   one paragraph per line, and a *Grounded in — measured* strip of the signals it actually read
   `[bound]`.
2. **A proposal** — standard card `[bound]`. **The instruction comes first and the receipt
   second, always** — a receipt opened with ("HRV 45 % over baseline") is the complexity this
   direction exists to remove. Nothing enters the day until the proposal is accepted, and the card
   says so `[static]`.
3. **The thread** `[bound]` — the exchange, including Svea's **declining** state, which is a normal
   outcome and not an error.
4. **Ask** — a text field row `[bound]`, pinned above the tab bar with its two prompt chips.
   `NoopLiquidGlassSearchField.swift` exists; re-tint to `controlFill` + `controlBorder`, radius 22,
   do not use its glass treatment on this canvas.
5. Rows: **What she remembers** → `svea/memory` · **What she may read** → `svea/consent`.

**States** — **no provider set**: the screen is replaced by `svea/gate`. Not a banner, not a
disabled field — the gate is the screen.

---

## 7.2 `gate` — no provider

**No back chevron, and no entry in the back map** (`30-routes.md`). There is nothing behind it: no
provider is set, and the way on is `setup`. This spec said *back → `coach`*, which was the stale
half of a route the map had already corrected.

Hero: the gate orb `[static]` — a 132 pt morphing radial with a 190 pt blurred halo and 26 drifting
specks, on `sveaPulse 8s` / `sveaSpin 64s`. Then a `[static]` title and a body paragraph saying
plainly that Svea needs a provider and a key, that the key stays on the phone, and what it costs.
Primary button `[static]` **Set up a provider** → `svea/setup`; secondary → `svea/consent`.
Everything else on the screen: nothing. The gate does not pad itself.

---

## 7.3 `setup` — provider and key

Header: back → **`coach`**, parent `Svea` `[static]`. Not `gate` — `gate` has no back of its own and
is not a screen you return *through*; the source's chevron reads *Svea* and lands on `coach`.

1. **Provider** — a wrapping chip row `[bound]`: Anthropic · OpenAI · Gemini · OpenRouter · Custom.
2. **API key** — a 48 pt row `[bound]`, in **five states**. This is settled; the HTML is the
   reference (`app/Noop Act 7 - Svea.dc.html`, §*the key, in five states*).

   | State | The row | The Test button below it |
   | --- | --- | --- |
   | **Not set** | value slot reads *No key yet* in `textDim`; the action beside it reads **Add key** | inert, and it says why: *Add a key to test it* |
   | **Entry** — after *Add key* or **Replace** | the row **becomes an input**: `type="password"`, autocorrect / autocapitalise off, paste allowed, masked as you type. **Save** sits inside the field and stays inert under 8 characters; **Cancel** sits under it beside the line *Masked as you type, and not shown again once saved. Nothing is stored until you save it, and nothing is sent until you test it.* | unchanged, still reading the previously stored key's state |
   | **Set** | `•••• •••• •••• ` + **the last four characters of the string that was saved** — derived, never a literal. Action: **Replace** | *Test the connection* |
   | **Testing** | unchanged and untouched | label *Testing…*, 70 % opacity, inert. **Indeterminate — no duration is predicted** |
   | **Answered** | unchanged | green fill, *Connected · {provider} answered*, and a green-dot card: the test sends no data from the app and the answer is not kept |
   | **Failed** | unchanged; **nothing that was stored changes** | amber label *Test again*, plus an amber card carrying one of the three failures below and two buttons, **Try again** / **Replace the key** |

   **Three failures, because the fix differs** `[bound]`: *Your provider refused the key* (it
   answered and rejected it — replacing is the only fix), *The request never left the phone* (no
   network; nothing was sent and nothing stored changed), *Your provider answered with an error*
   (the key works, the account is out of credit or over its own rate limit — their side to fix).

   **There is no Reveal**, and **no latency is ever shown.** The key is in the iPhone keychain,
   excluded from backups, never written to the export file, and **Noop cannot read it back out to
   show you — only replace it.** A Reveal button contradicts that sentence, needs a second read
   path into the keychain to exist at all, and puts a live credential on a screen someone is
   holding in public. Replace writes a new key, drops the old one and clears the test result;
   there is no *edit in place*, and the draft is never persisted.

   **No fake key may reach a release build.** The prototype seeds one demo string and masks it to
   its own last four (`8f2c`); the *Not set* state is reachable in the prototype through the
   `keyCase` prop, and the three failures through `testOutcome`.
3. **A model per job** — list card `[bound]`, three rows (the daily brief, conversation, charts) with
   the provider's own model ids.
4. **Test** secondary button, 44 / 15, lavender; the five states are in the table above. It is
   **indeterminate while testing and states no duration afterwards** — a round trip time is not a
   number a person can act on, and a fixed one is a lie.
5. **How it talks** — see §7.3a and §7.3b below.
6. **What Svea may read** — the 158° lavender row → `svea/consent`, with the grant count `[formula]`.

### 7.3a Voice — four choices, and Off is one of them

**Plain · Quiet · Direct · Off.** Exactly four, in that order, as chips. Each carries a `[static]`
note under the row saying what it does to the writing:

| | What it is |
| --- | --- |
| **Plain** | Three short paragraphs, in sentences. The default, and the only one that explains itself |
| **Quiet** | One line, no reasoning |
| **Direct** | Two lines, imperative — it will not soften a call you may disagree with |
| **Off** | **Svea says nothing unprompted and makes no request in the background.** Ask her something and she answers; nothing else reaches out, and the morning brief is not fetched |

**Off is not a fourth register — it is a switch.** It suppresses proactive speech *and* proactive
contact: while it is set, §7.3b's three rows are **held at Never**, dimmed to 38 %, and inert; the
brief is not requested; and `coach`'s brief card carries the *Not briefed · off* state rather than a
brief written in a default voice. **Off pauses; it does not revoke** — the saved level is kept and
restored the moment a voice comes back on, and the copy on the screen says so.

### 7.3b How often it speaks first — and what that permits

Three rows, radio marks `[bound]`: **Never** · **When something changed** · **Freely**.
**Never is the release default** — proactive contact is opt-in, and nothing runs in the background
until someone picks a level here. The *Never* row says so on its sub-line: *where this starts*.

Anything above Never is **permission for Svea to call the provider with Noop in the background**,
which is a request leaving the phone with nobody watching. So:

- **The permission is named on the row that grants it**, with its rate limit and its scheduling
  language `[static]`. *When something changed* — one request a day, on your key, the first time
  iOS wakes Noop after 04:00, **usually before you are up, sometimes not at all**; nothing is
  queued and nothing is retried. *Freely* — requests through the day whenever iOS wakes Noop, **at
  most one an hour, six a day, none between 22:00 and your wake**.
- **Delivery is never promised.** iOS decides when a background wake happens; a window it never
  wakes for is a morning without a brief, not a queued request. No copy anywhere may state a
  delivery time (`44-act5-plumbing.md` §5.16's execution-site rule).
- **A confirmation strip below the group restates it** while any proactive setting is active
  `[formula]`: Noop wakes, builds the same granted summary, calls your provider, **posts no
  notification**, nothing is stored on the provider's side by Noop, and a missed window is skipped
  rather than caught up.
- **The state is persisted with the choice**, not asked for again each time. One setting, one
  stored value; there is no separate system permission to request, because this is Noop's own
  background work rather than an OS capability.
- **Two verbs, and they are not the same one.** Moving **this row** back to Never **revokes**:
  the scheduled work is cancelled and the permission dropped in the same write, with nothing to
  restore. Setting the **voice** to Off **pauses**: the same work is cancelled, but the saved level
  is kept and comes back when a voice does. There is no "off but still armed" state, and no
  pending request survives either change.

---

## 7.4 `consent` — purpose by purpose

Header: back → **`setup`**, parent `Provider and key` `[static]`. Consent is a step inside setting a
provider up, and the source's chevron reads *Provider and key*. This spec said *back → `coach`*.

1. **What leaves the phone** — the 158° **aura** card at `.10 → .02`, border `.24`: three rows
   `[static]` — stays here always, goes out when you ask, never goes out.
2. **Pick a level** — three preset chips `[bound]`: Essentials · Personal · **Deep insights**, with
   a `[static]` note per preset. Editing any switch by hand drops the preset label, and the note
   says so rather than pretending one still applies.

   **Deep insights is confirmed separately, before anything is granted.** Tapping it does **not**
   change the grant map. It raises an amber confirmation card `[static]` naming what the level turns
   on — **sensitive journal topics** (mood, medication, cycle, anything marked private) **and lab
   results** — stating that those go out in the prompt text, and offering **Turn sensitive topics
   on** / **Keep them out**. Only the first applies the preset.

   This is the one grant the app will not switch on from a preset tap, and the reason is the same one
   the picker screen gives for the lab photo: this is the most exposed material a person has in the
   app, and a single tap on a chip labelled with a benefit is not consent to it. Essentials and
   Personal apply immediately — neither touches the sensitive rows.
3. **Purpose by purpose** — list card, **one toggle per purpose** `[bound]`, seven of them, not one
   blanket switch. Each sub-line says exactly what is sent for that purpose `[static]`; the
   **sensitive** row carries its own amber marker. Every one is **revocable**, and an off row states
   what stops working `[static]`.
4. **The prompt, as it would go out** `[bound]` — the real lines, with ungranted ones struck
   through. Ungranted material is **removed before the request is built**, not filtered from the
   reply, and the card says so.
5. Footnote `[static]`.

---

## 7.5 `memory` — what she remembers

Header: back → `coach`, parent `Svea`.
1. List card of remembered facts `[bound]`, each with a **Forget** action whose sub-line states the
   consequence `[static]`.
2. **Forget everything** destructive button — states what it destroys `[static]`. No confirmation
   sheet here (the consequence is in the row); the confirmations this act does have are Deep
   insights in §7.4 and nothing else.
3. Empty: one sentence `[static]`.
