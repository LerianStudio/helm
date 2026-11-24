<!-- {% raw %} -->
# Helm Upgrade from v5.2.1 to v5.2.2

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Automatic pod restart on configuration changes](#1-automatic-pod-restart-on-configuration-changes)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that adds automatic pod restart behavior when ConfigMaps or Secrets change. The application version remains at `1.12.0` across all components. No configuration changes are required — the upgrade adds checksum annotations to all deployment templates to trigger rolling restarts when configuration data changes.

The expected upgrade path is an in-place Helm upgrade with no downtime beyond the normal rolling restart window.

| Component | v5.2.1 | v5.2.2 |
|-----------|--------|--------|
| Chart version | `5.2.1` | `5.2.2` |
| App version | `1.12.0` | `1.12.0` |
| Components | 5 (pix, inbound, outbound, reconciliation, schedule) | 5 (pix, inbound, outbound, reconciliation, schedule) |

## Fixes

### 1. Automatic pod restart on configuration changes

All five deployment templates now include checksum annotations that automatically trigger pod restarts when their associated ConfigMaps or Secrets change.

**What changed:**

Each deployment template (`pix`, `inbound`, `outbound`, `reconciliation`, `schedule`) now includes checksum annotations in the pod template metadata. These annotations compute a SHA256 hash of the ConfigMap and Secret contents, causing Kubernetes to perform a rolling restart whenever the configuration data changes.

**Why it matters:**

Before this change, updating a ConfigMap or Secret value required operators to manually restart pods to pick up the new configuration. This was error-prone and could lead to configuration drift where some pods were running with old values while others had new values.

With checksum annotations, Helm automatically triggers a rolling restart whenever you change configuration values, ensuring all pods consistently use the latest configuration.

**Operational impact:**

After upgrading to v5.2.2, any future `helm upgrade` that changes ConfigMap or Secret values will automatically trigger a rolling restart of the affected deployments. This eliminates the need for manual pod restarts after configuration changes.

The upgrade to v5.2.2 itself rolls all five deployments, because it adds these annotations to every pod template.

In the `pix` and `reconciliation` Deployments, the existing conditional `checksum/mtls` annotation stays, and the `annotations:` block is now always rendered.

**Checksum annotation behavior:**

Each deployment now includes two checksum annotations:

| Annotation | Computed From | Conditional |
|------------|---------------|-------------|
| `checksum/config` | ConfigMap template content | Always present |
| `checksum/secret` | Secret template content | Only present when `useExistingSecrets` is `false` |

The `checksum/secret` annotation is conditional because when `useExistingSecrets` is `true`, the chart does not manage the Secret resource, so changes to external secrets will not trigger automatic restarts. Operators using external secrets must manually restart pods when secret values change.

> **Important:** If you use `useExistingSecrets: true` for any component, the checksum annotation for that component's secrets will **not** be rendered. You must manually restart that component's Deployment when you update its external Secret. The Deployments are `plugin-br-pix-indirect-btg` (pix) and `plugin-br-pix-indirect-btg-worker-inbound`, `-worker-outbound`, `-worker-reconciliation` and `-worker-schedule`. For example, for pix:

```bash
kubectl rollout restart deployment/plugin-br-pix-indirect-btg -n plugin-br-pix-indirect-btg
```

## Migration Steps

This upgrade requires no configuration changes or manual intervention. The checksum annotations are automatically added to all deployments during the upgrade.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Run the upgrade command:

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.2.2 -n plugin-br-pix-indirect-btg
```

3. Verify all pods are running and healthy:

```bash
kubectl get pods -n plugin-br-pix-indirect-btg -l app.kubernetes.io/instance=plugin-br-pix-indirect-btg
```

4. Verify the checksum annotations are present on all deployments:

```bash
kubectl get deployment -n plugin-br-pix-indirect-btg -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.template.metadata.annotations}{"\t"}{@}{"\n"}{end}{"\n"}{end}'
```

You should see `checksum/config` and (if not using external secrets) `checksum/secret` annotations on all five deployments.

> **Note:** The upgrade itself rolls all five deployments, because it adds the checksum annotations to every pod template.

**Testing the automatic restart behavior:**

After upgrading, you can verify that configuration changes trigger automatic restarts by modifying a ConfigMap value:

1. Update a configuration value in your values file:

```yaml
pix:
  configmap:
    SWAGGER_ENABLED: "false"  # Change from default "true"
```

2. Run the upgrade with the modified values:

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.2.2 -n plugin-br-pix-indirect-btg -f your-values.yaml
```

3. Observe that the `pix` deployment automatically performs a rolling restart:

```bash
kubectl rollout status deployment/plugin-br-pix-indirect-btg -n plugin-br-pix-indirect-btg
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.2.2 -n plugin-br-pix-indirect-btg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.2.2 -n plugin-br-pix-indirect-btg
```
<!-- {% endraw %} -->
