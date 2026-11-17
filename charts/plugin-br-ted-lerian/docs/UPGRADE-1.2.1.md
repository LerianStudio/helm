<!-- {% raw %} -->
# Helm Upgrade from v1.2.0 to v1.2.1

## Topics

- **[Overview](#overview)**
- **[Dependency Update](#dependency-update)**
- **[New Configuration: ALLOW_INSECURE_OTEL](#new-configuration-allow_insecure_otel)**
  - [What changed](#what-changed)
  - [Why it matters](#why-it-matters)
  - [How to configure](#how-to-configure)
  - [Migration guidance](#migration-guidance)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Overview

This is a patch release that updates the `lerian-common-helm` dependency and introduces a new OpenTelemetry security configuration option.

| Setting | v1.2.0 | v1.2.1 |
|---------|--------|--------|
| Chart version | `1.2.0` | `1.2.1` |
| App version | `1.0.0-beta.86` | `1.0.0-beta.86` |
| lerian-common-helm dependency | `2.6.1` | `2.7.0` |

**What changed:**
- `lerian-common-helm` dependency upgraded from `2.6.1` to `2.7.0`
- New `ALLOW_INSECURE_OTEL` configuration option for OpenTelemetry plaintext transport
- New `global.observability.allowInsecureOtel` field for environment-wide OTEL security settings
- ConfigMap template now renders `ALLOW_INSECURE_OTEL` with fallback logic
- Deployment template now passes `ALLOW_INSECURE_OTEL` to the `lerian-common.otel.podEnv` helper

**What stayed the same:**
- Application version remains `1.0.0-beta.86`
- All existing values.yaml defaults unchanged
- Review legacy refusals and existing Secrets before adopting the new default reason (see migration guidance)

**Impact:** This changes chart wiring, not the application binary or its existing transport-security policy. With `plugin-br-ted-lerian.otel.enabled: true`, the chart adds a plaintext allowance unless a modeled value or supported legacy route takes precedence. Review this security-policy change before upgrading; do not treat the fallback reason as approval of your network topology. An explicit empty legacy Secret value or a refusal in an existing external Secret is not preserved by the new node-local fallback.

---

## Dependency Update

The `lerian-common-helm` dependency has been updated from version `2.6.1` to `2.7.0`. The `lerian-common.otel.podEnv` helper already exists in `2.6.1`; `2.7.0` extends it with `ALLOW_INSECURE_OTEL` resolution. The released chart includes its locked dependencies; do not install the library as an application.

| Dependency | v1.2.0 | v1.2.1 |
|------------|--------|--------|
| lerian-common-helm | `2.6.1` | `2.7.0` |

**Impact:** Review the new transport allowance and legacy precedence below. Application and datastore image pins are unchanged by this patch.

---

## New Configuration: ALLOW_INSECURE_OTEL

### What changed

The chart now supports configuring `ALLOW_INSECURE_OTEL`, an environment variable that controls whether the application permits plaintext OpenTelemetry transport to the node-local collector in production environments.

**Before (v1.2.0):**

The `ALLOW_INSECURE_OTEL` variable could only be set via:
- `plugin-br-ted-lerian.extraEnvVars` (manual env entry)
- `plugin-br-ted-lerian.secrets.ALLOW_INSECURE_OTEL` (secret-based)

**After (v1.2.1):**

The variable is now a first-class configuration option with three levels of precedence:

1. `plugin-br-ted-lerian.configmap.ALLOW_INSECURE_OTEL` (component-specific)
2. `global.observability.allowInsecureOtel` (environment-wide)
3. Default: `"node-local collector on the pod's own node"` (automatic fallback)

When an explicit component or global value is set, the ConfigMap includes a string value, for example (rendered output, not a values-file fragment):

```yaml
data:
  ALLOW_INSECURE_OTEL: "example explicit component or global reason"
```

The Deployment passes root context and the component ConfigMap into `lerian-common.otel.podEnv`. It calls that helper only when `plugin-br-ted-lerian.otel.enabled` is true. The node-local fallback is emitted as explicit container `env`, not in the ConfigMap. `global.observability.enabled` or `configmap.ENABLE_TELEMETRY` can enable telemetry without enabling this node-local helper; then the configured endpoint and any explicit allowance come from the ConfigMap. Explicit container `env` wins over `envFrom`, so with the node-local helper on, its `http://$(HOST_IP):4317` endpoint overrides a global or ConfigMap endpoint.

### Why it matters

When the component node-local switch is enabled, the chart emits `http://$(HOST_IP):4317` for the OTLP/gRPC exporter (the `http://` scheme selects plaintext; it does not switch to OTLP/HTTP). The source tag matching the default image tag uses `lib-observability/v4` `v4.9.0`, whose existing production-like environment policy rejects insecure telemetry without an allowance. Anonymous access to the application image was refused during review, so its OCI revision could not be tied to that source tag. Source inspection is not a verified image boot.

**Without an allowance:** The inspected library source returns an initialization error for enabled insecure telemetry in a strict environment. This policy predates the chart patch; the application version is unchanged.

**With this setting:** Operators can explicitly document why plaintext transport is acceptable (e.g., "node-local collector on the pod's own node", "internal network with mTLS at the gateway").

### How to configure

#### Option 1: Review the node-local default

If your security policy permits the plaintext pod-to-node collector hop, the chart supplies the following container environment value when the component node-local switch is on and no modeled or supported legacy value takes precedence:

```yaml
ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"
```

#### Option 2: Set a custom reason at the component level

Override the default with a custom justification in your values file:

```yaml
plugin-br-ted-lerian:
  configmap:
    ALLOW_INSECURE_OTEL: "internal network with mTLS at the gateway"
```

#### Option 3: Set a custom reason environment-wide

For multi-chart deployments sharing the same security posture, set it globally:

```yaml
global:
  observability:
    enabled: true
    otlpEndpoint: "otel-collector:4317"
    allowInsecureOtel: "internal network with mTLS at the gateway"
```

This chart reads the global value when its component value is unset/null. Other charts must independently support this field. With the component node-local switch on, the explicit pod endpoint still overrides `otlpEndpoint` above; with it off, this global example enables telemetry to the configured endpoint.

#### Option 4: Refuse plaintext transport

To emit an explicit refusal rather than the fallback reason:

```yaml
plugin-br-ted-lerian:
  configmap:
    ALLOW_INSECURE_OTEL: ""
```

Or:

```yaml
plugin-br-ted-lerian:
  configmap:
    ALLOW_INSECURE_OTEL: "false"
```

> **Warning:** The inspected `v4.9.0` library rejects blank values and the case-insensitive negative words `false`, `0`, `no`, and `off` when its strict-environment plaintext check applies. YAML boolean `false` also renders as the string `"false"`. This is a library-source result, not an exercised application boot. Remove any legacy `extraEnvVars` entry for this key when relying on the modeled refusal, since that legacy route wins.

#### Option 5: Unset the variable

To leave the component modeled value unset (fall through to global, then the node-local fallback):

```yaml
plugin-br-ted-lerian:
  configmap:
    ALLOW_INSECURE_OTEL: null
```

And:

```yaml
global:
  observability:
    allowInsecureOtel: null
```

> **Note:** If both are `null`, the ConfigMap omits the key, but an enabled node-local helper still emits `ALLOW_INSECURE_OTEL: "node-local collector on the pod's own node"` in container `env` unless a supported legacy route suppresses it. `null` does not express refusal; use an explicit empty string or `"false"` for that policy.

### Migration guidance

**If you are NOT using OpenTelemetry:**

With telemetry disabled, this setting has no exporter effect. Check `global.observability.enabled` and `configmap.ENABLE_TELEMETRY` too: either can enable telemetry while the component node-local switch is off, and explicit component/global allowances still render in the ConfigMap.

**If you are using OpenTelemetry with the node-local collector:**

Review whether the fallback allowance is acceptable. To retain refusal, set `configmap.ALLOW_INSECURE_OTEL` explicitly to `""` or `"false"` and remove any conflicting legacy entry. An external Secret is not inspected, so its refusal is overridden by explicit pod `env` when the node-local helper is on. Confirm your complete production configuration separately; rendering an allowance does not prove startup readiness.

**If you previously set `ALLOW_INSECURE_OTEL` via `extraEnvVars`:**

The chart detects this legacy entry, suppresses its modeled ConfigMap entry and pod allowance, and emits the legacy value through the ConfigMap (not as a Deployment `env` entry). It wins even over a modeled refusal. Preserve unrelated `extraEnvVars` entries when migrating:

**Before (v1.2.0):**

```yaml
plugin-br-ted-lerian:
  extraEnvVars:
    - name: ALLOW_INSECURE_OTEL
      value: "internal network with mTLS at the gateway"
```

**After (v1.2.1):**

```yaml
plugin-br-ted-lerian:
  configmap:
    ALLOW_INSECURE_OTEL: "internal network with mTLS at the gateway"
```

Then remove the `extraEnvVars` entry.

**If you previously set `ALLOW_INSECURE_OTEL` via `secrets`:**

A non-empty legacy string in the generated Secret is preserved when no explicit component/global model value is set and `useExistingSecret` is false. An empty Secret value does not suppress the new node-local fallback. The new model takes precedence:

- If you set `plugin-br-ted-lerian.configmap.ALLOW_INSECURE_OTEL` or `global.observability.allowInsecureOtel`, the chart will use that value and ignore the secret.
- If `useExistingSecret` is true, the chart cannot inspect that Secret. With the node-local switch on, its explicit pod allowance overrides the Secret, even without a component/global override. Migrate any required reason or refusal into the model:

**Before (v1.2.0):**

```yaml
plugin-br-ted-lerian:
  secrets:
    ALLOW_INSECURE_OTEL: "internal network with mTLS at the gateway"
```

**After (v1.2.1):**

```yaml
plugin-br-ted-lerian:
  configmap:
    ALLOW_INSECURE_OTEL: "internal network with mTLS at the gateway"
```

Then remove the `secrets` entry.

> **Important:** With the node-local helper off and no modeled value, an external Secret can still supply this variable through `envFrom`. When the helper is on, explicit pod `env` wins; when a modeled ConfigMap value exists, its later `envFrom` entry wins over the Secret. Set the model to the intended reason or refusal before removing only this legacy key. Preserve all other Secret keys and references.

| Configuration Method | v1.2.0 Support | v1.2.1 Support | Recommended |
|---------------------|----------------|----------------|-------------|
| `plugin-br-ted-lerian.configmap.ALLOW_INSECURE_OTEL` | ❌ | ✅ | ✅ |
| `global.observability.allowInsecureOtel` | ❌ | ✅ | ✅ |
| `plugin-br-ted-lerian.extraEnvVars` | ✅ | ✅ | ❌ (legacy) |
| `plugin-br-ted-lerian.secrets.ALLOW_INSECURE_OTEL` | ✅ | ✅ | ❌ (legacy) |

---

## Preview changes before upgrading

Prepare `your-values.yaml` as the **complete intended configuration**, not just one of the fragments above. Keep private backups of current values/manifests and your authoritative values, plus a tested datastore backup/recovery plan. Stored Helm values alone do not recover external Secrets. Preserve unrelated settings, all image pins, credentials and Secret references; remove only superseded legacy keys. Keep these files and rendered Secret-bearing output out of Git, shared logs and public reports. The same file and reset semantics must be used for preview and upgrade below.

The application remains `1.0.0-beta.86`; this patch does not newly introduce its production requirements. Preserve working authentication, trusted proxy configuration, datastore TLS, licensing and rail/service-auth settings. The new allowance alone does not establish production readiness. The defaults and examples are not a complete runnable production configuration.

With identical values and unchanged image pins, a default telemetry-off application pod template is unchanged; enabling the node-local helper adds an environment entry and changes the pod template. An explicit ConfigMap allowance also changes its checksum, including with the helper off. The application pod labels do not contain the chart version. Bundled datastore pod templates and the optional regular PostgreSQL bootstrap Job were unchanged in the synthetic comparison; the bootstrap Job is not a migration hook. Review your actual rendered workloads before expecting a rollout.


```bash
helm diff upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --namespace plugin-br-ted-lerian --version 1.2.1 --reset-values -f your-values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --namespace plugin-br-ted-lerian --version 1.2.1 --reset-values -f your-values.yaml
```

After upgrading, inspect the release-scoped Deployment and confirm readiness and telemetry delivery without exposing Secrets. The public API Service port remains `8080`; health probes use internal port `8099` (`/readyz`, `/livez`). A successful Helm render is not evidence of a successful application boot, collector connection or database migration. Helm rollback does not restore datastore contents or external Secrets; use your tested recovery procedure.
<!-- {% endraw %} -->
