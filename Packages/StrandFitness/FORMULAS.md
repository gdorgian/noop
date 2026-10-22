# StrandFitness formulas

Every number on the Fitness page comes from one of these. They are Noop Aura's own, built from
published methods; each is pinned by a test in `Tests/StrandFitnessTests`.

| Metric | Formula | Source |
|---|---|---|
| Max heart rate | measured max, else 208 − 0.7 × age, else 190 (marked as a guess) | Tanaka, Monahan & Seals 2001 |
| Heart-rate zones | reserve fraction r = (HR − rest) / (max − rest); Z0 < 0.5, then 10-point bands to Z5 ≥ 0.9 | Karvonen 1957 |
| Session cardio load | TRIMP = Σ minutes × r × k·e^(b·r); k, b = 0.64, 1.92 (male), 0.86, 1.67 (female), mean if unknown | Banister 1991 |
| Cardio / Muscular Load | ATL = mean daily load, 7 days; CTL = mean daily load, 42 days; optimal 0.8–1.3 × CTL; gauge top 1.4 × optimal top | acute:chronic ratio, Gabbett 2016 |
| Load status | ATL/CTL < 0.8 detraining · < 1.0 maintaining · ≤ 1.3 productive · above fatigued | — |
| Calibrating | fewer than 10 sessions in 42 days, or none in the last 28 | — |
| Set stimulus | clamp(1 − max(0, RIR − 3) / 10, 0.3, 1); RIR reported, else from the lifter's best e1RM (Epley), best reps or best time | Epley 1985 |
| Muscular load | 10 points × stimulus per set; primary muscle 1.0, secondaries 0.5; cardio adds a per-sport share of its TRIMP to the muscles it works | — |
| Muscle freshness | fatigue = Σ load × 0.5^(hours / half-life); freshness = clamp(100 × (1 − fatigue / capacity), 1, 100); capacity = 1.5 × mean load per training day over 42 days (6 hard sets until 3 training days) | — |
| Freshness status | ≥ 75 % recovered · ≥ 40 % fatigued · below depleted | — |
| Half-lives | 36 h quads, hamstrings, glutes, lower back, adductors · 30 h chest, lats, upper back, traps · 24 h arms, shoulders, hip muscles · 18 h abs, obliques, calves, shins, neck | 48–72 h recovery literature |
| Cardio focus | share of zone 1–5 time: low aerobic Z1–2, high aerobic Z3–4, anaerobic Z5 | — |
| Heart-rate recovery | HR at session end − HR 60 s later, nearest samples within ±10 s; < 12 low · < 20 fair · < 30 good · else excellent | Cole et al. 1999 |
| Volume | weight × reps, with body mass added for bodyweight movements | — |
