# br-sisbajud — Installation Runbook

> Filled in from the chart itself (`README.md`, `values.yaml`, `values-dev.yaml`,
> `values-dev-with-br-sta.yaml`, `values-template.yaml`, templates) and from a real
> install next to a br-sta dev bundle on an isolated minikube (6 CPU / 7 GB). Goal:
> someone outside the squad, with only the chart and this runbook, can install a
> working release and knows what to check if something does not behave as expected.

---

## 0. Metadata

| Field | Value |
|---|---|
| Product / Chart | `br-sisbajud-helm` (releases as **1.2.0**) / app **1.1.0** |
| Components | one Go binary (HTTP API `:4029` + background workers), migrations Job, topics Job |
| Images | `ghcr.io/lerianstudio/br-sisbajud`, `br-sisbajud-migrations`, `br-sisbajud-topics` (all private on GHCR) |
| Upgrade guide | coming from chart 1.1.x: [`UPGRADE-1.2.md`](UPGRADE-1.2.md) |
| Last review of this runbook | 2026-09-30, against chart 1.2.0 / app 1.1.0 |
| Escalation contact | SISBAJUD squad (see chart CODEOWNERS) |

---

## 1. Installation profiles

| Profile | Values | What runs | Use case |
|---|---|---|---|
| **Dev bundle (quickstart)** | `values-dev.yaml` | the app, plus bundled PostgreSQL, Valkey, SeaweedFS (S3), OpenBao (Vault Transit, dev mode) and Redpanda; `ENVIRONMENT_NAME=development`; inbound auth, the br-sta consumer/transfers client and multi-tenancy off | Evaluation, local development, chart testing |
| **br-sisbajud + br-sta together** | `values-dev.yaml` + `values-dev-with-br-sta.yaml` | the app with its own PostgreSQL, Valkey and OpenBao, reusing a br-sta dev bundle's SeaweedFS and Redpanda in the same namespace; br-sta consumer and transfers client on | Integrated dev of the STA flow (remittance intake, return files) |
| **Production / external infra** | your file, started from `values-template.yaml` | the app + migrations + topics Jobs; every dependency external | Real tiers. Default environment `production` (fail-closed) |

Chart defaults alone do not render: the environment defaults to `production`, so the
chart fails fast until the external connections and secrets are set (section 5).

---

## 2. External dependencies

| Dependency | When it's needed | How the chart receives it |
|---|---|---|
| PostgreSQL | Always (single-tenant: the host is required) | `global.datastores.postgres` + `brSisbajud.secrets.POSTGRES_PASSWORD` |
| Valkey / Redis | Always (rate limit, idempotency, processing locks) | `global.datastores.redis` (`host:port`) + `brSisbajud.secrets.REDIS_PASSWORD` |
| Kafka / Redpanda | Streaming is on by default (lib-streaming producer/consumers, Midaz balance translator, br-sta facts) | `global.streaming` + `brSisbajud.secrets.STREAMING_SASL_PASSWORD` / `STREAMING_TLS_CA_CERT` |
| HashiCorp Vault Transit **or** AWS KMS | Always (envelope encryption of court-ordered seizure data) | `global.kms` + `brSisbajud.secrets.VAULT_APPROLE_SECRET_ID` (or `VAULT_TOKEN`) |
| S3-compatible object storage | Always (encrypted seizure artifacts + the br-sta transfer bucket) | `global.objectStorage.sisbajud` / `.sta` + `SEAWEEDFS_ACCESS_KEY` / `SEAWEEDFS_SECRET_KEY` |
| br-sta | Remittance intake (business facts on `lerian.streaming.br-sta`) and return-file submission (`POST /v1/transfers`) | `brSisbajud.sta.*`, `global.objectStorage.sta` (the same block br-sta reads) |
| plugin-access-manager | Inbound JWT validation, the STA m2m bearer, permission declaration | `global.auth`, `brSisbajud.identity` |
| Midaz ledger stream | Balance-change trigger (`lerian.streaming.ledger`, created by Midaz) | `brSisbajud.midaz.balanceTopic` |
| Lerian license gateway | Production (`LICENSE_KEY`); the pod needs egress to it | `brSisbajud.secrets.LICENSE_KEY`, `brSisbajud.license.organizationIds` (`global`) |
| Tenant manager | Only with multi-tenancy | `global.multiTenant` + `MULTI_TENANT_SERVICE_API_KEY` |

The Midaz ledger and CRM connectors are not configured through the chart: seed one
institution per tenant through the admin API (`POST /v1/institutions`) before orders
can execute.

---

## 3. Installation order

### Dev bundle

```bash
kubectl create namespace sisb-dev
kubectl -n sisb-dev create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io --docker-username=<github-user> --docker-password=<GHCR_READ_TOKEN>

helm install br-sisbajud charts/br-sisbajud -n sisb-dev \
  -f charts/br-sisbajud/values-dev.yaml \
  --set-json 'imagePullSecrets=[{"name":"ghcr-pull"}]'
```

Top-level `imagePullSecrets` covers the app, migrations, topics and bucket pods. With
the bundled dependencies the app pod runs idempotent initContainers (migrations,
wait-for-broker, topics, Transit mount) before it starts, so it never boots on a
missing schema, topics or Transit mount.

