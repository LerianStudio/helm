# br-sisbajud — Installation Runbook

> How to install, validate and troubleshoot br-sisbajud from this chart (dev bundle,
> pairing with br-sta, standalone, production). For operators installing the chart.

> **Outdated: this runbook describes the br-sisbajud monolith (app 1.2.x).** The chart
> now deploys the Sisbajud Mensageria (br-sfn `services/sisbajud`, app 1.1.0):
> main API on 4031, execution API on a TLS listener on 4032, mandatory streaming,
> mandatory JWT verification (`brSisbajud.auth`), a license in every
> environment, and the br-sta consumer on its own `sta.stream` cluster. The README
> ("From the monolith ... to the Mensageria", "Execution API", "Fail-fast gates") is
> authoritative until this runbook is rewritten.

---

## 0. Metadata

| Field | Value |
|---|---|
| Product / Chart | `br-sisbajud-helm` **1.4.3** / app **1.1.0** |
| Components | one Go binary (main HTTP API `:4031`, execution API `:4032`, background workers), migrations Job, topics Job (off by default) |
| Images | `ghcr.io/lerianstudio/br-sisbajud`, `br-sisbajud-migrations`, `br-sisbajud-topics` (all public on GHCR) |
| Upgrade guide | coming from chart 1.1.x: [`UPGRADE-1.2.md`](UPGRADE-1.2.md) |
| Last review of this runbook | 2026-10-05, against chart 1.2.0 / app 1.2.0 |
| Escalation contact | `@LerianStudio/G_Github_Devops` (see `.github/CODEOWNERS`) |

---

## 1. Installation profiles

> **Bundled infrastructure is for development and quickstart only. Production installs must use external, managed infrastructure.** Production means PostgreSQL with TLS, Valkey/Redis, Kafka/Redpanda with TLS, Vault/OpenBao in non-dev mode (or AWS KMS) and S3 object storage. The bundled `postgresql`, `valkey`, `seaweedfs`, `openbao` and `redpanda` subcharts exist for development, POC and quickstart installs. The render refuses the OpenBao and Redpanda bundles outside a development-class environment (`local`, `development`, `develop`, `dev`, `test`, `e2e`; staging is refused). The PostgreSQL, Valkey and SeaweedFS bundles only get a NOTES warning in a production-like environment, but they are unsupported in production all the same.

| Profile | Values | What runs | Use case |
|---|---|---|---|
| **Dev bundle (quickstart)** | `values-dev.yaml` | the app, plus bundled PostgreSQL, Valkey, SeaweedFS (S3), OpenBao (Vault Transit, dev mode) and Redpanda; `ENVIRONMENT_NAME=development`; inbound auth, the br-sta consumer/transfers client and multi-tenancy off | Evaluation, local development, chart testing |
| **br-sisbajud + br-sta together** | `values-dev.yaml` + `values-dev-with-br-sta.yaml` | the app with its own PostgreSQL, Valkey and OpenBao, reusing a br-sta dev bundle's SeaweedFS and Redpanda in the same namespace; br-sta transfers client on; the br-sta consumer stays off (it requires SASL, which the br-sta dev Redpanda does not offer) | Integrated dev of the STA flow (return files) |
| **Production / external infra** | your file, started from `values-template.yaml` | the app + migrations Job (the topics Job is off by default); every dependency external | Real tiers. Default environment `production` (fail-closed) |

Chart defaults alone do not render: the environment defaults to `production`, so the
chart fails fast until the external connections and secrets are set (section 5).

---

## 2. External dependencies

