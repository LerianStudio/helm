#!/usr/bin/env python3
"""Decide whether a bot chart-update pull request is a routine bump that may merge alone.

chart-bump-automerge.yml runs this on every pull request the push bot opens from
app-sync.yml. A routine bump merges once CI is green, without a human review and
without the Severino ticket; anything else keeps the manual path. The rule fails
closed: every condition below must hold, and an unexpected shape is not routine.

    - the pull request targets main and is not a legacy chart line patch;
    - the sender reported no new environment variables (title `fix(`, no attention note,
      every "New Env Vars" cell is `-`);
    - every commit is the CI user's, signed and verified, so nobody pushed on top;
    - only charts/<chart>/Chart.yaml and charts/<chart>/values.yaml are modified;
    - Chart.yaml differs only in appVersion and description;
    - values.yaml differs only in leaves whose path ends in image.tag, none added or removed;
    - every changed version is a plain X.Y.Z, strictly higher and on the same major.
      A downgrade or a major bump goes to a human.

    chart-bump-classify.py   reads PR_NUMBER and GITHUB_REPOSITORY, calls `gh api`, and
                             writes routine, reason and chart to GITHUB_OUTPUT
"""

import json
import os
import re
import subprocess
import sys

import yaml

CI_COMMITTER = os.environ.get("CI_COMMITTER", "lerian-studio")
CHART_FILE = re.compile(r"^charts/([^/]+)/(Chart|values)\.yaml$")
SEMVER = re.compile(r"^v?(\d+)\.(\d+)\.(\d+)$")
ENV_VARS_ROW = re.compile(r"^\|\s*[^|]+\|\s*[^|]+\|\s*([^|]*?)\s*\|\s*$")


class NotRoutine(Exception):
    pass


def leaves(node, path=()):
    """Every scalar of a YAML document keyed by its path, lists indexed by position."""
    if isinstance(node, dict):
        out = {}
        for key, value in node.items():
            out.update(leaves(value, path + (str(key),)))
        return out
    if isinstance(node, list):
        out = {}
        for i, value in enumerate(node):
            out.update(leaves(value, path + (str(i),)))
        return out
    return {path: node}


def check_version(where, old, new):
    old_m, new_m = SEMVER.match(str(old)), SEMVER.match(str(new))
    if not old_m or not new_m:
        raise NotRoutine(f"{where}: {old!r} -> {new!r} is not a plain X.Y.Z version")
    old_v = tuple(int(p) for p in old_m.groups())
    new_v = tuple(int(p) for p in new_m.groups())
    if new_v <= old_v:
        raise NotRoutine(f"{where}: {old} -> {new} is not an upgrade")
    if new_v[0] != old_v[0]:
        raise NotRoutine(f"{where}: {old} -> {new} changes the major version")


def check_metadata(pr):
    if pr["base"] != "main":
        raise NotRoutine(f"base branch is {pr['base']}, not main")
    title = pr["title"]
    if not title.startswith("fix("):
        raise NotRoutine(f"title {title!r} is not a fix( bump; feat( means new env vars")
    if "[legacy" in title:
        raise NotRoutine("legacy chart line patch")
    body = pr.get("body") or ""
    if "Attention" in body or "New environment variables" in body or "Legacy patch" in body:
        raise NotRoutine("pull request body carries an attention or legacy note")
    for line in body.splitlines():
        m = ENV_VARS_ROW.match(line.strip())
        if not m or line.strip().startswith("|--") or "New Env Vars" in line:
            continue
        if m.group(1) != "-":
            raise NotRoutine(f"components table lists new env vars: {m.group(1)}")


def check_commits(commits):
    if not commits:
        raise NotRoutine("pull request has no commits")
    for c in commits:
        author, committer = c.get("author"), c.get("committer")
        if author != CI_COMMITTER or committer != CI_COMMITTER:
            raise NotRoutine(f"commit {c['sha'][:7]} is by {author}/{committer}, not {CI_COMMITTER}")
        if not c.get("verified"):
            raise NotRoutine(f"commit {c['sha'][:7]} has no verified signature")


