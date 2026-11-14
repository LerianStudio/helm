# Helm Upgrade from v1.1.3 to v1.2.0

This guide covers the upgrade of the `system-facts` Helm chart from version **1.1.3** to **1.2.0**. This is a minor release that introduces license file support for both the service and worker components, refactors pod labels to prevent unnecessary restarts, and updates the default ingress hostname.

---

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
- **[Features](#features)**
  - [1. License File Support](#1-license-file-support)
  - [2. Pod Label Optimization](#2-pod-label-optimization)
  - [3. Default Ingress Hostname Change](#3-default-ingress-hostname-change)
- **[Configuration Reference](#configuration-reference)**
  - [License File Configuration](#license-file-configuration)
  - [New Environment Variables](#new-environment-variables)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Overview

Version **1.2.0** introduces the following changes:

- **License file support**: Both the System Facts service and worker can now mount a signed license file from a Kubernetes Secret as an alternative to the `LICENSE_KEY` environment variable
- **Pod label optimization**: The `helm.sh/chart` label has been moved out of pod templates to prevent unnecessary pod restarts on every chart version bump
- **Default ingress hostname**: Changed from `system-facts.lerian.net` to `system-facts.example.com`

There are no changes to:

- Application versions or image tags
- Dependencies or subcharts
- Core service functionality or APIs

---

## Breaking Changes

**None.** This is a minor release with no breaking changes. All existing configurations remain valid and the upgrade is backward compatible.

The default ingress hostname change only affects new installations. Existing deployments that have overridden `system-facts.ingress.hosts` in their values will not be affected.

---

## Features

### 1. License File Support

Both the System Facts service and the internal facts worker now support mounting a signed license file from a Kubernetes Secret as an alternative to providing a `LICENSE_KEY` environment variable.

**Why this matters:**

License files provide a more secure and flexible licensing mechanism:

- License files can be rotated without redeploying pods (Kubernetes automatically propagates Secret updates to mounted volumes)
- Centralized license management when the same license is shared across multiple components
- Support for advanced licensing features that require file-based validation

**How it works:**

When you configure `licenseFile.existingSecret`, the chart:

1. Mounts the specified Secret as a directory at `/etc/lerian/license`
2. Sets the `LICENSE_FILE_PATH` environment variable to `/etc/lerian/license/license`
3. Makes the `LICENSE_KEY` environment variable optional

The Secret must contain a key named `license` with the signed license file content.

**Configuration changes:**

Two new configuration blocks have been added:

| Component | New Field | Default | Description |
|-----------|-----------|---------|-------------|
| `system-facts` | `licenseFile.existingSecret` | `""` | Secret name holding the license file for the service |
| `worker` | `licenseFile.existingSecret` | `""` | Secret name holding the license file for the worker |
| `worker.secrets` | `LICENSE_KEY` | `""` | License key for the worker (optional when using license file) |

**Before (v1.1.3):**

```yaml
system-facts:
  secrets:
    LICENSE_KEY: "your-license-key-here"
  useExistingSecret: false
  existingSecretName: ""

worker:
  secrets:
    SYSTEM_FACTS_CLIENT_ID: ""
    SYSTEM_FACTS_CLIENT_SECRET: ""
    STREAMING_SASL_PASSWORD: ""
    STREAMING_TLS_CA_CERT: ""
  useExistingSecret: false
  existingSecretName: ""
```

**After (v1.2.0):**

```yaml
system-facts:
  secrets:
    LICENSE_KEY: "your-license-key-here"
  useExistingSecret: false
  existingSecretName: ""
  licenseFile:
    existingSecret: ""

worker:
  secrets:
    SYSTEM_FACTS_CLIENT_ID: ""
    SYSTEM_FACTS_CLIENT_SECRET: ""
    STREAMING_SASL_PASSWORD: ""
    STREAMING_TLS_CA_CERT: ""
    LICENSE_KEY: ""
  useExistingSecret: false
  existingSecretName: ""
  licenseFile:
    existingSecret: ""
```

**Operational impact:**

This is an additive change. Existing deployments using `LICENSE_KEY` continue to work without modification. The license file feature is opt-in.

> **Note:** The license file feature requires an image built with `lib-license-go` v5 or later for proper file mode handling. Check your application version compatibility before enabling this feature.

### 2. Pod Label Optimization

The `helm.sh/chart` label has been removed from pod templates for both the System Facts service and worker Deployments. This label now appears only on the Deployment resource itself, not on the pods.

**Why this matters:**

Previously, every Helm chart version bump (e.g., from `1.1.3` to `1.2.0`) changed the `helm.sh/chart` label on pod templates, triggering a rolling restart of all pods even when no actual configuration or image changes occurred. This caused unnecessary downtime and resource churn for patch releases that only updated chart metadata.

**Template changes:**

The chart introduces two new helper templates:

- `system-facts.podLabels`: Labels for service pod templates (without `helm.sh/chart`)
- `system-facts.worker.podLabels`: Labels for worker pod templates (without `helm.sh/chart`)

The existing `system-facts.labels` and `system-facts.worker.labels` templates retain the `helm.sh/chart` label and are used only on the Deployment resource itself.

**Before (v1.1.3):**

```yaml
# Deployment spec.template.metadata.labels
labels:
  helm.sh/chart: system-facts-1.1.3
  app.kubernetes.io/name: system-facts
  app.kubernetes.io/instance: my-release
  app.kubernetes.io/version: "1.1.0"
  app.kubernetes.io/managed-by: Helm
```

**After (v1.2.0):**

```yaml
# Deployment spec.template.metadata.labels
labels:
  app.kubernetes.io/name: system-facts
  app.kubernetes.io/instance: my-release
  app.kubernetes.io/version: "1.1.0"
  app.kubernetes.io/managed-by: Helm
```

**Operational impact:**

When you upgrade to v1.2.0, Kubernetes will perform a one-time rolling restart of all System Facts and worker pods because the pod template labels have changed (the `helm.sh/chart` label is being removed). This is expected behavior for this upgrade.

**After this upgrade**, future chart version bumps that only change metadata (patch releases like `1.2.0` → `1.2.1`) will **not** restart pods unless the pod template actually changes (image tags, environment variables, volume mounts, etc.).

> **Important:** This one-time restart is unavoidable when upgrading to v1.2.0. Plan the upgrade during a maintenance window if you are running a single replica without high availability.

### 3. Default Ingress Hostname Change

The default ingress hostname has been changed from `system-facts.lerian.net` to `system-facts.example.com`.

**Configuration change:**

| Setting | v1.1.3 | v1.2.0 |
|---------|--------|--------|
| `system-facts.ingress.hosts[0].host` | `"system-facts.lerian.net"` | `"system-facts.example.com"` |

**Before (v1.1.3):**

```yaml
system-facts:
  ingress:
    enabled: false
    className: ""
    annotations: {}
    hosts:
      - host: "system-facts.lerian.net"
        paths:
          - path: /
            pathType: Prefix
```

**After (v1.2.0):**

```yaml
system-facts:
  ingress:
    enabled: false
    className: ""
    annotations: {}
    hosts:
      - host: "system-facts.example.com"
        paths:
          - path: /
            pathType: Prefix
```

**Operational impact:**

This change only affects new installations or deployments that rely on the chart's default hostname. If you have overridden `system-facts.ingress.hosts` in your values file, your configuration is not affected.

If you are using the default hostname and have `ingress.enabled: true`, the Ingress resource will be updated to use `system-facts.example.com`. Since `example.com` is a reserved domain for documentation, you should already have a custom hostname configured in production.

> **Note:** The default `ingress.enabled` is `false`, so most deployments will not be affected by this change.

---

## Configuration Reference

### License File Configuration

To use license files instead of `LICENSE_KEY` environment variables, create a Kubernetes Secret containing your signed license file and reference it in your values.

#### System Facts Service

**Step 1:** Create a Secret with your license file:

```bash
kubectl create secret generic system-facts-license \
  --from-file=license=/path/to/your/license.lic \
  --namespace system-facts
```

**Step 2:** Configure the chart to use the Secret:

```yaml
system-facts:
  licenseFile:
    existingSecret: "system-facts-license"
  secrets:
    # LICENSE_KEY is now optional when licenseFile.existingSecret is set
    LICENSE_KEY: ""
```

#### Internal Facts Worker

**Step 1:** Create a Secret with your license file:

```bash
kubectl create secret generic worker-license \
  --from-file=license=/path/to/your/license.lic \
  --namespace system-facts
```

**Step 2:** Configure the chart to use the Secret:

```yaml
worker:
  enabled: true
  licenseFile:
    existingSecret: "worker-license"
  secrets:
    # LICENSE_KEY is now optional when licenseFile.existingSecret is set
    LICENSE_KEY: ""
    SYSTEM_FACTS_CLIENT_ID: "your-client-id"
    SYSTEM_FACTS_CLIENT_SECRET: "your-client-secret"
```

#### Shared License File

If both the service and worker use the same license, you can reference the same Secret:

```yaml
system-facts:
  licenseFile:
    existingSecret: "shared-license"

worker:
  enabled: true
  licenseFile:
    existingSecret: "shared-license"
```

### New Environment Variables

The following environment variable is automatically set when `licenseFile.existingSecret` is configured:

| Variable | Value | Description |
|----------|-------|-------------|
| `LICENSE_FILE_PATH` | `/etc/lerian/license/license` | Path to the mounted license file |

This variable is set in addition to any existing environment variables. The application checks for `LICENSE_FILE_PATH` first; if present, it reads the license from the file. If not present, it falls back to the `LICENSE_KEY` environment variable.

---

## Migration Steps

No values changes are required for this upgrade. The new features are opt-in and all existing configurations remain valid.

### Step 1: Verify current deployment

Confirm your current chart version:

```bash
helm list -n system-facts
```

The `CHART` column should show `system-facts-helm-1.1.3`.

### Step 2: Review license configuration (optional)

If you want to migrate from `LICENSE_KEY` environment variables to license files, prepare your license file Secrets before upgrading. See [License File Configuration](#license-file-configuration) for detailed instructions.

> **Note:** You can perform this migration after the upgrade. The license file feature is optional and does not require immediate action.

### Step 3: Review ingress configuration (if applicable)

If you have `system-facts.ingress.enabled: true` and are using the default hostname, verify that you have overridden `system-facts.ingress.hosts` in your values file:

```bash
helm get values system-facts -n system-facts
```

If your values do not include a custom `system-facts.ingress.hosts` configuration, add one before upgrading:

```yaml
system-facts:
  ingress:
    enabled: true
    hosts:
      - host: "your-actual-hostname.example.com"
        paths:
          - path: /
            pathType: Prefix
```

### Step 4: Apply the upgrade

Upgrade to version `1.2.0` using your existing values:

```bash
helm upgrade system-facts oci://ghcr.io/lerianstudio/system-facts-helm \
  --version 1.2.0 \
  --namespace system-facts \
  --reuse-values
```

> **Note:** The `--reuse-values` flag preserves your existing configuration. The new license file fields default to empty strings, so they remain disabled unless you explicitly configure them.

### Step 5: Monitor the upgrade

Watch the rollout status for the System Facts service:

```bash
kubectl rollout status deployment/system-facts -n system-facts
```

If the worker is enabled, monitor its rollout:

```bash
kubectl rollout status deployment/system-facts-worker -n system-facts
```

> **Important:** This upgrade will trigger a rolling restart of all pods due to the pod label changes. This is expected and will only happen once during this upgrade.

### Step 6: Verify the upgrade

Confirm the chart version was updated:

```bash
helm list -n system-facts
```

The `CHART` column should show `system-facts-helm-1.2.0`.

Verify that all pods are running and healthy:

```bash
kubectl get pods -n system-facts
```

### Step 7: Migrate to license files (optional)

If you want to use the new license file feature, follow the instructions in [License File Configuration](#license-file-configuration) and then upgrade again with the new values:

```bash
helm upgrade system-facts oci://ghcr.io/lerianstudio/system-facts-helm \
  --version 1.2.0 \
  --namespace system-facts \
  --values your-updated-values.yaml
```

---

## Preview changes before upgrading

```bash
helm diff upgrade system-facts oci://ghcr.io/lerianstudio/system-facts-helm --namespace system-facts --version 1.2.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade system-facts oci://ghcr.io/lerianstudio/system-facts-helm --namespace system-facts --version 1.2.0
```
