#!/usr/bin/env bash
# Build unsigned IPA payloads from one complete Noop Aura iOS .app:
#   1. AltStore/SideStore: phone/iPad app + the iOS widget extension, prepped for AltSign
#   2. Full Apple bundle: the same iOS app + widget, untouched for signing with a personal team
#
# The widget is an ordinary app extension: AltStore/SideStore re-sign it with the host app, and
# `prepare-ios-sideload-app.sh` leaves the capability template AltSign needs for the shared App Group.
# This fork's Aura release is iOS-only and contains no embedded watchOS bundle.
#
# Pass `-` for either output to skip that variant. The release workflow deliberately builds the
# public AltStore app and the private Full app separately, so it must not prepare (or even stage) a
# private AltStore copy. Optional NOOP_EXPECTED_* values turn release metadata into hard assertions.
set -euo pipefail

APP="${1:?usage: $0 path/to/Noop\ Aura.app lite.ipa|- full.ipa|-}"
LITE_INPUT="${2:?usage: $0 path/to/Noop\ Aura.app lite.ipa|- full.ipa|-}"
FULL_INPUT="${3:?usage: $0 path/to/Noop\ Aura.app lite.ipa|- full.ipa|-}"

[[ -d "$APP" ]] || { echo "iOS app bundle not found: $APP" >&2; exit 1; }
[[ "$LITE_INPUT" != "-" || "$FULL_INPUT" != "-" ]] || {
  echo "at least one IPA output must be requested" >&2
  exit 1
}

absolute_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "$PWD" "$1" ;;
  esac
}

APP_NAME="$(basename "$APP")"
IOS_WIDGET="$APP/PlugIns/NOOPWidgets.appex"

[[ "$APP_NAME" == "Noop Aura.app" ]] || {
  echo "release app bundle must be named 'Noop Aura.app'" >&2
  exit 1
}
[[ -d "$IOS_WIDGET" ]] || { echo "iOS build is missing its widget extension" >&2; exit 1; }
[[ ! -d "$APP/Watch" ]] || { echo "Aura iOS release unexpectedly contains a Watch bundle" >&2; exit 1; }

if find "$APP" -name embedded.mobileprovision -print -quit | grep -q .; then
  echo "refusing to package a provisioned Apple bundle" >&2
  exit 1
fi

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1/Info.plist"
}

verify_bundle_metadata() {
  local bundle="$1"
  local widget="$bundle/PlugIns/NOOPWidgets.appex"
  local root_name root_display root_version root_build root_id root_group
  local widget_display widget_version widget_build widget_id widget_group

  [[ "$(basename "$bundle")" == "Noop Aura.app" ]] || {
    echo "packaged app bundle name verification failed" >&2
    exit 1
  }
  [[ -d "$widget" ]] || {
    echo "packaged widget verification failed" >&2
    exit 1
  }

  root_name="$(plist_value "$bundle" CFBundleName)"
  root_display="$(plist_value "$bundle" CFBundleDisplayName)"
  root_version="$(plist_value "$bundle" CFBundleShortVersionString)"
  root_build="$(plist_value "$bundle" CFBundleVersion)"
  root_id="$(plist_value "$bundle" CFBundleIdentifier)"
  root_group="$(plist_value "$bundle" AppGroupIdentifier)"
  widget_display="$(plist_value "$widget" CFBundleDisplayName)"
  widget_version="$(plist_value "$widget" CFBundleShortVersionString)"
  widget_build="$(plist_value "$widget" CFBundleVersion)"
  widget_id="$(plist_value "$widget" CFBundleIdentifier)"
  widget_group="$(plist_value "$widget" AppGroupIdentifier)"

  [[ "$root_name" == "Noop Aura" && "$root_display" == "Noop Aura" ]] || {
    echo "app name metadata verification failed" >&2
    exit 1
  }
  [[ "$widget_display" == "Noop Aura" ]] || {
    echo "widget display-name verification failed" >&2
    exit 1
  }
  [[ "$widget_version" == "$root_version" ]] || {
    echo "widget version verification failed" >&2
    exit 1
  }
  [[ "$widget_build" == "$root_build" ]] || {
    echo "widget build-number verification failed" >&2
    exit 1
  }
  [[ "$widget_id" == "${root_id}.widgets" ]] || {
    echo "widget bundle-identity verification failed" >&2
    exit 1
  }
  [[ -n "$root_group" && "$widget_group" == "$root_group" ]] || {
    echo "app/widget App Group verification failed" >&2
    exit 1
  }

  if [[ -n "${NOOP_EXPECTED_VERSION:-}" && "$root_version" != "$NOOP_EXPECTED_VERSION" ]]; then
    echo "app version does not match the release expectation" >&2
    exit 1
  fi
  if [[ -n "${NOOP_EXPECTED_BUILD:-}" && "$root_build" != "$NOOP_EXPECTED_BUILD" ]]; then
    echo "app build number does not match the release expectation" >&2
    exit 1
  fi
  if [[ -n "${NOOP_EXPECTED_BUNDLE_ID:-}" && "$root_id" != "$NOOP_EXPECTED_BUNDLE_ID" ]]; then
    # Bundle/App Group values may be private signing-service identifiers. Never print either side.
    echo "app bundle identity does not match the release expectation" >&2
    exit 1
  fi
  if [[ -n "${NOOP_EXPECTED_APP_GROUP_ID:-}" && "$root_group" != "$NOOP_EXPECTED_APP_GROUP_ID" ]]; then
    echo "app App Group does not match the release expectation" >&2
    exit 1
  fi
}

