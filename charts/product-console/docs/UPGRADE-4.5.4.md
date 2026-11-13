<!-- {% raw %} -->
# Helm Upgrade from v4.5.3 to v4.5.4

## Topics

- **[Overview](#overview)**
- **[Changes](#changes)**
  - [1. Application version upgrade to 3.4.0](#1-application-version-upgrade-to-340)
  - [2. MongoDB existingSecret formatting cleanup](#2-mongodb-existingsecret-formatting-cleanup)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This chart patch updates the default product-console application from 3.2.0 to 3.4.0 and includes a cosmetic MongoDB subchart formatting fix. The application also attempts to delete the legacy MongoDB `license_files` collection during startup. Treat this as a persistent-data change: prepare a private backup and a recovery plan before starting the new application. Helm rollback cannot restore deleted MongoDB data.

| Field | v4.5.3 | v4.5.4 |
|-------|--------|--------|
| Chart version | `4.5.3` | `4.5.4` |
| App version | `3.2.0` | `3.4.0` |
| Image tag | `3.2.0` | `3.4.0` |

## Changes

### 1. Application version upgrade to 3.4.0

The default product-console image changes from 3.2.0 to 3.4.0. A preserved `image.tag` override takes precedence: if your complete values still pin 3.2.0, the upgrade retains that image. Deliberately update the intended pin to 3.4.0 before previewing; a chart upgrade alone does not override it.

| Setting | v4.5.3 | v4.5.4 |
|---------|--------|--------|
| `appVersion` | `3.2.0` | `3.4.0` |
| `image.tag` | `"3.2.0"` | `"3.4.0"` |

**Impact:**

Check the effective image tag and license configuration before upgrading. In application 3.4.0, startup calls `dropLicenseFiles()` after validating the MongoDB connection and then starts license validation using `LICENSE_KEY`. The collection deletion is asynchronous; a warning or healthy rollout does not prove whether the collection was removed. Preserve unrelated configuration and existing Secret references, and confirm the required license key is supplied securely. Do not rely on a legacy stored license file after upgrading.

### 2. MongoDB existingSecret formatting cleanup

The `mongodb.auth.existingSecret` value has been reformatted to improve readability. The template logic remains identical — this is purely a cosmetic change.

**Before (v4.5.3):**

```yaml
mongodb:
  auth:
    existingSecret: '{{ if eq .Chart.Name "mongodb" }}{{ include "common.names.fullname"
      . }}{{ end }}'
```

**After (v4.5.4):**

```yaml
mongodb:
  auth:
    existingSecret: '{{ if eq .Chart.Name "mongodb" }}{{ include "common.names.fullname" . }}{{ end }}'
```

**Impact:**

This is a formatting-only change with no functional impact. The template expression continues to point the MongoDB subchart at the same secret name. No action is required from operators.

## Migration Steps

The application version bump includes a destructive legacy-collection cleanup. Do not proceed without a verified backup and an operator-approved recovery plan for the prior application and license configuration.

**Recommended upgrade process:**

1. Save current Helm values and manifests privately, retain chart 4.5.3 and the prior effective application image, and take a consistent backup of the actual Console MongoDB database, including `license_files` if present. Use your established, tested backup/restore procedure; neither Helm nor the chart backs up this collection. Protect backups and do not commit credentials or license material.

2. Prepare `product-console-values.yaml` as the **complete intended configuration**. Preserve unrelated settings, storage and Secret references; deliberately set the intended image to 3.4.0 rather than retaining an old pin. Verify the effective `LICENSE_KEY` reference securely. The commands below use `--reset-values -f`: omitted settings fall back to chart defaults. Review the diff before applying.

3. Run the upgrade during a maintenance window. If rollback is needed, stop the new application's writers before restoring data using the established recovery procedure, recover the required legacy collection and license configuration, and use the prior chart with its complete values and prior image. Do not run the new application against the recovered collection during recovery: it can delete it again. Helm rollback alone is not data recovery. Validate restoration in isolation before relying on this downgrade path.

4. Verify the deployment is healthy and running the intended new application version:

```bash
kubectl rollout status deployment/product-console -n product-console
kubectl get pods -n product-console -l app.kubernetes.io/name=product-console -o jsonpath='{.items[0].spec.containers[0].image}'
```

5. Monitor application logs for issues and validate authenticated Console access and license behavior:

```bash
kubectl logs -n product-console -l app.kubernetes.io/name=product-console --tail=100 -f
```

> **Note:** Source and template checks are not a live upgrade, backup or restore exercise. Test your recovery procedure before production; a successful rollout does not prove recoverability or completion of the asynchronous collection cleanup.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm -n product-console --version 4.5.4 --reset-values -f product-console-values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm -n product-console --version 4.5.4 --reset-values -f product-console-values.yaml
```
<!-- {% endraw %} -->
