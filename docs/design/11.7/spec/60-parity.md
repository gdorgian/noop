# The parity audit — what a Noop user gains and what they lose

*Foundations pack, 6 of 6. Read after `50-wiring.md`. That sheet answered "can we build this against
the app we have". This one answers a different question: if the nine acts ship as the app, what
does a person who uses Noop today walk away from?*

*Rev 3, re-run 7 September **against all 69 screens**, screen by screen, off the standalone HTML.
This is not a re-read of Rev 2 with the count changed. Rev 2 was written when the design held 48
screens and then patched twice; between those patches and now, **twenty-one screens were built**,
and Rev 2 still described nine capabilities as absent or as a later release that are in the app
you can tap today. Every verdict below has been walked against a screen or marked as having no
screen. **The corrections are listed in §0 so nobody has to diff two revisions of a long page.**

That memo — `engines-without-screens.md`, reading the same tree at `829e7aa5`* — *adds a third
state to every feature on this page: not only shipped and designed, but **latent** — finished,
tested code with nowhere to appear. Rev 3's headline is that the latent list is now nearly empty.*

---

# Part 0 · What Rev 2 got wrong

Nine entries. Eight were **stale rather than mistaken** — true when written, overtaken by the
build — and one was a real error of scope.

| Rev 2 said | Rev 3, walked against the build |
| --- | --- |
| Breathe is `[gone]`, the flagship loss | **Built** — `day/breathe`, `bcatalog`, `bplayer`, `bsweep`, `bfound`. Five screens, the player *and* the sweep, off the orb |
| The import hub is a launch blocker | **Built** — `plumbing/import` → `reading` → `imported` / `rejected`. One drop target, per-category counts, specific errors |
| Backup and restore is a launch blocker | **Built** — `plumbing/backup`, both formats, `BackupSync`'s scheduled state, restore as a first-class path |
| Explore is `[gone]` | **Built** — `instrument/index` and `instrument/metric` |
| Compare is `[gone]` | **Built** — `instrument/compare` |
| Insights is `[gone]` | **Built** — `instrument/effects` |
| Smart Alarm is `[gone]` | **Built** — `night/alarm`, off `tonight`. Arms the strap's own firmware |
| Illness early-warning is `[gone]` | **Built** — inside `day/charge`, priced as a drain, **with the ruled-out half** |
| **Act 9 is "the second release"** | **Wrong, and this is the error rather than the staleness.** Act 9 is one of the nine acts. The redesign is nine acts; there is no second release inside it. Anything genuinely later is in §Later, and it is a short list of rows |

Two more that were `[thin]` and are now closed: the **Charge drivers** (a section on `day/charge`)
and **confidence** (the chip, `20-primitives.md` §15, applied across the pack). One more that was
`[thin]` and is now closed by a control rather than a screen: **search**, restored on `settings`.

**The honest summary of Rev 3: there is no launch blocker left in this document.** What remains is
a list of rows, two platform decisions, and one engine deliberately left dark.

---

The comparison is against the **iPhone** app as it exists on `main` — `RootTabView`'s four tabs
(Today, Trends, Sleep, More) and the twenty-six destinations `MoreCatalog.swift` enumerates, plus the
surfaces reached from cards rather than from the index. Not the macOS app: several things in
`docs/FEATURES.md` are Mac-only by construction and their absence from an iPhone design is correct,
not a regression. Those are called out where they matter, because counting them as losses would
inflate the number and make the rest of this document untrustworthy.

## The short answer

**The redesign is deeper on the day, and no longer shallower on the archive.**

A person who opens Noop each morning to read how they slept, whether to train, and what the day has
cost them gets a materially better app: fewer numbers, arranged as a story, with every figure
explained where it appears. That user gains.

A person who uses Noop as a *personal-data instrument* — the one who opens Explore to look up a
metric, Compare to overlay two of them, Insights to ask what actually moves their HRV — **keeps
their toolkit.** Act 9 is that toolkit and it is one of the nine acts, not a later release: an
index of every signal, a dossier per metric, an overlay with a real fit, and the behaviour-effects
half of Insights. Rev 2 filed all three as gone and then filed the act that answers them as
something that would arrive afterwards. Both statements were wrong at once.

And the gap that was **not** a preference is closed. Rev 2 opened: *there is currently no way to
get your history into the app, and no way to get it back out.* There is now — six screens of it.
`plumbing/import` is the one drop target twelve formats arrive through, `reading` streams it with
live per-category counts, `imported` reports what was written and what stayed blank, `rejected`
names the wrong file and the two ways out, and `backup` is the door out in both formats with
`BackupSync`'s scheduled state on it. On a fresh install the redesign now has a door, and on a
lost phone the history has an exit.

## The count

| | |
| --- | --- |
| Original iPhone destinations, `MoreCatalog` index | 26 |
| Original, including tabs and card-reached surfaces | roughly 60 |
| This design | **69 screens** — 5 · 12 · 7 · 4 · 21 · 5 · 5 · 6 · 4 |
| Kept or improved | **35 areas** |
| Missing with no substitute | **2** — Beat Rhythm, Mind |
| Thinner, with something nearby | **11** |
| New here, no counterpart in the original | **13** |
| Built and tested, with no screen in either app | **1** — `CyclePhaseEngine`, deliberately dark |
| Decided and listed, not built | **11** — the nine drawer utilities, hydration, the two About explainers |

69 against roughly 60 is not the story — the *distribution* is, and it has changed since Rev 2. The
nine acts still spend most of their screens on the daily loop, but Act 5 is now 21 screens and six
of those are the two doors. The drawer is a list of dimmed rows on `settings`; the archive is a
real act.

**The line that mattered most in Rev 2 is gone.** It read *"Missing with no substitute: 19"*. The
number is now two, and neither of the two is load-bearing: `RhythmView`'s beat-to-beat regularity
(consent-gated and experimental in the original) and the daily mood check-in. Everything else that
was on that list either has a screen or has a row that says *Later* with a reason on it.

## How to read this

| Tag | Meaning |
| --- | --- |
| [better] | Exists in both. The redesign is the better version and a returning user notices. |
| [kept] | Exists in both, at parity. No loss, no gain. |
| [closed] | Rev 2 filed it as missing or later. It is built, and the route is named. |
| [thin] | The capability survives in reduced form. A user will find the edge. |
| [gone] | No screen, no substitute. A user who relied on it hits a wall. |
| [later] | Decided, listed on a row with a **Later** chip, not built. Not the same as gone. |
| [new] | No counterpart in the original app. |

---

# Part 1 · The two doors — **both built [closed 1 September]**

