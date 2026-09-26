# Community post — Noop Discord, #fork-showcase

*Written 26 September 2026 to announce the pause and the hand-over. Title: **Noop Aura**. Attach
[`showcase/cover.png`](../assets/aura-11.7/showcase/cover.png) first (it becomes the thumbnail), then
the four themed images in [`showcase/`](../assets/aura-11.7/showcase/) and the
[architecture map](architecture/noop-aura-architecture-dark.png).*

```
Hi all 👋 Sharing **Noop Aura**, an iPhone-first fork of NOOP.

It keeps NOOP's foundation exactly where it is (the Bluetooth link, the on-device database, the analytics) and puts a calmer interface on top. Every screen was designed first as a full interactive prototype, then built back against it at 402×874.

We tried hard to get it finished, but personal responsibilities mean we have to pause development here. Rather than let it sit on a laptop, we're putting everything on GitHub for anyone who wants to continue it.

**What's in 11.7**
- Rest: last night as a ring against your sleep target, with stages and sleep debt
- Vitals against a band built from *your own* recent nights, not population charts
- Live heart rate on Today and on the Lock Screen / Dynamic Island
- One place to record rides, walks, HIIT, swims and lifts (with a lift log), written to Apple Health
- Trends, and a Body Age that shows which factors pull it which way
- Quick logging (coffee, water, meals, drinks, naps) and WHOOP export import
- Svea, an optional coach built on the NOOP AI fork's work: it only talks to the provider you pick, only about what you allow

**What's on GitHub**
The source, the complete design handoff (interactive HTML for every screen, specs and notes), an architecture map, the open design questions, the last real-device test and a handoff doc that says where to start. Known gaps: the strap alarm, goal setup and Home Screen widgets.
https://github.com/gdorgian/noop

**Try it**
iOS 17+. The IPA is unsigned, so sign it with your sideloader. Apple Health needs a signing identity with HealthKit (free Apple IDs can't get it). It's an experimental release.
https://github.com/gdorgian/noop/releases/tag/v11.7.0-aura.1104

If you pick it up, fork away. Issues and PRs are welcome, even if replies are slow for a while.

Not affiliated with WHOOP, not a medical device.
```
