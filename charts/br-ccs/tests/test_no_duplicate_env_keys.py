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

# The render starts from an install the boot contract accepts (the checks in
# templates/_validate.tpl refuse an incomplete one).
BASE_VALUES = CHART / "tests" / "values" / "boot-contract.yaml"

# Every optional passthrough key this chart skips when extraEnvVars carries it,
# plus REPORTER_URL (delivered without the retired REPORTER_ENABLED switch) and
# the Redis TLS posture keys.
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
    "ALLOW_INSECURE_OTEL",
    "REDIS_TLS", "ALLOW_INSECURE_REDIS", "REPORTER_HTTP_TIMEOUT_SEC",
]

# Keys the boot contract validates need values it accepts. The effective value is
# the extraEnvVars one, so only that side has to pass; it must still differ from
# the configmap side so the test can tell which one rendered.
VALUES = {
    "CRM_URL": ("https://from-configmap", "https://from-extra"),
    "OBJECT_STORAGE_CCS_SSE_ALGORITHM": ("aws:kms", "AES256"),
    "REDIS_TLS": ("false", "true"),
}


def configmap_lines(render: str) -> list[str]:
    for doc in render.split("\n---"):
        if re.search(r"^kind: ConfigMap$", doc, re.M) and re.search(r"^  name: br-ccs$", doc, re.M):
            return doc.splitlines()
    sys.exit("no br-ccs ConfigMap in the render")


def main() -> None:
    args = ["helm", "template", "br-ccs", str(CHART), "-f", str(BASE_VALUES)]
    for key in KEYS:
        from_cm, from_extra = VALUES.get(key, ("from-configmap", "from-extra"))
        args += ["--set-string", f"brCcs.configmap.{key}={from_cm}"]
        args += ["--set-string", f"brCcs.extraEnvVars.{key}={from_extra}"]

    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit("helm template failed:\n" + result.stderr)
    render = result.stdout
    lines = configmap_lines(render)

    failures = []
    for key in KEYS:
        hits = [line for line in lines if re.match(rf"^  {key}: ", line)]
        if len(hits) != 1:
            failures.append(f"{key}: rendered {len(hits)} times")
        elif VALUES.get(key, ("", "from-extra"))[1] not in hits[0]:
            failures.append(f"{key}: extraEnvVars did not win ({hits[0].strip()})")

    if failures:
        sys.exit("duplicate or wrong env keys:\n  " + "\n  ".join(failures))

    print(f"ok: {len(KEYS)} keys rendered once, extraEnvVars wins")


if __name__ == "__main__":
    main()
