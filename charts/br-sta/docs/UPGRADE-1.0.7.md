# Helm Upgrade from v1.0.6 to v1.0.7

This patch release upgrades the application from v1.2.0 to v1.3.0 and removes several deprecated configuration options. The new application version introduces a global license model (no longer requires `ORGANIZATION_IDS`), removes four legacy RabbitMQ publisher tuning parameters (not RabbitMQ publishing itself), and changes the credential sweep interval in the scheduler.

## Topics

- **[Application Version Update](#application-version-update)**
- **[License Configuration Changes](#license-configuration-changes)**
  - [What Changed](#what-changed)
  - [Migration Steps](#migration-steps)
- **[RabbitMQ Publisher Configuration Removal](#rabbitmq-publisher-configuration-removal)**
  - [What Changed](#what-changed-1)
  - [Migration Steps](#migration-steps-1)
- **[Scheduler Credential Interval Change](#scheduler-credential-interval-change)**
  - [What Changed](#what-changed-2)
  - [Migration Steps](#migration-steps-2)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Application Version Update

The default application version has been updated:

| Setting | v1.0.6 | v1.0.7 |
|---------|--------|--------|
| `appVersion` | 1.2.0 | 1.3.0 |

This affects the default image tags for the manager, worker, and migrations Job. If you have pinned specific image tags via `manager.image.tag`, `worker.image.tag`, or `migrations.image.tag`, those overrides will continue to take precedence.

> **Important:** If you are pinning images to version 1.2.0 or earlier, you must continue to provide the deprecated configuration options described in the sections below. The chart still renders them when explicitly set to maintain backward compatibility.

## License Configuration Changes

### What Changed

Application version 1.3.0 introduces a global license model. The `ORGANIZATION_IDS` environment variable is no longer required or used by the application.

| Setting | v1.0.6 | v1.0.7 |
|---------|--------|--------|
| `common.license.organizationIds` | Required in every environment | Optional (ignored by app 1.3.0; only needed if pinning image below 1.3.0) |
| `common.secrets.ORGANIZATION_IDS` | Accepted for secret-store sourcing | Optional (ignored by app 1.3.0; only needed if pinning image below 1.3.0) |

**Before (v1.0.6):**

The chart validated that `ORGANIZATION_IDS` was set and would fail deployment if missing:

```yaml
# values.yaml
common:
  license:
    organizationIds: "org-123,org-456"
  secrets:
    LICENSE_KEY: "your-license-key"
```

**After (v1.0.7):**

The `ORGANIZATION_IDS` validation has been removed. Only `LICENSE_KEY` is required:

```yaml
# values.yaml
common:
  secrets:
    LICENSE_KEY: "your-license-key"
```

The chart still renders `ORGANIZATION_IDS` to the ConfigMap if you explicitly set `common.license.organizationIds`, but the application will ignore it.

### Migration Steps

1. **If you are upgrading to application version 1.3.0 (the default):**

   You can safely remove `common.license.organizationIds` from your values file:

   ```yaml
   # values.yaml - remove this block
   common:
     license:
       organizationIds: "org-123,org-456"
   ```

   Keep only `LICENSE_KEY`:

   ```yaml
   # values.yaml
   common:
     secrets:
       LICENSE_KEY: "your-license-key"
   ```

2. **If you have pinned manager or worker images to version 1.2.0 or earlier:**

   You must continue to provide `ORGANIZATION_IDS` until you upgrade those images:

   ```yaml
   # values.yaml
   manager:
     image:
       tag: "1.2.0"
   worker:
     image:
       tag: "1.2.0"
   
   common:
     license:
       organizationIds: "org-123,org-456"
     secrets:
       LICENSE_KEY: "your-license-key"
   ```

> **Note:** The chart no longer fails deployment if `ORGANIZATION_IDS` is missing. If you are running an image below 1.3.0 without this value, the application itself will refuse to boot.

## RabbitMQ Publisher Configuration Removal

### What Changed

Application version 1.3.0 removes the following four legacy publisher tuning parameters. RabbitMQ audit and business-event publishers remain active; this is not removal of the messaging transport:

| Setting | v1.0.6 | v1.0.7 |
|---------|--------|--------|
| `common.rabbitmq.publisherConfirmTimeoutMs` | Default: `5000` | Optional (ignored by app 1.3.0) |
| `common.rabbitmq.publisherRecoveryInitialMs` | Default: `1000` | Optional (ignored by app 1.3.0) |
| `common.rabbitmq.publisherRecoveryMaxMs` | Default: `30000` | Optional (ignored by app 1.3.0) |
| `common.rabbitmq.publisherMaxRecoveries` | Default: `10` | Optional (ignored by app 1.3.0) |

**Before (v1.0.6):**

These environment variables were always rendered to the ConfigMap with default values:

```yaml
RABBITMQ_PUBLISHER_CONFIRM_TIMEOUT_MS: "5000"
RABBITMQ_PUBLISHER_RECOVERY_INITIAL_MS: "1000"
RABBITMQ_PUBLISHER_RECOVERY_MAX_MS: "30000"
RABBITMQ_PUBLISHER_MAX_RECOVERIES: "10"
```

**After (v1.0.7):**

These environment variables are only rendered if you explicitly set them in `common.rabbitmq`:

```yaml
# Only rendered if common.rabbitmq.publisherConfirmTimeoutMs is set
RABBITMQ_PUBLISHER_CONFIRM_TIMEOUT_MS: "5000"
```

### Migration Steps

1. **If you are upgrading to application version 1.3.0 (the default):**

   Remove any explicit publisher tuning from your values file:

   ```yaml
   # values.yaml - remove these fields
   common:
     rabbitmq:
       publisherConfirmTimeoutMs: 5000
       publisherRecoveryInitialMs: 1000
       publisherRecoveryMaxMs: 30000
       publisherMaxRecoveries: 10
   ```

   The application will ignore these values even if they are present.

2. **If you have pinned manager or worker images to version 1.2.0 or earlier:**

   You can continue to set these values if you have customized them:

   ```yaml
   # values.yaml
   manager:
     image:
       tag: "1.2.0"
   worker:
     image:
       tag: "1.2.0"
   
   common:
     rabbitmq:
       publisherConfirmTimeoutMs: 10000
       publisherRecoveryMaxMs: 60000
   ```

   If you were using the defaults, you do not need to set anything — the chart will not render them, and the application will use its built-in defaults (5000 / 1000 / 30000 / 10).

> **Note:** RabbitMQ is still used for audit transport and business-event channels. Only the publisher tuning parameters have been removed.

## Scheduler Credential Interval Change

### What Changed

Application version 1.3.0 changes the credential sweep behavior in the worker scheduler. The `credentialIntervalHours` configuration option is no longer used; the application now sweeps credentials every 5 minutes.

| Setting | v1.0.6 | v1.0.7 |
|---------|--------|--------|
| `worker.scheduler.credentialIntervalHours` | Optional (app-defined default) | Optional (ignored by app 1.3.0; only read by image below 1.3.0) |

**Before (v1.0.6):**

```yaml
SCHEDULER_CREDENTIAL_INTERVAL_HOURS: "24"
```

**After (v1.0.7):**

The environment variable is only rendered if you explicitly set `worker.scheduler.credentialIntervalHours`. Application version 1.3.0 ignores it and uses a fixed 5-minute interval.

### Migration Steps

1. **If you are upgrading to application version 1.3.0 (the default):**

   Remove `worker.scheduler.credentialIntervalHours` from your values file:

   ```yaml
   # values.yaml - remove this field
   worker:
     scheduler:
       credentialIntervalHours: 24
   ```

   The application will sweep credentials every 5 minutes regardless of this setting.

2. **If you have pinned the worker image to version 1.2.0 or earlier:**

   You can continue to set this value if you have customized it:

   ```yaml
   # values.yaml
   worker:
     image:
       tag: "1.2.0"
     scheduler:
       credentialIntervalHours: 12
   ```

> **Important:** The abandoned-rotation monitor now runs every 5 minutes; the credential validity monitor already used a 5-minute interval in 1.2.0. Do not pin only an older worker as a workaround: compatibility with the manager, migrations image and resulting database schema must be demonstrated for the complete selected version set.

## Database migrations and preparation

The default migrations image also changes from 1.2.0 to 1.3.0. Application 1.3.0 adds migration 000023 (credential `pending_encryption_key_id` and backfill) and 000024 (rebuild of the `reporter_filings` index). Plan the migration window and inspect the migration result before accepting traffic. For single-tenant external PostgreSQL, the enabled migration Job is a pre-upgrade hook. In multi-tenant mode that Job is not rendered: arrange and verify migrations for every tenant using the application's supported procedure before cutover. Do not assume a Helm rollout alone migrates every tenant.

Before upgrading:

1. Record the current Helm revision and save release configuration privately. These outputs can contain secrets; never commit, publish or paste them.

   ```bash
   umask 077
   mkdir -p private-upgrade-backup
   helm history br-sta -n br-sta > private-upgrade-backup/history.txt
   helm get values br-sta -n br-sta -o yaml > private-upgrade-backup/values.yaml
   helm get manifest br-sta -n br-sta > private-upgrade-backup/manifest.yaml
   ```

2. Take a consistent PostgreSQL backup and verify the restore procedure. Preserve `MASTER_KEYS`, credential material and existing Secret references privately; changing keys or losing them is not a migration strategy.
3. Prepare `values-1.0.7.yaml` as the **complete intended configuration**, preserving unrelated endpoints, Secret/license references, storage, ingress, resources and overrides. Remove only the retired keys identified above. The partial examples are not complete upgrade values files.
4. Validate the complete manager/worker/migrations version set, schema and scheduler behavior in staging. No live upgrade, SQL execution or restore is established by chart render checks.

Both commands below use `--reset-values` to discard retired stored overrides and apply the same complete file. A partial file would discard unrelated settings; inspect the full diff before proceeding.

## Preview changes before upgrading

```bash
helm diff upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm -n br-sta --version 1.0.7 --reset-values -f values-1.0.7.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm -n br-sta --version 1.0.7 --reset-values -f values-1.0.7.yaml --wait --timeout 10m
```

## Verify and recover

Check the migration Job result (or the per-tenant migration results), manager/worker rollout readiness and representative STA operations using your approved smoke tests. Discover exact workload names from the rendered manifest rather than assuming a fixed selector. Inspect logs privately and redact them before sharing.

To roll back Kubernetes release configuration, replace `PREVIOUS_REVISION` with the recorded Helm revision:

```bash
helm rollback br-sta PREVIOUS_REVISION -n br-sta --wait --timeout 10m
```

A Helm rollback does not reverse SQL migrations, restore PostgreSQL or undo credential/password state already negotiated with BACEN. Verify compatibility before rolling back the application version. If database recovery is required, stop the rollout and use the reviewed backup/restore and cutover procedure; do not blindly run down migrations or discard key material.
