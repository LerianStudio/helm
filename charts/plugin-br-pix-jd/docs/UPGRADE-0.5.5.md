# Helm Upgrade from v0.5.4 to v0.5.5

## Topics

- **[Overview](#overview)**
- **[What Changed](#what-changed)**
  - [1. Application Version Bump](#1-application-version-bump)
  - [2. Migration Schema Updates](#2-migration-schema-updates)
  - [3. Chart Formatting Cleanup](#3-chart-formatting-cleanup)
- **[Migration Impact](#migration-impact)**
- **[Configuration Changes](#configuration-changes)**
  - [Image Tag Updates](#image-tag-updates)
  - [Migration Image Configuration](#migration-image-configuration)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review Image Tag Pins](#step-1-review-image-tag-pins)
  - [Step 2: Verify Migration Job Configuration](#step-2-verify-migration-job-configuration)
  - [Step 3: Plan Rollout Order](#step-3-plan-rollout-order)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a **patch release** upgrading the `plugin-br-pix-jd` chart from v0.5.4 to v0.5.5. The primary change is an application version bump from `1.2.4` to `1.3.0`, which includes new database migrations (schemas 000045-000055) that are **required** for the application to function correctly.

| Setting | v0.5.4 | v0.5.5 |
|---------|--------|--------|
| Chart Version | 0.5.4 | 0.5.5 |
| App Version | 1.2.4 | 1.3.0 |
| API Image Tag (default) | `""` (falls back to 1.2.4) | `"1.3.0"` (explicitly pinned) |
| Migrations Image Tag | `"1.2.4"` | `"1.3.0"` |

## What Changed

### 1. Application Version Bump

The chart's `appVersion` has been updated from `1.2.4` to `1.3.0`, reflecting a minor version bump in the underlying application. This version includes functional changes that require corresponding database schema updates.

**Chart.yaml changes:**

| Field | v0.5.4 | v0.5.5 |
|-------|--------|--------|
| `version` | 0.5.4 | 0.5.5 |
| `appVersion` | 1.2.4 | 1.3.0 |

### 2. Migration Schema Updates

The migrations image has been updated to `1.3.0`, which adds **eleven new migration files** (000045-000055). These migrations are critical for the 1.3.0 application binary to operate correctly.

**Migration 000054 is particularly critical:** Without this migration, no Pix transactions can be created or settled. The application will fail at runtime if the schema is not updated before the new pods start serving traffic.

**values.yaml changes:**

**Before (v0.5.4):**

```yaml
migrations:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-migrations
    # -- Pinned explicitly: api, worker and migrations are all published at 1.2.4.
    # Migrations are independently versioned; a release that does not touch the SQL
    # skips this image, so re-check the pin on every appVersion bump.
    tag: "1.2.4"
    pullPolicy: IfNotPresent
```

**After (v0.5.5):**

```yaml
migrations:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-migrations
    # -- Pinned explicitly: api, worker and migrations are all published at 1.3.0.
    # Migrations are independently versioned; a release that does not touch the SQL
    # skips this image, so re-check the pin on every appVersion bump. 1.3.0 adds
    # 000045-000055, and the 1.3.0 binary needs them (000054 above all: without it
    # no Pix is created or settled), so this Job must run them before the app rolls.
    tag: "1.3.0"
    pullPolicy: IfNotPresent
```

**Operational impact:**

The migrations Job **must complete successfully** before the API or worker pods running version 1.3.0 can handle traffic. If the Job fails or is disabled, the application will encounter runtime errors when attempting to create or settle Pix transactions.

### 3. Chart Formatting Cleanup

The `Chart.yaml` file has been reformatted to remove extraneous blank lines. This is a cosmetic change with no functional impact on the chart's behavior or rendered resources.

**Additional values.yaml change:**

The API image tag has been explicitly pinned to `"1.3.0"` in the default values, replacing the previous empty string (which fell back to `appVersion`).

**Before (v0.5.4):**

```yaml
api:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd
    # -- Image tag. Empty falls back to .Chart.AppVersion. Pin this
    # explicitly in production rather than riding the chart's release train.
    tag: ""
    pullPolicy: IfNotPresent
```

**After (v0.5.5):**

```yaml
api:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd
    # -- Image tag. Empty falls back to .Chart.AppVersion. Pin this
    # explicitly in production rather than riding the chart's release train.
    tag: "1.3.0"
    pullPolicy: IfNotPresent
```

> **Note:** This change makes the default image tag explicit in the values file. If you have previously overridden `api.image.tag` in your own values, your override will continue to take precedence.

## Migration Impact

**Action required:** Operators must ensure the migrations Job completes before the API/worker pods roll out with version 1.3.0.

**Critical migration dependency:**

The 1.3.0 application binary depends on schema changes introduced in migrations 000045-000055. Without these migrations applied, the application will fail at runtime when attempting to:

- Create new Pix transactions
- Settle existing Pix transactions
- Process JDPI webhooks that trigger transaction state changes

**Rollout order:**

1. **Migrations Job runs first** (if using bundled PostgreSQL, this happens in `post-install`/`post-upgrade` hooks; if using external PostgreSQL, this happens in `pre-install`/`pre-upgrade` hooks)
2. **API and worker Deployments roll out** after the Job succeeds

> **Warning:** If you have disabled the migrations Job (`migrations.enabled=false`), you **must** apply the schema changes manually before upgrading. The application will not function correctly on version 1.3.0 without the new schema.

## Configuration Changes

### Image Tag Updates

The default image tags for both the API and migrations components have been updated to `1.3.0`.

| Component | Value Path | v0.5.4 | v0.5.5 |
|-----------|-----------|--------|--------|
| API | `api.image.tag` | `""` (falls back to 1.2.4) | `"1.3.0"` |
| Migrations | `migrations.image.tag` | `"1.2.4"` | `"1.3.0"` |

**If you have pinned image tags explicitly in your values:**

```yaml
api:
  image:
    tag: "1.2.4"  # Your existing override

migrations:
  image:
    tag: "1.2.4"  # Your existing override
```

**Update both to 1.3.0:**

```yaml
api:
  image:
    tag: "1.3.0"

migrations:
  image:
    tag: "1.3.0"
```

### Migration Image Configuration

The migrations image comment has been expanded to document the new schema files and their criticality.

**New comment text:**

```yaml
migrations:
  image:
    # -- Pinned explicitly: api, worker and migrations are all published at 1.3.0.
    # Migrations are independently versioned; a release that does not touch the SQL
    # skips this image, so re-check the pin on every appVersion bump. 1.3.0 adds
    # 000045-000055, and the 1.3.0 binary needs them (000054 above all: without it
    # no Pix is created or settled), so this Job must run them before the app rolls.
    tag: "1.3.0"
```

This comment serves as inline documentation for operators reviewing the values file.

## Migration Steps

### Step 1: Review Image Tag Pins

If you have explicitly pinned `api.image.tag` or `migrations.image.tag` in your values file, update them to `1.3.0`.

**Check your current values:**

```bash
helm get values plugin-br-pix-jd -n plugin-br-pix-jd
```

**If you see:**

```yaml
api:
  image:
    tag: "1.2.4"
```

**Update to:**

```yaml
api:
  image:
    tag: "1.3.0"
```

### Step 2: Verify Migration Job Configuration

Confirm that the migrations Job is enabled and will run during the upgrade.

**Check your values:**

```yaml
migrations:
  enabled: true  # Must be true
  image:
    tag: "1.3.0"
```

> **Warning:** If `migrations.enabled=false`, the schema will not be updated automatically. You must apply migrations 000045-000055 manually using golang-migrate or another migration tool before upgrading the application.

### Step 3: Plan Rollout Order

**For bundled PostgreSQL:**

The migrations Job runs in a `post-install`/`post-upgrade` hook, meaning the API and worker Deployments will begin rolling out **before** the schema is updated. This creates a brief window where the new pods may fail health checks until the migrations complete.

**Expected behavior:**

1. Helm begins the upgrade
2. API/worker Deployments start rolling out new pods (1.3.0)
3. New pods fail readiness probes (schema not yet updated)
4. Migrations Job runs and completes
5. New pods pass readiness probes and begin serving traffic

**For external PostgreSQL:**

The migrations Job runs in a `pre-install`/`pre-upgrade` hook, meaning the schema is updated **before** the API and worker roll out. This is the safer topology for zero-downtime upgrades.

**Monitor the migration Job:**

```bash
kubectl -n plugin-br-pix-jd logs job/plugin-br-pix-jd-migrations -f
```

**Verify the Job succeeded:**

```bash
kubectl -n plugin-br-pix-jd get job plugin-br-pix-jd-migrations
```

Expected output:

```
NAME                            COMPLETIONS   DURATION   AGE
plugin-br-pix-jd-migrations     1/1           45s        2m
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.5 -n plugin-br-pix-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.5 -n plugin-br-pix-jd
```
