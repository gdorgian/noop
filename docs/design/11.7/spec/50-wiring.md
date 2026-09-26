# The wiring sheet — what feeds every bound value

*Foundations pack, 5 of 5. Read after `00-RULES.md`. This is the document that answers "can we actually build this against the app we have", screen by screen, against the real codebase.*

Every `[bound]` and `[formula]` value in the 69 screens is listed here with the thing in the
codebase that feeds it. Four statuses:

| Status | Meaning |
| --- | --- |
| **wired** | The symbol exists and returns what the screen shows. Bind it and move on. |
| **derive** | The inputs exist; the number the screen shows does not. New work, specified in Part 1. |
| **decide** | Two or more real answers exist in the codebase. A human picks, once, before the screen is built. |
| **outside** | Not app code. Firmware, a platform limit, or a measurement someone has to take. |

The count: **six things need a new derivation, three need a decision, three sit outside the app.**
Everything else — the large majority of all 69 screens — is binding work against symbols that
already exist and already carry the honesty rules this design assumes.

---

# Part 1 · What nobody owns yet

Ordered by how much of the design stops without it.

## 1 · Charge as a battery that empties **derive**

**The design shows.** Today's state line: *"You woke with 92 and you have 61 left."* A whole screen
(`day/charge`) that prices each drain — *walk to the station, −8* — a bar of spent-versus-remaining,
and what tonight puts back. Live during a session: *charge spent so far*. After a session: *what it
cost*. In `effort/pick`: what each alternative would cost. On the Charge widget. And in `goal/set`,
where a goal that conflicts with the Charge model must say so.

**What exists.** `RecoveryScorer.recovery(...)` gives the **morning** number, 0–100 — the value the
design calls *what you woke with*. `RecoveryScorer.chargeDrivers(...)` explains why that morning
number landed where it did, in real marginal points per physiological term. `ActivityCostEngine`
prices a **sport**, as a historical average: how far below your rest baseline your next-morning
Charge sits after a session of this kind, and how many days it takes to bounce back.
`RecoveryForecaster.forecast(...)` estimates tomorrow morning.

**What is missing.** Nothing in the codebase decrements a number *during the day*. There is no
intraday charge-now, no per-event price at the moment the event happened, no ledger that sums to
the gap between wake and now. The battery is the design's central metaphor and it is the one thing
the app cannot currently compute.

**The decisions, in the order they have to be made.**

1. **Does the ledger have to balance?** The design implies yes: every drain is priced and the
   remainder is what is left. If the priced drains do not sum to `wake − now`, there must be an
   honest row for the difference (being awake at all is a cost) or the bar has an unexplained gap.
2. **What spends charge?** Cardiovascular load is the obvious term (`StrainScorer` already produces
   it intraday). Stressed minutes (`DaytimeStress`, `StressOnsetDetector`) plausibly do too, and the
   design's Stress screen implies they cost something. Sedentary hours (`SedentaryDetector`) may
   cost nothing at all. Pick the terms; each one you add is a claim.
3. **Is a price ever refunded?** The design's bar only empties. Decide whether a calm afternoon can
   push it back up, or whether only sleep repays.
4. **What does a session cost right now, before it has a next morning?** `ActivityCostEngine` answers
   for sessions like this one, on average, from your own history — which is a legitimate prior for
   `effort/pick` and a **defensible** live price, but it is not a measurement of this session. Say
   which one the number is, in the copy, once.
5. **Cold start.** `ActivityCostEngine` omits a sport under four tagged sessions and returns nothing
   without untouched rest days. The Charge screen needs a real state for "no priors yet" beyond the
   spec's existing empty state.

**Suggested shape.** A `ChargeLedger` in `StrandAnalytics`, pure and deterministic like its
neighbours: in — the morning recovery, today's intraday strain series, stressed minutes, tagged
events with their start times; out — `level`, `wake`, and `[ChargeDrain]` of
`(label, sublabel, cost, startedAt)`, ordered, with the residual row included. The screen spec's
rule that *a drain appears only once `startedAt <= now` and `cost > 0`* is then a filter over that
array, not logic in the view.

**What unblocks first.** `day/charge` is unbuildable without it; Today, `effort/live`,
`effort/detail`, `effort/pick` and two widgets each show one number from it.

## 2 · The word "Charge" already means two things **decide**

