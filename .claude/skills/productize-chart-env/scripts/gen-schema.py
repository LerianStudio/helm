#!/usr/bin/env python3
"""
gen-schema.py — generate a values.schema.json from a chart's values.yaml.

Strict WHERE it is safe, permissive WHERE it must be. The whole point of the
productize premise ("everything known is typed") is that our grouped config blocks
are closed sets — so a typo'd key under `<comp>.redis.<typo>` should be REJECTED at
`helm install`. But subcharts (postgresql/valkey/...), `global`, and open passthrough
maps (`configmap`, `extraEnvVars`, podAnnotations, ...) are NOT ours to close — forcing
`additionalProperties:false` there would reject legitimate keys and break the render.

Policy per object node:
  - OPEN  (additionalProperties: true / {type:string}) when: key is a known subchart /
    `global`, OR key is in OPEN_MAPS, OR the node is empty {}, OR any child key is
    UPPER_SNAKE (env-var-like) or non-identifier. No strict recursion.
  - CLOSED (additionalProperties: false, properties enumerated) otherwise — the typed
    camelCase grouped blocks. This is where typos get caught.
  - ROOT is always OPEN (allows subcharts). Strictness only kicks in on nested typed blocks.

Scalars get `type` + `default` (+ `enum` from a `# -- (enum: a|b|c)` annotation hint).
Descriptions come from the `# --` annotations (shared parse with gen-docs). `required` is
deliberately NOT emitted — default-everything, like cert-manager.

Because our grouped blocks ship EMPTY (`<comp>.redis: {}` — defaults live in the template),
values.yaml alone can't tell the generator the group's fields. So with `--chart-dir` the
generator also parses `templates/configmap.yaml`: it reads every
`cfgValue (... "params" $grp ... "field" "f" ... "default" "d")` plus the
`$grp := .Values.<comp>.<group>` var decls, and ENUMERATES those fields (type string,
default d) under the group block with `additionalProperties:false` — so a typo like
`<comp>.redis.poolSizeX` is rejected even though values ships `redis: {}`. This is the
template-as-source-of-truth rule the coverage check already relies on.

Usage:
  gen-schema.py --values charts/br-ccs/values.yaml --chart-dir charts/br-ccs \
      [--env config/.env.example] [--rendered-keys keys.txt] \
      [--out charts/br-ccs/values.schema.json]
  gen-schema.py --values ... --chart-dir ... --check   # exit 1 if out would change

--env + --rendered-keys guard the `configmap` escape hatch with `propertyNames.enum` (the UNION
of both — see the ENV_KEYS note). Omit both to leave `configmap` fully open (no typo protection).
"""
import argparse, json, re, sys, os


