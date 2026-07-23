# Helm Upgrade from v3.0.0 to v3.1.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Application version bump to 3.0.2](#1-application-version-bump-to-302)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `fetcher` chart upgrade from `3.0.0` to `3.1.0`. This is a minor release that updates the application version for both `manager` and `worker` components from `1.4.2` to `3.0.2`.

No breaking changes, no required `values.yaml` modifications, and no data migration are needed. The upgrade will trigger a rolling update of both the `manager` and `worker` Deployments to deploy the new application version.

## Features

### 1. Application version bump to 3.0.2

Both `manager` and `worker` components have been updated to application version `3.0.2` (from `1.4.2`). This is a significant version jump in the upstream application.

| Component | v3.0.0 | v3.1.0 |
|-----------|--------|--------|
| `appVersion` | `1.3.0` | `3.0.2` |
| `manager.image.tag` | `"1.4.2"` | `"3.0.2"` |
| `worker.image.tag` | `"1.4.2"` | `"3.0.2"` |

**Before (v3.0.0):**

```yaml
manager:
  image:
    repository: lerianstudio/fetcher-manager
    pullPolicy: IfNotPresent
    tag: "1.4.2"

worker:
  image:
    repository: lerianstudio/fetcher-worker
    pullPolicy: IfNotPresent
    tag: "1.4.2"
```

**After (v3.1.0):**

```yaml
manager:
  image:
    repository: lerianstudio/fetcher-manager
    pullPolicy: IfNotPresent
    tag: "3.0.2"

worker:
  image:
    repository: lerianstudio/fetcher-worker
    pullPolicy: IfNotPresent
    tag: "3.0.2"
```

> **Note:** Consult the upstream `fetcher` application release notes for details on changes between `1.4.2` and `3.0.2`. The version jump from `1.x` to `3.x` suggests significant application-level changes may be included.

> **Important:** Test this upgrade in a non-production environment first to verify compatibility with your existing data and workflows.

## Configuration Changes

No `values.yaml` keys were added, removed, or changed. The only modifications are the default image tag values for both components.

| Setting | v3.0.0 | v3.1.0 |
|---------|--------|--------|
| `manager.image.tag` | `"1.4.2"` | `"3.0.2"` |
| `worker.image.tag` | `"1.4.2"` | `"3.0.2"` |

## Migration Steps

This upgrade requires no manual migration steps. The Helm upgrade will perform a rolling update of both the `manager` and `worker` Deployments with the new application version.

**Recommended upgrade process:**

1. Review the upstream `fetcher` application changelog for version `3.0.2` to understand any behavioral changes or new features.
2. Test the upgrade in a staging or development environment first.
3. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
4. Run the upgrade command during a maintenance window.
5. Verify both manager and worker pods are running the new version:

```bash
kubectl get pods -n fetcher -l app.kubernetes.io/component=manager -o jsonpath='{.items[*].spec.containers[0].image}'
kubectl get pods -n fetcher -l app.kubernetes.io/component=worker -o jsonpath='{.items[*].spec.containers[0].image}'
```

6. Check manager and worker logs for any errors or warnings:

```bash
kubectl logs -n fetcher -l app.kubernetes.io/component=manager --tail=50
kubectl logs -n fetcher -l app.kubernetes.io/component=worker --tail=50
```

7. Monitor application metrics and health endpoints to ensure the new version is functioning correctly.

> **Note:** The rolling update strategy will ensure zero-downtime deployment. Pods will be replaced one at a time, with readiness probes ensuring traffic is only routed to healthy pods.

## Preview changes before upgrading

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.1.0 -n fetcher
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.1.0 -n fetcher
```