*Rev 3. Rev 2b corrected the source list here (badly understated) and the shape of the interaction.
Rev 3 closes the section: **both doors exist as screens**, and this part is now a record of what
they had to carry rather than an argument that they should exist. It stays at the front of the
document because it is the section a build most needs to get right, not because it is outstanding.*

## Data Sources — the door in [closed — `plumbing/import`]

**What the original does.** `DataSourcesView` is the import hub, and on a sideloaded, account-free
app it is the most load-bearing screen there is. It reports records imported and the date span, and
shows how many days and sleeps are stored.

Earlier revisions of this page said *four sources*. That was wrong. `ImportCoordinator` routes
**seven wearable brands and formats**, and the long tail adds five more file importers:

| What a user can hand it | What it accepts | Symbol |
| --- | --- | --- |
| WHOOP | `.zip` or folder — the four CSVs; 4.0, 5.0 and MG | `WhoopExportImporter` |
| Apple Health | `export.zip`, `export.xml` or a folder, streamed and aggregated locally | `AppleHealthImporter` |
| Xiaomi / Mi Band | the Mi Fitness sandbox folder, a `.zip` of it, or the bare `<user_id>.db` | `XiaomiBandImporter` |
| Oura | Account → Export Data JSON, or the per-category CSVs | `WearableExportImporter` |
| Fitbit | Google Takeout → Fitbit → JSON | `WearableExportImporter` |
| Garmin | Connect → Export Your Data, the GDPR `.zip` | `WearableExportImporter` |
| A single workout | GPX, TCX or FIT | `ActivityFileImporter` |
| Nutrition | daily CSV from Cronometer or MacroFactor | `NutritionCsvImporter` |
| Lab markers | CSV, and a lab report as text | `LabMarkerCsvImport`, `LabReportTextImport` |
| Lifting | a strength-training log | `LiftingImporter` |
| WHOOP biomarkers | the biomarker export | `WhoopBiomarkerExportParser` |
| The strap | live BLE | — |

**The interaction is not a source picker.** `ImportCoordinator.detectAndImport` takes one URL and
works out what it is: `export.xml` anywhere inside means Apple Health, any of the four WHOOP CSV
names means WHOOP, a `.db` under a `/de/` path means Mi Fitness, and anything else readable goes to
the wearable importer, which sniffs Oura against Fitbit against Garmin **by content** — by JSON key
shape, not by filename, so a renamed or re-zipped export still routes correctly. So the screen is
**one drop target**, and the list of twelve is a *reference* for what it can read rather than a menu
to choose from. That is a smaller screen than one row per source, not a bigger one.

**Three behaviours the screen has to carry**, all already true of the code — and all three now
stated on the screens (`44-act5-plumbing.md` §5.17 and §5.19):

1. **An imported score never becomes your score.** A brand's own number — Oura readiness, any sleep
   score — is stored under a reference key and never surfaced as Charge, Effort or Rest; Noop
   recomputes its own from the raw RHR, HRV and sleep inputs. **On the screen twice**, on `import`
   and on `apple`, because it is a migrating user's first question and both are doors.
2. **Only what the export carries is written.** Unknown stays nil rather than zero. The result state
   is therefore a per-category count — `ImportSummary` gives `recordCount`, `earliest`, `latest` and
   `countsByCategory` — not a single success tick. **`imported` is built that way**, and carries the
   sentence: a missing night and a bad night should never look alike.
3. **The errors are specific, and one is a worked example.** Hand it Oura's raw `heartrate.csv` and it
   does not say "no usable data": it says that file is the raw heart-rate log, and tells you to export
   as JSON or pick the daily CSV instead. **`rejected` is that screen** — a monospaced path, a
   sentence of diagnosis, two ways out with a recommendation, and *nothing was written* as its title.

**What the design has, as of 1 September.** Four screens, not one card:

| Screen | What it carries |
| --- | --- |
| `plumbing/import` | **One** drop target with the app's only dashed border; what is stored on this phone; the twelve formats as a *reference, not a menu*; and the scores-stay-yours paragraph |
| `plumbing/reading` | The stream, with a real percentage, the current filename, and **live per-category counts rising as it reads** — not a spinner |
| `plumbing/imported` | The span, the per-category counts, the blank-versus-zero rule, and what recomputes next |
| `plumbing/rejected` | The specific error, the two ways out, and *your stored days are untouched* |

`plumbing/data` keeps its three cards about data already present and now carries **Import** and
**Backup and restore** as its two doors. `plumbing/strap`'s *Sync Apple Health* row is still the
ongoing bridge — and `plumbing/apple` now states the distinction the audit turned on: a **feed** is
not **history**, and the page hands off to the import hub for the latter.

**Why it was a blocker.** Every screen in Acts 1, 2, 4, 6 and 8 reads history. The year heat strip
needs a year. `trends` refuses to render a verdict under six weeks of data, by design.
`ages/building` counts to seven nights. A migrating user's seven years of WHOOP history sitting in a
zip file on their phone now has somewhere to point.

## Backup and restore — the door out [closed — `plumbing/backup`]

The same blocker, and Rev 2 filed it in Part 3 §A.11 as an omission when it belonged here. On an app
with **no account and no cloud**, export is the only way a user reaches a new phone at all — losing
the phone means losing the history, and until 1 September no screen in the design prevented that.

Two formats, both round-tripping through the importers above, **both rows on `plumbing/backup`**:

- **`.noopbak`** — the lossless one. A zip of the full SQLite database, a `settings.json`, and a
  manifest recording which build wrote it (`DataBackup.writeBackup`). This is the phone-to-phone path.
  `BackupSync` adds automatic folder or iCloud snapshots with retention, pruning and a staleness check
  — which means the screen has a *scheduled* state, not just a button. **It has one**: a last-snapshot
  card with a schedule chip, the destination, the size, the next run and the retention.
- **The WHOOP four-CSV zip** — the interoperable one (`WhoopCsvExporter`). Re-imports into Noop and
  into upstream's Android build. Apple Health rows are deliberately excluded so a re-import cannot
  mis-attribute them, and on-device computed rows are tagged `noop (APPROXIMATE)` in the Source
  column, which both importers then skip. That tagging is a designed honesty guarantee and **the
  screen says it**, in monospace, in the sentence under the two rows.

Plus `RouteExporter` for GPS routes, and the raw-CSV export already specified on `plumbing/lab`.

**It was one screen family, not two features** — import and export are the same two formats read in
opposite directions, so they sit as two doors off `plumbing/data`. Restore is a first-class path on
`backup` rather than a footnote under export, and it names the build that wrote the file **before**
replacing anything.

---

# Part 2 · What gets better

Ordered by how often a person meets it.

