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

> **Bundled infrastructure is for development and quickstart only. Production installs must use external, managed infrastructure.** Production means PostgreSQL with TLS, Valkey/Redis, Kafka/Redpanda with TLS, Vault/OpenBao in non-dev mode (or AWS KMS) and S3 object storage. The bundled `postgresql`, `valkey`, `seaweedfs`, `openbao` and `redpanda` subcharts exist for development, POC and quickstart installs. The render refuses the OpenBao and Redpanda bundles in a production-like environment. The PostgreSQL, Valkey and SeaweedFS bundles only get a NOTES warning there, but they are unsupported in production all the same.

| Profile | Values | What runs | Use case |
|---|---|---|---|
| **Dev bundle (quickstart)** | `values-dev.yaml` | the app, plus bundled PostgreSQL, Valkey, SeaweedFS (S3), OpenBao (Vault Transit, dev mode) and Redpanda; `ENVIRONMENT_NAME=development`; inbound auth, the br-sta consumer/transfers client and multi-tenancy off | Evaluation, local development, chart testing |
| **br-sisbajud + br-sta together** | `values-dev.yaml` + `values-dev-with-br-sta.yaml` | the app with its own PostgreSQL, Valkey and OpenBao, reusing a br-sta dev bundle's SeaweedFS and Redpanda in the same namespace; br-sta consumer and transfers client on | Integrated dev of the STA flow (remittance intake, return files) |
| **Standalone (no br-sta)** | `values-dev.yaml` (or your file) with `sta.consumerEnabled` / `sta.transfersEnabled` off (the default) | the app alone; remessas enter through the HTTP intake `POST /v1/remittance-files/notifications` after the raw file is dropped into `STA_INBOUND_BUCKET` | Running SISBAJUD without the br-sta rail (see section 3, "Standalone") |
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

> Bundled infrastructure is for development and quickstart only. Production installs must use external, managed infrastructure. Do not promote this profile to a production tier.

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

### Standalone (no br-sta)

br-sisbajud runs without br-sta. Both STA legs are independent toggles, **off by
default** (and off in `values-dev.yaml`):

| Value | Env key | Default | What it does when `true` |
|---|---|---|---|
| `brSisbajud.sta.consumerEnabled` | `STA_CONSUMER_ENABLED` | `false` | Subscribes to br-sta's business facts (`lerian.streaming.br-sta`) and takes the remessas br-sta announces (needs `STREAMING_BROKERS` and `sta.expectedTenantSt`) |
| `brSisbajud.sta.transfersEnabled` | `STA_TRANSFERS_ENABLED` | `false` | Submits generated return files to br-sta (`POST /v1/transfers`), minting an m2m bearer from `PLUGIN_AUTH_HOST` (needs `sta.transfersBaseUrl`, `sta.clientId` + `STA_CLIENT_SECRET`) |

With both off, **remessas come in through the HTTP intake**, the only reception path
that does not need br-sta. `STA_INBOUND_BUCKET` is still required: it is the bucket the
intake reads the raw remessa from.

**1. Create the institution (once).** It provisions the institution's KEK (the raw
file is sealed under it on receipt). `institutionCode` is the 8-digit BACEN CNPJ root
that must match the remessa header. `connectorMetadata` is validated at write time:
`baseUrl` and at least one `organizations[].organizationId` are required even before
Midaz is wired. Without credentials the connector sends no auth header.

```bash
kubectl -n sisb-dev port-forward svc/br-sisbajud 14029:4029 &
INST=44444444-4444-4444-4444-444444444444
curl -s -X POST localhost:14029/v1/institutions -H 'Content-Type: application/json' -d '{
  "institutionId": "'$INST'",
  "connectorType": "midaz",
  "institutionCode": "12345678",
  "connectorMetadata": {
    "baseUrl": "http://midaz-ledger.midaz.svc.cluster.local:3002",
    "organizations": [{"organizationId": "019fcd7b-97df-71a5-8023-6eb3c661968b"}],
    "blockableBalances": ["default"],
    "blockableAccountTypes": ["deposit"]
  }
}'
```

**2. Drop the raw remessa into `STA_INBOUND_BUCKET`.** With the bundled SeaweedFS
(S3 auth off in the dev bundle), from inside the namespace:

