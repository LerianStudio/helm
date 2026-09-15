#!/usr/bin/env python3
"""Regression coverage for the opt-in Reporter CRM datasource contract."""

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
"""
CRM_CONFIG = """
common:
  configmap:
    DATASOURCE_CRM_CONFIG_NAME: "plugin_crm"
    DATASOURCE_CRM_TYPE: "mongodb"
    DATASOURCE_CRM_HOST: "crm.invalid"
    DATASOURCE_CRM_PORT: "27017"
    DATASOURCE_CRM_DATABASE: "crm"
    DATASOURCE_CRM_USER: "reporter"
    DATASOURCE_CRM_MIDAZ_ORGANIZATION_ID: "11111111-1111-4111-8111-111111111111"
"""
CRM_SECRETS = """
secrets:
  RABBITMQ_DEFAULT_PASS: "test-only"
  DATASOURCE_CRED_ENC_KEY: "46071cab3c0a47d43400741cb2a1aab25951f0d3509f373d150e96860ace057a"
  DATASOURCE_CRM_PASSWORD: "test-only-crm-password"
  CRYPTO_HASH_SECRET_KEY_CRM: "test-only-hash-key"
  CRYPTO_ENCRYPT_SECRET_KEY_CRM: "test-only-encrypt-key"
"""


def render(values: str) -> subprocess.CompletedProcess[str]:
    with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as fixture:
        fixture.write(textwrap.dedent(values))
        fixture_path = fixture.name
    try:
        return subprocess.run(
            ["helm", "template", "reporter", str(CHART), "--values", fixture_path],
            env={**os.environ, "KUBECONFIG": "/dev/null"},
            text=True,
            capture_output=True,
            check=False,
        )
    finally:
        Path(fixture_path).unlink(missing_ok=True)


def assert_success(result: subprocess.CompletedProcess[str], case: str) -> None:
    if result.returncode:
        raise AssertionError(f"{case} failed unexpectedly:\n{result.stderr}")


def manifest_kind(output: str, kind: str) -> list[str]:
    return [doc for doc in output.split("---") if f"\nkind: {kind}\n" in doc]


def main() -> int:
    absent = render(BASE_VALUES)
    assert_success(absent, "CRM absent")
    assert "DATASOURCE_CRM_CONFIG_NAME:" not in absent.stdout

    incomplete = render(BASE_VALUES + CRM_CONFIG.replace(
        '    DATASOURCE_CRM_MIDAZ_ORGANIZATION_ID: "11111111-1111-4111-8111-111111111111"\n',
        "",
    ) + CRM_SECRETS)
    if incomplete.returncode == 0:
        raise AssertionError("CRM without MIDAZ_ORGANIZATION_ID rendered successfully")
    if "DATASOURCE_CRM_MIDAZ_ORGANIZATION_ID" not in incomplete.stderr:
        raise AssertionError(f"CRM guard returned an unexpected error:\n{incomplete.stderr}")

    missing_inline_secret = render(BASE_VALUES + CRM_CONFIG)
    if missing_inline_secret.returncode == 0:
        raise AssertionError("CRM without chart-managed secrets rendered successfully")
    if "DATASOURCE_CRM_PASSWORD" not in missing_inline_secret.stderr:
        raise AssertionError(
            f"CRM secret guard returned an unexpected error:\n{missing_inline_secret.stderr}"
        )

    misplaced = render(BASE_VALUES + """
common:
  configmap:
    CRYPTO_HASH_SECRET_KEY_CRM: "test-only-hash-key"
manager:
  useExistingSecret: true
  existingSecretName: "manager-crm-secret"
worker:
  useExistingSecret: true
  existingSecretName: "worker-crm-secret"
""")
    if misplaced.returncode == 0:
        raise AssertionError("CRM hash key in common.configmap rendered successfully")
    if "must not be set in common.configmap" not in misplaced.stderr:
        raise AssertionError(f"misplaced CRM secret returned an unexpected error:\n{misplaced.stderr}")

    inline = render(BASE_VALUES + CRM_CONFIG + CRM_SECRETS)
    assert_success(inline, "complete CRM with chart-managed secrets")
    configmaps = manifest_kind(inline.stdout, "ConfigMap")
    secrets = manifest_kind(inline.stdout, "Secret")
    if sum("DATASOURCE_CRM_CONFIG_NAME:" in doc for doc in configmaps) != 2:
        raise AssertionError("complete CRM was not emitted to both ConfigMaps")
    sensitive = (
        "DATASOURCE_CRM_PASSWORD:",
        "CRYPTO_HASH_SECRET_KEY_CRM:",
        "CRYPTO_ENCRYPT_SECRET_KEY_CRM:",
    )
    if any(key in doc for doc in configmaps for key in sensitive):
        raise AssertionError("CRM secret key rendered in a ConfigMap")
    for key in sensitive:
        if sum(key in doc for doc in secrets) != 2:
            raise AssertionError(f"{key} was not emitted to both chart-managed Secrets")

    external = render(BASE_VALUES + CRM_CONFIG + """
manager:
  useExistingSecret: true
  existingSecretName: "manager-crm-secret"
worker:
  useExistingSecret: true
  existingSecretName: "worker-crm-secret"
""")
    assert_success(external, "complete CRM with external Secrets")
    if "manager-crm-secret" not in external.stdout or "worker-crm-secret" not in external.stdout:
        raise AssertionError("external CRM Secret references were not preserved")

    print("CRM regression matrix passed: absent, incomplete, missing inline secret, misplaced secret, inline secrets, external secrets")
    return 0


if __name__ == "__main__":
    sys.exit(main())
