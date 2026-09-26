# One request for design

*24 September 2026. Written against the 11.7 handoff in [`docs/design/11.7`](../design/11.7/README.md).
Still open when development paused on 26 September 2026.*

Release shows only what the app measures or computes. Wherever the final HTML uses the example
person's words or numbers and there is no rule for a real reading, Release leaves the words out. It
never substitutes the example. Everything below is left out today. Please send the sentence, the
template (with its slots) or the rule, or say "leave it out". Numbers in {braces} are values the app
can supply.

> Since this was written, Codex added some honest replacement sentences to Release (for example on
> Trends, Settings, Svea's consent page and the goal editor). They are not designer copy. Review them
> together with this list.

## A. Sentences with no rule for real data (Release omits them)

**Rest**

1. The night's verdict under "The shape of it" ("Full night, and deep sleep came early."): which facts pick which sentence?
2. The sub-line under "Why last night".
3. The sub-line under "Sleep debt". The figure is available; "two ordinary nights clears it" has no rule.
4. The ring sentence for a night that is not last night. Release keeps "The ring stops short by {n} minutes" and drops "— see why last night went that way".
5. Debt: the correlates list and the read paragraph.
6. Tonight: the note under each stop ("Clears twenty minutes of debt and still leaves you an evening"), and the two reason notes.

**Today and its details**

7. The day-so-far read, the scrub read ("Closest to the walk at 08:26 ...") and the "What happened" list.
8. The Heart hero's sub-line ("Easy · sitting just above resting").
9. The per-vital sentences on Vitals ("Two beats slower than your baseline...").
10. The Svea card's sub-line on Today.
11. Energy: the partial case's lead ("The strap was off between {start} and {end}...") needs the gap's clock times. Say whether we should compute them or drop the sentence.
12. Energy: the learning-case chip ("4 of 14 days").

**Effort (Act 3, recording only; no prescription ships)**

13. Session home with no recommendation: the hero label (the HTML only has "Dialled back for today" and "Your choice").
14. Picker intro. The current one promises "what it would cost you today", and nothing is priced.
15. Session detail: the chart read, the effort split sentence, "What it cost you" and Svea's paragraph.

**Trends**

16. The six-month and Year verdict lines, and the attendance read.
17. Capacity: "What moved it" and "What would move it next".
18. The Capacity footnote says the estimate uses "recovery after effort and the pace you hold". The app's estimate is waist-based (Nes) or resting pulse against maximum (Uth). Please reword.

**Your ages (one engine: VitalityEngine)**

19. The headline sentence ("Your body is running about 6 years behind your birthday, and it has been for two months.").
20. Driver detail: the lead line, "What would move it" and the caveat, per factor.
21. The engine has a sixth factor, sleep duration, with no design (no scale, no name decision). Release shows it as "Sleep duration" with no scale.
22. The HRV scale label "against the norm for 40" is shown as "against the norm for your age". Please confirm.

**You**

23. Core-card copy on the You hub, and "held to within" on the body clock.
24. Zones: the page copy "Built from two numbers Noop has actually seen on you" is false for an estimated maximum. Needs one line per source (estimated / set by you).
25. The History empty state has no sentence.
26. Widgets page: the three drawn previews use example figures, so Release lists the families only. The Glanceable family's detail still says "the three faces above".
27. Automations copy that promises missing features: Illness early warning "appears in the charge ledger"; Move reminder "never after your anchor".
28. Apple Health: the page copy ("six kinds out, one in") and the two summary tiles do not match the bridge. Release lists the groups written at the last sync.

**Goals**

29. Journey: Svea's week card, the biomarker summary, and the distance-goal subtitle.
30. Set: the evidence bars and the Safety check card.

## B. New labels Release had to use (confirm or replace)

31. Zone names: "Zone 1" to "Zone 5". The design's Resting / Easy / Steady / Hard / All out bands do not line up with the app's zones (owner decision: use the wearer's real zones).
32. Zone source tags: "estimated" / "set by you". Maximum card titles: "Estimated maximum" / "Maximum you set".
33. Tonight's reasons card rows: "Your need · {8h 00m}" and "Falling asleep · {14m}". *Since withdrawn: the record has no verified in-bed start, so Release offers no lights-out time at all.*
34. The sleep need is the app's planning target, not a measured need (owner decision). "own" is removed everywhere, and the 90-night calibration chip is gone. Should "your need" be renamed (for example "your target")?
35. Body Age "the same as your age" and "{n} years older than your age" (the HTML only writes "younger").
36. Fitness age: "{n} years over your own" and "The same as your own." (the HTML only writes "under").
37. Heart row: "{n} beats over your baseline" (the HTML only writes "under").
38. The session refusal uses spec 90 §9.1's body: "{workout name} started {time}. Noop keeps one session at a time." When a lift has no program name, {workout name} is "Lift". Please confirm.

## C. States the HTML does not draw

39. The strap is not bonded: "A reading, now" (the button is dimmed).
40. An unconfirmed body profile on Energy. Release shows a "Confirm your body profile" button.
41. Charge on the widgets and the Watch glance (owner decision: no morning recovery as Charge). Every Charge cell shows "–" until an intraday ledger exists. The small Rings widget shows Charge alone, so it is a lone dash. Redraw it, or pick a different small widget?
42. Your ages when there is not enough data, or the age is unconfirmed. *Since changed (owner decision, 24 September): the orb stays visible but still, in quiet green and grey, and names the reason (profile confirmation or the count of usable factors). Amber appears only when a validated Body Age is older than the wearer's age.*
43. Tonight without an armed alarm or a measured time to fall asleep. Only the alarm card shows.
44. Session home before a template is chosen: no label above the name.

## D. Still blocked on an engine (listed so nothing is lost)

- Charge (intraday ledger): the Today gauge, the Charge detail, the widgets and the Watch.
- Why last night (a causes engine).
- The year so far (the chapters and firsts are written prose).
- Body Age pace of aging needs a defensible longitudinal method. The health domains have a scorer (`BioAge` / SuperAgeCore, with tests) that is not wired into the Ages screen.
- The Act 3 prescription (the recommended session, its cost, the rest day "folded into tomorrow").
- Sleep goal (no nights-in-window goal kind). It is disabled; goals already saved are kept.