In the codebase, **Charge is the recovery score** — `ChargeDrivers`, "Charge points",
`recoveryByDay`, `RecoveryForecast.charge`. In this design, **Charge is a battery that empties over
the day**. One is a 0–100 verdict on your night; the other is a running balance. They are not the
same quantity, and a coder reading both will wire one into the other without noticing.

Pick one, this week, before any Charge screen is built:

- **Keep both, one scale.** Charge-at-wake *is* the recovery score, and charge-now is that number
  minus the day's spend. Cleanest, and the design already reads this way.
- **Rename in the engine.** The screens keep "Charge"; the score becomes Recovery internally.
  Honest, and a large diff across Swift, Kotlin and the CHANGELOG.

Whatever is chosen, `chargeDrivers(...)` has a home this design does not currently give it: it
answers *why you woke with 92*, which no screen asks. The natural place is a section on
`day/charge` above the ledger, or a push from the state line. Worth adding — it is real, it is
already written, and it is exactly the "show the evidence" voice the rest of the app uses.

## 3 · Which number is "body age" **decide**

`ages` shows a body age hero, a fitness age row, and a drivers list. The codebase has **three** age
engines and they are unrelated:

| Engine | Answers | Shape |
| --- | --- | --- |
| `FitnessAgeEngine` | cardiorespiratory fitness vs a typical person | one age + VO₂max + a readiness checklist |
| `VitalityEngine` | the measured hazard sum, in years | one age |
| `BioAge.score(...)` → SuperAgeCore | five weighted domains (cardiovascular, activity, body composition, recovery, lifestyle) | five domain scores + evidence completeness |

The mapping that fits the screen: **hero = `VitalityEngine`**, **row = `FitnessAgeEngine`**,
**drivers list and `ages/driver` = `BioAge` domains** — the only one of the three with a breakdown,
which is what the drivers list is. Confirm it, then write it down, because two of these types are
both called some flavour of `FitnessAgeResult` and resolve by import order.

Free win: `FitnessAgeEngine.assessReadiness(...)` returns exactly the per-input progress list
`ages/building` specifies, including which inputs are required and how complete each one is. The
first-week screen is already computed.

## 4 · Buzz for notifications **outside**

The screen is fully specified and cannot be built as app code. iOS hands no app another app's
notifications. The route is the strap as an **ANCS** consumer over BLE, which means:

- Firmware work, not app work, for the buzzing itself.
- The allow-list and the four conditions are **device configuration** and must sync to the strap,
  which decides at buzz time, offline. That is the twelfth state the act spec calls for: *saved to
  strap*.
- **The eight app rows cannot be pre-populated.** iOS will not enumerate installed apps. The list
  can only be *learned* — apps appear as ANCS delivers their first notification. So the screen's
  real first state is nearly empty, and the design needs one more state than it has: *"Apps appear
  here as they first buzz."* The eight rows in the spec stay as intent (chat and calls on, feeds and
  newsletters off), applied to whatever arrives.
- The **4 %** battery figure in the footnote is `[proto]`. Measure it and put the real number in the
  copy before this ships.

## 5 · Lab markers from a photo **derive**

Everything else in Act 8's biomarkers is built: the Lab Book holds ~30 markers, imports CSV,
carries reference ranges and trends, and can line a marker up against a wearable signal. What does
not exist is `goal/review` — reading markers **off a photo**. That is Vision text recognition, a
layout parse of a lab report, a mapping onto the known marker set, and a per-field confidence that
drives the screen's *Check this* chip. It is a self-contained project, and the honest v1 is to ship
`labs` with CSV import and hold `review` until someone owns the OCR.

## 6 · The widget snapshot **derive**

The WidgetKit target exists. What the three widgets need is a small piece of plumbing: a shared
app-group snapshot written on every sync — level, wake, state label, last night's duration and
stage totals — so the widgets read a file and, per the spec, **never wake the strap**. Small, but
nothing renders without it.

## 7 · Two smaller open items

- **Light appearance** `decide`. Designed values exist for dark only. Ship the setting; Light and
  System resolve to the dark scene until someone designs the light one. Do not half-flip tokens.
- **Past-day read-only** `wired, verify`. The day navigator replaces every live figure with its
  recorded value. `AnalyzeRecentDayCache` and the `DailyMetric` rows carry that;
  `DayOwnerResolver` owns which day a reading belongs to. Confirm every figure on Today has a
  recorded counterpart before shipping the navigator, or the em-dash path will be doing more work
  than intended.

---

# Part 2 · Traps

