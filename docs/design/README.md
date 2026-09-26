# Noop Aura design source

The [11.7 handoff](11.7/README.md) is the current iOS design reference. It includes the interactive HTML drawings in `app/`, implementation specifications in `spec/`, decision records in `notes/`, and source icon references in `assets/`.

Open `11.7/app/Noop - Full App.dc.html` in a browser. Keep the adjacent `support.js` file with the HTML. For a precise comparison, render a screen at **402 × 874**, capture the native iOS screen at the same size, and flip the two images in the same position. The handoff's README explains precedence and remaining build-time work.

These files are design references, not the shipped app. Their example measurements and names are prototype fixtures. A Release build must derive health values and claims from the wearer's actual record or show an honest unavailable state.

Earlier material is kept for history only. Where it disagrees with the 20 September pack, the 20 September pack wins.

- [`2026-09-09-handoff`](2026-09-09-handoff/README.md): the 9 September handoff, superseded. Its `CLOSURE.md` records the answers to the questions raised on that pack.
- [`qa-2026-09-09`](qa-2026-09-09/index.html): a screen-by-screen flip comparison of the app (Debug demo data) against that handoff. Download and open `index.html`; the evidence images sit beside it.

The development handoff, with open design questions and the device-test record, is in [`docs/aura`](../aura/README.md).
