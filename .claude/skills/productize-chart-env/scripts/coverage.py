#!/usr/bin/env python3
"""
coverage.py — the productize-chart-env self-check + coverage report.

Renders the WHOLE chart and reconciles what it emits against the app's
config/.env.example (the contract). A var is COVERED when the chart actually
emits it (any ConfigMap/Secret, incl. worker & sub-component templates), OR it
is an emit-when-set secret, OR it belongs to a domain whose helper is WIRED.

Truth = emission, not name. Two lessons baked in:
  1. A domain prefix (SD_/STREAMING_/MULTI_TENANT_/OTEL_/PLUGIN_AUTH_) counts as
     covered ONLY when its helper is wired — detected by the domain's ANCHOR key
     (e.g. SD_ENABLED) actually rendering. A prefix alone does NOT imply coverage
     (that hid unwired SD/streaming before).
  2. Render the whole chart (one `helm template`, no `-s`) so worker / signer /
     mqbridge / etc. ConfigMaps are all included — no false worker-only gaps.

Usage:
  coverage.py --chart-dir charts/br-ccs --env <br-ccs.env> \
              [--fixture <enable-all.yaml>] [--report <out.md>]

Fetch the .env first:
  gh api repos/LerianStudio/<app>/contents/config/.env.example --jq '.content' \
    | base64 -d > <app>.env
"""
import argparse, json, os, re, subprocess, sys
from collections import Counter

# domain prefix -> (domain, ANCHOR key that proves the helper is wired)
DOMAIN = [
    (re.compile(r"^MULTI_TENANT_"), "multiTenant", "MULTI_TENANT_ENABLED"),
    (re.compile(r"^(ENABLE_TELEMETRY$|OTEL_)"), "otel", "ENABLE_TELEMETRY"),
    (re.compile(r"^SD_"), "serviceDiscovery", "SD_ENABLED"),
    (re.compile(r"^STREAMING_"), "streaming", "STREAMING_ENABLED"),
    (re.compile(r"^PLUGIN_AUTH_"), "auth", "PLUGIN_AUTH_ENABLED"),
]
DATASTORE = {
    "POSTGRES_HOST", "POSTGRES_PORT", "POSTGRES_USER", "POSTGRES_SSLMODE",
    "POSTGRES_REPLICA_HOST", "REDIS_HOST",
    "RABBITMQ_HOST", "RABBITMQ_PORT_AMQP", "RABBITMQ_DEFAULT_USER",
}
# emit-when-set credentials/secret-adjacent — the Secret range renders them only when
# the operator provides a value, so "not emitted with the fixture" is NOT a gap.
# CLIENT_ID rides along with CLIENT_SECRET in the app Secret (not a credential itself).
SECRET_OPTIONAL = re.compile(
    r"(PASSWORD|_SECRET\b|_SECRET_|API_KEY|CLIENT_SECRET|CLIENT_ID|CRYPTO|LICENSE_KEY|"
    r"ORGANIZATION_IDS|ACCESS_KEY|SECRET_KEY|MASTER_KEYS?|_TOKEN$)")
# credential-NAMED but actually config/path (kept as config) — flagged for review, not secret
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


def render_all(chart_dir, fixture):
    """Render the whole chart; return the set of ConfigMap/Secret data keys.
    A data key is an UPPER_SNAKE key at exactly 2-space indent (under data:/stringData:);
    metadata (name/labels, lowercase) and container env (`- name:`, deeper) don't match."""
    cmd = ["helm", "template", "cov", chart_dir]
    if fixture:
        cmd += ["-f", fixture]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode:
        sys.stderr.write(r.stderr)
        return None
    return {m.group(1) for m in re.finditer(r"^  ([A-Z][A-Z0-9_]+):", r.stdout, re.M)}


def schema_allowlist(chart_dir):
    """Collect the configmap escape-hatch allowlist (every propertyNames.enum in the chart's
    values.schema.json) as a set. Empty set = no schema / no enum → can't cross-check.
    An active .env key that the chart does NOT emit is only truly settable by the operator when
    it is in this allowlist (configmap.<KEY>); absent from BOTH emission and allowlist it is a
    real gap (the operator cannot set it at all)."""
    if not chart_dir:
        return set()
    p = os.path.join(chart_dir, "values.schema.json")
    if not os.path.exists(p):
        return set()
    try:
        schema = json.load(open(p))
    except Exception:
        return set()
    allow = set()
    def walk(node):
        if isinstance(node, dict):
            pn = node.get("propertyNames")
            if isinstance(pn, dict) and isinstance(pn.get("enum"), list):
                allow.update(pn["enum"])
            for v in node.values():
                walk(v)
        elif isinstance(node, list):
            for v in node:
                walk(v)
    walk(schema)
    return allow


def domain_of(k, applies):
    """A key belongs to a domain only if the domain APPLIES to this chart — i.e. the
    domain's ANCHOR key (STREAMING_ENABLED, MULTI_TENANT_ENABLED, ...) is in the .env.
    This stops an app-prefix like STREAMING_HUB_* from matching the STREAMING_ domain
    when the app uses its OWN naming (not lib-streaming's env contract)."""
    for rx, dom, anchor in DOMAIN:
        if rx.match(k) and applies.get(dom):
            return dom, anchor
    return None, None


