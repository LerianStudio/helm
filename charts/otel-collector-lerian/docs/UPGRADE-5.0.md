# Helm Upgrade from v4.3.x to v5.0.0

## Overview

`otel-collector-lerian` 5.0.0 moves the collector image from `0.142.0` to `0.164.0` and the `opentelemetry-collector` subchart from `0.142.0` to `0.178.1`. The subchart changed how it reads values, so two kinds of existing overrides stop working.

## Breaking changes

### 1. `service.telemetry.metrics.address` is no longer accepted

The collector 0.164.0 rejects `address` (`'service.telemetry.metrics' has invalid keys: address`), and the subchart no longer converts it. A release that overrides it keeps the key after the values merge, and every pipeline stops.

Remove the override and, if you need a different port, use `readers`:

```yaml
opentelemetry-collector:
  config:
    service:
      telemetry:
        metrics:
          level: Basic
          readers:
            - pull:
                exporter:
                  prometheus:
                    host: 0.0.0.0
                    port: 8887
```

### 2. Pinned image tags older than the subchart

The subchart renders `service.telemetry.resource.attributes` as a list, which collector 0.142.0 cannot load. Remove any `opentelemetry-collector.image.tag` pin, or move it to 0.164.0 or newer.

## No change

Component ids (`otlphttp/server`, `k8sattributes`) keep the spelling used in this chart: `rewriteDeprecatedComponentNames` is `false`, so existing pipeline overrides keep working unchanged. The OTLP wire protocol and the masking transforms are untouched.

## Command to upgrade

```bash
helm upgrade <release> oci://ghcr.io/lerianstudio/otel-collector-lerian --version 5.0.0 -n <namespace> -f values.yaml
```
