# Plugin-br-pix-switch Changelog

## [1.1.0-beta.8] - Fix providers ingress default path for adapter-btg-mock

`providersIngress.routes` default for `adapterBtgMock` had `/mock-btg`
but the source binary mounts its router at `/btg-mock` (per
`apps/adapter-btg-mock/components/api/bootstrap/server.go`:
`const routePrefix = "/btg-mock"`). Requests reaching the ingress at
`/mock-btg/<anything>` were forwarded to the pod which had no route
registered there → 404s.

Switch the default path to `/btg-mock` so it matches what the binary
actually serves (and what the deployment template's probe defaults
already use).

## [1.1.0-beta.7] - Providers ingress + prefixed health probes

Two additions, single chart bump.

### Providers ingress

Adds a third top-level ingress, `providersIngress`, routed by URL path
prefix and disabled by default. Same shape as `appsIngress` /
`systemplaneIngress` (custom `routes` list, enabled-aware rendering,
no path rewriting at the ingress).

Default `routes` ships a single path:

  /mock-btg  ->  adapter-btg-mock (port 4103)

Reserved paths (commented placeholders) for `/bacen` and `/jd` —
added when those adapter components ship.

### Per-component probe paths

Each component now defaults its readiness + liveness probes to the
HTTP path that matches its source-side `routePrefix`:

| Component | readiness | liveness |
|---|---|---|
| spi | /spi/readyz | /spi/health |
| spi-systemplane | /spi/readyz | /spi/health |
| dict-hub | /dict-hub/readyz | /dict-hub/health |
| dict-hub-vsync | /readyz | /health |
| dict-proxy | /dict-proxy/readyz | /dict-proxy/health |
| dict-systemplane | /dict/readyz | /dict/health |
| cob-hub | /cob-hub/readyz | /cob-hub/health |
| cob-proxy | /cob-proxy/readyz | /cob-proxy/health |
| cob-systemplane | /cob/readyz | /cob/health |
| adapter-btg-mock | /btg-mock/readyz | /btg-mock/health |

Source repo `1.0.0-beta.103` mounted every component's HTTP router
under its own `/<component>` prefix (issue #135), which shifted
`/health` and `/readyz` to e.g. `/spi/health` and `/spi/readyz`. The
chart was still probing the un-prefixed paths, so kubelet liveness
failed → pod restart → CrashLoopBackOff that surfaced "license
validation failed" in the shutdown log (a red-herring shutdown
message, not the actual cause).

dict-hub-vsync is a background worker with no `routePrefix` — its
probe paths stay at `/health` and `/readyz`.

Operators can still override per env via
`<component>.readinessProbe.path` / `<component>.livenessProbe.path`.

## [1.1.0-beta.7] - Remove dead global.image block

Adds a third top-level ingress, `providersIngress`, routed by URL path
prefix and disabled by default. Same shape as `appsIngress` /
`systemplaneIngress` (custom `routes` list, enabled-aware rendering,
no path rewriting at the ingress).

The hostname is dedicated to outbound-provider adapters so cluster
operators can apply provider-specific annotations (mTLS, IP allowlists,
per-provider WAF rules) without coupling to the apps or systemplane
ingresses.

Default `routes` ships a single path:

  /mock-btg  ->  adapter-btg-mock (port 4103)

Future provider components (BACEN, JD, …) can be added by either:

1. Defining a new component (`bacenAdapter`, `jdAdapter`, …) and
   appending to `providersIngress.routes` at the chart level (separate
   PR).
2. Overriding `providersIngress.routes` per env in gitops to point at
   an existing component or external Service.

The chart skips routes whose target component is disabled, so the
default `mock-btg` route is silently dropped when `adapterBtgMock.enabled`
is false.

## [1.1.0-beta.7] - Remove dead global.image block