Five ways to wire something to the wrong real symbol. Each of these compiles.

1. **`RhythmScreener` is not `trends/rhythm`.** It is a heart-rhythm screener. The Rhythm line is
   about sleep timing: `SleepRegularity`, `SleepSchedule`, `CircadianEngine`.
2. **`avgHrv` is RMSSD; SuperAgeCore wants SDNN (`avgSdnn`).** `BioAgeInputs` says so at the top of
   the file. Reaching for the field named `avgHrv` skews the recovery domain and nothing ever errors.
3. **`ActivityCost.delta` is a per-sport historical average, not this session's cost.** Positive
   means the morning after sits below your rest baseline. It is a prior; do not print it as a
   measurement of the session that just ended.
4. **`RecoveryForecast` carries a ± band and a confidence tier.** The design's "tonight puts you
   back to about {n}" shows a single number. Either show the band or state in the copy that the
   number is approximate — the engine is explicitly an estimate, not a measurement.
5. **`BioAge.score(...)` returns nil** for an under-18 profile or when no instruments are present,
   by design, rather than returning the neutral value that maps to chronological age. That nil is
   the `ages/building` state, not an error.

And the one from `00-RULES.md` §9 that is worth repeating here because it is a data-layer mistake as
much as a colour one: **`NoopPalette`, never `StrandPalette`**, on every screen in this pack.

---

# Part 3 · Act by act

## Act 1 · The night

| Screen · element | Feeds from | Status |
| --- | --- | --- |
| `rest` duration, hypnogram stages | `SleepStager`, `SleepStageTotals`, `StagePercentages`, `Hypnogram.swift` | wired |
| `rest` delta vs need | `AnalyticsEngine.Rest.defaultNeedHours`, personal need from the Rest engine | wired |
| `rest` one-line verdict, headline by band | `SleepReadout` | wired |
| `rest` strap battery chip | `BatteryEstimator`, `ConnectionReadout` | wired |
| `tonight` bedtime anchor | `SleepSchedule`, `CircadianEngine.estimatePhase` | wired |
| `tonight` what tonight puts back | `RecoveryForecaster.forecast(...)` | wired |
| `tonight` wind-down nudges | `AutomationsView.swift` / notification settings | wired |
| `why` score restated + contributors | `RestSubScoreTrace`, `RecoveryScorer` sub-scores | wired |
| `debt` total, 14-night strip | `SleepDebt` | wired |

## Act 2 · The day

| Screen · element | Feeds from | Status |
| --- | --- | --- |
| `today` pulse on the orb | `LiveState` / BLE live HR | wired |
| `today` breathing word, orb pacing | `BreathPacer`, `BreathProtocol`, `BreathProtocolCatalog` — pace the orb from the engine, not from a CSS keyframe | wired |
| `today` day navigator, past-day values | `DayOwnerResolver`, `AnalyzeRecentDayCache`, `DailyMetric` | wired |
| `today` state line: woke with / left | wake from `RecoveryScorer.recovery(...)`; **left** has no source | **derive** (Part 1 §1) |
| `today` last night row | `SleepReadout` | wired |
| `today` Svea prompt + receipt | `AICoach` coaching call | wired — **copy is not bound to a type.** The instruction and its receipt are written per `70-copy.md` and the generated-string tables in `Noop - Build Document.dc.html` §on-screen sentences. The deleted body-state type's strings are not the reference |
| `today` day shape strip | `ActivityHeatmap`, intraday HR/motion series | wired |
| `today` heart / vitals / stress rows | `LiveState`, `Baselines`, `DaytimeStress` | wired |
| `charge` hero, bar, every ledger row, tonight's repayment | **the ledger does not exist**; repayment from `RecoveryForecaster` | **derive** |
| `charge` why you woke there (proposed) | `RecoveryScorer.chargeDrivers(...)` — already written, currently unsurfaced | wired |
| `day` 24-hour timeline, logged events | intraday series, `AutoWorkoutDetector`, manual logs | wired |
| `vitals` values, your-normal band, baseline line | `Baselines` / `VitalBands` configs, `SkinTempDisplay`, `RecoveryScorer.skinTempRelative(...)` | wired |
| `stress` minutes, day strip, stretches | `DaytimeStress`, `StressIndex`, `StressOnsetDetector`, `DaytimeBaselines` | wired |
| `heart` live figure, trace, resting / max / HRV | `LiveState`, `OverviewHRChart.swift`, `PrimarySessionRestingHR`, `HRVAnalyzer` | wired |

