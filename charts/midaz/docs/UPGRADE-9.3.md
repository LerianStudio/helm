# Helm Upgrade from v9.2.15 to v9.3.0

## Topics

- **[Features](#features)**
  - [1. Application version upgrade to 4.1.0](#1-application-version-upgrade-to-410)
  - [2. Transaction batch size configuration](#2-transaction-batch-size-configuration)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Application version upgrade to 4.1.0

The midaz application version has been upgraded from 4.0.7 to 4.1.0, affecting both the ledger and tracer components.

| Component | v9.2.15 | v9.3.0 |
|-----------|---------|--------|
| `appVersion` | `4.0.7` | `4.1.0` |
| `ledger.image.tag` | `4.0.7` | `4.1.0` |
| `tracer.image.tag` | `4.0.5` | `4.1.0` |

**Why this matters:**

This is a minor version upgrade that includes new features and improvements in the midaz application. The tracer component receives a more significant update from 4.0.5 to 4.1.0, bringing it in sync with the ledger version.

**After (v9.3.0):**

```yaml
ledger:
  image:
    repository: lerianstudio/midaz-ledger
    pullPolicy: IfNotPresent
    tag: "4.1.0"

tracer:
  image:
    repository: lerianstudio/midaz-tracer
    pullPolicy: Always
    tag: "4.1.0"
```

> **Note:** This upgrade will trigger pod restarts for both the ledger and tracer deployments due to the image tag changes. The ledger and tracer services will be briefly unavailable during the rolling update.

#### Action required

No action is required unless you have pinned specific image tags in your values overrides. If you have explicitly set `ledger.image.tag` or `tracer.image.tag` to older versions, remove those overrides or update them to `4.1.0` to receive the latest features and fixes:

```yaml
ledger:
  image:
    tag: "4.1.0"

tracer:
  image:
    tag: "4.1.0"
```

### 2. Transaction batch size configuration

A new environment variable `TRANSACTION_BATCH_MAX_SIZE` has been added to the ledger ConfigMap, allowing operators to configure the maximum number of transactions processed in a single batch.

| Setting | v9.2.15 | v9.3.0 |
|---------|---------|--------|
| `ledger.configmap.TRANSACTION_BATCH_MAX_SIZE` | (not available) | `10` (default) |

**Why this matters:**

This configuration option provides control over transaction batch processing performance. Adjusting the batch size can help optimize throughput and resource utilization based on your workload characteristics:

- **Smaller batches** (e.g., 5-10): Lower latency per batch, more frequent database commits, better for real-time processing
- **Larger batches** (e.g., 50-100): Higher throughput, fewer database round-trips, better for bulk processing scenarios

**After (v9.3.0):**

```yaml
ledger:
  configmap:
    TRANSACTION_BATCH_MAX_SIZE: "10"
```

The ConfigMap template now includes:

```yaml
data:
  TRANSACTION_BATCH_MAX_SIZE: {{ .Values.ledger.configmap.TRANSACTION_BATCH_MAX_SIZE | default "10" | quote }}
```

> **Important:** Because the ledger Deployment includes a `checksum/config` annotation (added in v9.2.13), adding this new environment variable will trigger a ledger pod restart on upgrade, even if you accept the default value.

#### Action required

No action is required to accept the default batch size of 10 transactions. If you need to tune batch processing for your workload, set the value in your values override:

```yaml
ledger:
  configmap:
    TRANSACTION_BATCH_MAX_SIZE: "50"  # adjust based on your performance requirements
```

> **Note:** Changes to this value after the initial upgrade will automatically trigger ledger pod restarts due to the ConfigMap checksum annotation.

## Configuration Reference

### New ledger configuration fields

| Field | Default | Description |
|-------|---------|-------------|
| `ledger.configmap.TRANSACTION_BATCH_MAX_SIZE` | `"10"` | Maximum number of transactions to process in a single batch. Controls the trade-off between latency and throughput in transaction processing. |

### Updated image tags

| Field | Previous Default | New Default | Description |
|-------|------------------|-------------|-------------|
| `ledger.image.tag` | `"4.0.7"` | `"4.1.0"` | Ledger service image tag |
| `tracer.image.tag` | `"4.0.5"` | `"4.1.0"` | Tracer service image tag |

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.3.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.3.0 -n midaz
```
