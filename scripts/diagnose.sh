#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
mkdir -p .build
clang -fobjc-arc -mmacosx-version-min=14.0 -Wno-deprecated-declarations \
  -framework AppKit -framework ScreenCaptureKit -framework CoreGraphics \
  research/capture_probe.m -o .build/capture_probe
exec .build/capture_probe "${1:-$project_root/verification/private/capture-probe}"
