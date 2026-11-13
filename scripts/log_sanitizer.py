#!/usr/bin/env python3
"""Strip terminal bytes and machine-local paths from captured tool output.

Scripts that record logs or environment details pipe through this module, so a
record keeps its failure messages, counts and timings without carrying a developer's
home directory, a machine-local Xcode path, or bytes that only render in a terminal.

Manual capture uses the same filter:

    swift test 2>&1 | python3 scripts/log_sanitizer.py > checks/suite.log
"""

import argparse
import pathlib
import re
import subprocess
import sys

# Colour, cursor and OSC 8 hyperlink sequences that tools emit when they believe
# they are attached to a terminal.
_ANSI_ESCAPE = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)")
# An absolute home path names the developer's account and private checkout layout.
_HOME_PATH = re.compile(r"/(?:Users|home)/[^/\s]+/")
# A capture from another worktree keeps its directory names, so trim it to the first path we
# recognize as repository-relative. Everything before that is private checkout layout.
_HOME_CHECKOUT_PREFIX = re.compile(
    r"/(?:Users|home)/[^/\s]+/\S*?(?=(?:Sources|Tests|Benchmarks|Demo|scripts|AI-docs)/)")
# Xcode installs are machine-local; the SDK path after the developer directory is the evidence.
_XCODE_DEVELOPER_DIR = re.compile(r"/Applications/Xcode[^/\s]*/Contents/Developer/")
# Swift Testing emits SF Symbols private-use glyphs on macOS. Event.Symbol.swift pairs each
# with a plain Unicode fallback for terminals without that font; use those so logs stay readable.
_SWIFT_TESTING_GLYPHS = {
    "\U001007c8": "\u25c7",  # .default -> WHITE DIAMOND
    "\U0010105b": "\u2714",  # .pass -> HEAVY CHECK MARK
    "\U00100884": "\u2718",  # .fail -> HEAVY BALLOT X
    "\U00100135": "\u21b3",  # .details -> DOWNWARDS ARROW WITH TIP RIGHTWARDS
}
# swift build pads its progress counters with thin spaces, which break word searches.
_THIN_SPACE = "\u2009"


def sanitize_log_text(text, root=None):
    """Return captured `text` with terminal bytes and machine-local paths removed.

    `root` is a checkout whose paths become repository-relative. Failure messages, counts
    and timings are preserved, as is any character whose meaning this module cannot judge.
    """
    text = text.replace("\r\n", "\n").replace("\r", "")
    text = _ANSI_ESCAPE.sub("", text)
    if root is not None:
        prefix = str(pathlib.Path(root).resolve()).rstrip("/") + "/"
        text = text.replace(prefix, "")
    text = _HOME_CHECKOUT_PREFIX.sub("<HOME>/", text)
    text = _HOME_PATH.sub("<HOME>/", text)
    text = _XCODE_DEVELOPER_DIR.sub("<DEVELOPER_DIR>/", text)
    for glyph, fallback in _SWIFT_TESTING_GLYPHS.items():
        text = text.replace(glyph, fallback)
    text = text.replace(_THIN_SPACE, " ")
    # Quoted blank source lines keep only the compiler gutter padding.
    return "\n".join(line.rstrip() for line in text.split("\n"))


def repository_root():
    """Return the current checkout root, or None outside a Git repository."""
    try:
        root = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"], text=True, stderr=subprocess.DEVNULL).strip()
    except (OSError, subprocess.CalledProcessError):
        return None
    return pathlib.Path(root) if root else None


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("paths", nargs="*", type=pathlib.Path,
                        help="captured files to sanitize; omit to filter stdin")
    parser.add_argument("--root", type=pathlib.Path, default=None,
                        help="checkout whose paths become repository-relative (default: this repository)")
    args = parser.parse_args(argv)
    root = args.root or repository_root()

    sources = (path.read_text(errors="replace") for path in args.paths) if args.paths \
        else (sys.stdin.read(),)
    for text in sources:
        sys.stdout.write(sanitize_log_text(text, root=root))
    return 0


if __name__ == "__main__":
    sys.exit(main())