### br-sisbajud + br-sta together (proved on minikube)

```bash
# 1. br-sta dev bundle, with br-sisbajud's own bucket added to its bucket Job
helm install br-sta charts/br-sta -n sisb-dev -f charts/br-sta/values-dev.yaml \
  --set-json 'imagePullSecrets=[{"name":"ghcr-pull"}]' \
  --set-json 'seaweedfsBuckets.extraBuckets=["sisbajud"]'
# 2. br-sisbajud wired to it (reuses br-sta's SeaweedFS + Redpanda)
helm install br-sisbajud charts/br-sisbajud -n sisb-dev \
  -f charts/br-sisbajud/values-dev.yaml -f charts/br-sisbajud/values-dev-with-br-sta.yaml \
  --set-json 'imagePullSecrets=[{"name":"ghcr-pull"}]'
```

The overlay assumes the br-sta release is named `br-sta` (manager Service
`br-sta-manager:4028`) and the default SeaweedFS / Redpanda Service names.

Observed: br-sisbajud pods healthy about 50 s after its install (br-sta itself took
about 105 s), **0 restarts**:

| Pods (Running) | Jobs (Complete) |
|---|---|
| `br-sisbajud-*`, `br-sisbajud-postgresql-0`, `br-sisbajud-valkey-primary-0`, `br-sisbajud-openbao-0` | `br-sisbajud-migrations`, `br-sisbajud-openbao-transit` |

Topics `lerian.streaming.br-sisbajud`, `.dlq` and `.commands` are created on br-sta's
Redpanda next to `lerian.streaming.br-sta`.

Upgrades: two consecutive `helm upgrade` with the same values produced no
Deployment/StatefulSet generation change (the dev passwords are pinned in
`values-dev.yaml`, see section 7).

Cleanup:

```bash
helm uninstall br-sisbajud -n sisb-dev
helm uninstall br-sta -n sisb-dev
kubectl -n sisb-dev delete pvc --all   # also required after changing the dev passwords
kubectl delete namespace sisb-dev
```

### Production

1. Provision PostgreSQL, Valkey, the S3 buckets (`global.objectStorage.sisbajud.bucket`
   and the br-sta transfer bucket), Vault Transit (or AWS KMS) and the broker.
2. Create the Secret out of band (`brSisbajud.useExistingSecret` + `existingSecretName`)
   or fill `brSisbajud.secrets` with `<path:...>` placeholders; create the GHCR pull secret.
3. `helm install`. Against external infra the migrations and topics Jobs are Helm
   `pre-install/pre-upgrade` + ArgoCD PreSync hooks, so the app never rolls unmigrated.
4. Seed institutions through the admin API (`POST /v1/institutions`).

---

## 4. Shared configuration contract (masks / lerian-common)

```yaml
global:
  env: { name: "production" }             # local|development|staging|e2e|test relax the app's gates
  datastores:
    postgres: { host: "", user: "br_sisbajud", name: "br_sisbajud", ssl: "require" }
    redis:    { host: "<host>:6379", tls: "true" }
  objectStorage:
    sisbajud: { endpoint: "", region: "", bucket: "sisbajud" }
    sta:      { bucket: "" }                # = br-sta's transfer bucket (required, no default)
  kms: { vendor: "hashicorp-vault", vaultAddr: "", vaultAuthMethod: "approle", vaultRoleId: "", vaultMount: "transit" }
  streaming: { brokers: "", tlsEnabled: true, saslMechanism: "SCRAM-SHA-256", saslUsername: "br-sisbajud" }
  auth: { enabled: true, host: "" }
```

| Global field | Native keys | Note |
|---|---|---|
| `global.env.name` | `ENVIRONMENT_NAME`, `ENV_NAME` | Only `local`/`development`/`staging`/`e2e`/`test` relax the gates; anything else is production-like |
| `global.datastores.*` | `POSTGRES_*`, `REDIS_*` | bundled subcharts derive them automatically |
| `global.objectStorage.sisbajud` | `SEAWEEDFS_S3_ENDPOINT/BUCKET/REGION` | — |
| `global.objectStorage.sta` | `STA_INBOUND_BUCKET` (+ `TRANSFER_OBJECT_STORAGE_BUCKET`), `STA_OBJECT_STORAGE_ENDPOINT` | Endpoint defaults to the sisbajud endpoint; the app enforces bucket and endpoint parity with br-sta |
| `global.kms` | `KMS_PROVIDER`, `VAULT_*`, `AWS_REGION` | `VAULT_APPROLE_SECRET_ID` / `VAULT_TOKEN` are secrets |
| `global.streaming` | `STREAMING_*` | br-sta facts arrive on `lerian.streaming.br-sta` |
| `global.auth` | `PLUGIN_AUTH_ENABLED`, `PLUGIN_AUTH_HOST` | The STA transfers client mints its m2m bearer from this host even with auth off |

