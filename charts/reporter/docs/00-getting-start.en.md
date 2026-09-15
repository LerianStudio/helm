# reporter — Installation Runbook

> Filled in from the chart itself (`README.md`, `values.yaml`, `templates/`) and the
> reference configuration in
> `lerian-internal-gitops/environments/benedita/helmfile/applications/dev-st/reporter`.
> Goal: someone outside the squad, with only the chart and this runbook, can install a
> working release and knows what to check if something doesn't behave as expected.

---

## 0. Metadata

| Field | Value |
|---|---|
| Product / Chart | `reporter` (chart `4.3.x` / app `3.0.0`) |
| Chart type | `multi-component` — `manager` (API) + `worker` (KEDA ScaledJob) |
| Owning squad | Reporter |
| Last review of this runbook | 2026-09-15, against chart `4.3.x` |
| Escalation contact | Reporter squad (see chart CODEOWNERS) |

Report generation is a pipeline: the **manager** API accepts a report request and
enqueues it on RabbitMQ; the **worker** (a KEDA-scaled Job, not a long-running
Deployment) drains the queue, queries the registered datasources, renders the document,
and writes it to object storage (SeaweedFS/S3). Manager state lives in MongoDB.

---

## 1. Installation profiles

| Profile | Shape | Use case |
|---|---|---|
| All-bundled (dev) | Bundled MongoDB + RabbitMQ + SeaweedFS + Valkey + KEDA (all `enabled: true`, default) | Local / kick-the-tyres. `ALLOW_INSECURE_TLS` defaults `true` because the bundled infra runs without TLS (section 5). |
| External infra | `mongodb`/`rabbitmq`/`seaweedfs`/`valkey.enabled: false`, endpoints via `global.datastores`/`global.objectStorage`, KEDA bundled or external | The `benedita/dev-st` reference topology (managed Postgres/Mongo/Valkey/RabbitMQ + external S3) |
| Managed cloud | `global.cloud: aws\|gcp\|azure` sets the connection topology (TLS, AMQP scheme, S3 path-style); endpoints still from `global.*`; `ALLOW_INSECURE_TLS: "false"` | Client-facing |

- Both components always deploy together — the manager without a worker enqueues jobs
  nothing drains; the worker without the manager has nothing to consume.
- **KEDA is a hard dependency** of the worker (it is a ScaledJob). Use the bundled
  operator (`keda.enabled: true`) or an external one (`keda.enabled: false` +
  `keda.external: true`) — but it must exist.

---

## 2. External dependencies

| Dependency | When it's needed | How the chart receives it |
|---|---|---|
| MongoDB | Always — manager state | Bundled subchart (Pattern A: app reads `<release>-mongodb` Secret via `secretKeyRef` — leave `MONGO_PASSWORD` unset), **or** external via `global.datastores.mongo` + `secrets.MONGO_PASSWORD` |
| RabbitMQ | Always — manager→worker job queue | Bundled groundhog2k subchart (Pattern B: broker points at the app Secret via `rabbitmq.authentication.existingSecret`), **or** external + optional topology bootstrap (`externalRabbitmqDefinitions`, section 5) |
| SeaweedFS / S3 | Always — rendered report output | Bundled subchart, **or** external via `global.objectStorage.s3` (endpoint/region/bucket) |
| Valkey / Redis | Always (cache) | Bundled subchart (auth **disabled** — no `REDIS_PASSWORD`), or external via `global.datastores.redis` |
| KEDA | Always (worker is a ScaledJob) | Bundled operator (`keda.enabled: true`) or external (`keda.external: true`) |
| Report **datasources** (Midaz onboarding/transaction DBs, plugin DBs, any external DB) | Always — the data the reports read | `DATASOURCE_<NAME>_*` keys in `common.configmap`; passwords in `secrets` — sections 4/5 |
| `lerian-common` (library chart) | Always | Chart dependency; provides templates + `global.*` masks. Nothing to configure. |
| plugin-access-manager (auth) | When the manager API is exposed | `global.auth.host` / `PLUGIN_AUTH_*` |
| Vault / secret manager | Recommended in production | `manager.useExistingSecret`/`worker.useExistingSecret` + `existingSecretName`, or Vault refs in `secrets:` |

