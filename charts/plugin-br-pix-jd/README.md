# plugin-br-pix-jd

Helm chart for the Lerian Pix plugin for direct participants through JD: DICT keys and claims, Pix transactions, refunds and limits, QR codes, MED 2.0, Pix Automático, and indirect participants. The chart is published as `oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm`.

This README is the reference for installing and configuring the chart. The Pix plugin requires an Enterprise license.

## What the chart installs

- **API**: the payment service — a Deployment, a Service, a ConfigMap, a Secret and a PodDisruptionBudget, plus an optional HorizontalPodAutoscaler (`api.autoscaling.enabled`) and an optional Ingress (`api.ingress.enabled`). It listens on port `8080`. `/health`, `/readyz`, `/metrics` and `/version` answer without authentication.
- **Worker**: a Deployment that runs the scheduled jobs — transaction reconciliation, the MED pollers and the delivery to indirect participants. It has no Service and no Ingress. **Disabled by default**; without it, those jobs do not run. To run it, set `worker.enabled: true` and `worker.image.repository: ghcr.io/lerianstudio/plugin-br-pix-jd-worker`. The worker and API image tags may differ: a release that changes only one of them publishes only that image.
- **Migrations Job**: applies the database schema with the `ghcr.io/lerianstudio/plugin-br-pix-jd-migrations` image, before the API rolls out (`pre-install` / `pre-upgrade`). The service does not migrate the database on its own.
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
| `api.configmap.PLUGIN_AUTH_ENABLED` and `api.configmap.PLUGIN_AUTH_HOST` | `"true"` and the Access Manager address | `"false"` and empty | with `ENVIRONMENT_NAME=production`, the service does not start: production refuses authentication off, and authentication on needs the host |
| `api.configmap.JD_BASE_URL`, `api.configmap.MIDAZ_URL_ONBOARDING`, `api.configmap.MIDAZ_URL_TRANSACTION`, `api.configmap.CRM_URL` | URLs | empty | the plugin has no address for JD, Midaz or CRM |
| `api.secrets.JD_CLIENT_ID`, `api.secrets.JD_SECRET`, `api.secrets.MIDAZ_CLIENT_ID`, `api.secrets.MIDAZ_CLIENT_SECRET`, `api.secrets.CRM_CLIENT_ID`, `api.secrets.CRM_CLIENT_SECRET` | client IDs and secrets | empty | the plugin cannot authenticate to JD, Midaz or CRM. These keys are read **only** from `api.secrets`; the chart ignores them in `api.configmap` |

With `ENVIRONMENT_NAME=production`, never set `ALLOW_CORS_WILDCARD`, `ALLOW_RATELIMIT_FAIL_OPEN` or `IS_DEVELOPMENT`: the render fails, because the service refuses to start with them.