| Dependency | When it's needed | How the chart receives it |
|---|---|---|
| PostgreSQL | Always (single-tenant: the host is required) | `global.datastores.postgres` + `brSisbajud.secrets.POSTGRES_PASSWORD` |
| Valkey / Redis | Always (rate limit, idempotency, processing locks) | `global.datastores.redis` (`host:port`) + `brSisbajud.secrets.REDIS_PASSWORD` |
| Kafka / Redpanda | Always (streaming is mandatory: the lib-streaming producer): brokers required; TLS in production | `global.streaming` + `brSisbajud.secrets.STREAMING_SASL_PASSWORD` / `STREAMING_TLS_CA_CERT` |
| HashiCorp Vault Transit **or** AWS KMS | Always (envelope encryption of court-ordered seizure data) | `global.kms` + `brSisbajud.secrets.VAULT_APPROLE_SECRET_ID` (or `VAULT_TOKEN`); with AWS KMS: `awsRegion` + `awsKeyMode` (`managed`\|`provided`) and, in `provided`, `awsKeyArn` (under `brSisbajud.kms` or `global.kms`) |
| S3-compatible object storage | Always (encrypted seizure artifacts + the br-sta transfer bucket) | `global.objectStorage.sisbajud` / `.sta` + `SEAWEEDFS_ACCESS_KEY` / `SEAWEEDFS_SECRET_KEY` |
| br-sta | Remittance intake (business facts on `lerian.streaming.br-sta`) and return-file submission (`POST /v1/transfers`) | `brSisbajud.sta.*`, `global.objectStorage.sta` (the same block br-sta reads) |
| plugin-access-manager | Inbound JWT validation, the STA m2m bearer, permission declaration | `global.auth`, `brSisbajud.identity` |
| Lerian license gateway | Always, in every environment (`LICENSE_KEY`, app 1.1.0); the pod needs egress to it | `brSisbajud.secrets.LICENSE_KEY`, `brSisbajud.license.organizationIds` (`global`) |
| Tenant manager | Only with multi-tenancy | `global.multiTenant` + `MULTI_TENANT_SERVICE_API_KEY` |

The Mensageria does not call the Midaz ledger: plugin-br-sisbajud executes orders on it.
Seed institutions through the admin API (`POST /v1/institutions`) before orders can execute.

---

## 3. Installation order

### Dev bundle

> Bundled infrastructure is for development and quickstart only. Production installs must use external, managed infrastructure. Do not promote this profile to a production tier.

```bash
kubectl create namespace sisb-dev
# the license key stays in a file: it never lands in shell history or process args
kubectl create secret generic br-sisbajud-license -n sisb-dev \
  --from-file=LICENSE_KEY=./br-sisbajud.license
helm dependency update charts/br-sisbajud
helm install br-sisbajud charts/br-sisbajud -n sisb-dev \
  -f charts/br-sisbajud/values-dev.yaml \
  --set-json 'brSisbajud.secretRefs={"LICENSE_KEY":{"name":"br-sisbajud-license","key":"LICENSE_KEY"}}'
```

A license is required here too. App 1.1.0 requires it in every
environment, `development` included (no dev bypass). `values-dev.yaml` ships no key:
the chart renders, but the pod does not boot until a real key is set.

The images are public, so no pull secret is needed (top-level `imagePullSecrets` is
only for a private mirror/registry). With
the bundled dependencies the app pod runs idempotent initContainers (migrations and
the Transit mount; wait-for-broker and topics only with `topics.enabled`) before it
starts, so it never boots on a missing schema or Transit mount.

Expected once the release is up:

| Pods (Running) | Jobs (Complete) |
|---|---|
| `br-sisbajud-*`, `br-sisbajud-postgresql-0`, `br-sisbajud-valkey-primary-0`, `br-sisbajud-openbao-0`, `redpanda-0`, `seaweedfs-master-0`, `seaweedfs-volume-0`, `seaweedfs-filer-0`, `seaweedfs-s3-*` | `br-sisbajud-migrations`, `br-sisbajud-openbao-transit`, `br-sisbajud-seaweedfs-buckets` |

With a bundled dependency these Jobs are post-install/post-upgrade hooks with
`before-hook-creation` only, so they stay `Complete` until `ttlSecondsAfterFinished`
(600 s) removes them. The next upgrade replaces them.

### br-sisbajud + br-sta together

```bash
# 0. namespace (both charts' images are public: no pull secret)
kubectl create namespace sisb-dev
# 1. br-sta dev bundle, with br-sisbajud's own bucket added to its bucket Job
kubectl create secret generic br-sta-license -n sisb-dev \
  --from-file=LICENSE_KEY=./br-sta.license
helm dependency update charts/br-sta
helm install br-sta charts/br-sta -n sisb-dev -f charts/br-sta/values-dev.yaml \
  --set-json 'seaweedfsBuckets.extraBuckets=["sisbajud"]' \
  --set-json 'common.secretRefs={"LICENSE_KEY":{"name":"br-sta-license","key":"LICENSE_KEY"}}' \
  --set common.license.organizationIds=<br-sta organization id>
# 2. br-sisbajud wired to it (reuses br-sta's SeaweedFS + Redpanda)
kubectl create secret generic br-sisbajud-license -n sisb-dev \
  --from-file=LICENSE_KEY=./br-sisbajud.license
helm dependency update charts/br-sisbajud
helm install br-sisbajud charts/br-sisbajud -n sisb-dev \
  -f charts/br-sisbajud/values-dev.yaml -f charts/br-sisbajud/values-dev-with-br-sta.yaml \
  --set-json 'brSisbajud.secretRefs={"LICENSE_KEY":{"name":"br-sisbajud-license","key":"LICENSE_KEY"}}'
```

