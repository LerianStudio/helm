# Helm Upgrade from v0.3.0 to v0.4.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Bundled Valkey Subchart](#1-bundled-valkey-subchart)
  - [2. PostgreSQL Default Topology Change](#2-postgresql-default-topology-change)
  - [3. Pinned Bitnami Images by Digest](#3-pinned-bitnami-images-by-digest)
- **[Configuration Reference](#configuration-reference)**
  - [Valkey Configuration](#valkey-configuration)
  - [PostgreSQL Configuration Updates](#postgresql-configuration-updates)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review Current Database Topology](#step-1-review-current-database-topology)
  - [Step 2: Verify Redis Configuration](#step-2-verify-redis-configuration)
  - [Step 3: Update Values File](#step-3-update-values-file)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a **minor version bump** from v0.3.0 to v0.4.0, introducing an optional bundled Valkey subchart (disabled by default), changing the PostgreSQL subchart default from enabled to disabled, and pinning both datastore images by digest for reproducibility.

The upgrade is **non-breaking for all existing installations**: every consumer of this chart already sets `postgresql.enabled` explicitly, so the default flip is inert. The Valkey subchart is disabled by default and requires explicit opt-in.

| Setting | v0.3.0 | v0.4.0 |
|---------|--------|--------|
| Chart Version | 0.3.0 | 0.4.0 |
| PostgreSQL default | `enabled: true` | `enabled: false` |
| Valkey subchart | Not present | Available (disabled by default) |
| Bitnami images | Tag-based | Digest-pinned |

## Features

### 1. Bundled Valkey Subchart

The chart now includes an **optional bundled Valkey** (Redis-compatible) via the Bitnami subchart (version 2.4.7), mirroring the PostgreSQL topology pattern. Valkey is **disabled by default** and requires explicit opt-in.

**Why this matters:**

- Operators can deploy a complete stack (app + PostgreSQL + Valkey) without provisioning external Redis infrastructure
- The rate limiter is fail-closed by default, so an unreachable Redis rejects traffic rather than degrading — a bundled Valkey eliminates this external dependency for development and testing environments
- Multi-tenant credential resolution from AWS Secrets Manager requires Redis for caching; the bundled option simplifies non-production deployments

**Topology options:**

#### Option 1: External Redis (default, unchanged behavior)

```yaml
valkey:
  enabled: false
  external: true

api:
  configmap:
    REDIS_HOST: redis.example.com:6379
  secrets:
    REDIS_PASSWORD: "your-redis-password"
```

This is the **default configuration** and matches all existing v0.3.0 deployments. No changes required.

#### Option 2: Bundled Valkey (new)

```yaml
valkey:
  enabled: true
  external: false

# REDIS_HOST is derived automatically from the Valkey Service
# REDIS_PASSWORD is sourced from the Valkey subchart's Secret
```

When `valkey.enabled=true` and `valkey.external=false`:

- The chart renders a Valkey StatefulSet in the same namespace
- `REDIS_HOST` is automatically set to the fully-qualified Service name: `<release>-valkey-primary.<namespace>.svc.cluster.local:6379`
- `REDIS_PASSWORD` is read from the Valkey subchart's Secret via `secretKeyRef` (key: `valkey-password`)
- The password is **not duplicated** into this chart's Secret — the same pattern used for bundled PostgreSQL

**Mutual exclusivity:**

> **Important:** Setting `valkey.enabled=true` together with `valkey.external=true` is contradictory and will **fail the render** with an error. The subchart condition is `valkey.enabled`, so the StatefulSet would be created while the app connects to a different server.

**Image pinning:**

The bundled Valkey uses a **digest-pinned image** from `bitnamisecure/valkey` (the public `bitnami/valkey` registry lost free tags). The digest is fixed to ensure reproducible deployments:

```yaml
valkey:
  global:
    security:
      allowInsecureImages: true
  image:
    repository: bitnamisecure/valkey
    tag: ""
    digest: "sha256:5d43ca8bb57aa263ef78d1684dbf1e4b4f63844727eafdd5ea2b0e102a25b141"
  auth:
    enabled: true
```

> **Note:** `allowInsecureImages: true` is required because the Bitnami subchart validates the repository name, and `bitnamisecure` does not match the expected `bitnami` prefix. This is a subchart requirement, not a security bypass.

**Credential sourcing:**

| Path | REDIS_HOST source | REDIS_PASSWORD source |
|------|-------------------|----------------------|
| External (default) | `api.configmap.REDIS_HOST` (required) | `api.secrets.REDIS_PASSWORD` (optional) |
| Bundled | Derived from Valkey Service | Valkey subchart Secret (`valkey-password` key) |

**Template changes:**

The chart adds three new helpers in `templates/_helpers.tpl`:

1. **`plugin-br-pix-jd.valkeyRenders`** — returns `true` if the Valkey subchart will render a Service in this release (mirrors `postgresRenders`)
2. **`plugin-br-pix-jd.redisHostDefault`** — returns the fully-qualified Valkey Service authority when bundled, empty string otherwise
3. **`plugin-br-pix-jd.redisPasswordEnv`** — emits a discrete `REDIS_PASSWORD` env var with `secretKeyRef` to the Valkey subchart's Secret when bundled, nothing otherwise

**Before (v0.3.0):**

```yaml
env:
  - name: REDIS_HOST
    valueFrom:
      configMapKeyRef:
        name: plugin-br-pix-jd
        key: REDIS_HOST
envFrom:
  - secretRef:
      name: plugin-br-pix-jd  # Contains REDIS_PASSWORD
```

**After (v0.4.0, bundled path):**

```yaml
env:
  - name: REDIS_HOST
    valueFrom:
      configMapKeyRef:
        name: plugin-br-pix-jd
        key: REDIS_HOST  # Value derived from Valkey Service
  - name: REDIS_PASSWORD
    valueFrom:
      secretKeyRef:
        name: plugin-br-pix-jd-valkey
        key: valkey-password
envFrom:
  - secretRef:
      name: plugin-br-pix-jd  # Does NOT contain REDIS_PASSWORD
```

**Operational impact:**

- On the **external path** (default), the rendered manifests are **byte-identical** to v0.3.0 — no changes to ConfigMap, Secret, or Deployment
- On the **bundled path**, `REDIS_PASSWORD` is removed from this chart's Secret and sourced from the Valkey subchart's Secret instead, preventing credential duplication (same pattern as bundled PostgreSQL)

### 2. PostgreSQL Default Topology Change

The PostgreSQL subchart default has changed from **enabled by default** to **disabled by default**, aligning with the `go-boilerplate-ddd-helm` reference chart and removing the "surprise StatefulSet" for new installs.

| Setting | v0.3.0 | v0.4.0 |
|---------|--------|--------|
| `postgresql.enabled` | `true` | `false` |
| `postgresql.external` | `false` | `true` |

**Why this matters:**

- In v0.3.0, any `helm install` without explicit `postgresql.enabled=false` would provision a StatefulSet, even if the operator intended to use an external database
- All six existing consumers of this chart already set `postgresql.enabled` explicitly (five `false`, one `true`), so **this change is inert for all of them**
- New installs now require explicit opt-in to the bundled database, matching the pattern of the Valkey subchart

**Migration impact:**

> **Important:** If your existing v0.3.0 deployment **relies on the implicit `postgresql.enabled=true` default** (i.e., you did not set it explicitly in your values), you must now set it explicitly to preserve the bundled database:

```yaml
postgresql:
  enabled: true
  external: false
```

**However**, this scenario is unlikely: the v0.1.0 upgrade guide documented that the bundled PostgreSQL was enabled by default, and operators following that guide would have made an explicit choice. If you are unsure, check your current values:

```bash
helm get values plugin-br-pix-jd -n plugin-br-pix-jd
```

If `postgresql.enabled` is not present in the output, add it to your values file before upgrading.

### 3. Pinned Bitnami Images by Digest

Both the PostgreSQL and Valkey subcharts now use **digest-pinned images** from `bitnamisecure` instead of tag-based images from the public `bitnami` registry, which lost free tag access.

**PostgreSQL image changes:**

| Setting | v0.3.0 | v0.4.0 |
|---------|--------|--------|
| Repository | `bitnami/postgresql` (implicit) | `bitnamisecure/postgresql` |
| Tag | `17.2.0-debian-12-r5` (subchart default) | `""` (digest-only) |
| Digest | None | `sha256:db2312d9b243afa8c3b3f5496e478d17d0dff9791d06f3b93b9567abd86ae92f` |
| PostgreSQL version | 17.2 | 18.4 |

**Why this matters:**

- The public `bitnami/postgresql` registry no longer serves versioned tags without authentication
- The `bitnamisecure` mirror publishes only `latest` (no version tags), so digest pinning is the only way to ensure reproducible deployments
- The pinned digest is **PostgreSQL 18.4**, a major version ahead of the managed databases in other environments (17.x)

**Compatibility verification:**

The chart maintainers verified that all 29 migrations apply successfully against PostgreSQL 18.4, producing identical schema (23 tables, 55 systemplane keys, `dirty=false`) as PostgreSQL 17.

**PostgreSQL 15+ schema permissions:**

> **Warning:** In PostgreSQL 15+, the `public` schema is not writable by non-owners by default. In the digest-pinned image, the database owner does **not** inherit `CREATE` privilege on `public` (`has_schema_privilege=false`). The migrations Job requires `CREATE`, so the bundled path now includes an `initdb` script to grant it:

```yaml
postgresql:
  primary:
    initdb:
      scripts:
        grant-create.sql: |
          GRANT CREATE ON SCHEMA public TO "plugin-br-pix-jd";
```

This script is **not included in the chart by default** — operators using the bundled PostgreSQL must add it to their values file. Without it, the Postgres StatefulSet will start successfully, but the migrations Job will fail with a permission error.

**Valkey image:**

```yaml
valkey:
  image:
    repository: bitnamisecure/valkey
    tag: ""
    digest: "sha256:5d43ca8bb57aa263ef78d1684dbf1e4b4f63844727eafdd5ea2b0e102a25b141"
```

**allowInsecureImages requirement:**

Both subcharts require `global.security.allowInsecureImages: true` because the Bitnami subchart validates the repository name and rejects `bitnamisecure` as non-standard:

```yaml
postgresql:
  global:
    security:
      allowInsecureImages: true

valkey:
  global:
    security:
      allowInsecureImages: true
```

> **Note:** This is a subchart validation bypass, not a security risk. The images are pulled over HTTPS and verified by digest.

## Configuration Reference

### Valkey Configuration

```yaml
valkey:
  # -- Render the bundled Valkey subchart. false = use external Redis
  enabled: false
  
  # -- Declare that Valkey is external to this release. Combining external=true
  # with enabled=true is contradictory and will fail the render.
  external: true
  
  # -- Required for bitnamisecure repository
  global:
    security:
      allowInsecureImages: true
  
  # -- Digest-pinned image (bitnami/valkey lost free tags)
  image:
    repository: bitnamisecure/valkey
    tag: ""
    digest: "sha256:5d43ca8bb57aa263ef78d1684dbf1e4b4f63844727eafdd5ea2b0e102a25b141"
  
  # -- Enable authentication (password required)
  auth:
    enabled: true
```

**New configuration flags:**

| Flag | Default | Description |
|------|---------|-------------|
| `valkey.enabled` | `false` | Render the Valkey StatefulSet in this release |
| `valkey.external` | `true` | Declare that Valkey is external (must be `false` if `enabled=true`) |
| `valkey.auth.enabled` | `true` | Require password authentication for Valkey |

### PostgreSQL Configuration Updates

```yaml
postgresql:
  # -- Bundle the Bitnami postgresql subchart. DISABLED by default (changed from v0.3.0)
  enabled: false
  
  # -- Treat the datastore as external (changed from v0.3.0)
  external: true
  
  # -- Required for bitnamisecure repository
  global:
    security:
      allowInsecureImages: true
  
  # -- Digest-pinned image (PostgreSQL 18.4)
  image:
    repository: bitnamisecure/postgresql
    tag: ""
    digest: "sha256:db2312d9b243afa8c3b3f5496e478d17d0dff9791d06f3b93b9567abd86ae92f"
  
  # -- Required for PostgreSQL 15+ schema permissions
  primary:
    initdb:
      scripts:
        grant-create.sql: |
          GRANT CREATE ON SCHEMA public TO "plugin-br-pix-jd";
  
  auth:
    username: "plugin-br-pix-jd"
    database: "plugin-br-pix-jd"
  
  primary:
    persistence:
      enabled: true
      size: 8Gi
```

**Changed defaults:**

| Setting | v0.3.0 | v0.4.0 |
|---------|--------|--------|
| `postgresql.enabled` | `true` | `false` |
| `postgresql.external` | `false` | `true` |
| `postgresql.image.repository` | `bitnami/postgresql` (implicit) | `bitnamisecure/postgresql` |
| `postgresql.image.digest` | None | `sha256:db2312d9b243afa8c3b3f5496e478d17d0dff9791d06f3b93b9567abd86ae92f` |

## Migration Steps

### Step 1: Review Current Database Topology

Check your current PostgreSQL configuration:

```bash
helm get values plugin-br-pix-jd -n plugin-br-pix-jd | grep -A5 postgresql
```

**If `postgresql.enabled` is not present in the output:**

You were relying on the implicit `enabled: true` default. Add it explicitly to preserve the bundled database:

```yaml
postgresql:
  enabled: true
  external: false
```

**If `postgresql.enabled: true` is present:**

No action required. Your explicit setting will override the new default.

**If `postgresql.enabled: false` is present:**

No action required. Your configuration already uses an external database.

### Step 2: Verify Redis Configuration

Check your current Redis configuration:

```bash
helm get values plugin-br-pix-jd -n plugin-br-pix-jd | grep -A5 REDIS
```

**If you are using an external Redis:**

No action required. The default `valkey.enabled=false` matches your topology.

**If you want to migrate to bundled Valkey:**

1. Remove `api.configmap.REDIS_HOST` and `api.secrets.REDIS_PASSWORD` from your values
2. Enable the Valkey subchart:

```yaml
valkey:
  enabled: true
  external: false
```

> **Warning:** Switching from external Redis to bundled Valkey will **lose all cached data** (rate limiter state, multi-tenant credential cache). Plan the migration during a maintenance window.

### Step 3: Update Values File

**For bundled PostgreSQL users (if not already explicit):**

```yaml
postgresql:
  enabled: true
  external: false
  global:
    security:
      allowInsecureImages: true
  image:
    repository: bitnamisecure/postgresql
    tag: ""
    digest: "sha256:db2312d9b243afa8c3b3f5496e478d17d0dff9791d06f3b93b9567abd86ae92f"
  primary:
    initdb:
      scripts:
        grant-create.sql: |
          GRANT CREATE ON SCHEMA public TO "plugin-br-pix-jd";
```

**For external Redis users (no changes required):**

```yaml
valkey:
  enabled: false
  external: true

api:
  configmap:
    REDIS_HOST: redis.example.com:6379
  secrets:
    REDIS_PASSWORD: "your-redis-password"
```

**For bundled Valkey users (new opt-in):**

```yaml
valkey:
  enabled: true
  external: false
  global:
    security:
      allowInsecureImages: true
  image:
    repository: bitnamisecure/valkey
    tag: ""
    digest: "sha256:5d43ca8bb57aa263ef78d1684dbf1e4b4f63844727eafdd5ea2b0e102a25b141"
  auth:
    enabled: true
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.4.0 -n plugin-br-pix-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.4.0 -n plugin-br-pix-jd
```