For the other variables the plugin reads, see [Environment variables](https://docs.lerian.studio/en/interfaces/pix-jd/pix-jd-environment-variables).

### `QRCODE_PUBLIC_BASE_URL`

The host where the plugin serves the signed payload of each dynamic QR code. Write the host only, for example `pix.example.com`.

- A value with `http://` or `https://` fails the render.
- JD caps the payload URL at 77 characters. The chart fails the render when `QRCODE_PUBLIC_BASE_URL` + `/` + `QRCODE_PAYLOAD_PATH` + `/` passes **51 characters**.
- With the default `QRCODE_PAYLOAD_PATH`, `qr`, the host can have **at most 47 characters**.

## Optional values

Set these only when your institution needs them.

| Key | When | Format | Default |
| :-- | :--- | :----- | :------ |
| `api.secrets.REDIS_PASSWORD` | only if your Valkey or Redis requires a password | password | empty |
| `api.cors.allowedOrigins` | only if a browser calls the API directly | list of origins | empty: every browser cross-origin call is refused |
| `api.rateLimit.*` | only to change the rate-limit defaults | see `values.yaml` | chart defaults |
| `api.secrets.INDIRECTS_DELIVERY_ENCRYPTION_KEY` | only if this deployment hosts indirect participants | exactly 64 hex characters | empty |
| `api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY` | only if JD requires signed payment orders for your institution | PEM private key | empty |
| `api.secrets.JD_PAYMENT_SIGNING_CERTIFICATE` | only if JD requires signed payment orders for your institution | PEM certificate registered at JD | empty |
| `api.configmap.JD_PAYMENT_SIGNING_ALGORITHM` | only if your key does not use the default algorithm | `ECDSA_P256_SHA256`, `ECDSA_P384_SHA384` or `RSA_PKCS1_SHA256` | empty, read as `ECDSA_P256_SHA256` |
| `api.configmap.IDP_DECLARATION_ENABLED` | only in a single-tenant install that should publish the plugin's permissions to the Access Manager at startup. Needs `PLUGIN_AUTH_ENABLED=true` and the three keys below; the render fails without them | `"true"` or `"false"` | `"false"` |
| `api.configmap.IDP_HOST` | only with `IDP_DECLARATION_ENABLED="true"` | Access Manager identity address, `http(s)://` URL without credentials | empty |
| `api.configmap.IDP_M2M_CLIENT_ID` | only with `IDP_DECLARATION_ENABLED="true"`; may be set in `api.secrets` instead | client ID of the plugin's M2M application in the Access Manager | empty |
| `api.secrets.IDP_M2M_CLIENT_SECRET` | only with `IDP_DECLARATION_ENABLED="true"` | client secret of that application | empty |

- **The encryption key** protects the delivery secret of each indirect participant. Create it with `openssl rand -hex 32`. The render fails on a value that is not 64 hex characters. See [Hosting indirect participants](https://docs.lerian.studio/en/interfaces/pix-jd/hosting-indirect-participants).
- **The signing key and the certificate go together: set both or neither.** With only one, the render fails, because the plugin would refuse every payment order. With neither, the plugin sends unsigned orders, which a JD that does not require the signature accepts.
  - Register at JD **only the certificate**. The private key never leaves your environment: it goes only into `api.secrets.JD_PAYMENT_SIGNING_PRIVATE_KEY`.
  - `api.secrets.JD_PAYMENT_SIGNING_CERTIFICATE` must be **the same certificate** you registered at JD; JD refuses every order signed against a different one. Compare its SHA-1 fingerprint with the one JD shows: `openssl x509 -in payment-signing.crt -outform DER | shasum -a 1 | tr a-f A-F`.
  - Pass each file with `--set-file`, as the install example shows, or as a YAML block scalar (`|`). A set value without a `-----BEGIN` PEM header, or an algorithm outside the three above, fails the render.
  - To create the pair and register the certificate, see [Payment-order signing](https://docs.lerian.studio/en/interfaces/pix-jd/payment-order-signing).

### Secrets and `existingSecret`

Every value under `api.secrets` is sensitive. Keep it in a Kubernetes Secret, never in a values file in version control.

To use a Secret that you manage, set `api.existingSecret.name`. The chart then renders no Secret of its own and reads every secret key — `LICENSE_KEY`, `POSTGRES_PASSWORD`, `REDIS_PASSWORD`, the JD/Midaz/CRM credentials and the optional keys above — from that Secret. The chart does not check that Secret's content: to sign payment orders, it must carry both signing keys.

If you use argocd-vault-plugin, a `<path:...>` placeholder skips the chart's format checks, because the plugin substitutes it after Helm runs. The value in your vault must then hold the key in the right format — for a PEM, with real line breaks.

## Install

Pin the image in production with `api.image.tag`. Without it, the image follows the chart's `appVersion`, so a chart upgrade also changes the application version. Image tags have no leading `v`. The migrations image is pinned separately in `migrations.image.tag`.

A values file with the values above. Every value is a placeholder:

```yaml
api:
  image:
    tag: "1.2.4"
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

When you upgrade to app 1.2.1, `MULTI_TENANT_ALLOW_INSECURE_HTTP` is no longer read. If `MULTI_TENANT_URL` uses `http://`, set `api.configmap.ALLOW_INSECURE_TLS: "true"` instead.

Replace `<pix-release>` with your release name. A new install uses `plugin-br-pix-jd`; an existing install keeps its own name, such as `plugin-br-pix-direct-jd`. An install of the earlier `plugin-br-pix-direct-jd-helm` chart keeps its settings in a `pix:` block, which this chart rejects: rewrite that values file into the `api` and `worker` blocks before you use it with this chart.

```bash
helm upgrade <pix-release> \
  oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm \
  --version <new-version> -n midaz-plugins -f my-values.yaml
```

```bash
helm uninstall <pix-release> -n midaz-plugins
```

Per-version notes: [0.1](docs/UPGRADE-0.1.md) · [0.2](docs/UPGRADE-0.2.md) · [0.3](docs/UPGRADE-0.3.md) · [0.4](docs/UPGRADE-0.4.md) · [0.4.1](docs/UPGRADE-0.4.1.md) · [0.4.2](docs/UPGRADE-0.4.2.md) · [0.4.3](docs/UPGRADE-0.4.3.md) · [0.4.4](docs/UPGRADE-0.4.4.md) · [0.4.5](docs/UPGRADE-0.4.5.md) · [0.4.6](docs/UPGRADE-0.4.6.md) · [0.4.7](docs/UPGRADE-0.4.7.md) · [0.4.8](docs/UPGRADE-0.4.8.md) · [0.5.0](docs/UPGRADE-0.5.0.md).

## Chart Contract

- Chart type: `multi-component`
- Required secrets: `api.secrets.POSTGRES_PASSWORD` (the render fails without it) and `api.secrets.LICENSE_KEY`; the JD, Midaz and CRM client credentials for a working install. With `api.existingSecret.name`, all of them come from that Secret.
- Dependency notes: `lerian-common-helm` (library chart, renders nothing); `postgresql` (Bitnami `16.3.5`) and `valkey` (Bitnami `2.4.7`), both disabled by default — the chart expects an external PostgreSQL and Valkey or Redis.
- Production overrides: `api.image.tag`, `api.configmap.ENVIRONMENT_NAME=production`, `api.configmap.POSTGRES_SSLMODE`, `api.configmap.PLUGIN_AUTH_ENABLED` / `PLUGIN_AUTH_HOST`, `api.configmap.REDIS_HOST`, `api.existingSecret.name`, and `api.ingress.*`.
- Source/license: the plugin is closed source and requires an Enterprise license; this chart is published from [LerianStudio/helm](https://github.com/LerianStudio/helm).

## Values

See [`values.yaml`](values.yaml) for the annotated defaults and [`values-template.yaml`](values-template.yaml) for the values you provide.