The overlay assumes the br-sta release is named `br-sta` (manager Service
`br-sta-manager:4028`) and the default SeaweedFS / Redpanda Service names.

Expected: br-sisbajud pods Ready without restarts, and these Jobs Complete:

| Pods (Running) | Jobs (Complete) |
|---|---|
| `br-sisbajud-*`, `br-sisbajud-postgresql-0`, `br-sisbajud-valkey-primary-0`, `br-sisbajud-openbao-0` | `br-sisbajud-migrations`, `br-sisbajud-openbao-transit` |

Topics `lerian.streaming.br-sisbajud` and `.dlq` are created on br-sta's
Redpanda next to `lerian.streaming.br-sta`.

Upgrades: a second `helm upgrade` with the same values does not change any
Deployment/StatefulSet generation and does not recreate pods (the dev passwords are
pinned in `values-dev.yaml`, see section 7).

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
| `brSisbajud.sta.consumerEnabled` | `STA_CONSUMER_ENABLED` | `false` | Subscribes to br-sta's business facts (`lerian.streaming.br-sta`) and takes the remessas br-sta announces (needs the `sta.stream` brokers, SASL (`saslMechanism`, `saslUsername` + `STA_STREAM_SASL_PASSWORD`), TLS + `STA_STREAM_TLS_CA_CERT` or the plaintext opt-in outside production, and `sta.expectedTenantSt`) |
| `brSisbajud.sta.transfersEnabled` | `STA_TRANSFERS_ENABLED` | `false` | Submits generated return files to br-sta (`POST /v1/transfers`), minting an m2m bearer from `PLUGIN_AUTH_HOST` (needs `sta.transfersBaseUrl`, `sta.clientId` + `STA_CLIENT_SECRET`) |

With both off, the app receives no remessas: app 1.1.0 takes them only from br-sta's
business facts (`sta.consumerEnabled`).

**Return files without br-sta.** The return-file crons (`workers.returnFile`,
`workers.informationReturnFile`, off by default) still generate the AJUD302/AJUD309
files. With `transfersEnabled` off, "generated and not submitted" is a valid state for
the app: it boots, and logs each file as not submitted. The app refuses to boot only
when transfers are enabled but the submission path could not be built.
- **Where the files go:** they are stored **encrypted** (ciphertext, institution-scoped
  key) in the service bucket `SEAWEEDFS_BUCKET`. There is no plaintext file to pick up
  from the bucket.

### Production

**How to confirm a production install** (`global.env.name=production`, external infra
only):

- The app pod is `1/1 Running` with no restarts.
- The boot log contains `Organization global has a valid license` and
  `license validation enabled`.
- `/readyz` is `healthy`, with `kms`, `postgres`, `redis`, `seaweedfs` and `streaming`
  `up`.
- The topics `lerian.streaming.br-sisbajud` and `.dlq` exist on the broker.
- The effective connections are the TLS ones: PostgreSQL `sslmode=require`, Valkey and
  Kafka over TLS (SASL when set), Vault Transit or AWS KMS as the KMS, an explicit CORS
  origin, `ORGANIZATION_IDS=global`.
- With br-sta wired: `sta_bucket_parity` and `sta_consumer` `up`, and the consumer group
  `br-sisbajud-sta-intake-v1` is `Stable` on `lerian.streaming.br-sta`.
- Known limitation: submitting transfers br-sisbajud -> br-sta needs
  plugin-access-manager for the m2m bearer.

1. Provision PostgreSQL, Valkey, the S3 buckets (`global.objectStorage.sisbajud.bucket`
   and the br-sta transfer bucket), Vault Transit (or AWS KMS) and the broker.
2. Create the Secret out of band (`brSisbajud.useExistingSecret` + `existingSecretName`)
   or fill `brSisbajud.secrets` with `<path:...>` placeholders.
