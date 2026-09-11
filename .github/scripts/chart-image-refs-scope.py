#!/usr/bin/env python3
"""Resolve which charts the image-refs gate should verify for this pull request.

Reads the changed-file list from /tmp/changed.txt and writes `charts` (a JSON
array) and `has-charts` to $GITHUB_OUTPUT.

Three things decide the scope:

  charts/<name>/**                    that chart
  helm-render-values/<name>.yaml      that chart — it is what the gate renders with
  a changed library chart             the charts that consume it from the worktree

The library rule is the one worth explaining. A library chart has no images of its
own, so verifying it directly is meaningless; what matters is the charts whose
render it changes. But only the ones depending on it through `file://` are
affected: a chart pinning `oci://ghcr.io/lerianstudio` gets the published version
regardless of what the working tree says, and will not see the change until someone
bumps its dependency — which edits its Chart.yaml and puts it in scope anyway.

A change to the workflow itself deliberately scopes to nothing. It is a required
check, so that means a green that verified no chart; the warning below exists so
that green is not silent.
"""

import json
import os
import re
import sys
from pathlib import Path

import yaml

CHARTS = Path("charts")
RENDER_VALUES = re.compile(r"^\.github/configs/helm-render-values/(.+)\.ya?ml$")
CHART_PATH = re.compile(r"^charts/([^/]+)/")
SELF = ".github/workflows/chart-image-refs.yml"


def load(path):
    try:
        return yaml.safe_load(path.read_text()) or {}
    except Exception:
        return {}


def is_library(name):
    return str(load(CHARTS / name / "Chart.yaml").get("type", "")).lower() == "library"


def local_dependents(library_dir):
    """Charts consuming `library_dir` from the working tree, not from a registry."""
    library_name = load(CHARTS / library_dir / "Chart.yaml").get("name")
    if not library_name:
        return set()
    out = set()
    for chart_yaml in sorted(CHARTS.glob("*/Chart.yaml")):
        for dep in load(chart_yaml).get("dependencies") or []:
            if dep.get("name") != library_name:
                continue
            if str(dep.get("repository", "")).startswith("file://"):
                out.add(chart_yaml.parent.name)
    return out


def main():
    changed = [
        line.strip()
        for line in Path("/tmp/changed.txt").read_text().splitlines()
        if line.strip()
    ]

    notices, scope = [], set()

    if SELF in changed:
        # Explicit product decision: editing the gate does not re-verify the charts.
        # Said out loud, because the check still reports success.
        print(
            "::warning::This pull request changes the image-refs gate itself. "
            "No chart is verified by it — review the logic by hand."
        )

    for path in changed:
        m = CHART_PATH.match(path)
        if m:
            scope.add(m.group(1))
        m = RENDER_VALUES.match(path)
        if m:
            scope.add(m.group(1))

    # A library in scope is not verifiable itself; swap it for what it affects.
    for name in sorted(scope):
        if (CHARTS / name / "Chart.yaml").exists() and is_library(name):
            deps = local_dependents(name)
            notices.append(
                f"{name} is a library chart: verifying its {len(deps)} local "
                f"dependent(s) instead" + (f" ({', '.join(sorted(deps))})" if deps else "")
            )
            scope.update(deps)

    final = sorted(
        name
        for name in scope
        if (CHARTS / name / "Chart.yaml").exists() and not is_library(name)
    )

    for n in notices:
        print(f"::notice::{n}")

    out = Path(os.environ["GITHUB_OUTPUT"]).open("a") if "GITHUB_OUTPUT" in os.environ else sys.stdout
    if not final:
        print("::notice::No installable chart in scope — nothing to verify")
        out.write("charts=[]\nhas-charts=false\n")
    else:
        print(f"::notice::Charts in scope: {' '.join(final)}")
        out.write(f"charts={json.dumps(final)}\nhas-charts=true\n")


if __name__ == "__main__":
    main()