| Area | Original | Here | |
| --- | --- | --- | --- |
| Today | One screen carrying three rings, a synthesis line, a key-metrics tile grid with sparklines, recovery vitals, a heart thread, coach cards, last workouts and a data-sources footer | A hero and five pushes: `charge`, `day`, `vitals`, `stress`, `heart`. The home screen answers one question and hands the rest to screens that can hold them | [better] |
| Where the day went | A Charge breakdown sheet naming which drivers moved the morning score | A whole screen, `day/charge`: the level against what you woke with, a spent-versus-remaining bar, every drain priced, and what tonight puts back | [better] |
| Sleep | The Sleep tab: hypnogram, night-detail tiles, stages vs typical, asleep-duration trend | Act 1 as four screens — `rest`, `why`, `debt`, and `tonight`, which the original has no equivalent of | [better] |
| Training decision | Workout selection and a manual-workout sheet; the coach proposes in cards | Act 3 as a decision: `session` recommends, `pick` prices the alternatives, `ready` confirms, `live` runs it, `detail` says what it cost | [better] |
| Body age | One Fitness Age tile in the vitals grid | Act 6: a hero, a drivers list, a per-driver screen, the method written out, and an honest first-week state | [better] |
| The coach | `CoachSettingsView` at 156 KB, one screen carrying provider, key, model, memory and consent | Act 7 as five screens — `coach`, `gate`, `setup`, `consent`, `memory` — with per-purpose consent as its own surface | [better] |
| Goals | Goal and Journey | Act 8: the route graphic, waypoints that only tick when recorded, and honest distance | [better] |
| Your record | Profile inside a 224 KB `SettingsView` | `record` as its own screen, with `zones` and step calibration under it | [better] |
| The strap | Settings' strap card plus a separate Power saving row | `strap`: a battery ring, connection and secure link, two independent sync acts, and sensors each priced in battery hours | [better] |
| Privacy | Prose in About and in the docs | `data`: what is recorded, what leaves, and a delete that names what it destroys | [better] |
| Widgets | Widgets exist; nothing in the app explains them | `widgets`: three previews at true size and what each one reads | [better] |
| Explore · a metric, looked up | `MetricExplorerView` — a grouped index and a per-metric dossier | `instrument/index` and `instrument/metric` — the index with a movement figure per signal, the dossier with a range control, a hero trend, and correlations that are only drawn when they clear | [closed] |
| Compare | `CompareView` — two to four metrics, min-max normalised, a crosshair, live Pearson r | `instrument/compare` — and **the shift control is the insight**: the fit is drawn only when it clears at that length and shift | [closed] |
| Insights | `InsightsView`, `InsightsHubView` — behaviour effects and metric relationships | `instrument/effects` — three engines on one screen, **all three refusal states designed** | [closed] |
| Breathe | The flagship: a protocol catalog, a paced player with a felt cue, live RMSSD, a resonance mode | `day/breathe` · `bcatalog` · `bplayer` · `bsweep` · `bfound` — the player **and** the sweep, off the orb, with the strap buzzing the cue | [closed] |
| History, in and out | `DataSourcesView`, `BackupSyncView` | `import` · `reading` · `imported` · `rejected` · `backup` — Part 1 | [closed] |
| Smart Alarm | `SmartAlarmView`, arming strap firmware | `night/alarm` — and arming is a separate, reversible act from setting, with every failure mode named before it happens | [closed] |
| Automations | `AutomationsView` — the strap as an input | `plumbing/automations` — and the ceiling **resolves to a real bpm before it arms**, with the resolved number on the screen | [closed] |
| The Updates inbox | `UpdateStore`, `UpdatesInboxView` | `day/inbox` — three row kinds that behave differently, and a proposal that names what accepting changed | [closed] |
| Apple Health, as a page | `AppleHealthView` — per-source tiles plus the export diagnostic | `plumbing/apple` — every kind with its own outcome, including *not asked* as an honest third state | [closed] |
| Workouts, in aggregate | `WorkoutsView` — ranges, summary tiles, per-sport cards | `effort/across` — and the days you did **not** train are counted | [closed] |
| Illness early-warning | Two anomalies against a 28-day baseline raise a banner | Inside `day/charge`, priced as a drain — **and the ruled-out half beside it**, which the blunt rule has no concept of | [closed] |
| Why you woke with that number | A tappable Charge breakdown with a confidence tier | The drivers section on `day/charge`, above the ledger, with the confidence chip on it | [closed] |
| Confidence | Calibrating / Est. / Reliable, and "Learning your baseline, N of 4 nights" | The confidence chip, `20-primitives.md` §15 — two rungs not three, in the host screen's own hue, naming the reason rather than the rung | [closed] |
| Search | The More index searches titles and keywords | The search field at the head of `settings`, over eleven groups | [closed] |
| Stress | `StressView` with a gauge, band, markers, trend and a how-this-is-computed card | `day/stress` — stressed minutes, same method | [kept] |
| Vitals | Health Monitor's vital-signs grid with in-range colouring | `day/vitals` — five vitals with your-normal bands | [kept] |
| Live heart rate | Live's smoothed BPM hero | `day/heart` and `effort/live` | [kept] |
| Biomarkers | Lab Book, around thirty markers with reference ranges | `labs`, `marker` | [kept] |
| Interval timer | Configurable work, rest and rounds with haptic transitions | `effort/intervals` | [kept] |
| Trends | Charge hero, small multiples, year heat strip | `trends` and its three pushes | [kept] |
| Heart-rate zones | `HRZoneEditorView`, percent-of-max or absolute beats | `plumbing/zones` | [kept] |
| The Lab | Test Centre plus Settings' experimental and HRV cards | `plumbing/lab` — experimental readings, gated probes, diagnostic exports | [kept] |
| Pairing | `AddDeviceWizard`, `OnboardingWizard` | `pair`, `devices`, `onboard` | [kept] |
| Units, appearance, streak, about | Settings groups | `settings`, eleven groups, each switch stating its cost | [kept] |
| Logging | Journal log card, caffeine card, manual entries | The log sheet from any tab, and `history` at 142 entries | [kept] |
| Power saving | Its own More row | Folded into `strap` | [kept] |
| Where you wear it | Guidance buried in docs | A card on `strap`, at the point where a bad reading gets explained | [new] |
| What Noop will not ask you | Nothing — the position exists in the docs and at first run only | `plumbing/position` — five denials, **each with its reason in the row**, and one card stating the total size of what *was* asked. No primary button | [new] |
| Wrist alerts | On iPhone these live inside Automations; the dedicated Notifications screen is macOS-only | `plumbing/notifs` — a first-class iPhone screen for which apps reach your wrist, with four conditions and an honest per-app default table | [new] |

