# Helm Upgrade from v2.0.0 to v2.1.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Improved SeaweedFS hostname parsing for HTTPS endpoints](#1-improved-seaweedfs-hostname-parsing-for-https-endpoints)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that improves the SeaweedFS hostname parsing logic in the init container to properly handle both HTTP and HTTPS endpoints. No breaking changes are introduced and no manual data migration is required.

## Features

### 1. Improved SeaweedFS hostname parsing for HTTPS endpoints

The init container's SeaweedFS wait logic has been updated to correctly extract hostnames from both HTTP and HTTPS URLs. The previous implementation only stripped the `http://` prefix, which caused incorrect hostname extraction when using HTTPS endpoints.

**Before (v2.0.0):**

```yaml
# Wait for SeaweedFS S3 API
SEAWEEDFS_HOST=$(echo "$OBJECT_STORAGE_ENDPOINT" | sed 's|http://||' | cut -d: -f1)
wait_for_service "$SEAWEEDFS_HOST" "8333"
```

**After (v2.1.0):**

```yaml
# Wait for SeaweedFS S3 API
SEAWEEDFS_HOST=$(echo "$OBJECT_STORAGE_ENDPOINT" | sed -E 's|^https?://||' | cut -d/ -f1 | cut -d: -f1)
wait_for_service "$SEAWEEDFS_HOST" "8333"
```

**What changed:**

The `sed` command now uses an extended regular expression (`-E` flag) with the pattern `^https?://` to match both `http://` and `https://` prefixes at the start of the URL. Additionally, the hostname extraction now properly handles URLs with paths by cutting on `/` before extracting the hostname portion.

**Why it matters:**

If your `OBJECT_STORAGE_ENDPOINT` environment variable uses an HTTPS URL (e.g., `https://seaweedfs.example.com:8333/path`), the previous version would fail to extract the correct hostname, potentially causing the init container to wait indefinitely or connect to the wrong host. The new parsing logic ensures reliable hostname extraction regardless of the protocol scheme or URL structure.

**Operational impact:**

- Deployments using HTTP endpoints (e.g., `http://seaweedfs:8333`) will continue to work without changes
- Deployments using HTTPS endpoints will now correctly parse the hostname and successfully wait for SeaweedFS availability
- The init container will be more resilient to different URL formats, including those with paths or query parameters

> **Note:** This change only affects the init container's readiness check when `seaweedfs.enabled` is `true`. If you are not using the chart-managed SeaweedFS or have disabled the init container wait logic, this change has no impact on your deployment.

## Configuration Changes

No configuration values have been added, removed, or renamed in this release. The following table summarizes the version changes:

| Setting           | v2.0.0 | v2.1.0 |
|-------------------|--------|--------|
| Chart `version`   | 2.0.0  | 2.1.0  |
| Chart `appVersion`| 1.2.0  | 1.2.0  |

All existing `values.yaml` settings remain fully compatible with version 2.1.0.

## Migration Steps

This upgrade requires no manual migration steps. The Helm upgrade will roll the pods with the updated init container logic.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading))
2. Ensure you have a recent backup of your data (if using chart-managed databases)
3. Run the upgrade command during a maintenance window
4. Verify all pods are running and healthy after the upgrade

```bash
kubectl get pods -n plugin-bc-correios
```

5. Check init container logs to confirm SeaweedFS connectivity (if enabled)

```bash
kubectl logs -n plugin-bc-correios -l app.kubernetes.io/name=plugin-bc-correios-helm -c wait-for-dependencies --tail=50
```

6. Verify application logs for any startup issues

```bash
kubectl logs -n plugin-bc-correios -l app.kubernetes.io/name=plugin-bc-correios-helm --tail=50
```

> **Note:** The upgrade will trigger a rolling restart of the BC Correios pods. Depending on your replica count and readiness probe configuration, this may cause brief service interruptions.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-bc-correios oci://registry-1.docker.io/lerianstudio/plugin-bc-correios-helm --version 2.1.0 -n plugin-bc-correios
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-bc-correios oci://registry-1.docker.io/lerianstudio/plugin-bc-correios-helm --version 2.1.0 -n plugin-bc-correios
```
