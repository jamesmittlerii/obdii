#!/usr/bin/env python3
"""
Single source of truth for SwiftOBD2 library version: swiftobd2-version.txt
at the repository root.

Writes the version to:
  - flutter_obdii/pubspec.yaml  -> flutter_obd2: ^X.Y.Z
  - All kotlin_obdii/**/build.gradle.kts -> com.github.jamesmittlerii:SwiftOBD2:X.Y.Z
  - obdii.xcodeproj/project.pbxproj -> minimumVersion = X.Y.Z (for SwiftOBD2)

Run from repo root:
  python3 scripts/sync_swiftobd2_version.py
"""

import re
import sys
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION_FILE = ROOT / "swiftobd2-version.txt"
PUBSPEC = ROOT / "flutter_obdii" / "pubspec.yaml"
PUBSPEC_LOCK = ROOT / "flutter_obdii" / "pubspec.lock"
PBXPROJ = ROOT / "obdii.xcodeproj" / "project.pbxproj"
RESOLVED = ROOT / "obdii.xcodeproj" / "project.xcworkspace" / "xcshareddata" / "swiftpm" / "Package.resolved"
KOTLIN_DIR = ROOT / "kotlin_obdii"

# Regex for flutter_obd2 in pubspec.yaml
FLUTTER_OBD2_RE = re.compile(
    r"(^\s*flutter_obd2:\s*[\^~]?)(\d+\.\d+\.\d+)([ \t\r]*$)",
    re.MULTILINE,
)

# Regex for SwiftOBD2 in build.gradle.kts
GRADLE_OBD2_RE = re.compile(
    r"(implementation\(\"com\.github\.jamesmittlerii:SwiftOBD2:)(\d+\.\d+\.\d+)(\"\))",
)

# Regex for SwiftOBD2 in project.pbxproj
# We need to find the specific XCRemoteSwiftPackageReference for SwiftOBD2
PBXPROJ_RE = re.compile(
    r"(XCRemoteSwiftPackageReference \"SwiftOBD2\" \*/ = \{[^{]*requirement = \{[^{]*minimumVersion = )(\d+\.\d+\.\d+)(;)",
    re.DOTALL,
)

# Regex for swiftobd2 in Package.resolved
# Targets the version string specifically within the swiftobd2 pin block
RESOLVED_RE = re.compile(
    r'({\s*"identity"\s*:\s*"swiftobd2",.*?"revision"\s*:\s*")[^"]*(".*?"version"\s*:\s*")[^"]*(")',
    re.DOTALL,
)

# Regex for flutter_obd2 in pubspec.lock
FLUTTER_LOCK_RE = re.compile(
    r'(  flutter_obd2:.*?version: ")([^"]*)(")',
    re.DOTALL,
)

def _read(path: Path) -> str:
    with path.open(encoding="utf-8", newline="") as f:
        return f.read()

def _write(path: Path, text: str) -> None:
    # Only write if the content changed to avoid triggering IDE auto-syncs unnecessarily.
    if path.is_file() and _read(path) == text:
        return
    with path.open("w", encoding="utf-8", newline="") as f:
        f.write(text)

def read_version() -> str:
    if not VERSION_FILE.is_file():
        print(f"error: missing {VERSION_FILE}", file=sys.stderr)
        sys.exit(1)
    version = None
    for line in _read(VERSION_FILE).splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        if re.fullmatch(r"\d+\.\d+\.\d+", s):
            version = s
            break
    if version is None:
        print(f"error: {VERSION_FILE} must contain a MAJOR.MINOR.PATCH version", file=sys.stderr)
        sys.exit(1)
    return version