The last row is worth reading twice. `MoreCatalog` says plainly that the Notifications screen cannot
compile on iOS and that its absence from the iPhone index is correct. The design gives iPhone a
notification screen it has never had. It is also the one screen in the pack that cannot be built as
app code — see `50-wiring.md` Part 1 §4.

**Thirty-five areas in this table, fifteen of them tagged [closed].** That ratio is the difference
between Rev 2 and Rev 3, and it is why Part 3 below is now short.

---

# Part 3 · What goes missing

## A · Gone, and felt in the first week

**Two.** Rev 2 listed eleven. Nine of the eleven are in Part 2 as [closed], with their routes named;
the reasoning Rev 2 wrote for each is kept in §A.3 below because it is what the built screens had to
satisfy, and a build that has not read it will produce the screen without the argument.

### 1 · Beat Rhythm [gone]

`RhythmView` — beat-to-beat regularity, consent-gated and experimental. `trends/rhythm` is
circadian timing and **a different thing entirely**; `50-wiring.md` warns against wiring one into
the other, and that warning is the reason this stays open rather than being quietly satisfied by a
similarly named screen.

It was `[thin]` in Rev 2's §B on the strength of the name collision. Walked properly, it is `[gone]`
— which is a **downgrade**, and the only one in Rev 3. Being honest about it is cheaper than
discovering it after someone has pointed a consent-gated experimental engine at a circadian screen.

### 2 · Mind [gone]

A daily mood check-in and its correlations against Charge, Rest and HRV. No screen, and no row.
The one capability in the original with no counterpart anywhere in the 69 — not thinner, not later,
absent. Worth a decision rather than a silence: it is the only *input* the redesign dropped, and
every other screen in the app is downstream of what gets logged.

### 3 · What the nine closed screens had to satisfy

Kept from Rev 2, because each paragraph is the acceptance criteria for a screen that now exists.

**Breathe** — `docs/FEATURES.md` calls it the flagship novel feature, and it is the one thing Noop
does that a phone alone cannot: the strap measures HRV from R-R intervals *and* buzzes, so it can
pace your breath with a felt cue and show the HRV response in real time. The catalog: Relax 4-6,
Coherence 5.5, Box, Diaphragmatic, Alternate Nostril, 4-7-8, Buteyko, Tummo, Ujjayi, Bhastrika,
Qi Gong, Soma, plus Presence Process tempos and guided entries for Kapalabhati, Holotropic, Wim Hof
and Shamanic. Open or 5 / 10 / 15 minute sessions. One pulse on inhale, two on exhale, silent
holds. Live BPM and rolling RMSSD, a coherence estimate, and a pre-versus-post RMSSD outcome. Modes
for Resonance and Calm me. Schedule maths in `StrandAnalytics` (`BreathProtocol`,
`BreathProtocolCatalog`, `BreathProtocolPlayer`), golden-vector tested.

Rev 2's complaint was that the design had *a box-breathing orb on `today`, and it is a graphic — it
paces nothing, buzzes nothing and measures nothing*. That is now the door: the orb opens
`day/breathe`, and the five screens behind it pace, buzz and measure. **The sweep is a mode inside
it, not a feature beside it**, which was the specific instruction — and it is the one thing in the
pack that needed a designed *activity* rather than a display.

**Explore** — `MetricExplorerView`: every signal in the catalog, one tap deep. A grouped index with
a faint dot marking metrics that hold no data; a per-metric dossier with a W / M / 3M / 6M / 1Y /
ALL range, a hero trend chart, average, min, max, latest and the delta against the previous
equal-length window tinted by whether that direction is good for that metric, and a cross-catalog
Pearson scan naming what correlates. Sparse metrics widen their own window **and say they did**.

**Compare** — `CompareView`: two to four metrics overlaid, each min-max normalised so different
units share an axis, a crosshair reading every series' real value on the nearest day, and a live
Pearson r per pair with a plain-English conclusion.

**Insights** — `InsightsView` and `InsightsHubView`, in two halves. Behaviour effects split logged
journal answers into days a behaviour was and was not logged and compare a chosen outcome across
the two groups, with group means and counts, a significant-versus-exploratory pill, and Cohen's d
with a magnitude word. Metric relationships carry a curated set of correlations including next-day
lag. `DoseResponseEngine`, `EffectRanker`, `CorrelationEngine` and `BehaviorInsights` all feed it.

**Workouts, in aggregate** — `WorkoutsView`: a 7D / 30D / 90D / 1Y / All range, summary tiles for
total workouts, time, calories, distance and most-active sport, per-sport breakdown cards, and an
all-sessions table with a source badge per row. Built as `effort/across` with **two deliberate
departures**: no calorie total (Noop keeps none) and the days you *did not* train are counted,
because a rest day is a training decision.

**Automations** — `AutomationsView`, and on iPhone it is where the wrist-alert controls live.
Double-tap the strap to fire an action. Lock or run a Shortcut when the strap comes off or goes
back on. A heart-rate ceiling with profile-zone or fixed-bpm modes, **resolved to a real bpm
boundary before it arms**. A target-zone coach that taps once to confirm, twice for more, three
times to ease off. Haptic stress check-ins after an HRV dip. And the illness early-warning toggle.

**Smart Alarm** — `SmartAlarmView` arms the strap's **own firmware alarm**, so it fires with the
phone asleep or the app closed. `MoreCatalog` carries a comment about a regression that once
dropped this row and left Alarms unreachable on iPhone, which is a fair measure of how much it is
missed. `night/tonight` gives a bedtime anchor and what it buys; **`night/alarm` sets the wake
time**, and the card explaining that it runs on the strap rather than the phone is the reason the
screen exists.

**The Updates inbox** — `UpdateStore` and `UpdatesInboxView`: the bell at the top of Today, badged
with an unread count, holding three kinds of row that behave differently — coach proposals that
need a decision with Accept, Change and Decline in the row; hints with nothing to decide; and
status rows including a Today card you swiped away, restorable in one tap. Deduped and capped so a
recompute loop cannot spam it.

**Illness early-warning** — two or more anomalies against a 28-day baseline (resting HR up 5 bpm or
more, HRV down 20 percent, skin temperature up 0.6 degrees, respiration up) raise a banner and post
one system notification per day. That blunt rule is what ships today. `IllnessSignalEngine` and
`IllnessDistance` were written to *replace* it and are now surfaced inside `day/charge` — priced
like any other drain rather than shouted as a banner, **with the ruled-out half beside it**. See
Part 5 §A: the negative finding is what makes the warning trustworthy, and it is still the only
negative finding anywhere in the 69 screens.

**Apple Health, as a page** — `AppleHealthView` is both a per-source page and, on iPhone, the
control surface for the two-way HealthKit bridge, including the export diagnostic that reports each
category's authorisation, count and last result. Built as `plumbing/apple`, which states the thing
the original never does: **iOS never tells an app a read was refused**, so a denied kind and an
empty one look identical from inside, which is why the page counts what was **written** rather than
claiming success.

