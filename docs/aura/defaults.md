# How Noop Aura starts

Aura is a calm companion for your data, with plenty of depth for anyone who wants it. A fresh install shows the
essentials and nothing more. Everything else is one tap away, in each page's Add sheet or in Settings.
Check this list against the code before every beta (decided 26 Oct 2026, build 1219).

## Pages

Pages show only sections marked `onByDefault`. Alternative designs stay in Add.

| Page | On by default | In Add, or shown only when there is something to show |
|---|---|---|
| Today | Breathing orb (Aura's signature look), Effort today + Bedtime (tiles), Last night, Your day, Energy, Vitals | Svea (once she is set up and not off), Logged today (once something is logged), Stress (until the day has a scored stress line), Activity status, every other tile and alternative design |
| Rest | Your sleep, In bed and asleep, Your last seven, Stages in lanes, Over time, Your next sleep | The shape of it, Trends, the header and sleep alternatives |
| Trends | Body age, Markers, What changed, Explore, Your summaries | Bloodwork (once there is a lab result), Recording history, alternatives |
| Fitness | All seven sections | Routines and Cardio and sports stay, because they are where a routine is built and a sport is started |
| You | Your clock, Your body, Your journey | Header alternatives |
| Recovery, Strain | Header, tiles, Trends | Header alternatives |

A section added in a later build is **offered** on a page the wearer has already arranged ("New on this page:
Add it / Not now"). It is never slipped in. Pages the wearer never arranged simply have it.

## Notifications

| On | Off |
|---|---|
| Your night is in, Battery alerts, Sync reminder, Backup reminder | Off-wrist reminder, A new best, Weekly read, Quiet hours |

- **Bedtime nudge** is off until Noop has planned from 14 of the wearer's own nights (`NoticeRules.nightsNeeded`).
  Today then offers it once ("Nudge me / Not now"). Either answer is final.
- **Notification permission** is asked at the end of setup, next to the four notices it is for. It is not asked
  at a random moment later.

## Everything else

- **Units** follow the iPhone's region: imperial only for US measurements, metric everywhere else. This is a
  registered default, never written, so a wearer who never chose keeps following the region. Temperature and
  distance follow units.
- **Effort** shows on a 0–100 scale. **Sleep staging V2** is on. **Live heart rate in the Dynamic Island** is on.
  **Power saving** is off, and starts at 20% when turned on. The **app icon** is Aura.
- **Svea** is off until a provider is connected.

## Upgrading

- Settings the wearer **chose** are kept. Settings they never touched follow the defaults above.
- Someone who arranged any page differently from the new default is asked once, on Today: **"Aura has a new
  default look: Keep my pages / Use the new look"**. A fresh install is never asked. Every page also keeps
  Reset in edit mode.
