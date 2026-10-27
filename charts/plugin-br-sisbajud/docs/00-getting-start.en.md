# plugin-br-sisbajud — Getting started

> The SISBAJUD executor: pulls judicial orders from the **Sisbajud Mensageria** (br-sfn)
> over the execution contract (HTTPS always; **mTLS optional**, `sisbajud.mensageria.mtlsEnabled`, matching the Mensageria), executes them on **Midaz**
> (block, unblock, transfer, information) and posts the results back. Runs in the client's
> cluster next to Midaz (BYOC) or in Lerian Cloud.

## 1. Prerequisites

| Dependency | How the chart receives it |
|---|---|
| Sisbajud Mensageria (https URL) | `sisbajud.mensageria.baseUrl` |
| Mensageria server CA | `sisbajud.mensageria.ca.existingSecret` (key `ca.crt`); optional in one-way TLS (empty = system trust store), required with mTLS |
| Executor client pair (mTLS only) | `sisbajud.mensageria.mtlsEnabled: true` + `sisbajud.mensageria.tls.existingSecret` (keys `tls.crt`, `tls.key`), chained to the Mensageria client CA |
| Executor M2M client in plugin-access-manager | `sisbajud.executor.m2mSubject` (the token `sub`) + `MENSAGERIA_CLIENT_ID` / `MENSAGERIA_CLIENT_SECRET` in the Secret |
| plugin-access-manager | `global.auth.host` (the Mensageria token is minted there, even with inbound auth off) |
| License | `LICENSE_KEY` in the Secret; `ORGANIZATION_IDS` = `global` |
| KMS | `global.kms` — Vault Transit (`VAULT_TOKEN` or AppRole) or AWS KMS (`awsRegion` + `awsKeyMode` under `sisbajud.kms` or `global.kms`). `provided` needs `awsKeyArn` and `awsCredentialsKeyArn`, and they must differ; `managed` needs both empty. `sisbajud.vault.awsKmsTimeoutSec` (`1`..`600`) and `awsKmsRotationCheckIntervalSec` (`1`..`86400`) are optional and validated in every aws mode. AWS KMS with multi-tenant is refused. Minimum image `1.1.0-beta.1`: any non-canonical tag needs `sisbajud.kms.allowUnverifiableImageTag: true` (not read from `global.kms`). There is no in-memory provider |
| PostgreSQL (TLS) | `global.datastores.postgres` + `POSTGRES_PASSWORD` |
| Redis/Valkey | `global.datastores.redis` + `REDIS_PASSWORD` (`/readyz` depends on it) |
| Streaming Hub | webhook subscription: `EXECUTOR_HUB_WEBHOOK_SECRET` in the Secret; or `executor.transport: sqs` |
| Streaming Hub tenant | `sisbajud.executor.streamingHubTenantId` (required; same value as the Streaming Hub's `STREAMING_HUB_TENANT_ID`) |

Midaz routing and credentials are **per institution** (institution config API, sealed in the database), not chart values.

## 2. Install

```bash
kubectl create namespace sisbajud
kubectl -n sisbajud create secret generic sisbajud-mensageria-ca --from-file=ca.crt=mensageria-ca.pem
# mTLS only:
kubectl -n sisbajud create secret tls sisbajud-mensageria-client --cert=client.pem --key=client-key.pem

cp values-template.yaml my-values.yaml   # fill every <...>
helm install plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm -n sisbajud -f my-values.yaml
```

With the defaults alone the chart does **not** render: each missing required value fails the render and names the key to set.

Install/upgrade order: migration password Secret (hook -10) → Job `plugin-br-sisbajud-migrations` (hook -5, ArgoCD PreSync) → Deployment. A failed migration aborts the release before any workload changes.

## 3. Streaming Hub webhook

The listener runs on `:9082` (Service `plugin-br-sisbajud-webhook`). Expose only `sisbajud.executor.webhook.path` (`/v1/webhooks/hub`) through `sisbajud.executor.webhook.ingress`. Outside `DEPLOYMENT_MODE=local` it needs its own TLS (`webhook.tls.existingSecret`) **or** TLS terminated and validated in front (`webhook.upstreamTlsValidated: true`).

## 4. Verify

```bash
kubectl -n sisbajud get pods,jobs
kubectl -n sisbajud port-forward svc/plugin-br-sisbajud 4029:4029
curl -s localhost:4029/readyz | jq .
```

`/readyz` lists every dependency. Known application limitation (still in `1.0.0`): the object-store (`seaweedfs`) probe is wired in every mode and defaults to `http://localhost:8333`; in executor mode the pod stays NotReady until `SEAWEEDFS_S3_ENDPOINT` (via `sisbajud.configmap`) points at a reachable S3. See the chart README.

## 5. Development profile

`postgresql.enabled=true`, `valkey.enabled=true` and `sisbajud.app.environmentName=development`: bundled plaintext infra, passwords read from the subchart Secrets, schema applied by a `migrations` initContainer in the app pod. Not supported in production.
