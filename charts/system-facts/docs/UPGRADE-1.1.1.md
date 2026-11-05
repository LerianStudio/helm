<!-- {% raw %} -->
# Helm Upgrade from v1.1.0 to v1.1.1

This guide covers the upgrade of the `system-facts` Helm chart from version **1.1.0** to **1.1.1**. This is a patch release that removes the `LICENSE_ENABLED` configuration option from the ConfigMap template.

---

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
- **[Configuration Changes](#configuration-changes)**
  - [Removed: LICENSE_ENABLED Environment Variable](#removed-license_enabled-environment-variable)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Overview

Version **1.1.1** removes the `LICENSE_ENABLED` configuration option from the ConfigMap template. Among the templates, this release changes only `templates/configmap.yaml`. The README and `values-template.yaml` also drop the `LICENSE_ENABLED` switch. There are no changes to:

- `appVersion` (remains `1.1.0`)
- Values schema or defaults in `values.yaml`
- Image tags or container specifications
- Other template files (Deployments, Services, etc.)
- Dependencies or subcharts

The `ORGANIZATION_IDS` configuration option remains unchanged and continues to function as before.

The upgrade rolls the System Facts pods, and the worker pods if `worker.enabled` is `true`: their pod templates carry the `helm.sh/chart` label, which changes with the chart version.

---

## Breaking Changes

`system-facts.configmap.LICENSE_ENABLED` is removed. The chart no longer renders it, so the application license gate is on, and the application refuses to boot without a valid license. If you set `LICENSE_ENABLED: "false"`, set `system-facts.secrets.LICENSE_KEY` and `system-facts.configmap.ORGANIZATION_IDS` before you upgrade. With `system-facts.useExistingSecret: true`, add `LICENSE_KEY` to the Secret named by `system-facts.existingSecretName` instead.

- If you never set `system-facts.configmap.LICENSE_ENABLED` in your values, the ConfigMap did not include the variable, so nothing changes for you.

The values schema itself is unchanged — you can still set `system-facts.configmap.LICENSE_ENABLED` in your values file, but the chart will ignore it.

---

## Configuration Changes

### Removed: LICENSE_ENABLED Environment Variable

The `LICENSE_ENABLED` environment variable has been removed from the ConfigMap template. Previously, operators could set `system-facts.configmap.LICENSE_ENABLED` to control license enforcement behavior. This option is no longer supported by the chart.

**Operational impact:**

If you have `system-facts.configmap.LICENSE_ENABLED` set in your values file, the chart will no longer render it into the ConfigMap. The license gate is on, and the application refuses to boot without a valid license.

The `ORGANIZATION_IDS` configuration option remains unchanged and continues to control which organization IDs are subject to license checks.

> **Note:** If you used `LICENSE_ENABLED: "false"`, set `system-facts.secrets.LICENSE_KEY` and `system-facts.configmap.ORGANIZATION_IDS` before you upgrade. The chart no longer provides this option.

---

## Migration Steps

If you set `system-facts.configmap.LICENSE_ENABLED: "false"`, set `system-facts.secrets.LICENSE_KEY` and `system-facts.configmap.ORGANIZATION_IDS` before you upgrade. A `LICENSE_ENABLED` key left in your values causes no render error; the chart ignores it.

### Step 1: Verify current deployment

Confirm your current chart version:

```bash
helm list -n system-facts
```

The `CHART` column should show `system-facts-helm-1.1.0`.

### Step 2: If you set LICENSE_ENABLED, add the license

If your values file includes `system-facts.configmap.LICENSE_ENABLED`, remove it and add the license:

**Before:**

```yaml
system-facts:
  configmap:
    ORGANIZATION_IDS: "org-123,org-456"
    LICENSE_ENABLED: "false"
```

**After:**

```yaml
system-facts:
  secrets:
    LICENSE_KEY: "<license-key>"
  configmap:
    ORGANIZATION_IDS: "org-123,org-456"
```

### Step 3: Apply the upgrade

Upgrade to version `1.1.1` using your existing values:

```bash
helm upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm \
  --version 1.1.1 \
  --namespace system-facts \
  --reuse-values
```

> **Note:** The `--reuse-values` flag preserves your existing configuration. If you changed your values file in Step 2, add `-f <your-values-file>` so the new `LICENSE_KEY` is applied.

### Step 4: Monitor the upgrade

Watch the rollout status for the System Facts service:

```bash
kubectl rollout status deployment/system-facts -n system-facts
```

If the worker is enabled, monitor its rollout:

```bash
kubectl rollout status deployment/system-facts-worker -n system-facts
```

> **Note:** The chart version bump changes the `helm.sh/chart` pod label, so the Deployment rolls. With the default single replica and `maxUnavailable: 1`, expect a short interruption. Run two or more replicas to keep the service available during the rollout.

### Step 5: Verify the upgrade

Confirm the chart version was updated:

```bash
helm list -n system-facts
```

The `CHART` column should show `system-facts-helm-1.1.1`.

Verify that all pods are running and healthy:

```bash
kubectl get pods -n system-facts
```

### Step 6: Verify ConfigMap changes

Inspect the ConfigMap to confirm `LICENSE_ENABLED` is no longer present:

```bash
kubectl get configmap system-facts -n system-facts -o yaml
```

The `LICENSE_ENABLED` key should not appear in the `data` section. The `ORGANIZATION_IDS` key should still be present if you have it configured.

---

## Preview changes before upgrading

```bash
helm diff upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm --version 1.1.1 -n system-facts --reuse-values
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm --version 1.1.1 -n system-facts --reuse-values
```
<!-- {% endraw %} -->
