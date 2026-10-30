<!-- {% raw %} -->
# Helm Upgrade from v0.5.6 to v0.5.7

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Worker Image Now Required](#1-worker-image-now-required)
  - [2. LICENSE_KEY Now Required for API](#2-license_key-now-required-for-api)
  - [3. SYSTEMPLANE_ENABLED Default Changed](#3-systemplane_enabled-default-changed)
- **[Features](#features)**
  - [1. Dedicated Worker Image](#1-dedicated-worker-image)
  - [2. New Environment Variables](#2-new-environment-variables)
  - [3. ORGANIZATION_IDS Default Value](#3-organization_ids-default-value)
  - [4. Streaming CloudEvents Source Format](#4-streaming-cloudevents-source-format)
  - [5. Removed Transaction Limit Period Variables](#5-removed-transaction-limit-period-variables)
  - [6. JD_USE_SERVICE_SEGMENTS Multi-Tenant Suppression](#6-jd_use_service_segments-multi-tenant-suppression)
  - [7. QR Code Configuration for Worker](#7-qr-code-configuration-for-worker)
  - [8. Migrations Job Connection Resolution](#8-migrations-job-connection-resolution)
  - [9. OTEL_RESOURCE_SERVICE_VERSION Removed](#9-otel_resource_service_version-removed)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Update Worker Image Configuration](#step-1-update-worker-image-configuration)
  - [Step 2: Set LICENSE_KEY in API Secrets](#step-2-set-license_key-in-api-secrets)
  - [Step 3: Review SYSTEMPLANE_ENABLED Setting](#step-3-review-systemplane_enabled-setting)
  - [Step 4: Add New Environment Variables (Optional)](#step-4-add-new-environment-variables-optional)
  - [Step 5: Update Streaming CloudEvents Source (If Used)](#step-5-update-streaming-cloudevents-source-if-used)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a **patch release** of the `plugin-br-pix-jd` chart (v0.5.7), introducing breaking changes to the worker image configuration and license key requirements. The chart now ships two components from **separate images**: the HTTP API (`plugin-br-pix-jd`) and the cron worker (`plugin-br-pix-jd-worker`), replacing the previous single-image architecture where both binaries lived in one image.

| Setting | v0.5.6 | v0.5.7 |
|---------|---------|---------|
| Chart version | 0.5.6 | 0.5.7 |
| App version | 1.3.0 | 1.3.0 |
| Worker image required | No (inherited from API) | Yes (dedicated image) |
| LICENSE_KEY required for API | No (worker only) | Yes (both components) |
| SYSTEMPLANE_ENABLED default (bundled Postgres) | `false` | `false` |
| SYSTEMPLANE_ENABLED default (external Postgres) | `false` | `true` |

## Breaking Changes

### 1. Worker Image Now Required

**What changed:**

The chart no longer supports the single-image architecture where `worker.image.repository` could be left empty to inherit the API image. The worker now **requires** its own dedicated image.

**Before (v0.5.6):**

```yaml
worker:
  enabled: true
  image:
    repository: ""  # Empty = inherit from api.image.repository
    tag: ""
```

The chart would override the entrypoint to `/worker` when `worker.image.repository` was empty.

**After (v0.5.7):**

```yaml
worker:
  enabled: true
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-worker
    tag: "1.3.0"
```

The worker image has its own `ENTRYPOINT ["/worker"]` and the chart no longer overrides the command.

> **Warning:** If you leave `worker.image.repository` empty in v0.5.7, the render will fail with:
> ```
> ERROR: image.repository is empty for one of the components.
> An empty repository renders as ":<tag>", which the API server rejects with
> InvalidImageName. Set api.image.repository or worker.image.repository.
> ```

**Why this matters:**

The API image (`plugin-br-pix-jd`) **no longer carries the `/worker` binary**. Attempting to run the worker from the API image will fail with a binary-not-found error. The two components are now built from separate Dockerfiles (`cmd/app/Dockerfile` and `cmd/worker/Dockerfile`) and published as separate images.

**Migration required:** Yes — see [Step 1](#step-1-update-worker-image-configuration).

### 2. LICENSE_KEY Now Required for API

**What changed:**

The API now validates the license key at boot in all modes. Previously, only the worker performed license validation.

**Before (v0.5.6):**

```yaml
api:
  secrets:
    LICENSE_KEY: ""  # Optional for API
```

The API Secret template would omit `LICENSE_KEY` if empty. Only the worker Secret required it.

**After (v0.5.7):**

```yaml
api:
  secrets:
    LICENSE_KEY: "your-license-key-here"  # Required
```

The render will fail if `api.secrets.LICENSE_KEY` is empty:

```
ERROR: api.secrets.LICENSE_KEY is required.
The api and the worker validate the license at boot in every mode and do not start
without it; IS_DEVELOPMENT only selects the development license gateway.
```

**Why this matters:**

The application now imports `lib-license-go` in `cmd/app/main.go` and validates the license before starting the HTTP server. Without a valid `LICENSE_KEY`, the API pod will crash with a license validation error, not just the worker.

**Migration required:** Yes — see [Step 2](#step-2-set-license_key-in-api-secrets).

### 3. SYSTEMPLANE_ENABLED Default Changed

**What changed:**

The default value for `SYSTEMPLANE_ENABLED` now depends on the database topology.

| Database | v0.5.6 Default | v0.5.7 Default |
|----------|---------------|---------------|
| Bundled PostgreSQL | `false` | `false` |
| External PostgreSQL | `false` | `true` |

**Why this matters:**

With the bundled PostgreSQL, the schema lands **after** the API rolls out (PostSync hook), so the API cannot boot with `SYSTEMPLANE_ENABLED=true` because the `systemplane_entries` table does not exist yet. The chart now defaults to `false` on this path to prevent a CrashLoop on first install.

With an external PostgreSQL, the schema is applied **before** the API rolls out (PreSync hook), so the table exists and the plane can be enabled by default.

> **Important:** With `SYSTEMPLANE_ENABLED=false`, every Pix flow that requires the own ISPB, the Midaz scope, or transaction routes will fail with **503 PIX-0051**. The NOTES.txt now warns:
> ```
> With systemplane on, the api cannot boot before the schema exists and a first install
> never reaches this Job, so on this path api.configmap.SYSTEMPLANE_ENABLED defaults to
> "false" and every Pix flow answers 503 until you set it to "true" after the first sync.
> ```

**Migration impact:**

If you are upgrading an existing install with the bundled PostgreSQL and have not explicitly set `SYSTEMPLANE_ENABLED`, the default remains `false` and no change occurs. If you are using an external PostgreSQL, the default changes to `true`, which may enable systemplane lookups that were previously disabled.

**Migration required:** Conditional — see [Step 3](#step-3-review-systemplane_enabled-setting).

## Features

### 1. Dedicated Worker Image

The chart now references the dedicated worker image by default in `values.yaml`:

```yaml
worker:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-worker
    tag: "1.3.0"
```

The `workerOwnImage` helper template has been removed from `_helpers.tpl` because the chart no longer supports the single-image shape. The NOTES.txt output now shows:

```
WORKER: enabled — image ghcr.io/lerianstudio/plugin-br-pix-jd-worker:1.3.0.
```

Instead of:

```
WORKER: enabled — dedicated image ghcr.io/lerianstudio/plugin-br-pix-jd-worker
        (its own ENTRYPOINT /worker).
```

Or:

```
WORKER: enabled — the api's image, entrypoint overridden to /worker.
```

### 2. New Environment Variables

The chart now emits two new environment variables in the ConfigMap for both API and worker:

| Variable | Default | Description |
|----------|---------|-------------|
| `MIDAZ_URL_TRACER` | `""` | Tracer base URL; empty screens no inbound credit |
| `APPLICATION_NAME` | `""` | License identity; empty defaults to `plugin-br-pix-jd` |

**Configuration:**

```yaml
api:
  configmap:
    MIDAZ_URL_TRACER: "https://tracer.example.com"
    APPLICATION_NAME: "my-pix-plugin"
```

These variables are shared between the API and worker (merged from `api.configmap` into `worker.configmap`), so you only need to set them once.

### 3. ORGANIZATION_IDS Default Value

The default value for `ORGANIZATION_IDS` has changed from empty string to `"global"`.

| Setting | v0.5.6 | v0.5.7 |
|---------|---------|---------|
| `ORGANIZATION_IDS` default | `""` | `"global"` |

**Why this matters:**

An empty `ORGANIZATION_IDS` previously caused the application to skip organization-scoped operations. The new default of `"global"` enables global organization scope by default, matching the typical single-tenant deployment pattern.

**Migration impact:**

If you have not explicitly set `ORGANIZATION_IDS`, the application will now use `"global"` instead of an empty string. If you need the previous behavior (no organization scope), explicitly set:

```yaml
api:
  configmap:
    ORGANIZATION_IDS: ""
```

### 4. Streaming CloudEvents Source Format

The default CloudEvents source format has changed from a URI-style path to a simple identifier.

| Setting | v0.5.6 | v0.5.7 |
|---------|---------|---------|
| `STREAMING_CLOUDEVENTS_SOURCE` default | `//lerian.midaz/plugin-br-pix-jd` | `plugin-br-pix-jd` |

**Why this matters:**

The CloudEvents specification recommends URI-reference format for the `source` attribute, but the application now uses a simpler identifier that matches the service name. This change aligns with the CloudEvents 1.0 spec's guidance that the source should be "a URI-reference" but does not require a scheme or authority.

**Migration impact:**

If you have not explicitly set `STREAMING_CLOUDEVENTS_SOURCE`, the emitted events will now have `source: plugin-br-pix-jd` instead of `source: //lerian.midaz/plugin-br-pix-jd`. If you have downstream consumers that filter on the old format, you must either:

#### Option 1: Keep existing format

```yaml
api:
  configmap:
    STREAMING_CLOUDEVENTS_SOURCE: "//lerian.midaz/plugin-br-pix-jd"
```

#### Option 2: Update consumers

Update your event consumers to recognize the new `plugin-br-pix-jd` source identifier.

### 5. Removed Transaction Limit Period Variables

The chart no longer emits `TRANSACTION_LIMIT_DAILY_PERIOD_INIT` and `TRANSACTION_LIMIT_DAILY_PERIOD_END` in the ConfigMap.

**Before (v0.5.6):**

```yaml
TRANSACTION_LIMIT_DAILY_PERIOD_INIT: "06:00"
TRANSACTION_LIMIT_DAILY_PERIOD_END: "20:00"
```

**After (v0.5.7):**

These variables are removed from the template. The application no longer reads them.

**Why this matters:**

The transaction limit clock bounds are now hardcoded in the application or sourced from a different configuration mechanism. If you were overriding these values, they will no longer have any effect.

**Migration impact:**

If you have explicitly set these variables in `api.configmap` or `api.extraConfigmap`, they will still be emitted (via the escape hatch), but the application will ignore them. Remove them from your values file to avoid confusion.

### 6. JD_USE_SERVICE_SEGMENTS Multi-Tenant Suppression

The `JD_USE_SERVICE_SEGMENTS` variable is now suppressed in multi-tenant mode.

**Before (v0.5.6):**

```yaml
JD_USE_SERVICE_SEGMENTS: "false"
```

Emitted unconditionally for both single-tenant and multi-tenant modes.

**After (v0.5.7):**

```yaml
{{- if ne (index $cm "MULTI_TENANT_ENABLED" | default "false" | toString) "true" }}
JD_USE_SERVICE_SEGMENTS: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" $cm "key" "JD_USE_SERVICE_SEGMENTS" "default" "false") | quote }}
{{- end }}
```

The variable is only emitted when `MULTI_TENANT_ENABLED` is not `"true"`.

**Why this matters:**

In multi-tenant mode, the application reads `JD_USE_SERVICE_SEGMENTS` from the tenant's bundle, not from the environment. Emitting it as an environment variable would cause a conflict, and the application now logs a warning if both are present.

**Migration impact:**

If you are running in multi-tenant mode and have set `JD_USE_SERVICE_SEGMENTS` in `api.configmap`, it will no longer appear in the rendered ConfigMap. The application will read it from the tenant bundle instead. If you are in single-tenant mode, no change occurs.

### 7. QR Code Configuration for Worker

The `qrcodeEnv` helper now emits QR code configuration for both the API and the worker.

**Why this matters:**

The worker does not serve QR payloads, but its config validation (shared with the API) requires `QRCODE_PUBLIC_BASE_URL` in production. Previously, the QR code block was only emitted for the API, which caused the worker to fail validation in production mode.

**Migration impact:**

If you have set `QRCODE_PUBLIC_BASE_URL` in `api.configmap`, it will now also appear in the worker's ConfigMap. No action required unless you were relying on the worker not having this variable.

### 8. Migrations Job Connection Resolution

The migrations Job now resolves the Postgres connection from the same merged ConfigMap that the API uses, instead of calling the individual helper functions directly.

**Before (v0.5.6):**

```yaml
env:
  - name: POSTGRES_HOST
    value: {{ include "plugin-br-pix-jd.postgresHost" . | quote }}
  - name: POSTGRES_PORT
    value: {{ include "plugin-br-pix-jd.cfg" (dict "configmap" (.Values.api.configmap | default dict) "key" "POSTGRES_PORT" "default" "5432") | quote }}
```

**After (v0.5.7):**

```yaml
{{- $pg := mergeOverwrite (fromYaml (include "plugin-br-pix-jd.platformEnv" (dict "root" $ "configmap" .Values.api.configmap "serviceName" "plugin-br-pix-jd"))) (.Values.api.extraConfigmap | default dict) -}}
env:
  - name: POSTGRES_HOST
    value: {{ $pg.POSTGRES_HOST | quote }}
  - name: POSTGRES_PORT
    value: {{ $pg.POSTGRES_PORT | quote }}
```

**Why this matters:**

The Job now sees the same connection parameters as the API, including any overrides from `global.datastores`, `global.cloud`, or `api.extraConfigmap`. This ensures consistency and eliminates a class of bugs where the Job and the API connect to different databases.

**Migration impact:**

If you have set Postgres connection parameters in `api.extraConfigmap` that were not being picked up by the migrations Job in v0.5.6, they will now be applied. Review your `api.extraConfigmap` to ensure the Job should use those values.

### 9. OTEL_RESOURCE_SERVICE_VERSION Removed

The `OTEL_RESOURCE_SERVICE_VERSION` variable is no longer emitted in the ConfigMap.

**Before (v0.5.6):**

```yaml
OTEL_RESOURCE_SERVICE_VERSION: "1.3.0"
```

Derived from `api.image.tag` or `.Chart.AppVersion`.

**After (v0.5.7):**

The variable is removed from the `$otelKeys` list and `$otelDefaults` map in the `platformEnv` helper.

**Why this matters:**

The OpenTelemetry semantic conventions recommend using `service.version` as a resource attribute, but the application does not use this variable. Removing it reduces ConfigMap noise and eliminates a potential source of confusion (the version in the ConfigMap may not match the actual running image if the tag is overridden).

**Migration impact:**

If you were relying on `OTEL_RESOURCE_SERVICE_VERSION` in your observability backend, you will need to derive the service version from another source (e.g., pod labels, image tag, or a custom resource attribute).

## Migration Steps

### Step 1: Update Worker Image Configuration

If you have the worker enabled, you **must** set `worker.image.repository` to the dedicated worker image.

**Before (v0.5.6):**

```yaml
worker:
  enabled: true
  image:
    repository: ""
    tag: ""
```

**After (v0.5.7):**

```yaml
worker:
  enabled: true
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-worker
    tag: "1.3.0"
```

> **Important:** Keep `worker.image.tag` equal to `api.image.tag`. The two components share one database and one schema, and tag divergence (while not policed by the chart) can cause runtime errors if the schema version does not match the application version.

### Step 2: Set LICENSE_KEY in API Secrets

The API now requires `LICENSE_KEY` at boot. If you have not set it, the render will fail.

**Add to your values file:**

```yaml
api:
  secrets:
    LICENSE_KEY: "your-license-key-here"
```

Or reference an existing Secret:

```yaml
api:
  existingSecret:
    name: plugin-pix-credentials
```

The existing Secret must contain a `LICENSE_KEY` key.

> **Note:** If you were previously setting `LICENSE_KEY` only in `worker.secrets`, you must now also set it in `api.secrets`. The two components do not share a Secret by default.

### Step 3: Review SYSTEMPLANE_ENABLED Setting

If you are using the **bundled PostgreSQL** and have not explicitly set `SYSTEMPLANE_ENABLED`, the default remains `false` and no action is required.

If you are using an **external PostgreSQL**, the default changes to `true`. Review whether this is correct for your deployment:

#### Option 1: Keep systemplane enabled (new default)

No action required. The API will read the own ISPB, Midaz scope, and transaction routes from the `systemplane_entries` table.

#### Option 2: Disable systemplane

```yaml
api:
  configmap:
    SYSTEMPLANE_ENABLED: "false"
```

> **Warning:** With `SYSTEMPLANE_ENABLED=false`, every Pix flow that requires systemplane data will fail with **503 PIX-0051**. The application will log:
> ```
> SYSTEMPLANE_ENABLED=false fails every Pix flow closed: the own ISPB, the Midaz scope
> and the transaction routes live only in systemplane.
> ```

### Step 4: Add New Environment Variables (Optional)

If you need to configure the Tracer URL or override the license identity, add:

```yaml
api:
  configmap:
    MIDAZ_URL_TRACER: "https://tracer.example.com"
    APPLICATION_NAME: "my-pix-plugin"
```

These variables are optional and default to empty (Tracer) or `plugin-br-pix-jd` (application name).

### Step 5: Update Streaming CloudEvents Source (If Used)

If you have downstream consumers that filter on the CloudEvents `source` attribute, verify they recognize the new format.

**Old format:**

```
source: //lerian.midaz/plugin-br-pix-jd
```

**New format:**

```
source: plugin-br-pix-jd
```

If you need to keep the old format, override it:

```yaml
api:
  configmap:
    STREAMING_CLOUDEVENTS_SOURCE: "//lerian.midaz/plugin-br-pix-jd"
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.7 -n plugin-br-pix-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.5.7 -n plugin-br-pix-jd
```
<!-- {% endraw %} -->
