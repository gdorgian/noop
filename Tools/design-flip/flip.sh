#!/bin/zsh
# flip.sh <design-page.html> <sim-route> <name> [extra launch args...]
#
# Captures one design-handoff screen and the same route in the iOS Simulator at 402 × 874, then
# writes <name>-flip.png (side by side) and <name>-flip.gif (the two alternating in place).
#
# Setup (see README.md in this folder):
#   - Serve the design HTML:   python3 -m http.server 8765 -d <folder with the .dc.html pages>
#   - Boot an iPhone 16 Pro simulator and install a Debug build of NOOPiOS.
# Environment:
#   FLIP_OUT      output folder                       (default ./flips)
#   FLIP_SIM      simulator UDID                      (default: booted)
#   FLIP_BROWSER  Chrome/Chromium/Brave executable    (default: Google Chrome, then Brave)
#   FLIP_SERVER   design server origin                (default http://localhost:8765)
#   FLIP_WAIT     seconds to wait after launching the app (default 5)
#   FLIP_CROP     x,y of the prototype phone in the 3x HTML capture (default 144,156)
set -e
PAGE=$1; ROUTE=$2; NAME=$3; shift 3
OUT=${FLIP_OUT:-./flips}
SIM=${FLIP_SIM:-booted}
SERVER=${FLIP_SERVER:-http://localhost:8765}
BROWSER=${FLIP_BROWSER:-}
if [[ -z $BROWSER ]]; then
  for candidate in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
                   "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"; do
    [[ -x $candidate ]] && BROWSER=$candidate && break
  done
fi
[[ -n $BROWSER ]] || { echo "No Chromium browser found; set FLIP_BROWSER" >&2; exit 1; }
APP=$(find ~/Library/Developer/Xcode/DerivedData -path '*Debug-iphonesimulator/Noop Aura.app' -maxdepth 6 -type d | head -1)
[[ -n $APP ]] || { echo "No Debug simulator build of Noop Aura found" >&2; exit 1; }
BID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist")
mkdir -p $OUT

"$BROWSER" --headless=new --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=3 --window-size=1100,1000 --virtual-time-budget=9000 \
  --screenshot=$OUT/$NAME-html-full.png "$SERVER/$PAGE" >/dev/null 2>&1
xcrun simctl terminate $SIM "$BID" >/dev/null 2>&1 || true
# --noop-route and --demo-seed are Debug-only launch arguments (NoopNavigation.swift).
xcrun simctl launch $SIM "$BID" --noop-route $ROUTE "$@" >/dev/null
sleep ${FLIP_WAIT:-5}
xcrun simctl io $SIM screenshot $OUT/$NAME-sim.png >/dev/null 2>&1

python3 - "$OUT" "$NAME" "${FLIP_CROP:-144,156}" <<'PY'
import sys
from PIL import Image
d, n, crop = sys.argv[1], sys.argv[2], sys.argv[3]
x, y = (int(v) for v in crop.split(','))
h = Image.open(f'{d}/{n}-html-full.png').convert('RGB').crop((x, y, x + 1206, y + 2622))
h.save(f'{d}/{n}-html.png')
s = Image.open(f'{d}/{n}-sim.png').convert('RGB').resize((1206, 2622))
c = Image.new('RGB', (1206 * 2 + 40, 2622), (233, 229, 221))
c.paste(h, (0, 0)); c.paste(s, (1246, 0))
c.resize((c.width // 3, c.height // 3)).save(f'{d}/{n}-flip.png')
# In-place flip: the two captures alternate in the same 402 × 874 frame.
h2 = h.resize((402, 874)); s2 = s.resize((402, 874))
h2.save(f'{d}/{n}-flip.gif', save_all=True, append_images=[s2], duration=900, loop=0)
print(f'{d}/{n}-flip.png')
PY
