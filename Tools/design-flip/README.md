# design-flip

Compares a design-handoff screen with the same screen in the iOS Simulator, at the design's
402 × 874 canvas, by flipping the two captures in place. This is how the 11.7 screens were checked
against [`docs/design/11.7`](../../docs/design/11.7/README.md).

## Setup

1. Copy the handoff's `app/` folder somewhere writable (for example `/tmp/flip`) and serve it:
   `python3 -m http.server 8765 -d /tmp/flip`
2. Boot an iPhone 16 Pro simulator (402 × 874 pt) and install a Debug build of the `NOOPiOS` scheme.
3. Have Google Chrome, Chromium or Brave installed, plus Python with Pillow (`pip3 install pillow`).

## Use

```bash
Tools/design-flip/flip.sh "Noop Act 2 - The Day.dc.html" today act2-today --demo-seed
```

Writes `flips/act2-today-flip.png` (side by side) and `flips/act2-today-flip.gif` (in-place flip).
`--demo-seed` loads the Debug demo person so the app shows data; Release never shows it.

Each page opens in its default state. To capture another state, make a copy of the page with other
prop defaults, then serve the copy:

```bash
python3 Tools/design-flip/mkflip.py "/tmp/flip/Noop Act 2 - The Day.dc.html" /tmp/flip/day-building.html confidence='"building"'
```

Each `key=value` sets that prop's `default` in the page's `data-props` block; values are JSON. The
available props and their options are listed in that block at the top of each page.

## Reading a flip

Separate **visual** differences (spacing, type, colour, geometry) from **content** differences. The
HTML shows its example person; the app shows the demo seed or real data. A different number is not a
defect, but a different layout is.
