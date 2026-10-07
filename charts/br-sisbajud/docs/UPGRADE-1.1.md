# Helm Upgrade from v1.0.1 to v1.1.0

## Table of Contents

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Kafka Topic Provisioning Job](#1-kafka-topic-provisioning-job)
- **[Configuration Reference](#configuration-reference)**
  - [Topics Configuration](#topics-configuration)
  - [New Template Helpers](#new-template-helpers)
- **[Migration Steps](#migration-steps)**
  - [Option 1: Enable Topic Provisioning (Recommended)](#option-1-enable-topic-provisioning-recommended)
  - [Option 2: Disable Topic Provisioning](#option-2-disable-topic-provisioning)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 1.1.0 introduces an optional **Kafka topic provisioning Job** that runs as an ArgoCD PreSync hook to idempotently create the required Redpanda topics before the application starts. This prevents `UNKNOWN_TOPIC_OR_PARTITION` errors on fresh broker deployments and ensures DLQ topics exist before the application attempts to publish to them.

| Setting | v1.0.1 | v1.1.0 |
|---------|--------|--------|
| Topic provisioning | Manual (operator responsibility) | Automated via PreSync Job (enabled by default) |
| Topics image | N/A | `ghcr.io/lerianstudio/br-sisbajud-topics` |

## Features

### 1. Kafka Topic Provisioning Job

A new PreSync Job (`br-sisbajud-topics`) has been added that runs before the main application Deployment. This Job uses `rpk topic create` to idempotently ensure all required reactive-bridge topics exist.

**What changed:**

- New `topics` configuration block in `values.yaml` with 38 lines of settings
- New Job template at `templates/topics/job.yaml` (116 lines)
- New template helpers in `_helpers.tpl` for topics naming and labels

**Why it matters:**

- **Eliminates manual topic creation:** Operators no longer need to pre-provision topics before deploying the application
- **Prevents startup failures:** The application won't crash with `UNKNOWN_TOPIC_OR_PARTITION` errors on fresh Kafka/Redpanda clusters
- **DLQ safety:** Dead-letter queue topics are created alongside primary topics, ensuring error handling works from the first message
- **GitOps-friendly:** The Job reuses the same `STREAMING_*` environment variables from `brSisbajud.extraEnvVars` and `brSisbajud.configmap`, avoiding duplicated secret references

**Topics created:**

The Job provisions the following topics (all with corresponding `.dlq` siblings):

1. `br-sisbajud.ledger.balance.changed` + `.dlq`
2. `br-sisbajud.block_account.created` + `.dlq`
3. `br-sisbajud.kek.rotated` + `.dlq`

> **Note:** The `midaz.balance.changed` topic is **not** provisioned by this Job. Midaz owns and creates that topic; br-sisbajud only consumes it.

**Job behavior:**

- **Hook type:** ArgoCD PreSync with weight `-1` (runs in the same wave as migrations, before the Deployment)
- **Idempotency:** Uses `rpk topic list` then `rpk topic create` — safe to run multiple times
- **Lifecycle:** Deleted before each sync and after success (`BeforeHookCreation,HookSucceeded`)
- **Timeout:** 600 seconds active deadline, 3 retry attempts
- **Security:** Runs as non-root user 65532 with read-only root filesystem and dropped capabilities

## Configuration Reference

### Topics Configuration

The new `topics` block controls the PreSync topic provisioning Job:

```yaml
topics:
  enabled: true
  image:
    repository: ghcr.io/lerianstudio/br-sisbajud-topics
    tag: ""  # Defaults to Chart.AppVersion
    pullPolicy: IfNotPresent
  imagePullSecrets: []  # Falls back to global imagePullSecrets
  partitions: 1
  replicationFactor: 1
  retentionMs: ""  # Empty = broker default
  list:
    - br-sisbajud.ledger.balance.changed
    - br-sisbajud.ledger.balance.changed.dlq
    - br-sisbajud.block_account.created
    - br-sisbajud.block_account.created.dlq
    - br-sisbajud.kek.rotated
    - br-sisbajud.kek.rotated.dlq
  backoffLimit: 3
  activeDeadlineSeconds: 600
  ttlSecondsAfterFinished: 600
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      memory: 256Mi
```

| Flag | Default | Description |
|------|---------|-------------|
| `topics.enabled` | `true` | Enable/disable the PreSync topic provisioning Job |
| `topics.image.repository` | `ghcr.io/lerianstudio/br-sisbajud-topics` | Container image for the rpk-based provisioning tool |
| `topics.image.tag` | `""` (Chart.AppVersion) | Image tag; empty string uses the chart's appVersion |
| `topics.image.pullPolicy` | `IfNotPresent` | Image pull policy |
| `topics.imagePullSecrets` | `[]` | Image pull secrets; falls back to global `imagePullSecrets` if empty |
| `topics.partitions` | `1` | Number of partitions per topic |
| `topics.replicationFactor` | `1` | Replication factor; set to `3` for multi-broker production clusters |
| `topics.retentionMs` | `""` | Retention period in milliseconds; empty uses broker default |
| `topics.list` | (6 topics) | List of topic names to create |
| `topics.backoffLimit` | `3` | Number of Job retry attempts |
| `topics.activeDeadlineSeconds` | `600` | Maximum Job execution time (10 minutes) |
| `topics.ttlSecondsAfterFinished` | `600` | Time to keep completed Job pods (10 minutes) |
| `topics.resources` | (see above) | Resource requests and limits for the Job container |

**Environment variables resolved by the Job:**

The Job automatically inherits Kafka connection settings from `brSisbajud.extraEnvVars` and `brSisbajud.configmap`:

| Variable | Source | Required | Description |
|----------|--------|----------|-------------|
| `STREAMING_BROKERS` | extraEnvVars → configmap → default `""` | Yes | Kafka/Redpanda broker addresses |
| `STREAMING_TLS_ENABLED` | extraEnvVars → configmap → default `"false"` | Yes | Enable TLS for broker connections |
| `STREAMING_SASL_MECHANISM` | extraEnvVars → configmap | No | SASL mechanism (e.g., `SCRAM-SHA-256`) |
| `STREAMING_SASL_USERNAME` | extraEnvVars → configmap | No | SASL username |
| `STREAMING_SASL_PASSWORD` | extraEnvVars → configmap | No | SASL password (typically from secret via `valueFrom`) |
| `STREAMING_TLS_CA_CERT` | extraEnvVars → configmap | No | PEM-encoded CA certificate for TLS |
| `TOPICS` | Derived from `topics.list` | Yes | Space-separated list of topic names |
| `TOPIC_PARTITIONS` | `topics.partitions` | Yes | Number of partitions |
| `TOPIC_REPLICAS` | `topics.replicationFactor` | Yes | Replication factor |
| `TOPIC_RETENTION_MS` | `topics.retentionMs` | No | Retention period; omitted if empty |
| `HOME` | Hardcoded `/tmp` | Yes | Writable directory for rpk config (required with readOnlyRootFilesystem) |

> **Important:** The Job preserves `valueFrom` references (secretKeyRef/configMapKeyRef) from `brSisbajud.extraEnvVars`, so secret-backed SASL/TLS credentials reach the Job exactly as they reach the Deployment. No duplicate secret references are needed.

### New Template Helpers

Two new template helpers were added to `_helpers.tpl`:

**Before (v1.0.1):**

```yaml
# Only br-sisbajud.fullname, br-sisbajud.chart, br-sisbajud.labels,
# br-sisbajud-migrations.fullname, and br-sisbajud-migrations.labels existed
```

**After (v1.1.0):**

```yaml
{{- define "br-sisbajud-topics.fullname" -}}
{{- printf "%s-topics" (include "br-sisbajud.fullname" . | trunc 56 | trimSuffix "-") | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "br-sisbajud-topics.labels" -}}
helm.sh/chart: {{ include "br-sisbajud.chart" . }}
app.kubernetes.io/name: {{ include "br-sisbajud-topics.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: topics
{{- end }}
```

**Operational impact:**

- The topics Job is named `<release-name>-topics` (e.g., `br-sisbajud-topics`)
- Labels include `app.kubernetes.io/component: topics` for filtering and monitoring
- Naming follows the same truncation logic as other chart components (63-character Kubernetes limit)

## Migration Steps

### Option 1: Enable Topic Provisioning (Recommended)

If you want the chart to automatically provision topics (recommended for new deployments and environments where topics don't yet exist):

1. **Ensure Kafka connection settings are configured.** The Job reuses `STREAMING_*` variables from your existing `brSisbajud.extraEnvVars` or `brSisbajud.configmap`. Verify these are set:

```yaml
brSisbajud:
  extraEnvVars:
    - name: STREAMING_BROKERS
      value: "redpanda.kafka.svc.cluster.local:9092"
    - name: STREAMING_TLS_ENABLED
      value: "false"
    # Add SASL/TLS settings if required:
    # - name: STREAMING_SASL_PASSWORD
    #   valueFrom:
    #     secretKeyRef:
    #       name: kafka-credentials
    #       key: password
```

2. **Adjust replication factor for production.** The default `replicationFactor: 1` is suitable for single-broker dev/test environments. For multi-broker production clusters, override it:

```yaml
topics:
  replicationFactor: 3
```

3. **(Optional) Customize topic retention.** If your environment requires non-default retention:

```yaml
topics:
  retentionMs: "604800000"  # 7 days in milliseconds
```

4. **Upgrade the chart.** The Job will run automatically as a PreSync hook:

```bash
helm upgrade br-sisbajud oci://registry-1.docker.io/lerianstudio/br-sisbajud-helm \
  --version 1.1.0 \
  -n br-sisbajud \
  -f values.yaml
```

5. **Verify topic creation.** After the upgrade, check that topics were created:

```bash
kubectl logs -n br-sisbajud -l app.kubernetes.io/component=topics --tail=50
```

Expected output includes lines like:

```
TOPIC                                      STATUS
br-sisbajud.ledger.balance.changed         OK
br-sisbajud.ledger.balance.changed.dlq     OK
br-sisbajud.block_account.created          OK
br-sisbajud.block_account.created.dlq      OK
br-sisbajud.kek.rotated                    OK
br-sisbajud.kek.rotated.dlq                OK
```

> **Note:** If topics already exist, the Job will report them as `OK` and skip creation. The Job is idempotent.

### Option 2: Disable Topic Provisioning

If you manage topics externally (e.g., via Terraform, manual `rpk` commands, or a separate provisioning system), disable the Job:

```yaml
topics:
  enabled: false
```

Then upgrade:

```bash
helm upgrade br-sisbajud oci://registry-1.docker.io/lerianstudio/br-sisbajud-helm \
  --version 1.1.0 \
  -n br-sisbajud \
  --set topics.enabled=false
```

> **Warning:** With `topics.enabled: false`, you are responsible for ensuring all topics in the `topics.list` (including `.dlq` siblings) exist before the application starts. Missing topics will cause runtime errors.

## Preview changes before upgrading

```bash
helm diff upgrade br-sisbajud oci://registry-1.docker.io/lerianstudio/br-sisbajud-helm --version 1.1.0 -n br-sisbajud
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-sisbajud oci://registry-1.docker.io/lerianstudio/br-sisbajud-helm --version 1.1.0 -n br-sisbajud
```
