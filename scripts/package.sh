#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
test -d dist/StillHere.app
ditto -c -k --sequesterRsrc --keepParent dist/StillHere.app dist/StillHere-0.1.0-mac.zip
staging="$project_root/.build/dmg-stage"
mkdir -p "$staging"
ditto dist/StillHere.app "$staging/StillHere.app"
if [[ ! -e "$staging/Applications" ]]; then ln -s /Applications "$staging/Applications"; fi
hdiutil create -volname "StillHere" -srcfolder "$staging" -ov -format UDZO dist/StillHere-0.1.0-mac.dmg
shasum -a 256 dist/StillHere-0.1.0-mac.zip dist/StillHere-0.1.0-mac.dmg > dist/SHA256SUMS.txt
