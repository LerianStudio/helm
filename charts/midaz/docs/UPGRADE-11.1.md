<!-- {% raw %} -->
# Helm Upgrade from v11.0.0 to v11.1.0

## Topics

- **[Features](#features)**
  - [1. OpenTelemetry Inbound Trace Context Trust Control](#1-opentelemetry-inbound-trace-context-trust-control)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. OpenTelemetry Inbound Trace Context Trust Control

**Who is affected:** every release that uses distributed tracing (observability enabled). This change adds explicit control over whether the ledger and tracer services trust W3C trace context headers from inbound requests.

#### What Changed

A new environment variable `OTEL_TRUST_INBOUND_TRACE_CONTEXT` has been added to both the ledger and tracer components, with a default value of `"false"`.

| Component | Setting | v11.0.0 | v11.1.0 |
|-----------|---------|---------|---------|
| `ledger` | `OTEL_TRUST_INBOUND_TRACE_CONTEXT` | (not present) | `"false"` |
| `tracer` | `OTEL_TRUST_INBOUND_TRACE_CONTEXT` | (not present) | `"false"` |

**Before (v11.0.0):**

The ledger and tracer ConfigMaps did not include this setting. The OpenTelemetry SDK's default behavior applied, which typically trusts inbound trace context.

**After (v11.1.0):**

```yaml
ledger:
  configmap:
    OTEL_TRUST_INBOUND_TRACE_CONTEXT: "false"

tracer:
  configmap:
    OTEL_TRUST_INBOUND_TRACE_CONTEXT: "false"
```

#### Why This Matters

The `OTEL_TRUST_INBOUND_TRACE_CONTEXT` setting controls whether your services accept and propagate trace IDs and sampling decisions from incoming HTTP headers (`traceparent`, `tracestate`).

- **Security boundary:** When set to `"false"` (the new default), the service generates its own trace IDs and makes its own sampling decisions, preventing untrusted callers from manipulating trace data or forcing expensive sampling
- **Trusted environments:** When set to `"true"`, the service accepts trace context from callers, which is appropriate when all traffic comes through a trusted API gateway, service mesh, or internal network where every caller is authenticated and authorized
- **Trace continuity:** In a trusted environment, setting this to `"true"` allows end-to-end traces to span from external clients through your services

The conservative default of `"false"` protects against:
- Malicious clients forcing high-cardinality trace IDs that could overwhelm your observability backend
- Unauthorized sampling decisions that bypass your sampling policies
- Trace injection attacks in multi-tenant environments

#### Configuration Reference

| Flag | Default | Description |
|------|---------|-------------|
| `ledger.configmap.OTEL_TRUST_INBOUND_TRACE_CONTEXT` | `"false"` | Trust W3C trace context headers from callers to the ledger service |
| `tracer.configmap.OTEL_TRUST_INBOUND_TRACE_CONTEXT` | `"false"` | Trust W3C trace context headers from callers to the tracer service |

#### Action Required

**For most deployments:** No action required. The default `"false"` is the secure choice for internet-facing or multi-tenant deployments.

**For deployments behind a trusted gateway or service mesh:**

If your Midaz services run behind an API gateway (e.g., Kong, Envoy, NGINX) or service mesh (e.g., Istio, Linkerd) that already authenticates and authorizes all callers, and you want end-to-end trace continuity from external requests, set this to `"true"`:

```yaml
ledger:
  configmap:
    OTEL_TRUST_INBOUND_TRACE_CONTEXT: "true"

tracer:
  configmap:
    OTEL_TRUST_INBOUND_TRACE_CONTEXT: "true"
```

> **Warning:** Only enable this in environments where **every** caller reaching the ledger or tracer is trusted. In a multi-tenant SaaS deployment or any environment with untrusted external clients, keep the default `"false"`.

> **Note:** This setting does not affect outbound trace propagation. The ledger and tracer always propagate trace context to their downstream dependencies (PostgreSQL, MongoDB, RabbitMQ, etc.) regardless of this flag.

#### Template Changes

The ConfigMap templates for both ledger and tracer now include the new environment variable with inline documentation:

**ledger ConfigMap (charts/midaz/templates/ledger/configmap.yaml):**

```yaml
# Set "true" only when every caller reaching the service is trusted (behind a gateway or
# mesh); otherwise callers choose the trace id and the sampling decision.
OTEL_TRUST_INBOUND_TRACE_CONTEXT: {{ $cm.OTEL_TRUST_INBOUND_TRACE_CONTEXT | default "false" | quote }}
```

**tracer ConfigMap (charts/midaz/templates/tracer/configmap.yaml):**

```yaml
# Set "true" only when every caller reaching the service is trusted (behind a gateway or
# mesh); otherwise callers choose the trace id and the sampling decision.
OTEL_TRUST_INBOUND_TRACE_CONTEXT: {{ $cm.OTEL_TRUST_INBOUND_TRACE_CONTEXT | default "false" | quote }}
```

The upgrade will restart both the ledger and tracer pods to apply the new ConfigMap. No data loss or downtime beyond the normal rolling update is expected.

## Configuration Reference

The following new configuration fields are available in `values.yaml`:

```yaml
ledger:
  configmap:
    # Trust inbound W3C trace context. "true" only when every caller is trusted
    # (behind a gateway or mesh).
    OTEL_TRUST_INBOUND_TRACE_CONTEXT: "false"

tracer:
  configmap:
    # Trust inbound W3C trace context. "true" only when every caller is trusted
    # (behind a gateway or mesh).
    OTEL_TRUST_INBOUND_TRACE_CONTEXT: "false"
```

Both fields default to `"false"` and can be overridden in your custom `values.yaml` or via `--set`:

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.1.0 \
  --set ledger.configmap.OTEL_TRUST_INBOUND_TRACE_CONTEXT="true" \
  --set tracer.configmap.OTEL_TRUST_INBOUND_TRACE_CONTEXT="true"
```

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.1.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.1.0
```
<!-- {% endraw %} -->
