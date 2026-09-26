# What is deliberately not in this release

*Written 1 September. Read with `60-parity.md`, which explains why each one is affordable.*

**Nothing on this page is an oversight, and nothing on it is a bug.** Each item was designed, costed
and then held back. If you are implementing and you find one of these missing, that is correct —
do not build it, and do not improvise a placeholder for it.

## The rule that makes this safe

A capability that is decided but not built is **listed, dimmed, and marked `Later`** — never a live
switch with nothing behind it, and never silently absent. See `60-parity.md` Part 5 §C ¶4 for the
full convention. In short:

- Whole row not shipping → the row renders with a dimmed title, its normal sub-line, a neutral
  **Later** chip where the chevron would be, and **no control and no tap target**.
- Part of a row shipping → the live options work; the unshipped options render at 34% opacity and
  cannot be picked, and the row's own sub-line says which and why.
- The chip is **neutral grey**, never amber. Amber means *needs your attention*; a feature that has
  not shipped is not the user's problem.

## The nine utilities — `settings` → Later

Listed as rows, in this order, under the group note. None of them navigate.

| Row | What it will be |
| --- | --- |
| Your data, fused | every source merged onto one timeline, with the winner named per day |
| Storage | what the database is spending, by category |
| Nutrition | calories and macros on the same timeline as charge and rest, via CSV |
| Weekly digest | the written summary, Sunday evening |
| Trends report | a longer read across a quarter, exportable |
| Siri and Shortcuts | App Intents and voice |
| Shortcuts export | the HealthKit-free path, for a sideloaded build with no account |
| Strap limitations | 4.0 against 5.0 against MG — what each band can read |
| How Noop works / What's new / Set up Apple Watch | in the About group, same treatment |

## The six appearance treatments — `settings` → Appearance

Chart colours, Sleep chart, Card surface, Day-cycle sky, App icon, and Hydration under Features.
Same treatment. **Light appearance** is an option-level Later: the design has values for dark only,
so Dark is live and Light and System are dimmed with the reason in the row's sub-line.

## Translation

Every string in this pack is English, and several are specified verbatim in `70-copy.md` and the
Build Document. The Language row ships with **English live, System and Deutsch dimmed**.

Implementers: still wrap every string as `LocalizedStringResource`, exactly as `MoreCatalog` already
does, and keep the repo's i18n audit passing. The strings being English today is a release decision;
hard-coding them is a bug that will cost a week later.

## Cycle phase

`CyclePhaseEngine` stays dark and unsurfaced. It is the one engine with no screen and no chip on
purpose — `60-parity.md` Part 5 §B has the reasoning. Do not wire it to anything.

## What that leaves

Everything else in the 69 screens is meant to be built, and every one of them is reachable. If a
screen in the prototype has no door you can find, that is a bug in the prototype — tell me rather
than inventing a route.