3. Pull secret: optional. The images are public on GHCR and the chart default is
   `imagePullSecrets: []`. Only for a private mirror/registry, create the Secret and set
   the root list, which the app, migrations, topics and bucket pods all use:

   ```bash
   kubectl -n <namespace> create secret docker-registry <your-secret> \
     --docker-server=<registry> --docker-username=<user> --docker-password=<token>
   ```

   ```yaml
   imagePullSecrets: [{name: <your-secret>}]
   ```
4. `helm install` from the OCI registry, pinning the chart version:

   ```bash
   helm install br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm --version <version> \
     -n <namespace> -f my-values.yaml
   ```

   Install a released version from the registry, never a branch checkout.
   Against external infra the migrations and topics Jobs are Helm
   `pre-install/pre-upgrade` + ArgoCD PreSync hooks, so the app never rolls unmigrated.
5. Seed institutions through the admin API (`POST /v1/institutions`).

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
  streaming: { enabled: true, brokers: "", tlsEnabled: true, saslMechanism: "SCRAM-SHA-256", saslUsername: "br-sisbajud" }
  auth: { enabled: true, host: "" }
```

| Global field | Native keys | Note |
|---|---|---|
| `global.env.name` | `ENVIRONMENT_NAME`, `ENV_NAME` | Only `local`/`development`/`staging`/`e2e`/`test` relax the gates (never the license); anything else is production-like |
| `global.datastores.*` | `POSTGRES_*`, `REDIS_*` | bundled subcharts derive them automatically |
| `global.objectStorage.sisbajud` | `SEAWEEDFS_S3_ENDPOINT/BUCKET/REGION` | — |
| `global.objectStorage.sta` | `STA_INBOUND_BUCKET` (+ `TRANSFER_OBJECT_STORAGE_BUCKET`), `STA_OBJECT_STORAGE_ENDPOINT` | Endpoint defaults to the sisbajud endpoint; the app enforces bucket and endpoint parity with br-sta |
| `global.kms` | `KMS_PROVIDER`, `VAULT_*`, `AWS_REGION`, `KMS_AWS_KEY_MODE`, `KMS_AWS_KEY_ARN` | `VAULT_APPROLE_SECRET_ID` / `VAULT_TOKEN` are secrets. Mode and ARN: `brSisbajud.configmap` > `brSisbajud.kms` > `global.kms`; `provided` requires the ARN, `managed` rejects it. The chart-derived `KMS_AWS_*` keys (`kms.awsKeyMode`/`awsKeyArn` and the `brSisbajud.vault` knobs) are emitted only with `KMS_PROVIDER=aws`; `brSisbajud.configmap.KMS_AWS_*` is the escape hatch and is emitted with any provider |
| `brSisbajud.vault.awsKmsTimeoutSec` / `awsKmsRotationCheckIntervalSec` | `KMS_AWS_TIMEOUT_SEC` / `KMS_AWS_ROTATION_CHECK_INTERVAL_SEC` | Optional, only with `KMS_PROVIDER=aws`; whole seconds, `1`..`600` (every aws mode) and `1`..`86400` (validated only in `provided`) |
| `global.streaming` | `STREAMING_*` | The lib-streaming producer only; br-sta facts come through `brSisbajud.sta.stream` |
| `global.auth` | `PLUGIN_AUTH_ENABLED`, `PLUGIN_AUTH_HOST` | The STA transfers client mints its m2m bearer from this host even with auth off |

br-sta wiring (grouped values under `brSisbajud.sta`): `consumerEnabled`,
`expectedTenantSt` (= br-sta's `DEFAULT_TENANT_ID` in single-tenant), `transfersEnabled`,
`transfersBaseUrl` (br-sta manager URL), `clientId` (+ `STA_CLIENT_SECRET` in the Secret).

---

## 5. Operational notes

| Topic | What to know | Before enabling / how to confirm |
|---|---|---|
| Fail-fast render | Mirrors the app's boot validation: `STA_INBOUND_BUCKET` always; Postgres/Redis host in single-tenant; KMS provider + credentials; streaming brokers/SASL/TLS; `LICENSE_KEY` in a production-like environment (the app requires it in every environment); Postgres password production-like; STA transfers client / inbound auth / declaration publisher credentials; multi-tenant URL/Redis/API key; `ORGANIZATION_IDS` required and `global` | Read the render error: it names the exact value |
| Dev-only bundle guard | `openbao` (dev mode, keys in memory) and `redpandaBundle` are refused outside `local`/`development`/`develop`/`dev`/`test`/`e2e` (staging is refused). Separate from the app's own relaxations, which `staging` still gets | `helm template ... --set global.env.name=production` with the dev bundle fails naming both |
| OpenBao dev mode | A restart of the OpenBao pod loses every Transit key: previously encrypted rows become unreadable | Dev/evaluation only; reset the database with it |
| STA transfers client | Needs a reachable plugin-access-manager to mint its m2m bearer | Without it, return-file submission to br-sta fails |
| br-sta facts for unknown transfers | Known app behaviour: a `lerian.streaming.br-sta` fact for a transfer br-sisbajud did not create is retried (holding the partition) until its retry budget is spent, then parked in the DLQ (`transfer_not_found_after_retry`) | Watch `sta_consumer` in `/readyz` (`consumer_not_polling`) |
| Image gate with AWS KMS | Images before `1.1.0-beta.13` ignore `KMS_AWS_KEY_MODE`/`KMS_AWS_KEY_ARN` and create their own KMS key; with `KMS_PROVIDER=aws` the render refuses those tags. Only the canonical form `vX.Y.Z[-(alpha\|beta\|rc).N]` (no leading zeros, no `@`) is compared with the minimum | Any other tag (`@` digest, arch suffix, `+build`, non-SemVer) needs `brSisbajud.kms.allowUnverifiableImageTag: true` (not read from `global.kms`); with the flag a non-canonical tag passes without any version check. A canonical tag below `1.1.0-beta.13` fails even with the flag |
| Images | App, migrations and topics images are public on GHCR | A pull secret (`imagePullSecrets`) only for a private mirror/registry |

### License

| Topic | Behaviour (app `1.1.0`) |
|---|---|
| Every environment | In app 1.1.0 a license is mandatory in every `ENVIRONMENT_NAME`, `development`/`staging`/`e2e`/`test`/`local` included: no dev bypass, no unlicensed mode. The boot fails closed when `LICENSE_KEY` is blank or `ORGANIZATION_IDS` is blank or not `global`. Only a local `-tags licensetest` build runs unlicensed; the published image never does |
| At startup | A valid license boots, and so does a license in grace, including the outage grace when the gateway cannot answer. A 4xx refusal from the gateway aborts the boot |
| One key per product | A key licenses a single product. A key issued for another product is refused with `Exiting: LCS-0012: refused by the gateway (LCS-1005)`; an unknown or altered key with `(LCS-1002)` |
| On refusal | The process exits and the pod goes to `CrashLoopBackOff`. In a rolling update the pod that is already running keeps serving, so the rollout stalls but nothing goes down |
| Gateway | `https://license.lerian.io`, `POST /licenses/validate`. Egress to it is mandatory and the URL is not configurable. Keys issued for staging were validated on this production gateway. The license SDK in app 1.1.0 still switches to a development gateway when the pod env carries `IS_DEVELOPMENT=true` outside production; since chart 1.4.3 the chart drops that key from the ConfigMap and Secret it generates (`brSisbajud.configmap`, `brSisbajud.secrets`), but it still reaches the pod through `brSisbajud.extraEnvVars`, `brSisbajud.secretRefs.IS_DEVELOPMENT`, or the operator Secret of `useExistingSecret`, which `envFrom` loads unfiltered |
| Refresh and grace | The key is re-validated every 6 h. When the gateway does not answer (network error or 5xx) after it has confirmed the key once, the process keeps serving through decaying grace windows (2 d, 1 d, 12 h, 6 h, so at most 3 d 18 h) and then exits. A process that was never confirmed gets 6 h only. A 4xx refusal ends the grace at once. The windows live in memory: a pod restarted during an outage starts unconfirmed |
| Offline | No offline license mode in this app version |
| Render gate | A production-like environment fails the render without `LICENSE_KEY` (a Secret value, `secretRefs`, `extraEnvVars` or `useExistingSecret`); in `local`/`development`/`staging`/`e2e`/`test` the render passes and the pod refuses to boot. `ORGANIZATION_IDS` must be `global` |
| How to confirm | No license check in `/readyz`: look for the boot log lines `Organization global has a valid license` and `license validation enabled` |

