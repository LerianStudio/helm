# plugin-br-sisbajud (Helm chart)

## Chart Contract

- Chart type: `single-service`
- Required secrets: `LICENSE_KEY`, `MENSAGERIA_CLIENT_ID`, `MENSAGERIA_CLIENT_SECRET`, `EXECUTOR_HUB_WEBHOOK_SECRET` (webhook transport), the KMS credential (`VAULT_TOKEN` or `VAULT_APPROLE_SECRET_ID`; none for AWS KMS), `POSTGRES_PASSWORD` / `REDIS_PASSWORD` for external infra, plus an existing Secret with the Mensageria mTLS material (`ca.crt`, `tls.crt`, `tls.key`). The default render fails on purpose and names the first missing value.
- Dependency notes: PostgreSQL and Valkey ship as Bitnami subcharts, **disabled by default** and development-only. Production uses external, managed PostgreSQL and Redis/Valkey, a Vault Transit or AWS KMS, plugin-access-manager and the Sisbajud Mensageria (br-sfn).
- Production overrides: `global.datastores`, `global.kms`, `global.auth.host`, `sisbajud.mensageria.*`, `sisbajud.executor.*`, and `sisbajud.useExistingSecret` + `existingSecretName` (an existing Secret **replaces** the chart Secret; it is not merged).
- Source/license: chart source in [github.com/LerianStudio/helm](https://github.com/LerianStudio/helm) (Apache-2.0); application in [LerianStudio/plugin-br-sisbajud](https://github.com/LerianStudio/plugin-br-sisbajud).

## Overview

The SISBAJUD **executor**. One process that:

1. pulls judicial orders from the **Sisbajud Mensageria** over the execution contract (HTTPS, **mTLS mandatory**);
2. executes them on **Midaz** (block, unblock, transfer, information) using each institution's connector configuration, stored sealed in its database;
3. posts the results back to the Mensageria.

Notices arrive through the Streaming Hub **webhook** (default, own listener on `:9082`) or an **SQS** queue. The regulatory side (STA intake, return files, BACEN) is the Sisbajud Mensageria, a br-sfn rail — it is not part of this chart. This chart replaces `br-sisbajud` (deprecated).

| Resource | Notes |
|---|---|
| Deployment | `ghcr.io/lerianstudio/plugin-br-sisbajud`, HTTP API `:4029` (`/health`, `/readyz`), webhook `:9082` |
| Service / Service `-webhook` | ClusterIP; the webhook Service exposes only the listener |
| Ingress / Ingress `-webhook` | both optional; expose only the webhook path to the Streaming Hub |
| Job `-migrations` | `ghcr.io/lerianstudio/plugin-br-sisbajud-migrations`, pre-install/pre-upgrade hook (ArgoCD PreSync, wave -5) |
| ConfigMap / Secret | env; no credential is ever rendered in the ConfigMap |

## Install

```bash
kubectl create secret generic sisbajud-mensageria-mtls -n sisbajud \
  --from-file=ca.crt=mensageria-ca.pem --from-file=tls.crt=client.pem --from-file=tls.key=client-key.pem

helm install plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm \
  -n sisbajud -f my-values.yaml      # start from values-template.yaml
```

See [docs/00-getting-start.md](docs/00-getting-start.md) (pt-BR) / [docs/00-getting-start.en.md](docs/00-getting-start.en.md).

## Configuration

Precedence per env key: `sisbajud.configmap.<KEY>` > `sisbajud.<group>.<field>` > `sisbajud.datastores` / `sisbajud.kms` > `global.<block>` > `global.cloud` preset > chart default.

| Values | Env | Notes |
|---|---|---|
| `sisbajud.mensageria.baseUrl` | `MENSAGERIA_BASE_URL` | https; turns the process into the executor |
| `sisbajud.mensageria.tls.existingSecret` (+ `caKey`, `certKey`, `keyKey`, `mountPath`) | `MENSAGERIA_TLS_CA_FILE`, `MENSAGERIA_TLS_CLIENT_CERT_FILE`, `MENSAGERIA_TLS_CLIENT_KEY_FILE` | mounted read-only; the env vars carry **file paths** |
| `sisbajud.executor.m2mSubject` | `EXECUTOR_M2M_SUBJECT` | `sub` of the executor M2M token |
| `sisbajud.secrets.MENSAGERIA_CLIENT_ID/SECRET` | same | minted at `PLUGIN_AUTH_HOST` |
| `sisbajud.executor.heartbeatEvery` / `responseDeadlineMargin` | `EXECUTOR_HEARTBEAT_EVERY` / `RESPONSE_DEADLINE_MARGIN` | required; margin = same value as the Mensageria |
| `sisbajud.executor.transport` | `EXECUTOR_TRANSPORT` | `webhook` (default) or `sqs` |
| `sisbajud.executor.webhook.*` | `EXECUTOR_HUB_WEBHOOK_*` | outside `DEPLOYMENT_MODE=local`: `tls.existingSecret` or `upstreamTlsValidated: true` |
| `sisbajud.executor.sqs.*` | `EXECUTOR_SQS_*` | needs AWS credentials (IRSA annotation or `aws.rolesAnywhere`) |
| `global.kms.*` | `KMS_PROVIDER`, `VAULT_*`, `AWS_REGION` | `vault` or `aws`; the app has no in-memory provider |
| `global.datastores.postgres/redis` | `POSTGRES_*`, `REDIS_*` | `REDIS_HOST` is rendered as `host:port` |
| `sisbajud.app.defaultTenantId` | `DEFAULT_TENANT_ID` | must be a UUID |
| `sisbajud.license.organizationIds` | `ORGANIZATION_IDS` | must be `global` |
| `global.auth.*` | `PLUGIN_AUTH_ENABLED`, `PLUGIN_AUTH_HOST` | |

`STREAMING_ENABLED` is pinned to `false`: executor mode starts no producer or consumer. `sisbajud.configmap` accepts only the executor's non-credential keys (`values.schema.json`); credentials go in `sisbajud.secrets` (emitted only when set) or the existing Secret.

## Known limitation: object-store readiness probe

The application (≤ `1.3.0-beta.2`) wires a SeaweedFS/S3 client in every mode and its `/readyz` gates on it; `SEAWEEDFS_S3_ENDPOINT` defaults to `http://localhost:8333` in code, so in executor mode the pod stays NotReady unless that endpoint answers. Executor mode never reads or writes objects. Until the app skips that probe in executor mode, point `sisbajud.configmap.SEAWEEDFS_S3_ENDPOINT` / `SEAWEEDFS_BUCKET` / `SEAWEEDFS_REGION` (and, if needed, `sisbajud.secrets.SEAWEEDFS_ACCESS_KEY` / `SEAWEEDFS_SECRET_KEY`) at a reachable S3 endpoint.

## Development profile

`postgresql.enabled=true` and `valkey.enabled=true` bundle plaintext infra for development: set `sisbajud.app.environmentName=development`; the app reads the subchart passwords via `secretKeyRef` and the schema is applied by a `migrations` initContainer in the app pod.

## Multi-tenant

`global.multiTenant.enabled=true` emits the `MULTI_TENANT_*` group and skips the migrations (per-tenant schemas are migrated outside the chart). The executor serves exactly one tenant: the webhook secret / SQS queue is single-tenant and the app refuses a fleet of more than one.
