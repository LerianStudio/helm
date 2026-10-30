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

This is a **patch release** of the `plugin-br-pix-jd` chart (v0.5.7). It changes how the worker image is resolved, requires `LICENSE_KEY` for the API, and flips the `SYSTEMPLANE_ENABLED` default for external PostgreSQL. The chart now ships two components from **separate images**: the HTTP API (`plugin-br-pix-jd`) and the cron worker (`plugin-br-pix-jd-worker`). The previous single-image shape, where the worker ran the API image with the entrypoint overridden to `/worker`, is gone.

The API Deployment rolls on this upgrade: the ConfigMap and Secret checksums and the `helm.sh/chart` pod label change. If the worker is enabled, its Deployment (strategy `Recreate`) is replaced as well, now running the dedicated worker image.

| Setting | v0.5.6 | v0.5.7 |
|---------|---------|---------|
| Chart version | 0.5.6 | 0.5.7 |
| App version | 1.3.0 | 1.3.0 |
| Worker image | Inherited from the API image, entrypoint overridden to `/worker` | Dedicated image by default, no entrypoint override |
| Worker image tag | Empty, inherits `api.image.tag` | `1.3.0` in `values.yaml`, no longer follows `api.image.tag` |
| LICENSE_KEY required for API | No (worker only, and optional with `IS_DEVELOPMENT`) | Yes (both components, every mode) |
| SYSTEMPLANE_ENABLED default (bundled Postgres) | `false` | `false` |
| SYSTEMPLANE_ENABLED default (external Postgres) | `false` | `true` |

## Breaking Changes

### 1. Worker Image Now Required

**What changed:**

The chart no longer supports the single-image architecture where `worker.image.repository` could be left empty to inherit the API image. The worker now runs its own dedicated image, and `values.yaml` sets it by default. You only need to act if your values file overrides `worker.image.repository` or `worker.image.tag`.

**Before (v0.5.6):**

```yaml
worker:
  enabled: true
  image:
    repository: ""  # Empty = inherit from api.image.repository
    tag: ""
```

The chart would override the entrypoint to `/worker` when `worker.image.repository` was empty.

**After (v0.5.7), chart defaults:**

```yaml
worker:
  enabled: false   # still opt-in
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-worker
    tag: "1.3.0"
```

The worker image has its own `ENTRYPOINT ["/worker"]` and the chart no longer sets `command` on the worker container.

> **Warning:** If your values file sets `worker.image.repository` to an empty string and `worker.enabled` is `true`, the render fails with:
> ```
> ERROR: image.repository is empty for one of the components.
> An empty repository renders as ":<tag>", which the API server rejects with
> InvalidImageName. Set api.image.repository or worker.image.repository.
> ```

> **Warning:** If your values file sets `worker.image.repository` to the API image (`ghcr.io/lerianstudio/plugin-br-pix-jd`), the render succeeds but the chart no longer adds `command: ["/worker"]`. The worker container then starts the API image's own entrypoint instead of the worker. Do not point the worker at the API image.

**Worker tag no longer follows the API tag.** In v0.5.6 an empty `worker.image.tag` inherited `api.image.tag`. In v0.5.7 `worker.image.tag` defaults to `1.3.0`, and an empty value falls back to the chart `appVersion`, not to `api.image.tag`. If you pin `api.image.tag`, pin `worker.image.tag` to the same value.

**Why this matters:**

According to the chart's `values.yaml`, the app publishes one image per entry point: `plugin-br-pix-jd` (`cmd/app`, `ENTRYPOINT /service`) and `plugin-br-pix-jd-worker` (`cmd/worker`, `ENTRYPOINT /worker`), and the API image carries no `/worker` binary.

