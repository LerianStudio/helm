#!/usr/bin/env python3
"""Keep Helm template syntax in markdown away from Liquid.

charts.lerian.studio is built by GitHub Pages (Jekyll 3.10), which runs Liquid over
every .md it publishes. A Helm snippet outside a raw block either breaks the whole
site build (an unterminated `{{`), warns, or — worst — parses as a valid Liquid
variable such as `{{ .Values.foo }}` and renders as nothing, with no warning at all.
So the build log is no signal; the rule has to be checked on the source.

The rule: in every markdown file Jekyll publishes, `{{` and `{%` may only appear
inside a `{% raw %}` ... `{% endraw %}` block. Liquid's raw does not nest — the first
endraw closes it — and this check reads the file the same way.

    liquid-guard.py                      check every published .md tracked by git
    liquid-guard.py --changed-since REF  check only the published .md files added,
                                         modified or renamed since REF (REF...HEAD)
    liquid-guard.py --fix F..            wrap each given file the way the
                                         helm-upgrade-doc generator in
                                         shared-workflows-public does

Why two scopes: Pages publishes main only. A pull request into main gets the full
scan, because whatever main holds is what the site builds. A pull request into any
other branch (a maintenance/<chart>-<X.Y>.x line) gets --changed-since its base:
those branches are never published, and they are seeded by restoring charts/<chart>/
from an old chart tag that predates the raw-wrapping on main. A full scan there fails
every pull request on upgrade guides it inherited and never touched — LerianStudio/helm#3093
failed on three UPGRADE docs outside its diff. The changed-files scan still stops a
pull request from adding new unwrapped Liquid, so main stays clean when the line's
docs are later brought back.

Exits 1 when a file breaks the rule, with a GitHub annotation on the first offending
line of each file.
"""

import re
import subprocess
import sys

RAW_OPEN = re.compile(r"\{%-?\s*raw\s*-?%\}")
RAW_CLOSE = re.compile(r"\{%-?\s*endraw\s*-?%\}")
LIQUID = re.compile(r"\{\{|\{%")

# The generator's wrapper: markers inside HTML comments, so Liquid honours them and
# GitHub's markdown view hides them.
MARKER_LINE = re.compile(r"^[ \t]*(<!--[ \t]*)?\{%-?[ \t]*(end)?raw[ \t]*-?%\}([ \t]*-->)?[ \t]*\n?", re.M)
WRAP_OPEN = "<!-- {% raw %} -->\n"
WRAP_CLOSE = "\n<!-- {% endraw %} -->\n"


def published(path):
    # Jekyll skips any path segment starting with `.` or `_` unless configured otherwise.
    return not any(part.startswith((".", "_")) for part in path.split("/"))


def offence(text):
    """Return (line, reason) for the first Liquid token outside a raw block, or None."""
    pos = 0
    while True:
        opened = RAW_OPEN.search(text, pos)
        stop = opened.start() if opened else len(text)
        stray = LIQUID.search(text, pos, stop)
        if stray:
            return text.count("\n", 0, stray.start()) + 1, "Liquid syntax outside a raw block"
        if not opened:
            return None
        closed = RAW_CLOSE.search(text, opened.end())
        if not closed:
            return text.count("\n", 0, opened.start()) + 1, "raw block is never closed"
        pos = closed.end()


def fix(path):
    with open(path, encoding="utf-8") as f:
        src = f.read()
    body = RAW_OPEN.sub("", RAW_CLOSE.sub("", MARKER_LINE.sub("", src)))
    if LIQUID.search(body):
        body = WRAP_OPEN + body.rstrip("\n") + WRAP_CLOSE
    if body != src:
        with open(path, "w", encoding="utf-8") as f:
            f.write(body)
        print(f"wrapped {path}")


def git_paths(*args):
    out = subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout
    return [p for p in out.split("\0") if p]


def main(args):
    if args[:1] == ["--fix"]:
        for path in args[1:]:
            fix(path)
        return 0

    if args[:1] == ["--changed-since"]:
        if len(args) != 2 or not args[1]:
            print("usage: liquid-guard.py --changed-since REF", file=sys.stderr)
            return 2
        base = args[1]
        # Deleted files are left out: there is nothing left to publish.
        files = git_paths("diff", "-z", "--name-only", "--diff-filter=d", f"{base}...HEAD", "--", "*.md")
        mode = f"changed-files mode (published .md changed since {base})"
    elif not args:
        files = git_paths("ls-files", "-z", "--", "*.md")
        mode = "full mode (every published .md tracked by git)"
    else:
        print(f"unknown arguments: {' '.join(args)}", file=sys.stderr)
        return 2

    files = list(filter(published, files))
    print(f"Markdown Liquid Guard: {mode}, {len(files)} file(s) to check")
    failed = 0
    for path in files:
        with open(path, encoding="utf-8") as f:
            found = offence(f.read())
        if found:
            line, reason = found
            print(f"::error file={path},line={line}::{reason}. Wrap the file: python3 .github/scripts/liquid-guard.py --fix {path}")
            failed += 1

    if failed:
        print(f"{failed} of {len(files)} markdown file(s) would break or blank out on charts.lerian.studio")
    elif not files:
        print("No published markdown to check: 0 files scanned")
    else:
        print(f"All {len(files)} checked markdown file(s) are Liquid-safe")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