Drop the `global.image` block from `values.yaml`. Since `1.1.0-beta.6`
every component already sets its own `image.repository` to a distinct
per-component image, so the global default was never reached at render
time and the old `repository: ghcr.io/lerianstudio/plugin-br-pix-switch`
value misled readers into thinking pods pulled from the original
single-binary image.

Changes:

- `values.yaml`: remove `global.image` (the `{repository, pullPolicy,
  tag}` sub-block). `global.imagePullSecrets` stays — it's still
  the natural place to set a single pull-secret list for the whole
  cohort.
- `_helpers.tpl`: simplify `componentImage` to read repo directly from
  per-component values and default tag to `.Chart.AppVersion`. Drop the
  intermediate `global.image.tag` fallback.
- `componentPullPolicy`: hard-default to `IfNotPresent` instead of
  reading `global.image.pullPolicy`.
- 10 component `configmap.yaml` templates: drop the
  `global.image.tag` fallback when deriving
  `OTEL_RESOURCE_SERVICE_VERSION`.

No rendered output changes when component-level `image.repository` and
`image.tag` are set (which is the documented use). Operators who relied
on `global.image.tag` for cohort-wide tag override must switch to
setting `image.tag` per component (or use a YAML anchor / helmfile
override list).

## [1.1.0-beta.6] - Per-component image repositories

Each component's `image.repository` now defaults to its own GHCR image
name, published by the plugin-br-pix-switch source repo as 10 distinct
per-component images (one per Dockerfile):

| Component (values key) | Default image |
|---|---|
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

