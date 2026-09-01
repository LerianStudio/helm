# Helm Upgrade from v0.2.0 to v0.3.0

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Migrations Image Architecture Change](#1-migrations-image-architecture-change)
- **[Features](#features)**
  - [1. Dedicated Migrations Image](#1-dedicated-migrations-image)
  - [2. Application Version Bump](#2-application-version-bump)
- **[Configuration Reference](#configuration-reference)**
  - [Migrations Configuration](#migrations-configuration)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Pin Migrations Image Tag](#step-1-pin-migrations-image-tag)
  - [Step 2: Verify Image Availability](#step-2-verify-image-availability)
  - [Step 3: Review Migration Job Configuration](#step-3-review-migration-job-configuration)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This release introduces a **dedicated migrations image** to replace the previous extract-from-app-image approach, which never worked due to the app image being distroless. The chart now consumes `ghcr.io/lerianstudio/plugin-br-pix-jd-migrations`, a purpose-built image containing golang-migrate with the application's SQL schema baked in.

| Setting | v0.2.0 | v0.3.0 |
|---------|--------|--------|
| Chart Version | 0.2.0 | 0.3.0 |
| App Version | 1.12.0-beta.8 | 1.13.0-beta.4 |
| Migrations Image | Extracted from app image | Dedicated `plugin-br-pix-jd-migrations` image |
| Migrations Job Architecture | initContainer + emptyDir + generic migrate/migrate | Single container with baked-in schema |

## Breaking Changes

### 1. Migrations Image Architecture Change

**What changed:**

The migrations Job previously attempted to extract `/migrations` from the app image using an initContainer running `/bin/sh -c cp`, then applied the schema from a generic `migrate/migrate:v4.18.1` container over a shared emptyDir. This approach **never worked** because the app image is `gcr.io/distroless/static-debian12`, which ships no shell and no `cp` binary. The initContainer died with:

```
exec: "/bin/sh": stat /bin/sh: no such file or directory
```

The bug remained invisible because the only two production installs were **multi-tenant**, where the migrations Job is skipped entirely (the Tenant Manager owns per-tenant schema migrations).

**Why it matters:**

The first **single-tenant** install hit `ImagePullBackOff` immediately. The chart now consumes a dedicated migrations image (`ghcr.io/lerianstudio/plugin-br-pix-jd-migrations`) that contains golang-migrate with the SQL schema baked in, matching the pattern used by all sibling charts (`br-ccs`, `br-sisbajud`, `br-sfn`, `matcher`, `plugin-access-manager`, `plugin-br-bank-transfer`, `streaming-hub`).

**Migration impact:**

| Component | v0.2.0 | v0.3.0 |
|-----------|--------|--------|
| Migrations source | App image (`/migrations` extracted via shell) | Dedicated migrations image |
| initContainers | `wait-for-postgres` + `extract-migrations` | `wait-for-postgres` only (bundled DB) |
| Volumes | `emptyDir` for extracted schema | None |
| Image configuration | `migrations.migrateImage` | `migrations.image.repository` + `migrations.image.tag` |
| Password handling | In-shell DSN assembly | ENTRYPOINT with percent-encoding |

**Before (v0.2.0):**

```yaml
migrations:
  enabled: true
  migrateImage: migrate/migrate:v4.18.1
  sourcePath: /migrations
  table: ""
```

**After (v0.3.0):**

```yaml
migrations:
  enabled: true
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-migrations
    tag: ""  # MUST BE PINNED — see warning below
    pullPolicy: IfNotPresent
  table: ""
```

> **Warning:** The `migrations.image.tag` field **must be explicitly pinned**. The fallback to `.Chart.AppVersion` is a convention-compliant default, not a correct one: the release pipeline builds only the components a commit touched, so `api`, `worker`, and `migrations` tags legitimately **diverge**. No single tag names all three. As measured on 2026-08-27, `api` and `migrations` exist at `1.13.0-beta.4`, but `worker` stops at `1.13.0-beta.3`. An unpinned tag surfaces as `ImagePullBackOff` on a PreSync hook, which **blocks the entire sync**.

> **Important:** The chart will **fail the render** with a descriptive error if `migrations.image.repository` is empty:
> ```
> ERROR: migrations.image.repository is empty.
> An empty repository renders as ":<tag>", which the API server rejects with
> InvalidImageName — and this Job is a PreSync hook, so it blocks the whole sync.
> Set migrations.image.repository (default: ghcr.io/lerianstudio/plugin-br-pix-jd-migrations).
> ```

**Removed fields:**

| Field | v0.2.0 | v0.3.0 | Replacement |
|-------|--------|--------|-------------|
| `migrations.migrateImage` | `migrate/migrate:v4.18.1` | Removed | `migrations.image.repository` + `migrations.image.tag` |
| `migrations.sourcePath` | `/migrations` | Removed | Baked into migrations image |

**Template changes:**

The migrations Job template (`templates/common/migrations-job.yaml`) was rewritten to:

1. Remove the `extract-migrations` initContainer (no shell, no emptyDir)
2. Remove the `emptyDir` volume and its mount
3. Replace the generic `migrate/migrate` container with the dedicated migrations image
4. Remove the in-shell DSN assembly (`command: [/bin/sh, -c, migrate -database "postgres://..."]`)
5. Add `POSTGRES_MIGRATIONS_TABLE` environment variable (replaces URL query parameter)
6. Move the `wait-for-postgres` initContainer inside an `{{- if $bundled }}` guard (external databases don't need it)

**Before (v0.2.0):**

```yaml
initContainers:
  - name: wait-for-postgres
    # ...
  - name: extract-migrations
    image: {{ app image }}
    command:
      - /bin/sh
      - -c
      - cp -R /migrations/. /workdir/
    volumeMounts:
      - name: migrations
        mountPath: /workdir

containers:
  - name: migrations
    image: migrate/migrate:v4.18.1
    command:
      - /bin/sh
      - -c
      - >-
        migrate -path /migrations
        -database "postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@..."
        up
    volumeMounts:
      - name: migrations
        mountPath: /migrations
        readOnly: true

volumes:
  - name: migrations
    emptyDir: {}
```

**After (v0.3.0):**

```yaml
{{- if $bundled }}
initContainers:
  - name: wait-for-postgres
    # ...
{{- end }}

containers:
  - name: migrations
    image: {{ migrations image with tag }}
    # NO command: — ENTRYPOINT handles DSN assembly and percent-encoding
    env:
      - name: POSTGRES_HOST
        value: ...
      - name: POSTGRES_USER
        value: ...
      - name: POSTGRES_NAME
        value: ...
      - name: POSTGRES_SSLMODE
        value: ...
      {{- with $mig.table }}
      - name: POSTGRES_MIGRATIONS_TABLE
        value: {{ . | quote }}
      {{- end }}
      {{- include "plugin-br-pix-jd.migrationPasswordEnv" . | nindent 12 }}
    # NO volumeMounts
# NO volumes
```

**Operational impact:**

- The migrations Job now runs a **single container** with no initContainers (except `wait-for-postgres` for bundled PostgreSQL)
- Passwords containing `@ : / ? # & + %` or spaces are now supported via the image's ENTRYPOINT percent-encoding (the old in-shell DSN could not handle them)
- The `migrations.table` override is now passed as `POSTGRES_MIGRATIONS_TABLE` environment variable instead of a URL query parameter
- The Job will fail fast with `ImagePullBackOff` if `migrations.image.tag` is unpinned and the tag doesn't exist, rather than silently extracting an empty schema

## Features

### 1. Dedicated Migrations Image

The chart now consumes a **purpose-built migrations image** that contains golang-migrate with the application's SQL schema baked in. This matches the architecture of all sibling charts and eliminates the shell/emptyDir workaround that never functioned.

**Key characteristics:**

- Image: `ghcr.io/lerianstudio/plugin-br-pix-jd-migrations`
- Base: `migrate/migrate` with `migrations/` directory baked in
- ENTRYPOINT: Assembles DSN from `POSTGRES_*` environment variables and applies schema
- Password handling: Percent-encodes special characters (`@ : / ? # & + %` and spaces)
- No shell required: The image's ENTRYPOINT is the only executable

**Configuration:**

```yaml
migrations:
  enabled: true
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-migrations
    tag: "1.13.0-beta.4"  # MUST BE PINNED
    pullPolicy: IfNotPresent
  table: ""  # Optional x-migrations-table override
```

**Environment variables:**

The migrations container receives:

| Variable | Source | Purpose |
|----------|--------|---------|
| `POSTGRES_HOST` | `postgresql.host` or bundled subchart | Database hostname |
| `POSTGRES_USER` | `global.datastores.postgres.user` or chart default | Database user |
| `POSTGRES_NAME` | `api.configmap.POSTGRES_NAME` or chart default | Database name |
| `POSTGRES_SSLMODE` | `global.datastores.postgres.ssl` or chart default | SSL mode |
| `POSTGRES_PASSWORD` | `api.secrets.POSTGRES_PASSWORD` or bundled subchart | Database password (via secretKeyRef) |
| `POSTGRES_MIGRATIONS_TABLE` | `migrations.table` | Optional migrations table name override |

> **Note:** The `POSTGRES_MIGRATIONS_TABLE` variable is only set if `migrations.table` is non-empty. When omitted, golang-migrate uses its default table name (`schema_migrations`).

**Password security:**

The image's ENTRYPOINT percent-encodes the password before assembling the DSN, which means passwords can now contain characters that would break URL parsing:

- `@` (at sign)
- `:` (colon)
- `/` (slash)
- `?` (question mark)
- `#` (hash)
- `&` (ampersand)
- `+` (plus)
- `%` (percent)
- Spaces

The old in-shell DSN assembly (`postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@...`) could not handle these characters and would fail with connection errors or parse the DSN incorrectly.

### 2. Application Version Bump

The chart's `appVersion` has been updated from `1.12.0-beta.8` to `1.13.0-beta.4`, reflecting the release train the chart was cut against.

| Component | v0.2.0 | v0.3.0 |
|-----------|--------|--------|
| Chart `appVersion` | 1.12.0-beta.8 | 1.13.0-beta.4 |

> **Important:** The `appVersion` is a **fallback default** for `api.image.tag`, `worker.image.tag`, and `migrations.image.tag`. Production values should **always pin tags explicitly** rather than inheriting from `appVersion`, because the release pipeline builds only the components a commit touched. Tags legitimately diverge across components.

**Recommended configuration:**

```yaml
api:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd
    tag: "1.13.0-beta.4"  # Explicit pin

worker:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-worker
    tag: "1.13.0-beta.3"  # May differ from api

migrations:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-migrations
    tag: "1.13.0-beta.4"  # May differ from worker
```

## Configuration Reference

### Migrations Configuration

**New structure (v0.3.0):**

```yaml
migrations:
  # -- Enable the migrations Job (incompatible with multi-tenant mode)
  enabled: true
  
  # -- Kubernetes Job retry configuration
  backoffLimit: 3
  activeDeadlineSeconds: 600
  ttlSecondsAfterFinished: 600
  
  # -- Timeout for the wait-for-postgres initContainer (bundled DB only)
  waitTimeoutSeconds: 300
  
  # -- Annotations added to the Job
  annotations: {}
  
  # -- Resource requests/limits for the migrations container
  resources: {}
  
  # -- Image used to wait for the datastore to accept connections (bundled DB only)
  waitImage: busybox:1.37
  
  # -- Dedicated migrations image: golang-migrate with this app's SQL baked in
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-migrations
    # PIN THIS. The fallback to .Chart.AppVersion is a convention-compliant default,
    # not a correct one: the release pipeline builds only the components a commit
    # touched, so api, worker and migrations tags legitimately DIVERGE and no single
    # tag names all three.
    tag: ""
    pullPolicy: IfNotPresent
  
  # -- Optional x-migrations-table override, passed to the image as
  # POSTGRES_MIGRATIONS_TABLE; empty uses golang-migrate's default (schema_migrations)
  table: ""
```

**Field changes:**

| Field | v0.2.0 | v0.3.0 | Notes |
|-------|--------|--------|-------|
| `migrations.migrateImage` | `migrate/migrate:v4.18.1` | **Removed** | Replaced by `migrations.image.repository` |
| `migrations.sourcePath` | `/migrations` | **Removed** | Baked into migrations image |
| `migrations.image` | N/A | **New** | Structured image configuration |
| `migrations.image.repository` | N/A | **New** | Default: `ghcr.io/lerianstudio/plugin-br-pix-jd-migrations` |
| `migrations.image.tag` | N/A | **New** | **Must be pinned** — see warning above |
| `migrations.image.pullPolicy` | N/A | **New** | Default: `IfNotPresent` |
| `migrations.table` | `""` | `""` | Now passed as `POSTGRES_MIGRATIONS_TABLE` env var |

## Migration Steps

### Step 1: Pin Migrations Image Tag

Update your `values.yaml` to explicitly set the migrations image tag. **Do not rely on the `appVersion` fallback.**

**Add to your values:**

```yaml
migrations:
  enabled: true
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-migrations
    tag: "1.13.0-beta.4"
    pullPolicy: IfNotPresent
```

> **Warning:** If you leave `migrations.image.tag` empty, the chart will fall back to `.Chart.AppVersion` (`1.13.0-beta.4`). This may work for this release, but tags diverge across components in future releases. An unpinned tag that doesn't exist will cause `ImagePullBackOff` on a PreSync hook, **blocking the entire Helm sync**.

### Step 2: Verify Image Availability

Confirm the migrations image exists at your pinned tag before upgrading:

```bash
docker pull ghcr.io/lerianstudio/plugin-br-pix-jd-migrations:1.13.0-beta.4
```

If the image doesn't exist, check the [releases page](https://github.com/lerianstudio/plugin-br-pix-jd/releases) for available tags.

### Step 3: Review Migration Job Configuration

If you previously customized `migrations.migrateImage` or `migrations.sourcePath`, remove those fields and migrate to the new `migrations.image` structure.

**Before (v0.2.0):**

```yaml
migrations:
  enabled: true
  migrateImage: migrate/migrate:v4.18.1
  sourcePath: /migrations
  table: custom_migrations
```

**After (v0.3.0):**

```yaml
migrations:
  enabled: true
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-migrations
    tag: "1.13.0-beta.4"
    pullPolicy: IfNotPresent
  table: custom_migrations
```

> **Note:** The `migrations.table` field is unchanged in behavior — it still overrides the migrations table name — but is now passed to the image as the `POSTGRES_MIGRATIONS_TABLE` environment variable instead of a URL query parameter.

**Optional: Customize migrations image registry**

If you mirror images to a private registry:

```yaml
global:
  imageRegistry: registry.example.com

migrations:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-migrations
    tag: "1.13.0-beta.4"
```

The chart will prepend `global.imageRegistry` to the repository, rendering:

```
registry.example.com/ghcr.io/lerianstudio/plugin-br-pix-jd-migrations:1.13.0-beta.4
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.3.0 -n plugin-br-pix-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.3.0 -n plugin-br-pix-jd
```
