# Helm Upgrade from v1.0.0 to v1.0.1

This guide covers the upgrade of the `system-facts` Helm chart from version **1.0.0** to **1.0.1**. This is a patch release with no functional changes, template modifications, or configuration updates.

---

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
- **[Fixes](#fixes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Overview

Version **1.0.1** is a patch release that updates only the chart version metadata in `Chart.yaml`. There are no changes to:

- Values schema or defaults
- Template files (Deployments, Services, ConfigMaps, etc.)
- Application configuration or environment variables
- Dependencies or subcharts

This release is a no-op upgrade from an operational perspective. All existing configurations, secrets, and deployments remain unchanged.

---

## Breaking Changes

**None.** This is a patch release with no breaking changes.

---

## Fixes

**None.** This release contains no bug fixes or functional changes. The version bump is purely administrative.

---

## Migration Steps

No migration steps are required. The upgrade can be applied directly without configuration changes or manual intervention.

### Step 1: Verify current deployment

Confirm your current chart version:

```bash
helm list -n system-facts
```

Expected output should show version `1.0.0`.

### Step 2: Apply the upgrade

Upgrade to version `1.0.1` using your existing values:

```bash
helm upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm \
  --version 1.0.1 \
  --namespace system-facts \
  --reuse-values
```

> **Note:** The `--reuse-values` flag preserves your existing configuration. No values changes are required for this upgrade.

### Step 3: Verify the upgrade

Confirm the chart version was updated:

```bash
helm list -n system-facts
```

Expected output should show version `1.0.1`.

Verify that all pods remain healthy:

```bash
kubectl get pods -n system-facts
```

> **Note:** Since no templates changed, Kubernetes will not recreate any pods. The upgrade completes immediately without rolling restarts.

---

## Preview changes before upgrading

```bash
helm diff upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm --version 1.0.1 -n system-facts
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm --version 1.0.1 -n system-facts
```
