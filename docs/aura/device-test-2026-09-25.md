# Device test — 25 September 2026

Build 1102 (11.7.0), a personal signed build of what became the 11.7.0 experimental release, on an
iPhone 16 Pro Max (iOS 27) with a WHOOP strap. A month of WHOOP history had been restored from a
backup. Ticked by the owner.

| Area | Check | Result |
| --- | --- | --- |
| Heart rate | Today shows live heart rate within a minute | Pass |
| | Live heart rate on the Lock Screen / Dynamic Island | Pass |
| Recording | Effort → sport → Start, run 2+ minutes | Pass |
| | Pause, resume, End; the session appears in history | Pass |
| | The workout appears in the Health app | Pass |
| | Force-quit mid-session; the session bar returns with the right sport and time | Pass |
| One session | Starting a Lift while a session runs shows "A session is already running"; "Go to it" returns to it | Pass |
| | Nothing is ended or replaced | Pass |
| Lift | Effort → Strength opens the Lift library; start, log a set, finish | Pass |
| | The lift appears in history; tapping it opens the lift detail | Pass |
| Apple Health | You → Apple Health lists what the last sync wrote | Pass |
| | Heart rate and sleep from the strap appear in the Health app | Pass |
| Alarm | Rest → Tonight: the alarm card arms and disarms | Pass |
| | The strap alarm buzzes in the morning | **Fail — it did not buzz** |
| The + button | Today: "Log it"; a logged coffee survives relaunch | Pass |
| | Rest: "Log the day" opens empty; saving shows "Logged {time} — …" | Pass |
| | Trends: "Everything you logged" lists the last three days | Pass |
| | You → Your journey: set and commit a goal | **Fail — broken** |
| | Effort, You and Ages each open their screen or sheet | Pass |
| Honesty | Home Screen widgets show data, Charge as "–" | **Fail — Noop's widgets not available in the gallery** |
| | Your ages: a Body Age, or a still green/grey orb naming the reason | Pass |
| | No screen shows the example person's numbers | Pass |

Also confirmed from the Mac with `devicectl`: the build and bundle were the expected ones, the widget
extension process was running, and the App Group snapshot held real heart rate, HRV, resting heart
rate and battery, with no Charge value.

Fixed during this round (in the release): the + button opened a placeholder instead of the designed
sheets (which also blocked the goal editor); Today briefly showed example times on launch; the energy
card printed "basal 0 · active 0" when the strap gives only a total; the terms gate and onboarding were
laid out 470 pt wide and cut off; and the app's text shrank with the iPhone's Text Size setting.