def fetch_git_hash(version: str) -> str:
    print(f"Fetching git hash for SwiftOBD2 version {version}...")
    url = "https://github.com/jamesmittlerii/SwiftOBD2"
    cmd = ["git", "ls-remote", "--tags", url, version]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        if not result.stdout:
            print(f"error: tag {version} not found at {url}", file=sys.stderr)
            sys.exit(1)
        # result.stdout is "hash\trefs/tags/version"
        git_hash = result.stdout.split()[0]
        print(f"Found hash: {git_hash}")
        return git_hash
    except subprocess.CalledProcessError as e:
        print(f"error: failed to fetch git hash: {e.stderr}", file=sys.stderr)
        sys.exit(1)

def sync_pubspec(version: str):
    text = _read(PUBSPEC)
    if not FLUTTER_OBD2_RE.search(text):
        print(f"warning: could not find flutter_obd2 in {PUBSPEC}")
    else:
        updated = FLUTTER_OBD2_RE.sub(rf"\g<1>{version}\3", text)
        _write(PUBSPEC, updated)
        print(f"synced {PUBSPEC}")

    # Handle local directory override for Flutter if it exists (mirroring Kotlin logic)
    local_flutter = ROOT.parent / "SwiftOBD2" / "flutterobd2"
    overrides_file = PUBSPEC.parent / "pubspec_overrides.yaml"
    if local_flutter.is_dir():
        # Using relative path from flutter_obdii to SwiftOBD2/flutterobd2
        rel_path = "../../SwiftOBD2/flutterobd2"
        overrides_content = f"dependency_overrides:\n  flutter_obd2:\n    path: \"{rel_path}\"\n"
        _write(overrides_file, overrides_content)
        print(f"ensured local override in {overrides_file}")
    elif overrides_file.is_file():
        # If the local dir is gone, we should probably remove the override
        # but only if it's specifically for flutter_obd2
        content = _read(overrides_file)
        if "flutter_obd2:" in content and "path:" in content:
            print(f"info: local directory {local_flutter} not found, you may want to remove {overrides_file}")

def sync_gradle(version: str):
    for path in KOTLIN_DIR.rglob("build.gradle.kts"):
        text = _read(path)
        if GRADLE_OBD2_RE.search(text):
            updated = GRADLE_OBD2_RE.sub(rf"\g<1>{version}\3", text)
            _write(path, updated)
            print(f"synced {path}")

def sync_pbxproj(version: str):
    text = _read(PBXPROJ)
    if not PBXPROJ_RE.search(text):
        print(f"warning: could not find SwiftOBD2 minimumVersion in {PBXPROJ}")
        return
    updated = PBXPROJ_RE.sub(rf"\g<1>{version}\3", text)
    _write(PBXPROJ, updated)
    print(f"synced {PBXPROJ}")

def sync_resolved(version: str, git_hash: str):
    if not RESOLVED.is_file():
        return
    text = _read(RESOLVED)
    if not RESOLVED_RE.search(text):
        print(f"warning: could not find swiftobd2 version in {RESOLVED}")
        return
    # Replace both revision and version
    updated = RESOLVED_RE.sub(rf"\g<1>{git_hash}\g<2>{version}\3", text)
    _write(RESOLVED, updated)
    print(f"synced {RESOLVED}")

def sync_flutter_lock(version: str):
    if not PUBSPEC_LOCK.is_file():
        return
    text = _read(PUBSPEC_LOCK)
    if not FLUTTER_LOCK_RE.search(text):
        print(f"warning: could not find flutter_obd2 block in {PUBSPEC_LOCK}")
        return
    updated = FLUTTER_LOCK_RE.sub(rf"\g<1>{version}\3", text)
    _write(PUBSPEC_LOCK, updated)
    print(f"synced {PUBSPEC_LOCK}")

def main():
    version = read_version()
    git_hash = fetch_git_hash(version)

    print(f"Syncing SwiftOBD2 version {version}...")
    sync_pubspec(version)
    sync_gradle(version)
    sync_pbxproj(version)
    sync_resolved(version, git_hash)
    sync_flutter_lock(version)
    print("Done.")

if __name__ == "__main__":
    main()
