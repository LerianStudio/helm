# Helm Upgrade from v0.x to v1.x

This guide covers the upgrade of the `plugin-br-sisbajud` Helm chart from version **0.0.0** to **1.0.0**. This is the initial release of the chart, introducing the SISBAJUD executor service that pulls judicial orders from the Sisbajud Mensageria, executes them on Midaz, and posts results back.

## Table of Contents

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
- **[Features](#features)**
  - [1. SISBAJUD Executor Service](#1-sisbajud-executor-service)
  - [2. Sisbajud Mensageria Integration](#2-sisbajud-mensageria-integration)
  - [3. Streaming Hub Webhook Listener](#3-streaming-hub-webhook-listener)
  - [4. SQS Consumer Transport](#4-sqs-consumer-transport)
  - [5. Database Migrations](#5-database-migrations)
  - [6. Bundled Development Infrastructure](#6-bundled-development-infrastructure)
  - [7. Security and Compliance](#7-security-and-compliance)
  - [8. Observability and Monitoring](#8-observability-and-monitoring)
- **[Deployment Scenarios](#deployment-scenarios)**
  - [Production with External Infrastructure](#production-with-external-infrastructure)
  - [Development with Bundled Infrastructure](#development-with-bundled-infrastructure)
  - [AWS Deployment with IAM Roles Anywhere](#aws-deployment-with-iam-roles-anywhere)
- **[Configuration Reference](#configuration-reference)**
  - [Required Configuration](#required-configuration)
  - [Mensageria TLS Configuration](#mensageria-tls-configuration)
  - [Executor Configuration](#executor-configuration)
  - [Webhook Listener Configuration](#webhook-listener-configuration)
  - [SQS Consumer Configuration](#sqs-consumer-configuration)
  - [Infrastructure Configuration](#infrastructure-configuration)
  - [Security Configuration](#security-configuration)
  - [Environment Variables](#environment-variables)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 1.0.0 is the initial release of the `plugin-br-sisbajud` Helm chart. This chart deploys the SISBAJUD executor, a service that:

- Pulls judicial orders from the Sisbajud Mensageria over the execution contract (one-way TLS by default, optional mTLS)
- Executes orders on Midaz (block / unblock / transfer / information operations)
- Posts execution results back to the Mensageria
- Provides an HTTP API on port 4029
- Runs a Streaming Hub webhook listener on port 9082

The chart follows the Lerian Studio single-service pattern and integrates with the `lerian-common-helm` library (v2.3.0) for shared configuration contracts.

## Breaking Changes

This is the initial release (v0.0.0 → v1.0.0), so there are no breaking changes from a previous version. However, operators must be aware of the following requirements:

### Mandatory Configuration

The chart **will not render** without the following configuration values set:

1. **Mensageria URL and TLS certificates** (`sisbajud.mensageria.baseUrl`, CA certificate)
2. **M2M identity** (`sisbajud.executor.m2mSubject`, `sisbajud.secrets.MENSAGERIA_CLIENT_ID`, `sisbajud.secrets.MENSAGERIA_CLIENT_SECRET`)
3. **License key** (`sisbajud.secrets.LICENSE_KEY`)
4. **KMS configuration** (`global.kms` or `sisbajud.kms`)
5. **PostgreSQL connection** (`global.datastores.postgres` or `sisbajud.datastores.postgres`)
6. **Redis/Valkey connection** (`global.datastores.redis` or `sisbajud.datastores.redis`)

> **Important:** The chart will fail the render with the exact key to set for any missing required value. Start from the `values-template.yaml` file provided in the chart repository.

## Features

### 1. SISBAJUD Executor Service

The chart deploys a single Go process that runs the executor runner, HTTP API, and webhook listener.

**Key characteristics:**

- **Single replica by default** (one runner per tenant, one webhook subscription)
- **Distroless container** (`ghcr.io/lerianstudio/plugin-br-sisbajud`) running as nonroot user (UID/GID 65532)
- **Read-only root filesystem** with security context hardening
- **Resource requests/limits** (100m CPU / 256Mi memory requests, 1 CPU / 512Mi memory limits)

**Default configuration:**

```yaml
sisbajud:
  enabled: true
  replicaCount: 1
  image:
    repository: ghcr.io/lerianstudio/plugin-br-sisbajud
    tag: ""  # Defaults to Chart.appVersion (1.0.0)
    pullPolicy: IfNotPresent
  
  service:
    type: ClusterIP
    port: 4029
  
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: "1"
      memory: 512Mi
```

### 2. Sisbajud Mensageria Integration

The executor connects to the Sisbajud Mensageria (a br-sfn rail) over HTTPS to fetch judicial orders and post results.

**TLS modes:**

| Mode | Description | Required Configuration |
|------|-------------|------------------------|
| One-way TLS (default) | Executor verifies Mensageria server certificate | `mensageria.baseUrl`, optional CA certificate |
| Mutual TLS (mTLS) | Both parties verify each other | `mensageria.baseUrl`, `mensageria.mtlsEnabled: true`, CA certificate, client certificate pair |

**Configuration example (one-way TLS):**

```yaml
sisbajud:
  mensageria:
    baseUrl: "https://mensageria.internal.example.com"
    mtlsEnabled: false
    ca:
      existingSecret: "mensageria-ca"
      key: "ca.crt"
      mountPath: "/etc/plugin-br-sisbajud/mensageria-ca"
```

**Configuration example (mutual TLS):**

```yaml
sisbajud:
  mensageria:
    baseUrl: "https://mensageria.internal.example.com"
    mtlsEnabled: true
    ca:
      existingSecret: "mensageria-ca"
      key: "ca.crt"
      mountPath: "/etc/plugin-br-sisbajud/mensageria-ca"
    tls:
      existingSecret: "executor-client-cert"
      certKey: "tls.crt"
      keyKey: "tls.key"
      mountPath: "/etc/plugin-br-sisbajud/mensageria"
```

> **Note:** The `mtlsEnabled` setting must match the Mensageria's `SISBAJUD_EXECUTION_MTLS_ENABLED` configuration. A mismatch will cause TLS handshake failures.

### 3. Streaming Hub Webhook Listener

The executor runs a dedicated webhook listener on port 9082 to receive events from the Streaming Hub.

**Key features:**

- **Separate Service** (`plugin-br-sisbajud-webhook`) on port 9082
- **Optional Ingress** for external Streaming Hub access
- **HMAC signature verification** (`EXECUTOR_HUB_WEBHOOK_SECRET`)
- **Optional TLS** (certificate pair or upstream termination)

**Default configuration:**

```yaml
sisbajud:
  executor:
    webhook:
      port: 9082
      path: "/v1/webhooks/hub"
      maxSkewSec: "300"
      maxHandleAttempts: "5"
      upstreamTlsValidated: false
      
      service:
        type: ClusterIP
        port: 9082
      
      ingress:
        enabled: false
        className: ""
        annotations: {}
        hosts: []
        tls: []
```

**Webhook secret configuration:**

```yaml
sisbajud:
  secrets:
    EXECUTOR_HUB_WEBHOOK_SECRET: "your-webhook-secret-here"
    EXECUTOR_HUB_WEBHOOK_SECRET_PREVIOUS: "previous-secret-for-rotation"
```

### 4. SQS Consumer Transport

As an alternative to the webhook listener, the executor can consume events from an AWS SQS queue.

**Transport selection:**

```yaml
sisbajud:
  executor:
    transport: "sqs"  # Default: "webhook"
    
    sqs:
      queueUrl: "https://sqs.us-east-1.amazonaws.com/123456789012/sisbajud-orders"
      region: "us-east-1"
      waitTimeSeconds: "20"
      maxMessages: "10"
      visibilityTimeoutSeconds: "300"
      maxReceiveCount: "5"
```

> **Note:** SQS transport requires AWS credentials (IRSA via `serviceAccount.annotations` or `aws.rolesAnywhere` configuration).

### 5. Database Migrations

The chart includes a migrations component that runs PostgreSQL schema migrations using the `plugin-br-sisbajud-migrations` image.

**Deployment modes:**

| Scenario | Mode | Description |
|----------|------|-------------|
| External PostgreSQL | Pre-install/pre-upgrade hook Job | Runs as a Helm hook (ArgoCD PreSync) |
| Bundled PostgreSQL | InitContainer | Runs as an initContainer of the app pod |

**Default configuration:**

```yaml
migrations:
  enabled: true
  image:
    repository: ghcr.io/lerianstudio/plugin-br-sisbajud-migrations
    tag: ""  # Defaults to Chart.appVersion
    pullPolicy: IfNotPresent
  
  timeoutSec: "300"
  backoffLimit: 3
  activeDeadlineSeconds: 600
  ttlSecondsAfterFinished: 300
  
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      memory: 256Mi
```

> **Important:** Migrations are skipped when `MULTI_TENANT_ENABLED=true` (per-tenant schemas are migrated outside this chart).

### 6. Bundled Development Infrastructure

The chart can optionally bundle PostgreSQL and Valkey (Redis-compatible) for development environments.

**PostgreSQL subchart:**

```yaml
postgresql:
  enabled: false  # Set to true for development
  auth:
    username: "sisbajud"
    password: "dev-password"
    database: "sisbajud"
```

**Valkey subchart:**

```yaml
valkey:
  enabled: false  # Set to true for development
  auth:
    enabled: true
    password: "dev-password"
```

> **Warning:** Bundled infrastructure is for development only. Production deployments must use external, managed PostgreSQL and Redis/Valkey instances.

### 7. Security and Compliance

The chart implements security best practices:

**Pod Security:**

```yaml
sisbajud:
  podSecurityContext:
    fsGroup: 65532
    seccompProfile:
      type: RuntimeDefault
  
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    runAsGroup: 65532
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
    seccompProfile:
      type: RuntimeDefault
```

**Secrets Management:**

- **Chart-managed Secret** for credentials (default)
- **External Secret** support via `sisbajud.useExistingSecret` (ESO/Vault integration)
- **KMS integration** for envelope encryption (HashiCorp Vault or AWS KMS)

**License Enforcement:**

```yaml
sisbajud:
  license:
    organizationIds: "global"
    isDevelopment: ""  # Set to "true" for dev-issued license keys
  
  secrets:
    LICENSE_KEY: "your-license-key-here"
```

### 8. Observability and Monitoring

The chart includes comprehensive observability features:

**Health Probes:**

```yaml
sisbajud:
  readinessProbe:
    path: /readyz
    initialDelaySeconds: 10
    periodSeconds: 10
    timeoutSeconds: 5
    successThreshold: 1
    failureThreshold: 3
  
  livenessProbe:
    path: /version  # Static endpoint to avoid restart loops
    initialDelaySeconds: 15
    periodSeconds: 20
    timeoutSeconds: 5
    successThreshold: 1
    failureThreshold: 3
```

**OpenTelemetry:**

```yaml
global:
  observability:
    enabled: "true"
    otlpEndpoint: "otel-collector.observability.svc.cluster.local:4317"
    deploymentEnvironment: "production"

sisbajud:
  observability:
    serviceName: "plugin-br-sisbajud"
    libraryName: "github.com/LerianStudio/plugin-br-sisbajud"
```

**Logging:**

```yaml
sisbajud:
  app:
    logLevel: "info"  # debug | info | warn | error
```

## Deployment Scenarios

### Production with External Infrastructure

**Recommended for production environments:**

```yaml
global:
  cloud: "aws"  # or "gcp", "azure", "" for self-managed
  
  datastores:
    postgres:
      host: "postgres.production.internal"
      port: "5432"
      user: "sisbajud"
      name: "sisbajud"
      ssl: "require"
    redis:
      host: "redis.production.internal"
      port: "6379"
      tls: "true"
  
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
  
  observability:
    enabled: "true"
    otlpEndpoint: "otel-collector.observability.svc.cluster.local:4317"
    deploymentEnvironment: "production"

sisbajud:
  replicaCount: 1
  
  app:
    environmentName: "production"
    deploymentMode: "byoc"
    defaultTenantId: "11111111-1111-1111-1111-111111111111"
  
  mensageria:
    baseUrl: "https://mensageria.production.internal"
    mtlsEnabled: true
    ca:
      existingSecret: "mensageria-ca"
    tls:
      existingSecret: "executor-client-cert"
  
  executor:
    m2mSubject: "executor-production"
    streamingHubTenantId: "22222222-2222-2222-2222-222222222222"
    heartbeatEvery: "1m"
    responseDeadlineMargin: "2h"
    transport: "webhook"
  
  secrets:
    LICENSE_KEY: "prod-license-key"
    MENSAGERIA_CLIENT_ID: "executor-client-id"
    MENSAGERIA_CLIENT_SECRET: "executor-client-secret"
    EXECUTOR_HUB_WEBHOOK_SECRET: "webhook-secret"
    POSTGRES_PASSWORD: "postgres-password"
    REDIS_PASSWORD: "redis-password"

postgresql:
  enabled: false

valkey:
  enabled: false
```

### Development with Bundled Infrastructure

**For local development and testing:**

```yaml
global:
  cloud: ""

sisbajud:
  replicaCount: 1
  
  app:
    environmentName: "development"
    deploymentMode: "local"
    defaultTenantId: "11111111-1111-1111-1111-111111111111"
  
  mensageria:
    baseUrl: "https://mensageria.dev.internal"
    mtlsEnabled: false
  
  executor:
    m2mSubject: "executor-dev"
    streamingHubTenantId: "22222222-2222-2222-2222-222222222222"
    heartbeatEvery: "30s"
    responseDeadlineMargin: "1h"
    transport: "webhook"
  
  license:
    isDevelopment: "true"
  
  secrets:
    LICENSE_KEY: "dev-license-key"
    MENSAGERIA_CLIENT_ID: "executor-dev"
    MENSAGERIA_CLIENT_SECRET: "dev-secret"
    EXECUTOR_HUB_WEBHOOK_SECRET: "dev-webhook-secret"

postgresql:
  enabled: true
  auth:
    username: "sisbajud"
    password: "dev-password"
    database: "sisbajud"

valkey:
  enabled: true
  auth:
    enabled: true
    password: "dev-password"
```

### AWS Deployment with IAM Roles Anywhere

**For AWS deployments using IAM Roles Anywhere for KMS access:**

```yaml
global:
  cloud: "aws"
  
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"

sisbajud:
  serviceAccount:
    create: true
    annotations: {}  # IRSA not used with Roles Anywhere

aws:
  rolesAnywhere:
    enabled: true
    trustAnchorArn: "arn:aws:rolesanywhere:us-east-1:123456789012:trust-anchor/abc123"
    profileArn: "arn:aws:rolesanywhere:us-east-1:123456789012:profile/executor-profile"
    roleArn: "arn:aws:iam::123456789012:role/executor-kms-role"
    region: "us-east-1"
    
    certificate:
      existingSecret: "executor-aws-cert"
      certKey: "tls.crt"
      keyKey: "tls.key"
```

## Configuration Reference

### Required Configuration

The following values **must** be set for the chart to render successfully:

| Parameter | Description | Example |
|-----------|-------------|---------|
| `sisbajud.mensageria.baseUrl` | Mensageria HTTPS endpoint | `https://mensageria.internal` |
| `sisbajud.executor.m2mSubject` | M2M token subject | `executor-production` |
| `sisbajud.executor.heartbeatEvery` | Heartbeat interval (Go duration) | `1m` |
| `sisbajud.executor.responseDeadlineMargin` | Response deadline margin (must match Mensageria) | `2h` |
| `sisbajud.secrets.LICENSE_KEY` | Lerian Studio license key | `license-key-here` |
| `sisbajud.secrets.MENSAGERIA_CLIENT_ID` | M2M client ID | `client-id` |
| `sisbajud.secrets.MENSAGERIA_CLIENT_SECRET` | M2M client secret | `client-secret` |
| `global.kms.vendor` or `sisbajud.kms.vendor` | KMS provider | `hashicorp-vault` or `aws` |
| `global.datastores.postgres.host` | PostgreSQL host | `postgres.internal` |
| `global.datastores.redis.host` | Redis/Valkey host | `redis.internal` |

### Mensageria TLS Configuration

**One-way TLS (default):**

```yaml
sisbajud:
  mensageria:
    baseUrl: "https://mensageria.internal"
    mtlsEnabled: false
    ca:
      existingSecret: "mensageria-ca"  # Optional
      key: "ca.crt"
      mountPath: "/etc/plugin-br-sisbajud/mensageria-ca"
```

**Mutual TLS:**

```yaml
sisbajud:
  mensageria:
    baseUrl: "https://mensageria.internal"
    mtlsEnabled: true
    ca:
      existingSecret: "mensageria-ca"  # Required
      key: "ca.crt"
      mountPath: "/etc/plugin-br-sisbajud/mensageria-ca"
    tls:
      existingSecret: "executor-client-cert"  # Required
      certKey: "tls.crt"
      keyKey: "tls.key"
      mountPath: "/etc/plugin-br-sisbajud/mensageria"
```

### Executor Configuration

| Flag | Default | Description |
|------|---------|-------------|
| `executor.m2mSubject` | `""` (required) | Subject claim of the executor's M2M token |
| `executor.streamingHubTenantId` | `""` (required) | Streaming Hub tenant ID (must match Hub deployment) |
| `executor.heartbeatEvery` | `""` (required) | Heartbeat interval (Go duration, e.g. "1m") |
| `executor.humanDecisionAfterBeats` | `"3"` | Number of missed heartbeats before human decision |
| `executor.responseDeadlineMargin` | `""` (required) | Response deadline margin (must match Mensageria, e.g. "2h") |
| `executor.settleWindow` | `""` | Settlement window (Go duration, default "1s") |
| `executor.tickEvery` | `"30s"` | Tick interval for internal processing |
| `executor.orphanReconcileWindow` | `"48h"` | Window for orphan order reconciliation |
| `executor.transport` | `"webhook"` | Transport mode: `webhook` or `sqs` |

### Webhook Listener Configuration

| Flag | Default | Description |
|------|---------|-------------|
| `executor.webhook.port` | `9082` | Webhook listener port |
| `executor.webhook.path` | `"/v1/webhooks/hub"` | Webhook endpoint path |
| `executor.webhook.maxSkewSec` | `"300"` | Maximum timestamp skew for signature verification (seconds) |
| `executor.webhook.maxHandleAttempts` | `"5"` | Maximum retry attempts for webhook handling |
| `executor.webhook.upstreamTlsValidated` | `false` | Whether TLS is terminated upstream (load balancer) |

**Webhook TLS configuration:**

```yaml
sisbajud:
  executor:
    webhook:
      upstreamTlsValidated: false
      tls:
        existingSecret: "webhook-tls-cert"
        certKey: "tls.crt"
        keyKey: "tls.key"
        mountPath: "/etc/plugin-br-sisbajud/webhook-tls"
```

**Webhook Ingress configuration:**

```yaml
sisbajud:
  executor:
    webhook:
      ingress:
        enabled: true
        className: "nginx"
        annotations:
          cert-manager.io/cluster-issuer: "letsencrypt-prod"
        hosts:
          - host: executor-webhook.example.com
            paths:
              - path: /v1/webhooks/hub
                pathType: Exact
        tls:
          - secretName: webhook-tls
            hosts:
              - executor-webhook.example.com
```

### SQS Consumer Configuration

| Flag | Default | Description |
|------|---------|-------------|
| `executor.sqs.queueUrl` | `""` | SQS queue URL |
| `executor.sqs.region` | `""` | AWS region |
| `executor.sqs.waitTimeSeconds` | `"20"` | Long polling wait time |
| `executor.sqs.maxMessages` | `"10"` | Maximum messages per receive |
| `executor.sqs.visibilityTimeoutSeconds` | `"300"` | Message visibility timeout |
| `executor.sqs.maxReceiveCount` | `"5"` | Maximum receive count before DLQ |

### Infrastructure Configuration

**PostgreSQL:**

```yaml
global:
  datastores:
    postgres:
      host: "postgres.internal"
      port: "5432"
      user: "sisbajud"
      name: "sisbajud"
      ssl: "require"
      replicaHost: "postgres-replica.internal"  # Optional read replica

sisbajud:
  postgres:
    maxOpenConns: "25"
    maxIdleConns: "5"
    connMaxLifetimeMins: "30"
    connMaxIdleTimeMins: "5"
    connectTimeoutSec: "10"
  
  secrets:
    POSTGRES_PASSWORD: "postgres-password"
    POSTGRES_REPLICA_PASSWORD: "replica-password"  # If using replica
```

**Redis/Valkey:**

```yaml
global:
  datastores:
    redis:
      host: "redis.internal"
      port: "6379"
      tls: "true"
      caCert: "/path/to/ca.crt"  # Optional CA certificate path

sisbajud:
  redis:
    db: "0"
    protocol: "3"
    masterName: ""  # For Redis Sentinel
  
  secrets:
    REDIS_PASSWORD: "redis-password"
```

**KMS (HashiCorp Vault):**

```yaml
global:
  kms:
    vendor: "hashicorp-vault"
    vaultAddr: "https://vault.internal:8200"
    vaultAuthMethod: "approle"
    vaultRoleId: "role-id-here"
    vaultMount: "transit"

sisbajud:
  vault:
    timeoutSec: "15"
    renewEnabled: "true"
    renewMinIntervalSec: "60"
  
  secrets:
    VAULT_APPROLE_SECRET_ID: "secret-id-here"
```

**KMS (AWS):**

```yaml
global:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
```

### Security Configuration

**Service Account with IRSA:**

```yaml
sisbajud:
  serviceAccount:
    create: true
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/executor-role"
    name: ""
```

**External Secret (ESO/Vault):**

```yaml
sisbajud:
  useExistingSecret: true
  existingSecretName: "executor-secrets"
```

**Pod Security Context:**

```yaml
sisbajud:
  podSecurityContext:
    fsGroup: 65532
    seccompProfile:
      type: RuntimeDefault
  
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    runAsGroup: 65532
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
```

### Environment Variables

The chart generates the following environment variables (non-exhaustive list of key variables):

| Variable | Source | Description |
|----------|--------|-------------|
| `ENVIRONMENT_NAME` | `sisbajud.app.environmentName` | Environment name (local/development/staging/production) |
| `DEPLOYMENT_MODE` | `sisbajud.app.deploymentMode` | Deployment mode (byoc/saas/local) |
| `DEFAULT_TENANT_ID` | `sisbajud.app.defaultTenantId` | Single-tenant ID (must be UUID) |
| `SERVER_ADDRESS` | `sisbajud.service.port` | HTTP API listen address |
| `MENSAGERIA_BASE_URL` | `sisbajud.mensageria.baseUrl` | Mensageria HTTPS endpoint |
| `MENSAGERIA_MTLS_ENABLED` | `sisbajud.mensageria.mtlsEnabled` | Enable mutual TLS |
| `MENSAGERIA_TLS_CA_FILE` | `sisbajud.mensageria.ca.*` | Path to Mensageria CA certificate |
| `MENSAGERIA_TLS_CLIENT_CERT_FILE` | `sisbajud.mensageria.tls.*` | Path to client certificate (mTLS) |
| `MENSAGERIA_TLS_CLIENT_KEY_FILE` | `sisbajud.mensageria.tls.*` | Path to client private key (mTLS) |
| `MENSAGERIA_CLIENT_ID` | `sisbajud.secrets.MENSAGERIA_CLIENT_ID` | M2M client ID |
| `MENSAGERIA_CLIENT_SECRET` | `sisbajud.secrets.MENSAGERIA_CLIENT_SECRET` | M2M client secret |
| `EXECUTOR_M2M_SUBJECT` | `sisbajud.executor.m2mSubject` | M2M token subject |
| `STREAMING_HUB_TENANT_ID` | `sisbajud.executor.streamingHubTenantId` | Streaming Hub tenant ID |
| `EXECUTOR_HEARTBEAT_EVERY` | `sisbajud.executor.heartbeatEvery` | Heartbeat interval |
| `EXECUTOR_HUMAN_DECISION_AFTER_BEATS` | `sisbajud.executor.humanDecisionAfterBeats` | Missed heartbeats threshold |
| `RESPONSE_DEADLINE_MARGIN` | `sisbajud.executor.responseDeadlineMargin` | Response deadline margin |
| `EXECUTOR_TRANSPORT` | `sisbajud.executor.transport` | Transport mode (webhook/sqs) |
| `EXECUTOR_HUB_WEBHOOK_ADDRESS` | `sisbajud.executor.webhook.port` | Webhook listener address |
| `EXECUTOR_HUB_WEBHOOK_PATH` | `sisbajud.executor.webhook.path` | Webhook endpoint path |
| `EXECUTOR_HUB_WEBHOOK_SECRET` | `sisbajud.secrets.EXECUTOR_HUB_WEBHOOK_SECRET` | Webhook HMAC secret |
| `EXECUTOR_SQS_QUEUE_URL` | `sisbajud.executor.sqs.queueUrl` | SQS queue URL |
| `EXECUTOR_SQS_REGION` | `sisbajud.executor.sqs.region` | AWS region for SQS |
| `LICENSE_KEY` | `sisbajud.secrets.LICENSE_KEY` | Lerian Studio license key |
| `ORGANIZATION_IDS` | `sisbajud.license.organizationIds` | License organization IDs |
| `POSTGRES_HOST` | `global.datastores.postgres.host` | PostgreSQL host |
| `POSTGRES_PORT` | `global.datastores.postgres.port` | PostgreSQL port |
| `POSTGRES_USER` | `global.datastores.postgres.user` | PostgreSQL user |
| `POSTGRES_NAME` | `global.datastores.postgres.name` | PostgreSQL database name |
| `POSTGRES_PASSWORD` | `sisbajud.secrets.POSTGRES_PASSWORD` | PostgreSQL password |
| `POSTGRES_SSLMODE` | `global.datastores.postgres.ssl` | PostgreSQL SSL mode |
| `REDIS_HOST` | `global.datastores.redis.host` | Redis/Valkey host |
| `REDIS_TLS` | `global.datastores.redis.tls` | Enable Redis TLS |
| `REDIS_PASSWORD` | `sisbajud.secrets.REDIS_PASSWORD` | Redis password |
| `KMS_PROVIDER` | `global.kms.vendor` | KMS provider (hashicorp-vault/aws) |
| `VAULT_ADDR` | `global.kms.vaultAddr` | Vault address |
| `VAULT