---

## 6. How to validate a successful install

```bash
kubectl -n <ns> get pods
kubectl -n <ns> get jobs
kubectl -n <ns> port-forward svc/br-sisbajud 14029:4031
curl -s localhost:14029/readyz     # readiness probe path
curl -s localhost:14029/health     # liveness probe path
```

| Check | Command/URL | Expected | If it doesn't match, check first |
|---|---|---|---|
| Pods | `kubectl get pods` | app `1/1 Running`, 0 restarts | `CrashLoopBackOff`: the log names the missing dependency |
| Jobs | `kubectl get jobs` | Dev bundle: `migrations`, `openbao-transit`, `seaweedfs-buckets` `Complete` (until the 600 s TTL). External infra: Helm and ArgoCD delete the migrations/topics hook Jobs once they succeed, so no Job left means success | A Job left `Failed` (kept for its logs): Postgres host/password; broker reachability for topics |
| Readiness | `GET /readyz` | `healthy`; `postgres`, `redis`, `kms`, `seaweedfs`, `streaming` `up`; with br-sta wired: `sta_bucket_parity` `up` and `sta_consumer` `up` | `sta_bucket_parity` stays `up` with a reason (`unreachable`, `endpoint_mismatch`, `bucket_mismatch`): the sta store is unreachable or its bucket/endpoint differ from br-sta's |
| br-sta integration | create a transfer on br-sta (see the br-sta runbook): the mock STA takes it to `Accepted` and br-sta publishes a fact on `lerian.streaming.br-sta` | The fact reaches br-sisbajud's STA consumer (group `br-sisbajud-sta-intake-v1`) | A fact for a transfer br-sisbajud did not create is retried (section 5) |
| Known limitation | br-sisbajud → br-sta `POST /v1/transfers` needs plugin-access-manager (the m2m bearer) and seeded institutions/orders; without it, transfer submission fails | — | Set `global.auth.host` to a real plugin-access-manager |

