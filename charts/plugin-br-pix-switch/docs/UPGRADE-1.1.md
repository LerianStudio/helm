# Helm Upgrade from v1.0.x to v1.1.x

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Multi-component refactor](#1-multi-component-refactor)
  - [2. New subchart dependencies](#2-new-subchart-dependencies)
  - [3. Bootstrap Jobs for PostgreSQL and MongoDB](#3-bootstrap-jobs-for-postgresql-and-mongodb)
  - [4. Schema migration Jobs for spi, dict-hub, cob-hub](#4-schema-migration-jobs-for-spi-dict-hub-cob-hub)
  - [5. Shared multi-path ingresses](#5-shared-multi-path-ingresses)
  - [6. Per-component image repositories](#6-per-component-image-repositories)
  - [7. Per-component health probe paths](#7-per-component-health-probe-paths)
  - [8. DEPLOYMENT_MODE default switched to byoc](#8-deployment_mode-default-switched-to-byoc)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a major refactor of the `plugin-br-pix-switch` chart. The 1.0.x line shipped a single-Deployment chart whose values exposed environment variables (`DB_HOST`, `DB_PORT`, ...) that the application binaries do not read. As a result, no usable production deployment of the chart exists on the 1.0.x line, so this guide treats the migration as a values-shape rewrite rather than a state-preserving upgrade.

The 1.1.x chart deploys all 10 application components independently (`spi`, `spi-systemplane`, `adapter-btg-mock`, `dict-hub`, `dict-hub-vsync`, `dict-proxy`, `dict-systemplane`, `cob-hub`, `cob-proxy`, `cob-systemplane`), each with its own Deployment, Service, ConfigMap, Secret, ServiceAccount, HPA, PDB, and ingress route. It also adds optional bootstrap and schema-migration Jobs and three new subchart dependencies (`mongodb`, `rabbitmq`, plus `valkey` repository change).

## Features

### 1. Multi-component refactor

The single `pixSwitch` values block has been replaced by 10 per-component blocks. Each block is independently `enabled`, sized, and configured.

| Component (values key) | Service port | Purpose |
|------------------------|--------------|---------|
| `spi` | 4101 | PIX SPI service |
| `spiSystemplane` | 4102 | Runtime config plane for SPI |
| `adapterBtgMock` | 4103 | BTG provider mock (disabled by default) |
| `dictHub` | 4104 | DICT hub |
| `dictHubVsync` | 4105 | DICT verification sync worker |
| `dictProxy` | 4106 | DICT proxy to BCB |
| `dictSystemplane` | 4107 | Runtime config plane for DICT |
| `cobHub` | 4108 | COB hub |
| `cobProxy` | 4109 | COB proxy to BCB |
| `cobSystemplane` | 4110 | Runtime config plane for COB |

Ports sit in the 41xx range to avoid conflicts with the org port allocation table (4001-4013 is used by Identity, Fees, CRM, Reporter, etc.).

The legacy `pixSwitch.*` values are not honored and must be removed.

### 2. New subchart dependencies

`Chart.yaml` declares four optional subcharts. All default to disabled; production deployments are expected to point each component at an externally-managed datastore through a Kubernetes Secret.

| Subchart | Version | Repository | Used by |
|----------|---------|------------|---------|
| `postgresql` | 16.3 | https://charts.bitnami.com/bitnami | 7 components (DATABASE_URL) |
| `valkey` | 2.4.7 | oci://registry-1.docker.io/bitnamicharts | spi, dict-hub, dict-hub-vsync (optional cache) |
| `mongodb` | 16.4 | https://charts.bitnami.com/bitnami | dict-hub |
| `rabbitmq` | 2.1.11 | https://groundhog2k.github.io/helm-charts | dict-hub-vsync |

The `valkey` subchart was previously sourced from `https://valkey.io/valkey-helm`; in 1.1.x it is sourced from the Bitnami OCI registry instead.

### 3. Bootstrap Jobs for PostgreSQL and MongoDB

Optional bootstrap Jobs provision the databases, roles, and grants required by the application. Both are disabled by default and gated by `global.externalPostgresDefinitions.enabled` and `global.externalMongoDefinitions.enabled`.

```yaml
global:
  externalPostgresDefinitions:
    enabled: false
  externalMongoDefinitions:
    enabled: false
```

When enabled, the chart renders:

| Job | Action |
|-----|--------|
| `bootstrap-postgres-pix-spi` | Creates `pix-spi` database and `pixswitch` role |
| `bootstrap-postgres-pix-dict` | Creates `pix-dict` database and grants |
| `bootstrap-postgres-pix-cob` | Creates `pix-cob` database and grants |
| `bootstrap-mongodb` | Creates `pixswitch` Mongo user with `readWrite` on `pix-dict` and `pix-cob` |

Each Job is idempotent and skips when the role, database, or user already exists.

### 4. Schema migration Jobs for spi, dict-hub, cob-hub

The three components that own schema migrations now ship a `golang-migrate` Helm-hook Job. Each Job uses the component's own image (which since `1.0.0-beta.101` ships both `/app` and `/migrate` binaries) and runs `pre-upgrade,post-install` with weight `-5`.

```yaml
spi:
  migrations:
    enabled: true
    migrationsPath: /migrations
    ttlSecondsAfterFinished: 300
    backoffLimit: 3
dictHub:
  migrations:
    enabled: true
cobHub:
  migrations:
    enabled: true
```

Setting `migrations.enabled: false` skips the Job for that component. Without these Jobs, application tables are never created.

### 5. Shared multi-path ingresses

Per-component `ingress` blocks have been replaced by three top-level ingress objects routed by URL path prefix.

| Top-level key | Default hostname | Default routes |
|---------------|------------------|----------------|
| `appsIngress` | (operator-set) | `/spi`, `/dict-hub`, `/dict-proxy`, `/cob-hub`, `/cob-proxy` |
| `systemplaneIngress` | (operator-set) | `/spi`, `/dict`, `/cob` |
| `providersIngress` | (operator-set) | `/btg-mock` |

Routes whose target component is disabled are silently dropped. No path rewriting is performed at the ingress; applications register their own `/<component>` prefix on the source side.

`adapterBtgMock` keeps its own per-component `ingress` block in addition to its entry in `providersIngress.routes` because it is dev-only and operators may want to expose it independently.

### 6. Per-component image repositories

Each component now defaults its `image.repository` to the per-component image published by the source repo from `1.0.0-beta.101` onward. Previously every component fell back to the global default `ghcr.io/lerianstudio/plugin-br-pix-switch`, which only contained the SPI binary.

| Component | Default image |
|-----------|---------------|
| `spi` | `ghcr.io/lerianstudio/plugin-br-pix-switch-spi-api` |
| `spiSystemplane` | `ghcr.io/lerianstudio/plugin-br-pix-switch-spi-systemplane-api` |
| `adapterBtgMock` | `ghcr.io/lerianstudio/plugin-br-pix-switch-adapter-btg-mock-api` |
| `dictHub` | `ghcr.io/lerianstudio/plugin-br-pix-switch-dict-hub-api` |
| `dictHubVsync` | `ghcr.io/lerianstudio/plugin-br-pix-switch-dict-hub-vsync` |
| `dictProxy` | `ghcr.io/lerianstudio/plugin-br-pix-switch-dict-proxy-api` |
| `dictSystemplane` | `ghcr.io/lerianstudio/plugin-br-pix-switch-dict-systemplane-api` |
| `cobHub` | `ghcr.io/lerianstudio/plugin-br-pix-switch-cob-hub-api` |
| `cobProxy` | `ghcr.io/lerianstudio/plugin-br-pix-switch-cob-proxy-api` |
| `cobSystemplane` | `ghcr.io/lerianstudio/plugin-br-pix-switch-cob-systemplane-api` |

The dead `global.image` block was removed in `1.1.0-beta.7`. Operators who relied on `global.image.tag` for cohort-wide tag overrides must now set `image.tag` per component.

### 7. Per-component health probe paths

Each component defaults its readiness and liveness probes to the HTTP path that matches its source-side `routePrefix`:

| Component | readiness | liveness |
|-----------|-----------|----------|
| `spi` | `/spi/readyz` | `/spi/health` |
| `spiSystemplane` | `/spi/readyz` | `/spi/health` |
| `dictHub` | `/dict-hub/readyz` | `/dict-hub/health` |
| `dictHubVsync` | `/readyz` | `/health` |
| `dictProxy` | `/dict-proxy/readyz` | `/dict-proxy/health` |
| `dictSystemplane` | `/dict/readyz` | `/dict/health` |
| `cobHub` | `/cob-hub/readyz` | `/cob-hub/health` |
| `cobProxy` | `/cob-proxy/readyz` | `/cob-proxy/health` |
| `cobSystemplane` | `/cob/readyz` | `/cob/health` |
| `adapterBtgMock` | `/btg-mock/readyz` | `/btg-mock/health` |

Override per environment via `<component>.readinessProbe.path` and `<component>.livenessProbe.path`.

### 8. DEPLOYMENT_MODE default switched to byoc

The chart-wide default for `DEPLOYMENT_MODE` switched from `local` to `byoc` on every component's configmap. `byoc` triggers production license enforcement; opt back in to `local` explicitly for dev or CI installs without a license:

```yaml
spi:
  configmap:
    DEPLOYMENT_MODE: "local"
# ... repeat per component
```

## Configuration Changes

The following table summarizes the chart-level changes between v1.0.x and v1.1.x:

| Setting | v1.0.1-beta.1 | v1.1.0-beta.10 |
|---------|---------------|----------------|
| Chart version | `1.0.1-beta.1` | `1.1.0-beta.10` |
| App version | `1.0.0-beta.1` | `1.0.0-beta.101` |
| `pixSwitch.*` block | present | removed |
| Per-component blocks (`spi`, `dictHub`, ...) | not present | required |
| `postgresql.enabled` (default) | `true` | `false` |
| `valkey.enabled` (default) | `true` | `false` |
| `valkey.auth.enabled` (default) | `false` | `true` |
| `valkey` repository | `https://valkey.io/valkey-helm` | `oci://registry-1.docker.io/bitnamicharts` |
| `mongodb` subchart | not declared | declared, disabled |
| `rabbitmq` subchart | not declared | declared, disabled |
| `global.image` block | present | removed |
| `appsIngress`, `systemplaneIngress`, `providersIngress` | not present | added |
| Bootstrap and migration Jobs | not present | added (opt-in) |
| `DEPLOYMENT_MODE` default | `local` | `byoc` |

## Migration Steps

Because the 1.0.x chart did not produce a working deployment (the old `pixSwitch` block emitted `DB_HOST`/`DB_PORT`/... which the application binaries do not read), there is no in-place state to preserve. The migration is a values-shape rewrite.

1. Read this guide alongside `charts/plugin-br-pix-switch/values.yaml` and `charts/plugin-br-pix-switch/values-template.yaml` in the new chart.
2. Remove the legacy `pixSwitch:` block and any `pixSwitch.*` overrides from your custom values.
3. Rewrite custom values into the per-component shape (`spi:`, `spiSystemplane:`, `dictHub:`, `dictHubVsync:`, `dictProxy:`, `dictSystemplane:`, `cobHub:`, `cobProxy:`, `cobSystemplane:`, `adapterBtgMock:`).
4. Decide how to provide datastores:
   - Provision `pix-spi`, `pix-dict`, `pix-cob` PostgreSQL databases and a `pixswitch` role externally, or set `global.externalPostgresDefinitions.enabled=true` to let the chart bootstrap them.
   - Provision a MongoDB database for `dict-hub` (and optionally `cob-hub`), or set `global.externalMongoDefinitions.enabled=true`.
   - Configure RabbitMQ (required only by `dict-hub-vsync`) and Valkey (optional cache for `spi`, `dict-hub`, `dict-hub-vsync`).
5. Set per-component `image.repository` and `image.tag` if you do not want the new per-component defaults.
6. Replace per-component `ingress.*` overrides with entries in `appsIngress.routes`, `systemplaneIngress.routes`, or `providersIngress.routes`.
7. If running outside production, set `DEPLOYMENT_MODE: "local"` in each component's `configmap` block to bypass license enforcement.
8. Render the chart locally with `helm template` and review the manifest diff.
9. Apply the upgrade in a controlled environment before production.

```bash
kubectl get pods -n <namespace>
```

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/instance=plugin-br-pix-switch --tail=50
```

> **Note:** The schema-migration Jobs run as `pre-upgrade` hooks. Confirm the application image has `/migrate` available (source `1.0.0-beta.101` and later) before enabling them, otherwise the Job will fail with `exec: "/migrate": no such file`.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-switch oci://registry-1.docker.io/lerianstudio/plugin-br-pix-switch-helm --version 1.1.0-beta.10 -n <namespace>
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-switch oci://registry-1.docker.io/lerianstudio/plugin-br-pix-switch-helm --version 1.1.0-beta.10 -n <namespace>
```
