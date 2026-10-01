# br-sta — Installation Runbook

> Filled in from the chart itself (`README.md`, `values.yaml`, `values-dev.yaml`,
> `values-template.yaml`, templates) and from a real install of the dev bundle on an
> isolated minikube (6 CPU / 7 GB), plus a production-mode install on external infra
> (section 3, Production). Goal: someone outside the squad, with only the
> chart and this runbook, can install a working release and knows what to check if
> something does not behave as expected.

---

## 0. Metadata

| Field | Value |
|---|---|
| Product / Chart | `br-sta-helm` (first release **1.0.0**) / app **1.0.0** (first stable STA release) |
| Components | `manager` (HTTP API, `:4028`), `worker` (background process, probe server `:4029`, exactly one replica), migrations Job |
| Images | `ghcr.io/lerianstudio/br-sta-manager`, `br-sta-worker`, `br-sta-migrations` (all private on GHCR); dev only: `mock-sta-server` (private) |
| Last review of this runbook | 2026-09-30, against chart 1.0.0 / app 1.0.0 |
| Escalation contact | STA squad (see chart CODEOWNERS) |

---

## 1. Installation profiles

The profile is chosen by the values file you layer, not by a flag.

> **Bundled infrastructure is for development and quickstart only. Production installs must use external, managed infrastructure.** Production means external, managed infrastructure: PostgreSQL with TLS, Valkey/Redis, RabbitMQ, Kafka/Redpanda with TLS, S3 object storage and the real BACEN/Nuclea STA upstream. The bundled `postgresql`, `valkey`, `rabbitmq`, `seaweedfs` and `redpanda` subcharts and `mockSta` exist for development, POC and quickstart. The render refuses Redpanda and the mock STA in a production-like environment and only warns (NOTES) for the others, but none of them is supported in production.

| Profile | Values | What runs | Use case |
|---|---|---|---|
| **Dev bundle (quickstart)** | `values-dev.yaml` | manager + worker + migrations, plus bundled PostgreSQL, Valkey, RabbitMQ, SeaweedFS (S3), Redpanda and the mock STA server, all in the release namespace; `ENV_NAME=development`, inbound auth off | Evaluation, local development, chart testing. Nothing reaches BACEN |
| **Dev bundle for br-sisbajud** | `values-dev.yaml` + `--set-json 'seaweedfsBuckets.extraBuckets=["sisbajud"]'` | Same as above, plus br-sisbajud's own bucket | Pair with br-sisbajud's `values-dev-with-br-sta.yaml` in the same namespace (section 3) |
| **Production / external infra** | your file, started from `values-template.yaml` | manager + worker + migrations only; every dependency external | Real tiers. Default `ENV_NAME=production` (fail-closed) |

Chart defaults alone do not render: the default environment is `production`, so the
chart fails fast until the external connections and secrets are set (section 5).

---

## 2. External dependencies

| Dependency | When it's needed | How the chart receives it |
|---|---|---|
| PostgreSQL | Always (single-tenant: the chart requires the host) | `global.datastores.postgres` + `common.secrets.POSTGRES_PASSWORD`. DB/user default `br_sta` |
| Valkey / Redis | Always (rate limit, idempotency, scheduler leader election) | `global.datastores.redis` (`host:port`) + `common.secrets.REDIS_PASSWORD` |
| RabbitMQ | Always in production (audit transport + business-event channel; the app refuses production without it) | `global.datastores.broker` + `common.secrets.RABBITMQ_DEFAULT_PASS` (or a full `RABBITMQ_URL`). The management API must be reachable: the app health-checks it on every connect |
| S3-compatible object storage | Always in production (the transfer bucket holds both directions) | `global.objectStorage.sta` (+ `staAuditExports` for audit exports) + `common.secrets.AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` or an IRSA / workload-identity annotation on `serviceAccount` |
| Kafka / Redpanda | Off by default, like the other Lerian charts: business facts on `lerian.streaming.br-sta` (+ `.dlq`), the topic br-sisbajud consumes | `global.streaming` (`enabled: true` + brokers) + `common.secrets.STREAMING_SASL_PASSWORD` / `STREAMING_TLS_CA_CERT`. With `topicAutoProvision: true` (the default) both binaries create the topics at boot when the principal has CreateTopics; with `false` (IaC topics) they must exist first |
| plugin-access-manager | Mandatory outside a development-class env (the app accepts `PLUGIN_AUTH_ENABLED=false` only in development/develop/dev/local/test) | `global.auth.enabled` + `global.auth.host` |
| Lerian license gateway | Production (`LICENSE_KEY` + `ORGANIZATION_IDS`); the pods need egress to it | `common.secrets.LICENSE_KEY`, `common.license.organizationIds` |
| BACEN STA | The real upstream (homologation or production host) | `common.bacen.environment` (`homologation` default) |
| Tenant manager | Only with multi-tenancy | `global.multiTenant` + `common.secrets.MULTI_TENANT_SERVICE_API_KEY` |