def template_group_fields(chart_dir):
    """Parse templates/configmap.yaml → {values-path: {field: default}} for grouped blocks."""
    tpl = os.path.join(chart_dir, "templates", "configmap.yaml")
    if not os.path.exists(tpl):
        return {}
    src = open(tpl).read()
    # $grp := .Values.<path>   (path may be brCcs.rateLimit or, for flat charts, rateLimit)
    short2path = {m.group(1): m.group(2)
                  for m in re.finditer(r"\$(\w+)\s*:=\s*\.Values\.([\w.]+)\s*\|\s*default dict", src)}
    # Component var: $component := index .Values "br-sta"  OR  $component := .Values.brSta
    # (the direct camelCase form has NO `| default dict`, so it won't collide with group vars).
    compvars = {m.group(1): m.group(2)
                for m in re.finditer(r'\$(\w+)\s*:=\s*index\s+\.Values\s+"([\w-]+)"', src)}
    compvars.update({m.group(1): m.group(2)
                     for m in re.finditer(r'\$(\w+)\s*:=\s*\.Values\.(\w+)\s*-?\}\}', src)})
    for m in re.finditer(r"\$(\w+)\s*:=\s*\$(\w+)\.(\w+)\s*\|\s*default dict", src):
        grp_var, comp_var, group = m.group(1), m.group(2), m.group(3)
        if comp_var in compvars:
            short2path[grp_var] = f"{compvars[comp_var]}.{group}"
    groups = {}
    # params expressed as a $var: "params" $rl "field" "max" "default" "500"
    for m in re.finditer(r'"params"\s*\$(\w+)\s*"field"\s*"(\w+)"\s*"default"\s*("([^"]*)"|[^)\s]+)', src):
        grp, field, default = m.group(1), m.group(2), m.group(4) if m.group(4) is not None else ""
        path = short2path.get(grp)
        if path:
            groups.setdefault(path, {})[field] = default
    # params expressed INLINE: "params" ($component.multiTenant | default dict) "field" "enabled" ...
    #   or "params" (.Values.brCcs.rateLimit | default dict) "field" ...
    for m in re.finditer(
            r'"params"\s*\((?:\$(\w+)|\.Values)\.([\w.]+?)\s*\|\s*default dict\)\s*"field"\s*"(\w+)"\s*"default"\s*("([^"]*)"|[^)\s]+)',
            src):
        comp_var, tail, field = m.group(1), m.group(2), m.group(3)
        default = m.group(5) if m.group(5) is not None else ""
        if comp_var and comp_var in compvars:
            path = f"{compvars[comp_var]}.{tail}"
        elif not comp_var:
            path = tail                      # .Values.<path>
        else:
            path = None
        if path:
            groups.setdefault(path, {})[field] = default
    return groups

try:
    import yaml
except ImportError:
    sys.stderr.write("gen-schema needs PyYAML (pip install pyyaml)\n"); sys.exit(2)

SUBCHARTS = {"postgresql", "valkey", "redis", "rabbitmq", "mongodb", "kafka",
             "lerian-common-helm", "lerian-common", "common"}
OPEN_MAPS = {"configmap", "data", "extraEnvVars", "extraEnvVarsCM", "extraEnvVarsSecret",
             "podAnnotations", "podLabels", "annotations", "commonLabels", "labels",
             "matchLabels", "selectorLabels", "nodeSelector", "extraObjects", "secrets",
             "config", "grafana.ini", "structuredConfig"}
IDENT = re.compile(r"^[a-z][A-Za-z0-9]*$")          # camelCase leaf key
ENVLIKE = re.compile(r"^[A-Z][A-Z0-9_]+$")          # env-var-like key

# The valid NATIVE_KEY allowlist guarding the `configmap`/`data` escape hatch with
# `propertyNames.enum`: a typo'd override (configmap.RATE_LIMIT_MAXX) is rejected while any real
# key is accepted — typo protection for the tiered model WITHOUT typing every key as a knob.
# CRITICAL: the allowlist is the UNION of the app .env keys (--env) AND the keys the chart
# actually RENDERS (--rendered-keys). The .env alone is too strict — the app reads (and the
# helpers emit) keys the .env.example omits (e.g. STREAMING_SASL_MECHANISM, an SD_*/streaming
# gap): those are legitimate escape-hatch overrides and a .env-only enum would wrongly reject
# them. When neither source is given, `configmap` stays fully open (no enum).
ENV_KEYS = set()
_ENV_KEY = re.compile(r"^#?\s*([A-Z][A-Z0-9_]+)\s*=")   # active OR commented-optional env var
_KEY = re.compile(r"^([A-Z][A-Z0-9_]+)\s*$")            # bare key (one per line) for --rendered-keys


def parse_env_keys(path):
    keys = set()
    for line in open(path):
        m = _ENV_KEY.match(line)
        if m:
            keys.add(m.group(1))
    return keys


def parse_key_list(path):
    keys = set()
    for line in open(path):
        m = _KEY.match(line.strip())
        if m:
            keys.add(m.group(1))
    return keys


