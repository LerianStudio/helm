<!-- {% raw %} -->
# Helm Upgrade from v5.2.2 to v5.2.3

## Topics

- **[Fixes](#fixes)**
  - [1. Health probe timeout defaults increased](#1-health-probe-timeout-defaults-increased)
  - [2. LICENSE_KEY secret added to all components](#2-license_key-secret-added-to-all-components)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Health probe timeout defaults increased

This patch release increases the default `timeoutSeconds` for both readiness and liveness probes from `1` second to `3` seconds across all service components: `pix`, `inbound`, `outbound`, `reconciliation`, and `schedule`.

**What changed:**

The probe timeout default was increased to provide more tolerance for health check responses, especially in environments with higher network latency or during periods of increased load.

| Component | Probe Type | v5.2.2 Default | v5.2.3 Default |
|-----------|------------|----------------|----------------|
| `pix` | readinessProbe.timeoutSeconds | `1` | `3` |
| `pix` | livenessProbe.timeoutSeconds | `1` | `3` |
| `inbound` | readinessProbe.timeoutSeconds | `1` | `3` |
| `inbound` | livenessProbe.timeoutSeconds | `1` | `3` |
| `outbound` | readinessProbe.timeoutSeconds | `1` | `3` |
| `outbound` | livenessProbe.timeoutSeconds | `1` | `3` |
| `reconciliation` | readinessProbe.timeoutSeconds | `1` | `3` |
| `reconciliation` | livenessProbe.timeoutSeconds | `1` | `3` |
| `schedule` | readinessProbe.timeoutSeconds | `1` | `3` |
| `schedule` | livenessProbe.timeoutSeconds | `1` | `3` |

**Why it matters:**

A 1-second timeout can be too aggressive in production environments, leading to false-positive probe failures when the application is healthy but momentarily slow to respond. This can cause unnecessary pod restarts and service disruptions. The new 3-second default provides a more realistic timeout while still catching genuine health issues.

**Operational impact:**

If your deployment was experiencing intermittent probe failures or unexpected pod restarts due to timeout issues, this change should reduce those occurrences. Pods will wait up to 3 seconds for health check responses before marking the probe as failed.

**Example deployment template change (pix component):**

**Before (v5.2.2):**

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 1
  successThreshold: 1
  failureThreshold: 3
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 1
  successThreshold: 1
  failureThreshold: 3
```

**After (v5.2.3):**

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  successThreshold: 1
  failureThreshold: 3
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  successThreshold: 1
  failureThreshold: 3
```

> **Note:** If you have explicitly overridden `timeoutSeconds` in your custom values file, your override will continue to take precedence. Review your custom values to ensure they remain appropriate for your environment.

**To revert to the previous 1-second timeout** (not recommended unless you have specific requirements):

```yaml
pix:
  readinessProbe:
    timeoutSeconds: 1
  livenessProbe:
    timeoutSeconds: 1

inbound:
  readinessProbe:
    timeoutSeconds: 1
  livenessProbe:
    timeoutSeconds: 1

outbound:
  readinessProbe:
    timeoutSeconds: 1
  livenessProbe:
    timeoutSeconds: 1

reconciliation:
  readinessProbe:
    timeoutSeconds: 1
  livenessProbe:
    timeoutSeconds: 1

schedule:
  readinessProbe:
    timeoutSeconds: 1
  livenessProbe:
    timeoutSeconds: 1
```

### 2. LICENSE_KEY secret added to all components

This patch release adds `LICENSE_KEY` secret configuration to all service components: `inbound`, `outbound`, `reconciliation`, and `schedule`. Each component now supports its own `LICENSE_KEY` secret with automatic fallback to the global `pix.secrets.LICENSE_KEY` value.

**What changed:**

New `LICENSE_KEY` secret fields were added to the `secrets` block of each component in `values.yaml`. The corresponding secret templates were updated to include the `LICENSE_KEY` environment variable with a fallback chain.

| Component | New Secret Field | Fallback Behavior |
|-----------|------------------|-------------------|
| `inbound.secrets.LICENSE_KEY` | Added | Falls back to `pix.secrets.LICENSE_KEY` when empty |
| `outbound.secrets.LICENSE_KEY` | Added | Falls back to `pix.secrets.LICENSE_KEY` when empty |
| `reconciliation.secrets.LICENSE_KEY` | Added | Falls back to `pix.secrets.LICENSE_KEY` when empty |
| `schedule.secrets.LICENSE_KEY` | Added | Falls back to `pix.secrets.LICENSE_KEY` when empty |

**Why it matters:**

This change enables per-component license key configuration while maintaining backward compatibility with the existing global license key pattern. Operators can now set different license keys for individual components if required, or continue using a single global key.

**Operational impact:**

If you already have `pix.secrets.LICENSE_KEY` configured, all components will automatically inherit that value through the fallback mechanism. No immediate action is required unless you need component-specific license keys.

**Example secret template change (inbound component):**

**Before (v5.2.2):**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: plugin-br-pix-indirect-btg-inbound
type: Opaque
data:
  DB_PASSWORD: {{ .Values.inbound.secrets.DB_PASSWORD | b64enc | quote }}
  INTERNAL_WEBHOOK_SECRET: {{ .Values.inbound.secrets.INTERNAL_WEBHOOK_SECRET | default .Values.pix.secrets.INTERNAL_WEBHOOK_SECRET | b64enc | quote }}
```

**After (v5.2.3):**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: plugin-br-pix-indirect-btg-inbound
type: Opaque
data:
  DB_PASSWORD: {{ .Values.inbound.secrets.DB_PASSWORD | b64enc | quote }}
  INTERNAL_WEBHOOK_SECRET: {{ .Values.inbound.secrets.INTERNAL_WEBHOOK_SECRET | default .Values.pix.secrets.INTERNAL_WEBHOOK_SECRET | b64enc | quote }}
  LICENSE_KEY: {{ .Values.inbound.secrets.LICENSE_KEY | default .Values.pix.secrets.LICENSE_KEY | b64enc | quote }}
```

**Example values.yaml configuration:**

**Option 1: Use global license key (recommended for most deployments):**

```yaml
pix:
  secrets:
    LICENSE_KEY: "your-global-license-key-here"

inbound:
  secrets:
    LICENSE_KEY: ""  # Falls back to pix.secrets.LICENSE_KEY

outbound:
  secrets:
    LICENSE_KEY: ""  # Falls back to pix.secrets.LICENSE_KEY

reconciliation:
  secrets:
    LICENSE_KEY: ""  # Falls back to pix.secrets.LICENSE_KEY

schedule:
  secrets:
    LICENSE_KEY: ""  # Falls back to pix.secrets.LICENSE_KEY
```

**Option 2: Use component-specific license keys:**

```yaml
pix:
  secrets:
    LICENSE_KEY: "global-fallback-key"

inbound:
  secrets:
    LICENSE_KEY: "inbound-specific-key"

outbound:
  secrets:
    LICENSE_KEY: "outbound-specific-key"

reconciliation:
  secrets:
    LICENSE_KEY: ""  # Falls back to pix.secrets.LICENSE_KEY

schedule:
  secrets:
    LICENSE_KEY: ""  # Falls back to pix.secrets.LICENSE_KEY
```

> **Important:** The `LICENSE_KEY` fields default to empty strings (`""`), which means they will use the global `pix.secrets.LICENSE_KEY` value. If you do not have `pix.secrets.LICENSE_KEY` configured and your application requires a license key, you must set it before upgrading.

**New environment variables added:**

| Variable | Component | Default | Description |
|----------|-----------|---------|-------------|
| `LICENSE_KEY` | inbound | Falls back to `pix.secrets.LICENSE_KEY` | License key for the inbound service |
| `LICENSE_KEY` | outbound | Falls back to `pix.secrets.LICENSE_KEY` | License key for the outbound service |
| `LICENSE_KEY` | reconciliation | Falls back to `pix.secrets.LICENSE_KEY` | License key for the reconciliation service |
| `LICENSE_KEY` | schedule | Falls back to `pix.secrets.LICENSE_KEY` | License key for the schedule service |

## Configuration Changes

No values are removed or renamed. The changes are additive and backward-compatible:

| Setting | v5.2.2 | v5.2.3 |
|---------|--------|--------|
| Chart version | `5.2.2` | `5.2.3` |
| App version | `1.12.0` | `1.12.0` |
| `*.readinessProbe.timeoutSeconds` default | `1` | `3` |
| `*.livenessProbe.timeoutSeconds` default | `1` | `3` |
| `inbound.secrets.LICENSE_KEY` | (not present) | `""` (falls back to `pix.secrets.LICENSE_KEY`) |
| `outbound.secrets.LICENSE_KEY` | (not present) | `""` (falls back to `pix.secrets.LICENSE_KEY`) |
| `reconciliation.secrets.LICENSE_KEY` | (not present) | `""` (falls back to `pix.secrets.LICENSE_KEY`) |
| `schedule.secrets.LICENSE_KEY` | (not present) | `""` (falls back to `pix.secrets.LICENSE_KEY`) |

## Migration Steps

This upgrade requires no destructive migration steps. The new defaults are backward-compatible and will not change behavior for existing deployments that already have `pix.secrets.LICENSE_KEY` configured.

**Recommended upgrade process:**

1. Review your current `pix.secrets.LICENSE_KEY` configuration. If it is already set, no action is required — all components will inherit it automatically.

2. If your application requires a license key and you do not have `pix.secrets.LICENSE_KEY` configured, set it before upgrading:

```yaml
pix:
  secrets:
    LICENSE_KEY: "your-license-key-here"
```

3. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

4. Run the upgrade command during a maintenance window.

5. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n plugin-br-pix-indirect-btg
```

6. Check service logs to confirm no license key errors:

```bash
kubectl logs -n plugin-br-pix-indirect-btg -l app.kubernetes.io/name=plugin-br-pix-indirect-btg --tail=50
```

> **Note:** The upgrade triggers a rolling restart of all deployments because the secret templates change. Depending on your replica count and probe timing, this may cause brief service interruptions. The new 3-second probe timeout may slightly extend the time required for pods to become ready.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.2.3 -n plugin-br-pix-indirect-btg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.2.3 -n plugin-br-pix-indirect-btg
```
<!-- {% endraw %} -->
