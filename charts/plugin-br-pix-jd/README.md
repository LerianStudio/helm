# plugin-br-pix-jd

Helm chart for [`plugin-br-pix-jd`](https://github.com/LerianStudio/plugin-br-pix-jd) — the Lerian Bacen/JDPI Pix plugin: DICT keys and claims, SPI transactions, refunds and limits, QR codes, inbound JDPI webhooks, MED 2.0, Pix Automático, and indirect participants.

## Chart Contract

- Chart type: `multi-component`
- Required secrets: `worker.secrets.LICENSE_KEY` (or `api.secrets.LICENSE_KEY`, which it falls back to) — required only when the worker is enabled and `IS_DEVELOPMENT` is not true. The api does NOT validate a license. `api.secrets.POSTGRES_PASSWORD` only when the bundled Postgres is disabled or marked external. Everything else is optional at this chart version; the JD / Midaz / CRM / notification credentials land in a later phase of this chart's rollout.
- Dependency notes: two dependencies. `lerian-common-helm` is a **local library chart** (`file://../lerian-common`) — it renders nothing and supplies the shared env and workload helpers. `postgresql` is the Bitnami subchart, pinned to `16.3.5`, bundled by default and gated on `postgresql.enabled`; set `postgresql.enabled=false` or `postgresql.external=true` for an operator-provided datastore.
- Production overrides: `api.image.tag`, `api.configmap.ENVIRONMENT_NAME=production`, `api.configmap.POSTGRES_SSLMODE` (production requires SSL), `api.configmap.REDIS_HOST`, `api.existingSecret.name` for operator-managed credentials, and `api.ingress.*`. Never set the `ALLOW_*` bypasses in production — the app fails its boot when they are present under `ENVIRONMENT_NAME=production`.
- AWS credentials (multi-tenant only — M2M resolves per-tenant Midaz/CRM/JD credentials from Secrets Manager at runtime). Two mutually exclusive options, chosen by cluster: on **EKS** use IRSA — set `serviceAccount.annotations["eks.amazonaws.com/role-arn"]` and leave `aws.rolesAnywhere.enabled=false`. **Anywhere else**, where IRSA does not exist, set `aws.rolesAnywhere.enabled=true` plus `trustAnchorArn` / `profileArn` / `roleArn`; the chart then adds an `aws-signing-helper` sidecar to both the api and the worker pods, mounts the client certificate read-only from `aws.rolesAnywhere.certificateSecretName` (default `<fullname>-iam-tls`, keys `tls.crt` / `tls.key`), and sets the pod `fsGroup` to 65532 so the sidecar can read it. The certificate is NOT created by this chart — provision it with cert-manager or equivalent. Never enable both paths.
- Deployment mode: `api.configmap.DEPLOYMENT_MODE` accepts `saas`, `byoc` or `local` (default empty, which the app reads as `local`). It is **independent of `ENVIRONMENT_NAME`** — both saas-staging and local-production are legitimate. `saas` turns ON the app's TLS enforcement over Postgres and Redis, plus the multi-tenant Redis and the tenant-manager URL when `MULTI_TENANT_ENABLED=true`; a plaintext endpoint then fails the boot naming the offending dependency. The chart validates the value at render time, because the app rejects an unrecognized one at boot and would CrashLoop instead.
- Source/license: [LerianStudio/plugin-br-pix-jd](https://github.com/LerianStudio/plugin-br-pix-jd). The plugin is closed source; this chart is published from [LerianStudio/helm](https://github.com/LerianStudio/helm).

## Before you install

**Pin `api.image.tag` in production.** The chart's `appVersion` (`1.12.0-beta.8`) is the tag of the release train it was cut against, published to `ghcr.io/lerianstudio/plugin-br-pix-jd` — note the registry tag has no leading `v`. Riding `appVersion` means a chart bump silently changes the app version.

**The `worker` component ships disabled.** The production Dockerfile builds only `./cmd/app`, so the image carries no `/worker` binary. Until the app ships a build with both entry points (the pattern already present in its `Dockerfile.smoke`), enabling `worker` yields a CrashLoopBackOff — and transaction reconciliation, the MED pollers and the indirect-delivery drainer do not run.

**The app does not apply migrations on boot** — it reads `MIGRATIONS_PATH` and never calls `golang-migrate`. The chart therefore ships a segregated migration Job whose hook phase follows the datastore: `PostSync` for the bundled Postgres (provisioned during Sync, so the api briefly serves against an empty schema), `PreSync` for an external one (schema-first). In multi-tenant mode the Tenant Manager owns per-tenant migrations and the chart REFUSES `migrations.enabled=true`.

## Components

| Component | Values key | Workload | Entry point | Notes |
|---|---|---|---|---|
| API | `api` | Deployment + Service (+ Ingress / HPA / PDB) | image default (`/service` = `cmd/app`) | Listens on `8080`. `/health`, `/readyz`, `/metrics`, `/version` are auth-exempt. |
| Worker | `worker` | Deployment | `/worker` (`cmd/worker`) | No Service, no Ingress, no HPA, no probes — it runs cron jobs, not a listener. Disabled by default. |

Each component has its own image: `plugin-br-pix-jd` (api) and `plugin-br-pix-jd-worker`. Point `worker.image.repository` at the latter and the chart stops overriding the command, since that image's own ENTRYPOINT is already `/worker`. Leaving it unset keeps the older single-image shape, where the api image carries both binaries. **Tags may differ between the two** — the release pipeline builds only the component that changed, so an api-only release legitimately leaves the worker a tag behind; the chart does not police this.

## Credentials

`POSTGRES_PASSWORD` is single-sourced. With the bundled subchart the password is generated into the subchart's own Secret and the container reads it through a `secretKeyRef`; the key is deliberately absent from this chart's Secret. Only on the external path does the operator supply it, and the chart fails the render with an actionable message rather than emitting an empty value.

## Rate limiting

The three-tier limiter is Redis-backed and **fail-closed by default**: an unreachable Redis rejects requests rather than degrading. `api.configmap.REDIS_HOST` is therefore required. Use the productized `api.rateLimit.*` knobs; raw `api.configmap.RATE_LIMIT_*` keys still work and take precedence.

## Values

See [`values.yaml`](values.yaml) for the annotated defaults and [`values-template.yaml`](values-template.yaml) for the operator-provided placeholders.
