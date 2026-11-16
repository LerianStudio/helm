#!/usr/bin/env python3
"""Regression coverage for the streaming env the chart hands Reporter >= 4.10.0.

The app publishes every business event to Kafka. In single-tenant mode it dials
STREAMING_KAFKA_BROKERS and refuses to boot with streaming on and that key empty.
It also refuses to boot when STREAMING_CLOUDEVENTS_SOURCE is anything but the roster
name "reporter", whether or not streaming is enabled.
"""

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
    tag: "4.10.0"
worker:
  image:
    tag: "4.10.0"
secrets:
  RABBITMQ_DEFAULT_PASS: "test-only"
  DATASOURCE_CRED_ENC_KEY: "46071cab3c0a47d43400741cb2a1aab25951f0d3509f373d150e96860ace057a"
  LICENSE_KEY: "test-only"
"""
COMPONENTS = ("reporter-manager", "reporter-worker")


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


def values_of(text: str, key: str) -> list:
    prefix = f"{key}:"
    return [l.strip()[len(prefix):].strip() for l in text.splitlines() if l.strip().startswith(prefix)]


def expect(output: str, key: str, want, case: str) -> None:
    for name in COMPONENTS:
        got = values_of(doc(output, "ConfigMap", name), key)
        exp = [] if want is None else [f'"{want}"']
        if got != exp:
            raise AssertionError(f"{case}: {name} {key} = {got}, want {exp}")


def main() -> int:
    off = render(BASE_VALUES)
    expect(off, "STREAMING_ENABLED", "false", "streaming off")
    expect(off, "STREAMING_KAFKA_BROKERS", None, "streaming off")
    expect(off, "STREAMING_CLOUDEVENTS_SOURCE", None, "streaming off")

    single = render(BASE_VALUES + """
global:
  streaming:
    enabled: true
    brokers: "redpanda.invalid:9092"
""")
    expect(single, "STREAMING_BROKERS", "redpanda.invalid:9092", "single-tenant")
    expect(single, "STREAMING_KAFKA_BROKERS", "redpanda.invalid:9092", "single-tenant")
    expect(single, "STREAMING_CLOUDEVENTS_SOURCE", "reporter", "single-tenant")

    override = render(BASE_VALUES + """
global:
  streaming:
    enabled: true
    brokers: "redpanda.invalid:9092"
common:
  configmap:
    STREAMING_KAFKA_BROKERS: "kafka-a.invalid:9092,kafka-b.invalid:9092"
""")
    expect(override, "STREAMING_KAFKA_BROKERS", "kafka-a.invalid:9092,kafka-b.invalid:9092", "common override")

    component = render(BASE_VALUES + """
global:
  streaming:
    enabled: true
    brokers: "redpanda.invalid:9092"
manager:
  extraEnvVars:
    STREAMING_KAFKA_BROKERS: "manager-only.invalid:9092"
""")
    if values_of(doc(component, "ConfigMap", "reporter-manager"), "STREAMING_KAFKA_BROKERS") != ["manager-only.invalid:9092"]:
        raise AssertionError("component override: manager must carry only its own STREAMING_KAFKA_BROKERS, once")
    if values_of(doc(component, "ConfigMap", "reporter-worker"), "STREAMING_KAFKA_BROKERS") != ['"redpanda.invalid:9092"']:
        raise AssertionError("component override: worker must keep the global brokers")

    multi = render(BASE_VALUES + """
global:
  streaming:
    enabled: true
    brokers: "redpanda.invalid:9092"
  multiTenant:
    enabled: true
""")
    expect(multi, "STREAMING_KAFKA_BROKERS", None, "multi-tenant")

    legacy_source = render(BASE_VALUES + """
global:
  streaming:
    enabled: true
    brokers: "redpanda.invalid:9092"
common:
  configmap:
    STREAMING_CLOUDEVENTS_SOURCE: "custom"
""")
    expect(legacy_source, "STREAMING_CLOUDEVENTS_SOURCE", "custom", "explicit source wins")

    print("streaming env matrix passed: off, single-tenant, common override, component override, multi-tenant, explicit source")
    return 0


if __name__ == "__main__":
    sys.exit(main())