The chart does not create databases, RabbitMQ users/vhosts or buckets against
external infra; it runs the SQL migrations (single-tenant). The app declares its own
RabbitMQ exchanges and queues at boot.

---

## 3. Installation order

### Dev bundle (proved on minikube)

```bash
kubectl create namespace sta-dev
# GHCR pull secret (the br-sta images are private). Use a token with read:packages.
kubectl -n sta-dev create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io --docker-username=<github-user> --docker-password=<GHCR_READ_TOKEN>

helm install br-sta charts/br-sta -n sta-dev \
  -f charts/br-sta/values-dev.yaml \
  --set-json 'imagePullSecrets=[{"name":"ghcr-pull"}]'
```

`imagePullSecrets` (root key) is used by the manager, worker, migrations Job and the
mock STA server; the bundled infra and bootstrap Jobs run public images.

Expected after about **105 s** on a fresh namespace:

| Pods (Running) | Jobs (Complete) |
|---|---|
| `br-sta-manager-*`, `br-sta-worker-*` (**0 restarts**), `br-sta-mock-sta-*`, `br-sta-postgresql-0`, `br-sta-valkey-primary-0`, `br-sta-rabbitmq-0`, `redpanda-0` (2/2), `seaweedfs-master-0`, `seaweedfs-volume-0`, `seaweedfs-filer-0`, `seaweedfs-s3-*` | `br-sta-migrations-<hash>`, `br-sta-seaweedfs-buckets-<hash>`, `br-sta-redpanda-topics-<hash>` |

The bootstrap Jobs are regular Jobs named after a hash of their spec (not hooks): the
app's `/readyz` gates on the transfer bucket, so a post-install hook would never run.

Upgrades are idempotent: two consecutive `helm upgrade` with the same values
produced no error, no Deployment/StatefulSet generation change and the same pods.

Cleanup:

```bash
helm uninstall br-sta -n sta-dev
kubectl -n sta-dev delete pvc --all   # also required if you change the dev passwords (section 7)
kubectl delete namespace sta-dev
```

### With br-sisbajud

