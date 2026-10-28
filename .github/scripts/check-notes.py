#!/usr/bin/env python3
"""Read-only filesystem/text precheck; Towncrier owns fragment parsing/rendering."""
from pathlib import Path
import stat
import sys
import tomllib


def regular_text(path):
    if not stat.S_ISREG(path.lstat().st_mode):
        raise ValueError(f"{path}: expected a regular file, not a symlink or special file")
    text = path.read_text(encoding="utf-8", errors="strict")
    if not text.strip():
        raise ValueError(f"{path}: expected nonempty UTF-8 text")
    return text


def validate(root):
    # Reject ancestor links before examining anything below them.
    for path in (root, root / "map", root / "changelog", root / "map/changelog"):
        if not stat.S_ISDIR(path.lstat().st_mode):
            raise ValueError(f"{path}: expected a real directory, not a symlink")

    config = tomllib.loads(regular_text(root / "towncrier.toml"))["tool"]["towncrier"]
    # Keep the checked paths identical to Towncrier's inputs/outputs. There is no
    # custom template, section traversal, package import, or alternate output.
    expected = {
        "directory": "changelog", "filename": "CHANGELOG.md", "package": "",
        "template": "towncrier:default.md", "ignore": [],
    }
    if any(config.get(key) != value for key, value in expected.items()) or "section" in config:
        raise ValueError("Towncrier must keep the reviewed flat package layout and strict ignore list")

    count = 0
    for package in (root, root / "map"):
        regular_text(package / "CHANGELOG.md")
        for path in sorted((package / "changelog").iterdir()):
            regular_text(path)  # Includes README; no ignored symlink/nested-file escape.
            count += 1
    return count


if __name__ == "__main__":
    try:
        count = validate(Path.cwd())
    except (OSError, UnicodeError, ValueError, KeyError, TypeError) as error:
        sys.exit(f"Release-note precheck failed: {error}")
    print(f"Release-note filesystem/text precheck passed ({count} files, core and Map).")
