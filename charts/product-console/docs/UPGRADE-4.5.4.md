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

This is a patch release that upgrades the product-console application from version 3.2.0 to 3.4.0 and includes a cosmetic formatting fix for the MongoDB subchart configuration. No breaking changes are introduced.

| Field | v4.5.3 | v4.5.4 |
|-------|--------|--------|
| Chart version | `4.5.3` | `4.5.4` |
| App version | `3.2.0` | `3.4.0` |
| Image tag | `3.2.0` | `3.4.0` |

## Changes

### 1. Application version upgrade to 3.4.0

The product-console application has been upgraded from version 3.2.0 to 3.4.0. The image tag is automatically updated to match the new appVersion.

| Setting | v4.5.3 | v4.5.4 |
|---------|--------|--------|
| `appVersion` | `3.2.0` | `3.4.0` |
| `image.tag` | `"3.2.0"` | `"3.4.0"` |

**Impact:**

No configuration changes are required for this upgrade. The new application version will be deployed automatically during the Helm upgrade.

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

This upgrade requires no mandatory configuration changes. The application version bump is the only functional change.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Run the upgrade command during a maintenance window.

3. Verify the deployment is healthy and running the new application version:

```bash
kubectl rollout status deployment/product-console -n product-console
kubectl get pods -n product-console -l app.kubernetes.io/name=product-console -o jsonpath='{.items[0].spec.containers[0].image}'
```

4. Monitor application logs for any issues after the upgrade:

```bash
kubectl logs -n product-console -l app.kubernetes.io/name=product-console --tail=100 -f
```

> **Note:** This upgrade changes the application image from 3.2.0 to 3.4.0. Review the product-console application release notes for details on what changed between these versions.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm -n product-console --version 4.5.4
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm -n product-console --version 4.5.4
```
<!-- {% endraw %} -->
