# Helm Upgrade from v4.1.2 to v4.1.3

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Default MONGO_PARAMETERS on global.cloud: aws drops tlsInsecure=true](#1-default-mongo_parameters-on-globalcloud-aws-drops-tlsinsecuretrue)
  - [2. Pod templates no longer carry the chart version](#2-pod-templates-no-longer-carry-the-chart-version)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `fetcher` chart upgrade from `4.1.2` to `4.1.3`. This is a **patch** release. The application version (`appVersion: 4.1.0`) is unchanged, and no `values.yaml` key is added, removed or renamed.

No action is required before the upgrade. The `manager` and `worker` pods restart once during the upgrade (see section 2).

## Fixes

### 1. Default MONGO_PARAMETERS on global.cloud: aws drops tlsInsecure=true

With `global.cloud: aws` and no explicit params value, the default `MONGO_PARAMETERS` no longer includes `tlsInsecure=true`. DocumentDB connections use the AWS RDS CA set that ships in the application image.

On `global.cloud: aws`, check the `MONGO_PARAMETERS` line in the `helm diff` output before you upgrade.

**Rendered `MONGO_PARAMETERS` with `global.cloud: aws` and no explicit params value:**

```yaml
# v4.1.2
MONGO_PARAMETERS: "tls=true&tlsInsecure=true&directConnection=true&retryWrites=false&connectTimeoutMS=10000&serverSelectionTimeoutMS=10000"

# v4.1.3
MONGO_PARAMETERS: "tls=true&directConnection=true&retryWrites=false&connectTimeoutMS=10000&serverSelectionTimeoutMS=10000"
```

| Setting | v4.1.2 | v4.1.3 |
|---------|--------|--------|
| `MONGO_PARAMETERS` (`global.cloud: aws`, no explicit value) | includes `tlsInsecure=true` | `tlsInsecure=true` removed |
| `MONGO_PARAMETERS` (explicit value) | as set | as set (unchanged) |
| `MONGO_PARAMETERS` (other `global.cloud` values) | unchanged | unchanged |

An explicitly set value renders unchanged, whether you set it in `global.datastores.mongo.params`, in `datastores.mongo.params` or in `common.configmap.MONGO_PARAMETERS`. If you set `tlsInsecure=true` there, it stays.

### 2. Pod templates no longer carry the chart version

The `helm.sh/chart` label is removed from the `manager` and `worker` pod templates. It stays on every other resource. The `checksum/*` annotations now hash only the `data` of the ConfigMaps and Secrets, so a chart version bump alone no longer changes them.

The pod template changes in this release, so the `manager` and `worker` Deployments each roll once. From this release on, a chart version bump alone does not restart the pods.

## Configuration Changes

| Setting | v4.1.2 | v4.1.3 | Action Required |
|---------|--------|--------|-----------------|
| `MONGO_PARAMETERS` on `global.cloud: aws` | includes `tlsInsecure=true` | no `tlsInsecure=true` | None |
| `helm.sh/chart` on pod templates | present | removed | None (one pod restart) |

## Migration Steps

1. **Preview the changes** using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. **Run the upgrade** (see [Command to upgrade](#command-to-upgrade)).

3. **Verify pods are healthy** after the roll:

```bash
kubectl get pods -n fetcher
```

4. **On `global.cloud: aws`, check that the manager and worker connect to DocumentDB:**

```bash
kubectl logs -n fetcher -l app.kubernetes.io/component=manager --tail=50
kubectl logs -n fetcher -l app.kubernetes.io/component=worker --tail=50
```

If either component logs a certificate verification error against DocumentDB, set `global.datastores.mongo.params` explicitly for your environment and upgrade again.

## Preview changes before upgrading

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 4.1.3 -n fetcher
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 4.1.3 -n fetcher
```
