# Helm Upgrade from v2.1.0 to v2.1.1

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Infrastructure Image Repository Migration](#infrastructure-image-repository-migration)**
  - [1. Valkey Repository Change](#1-valkey-repository-change)
  - [2. PostgreSQL Repository Change](#2-postgresql-repository-change)
  - [3. MongoDB Repository Change](#3-mongodb-repository-change)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review Image Repository Changes](#step-1-review-image-repository-changes)
  - [Step 2: Verify Image Pull Configuration](#step-2-verify-image-pull-configuration)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 2.1.1 is a patch release that updates the application version from 2.2.0 to 3.0.0 and migrates all Bitnami infrastructure dependencies (Valkey, PostgreSQL, MongoDB) from the `bitnami/*` Docker Hub repositories to `bitnamilegacy/*` repositories. This migration is required because Bitnami has deprecated their Docker Hub images in favor of OCI registry distribution. The `bitnamilegacy` namespace serves the same image tags, ensuring data compatibility and zero downtime during the upgrade.

The release also sets `global.security.allowInsecureImages=true` for all three subcharts to permit pulling from the legacy repositories. This is a temporary measure to maintain compatibility while the ecosystem transitions to OCI registries.

## Application Version Update

**What changed:**  
The default container image tag has been updated to align with the new application version.

| Setting | v2.1.0 | v2.1.1 |
|---------|--------|--------|
| `appVersion` (Chart.yaml) | `2.2.0` | `3.0.0` |
| `bankTransfer.image.tag` | `2.2.0` | `3.0.0` |

**Why it matters:**  
The application container will be updated to version 3.0.0, which may include bug fixes, performance improvements, or new features at the application level. Refer to the application's release notes for details on what changed in the application itself.

**Operational impact:**  
- The bank-transfer deployment will perform a rolling update to the new image version
- If you have explicitly set `bankTransfer.image.tag` in your values, that override will continue to be respected
- No configuration changes are required unless you want to pin to a specific version

**Migration required:**  
No — the upgrade is automatic. If you have overridden `bankTransfer.image.tag` in your values and want to use the new default, remove the override:

```yaml
# Remove this override to use the chart's new default (3.0.0)
bankTransfer:
  image:
    tag: "2.2.0"  # Delete this line to use 3.0.0
```

## Infrastructure Image Repository Migration

All three Bitnami infrastructure subcharts (Valkey, PostgreSQL, MongoDB) have been migrated from `bitnami/*` to `bitnamilegacy/*` Docker Hub repositories. This change is accompanied by setting `global.security.allowInsecureImages=true` for each subchart.

**Why this matters:**  
Bitnami has deprecated their Docker Hub image distribution in favor of OCI registries. The `bitnamilegacy` namespace on Docker Hub serves the same image tags as the original `bitnami/*` repositories, ensuring that existing data volumes remain readable and no data migration is required. The `allowInsecureImages` flag is set to `true` because the legacy repositories may not meet the latest security scanning requirements, but the images themselves are functionally identical to the previous versions.

**Operational impact:**  
- Kubernetes will pull images from `bitnamilegacy/*` instead of `bitnami/*` during the upgrade
- Image tags remain unchanged (Valkey 8.0.2, PostgreSQL 17.4.0, MongoDB 8.0.5)
- Existing PersistentVolumes and data formats are fully compatible — no data migration required
- The upgrade will trigger a rolling restart of each infrastructure component as new images are pulled

**Migration required:**  
No — the change is transparent to operators. Existing data volumes will work without modification. See [Migration Steps](#migration-steps) if you need to customize image pull behavior.

### 1. Valkey Repository Change

**Before (v2.1.0):**
```yaml
valkey:
  enabled: true
  global:
    security:
      allowInsecureImages: false
  image:
    repository: bitnami/valkey
    tag: "8.0.2"
```

**After (v2.1.1):**
```yaml
valkey:
  enabled: true
  # Here, in postgresql and in mongodb: bitnami/* tags are gone; bitnamilegacy serves the same tags, so data stays readable.
  global:
    security:
      allowInsecureImages: true
  image:
    repository: bitnamilegacy/valkey
    tag: "8.0.2"
```

| Setting | v2.1.0 | v2.1.1 |
|---------|--------|--------|
| `valkey.image.repository` | `bitnami/valkey` | `bitnamilegacy/valkey` |
| `valkey.global.security.allowInsecureImages` | `false` | `true` |
| `valkey.image.tag` | `8.0.2` | `8.0.2` (unchanged) |

### 2. PostgreSQL Repository Change

**Before (v2.1.0):**
```yaml
postgresql:
  enabled: true
  global:
    security:
      allowInsecureImages: false
  image:
    repository: bitnami/postgresql
    tag: "17.4.0"
```

**After (v2.1.1):**
```yaml
postgresql:
  enabled: true
  global:
    security:
      allowInsecureImages: true
  image:
    repository: bitnamilegacy/postgresql
    tag: "17.4.0"
```

| Setting | v2.1.0 | v2.1.1 |
|---------|--------|--------|
| `postgresql.image.repository` | `bitnami/postgresql` | `bitnamilegacy/postgresql` |
| `postgresql.global.security.allowInsecureImages` | `false` | `true` |
| `postgresql.image.tag` | `17.4.0` | `17.4.0` (unchanged) |

### 3. MongoDB Repository Change

**Before (v2.1.0):**
```yaml
mongodb:
  enabled: true
  global:
    security:
      allowInsecureImages: false
  image:
    repository: bitnami/mongodb
    tag: "8.0.5"
```

**After (v2.1.1):**
```yaml
mongodb:
  enabled: true
  global:
    security:
      allowInsecureImages: true
  image:
    repository: bitnamilegacy/mongodb
    tag: "8.0.5"
```

| Setting | v2.1.0 | v2.1.1 |
|---------|--------|--------|
| `mongodb.image.repository` | `bitnami/mongodb` | `bitnamilegacy/mongodb` |
| `mongodb.global.security.allowInsecureImages` | `false` | `true` |
| `mongodb.image.tag` | `8.0.5` | `8.0.5` (unchanged) |

## Migration Steps

### Step 1: Review Image Repository Changes

The repository migration is automatic and requires no action for most deployments. However, if you have overridden image repositories in your values, review the changes:

#### Option 1: Use the new defaults (recommended)

Remove any `image.repository` overrides for Valkey, PostgreSQL, or MongoDB to use the new `bitnamilegacy/*` defaults:

```yaml
# Remove these overrides to use the chart's new defaults
valkey:
  image:
    repository: bitnami/valkey  # Delete this line

postgresql:
  image:
    repository: bitnami/postgresql  # Delete this line

mongodb:
  image:
    repository: bitnami/mongodb  # Delete this line
```

#### Option 2: Pin to a custom registry

If your organization mirrors images to a private registry, update your overrides to point to your mirror:

```yaml
valkey:
  image:
    repository: my-registry.example.com/valkey
    tag: "8.0.2"

postgresql:
  image:
    repository: my-registry.example.com/postgresql
    tag: "17.4.0"

mongodb:
  image:
    repository: my-registry.example.com/mongodb
    tag: "8.0.5"
```

> **Note:** If you use a private registry, ensure the images are mirrored from `bitnamilegacy/*` (or the original `bitnami/*` tags, which are functionally identical).

### Step 2: Verify Image Pull Configuration

The `allowInsecureImages=true` setting permits pulling from the legacy repositories. If your cluster enforces strict image security policies (e.g., via admission controllers or Pod Security Policies), verify that the policy allows images from `bitnamilegacy/*` or adjust your policy accordingly.

If you need to revert to `allowInsecureImages=false` (e.g., because your private registry mirrors pass security scans), override the setting:

```yaml
valkey:
  global:
    security:
      allowInsecureImages: false

postgresql:
  global:
    security:
      allowInsecureImages: false

mongodb:
  global:
    security:
      allowInsecureImages: false
```

> **Warning:** Setting `allowInsecureImages=false` while using `bitnamilegacy/*` repositories may cause image pull failures if your cluster's security policies reject the images. Only use this override if you are pulling from a private registry that passes security scans.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.1.1 -n plugin-br-bank-transfer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm --version 2.1.1 -n plugin-br-bank-transfer
```
