# Helm Upgrade from v1.0.0 to v1.0.1

## Topics

- **[Overview](#overview)**
- **[New observability configuration](#new-observability-configuration)**
  - [1. ALLOW_INSECURE_OTEL environment variable](#1-allow_insecure_otel-environment-variable)
  - [2. Configuration precedence](#2-configuration-precedence)
  - [3. Default behavior](#3-default-behavior)
- **[Migration scenarios](#migration-scenarios)**
  - [Scenario 1: Telemetry disabled (default)](#scenario-1-telemetry-disabled-default)
  - [Scenario 2: Telemetry enabled with node-local collector](#scenario-2-telemetry-enabled-with-node-local-collector)
  - [Scenario 3: Custom ALLOW_INSECURE_OTEL reason](#scenario-3-custom-allow_insecure_otel-reason)
  - [Scenario 4: Explicit refusal of insecure OTLP](#scenario-4-explicit-refusal-of-insecure-otlp)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Chart version 1.0.1 is a **patch release** that adds configuration support for the `ALLOW_INSECURE_OTEL` environment variable. This variable controls whether the application accepts plaintext OTLP exports to a node-local collector when telemetry is enabled in production environments.

**No breaking changes.** Existing installations with telemetry disabled are unaffected. Installations with telemetry enabled gain automatic support for the plaintext node-local collector pattern without requiring configuration changes.

| Aspect | v1.0.0 | v1.0.1 |
|--------|--------|--------|
| Chart version | 1.0.0 | 1.0.1 |
| App version | 1.1.2 | 1.1.2 (unchanged) |
| Breaking changes | N/A | None |
| New configuration fields | N/A | `global.observability.allowInsecureOtel`, `brCcs.configmap.ALLOW_INSECURE_OTEL` |
| New environment variables | N/A | `ALLOW_INSECURE_OTEL` (conditional) |

## New observability configuration

### 1. ALLOW_INSECURE_OTEL environment variable

When `global.observability.enabled: true` (or the legacy `brCcs.configmap.ENABLE_TELEMETRY: "true"`), the chart configures the pod to export OTLP telemetry to `$(HOST_IP):4317` — a plaintext connection to the collector on the pod's own node. The `lib-observability` library (v1.1.0+) refuses plaintext OTLP exports in production unless the `ALLOW_INSECURE_OTEL` environment variable contains a reason string explaining why the insecure transport is acceptable.

Chart 1.0.1 automatically sets this variable when telemetry is enabled, preventing application startup failures in production environments using the node-local collector pattern.

| Environment Variable | Purpose | Set By |
|---------------------|---------|--------|
| `ALLOW_INSECURE_OTEL` | Reason string allowing plaintext OTLP to node-local collector | Chart (ConfigMap + Deployment) |

### 2. Configuration precedence

The chart resolves the `ALLOW_INSECURE_OTEL` value using the following precedence chain:

1. **`brCcs.extraEnvVars.ALLOW_INSECURE_OTEL`** — legacy direct environment variable override (highest priority; chart skips its own entry)
2. **`brCcs.configmap.ALLOW_INSECURE_OTEL`** — component-level configuration
3. **`global.observability.allowInsecureOtel`** — umbrella-level configuration for multi-component deployments
4. **Chart default** — `"node-local collector on the pod's own node"` (lowest priority)

**Null vs empty string semantics:**

- **`null`** (or omitted key) — unset; falls through to the next precedence level
- **`""`** (empty string) — explicit refusal; stops the precedence chain and prevents plaintext OTLP (application refuses to start with telemetry enabled in production)
- **`"false"`** — treated as a reason string by `lib-observability` v1.1.0, **not** as a refusal; use `""` to refuse

> **Important:** Setting `allowInsecureOtel: ""` explicitly refuses the plaintext exporter. The application will fail to start in production if telemetry is enabled and the collector endpoint has no scheme (the node-local pattern). Use this only when migrating to a secure collector endpoint.

### 3. Default behavior

**Before (v1.0.0):**

The chart did not set `ALLOW_INSECURE_OTEL`. Applications using `lib-observability` v1.1.0+ with telemetry enabled in production would fail to start with an error about refusing insecure OTLP exports.

**After (v1.0.1):**

The chart automatically sets `ALLOW_INSECURE_OTEL` when telemetry is enabled, using the resolved value from the precedence chain. The ConfigMap includes the key only when a modeled setting is present (component or global level); otherwise the Deployment sets it directly with the chart default.

**ConfigMap rendering (v1.0.1):**

```yaml
# Rendered only when brCcs.configmap.ALLOW_INSECURE_OTEL or 
# global.observability.allowInsecureOtel is explicitly set (non-null)
data:
  ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
```

**Deployment environment (v1.0.1):**

```yaml
# Always rendered when telemetry is enabled, unless brCcs.extraEnvVars 
# already provides ALLOW_INSECURE_OTEL
env:
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "$(HOST_IP):4317"
  - name: ALLOW_INSECURE_OTEL
    value: "node-local collector on the pod's own node"
```

## Migration scenarios

### Scenario 1: Telemetry disabled (default)

**Current configuration (v1.0.0):**

```yaml
global:
  observability:
    enabled: false  # or omitted (default)
```

**Action required:** None. The `ALLOW_INSECURE_OTEL` variable is not rendered when telemetry is disabled.

**Result after upgrade:** No configuration changes; no new environment variables.

---

### Scenario 2: Telemetry enabled with node-local collector

**Current configuration (v1.0.0):**

```yaml
global:
  observability:
    enabled: true
    otlpEndpoint: ""  # or omitted; chart uses $(HOST_IP):4317
    deploymentEnvironment: "production"
```

**Known issue in v1.0.0:** Application fails to start in production with error about refusing insecure OTLP.

**Action required:** Upgrade to v1.0.1. No values changes needed.

**Result after upgrade:** Chart automatically sets `ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"` in the Deployment environment. Application starts successfully.

---

### Scenario 3: Custom ALLOW_INSECURE_OTEL reason

**Use case:** Organization policy requires a specific justification string for plaintext OTLP exports.

**Recommended configuration (v1.0.1):**

```yaml
global:
  observability:
    enabled: true
    deploymentEnvironment: "production"
    allowInsecureOtel: "approved by security team ticket SEC-12345 for node-local daemonset collector"
```

**Alternative component-level override:**

```yaml
brCcs:
  configmap:
    ALLOW_INSECURE_OTEL: "approved by security team ticket SEC-12345 for node-local daemonset collector"
```

**Result:** The custom reason string is set in both ConfigMap and Deployment environment, satisfying `lib-observability` requirements while providing audit trail.

---

### Scenario 4: Explicit refusal of insecure OTLP

**Use case:** Migrating to a secure collector endpoint (e.g., `https://collector.example.com:4318`) and want to ensure no plaintext fallback occurs.

**Step 1:** Configure secure collector endpoint and explicitly refuse insecure transport:

```yaml
global:
  observability:
    enabled: true
    otlpEndpoint: "https://collector.example.com:4318"
    deploymentEnvironment: "production"
    allowInsecureOtel: ""  # explicit refusal
```

**Step 2:** Upgrade to v1.0.1:

```bash
helm upgrade br-ccs oci://registry-1.docker.io/lerianstudio/br-ccs-helm \
  --version 1.0.1 -n br-ccs \
  -f values.yaml
```

**Step 3:** Verify the application starts successfully with the secure endpoint:

```bash
kubectl -n br-ccs logs deployment/br-ccs | grep -i otel
kubectl -n br-ccs get pods -l app.kubernetes.io/name=br-ccs
```

> **Warning:** Setting `allowInsecureOtel: ""` with a plaintext `otlpEndpoint` (or the default node-local pattern) will cause application startup failure in production. Only use explicit refusal after migrating to a secure collector endpoint.

**Result:** ConfigMap contains `ALLOW_INSECURE_OTEL: ""`, Deployment inherits it, and the application refuses any plaintext OTLP export attempts.

## Preview changes before upgrading

```bash
helm diff upgrade br-ccs oci://registry-1.docker.io/lerianstudio/br-ccs-helm --version 1.0.1 -n br-ccs
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-ccs oci://registry-1.docker.io/lerianstudio/br-ccs-helm --version 1.0.1 -n br-ccs
```
