# plugin-br-sisbajud — Getting started

> The SISBAJUD executor: pulls judicial orders from the **Sisbajud Mensageria** (br-sfn)
> over the execution contract (HTTPS, **mTLS mandatory**), executes them on **Midaz**
> (block, unblock, transfer, information) and posts the results back. Runs in the client's
> cluster next to Midaz (BYOC) or in Lerian Cloud.

## 1. Prerequisites

| Dependency | How the chart receives it |
|---|---|
| Sisbajud Mensageria (https URL) | `sisbajud.mensageria.baseUrl` |
| mTLS material (server CA + client cert/key) | existing Secret in `sisbajud.mensageria.tls.existingSecret` (keys `ca.crt`, `tls.crt`, `tls.key`) |
| Executor M2M client in plugin-access-manager | `sisbajud.executor.m2mSubject` (the token `sub`) + `MENSAGERIA_CLIENT_ID` / `MENSAGERIA_CLIENT_SECRET` in the Secret |
| plugin-access-manager | `global.auth.host` (the Mensageria token is minted there, even with inbound auth off) |
| License | `LICENSE_KEY` in the Secret; `ORGANIZATION_IDS` = `global` |
| KMS | `global.kms` — Vault Transit (`VAULT_TOKEN` or AppRole) or AWS KMS (`awsRegion`). There is no in-memory provider |
| PostgreSQL (TLS) | `global.datastores.postgres` + `POSTGRES_PASSWORD` |
| Redis/Valkey | `global.datastores.redis` + `REDIS_PASSWORD` (`/readyz` depends on it) |
| Streaming Hub | webhook subscription: `EXECUTOR_HUB_WEBHOOK_SECRET` in the Secret; or `executor.transport: sqs` |

Midaz routing and credentials are **per institution** (institution config API, sealed in the database), not chart values.

## 2. Install

```bash
kubectl create namespace sisbajud
kubectl -n sisbajud create secret generic sisbajud-mensageria-mtls \
  --from-file=ca.crt=mensageria-ca.pem --from-file=tls.crt=client.pem --from-file=tls.key=client-key.pem

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

`/readyz` lists every dependency. Known application limitation (≤ `1.0.0-beta.1`): the object-store (`seaweedfs`) probe is wired in every mode and defaults to `http://localhost:8333`; in executor mode the pod stays NotReady until `SEAWEEDFS_S3_ENDPOINT` (via `sisbajud.configmap`) points at a reachable S3. See the chart README.

## 5. Development profile

`postgresql.enabled=true`, `valkey.enabled=true` and `sisbajud.app.environmentName=development`: bundled plaintext infra, passwords read from the subchart Secrets, schema applied by a `migrations` initContainer in the app pod. Not supported in production.