def open_map_schema(child_path, node, desc):
    """Open passthrough object. For the `configmap`/`data` escape hatch, guard the KEYS with the
    .env allowlist (propertyNames.enum) — handles both the wrapped style (keys directly under
    `configmap`) and the flat style (keys under `configmap.data`)."""
    cs = {"type": "object", "additionalProperties": True}
    cd = desc.get(child_path, (None, None))[0]
    if cd:
        cs["description"] = cd
    leaf = child_path.split(".")[-1]
    if ENV_KEYS and leaf in ("configmap", "data"):
        allow = {"enum": sorted(ENV_KEYS)}
        if leaf == "configmap" and isinstance(node, dict) and "data" in node:
            # flat chart: the escape hatch is `configmap.data` — guard the nested map's keys.
            cs["properties"] = {"data": {"type": "object", "additionalProperties": True,
                                         "propertyNames": allow}}
        else:
            # wrapped chart: keys live directly under `configmap` — guard them here.
            cs["propertyNames"] = allow
    return cs


def descriptions(values_path):
    """Reuse the # -- annotation parse for path -> (description, enum)."""
    out, stack, pend, penum = {}, [], None, None
    for raw in open(values_path):
        line = raw.rstrip("\n"); indent = len(line) - len(line.lstrip(" "))
        m = re.match(r"^\s*#\s?--\s?(.*)$", line)
        if m:
            body = m.group(1)
            mt = re.match(r"\(enum:\s*([^)]+)\)\s*(.*)$", body)
            if mt:
                penum = [x.strip() for x in mt.group(1).split("|")]; body = mt.group(2)
            else:
                mt2 = re.match(r"\([^)]*\)\s*(.*)$", body)
                if mt2:
                    body = mt2.group(1)
            pend = body.strip(); continue
        if re.match(r"^\s*#", line) or not line.strip():
            continue
        mk = re.match(r"^(\s*)([A-Za-z0-9_.\-]+):", line)
        if not mk:
            pend, penum = None, None; continue
        while stack and stack[-1][0] >= indent:
            stack.pop()
        stack.append((indent, mk.group(2)))
        if pend is not None or penum is not None:
            out[".".join(k for _, k in stack)] = (pend, penum)
        pend, penum = None, None
    return out


def scalar_schema(v):
    if isinstance(v, bool):
        return {"type": "boolean"}
    if isinstance(v, int):
        return {"type": "integer"}
    if isinstance(v, float):
        return {"type": "number"}
    if v is None:
        return {"type": ["string", "null"]}
    return {"type": "string"}


def is_open(key, node):
    if key in SUBCHARTS or key == "global":
        return True
    if key in OPEN_MAPS:
        return True
    if isinstance(node, dict):
        if not node:
            return True
        for k in node:
            if ENVLIKE.match(str(k)) or not IDENT.match(str(k)):
                return True
    return False


