#!/usr/bin/env python3
"""Resolve which charts a pull request touches.

Reads the changed-file list from /tmp/changed.txt — which the caller fills from the
pull request's own file list, not from a local diff — and writes `charts` (a JSON
array) and `has-charts` to $GITHUB_OUTPUT.

The rule is deliberately narrow: a pull request is verified against the charts it
changed, never against the repository. Three things put a chart in scope:

  charts/<name>/**                     that chart
  helm-render-values/<name>.yaml       that chart — it is what the chart renders with
  helm-install-values/<name>.yaml      likewise

A changed library chart is the one indirection. It has no images and cannot be
installed, so it is replaced by the charts that consume it from the working tree —
and only those. A chart pinning `oci://ghcr.io/lerianstudio` receives the published
library whatever the working tree says, and will not see the change until someone
bumps its dependency, which edits its Chart.yaml and puts it in scope by the
ordinary rule.

Set SELF_PATH to a workflow file to have a change to it warn rather than widen: the
gate says out loud that it verified nothing instead of sweeping every chart.
"""

import json
import os
import re
import sys
from pathlib import Path

import yaml

CHARTS = Path("charts")
VALUES = re.compile(r"^\.github/configs/helm-(?:render|install)-values/(.+)\.ya?ml$")
CHART_PATH = re.compile(r"^charts/([^/]+)/")


def load(path):
    try:
        return yaml.safe_load(path.read_text()) or {}
    except Exception:
        return {}


def is_library(name):
    return str(load(CHARTS / name / "Chart.yaml").get("type", "")).lower() == "library"


def local_dependents(library_dir):
    """Charts consuming `library_dir` from the working tree, not from a registry.

    Matched on the resolved `file://` path, not on the declared dependency name.
    The name is exactly what a rename changes: consumers would still carry the old
    one, the library would look like nobody depends on it, and the charts the rename
    breaks would go unverified.
    """
    target = (CHARTS / library_dir).resolve()
    out = set()
    for chart_yaml in sorted(CHARTS.glob("*/Chart.yaml")):
        consumer = chart_yaml.parent
        for dep in load(chart_yaml).get("dependencies") or []:
            repo = str(dep.get("repository", ""))
            if not repo.startswith("file://"):
                continue
            try:
                resolved = (consumer / repo[len("file://") :]).resolve()
            except (OSError, ValueError):
                continue
            if resolved == target:
                out.add(consumer.name)
    return out


def main():
    changed = [
        line.strip()
        for line in Path("/tmp/changed.txt").read_text().splitlines()
        if line.strip()
    ]

    self_path = os.environ.get("SELF_PATH", "")
    if self_path and self_path in changed:
        print(
            f"::warning::This pull request changes {self_path} itself. No chart is "
            "verified by it — review the logic by hand."
        )

    scope = set()
    for path in changed:
        for pattern in (CHART_PATH, VALUES):
            m = pattern.match(path)
            if m:
                scope.add(m.group(1))

    notices = []
    for name in sorted(scope):
        if (CHARTS / name / "Chart.yaml").exists() and is_library(name):
            deps = local_dependents(name)
            notices.append(
                f"{name} is a library chart: scoping to its {len(deps)} local "
                f"dependent(s)" + (f" ({', '.join(sorted(deps))})" if deps else "")
            )
            scope.update(deps)

    # Existence is checked before the library test everywhere: a pull request can
    # delete Chart.yaml and leave the directory, and that must drop out of scope
    # rather than raise.
    final = sorted(
        name
        for name in scope
        if (CHARTS / name / "Chart.yaml").exists() and not is_library(name)
    )

    for n in notices:
        print(f"::notice::{n}")

    out = (
        Path(os.environ["GITHUB_OUTPUT"]).open("a")
        if "GITHUB_OUTPUT" in os.environ
        else sys.stdout
    )
    # Two shapes of the same list: `charts` feeds a job matrix, `charts-list` feeds
    # a shell loop. Emitting both keeps every caller off ad-hoc jq.
    if not final:
        print("::notice::No installable chart changed by this pull request")
        out.write("charts=[]\ncharts-list=\nhas-charts=false\n")
    else:
        print(f"::notice::Charts in scope: {' '.join(final)}")
        out.write(
            f"charts={json.dumps(final)}\n"
            f"charts-list={' '.join(final)}\n"
            "has-charts=true\n"
        )


if __name__ == "__main__":
    main()
