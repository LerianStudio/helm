# Helm Upgrade from v1.2.0 to v1.3.0

This guide covers the upgrade of the `plugin-br-sisbajud` Helm chart from version **1.2.0** to **1.3.0**. This is a minor release that introduces the **direct channel** for judicial order execution, permanent block support with balance-change streaming, and new executor modes.

## Table of Contents

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Midaz CRM Mode Default Changed](#1-midaz-crm-mode-default-changed)
  - [2. Streaming Now Required for Default Configuration](#2-streaming-now-required-for-default-configuration)
  - [3. Library Name Changed](#3-library-name-changed)
- **[Features](#features)**
  - [1. Direct Channel for Order Execution](#1-direct-channel-for-order-execution)
  - [2. Permanent Block Support with Balance-Change Streaming](#2-permanent-block-support-with-balance-change-streaming)
  - [3. DIRECT-Only Executor Mode](#3-direct-only-executor-mode)
  - [4. Enhanced Executor Configuration](#4-enhanced-executor-configuration)
  - [5. Direct Channel Drainer Alarms](#5-direct-channel-drainer-alarms)
- **[Configuration Reference](#configuration-reference)**
  - [Executor Mode Configuration](#executor-mode-configuration)
  - [Direct Channel Configuration](#direct-channel-configuration)
  - [Streaming Configuration](#streaming-configuration)
  - [Enhanced Executor Settings](#enhanced-executor-settings)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review Midaz CRM Mode](#step-1-review-midaz-crm-mode)
  - [Step 2: Configure Streaming for Permanent Blocks](#step-2-configure-streaming-for-permanent-blocks)
  - [Step 3: Update Observability Library Name](#step-3-update-observability-library-name)
  - [Step 4: Review New Executor Settings](#step-4-review-new-executor-settings)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 1.3.0 (application version 1.2.0) introduces significant new capabilities for the SISBAJUD executor:

**Key changes:**

- **Direct channel** for judicial order execution via `POST /v1/institutions/{id}/executor/...`
- **Permanent block support** with balance-change streaming integration (RedPanda/Kafka)
- **DIRECT-only executor mode** that runs without Mensageria (no Hub webhook or SQS intake)
- **Midaz v4 compatibility** with embedded CRM mode as the new default
- **Enhanced executor configuration** with result drainer caps, order sweep, and alarm thresholds

**Application version:**

| Chart Version | App Version |
|---------------|-------------|
| 1.2.0 | 1.1.0 |
| 1.3.0 | 1.2.0 |

## Breaking Changes

### 1. Midaz CRM Mode Default Changed

**What changed:**

The default value of `MIDAZ_CRM_MODE` has changed from `legacy` to `embedded` to match Midaz v4.

| Setting | v1.2.0 | v1.3.0 |
|---------|--------|--------|
| `sisbajud.midaz.crmMode` | `"legacy"` | `"embedded"` |
| `MIDAZ_CRM_MODE` | `"legacy"` | `"embedded"` |

**Why it matters:**

- **Midaz v4** serves the CRM embedded in the ledger and no longer has the legacy `/v1/holders` surface
- **Midaz v3** requires `"legacy"` mode
- **Wrong mode symptom:** Every holder read fails

**Migration action required:**

If your institution's Midaz is **v3**, you **must** explicitly set the legacy mode:

```yaml
sisbajud:
  midaz:
    crmMode: "legacy"
```

If your institution's Midaz is **v4**, no action is required (the new default is correct).

> **Important:** The chart does not auto-detect the Midaz version. Operators must set the correct mode based on their Midaz deployment.

### 2. Streaming Now Required for Default Configuration

**What changed:**

The chart now enables `STREAMING_ENABLED=true` by default when `DIRECT_PERMANENT_BLOCK_ENABLED=true` (the chart default), and validates that `STREAMING_BROKERS` is set.

**Before (v1.2.0):**

```yaml
# Streaming was explicitly disabled in executor mode
STREAMING_ENABLED: "false"
```

**After (v1.3.0):**

```yaml
# Streaming follows the permanent block switch (on by default)
STREAMING_ENABLED: "true"  # When DIRECT_PERMANENT_BLOCK_ENABLED=true (default)
```

**Why it matters:**

- **Permanent blocks** (SISBAJUD "P"/"D" orders) read the balance-change stream to capture subsequent transactions
- The chart **refuses to render** if `DIRECT_PERMANENT_BLOCK_ENABLED=true` (default) without `STREAMING_BROKERS`
- Installs without streaming infrastructure (e.g. Mensageria-only) must explicitly disable permanent blocks
- The permanent block is also served only single-tenant with inbound auth on: an install with `global.auth.enabled: false` or `global.multiTenant.enabled: true` must set `sisbajud.direct.permanentBlockEnabled: false`, or the render fails.

**Migration action required:**

#### Option 1: Enable Streaming (Recommended for Production)

If you want to support permanent blocks, configure streaming:

```yaml
global:
  streaming:
    enabled: true
    brokers: "redpanda.internal:9092"
    tlsEnabled: true
    saslMechanism: "SCRAM-SHA-512"
    saslUsername: "sisbajud-executor"

sisbajud:
  secrets:
    STREAMING_SASL_PASSWORD: "your-sasl-password"
    STREAMING_TLS_CA_CERT: "<base64-encoded PEM CA certificate>"
```

#### Option 2: Disable Permanent Blocks

If you do not have streaming infrastructure, disable permanent blocks:

```yaml
sisbajud:
  direct:
    permanentBlockEnabled: false
```

> **Warning:** Disabling permanent blocks means the direct channel will refuse permanent block orders (SISBAJUD "P"/"D") with HTTP 422 error code SBJ-0027. Cancellations and UNBLOCK/TRANSFER of permanent parents are always accepted.

### 3. Library Name Changed

**What changed:**

The default OpenTelemetry library name has changed.

| Setting | v1.2.0 | v1.3.0 |
|---------|--------|--------|
| `sisbajud.observability.libraryName` | `"github.com/LerianStudio/plugin-br-sisbajud"` | `"github.com/LerianStudio/br-sisbajud"` |
| `OTEL_LIBRARY_NAME` | `"github.com/LerianStudio/plugin-br-sisbajud"` | `"github.com/LerianStudio/br-sisbajud"` |

**Why it matters:**

This affects OpenTelemetry trace and metric attributes. If you have dashboards or alerts filtering by library name, they need to be updated.

**Migration action required:**

If you have custom observability configuration, update it:

```yaml
sisbajud:
  observability:
    libraryName: "github.com/LerianStudio/br-sisbajud"
```

If you have dashboards or alerts filtering by the old library name, update them to use the new name.

## Features

### 1. Direct Channel for Order Execution

The chart now supports the **direct channel**, an HTTP API for judicial order execution that bypasses the Mensageria queue.

**Key characteristics:**

- **Permanent block support:** Handles SISBAJUD "P"/"D" orders with ongoing balance monitoring
- **Single-tenant only:** Requires `MULTI_TENANT_ENABLED=false` and `PLUGIN_AUTH_ENABLED=true`
- **Streaming integration:** Permanent blocks read the balance-change stream

**Default configuration:**

```yaml
sisbajud:
  direct:
    permanentBlockEnabled: true
    permanentRefreshEvery: "15m"
    permanentResultEmitterEnabled: ""
```

> **Note:** The `permanentBlockEnabled` flag only controls whether permanent blocks are accepted (temporary blocks, unblocks, transfers, and cancellations are always accepted).

### 2. Permanent Block Support with Balance-Change Streaming

Permanent blocks (SISBAJUD "P"/"D" orders) monitor account balances continuously and capture subsequent transactions.

**Streaming requirements:**

| Requirement | Configuration |
|-------------|---------------|
| RedPanda/Kafka brokers | `global.streaming.brokers` |
| TLS (production) | `global.streaming.tlsEnabled=true` |
| SASL authentication | `global.streaming.saslMechanism` + `saslUsername` + `STREAMING_SASL_PASSWORD` |
| CA certificate (required with TLS on; base64-encoded PEM) | `sisbajud.secrets.STREAMING_TLS_CA_CERT` |

**Configuration example:**

```yaml
global:
  streaming:
    enabled: true
    brokers: "redpanda-0.redpanda.svc.cluster.local:9092,redpanda-1.redpanda.svc.cluster.local:9092"
    tlsEnabled: true
    saslMechanism: "SCRAM-SHA-512"
    saslUsername: "sisbajud-executor"
    compression: "snappy"
    requiredAcks: "all"

sisbajud:
  direct:
    permanentBlockEnabled: true
    permanentRefreshEvery: "15m"
    permanentResultEmitterEnabled: ""

  secrets:
    STREAMING_SASL_PASSWORD: "your-sasl-password"
    STREAMING_TLS_CA_CERT: "<base64-encoded PEM CA certificate>"
```

**Rollback considerations:**

If you need to turn permanent blocks off while permanent blocks are ACTIVE:

```yaml
sisbajud:
  direct:
    permanentBlockEnabled: false

global:
  streaming:
    enabled: true
    brokers: "redpanda.internal:9092"
```

> **Important:** Keep `streaming.enabled=true` and `brokers` configured during rollback so ACTIVE permanent blocks continue to run (capture, expiry, results). The application refuses to boot with ACTIVE permanents and streaming off.

### 3. DIRECT-Only Executor Mode

The chart now supports a **DIRECT-only executor mode** that runs without Mensageria integration.

**What it is:**

- Executor runs with `EXECUTOR_ENABLED=true` and no `MENSAGERIA_BASE_URL`
- No Hub webhook listener or SQS intake (no transport configuration)
- Permanent blocks are supported (with streaming)

**Configuration example:**

```yaml
sisbajud:
  executor:
    enabled: "true"
    m2mSubject: "executor-direct"
    heartbeatEvery: "1m"
    responseDeadlineMargin: "2h"
    tickEvery: "30s"
    # No transport, webhook, or sqs configuration

  mensageria:
    baseUrl: ""  # Empty = DIRECT-only mode

  direct:
    permanentBlockEnabled: true

global:
  auth:
    enabled: true
    host: "http://plugin-access-manager-auth.midaz-plugins.svc.cluster.local:4000"
  streaming:
    enabled: true
    brokers: "redpanda.internal:9092"
```

**NOTES output (DIRECT-only mode):**

```
plugin-br-sisbajud 1.2.0 (SISBAJUD executor) deployed to namespace sisbajud.

  Executor:    DIRECT-only (EXECUTOR_ENABLED=true, no Mensageria): no Hub webhook or SQS intake; permanent block ENABLED
  KMS:         vault
  Permanent:   DIRECT_PERMANENT_BLOCK_ENABLED=true. Off stops only NEW permanents; ACTIVE ones keep running.
               Alert on sisbajud_executor_permanent_active_with_switch_off > 0 (see the chart README).
```

> **Note:** In DIRECT-only mode, only `executor.m2mSubject`, `executor.heartbeatEvery`, `executor.responseDeadlineMargin`, `executor.tickEvery`, and `executor.webhook.maxHandleAttempts` (direct drainer cap) are required. Transport, webhook listener, SQS, and `streamingHubTenantId` are not used. The render also requires `global.auth.enabled: true` and `global.auth.host`.

### 4. Enhanced Executor Configuration

The chart adds new executor configuration flags for result handling, order lifecycle, and operational alarms.

**New flags:**

| Flag | Default | Description |
|------|---------|-------------|
| `executor.resultMaxAttempts` | `"12"` | Result drainer attempt cap per outbox row (>= 1; "0" = app default 12) |
| `executor.orderSweepEnabled` | `"false"` | Enable the execution_order sweep |

**Configuration example:**

```yaml
sisbajud:
  executor:
    resultMaxAttempts: "12"
    orderSweepEnabled: "false"
    webhook:
      maxHandleAttempts: "5"
```

**Result drainer:**

- Publishes execution results to the Mensageria
- Retries up to `resultMaxAttempts` times
- After exhaustion, requires human decision (check logs for alarm)

### 5. Direct Channel Drainer Alarms

The chart adds alarm thresholds for the direct channel drainer to detect infrastructure issues and purge-eligible orders.

**New flags:**

| Flag | Default | Description |
|------|---------|-------------|
| `executor.direct.drainerInfraAlarmThreshold` | `"3"` | Alarm at every multiple of this many consecutive infra errors |
| `executor.direct.purgeEligibleAlarmAfter` | `"168h"` | ERROR log when oldest purge-eligible order is this old (7 days) |
| `executor.direct.purgeRefreshEvery` | `"15m"` | How often the purge-eligible count is refreshed |

**Configuration example:**

```yaml
sisbajud:
  executor:
    direct:
      drainerInfraAlarmThreshold: "3"
      purgeEligibleAlarmAfter: "168h"
      purgeRefreshEvery: "15m"
```

**Drainer infra alarm:**

- Triggers on consecutive infrastructure errors
- Logs an ERROR at every multiple of the threshold (3, 6, 9, ...)

**Purge-eligible alarm:**

- Logs an ERROR when the oldest purge-eligible order exceeds the threshold
- A direct order is purge-eligible once it is closed and, for a BLOCK order, one calendar year after its first ledger effect
- ACTIVE permanent blocks are never eligible
- No automatic purge: a person decides through the audited erase API

## Configuration Reference

### Executor Mode Configuration

The executor mode is determined by `EXECUTOR_ENABLED` and `MENSAGERIA_BASE_URL`:

| `EXECUTOR_ENABLED` | `MENSAGERIA_BASE_URL` | Mode | Description |
|--------------------|-----------------------|------|-------------|
| `""` (unset) | Non-blank | Mensageria | Legacy signal: Mensageria URL runs the executor |
| `"false"` | Non-blank | Mensageria | Explicit false never turns it off (legacy compatibility) |
| `"true"` | Blank | DIRECT-only | No Mensageria, no transport, only direct channel |
| `"true"` | Non-blank | Mensageria | Explicit true with Mensageria (both modes) |

**Configuration example (Mensageria mode):**

```yaml
sisbajud:
  executor:
    enabled: ""  # Or omit (legacy signal)
  
  mensageria:
    baseUrl: "https://mensageria.internal"
```

**Configuration example (DIRECT-only mode):**

```yaml
sisbajud:
  executor:
    enabled: "true"
  
  mensageria:
    baseUrl: ""  # Empty = DIRECT-only
```

### Direct Channel Configuration

| Flag | Default | Description |
|------|---------|-------------|
| `direct.permanentBlockEnabled` | `true` | Accept permanent blocks (SISBAJUD "P"/"D"); requires streaming |
| `direct.permanentRefreshEvery` | `"15m"` | How often ACTIVE permanent block accounts are refreshed (1m to 15m) |
| `direct.permanentResultEmitterEnabled` | `""` | Publish results for subsequent captures: `""` (follows streaming), `"true"`, `"false"` |

**Configuration example:**

```yaml
sisbajud:
  direct:
    permanentBlockEnabled: true
    permanentRefreshEvery: "15m"
    permanentResultEmitterEnabled: ""
```

**Permanent block switch:**

- `true` (default): Accept permanent blocks; requires `STREAMING_ENABLED=true` and `STREAMING_BROKERS`
- `false`: Refuse permanent blocks with HTTP 422 error SBJ-0027; cancellations and UNBLOCK/TRANSFER of permanents are always accepted

**Result emitter:**

- `""` (default): Follows `STREAMING_ENABLED` (on by default with permanent blocks)
- `"true"`: Always publish results (requires streaming on)
- `"false"`: Never publish results (captures are not published)

> **Important:** The permanent block switch only stops NEW permanent blocks. ACTIVE permanents keep running (capture, expiry, results) as long as streaming is on. Alert on `sisbajud_executor_permanent_active_with_switch_off > 0` to detect this state.

### Streaming Configuration

The chart now integrates with `lerian-common.streaming.env` for RedPanda/Kafka configuration.

**Required for permanent blocks:**

```yaml
global:
  streaming:
    enabled: true
    brokers: "redpanda-0.redpanda.svc.cluster.local:9092,redpanda-1.redpanda.svc.cluster.local:9092"
    tlsEnabled: true
    saslMechanism: "SCRAM-SHA-512"
    saslUsername: "sisbajud-executor"
    compression: "snappy"
    requiredAcks: "all"

sisbajud:
  secrets:
    STREAMING_SASL_PASSWORD: "your-sasl-password"
    STREAMING_TLS_CA_CERT: "<base64-encoded PEM CA certificate>"
```

**New environment variables:**

| Variable | Source | Description |
|----------|--------|-------------|
| `STREAMING_BROKERS` | `global.streaming.brokers` | Comma-separated broker list |
| `STREAMING_TLS_ENABLED` | `global.streaming.tlsEnabled` | Enable TLS (required in production) |
| `STREAMING_SASL_MECHANISM` | `global.streaming.saslMechanism` | SASL mechanism (PLAIN, SCRAM-SHA-256, SCRAM-SHA-512) |
| `STREAMING_SASL_USERNAME` | `global.streaming.saslUsername` | SASL username |
| `STREAMING_SASL_PASSWORD` | `sisbajud.secrets.STREAMING_SASL_PASSWORD` | SASL password (secret) |
| `STREAMING_TLS_CA_CERT` | `sisbajud.secrets.STREAMING_TLS_CA_CERT` | Broker CA certificate, base64-encoded PEM (secret); required with `STREAMING_TLS_ENABLED=true` |
| `STREAMING_COMPRESSION` | `global.streaming.compression` | Compression codec (none, gzip, snappy, lz4, zstd) |
| `STREAMING_REQUIRED_ACKS` | `global.streaming.requiredAcks` | Producer acks (none, leader, all) |

> **Note:** The CloudEvents source is pinned to `plugin-br-sisbajud` (the roster name). The application refuses any other value.

### Enhanced Executor Settings

**New environment variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `EXECUTOR_ENABLED` | `""` | Executor mode switch: `""` (legacy), `"true"`, `"false"` |
| `EXECUTOR_RESULT_MAX_ATTEMPTS` | `"12"` | Result drainer attempt cap per outbox row |
| `EXECUTOR_ORDER_SWEEP_ENABLED` | `"false"` | Enable the execution_order sweep |
| `EXECUTOR_DIRECT_DRAINER_INFRA_ALARM_THRESHOLD` | `"3"` | Consecutive infra errors before alarm |
| `EXECUTOR_DIRECT_PURGE_ELIGIBLE_ALARM_AFTER` | `"168h"` | Age threshold for purge-eligible alarm |
| `EXECUTOR_DIRECT_PURGE_REFRESH_EVERY` | `"15m"` | Purge-eligible count refresh interval |
| `DIRECT_PERMANENT_BLOCK_ENABLED` | `"true"` | Accept permanent blocks (requires streaming) |
| `DIRECT_PERMANENT_REFRESH_EVERY` | `"15m"` | ACTIVE permanent account refresh interval |
| `EXECUTOR_PERMANENT_RESULT_EMITTER_ENABLED` | `""` | Publish permanent capture results (follows streaming) |

## Migration Steps

### Step 1: Review Midaz CRM Mode

**If Midaz v3:**

Set the legacy CRM mode explicitly:

```yaml
sisbajud:
  midaz:
    crmMode: "legacy"
```

**If Midaz v4:**

No action required (the new default `"embedded"` is correct).

### Step 2: Configure Streaming for Permanent Blocks

**If you want to support permanent blocks (recommended):**

1. Deploy or configure RedPanda/Kafka infrastructure
2. Create a service account and credentials (SASL)
3. Configure streaming in your values:

```yaml
global:
  streaming:
    enabled: true
    brokers: "redpanda-0.redpanda.svc.cluster.local:9092,redpanda-1.redpanda.svc.cluster.local:9092"
    tlsEnabled: true
    saslMechanism: "SCRAM-SHA-512"
    saslUsername: "sisbajud-executor"

sisbajud:
  secrets:
    STREAMING_SASL_PASSWORD: "your-sasl-password"
```

4. With `tlsEnabled: true`, add the broker CA certificate (base64-encoded PEM). Without it the permanent block's balance-change consumer does not start:

```yaml
sisbajud:
  secrets:
    STREAMING_TLS_CA_CERT: "<base64-encoded PEM CA certificate>"
```

**If you do NOT have streaming infrastructure:**

Disable permanent blocks explicitly:

```yaml
sisbajud:
  direct:
    permanentBlockEnabled: false
```

> **Warning:** The chart will refuse to render if `permanentBlockEnabled=true` (default) without `STREAMING_BROKERS`.

### Step 3: Update Observability Library Name

**If you have custom observability configuration:**

Update the library name to the new value:

```yaml
sisbajud:
  observability:
    libraryName: "github.com/LerianStudio/br-sisbajud"
```

**If you have dashboards or alerts filtering by library name:**

Update them to use the new name `github.com/LerianStudio/br-sisbajud` instead of `github.com/LerianStudio/plugin-br-sisbajud`.

### Step 4: Review New Executor Settings

**Review the new executor flags and adjust if needed:**

```yaml
sisbajud:
  executor:
    resultMaxAttempts: "12"
    orderSweepEnabled: "false"
    webhook:
      maxHandleAttempts: "5"
    
    direct:
      drainerInfraAlarmThreshold: "3"
      purgeEligibleAlarmAfter: "168h"
      purgeRefreshEvery: "15m"
  
  direct:
    permanentRefreshEvery: "15m"
    permanentResultEmitterEnabled: ""
```

**Most deployments can use the defaults.** Adjust only if:

- You have high result failure rates (increase `resultMaxAttempts`)
- You want more aggressive purge alarms (decrease `purgeEligibleAlarmAfter`)

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm -n sisbajud --version 1.3.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm -n sisbajud --version 1.3.0
```
