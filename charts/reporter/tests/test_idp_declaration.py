#!/usr/bin/env python3
"""Regression coverage for the Access Manager permission declaration (IDP_*) contract."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap


CHART = Path(__file__).resolve().parents[1]
BASE_VALUES = """
mongodb:
  enabled: false
rabbitmq:
  enabled: false
seaweedfs:
  enabled: false
valkey:
  enabled: false
keda:
  enabled: false
otel-collector-lerian:
  enabled: false
manager:
  image:
    tag: "3.0.1"
worker:
  image:
    tag: "3.0.1"
secrets:
  RABBITMQ_DEFAULT_PASS: "test-only"
  DATASOURCE_CRED_ENC_KEY: "46071cab3c0a47d43400741cb2a1aab25951f0d3509f373d150e96860ace057a"
  LICENSE_KEY: "test-only"
"""


def render(values: str) -> str:
    with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as fixture:
        fixture.write(textwrap.dedent(values))
        fixture_path = fixture.name
    try:
        result = subprocess.run(
            ["helm", "template", "reporter", str(CHART), "--values", fixture_path],
            env={**os.environ, "KUBECONFIG": "/dev/null"},
            text=True,
            capture_output=True,
            check=False,
        )
    finally:
        Path(fixture_path).unlink(missing_ok=True)
    if result.returncode:
        raise AssertionError(f"render failed unexpectedly:\n{result.stderr}")
    return result.stdout


def doc(output: str, kind: str, name: str) -> str:
    for d in output.split("---"):
        if f"\nkind: {kind}\n" in d and f"\n  name: {name}\n" in d:
            return d
    raise AssertionError(f"{kind}/{name} not rendered")


def count(text: str, line: str) -> int:
    return sum(1 for l in text.splitlines() if l.strip() == line)


def main() -> int:
    absent = render(BASE_VALUES)
    manager_cm = doc(absent, "ConfigMap", "reporter-manager")
    if count(manager_cm, 'IDP_DECLARATION_ENABLED: "false"') != 1 or "IDP_HOST:" in manager_cm:
        raise AssertionError("defaults: expected only IDP_DECLARATION_ENABLED=false in the manager ConfigMap")
    if "IDP_" in doc(absent, "ConfigMap", "reporter-worker"):
        raise AssertionError("defaults: IDP_* leaked into the worker ConfigMap")

    on = render(BASE_VALUES + """
manager:
  configmap:
    IDP_DECLARATION_ENABLED: "true"
    IDP_HOST: "http://identity.invalid:4001"
secrets:
  RABBITMQ_DEFAULT_PASS: "test-only"
  DATASOURCE_CRED_ENC_KEY: "46071cab3c0a47d43400741cb2a1aab25951f0d3509f373d150e96860ace057a"
  LICENSE_KEY: "test-only"
  IDP_M2M_CLIENT_ID: "test-client"
  IDP_M2M_CLIENT_SECRET: "test-secret"
""")
    manager_cm = doc(on, "ConfigMap", "reporter-manager")
    if count(manager_cm, 'IDP_DECLARATION_ENABLED: "true"') != 1 or count(manager_cm, 'IDP_HOST: "http://identity.invalid:4001"') != 1:
        raise AssertionError("enabled: gate/host not rendered exactly once in the manager ConfigMap")
    manager_secret = doc(on, "Secret", "reporter-manager")
    for key in ("IDP_M2M_CLIENT_ID:", "IDP_M2M_CLIENT_SECRET:"):
        if sum(1 for l in manager_secret.splitlines() if l.strip().startswith(key)) != 1:
            raise AssertionError(f"enabled: {key} not rendered exactly once in the manager Secret")
    if "IDP_M2M_" in doc(on, "Secret", "reporter-worker"):
        raise AssertionError("enabled: the declaration client pair leaked into the worker Secret")

    legacy = render(BASE_VALUES + """
manager:
  extraEnvVars:
    IDP_DECLARATION_ENABLED: "true"
    IDP_HOST: "http://legacy.invalid:4001"
""")
    manager_cm = doc(legacy, "ConfigMap", "reporter-manager")
    if count(manager_cm, 'IDP_HOST: "http://legacy.invalid:4001"') != 1 or count(manager_cm, 'IDP_DECLARATION_ENABLED: "true"') != 1:
        raise AssertionError("legacy extraEnvVars: keys missing or duplicated in the manager ConfigMap")

    globl = render(BASE_VALUES + """
global:
  idp:
    host: "http://global.invalid:4001"
""")
    if count(doc(globl, "ConfigMap", "reporter-manager"), 'IDP_HOST: "http://global.invalid:4001"') != 1:
        raise AssertionError("global.idp.host not rendered in the manager ConfigMap")

    print("IDP declaration matrix passed: defaults, enabled (manager only), legacy extraEnvVars, global host")
    return 0


if __name__ == "__main__":
    sys.exit(main())
