#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
export CLANG_MODULE_CACHE_PATH="$project_root/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_root/.build/clang-cache"

if [[ "${1:-}" == "--universal" ]]; then
  build_arches=(arm64 x86_64)
else
  build_arches=("$(uname -m)")
fi

for architecture in "${build_arches[@]}"; do
  swift build --configuration release --arch "$architecture" --disable-sandbox \
    --cache-path .build/cache --config-path .build/config --security-path .build/security
done

app_bundle="$project_root/dist/StillHere.app"
mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources" "$app_bundle/Contents/Helpers"
binaries=()
clang_arches=()
for architecture in "${build_arches[@]}"; do
  binaries+=(".build/${architecture}-apple-macosx/release/StillHere")
  clang_arches+=(-arch "$architecture")
done
if [[ "${#binaries[@]}" -gt 1 ]]; then
  lipo -create "${binaries[@]}" -output "$app_bundle/Contents/MacOS/StillHere"
else
  cp "${binaries[0]}" "$app_bundle/Contents/MacOS/StillHere"
fi
cp Sources/StillHere/Resources/*.png "$app_bundle/Contents/Resources/"

clang -fobjc-arc -mmacosx-version-min=14.0 -Wno-deprecated-declarations "${clang_arches[@]}" \
  -framework AppKit -framework ScreenCaptureKit -framework CoreGraphics \
  research/capture_probe.m -o "$app_bundle/Contents/Helpers/capture_probe"

swift -module-cache-path "$CLANG_MODULE_CACHE_PATH" scripts/make-icon.swift "$project_root/.build/icon.png"
iconset="$project_root/.build/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" .build/icon.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" .build/icon.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app_bundle/Contents/Resources/AppIcon.icns"

cat > "$app_bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>dev.0xzohar.stillhere</string>
  <key>CFBundleName</key><string>StillHere</string>
  <key>CFBundleDisplayName</key><string>在场 · StillHere</string>
  <key>CFBundleExecutable</key><string>StillHere</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.3.0</string>
  <key>CFBundleVersion</key><string>3</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>Copyright 2026 Zohar Huang</string>
</dict></plist>
PLIST

codesign --force --sign - "$app_bundle/Contents/Helpers/capture_probe"
codesign --force --sign - "$app_bundle"
codesign --verify --deep --strict "$app_bundle"
printf 'Built %s\n' "$app_bundle"
