#!/usr/bin/env python3
"""
Single source of truth for marketing semver (MAJOR.MINOR.PATCH): release-version.txt
at the repository root (first non-comment line).

Writes the same triplet to:
  - flutter_obdii/pubspec.yaml  -> version: X.Y.Z+<build>  (build preserved from current pubspec)
  - kotlin_obdii/androidApp/build.gradle.kts -> versionName
  - obdii.xcodeproj/project.pbxproj -> MARKETING_VERSION only for com.rheosoft.obdii

Run from repo root:
  python3 scripts/sync_release_version.py
  python3 scripts/sync_release_version.py --bump-release-patch   # increment patch in release-version.txt, then sync

Exit 1 if files are missing, malformed, or pbxproj does not match expected layout.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RELEASE_FILE = ROOT / "release-version.txt"
PUBSPEC = ROOT / "flutter_obdii" / "pubspec.yaml"
GRADLE = ROOT / "kotlin_obdii" / "androidApp" / "build.gradle.kts"
PBXPROJ = ROOT / "obdii.xcodeproj" / "project.pbxproj"

VERSION_LINE = re.compile(
    # Allow \r before $ so pubspec matches on Windows (CRLF) checkouts.
    r"^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)[ \t\r]*$",
    re.MULTILINE,
)
MARKETING_OBDII = re.compile(
    r"(MARKETING_VERSION = )\d+\.\d+\.\d+(;\s*\n\s*PRODUCT_BUNDLE_IDENTIFIER = com\.rheosoft\.obdii;)",
    re.MULTILINE,
)
VERSION_NAME = re.compile(
    r"(^\s*versionName\s*=\s*\")(\d+\.\d+\.\d+)(\"[ \t\r]*$)",
    re.MULTILINE,
)


def _read(path: Path) -> str:
    # Preserve newlines (avoid CRLF -> LF rewrites on Windows).
    with path.open(encoding="utf-8", newline="") as f:
        return f.read()


def _write(path: Path, text: str) -> None:
    with path.open("w", encoding="utf-8", newline="") as f:
        f.write(text)


def read_release_version() -> str:
    if not RELEASE_FILE.is_file():
        print(f"error: missing {RELEASE_FILE}", file=sys.stderr)
        sys.exit(1)
    marketing = None
    for line in _read(RELEASE_FILE).splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        if re.fullmatch(r"\d+\.\d+\.\d+", s):
            marketing = s
            break
    if marketing is None:
        print(
            f"error: {RELEASE_FILE} must contain a line MAJOR.MINOR.PATCH (digits only, optional # comments)",
            file=sys.stderr,
        )
        sys.exit(1)
    return marketing


def bump_release_patch_file() -> str:
    """Increment MAJOR.MINOR.PATCH -> MAJOR.MINOR.(PATCH+1) on the first semver line; preserve comments and layout."""
    raw = _read(RELEASE_FILE)
    sep = "\r\n" if "\r\n" in raw else "\n"
    lines = raw.splitlines()
    bumped_to: str | None = None
    new_lines: list[str] = []
    for line in lines:
        s = line.strip()
        if not s or s.startswith("#"):
            new_lines.append(line)
            continue
        if bumped_to is None and re.fullmatch(r"\d+\.\d+\.\d+", s):
            m = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)", s)
            assert m is not None
            maj, mino, pat = map(int, m.groups())
            bumped_to = f"{maj}.{mino}.{pat + 1}"
            prefix = line[: len(line) - len(line.lstrip())]
            new_lines.append(prefix + bumped_to)
            continue
        new_lines.append(line)
    if bumped_to is None:
        print(
            f"error: no MAJOR.MINOR.PATCH line to bump in {RELEASE_FILE}",
            file=sys.stderr,
        )
        sys.exit(1)
    out = sep.join(new_lines)
    if raw.endswith(sep) or (sep == "\r\n" and raw.endswith("\n")):
        if not out.endswith(sep):
            out += sep
    _write(RELEASE_FILE, out)
    return bumped_to


def sync_pubspec(marketing: str) -> str:
    text = _read(PUBSPEC)
    m = VERSION_LINE.search(text)
    if not m:
        print(f"error: could not parse version line in {PUBSPEC}", file=sys.stderr)
        sys.exit(1)
    build = m.group(4)
    new_line = f"version: {marketing}+{build}"
    updated = VERSION_LINE.sub(new_line, text, count=1)
    _write(PUBSPEC, updated)
    return updated


def sync_gradle(marketing: str) -> str:
    text = _read(GRADLE)
    if not VERSION_NAME.search(text):
        print(f"error: could not find versionName in {GRADLE}", file=sys.stderr)
        sys.exit(1)
    updated = VERSION_NAME.sub(rf"\g<1>{marketing}\3", text, count=1)
    _write(GRADLE, updated)
    return updated


def sync_pbxproj(marketing: str) -> str:
    text = _read(PBXPROJ)
    updated, n = MARKETING_OBDII.subn(rf"\g<1>{marketing}\2", text)
    if n != 2:
        print(
            f"error: expected 2 obdii MARKETING_VERSION blocks (Debug+Release), replaced {n} in {PBXPROJ}",
            file=sys.stderr,
        )
        sys.exit(1)
    _write(PBXPROJ, updated)
    return updated


def main() -> None:
    args = [a for a in sys.argv[1:] if a]
    bump = "--bump-release-patch" in args
    extra = [a for a in args if a != "--bump-release-patch"]
    if extra:
        print(f"error: unknown arguments: {extra}", file=sys.stderr)
        sys.exit(2)
    if bump:
        bumped = bump_release_patch_file()
        print(f"bumped {RELEASE_FILE} to {bumped}")
    marketing = read_release_version()
    sync_pubspec(marketing)
    sync_gradle(marketing)
    sync_pbxproj(marketing)
    print(f"synced marketing version {marketing} -> pubspec, kotlin androidApp, obdii.xcodeproj")


if __name__ == "__main__":
    main()
