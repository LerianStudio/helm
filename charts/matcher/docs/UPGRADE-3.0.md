# Helm Upgrade from v2.x to v3.x

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Default passwords removed from values.yaml](#1-default-passwords-removed-from-valuesyaml)
  - [2. Security context hardened to non-root](#2-security-context-hardened-to-non-root)
  - [3. Infrastructure secret single-sourcing](#3-infrastructure-secret-single-sourcing)
  - [4. PostgreSQL subchart version bump](#4-postgresql-subchart-version-bump)
  - [5. Dynamic infrastructure hostnames](#5-dynamic-infrastructure-hostnames)
- **[Features](#features)**
  - [1. Single-source infrastructure secrets](#1-single-source-infrastructure-secrets)
  - [2. Release-aware infrastructure hostnames](#2-release-aware-infrastructure-hostnames)
  - [3. New ALLOW_INSECURE_TLS configuration flag](#3-new-allow_insecure_tls-configuration-flag)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review and set all required passwords](#step-1-review-and-set-all-required-passwords)
  - [Step 2: Verify security context compatibility](#step-2-verify-security-context-compatibility)
  - [Step 3: Review infrastructure hostname overrides](#step-3-review-infrastructure-hostname-overrides)
  - [Step 4: Validate RabbitMQ password handling](#step-4-validate-rabbitmq-password-handling)
- **[Deployment Scenarios](#deployment-scenarios)**
  - [Scenario 1: Internal PostgreSQL, Valkey, and RabbitMQ (default)](#scenario-1-internal-postgresql-valkey-and-rabbitmq-default)
  - [Scenario 2: External PostgreSQL with existing secret](#scenario-2-external-postgresql-with-existing-secret)
  - [Scenario 3: External infrastructure without existing secrets](#scenario-3-external-infrastructure-without-existing-secrets)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `matcher` chart upgrade from `2.2.0` to `3.0.0`. This is a **major** release that removes insecure default passwords, hardens the security context to run as non-root, and introduces single-source infrastructure secrets. The application image (`appVersion: 1.0.0`) is unchanged.

**All operators must review and set passwords explicitly before upgrading.** The chart will no longer deploy with default credentials.

## Breaking Changes

### 1. Default passwords removed from values.yaml

All default passwords (`"lerian"`, `"replicator_password"`, `"WCB00CfurKivfNH61hbxPaNg+xtyA/7RI6bEx5RMGvE="`) have been removed from `values.yaml`. The chart now requires operators to provide passwords explicitly via values overrides or existing secrets.

**Before (v2.2.0):**

```yaml
global:
  externalPostgresDefinitions:
    adminCredentials:
      password: "lerian"
    matcherCredentials:
      password: "lerian"
  externalRabbitmqDefinitions:
    adminCredentials:
      password: "lerian"
    matcherCredentials:
      password: "lerian"

matcher:
  secrets:
    POSTGRES_PASSWORD: "lerian"
    POSTGRES_REPLICA_PASSWORD: "lerian"
    REDIS_PASSWORD: "lerian"
    RABBITMQ_PASSWORD: "lerian"

postgresql:
  auth:
    postgresPassword: "lerian"
    password: "lerian"
    replicationPassword: "replicator_password"

valkey:
  auth:
    password: lerian

rabbitmq:
  auth:
    password:
      value: "lerian"
    erlangCookie:
      value: "WCB00CfurKivfNH61hbxPaNg+xtyA/7RI6bEx5RMGvE="
```

**After (v3.0.0):**

```yaml
global:
  externalPostgresDefinitions:
    adminCredentials:
      password: ""
    matcherCredentials:
      password: ""
  externalRabbitmqDefinitions:
    adminCredentials:
      password: ""
    matcherCredentials:
      password: ""

matcher:
  secrets:
    POSTGRES_PASSWORD: ""
    POSTGRES_REPLICA_PASSWORD: ""
    REDIS_PASSWORD: ""
    RABBITMQ_PASSWORD: ""

postgresql:
  auth:
    postgresPassword: ""
    password: ""
    replicationPassword: ""

valkey:
  auth:
    password: ""

rabbitmq:
  auth:
    password:
      value: ""
    erlangCookie:
      value: ""
```

> **Warning:** Upgrading without setting passwords will cause the deployment to fail. See [Migration Steps](#migration-steps) for instructions.

### 2. Security context hardened to non-root

The matcher container now runs as user `1000:1000` with a read-only root filesystem and restricted capabilities.

**Before (v2.2.0):**

```yaml
matcher:
  securityContext:
    runAsGroup: 0
    runAsUser: 0
    runAsNonRoot: false
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: false
```

**After (v3.0.0):**

```yaml
matcher:
  securityContext:
    runAsGroup: 1000
    runAsUser: 1000
    runAsNonRoot: true
    capabilities:
      drop:
        - ALL
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    seccompProfile:
      type: RuntimeDefault
```

> **Important:** If your matcher image writes to the filesystem at runtime (logs, temp files, etc.), you must either:
> - Update the image to write to `/tmp` or another writable `emptyDir` volume
> - Override `matcher.securityContext.readOnlyRootFilesystem: false` (not recommended)

### 3. Infrastructure secret single-sourcing

PostgreSQL and Valkey passwords are now sourced directly from the subchart-generated secrets when using internal infrastructure. The matcher chart no longer duplicates these passwords in its own secret unless you are using external infrastructure without an existing secret.

**Operational impact:**

- **Internal PostgreSQL/Valkey:** Passwords are read from `<release>-postgresql` and `<release>-valkey` secrets. The matcher secret will not contain `POSTGRES_PASSWORD`, `POSTGRES_REPLICA_PASSWORD`, or `REDIS_PASSWORD` keys.
- **External PostgreSQL/Valkey with existingSecret:** Passwords are read from the operator-provided secret. The matcher secret will not contain these keys.
- **External PostgreSQL/Valkey without existingSecret:** Operators must set `matcher.secrets.POSTGRES_PASSWORD`, `matcher.secrets.POSTGRES_REPLICA_PASSWORD`, and `matcher.secrets.REDIS_PASSWORD` explicitly. These will be stored in the matcher secret.

> **Note:** RabbitMQ password handling remains operator-provided in all scenarios (see [Known Limitation](#scenario-1-internal-postgresql-valkey-and-rabbitmq-default)).

### 4. PostgreSQL subchart version bump

The PostgreSQL subchart dependency has been updated from `16.3` to `16.3.5`. This is a patch release with no breaking changes, but operators should review the [Bitnami PostgreSQL 16.3.5 release notes](https://github.com/bitnami/charts/releases/tag/postgresql-16.3.5) for any relevant fixes.

### 5. Dynamic infrastructure hostnames

PostgreSQL, Valkey, and RabbitMQ hostnames in the ConfigMap are now dynamically generated based on the Helm release name and subchart configuration. Hard-coded hostnames like `matcher-postgresql-primary.matcher.svc.cluster.local.` have been replaced with template logic that respects `fullnameOverride` and `nameOverride`.

**Before (v2.2.0):**

```yaml
matcher:
  configmap:
    POSTGRES_HOST: "matcher-postgresql-primary.matcher.svc.cluster.local."
    POSTGRES_REPLICA_HOST: "matcher-postgresql-replication.matcher.svc.cluster.local."
    REDIS_HOST: "matcher-valkey-primary.matcher.svc.cluster.local.:6379"
```

**After (v3.0.0):**

```yaml
matcher:
  configmap:
    POSTGRES_HOST: ""
    POSTGRES_REPLICA_HOST: ""
    REDIS_HOST: ""
```

When left empty, the chart derives the hostname from the subchart's service name. For example, with release name `my-matcher`:

- `POSTGRES_HOST` → `my-matcher-postgresql-primary.my-matcher.svc.cluster.local.`
- `POSTGRES_REPLICA_HOST` → `my-matcher-postgresql-replication.my-matcher.svc.cluster.local.`
- `REDIS_HOST` → `my-matcher-valkey-primary.my-matcher.svc.cluster.local.:6379`

> **Important:** If you override subchart names with `postgresql.fullnameOverride` or `valkey.fullnameOverride`, the chart will respect those overrides. If you use external infrastructure, set these hostnames explicitly.

## Features

### 1. Single-source infrastructure secrets

PostgreSQL and Valkey passwords are now single-sourced from the subchart-generated secrets when using internal infrastructure. This eliminates password duplication and reduces the risk of configuration drift.

The matcher deployment now uses `valueFrom.secretKeyRef` to reference the subchart secrets directly:

```yaml
env:
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: my-matcher-postgresql
        key: password
  - name: POSTGRES_REPLICA_PASSWORD
    valueFrom:
      secretKeyRef:
        name: my-matcher-postgresql
        key: replication-password
  - name: REDIS_PASSWORD
    valueFrom:
      secretKeyRef:
        name: my-matcher-valkey
        key: valkey-password
```

The chart automatically detects whether to use the subchart secret or the matcher secret based on:

1. Whether the subchart is enabled and internal
2. Whether an `existingSecret` is configured in the subchart
3. Whether a password is set in `matcher.secrets.*`

See [Deployment Scenarios](#deployment-scenarios) for detailed examples.

### 2. Release-aware infrastructure hostnames

Infrastructure hostnames are now derived from the Helm release name and subchart configuration using the `common.names.dependency.fullname` helper (vendored from Bitnami common). This ensures hostnames remain correct when:

- The release name is not `matcher`
- Subchart `fullnameOverride` or `nameOverride` is set
- The chart is deployed multiple times in the same namespace

The chart falls back to these dynamic hostnames when `matcher.configmap.POSTGRES_HOST`, `matcher.configmap.POSTGRES_REPLICA_HOST`, and `matcher.configmap.REDIS_HOST` are empty strings.

### 3. New ALLOW_INSECURE_TLS configuration flag

A new environment variable `ALLOW_INSECURE_TLS` has been added to the ConfigMap with a default value of `"true"`.

| Flag | Default | Description |
|------|---------|-------------|
| `ALLOW_INSECURE_TLS` | `"true"` | Allows the matcher service to connect to infrastructure endpoints with self-signed or invalid TLS certificates. Set to `"false"` in production environments with valid certificates. |

**Configuration:**

```yaml
matcher:
  configmap:
    ALLOW_INSECURE_TLS: "false"
```

## Configuration Changes

| Setting | v2.2.0 | v3.0.0 |
|---------|--------|--------|
| `global.externalPostgresDefinitions.adminCredentials.password` | `"lerian"` | `""` (required) |
| `global.externalPostgresDefinitions.matcherCredentials.password` | `"lerian"` | `""` (required) |
| `global.externalRabbitmqDefinitions.adminCredentials.password` | `"lerian"` | `""` (required) |
| `global.externalRabbitmqDefinitions.matcherCredentials.password` | `"lerian"` | `""` (required) |
| `matcher.readinessProbe` | (not exposed) | `{}` (override any field) |
| `matcher.livenessProbe` | (not exposed) | `{}` (override any field) |
| `matcher.securityContext.runAsUser` | `0` | `1000` |
| `matcher.securityContext.runAsGroup` | `0` | `1000` |
| `matcher.securityContext.runAsNonRoot` | `false` | `true` |
| `matcher.securityContext.readOnlyRootFilesystem` | `false` | `true` |
| `matcher.securityContext.allowPrivilegeEscalation` | (not set) | `false` |
| `matcher.securityContext.seccompProfile.type` | (not set) | `RuntimeDefault` |
| `matcher.configmap.ALLOW_INSECURE_TLS` | (not set) | `"true"` |
| `matcher.configmap.POSTGRES_HOST` | `"matcher-postgresql-primary.matcher.svc.cluster.local."` | `""` (dynamic) |
| `matcher.configmap.POSTGRES_REPLICA_HOST` | `"matcher-postgresql-replication.matcher.svc.cluster.local."` | `""` (dynamic) |
| `matcher.configmap.REDIS_HOST` | `"matcher-valkey-primary.matcher.svc.cluster.local.:6379"` | `""` (dynamic) |
| `matcher.secrets.POSTGRES_PASSWORD` | `"lerian"` | `""` (single-sourced or required) |
| `matcher.secrets.POSTGRES_REPLICA_PASSWORD` | `"lerian"` | `""` (single-sourced or required) |
| `matcher.secrets.REDIS_PASSWORD` | `"lerian"` | `""` (single-sourced or required) |
| `matcher.secrets.RABBITMQ_PASSWORD` | `"lerian"` | `""` (required) |
| `postgresql.auth.postgresPassword` | `"lerian"` | `""` (required) |
| `postgresql.auth.password` | `"lerian"` | `""` (required) |
| `postgresql.auth.replicationPassword` | `"replicator_password"` | `""` (required) |
| `valkey.auth.password` | `lerian` | `""` (required) |
| `rabbitmq.auth.password.value` | `"lerian"` | `""` (required) |
| `rabbitmq.auth.erlangCookie.value` | `"WCB00CfurKivfNH61hbxPaNg+xtyA/7RI6bEx5RMGvE="` | `""` (required) |
| `postgresql` (subchart version) | `16.3` | `16.3.5` |

Files modified between `2.2.0` and `3.0.0`:

- `charts/matcher/Chart.yaml`
- `charts/matcher/values.yaml`
- `charts/matcher/templates/_helpers.tpl`
- `charts/matcher/templates/configmap.yaml`
- `charts/matcher/templates/deployment.yaml`
- `charts/matcher/templates/secrets.yaml`

## Migration Steps

### Step 1: Review and set all required passwords

Create a `values-override.yaml` file with all required passwords. **Do not reuse the old default passwords in production.**

```yaml
postgresql:
  auth:
    postgresPassword: "your-secure-postgres-admin-password"
    password: "your-secure-matcher-db-password"
    replicationPassword: "your-secure-replication-password"

valkey:
  auth:
    password: "your-secure-valkey-password"

rabbitmq:
  auth:
    password:
      value: "your-secure-rabbitmq-password"
    erlangCookie:
      value: "your-secure-erlang-cookie-base64"

matcher:
  secrets:
    RABBITMQ_PASSWORD: "your-secure-rabbitmq-password"
```

> **Note:** For internal PostgreSQL and Valkey, you only need to set passwords in the subchart sections (`postgresql.auth.*` and `valkey.auth.password`). The matcher will automatically reference those secrets. For external infrastructure, see [Deployment Scenarios](#deployment-scenarios).

If you are using external PostgreSQL or RabbitMQ bootstrap jobs, also set:

```yaml
global:
  externalPostgresDefinitions:
    adminCredentials:
      password: "your-external-postgres-admin-password"
    matcherCredentials:
      password: "your-external-postgres-matcher-password"
  externalRabbitmqDefinitions:
    adminCredentials:
      password: "your-external-rabbitmq-admin-password"
    matcherCredentials:
      password: "your-external-rabbitmq-matcher-password"
```

### Step 2: Verify security context compatibility

Check if your matcher image writes to the filesystem at runtime:

```bash
kubectl exec -n matcher deploy/matcher -- ls -la /
```

If you see writable directories outside `/tmp`, `/var/run`, or mounted volumes, you must either:

1. Update the image to write only to `/tmp` or mounted `emptyDir` volumes
2. Override the security context (not recommended):

```yaml
matcher:
  securityContext:
    readOnlyRootFilesystem: false
```

### Step 3: Review infrastructure hostname overrides

If you have overridden `postgresql.fullnameOverride`, `valkey.fullnameOverride`, or use external infrastructure, verify the generated hostnames:

```bash
helm template matcher oci://registry-1.docker.io/lerianstudio/matcher-helm --version 3.0.0 -n matcher -f values-override.yaml | grep -A5 "kind: ConfigMap"
```

If the hostnames are incorrect, set them explicitly:

```yaml
matcher:
  configmap:
    POSTGRES_HOST: "my-custom-postgres.default.svc.cluster.local."
    POSTGRES_REPLICA_HOST: "my-custom-postgres-replica.default.svc.cluster.local."
    REDIS_HOST: "my-custom-valkey.default.svc.cluster.local.:6379"
```

### Step 4: Validate RabbitMQ password handling

RabbitMQ passwords are **not** single-sourced in v3.0.0. You must set `matcher.secrets.RABBITMQ_PASSWORD` explicitly, even when using the internal RabbitMQ subchart:

```yaml
matcher:
  secrets:
    RABBITMQ_PASSWORD: "your-secure-rabbitmq-password"

rabbitmq:
  auth:
    password:
      value: "your-secure-rabbitmq-password"
```

> **Important:** The password must match in both places. This is a known limitation documented in the chart README.

## Deployment Scenarios

### Scenario 1: Internal PostgreSQL, Valkey, and RabbitMQ (default)

When using the bundled subcharts (default configuration), passwords are single-sourced from the subchart secrets for PostgreSQL and Valkey. RabbitMQ requires manual duplication.

**Configuration:**

```yaml
postgresql:
  enabled: true
  auth:
    postgresPassword: "your-secure-postgres-admin-password"
    password: "your-secure-matcher-db-password"
    replicationPassword: "your-secure-replication-password"

valkey:
  enabled: true
  auth:
    enabled: true
    password: "your-secure-valkey-password"

rabbitmq:
  enabled: true
  auth:
    password:
      value: "your-secure-rabbitmq-password"
    erlangCookie:
      value: "your-secure-erlang-cookie-base64"

matcher:
  secrets:
    RABBITMQ_PASSWORD: "your-secure-rabbitmq-password"
    # POSTGRES_PASSWORD, POSTGRES_REPLICA_PASSWORD, REDIS_PASSWORD are NOT set here
    # They are single-sourced from the subchart secrets
```

**Result:**

- `POSTGRES_PASSWORD` → read from `<release>-postgresql` secret, key `password`
- `POSTGRES_REPLICA_PASSWORD` → read from `<release>-postgresql` secret, key `replication-password`
- `REDIS_PASSWORD` → read from `<release>-valkey` secret, key `valkey-password`
- `RABBITMQ_PASSWORD` → read from `<release>-matcher` secret, key `RABBITMQ_PASSWORD`

> **Known Limitation:** RabbitMQ password must be set in both `rabbitmq.auth.password.value` and `matcher.secrets.RABBITMQ_PASSWORD`. This will be addressed in a future release.

### Scenario 2: External PostgreSQL with existing secret

When using external PostgreSQL with an operator-managed secret, configure the subchart to reference it:

**Configuration:**

```yaml
postgresql:
  enabled: true
  external: true
  auth:
    existingSecret: "my-postgres-secret"
    # Keys in the secret must be: password, replication-password

matcher:
  configmap:
    POSTGRES_HOST: "my-external-postgres.example.com"
    POSTGRES_REPLICA_HOST: "my-external-postgres-replica.example.com"
  secrets:
    # POSTGRES_PASSWORD and POSTGRES_REPLICA_PASSWORD are NOT set here
    # They are single-sourced from my-postgres-secret
```

**Result:**

- `POSTGRES_PASSWORD` → read from `my-postgres-secret`, key `password`
- `POSTGRES_REPLICA_PASSWORD` → read from `my-postgres-secret`, key `replication-password`

### Scenario 3: External infrastructure without existing secrets

When using external PostgreSQL, Valkey, or RabbitMQ without an existing secret, you must provide passwords in `matcher.secrets.*`:

**Configuration:**

```yaml
postgresql:
  enabled: false

valkey:
  enabled: false

rabbitmq:
  enabled: false

matcher:
  configmap:
    POSTGRES_HOST: "my-external-postgres.example.com"
    POSTGRES_REPLICA_HOST: "my-external-postgres-replica.example.com"
    REDIS_HOST: "my-external-valkey.example.com:6379"
  secrets:
    POSTGRES_PASSWORD: "your-external-postgres-password"
    POSTGRES_REPLICA_PASSWORD: "your-external-postgres-replica-password"
    REDIS_PASSWORD: "your-external-valkey-password"
    RABBITMQ_PASSWORD: "your-external-rabbitmq-password"
```

**Result:**

- All passwords are stored in the `<release>-matcher` secret
- The matcher deployment reads them from that secret

## Configuration Reference

### New fields in v3.0.0

```yaml
matcher:
  # Readiness probe configuration. All fields override chart defaults.
  readinessProbe:
    path: /readyz
    initialDelaySeconds: 5
    periodSeconds: 10
    timeoutSeconds: 5
    successThreshold: 1
    failureThreshold: 3

  # Liveness probe configuration. All fields override chart defaults.
  livenessProbe:
    path: /health
    initialDelaySeconds: 15
    periodSeconds: 20
    timeoutSeconds: 5
    successThreshold: 1
    failureThreshold: 3

  # Security context (hardened defaults)
  securityContext:
    runAsGroup: 1000
    runAsUser: 1000
    runAsNonRoot: true
    capabilities:
      drop:
        - ALL
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    seccompProfile:
      type: RuntimeDefault

  configmap:
    # New flag for TLS certificate validation
    ALLOW_INSECURE_TLS: "true"
    
    # Dynamic hostnames (leave empty to auto-generate)
    POSTGRES_HOST: ""
    POSTGRES_REPLICA_HOST: ""
    REDIS_HOST: ""

  secrets:
    # Single-sourced from subchart secrets when using internal infrastructure
    POSTGRES_PASSWORD: ""
    POSTGRES_REPLICA_PASSWORD: ""
    REDIS_PASSWORD: ""
    # Always required (not single-sourced)
    RABBITMQ_PASSWORD: ""
```

### Probe defaults

| Probe | Field | Default |
|-------|-------|---------|
| Liveness | `path` | `/health` |
| Liveness | `initialDelaySeconds` | `15` |
| Liveness | `periodSeconds` | `20` |
| Liveness | `timeoutSeconds` | `5` |
| Liveness | `successThreshold` | `1` |
| Liveness | `failureThreshold` | `3` |
| Readiness | `path` | `/readyz` |
| Readiness | `initialDelaySeconds` | `5` |
| Readiness | `periodSeconds` | `10` |
| Readiness | `timeoutSeconds` | `5` |
| Readiness | `successThreshold` | `1` |
| Readiness | `failureThreshold` | `3` |

### Security context defaults

| Field | Default |
|-------|---------|
| `runAsUser` | `1000` |
| `runAsGroup` | `1000` |
| `runAsNonRoot` | `true` |
| `readOnlyRootFilesystem` | `true` |
| `allowPrivilegeEscalation` | `false` |
| `seccompProfile.type` | `RuntimeDefault` |
| `capabilities.drop` | `["ALL"]` |

## Preview changes before upgrading

```bash
helm diff upgrade matcher oci://registry-1.docker.io/lerianstudio/matcher-helm --version 3.0.0 -n matcher -f values-override.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade matcher oci://registry-1.docker.io/lerianstudio/matcher-helm --version 3.0.0 -n matcher -f values-override.yaml
```

After upgrading, verify the rollout:

```bash
kubectl rollout status -n matcher deploy/matcher
kubectl get pods -n matcher
kubectl logs -n matcher -l app.kubernetes.io/name=matcher --tail=50
```
