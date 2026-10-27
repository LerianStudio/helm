<!-- {% raw %} -->
# Helm Upgrade from v9.7.3 to v9.8.0

## Topics

- **[Features](#features)**
  - [1. Balance Sync Fork Handling Configuration](#1-balance-sync-fork-handling-configuration)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

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