```bash
kubectl -n sisb-dev run s3-put --rm -i --restart=Never --image=amazon/aws-cli:2.17.0 \
  --env AWS_ACCESS_KEY_ID=any --env AWS_SECRET_ACCESS_KEY=any --env AWS_DEFAULT_REGION=us-east-1 \
  --command -- sh -c 'cat > /tmp/r.txt && aws --endpoint-url http://seaweedfs-s3:8333 \
    s3 cp /tmp/r.txt s3://br-sta-transfer/inbound/12345678/AJUD301_12345678_20260617.txt' \
  < remessa.txt
```

The bucket is `global.objectStorage.sta.bucket` (`br-sta-transfer` in
`values-dev.yaml`). The br-sisbajud repository ships a valid 5301 remessa with header
CNPJ `12345678` at `internal/bootstrap/testdata/remittance_notification_remessa.txt`.

**3. Notify the service.** The body is camelCase and all four fields are required:

```bash
curl -s -X POST localhost:14029/v1/remittance-files/notifications \
  -H 'Content-Type: application/json' -d '{
  "objectKey": "inbound/12345678/AJUD301_12345678_20260617.txt",
  "institutionId": "'$INST'",
  "institutionCode": "12345678",
  "fileType": "5301"
}'
# => {"status":"processed","fileId":"<uuid>","environment":"PRODUCTION"}
```

| Field | Rule |
|---|---|
| `objectKey` | Key of the object already in `STA_INBOUND_BUCKET`. For `5303`/`5313` (BACEN validation results) it must be `inbound/<all-digit protocol>/<file name>`; any non-empty key otherwise |
| `institutionId` | UUID of an existing institution |
| `institutionCode` | The institution's 8-digit BACEN CNPJ; the parser checks it against the file header |
| `fileType` | Numeric SISBAJUD code, never a label: `5301`/`5303`/`5308` (PRODUCTION: remessa de bloqueio / resultado de validação sintática / requisição AJUD308), `5311`/`5313`/`5318` (the same three in HOMOLOGATION). `5302`/`5312` are produced by this service, never accepted |

Responses:
- `200 {"status":"processed","fileId","environment"}`;
- `200 {"status":"skipped","reason":"skipped"}` on an idempotent re-delivery, or
  `"reason":"lock_held"` while another worker processes the same file;
- `422` SBJ-0006: bad body, unknown `fileType`, or a bad key shape;
- `404` SBJ-0005: the object is not in the bucket;
- `503` SBJ-0008.

The reception runs synchronously in the request.

**Auth.** With `PLUGIN_AUTH_ENABLED=false` (the dev bundle) the route is open. With
auth on, the caller needs the `remittance_file:receive` scope: the `br-sisbajud-admin`
role, or the M2M editor role. `POST /v1/institutions` needs the institution write scope.

**Return files without br-sta.** The return-file crons (`workers.returnFile`,
`workers.informationReturnFile`, off by default) still generate the AJUD302/AJUD309
files. With `transfersEnabled` off, "generated and not submitted" is a valid state for
the app: it boots, and logs each file as not submitted. The app refuses to boot only
when transfers are enabled but the submission path could not be built.
- **Where the files go:** they are stored **encrypted** (ciphertext, institution-scoped
  key) in the service bucket `SEAWEEDFS_BUCKET`. There is no plaintext file to pick up
  from the bucket.
- **Dev export:** in `local`/`development` only,
  `GET /v1/admin/return-file/{id}/content` returns the decrypted bytes (base64).
- **Production:** app 1.1.0 has no production export endpoint. Delivering return files
  to BACEN is br-sta's job (`transfersEnabled`). Without br-sta the return leg must be
  covered by the operator's own STA channel, and that is outside what this app version
  offers.

> **Not exercised yet.** This HTTP intake path was not run on minikube. The contract
> above was read from the app source at v1.1.0: `internal/adapters/http/remittance_notification_handler.go`,
> `remittance_notification_huma.go`, `internal/bootstrap/routes_remittance_notification.go`,
> `institution_handler.go`, and the endpoint's integration test
> `internal/bootstrap/remittance_notification_integration_test.go`, which uses the same
> body and fixture.

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
| Not exercised | br-sisbajud → br-sta `POST /v1/transfers` (needs plugin-access-manager and seeded institutions/orders); inbound files from BACEN/mock to br-sisbajud; the standalone HTTP intake `POST /v1/remittance-files/notifications` (documented from source, section 3) | — | — |

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
