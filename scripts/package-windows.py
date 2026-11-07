#!/usr/bin/env python3
"""Package the exact supplied Windows executable with its offline assets."""
import argparse
import hashlib
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parent.parent
ARTWORK = (
    "ExistentialCapybara", "MeetingEmail", "AwayWorking", "QuietOfficeBilingual",
    "InboxReplyBilingual", "FishModeBilingual", "LoadingDogBilingual", "PieReserveBilingual",
    "SaveMeTheBlame", "AILooksBusy", "AIIsClient", "TestedByPrayer",
    "AITookMeeting", "MoreAgents", "AllISaidWasSure", "AIWroteBug",
    "RunOrRun", "ContextFull", "CoffeeNoFix", "RequirementsRegrow",
    "AICantSleep", "AskedAQuestion", "MyOldCode", "DidYouThough",
)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("exe", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    entries = {"StillHere.exe": args.exe, "LICENSE.txt": ROOT / "LICENSE"}
    entries.update({f"Wallpapers/{name}.png": ROOT / "Sources/StillHere/Resources" / f"{name}.png" for name in ARTWORK})
    for path in entries.values():
        if not path.is_file():
            parser.error(f"Missing required package input: {path}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(args.output, "w", compression=ZIP_DEFLATED, compresslevel=6) as archive:
        # BOM lets older Windows Notepad recognize the Chinese instructions as UTF-8.
        instructions = (ROOT / "docs/START-HERE-windows.txt").read_text(encoding="utf-8")
        archive.writestr("START-HERE.txt", instructions.encode("utf-8-sig"))
        for name, path in entries.items():
            archive.write(path, name)
    with ZipFile(args.output) as archive:
        if set(archive.namelist()) != set(entries) | {"START-HERE.txt"}:
            raise SystemExit("Unexpected package contents")
        for name, path in entries.items():
            if hashlib.sha256(archive.read(name)).digest() != hashlib.sha256(path.read_bytes()).digest():
                raise SystemExit(f"Package verification failed: {name}")
    print(f"Verified {args.output} with executable, instructions, license and {len(ARTWORK)} wallpapers")

if __name__ == "__main__":
    main()
