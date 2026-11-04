<!-- {% raw %} -->
# Helm Upgrade from v4.1.2 to v4.1.3

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Pod label stability across chart upgrades](#1-pod-label-stability-across-chart-upgrades)
  - [2. Checksum annotation accuracy](#2-checksum-annotation-accuracy)
  - [3. AWS DocumentDB TLS certificate verification](#3-aws-documentdb-tls-certificate-verification)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `fetcher` chart upgrade from `4.1.2` to `4.1.3`. This is a **patch** release that fixes pod restart behavior during chart upgrades, improves checksum annotation accuracy, and corrects MongoDB TLS configuration for AWS DocumentDB deployments.

The application version (`appVersion: 4.1.0`) is unchanged. No breaking changes, no required `values.yaml` modifications, and no data migration are needed.

## Fixes

### 1. Pod label stability across chart upgrades

The chart previously included the `helm.sh/chart` label (which contains the chart version) in the pod template labels for both `manager` and `worker` Deployments. This caused Kubernetes to detect a pod spec change on every chart upgrade, triggering unnecessary pod restarts even when no application configuration changed.

**Before (v4.1.2):**

```yaml
# manager Deployment pod template
metadata:
  labels:
    helm.sh/chart: fetcher-4.1.2
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: fetcher-manager
    app.kubernetes.io/instance: fetcher
    app.kubernetes.io/component: manager
```

**After (v4.1.3):**

```yaml
# manager Deployment pod template
metadata:
  labels:
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: fetcher-manager
    app.kubernetes.io/instance: fetcher
    app.kubernetes.io/component: manager
```

The `helm.sh/chart` label is now applied only to the Deployment resource itself (not the pod template), while pod-level labels remain stable across chart version bumps.

| Component | Label scope | v4.1.2 | v4.1.3 |
|-----------|-------------|--------|--------|
| `manager` Deployment | Resource labels | Includes `helm.sh/chart` | Includes `helm.sh/chart` |
| `manager` Deployment | Pod template labels | Includes `helm.sh/chart` | Excludes `helm.sh/chart` |
| `worker` Deployment | Resource labels | Includes `helm.sh/chart` | Includes `helm.sh/chart` |
| `worker` Deployment | Pod template labels | Includes `helm.sh/chart` | Excludes `helm.sh/chart` |

> **Note:** This change reduces unnecessary pod churn during chart upgrades. Pods will only restart when application configuration (ConfigMaps, Secrets, or container specs) actually changes.

### 2. Checksum annotation accuracy

The chart uses checksum annotations on pod templates to trigger rolling updates when ConfigMaps or Secrets change. Previously, the checksum was computed over the entire rendered YAML document (including metadata and resource type), which could produce false positives if only non-data fields changed.

**Before (v4.1.2):**

```yaml
# manager Deployment pod template annotations
annotations:
  checksum/config: {{ include (print $.Template.BasePath "/manager/configmap.yaml") . | sha256sum }}
  checksum/secret: {{ include (print $.Template.BasePath "/manager/secrets.yaml") . | sha256sum }}
  checksum/common-config: {{ include (print $.Template.BasePath "/common/configmap.yaml") . | sha256sum }}
  checksum/common-secret: {{ include (print $.Template.BasePath "/common/secrets.yaml") . | sha256sum }}
```

**After (v4.1.3):**

```yaml
# manager Deployment pod template annotations
annotations:
  checksum/config: {{ (include (print $.Template.BasePath "/manager/configmap.yaml") . | fromYaml).data | toYaml | sha256sum }}
  checksum/secret: {{ (include (print $.Template.BasePath "/manager/secrets.yaml") . | fromYaml).data | toYaml | sha256sum }}
  checksum/common-config: {{ (include (print $.Template.BasePath "/common/configmap.yaml") . | fromYaml).data | toYaml | sha256sum }}
  checksum/common-secret: {{ (include (print $.Template.BasePath "/common/secrets.yaml") . | fromYaml).data | toYaml | sha256sum }}
```

The checksum is now computed only over the `.data` field of each ConfigMap or Secret, ignoring metadata changes.

| Component | Annotation | v4.1.2 checksum scope | v4.1.3 checksum scope |
|-----------|------------|----------------------|----------------------|
| `manager` | `checksum/config` | Entire ConfigMap YAML | ConfigMap `.data` only |
| `manager` | `checksum/secret` | Entire Secret YAML | Secret `.data` only |
| `manager` | `checksum/common-config` | Entire ConfigMap YAML | ConfigMap `.data` only |
| `manager` | `checksum/common-secret` | Entire Secret YAML | Secret `.data` only |
| `worker` | `checksum/config` | Entire ConfigMap YAML | ConfigMap `.data` only |
| `worker` | `checksum/secret` | Entire Secret YAML | Secret `.data` only |
| `worker` | `checksum/common-config` | Entire ConfigMap YAML | ConfigMap `.data` only |
| `worker` | `checksum/common-secret` | Entire Secret YAML | Secret `.data` only |

> **Note:** This change improves checksum stability. Pods will only restart when the actual configuration data changes, not when metadata (labels, annotations on the ConfigMap/Secret resource) is modified.

### 3. AWS DocumentDB TLS certificate verification

When `global.cloud` is set to `"aws"` and MongoDB connection parameters are not explicitly configured, the chart previously included `tlsInsecure=true` in the default `MONGO_PARAMETERS` connection string. This disabled TLS certificate verification for AWS DocumentDB connections, which is unnecessary because the fetcher application trusts the AWS RDS CA bundle by default.

**Before (v4.1.2):**

```yaml
# Default MONGO_PARAMETERS for AWS cloud preset (when not explicitly set)
MONGO_PARAMETERS: "tlsInsecure=true&tls=true"
```

**After (v4.1.3):**

```yaml
# Default MONGO_PARAMETERS for AWS cloud preset (when not explicitly set)
MONGO_PARAMETERS: "tls=true"
```

The `tlsInsecure=true` parameter is now removed from the AWS preset default. If you have explicitly set `MONGO_PARAMETERS` via any of the following configuration paths, your value is preserved unchanged:

- `secrets.MONGO_PARAMETERS`
- `global.datastores.mongo.params`
- `manager.dedicated.mongo.params` or `worker.dedicated.mongo.params`

| Configuration source | v4.1.2 behavior | v4.1.3 behavior |
|---------------------|----------------|----------------|
| AWS preset (no explicit params) | `tlsInsecure=true&tls=true` | `tls=true` |
| Explicitly set params (any source) | User value unchanged | User value unchanged |
| Non-AWS cloud preset | User value or empty | User value or empty |

> **Important:** If you are using AWS DocumentDB and have relied on the implicit `tlsInsecure=true` default, your connections will now verify TLS certificates. Ensure your DocumentDB cluster uses a certificate signed by the AWS RDS CA bundle, or explicitly set `tlsInsecure=true` in your values if certificate verification must be disabled.

**Example configuration to preserve insecure TLS (not recommended):**

```yaml
secrets:
  MONGO_PARAMETERS: "tlsInsecure=true&tls=true"
```

> **Note:** Enabling TLS certificate verification improves security posture for AWS DocumentDB connections. This change aligns with AWS best practices.

## Configuration Changes

No `values.yaml` keys were added, removed, or changed. All fixes are internal template logic improvements with no required operator action.

| Setting | v4.1.2 | v4.1.3 |
|---------|--------|--------|
| Pod template labels | Include `helm.sh/chart` | Exclude `helm.sh/chart` |
| Checksum annotation scope | Entire resource YAML | `.data` field only |
| AWS preset `MONGO_PARAMETERS` default | `tlsInsecure=true&tls=true` | `tls=true` |

## Migration Steps

This upgrade requires no manual migration steps for most deployments. The Helm upgrade will roll both `manager` and `worker` Deployments with the corrected templates.

**Recommended upgrade process:**

1. If you are using AWS DocumentDB with `global.cloud: aws` and have not explicitly set `MONGO_PARAMETERS`, verify that your DocumentDB cluster certificate is trusted by the fetcher application. If certificate verification will fail, explicitly configure `tlsInsecure=true` before upgrading:

```yaml
secrets:
  MONGO_PARAMETERS: "tlsInsecure=true&tls=true"
```

2. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

3. Run the upgrade command during a maintenance window.

4. Verify that both manager and worker pods are healthy after the upgrade:

```bash
kubectl get pods -n midaz-plugins -l app.kubernetes.io/name=fetcher-manager
kubectl get pods -n midaz-plugins -l app.kubernetes.io/name=fetcher-worker
```

5. Check manager and worker logs for MongoDB connection errors:

```bash
kubectl logs -n midaz-plugins -l app.kubernetes.io/component=manager --tail=50
kubectl logs -n midaz-plugins -l app.kubernetes.io/component=worker --tail=50
```

> **Note:** The upgrade will trigger a rolling restart of both manager and worker pods due to the pod label and checksum annotation changes. Plan for brief service interruption during the rollout.

## Preview changes before upgrading

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm -n midaz-plugins --version 4.1.3
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm -n midaz-plugins --version 4.1.3
```
<!-- {% endraw %} -->
