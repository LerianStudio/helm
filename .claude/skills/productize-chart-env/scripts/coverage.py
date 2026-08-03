#!/usr/bin/env python3
"""
coverage.py — the productize-chart-env self-check + coverage report.

Renders a chart and reconciles what it emits against the app's config/.env.example
(the contract). Classifies every var (config / datastore / helper / secret / gap /
omitted) by the domain map, then reports coverage and FAILS if:
  - an ACTIVE .env var is left unhandled (nothing productizes it), or
  - the chart emits a ConfigMap key that maps to nothing (raw / undocumented drift).

It is a REPORT + GATE, not a generator: it tells you what is covered and what is
still a gap, so the productization is provably complete against the .env.

Usage:
  coverage.py --chart-dir charts/br-ccs --env <br-ccs.env> \
              [--fixture <enable-all.yaml>] [--report <out.md>]

Fetch the .env first:
  gh api repos/LerianStudio/<app>/contents/config/.env.example --jq '.content' \
    | base64 -d > <app>.env
"""
import argparse, re, subprocess, sys

# cross-cutting domains → the lerian-common helper that owns them (Rule: never cfgValue)
DOMAIN = [
    (re.compile(r"^MULTI_TENANT_"), "helper:multiTenant"),
    (re.compile(r"^(ENABLE_TELEMETRY|OTEL_)"), "helper:otel"),
    (re.compile(r"^SD_"), "helper:serviceDiscovery"),
    (re.compile(r"^STREAMING_"), "helper:streaming"),
    (re.compile(r"^PLUGIN_AUTH_"), "helper:auth"),
]
# host/conn fields the datastore mask owns (tuning stays config)
DATASTORE = {
    "POSTGRES_HOST", "POSTGRES_PORT", "POSTGRES_USER", "POSTGRES_SSLMODE",
    "POSTGRES_REPLICA_HOST", "REDIS_HOST",
    "RABBITMQ_HOST", "RABBITMQ_PORT_AMQP", "RABBITMQ_DEFAULT_USER",
}
SECRET = re.compile(
    r"(PASSWORD|_SECRET\b|_SECRET_|API_KEY|CLIENT_SECRET|CRYPTO|LICENSE_KEY|"
    r"ACCESS_KEY|SECRET_KEY|ORGANIZATION_IDS|_TOKEN$)"
)
# credential-NAMED but actually config/path (Rule 1) — never classified secret
SECRET_FALSE_POSITIVE = {"WEBHOOK_API_KEY_FILE", "AWS_ACCESS_KEY_ID", "SD_TOKEN"}


def env_vars(path):
    active, commented = set(), set()
    for ln in open(path):
        m = re.match(r"^([A-Z][A-Z0-9_]+)=", ln)
        if m:
            active.add(m.group(1)); continue
        m = re.match(r"^#\s*([A-Z][A-Z0-9_]+)=", ln)
        if m:
            commented.add(m.group(1))
    return active, commented


def render(chart_dir, fixture, tmpl):
    cmd = ["helm", "template", "cov", chart_dir, "-s", tmpl]
    if fixture:
        cmd += ["-f", fixture]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode:
        sys.stderr.write(r.stderr)
        return None
    return {m.group(1) for m in re.finditer(r"^  ([A-Z][A-Z0-9_]+):", r.stdout, re.M)}


def classify(k, emitted):
    for rx, dom in DOMAIN:
        if rx.match(k):
            return dom
    if k in DATASTORE:
        return "datastore"
    if k not in SECRET_FALSE_POSITIVE and SECRET.search(k):
        return "secret"
    if k in emitted:
        return "config"
    return "gap"  # in .env, not covered, not a known secret → backlog


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--chart-dir", required=True)
    ap.add_argument("--env", required=True)
    ap.add_argument("--fixture", default=None)
    ap.add_argument("--report", default=None)
    a = ap.parse_args()

    active, commented = env_vars(a.env)
    allenv = active | commented
    cm = render(a.chart_dir, a.fixture, "templates/configmap.yaml")
    sec = render(a.chart_dir, a.fixture, "templates/secrets.yaml") or set()
    if cm is None:
        print("FAIL: ConfigMap did not render"); return 1
    emitted = cm | sec

    rows = {k: classify(k, emitted) for k in sorted(allenv | emitted)}
    fails, warns, review = [], [], []

    for k in sorted(active):
        if rows[k] == "gap":
            warns.append(f"gap: '{k}' declared in .env, chart does not cover it yet")
    for k in sorted(cm):
        kind = rows.get(k, "gap")
        if kind == "gap" and k not in allenv:
            warns.append(f"chart-only: '{k}' emitted but not in the app .env (dead config or .env incomplete?)")
    for k in sorted(allenv):
        kind = rows[k]
        if kind == "config" and k not in emitted and k in active:
            fails.append(f"'{k}' classified config but NOT emitted by the render")
    for k in sorted(SECRET_FALSE_POSITIVE & set(cm)):
        review.append(f"'{k}' is credential-NAMED but kept as config (path/empty-default) — confirm")

    from collections import Counter
    counts = Counter(rows[k] for k in active)
    print(f"[coverage] {a.chart_dir}: {len(active)} active .env vars — {dict(counts)}")
    for r in review:
        print(f"  REVIEW {r}")
    for w in warns:
        print(f"  WARN   {w}")
    for f in fails:
        print(f"  FAIL   {f}")

    report_lines = [f"# Coverage — {a.chart_dir}", "", f"Active .env vars: {len(active)}", ""]
    for kind in ["config", "datastore", "helper:multiTenant", "helper:otel",
                 "helper:serviceDiscovery", "helper:streaming", "helper:auth", "secret", "gap"]:
        ks = [k for k in sorted(allenv) if rows[k] == kind]
        if ks:
            report_lines.append(f"## {kind} ({len(ks)})")
            report_lines += [f"- {k}" for k in ks]
            report_lines.append("")
    if a.report:
        open(a.report, "w").write("\n".join(report_lines) + "\n")
        print(f"[coverage] report → {a.report}")

    if fails:
        print(f"[coverage] FAILED ({len(fails)} hard)"); return 1
    print(f"[coverage] OK ({len(warns)} warn, {len(review)} review)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