br-sta wiring (grouped values under `brSisbajud.sta`): `consumerEnabled`,
`expectedTenantSt` (= br-sta's `DEFAULT_TENANT_ID` in single-tenant), `transfersEnabled`,
`transfersBaseUrl` (br-sta manager URL), `clientId` (+ `STA_CLIENT_SECRET` in the Secret).

---

## 5. Operational notes

| Topic | What to know | Before enabling / how to confirm |
|---|---|---|
| Fail-fast render | Mirrors the app's boot validation: `STA_INBOUND_BUCKET` always; Postgres/Redis host in single-tenant; KMS provider + credentials; streaming brokers/SASL/TLS; `LICENSE_KEY` + Postgres password production-like; STA transfers client / inbound auth / declaration publisher credentials; multi-tenant URL/Redis/API key; `ORGANIZATION_IDS` must be `global` | Read the render error: it names the exact value |
| Production guard | `openbao` (dev mode, keys in memory) and `redpandaBundle` are refused outside `local`/`development`/`staging`/`e2e`/`test` | `helm template ... --set global.env.name=production` with the dev bundle fails naming both |
| OpenBao dev mode | A restart of the OpenBao pod loses every Transit key: previously encrypted rows become unreadable | Dev/evaluation only; reset the database with it |
| STA transfers client | Needs a reachable plugin-access-manager to mint its m2m bearer | Without it, return-file submission to br-sta fails |
| br-sta facts for unknown transfers | Known app behaviour: a `lerian.streaming.br-sta` fact for a transfer br-sisbajud did not create is retried as transient and holds the partition | Watch `sta_consumer` in `/readyz` (`degraded`, `consumer_not_polling`) |
| Private images | App, migrations and topics images are private on GHCR | Pull secret in the namespace (`imagePullSecrets`) |

---

## 6. How to validate a successful install

```bash
kubectl -n <ns> get pods
kubectl -n <ns> get jobs
kubectl -n <ns> port-forward svc/br-sisbajud 14029:4029
curl -s localhost:14029/readyz     # readiness probe path
curl -s localhost:14029/health     # liveness probe path
```

| Check | Command/URL | Expected | If it doesn't match, check first |
|---|---|---|---|
| Pods | `kubectl get pods` | app `1/1 Running`, 0 restarts | `CrashLoopBackOff`: the log names the missing dependency |
| Jobs | `kubectl get jobs` | migrations (and in dev `openbao-transit`, buckets, topics) `Complete` | Postgres host/password; broker reachability for topics |
| Readiness | `GET /readyz` | `healthy`; `postgres`, `redis`, `kms`, `seaweedfs`, `streaming` `up`; with br-sta wired: `sta_bucket_parity` `up` and `sta_consumer` `up` | `sta_bucket_parity` down: the sta bucket/endpoint differ from br-sta's |
| br-sta integration (proved) | create a transfer on br-sta (see the br-sta runbook): the mock STA takes it to `Accepted` and br-sta publishes a fact on `lerian.streaming.br-sta` | The fact reaches br-sisbajud's STA consumer (group `sisbajud-sta-consumer`) | A fact for a transfer br-sisbajud did not create is retried (section 5) |
| Not exercised | br-sisbajud → br-sta `POST /v1/transfers` (needs plugin-access-manager and seeded institutions/orders); inbound files from BACEN/mock to br-sisbajud | — | — |

---

## 7. Known errors and what they mean

| Error/log | Cause | Fix |
|---|---|---|
| Valkey and the app restart on every `helm upgrade` | The Valkey subchart regenerates a password left empty | `values-dev.yaml` now pins public dev passwords for PostgreSQL and Valkey; set yours explicitly in other dev files |
| Postgres `password authentication failed` after changing the dev passwords | The data volume keeps the password it was initialised with | `helm uninstall`, delete the PVCs, reinstall |
| `sta_consumer` `degraded` / `consumer_not_polling`, log `STA inbound event requeued: transfer_not_found` then `partition halted (head-of-line blocked)` | Known app behaviour: a br-sta fact that references a transfer unknown to br-sisbajud is retried and blocks the partition | Monitor `sta_consumer`; in dev, do not create br-sta transfers outside br-sisbajud on a shared topic |
| Topics Job fails with TLS on | The topics image needs the broker CA as a file when `STREAMING_TLS_ENABLED=true`, even for a public-CA broker | Set `brSisbajud.secrets.STREAMING_TLS_CA_CERT`, or provision the topics out of band and set `topics.enabled=false` |
| Render fails naming `STA_INBOUND_BUCKET` | No default by policy | `global.objectStorage.sta.bucket` = br-sta's transfer bucket |
| Boot refused in production, license errors | `LICENSE_KEY` missing, or no egress to the license gateway (no offline license mode in this app version) | Set the key and allow egress |
| Browser calls blocked although CORS origins are set | lib-commons' CORS middleware reads `ACCESS_CONTROL_ALLOW_ORIGIN` | Use `brSisbajud.cors.allowedOrigins` (the chart maps it); a wildcard needs the explicit opt-in |
| br-sta at `1.0.0` "older" than `1.2.0-beta.x` | br-sta's version line was reset for its stable release: `1.0.0` is the later, compatible release | Pin br-sta `1.0.0` explicitly |
