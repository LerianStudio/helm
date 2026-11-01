# plugin-br-sisbajud (Helm chart)

## Chart Contract

- Chart type: `single-service`
- Required secrets: `LICENSE_KEY`, `MENSAGERIA_CLIENT_ID`, `MENSAGERIA_CLIENT_SECRET`, `EXECUTOR_HUB_WEBHOOK_SECRET` (webhook transport), the KMS credential (`VAULT_TOKEN` or `VAULT_APPROLE_SECRET_ID`; none for AWS KMS), `POSTGRES_PASSWORD` / `REDIS_PASSWORD` for external infra, plus, as existing Secrets, the Mensageria server CA (`ca.crt`; optional in one-way TLS) and, with mTLS only, the executor client pair (`tls.crt`, `tls.key`). The default render fails on purpose and names the first missing value.
- Dependency notes: PostgreSQL and Valkey ship as Bitnami subcharts, **disabled by default** and development-only. Production uses external, managed PostgreSQL and Redis/Valkey, a Vault Transit or AWS KMS, plugin-access-manager and the Sisbajud Mensageria (br-sfn).
- Production overrides: `global.datastores`, `global.kms`, `global.auth.host`, `sisbajud.mensageria.*`, `sisbajud.executor.*`, and `sisbajud.useExistingSecret` + `existingSecretName` (an existing Secret **replaces** the chart Secret; it is not merged).
- Source/license: chart source in [github.com/LerianStudio/helm](https://github.com/LerianStudio/helm) (Elastic License 2.0); application in [LerianStudio/plugin-br-sisbajud](https://github.com/LerianStudio/plugin-br-sisbajud).

## Overview

The SISBAJUD **executor**. One process that:

1. pulls judicial orders from the **Sisbajud Mensageria** over the execution contract (HTTPS always; **mTLS optional** via `sisbajud.mensageria.mtlsEnabled`, which must match the Mensageria's `SISBAJUD_EXECUTION_MTLS_ENABLED`);
2. executes them on **Midaz** (block, unblock, transfer, information) using each institution's connector configuration, stored sealed in its database;
3. posts the results back to the Mensageria.

Notices arrive through the Streaming Hub **webhook** (default, own listener on `:9082`) or an **SQS** queue. The regulatory side (STA intake, return files, BACEN) is the Sisbajud Mensageria, a br-sfn rail — it is not part of this chart. This chart replaces `br-sisbajud` (deprecated).

| Resource | Notes |
|---|---|
| Deployment | `ghcr.io/lerianstudio/plugin-br-sisbajud`, HTTP API `:4029` (liveness `/version`, readiness `/readyz`), webhook `:9082` |
| Service / Service `-webhook` | ClusterIP; the webhook Service exposes only the listener |
| Ingress / Ingress `-webhook` | both optional; expose only the webhook path to the Streaming Hub |
| Job `-migrations` | `ghcr.io/lerianstudio/plugin-br-sisbajud-migrations`, pre-install/pre-upgrade hook (ArgoCD PreSync, wave -5) |
| ConfigMap / Secret | env; no credential is ever rendered in the ConfigMap |

## Install

```bash
kubectl create secret generic sisbajud-mensageria-ca -n sisbajud --from-file=ca.crt=mensageria-ca.pem
# mTLS only (sisbajud.mensageria.mtlsEnabled: true):
kubectl create secret tls sisbajud-mensageria-client -n sisbajud --cert=client.pem --key=client-key.pem

helm install plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm \
  -n sisbajud -f my-values.yaml      # start from values-template.yaml
```

See [docs/00-getting-start.md](docs/00-getting-start.md) (pt-BR) / [docs/00-getting-start.en.md](docs/00-getting-start.en.md).

## Configuration

Precedence per env key: `sisbajud.configmap.<KEY>` > `sisbajud.<group>.<field>` > `sisbajud.datastores` / `sisbajud.kms` > `global.<block>` > `global.cloud` preset > chart default.

| Values | Env | Notes |
|---|---|---|
| `sisbajud.mensageria.baseUrl` | `MENSAGERIA_BASE_URL` | https; turns the process into the executor (Mensageria mode) |
| `sisbajud.executor.enabled` | `EXECUTOR_ENABLED` | `""` (default, not emitted) \| `true` \| `false`. `true` without `mensageria.baseUrl` = DIRECT-only executor (see below); `false` never turns a configured Mensageria off |
| `sisbajud.mensageria.mtlsEnabled` | `MENSAGERIA_MTLS_ENABLED` | `false` (one-way TLS). `true` requires the CA and the client pair. Must match the Mensageria |
| `sisbajud.mensageria.ca.existingSecret` (+ `key`, `mountPath`) | `MENSAGERIA_TLS_CA_FILE` | server CA, mounted at `<mountPath>/ca.crt`. Optional in one-way TLS (empty = system trust store); empty falls back to `tls.existingSecret` + `tls.caKey` |
| `sisbajud.mensageria.tls.existingSecret` (+ `certKey`, `keyKey`, `mountPath`) | `MENSAGERIA_TLS_CLIENT_CERT_FILE`, `MENSAGERIA_TLS_CLIENT_KEY_FILE` | client pair, mounted (at `<mountPath>/tls.crt`, `tls.key`) and emitted **only with mTLS** |
| `sisbajud.license.isDevelopment` | `IS_DEVELOPMENT` | `"true"` routes the license check to the dev gateway (dev-issued keys) |
| `sisbajud.executor.m2mSubject` | `EXECUTOR_M2M_SUBJECT` | `sub` of the executor M2M token |
| `sisbajud.executor.streamingHubTenantId` | `STREAMING_HUB_TENANT_ID` | required; same value as the Streaming Hub deployment |
| `sisbajud.secrets.MENSAGERIA_CLIENT_ID/SECRET` | same | minted at `PLUGIN_AUTH_HOST` |
| `sisbajud.executor.heartbeatEvery` / `responseDeadlineMargin` | `EXECUTOR_HEARTBEAT_EVERY` / `RESPONSE_DEADLINE_MARGIN` | required; margin = same value as the Mensageria |
| `sisbajud.executor.transport` | `EXECUTOR_TRANSPORT` | `webhook` (default) or `sqs` |
| `sisbajud.executor.webhook.*` | `EXECUTOR_HUB_WEBHOOK_*` | outside `DEPLOYMENT_MODE=local`: `tls.existingSecret` or `upstreamTlsValidated: true` |
| `sisbajud.executor.sqs.*` | `EXECUTOR_SQS_*` | needs AWS credentials (IRSA annotation or `aws.rolesAnywhere`) |
| `sisbajud.executor.webhook.maxHandleAttempts` | `EXECUTOR_HUB_WEBHOOK_MAX_HANDLE_ATTEMPTS` | `5`; also the direct drainer's attempt cap in every executor mode (>= 1 + ceil(settleWindow / tickEvery)) |
| `sisbajud.executor.resultMaxAttempts` | `EXECUTOR_RESULT_MAX_ATTEMPTS` | `12`; result drainer cap per row (`0` = app default) |
| `sisbajud.executor.direct.drainerInfraAlarmThreshold` | `EXECUTOR_DIRECT_DRAINER_INFRA_ALARM_THRESHOLD` | `3`; integer >= 1 |
| `sisbajud.executor.direct.purgeEligibleAlarmAfter` | `EXECUTOR_DIRECT_PURGE_ELIGIBLE_ALARM_AFTER` | `168h`; Go duration > 0. The plugin never purges the direct intake |
| `sisbajud.direct.permanentBlockEnabled` | `DIRECT_PERMANENT_BLOCK_ENABLED` | **`false`** (keep it): the direct POST refuses permanent blocks with 422 SBJ-0027. Only `true`/`false` |
| `global.kms.*` | `KMS_PROVIDER`, `VAULT_*`, `AWS_REGION`, `KMS_AWS_KEY_MODE`, `KMS_AWS_KEY_ARN`, `KMS_AWS_CREDENTIALS_KEY_ARN` | `vault` or `aws`; the app has no in-memory provider. With `aws`: `awsRegion`, `awsKeyMode`, `awsKeyArn`, `awsCredentialsKeyArn` |
| `sisbajud.kms.awsKeyMode` | `KMS_AWS_KEY_MODE` | `managed` or `provided`; required with `KMS_PROVIDER=aws` |
| `sisbajud.kms.awsKeyArn` | `KMS_AWS_KEY_ARN` | `provided`: required; `managed`: must be empty |
| `sisbajud.kms.awsCredentialsKeyArn` | `KMS_AWS_CREDENTIALS_KEY_ARN` | `provided`: required and distinct from `awsKeyArn`; `managed`: must be empty |
| `sisbajud.kms.allowUnverifiableImageTag` | none (render-time acknowledgement) | unset (`true` confirms an `image.tag` the chart cannot verify (any tag outside the canonical form `vX.Y.Z[-(alpha|beta|rc).N]`) is `>= 1.1.0-beta.1`) |
| `sisbajud.vault.awsKmsTimeoutSec` | `KMS_AWS_TIMEOUT_SEC` | optional; whole seconds, 1..600; emitted only with `KMS_PROVIDER=aws` |
| `sisbajud.vault.awsKmsRotationCheckIntervalSec` | `KMS_AWS_ROTATION_CHECK_INTERVAL_SEC` | optional; whole seconds, 1..86400; emitted only with `KMS_PROVIDER=aws` |
| `global.datastores.postgres/redis` | `POSTGRES_*`, `REDIS_*` | `REDIS_HOST` is rendered as `host:port` |
| `sisbajud.app.defaultTenantId` | `DEFAULT_TENANT_ID` | must be a UUID |
| `sisbajud.license.organizationIds` | `ORGANIZATION_IDS` | must be `global` |
| `global.auth.*` | `PLUGIN_AUTH_ENABLED`, `PLUGIN_AUTH_HOST` | |

Liveness probes `/version` (static build info, always 200): the app's `/health` stays 503 until its startup self-probe passes, and that self-probe stays degraded while no institution is routed, so a fresh install would be restarted in a loop. Readiness stays on `/readyz`.

`VAULT_ADDR` and `MENSAGERIA_BASE_URL` must be https (`VAULT_ADDR` may be http only for a loopback host or `ENVIRONMENT_NAME` `local|development|test`); argocd-vault-plugin placeholders (`<path:...>`) are not checked at render.

`STREAMING_ENABLED` is pinned to `false`: executor mode starts no producer or consumer. `sisbajud.configmap` accepts only the executor's non-credential keys (`values.schema.json`); credentials go in `sisbajud.secrets` (emitted only when set) or the existing Secret.

**AWS KMS key mode.** With `KMS_PROVIDER=aws` the key mode is now required: set `sisbajud.kms.awsKeyMode` (or `global.kms.awsKeyMode`); `provided` needs both `awsKeyArn` and `awsCredentialsKeyArn`, and they must differ; `managed` needs both empty (the app creates and owns the keys). `awsKmsTimeoutSec` and `awsKmsRotationCheckIntervalSec` are validated in every aws mode. The mode and both ARNs are trimmed both for validation and in the ConfigMap; `awsKmsTimeoutSec` and `awsKmsRotationCheckIntervalSec` are validated after trimming but rendered as set (the app trims them at boot). `"+30"` is refused at render although the app accepts it (deliberately stricter).

- `KMS_AWS_*` enter only via `sisbajud.kms.*` / `sisbajud.vault.*` (or `global.kms.*`); the `sisbajud.configmap` key enum (`values.schema.json`) rejects them.
- `aws` is single-tenant (BYOC) only: the render fails with multi-tenant enabled (the app refuses it).
- `sisbajud.extraEnvVars` entries are container env and override the ConfigMap, but they are not validated at render: a `MULTI_TENANT_ENABLED` or `KMS_AWS_*` set there (including `KMS_PROVIDER=aws`, or an image whose tag the gate never sees) bypasses the checks above, and only the app's boot validation refuses an invalid combination.
- The distinct-ARN check is a textual comparison: an alias and the ARN of the same key pass the render and are only caught by the app.
- Minimum image: `plugin-br-sisbajud-v1.1.0-beta.1` (chart value `sisbajud.image.tag >= 1.1.0-beta.1`). Older images (such as `1.0.0`) ignore the key mode and create their own KMS key, so the chart fails the render on them.
- Only a tag in the canonical form `^v?X.Y.Z(-(alpha|beta|rc).N)?$` is verifiable (e.g. `1.1.0-beta.1`, `v1.2.0`, `1.2.0-rc.2`); it is compared with the minimum. Every other tag fails closed unless `sisbajud.kms.allowUnverifiableImageTag: true`: non-SemVer (`latest`, mirror tags), other suffixes such as arch tags (`1.1.0-beta.1-amd64`, `1.2.0-beta1`) and build metadata (`1.2.0+build.5`), even when the version part is above the minimum. With the flag set such a tag passes without any version check, even one whose label is below the minimum (e.g. `1.1.0-beta.0-amd64`): the chart does not read the label of a non-canonical tag, so the acknowledgement is the operator's word that the image has key modes. This flag is per chart only: setting it under `global.kms` has no effect.
- A tag containing `@` (`tag@digest` or digest-only) also requires `sisbajud.kms.allowUnverifiableImageTag: true`, even when the tag part is canonical: the kubelet pulls by digest, so the label cannot be verified against the minimum. With the flag set no version check is made. A canonical tag below the minimum fails even with the flag.
- A digest-only tag (`image.tag: "@sha256:…"`) is not supported by this chart's image template: it renders `repo:@sha256:…`, which the kubelet rejects.
- This is the first gate in this repo that treats `@` as a signal: other charts' minimum-version gates strip the digest or fail open on it. The deviation is deliberate (DR-04).
- Residual: a mutable SemVer tag re-pushed in a mirror is still only a label; the chart cannot detect it.
- AWS credentials come via IRSA (`serviceAccount` annotations) or this chart's `aws.rolesAnywhere` block; this chart has no `secretRefs`.

## DIRECT-only executor (no Mensageria)

`sisbajud.executor.enabled: "true"` with an empty `sisbajud.mensageria.baseUrl` boots the executor without the Sisbajud Mensageria. The chart then requires only `executor.m2mSubject`, `responseDeadlineMargin`, `heartbeatEvery`, `tickEvery` (plus the license, KMS, PostgreSQL, Redis, `PLUGIN_AUTH_HOST` and `global.auth.enabled: true`: the direct channel is served only with inbound auth on, and the render fails without it). It emits no `EXECUTOR_TRANSPORT` / Hub webhook / SQS keys except `EXECUTOR_HUB_WEBHOOK_MAX_HANDLE_ATTEMPTS` (the direct drainer cap), renders no webhook Service, Ingress or container port, and does not require `MENSAGERIA_CLIENT_ID/SECRET`, `EXECUTOR_HUB_WEBHOOK_SECRET` or `STREAMING_HUB_TENANT_ID`. Direct orders arrive on `POST /v1/institutions/{institutionId}/executor/...` (opt-in per institution). Operations: the application's `docs/runbooks/direct-channel-operations.md`.

Existing Mensageria installs are unchanged: with `executor.enabled` unset the `EXECUTOR_ENABLED` key is not emitted; the chart adds only the four direct-channel knobs above at the app defaults.

## Midaz CRM mode

`sisbajud.midaz.crmMode` (`MIDAZ_CRM_MODE`) must match the Midaz the institutions use; set it explicitly. The default stays `legacy` so an upgrade never changes an existing install.

| Midaz | `crmMode` |
|-------|-----------|
| v4 (CRM embedded in the ledger, no legacy `/v1/holders`) | `embedded` |
| v3 | `legacy` |

With the wrong mode every holder read fails.

## Known limitation: object-store readiness probe (app, B1)

The application (still in `1.0.0`) wires a SeaweedFS/S3 client in every mode and its `/readyz` gates on it; `SEAWEEDFS_S3_ENDPOINT` defaults to `http://localhost:8333` in code, so in executor mode the pod stays NotReady unless that endpoint answers. Executor mode never reads or writes objects. Until the app skips that probe in executor mode, point `sisbajud.configmap.SEAWEEDFS_S3_ENDPOINT` / `SEAWEEDFS_BUCKET` / `SEAWEEDFS_REGION` (and, if needed, `sisbajud.secrets.SEAWEEDFS_ACCESS_KEY` / `SEAWEEDFS_SECRET_KEY`) at a reachable S3 endpoint.

## Development profile

`postgresql.enabled=true` and `valkey.enabled=true` bundle plaintext infra for development: set `sisbajud.app.environmentName=development`; the app reads the subchart passwords via `secretKeyRef` and the schema is applied by a `migrations` initContainer in the app pod.

## Multi-tenant

`global.multiTenant.enabled=true` emits the `MULTI_TENANT_*` group and skips the migrations (per-tenant schemas are migrated outside the chart). The executor serves exactly one tenant: the webhook secret / SQS queue is single-tenant and the app refuses a fleet of more than one.
