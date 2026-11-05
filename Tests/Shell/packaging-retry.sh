#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/../.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/stillhere-package-test.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/scripts" "$fixture/dist/StillHere.app/Contents" "$fixture/bin"
cp "$project_root/scripts/package.sh" "$fixture/scripts/package.sh"
printf 'controlled packaging fixture\n' > "$fixture/dist/StillHere.app/Contents/fixture.txt"
cat > "$fixture/bin/hdiutil" <<'FAKE'
#!/bin/bash
set -euo pipefail
count=0
if [[ -f "$STILLHERE_TEST_COUNT" ]]; then count="$(<"$STILLHERE_TEST_COUNT")"; fi
count=$((count + 1))
printf '%s' "$count" > "$STILLHERE_TEST_COUNT"
if [[ "${STILLHERE_TEST_ERROR:-busy}" == "other" ]]; then
  printf 'hdiutil: create failed - unrelated failure\n' >&2
  exit 1
fi
if [[ "$count" -lt 3 ]]; then
  printf 'hdiutil: create failed - Resource busy\n' >&2
  exit 1
fi
printf 'controlled fake disk image\n' > "${!#}"
FAKE
chmod +x "$fixture/bin/hdiutil"
export STILLHERE_TEST_COUNT="$fixture/count"
PATH="$fixture/bin:$PATH" bash "$fixture/scripts/package.sh"
test "$(<"$STILLHERE_TEST_COUNT")" -eq 3
(
  cd "$fixture/dist"
  shasum -a 256 -c SHA256SUMS.txt
)
printf '0' > "$STILLHERE_TEST_COUNT"
if STILLHERE_TEST_ERROR=other PATH="$fixture/bin:$PATH" bash "$fixture/scripts/package.sh"; then
  printf 'An unrelated error was incorrectly ignored.\n' >&2
  exit 1
fi
test "$(<"$STILLHERE_TEST_COUNT")" -eq 1
printf 'Packaging retry and fail-fast checks passed.\n'
