#!/usr/bin/env python3
"""Verify Mac, Windows, documentation and source assets describe the same collection."""
import ast
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parent.parent
swift = (ROOT / "Sources/StillHere/PreferencesWindow.swift").read_text(encoding="utf-8")
entries = re.findall(r'\.init\(id:\s*"([^"]+)",\s*resource:\s*"([^"]+)"', swift)
if not entries or len({key for key, _ in entries}) != len(entries):
    raise SystemExit("Mac gallery IDs are missing or duplicated")
mac = [name for _, name in entries]
module = ast.parse((ROOT / "scripts/package-windows.py").read_text(encoding="utf-8"))
assign = next((node for node in module.body if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "ARTWORK" for t in node.targets)), None)
if assign is None:
    raise SystemExit("Windows artwork list is missing")
windows = list(ast.literal_eval(assign.value))
if len(mac) != len(set(mac)) or mac != windows:
    raise SystemExit("Mac and Windows wallpaper collections differ")
resources = ROOT / "Sources/StillHere/Resources"
actual = {p.stem for p in resources.glob("*.png")}
if set(mac) != actual:
    raise SystemExit(f"Resource mismatch: missing={set(mac)-actual}; extra={actual-set(mac)}")
gallery = (ROOT / "docs/WALLPAPERS.md").read_text(encoding="utf-8")
for name in mac:
    path = resources / f"{name}.png"
    with path.open("rb") as stream:
        header = stream.read(24)
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise SystemExit(f"Invalid PNG header: {path}")
    width, height = struct.unpack(">II", header[16:24])
    if width < 1200 or height < 675 or width <= height:
        raise SystemExit(f"Unexpected wallpaper dimensions: {path} ({width}x{height})")
    if f"/Resources/{name}.png" not in gallery:
        raise SystemExit(f"Wallpaper missing from public gallery: {name}")
print(f"Verified {len(mac)} unique wallpapers across Mac, Windows, images, and public gallery")
