# Helm Upgrade from v9.7.x to v9.8.0

## Topics

- **[New Configuration](#new-configuration)**
  - [1. Balance sync fork detection and quarantine](#1-balance-sync-fork-detection-and-quarantine)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## New Configuration

### 1. Balance sync fork detection and quarantine

The ledger's balance-sync worker now classifies rejected balance writes (Postgres
version regressions or value mismatches at the same version, known as a "fork")
instead of silently discarding them. Forked entries stay scheduled with an
exponential backoff and, after a configurable number of attempts, are recorded
in a new `balance_sync_quarantine` table.

Three optional environment variables control this behavior, exposed in the
ledger ConfigMap next to `BALANCE_SYNC_TTL_KEEPALIVE_INTERVAL_MS`:

| Variable | Default | Description |
|----------|---------|--------------|
| `BALANCE_SYNC_FORK_MAX_ATTEMPTS` | `"6"` | Attempts before a forked balance is quarantined |
| `BALANCE_SYNC_FORK_BACKOFF_BASE_MS` | `"1000"` | Base backoff before retrying a forked balance (ms) |
| `BALANCE_SYNC_FORK_BACKOFF_MAX_MS` | `"600000"` | Backoff ceiling for a forked balance (ms) |

#### Operational impact

- **No action required:** all three variables have safe, backward-compatible
  defaults and render automatically with no changes to `values.yaml`.
- **Customize only if needed:** set `ledger.configmap.BALANCE_SYNC_FORK_MAX_ATTEMPTS`,
  `ledger.configmap.BALANCE_SYNC_FORK_BACKOFF_BASE_MS`, and/or
  `ledger.configmap.BALANCE_SYNC_FORK_BACKOFF_MAX_MS` to tune the retry policy.
- **No migration or rendered-manifest changes** beyond the three new ConfigMap
  keys. Existing deployments are unaffected until the matching ledger
  application version is rolled out.

**Example override:**

```yaml
ledger:
  configmap:
    BALANCE_SYNC_FORK_MAX_ATTEMPTS: "3"
    BALANCE_SYNC_FORK_BACKOFF_BASE_MS: "2000"
    BALANCE_SYNC_FORK_BACKOFF_MAX_MS: "300000"
```

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.8.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.8.0 -n midaz
```
