# Designer answers — 9 September

*The four source-of-truth questions left open on 8 September, settled. Bounded: nothing else was
reopened or re-audited.*

**The HTML is authoritative.** Every answer below landed in the act sources first
(`app/Noop Act 7 - Svea.dc.html`, `app/Noop Act 8 - Goals and Labs.dc.html`); the spec follows them.
Where a number appears in copy it is now **computed in the source**, not typed into a sentence.

---

## 1 — API key: five states, no hardcoded suffix, no promised latency

Full table in `acts/46-act7-svea.md` §7.3.2. In short:

| State | Row | Test button |
| --- | --- | --- |
| **Not set** | *No key yet* in `textDim` · action **Add key** | inert, labelled *Add a key to test it* |
| **Entry** (from *Add key* or **Replace**) | the row becomes a masked `type="password"` input — autocorrect and autocapitalise off, paste allowed — with an inline **Save** (inert under 8 characters) and **Cancel** beneath, beside *Masked as you type, and not shown again once saved. Nothing is stored until you save it, and nothing is sent until you test it.* | unchanged |
| **Set** | `•••• •••• •••• ` + **the last four of the string that was saved** · action **Replace** | *Test the connection* |
| **Testing** | untouched | *Testing…*, 70 % opacity, inert — **indeterminate; no duration is predicted** |
| **Answered** | untouched | green: *Connected · {provider} answered*, plus a green-dot card saying the test sends no data from the app and the answer is not kept |
| **Failed** | untouched, and **nothing stored changes** | amber *Test again*, plus a card with the failure and **Try again** / **Replace the key** |

**Replace now opens the input** — that was the defect. It is the same input as first entry, it
clears the stored test result, and the draft is never persisted.

**Three failures, because the fix differs:**

1. *Your provider refused the key* — it answered and rejected it; replacing is the only fix.
2. *The request never left the phone* — no network; nothing sent, nothing stored changed.
3. *Your provider answered with an error* — the key works, the account is out of credit or over its
   own rate limit; their side to fix.

**No latency anywhere.** `1.2s` is gone and nothing replaces it: a round-trip time is not something
a person can act on, and a fixed one is a lie. **No key suffix is written by hand.** The prototype
seeds one clearly-named demo string and masks it to *its own* last four; `keyCase` reaches the
*Not set* state and `testOutcome` reaches the three failures.

---

## 2 — Manual lab entry: **nine**, and they are the nine `labs` keeps

Nine, because a typed value must have somewhere to live: the by-hand sheet and the Biomarkers list
are now **one list**. `labs` therefore holds nine markers, not seven — Haemoglobin and Creatine
kinase were added with bands, and the ring reads *of 9 in band*.

| # | Field | Unit | Band |
| --- | --- | --- | --- |
| 1 | Haemoglobin | g/L | 130–170 |
| 2 | Ferritin | µg/L | 30–400 |
| 3 | Vitamin D | nmol/L | 50–125 |
| 4 | ApoB | g/L | 0.5–1.0 |
| 5 | HbA1c | mmol/mol | 20–42 |
| 6 | hs-CRP | mg/L | 0–3 |
| 7 | TSH | mIU/L | 0.4–4.0 |
| 8 | ALT | U/L | 10–50 |
| 9 | Creatine kinase | U/L | 30–200 |

Order is the order a printed panel runs, so the eye can follow a sheet down the screen.

**Nine is the by-hand list; four was one photograph.** The photo route shows whatever the sheet
printed — four rows in the demo sheet — and its title says four *because four were read*. The two
counts never needed reconciling; the screen just had to stop claiming one and rendering the other.

**One input open at a time.** Nine simultaneously-open inputs is a wall, so a row starts collapsed
at `—` / *not filled in* with **Type it in** / **Leave it out**. Typing opens the same input the
photo route uses (**Use this value** / **Cancel**), noted as *stored as entered rather than read*.
Cancel closes without deciding; *Leave it out* is the explicit decline; both are undoable, and a row
left alone is not stored — not as a value, and not as "you declined this".

---

## 3 — Goal safety: one formula, and every figure computed from it

```
weekly build   = (peak ÷ now) ^ (1 ÷ building weeks) − 1
building weeks = weeks to the date − 2 easy weeks − 1 taper week
```

Tolerance is **this person's history, not a rule of thumb**: `absorbed = 5%` is the steepest weekly
build their last two blocks took without a poor night; `ceiling = 10%` is where Noop stops building.
Those are the only two thresholds, and the copy names them and nothing else.

The three verdicts differ in **one input** — the peak the finish they asked for requires — off the
same 34 km a week and the same eleven weeks, eight of them building:

| Ask | Peak | Build | Verdict |
| --- | --- | --- | --- |
| Finish comfortably | 48 km | **4.4 %** | inside 5 % — *the data says yes* |
| Under two hours | 55 km | **6.2 %** | over 5 %, under 10 % — *possible, with one condition* |
| Under 1:45 | 75 km | **10.4 %** | over the 10 % ceiling — *the data says not by then* |

Alternatives quoted in the fix lines are the same function re-run: 55 km over twelve building weeks
(23 November) is **4.1 %**; 75 km over twenty-six (8 February) is **3.1 %**.

`12%` and `19%` are gone, and so is the possibility of them coming back: **no build figure is
written into copy** — the verdict body, the fix line, the safety line, the commit confirmation and
the waypoint label all interpolate the same computed values, and the route's peak label follows the
same `peak` (48 km on the committed route, not 55). The evidence bars are real ratios too: longest
run ÷ the long run the route needs, volume ÷ peak, and absorbed ÷ the build this asks for.

---

## 4 — Proactive Svea: default, delivery, limits, and pause vs revoke

**Release default: `never`.** Proactive contact is opt-in; nothing runs in the background until
someone picks a level. The *Never* row says so on its sub-line — *where this starts*.

**Delivery is never promised.** iOS decides when a background wake happens, so the copy describes
the trigger and not a time: *the first time iOS wakes Noop after 04:00 — usually before you are up,
sometimes not at all.* **Nothing is queued and nothing is retried**; a window iOS never wakes for is
a morning without a brief, and a missed window is skipped rather than caught up.

**Rate limits, on the row that grants them:**

| Level | Limit |
| --- | --- |
| *Never* | no background contact of any kind |
| *When something changed* | **one request a day**, on the first wake after 04:00 |
| *Freely* | **at most one an hour, six a day, none between 22:00 and your wake** |

**Two verbs, and they are not the same one** — which is what the old files got wrong by using both
for both:

- Moving **this row** back to **Never revokes**: the scheduled work is cancelled and the permission
  dropped in the same write. There is nothing kept and nothing to restore.
- Setting the **voice to Off pauses**: the same work is cancelled, but **the saved level is kept and
  restored** when a voice comes back on. The screen says so where it matters — *your saved choice is
  paused, not forgotten*.

There is still no "off but still armed" state, and no pending request survives either change.

---

## What this does not close

Unchanged from `CLOSURE.md`: the four `.ttf` binaries remain an external prerequisite, the Swift
sources have still not been compiled, and nothing mechanically prevents a hand edit from
reintroducing a duplicated route matrix. The mechanical HTML/Swift corrections the coders listed as
theirs are theirs — the one exception is Act 7's render crash (`voiceOff` used above its
declaration), fixed here only because it blocked verifying the key states.