verify_packaged_ipa() {
  local ipa="$1"
  local label="$2"
  local verify_dir="$STAGE/verify-$label"

  mkdir -p "$verify_dir"
  unzip -qq "$ipa" \
    "Payload/Noop Aura.app/Info.plist" \
    "Payload/Noop Aura.app/PlugIns/NOOPWidgets.appex/Info.plist" \
    -d "$verify_dir"
  verify_bundle_metadata "$verify_dir/Payload/Noop Aura.app"
}

verify_bundle_metadata "$APP"

if [[ "$LITE_INPUT" != "-" ]]; then
  LITE_IPA="$(absolute_path "$LITE_INPUT")"
fi
if [[ "$FULL_INPUT" != "-" ]]; then
  FULL_IPA="$(absolute_path "$FULL_INPUT")"
fi
if [[ "$LITE_INPUT" != "-" && "$FULL_INPUT" != "-" && "$LITE_IPA" == "$FULL_IPA" ]]; then
  echo "AltStore and Full IPA outputs must be different files" >&2
  exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

if [[ "$FULL_INPUT" != "-" ]]; then
  mkdir -p "$STAGE/full/Payload"
  cp -R "$APP" "$STAGE/full/Payload/"
fi

if [[ "$LITE_INPUT" != "-" ]]; then
  mkdir -p "$STAGE/lite/Payload"
  cp -R "$APP" "$STAGE/lite/Payload/"

  # Assert the widget survived staging. What the bundle contains is the promise
  # made to AltStore users, so the extension going missing has to be loud rather than shipping a
  # quietly widget-less IPA — which is the regression this packaging split just corrected.
  [[ -d "$STAGE/lite/Payload/$APP_NAME/PlugIns/NOOPWidgets.appex" ]] || {
    echo "AltStore IPA lost NOOPWidgets.appex" >&2
    exit 1
  }

  # Embed the ad-hoc capability template (App Group + HealthKit) so AltSign can discover, provision
  # and re-sign what the app and widget share (#887). The Full IPA deliberately stays unprepped for
  # people signing with their own team.
  "$(dirname "$0")/prepare-ios-sideload-app.sh" "$STAGE/lite/Payload/$APP_NAME"

  mkdir -p "$(dirname "$LITE_IPA")"
  rm -f "$LITE_IPA"
  (cd "$STAGE/lite" && zip -qry "$LITE_IPA" Payload)
  verify_packaged_ipa "$LITE_IPA" lite
  echo "Packaged AltStore IPA: $LITE_IPA ($(du -h "$LITE_IPA" | cut -f1))"
fi

if [[ "$FULL_INPUT" != "-" ]]; then
  mkdir -p "$(dirname "$FULL_IPA")"
  rm -f "$FULL_IPA"
  (cd "$STAGE/full" && zip -qry "$FULL_IPA" Payload)
  verify_packaged_ipa "$FULL_IPA" full
  echo "Packaged Full IPA:     $FULL_IPA ($(du -h "$FULL_IPA" | cut -f1))"
fi
