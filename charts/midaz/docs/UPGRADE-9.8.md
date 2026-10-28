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
  v4.2 pods. With the default `migrations` settings, one upgrade to this chart runs the
  migration Jobs first (Helm `pre-upgrade` hooks; Argo CD `Sync` hooks, with the Deployments one
  wave later through `deploymentSyncWave`) and then rolls the ledger with a surge, so the steps
  below stop every v4.2 pod before the upgrade runs.
- **Before the window.**
  - Pause autoscaling for the ledger, and GitOps auto-sync and self-heal for this release.
    Autoscaling scales in pods that are draining; self-heal reverts the manual steps below.
  - If the Tracer runs in another release, upgrade it to v4.3 first. When this release runs it
    (`tracer.enabled: true`), the same upgrade migrates and rolls it, and traffic stays cut
    until both rollouts finish.
  - Multi-tenant only: raise `MULTI_TENANT_CACHE_TTL_SEC` (`ledger.extraEnvVars`) above the
    length of the window, rolled on the same v4.2 image while traffic still reaches every
    tenant. Without traffic, the pods forget every tenant about two minutes after the cut and
    stop draining.
- **Drained cutover.**
  1. Cut traffic to the ledger outside the pods: remove the ingress route, or point the Service
     at no pod with
     `kubectl -n <ns> patch svc <ledger-service> -p '{"spec":{"selector":{"cutover":"closed"}}}'`.
     Keep the v4.2 pods running.
  2. Wait until the v4.2 pods finish their own work: the write-behind queue
     (`RABBITMQ_TRANSACTION_BALANCE_OPERATION_QUEUE`) shows 0 ready and 0 unacked, the Valkey
     hashes `engine:{transactions}:recover` and `backup_queue:{transactions}` are empty, and the
     sorted sets `schedule:{transactions}:balance-sync-v2` and
     `schedule:{transactions}:balance-sync` are empty. Multi-tenant: check every tenant vhost and
     the `tenant:<tenantId>:` copy of each key.
  3. Stop every v4.2 pod and wait until all are gone:

     ```bash
     kubectl -n <ns> scale deploy/<ledger-deployment> --replicas=0
     kubectl -n <ns> wait --for=delete pod -l <ledger-pod-labels> --timeout=5m
     ```

     Check step 2 once more. If anything is back above 0, scale the v4.2 pods up on the same
     image and repeat from step 2.
  4. Upgrade to this chart version (`helm upgrade`, or an Argo CD sync). The hooks migrate the
     databases and the v4.3.0 pods start with no v4.2 pod beside them, so the window includes
     the migrations. With `migrations.enabled: false`, run the migrations yourself before this
     step. With `ledger.autoscaling.enabled`, the chart sets no replica count and the
     HPA does not scale a Deployment at 0: scale the ledger back up by hand.
  5. Wait for `kubectl -n <ns> rollout status deploy/<ledger-deployment>`, and for the Tracer's
     rollout when this release runs it. Every ledger pod answers `/readyz` with 200 and reports
     v4.3.0 on `/version`.
  6. Restore traffic (remove the `cutover` selector or restore the ingress route), then
     re-enable autoscaling and GitOps sync.

  The ledger refuses writes from the cut until v4.3.0 serves.
- **Rollback floor.** A v4.3 ledger rolls back only to these builds:
  - v4.3.0-rc.6, or v4.3.0-beta.79 and later (recommended);
  - v4.3.0-beta.39 to beta.78, or v4.3.0-rc.3 to rc.5.

  v4.3.0-rc.1, rc.2, beta.1 to beta.38 and every v4.2.x are not supported, even fully drained:
  an earlier build can apply the money of a v4.3 record in Valkey and then fail to write the
  transaction's record and metadata. So never `helm rollback` to the revision before this
  upgrade, which restores v4.2.x. Roll back with steps 1 to 6 and the target's image, and set
  `ledger.migrations.enabled: false`: the target's migration image refuses a database already
  at v4.3.

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
