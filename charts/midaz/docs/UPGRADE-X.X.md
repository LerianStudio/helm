# Helm Upgrade from v4.x to vX.X

## Topics

- **[Features](#features)**
  - [1. New Ledger service with combined functionality](#1-new-ledger-service-with-combined-functionality)
  - [2. Migration support with simultaneous service deployment](#2-migration-support-with-simultaneous-service-deployment)
  - [3. Ingress redirection to Ledger](#3-ingress-redirection-to-ledger)
- **[Deployment Scenarios](#deployment-scenarios)**
  - [Scenario 1: New installations with Ledger (recommended)](#scenario-1-new-installations-with-ledger-recommended)
  - [Scenario 2: Gradual migration from Onboarding/Transaction](#scenario-2-gradual-migration-from-onboardingtransaction)
  - [Scenario 3: Internal testing (all services)](#scenario-3-internal-testing-all-services)
  - [Scenario 4: Default mode (Onboarding + Transaction only)](#scenario-4-default-mode-onboarding--transaction-only)
- **[Configuration Reference](#configuration-reference)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. New Ledger service with combined functionality

A new `ledger` service is now available that combines the functionality of both onboarding and transaction modules into a single deployment. This is an **optional** feature - existing onboarding and transaction services continue to work as before.

**Key characteristics:**
- Single HTTP endpoint (port 3000 by default)
- Separate database configurations for each module (onboarding and transaction)
- Shared Redis and RabbitMQ connections
- New Balance Sync Worker for background processing

**New environment variables introduced:**
```yaml
# Balance Sync Worker
BALANCE_SYNC_WORKER_ENABLED: "false"
BALANCE_SYNC_MAX_WORKERS: "5"
```

### 2. Flexible deployment options

The chart now supports multiple deployment configurations to accommodate different use cases:

- **Default behavior (no changes required):** Existing installations continue to deploy onboarding and transaction services as before
- **Ledger mode:** Enable the unified ledger service for new or migrated installations
- **Test mode:** Run all three services simultaneously for internal testing purposes

For testing scenarios where you need all services running simultaneously, use the hidden `migration.allowAllServices` flag (not exposed in public `values.yaml`, defaults to `false`):

```yaml
migration:
  allowAllServices: true
```

### 3. Ingress redirection to Ledger

When ledger is enabled, the existing onboarding and transaction ingresses automatically redirect traffic to the ledger service. This ensures backward compatibility with existing DNS configurations and client integrations - your clients don't need to change their endpoints.

**How it works:**

The ingress templates use a helper function to determine the target service:

```
IF (ledger.enabled = true) AND (migration.allowAllServices ≠ true)
  THEN → ingress points to "midaz-ledger"
ELSE
  → ingress points to original service (midaz-onboarding or midaz-transaction)
```

**Ingress behavior by configuration:**

| `ledger.enabled` | `migration.allowAllServices` | `onboarding` ingress target | `transaction` ingress target |
|------------------|------------------------------|----------------------------|------------------------------|
| `false` | `false` (default) | `midaz-onboarding` | `midaz-transaction` |
| `true` | `false` (default) | `midaz-ledger` | `midaz-ledger` |
| `true` | `true` | `midaz-onboarding` | `midaz-transaction` |

**Important notes:**
- The ingress resource **names** remain unchanged (`midaz-onboarding`, `midaz-transaction`) to preserve DNS compatibility
- Only the **backend service** changes based on the configuration
- Ingresses are only created if their respective `*.ingress.enabled` flag is `true`

## Deployment Scenarios

### Scenario 1: New installations with Ledger (recommended)

For new deployments, enable only the ledger service:

```yaml
ledger:
  enabled: true

onboarding:
  enabled: false

transaction:
  enabled: false
```

**Resources deployed:**
- `midaz-ledger` deployment, service, configmap, secrets, serviceaccount
- `midaz-onboarding` ingress (pointing to ledger)
- `midaz-transaction` ingress (pointing to ledger)

### Scenario 2: Gradual migration from Onboarding/Transaction

To migrate gradually while maintaining the same ingress endpoints:

```yaml
ledger:
  enabled: true

onboarding:
  enabled: true  # Will be disabled automatically

transaction:
  enabled: true  # Will be disabled automatically
```

**Result:** Only ledger is deployed, but ingresses keep their original names for DNS compatibility.

### Scenario 3: Internal testing (all services)

To run all three services simultaneously for testing purposes:

```yaml
ledger:
  enabled: true

onboarding:
  enabled: true

transaction:
  enabled: true

migration:
  allowAllServices: true
```

**Resources deployed:**
- All ledger resources
- All onboarding resources (with original ingress pointing to onboarding)
- All transaction resources (with original ingress pointing to transaction)

> **Warning:** This mode is intended for internal testing only. Running all services simultaneously in production is not recommended.

### Scenario 4: Default mode (Onboarding + Transaction only)

This is the **default behavior** - no changes required for existing installations. The onboarding and transaction services continue to work as before:

```yaml
ledger:
  enabled: false  # default

onboarding:
  enabled: true   # default

transaction:
  enabled: true   # default
```

**Resources deployed:**
- All onboarding resources
- All transaction resources

> **Note:** Existing installations upgrading to this version will continue to work without any configuration changes.

> **Deprecation Notice:** The separate onboarding and transaction services are expected to become legacy in a future release. We recommend planning your migration to the unified ledger service.

## Configuration Reference

### Ledger service configuration

The ledger service uses module-specific database configurations:

```yaml
ledger:
  enabled: false
  name: "ledger"
  replicaCount: 1

  image:
    repository: lerianstudio/midaz-ledger
    tag: ""  # Defaults to Chart.AppVersion
    pullPolicy: IfNotPresent

  configmap:
    # App Configuration
    ENV_NAME: "production"
    LOG_LEVEL: "debug"
    SERVER_PORT: "3000"
    SERVER_ADDRESS: ":3000"

    # Auth Configuration
    PLUGIN_AUTH_ENABLED: "false"
    PLUGIN_AUTH_HOST: ""

    # Accounting Configuration
    ACCOUNT_TYPE_VALIDATION: ""
    TRANSACTION_ROUTE_VALIDATION: ""

    # PostgreSQL - Onboarding Module
    DB_ONBOARDING_HOST: "midaz-postgresql-primary.midaz.svc.cluster.local."
    DB_ONBOARDING_USER: "midaz"
    DB_ONBOARDING_NAME: "onboarding"
    DB_ONBOARDING_PORT: "5432"
    DB_ONBOARDING_SSLMODE: "disable"
    DB_ONBOARDING_REPLICA_HOST: "midaz-postgresql-replication.midaz.svc.cluster.local."
    # ... additional replica config

    # PostgreSQL - Transaction Module
    DB_TRANSACTION_HOST: "midaz-postgresql-primary.midaz.svc.cluster.local."
    DB_TRANSACTION_USER: "midaz"
    DB_TRANSACTION_NAME: "transaction"
    DB_TRANSACTION_PORT: "5432"
    DB_TRANSACTION_SSLMODE: "disable"
    DB_TRANSACTION_REPLICA_HOST: "midaz-postgresql-replication.midaz.svc.cluster.local."
    # ... additional replica config

    # MongoDB - Onboarding Module
    MONGO_ONBOARDING_HOST: "midaz-mongodb.midaz.svc.cluster.local."
    MONGO_ONBOARDING_NAME: "onboarding"
    MONGO_ONBOARDING_USER: "midaz"
    MONGO_ONBOARDING_PORT: "27017"

    # MongoDB - Transaction Module
    MONGO_TRANSACTION_HOST: "midaz-mongodb.midaz.svc.cluster.local."
    MONGO_TRANSACTION_NAME: "transaction"
    MONGO_TRANSACTION_USER: "midaz"
    MONGO_TRANSACTION_PORT: "27017"

    # Redis (shared)
    REDIS_HOST: "midaz-valkey-primary.midaz.svc.cluster.local.:6379"
    # ... additional Redis config

    # RabbitMQ (shared)
    RABBITMQ_HOST: "midaz-rabbitmq.midaz.svc.cluster.local."
    # ... additional RabbitMQ config

    # Balance Sync Worker (new)
    BALANCE_SYNC_WORKER_ENABLED: "false"
    BALANCE_SYNC_MAX_WORKERS: "5"

  secrets:
    # Onboarding Module
    DB_ONBOARDING_PASSWORD: "lerian"
    DB_ONBOARDING_REPLICA_PASSWORD: "lerian"
    MONGO_ONBOARDING_PASSWORD: "lerian"

    # Transaction Module
    DB_TRANSACTION_PASSWORD: "lerian"
    DB_TRANSACTION_REPLICA_PASSWORD: "lerian"
    MONGO_TRANSACTION_PASSWORD: "lerian"

    # Shared
    REDIS_PASSWORD: "lerian"
    RABBITMQ_DEFAULT_PASS: "lerian"
    RABBITMQ_CONSUMER_PASS: "lerian"
```

### External Secrets Support

The ledger service supports external secrets:

```yaml
ledger:
  useExistingSecret: true
  existingSecretName: <existing-secret-name>
```

**Note:** See the [ledger secrets template](https://github.com/LerianStudio/helm/blob/main/charts/midaz/templates/ledger/secrets.yaml) for the required secret keys.

### Deployment flags reference

| Flag | Default | Description |
|------|---------|-------------|
| `ledger.enabled` | `false` | Enables the unified ledger service |
| `onboarding.enabled` | `true` | Enables onboarding (auto-disabled when ledger is enabled) |
| `transaction.enabled` | `true` | Enables transaction (auto-disabled when ledger is enabled) |
| `migration.allowAllServices` | `false` | Hidden flag to allow all services simultaneously |

## Production recommendation

We do not recommend using the Midaz Helm chart's default dependencies (databases, cache, and message broker) in production environments. For production-grade deployments, follow our best practices to operate these dependencies with proper security, observability, backups, disaster recovery, and SLOs.

Reference: [Midaz Production Best Practices](https://docs.lerian.studio/en/midaz/midaz-production-best-practices)

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version X.X.X -n midaz
```
