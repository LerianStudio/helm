# Helm Upgrade from v1.2.0 to v1.3.0

## Topics

- **[Breaking Changes](#breaking-changes)**
  - [Application architecture change: monolith split into Mensageria](#application-architecture-change-monolith-split-into-mensageria)
  - [Execution API: new mandatory TLS listener](#execution-api-new-mandatory-tls-listener)
  - [Streaming is now required](#streaming-is-now-required)
  - [Removed executor-side workers and Midaz balance consumers](#removed-executor-side-workers-and-midaz-balance-consumers)
  - [Main HTTP listener port change](#main-http-listener-port-change)
  - [appVersion reset to 1.0.0](#appversion-reset-to-100)
  - [License key requirement relaxed in development environments](#license-key-requirement-relaxed-in-development-environments)
  - [Topics job disabled by default](#topics-job-disabled-by-default)
  - [STA consumer group removed](#sta-consumer-group-removed)
- **[Features](#features)**
  - [1. Execution API with dedicated TLS listener](#1-execution-api-with-dedicated-tls-listener)
  - [2. Execution sweeper and canary](#2-execution-sweeper-and-canary)
  - [3. STA stream configuration](#3-sta-stream-configuration)
  - [4. Local JWT bearer verification](#4-local-jwt-bearer-verification)
  - [5. Migrations timeout configuration](#5-migrations-timeout-configuration)
  - [6. Extra volumes and volume mounts](#6-extra-volumes-and-volume-mounts)
- **[Configuration Reference](#configuration-reference)**
  - [Execution API settings](#execution-api-settings)
  - [Execution sweeper settings](#execution-sweeper-settings)
  - [STA stream settings](#sta-stream-settings)
  - [Auth settings](#auth-settings)
  - [Migration settings](#migration-settings)
  - [Removed settings](#removed-settings)
  - [New environment variables](#new-environment-variables)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Breaking Changes

### Application architecture change: monolith split into Mensageria

The br-sisbajud application has been architecturally split. Version 1.3.0 deploys the **Sisbajud Mensageria** — the regulatory side of SISBAJUD that handles STA intake, return files, and BACEN integration. The executor-side functionality (order execution, reconciliation, permanent block expiry, Midaz balance consumers) has moved to a separate component: **plugin-br-sisbajud**.

| Setting | v1.2.0 | v1.3.0 |
|---------|--------|--------|
| Application scope | Full SISBAJUD monolith (regulatory + executor) | Mensageria only (regulatory side) |
| Source repository | `github.com/LerianStudio/br-sisbajud` | `github.com/LerianStudio/br-sfn/services/sisbajud` |
| Image repository | `ghcr.io/lerianstudio/br-sisbajud` | `ghcr.io/lerianstudio/br-sisbajud` (same, different build) |
| Executor workers | Included in monolith | Moved to plugin-br-sisbajud |
| Midaz balance consumers | Included in monolith | Moved to plugin-br-sisbajud |

**Before (v1.2.0):**

```yaml
# Chart.yaml
description: A Helm chart for br-sisbajud — the Lerian SISBAJUD plugin (judicial
  asset blocking/unblocking integration with BACEN SISBAJUD)

sources:
  - https://github.com/LerianStudio/br-sisbajud
```

**After (v1.3.0):**

```yaml
# Chart.yaml
description: A Helm chart for br-sisbajud — the Lerian Sisbajud Mensageria (the
  regulatory side of SISBAJUD judicial asset blocking with BACEN, plus the
  execution API plugin-br-sisbajud calls)

sources:
  - https://github.com/LerianStudio/br-sfn/tree/develop/services/sisbajud
```

> **Important:** The Mensageria is a **single-tenant only** service. Multi-tenant deployments are not supported in v1.3.0. The STA consumer and transfers client operate in single-tenant mode.

> **Warning:** If you were using the executor-side workers (execution, reconciliation, permanentBlockExpiry, rehashBackfill, informationRequest, monitoringExpiry) or Midaz balance consumers in v1.2.0, you must deploy plugin-br-sisbajud separately to restore that functionality. The Mensageria does not execute orders — it only prepares them for the executor.

### Execution API: new mandatory TLS listener

The Mensageria introduces a dedicated TLS listener for the execution API (`/v1/sisbajud/execution/*`), which plugin-br-sisbajud calls to fetch orders for execution. This listener is **always TLS-enabled** and terminates TLS **inside the pod** (the application has no plain-HTTP mode for it).

| Setting | v1.2.0 | v1.3.0 |
|---------|--------|--------|
| Execution API | Not present | Dedicated TLS listener on port 4032 |
| TLS termination | N/A | In-pod (application handles TLS) |
| Server certificate | N/A | Required at boot (SISBAJUD_EXECUTION_TLS_CERT_FILE / _KEY_FILE) |
| Client authentication | N/A | Optional mTLS (SISBAJUD_EXECUTION_MTLS_ENABLED) |
| Bearer token | N/A | Always required |

**Default configuration:**

```yaml
brSisbajud:
  execution:
    enabled: true
    port: 4032
    mtlsEnabled: false
    tls:
      existingSecret: ""
      certKey: tls.crt
      keyKey: tls.key
      mountPath: /etc/sisbajud/execution-tls
      generate: false
      extraDnsNames: []
      validityDays: 365
    clientCa:
      existingSecret: ""
      key: ca.crt
      mountPath: /etc/sisbajud/execution-client-ca
```

> **Important:** The application **refuses to boot** without `SISBAJUD_EXECUTION_TLS_CERT_FILE` and `SISBAJUD_EXECUTION_TLS_KEY_FILE`. You must provide a server certificate and key via `brSisbajud.execution.tls.existingSecret` (or use the dev-only `generate: true` option in development environments).

> **Warning:** The server certificate must include the Service DNS name in its Subject Alternative Names (SANs). The plugin will dial `https://<fullname>.<namespace>.svc.cluster.local:4032` by default, so the certificate must be valid for that name.

**Migration required:** See [Migration Steps](#migration-steps) for detailed instructions on provisioning the execution API certificate.

### Streaming is now required

The Mensageria **requires** streaming to be enabled (`STREAMING_ENABLED=true`) and refuses to boot with it disabled. The execution releaser (R-03) needs a real emitter, or the plugin never learns of released orders.

| Setting | v1.2.0 | v1.3.0 |
|---------|--------|--------|
| `global.streaming.enabled` | `true` (default, optional) | `true` (mandatory) |
| Application behavior with streaming disabled | Runs without broker (outbox disabled) | Refuses to boot |

**Before (v1.2.0):**

```yaml
# values.yaml comment
# On by default (needs OUTBOX_ENABLED=true, also the default). With it on the
# render requires brokers; in a production-like environment tlsEnabled: true;
# with TLS, secrets.STREAMING_TLS_CA_CERT; with a saslMechanism, saslUsername +
# secrets.STREAMING_SASL_PASSWORD. Set enabled: false to run without a broker.
```

**After (v1.3.0):**

```yaml
# values.yaml comment
# On by default and REQUIRED: the Mensageria refuses to boot with
# STREAMING_ENABLED=false (R-03: the execution releaser needs a real emitter,
# or the plugin never learns of a released order), and it needs
# OUTBOX_ENABLED=true (the default). The render requires brokers; in a
# production-like environment tlsEnabled: true; with TLS,
# secrets.STREAMING_TLS_CA_CERT; with a saslMechanism, saslUsername +
# secrets.STREAMING_SASL_PASSWORD.
```

> **Warning:** If you were running v1.2.0 with `global.streaming.enabled: false`, you must provision a Kafka/Redpanda cluster and configure `global.streaming` before upgrading to v1.3.0. The Mensageria will not start without a broker connection.

### Removed executor-side workers and Midaz balance consumers

All executor-side workers and Midaz balance consumers have been removed from the Mensageria and moved to plugin-br-sisbajud.

**Removed workers:**

- `execution` (orchestrator, unblock execution)
- `reconciliation` (order reconciliation, intensified mode)
- `permanentBlockExpiry` (permanent block expiry)
- `rehashBackfill` (hash backfill with optional key drop)
- `informationRequest` (information request processor)
- `monitoringExpiry` (monitoring expiry)

**Removed balance consumers:**

- `balanceConsumer` (core balance consumer)
- Midaz balance consumer (balance translator)

**Removed configuration keys:**

The following `brSisbajud.workers` keys are no longer rendered:

- `execution.enabled`, `execution.orchestratorLockTtl`, `execution.orchestratorRenewInterval`, `execution.unblockScanInterval`, `execution.unblockBatchSize`
- `reconciliation.enabled`, `reconciliation.scanInterval`, `reconciliation.batchSize`, `reconciliation.intensifiedEnabled`, `reconciliation.intensifiedScanInterval`, `reconciliation.nearDeadlinePercent`
- `permanentBlockExpiry.enabled`, `permanentBlockExpiry.scanInterval`, `permanentBlockExpiry.batchSize`
- `rehashBackfill.enabled`, `rehashBackfill.scanInterval`, `rehashBackfill.batchSize`, `rehashBackfill.dropPreviousKeyEnabled`
- `informationRequest.enabled`, `informationRequest.scanInterval`, `informationRequest.batchSize`, `informationRequest.lockTtl`
- `monitoringExpiry.enabled`, `monitoringExpiry.scanInterval`, `monitoringExpiry.batchSize`

The following `brSisbajud.balanceConsumer` keys are no longer rendered:

- `group`, `dedupTtl`, `retryBudget`

The following `brSisbajud.midaz` keys are no longer rendered:

- `balanceTopic`, `balanceConsumerGroup`, `balanceDefaultAccountType`, `crmMode`, `manifestCheckInterval`

> **Important:** If you have any of these keys set in your `values.yaml`, they will be ignored in v1.3.0. The chart emits a warning in `NOTES.txt` listing any removed keys that are still set. Remove them from your values file to avoid confusion.

**Migration required:** If you were using any of these workers or consumers, deploy plugin-br-sisbajud separately and configure it with the equivalent settings. See the plugin-br-sisbajud chart documentation for migration instructions.

### Main HTTP listener port change

The main HTTP API listener port has changed from 4029 to 4031 to match the Mensageria's default `SERVER_ADDRESS`.

| Setting | v1.2.0 | v1.3.0 |
|---------|--------|--------|
| `brSisbajud.service.port` | `4029` | `4031` |
| `SERVER_ADDRESS` default | `0.0.0.0:4029` | `0.0.0.0:4031` |
| Dockerfile EXPOSE | `4029` | `4031` |

**Before (v1.2.0):**

```yaml
brSisbajud:
  service:
    port: 4029
```

**After (v1.3.0):**

```yaml
brSisbajud:
  service:
    port: 4031
```

> **Note:** If you have hardcoded the port 4029 in any external configuration (e.g., Ingress backend, external load balancer, monitoring probes), update it to 4031 after the upgrade.

> **Warning:** If you override `brSisbajud.server.address` to listen on a different port, ensure it matches `brSisbajud.service.port`. The Service always follows `service.port`, so a mismatch will leave the application listening where nothing routes.

### appVersion reset to 1.0.0

The chart's `appVersion` has been reset to `1.0.0` to reflect the Mensageria's versioning scheme (independent of the monolith's 1.2.x series).

| Setting | v1.2.0 | v1.3.0 |
|---------|--------|--------|
| `appVersion` | `1.2.0` | `1.0.0` |
| Default image tag | `1.2.0` | `1.0.0` |
| Release tag format | `v1.2.0` | `sisbajud-v1.0.0` (br-sfn monorepo) |

**Before (v1.2.0):**

```yaml
# Chart.yaml
appVersion: "1.2.0"

# NOTE: appVersion is the default image tag for the app, the migrations Job and
# the topics Job. Override via brSisbajud.image.tag / migrations.image.tag /
# topics.image.tag when needed.
```

**After (v1.3.0):**

```yaml
# Chart.yaml
appVersion: "1.0.0"

# NOTE: appVersion is the default image tag for the app and the migrations Job
# (br-sfn release sisbajud-v<appVersion>: ghcr.io/lerianstudio/br-sisbajud and
# br-sisbajud-migrations). The optional topics Job pins its own tag. Override
# via brSisbajud.image.tag / migrations.image.tag when needed.
```

> **Important:** The image tag defaults to `appVersion` (1.0.0). If you were relying on the default tag in v1.2.0, the upgrade will pull the 1.0.0 Mensageria image. This is the intended behavior — the Mensageria is a new application with its own version series.

> **Note:** The topics job now pins its own tag (`1.2.0`, the last published topics image) independently of `appVersion`, since br-sfn does not publish a Mensageria-specific topics image. The topics job uses a generic rpk entrypoint that is product-agnostic.

### License key requirement relaxed in development environments

The license key requirement has been relaxed in development-class environments. In v1.2.0, `LICENSE_KEY` was required in **every** environment (no dev bypass). In v1.3.0, an empty `LICENSE_KEY` is accepted as the dev bypass in `local`, `development`, `staging`, `e2e`, and `test` environments.

| Setting | v1.2.0 | v1.3.0 |
|---------|--------|--------|
| `LICENSE_KEY` required | Every environment | Production-like environments only |
| Dev bypass | None (always required) | Empty `LICENSE_KEY` in local/development/staging/e2e/test |

**Before (v1.2.0):**

```yaml
# values.yaml comment
# LICENSE_KEY is a secret and, since app 1.2.0, required in
# EVERY environment (no dev bypass): the render fails without it.
```

**After (v1.3.0):**

```yaml
# values.yaml comment
# LICENSE_KEY is a secret, required in a production-like
# environment (anything but local|development|staging|e2e|test); in those five
# an empty LICENSE_KEY is the app's dev bypass.
```

> **Note:** In production-like environments (anything other than the five dev-class names), `LICENSE_KEY` is still required and the render will fail without it. In development environments, you can leave it empty or unset.

### Topics job disabled by default

The topics provisioning job is now **disabled by default** (`topics.enabled: false`). The Mensageria's lib-streaming v4.1 creates its own topics (`lerian.streaming.br-sisbajud` and `.dlq`) at boot when `STREAMING_TOPIC_AUTO_PROVISION` is true (the default) and the principal holds CreateTopics ACL.

| Setting | v1.2.0 | v1.3.0 |
|---------|--------|--------|
| `topics.enabled` | `true` | `false` |
| Topic auto-creation | App creates topics if principal has CreateTopics | App creates topics if principal has CreateTopics |
| Topics job purpose | Idempotent pre-provisioning | Optional (only for brokers where principal lacks CreateTopics) |

**Before (v1.2.0):**

```yaml
topics:
  enabled: true
  list:
    - lerian.streaming.br-sisbajud
    - lerian.streaming.br-sisbajud.dlq
    - lerian.streaming.br-sisbajud.commands
```

**After (v1.3.0):**

```yaml
topics:
  enabled: false
  list:
    - lerian.streaming.br-sisbajud
    - lerian.streaming.br-sisbajud.dlq
```

> **Note:** The `.commands` topic has been removed from the list. It was used by the balance trigger in the monolith, which has moved to plugin-br-sisbajud.

> **Important:** Enable the topics job only if your broker requires pre-provisioned topics and the Mensageria's principal lacks CreateTopics ACL. Otherwise, leave it disabled and let the application create its topics at boot.

### STA consumer group removed

The `STA_CONSUMER_GROUP` environment variable has been removed. The STA consumer now uses a hardcoded consumer group name internally.

| Setting | v1.2.0 | v1.3.0 |
|---------|--------|--------|
| `brSisbajud.sta.consumerGroup` | `"sisbajud-sta-consumer"` (default) | Removed |
| `STA_CONSUMER_GROUP` | Rendered | Not rendered |

**Before (v1.2.0):**

```yaml
brSisbajud:
  sta:
    consumerGroup: "sisbajud-sta-consumer"
```

**After (v1.3.0):**

```yaml
# brSisbajud.sta.consumerGroup is no longer a valid key
```

> **Note:** If you have `brSisbajud.sta.consumerGroup` set in your `values.yaml`, remove it. The key is ignored in v1.3.0.

---

## Features

### 1. Execution API with dedicated TLS listener

The Mensageria introduces a dedicated TLS listener for the execution API, which plugin-br-sisbajud calls to fetch orders for execution. This listener is always TLS-enabled and terminates TLS inside the pod.

**Configuration:**

```yaml
brSisbajud:
  execution:
    enabled: true
    port: 4032
    mtlsEnabled: false
    tls:
      existingSecret: ""
      certKey: tls.crt
      keyKey: tls.key
      mountPath: /etc/sisbajud/execution-tls
      generate: false
      extraDnsNames: []
      validityDays: 365
    clientCa:
      existingSecret: ""
      key: ca.crt
      mountPath: /etc/sisbajud/execution-client-ca
```

| Flag | Default | Description |
|------|---------|-------------|
| `brSisbajud.execution.enabled` | `true` | Enable the execution API listener (renders port, env, mount) |
| `brSisbajud.execution.port` | `4032` | Container and Service port for the execution API |
| `brSisbajud.execution.mtlsEnabled` | `false` | Require and verify client certificates (mTLS) |
| `brSisbajud.execution.tls.existingSecret` | `""` | Secret holding the server certificate and key (e.g., cert-manager issued Secret) |
| `brSisbajud.execution.tls.certKey` | `tls.crt` | Key in the Secret holding the server certificate |
| `brSisbajud.execution.tls.keyKey` | `tls.key` | Key in the Secret holding the server private key |
| `brSisbajud.execution.tls.mountPath` | `/etc/sisbajud/execution-tls` | Mount path for the TLS Secret |
| `brSisbajud.execution.tls.generate` | `false` | DEV ONLY: generate a self-signed CA and server certificate |
| `brSisbajud.execution.tls.extraDnsNames` | `[]` | Additional DNS names for the generated certificate (only with `generate: true`) |
| `brSisbajud.execution.tls.validityDays` | `365` | Validity period for the generated certificate (only with `generate: true`) |
| `brSisbajud.execution.clientCa.existingSecret` | `""` | Secret holding the client CA bundle (mTLS only; empty = reuse `tls.existingSecret`) |
| `brSisbajud.execution.clientCa.key` | `ca.crt` | Key in the Secret holding the client CA bundle |
| `brSisbajud.execution.clientCa.mountPath` | `/etc/sisbajud/execution-client-ca` | Mount path for the client CA Secret |

**Service exposure:**

The execution API is exposed on the same Service as the main HTTP API, as a second port named `execution`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: br-sisbajud
spec:
  ports:
    - name: http
      port: 4031
      targetPort: 4031
    - name: execution
      port: 4032
      targetPort: 4032
```

The plugin reaches it at `https://<fullname>.<namespace>.svc.cluster.local:4032`.

**TLS modes:**

#### One-way TLS (default)

The listener requires TLS but does not verify client certificates. The plugin only needs to trust the server CA.

```yaml
brSisbajud:
  execution:
    mtlsEnabled: false
    tls:
      existingSecret: "br-sisbajud-execution-tls"
```

#### Mutual TLS (mTLS)

The listener requires and verifies client certificates signed by the client CA. The plugin needs both the server CA (to trust the server) and a client certificate (to authenticate itself).

```yaml
brSisbajud:
  execution:
    mtlsEnabled: true
    tls:
      existingSecret: "br-sisbajud-execution-tls"
    clientCa:
      existingSecret: "br-sisbajud-execution-client-ca"
```

> **Important:** If you enable mTLS (`mtlsEnabled: true`), you must also enable mTLS on the plugin side (`plugin-br-sisbajud` chart: `brSisbajud.mensageria.mtlsEnabled: true`) and provide a client certificate. A mismatch (mTLS on one side, one-way TLS on the other) will fail the TLS handshake.

**Development mode: self-signed certificate generation**

For development environments only, the chart can generate a self-signed CA and server certificate:

```yaml
brSisbajud:
  execution:
    tls:
      generate: true
      extraDnsNames:
        - "br-sisbajud.example.local"
```

> **Warning:** `generate: true` is **refused outside development-class environments** (local, development, staging, e2e, test). In production, use a real certificate issued by cert-manager or your PKI.

> **Note:** Under ArgoCD (no Helm lookup), the generated certificate regenerates on every sync. Use `existingSecret` with ArgoCD to avoid certificate churn.

The generated certificate includes the following SANs:

- `<fullname>.<namespace>.svc.cluster.local` (default Service DNS)
- `<fullname>.<namespace>.svc` (short Service DNS)
- `<fullname>` (pod-local DNS)
- Any additional names in `extraDnsNames`

The chart writes the CA, certificate, and key into a Secret named `<fullname>-execution-tls` with keys `ca.crt`, `tls.crt`, and `tls.key`. Copy `ca.crt` into the plugin's Mensageria CA Secret.

### 2. Execution sweeper and canary

The Mensageria includes an execution sweeper (per-subject release sweep, retained-order alarms) and a canary (executor round-trip probe).

**Configuration:**

```yaml
brSisbajud:
  executionSweep:
    responseDeadlineMargin: "2h"
    drainedHeadAlarmAfter: "30m"
    sweepIntervalSec: "60"
    deadlineMarginSec: ""
    canaryIntervalSec: "300"
```

| Flag | Default | Description |
|------|---------|-------------|
| `brSisbajud.executionSweep.responseDeadlineMargin` | `"2h"` | Go duration: how far before the response deadline to release orders |
| `brSisbajud.executionSweep.drainedHeadAlarmAfter` | `"30m"` | Go duration: alarm if the head order is retained for this long after all others are drained |
| `brSisbajud.executionSweep.sweepIntervalSec` | `"60"` | Sweep interval in seconds |
| `brSisbajud.executionSweep.deadlineMarginSec` | `""` | Deadline margin in seconds (unset = return file `scanInterval`; must be > 0 and < 21600) |
| `brSisbajud.executionSweep.canaryIntervalSec` | `"300"` | Canary probe interval in seconds |

> **Note:** `responseDeadlineMargin` and `drainedHeadAlarmAfter` are Go durations (e.g., `2h`, `30m`, `1h30m`). The application has no defaults for these; the chart defaults are shown above.

### 3. STA stream configuration

The Mensageria's STA consumer reads from br-sta's **own Kafka cluster**, not from `global.streaming`. This is configured via `brSisbajud.sta.stream`.

**Configuration:**

```yaml
brSisbajud:
  sta:
    consumerEnabled: false
    stream:
      brokers: ""
      saslMechanism: ""
      saslUsername: ""
      saslAllowPlaintext: ""
      tlsEnabled: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `brSisbajud.sta.stream.brokers` | `""` | Kafka broker addresses (comma-separated) |
| `brSisbajud.sta.stream.saslMechanism` | `""` | SASL mechanism (PLAIN, SCRAM-SHA-256, SCRAM-SHA-512) |
| `brSisbajud.sta.stream.saslUsername` | `""` | SASL username |
| `brSisbajud.sta.stream.saslAllowPlaintext` | `""` | Allow SASL over plaintext (refused in production) |
| `brSisbajud.sta.stream.tlsEnabled` | `""` | Enable TLS |

**Secrets:**

- `STA_STREAM_SASL_PASSWORD`: SASL password (in `brSisbajud.secrets`)
- `STA_STREAM_TLS_CA_CERT`: CA certificate bundle (base64 PEM, in `brSisbajud.secrets`)

**Validation:**

When `brSisbajud.sta.consumerEnabled` is `true`, the application requires:

- `brokers`
- Full SASL triple (`saslMechanism`, `saslUsername`, `STA_STREAM_SASL_PASSWORD`)
- TLS + CA (`tlsEnabled: true`, `STA_STREAM_TLS_CA_CERT`), or `saslAllowPlaintext: true` (refused in production)

> **Important:** The STA consumer is **single-tenant only**. It does not fall back to `global.streaming` — it reads only from the br-sta cluster configured here.

### 4. Local JWT bearer verification

The Mensageria now performs local JWT bearer verification (lib-auth) in addition to calling the Access Manager. This is **required at boot** in both auth switch positions (`PLUGIN_AUTH_ENABLED=true` and `false`), with one exemption: `PLUGIN_AUTH_ENABLED=true` + `DEPLOYMENT_MODE=local` + `ENV_NAME=local`.

**Configuration:**

```yaml
brSisbajud:
  auth:
    jwtIssuer: ""
    jwtVerifyCert: ""
    jwtVerifyCertSecret:
      name: ""
      key: ""
    jwtVerifyCertPath: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `brSisbajud.auth.jwtIssuer` | `""` | Exact `iss` claim the Access Manager stamps into tokens |
| `brSisbajud.auth.jwtVerifyCert` | `""` | Inline PEM of the Access Manager's RSA public key/certificate (wins over path) |
| `brSisbajud.auth.jwtVerifyCertSecret.name` | `""` | Secret holding the PEM (mounted read-only) |
| `brSisbajud.auth.jwtVerifyCertSecret.key` | `""` | Key in the Secret holding the PEM |
| `brSisbajud.auth.jwtVerifyCertPath` | `""` | Path to the PEM file (with your own `extraVolumes`/`extraVolumeMounts`) |

**Precedence:**

1. `jwtVerifyCert` (inline PEM, rendered into ConfigMap)
2. `jwtVerifyCertSecret` (Secret mount, sets `AUTH_JWT_VERIFY_CERT_PATH`)
3. `jwtVerifyCertPath` (verbatim path, with your own mounts)

> **Note:** The PEM is the Access Manager's **public key or certificate**, not a credential. It is safe to render into the ConfigMap via `jwtVerifyCert`.

**Example (inline PEM):**

```yaml
brSisbajud:
  auth:
    jwtIssuer: "https://access-manager.example.com"
    jwtVerifyCert: |
      -----BEGIN PUBLIC KEY-----
      MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
      -----END PUBLIC KEY-----
```

**Example (Secret mount):**

```yaml
brSisbajud:
  auth:
    jwtIssuer: "https://access-manager.example.com"
    jwtVerifyCertSecret:
      name: "access-manager-jwt-public-key"
      key: "public.pem"
```

### 5. Migrations timeout configuration

The migrations job now supports a configurable timeout via `migrations.timeoutSec`.

**Configuration:**

```yaml
migrations:
  timeout
