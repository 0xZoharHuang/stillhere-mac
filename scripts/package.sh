#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
test -d dist/StillHere.app
ditto -c -k --sequesterRsrc --keepParent dist/StillHere.app dist/StillHere-0.2.0-mac.zip
staging="$project_root/.build/dmg-stage"
mkdir -p "$staging"
ditto dist/StillHere.app "$staging/StillHere.app"
if [[ ! -e "$staging/Applications" ]]; then ln -s /Applications "$staging/Applications"; fi
error_log="$project_root/.build/hdiutil-create.log"
for attempt in 1 2 3 4 5; do
  if hdiutil create -volname "StillHere" -srcfolder "$staging" -ov -format UDZO \
      dist/StillHere-0.2.0-mac.dmg 2>"$error_log"; then
    break
  fi
  error_text="$(<"$error_log")"
  printf '%s\n' "$error_text" >&2
  if [[ "$error_text" != *"Resource busy"* ]] || [[ "$attempt" -eq 5 ]]; then
    exit 1
  fi
  printf 'DMG creation is busy; retrying (%s/5).\n' "$attempt" >&2
  sleep "$((attempt * 2))"
done
(
  cd dist
  shasum -a 256 StillHere-0.2.0-mac.zip StillHere-0.2.0-mac.dmg > SHA256SUMS.txt
)
