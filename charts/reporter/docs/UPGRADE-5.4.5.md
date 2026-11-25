<!-- {% raw %} -->
# Helm Upgrade from v5.4.4 to v5.4.5

## Topics

- **[Overview](#overview)**
- **[Application behavior changes in 4.11.0](#application-behavior-changes-in-4110)**
- **[Fixes](#fixes)**
  - [1. Application version bump to 4.11.0](#1-application-version-bump-to-4110)
  - [2. MongoDB existingSecret value formatting corrected](#2-mongodb-existingsecret-value-formatting-corrected)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `4.10.0` to `4.11.0` and corrects a YAML formatting issue in the MongoDB subchart configuration. The chart needs no change to your values, but the application release changes behavior and asks for actions before the upgrade. Read [Application behavior changes in 4.11.0](#application-behavior-changes-in-4110) first.

| Field | v5.4.4 | v5.4.5 |
|-------|--------|--------|
| Chart version | `5.4.4` | `5.4.5` |
| App version | `4.10.0` | `4.11.0` |
| Manager image tag | `4.10.0` | `4.11.0` |
| Worker image tag | `4.10.0` | `4.11.0` |

## Application behavior changes in 4.11.0

- Read [Read before upgrading from 4.10.0](https://github.com/LerianStudio/reporter/releases/tag/v4.11.0) in the reporter v4.11.0 release notes before you upgrade. The chart does not check any of these items, so the render and the rollout succeed either way.
- **Worker before manager.** The 4.11.0 manager sends XLSX reports and file dataset fetches as message schema 5. A 4.10.0 worker refuses that schema and ends the report in Error. A single `helm upgrade` updates both components at the same time, so use the two-step upgrade in [Migration Steps](#migration-steps).
- **Console 3.7.0.** Marking a recurring deadline as delivered needs Console 3.7.0. Console 3.6.0 does not send the `occurrence` field and gets `400 RPT-0221`.
- **Saved templates.** Three template engine corrections change the output of stored templates at their next report, scheduled reports included. Some templates that finished under 4.10.0 now end in Error.
- **Multi-tenant data sources.** In a multi-tenant deployment, a PostgreSQL or MongoDB data source registered on a private, loopback or metadata address stops connecting. Check the registered data sources before the upgrade. Single-tenant deployments are not affected.
- **Permissions manifest.** In a multi-tenant deployment, the new `file-source` and `file-dataset` routes answer `403` until the manifest is reconciled into each tenant.

## Fixes

### 1. Application version bump to 4.11.0

The manager and worker image tags have been updated from `4.10.0` to `4.11.0`, and the chart `appVersion` field reflects this change.

| Component | v5.4.4 | v5.4.5 |
|-----------|--------|--------|
| Chart `appVersion` | `"4.10.0"` | `"4.11.0"` |
| `manager.image.tag` | `"4.10.0"` | `"4.11.0"` |
| `worker.image.tag` | `"4.10.0"` | `"4.11.0"` |

**Before (v5.4.4):**

```yaml
manager:
  image:
    tag: "4.10.0"

worker:
  image:
    tag: "4.10.0"
```

**After (v5.4.5):**

```yaml
manager:
  image:
    tag: "4.11.0"

worker:
  image:
    tag: "4.11.0"
```

> **Note:** What restarts depends on `keda.enabled`:
>
> - `keda.enabled: true` (default): the worker is `ScaledJob/reporter-worker`. Only `Deployment/reporter-manager` does a rolling update. The Jobs that KEDA creates after the upgrade use `4.11.0`. The ScaledJob sets no `spec.rollout`, so when it changes KEDA deletes the running Jobs of the previous version. A report in generation at that moment is lost.
> - `keda.enabled: false`: `Deployment/reporter-worker` does a rolling update, like the manager.

### 2. MongoDB existingSecret value formatting corrected

The `mongodb.auth.existingSecret` field in `values.yaml` has been reformatted to improve readability. The template logic remains functionally identical — this is a cosmetic change that splits a long line across two lines.

| Setting | v5.4.4 | v5.4.5 |
|---------|--------|--------|
| `mongodb.auth.existingSecret` | Single-line template string | Multi-line template string (same logic) |

**Before (v5.4.4):**

```yaml
mongodb:
  auth:
    existingSecret: '{{ if eq .Chart.Name "mongodb" }}{{ include "common.names.fullname" . }}{{ end }}'
```

**After (v5.4.5):**

```yaml
mongodb:
  auth:
    existingSecret: '{{ if eq .Chart.Name "mongodb" }}{{ include "common.names.fullname"
      . }}{{ end }}'
```

The rendered output is unchanged. When the MongoDB subchart is enabled, the template evaluates to the subchart's generated Secret name; when disabled, it evaluates to an empty string.

> **Note:** This change does not affect the behavior of the chart. No values override is required.

## Migration Steps

This upgrade needs no change to your values. The application release needs the actions in [Application behavior changes in 4.11.0](#application-behavior-changes-in-4110).

The upgrade moves `Deployment/reporter-manager` and the worker (`ScaledJob/reporter-worker` with KEDA, `Deployment/reporter-worker` without) to image tag `4.11.0`. See the note in [Fixes 1](#1-application-version-bump-to-4110) for what restarts.

**Recommended upgrade process:**

1. Check the items in [Application behavior changes in 4.11.0](#application-behavior-changes-in-4110): Console version, saved templates and, in multi-tenant deployments, data sources and the permissions manifest.
2. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
3. Wait until no report is in generation. With KEDA, the upgrade deletes the worker Jobs that are running.
4. Upgrade the worker first and keep the manager on `4.10.0`:

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n <namespace> --version 5.4.5 -f <your-values>.yaml --set manager.image.tag=4.10.0
```

5. Run the [upgrade command](#command-to-upgrade) without `--set manager.image.tag`. This moves the manager to `4.11.0`.
6. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

7. Check manager and worker logs to confirm the new version is running:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-manager --tail=50
# keda.enabled: true (default). Prints nothing while no report is in generation.
kubectl logs -n <namespace> -l scaledjob.keda.sh/name=reporter-worker --tail=50
# keda.enabled: false
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-worker --tail=50
```

> **Note:** Only the manager and the worker change. Existing MongoDB, RabbitMQ, and Valkey pods are not affected.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n <namespace> --version 5.4.5 -f <your-values>.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n <namespace> --version 5.4.5 -f <your-values>.yaml
```
<!-- {% endraw %} -->
