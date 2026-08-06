# Helm Upgrade from v1.0.0 to v1.1.0

## Topics

- **[Features](#features)**
  - [1. New correios component](#1-new-correios-component)
- **[Configuration Reference](#configuration-reference)**
  - [correios values structure](#correios-values-structure)
  - [correios configuration flags](#correios-configuration-flags)
  - [correios migrations configuration](#correios-migrations-configuration)
- **[Template Changes](#template-changes)**
  - [Migration job helper enhancement](#migration-job-helper-enhancement)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. New correios component

Version 1.1.0 introduces the **correios** component, a BC Correio regulatory mailbox service that handles BCB SOAP polling, attachment storage, search, audit trail, and transmission. This component is disabled by default and must be explicitly enabled.

**What it does:**

- Polls BCB SOAP endpoints for regulatory mailbox messages
- Stores attachments in S3-compatible object storage
- Provides search and audit trail capabilities
- Requires external Postgres, Valkey/Redis cache, RabbitMQ, and S3-compatible storage

**Key characteristics:**

- The Docker image name remains `plugin-bc-correios` (predates monorepo migration)
- Migrations are baked into the image at `/migrations` and run out-of-process
- The application reads `POSTGRES_NAME` instead of the standard `POSTGRES_DB` environment variable
- Default service port is 8080 with `/health` and `/readyz` endpoints

| Setting | v1.0.0 | v1.1.0 |
|---------|--------|--------|
| `correios` section | Not present | Added, disabled by default |
| `correios.enabled` | N/A | `false` |

> **Important:** The correios component is opt-in. Existing deployments will not be affected unless you explicitly set `correios.enabled: true`.

## Configuration Reference

### correios values structure

The correios component follows the standard br-sfn component pattern with deployment, service, ingress, autoscaling, and migrations support.

**Complete correios configuration block:**

```yaml
correios:
  enabled: false
  replicaCount: 1
  revisionHistoryLimit: 10
  image:
    repository: ghcr.io/lerianstudio/plugin-bc-correios
    tag: ""
    pullPolicy: IfNotPresent
  imagePullSecrets: []
  podAnnotations: {}
  deploymentUpdate:
    type: RollingUpdate
    maxSurge: 1
    maxUnavailable: 0
  service:
    type: ClusterIP
    port: 8080
  configmap: {}
  secrets: {}
  useExistingSecret: false
  existingSecretName: ""
  extraEnvVars: []
  extraVolumes: []
  extraVolumeMounts: []
  livenessProbe: {}
  readinessProbe: {}
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      memory: 512Mi
  autoscaling:
    enabled: false
    minReplicas: 2
    maxReplicas: 5
    targetCPUUtilizationPercentage: 80
  pdb:
    enabled: false
    minAvailable: 1
  ingress:
    enabled: false
    className: ""
    annotations: {}
    hosts: []
    tls: []
  nodeSelector: {}
  affinity: {}
  tolerations: []
  migrations:
    enabled: true
    sourcePath: /migrations
    table: ""
    postgres:
      host: ""
      port: ""
      user: ""
      database: ""
      sslMode: ""
    passwordSecret:
      name: ""
      key: POSTGRES_PASSWORD
    imagePullSecrets: []
    backoffLimit: 3
    activeDeadlineSeconds: 600
    ttlSecondsAfterFinished: 600
    resources: {}
```

### correios configuration flags

| Flag | Default | Description |
|------|---------|-------------|
| `correios.enabled` | `false` | Enable the correios component |
| `correios.replicaCount` | `1` | Number of correios pod replicas |
| `correios.service.port` | `8080` | Service port (matches Dockerfile EXPOSE) |
| `correios.resources.requests.cpu` | `100m` | CPU request per pod |
| `correios.resources.requests.memory` | `128Mi` | Memory request per pod |
| `correios.resources.limits.memory` | `512Mi` | Memory limit per pod |
| `correios.autoscaling.enabled` | `false` | Enable horizontal pod autoscaling |
| `correios.autoscaling.minReplicas` | `2` | Minimum replicas when autoscaling is enabled |
| `correios.autoscaling.maxReplicas` | `5` | Maximum replicas when autoscaling is enabled |
| `correios.autoscaling.targetCPUUtilizationPercentage` | `80` | Target CPU utilization for autoscaling |
| `correios.pdb.enabled` | `false` | Enable pod disruption budget |
| `correios.pdb.minAvailable` | `1` | Minimum available pods during disruptions |

### correios migrations configuration

The correios component includes database migration support with a special requirement: it reads the database name from the `POSTGRES_NAME` environment variable instead of the standard `POSTGRES_DB`.

| Flag | Default | Description |
|------|---------|-------------|
| `correios.migrations.enabled` | `true` | Run migrations as a pre-upgrade Helm hook Job |
| `correios.migrations.sourcePath` | `/migrations` | Path to migration files in the image |
| `correios.migrations.postgres.host` | `""` | Postgres host (required if migrations enabled) |
| `correios.migrations.postgres.port` | `""` | Postgres port (required if migrations enabled) |
| `correios.migrations.postgres.user` | `""` | Postgres user (required if migrations enabled) |
| `correios.migrations.postgres.database` | `""` | Postgres database name (falls back to `configmap.POSTGRES_NAME`) |
| `correios.migrations.postgres.sslMode` | `""` | Postgres SSL mode (falls back to `configmap.POSTGRES_SSLMODE`, defaults to `disable`) |
| `correios.migrations.passwordSecret.name` | `""` | Secret containing Postgres password (required) |
| `correios.migrations.passwordSecret.key` | `POSTGRES_PASSWORD` | Key in the secret containing the password |
| `correios.migrations.backoffLimit` | `3` | Number of retries for failed migration Job |
| `correios.migrations.activeDeadlineSeconds` | `600` | Maximum time for migration Job to complete |
| `correios.migrations.ttlSecondsAfterFinished` | `600` | Time to keep completed migration Job pods |

**Example: Enabling correios with migrations:**

```yaml
correios:
  enabled: true
  replicaCount: 2
  configmap:
    POSTGRES_NAME: correios_db
    POSTGRES_SSLMODE: require
  migrations:
    enabled: true
    postgres:
      host: postgres.database.svc.cluster.local
      port: "5432"
      user: correios_user
    passwordSecret:
      name: correios-postgres-secret
      key: POSTGRES_PASSWORD
```

> **Note:** The correios application reads `POSTGRES_NAME` from its ConfigMap, not `POSTGRES_DB`. Ensure you set `correios.configmap.POSTGRES_NAME` or `correios.migrations.postgres.database` for migrations to work correctly.

**Example: Using an existing secret for correios:**

```yaml
correios:
  enabled: true
  useExistingSecret: true
  existingSecretName: correios-secrets
  migrations:
    passwordSecret:
      name: correios-postgres-secret
      key: password
```

## Template Changes

### Migration job helper enhancement

The `br-sfn.componentMigrationJob` helper template has been enhanced to support components that use non-standard database configuration keys.

**Before (v1.0.0):**

```yaml
{{- define "br-sfn.componentMigrationJob" -}}
{{- $mig := .comp.migrations | default dict -}}
# ... (template logic)
{{- $pgDb := include "br-sfn.migrationPgValue" (dict "mig" $mig "key" "database" "cfg" $cfg "cfgKey" "POSTGRES_DB" "fallback" "") -}}
{{- if not $pgDb -}}
{{- fail (printf "br-sfn: %s migrations need a Postgres database — set %s.migrations.postgres.database or %s.configmap.POSTGRES_DB" .name .name .name) -}}
{{- end -}}
```

**After (v1.1.0):**

```yaml
{{- define "br-sfn.componentMigrationJob" -}}
{{- $mig := .comp.migrations | default dict -}}
# ... (template logic)
{{- $dbCfgKey := .dbCfgKey | default "POSTGRES_DB" -}}
{{- $pgDb := include "br-sfn.migrationPgValue" (dict "mig" $mig "key" "database" "cfg" $cfg "cfgKey" $dbCfgKey "fallback" "") -}}
{{- if not $pgDb -}}
{{- fail (printf "br-sfn: %s migrations need a Postgres database — set %s.migrations.postgres.database or %s.configmap.%s" .name .name .name $dbCfgKey) -}}
{{- end -}}
```

**What changed:**

- The helper now accepts an optional `dbCfgKey` parameter in the input dict
- If not provided, `dbCfgKey` defaults to `POSTGRES_DB` (preserving backward compatibility)
- The correios component passes `dbCfgKey: "POSTGRES_NAME"` to the helper

**Operational impact:**

- Existing components (desk, slcEdge, etc.) are unaffected — they continue using `POSTGRES_DB`
- The correios component correctly reads its database name from `POSTGRES_NAME`
- Error messages now dynamically reference the correct ConfigMap key

> **Note:** This change is fully backward compatible. No action is required for existing components.

## Preview changes before upgrading

```bash
helm diff upgrade br-sfn oci://registry-1.docker.io/lerianstudio/br-sfn-helm --version 1.1.0 -n br-sfn
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-sfn oci://registry-1.docker.io/lerianstudio/br-sfn-helm --version 1.1.0 -n br-sfn
```
