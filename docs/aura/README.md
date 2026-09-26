# Noop Aura — development handoff

*Development paused on 26 September 2026, after the
[11.7.0 experimental release](https://github.com/gdorgian/noop/releases/tag/v11.7.0-aura.1104).
Everything needed to continue lives in this repository; nothing depends on files kept elsewhere.*

## Where everything is

| What | Where |
| --- | --- |
| How the app fits together (interactive map + images) | [`architecture/`](architecture/) — open `noop-aura-architecture.html` in a browser |
| Current design reference (20 September handoff: HTML, specs, notes) | [`docs/design/11.7`](../design/11.7/README.md) |
| Earlier design handoff (9 September, superseded, kept for history) | [`docs/design/2026-09-09-handoff`](../design/2026-09-09-handoff/README.md) |
| Screen-by-screen QA against the 9 September handoff | [`docs/design/qa-2026-09-09`](../design/qa-2026-09-09/index.html) |
| Everything still needed from design (44 items) | [`designer-request.md`](designer-request.md) |
| What was tested on a real iPhone, and the result | [`device-test-2026-09-25.md`](device-test-2026-09-25.md) |
| Design-vs-app screenshot comparison tool | [`Tools/design-flip`](../../Tools/design-flip/README.md) |
| Why things are built the way they are | [`docs/fork/decisions.md`](../fork/decisions.md) |
| Release notes for 11.7.0 | [`docs/fork/releases/v11.7.0.md`](../fork/releases/v11.7.0.md) |
| Older, unmerged experiments (August) | branches under `archive/` |

The iOS code is on `main`. The Aura interface is `StrandiOS/NoopUI` (`NoopShell.swift` holds the
production shell, `NoopVerifiedAppShell`; each act has a view file and, for live data, a
`…Record.swift` beside it).

## Rules the release was built on

These were owner decisions. Change them deliberately, not by accident.

- **Honest over full.** Release shows only what the app measures or computes. With no rule for a
  real reading, a designed sentence is left out, never filled with the example person's words or
  numbers. Missing values show "—". Debug demo data (`--demo-seed`, Debug builds only) never reaches
  Release.
- **Charge** is not shown until an intraday ledger exists. Morning recovery is never presented as
  Charge, including on widgets and the Watch.
- **Sleep need** is the app's planning target, not a measured personal need. No lights-out time is
  offered: the record has no verified time of getting into bed.
- **Sessions and Lift** are one workout experience. Only one session runs at a time; a second start is
  refused with the designed "A session is already running" sheet, never ended or replaced.
- **No prescription** (recommended workout, predicted cost) without an engine behind it.
- **Heart-rate zones** are the wearer's real zones, named Zone 1–5, marked "estimated" or "set by you".
- **Body Age** uses one engine (`VitalityEngine`) for the hero, its band and its drivers. Before data
  exists the orb stays still in quiet green and grey and names the reason; amber only when a
  validated Body Age is older than the wearer's age.
- **The Sleep goal** is disabled; goals already saved are kept.
- **Text** is held at the standard size whatever the iPhone's Text Size is set to.
- **Branding:** "Noop Aura" on the terms and first-launch gate; "Noop" elsewhere. Dark is the active
  appearance; Light/System is "Later".

## Known problems at the pause

From the 25 September device test (build 1102):

- **The strap alarm did not buzz.** Trace from Rest → Tonight's alarm toggle to the strap command.
- **You → Your journey is broken** on a real device (details not yet captured).
- **Noop's Home Screen widgets did not appear in the widget gallery**, although the widget extension
  runs (the Live Activity works). Likely signing of the extension or a gallery cache after an identity
  change; check how the sideloader signs `NOOPWidgets.appex`.
- **A cardio session can be lost** if its database write fails after the crash-recovery copy is
  cleared (`AppModel.endWorkout`). Rare, but real.
- **Designer copy is still missing** for many real-data states: see
  [`designer-request.md`](designer-request.md).
- The user's own verdict at the pause: usable for recording, not yet a daily app. Many screens are
  honest but sparse until the engines below exist.

## Still blocked on an engine

- Intraday **Charge** ledger (Today gauge, Charge detail, widgets, Watch).
- **Why last night** (a causes engine).
- **The year so far** (written chapters).
- **Pace of aging** (needs a longitudinal method) and the **health domains** (the `BioAge` /
  SuperAgeCore scorer exists with tests but is not wired into Ages).
- **Workout prescription** and the **Sleep goal** kind.

## Building

- Scheme `NOOPiOS`; run `xcodegen generate` after changing `project.yml`. See
  [`docs/BUILD.md`](../BUILD.md) and [`docs/IOS.md`](../IOS.md).
- **Signing identity stays private.** A personal build reads its bundle ID and App Group from
  `Config/BundleIdSecrets.xcconfig`, which is gitignored and must never be committed (see `CLAUDE.md`,
  "Fork identity"). Both values must match the provisioning profile, including the App Group, or the
  widgets cannot share data.
- **A public IPA carries only the public defaults** (`com.noopapp.noop`). The 11.7.0 release was built,
  run through `Tools/anonymize-ios-app.sh`, checked for the expected public IDs, and only then uploaded.
- Swift files shared with macOS must also build under the `Strand` scheme.

## Testing on a real iPhone from the Mac

With the phone paired and unlocked, `xcrun devicectl` can do most checks without touching the phone:

- `devicectl device capture screenshot --device <udid> --destination shot.png`: see the current screen.
- `devicectl device info apps --device <udid>`: confirm the installed build number.
- `devicectl device info files --domain-type appGroupDataContainer --domain-identifier <app group>`:
  confirm the widgets' shared snapshot is being written.

It cannot tap; the tester navigates and the Mac captures.