## Act 3 · The effort

| Screen · element | Feeds from | Status |
| --- | --- | --- |
| `session` recommendation + receipt | `EffortFeasibility` | wired — the receipt is plain language with **no units**, per `70-copy.md` rules 3 and 7; wording from the Build Document's generated-string table, not from a deleted type |
| `session` week bars, last session | `StrainScorer`, `AutoWorkoutDetector`, `SportIcon.swift` | wired |
| `pick` alternatives, what each costs in charge | list is wired; the cost is `ActivityCostEngine` **as a prior** | derive (Part 1 §1, §Trap 3) |
| `ready` strap check rows | `ConnectionReadout`, `BatteryEstimator` | wired |
| `across` range, tiles, per-sport rows, session rows | `WorkoutsView`'s own query (7D/30D/90D/1Y/All), `StrainScorer`, `SportIcon.swift` | wired |
| `across` source chip per row | the importer that wrote the row — `ImportSummary` provenance, `WhoopExportImporter` / `AppleHealthImporter` / the strap | wired |
| `across` charge spent, minutes added to the nights after | `ActivityCostEngine` summed over the window **as a prior**, same caveat as `pick` (Trap 3) | derive |
| `live` elapsed, live HR, zone strip, load | `LiveSessionEngine`, `LiveState`, custom zones from the profile | wired |
| `live` charge spent so far | **no source** | **derive** |
| `intervals` interval runner | `LiveSessionEngine`, `HRDownPacer`, `HRCeilingAlertEngine` | wired |
| `detail` duration, zones, trace, splits | `ManualWorkoutRescore`, `OverviewHRChart.swift`, session store | wired |
| `detail` what it cost | **no source** | **derive** |

## Act 4 · The bigger picture

| Screen · element | Feeds from | Status |
| --- | --- | --- |
| `trends` four lines, values, sparklines | `RangeReport`, `ComparisonEngine`, `Sparkline.swift` | wired |
| `trends` per-line verdicts | `RangeReport` + `BehaviorInsights`; the shortest window is `[static]` *"Too early to say."* — do not compute one | wired |
| `trends` body age row | see Act 6 · Part 1 §3 | decide |
| `trends` log sheet + filters | `history` data, filter state persists | wired |
| `capacity` figure, chart, what moved it | `StrainScorer`, `ReadinessTrainingLoad`, `EffectRanker`, `CorrelationEngine` | wired |
| `rhythm` phase plot, drift sentence | `SleepRegularity`, `SleepSchedule`, `CircadianEngine` — **not** `RhythmScreener` | wired |
| `year` heat strip, three numbers | `ActivityHeatmap`, daily rows | wired |

## Act 5 · The plumbing

