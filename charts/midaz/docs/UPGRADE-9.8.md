<!-- {% raw %} -->
# Helm Upgrade from v9.7.3 to v9.8.0

## Topics

- **[Before you upgrade: Midaz v4.2.x to v4.3](#before-you-upgrade-midaz-v42x-to-v43)**
- **[Features](#features)**
  - [1. Balance Sync Fork Handling Configuration](#1-balance-sync-fork-handling-configuration)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Before you upgrade: Midaz v4.2.x to v4.3

This chart version moves the ledger from Midaz v4.2.x to v4.3.0. That step needs a drained
cutover, never a rolling update, and it limits how far a later rollback can go.

- **Why no rolling update.** v4.2.x cannot finish work that v4.3 records and refuses it, and
  both versions take the same recovery lock. A fleet that mixes the two hands v4.3 records to
  v4.2 pods.
- **Drained cutover.**
  1. Upgrade the Tracer first, then run the ledger migrations.
  2. Multi-tenant only: raise `MULTI_TENANT_CACHE_TTL_SEC` on the v4.2 pods above the length of
     the window. Without traffic, the pods forget every tenant about two minutes after the cut
     and stop draining.
  3. Cut traffic to the ledger outside the pods (ingress or Service). Keep the v4.2 pods running.
  4. Wait until the v4.2 pods finish their own work: the write-behind queue
     (`RABBITMQ_TRANSACTION_BALANCE_OPERATION_QUEUE`) shows 0 ready and 0 unacked, the Valkey
     hashes `engine:{transactions}:recover` and `backup_queue:{transactions}` are empty, and the
     sorted sets `schedule:{transactions}:balance-sync-v2` and
     `schedule:{transactions}:balance-sync` are empty. Multi-tenant: check every tenant vhost and
     the `tenant:<tenantId>:` copy of each key.
  5. Then roll the ledger to v4.3.0 and restore traffic.

  The ledger refuses writes from the cut until v4.3.0 serves.
- **Rollback floor.** Roll a v4.3 ledger back only to v4.3.0-beta.39 or later (v4.3.0-rc.6, or
  beta.79 and later, is recommended). v4.3.0-rc.1, rc.2, beta.1 to beta.38 and every v4.2.x are
  not supported, even fully drained: an earlier build can apply the money of a v4.3 record in
  Valkey and then fail to write the transaction's record and metadata.

## Features

### 1. Balance Sync Fork Handling Configuration

Three new environment variables have been introduced to the ledger service to control the behavior of balance fork detection and retry logic. These settings allow operators to fine-tune how the system handles balance synchronization conflicts caused by Postgres version regressions or value mismatches.

A balance fork occurs when the ledger service detects inconsistencies in balance data during synchronization — typically due to concurrent updates, version conflicts, or data integrity issues. The new configuration allows the system to automatically retry forked balances with exponential backoff before moving them to a quarantine table for manual review.

#### New Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BALANCE_SYNC_FORK_MAX_ATTEMPTS` | `6` | Number of retry attempts before a forked balance is moved to the quarantine table |
| `BALANCE_SYNC_FORK_BACKOFF_BASE_MS` | `1000` | Initial backoff delay in milliseconds before retrying a forked balance |
| `BALANCE_SYNC_FORK_BACKOFF_MAX_MS` | `600000` | Maximum backoff delay in milliseconds (ceiling for exponential backoff) |

#### Configuration Example

The new variables are added to the ledger ConfigMap and can be overridden in your `values.yaml`:

```yaml
ledger:
  configmap:
    # Balance fork handling configuration
    BALANCE_SYNC_FORK_MAX_ATTEMPTS: "6"
    BALANCE_SYNC_FORK_BACKOFF_BASE_MS: "1000"
    BALANCE_SYNC_FORK_BACKOFF_MAX_MS: "600000"
```

#### Operational Impact

**Default Behavior:**
- Forked balances will be retried up to 6 times
- First retry occurs after 1 second
- Backoff increases exponentially with each retry (1s → 2s → 4s → 8s → ...)
- Maximum backoff is capped at 10 minutes (600,000ms)
- After 6 failed attempts, the balance is moved to quarantine for manual investigation

**When to Adjust:**

Increase `BALANCE_SYNC_FORK_MAX_ATTEMPTS` if:
- Your environment experiences frequent transient conflicts that resolve themselves
- You want to reduce manual intervention for temporary issues

Adjust `BALANCE_SYNC_FORK_BACKOFF_BASE_MS` and `BALANCE_SYNC_FORK_BACKOFF_MAX_MS` if:
- You need faster retry cycles in low-latency environments (decrease base)
- You want to reduce system load during conflicts (increase base or max)
- Your database recovery time requires longer wait periods (increase max)

> **Note:** These settings only affect the balance synchronization subsystem. They do not impact normal transaction processing or balance queries.

> **Important:** If you observe balances being quarantined frequently, investigate the root cause (database performance, concurrent load, schema issues) rather than simply increasing retry attempts.

## Configuration Reference

The following table shows the new configuration options added in v9.8.0:

| Setting | v9.7.3 | v9.8.0 |
|---------|--------|--------|
| `BALANCE_SYNC_FORK_MAX_ATTEMPTS` | Not present | `6` (default) |
| `BALANCE_SYNC_FORK_BACKOFF_BASE_MS` | Not present | `1000` (default) |
| `BALANCE_SYNC_FORK_BACKOFF_MAX_MS` | Not present | `600000` (default) |

**Template Changes:**

**Before (v9.7.3):**
```yaml
  # How often the cache TTL of every synced balance is refreshed (ms).
  BALANCE_SYNC_TTL_KEEPALIVE_INTERVAL_MS: {{ $cm.BALANCE_SYNC_TTL_KEEPALIVE_INTERVAL_MS | default "300000" | quote }}

  # =============================================================================
  # RATE LIMITING
```

**After (v9.8.0):**
```yaml
  # How often the cache TTL of every synced balance is refreshed (ms).
  BALANCE_SYNC_TTL_KEEPALIVE_INTERVAL_MS: {{ $cm.BALANCE_SYNC_TTL_KEEPALIVE_INTERVAL_MS | default "300000" | quote }}
  # Attempts before a balance fork (Postgres version regression or value
  # mismatch at the same version) is moved to the quarantine table.
  BALANCE_SYNC_FORK_MAX_ATTEMPTS: {{ $cm.BALANCE_SYNC_FORK_MAX_ATTEMPTS | default "6" | quote }}
  # Base backoff before retrying a forked balance (ms).
  BALANCE_SYNC_FORK_BACKOFF_BASE_MS: {{ $cm.BALANCE_SYNC_FORK_BACKOFF_BASE_MS | default "1000" | quote }}
  # Backoff ceiling for a forked balance (ms).
  BALANCE_SYNC_FORK_BACKOFF_MAX_MS: {{ $cm.BALANCE_SYNC_FORK_BACKOFF_MAX_MS | default "600000" | quote }}

  # =============================================================================
  # RATE LIMITING
```

All new variables include sensible defaults and do not require explicit configuration unless you need to tune the fork handling behavior for your specific environment.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.8.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.8.0 -n midaz
```
<!-- {% endraw %} -->
