#!/usr/bin/env python3
"""Strip terminal bytes and machine-local paths from captured tool output.

Scripts that record logs or environment details pipe through this module, so a
record keeps its failure messages, counts and timings without carrying a developer's
home directory, a machine-local Xcode path, a physical device identifier, a signing
team or account, or bytes that only render in a terminal.

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
# MobileBuildMCP keeps per-run logs under a machine-local workspace directory named after the
# checkout and a session hash. The tool's messages are the record; where they were stored is not.
# Match before the home-path rules, which would otherwise leave the session hash and file name.
_MOBILEBUILDMCP_LOG = re.compile(
    r"(?:~|/(?:Users|home)/[^/\s]+)/Library/Developer/MobileBuildMCP/\S*")
# A device identifier names one user's hardware. devicectl and MobileBuildMCP echo the value
# passed to --device, and MobileBuildMCP also prints it as "Device: <UDID>".
_DEVICE_UDID = re.compile(r"\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{12,16}\b")
# A signing team and the Apple account behind it identify the maintainer, not the build. Match
# the account only where a signing message names it, so unrelated addresses in tool output stay.
_TEAM_ID = re.compile(r"(?i)(DEVELOPMENT_TEAM=)[A-Z0-9]{10}\b")
_SIGNING_ACCOUNT = re.compile(
    r"(?i)\b(account|apple id)\b[\s:=]*['\"]?([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})['\"]?")
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
    text = _MOBILEBUILDMCP_LOG.sub("<LOCAL_BUILD_LOG>", text)
    text = _DEVICE_UDID.sub("<DEVICE_ID>", text)
    text = _TEAM_ID.sub(r"\1<TEAM_ID>", text)
    text = _SIGNING_ACCOUNT.sub(lambda match: f"{match.group(1)} <ACCOUNT>", text)
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