| Screen · element | Feeds from | Status |
| --- | --- | --- |
| `you` 24-hour ring: sleep arc, anchor, usual wake, now-marker | `CircadianEngine.estimatePhase(...)` (acrophase, temp-min, offset vs schedule, confidence), `SleepSchedule` | wired |
| `you` portrait / initials | `ProfileAvatarView.swift` | **extend** — the photo path is wired; the no-photo fallback is `BrandMark` and must become the user's initials (see `44-act5-plumbing.md`) |
| `you` row sub-lines (e.g. strap battery + last sync) | `BatteryEstimator`, `ConnectionReadout` | wired |
| `record` every field, imperial entry, HR max, step calibration | `SettingsView.swift` (`measureField`, `poundsField`, `feetInchesField`, `hrMaxField`), `StepsEstimateEngine`, `MetricArbitrationPolicy` | wired |
| `zones` five zones | custom zones in `SettingsView.swift` | wired |
| `history` records, grouped, filtered | day store + `AutoWorkoutDetector` + manual logs | wired |
| `strap` battery ring, days left, sensors priced in battery hours | `BatteryEstimator` | wired |
| `strap` connection, secure link, sync states | `ConnectionReadout`, HealthKit sync | wired |
| `strap` log copy / save / auto-export | raw-CSV export (#322/#276), `CsvExport` | wired |
| `notifs` everything | ANCS on the strap | **outside** (Part 1 §4) |
| `devices` known straps | `StrapComparison`, pairing store | wired |
| `pair` three-step flow | BLE pairing | wired |
| `data` what is recorded / what leaves / delete | `DataBackup`, `CsvExport`, the data store | wired |
| `settings` eleven groups | `SettingsView.swift`, `AutomationsView.swift`, `NotificationSettingsView.swift`, `StreakCalculator` | wired |
| `settings` Appearance: Light | designed for dark only | decide (Part 1 §7) |
| `widgets` three previews and the real widgets | WidgetKit target exists; the app-group snapshot does not | **derive** (Part 1 §6) |
| `lab` experimental readings, probes, exports | `PuffinExperiment` flags, `TestCentreLayout`, `TestDomain`, raw-CSV export | wired |
| `onboard` card stack | first-run flow | wired |

## Act 6 · Your ages

| Screen · element | Feeds from | Status |
| --- | --- | --- |
| `ages` body age hero | `VitalityEngine` (proposed) | **decide** (Part 1 §3) |
| `ages` fitness age row | `FitnessAgeEngine` | wired |
| `ages` drivers list | `BioAge.score(...)` five domains | decide |
| `building` progress per input | `FitnessAgeEngine.assessReadiness(...)` — returns the exact checklist | wired |
| `driver` contribution, trend, what would move it | `BioAge` domain scores, `TrendChart.swift` | wired |
| `health` readings with your-normal bands | `Baselines` / `VitalBands`, `DailyMetric` | wired |

## Act 7 · Svea

| Screen · element | Feeds from | Status |
| --- | --- | --- |
| `coach` the call + receipt | `AICoach` | wired — one instruction then one receipt; both written per `70-copy.md` and the Build Document generated-string tables |
| `coach` ask field, recent exchanges | `AICoach` chat, `CoachHistoryBudget`, `NoopLiquidGlassSearchField.swift` | wired |
| `gate` no provider | `AICoach.provider` unset | wired |
| `setup` provider, key, test | `AIProvider` (OpenAI / Anthropic / Gemini / OpenRouter / custom OpenAI-compatible), keychain, models endpoint for the test | wired |
| `consent` one toggle per purpose | `ToolConsent` / `CoachPurpose`, layered under `dataConsent` — already per-purpose, exactly as designed | wired |
| `memory` remembered facts, forget, forget everything | `CoachMemory`, `SemanticMemory` | wired |

Act 7 is the best-supported act in the design. The consent model the screens describe — a master
switch with revocable per-purpose access underneath — is what the code already does.

## Act 8 · Goals and labs

| Screen · element | Feeds from | Status |
| --- | --- | --- |
| `goal` route graphic, waypoints | `GoalMilestones.suggest(...)` for the waypoints, `GoalMeasure` for the smoothed series | wired |
| `goal` a waypoint only ticks when recorded | `JourneyMilestones` (app target) records what has happened; `GoalMilestones` is forward-looking. The rule is: tick from the former, never the latter | wired |
| `goal` honest distance | `GoalMilestones.course(...)` — `onCourse` / `ahead` / `behind` / `movingAway` / `unforeseeable` / `notEnoughData` map straight onto the design's honest-distance copy | wired |
| `set` what / by when / what it will take | `GoalMilestones`, `GoalMeasure` | wired |
| `set` where it conflicts with the Charge model | depends on the ledger | **derive** |
| `labs` markers, panels, bands | Lab Book (~30 markers, CSV import, reference ranges), `LabBookProjection` | wired |
| `review` import from a photo | no OCR anywhere in the codebase | **derive** (Part 1 §5) |
| `marker` value, band, history, what it is | Lab Book + `TrendChart.swift` | wired |

---

# Part 4 · Built, and not on any screen

Real engines with no surface in this design. Not gaps — options, listed so nobody rebuilds them by
accident and so the next act has somewhere to start.

- `IllnessSignalEngine` + `IllnessDistance` — an early-illness read. The design has no home for it;
  the Charge screen's "what is limiting you" is the natural one.
- `CyclePhaseEngine` — cycle phase. Nothing in the nine acts refers to it at all.
- `DoseResponseEngine`, `EffectRanker`, `CorrelationEngine`, `BehaviorInsights` — the discovered
  "what actually moves your numbers" layer. `trends/capacity`'s *what moved it* uses a slice; the
  rest is unsurfaced.
- `ResonanceEngine` — resonance breathing, beyond the box-breathing orb.
- `SpotHrvReading` — an on-demand HRV reading.
- `RecoveryForecast`'s ± band and `ScoreConfidence` tiers — the design shows point values almost
  everywhere. Confidence is computed; consider showing it where the number is thin.
