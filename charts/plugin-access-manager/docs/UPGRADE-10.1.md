<!-- {% raw %} -->
# Helm Upgrade from v10.0.3 to v10.1.0

# Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Skip RBAC Chain in Caradhras Migrations](#1-skip-rbac-chain-in-caradhras-migrations)
  - [2. Extra Environment Variables for Migrate Init Container](#2-extra-environment-variables-for-migrate-init-container)
- **[Configuration Reference](#configuration-reference)**
  - [New Caradhras Migration Settings](#new-caradhras-migration-settings)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Determine if You Need skipRBACChain](#step-1-determine-if-you-need-skiprbacchain)
  - [Step 2: Review Any Custom Migration Environment Variables](#step-2-review-any-custom-migration-environment-variables)
  - [Step 3: Check the Image Versions](#step-3-check-the-image-versions)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Overview

This is a minor release that increments the chart version from 10.0.3 to 10.1.0. The application version (appVersion) remains unchanged at `3.13.1`.

**What changed:**

This release introduces two new optional configuration fields under `caradhras.migrations`:

1. **`skipRBACChain`**: skips the RBAC migration chain (Lerian product permissions, roles and groups) for an install whose permissions arrive through RI manifests
2. **`extraEnvVars`**: passes extra environment variables to the migrate init container

**What this means for operators:**

Both fields are **opt-in**. If you do not set them, the rendered manifests differ from v10.0.3 only in the `helm.sh/chart` label, and no environment variable or image changes. The upgrade needs no configuration change. The pod templates of the auth, identity and caradhras Deployments carry the label `helm.sh/chart: plugin-access-manager-<version>`, so any chart version bump replaces the pods of all three, even when nothing else in the pod changes. I checked this by rendering the previous and the new chart version with `helm template`. Auth and identity render `maxSurge: 1` and `maxUnavailable: 1` by default (auth runs 3 replicas, identity 1), so identity can be briefly unavailable during the rollout when it runs a single replica.

> **Important:** `skipRBACChain` works only with `caradhras` and `caradhras-migrations` images that read `MIGRATIONS_SKIP_RBAC_CHAIN`. The default Caradhras image of this chart version is `1.5.1`. The chart does not state which Caradhras version first reads the variable, and it does not check the image. Confirm this with the Caradhras release notes before you enable the option. See [Step 3](#step-3-check-the-image-versions).

| Component | v10.0.3 | v10.1.0 |
|-----------|---------|---------|
| Chart version | 10.0.3 | 10.1.0 |
| App version | 3.13.1 | 3.13.1 |
| Caradhras image (default) | `1.5.1` | `1.5.1` (unchanged) |
| Caradhras migrations image (default) | `1.5.1` | `1.5.1` (unchanged) |

**Action required:**

None for standard deployments. Read the [Migration Steps](#migration-steps) if you run an install whose permissions arrive through RI manifests, or if you need to pass settings to the migration process.

# Features

### 1. Skip RBAC Chain in Caradhras Migrations

**What changed:**

A new boolean value, `caradhras.migrations.skipRBACChain`, skips the RBAC migration chain (`migrations-rbac/`: Lerian product permissions, roles and groups under organization `lerian`) in two places: the `migrate` init container, and the boot schema check of the `caradhras` container. The schema chain runs as usual.

**Why this matters:**

An install that takes its permissions through RI manifests does not need the RBAC chain. RI stands for Responsibility Inversion: each Lerian product declares its own permissions to Identity. The internal `cross` Caradhras install works this way, and it boots from an RBAC-free seed (`/cross/init_data.json`). On such an install:

- The RBAC chain adds the permissions, roles and groups of Lerian products under organization `lerian`, which this install does not take
- The boot schema check expects the RBAC chain at its head, and fails if the chain was never applied

Client installs that get their permissions from the RBAC migrations must keep the default (`false`).

**How it works:**

When enabled, the chart sets the environment variable `MIGRATIONS_SKIP_RBAC_CHAIN` to `"true"` on two containers:

1. The `migrate` init container, which applies the database migrations before Caradhras starts
2. The `caradhras` container, whose boot check then skips the same chain

Both containers must use a Caradhras image that reads the variable (see [Step 3](#step-3-check-the-image-versions)). With the skip on:

- The migrate init container applies the schema chain only. The control table `schema_migrations` is neither created nor written.
- Rows that an earlier run of the RBAC chain inserted stay where they are. On an install that already ran the chain, the chain stops at its current version, and RBAC migrations in later images never apply.
- A value that is not a boolean makes both containers fail to start.

The migrate init container logs the skip:

```
postgres-migrations: MIGRATIONS_SKIP_RBAC_CHAIN=true: skipping the rbac chain (migrations-rbac/, control table schema_migrations) by operator choice; it was not applied, and its RBAC-only safety checks stood down with it
```

The `caradhras` container logs it once at boot:

```
bootstrap: rbac chain check skipped by MIGRATIONS_SKIP_RBAC_CHAIN=true; only a dirty control table still fails boot
```

**Before (v10.0.3):**

The migrate init container and the caradhras container had no way to skip the RBAC migration chain. Both always applied and checked it.

**After (v10.1.0):**

```yaml
# In the migrate init container
- name: MIGRATIONS_SKIP_RBAC_CHAIN
  value: "true"

# In the caradhras container
- name: MIGRATIONS_SKIP_RBAC_CHAIN
  value: "true"
```

**Template changes:**

```yaml
# In the migrate init container
{{- with .Values.caradhras.migrations }}
{{- if .skipRBACChain }}
# Schema chain only; RBAC arrives via RI manifests. Needs an image that reads it.
- name: MIGRATIONS_SKIP_RBAC_CHAIN
  value: "true"
{{- end }}
{{- end }}

# In the caradhras container
{{- if (.Values.caradhras.migrations).skipRBACChain }}
# The boot schema check must skip the chain the migrate init container skipped,
# or any image with a newer rbac head crash-loops. Needs an image that reads it.
- name: MIGRATIONS_SKIP_RBAC_CHAIN
  value: "true"
{{- end }}
```

> **Important:** Use the same Caradhras version for `caradhras.image.tag` and `caradhras.migrations.image.tag`. If the migrate init container skips the chain but the `caradhras` image does not read the variable, the server still expects the RBAC chain at its head. It then crash-loops at boot with `schema compatibility check failed`.

> **Warning:** Enable `skipRBACChain` only on an install whose permissions arrive through RI manifests. On a standard install, the permissions stop coming from migrations, and users get authorization failures.

### 2. Extra Environment Variables for Migrate Init Container

**What changed:**

A new map, `caradhras.migrations.extraEnvVars`, passes extra environment variables to the migrate init container. You write them as `NAME: value` pairs. The chart renders each pair as a Kubernetes environment variable entry.

**Why this matters:**

The migration applier reads its settings from environment variables. This field lets you set them without a custom template. The applier variables that you are most likely to set are:

| Variable | Default | What it does |
|----------|---------|--------------|
| `MIGRATIONS_TIMEOUT_SEC` | `300` | Work budget in seconds. It starts once the applier holds the adoption lock. |
| `MIGRATIONS_LOCK_WAIT_SEC` | `900` | How long this applier queues behind another one before it stands down. |

Both are positive integers. The Caradhras runbook `docs/runbooks/db-adoption.md` documents them. Use `extraEnvVars` for a variable that your caradhras-migrations image reads. A variable that the image does not read has no effect.

**How it works:**

The chart renders each pair as a separate entry in the migrate init container. Values are converted to strings and quoted.

**Validation:**

- A name must match `^[-._a-zA-Z][-._a-zA-Z0-9]*$`, and a value must be a string, number or boolean. The chart schema rejects anything else when Helm validates your values.
- The chart refuses these names, because it sets them itself:
  - `POSTGRES_HOST`
  - `POSTGRES_PORT`
  - `POSTGRES_DB`
  - `POSTGRES_USER`
  - `POSTGRES_PASSWORD`
  - `POSTGRES_SSLMODE`
  - `MIGRATIONS_SKIP_RBAC_CHAIN`

A refused name fails the render with `caradhras.migrations.extraEnvVars.<NAME> duplicates a chart-owned env of the migrate init container; use the chart value instead`.

**Template changes:**

**Before (v10.0.3):**

The migrate init container received only the chart-managed variables for the database connection and the SSL mode.

**After (v10.1.0):**

```yaml
{{- range $name, $value := .extraEnvVars }}
{{- if has $name (list "POSTGRES_HOST" "POSTGRES_PORT" "POSTGRES_DB" "POSTGRES_USER" "POSTGRES_PASSWORD" "POSTGRES_SSLMODE" "MIGRATIONS_SKIP_RBAC_CHAIN") }}
{{- fail (printf "caradhras.migrations.extraEnvVars.%s duplicates a chart-owned env of the migrate init container; use the chart value instead" $name) }}
{{- end }}
- name: {{ $name | quote }}
  value: {{ $value | toString | quote }}
{{- end }}
```

**Example usage:**

```yaml
caradhras:
  migrations:
    extraEnvVars:
      MIGRATIONS_TIMEOUT_SEC: "600"
      MIGRATIONS_LOCK_WAIT_SEC: "1200"
```

This renders as:

```yaml
- name: "MIGRATIONS_TIMEOUT_SEC"
  value: "600"
- name: "MIGRATIONS_LOCK_WAIT_SEC"
  value: "1200"
```

> **Note:** Values in `extraEnvVars` are written in plain text into the pod spec. Do not put secrets in this field.

> **Note:** `extraEnvVars` reaches the migrate init container only. It does not reach the `caradhras` container.

> **Warning:** Leave `MIGRATIONS_ALLOW_RBAC_BASELINE_ON_POPULATED_DB` unset. It is a decision for one specific database, taken once. It is not a deployment setting. A chart value that carries it permanently disarms a safety gate for every later adoption.

# Configuration Reference

### New Caradhras Migration Settings

The following new fields are available under `caradhras.migrations`:

```yaml
caradhras:
  migrations:
    # Existing fields (image configuration)
    image:
      repository: ""
      tag: ""

    # New in v10.1.0
    skipRBACChain: false
    extraEnvVars: {}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `skipRBACChain` | boolean | `false` | Skip the RBAC migration chain (Lerian product permissions, roles and groups under organization `lerian`) in the migrate init container and in the caradhras boot schema check. For installs whose permissions arrive only through RI manifests, such as the internal `cross` install. Needs caradhras and caradhras-migrations images that read `MIGRATIONS_SKIP_RBAC_CHAIN` (see [Step 3](#step-3-check-the-image-versions)). |
| `extraEnvVars` | map | `{}` | Extra environment variables for the migrate init container only, as `NAME: value` pairs. Values are rendered as quoted strings. Names must match `^[-._a-zA-Z][-._a-zA-Z0-9]*$`. Chart-owned names (`POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_SSLMODE`, `MIGRATIONS_SKIP_RBAC_CHAIN`) are refused. Not for secrets: values are visible in the pod spec. |

**Environment variable set by skipRBACChain:**

When `skipRBACChain: true`, the chart adds this variable to both the migrate init container and the caradhras container:

| Variable | Value | Description |
|----------|-------|-------------|
| `MIGRATIONS_SKIP_RBAC_CHAIN` | `"true"` | The migration applier and the caradhras boot check skip the RBAC chain. Only the schema chain is applied and checked. |

# Migration Steps

### Step 1: Determine if You Need skipRBACChain

#### Option 1: Standard Deployment (No Action Required)

If your permissions, roles and groups come from the Caradhras RBAC migrations, **do not enable `skipRBACChain`**. The default (`skipRBACChain: false`) is correct.

**Action:** Upgrade with your existing values. No change is required.

#### Option 2: Permissions Through RI Manifests (Enable skipRBACChain)

If your Caradhras install takes no RBAC migrations and its permissions arrive through RI manifests, enable `skipRBACChain`. The internal `cross` Caradhras install is the case this option was built for.

**Action:** Set the option and use image tags that read it (see [Step 3](#step-3-check-the-image-versions)):

```yaml
caradhras:
  image:
    tag: "<caradhras tag that reads MIGRATIONS_SKIP_RBAC_CHAIN>"
  migrations:
    skipRBACChain: true
    image:
      tag: "<same tag for caradhras-migrations>"
```

> **Warning:** On a standard install, enabling `skipRBACChain` stops the RBAC migrations. Permissions are then missing or stale, and users get authorization failures.

### Step 2: Review Any Custom Migration Environment Variables

#### Option 1: No Custom Variables Needed (No Action Required)

If you do not need to change a migration applier setting, **do not set `extraEnvVars`**. The default empty map (`{}`) is correct.

**Action:** Upgrade with your existing values. No change is required.

#### Option 2: Add Custom Migration Variables

To change a migration applier setting, add it to `extraEnvVars`. For example, to give the migration a larger work budget:

```yaml
caradhras:
  migrations:
    extraEnvVars:
      MIGRATIONS_TIMEOUT_SEC: "600"
```

To change a chart-owned setting, use the chart's own values instead of `extraEnvVars`. The database connection comes from the `auth` database settings, for example `auth.configmap.DB_HOST` and `auth.configmap.DB_SSLMODE`. They feed both the migrate init container and the `caradhras` container. The RBAC chain flag has its own value, `caradhras.migrations.skipRBACChain`.

> **Warning:** Do not use `extraEnvVars` for secrets. The values are written in plain text into the pod spec, and anyone who can read the Kubernetes resources can see them.

### Step 3: Check the Image Versions

`skipRBACChain` needs both images to read `MIGRATIONS_SKIP_RBAC_CHAIN`:

| Image | Must read `MIGRATIONS_SKIP_RBAC_CHAIN` |
|-------|-----------------------------------------|
| `ghcr.io/lerianstudio/caradhras` | yes |
| `ghcr.io/lerianstudio/caradhras-migrations` | yes |

The chart default tag is `1.5.1` in this chart version. The chart does not say which Caradhras version first reads the variable, so it cannot tell you whether a given tag supports the option. An image that does not read the variable ignores it, and the chart does not warn you. Check the Caradhras release notes for the first version that reads `MIGRATIONS_SKIP_RBAC_CHAIN`, and use only a version that already exists as a published image.

**Check your current image tags:**

`helm get values` shows only the values you set, not the chart defaults. To see the images the release really runs, read the rendered manifest. The command selects the `image:` lines of the Caradhras Deployment by template path, so it also works when you use a custom image repository:

```bash
helm get manifest plugin-access-manager -n plugin-access-manager \
  | awk '/^# Source:/ {s=$3} s ~ /templates\/caradhras\/deployment\.yaml$/ && /^[[:space:]]+image:/'
```

The output has one line for the `wait-for-dependencies` init container, one for the `migrate` init container (`caradhras-migrations`) and one for the `caradhras` container. Read the tags of the last two.

To see which tag keys you set yourself, check these keys in `helm get values plugin-access-manager -n plugin-access-manager -o yaml`:

```yaml
caradhras:
  image:
    tag: "..."
  migrations:
    image:
      tag: "..."
auth:
  backend:
    image:
      tag: "..."
    migrations:
      image:
        tag: "..."
```

The chart resolves each tag in this order: the `caradhras.*` value, then the legacy `auth.backend.*` value, then the chart default. A legacy `auth.backend.*` tag therefore still counts when the `caradhras.*` tag is empty.

**Set both tags to the same version.** If the two images differ, and the migrate init container skips the chain while the server image does not read the variable, the server crash-loops at boot.

**Test in a non-production environment:**

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager \
  --version 10.1.0 \
  -n plugin-access-manager-staging \
  -f values.yaml
```

Verify that:

- The migrate init container completes successfully, and its log shows the skip line from [How it works](#1-skip-rbac-chain-in-caradhras-migrations)
- The caradhras pod starts without crash-looping, and its log shows the boot skip line
- Permissions are available from your RI manifests

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.1.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.1.0 -n plugin-access-manager
```
<!-- {% endraw %} -->