def classify(k, emitted, wired, applies):
    """Return (kind, covered:bool). kind is for the report; covered decides gap."""
    if k in emitted:
        dom, _ = domain_of(k, applies)
        if dom:
            return f"helper:{dom}", True
        if k in DATASTORE:
            return "datastore", True
        if k not in SECRET_FALSE_POSITIVE and SECRET_OPTIONAL.search(k):
            return "secret", True
        return "config", True
    # NOT emitted:
    dom, anchor = domain_of(k, applies)
    if dom:
        if wired.get(dom):
            return f"helper:{dom}", True          # sibling renders only when the domain is enabled
        return f"gap:helper-not-wired:{dom}", False
    if k not in SECRET_FALSE_POSITIVE and SECRET_OPTIONAL.search(k):
        return "secret", True                     # emit-when-set — operator provides it
    if k in DATASTORE:
        return "datastore", True                  # conditional (external infra)
    return "gap", False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--chart-dir", required=True)
    ap.add_argument("--env", required=True)
    ap.add_argument("--fixture", default=None)
    ap.add_argument("--report", default=None)
    a = ap.parse_args()

    active, commented = env_vars(a.env)
    allenv = active | commented
    emitted = render_all(a.chart_dir, a.fixture)
    if emitted is None:
        print("FAIL: chart did not render"); return 1

    # a domain APPLIES only if the app declares its ANCHOR key (else an app-prefix like
    # STREAMING_HUB_* is app config, not the STREAMING_ domain); WIRED = anchor emitted.
    applies = {dom: (anchor in allenv or anchor in emitted) for _, dom, anchor in DOMAIN}
    wired = {dom: (anchor in emitted) for _, dom, anchor in DOMAIN}

    rows = {k: classify(k, emitted, wired, applies) for k in sorted(allenv | emitted)}
    allow = schema_allowlist(a.chart_dir)
    fails, warns, review = [], [], []

    for k in sorted(active):
        kind, covered = rows[k]
        # An emit-when-set secret classified covered by NAME is not proof the chart wires it: if
        # no secrets.yaml entry maps it, `<comp>.secrets.<K>` is silently dropped. Surface it.
        if covered and kind == "secret" and k not in emitted:
            review.append(f"'{k}' classified emit-when-set secret but NOT rendered with this "
                          f"fixture — confirm secrets.yaml maps it into Secret.data/stringData")
        if covered:
            continue
        if kind.startswith("gap:helper-not-wired:"):
            fails.append(f"{k}: domain helper '{kind.split(':')[-1]}' is NOT wired "
                         f"(the app declares {kind.split(':')[-1].upper()}_* but the chart never emits it)")
        elif allow and k not in allow:
            # Real gap: not emitted AND not in the schema allowlist → the operator cannot even set
            # it via configmap.<K>. (When no schema/allowlist is available we can't cross-check, so
            # it stays a WARN below.)
            fails.append(f"{k}: declared active in .env but neither emitted nor in the schema "
                         f"allowlist (propertyNames.enum) — the operator cannot set it via configmap")
        elif allow:
            # In the allowlist but not emitted: legitimate ONLY as an app-default-only key the
            # operator can override via configmap.<K>. Allowlist membership grants SET, not EMIT —
            # confirm the app internally defaults it (the byte-identity-preserving case).
            warns.append(f"app-default-only: '{k}' not emitted; settable via configmap.{k} "
                         f"(in allowlist) — confirm the app internally defaults it")
        else:
            warns.append(f"gap: '{k}' declared in .env, chart does not cover it (no schema to cross-check)")
    for k in sorted(emitted - allenv):
        if not re.match(r"^[A-Z]", k):
            continue
        warns.append(f"chart-only: '{k}' emitted but not in the app .env (dead config or .env incomplete?)")
    for k in sorted(SECRET_FALSE_POSITIVE & emitted):
        review.append(f"'{k}' is credential-NAMED but kept as config (path/empty-default) — confirm")

    counts = Counter(rows[k][0].split(":")[0] if not rows[k][0].startswith("helper") else rows[k][0]
                     for k in active)
    print(f"[coverage] {a.chart_dir}: {len(active)} active .env vars — {dict(counts)}")
    print(f"[coverage] domain helpers wired: {wired}")
    for r in review:
        print(f"  REVIEW {r}")
    for w in warns:
        print(f"  WARN   {w}")
    for f in fails:
        print(f"  FAIL   {f}")

    if a.report:
        lines = [f"# Coverage — {a.chart_dir}", "", f"Active .env vars: {len(active)}", ""]
        order = ["config", "datastore", "helper:multiTenant", "helper:otel",
                 "helper:serviceDiscovery", "helper:streaming", "helper:auth", "secret"]
        for kind in order:
            ks = [k for k in sorted(allenv) if rows[k][0] == kind]
            if ks:
                lines.append(f"## {kind} ({len(ks)})")
                lines += [f"- {k}" for k in ks]; lines.append("")
        gaps = [k for k in sorted(active) if not rows[k][1]]
        if gaps:
            lines.append(f"## GAPS ({len(gaps)})")
            lines += [f"- {k} — {rows[k][0]}" for k in gaps]; lines.append("")
        open(a.report, "w").write("\n".join(lines) + "\n")
        print(f"[coverage] report → {a.report}")

    if fails:
        print(f"[coverage] FAILED ({len(fails)} unwired-helper / hard)"); return 1
    print(f"[coverage] OK ({len(warns)} warn, {len(review)} review)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