## B · Thinner here, with something nearby

**Eleven.** Rev 2 listed fifteen. Three are closed and now sit in Part 2 (the Charge drivers, the
confidence ladder, search); two moved the other way, into §A as `[gone]` — Beat Rhythm, because
`trends/rhythm` is a different measurement with a similar name, and Mind, because a coffee row in
the log sheet is not a mood check-in.

| Area | What narrows | |
| --- | --- | --- |
| Why you woke with that number | **[closed]** — the drivers section on `day/charge`, above the ledger, with the confidence chip on it. Was `[thin]` in Rev 2 | — |
| Confidence | **[closed]** — `20-primitives.md` §15. Was `[thin]` | — |
| Search | **[closed]** — the field at the head of `settings`. Was `[thin]` | — |
| Trends range | Act 4's three windows (six weeks, six months, the year) against the original's six. **Act 9 carries the full W / M / 3M / 6M / 1Y / ALL range**, so this is now a deliberate split rather than a loss: the daily act reads slowly, the instrument reads at any length. It still costs Act 4 the weekly view | [thin] |
| Activity status | Active, Sick, Injured or On break, each with a duration, driving the base card's copy. No screen or chip in the design | [thin] |
| Sleep depth | Stages vs typical, the trailing-30-night asleep-duration trend, and stepping back through earlier nights all live on the original Sleep tab. Act 1 keeps the hypnogram and the debt strip | [thin] |
| Caffeine and hydration | `HydrationView`, `CaffeineLogCard`, caffeine decay, and self-importing water and caffeine from Apple Health. The design's log sheet has a coffee row; hydration is a **Later** row on `settings` | [thin] |
| Live console | Live's R-R interval list, decoded frame and event grid, BLE log, and scan and re-scan and buzz controls. `heart` and `strap` cover the readings, and `heart` now carries the spot reading; the diagnostics belong in `plumbing/lab` and are still not specified there | [thin] |
| Journal | Behaviour logging survives in the log sheet, and `instrument/effects` is what it feeds. The personal-experiments half of Journal does not survive | [thin] |
| How scoring works | `IntelligenceView` and `ScoringGuideView` explain how Charge, Effort and Rest are computed. `ages/method` does this for body age only — and the confidence chip is **tappable to the screen that explains the arithmetic**, which for seven of the eight engines does not exist yet. Until it does the chip is inert rather than dishonest (Part 5 §C ¶1) | [thin] |
| Customise Today | Shown and hidden sections, drag to reorder, tiles per row, detailed tiles. The design is a fixed layout, which is a defensible position but a capability a current user has | [thin] |
| Widgets and glances | Rings widget, Live Activity and Dynamic Island, Home Screen quick actions. The design specifies Charge small, Last night medium and a Lock Screen pair; the running-session live bar is in-app only | [thin] |
| Watch companion | `AppleWatchSetupView` and `AppleWatchAboutView`, plus the Watch Breathe view. Nothing in the 69 mentions a Watch — and now that Breathe ships, the Watch Breathe view is the sharpest instance of it | [thin] |
| Nutrition | Calories and macros on the same timeline as Charge and Rest, via CSV. The importer reads Cronometer and MacroFactor exports, so the data can arrive through `plumbing/import`; nothing displays it | [thin] |

## C · The drawer [closed 1 September — listed on `settings`]

Real screens, none of them daily, all cheap to re-add as rows on `settings` or `data`. **All nine
are now listed** in a **Later** group at the foot of `settings`, dimmed, each with a neutral
**Later** chip where the chevron would be and no control to touch — the convention in §C ¶4.

**`[later]` is not `[gone]`, and that distinction is the point of the group.** A row that says
*Later* with a reason on it is a product saying where it stands. An absent row is a product hoping
you do not look. All nine below are therefore retagged `[later]`.

| Screen | What it is | |
| --- | --- | --- |
| Your Data, Fused | `FusedRecordView` — the merged record across sources on one timeline | [later] |
| Mi Band | `XiaomiBandView` — Mi Fitness import. **The import half is closed**: folded into Part 1's one drop target. Only the per-source page is later | [later] |
| Shortcuts Export | The HealthKit-free path for anonymous sideloaded builds | [later] |
| NOOP Limitations | The 4.0 versus 5.0 and MG capability grid: what the app can actually read off each strap | [later] |
| Siri and Shortcuts | App Intents and voice. Note that `plumbing/automations` already fires Shortcuts from the strap, so the gap is invocation, not integration | [later] |
| Storage | `StorageView` — what the database is spending | [later] |
| How NOOP Works, What's New | `HowNoopWorksView`, `WhatsNewView` — the explainer and the release log. **The explainer is load-bearing**: it is where the confidence chip's tap wants to land (§B) | [later] |
| Weekly Digest, Trends Report | `WeeklyDigestView`, `TrendsReportView` — the periodic written summary | [later] |
| Nutrition | Calories and macros on the same timeline as Charge and Rest, via CSV | [later] |

Two more that are not screens but are losses a user can feel. **Both are now on a row rather than
absent**, per §C ¶4 — the option is dimmed with the reason in its own sub-line:

- **Light appearance.** The original ships Dark, Light and System. The design has designed values
  for dark only; `50-wiring.md` Part 1 §7 has it as an open decision. **Light** and **System** are
  dimmed against a shipped **Dark**, which closes the switch that used to promise something the
  design does not have. It remains a regression for anyone using Light today, and the decision is
  still open.
- **Translation.** `MoreCatalog` titles are `LocalizedStringResource` and the repo runs an i18n
  audit with an echo gate. Every string in this spec pack is English, and several are specified
  verbatim. **System** and **Deutsch** are dimmed against a shipped **English**. Someone still has
  to decide whether the redesign ships translated — and the volume of verbatim copy in this pack
  is the real cost of that decision.

These two are the only **platform** decisions left in this document. Everything else outstanding is
a row.

---

# Part 4 · What is new here

Not restyled — absent from the current app.

