#!/usr/bin/env python3
"""Ephemeral licensed CI values and output scrubbing; no license bypass."""

import base64
import json
import os
from pathlib import Path
import sys
import tempfile


NAMES = ("PLUGIN_ACCESS_MANAGER_CI_LICENSE_KEY", "PLUGIN_ACCESS_MANAGER_CI_ORGANIZATION_IDS")


def create():
    values = [os.environ.get(name, "") for name in NAMES]
    if not all(value.strip() for value in values):
        raise ValueError("missing prerequisites")
    # No fallback to a shared or repository directory for credential material.
    directory = Path(os.environ["RUNNER_TEMP"])
    if not directory.is_absolute() or not directory.is_dir():
        raise ValueError("invalid RUNNER_TEMP")
    fd, name = tempfile.mkstemp(prefix="access-manager-license-", suffix=".json", dir=directory)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w") as stream:
            secrets = dict(zip(("LICENSE_KEY", "ORGANIZATION_IDS"), values))
            json.dump({part: {"secrets": secrets} for part in ("auth", "identity")}, stream)
            stream.write("\n")
    except BaseException:
        Path(name).unlink(missing_ok=True)
        raise
    # Only the path is returned to the caller, never contents.
    print(name)


def redact():
    fragments = set()
    for name in NAMES:
        value = os.environ.get(name, "")
        if value:
            fragments.update((value, json.dumps(value)[1:-1], base64.b64encode(value.encode()).decode()))
            fragments.update(value.splitlines())
            if name.endswith("ORGANIZATION_IDS"):
                fragments.update(part.strip() for part in value.split(","))
    fragments.discard("")
    for line in sys.stdin:
        for fragment in sorted(fragments, key=len, reverse=True):
            line = line.replace(fragment, "[REDACTED]")
        sys.stdout.write(line)
        sys.stdout.flush()


if __name__ == "__main__":
    try:
        if sys.argv[1:] == ["create"]:
            create()
        elif sys.argv[1:] == ["redact"]:
            redact()
        else:
            raise ValueError("invalid mode")
    except Exception:
        # Exceptions can contain the input; never print their contents/traceback.
        print("::error::Access Manager CI values processing failed; check prerequisites and RUNNER_TEMP.", file=sys.stderr)
        sys.exit(1)
