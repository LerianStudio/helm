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
import argparse, base64, json, os, re, subprocess, sys, tempfile
from collections import Counter
try:
    import yaml
    HAVE_YAML = True
except ImportError:
    HAVE_YAML = False

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


def _render(chart_dir, fixtures):
    """helm template with 0+ -f fixtures → (returncode, stdout, stderr)."""
    cmd = ["helm", "template", "cov", chart_dir]
    for f in fixtures:
        if f:
            cmd += ["-f", f]
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.returncode, r.stdout, r.stderr


def render_all(chart_dir, fixture):
    """Render the whole chart; return the set of ConfigMap/Secret data keys.
    A data key is an UPPER_SNAKE key at exactly 2-space indent (under data:/stringData:);
    metadata (name/labels, lowercase) and container env (`- name:`, deeper) don't match."""
    rc, out, err = _render(chart_dir, [fixture])
    if rc:
        sys.stderr.write(err)
        return None
    return {m.group(1) for m in re.finditer(r"^  ([A-Z][A-Z0-9_]+):", out, re.M)}


SENTINEL = "COVPROBE9Z7"   # unlikely-to-collide marker for the configured-render probe


def find_override_paths(chart_dir):
    """(configmap_path, secrets_path) dotted paths into values.yaml — the operator override
    surfaces. Handles wrapped (`<comp>.configmap`) and flat (`configmap` / `configmap.data`)."""
    if not HAVE_YAML:
        return None, None
    vp = os.path.join(chart_dir, "values.yaml")
    if not os.path.exists(vp):
        return None, None
    try:
        vals = yaml.safe_load(open(vp)) or {}
    except Exception:
        return None, None

    def find(name):
        if name in vals:
            return name
        for k, v in vals.items():
            if isinstance(v, dict) and name in v:
                return f"{k}.{name}"
        return None

    cm = find("configmap")
    if cm:                                   # flat charts route the escape hatch through .data
        node = vals
        for s in cm.split("."):
            node = (node or {}).get(s, {}) if isinstance(node, dict) else {}
        if isinstance(node, dict) and "data" in node:
            cm = f"{cm}.data"
    return cm, find("secrets")


def _set_path(root, path, key, value):
    cur = root
    for s in path.split("."):
        cur = cur.setdefault(s, {})
    cur[key] = value


def probe_wired(chart_dir, base_fixture, cm_path, sec_path, config_keys, secret_keys):
    """CONFIGURED RENDER: set each candidate key (config via cm_path, secret via sec_path) to a
    sentinel and re-render. Return the subset whose sentinel actually surfaces in the rendered
    ConfigMap/Secret — proof the override is EFFECTIVE (the chart emits the key), not merely
    name-allowlisted. None = probe could not run (no PyYAML / no path / render failed)."""
    if not HAVE_YAML:
        return None
    overrides, probe_of = {}, {}
    for k in config_keys:
        if cm_path:
            _set_path(overrides, cm_path, k, f"{SENTINEL}{k}"); probe_of[k] = f"{SENTINEL}{k}"
    for k in secret_keys:
        if sec_path:
            _set_path(overrides, sec_path, k, f"{SENTINEL}{k}"); probe_of[k] = f"{SENTINEL}{k}"
    if not probe_of:
        return set()
    tf = tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False)
    try:
        yaml.safe_dump(overrides, tf); tf.close()
        rc, out, err = _render(chart_dir, [base_fixture, tf.name])
    finally:
        os.unlink(tf.name)
    if rc:
        sys.stderr.write("[coverage] probe render failed; can't verify emission-on-set\n" + err)
        return None
    wired = set()
    for k, sent in probe_of.items():
        # secrets render base64 in Secret.data (raw in stringData) — accept either form.
        if sent in out or base64.b64encode(sent.encode()).decode() in out:
            wired.add(k)
    return wired


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
    cm_path, sec_path = find_override_paths(a.chart_dir)
    fails, warns, review = [], [], []

    # Active keys the DEFAULT render does NOT emit. Emission (not a name/allowlist match) is the
    # only proof a key is covered, so we PROVE the rest with a configured render below.
    helper_gaps = [k for k in active if not rows[k][1] and rows[k][0].startswith("gap:helper-not-wired:")]
    secret_cand = [k for k in active if k not in emitted and rows[k][0] == "secret"]
    config_cand, unsettable = [], []
    for k in active:
        kind, covered = rows[k]
        if k in emitted or kind == "secret" or kind.startswith("gap:helper-not-wired:"):
            continue
        # emitted==False here (config/datastore gap). Datastore is conditional-external (ok).
        if kind == "datastore":
            continue
        if allow and k not in allow:
            unsettable.append(k)          # not emitted AND not in allowlist → operator can't set it
        else:
            config_cand.append(k)

    # CONFIGURED RENDER: set every candidate and confirm the override actually reaches a rendered
    # ConfigMap/Secret. A `propertyNames.enum` membership or a secret-shaped NAME does NOT prove the
    # chart emits the key — only this probe does.
    probe = probe_wired(a.chart_dir, a.fixture, cm_path, sec_path, config_cand, secret_cand)

    for k in sorted(helper_gaps):
        dom = rows[k][0].split(":")[-1]
        fails.append(f"{k}: domain helper '{dom}' is NOT wired "
                     f"(the app declares {dom.upper()}_* but the chart never emits it)")
    for k in sorted(unsettable):
        fails.append(f"{k}: declared active in .env, not emitted, and NOT in the schema allowlist "
                     f"— the operator cannot set it via configmap")
    if probe is None:
        # Probe unavailable (no PyYAML / no override path / render failed): never a silent pass —
        # surface every unproven candidate for human triage.
        for k in sorted(config_cand):
            review.append(f"'{k}' not emitted by default; emission-on-override NOT verified "
                          f"(probe unavailable) — confirm configmap.{k} actually emits it")
        for k in sorted(secret_cand):
            review.append(f"'{k}' secret not rendered by default; emission-on-set NOT verified "
                          f"(probe unavailable) — confirm secrets.yaml maps it")
    else:
        for k in sorted(config_cand):
            if k not in probe:
                fails.append(f"{k}: allowlisted but setting configmap.{k} emits NOTHING (no template "
                             f"line renders it) — a dead allowlist entry, not actually settable")
        for k in sorted(secret_cand):
            if k not in probe:
                fails.append(f"{k}: secret-classified but setting it produces no Secret entry "
                             f"— the chart silently drops the credential")
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
