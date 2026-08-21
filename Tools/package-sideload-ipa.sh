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
#
# Env:
#   STRIP_EXTENSIONS=1       drop PlugIns/ (widgets + Live Activity). Only when the signing identity
#                            cannot cover the extension bundle ids.
#   STRIP_EMBEDDING_MODEL=1  drop the 336 MB Nomic GGUF. Coach memory falls back to keyword retrieval;
#                            see the block below for the trade.
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

# The on-device embedding model is 336 MB of the bundle — roughly 95% of it. The coach's semantic memory
# uses it to build a vector index over approved facts and chat turns; without it the retrieval falls back
# to its keyword arm, which `NomicTextEmbeddingProvider` does by design when the file is absent (it checks
# for the file and degrades rather than failing). DX23876's own MemoryBench measures that keyword-only
# path as a shipped configuration, not a broken one.
#
# So this is a real choice rather than a compromise: STRIP_EMBEDDING_MODEL=1 trades better recall in the
# coach's memory for an IPA that is ~20 MB instead of ~350 MB. Over a cable that is a rounding error; over
# a phone re-signing itself every seven days on a free Apple ID, it is the difference between a background
# task and a chore.
if [ "${STRIP_EMBEDDING_MODEL:-0}" = "1" ]; then
    MODEL=$(find "$BUNDLE" -maxdepth 2 -name "*.gguf" 2>/dev/null | head -1)
    if [ -n "$MODEL" ]; then
        echo "stripping the on-device embedding model ($(du -h "$MODEL" | cut -f1)) — coach memory falls back to keyword retrieval"
        rm -f "$MODEL"
    fi
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