def build(node, path, desc, tgroups):
    d, enum = desc.get(path, (None, None))
    # Grouped config block: values ships it empty, the template defines its fields.
    if path in tgroups and isinstance(node, dict) and all(IDENT.match(str(k)) for k in node):
        props = {}
        for f, dflt in sorted(tgroups[path].items()):
            # No `type`: cfgValue config is stringly-typed but YAML/helm coerce a toggle to a
            # bool or a number to an int — constraining the scalar TYPE breaks legitimate values.
            # The guardrail is `additionalProperties:false` on the parent (catches typo'd KEYS).
            fs = {"default": dflt}
            fd = desc.get(f"{path}.{f}", (None, None))[0]
            if fd:
                fs["description"] = fd
            props[f] = fs
        # merge any real values.yaml children (override the template-derived stub)
        for k, v in (node or {}).items():
            props[k] = build(v, f"{path}.{k}", desc, tgroups)
        s = {"type": "object", "properties": props, "additionalProperties": False}
        if d:
            s["description"] = d
        return s
    if isinstance(node, dict):
        # OPEN node → permissive object, no strict recursion
        # (decision made by caller via key; here handle empty/env-like)
        s = {"type": "object"}
        if d:
            s["description"] = d
        props = {}
        open_here = (not node) or any(ENVLIKE.match(str(k)) or not IDENT.match(str(k)) for k in node)
        if open_here:
            s["additionalProperties"] = {"type": "string"} if node == {} or all(
                not isinstance(v, (dict, list)) for v in node.values()) else True
            return s
        for k, v in node.items():
            child_path = f"{path}.{k}" if path else k
            if is_open(k, v) and child_path not in tgroups:
                props[k] = open_map_schema(child_path, v, desc)
            elif not isinstance(v, (dict, list)):
                # Scalar leaf of an OPEN operational block: emit NO `type` (default only),
                # same as cfgValue config-group fields. A default like pdb.maxUnavailable ""
                # or minAvailable 1 picks ONE type, but these are k8s int-or-string fields —
                # YAML/helm coerce, so locking the scalar type rejects the other valid form.
                fs = {} if v is None else {"default": v}
                fd, fenum = desc.get(child_path, (None, None))
                if fd:
                    fs["description"] = fd
                if fenum:
                    fs["enum"] = fenum
                props[k] = fs
            else:
                props[k] = build(v, child_path, desc, tgroups)
        s["properties"] = props
        # Strictness (additionalProperties:false) is ONLY correct on our finite cfgValue
        # config groups (tgroups) — those are handled by the branch above. A generic
        # camelCase dict reaching HERE is an OPERATIONAL/structural block (role configs
        # like all/ingest/delivery, autoscaling, pdb, resources, image, service, ...) —
        # k8s passthrough where operators legitimately add fields (pdb.maxUnavailable,
        # resources.limits, affinity, ...). Closing those rejected valid input, so keep
        # them OPEN. Typo protection stays where the contract is finite: the config groups.
        s["additionalProperties"] = True
        return s
    if isinstance(node, list):
        s = {"type": "array"}
        if d:
            s["description"] = d
        return s
    s = scalar_schema(node)
    if node is not None and not isinstance(node, bool):
        s["default"] = node
    elif isinstance(node, bool):
        s["default"] = node
    if d:
        s["description"] = d
    if enum:
        s["enum"] = enum
    return s


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--values", required=True)
    ap.add_argument("--chart-dir", default=None,
                    help="chart dir; parses templates/configmap.yaml to type the empty grouped blocks")
    ap.add_argument("--out", default=None)
    ap.add_argument("--env", default=None,
                    help="app .env(.example); its keys seed the propertyNames.enum allowlist "
                         "guarding the configmap escape hatch (typo protection)")
    ap.add_argument("--rendered-keys", default=None,
                    help="file of NATIVE_KEYs the chart RENDERS (one per line; e.g. "
                         "`helm template <enable-all> | yq '..data|keys'`). UNIONed with --env so "
                         "the allowlist covers helper-emitted keys the .env.example omits.")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()

    global ENV_KEYS
    if a.env:
        ENV_KEYS |= parse_env_keys(a.env)
    if a.rendered_keys:
        ENV_KEYS |= parse_key_list(a.rendered_keys)

    values = yaml.safe_load(open(a.values)) or {}
    desc = descriptions(a.values)
    tgroups = template_group_fields(a.chart_dir) if a.chart_dir else {}
    # ROOT: always open (subcharts/global live here); enumerate top-level for docs but permit extras
    props = {}
    for k, v in values.items():
        cp = k
        if is_open(k, v) and cp not in tgroups:
            props[k] = open_map_schema(cp, v, desc)
        else:
            props[k] = build(v, cp, desc, tgroups)
    schema = {
        "$schema": "https://json-schema.org/draft-07/schema#",
        "title": f"Values schema (generated by productize-chart-env/gen-schema.py)",
        "type": "object",
        "properties": props,
        "additionalProperties": True,     # ROOT open — never reject subchart/unknown top-level keys
    }
    out = json.dumps(schema, indent=2, ensure_ascii=False) + "\n"
    if a.check and a.out:
        cur = open(a.out).read() if os.path.exists(a.out) else ""
        if cur != out:
            print(f"[gen-schema] {a.out} is STALE — regenerate", file=sys.stderr); return 1
        print(f"[gen-schema] {a.out} up to date"); return 0
    if a.out:
        open(a.out, "w").write(out)
        print(f"[gen-schema] wrote {a.out}")
    else:
        sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