The onboarding datasource is the built-in one; every other datasource (transaction,
plugin DBs, external DBs) is registered by the operator — see section 4.

---

## 3. Installation order

1. Decide bundled vs external for each of MongoDB / RabbitMQ / SeaweedFS / Valkey. For
   external, set `global.datastores.{mongo,redis,broker}` + `global.objectStorage.s3`
   (and `global.cloud` for the TLS/topology preset).
2. Provide the required secrets **before** `helm install`:
   - `secrets.DATASOURCE_CRED_ENC_KEY` — hex AES key (`openssl rand -hex 32`).
     **Required from app 3.0.0** on both components, **must be identical**, **not
     rotatable**. The render fails if an `image.tag >= 3.0.0` is set and this is empty.
   - `secrets.DATASOURCE_ONBOARDING_PASSWORD` — the built-in onboarding datasource.
   - With bundled RabbitMQ: `secrets.RABBITMQ_DEFAULT_PASS` and a **stable**
     `secrets.RABBITMQ_ERLANG_COOKIE` (`openssl rand -hex 32`; must not change across
     upgrades).
   - MongoDB password: leave unset with the bundled subchart (single-sourced); set
     `secrets.MONGO_PASSWORD` only for external Mongo.
3. Register the report datasources: `DATASOURCE_<NAME>_*` connection keys under
   `common.configmap`, matching `DATASOURCE_<NAME>_PASSWORD` under `secrets` (section 4).
4. Ensure KEDA is available (bundled or external) — the worker will not scale without it.
5. `ALLOW_INSECURE_TLS`: keep `"true"` for the bundled non-TLS infra (default); set
   `"false"` for any TLS-terminated / managed-cloud topology (`global.cloud` presets do
   this for you).
6. ClusterRole: the manager creates a ClusterRole+Binding (CRD/deployment access). If it
   already exists from a prior install, set `manager.clusterRole.create: false`.
7. `helm install reporter … -n reporter --create-namespace`. The infra hosts and the
   `<release>-mongodb` / `reporter-manager` Secret refs assume the release is named
   **`reporter`** — if you rename it, re-point `rabbitmq.authentication.existingSecret`.

---

## 4. Shared configuration contract (masks / lerian-common) + datasources

Set endpoints **once per environment** under `global.*`; a native `common.configmap.<KEY>`
always overrides the mask.

```yaml
global:
  cloud: "aws"          # aws|gcp|azure — sets TLS/AMQP/S3 topology; unset = bundled dev
  datastores:
    mongo:  { host: "", port: "27017", user: "" }
    redis:  { host: ":6379" }            # host carries host:port; REDIS_USER via mask
    broker: { host: "" }                 # RabbitMQ
  objectStorage:
    s3: { endpoint: "", region: "", bucket: "" }
  observability: { enabled: true }
  auth: { host: "" }                     # plugin-access-manager
```

| Global field | Effect | Overriding native key |
|---|---|---|
| `global.datastores.mongo.*` | `MONGO_HOST`/`PORT`/`USER` (+ topology from `global.cloud`) | `common.configmap.MONGO_*` |
| `global.datastores.redis.*` | `REDIS_HOST`/`REDIS_USER` | `common.configmap.REDIS_*` |
| `global.datastores.broker.*` | `RABBITMQ_HOST` (+ AMQP scheme/port from `global.cloud`) | `common.configmap.RABBITMQ_*` |
| `global.objectStorage.s3.*` | `OBJECT_STORAGE_ENDPOINT`/region/bucket | `common.configmap.OBJECT_STORAGE_*` |
| `global.observability.enabled` | `ENABLE_TELEMETRY` | `common.configmap.ENABLE_TELEMETRY` |
| `global.auth.host` | `PLUGIN_AUTH_HOST` | `common.configmap.PLUGIN_AUTH_HOST` |

