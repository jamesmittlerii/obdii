#!/usr/bin/env python3

import argparse
import os
import re
import subprocess
from pathlib import Path
from xml.sax.saxutils import escape


LINE_RE = re.compile(r"^\s*(\d+):\s*([0-9]+(?:\.[0-9]+)?)")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert xccov coverage in an .xcresult bundle to Sonar generic coverage XML."
    )
    parser.add_argument("result_bundle", help="Path to the .xcresult bundle")
    parser.add_argument("output", help="Path to the output Sonar generic coverage XML")
    parser.add_argument(
        "--workspace",
        default=os.getcwd(),
        help="Repository root used to relativize source file paths",
    )
    parser.add_argument(
        "--exclude-prefix",
        action="append",
        default=["test/"],
        help="Relative path prefixes to exclude from generated coverage",
    )
    return parser.parse_args()


def run(*args: str) -> str:
    return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL)


def iter_file_paths(result_bundle: str) -> list[str]:
    output = run("xcrun", "xccov", "view", "--archive", "--file-list", result_bundle)
    return [line.strip() for line in output.splitlines() if line.strip()]


def iter_line_coverage(result_bundle: str, file_path: str) -> list[tuple[int, bool]]:
    output = run("xcrun", "xccov", "view", "--archive", "--file", file_path, result_bundle)
    covered_lines: list[tuple[int, bool]] = []
    for line in output.splitlines():
        match = LINE_RE.match(line)
        if not match:
            continue
        line_number = int(match.group(1))
        covered = float(match.group(2)) > 0
        covered_lines.append((line_number, covered))
    return covered_lines


def should_include(relative_path: str, exclude_prefixes: list[str]) -> bool:
    if not relative_path.endswith(".swift"):
        return False
    return not any(relative_path.startswith(prefix) for prefix in exclude_prefixes)


def main() -> None:
    args = parse_args()
    workspace = Path(args.workspace).resolve()
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with output_path.open("w", encoding="utf-8") as handle:
        handle.write('<coverage version="1">')
        for absolute_path in iter_file_paths(args.result_bundle):
            absolute = Path(absolute_path).resolve()
            try:
                relative = absolute.relative_to(workspace).as_posix()
            except ValueError:
                continue
            if not should_include(relative, args.exclude_prefix):
                continue
            lines = iter_line_coverage(args.result_bundle, absolute_path)
            if not lines:
                continue
            handle.write(f'<file path="{escape(relative)}">')
            for line_number, covered in lines:
                covered_attr = "true" if covered else "false"
                handle.write(
                    f'<lineToCover lineNumber="{line_number}" covered="{covered_attr}"/>'
                )
            handle.write("</file>")
        handle.write("</coverage>")


if __name__ == "__main__":
    main()
