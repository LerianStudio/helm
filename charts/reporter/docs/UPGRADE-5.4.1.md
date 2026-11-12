<!-- {% raw %} -->
# Helm Upgrade from v5.4.0 to v5.4.1

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
  - [1. Manager image updated to 4.9.0](#1-manager-image-updated-to-490)
  - [2. Worker image updated to 4.9.0](#2-worker-image-updated-to-490)
- **[Application behavior changes in 4.9.0](#application-behavior-changes-in-490)**
  - [1. Only a person can approve a regulatory report](#1-only-a-person-can-approve-a-regulatory-report)
  - [2. License: licenseFile now works, and LICENSE_KEY stores the license in MongoDB](#2-license-licensefile-now-works-and-license_key-stores-the-license-in-mongodb)
- **[Fixes](#fixes)**
  - [1. MongoDB existingSecret template formatting corrected](#1-mongodb-existingsecret-template-formatting-corrected)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `4.8.0` to `4.9.0` for both the manager and worker components. The release also includes a minor formatting fix for the MongoDB `existingSecret` template. The chart itself adds no configuration change, but app `4.9.0` changes behavior: an application (M2M) token can no longer approve a regulatory report, and the license handling moves to lib-license-go v5. Read [Application behavior changes in 4.9.0](#application-behavior-changes-in-490) before upgrading.

| Field | v5.4.0 | v5.4.1 |
|-------|--------|--------|
| Chart version | `5.4.0` | `5.4.1` |
| App version | `4.8.0` | `4.9.0` |
| Manager image tag | `4.8.0` | `4.9.0` |
| Worker image tag | `4.8.0` | `4.9.0` |

## Application Version Update

### 1. Manager image updated to 4.9.0

The manager component image tag has been updated from `4.8.0` to `4.9.0`.

| Setting | v5.4.0 | v5.4.1 |
|---------|--------|--------|
| `manager.image.tag` | `"4.8.0"` | `"4.9.0"` |

**Before (v5.4.0):**

```yaml
manager:
  image:
    tag: "4.8.0"
```

**After (v5.4.1):**

```yaml
manager:
  image:
    tag: "4.9.0"
```

### 2. Worker image updated to 4.9.0

The worker component image tag has been updated from `4.8.0` to `4.9.0`.

| Setting | v5.4.0 | v5.4.1 |
|---------|--------|--------|
| `worker.image.tag` | `"4.8.0"` | `"4.9.0"` |

**Before (v5.4.0):**

```yaml
worker:
  image:
    tag: "4.8.0"
```

**After (v5.4.1):**

```yaml
worker:
  image:
    tag: "4.9.0"
```

## Application behavior changes in 4.9.0

### 1. Only a person can approve a regulatory report

Since app `4.9.0`, a regulatory approval request (`POST` on the regulatory approval route) sent with an application (M2M) token is refused with `403 RPT-0201` ("Only a person can approve a regulatory report"), and the report stays unapproved. A person holding the `regulatory-approval: post` permission approves in the Console as before. Every other permission of the application stays available, so a workflow can still generate, follow and correct a report.

This affects every deployment where lib-auth M2M inversion is on (`AUTH_M2M_INVERSION_ENABLED=true`, as in Lerian Cloud). The chart does not set this variable, so also check releases that add it through extra environment variables. Where the inversion is off, an application already got `401 RPT-0158` on this route, and nothing changes.

**Action:** if a workflow or integration approves regulatory reports with an application token, move that approval to a person in the Console before upgrading.

### 2. License: licenseFile now works, and LICENSE_KEY stores the license in MongoDB

App `4.9.0` is the first image on lib-license-go v5:

- **`manager.licenseFile` / `worker.licenseFile`:** the chart already supported a mounted, signed license file (`LICENSE_FILE_PATH`), but the `4.8.0` image ignored it. From `4.9.0` it works. With a license file, reporter does not call the license server and does not use MongoDB for the license.
- **`LICENSE_KEY`:** with a license key, the manager and the worker keep the signed license file in the `lerian_license_file` collection of the `MONGO_NAME` database. MongoDB creates the collection on first use, in the database reporter already writes to, so a user with `readWrite` on that database needs no change. Reporter already connected to MongoDB at boot, so no new connection setting is needed.
- **License server unavailable:** if the license server does not answer at boot, the pod stays alive but not ready (`/readyz` fails) and retries until a license is accepted. It no longer exits. A real verdict (for example, an invalid or revoked license) still refuses to start. Because the manager Deployment uses `maxUnavailable: 0`, a new manager pod that never becomes ready stops the rollout, and the `4.8.0` pods keep serving traffic. If the rollout does not finish, check the license logs of the new pods.

## Fixes

### 1. MongoDB existingSecret template formatting corrected

The `mongodb.auth.existingSecret` template has been reformatted to remove unnecessary line breaks. This change improves readability but does not affect the rendered output or functionality.

| Setting | v5.4.0 | v5.4.1 |
|---------|--------|--------|
| `mongodb.auth.existingSecret` | Multi-line template with line break | Single-line template |

**Before (v5.4.0):**

```yaml
mongodb:
  auth:
    existingSecret: '{{ if eq .Chart.Name "mongodb" }}{{ include "common.names.fullname"
      . }}{{ end }}'
```

**After (v5.4.1):**

```yaml
mongodb:
  auth:
    existingSecret: '{{ if eq .Chart.Name "mongodb" }}{{ include "common.names.fullname" . }}{{ end }}'
```

> **Note:** This is a cosmetic change that does not affect the behavior of the chart. The rendered secret name remains identical.

## Migration Steps

This upgrade requires no chart configuration change. Before upgrading, check the two application behavior changes above: regulatory approval by an application token, and MongoDB write access for the license collection when you use `LICENSE_KEY`.

The upgrade triggers a rolling restart of the manager Deployment (and of the worker Deployment when KEDA is disabled). With the default KEDA ScaledJob, the image change updates the ScaledJob, and KEDA deletes the existing worker Jobs, **including Jobs that are generating a report**. Those reports are interrupted.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Run the upgrade command during a maintenance window, when no report is being generated. With the default KEDA ScaledJob, check that no worker Job is running:

```bash
kubectl get jobs -n <namespace> -l scaledjob.keda.sh/name=reporter-worker
```

3. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

4. Check that the new image versions are deployed:

```bash
kubectl describe pod -n <namespace> -l app.kubernetes.io/name=reporter-manager | grep Image:
# Worker, default KEDA ScaledJob (pods exist only while a report Job runs); with KEDA disabled use -l app.kubernetes.io/name=reporter-worker
kubectl describe pod -n <namespace> -l scaledjob.keda.sh/name=reporter-worker | grep Image:
```

5. Verify application logs for both components:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-manager --tail=50
# Worker, default KEDA ScaledJob; with KEDA disabled use -l app.kubernetes.io/name=reporter-worker
kubectl logs -n <namespace> -l scaledjob.keda.sh/name=reporter-worker --tail=50
```

> **Note:** With the default KEDA ScaledJob, KEDA creates new worker Jobs with the `4.9.0` image when new report messages arrive. If a report was being generated during the upgrade, check its status after the upgrade.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n <namespace> --version 5.4.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n <namespace> --version 5.4.1
```
<!-- {% endraw %} -->