| | What it is |
| --- | --- |
| `day/charge` | The intraday ledger. Every drain priced, spent against remaining, and what tonight puts back. The design's central metaphor. `50-wiring.md` Part 1 §1 had this as the one number the app cannot compute; two partial answers now exist and between them very little is missing — corrected in Part 5 §D |
| `night/tonight` | Tonight's plan: a bedtime anchor and what it buys, adaptive to the schedule |
| `plumbing/you` | The body clock. `CircadianEngine.estimatePhase` computes acrophase, temperature minimum, offset against schedule and a confidence tier, and no screen in the current app shows any of it |
| Act 6 entire | Five screens for the ages, where the original has one tile |
| `plumbing/notifs` | An iPhone notification screen, which the current app cannot have — see Part 2 |
| `plumbing/widgets` | Widget previews at true size, with what each one reads |
| `night/debt` | Sleep debt as its own screen with a 14-night strip |
| `effort/session` and `effort/pick` | The effort framed as one decision a day, with each alternative priced |
| The live session bar | A running session reachable from anywhere, non-dismissible until it ends |
| `plumbing/data` | Privacy as a screen rather than as prose in About |
| `plumbing/position` | **What Noop will not ask you** — five denials, each with its reason in the row. No other health app in the category states its refusals as a screen |
| `plumbing/import` · `reading` · `imported` · `rejected` | Rev 2 filed the import hub as a *loss*, because `DataSourcesView` exists. Only the door is kept; **the flow is new** — live per-category counts while it streams, the blank-versus-zero rule stated on the result, and a rejection that names the file and recommends one of two fixes |
| `day/bsweep` and `day/bfound` | The original has a resonance *mode*; it has no screen that runs a sweep as a designed activity and hands its result to the rest of the app |
| The confidence chip | One ladder, one set of words, everywhere — in the host screen's own hue, naming the reason rather than the rung. The original has three tiers with three vocabularies |
| The cost convention | Every switch's sub-line states what it costs — in battery hours, in attention, or in what stops working. A rule, not a screen, and it applies across all **69** |
| The evidence gate | A verdict beside a Charge number is **bound or omitted**, never derived from a bucket. `41-act2-day.md` §2.2. A rule rather than a screen, and the only one in the pack that makes the app say *less* |

---

# Part 5 · Built, and never on screen — **seven of eight now placed**

*Eight pieces of physiology were finished, tested code running on-device — numbers in, numbers out,
no database and no network behind them — with nowhere to appear. Wiring one to a screen is about a
day's work; the reason none of them were on screen is that nobody had decided where they go.*

*Rev 3: **seven of the eight are now surfaced**, and the eighth is deliberately dark. This part is
therefore no longer a list of homeless engines. It stays because §A, §B and §C carry the scope, the
reasoning and the four conventions that the built screens had to satisfy — and §C ¶2 in particular
is the one that is easiest to skip and most visible when skipped.*

| Engine | Where it went | What a new user waits for it |
| --- | --- | --- |
| `IllnessSignalEngine`, `IllnessDistance` | **`day/charge`**, priced as a drain, with the ruled-out half — built | A trusted baseline |
| `ResonanceEngine` | **`day/bsweep`** — a mode inside Breathe, built | Ready now |
| `DoseResponseEngine` | **`instrument/effects`** — built | Ready now |
| `BehaviorInsights` | **`instrument/effects`** — built | Five days with, five without |
| `EffectRanker` | **`instrument/effects`** — built | Five days with, five without |
| `CorrelationEngine` | **`instrument/compare`** and **`instrument/metric`** — built | Ready now |
| `SpotHrvReading` | **`day/heart`** — a card, not a push. Built | Ready now |
| `CyclePhaseEngine` | **Out of scope** — decided, stays dark. §B | 42 nights |

The right-hand column decides more about these screens than the left one does. **Half of the eight
say nothing at all for the first two to six weeks**, which is precisely the period in which someone
decides whether to keep the app. See §C ¶2 — and note that with the engines now surfaced, that
waiting is no longer hypothetical: it is what a new install looks like on day one.

## A · Beyond what Part 3 scoped

Three of the seven placed engines do more than Rev 2 credited them with. That changed the scope of
the work, not its order — and all three are built to the scope below.

**The illness engine is a regression to repair and an upgrade to take.** Beside the four signals it
reports a 0–100 distance from this person's own normal, each signal with a direction and a distance,
and which fired against which stayed quiet. Then the part the blunt rule has no concept of: which
confounders were logged that day — alcohol, stress, sauna, a late or hard session, travel — and how far
the score was deliberately damped because of them.

That second half is the feature. Alcohol raises resting heart rate and skin temperature and crushes
variability in almost exactly the pattern early illness does, so a rule that cannot tell them apart
cries wolf every weekend until the user stops reading the banner. Saying out loud what was *ruled out*
is what makes a warning trustworthy rather than alarming — and it is still the **only** negative
finding anywhere in the 69 screens. It needs a treatment of its own, not a footnote. Five states to
hold: silent for want of a baseline, quiet, mild, raised, and damped. The *never* is unchanged and
hardest to keep at *raised* — no condition is named, ever.

**Built inside `day/charge`** as *what it ruled out first*, priced in the ledger rather than raised
as a banner. The card names how many confounders were checked and that none of them are in
yesterday, and it carries the baseline's own confidence chip — which is what stops a *raised*
finding from looking certain on a thin baseline.

**Breathe needs an activity designed, not only a screen.** The resonance sweep paces through several
candidate rates, a minute or two each, measuring how hard the heart swings against each. During the
sweep there is a real oscillation to draw against the pacer the user is following, and the strap can
buzz the cue rather than only showing it — the loop between cue, body and graphic *is* the feature. It
ends in a curve across rates with a clear peak, usually between four and a half and seven breaths a
minute. Four states, and the hand-off is the part to get right: what Breathe is before a sweep, and
what changes on it afterwards.

**Built as `day/bsweep` and `day/bfound`.** The oscillation is drawn against the pacer on `bplayer`
— dashed line for the pace, bright line for the heart, with one sentence saying which is which —
and the strap buzzes the cue. The hand-off is `breathe` §6: a three-row card that does not exist
before the first sweep and states what the sweep changed after it.

**The instrument's four engines are not four features.** Two details to carry into Act 9. First,
`DoseResponseEngine` opens with a published figure and becomes the user's own over weeks, so the
number is never missing but its *ownership* moves — and it can end up disagreeing with the
literature. If the design cannot draw the difference between a borrowed number and an earned one,
that engine should not ship; that distinction is the entire basis for showing a confident number on
day one. Second, `EffectRanker`'s insight is the *lag*, not the ranking: "your evening drink shows up
tomorrow morning, not tonight" is worth more than any ordering, and a plain ranked list throws it
away.

**Both are in the build**, and the generated-string tables in `Noop - Build Document.dc.html` §5
carry them verbatim: the dose figure has four states — *borrowed*, *blending*, *yours*, and
**disagrees**, where both numbers are shown and neither is hidden — and the ranked row leads with
the lag (*same night* / *next morning* / *two days on*) rather than the position.

## B · The engine that stays dark

### Cycle phase — decided, and the decision is no