### 4.1 Datasources (the report data sources) — required config

Datasources are what the reports actually read. They are a **declared open namespace**:
`DATASOURCE_<NAME>_<PROPERTY>` is accepted by the strict `values.schema.json` for any
`<NAME>` you choose (guard: `propertyNames: pattern ^DATASOURCE_...`), so you register
datasources without touching the schema, while a typo *outside* the family (e.g.
`REDIS_HOSTX`) is still rejected at `helm install`. Pick a unique uppercase `<NAME>` per
datasource (`ONBOARDING`, `TRANSACTION`, `SALES`, …). Connection keys go under
`common.configmap`; the matching `DATASOURCE_<NAME>_PASSWORD` goes under `secrets`.

**Required per datasource** (`DATASOURCE_<NAME>_…`):

| Property | Description | Example |
|---|---|---|
| `CONFIG_NAME` | Logical name used to reference it in report templates | `external_db` |
| `HOST` | Database host or IP | `external-postgres.example.com` |
| `PORT` | Database port | `5432` |
| `USER` | Database username | `db_user` |
| `PASSWORD` | Password — **must be under `secrets`**, not `configmap` | `…` |
| `DATABASE` | Database name | `external_database` |
| `TYPE` | Engine — `postgresql` or `mongodb` | `postgresql` |

**Optional** (SQL): `SSLMODE` (default `disable`), `SSLROOTCERT` (default `""`),
`DB_SCHEMAS` (comma list, default `public`).
**MongoDB datasources** additionally use `URI` (e.g. `mongodb`), `OPTIONS`
(e.g. `authSource=admin&directConnection=true&maxIdleTimeMS=60000`) and `MAX_POOL_SIZE`
instead of the SQL SSL keys.

The built-in **`ONBOARDING`** datasource (the Midaz onboarding DB) is always registered —
its password is `secrets.DATASOURCE_ONBOARDING_PASSWORD` (a required secret).

**Minimal example (one external Postgres datasource):**

```yaml
common:
  configmap:
    DATASOURCE_SALES_CONFIG_NAME: sales_db
    DATASOURCE_SALES_HOST: sales-postgres.example.com
    DATASOURCE_SALES_PORT: "5432"
    DATASOURCE_SALES_USER: sales_user
    DATASOURCE_SALES_DATABASE: sales
    DATASOURCE_SALES_TYPE: postgresql
    DATASOURCE_SALES_SSLMODE: require
    DATASOURCE_SALES_DB_SCHEMAS: sales,inventory   # optional
secrets:
  DATASOURCE_SALES_PASSWORD: "…"
```

**Reference topology (`benedita/dev-st`) — several datasources of both engines** side by
side, showing the SQL and MongoDB shapes:

```yaml
common:
  configmap:
    # SQL (Midaz Postgres) — onboarding is the built-in one
    DATASOURCE_ONBOARDING_CONFIG_NAME: midaz_onboarding
    DATASOURCE_ONBOARDING_HOST: postgresql.dev-st.lerian.net
    DATASOURCE_ONBOARDING_PORT: "5432"
    DATASOURCE_ONBOARDING_USER: midaz
    DATASOURCE_ONBOARDING_DATABASE: onboarding
    DATASOURCE_ONBOARDING_TYPE: postgresql
    DATASOURCE_ONBOARDING_SSLMODE: disable

    DATASOURCE_TRANSACTION_CONFIG_NAME: midaz_transaction
    DATASOURCE_TRANSACTION_HOST: postgresql.dev-st.lerian.net
    DATASOURCE_TRANSACTION_PORT: "5432"
    DATASOURCE_TRANSACTION_USER: midaz
    DATASOURCE_TRANSACTION_DATABASE: transaction
    DATASOURCE_TRANSACTION_TYPE: postgresql
    DATASOURCE_TRANSACTION_SSLMODE: disable

    # MongoDB (metadata / plugin DBs) — note URI/OPTIONS/MAX_POOL_SIZE, no SSLMODE
    DATASOURCE_ONBOARDING_METADATA_CONFIG_NAME: midaz_onboarding_metadata
    DATASOURCE_ONBOARDING_METADATA_URI: mongodb
    DATASOURCE_ONBOARDING_METADATA_HOST: mongodb.dev-st.lerian.net
    DATASOURCE_ONBOARDING_METADATA_PORT: "27017"
    DATASOURCE_ONBOARDING_METADATA_DATABASE: onboarding
    DATASOURCE_ONBOARDING_METADATA_USER: midaz
    DATASOURCE_ONBOARDING_METADATA_TYPE: mongodb
    DATASOURCE_ONBOARDING_METADATA_MAX_POOL_SIZE: "20"
    DATASOURCE_ONBOARDING_METADATA_OPTIONS: "authSource=admin&directConnection=true&maxIdleTimeMS=60000"

    DATASOURCE_FEES_CONFIG_NAME: plugin_fees
    DATASOURCE_FEES_URI: mongodb
    DATASOURCE_FEES_HOST: mongodb.dev-st.lerian.net
    DATASOURCE_FEES_PORT: "27017"
    DATASOURCE_FEES_DATABASE: plugin-fees-db
    DATASOURCE_FEES_USER: plugin-fees
    DATASOURCE_FEES_TYPE: mongodb
    DATASOURCE_FEES_OPTIONS: "authSource=admin&directConnection=true&maxIdleTimeMS=60000"

secrets:
  DATASOURCE_ONBOARDING_PASSWORD: "…"        # required (built-in)
  DATASOURCE_TRANSACTION_PASSWORD: "…"
  DATASOURCE_ONBOARDING_METADATA_PASSWORD: "…"
  DATASOURCE_FEES_PASSWORD: "…"
```

**Using a datasource in a report template** — reference it by `CONFIG_NAME`, optionally
scoping the schema `config_name:schema.table`:

```
external_db:orders               # default (public) schema
external_db:sales.orders         # explicit schema
analytics_db:reports.monthly_summary
```

> ⚠️ `DATASOURCE_CRED_ENC_KEY` and every `DATASOURCE_<NAME>_PASSWORD` belong under
> `secrets:`, **never** `common.configmap:` — the configmap escape-hatch accepts any
> `DATASOURCE_*` key, so a misplaced credential lands in a plaintext ConfigMap with no
> warning.

---

## 5. Operational notes

| Topic | What to know | Before enabling / how to confirm |
|---|---|---|
| **`DATASOURCE_CRED_ENC_KEY` (app ≥ 3.0.0)** | Hex AES key that encrypts registered datasource credentials at rest. **Identical** on manager + worker, **not rotatable** in that release. Render fails if an `image.tag >= 3.0.0` is set and it's empty. | Generate once (`openssl rand -hex 32`), store in a secret manager, set the same value on both components. |
| **`ALLOW_INSECURE_TLS` defaults `true`** | The bundled mongo/redis/rabbitmq run without TLS and the app hard-fails ("TLS required") unless this bypass is on, so a zero-override install works. | Flip to `"false"` on any managed-cloud/TLS-terminated topology (the `global.cloud` presets do this). |
| **RabbitMQ Erlang cookie must be stable** | With the bundled broker, `RABBITMQ_ERLANG_COOKIE` must not change across upgrades or the broker won't re-form its cluster/quorum. | Generate once and pin it; never let CI regenerate it. |
| **Worker is a KEDA ScaledJob (scale-to-zero)** | Not a Deployment — it has no readiness/liveness probes. Zero worker pods at idle is normal; pods appear when the RabbitMQ queue has depth. | Don't alert on "0 worker pods". Confirm scaling by enqueuing a report and watching Jobs appear. |
| **SeaweedFS ServiceAccount was renamed** | `seaweedfs.global.serviceAccountName` is now `reporter-seaweedfs` (was `seaweedfs`) to avoid cross-release collisions. On upgrade this triggers a one-time SeaweedFS pod restart; IRSA/RoleBinding pinned to the old name must be updated. | Only relevant if `seaweedfs.enabled: true`. Update IAM/IRSA annotations to the new SA name before upgrading. |
| **Manager ClusterRole is cluster-scoped** | The manager gets a ClusterRole+Binding for CRD/deployment access; a fixed name collides if two releases create it. | Set `manager.clusterRole.create: false` when it already exists. |
| **External RabbitMQ bootstrap is topology-only** | `externalRabbitmqDefinitions` declares exchanges/queues/bindings on vhost `/`; it does **not** create the app user, its permissions, or the vhost. | Provision the app user + permissions on the broker first; then enable the bootstrap job. |
| **Release name is load-bearing** | Hardcoded infra hosts + `<release>-mongodb`/`reporter-manager` Secret refs assume release `reporter`. | Install as `reporter`, or re-point `rabbitmq.authentication.existingSecret` and the Mongo refs. |

