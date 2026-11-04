<!-- {% raw %} -->
# Helm Upgrade from v1.1.2 to v1.1.3

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Zero-downtime rolling updates](#1-zero-downtime-rolling-updates)
  - [2. Redis timeout environment variables](#2-redis-timeout-environment-variables)
  - [3. Pod label stability](#3-pod-label-stability)
  - [4. CloudEvents source default](#4-cloudevents-source-default)
  - [5. ConfigMap checksum calculation](#5-configmap-checksum-calculation)
  - [6. Bundled subchart namespace resolution](#6-bundled-subchart-namespace-resolution)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Overview

This is a patch release that fixes several operational issues related to rolling updates, Redis configuration, and pod restart behavior. No breaking changes are included.

| Setting | v1.1.2 | v1.1.3 |
|---------|--------|--------|
| Chart version | `1.1.2` | `1.1.3` |
| App version | `1.0.0-beta.64` | `1.0.0-beta.64` |

**What changed:**
- Default `maxUnavailable` changed from `1` to `0` for zero-downtime rolling updates
- Redis timeout environment variables renamed from `*_MS` to whole seconds
- Pod labels no longer include `helm.sh/chart`, preventing unnecessary restarts on chart version bumps
- CloudEvents source default changed from chart name to `br-ted`
- ConfigMap and Secret checksum annotations now hash only the data/stringData fields
- Bundled subchart host resolution now respects `namespaceOverride`
- Documentation comments updated to remove environment-specific references

**What stayed the same:**
- Application version remains `1.0.0-beta.64`
- All functional configuration parameters unchanged
- All service, ingress, and resource settings unchanged

**Impact:** This upgrade requires no configuration changes. Existing values files are fully compatible. The upgrade will trigger a pod rollout due to template changes, but subsequent chart upgrades will not restart pods unnecessarily.

---

## Fixes

### 1. Zero-downtime rolling updates

The default rolling update strategy now keeps the old pod serving traffic until the new pod is ready, eliminating brief service interruptions during upgrades.

| Setting | v1.1.2 | v1.1.3 |
|---------|--------|--------|
| `plugin-br-ted-lerian.deploymentUpdate.maxUnavailable` | `1` | `0` |

**Before (v1.1.2):**
```yaml
plugin-br-ted-lerian:
  deploymentUpdate:
    type: RollingUpdate
    maxSurge: 1
    maxUnavailable: 1
```

**After (v1.1.3):**
```yaml
plugin-br-ted-lerian:
  deploymentUpdate:
    type: RollingUpdate
    maxSurge: 1
    # (0 keeps the old pod serving until the surged pod is ready)
    maxUnavailable: 0
```

**Impact:** During rolling updates, Kubernetes will now create the new pod first and wait for it to pass readiness checks before terminating the old pod. This prevents the brief window where no pods are ready to serve traffic.

> **Note:** If you have explicitly set `maxUnavailable: 1` in your values file and want to keep that behavior, no action is required. The chart respects your override.

The template also includes a safeguard: if both `maxSurge` and `maxUnavailable` are set to `0` (which Kubernetes rejects), the chart automatically sets `maxUnavailable: 1` to allow the rollout to proceed.

---

### 2. Redis timeout environment variables

The application now reads Redis timeout values as whole seconds instead of milliseconds. The chart automatically converts the existing millisecond values to seconds (minimum 1 second).

| Environment Variable | v1.1.2 | v1.1.3 |
|---------------------|--------|--------|
| Read timeout | `REDIS_READ_TIMEOUT_MS` | `REDIS_READ_TIMEOUT` |
| Write timeout | `REDIS_WRITE_TIMEOUT_MS` | `REDIS_WRITE_TIMEOUT` |
| Dial timeout | `REDIS_DIAL_TIMEOUT_MS` | `REDIS_DIAL_TIMEOUT` |

**Before (v1.1.2):**
```yaml
plugin-br-ted-lerian:
  redis:
    readTimeoutMs: "3000"   # → REDIS_READ_TIMEOUT_MS
    writeTimeoutMs: "3000"  # → REDIS_WRITE_TIMEOUT_MS
    dialTimeoutMs: "5000"   # → REDIS_DIAL_TIMEOUT_MS
```

**After (v1.1.3):**
```yaml
plugin-br-ted-lerian:
  redis:
    readTimeoutMs: "3000"   # → REDIS_READ_TIMEOUT (whole seconds, minimum 1)
    writeTimeoutMs: "3000"  # → REDIS_WRITE_TIMEOUT (whole seconds, minimum 1)
    dialTimeoutMs: "5000"   # → REDIS_DIAL_TIMEOUT (whole seconds, minimum 1)
```

**Impact:** The chart divides your existing millisecond values by 1000 and rounds down, with a minimum of 1 second. The default values convert as follows:

| Parameter | Milliseconds | Seconds |
|-----------|--------------|---------|
| `readTimeoutMs: "3000"` | 3000ms | 3s |
| `writeTimeoutMs: "3000"` | 3000ms | 3s |
| `dialTimeoutMs: "5000"` | 5000ms | 5s |

> **Important:** If you have set custom timeout values in your values file, verify they convert to the desired whole seconds. For example, `readTimeoutMs: "1500"` becomes `1` second (not `1.5`). If you need sub-second precision, you must now set the timeout in whole seconds (minimum 1).

The parameter names remain `*Ms` for backward compatibility, but the rendered environment variables are now `REDIS_READ_TIMEOUT`, `REDIS_WRITE_TIMEOUT`, and `REDIS_DIAL_TIMEOUT`.

If you have overridden these variables directly via `extraEnvVars`, the chart will skip rendering them in the ConfigMap to avoid conflicts.

---

### 3. Pod label stability

The `helm.sh/chart` label has been removed from the pod template, preventing unnecessary pod restarts when only the chart version changes.

**Before (v1.1.2):**
```yaml
# Pod template included:
labels:
  helm.sh/chart: plugin-br-ted-lerian-1.1.2
  app.kubernetes.io/name: plugin-br-ted-lerian
  app.kubernetes.io/version: "1.0.0-beta.64"
```

**After (v1.1.3):**
```yaml
# Pod template includes:
labels:
  app.kubernetes.io/name: plugin-br-ted-lerian
  app.kubernetes.io/version: "1.0.0-beta.64"
  # helm.sh/chart removed from pod template
```

**Impact:** This upgrade will restart pods once (because the label is being removed). Future chart upgrades that only bump the chart version (e.g., `1.1.3` → `1.1.4`) will not restart pods unless the application version, configuration, or templates change.

The `helm.sh/chart` label remains on the Deployment, Service, and other top-level resources for tracking purposes — only the pod template is affected.

---

### 4. CloudEvents source default

The default CloudEvents source for streaming events has changed from the chart name to `br-ted`, which is the only value the application accepts at boot.

| Setting | v1.1.2 | v1.1.3 |
|---------|--------|--------|
| `plugin-br-ted-lerian.streaming.cloudeventsSource` default | `plugin-br-ted-lerian` | `br-ted` |

**Before (v1.1.2):**
```yaml
# Default behavior:
CLOUDEVENTS_SOURCE: plugin-br-ted-lerian
```

**After (v1.1.3):**
```yaml
# Default behavior:
CLOUDEVENTS_SOURCE: br-ted
```

**Impact:** If you have not explicitly set `plugin-br-ted-lerian.streaming.cloudeventsSource` in your values file, the rendered ConfigMap will change from `plugin-br-ted-lerian` to `br-ted`. This aligns with the application's requirement and prevents boot failures.

> **Note:** If you have explicitly set `cloudeventsSource` to a different value, the chart will respect your override. However, the application only boots with `cloudeventsSource: "br-ted"`, so ensure your override matches this requirement.

---

### 5. ConfigMap checksum calculation

The checksum annotations that trigger pod restarts on configuration changes now hash only the `data` or `stringData` fields, ignoring metadata changes.

**Before (v1.1.2):**
```yaml
annotations:
  checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
  checksum/secret: {{ include (print $.Template.BasePath "/secrets.yaml") . | sha256sum }}
```

**After (v1.1.3):**
```yaml
annotations:
  checksum/config: {{ (include (print $.Template.BasePath "/configmap.yaml") . | fromYaml).data | toYaml | sha256sum }}
  checksum/secret: {{ (include (print $.Template.BasePath "/secrets.yaml") . | fromYaml).stringData | toYaml | sha256sum }}
```

**Impact:** Pods will only restart when the actual configuration data changes, not when metadata (labels, annotations on the ConfigMap/Secret resource itself) changes. This prevents unnecessary restarts during chart upgrades that only modify resource metadata.

---

### 6. Bundled subchart namespace resolution

When bundled PostgreSQL or Valkey subcharts are enabled, the chart now correctly resolves their service hostnames if they deploy to a different namespace via `namespaceOverride`.

**Before (v1.1.2):**
```yaml
# Always used .Release.Namespace:
POSTGRES_HOST: postgresql-primary.plugin-br-ted-lerian.svc.cluster.local
REDIS_HOST: valkey-primary.plugin-br-ted-lerian.svc.cluster.local
```

**After (v1.1.3):**
```yaml
# Respects subchart namespaceOverride:
POSTGRES_HOST: postgresql-primary.<namespace>.svc.cluster.local
REDIS_HOST: valkey-primary.<namespace>.svc.cluster.local
# where <namespace> is postgresql.namespaceOverride or valkey.namespaceOverride if set,
# otherwise .Release.Namespace
```

**Impact:** If you have enabled bundled subcharts (`postgresql.enabled: true` or `valkey.enabled: true`) and set `postgresql.namespaceOverride` or `valkey.namespaceOverride`, the chart will now generate the correct service hostname. No action is required unless you have worked around this issue by manually setting `POSTGRES_HOST` or `REDIS_HOST` in `plugin-br-ted-lerian.configmap`.

> **Note:** Most deployments use external datastores and are unaffected by this change. This fix only applies when bundled subcharts are enabled.

---

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --namespace plugin-br-ted-lerian --version 1.1.3
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --namespace plugin-br-ted-lerian --version 1.1.3
```
<!-- {% endraw %} -->