`CyclePhaseEngine` classifies which half of the cycle recent nights fall in, from nightly skin
temperature corroborated by the resting-heart-rate rise and variability drop that accompany the same
half, and gives a window — never a date — for when the next change is likely to fall. It needs 42
nights before it will classify anything and expects cycles between three and six weeks.

It is in neither the wiring sheet nor Part 3 above, because the current app does not have it either.
That made it a genuinely open question rather than an omission — and the one place in the pack where
the copy constrains the design rather than the reverse. Someone will read a confident-looking phase
display as a fertility signal whatever the caption says. The *never* list is absolute: no date, no
fertile window, no safe days, nothing readable as contraception, as a pregnancy test or as a diagnosis.
So the confidence the visual projects has to match the confidence the engine has, and a treatment that
looks certain is wrong however accurate the number behind it is.

It is also the one genuinely cyclical dataset in the app. Everything else here is a line running left
to right; this is a loop, and forcing it onto a timeline throws away what makes it legible. Three
states, and most users sit in the first one for six weeks.

**Decided: out of scope for the redesign.** Not a context layer either — the engine stays dark and
unsurfaced, and the question reopens after launch if real users ask for it. The reasoning that a
context layer was the safer of the two live options still holds, so that is the shape to revisit; but
nothing is drawn for it now. It should not become a screen by default because an engine exists, and it
should not become a chip on two screens by default either.

### A reading, now — one card [closed — `day/heart`]

`SpotHrvReading` takes about sixty seconds of held-still beats and computes variability the same way
the overnight figure is computed, so the two can sit side by side. Part 3 §B has the live console as
thinner; this is the smallest item in the pack and the fastest to feel real — four states, and a bounded
minute that is a natural moment in its own right. The caveat travels with the result rather than being
buried: a daytime spot reading and a night's average were not taken under the same conditions.

**Built 1 September, on `day/heart`.** A card between the zone breakdown and the heart rows, four states:
idle, a counted-down minute with a running clean-beat total and a Stop that keeps nothing, the result
beside last night's overnight figure, and *not enough clean beats* — which names how much of the minute
was unusable, says nothing was saved, and does not offer a number it cannot stand behind. The caveat
travels under the result rather than in a footnote: a minute sitting up and a whole night lying down
were not taken under the same conditions, so read it against your other daytime readings.

It is a daily gesture rather than a diagnostic — a minute you take
because you are curious, sitting with the live heart rate that is already on that screen, not filed
under the instruments in `plumbing/lab`. That placement also means the comparison it wants is already
next to it.

## C · Five rules the eight share

Conventions, in the same class as the cost sub-line in Part 4 — each decided once and applied across
all **69** screens. **All five are now in the build**; ¶2 is the one that is easiest to skip and the
most visible when skipped.

1. **Certainty needs a place to live.** All eight report confidence on the same three-step ladder:
   still calibrating, building, solid. `ScoreConfidence` was computed and unsurfaced against a design
   that showed point values almost everywhere. None of the eight can be shown honestly without the
   ladder, which makes it a design decision rather than a vocabulary note. One ladder, one set of
   words, everywhere.

   **Decided, and built: a chip in the host screen's own hue, ramped** (`20-primitives.md` §15).
   `10-tokens.md` reserves amber (`effort`) for *needs attention* and `hot` for *critical*, so a
   calibrating score can borrow neither — there is nothing to act on, and an amber chip would read as
   a warning about the user's body rather than a note about the app's arithmetic. Confidence is a
   progress state, not a severity one. So the chip takes the hue the screen already has, per
   `20-primitives.md` §6's rule that a component never picks its own colour: lavender on `night/rest`,
   aura on `day/charge`, blush on the age screens. The ramp is the tinted-card rule's own range — the
   hue at 7 percent with a 22 percent border while calibrating, 12 and 30 while building.

   Two chips, not three: **solid is plain**, which is the precedent `47-act8-goals.md` already sets for
   read markers (confident plain, uncertain chipped). On a long-term user's screens most numbers are
   solid, so a permanent *Solid* chip would be pure noise on all **69**. The chip names the reason
   rather than the rung alone — "3 of 4 nights", not "calibrating" — and it is tappable, which is the
   one thing words alone cannot do and matters with eight engines to explain. While calibrating the
   score is withheld entirely and the count takes its place, the behaviour the current iPhone app
   already has. On small cards the chip shrinks to a dot in the same corner. Drawn as
   `Noop Confidence - D Hue Ramp`.

   **The chip is not a licence.** It qualifies a number the app *has*. It cannot make an unevidenced
   sentence honest — that is the evidence gate's job (`41-act2-day.md` §2.2), and the two rules are
   not interchangeable. Where there is no evidence, the words are **omitted**, not chipped.
2. **Design the waiting, not just the answer.** Several of these say nothing for two to six weeks. That
   silence *is* the new user's experience of the feature. Treated as an empty state drawn at the end, it
   will look broken for the whole period in which someone is deciding whether to keep the app.

   **Now testable rather than theoretical**, and it is the one thing to walk before launch: install
   clean, import nothing, and read all 69 screens on day one. `ages/building` and `plumbing/imported`
   are the two that were designed for it; the rest have to be checked.
3. **Inferred and measured must look different.** More than one engine carries an explicit marker for a
   part that was estimated rather than observed — most sharply the borrowed-against-earned number in
   dose response. That distinction is load-bearing and belongs in the visual language, not in a caption.
4. **Later is a state, and it is on the row.** A capability that is decided but not built is *listed*,
   dimmed, with a neutral **Later** chip where the chevron would be and no control to touch — never a
   live switch with nothing behind it. Neutral because amber is reserved for attention and this is not a
   warning; on the row because a footnote at the bottom of a screen does not stop someone flipping the
   switch above it. It applies to a whole row where nothing ships (the nine drawer utilities, the six
   appearance treatments, hydration, the two About explainers) and to individual options where part of
   the row ships: **Light** and **System** appearance are dimmed against a shipped Dark, **System** and
   **Deutsch** against a shipped English, each with the reason in the row's own sub-line. That closes
   the two switches §C flagged as promising something the design does not have.
5. **Absence is a result.** "No clear pattern", "nothing cleared the bar", "not enough clean beats" are
   answers, not errors. They need the same care as the positive states, and arguably more, because they
   are what make the positive ones believable.

   Rev 3 adds a sixth instance of it, and it is the hardest: **an omitted sentence.** Where analytics
   supplies no verdict beside a Charge number, the card is one sentence shorter and says nothing about
   it. A shorter card is the correct output for a thinner day.

## D · The energy gauge — a correction

Part 4 called `day/charge` the one number the app cannot yet compute. That is now out of date. There
are two partial answers to energy in the tree and they solve different halves. One has the **morning**:
what you woke with, why it landed there, what a session costs you on average, and what tonight should
put back. The other, built more recently, has the **during-the-day** machinery: five-minute buckets
across the day, a running total, a projection with an honest range, and a curve learned from this
person's own history of how much of a normal day is spent by any given hour.