def check_files(files):
    """Returns the chart name; every file must be a modified Chart.yaml or values.yaml of one chart."""
    if not files:
        raise NotRoutine("pull request changes no files")
    charts = set()
    for f in files:
        m = CHART_FILE.match(f["filename"])
        if not m:
            raise NotRoutine(f"{f['filename']} is outside Chart.yaml/values.yaml")
        if f["status"] != "modified":
            raise NotRoutine(f"{f['filename']} is {f['status']}, not modified")
        charts.add(m.group(1))
    if len(charts) != 1:
        raise NotRoutine(f"pull request touches several charts: {sorted(charts)}")
    return charts.pop()


def check_chart_yaml(base_text, head_text):
    base, head = yaml.safe_load(base_text) or {}, yaml.safe_load(head_text) or {}
    rest = lambda d: {k: v for k, v in d.items() if k not in ("appVersion", "description")}
    if rest(base) != rest(head):
        changed = sorted(k for k in set(rest(base)) | set(rest(head)) if base.get(k) != head.get(k))
        raise NotRoutine(f"Chart.yaml changes more than appVersion/description: {changed}")
    changes = 0
    if base.get("appVersion") != head.get("appVersion"):
        check_version("Chart.yaml appVersion", base.get("appVersion"), head.get("appVersion"))
        changes += 1
    return changes


def check_values_yaml(base_text, head_text):
    base, head = leaves(yaml.safe_load(base_text) or {}), leaves(yaml.safe_load(head_text) or {})
    if set(base) != set(head):
        diff = sorted(".".join(p) for p in set(base) ^ set(head))
        raise NotRoutine(f"values.yaml adds or removes keys: {diff}")
    changes = 0
    for path in sorted(base):
        if base[path] == head[path]:
            continue
        dotted = ".".join(path)
        if path[-2:] != ("image", "tag"):
            raise NotRoutine(f"values.yaml changes {dotted}, which is not an image tag")
        check_version(f"values.yaml {dotted}", base[path], head[path])
        changes += 1
    return changes


def classify(pr, files, commits, contents):
    """contents maps (path, "base"|"head") to the file text. Returns (routine, reason, chart)."""
    chart = ""
    try:
        check_metadata(pr)
        check_commits(commits)
        chart = check_files(files)
        changes = 0
        for f in files:
            base, head = contents[(f["filename"], "base")], contents[(f["filename"], "head")]
            if f["filename"].endswith("/Chart.yaml"):
                changes += check_chart_yaml(base, head)
            else:
                changes += check_values_yaml(base, head)
        if changes == 0:
            raise NotRoutine("no version changed")
    except NotRoutine as e:
        return False, str(e), chart
    return True, f"routine bump of {chart}: {changes} version(s) raised within the same major", chart


def gh_api(path, raw=False, paginate=False):
    cmd = ["gh", "api", path]
    if raw:
        cmd += ["-H", "Accept: application/vnd.github.raw"]
    if paginate:
        cmd += ["--paginate", "--slurp"]
    return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout


def main():
    repo, number = os.environ["GITHUB_REPOSITORY"], os.environ["PR_NUMBER"]
    p = json.loads(gh_api(f"repos/{repo}/pulls/{number}"))
    pr = {"base": p["base"]["ref"], "title": p["title"], "body": p["body"]}
    files = [f for page in json.loads(gh_api(f"repos/{repo}/pulls/{number}/files", paginate=True)) for f in page]
    commits = [
        {
            "sha": c["sha"],
            "author": (c.get("author") or {}).get("login"),
            "committer": (c.get("committer") or {}).get("login"),
            "verified": c["commit"]["verification"]["verified"],
        }
        for page in json.loads(gh_api(f"repos/{repo}/pulls/{number}/commits", paginate=True))
        for c in page
    ]
    contents = {}
    for f in files:
        if f["status"] == "modified" and CHART_FILE.match(f["filename"]):
            for side, sha in (("base", p["base"]["sha"]), ("head", p["head"]["sha"])):
                contents[(f["filename"], side)] = gh_api(f"repos/{repo}/contents/{f['filename']}?ref={sha}", raw=True)

    routine, reason, chart = classify(pr, files, commits, contents)
    print(f"routine={routine}: {reason}")
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as out:
            out.write(f"routine={'true' if routine else 'false'}\nreason={reason}\nchart={chart}\n")
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as out:
            verdict = "routine bump: merges when CI is green" if routine else "needs human review"
            out.write(f"### Chart bump classification\n\n**{verdict}**\n\n{reason}\n")


if __name__ == "__main__":
    sys.exit(main())
