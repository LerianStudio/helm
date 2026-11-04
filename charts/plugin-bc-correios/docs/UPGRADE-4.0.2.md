# Helm Upgrade from v4.0.1 to v4.0.2

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Database migrations Job](#1-database-migrations-job)
  - [2. Distributed HTTP rate limiting enabled by default](#2-distributed-http-rate-limiting-enabled-by-default)
  - [3. Valkey maxmemory-policy changed to noeviction](#3-valkey-maxmemory-policy-changed-to-noeviction)
- **[Configuration Changes](#configuration-changes)**
  - [New Environment Variables](#new-environment-variables)
  - [Migrations Job Settings](#migrations-job-settings)
  - [Valkey Configuration](#valkey-configuration)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that introduces automated database migrations, enables distributed HTTP rate limiting by default, and adjusts the Valkey cache eviction policy. The chart version moves from 4.0.1 to 4.0.2. The application version remains at 1.1.0. While the upgrade introduces new functionality, the default behavior is backward-compatible for most deployments. Operators using the bundled Valkey subchart should review the cache policy change.

## Features

### 1. Database migrations Job

Version 4.0.2 introduces an automated database migrations Job that runs on install and on each upgrade. Previously, the application was responsible for running migrations at startup. Now, the chart ships SQL migration files in the application image (`/migrations`) and applies them using the `migrate/migrate` CLI in a pre-deployment Job.

**How it works:**

- The Job runs before the application pods start
- It copies migration files from the application image to an emptyDir volume
- The `migrate` container connects to PostgreSQL and applies pending migrations
- The Job is recreated on each upgrade (the name includes a hash of the spec and connection parameters)
- ArgoCD hooks automatically prune old Job resources

**Default configuration:**

```yaml
bc-correios:
  migrations:
    enabled: true
    image:
      repository: migrate/migrate
      tag: v4.20.1@sha256:76cc2074cb6642631f34a898ced71e6aeaa743275a22e0c5be7a4d78c4daa743
      pullPolicy: IfNotPresent
    backoffLimit: 3
    activeDeadlineSeconds: 600
    resources:
      limits:
        cpu: 500m
        memory: 256Mi
      requests:
        cpu: 100m
        memory: 128Mi
```

**Operational impact:**

- The Job must complete successfully before the application pods are rolled
- If migrations fail, the upgrade will be blocked (the Job will retry up to `backoffLimit` times)
- The Job inherits the application's `nodeSelector`, `affinity`, `tolerations`, `hostAliases`, and `imagePullSecrets`
- The Job uses the same PostgreSQL connection settings as the application (from ConfigMap and Secret)

**Migration file location:**

The application image must include migration files at `/migrations`. The chart does not validate the presence of these files; if the directory is empty, the Job will succeed with no migrations applied.

**Disabling migrations:**

If you manage database migrations externally (e.g., via a separate CI/CD pipeline), you can disable the Job:

```yaml
bc-correios:
  migrations:
    enabled: false
```

> **Important:** The migrations Job requires a successful connection to PostgreSQL. If you use the bundled PostgreSQL subchart, the Job includes an init container that waits for the database to be ready. If you use an external database, ensure it is accessible before upgrading.

### 2. Distributed HTTP rate limiting enabled by default

Version 4.0.2 adds a new `RATE_LIMIT_ENABLED` environment variable to the ConfigMap, defaulting to `"true"`. This enables distributed HTTP rate limiting backed by Valkey (the bundled Redis-compatible cache).

**Before (v4.0.1):**

The application included rate limiting logic, but the feature was not explicitly enabled via configuration. The chart did not expose a toggle for this feature.

**After (v4.0.2):**

```yaml
bc-correios:
  configmap:
    RATE_LIMIT_ENABLED: "true"
```

**Operational impact:**

- The application will enforce HTTP rate limits using Valkey as the shared state store
- The existing `BC_CORREIO_RATE_LIMIT_PER_MINUTE` and `BC_CORREIO_RATE_LIMIT_PER_HOUR` settings (default: 50/min, 2700/hour) now take effect
- If Valkey is unavailable, rate limiting will fail open (requests will not be blocked)
- If you do not want distributed rate limiting, set `RATE_LIMIT_ENABLED: "false"` in your values file

**Disabling rate limiting:**

```yaml
bc-correios:
  configmap:
    RATE_LIMIT_ENABLED: "false"
```

> **Note:** The rate limiter requires a working Valkey connection. If you disable the bundled Valkey subchart (`valkey.enabled: false`), you must provide an external Valkey/Redis instance via `bc-correios.configmap.CACHE_HOST` and `bc-correios.secrets.CACHE_PASSWORD`, or disable rate limiting.

### 3. Valkey maxmemory-policy changed to noeviction

The bundled Valkey subchart now uses `--maxmemory-policy noeviction` instead of `allkeys-lru`. This change ensures that Valkey will not evict keys when the memory limit is reached, preventing data loss for rate limiting state.

**Before (v4.0.1):**

```yaml
valkey:
  master:
    extraFlags:
      - "--maxmemory 256mb"
      - "--maxmemory-policy allkeys-lru"
      - "--hz 100"
      - "--maxclients 1000"
```

**After (v4.0.2):**

```yaml
valkey:
  master:
    extraFlags:
      - "--maxmemory 256mb"
      - "--maxmemory-policy noeviction"
      - "--hz 100"
      - "--maxclients 1000"
```

**Operational impact:**

- When Valkey reaches the 256MB memory limit, it will reject new writes instead of evicting old keys
- This prevents rate limiting counters from being evicted prematurely
- If your workload generates more rate limiting state than 256MB can hold, you should increase the memory limit:

```yaml
valkey:
  master:
    extraFlags:
      - "--maxmemory 512mb"
      - "--maxmemory-policy noeviction"
      - "--hz 100"
      - "--maxclients 1000"
```

> **Warning:** If Valkey runs out of memory with `noeviction`, the application will not be able to record new rate limiting state, and requests may fail. Monitor Valkey memory usage and adjust the limit if necessary.

## Configuration Changes

### New Environment Variables

The following environment variable is added to the ConfigMap:

| Variable              | Default | Description |
|-----------------------|---------|-------------|
| `RATE_LIMIT_ENABLED`  | `"true"` | Enables distributed HTTP rate limiting backed by Valkey. Set to `"false"` to disable. |

### Migrations Job Settings

The following settings control the database migrations Job:

| Setting                                  | Default | Description |
|------------------------------------------|---------|-------------|
| `bc-correios.migrations.enabled`         | `true`  | Enables the migrations Job. Set to `false` to disable. |
| `bc-correios.migrations.image.repository` | `migrate/migrate` | Docker image repository for the migrate CLI. |
| `bc-correios.migrations.image.tag`       | `v4.20.1@sha256:76cc2074cb6642631f34a898ced71e6aeaa743275a22e0c5be7a4d78c4daa743` | Image tag (pinned with SHA256 digest). |
| `bc-correios.migrations.image.pullPolicy` | `IfNotPresent` | Image pull policy. |
| `bc-correios.migrations.backoffLimit`    | `3`     | Number of retries before marking the Job as failed. |
| `bc-correios.migrations.activeDeadlineSeconds` | `600` | Maximum time (in seconds) the Job is allowed to run. |
| `bc-correios.migrations.resources.limits.cpu` | `500m` | CPU limit for the migrate container. |
| `bc-correios.migrations.resources.limits.memory` | `256Mi` | Memory limit for the migrate container. |
| `bc-correios.migrations.resources.requests.cpu` | `100m` | CPU request for the migrate container. |
| `bc-correios.migrations.resources.requests.memory` | `128Mi` | Memory request for the migrate container. |

**Complete YAML example with all migrations settings:**

```yaml
bc-correios:
  migrations:
    enabled: true
    image:
      repository: migrate/migrate
      tag: v4.20.1@sha256:76cc2074cb6642631f34a898ced71e6aeaa743275a22e0c5be7a4d78c4daa743
      pullPolicy: IfNotPresent
    backoffLimit: 3
    activeDeadlineSeconds: 600
    resources:
      limits:
        cpu: 500m
        memory: 256Mi
      requests:
        cpu: 100m
        memory: 128Mi
```

### Valkey Configuration

The following Valkey configuration changes in this release:

| Setting                                  | v4.0.1         | v4.0.2       |
|------------------------------------------|----------------|--------------|
| `valkey.master.extraFlags[1]`            | `--maxmemory-policy allkeys-lru` | `--maxmemory-policy noeviction` |

## Migration Steps

This upgrade requires no mandatory manual migration steps for most deployments. The Helm upgrade will create the migrations Job, apply pending database migrations, and roll the application pods with the new configuration.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading))

2. Ensure you have a recent backup of your PostgreSQL database:

```bash
kubectl exec -n <namespace> <postgresql-pod> -- pg_dump -U <username> <database> > backup.sql
```

3. If you manage database migrations externally, disable the migrations Job in your values file:

```yaml
bc-correios:
  migrations:
    enabled: false
```

4. If you do not want distributed rate limiting, disable it in your values file:

```yaml
bc-correios:
  configmap:
    RATE_LIMIT_ENABLED: "false"
```

5. If you use the bundled Valkey subchart and your workload requires more than 256MB of cache memory, increase the limit:

```yaml
valkey:
  master:
    extraFlags:
      - "--maxmemory 512mb"
      - "--maxmemory-policy noeviction"
      - "--hz 100"
      - "--maxclients 1000"
```

6. Run the upgrade command during a maintenance window

7. Verify the migrations Job completed successfully:

```bash
kubectl get jobs -n <namespace> -l app.kubernetes.io/component=migrations
kubectl logs -n <namespace> -l app.kubernetes.io/component=migrations
```

8. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

9. Check application logs for any startup issues:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=bc-correios,app.kubernetes.io/instance=plugin-bc-correios --tail=50
```

10. Verify rate limiting is working (if enabled):

```bash
kubectl exec -n <namespace> -it <pod-name> -- wget -qO- http://localhost:9090/health/ready
```

> **Warning:** The migrations Job must complete successfully before the application pods are rolled. If migrations fail, the upgrade will be blocked. Check the Job logs for errors and resolve any database connectivity or migration issues before retrying.

> **Note:** The upgrade will trigger a rolling restart of the BC Correios pods. Depending on your replica count and readiness probe configuration, this may cause brief service interruptions. Plan the upgrade during a maintenance window if you run a single replica.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-bc-correios oci://registry-1.docker.io/lerianstudio/plugin-bc-correios-helm --version 4.0.2 -n plugin-bc-correios
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-bc-correios oci://registry-1.docker.io/lerianstudio/plugin-bc-correios-helm --version 4.0.2 -n plugin-bc-correios
```