---

## 7. Known errors and what they mean

| Error/log | Cause | Fix |
|---|---|---|
| Valkey and the app restart on every `helm upgrade` | The Valkey subchart regenerates a password left empty | `values-dev.yaml` pins public dev passwords for PostgreSQL and Valkey; set yours explicitly in other dev files |
| Postgres `password authentication failed` after changing the dev passwords | The data volume keeps the password it was initialised with | `helm uninstall`, delete the PVCs, reinstall |
| `sta_consumer` `consumer_not_polling`, log `STA inbound event requeued: transfer_not_found` then `partition halted (head-of-line blocked)` | Known app behaviour: a br-sta fact that references a transfer unknown to br-sisbajud is retried (holding the partition) until its retry budget is spent, then parked in the DLQ (`transfer_not_found_after_retry`) | Monitor `sta_consumer`; in dev, do not create br-sta transfers outside br-sisbajud on a shared topic |
| Topics Job fails with TLS on | The topics image needs the broker CA as a file when `STREAMING_TLS_ENABLED=true`, even for a public-CA broker | Set `brSisbajud.secrets.STREAMING_TLS_CA_CERT`, or provision the topics out of band and set `topics.enabled=false` |
| Render fails naming `STA_INBOUND_BUCKET` | No default by policy | `global.objectStorage.sta.bucket` = br-sta's transfer bucket |
| Boot refused (any environment), license errors | `LICENSE_KEY` missing, a key for another product (`LCS-1005`) or an unknown key (`LCS-1002`), or no egress to the license gateway (no offline license mode in this app version) | Set this product's key and allow egress (section 5, License) |
| Browser calls blocked although CORS origins are set | lib-commons' CORS middleware reads `ACCESS_CONTROL_ALLOW_ORIGIN` | Use `brSisbajud.cors.allowedOrigins` (the chart maps it); a wildcard needs the explicit opt-in |

---

## 8. Rollback

```bash
helm history br-sisbajud -n <namespace>
helm rollback br-sisbajud <revision> -n <namespace>
```

Under ArgoCD, revert the values/chart version commit in Git instead; a manual rollback
is undone by the next sync.

- **Migrations are forward-only.** A rollback redeploys the older chart and image but
  does not revert the schema: the migrations Job only runs `migrate up`, and the older
  revision's hook re-runs it as a no-op. An older app image is only tested against its
  own schema and may fail against a newer one. Roll back to an image that
  knows the current schema version, or restore the database from a backup taken before
  the upgrade. Take that backup before every upgrade that ships migrations.
- **The KMS keys must survive every rollback and reinstall.** Encrypted data, such as the
  stored return files, is wrapped by the Transit keys (`sisbajud-kek-*`) in Vault/OpenBao, or by the
  AWS KMS key. Never delete or recreate them: data encrypted under a lost key is
  unrecoverable. This is also why the OpenBao dev bundle, whose keys live in memory, is
  dev-only.
