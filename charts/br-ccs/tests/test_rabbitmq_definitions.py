#!/usr/bin/env python3
"""The bundled RabbitMQ definitions give the br-ccs user the broker password and
declare sta.business.events the way br-sta does.

The definitions travel base64-encoded in a Secret, which helm-unittest cannot
decode, so they are checked here on the raw render.
"""
import base64
import json
import pathlib
import re
import subprocess
import sys

CHART = pathlib.Path(__file__).resolve().parent.parent
TEMPLATE = "templates/rabbitmq_load_definitions.yaml"


def render(*sets: str) -> subprocess.CompletedProcess:
    args = ["helm", "template", "br-ccs", str(CHART), "-s", TEMPLATE]
    for s in sets:
        args += ["--set", s]
    return subprocess.run(args, capture_output=True, text=True)


def main() -> None:
    failures = []

    out = render("rabbitmq.enabled=true",
                 "rabbitmq.authentication.password.value=broker-pass",
                 "rabbitmq.authentication.erlangCookie.value=cookie")
    if out.returncode != 0:
        sys.exit(f"render failed: {out.stderr.strip()}")
    match = re.search(r'load_definition\.json: "([^"]+)"', out.stdout)
    if not match:
        sys.exit("no load_definition.json in the render")
    defs = json.loads(base64.b64decode(match.group(1)))

    users = {u["name"]: u for u in defs["users"]}
    if users.get("br-ccs", {}).get("password") != "broker-pass":
        failures.append("br-ccs user does not carry the broker password")

    exchanges = {e["name"]: e for e in defs["exchanges"]}
    sta = exchanges.get("sta.business.events")
    if sta is None:
        failures.append("sta.business.events is not declared")
    elif (sta["type"], sta["durable"], sta["arguments"]) != (
            "topic", True, {"alternate-exchange": "sta.business.dlq"}):
        failures.append(f"sta.business.events differs from br-sta's declare: {sta}")
    # br-ccs declares its business exchange with this alternate exchange at boot;
    # any other argument fails that declare with PRECONDITION_FAILED (406).
    if exchanges.get("events", {}).get("arguments") != {"alternate-exchange": "ccs.business.dlq"}:
        failures.append("the events exchange differs from the app's declare")

    missing = render("rabbitmq.enabled=true",
                     "rabbitmq.authentication.erlangCookie.value=cookie")
    if missing.returncode == 0 or "rabbitmq.authentication.password.value is required" not in missing.stderr:
        failures.append("a bundled broker without a password still renders")

    if failures:
        sys.exit("rabbitmq definitions:\n  " + "\n  ".join(failures))

    print("ok: br-ccs user has the broker password; sta.business.events matches br-sta")


if __name__ == "__main__":
    main()