---

## 6. How to validate a successful install

```bash
kubectl get pods -n reporter               # manager Running; worker pods only under load
kubectl get scaledobject,scaledjob,triggerauthentication -n reporter
kubectl -n reporter port-forward svc/reporter-manager 4005:4005 &
curl -fsS http://localhost:4005/health     # liveness
curl -fsS http://localhost:4005/readyz     # readiness
# API docs: http://localhost:4005/swagger/index.html
```

| Check | Command/URL | Expected | If it doesn't match, check first |
|---|---|---|---|
| Manager pod | `kubectl get pods -n reporter` | `Running`, `1/1` | `CreateContainerConfigError` → missing Secret; render/boot error naming `DATASOURCE_CRED_ENC_KEY` → set it (section 5) |
| Liveness / Readiness | `curl …:4005/health` and `/readyz` | `200` | Not Ready → manager can't reach Mongo/RabbitMQ; check `ALLOW_INSECURE_TLS` vs your infra |
| KEDA wiring | `kubectl get scaledjob,triggerauthentication -n reporter` | present | Absent → KEDA CRDs missing (operator not installed); worker will never scale |
| Worker scales | enqueue a report, then `kubectl get jobs -n reporter` | Jobs appear, then complete | No Jobs → KEDA trigger/queue not reachable; check RabbitMQ + TriggerAuthentication |
| Report output | generate a report, check object storage | file written to the bucket | Missing → SeaweedFS/S3 endpoint or credentials wrong |
| Datasource query | a report that reads a registered datasource | rows returned | Empty/error → `DATASOURCE_<NAME>_*` connection wrong, or password left in `configmap` (must be in `secrets`) |

---

## 7. Known errors and what they mean

| Error/log | Cause | Fix |
|---|---|---|
| Render fails naming `DATASOURCE_CRED_ENC_KEY` | `image.tag >= 3.0.0` with the key empty | Set the hex AES key (identical on manager + worker) |
| Manager `CrashLoopBackOff`, log "TLS required" (Mongo) | `ALLOW_INSECURE_TLS: "false"` against non-TLS bundled infra | Keep `"true"` for bundled infra; `"false"` only with real TLS |
| `ClusterRole … already exists` on install | A prior release created the manager ClusterRole (fixed name) | `manager.clusterRole.create: false` |
| RabbitMQ won't start / loses its cluster after upgrade | `RABBITMQ_ERLANG_COOKIE` changed between installs | Pin a stable cookie; restore the original value |
| Worker never spawns Jobs under load | KEDA operator absent, or the RabbitMQ trigger/TriggerAuthentication can't reach the broker | Install KEDA (bundled or external) and verify the trigger credentials |
| A datasource password shows up in the ConfigMap | `DATASOURCE_<NAME>_PASSWORD` placed under `common.configmap` instead of `secrets` | Move it to `secrets:` and rotate the exposed credential |
| SeaweedFS pods restart / IRSA breaks after upgrade | SeaweedFS ServiceAccount renamed to `reporter-seaweedfs` | Update IAM/IRSA/RoleBinding refs to the new SA name |
| Reports enqueue but never produce output | Object storage endpoint/bucket wrong, or worker not scaling | Verify `global.objectStorage.s3` + KEDA scaling (section 6) |