x [Step 1](#step-1-update-worker-image-configuration).

### 2. LICENSE_KEY Now Required for API

**What changed:**

The chart now requires the license key for both the API and the worker, in every mode. In v0.5.6 the chart required it only for the worker, and the worker requirement was waived when `IS_DEVELOPMENT` was true.

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

When the chart renders the API Secret itself (no `api.existingSecret.name`), the render fails if `api.secrets.LICENSE_KEY` is empty:

```
ERROR: api.secrets.LICENSE_KEY is required.
The api and the worker validate the license at boot in every mode and do not start
without it; IS_DEVELOPMENT only selects the development license gateway.
```

**Why this matters:**

Per the chart's error message, the API and the worker validate the license at boot and do not start without it. `IS_DEVELOPMENT` no longer makes the key optional: it only selects the development license gateway. A development stack that set `IS_DEVELOPMENT=true` with no key and the worker enabled rendered in v0.5.6 and fails to render in v0.5.7.

**Migration required:** Yes, see [Step 2](#step-2-set-license_key-in-api-secrets).

### 3. SYSTEMPLANE_ENABLED Default Changed

**What changed:**

The default value for `SYSTEMPLANE_ENABLED` now depends on the database topology.

| Database | v0.5.6 Default | v0.5.7 Default |
|----------|---------------|---------------|
| Bundled PostgreSQL | `false` | `false` |
| External PostgreSQL | `false` | `true` |

**Why this matters:**

With the bundled PostgreSQL, the migrations Job runs **after** the release syncs (Helm `post-install`/`post-upgrade` hook, ArgoCD PostSync). With systemplane on, the API cannot boot before the schema exists, and a first install never reaches the Job. The chart therefore defaults to `false` on this path.

With an external PostgreSQL (the chart default, since `postgresql.enabled` is `false`), the migrations Job runs **before** the API rolls out (Helm `pre-install`/`pre-upgrade` hook, ArgoCD PreSync), so the plane can be enabled by default.

> **Important:** According to the chart, with `SYSTEMPLANE_ENABLED=false` every Pix flow that requires the own ISPB, the Midaz scope, or transaction routes fails closed with **503 PIX-0051**. The NOTES.txt (bundled PostgreSQL path) now warns:
> ```
> With systemplane on, the api cannot boot before the schema exists and a first install
> never reaches this Job, so on this path api.configmap.SYSTEMPLANE_ENABLED defaults to
> "false" and every Pix flow answers 503 until you set it to "true" after the first sync.
> ```

**Migration impact:**

If you use the bundled PostgreSQL and have not set `SYSTEMPLANE_ENABLED`, the default remains `false` and nothing changes. With an external PostgreSQL and `SYSTEMPLANE_ENABLED` unset in `api.configmap`, the rendered ConfigMap changes from `"false"` to `"true"` (confirmed with the CI render fixture). If you already set it explicitly, nothing changes. The external-PostgreSQL migrations Job runs as a pre-upgrade hook, so the schema is applied before the API pods roll.

**Migration required:** Conditional, see [Step 3](#step-3-review-systemplane_enabled-setting).

## Features

### 1. Dedicated Worker Image

The chart references the dedicated worker image by default in `values.yaml`:

```yaml
worker:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-worker
    tag: "1.3.0"
```

The `workerOwnImage` helper template has been removed from `_helpers.tpl` because the chart no longer supports the single-image shape. The NOTES.txt line for an enabled worker now names the full worker image reference (for example `ghcr.io/lerianstudio/plugin-br-pix-jd-worker:1.3.0`). In v0.5.6 it named either the dedicated image or the API image with the entrypoint overridden to `/worker`.

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

`ORGANIZATION_IDS` is the license organization scope: `"global"` for a global-plugin license, or the comma-separated organization IDs of a per-organization license. According to the chart (`values-template.yaml` and README), an empty value stops the service from starting, because the license check needs it. The v0.5.6 default of `""` therefore required every install to set it; the new default `"global"` covers the global-license case.

**Migration impact:**

If you have not set `ORGANIZATION_IDS`, the rendered value changes from `""` to `"global"`. If you use a per-organization license, set the organization IDs explicitly:

```yaml
api:
  configmap:
    ORGANIZATION_IDS: "<org-id-1>,<org-id-2>"
```

Do not set `ORGANIZATION_IDS: ""`: the chart renders it as an empty string, and the chart documents that an empty value fails the boot.

### 4. Streaming CloudEvents Source Format

The default CloudEvents source format has changed from a URI-style path to a simple identifier.

| Setting | v0.5.6 | v0.5.7 |
|---------|---------|---------|
| `STREAMING_CLOUDEVENTS_SOURCE` default | `//lerian.midaz/plugin-br-pix-jd` | `plugin-br-pix-jd` |

**Why this matters:**

The chart now defaults the streaming source to the app name.

**Migration impact:**

The variable is only rendered when `api.configmap.STREAMING_ENABLED` is `"true"`. If streaming is on and you have not set `STREAMING_CLOUDEVENTS_SOURCE`, the ConfigMap changes from `//lerian.midaz/plugin-br-pix-jd` to `plugin-br-pix-jd`, so events carry the new `source`. If you have downstream consumers that filter on the old format, you must either:

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

These variables are removed from the template. The v0.5.7 changelog lists this as "Stopped emitting environment variables that the app no longer reads".

**Why this matters:**

Values you set under `api.configmap` for these two keys are now silently dropped: in v0.5.6 a `TRANSACTION_LIMIT_DAILY_PERIOD_INIT: "07:00"` in `api.configmap` was rendered, in v0.5.7 it is not (confirmed by rendering both tags).

**Migration impact:**

If you overrode these in `api.configmap`, the override no longer reaches the pods. Keys set under `api.extraConfigmap` are still rendered as-is. The chart does not document where the transaction-limit clock bounds come from now, so confirm with the plugin team before relying on a custom value.

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

According to the chart, in multi-tenant mode the application reads `JD_USE_SERVICE_SEGMENTS` from the tenant's bundle and logs a warning when the variable is present in the environment.

**Migration impact:**

The check reads `MULTI_TENANT_ENABLED` from `api.configmap`. If it is `"true"` and you set `JD_USE_SERVICE_SEGMENTS` in `api.configmap`, the key no longer appears in the rendered ConfigMap (confirmed by rendering). In single-tenant mode, no change occurs.

### 7. QR Code Configuration for Worker

The worker ConfigMap now includes the QR code configuration (`QRCODE_PUBLIC_BASE_URL`, `QRCODE_PAYLOAD_PATH`, `QRCODE_JWK_PATH`, `QRCODE_JWS_CONTENT_TYPE`, `QRCODE_JWKS_CONTENT_TYPE`), built by the same `qrcodeEnv` helper as the API.

**Why this matters:**

The worker does not serve QR payloads, but according to the chart its config validation (shared with the API) requires `QRCODE_PUBLIC_BASE_URL` in production. Previously the QR block was only rendered for the API.

**Migration impact:**

If you have set `QRCODE_PUBLIC_BASE_URL` in `api.configmap`, it now also appears in the worker's ConfigMap. No action required.

### 8. Migrations Job Connection Resolution

The migrations Job now resolves the Postgres connection the way the API ConfigMap does, instead of calling the individual helper functions directly. The worker's `wait-for-postgres` init container changed too: it now reads `POSTGRES_HOST` and `POSTGRES_PORT` from the worker's own ConfigMap (`envFrom`) instead of values rendered into the command line.

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

The Job now sees the same connection parameters as the API, including overrides from `global.datastores`, `global.cloud`, or `api.extraConfigmap`, and uses them for `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_NAME` and `POSTGRES_SSLMODE`.

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

The v0.5.7 changelog lists this under "Stopped emitting environment variables that the app no longer reads".

**Migration impact:**

A value set in `api.configmap.OTEL_RESOURCE_SERVICE_VERSION` is no longer rendered (confirmed by rendering); use `api.extraConfigmap` if you still need it. If you relied on the variable in your observability backend, derive the version from another source such as the `app.kubernetes.io/version` label or the image tag.

## Migration Steps

### Step 1: Update Worker Image Configuration

If you have the worker enabled and your values file does not set `worker.image.repository` or `worker.image.tag`, no change is needed: the chart default is the dedicated worker image. Remove any `worker.image.repository: ""` override, and do not point it at the API image.

**Before (v0.5.6):**

```yaml
worker:
  enabled: true
  image:
    repository: ""
    tag: ""
```

**After (v0.5.7), only if you pin the image yourself:**

```yaml
worker:
  enabled: true
  image:
    repository: ghcr.io/lerianstudio/plugin-br-pix-jd-worker
    tag: "1.3.0"   # same value as api.image.tag
```

> **Important:** `worker.image.tag` does not follow `api.image.tag`. When you change `api.image.tag`, change `worker.image.tag` to the same value. The chart does not check that the two match.

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

The existing Secret must contain a `LICENSE_KEY` key. With `api.existingSecret.name` set, the chart does not render the API Secret, so the render gate does not apply to the API.

> **Note:** If you were previously setting `LICENSE_KEY` only in `worker.secrets`, you must now also set it in `api.secrets` (or in the Secret named by `api.existingSecret.name`). The two components do not share a Secret by default.

> **Note:** With the worker enabled, the worker renders its own Secret unless `worker.existingSecret.name` is set. That Secret takes `worker.secrets.LICENSE_KEY`, falling back to `api.secrets.LICENSE_KEY`. Setting only `api.existingSecret.name` with the worker enabled still fails the render with "a license key is required for the worker". Set `worker.existingSecret.name`, or set the key inline.

### Step 3: Review SYSTEMPLANE_ENABLED Setting

If you are using the **bundled PostgreSQL** and have not explicitly set `SYSTEMPLANE_ENABLED`, the default remains `false` and no action is required.

If you are using an **external PostgreSQL** (the chart default) and have not set `SYSTEMPLANE_ENABLED`, the default changes to `true`. Review whether this is correct for your deployment:

#### Option 1: Keep systemplane enabled (new default)

No action required. According to the chart, the own ISPB, the Midaz scope and the transaction routes live only in systemplane.

#### Option 2: Disable systemplane

```yaml
api:
  configmap:
    SYSTEMPLANE_ENABLED: "false"
```

> **Warning:** According to the chart, with `SYSTEMPLANE_ENABLED=false` every Pix flow that requires systemplane data fails closed with **503 PIX-0051**.

### Step 4: Add New Environment Variables (Optional)

If you need to configure the Tracer URL or override the license identity, add:

```yaml
api:
  configmap:
    MIDAZ_URL_TRACER: "https://tracer.example.com"
    APPLICATION_NAME: "my-pix-plugin"
```

These variables are optional. `MIDAZ_URL_TRACER` defaults to empty, in which case no inbound credit is screened. `APPLICATION_NAME` defaults to empty, which the app reads as `plugin-br-pix-jd`; set it only if your license names another application. The API and the worker must agree, so set it in `api.configmap` only.

### Step 5: Update Streaming CloudEvents Source (If Used)

If streaming is enabled (`api.configmap.STREAMING_ENABLED: "true"`) and you have downstream consumers that filter on the CloudEvents `source` attribute, verify they recognize the new format.

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
