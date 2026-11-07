#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
app="$root/dist/StillHere.app"
out="$root/dist/StillHere-0.3.0-mac-ready.dmg"
test -d "$app"
codesign --verify --deep --strict "$app"
stage="$(mktemp -d "${TMPDIR:-/tmp}/stillhere-ready.XXXXXX")"
error_log="${stage}.log"
trap 'rm -rf "$stage"; rm -f "$error_log"' EXIT
ditto "$app" "$stage/StillHere.app"
cp docs/START-HERE-mac.txt "$stage/START-HERE.txt"
cp LICENSE "$stage/LICENSE.txt"
ln -s /Applications "$stage/Applications"
for attempt in 1 2 3 4 5; do
  if hdiutil create -volname "StillHere" -srcfolder "$stage" -ov -format UDZO "$out" 2>"$error_log"; then
    printf 'Created %s\n' "$out"
    exit 0
  fi
  error_text="$(<"$error_log")"
  printf '%s\n' "$error_text" >&2
  if [[ "$error_text" != *"Resource busy"* || "$attempt" -eq 5 ]]; then exit 1; fi
  sleep "$((attempt * 2))"
done
