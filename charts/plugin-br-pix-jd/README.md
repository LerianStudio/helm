# plugin-br-pix-jd

Helm chart for [`plugin-br-pix-jd`](https://github.com/LerianStudio/plugin-br-pix-jd) — the Lerian Bacen/JDPI Pix plugin: DICT keys and claims, SPI transactions, refunds and limits, QR codes, inbound JDPI webhooks, MED 2.0, Pix Automático, and indirect participants. It processes Pix instant payments as a direct participant. The chart is published as `oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm`.

This README is the reference for installing and configuring the chart. The Pix plugin requires an Enterprise license.

## What the chart installs

- **API**: the payment service — a Deployment, a Service, a ConfigMap, a Secret and a PodDisruptionBudget, plus an optional HorizontalPodAutoscaler (`api.autoscaling.enabled`) and an optional Ingress (`api.ingress.enabled`).
- **Worker**: a Deployment that runs the scheduled jobs (transaction reconciliation, the MED pollers, the indirect-delivery drainer). **Disabled by default.** To run it, set `worker.enabled: true` and point `worker.image.repository` at `ghcr.io/lerianstudio/plugin-br-pix-jd-worker`.
- **Migrations Job**: applies the database schema with the dedicated `plugin-br-pix-jd-migrations` image. The app does not migrate on boot. With an external PostgreSQL the Job runs before the API rolls out (`pre-install` / `pre-upgrade`).
- **PostgreSQL and Valkey subcharts**: bundled, and **both disabled by default**. The chart expects an external PostgreSQL and an external Valkey or Redis.

## Prerequisites

- A running Midaz deployment.
- The Access Manager chart `plugin-access-manager` at **9.5.10 or later**. Earlier versions do not grant the Pix roles the permission of the key lookup route, and that route answers `403`.
- Connectivity to the Brazilian payment infrastructure through the JD direct-participant channel.
- An Enterprise license key.
- Helm 3.8 or later, for OCI registry support.

## Values you must set

The chart **refuses to render** without these:

| Key | Format | Default | Without it |
| :-- | :----- | :------ | :--------- |
| `api.configmap.ENVIRONMENT_NAME` | `production`, `staging` or `development` | empty | the render fails. An empty value would run the service as a development environment, with every production security check off |
| `api.configmap.POSTGRES_HOST` | host of the external PostgreSQL | empty | the render fails |
| `api.secrets.POSTGRES_PASSWORD` | password of the external PostgreSQL | empty | the render fails. Or supply it through `api.existingSecret.name` |
| `api.configmap.REDIS_HOST` | `host:port` of the Valkey or Redis | empty | the render fails. The rate limiter is fail-closed: without Redis it refuses every request |

The chart **renders** without the values below, but the service does not work without them:

| Key | Format | Default | Without it |
| :-- | :----- | :------ | :--------- |
| `api.secrets.LICENSE_KEY` | your license key | empty | the service does not start. The worker reads the same key |
| `api.configmap.ORGANIZATION_IDS` | `global` | empty | the service does not start: the license check needs it |
| `api.configmap.SYSTEMPLANE_ENABLED` | `"true"` | `"false"` | the plugin does not mount its `/system` routes, and every configuration call of the setup answers `404` |
| `api.configmap.QRCODE_PUBLIC_BASE_URL` | a host, without a scheme | empty | with `ENVIRONMENT_NAME=production`, the service does not start |
| `api.configmap.POSTGRES_SSLMODE` | `require` or `verify-full` | `disable` | with `ENVIRONMENT_NAME=production`, the service does not start: production refuses `disable` |
| `api.configmap.PLUGIN_AUTH_ENABLED` and `api.configmap.PLUGIN_AUTH_HOST` | `"true"` and the Access Manager address | `"false"` and empty | with `ENVIRONMENT_NAME=production`, the service does not start: production refuses auth off, and auth on needs the host. Or set `global.auth.enabled` / `global.auth.host` |
| `api.configmap.JD_BASE_URL`, `api.configmap.MIDAZ_URL_ONBOARDING`, `api.configmap.MIDAZ_URL_TRANSACTION`, `api.configmap.CRM_URL` | URLs | empty | the plugin has no address for JD, Midaz or CRM |
| `api.secrets.JD_CLIENT_ID`, `api.secrets.JD_SECRET`, `api.secrets.MIDAZ_CLIENT_ID`, `api.secrets.MIDAZ_CLIENT_SECRET`, `api.secrets.CRM_CLIENT_ID`, `api.secrets.CRM_CLIENT_SECRET` | client IDs and secrets | empty | the plugin cannot authenticate to JD, Midaz or CRM. These keys are read **only** from `api.secrets`; the chart ignores them in `api.configmap` |

For the other variables the plugin reads, see [Environment variables](https://docs.lerian.studio/en/interfaces/pix-jd/pix-jd-environment-variables).

### `QRCODE_PUBLIC_BASE_URL`

The host where the plugin serves the signed payload of each dynamic QR code. Write the host only, for example `pix.example.com`.

- A value with `http://` or `https://` fails the render.
- JD caps the payload URL at 77 characters. The chart fails the render when `QRCODE_PUBLIC_BASE_URL` + `/` + `QRCODE_PAYLOAD_PATH` + `/` passes **51 characters** (42 with `MULTI_TENANT_ENABLED=true`).
- With the default `QRCODE_PAYLOAD_PATH`, `qr`, the host can have **at most 47 characters**.

## Optional values

Set these only when your institution needs them.

| Key | When | Format | Default |
| :-- | :--- | :----- | :------ |
| `api.secrets.INDIRECTS_DELIVERY_ENCRYPTION_KEY` | only if this deployment hosts indirect participants | exactly 64 hex characters | empty |
| `api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY` | only if JD requires signed payment orders | PEM private key | empty |
| `api.secrets.JD_PAYMENT_SIGNING_CERTIFICATE` | only if JD requires signed payment orders | PEM certificate registered at JD | empty |
| `api.configmap.JD_PAYMENT_SIGNING_ALGORITHM` | only if your key does not use the default algorithm | `ECDSA_P256_SHA256`, `ECDSA_P384_SHA384` or `RSA_PKCS1_SHA256` | empty, read as `ECDSA_P256_SHA256` |

- **The encryption key** protects the delivery secret of each indirect participant. Create it with `openssl rand -hex 32`. The render fails on a value that is not 64 hex characters. See [Hosting indirect participants](https://docs.lerian.studio/en/interfaces/pix-jd/hosting-indirect-participants).
- **The signing key and the certificate go together: set both or neither.** With only one, the render fails, because the plugin would refuse every payment order. With neither, the plugin sends unsigned orders. A set value without a `-----BEGIN` PEM header, or an algorithm outside the three above, also fails the render. Pass each file with `--set-file`. Details in [Payment-order signing](#payment-order-signing) below and in [Payment-order signing](https://docs.lerian.studio/en/interfaces/pix-jd/payment-order-signing).

### Secrets and `existingSecret`

Every value under `api.secrets` is sensitive. Keep it in a Kubernetes Secret, never in a values file in version control.

To use a Secret that you manage, set `api.existingSecret.name`. The chart then renders no Secret of its own and reads every secret key — `LICENSE_KEY`, `POSTGRES_PASSWORD`, the JD/Midaz/CRM credentials, and the optional keys above — from that Secret. The chart does not check that Secret's content: to sign payment orders, it must carry both signing keys.

## Install

A values file with the values above. Every value is a placeholder:

```yaml
api:
  configmap:
    ENVIRONMENT_NAME: "production"
    ORGANIZATION_IDS: "global"
    SYSTEMPLANE_ENABLED: "true"
    QRCODE_PUBLIC_BASE_URL: "pix.example.com"
    POSTGRES_HOST: "postgres.example.internal"
    POSTGRES_SSLMODE: "require"
    REDIS_HOST: "valkey.example.internal:6379"
    PLUGIN_AUTH_ENABLED: "true"
    PLUGIN_AUTH_HOST: "https://access-manager.example.internal"
    JD_BASE_URL: "https://jd.example.internal"
    MIDAZ_URL_ONBOARDING: "https://midaz-onboarding.example.internal"
    MIDAZ_URL_TRANSACTION: "https://midaz-transaction.example.internal"
    CRM_URL: "https://crm.example.internal"
  existingSecret:
    name: "plugin-br-pix-jd-secrets"
```

Read the current chart version, then install:

```bash
helm show chart oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm
```

```bash
helm install plugin-br-pix-jd \
  oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm \
  --version <version> -n midaz-plugins --create-namespace -f my-values.yaml
```

If JD requires signed payment orders and you do not use `api.existingSecret.name`, pass the two files in the same command:

```bash
helm install plugin-br-pix-jd \
  oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm \
  --version <version> -n midaz-plugins --create-namespace -f my-values.yaml \
  --set-file api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY=payment-signing.key \
  --set-file api.secrets.JD_PAYMENT_SIGNING_CERTIFICATE=payment-signing.crt
```

When the plugin answers its health probe (`/health`, `/readyz`), set up the product with [Setting up the rail](https://docs.lerian.studio/en/interfaces/pix-jd/pix-jd-setup).

## Upgrade and uninstall

Before you upgrade to app 1.1.0 or later (chart 0.4.8 or later), upgrade the Access Manager chart `plugin-access-manager` to 9.5.10 or later. Otherwise the key lookup route answers `403` after the upgrade.

Replace `<pix-release>` with your release name. A new install uses `plugin-br-pix-jd`; an existing install keeps its own name, such as `plugin-br-pix-direct-jd`. An install of the earlier `plugin-br-pix-direct-jd-helm` chart keeps its settings in a `pix:` block, which this chart rejects: rewrite that values file into the `api` and `worker` blocks before you use it with this chart.

```bash
helm upgrade <pix-release> \
  oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm \
  --version <new-version> -n midaz-plugins -f my-values.yaml
```

```bash
helm uninstall <pix-release> -n midaz-plugins
```

Per-version notes: [0.1](docs/UPGRADE-0.1.md) · [0.2](docs/UPGRADE-0.2.md) · [0.3](docs/UPGRADE-0.3.md) · [0.4](docs/UPGRADE-0.4.md) · [0.4.1](docs/UPGRADE-0.4.1.md) · [0.4.2](docs/UPGRADE-0.4.2.md) · [0.4.3](docs/UPGRADE-0.4.3.md) · [0.4.4](docs/UPGRADE-0.4.4.md) · [0.4.5](docs/UPGRADE-0.4.5.md) · [0.4.6](docs/UPGRADE-0.4.6.md) · [0.4.7](docs/UPGRADE-0.4.7.md) · [0.4.8](docs/UPGRADE-0.4.8.md) · [0.4.9](docs/UPGRADE-0.4.9.md).

---

## Chart Contract

- Chart type: `multi-component`
- Required secrets: `api.secrets.POSTGRES_PASSWORD` while PostgreSQL is external (the default) — the render fails without it. `api.secrets.LICENSE_KEY` — the api and the worker both validate the license at boot (the worker falls back to the api's key). The JD, Midaz and CRM client credentials in `api.secrets` for a working install. With `api.existingSecret.name`, all of them come from that Secret instead.
- Dependency notes: three dependencies. `lerian-common-helm` is the published library chart (`oci://ghcr.io/lerianstudio`, `2.1.2`) — it renders nothing and supplies the shared env and workload helpers. `postgresql` is the Bitnami subchart, pinned to `16.3.5`, **disabled by default** (`postgresql.enabled=false`, `postgresql.external=true`); enable it with `postgresql.enabled=true` and `postgresql.external=false`. A third, `valkey` (2.4.7, Bitnami), is gated on `valkey.enabled` and is also OFF by default, so every install that points `REDIS_HOST` at an external Valkey renders byte-identically.
- Production overrides: `api.image.tag`, `api.configmap.ENVIRONMENT_NAME=production`, `api.configmap.POSTGRES_SSLMODE` (production requires SSL), `api.configmap.REDIS_HOST`, `api.existingSecret.name` for operator-managed credentials, and `api.ingress.*`. Never set the `ALLOW_*` bypasses in production — the app fails its boot when they are present under `ENVIRONMENT_NAME=production`.
- AWS credentials (multi-tenant only — M2M resolves per-tenant Midaz/CRM/JD credentials from Secrets Manager at runtime). Two mutually exclusive options, chosen by cluster: on **EKS** use IRSA — set `serviceAccount.annotations["eks.amazonaws.com/role-arn"]` and leave `aws.rolesAnywhere.enabled=false`. **Anywhere else**, where IRSA does not exist, set `aws.rolesAnywhere.enabled=true` plus `trustAnchorArn` / `profileArn` / `roleArn`; the chart then adds an `aws-signing-helper` sidecar to both the api and the worker pods, mounts the client certificate read-only from `aws.rolesAnywhere.certificateSecretName` (default `<fullname>-iam-tls`, keys `tls.crt` / `tls.key`), and sets the pod `fsGroup` to 65532 so the sidecar can read it. The certificate is NOT created by this chart — provision it with cert-manager or equivalent. Never enable both paths.
- Deployment mode: `api.configmap.DEPLOYMENT_MODE` accepts `saas`, `byoc` or `local` (default empty, which the app reads as `local`). It is **independent of `ENVIRONMENT_NAME`** — both saas-staging and local-production are legitimate. `saas` turns ON the app's TLS enforcement over Postgres and Redis, plus the multi-tenant Redis and the tenant-manager URL when `MULTI_TENANT_ENABLED=true`; a plaintext endpoint then fails the boot naming the offending dependency. The chart validates the value at render time, because the app rejects an unrecognized one at boot and would CrashLoop instead.
- Source/license: [LerianStudio/plugin-br-pix-jd](https://github.com/LerianStudio/plugin-br-pix-jd). The plugin is closed source; this chart is published from [LerianStudio/helm](https://github.com/LerianStudio/helm).

## Before you install

**Pin `api.image.tag` in production.** The chart's `appVersion` is `1.1.1`, published to `ghcr.io/lerianstudio/plugin-br-pix-jd` — registry tags have no leading `v`. Riding `appVersion` means a chart bump changes the app version. The `1.x` line is newer than `2.0.1`: the plugin's tag history was reset and the release train restarted (see [the 0.4.6 upgrade notes](docs/UPGRADE-0.4.6.md)). Migrations are pinned independently, to `1.1.1`. See [the 0.4.9 upgrade notes](docs/UPGRADE-0.4.9.md).

**The `worker` component ships disabled.** Enable it with `worker.enabled=true` and point `worker.image.repository` at `ghcr.io/lerianstudio/plugin-br-pix-jd-worker`. Without the worker, transaction reconciliation, the MED pollers and the indirect-delivery drainer do not run.

**The app does not apply migrations on boot** — it reads `MIGRATIONS_PATH` and never calls `golang-migrate`. The chart therefore ships a segregated migration Job whose hook phase follows the datastore: `PostSync` for the bundled Postgres (provisioned during Sync, so the api briefly serves against an empty schema), `PreSync` for an external one (schema-first). The Job runs the dedicated `plugin-br-pix-jd-migrations` image (golang-migrate with the SQL baked in) — not the app image, which is distroless and has no shell. In multi-tenant mode the Tenant Manager owns per-tenant migrations and the chart SKIPS the Job automatically, reporting the skip in `NOTES.txt`; `migrations.enabled` does not need to be set.

## Components

| Component | Values key | Workload | Entry point | Notes |
|---|---|---|---|---|
| API | `api` | Deployment + Service (+ Ingress / HPA / PDB) | image default (`/service` = `cmd/app`) | Listens on `8080`. `/health`, `/readyz`, `/metrics`, `/version` are auth-exempt. |
| Worker | `worker` | Deployment | `/worker` (`cmd/worker`) | No Service, no Ingress, no HPA, no probes — it runs cron jobs, not a listener. Disabled by default. |

Each component has its own image: `plugin-br-pix-jd` (api) and `plugin-br-pix-jd-worker`. Point `worker.image.repository` at the latter and the chart stops overriding the command, since that image's own ENTRYPOINT is already `/worker`. Leaving it unset keeps the older single-image shape, where the api image carries both binaries. **Tags may differ between the two** — the release pipeline builds only the component that changed, so an api-only release legitimately leaves the worker a tag behind; the chart does not police this.

## Credentials

`POSTGRES_PASSWORD` is single-sourced. With the bundled subchart the password is generated into the subchart's own Secret and the container reads it through a `secretKeyRef`; the key is deliberately absent from this chart's Secret. Only on the external path does the operator supply it, and the chart fails the render with an actionable message rather than emitting an empty value.

`REDIS_PASSWORD` follows the identical rule with the bundled Valkey, with one difference worth knowing: the key in the subchart Secret is `valkey-password`, not `password`. Copying the Postgres wiring verbatim yields a `secretKeyRef` to a key that does not exist, and the pod starts with no password against a Valkey that requires AUTH.

## Payment-order signing

Optional. Set it only when the client's JD enforces signed payment orders (`JDPI_IF__HashAtivo=true`): such a JD refuses an order that does not carry the participant's signature (the `hash` group) with `JDPISPI017`. Without the values nothing changes: the api sends unsigned orders, as before, and a JD that does not enforce the signature accepts them.

| Value | Where it lands | Required |
|---|---|---|
| `api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY` | api Secret, `JD_PAYMENT_SIGNING_PRIVATE_KEY`, only when set | no — both or neither |
| `api.secrets.JD_PAYMENT_SIGNING_CERTIFICATE` | api Secret, `JD_PAYMENT_SIGNING_CERTIFICATE`, only when set | no — both or neither |
| `api.configmap.JD_PAYMENT_SIGNING_ALGORITHM` | api ConfigMap, only when set | no — empty means `ECDSA_P256_SHA256`; also `ECDSA_P384_SHA384`, `RSA_PKCS1_SHA256` |

- JDPI Cabine receives **only the public certificate** (PEM), as "Certificados Hash – Assinatura Payload". The private key never leaves your environment: it goes only into `api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY`.
- `api.secrets.JD_PAYMENT_SIGNING_CERTIFICATE` must be **the same certificate** registered in Cabine: the plugin derives each payment order's thumbprint from it, and JD refuses every order signed against a different one (`JDPISPI017`). Compare its SHA-1 fingerprint with Cabine's: `openssl x509 -in cert.pem -outform DER | shasum -a 1 | tr a-f A-F`.
- Both values are PEM. Pass the files with `--set-file api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY=key.pem --set-file api.secrets.JD_PAYMENT_SIGNING_CERTIFICATE=cert.pem`, or as YAML block scalars (`|`).
- The render FAILS, naming the value, when only one of the two is set (the app would refuse every order, `409 PIX-0136`), when a set value has no `-----BEGIN` PEM header, and when the algorithm is not one of the three accepted.
- With `api.existingSecret.name` the chart renders no Secret and does not check: to sign, that Secret must carry both keys.
- argocd-vault-plugin: `<path:secret/data/...#KEY>` works for both keys. The PEM check is skipped for a placeholder, since AVP substitutes it after Helm runs; the Vault value must hold the PEM with real line breaks.

## Rate limiting

The three-tier limiter is Redis-backed and **fail-closed by default**: an unreachable Redis rejects requests rather than degrading. `api.configmap.REDIS_HOST` is therefore required. Use the productized `api.rateLimit.*` knobs; raw `api.configmap.RATE_LIMIT_*` keys still work and take precedence.

## Values

See [`values.yaml`](values.yaml) for the annotated defaults and [`values-template.yaml`](values-template.yaml) for the operator-provided placeholders.
