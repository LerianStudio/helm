#!/usr/bin/env python3
"""Write Access Manager's runtime-only license overlay; stdout is its path only."""
import json
import os
from pathlib import Path
import sys
import tempfile


def main():
    values = {}
    missing = []
    for component in ("auth", "identity"):
        secrets = {}
        for field in ("LICENSE_KEY", "ORGANIZATION_IDS"):
            name = f"IT_{component.upper()}_{field}"
            value = os.environ.get(name, "")
            if not value.strip() or (field == "ORGANIZATION_IDS" and
                                     any(not org.strip() for org in value.split(","))):
                missing.append(name)
            secrets[field] = value
        values[component] = {"secrets": secrets}

    if missing:
        print("::error::[plugin-access-manager] Deep install requires licensed CI credentials: "
              + ", ".join(missing)
              + ". Configure the matching HELM_IT_* Actions secrets. "
              "Do not use sample licenses or disable authorization.", file=sys.stderr)
        return 1

    # mkstemp creates mode 0600 atomically. JSON is valid Helm values YAML and
    # safely preserves quotes/newlines without shell interpolation or --set.
    fd, path = tempfile.mkstemp(prefix="helm-it-license-", suffix=".json")
    try:
        with os.fdopen(fd, "w") as out:
            json.dump(values, out)
    except BaseException:
        Path(path).unlink(missing_ok=True)
        raise
    print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