1. Install br-sta as above, adding `--set-json 'seaweedfsBuckets.extraBuckets=["sisbajud"]'`
   (its bucket Job then also creates br-sisbajud's bucket).
2. Install br-sisbajud in the same namespace with its `values-dev.yaml` +
   `values-dev-with-br-sta.yaml` (see the br-sisbajud runbook). It reuses br-sta's
   SeaweedFS and Redpanda and calls `http://br-sta-manager:4028`.

### Production

> **Validated in production mode.** br-sta `1.0.0` was installed with
> `global.env.name=production`, the production license gateway and external infra only
> (no bundled subchart) in a production-like cluster. Confirmed at runtime:
> PostgreSQL `sslmode=require`; Valkey over TLS with a private CA; RabbitMQ over
> `amqps` (5671) with the management health check over `https` (15671) and a CA bundle
> (see "RabbitMQ with a private CA" below); Kafka with TLS + SASL SCRAM; an explicit CORS
> origin; `ORGANIZATION_IDS=global`. The migrations ran as the `pre-install` hook, and
> the manager and worker were `1/1` about 37 s later with 0 restarts. `/readyz`
> returned `200`, with `license`, `postgres`, `rabbitmq`, `redis` (`tls: true`) and
> `storage_transfer` `up`. The worker loops started: business publisher, outbound
> fanout, leader election and audit consumer. Not exercised: authenticated API calls
> and transfer submission from br-sisbajud, since both need plugin-access-manager.

1. Provision PostgreSQL (database/user `br_sta` by default), Valkey, RabbitMQ (with the
   management API reachable), the S3 buckets, and, if streaming is on (off by default),
   Kafka/Redpanda: the topics `lerian.streaming.br-sta` and `lerian.streaming.br-sta.dlq`,
   or CreateTopics for the br-sta principal (`global.streaming.topicAutoProvision: true`).
2. Generate the master key once (`openssl rand -hex 32`) and store `v1:<hex>` as
   `MASTER_KEYS` in your secret store. Never replace it: add a new version instead.
3. Create the app Secret out of band (`common.useExistingSecret: true` +
   `existingSecretName`), reference single keys of it with `common.secretRefs.<KEY>:
   {name, key}`, or fill `common.secrets` with `<path:...>` placeholders.
4. Create the GHCR pull secret in the namespace. The chart default is `ghcr-credential`
   (`imagePullSecrets: [{name: ghcr-credential}]`):

   ```bash
   kubectl -n <namespace> create secret docker-registry ghcr-credential \
     --docker-server=ghcr.io --docker-username=<github-user> --docker-password=<GHCR_READ_TOKEN>
   ```

   For a differently named Secret, override the root list, which the manager, worker,
   migrations Job and mock STA all use: `imagePullSecrets: [{name: <your-secret>}]`.
5. `helm install` with your values. Against external Postgres the migrations run as a
   Helm `pre-install`/`pre-upgrade` hook and as an ArgoCD PreSync hook (the hook Secret
   at weight -2, the Job at -1), so the app never boots unmigrated under either tool.
6. Register the BACEN operator credentials (`POST /v1/credentials`) and the
   document-type / inbound-source configs through the API before transfers run.

### RabbitMQ with a private CA (production)

The app checks both the AMQPS connection and the management health check (`https`)
against the container's system certificate pool. When the broker's certificate comes
from a private CA, give the manager **and** the worker a bundle through
`SSL_CERT_FILE`. The bundle must contain the public roots **plus** your CA, because the
public roots are still needed to reach the license gateway and any other public TLS
endpoint.

```bash
cat /etc/ssl/certs/ca-certificates.crt my-private-ca.pem > ca-bundle.pem
kubectl -n <namespace> create configmap br-sta-ca-bundle --from-file=ca-bundle.pem
```

```yaml
manager:
  extraVolumes:      [{ name: ca-bundle, configMap: { name: br-sta-ca-bundle } }]
  extraVolumeMounts: [{ name: ca-bundle, mountPath: /etc/br-sta-ca, readOnly: true }]
  extraEnvVars:      [{ name: SSL_CERT_FILE, value: /etc/br-sta-ca/ca-bundle.pem }]
worker:
  extraVolumes:      [{ name: ca-bundle, configMap: { name: br-sta-ca-bundle } }]
  extraVolumeMounts: [{ name: ca-bundle, mountPath: /etc/br-sta-ca, readOnly: true }]
  extraEnvVars:      [{ name: SSL_CERT_FILE, value: /etc/br-sta-ca/ca-bundle.pem }]
```

---

## 4. Shared configuration contract (masks / lerian-common)

Set the connections once in `global:`; the chart renders the app's native keys. Do
not repeat native keys under `common.configmap`: a native key there wins over the mask.

```yaml
global:
  env: { name: "production" }
  datastores:
    postgres: { host: "", ssl: "require" }                      # user/name default br_sta
    redis:    { host: "<host>:6379", tls: "true" }
    broker:   { host: "", amqpPort: "5671", scheme: "amqps", user: "br_sta" }
  objectStorage:
    sta:             { endpoint: "", region: "", bucket: "" }   # the same block br-sisbajud reads
    staAuditExports: { bucket: "" }                             # endpoint/region default to sta
  kms:       { vendor: "envvar" }                               # aws => KMS-wrapped MASTER_KEYS + keyId
  auth:      { enabled: true, host: "" }
  streaming: { enabled: false, brokers: "", tlsEnabled: true, saslMechanism: "SCRAM-SHA-256", saslUsername: "", topicAutoProvision: true }   # brokers/username required when enabled
```

| Global field | Native keys | Note |
|---|---|---|
| `global.env.name` | `ENV_NAME` | `production` turns on the app's production gates; development-class names allow auth off and the dev-only bundles |
| `global.datastores.postgres.*` | `POSTGRES_HOST/PORT/USER/NAME/SSLMODE`, replica keys | `sslmode=disable` is refused in production |
| `global.datastores.broker.*` | `RABBITMQ_HOST/PORT_AMQP/PORT_HOST/DEFAULT_USER/SCHEME` | The management health-check URL derives from host + `port` (https for `amqps`) |
| `global.objectStorage.sta.*` | `TRANSFER_OBJECT_STORAGE_BUCKET`, `TRANSFER_S3_*` | Keep it identical to br-sisbajud's `global.objectStorage.sta` |
| `global.kms.*` | `MASTER_KEY_PROVIDER`, `MASTER_KEY_KMS_KEY_ID`, `MASTER_KEY_KMS_REGION` | `MASTER_KEYS` is always a secret |
| `global.auth.*` | `PLUGIN_AUTH_ENABLED`, `PLUGIN_AUTH_HOST` | Defaults to `true` outside a development-class env |
| `global.streaming.*` | `STREAMING_*` transport keys | `STREAMING_SASL_USERNAME` may live in the Secret |
| `global.multiTenant.*` | `MULTI_TENANT_*` | Tuning knobs under `common.multiTenant.*` |
| `global.observability.*` | `ENABLE_TELEMETRY`, `OTEL_*` | Telemetry on with no endpoint => node-local `http://$(HOST_IP):4317` |

Compatibility knobs (values only): keep a pre-existing in-cluster address such as
`br-sta:8080` with `manager.service.name: br-sta`, `manager.service.port: 8080` and
`manager.containerPort: 4028` (the Ingress follows the Service name). Worker-only
knobs live under `worker.*` (scheduler, audit publisher/consumer/partition/cleanup/
verifier/export generator).

---

## 5. Operational notes

| Topic | What to know | Before enabling / how to confirm |
|---|---|---|
| Fail-fast render | The chart mirrors the app's boot validation: `MASTER_KEYS` (format and version), auth switch, single-tenant Postgres/Redis host, RabbitMQ host + health-check URL, production gates (Postgres password, no `sslmode=disable`, RabbitMQ + outbox + business channel on, transfer bucket, `LICENSE_KEY` + `ORGANIZATION_IDS`, no wildcard CORS), streaming brokers/SASL, reporter bridge exchange + resolver | Read the render error: it names the exact value to set |
| Production guard | `redpandaBundle` and `mockSta` are refused outside a development-class environment | `helm template ... --set global.env.name=staging` fails naming both |
| Worker is single-replica | No leader election for every loop: exactly one replica, `Recreate` | Do not scale it; scale the manager instead |
| Transfer scheduler | `TRANSFER_SCHEDULER_ENABLED` (default `true`) is the only path that uploads to BACEN | Worker log `Transfers outbound fanout started` |
| Mock profile | Any `STA_SCHEME` / `STA_FILE_HOST` / `STA_PASSWORD_HOST` redirects the STA client away from BACEN and relaxes the trust-store readiness gate | Never set them in production |
| CORS | lib-commons' middleware reads `ACCESS_CONTROL_*`; the chart renders `ACCESS_CONTROL_ALLOW_ORIGIN` from `common.cors.allowedOrigins`. Empty = deny-all | Production: explicit origins only |
| Master key | Replacing `MASTER_KEYS` makes every stored BACEN credential undecryptable | Add a new version (`v1:...,v2:...`) and switch `MASTER_KEY_VERSION` |
| Filing sweep | `worker.scheduler.filingSweepEnabled` (default `false`) auto-closes stranded reporter filings; `filingSweepAgeMinutes` is a safety knob | Enable deliberately; do not tune the age down |
| Private images | All app images are private on GHCR | Pull secret in every namespace (`imagePullSecrets`) |

### License

| Topic | Behaviour (app `1.0.0`, license SDK v4.1.0) |
|---|---|
| One key per product | A key licenses a single product. A key issued for another product is refused with `Exiting: LCS-0012: refused by the gateway (LCS-1005)`; an unknown or altered key with `(LCS-1002)` |
| On refusal | The process exits and the pod goes to `CrashLoopBackOff`. In a rolling update the pod that is already running keeps serving, so the rollout stalls but nothing goes down |
| Gateway | `https://license.lerian.io`, `POST /licenses/validate`. Egress to it is mandatory and the URL is not configurable. Keys issued for staging were validated on this production gateway. `common.license.isDevelopment: "true"` (`IS_DEVELOPMENT`) switches to `https://license.dev.lerian.io`: use it only for keys issued by the dev gateway |
| Refresh and grace | The key is re-validated every 6 h. When the gateway does not answer (network error or 5xx) after it has confirmed the key once, the process keeps serving through decaying grace windows (2 d, 1 d, 12 h, 6 h, so at most 3 d 18 h) and then exits. A process that was never confirmed gets 6 h only. A 4xx refusal ends the grace at once. The windows live in memory: a pod restarted during an outage starts unconfirmed |
| Offline | No offline license mode in this app version |
| Render gate | With `global.env.name=production` the render fails without `LICENSE_KEY` and `ORGANIZATION_IDS` |
| How to confirm | `GET /readyz` -> `checks.license` `up` (`n/a` when no license client is wired) |

---

## 6. How to validate a successful install

```bash
kubectl -n <ns> get pods
kubectl -n <ns> get jobs                          # migrations (and, in dev, buckets/topics) Complete
kubectl -n <ns> port-forward svc/<manager-service> 14028:<service-port>
curl -s localhost:14028/readyz                    # readiness (manager and worker probe path)
curl -s localhost:14028/health                    # liveness
```

| Check | Command/URL | Expected | If it doesn't match, check first |
|---|---|---|---|
| Pods | `kubectl get pods` | manager and worker `1/1 Running`, 0 restarts | `CrashLoopBackOff`: the last log line names the failing dependency (section 7) |
| Migrations | `kubectl get jobs` | `br-sta-migrations-<hash>` `Complete` | Postgres host/password, `ALLOW_INSECURE_TLS` for a plaintext Postgres |
| Readiness | `GET /readyz` | `200`, `status: healthy`; `postgres`, `redis`, `rabbitmq`, `storage_transfer` `up` (`license` `n/a` without a key; `storage_audit_exports` `skipped` on the manager) | A `down` check names the dependency; a missing bucket shows as `storage_transfer` down |
| Liveness | `GET /health` | `200 {"status":"available"}` | — |
| Worker loops | `kubectl logs deploy/<fullname>-worker` | audit publisher/consumer, business publisher, outbound fanout, `scheduler: starting leader campaign`, periodic `poll outcome` | Missing loop: its toggle under `worker.*` / `common.transfer.*` |
| Dev E2E (proved) | upload a file under `outbound/` in the transfer bucket, `POST /v1/credentials`, then `POST /v1/transfers` (`sourceProduct`, `documentType` e.g. `AJUD302`, `fileRef: outbound/<file>`, `fileName`) with a bearer token | The worker packages it, gets a protocol from the mock, polls `10 -> 15 -> 35` and the transfer ends `Accepted`; a fact lands on `lerian.streaming.br-sta` | With auth off the API still requires a bearer naming a principal (not verified in development) |
| Not exercised | Authenticated API calls against plugin-access-manager; br-sisbajud -> br-sta `POST /v1/transfers` submission (needs plugin-access-manager) | — | — |

---

## 7. Known errors and what they mean

| Error/log | Cause | Fix |
|---|---|---|
| `rabbitmq health check failed: rabbitmq health check URL is empty` (manager and worker crash-loop) | lib-commons checks the management API on every connect | The chart derives `RABBITMQ_HEALTH_CHECK_URL` from the broker host/port; set `global.datastores.broker.port` (management) or `common.rabbitmq.healthCheckUrl` if yours differs. Plain `http` needs `common.rabbitmq.allowInsecureHealthCheck: true` (the render says so) |
| `redpanda-topics` Job stuck on `waiting for ...` | The bundled Redpanda's Kafka API is not up yet (the Job waits on `rpk topic list`) | Check the `redpanda-0` pod and its logs; the Job retries until the broker answers |
| Postgres `password authentication failed` after changing the dev passwords | The data volume keeps the password it was initialised with | `helm uninstall`, delete the PVCs, reinstall |
| Browser calls blocked although `CORS_ALLOWED_ORIGINS` is set | The CORS middleware reads `ACCESS_CONTROL_ALLOW_ORIGIN` | Use `common.cors.allowedOrigins`; `*` needs `common.security.allowCorsWildcard: true` and is refused in production |
| Tooling picks `1.2.0-beta.x` over `1.0.0` | The app's version line was reset for the stable release: `1.0.0` has lower SemVer precedence but is the later, compatible release (same env and migrations) | Pin `1.0.0` explicitly |
| Boot refused in production, license errors | `LICENSE_KEY` / `ORGANIZATION_IDS` missing, a key for another product (`LCS-1005`) or an unknown key (`LCS-1002`), or no egress to the license gateway (there is no offline license mode in this app version) | Set both, use this product's key, allow egress (section 5, License) |
| `Failed to connect to plugin-auth` at boot | plugin-access-manager is not installed or not reachable yet | Informational: the pods still become Ready. Authenticated calls need plugin-access-manager |
| `PLUGIN_AUTH_ENABLED=false is only accepted in a development-class environment` | Auth off in `staging`/`production` | Enable `global.auth` or use a development-class `global.env.name` |
| `MASTER_KEYS is malformed` / `must reference a key present` | Wrong `version:hex` shape or `MASTER_KEY_VERSION` mismatch | `v1:<64 hex chars>` and `common.credentials.masterKeyVersion: v1` |
| br-sisbajud `sta_consumer` degraded after a br-sta fact | Known br-sisbajud behaviour: a fact for a transfer br-sisbajud did not create is retried and blocks the partition | Monitor `sta_consumer` on br-sisbajud's `/readyz`; see the br-sisbajud runbook |

---

## 8. Rollback

```bash
helm history br-sta -n <namespace>
helm rollback br-sta <revision> -n <namespace>
```

Under ArgoCD, revert the values/chart version commit in Git instead; a manual rollback
is undone by the next sync.

- **Migrations are forward-only.** A rollback redeploys the older chart and image but
  does not revert the schema: the migrations Job only applies `up` migrations, and the
  pre-upgrade/PreSync hook of the older revision re-runs them as a no-op. An older app
  image can refuse a schema newer than the one it ships (for example, an app build
  whose last migration is lower than the database's version fails its migration check
  at boot). Roll back to an image that knows the current schema version, or restore the
  database from a backup taken before the upgrade. Take that backup before every
  upgrade that ships migrations.
- **`MASTER_KEYS` must survive every rollback and reinstall.** The operator credentials
  stored through `POST /v1/credentials` are envelope-encrypted, and each ciphertext is
  pinned to the master-key version that encrypted it. The app decrypts through that
  version (`unknown master key version` when it is missing from `MASTER_KEYS`). Never
  change or drop an existing version. To rotate, add a new `v2:<hex>` entry next to
  `v1` and move `common.credentials.masterKeyVersion` to it: new writes use `v2` and
  old ciphertexts still decrypt with `v1`. Losing a version, or its value in the secret
  store, makes every credential encrypted under it unrecoverable: they have to be
  registered again. With `MASTER_KEY_PROVIDER=aws-kms` the same holds for the wrapped
  blobs and the KMS key that wraps them.
