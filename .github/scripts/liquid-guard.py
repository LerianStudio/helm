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

    liquid-guard.py            check every published .md tracked by git
    liquid-guard.py --fix F..  wrap each given file the way the helm-upgrade-doc
                               generator in shared-workflows-public does

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


def main(args):
    if args[:1] == ["--fix"]:
        for path in args[1:]:
            fix(path)
        return 0

    files = subprocess.run(["git", "ls-files", "*.md"], check=True, capture_output=True, text=True).stdout.split()
    failed = 0
    for path in filter(published, files):
        with open(path, encoding="utf-8") as f:
            found = offence(f.read())
        if found:
            line, reason = found
            print(f"::error file={path},line={line}::{reason}. Wrap the file: python3 .github/scripts/liquid-guard.py --fix {path}")
            failed += 1

    print(f"{failed} markdown file(s) would break or blank out on charts.lerian.studio" if failed else "All published markdown is Liquid-safe")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
