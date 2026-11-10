#!/usr/bin/env python3
"""A key present both in brCcs.configmap and in brCcs.extraEnvVars must render
exactly once in the ConfigMap.

helm-unittest asserts on the parsed YAML, where a duplicated mapping key silently
collapses to its last value, so the duplicate is counted here on the raw render.
"""
import pathlib
import re
import subprocess
import sys

CHART = pathlib.Path(__file__).resolve().parent.parent

# Every optional passthrough key this chart skips when extraEnvVars carries it,
# plus REPORTER_URL (delivered without the retired REPORTER_ENABLED switch).
KEYS = [
    "CRM_URL", "CRM_ORGANIZATION_ID", "CRM_M2M_TARGET_SERVICE",
    "IDP_DECLARATION_ENABLED", "IDP_HOST",
    "REPORTER_TEMPLATE_ID_ACCS001", "REPORTER_TEMPLATE_NAME_ACCS001",
    "CCS_REPORTER_POLL_TOTAL_TIMEOUT_SEC",
    "BATCH_SCHEDULER_ENABLED",
    "STA_FILE_HASH_VERIFY_ENABLED", "STA_EVENT_HMAC_VERIFY_ENABLED",
    "CCS_MOVEMENT_MAX_BUSINESS_DAYS_PAST",
    "ALLOW_INSECURE_TLS", "OBJECT_STORAGE_CCS_SSE_ALGORITHM", "SWAGGER_HOST",
    "REPORTER_URL",
]


def configmap_lines(render: str) -> list[str]:
    for doc in render.split("\n---"):
        if re.search(r"^kind: ConfigMap$", doc, re.M) and re.search(r"^  name: br-ccs$", doc, re.M):
            return doc.splitlines()
    sys.exit("no br-ccs ConfigMap in the render")


def main() -> None:
    args = ["helm", "template", "br-ccs", str(CHART)]
    for key in KEYS:
        args += ["--set-string", f"brCcs.configmap.{key}=from-configmap"]
        args += ["--set-string", f"brCcs.extraEnvVars.{key}=from-extra"]

    render = subprocess.run(args, check=True, capture_output=True, text=True).stdout
    lines = configmap_lines(render)

    failures = []
    for key in KEYS:
        hits = [line for line in lines if re.match(rf"^  {key}: ", line)]
        if len(hits) != 1:
            failures.append(f"{key}: rendered {len(hits)} times")
        elif "from-extra" not in hits[0]:
            failures.append(f"{key}: extraEnvVars did not win ({hits[0].strip()})")

    if failures:
        sys.exit("duplicate or wrong env keys:\n  " + "\n  ".join(failures))

    print(f"ok: {len(KEYS)} keys rendered once, extraEnvVars wins")


if __name__ == "__main__":
    main()