Previously every component fell back to the global default
`ghcr.io/lerianstudio/plugin-br-pix-switch`, which only contained the
SPI binary — meaning all 9 component pods ran SPI regardless of role.
With the source repo now publishing per-component images
(plugin-br-pix-switch PR #137, available from `1.0.0-beta.101`), each
pod can run its own binary out of the box.

The `global.image.repository` fallback stays unchanged for backwards
compatibility — operators using a custom registry can still override
globally without setting every component.

`appVersion` bumped to `1.0.0-beta.101` so the chart's default tag
points at real published images (was `1.0.0-beta.1` which never existed
in GHCR as a per-component image).

## [1.1.0-beta.5] - Shared multi-path ingresses

Replaces 9 of the per-component `ingress:` blocks with two top-level
ingress objects routed by URL path prefix:

- `appsIngress` (single hostname) — user-facing traffic. Routes `/spi`,
  `/dict-hub`, `/dict-proxy`, `/cob-hub`, `/cob-proxy` to the matching
  application Service.
- `systemplaneIngress` (separate hostname) — admin/runtime-config traffic.
  Routes `/spi`, `/dict`, `/cob` to the matching `*-systemplane` Service.

Two hostnames keep the apps and systemplane traffic boundaries clean so
operators can layer different ingress annotations (auth, IP allowlist,
WAF) on each without coupling them.

The chart skips routes whose target component is disabled, so partial
deployments render only the path rules that have a backing Service.

No path rewriting is performed at the ingress — apps own their
`/<component>` path namespace. Application routing must register routes
under their prefix (e.g. SPI registers `/spi/health`, `/spi/keys/lookup`).

`adapter-btg-mock` keeps its own per-component `ingress` block and
template — it sits outside the apps/systemplane shared ingress design
because it is dev-only and operators may want to expose it
independently.

### Breaking changes from `1.1.0-beta.4`

- Removed: per-component `ingress:` blocks on the 9 production components
  (`.spi.ingress`, `.spiSystemplane.ingress`, `.dictHub.ingress`,
  `.dictHubVsync.ingress`, `.dictProxy.ingress`, `.dictSystemplane.ingress`,
  `.cobHub.ingress`, `.cobProxy.ingress`, `.cobSystemplane.ingress`). Any
  per-env values that set `<component>.ingress.enabled=true` on these are
  no longer honored — migrate to `appsIngress` / `systemplaneIngress`.
- Removed: 9 per-component `templates/<component>/ingress.yaml` files.
- `adapterBtgMock.ingress` is preserved unchanged.

## [1.1.0-beta.4] - envFrom order fix

Swap envFrom order on all 10 component deployment templates so
external-Secret values (DATABASE_URL, MONGO_URL, VALKEY_URL,
RABBITMQ_URI) override the chart's bundled-subchart ConfigMap defaults.
The previous order `[secretRef, configMapRef]` caused the ConfigMap to
win, silently dropping every Vault-injected URL override.

## [1.1.0-beta.3] - DEPLOYMENT_MODE default to byoc

Switch the chart-wide default for `DEPLOYMENT_MODE` from `local` to
`byoc` on all 10 component blocks. byoc triggers production license
enforcement; operators opt back into `local` explicitly for dev/CI
installs without a license.

## [1.1.0-beta.2] - Multi-component refactor + bootstrap Jobs + subchart wiring

The chart now deploys all 10 independently-built components of the
plugin-br-pix-switch app, each with its own Deployment, Service, ConfigMap,
Secret, ServiceAccount, HPA, PDB, and optional Ingress.

The prior `1.x-beta.1` chart never produced a working deployment (its
single-binary `pixSwitch` block emitted env vars the app source never reads,
e.g. `DB_HOST`/`DB_PORT`/... while the source reads `DATABASE_URL`). Because
no prior tag was ever functional, this release continues the 1.x line
instead of jumping to 2.0; consumers who tried 1.x cannot have a working
deployment to migrate from.

### Components (10 binaries, 10 Deployments)

- `spi` (port 4101) — PIX SPI service
- `spi-systemplane` (port 4102) — runtime config plane for SPI
- `adapter-btg-mock` (port 4103) — BTG provider mock (disabled by default)
- `dict-hub` (port 4104) — DICT hub
- `dict-hub-vsync` (port 4105) — DICT verification sync worker
- `dict-proxy` (port 4106) — DICT proxy to BCB
- `dict-systemplane` (port 4107) — runtime config plane for DICT
- `cob-hub` (port 4108) — COB hub
- `cob-proxy` (port 4109) — COB proxy to BCB
- `cob-systemplane` (port 4110) — runtime config plane for COB

Ports allocated in the 41xx range to avoid conflicts with the org port
allocation table (4001–4013 is used by Identity, Fees, CRM, Reporter, etc.).

### Bootstrap Jobs

Optional database bootstrap Jobs (gated by
`global.externalPostgresDefinitions.enabled` and
`global.externalMongoDefinitions.enabled`, both `false` by default):

- `bootstrap-postgres-pix-spi` — creates `pix-spi` database + `pixswitch` role
- `bootstrap-postgres-pix-dict` — creates `pix-dict` database + grants
- `bootstrap-postgres-pix-cob` — creates `pix-cob` database + grants
- `bootstrap-mongodb` — creates the `pixswitch` Mongo user with `readWrite`
  on `pix-dict` and `pix-cob` databases

Each Job is idempotent (skips when the role/database/user already exists).

### Subchart dependencies (all disabled by default)

| Subchart | Used by |
|---|---|
| postgresql (Bitnami 16.3) | 7 components (DATABASE_URL) |
| valkey (Bitnami 2.4.7) | spi, dict-hub, dict-hub-vsync (optional cache) |
| mongodb (Bitnami 16.4) | dict-hub only |
| rabbitmq (groundhog2k 2.1.11) | dict-hub-vsync only |

Default credentials (`pixswitch` / `lerian`) feed the URL defaults in each
component's configmap block so a fresh `helm install --set
<subchart>.enabled=true` works out of the box. Production deployments
disable the subcharts and provide URLs via an external Kubernetes Secret
(see values.yaml header for the override pattern).

### Other features

- `wait-for-dependencies` init container parses each component's URL env
  vars (DATABASE_URL / MONGO_URL / VALKEY_URL / RABBITMQ_URI) and waits
  for each TCP endpoint to be reachable. Skips dependencies that aren't
  configured for that component.
- Per-component `command` / `args` overrides so a single multi-binary
  image (when the source repo publishes one) can run different binaries
  per Deployment.
- `OTEL_RESOURCE_SERVICE_VERSION` auto-derived from the deployed image
  tag (component > global > Chart.AppVersion).
- When `TELEMETRY_ENABLED=true`, each pod injects `HOST_IP` via downward
  API and points `OTEL_EXPORTER_OTLP_ENDPOINT` at `$(HOST_IP):4317` for
  node-local OTel collectors. Operators can override the endpoint via
  the component's configmap for external collectors.
- `livenessProbe.path` defaults to `/health` (matches what the pix-switch
  binaries actually serve).

### Migration

No usable 1.0.x / 1.1.0-beta.1 deployment exists today (env-var mismatch).
Operators who tried earlier versions should:

1. Rewrite values to the new shape (per-component blocks: `spi:`, `dictHub:`,
   etc.) using `values-template.yaml` as a starting point.
2. Provision 3 Postgres databases (`pix-spi`, `pix-dict`, `pix-cob`) and a
   `pixswitch` role — or let the bootstrap Jobs do it via
   `global.externalPostgresDefinitions.enabled=true`.
3. Provision MongoDB databases for `dict-hub` (and optionally `cob-hub`).
4. Configure Valkey (optional, for caching) and RabbitMQ (required only for
   `dict-hub-vsync`).
5. Deploy with `installed: true` in helmfile.

Pattern adapted from `helm/charts/plugin-access-manager` and
`helm/charts/midaz` multi-component layouts.

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-switch-v1.0.0)

- **Features**
  - Added Helm chart for plugin-br-pix-switch.

- **Fixes**
  - Addressed CodeRabbit feedback on NOTES, README, configmap, and labeler.
  - Corrected appVersion to 1.0.0-beta.1 and updated the compatibility matrix.
  - Applied container securityContext, fixed tolerations type, and added NOTES defaults.

Contributors: @bedatty, @lerian-studio

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-pix-switch-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-switch-v1.0.0)

- **Features:**
  - Added Helm chart for plugin-br-pix-switch.

- **Fixes:**
  - Addressed CodeRabbit feedback on NOTES, README, configmap, and labeler.
  - Corrected appVersion to 1.0.0-beta.1 and updated the compatibility matrix.
  - Applied container securityContext, fixed tolerations type, and added NOTES defaults.

Contributors: @bedatty, @lerian-studio

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-pix-switch-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-switch-v1.0.0)

- **Features**
  - Added Helm chart for plugin-br-pix-switch.

- **Fixes**
  - Addressed CodeRabbit feedback on NOTES, README, configmap, and labeler.
  - Corrected appVersion to 1.0.0-beta.1 and added it to the compatibility matrix.
  - Applied container securityContext, fixed tolerations type, and added NOTES defaults.

Contributors: @bedatty, @lerian-studio

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-pix-switch-v1.0.0)

---

## [1.0.0](https://github.com/LerianStudio/helm/releases/tag/plugin-br-pix-switch-v1.0.0)

- **Features:**
  - Added Helm chart for plugin-br-pix-switch.

- **Fixes:**
  - Addressed CodeRabbit feedback on NOTES, README, configmap, and labeler.
  - Corrected appVersion to 1.0.0-beta.1 and updated compatibility matrix.
  - Applied container securityContext, fixed tolerations type, and added NOTES defaults.

Contributors: @bedatty, @lerian-studio

[View all changes](https://github.com/LerianStudio/helm/commits/plugin-br-pix-switch-v1.0.0)

---

## [1.0.0] - 2026-03-27

### Added

- Initial chart release for plugin-br-pix-switch
- Single Go service deployment (HTTP port 4000, gRPC port 7001)
- PostgreSQL dependency (Bitnami subchart v16.3)
- Valkey dependency (Bitnami subchart v2.4.6)
- HPA, PDB, Ingress support
- OpenTelemetry integration
- Readiness and liveness probes

