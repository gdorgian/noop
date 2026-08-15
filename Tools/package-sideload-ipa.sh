#!/usr/bin/env bash
# Package a built NOOPiOS .app as an .ipa for FREE-Apple-ID sideloading (SideStore / AltStore).
#
# Why this exists: free provisioning cannot reuse a bundle identifier, so SideStore rewrites the app's
# id to "<bundle-id>.<TEAMID>" at install time. It does NOT rewrite the embedded Watch app's
# WKCompanionAppBundleIdentifier, which is baked at build time as the ORIGINAL id — so iOS sees a watch
# app pointing at a companion that no longer exists and refuses the whole install:
#
#   InvalidCompanionAppBundleIdentifier (… incorrect value, "com.noopapp.noop", for the
#   WKCompanionAppBundleIdentifier key … set it to the companion app's bundle identifier,
#   "com.noopapp.noop.<TEAMID>".)
#
# Patching the key to a specific team id would work but hardcodes one machine's provisioning, and a
# watch app can't be usefully installed over a free sideload anyway. Dropping it is the honest fix:
# smaller download, no watch features lost that were reachable in the first place.
#
# Usage: Tools/package-sideload-ipa.sh <path-to-.app> <output.ipa>
set -euo pipefail

APP=${1:?usage: package-sideload-ipa.sh <path-to-.app> <output.ipa>}
OUT=${2:?usage: package-sideload-ipa.sh <path-to-.app> <output.ipa>}
[ -d "$APP" ] || { echo "not a bundle: $APP" >&2; exit 1; }

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/"

BUNDLE="$STAGE/Payload/$(basename "$APP")"
if [ "${STRIP_EXTENSIONS:-0}" = "1" ] && [ -d "$BUNDLE/PlugIns" ]; then
    echo "stripping app extensions (explicit App ID covers the app bundle id only)"
    rm -rf "$BUNDLE/PlugIns"
fi

if [ -d "$BUNDLE/Watch" ]; then
    echo "stripping embedded Watch app (see header for why)"
    rm -rf "$BUNDLE/Watch"
fi

rm -f "$OUT"
( cd "$STAGE" && zip -qry "$OUT" Payload )

echo "packaged: $OUT"
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$BUNDLE/Info.plist" | sed 's/^/version: /'
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$BUNDLE/Info.plist" | sed 's/^/build:   /'
ls -lh "$OUT" | awk '{print "size:    "$5}'
shasum -a 256 "$OUT" | awk '{print "sha256:  "$1}'