That last curve is a design addition rather than a technical one, and it is what makes a draining gauge
honest. It is the difference between "61 left" and "61 left, and on a normal day most of what is coming
would already be spent by now". Neither half is the ledger alone. Between them, very little is missing.

---

# Part 6 · The recommendation

## Before launch — **all six closed**

Rev 2's before-launch list was one new screen and five insertions. All six are built. Kept here as
a record, because each line is the acceptance criterion for the thing that answered it.

| | Item | Closed by |
| --- | --- | --- |
| 1 | **The import hub — one drop target, twelve formats.** Auto-detection means this is not a source picker: one place to hand a file, a reference list of what it reads, per-category result counts, and specific errors. Without it the app has no door | `plumbing/import` · `reading` · `imported` · `rejected` |
| 2 | **Backup and restore — the same screen family.** `.noopbak` and the WHOOP CSV zip, plus `BackupSync`'s scheduled snapshots, which need a state and not just a button. No account means no other way onto a new phone | `plumbing/backup` |
| 3 | **Breathe as a screen, and a sweep as an activity.** The flagship. Scoped as the player *plus* the resonance sweep — a mode inside it, and the one piece of the pack that is an activity rather than a display | `day/breathe` · `bcatalog` · `bplayer` · `bsweep` · `bfound`, off the orb |
| 4 | **Smart Alarm.** It arms strap firmware; a user who wakes to it today cannot lose it silently | `night/alarm`, a row on `tonight` — a screen rather than the row Rev 2 scoped, because arming had to be separable from setting |
| 5 | **The illness signal, and what it ruled out.** Priced like any other drain rather than shouted as a banner — the more honest register for a signal that is often a hangover. Five states, and *raised* is the hard one | Inside `day/charge`, as *what it ruled out first* |
| 6 | **The Charge drivers.** Above the ledger, answering why you woke with that number | The drivers section on `day/charge` |

The convention items 5 and 6 both depended on is also built: **the confidence chip**
(`20-primitives.md` §15). Amber stays reserved for attention, which matters most on the very screen
item 5 lands on — the illness signal and the confidence chip would otherwise sit on `day/charge` in
the same colour meaning opposite things.

### The one thing Rev 3 adds to the before-launch list

**Walk a clean install.** Part 5 §C ¶2 stopped being theoretical the moment the engines were
surfaced: half of the eight say nothing for two to six weeks, and that silence is now something you
can open the app and look at. Install clean, import nothing, and read all 69 screens on day one.
`ages/building` and `plumbing/imported` were designed for that state. The rest were not, and the
period they will look wrong in is exactly the period someone is deciding whether to keep the app.

That is a test, not a screen. It is the only item on this list.

## There is no second release

**Rev 2 was wrong about this and it is the correction that matters most in Rev 3.**

Rev 2 wrote: *"The second release: Act 9, and it has an obvious shape — the instrument."* Act 9 is
one of **the nine acts**. It is four screens — `index`, `metric`, `compare`, `effects` — and it is
in the app you can tap today, with its own row at the foot of `trends` and its own entry in the
screen inventory. The redesign is nine acts and 69 screens; **there is no second release inside
it.** Filing a quarter of the archive as "later" and then filing Explore, Compare and Insights as
"gone" was double-counting the same absence, and both halves are now false.

What Rev 2 put on that list, and where each actually landed:

| Rev 2's second release | Actually |
| --- | --- |
| Explore · Compare · Insights, as one act | **Act 9.** Built together, as the memo advised — they share a data model, a range control and a correlation engine, and bolted on individually they would each have looked like a settings screen |
| Automations | **`plumbing/automations`**, one door off `settings` |
| The Updates inbox | **`day/inbox`**, behind the badged bell |
| Workouts in aggregate | **`effort/across`** — landed first, on 31 August, because it reuses the instrument's range control |

Rev 2 closed that section with *"the maths is finished; what is missing is the index, the range
control, and the two treatments— borrowed against earned, and the lag."* All three exist. The
generated-string tables in the Build Document carry the dose figure's four states, including
**disagrees**, and the ranked row leads with the lag rather than the position.

## What is actually later

A short list, and none of it is an act.

1. **The nine drawer utilities** — rows on `settings`, dimmed, with a **Later** chip. Part 3 §C.
   They do not need designing; they need listing, and the cost sub-line is enough to make a list of
   nine read as deliberate rather than as a dumping ground.
2. **Hydration and the two About explainers** — the same treatment, same group. One of them is
   load-bearing: *How Noop works* is where the confidence chip's tap wants to land, and until it
   exists the chip is inert rather than dishonest.
3. **Two platform decisions** — Light appearance and translation. Both are dimmed options with the
   reason in the row, so neither promises anything today; both are still open. Part 3 §C.
4. **Two capabilities with no screen and no row** — Beat Rhythm and Mind. Part 3 §A. Mind is the
   one worth a decision rather than a silence: it is the only *input* the redesign dropped.
5. **Cycle phase** — not on this list either. The engine stays dark until someone asks for it, and
   the shape to revisit is a context layer rather than a screen. Part 5 §B.

## Settled, and still settled

All five placements Rev 2 opened were decided, and all five are now built rather than decided.

1. **Cycle phase — out of scope.** The engine stays dark. Part 5 §B.
2. **The spot reading — `day/heart`.** A card, not a push. Built.
3. **The illness signal — inside `day/charge`.** Priced as a drain. Built.
4. **Breathe — the player and the sweep together.** The sweep is the feature, not a later mode. Built.
5. **The confidence ladder — a chip in the screen's own hue.** Two chips, not three; solid is plain.
   Built, `20-primitives.md` §15.

One convention is new since Rev 2 and belongs beside them: **the evidence gate**
(`41-act2-day.md` §2.2). A verdict beside a Charge number is bound or omitted, never derived from a
bucket. It is the only rule in the pack that makes the app say *less*, and it removed six strings
that had been in the design since the first draft.

## The honest sentence for a returning user

They will find the morning better, the night better, the training decision better, and the
body-age story better than anything the current app shows. They will find their history where they
put it, Breathe where the orb is, their alarm on tonight's plan, and the data answerable in Act 9.

What they will not find: beat-to-beat rhythm, a mood check-in, a Watch app, a light theme, and
nine utilities that say *Later* on the row instead of opening. **That is the whole list.** Rev 2's
version of this paragraph read *"their history missing until it is imported, Breathe gone, their
alarm gone, and no way to ask the data a question they did not think of in advance"* — four
sentences of loss, and none of the four is true any more.
