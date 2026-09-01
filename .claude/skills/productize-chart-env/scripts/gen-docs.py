#!/usr/bin/env python3
"""
gen-docs.py — generate a values README parameter table from `# --` annotations.

Self-contained (no helm-docs binary). Parses values.yaml line-by-line (PyYAML strips
comments, so we can't use it), tracks indentation to build dotted key paths, and pairs
each `# --` comment block with the key beneath it. Emits a Markdown table:
`| Key | Type | Default | Description |`, grouped by `# @section` markers.

Annotation dialect (helm-docs compatible subset):
  # -- (type) Description text          # type hint optional, e.g. (int) (bool) (tpl/string)
  # continuation line of the description
  # @section Section Title              # starts a new table section
  # @default -- <shown default>         # override the displayed default
  # @ignore                             # skip the next key

Usage:
  gen-docs.py --values charts/br-ccs/values.yaml [--out charts/br-ccs/README.params.md]
  gen-docs.py --values charts/br-ccs/values.yaml --check   # exit 1 if --out would change
"""
import argparse, re, sys, io


def infer_type(v):
    s = v.strip()
    if s in ("{}",) or s.endswith(":"):
        return "object"
    if s in ("[]",):
        return "list"
    if s in ("true", "false"):
        return "bool"
    if re.fullmatch(r"-?\d+", s):
        return "int"
    if re.fullmatch(r"-?\d+\.\d+", s):
        return "float"
    return "string"


def parse(values_path):
    rows = []            # (section, key, type, default, desc)
    section = "Parameters"
    stack = []           # (indent, key)
    pending_desc = []
    pending_type = None
    pending_default = None
    ignore_next = False

    for raw in open(values_path):
        line = raw.rstrip("\n")
        stripped = line.strip()
        indent = len(line) - len(line.lstrip(" "))

        # comment lines
        m = re.match(r"^\s*#\s?(.*)$", line)
        if m:
            c = m.group(1)
            ms = re.match(r"@section\s+(.*)$", c)
            if ms:
                section = ms.group(1).strip(); continue
            if re.match(r"@ignore\b", c):
                ignore_next = True; continue
            md = re.match(r"@default\s+--\s+(.*)$", c)
            if md:
                pending_default = md.group(1).strip(); continue
            md2 = re.match(r"--\s?(.*)$", c)
            if md2:
                body = md2.group(1)
                mt = re.match(r"\(([^)]+)\)\s*(.*)$", body)
                if mt:
                    pending_type = mt.group(1); body = mt.group(2)
                pending_desc = [body.strip()]
                continue
            # a continuation of a `# --` block (plain comment right after)
            if pending_desc:
                pending_desc.append(c.strip())
            continue

        # blank line resets a dangling annotation only if no key followed
        if not stripped:
            continue

        # a `key:` (or `key: value`) line
        mk = re.match(r"^(\s*)([A-Za-z0-9_.\-]+):\s?(.*)$", line)
        if not mk:
            pending_desc, pending_type, pending_default = [], None, None
            continue
        key = mk.group(2)
        val = mk.group(3)
        # maintain indent stack → dotted path
        while stack and stack[-1][0] >= indent:
            stack.pop()
        stack.append((indent, key))
        path = ".".join(k for _, k in stack)

        if ignore_next:
            ignore_next = False
            pending_desc, pending_type, pending_default = [], None, None
            continue
        if pending_desc:
            # An annotated key with no inline value is a mapping/parent (children follow) →
            # type "object", matching the "{}" default below (not "string" from an empty val).
            typ = pending_type or (infer_type(val) if val.strip() else "object")
            default = pending_default if pending_default is not None else (val if val.strip() else "{}")
            desc = " ".join(pending_desc).strip()
            rows.append((section, path, typ, default, desc))
        pending_desc, pending_type, pending_default = [], None, None
    return rows


def render(rows):
    out = io.StringIO()
    out.write("# Parameters\n\n")
    sections = {}
    order = []
    for sec, *rest in rows:
        if sec not in sections:
            sections[sec] = []; order.append(sec)
        sections[sec].append(rest)
    for sec in order:
        out.write(f"## {sec}\n\n")
        out.write("| Key | Type | Default | Description |\n|-----|------|---------|-------------|\n")
        for key, typ, default, desc in sections[sec]:
            # Escape pipes in EVERY cell — a `|` in a type (e.g. `enum: all|split`),
            # default, or description otherwise reads as a column separator and shifts
            # the whole row. (The `(enum: a|b)` annotation must keep its pipe for
            # gen-schema, so the escaping has to happen here at render time.)
            d = default.replace("|", "\\|")
            t = typ.replace("|", "\\|")
            ds = desc.replace("|", "\\|")
            out.write(f"| `{key}` | {t} | `{d}` | {ds} |\n")
        out.write("\n")
    # Exactly one trailing newline (no blank line at EOF → passes `git diff --check`).
    return out.getvalue().rstrip("\n") + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--values", required=True)
    ap.add_argument("--out", default=None)
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    md = render(parse(a.values))
    if a.check and a.out:
        cur = open(a.out).read() if __import__("os").path.exists(a.out) else ""
        if cur != md:
            print(f"[gen-docs] {a.out} is STALE — regenerate", file=sys.stderr); return 1
        print(f"[gen-docs] {a.out} up to date"); return 0
    if a.out:
        open(a.out, "w").write(md)
        print(f"[gen-docs] wrote {a.out} ({md.count(chr(10))} lines)")
    else:
        sys.stdout.write(md)
    return 0


if __name__ == "__main__":
    sys.exit(main())
