<p align="center">
  <img src="StrandiOS/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png" width="96" alt="Noop Aura app icon">
</p>

<h1 align="center">Noop Aura</h1>

<p align="center">Your WHOOP strap data, on your iPhone, in a calmer interface.</p>

<p align="center"><strong>11.7.0 experimental development release · iPhone first · not a medical device</strong></p>

Noop Aura is an independent fork of [RyanBR's NOOP](https://github.com/ryanbr/noop). It keeps the local-first strap, storage and analytics foundation, develops a new iOS interface, and draws on the optional AI-coach work from [DX's fork](https://github.com/DX23876/noop). It is not affiliated with WHOOP.

The app is **still in development**. You can try the current iPhone build, inspect the complete design source, and report what fails or differs. Do not rely on its estimates for medical decisions.

## The app

<p align="center">
  <img src="docs/assets/aura-11.7/today.png" width="205" alt="Noop Aura Today screen with the breathing and Charge orb">
  <img src="docs/assets/aura-11.7/trends.png" width="205" alt="Noop Aura Trends screen with the animated Body Age graphic">
  <img src="docs/assets/aura-11.7/rest.png" width="205" alt="Noop Aura Rest screen with the sleep ring">
  <img src="docs/assets/aura-11.7/you.png" width="205" alt="Noop Aura You screen with the day-cycle graphic">
</p>

<p align="center"><sub>Native iOS Simulator captures from the 11.7 build. Debug-only example data is used in these pictures; Release does not fill missing measurements with those values.</sub></p>

Today brings together the current record and quick ways into the rest of the app. Rest covers the night and tonight's plan. Sessions, trends, ages, the optional coach, goals and labs have their own screens. What you see in a normal build depends on data actually available to the app; an unready measurement should say so rather than invent a number.

## Try 11.7

Download the **[Noop Aura 11.7.0 experimental release](https://github.com/gdorgian/noop/releases/tag/v11.7.0-aura.1104)** and read its limitations before installing. The IPA is unsigned and must be signed with your own Apple ID through a compatible sideloader. This is not an App Store build. Keep a backup before changing app identity or reinstalling; a different signed bundle ID will not inherit the old app's local database.

The current release is for **iOS only**. For Android, use the [upstream project](https://github.com/ryanbr/noop). See the [iOS install guide](docs/IOS.md) and [build guide](docs/BUILD.md) for technical details.

## Explore the design

The complete [11.7 design handoff](docs/design/11.7/README.md) is public here: interactive HTML for the app and its child screens, specifications, measurements, route maps, decision notes and icon references. Start with its README, then `notes/FOR ENGINEERING - Noop Aura 11.7 open items.txt`. The HTML is the visual and interaction reference; it is **not** the application code. The [design index](docs/design/README.md) explains how to compare it with an iOS screenshot at 402 × 874.

## Privacy and provenance

The strap record and app database are kept on the device. The AI coach is optional; if enabled, it can contact the provider you configure under the permissions you grant. Noop Aura has no project account or telemetry server. Read [privacy and security](docs/PRIVACY_SECURITY.md), [attribution](ATTRIBUTION.md) and the [license](LICENSE) for the precise boundaries.

This release is an **experiment, not a claim of finished feature parity**. Some data-driven screens need more history, some features need further wiring or real-device verification, and the design HTML contains example-person values that are never a substitute for your own readings. Bugs and side-by-side screenshot comparisons are welcome in [Issues](https://github.com/gdorgian/noop/issues).
