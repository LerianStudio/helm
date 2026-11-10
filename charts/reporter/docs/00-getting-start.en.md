# reporter — Installation Runbook

> Filled in from the chart itself (`README.md`, `values.yaml`, `templates/`).
> Goal: someone outside the squad, with only the chart and this runbook, can install a
> working release and knows what to check if something doesn't behave as expected.

---

## 0. Metadata

| Field | Value |
|---|---|
| Product / Chart | `reporter` (chart `5.3.x` / app `4.7.0-beta.1`) |
| Chart type | `multi-component` — `manager` (API) + `worker` (KEDA ScaledJob) |
| Owning squad | Reporter |

Report generation is a pipeline: the **manager** API accepts a report request and
enqueues it on RabbitMQ; the **worker** (a KEDA-scaled Job, not a long-running
Deployment) drains the queue, queries the registered datasources, renders the document,
and writes it to object storage (SeaweedFS/S3). Manager state lives in MongoDB.

---

## 1. Installation profiles

| Profile | Shape | Use case |
|---|---|---|
| All-bundled (dev) | Bundled MongoDB + RabbitMQ + SeaweedFS + Valkey + KEDA (all `enabled: true`, default) | Local / kick-the-tyres. `ALLOW_INSECURE_TLS` defaults `true` because the bundled infra runs without TLS (section 5). |
| External infra | `mongodb`/`rabbitmq`/`seaweedfs`/`valkey.enabled: false`, endpoints via `global.datastores`/`global.objectStorage`, KEDA bundled or external | Managed Postgres/Mongo/Valkey/RabbitMQ + external S3 |
| Managed cloud | `global.cloud: aws\|gcp\|azure` sets the connection topology (TLS, S3 path-style, and AMQP scheme/port **for AWS only** — see §5); endpoints still from `global.*`; `ALLOW_INSECURE_TLS: "false"` | Client-facing |

- Both components always deploy together — the manager without a worker enqueues jobs
  nothing drains; the worker without the manager has nothing to consume.
- **KEDA** runs the worker as a ScaledJob by default. Use the bundled operator
  (`keda.enabled: true`) or an external one (`keda.enabled: false` + `keda.external: true`).
  With both off, the worker runs as a Deployment with an HPA.

---

## 2. External dependencies

| Dependency | When it's needed | How the chart receives it |
|---|---|---|
| MongoDB | Always — manager state | Bundled subchart (Pattern A: app reads `<release>-mongodb` Secret via `secretKeyRef` — leave `MONGO_PASSWORD` unset), **or** external via `global.datastores.mongo` + `secrets.MONGO_PASSWORD` |
| RabbitMQ | Always — manager→worker job queue | Bundled groundhog2k subchart (Pattern B: broker points at the app Secret via `rabbitmq.authentication.existingSecret`), **or** external + optional topology bootstrap (`externalRabbitmqDefinitions`, section 5) |
| SeaweedFS / S3 | Always — rendered report output | Bundled subchart, **or** external via `global.objectStorage.s3` (endpoint/region/bucket) |
| Valkey / Redis | Always (cache) | Bundled subchart (auth **disabled** — no `REDIS_PASSWORD`), or external via `global.datastores.redis` |
| KEDA | By default (worker is a ScaledJob) | Bundled operator (`keda.enabled: true`) or external (`keda.external: true`) |
| Report **datasources** (Midaz onboarding/transaction DBs, plugin DBs, any external DB) | Always — the data the reports read | `DATASOURCE_<NAME>_*` keys in `common.configmap`; passwords in `secrets` — sections 4/5 |
| `lerian-common` (library chart) | Always | Chart dependency; provides templates + `global.*` masks. Nothing to configure. |
| plugin-access-manager (auth) | When the manager API is exposed | `global.auth.host` / `PLUGIN_AUTH_*` |
| Vault / secret manager | Recommended in production | `manager.useExistingSecret`/`worker.useExistingSecret` + `existingSecretName`, or Vault refs in `secrets:` (`useExistingSecret` needs `rabbitmq.enabled: false`) |

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
   - `secrets.LICENSE_KEY` — required from app 4.6.0 (the default image is 4.7.0-beta.1). The render fails while it is empty, and the manager and the worker refuse to boot without it.
   - With bundled RabbitMQ: `secrets.RABBITMQ_DEFAULT_PASS` and a **stable**
     `secrets.RABBITMQ_ERLANG_COOKIE` (`openssl rand -hex 32`; must not change across
     upgrades).
   - MongoDB password: leave unset with the bundled subchart (single-sourced); set
     `secrets.MONGO_PASSWORD` only for external Mongo.
3. Register the report datasources: `DATASOURCE_<NAME>_*` connection keys under
   `common.configmap`, matching `DATASOURCE_<NAME>_PASSWORD` under `secrets` (section 4).
4. Ensure KEDA is available (bundled or external) — the worker will not scale without it.
5. `ALLOW_INSECURE_TLS`: keep `"true"` for the bundled non-TLS infra (default); set
   `"false"` for any TLS-terminated / managed-cloud topology. `global.cloud` does not
   change it.
6. ClusterRole: the manager creates a ClusterRole+Binding (CRD/deployment access). If it
   already exists from a prior install, set `manager.clusterRole.create: false`.
7. `helm install reporter … -n reporter --create-namespace`. The chart's **hardcoded
   infra hosts** (e.g. the default `MONGO_HOST`/`RABBITMQ_HOST`) assume the release is
   named **`reporter`**; if you rename the release, override those hosts (section 5). The
   `<release>-mongodb` Secret ref **auto-follows** the release name (via
   `reporter.infraSecretRef`), so it needs no manual change; RabbitMQ's
   `rabbitmq.authentication.existingSecret` only needs re-pointing if you change
   `manager.name` / `manager.existingSecretName`.

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
| `global.auth.host` | `PLUGIN_AUTH_ADDRESS` | `common.configmap.PLUGIN_AUTH_ADDRESS` |

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

**Optional** (PostgreSQL): `SSLMODE` (default `disable`), `SSLROOTCERT` (default `""`).
The schema list is `DATASOURCE_<CONFIG_NAME>_SCHEMAS`, keyed by the `CONFIG_NAME` value in
upper case (comma list, default `public`).
**MongoDB datasources** can also set `OPTIONS` (URI options, e.g. `authSource=admin`).

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
| **`ALLOW_INSECURE_TLS` defaults `true`** | The bundled mongo/redis/rabbitmq run without TLS and the app hard-fails ("TLS required") unless this bypass is on, so a zero-override install works. | Flip to `"false"` on any managed-cloud/TLS-terminated topology; `global.cloud` does not change it. |
| **RabbitMQ Erlang cookie must be stable** | With the bundled broker, `RABBITMQ_ERLANG_COOKIE` must not change across upgrades or the broker won't re-form its cluster/quorum. | Generate once and pin it; never let CI regenerate it. |
| **Worker is a KEDA ScaledJob (scale-to-zero)** | Not a Deployment — it has no readiness/liveness probes. Zero worker pods at idle is normal; pods appear when the RabbitMQ queue has depth. | Don't alert on "0 worker pods". Confirm scaling by enqueuing a report and watching Jobs appear. |
| **SeaweedFS ServiceAccount was renamed** | `seaweedfs.global.serviceAccountName` is now `reporter-seaweedfs` (was `seaweedfs`) to avoid cross-release collisions. On upgrade from a chart older than 4.0.0 this triggers a one-time SeaweedFS pod restart; IRSA/RoleBinding pinned to the old name must be updated. | Only relevant if `seaweedfs.enabled: true`. Update IAM/IRSA annotations to the new SA name before upgrading. |
| **Manager ClusterRole is cluster-scoped** | The manager gets a ClusterRole+Binding for CRD/deployment access, named `<manager.name>-<namespace>`; two releases in one namespace collide. | Set `manager.clusterRole.create: false` when it already exists. |
| **External RabbitMQ bootstrap is topology-only** | `externalRabbitmqDefinitions` declares exchanges/queues/bindings on vhost `/`; it does **not** create the app user, its permissions, or the vhost. | Provision the app user + permissions on the broker first; then enable the bootstrap job. |
| **Release name affects hardcoded hosts only** | The default infra hosts (`MONGO_HOST`, `RABBITMQ_HOST`, …) assume release `reporter`. The `<release>-mongodb` Secret ref auto-follows the release (`reporter.infraSecretRef`); `reporter-manager` derives from `manager.name`, not the release name. | Install as `reporter`, or override the infra hosts. Re-point `rabbitmq.authentication.existingSecret` **only** if you change `manager.name`/`manager.existingSecretName`. |
| **Broker topology preset is AWS-only** | `global.cloud` supplies `broker` (AMQP scheme/port) **only** for `aws`. `gcp`/`azure` omit it, so `scheme`/`amqpPort` fall back to `amqp`/`5672` — an external TLS or non-default broker then fails for both the app and the KEDA trigger (they share the resolver). | On GCP/Azure or any external TLS/non-default broker, set `global.datastores.broker.scheme`/`amqpPort` (or `common.configmap.RABBITMQ_URI`/`RABBITMQ_PORT_AMQP`) explicitly. |

---

## 6. How to validate a successful install

```bash
kubectl get pods -n reporter               # manager Running; worker pods only under load
kubectl get scaledobject,scaledjob,triggerauthentication -n reporter
kubectl -n reporter port-forward svc/reporter-manager 4005:4005 &
# wait for the forward to be ready before curling (avoids a transient connection-refused):
until curl -fsS http://localhost:4005/health >/dev/null 2>&1; do sleep 1; done
curl -fsS http://localhost:4005/health     # liveness
curl -fsS http://localhost:4005/version    # build identity
# API docs (needs manager.configmap.SWAGGER_ENABLED: "true"): http://localhost:4005/swagger/index.html
# readiness lives on the internal health port, reach it through a pod:
#   kubectl -n reporter port-forward pod/<manager-pod> 8099:8099 & curl -fsS http://localhost:8099/readyz
```

| Check | Command/URL | Expected | If it doesn't match, check first |
|---|---|---|---|
| Manager pod | `kubectl get pods -n reporter` | `Running`, `1/1` | `CreateContainerConfigError` → missing Secret; render/boot error naming `DATASOURCE_CRED_ENC_KEY` → set it (section 5) |
| Liveness / Readiness | `curl …:4005/health`; `/readyz` on the health port 8099 | `200` | Not Ready → a startup check has not passed (see `/readyz` `checks`); check `ALLOW_INSECURE_TLS` vs your infra |
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
| `ClusterRole … already exists` on install | Another release in the same namespace already created the manager ClusterRole | `manager.clusterRole.create: false` |
| RabbitMQ won't start / loses its cluster after upgrade | `RABBITMQ_ERLANG_COOKIE` changed between installs | Pin a stable cookie; restore the original value |
| Worker never spawns Jobs under load | KEDA operator absent, or the RabbitMQ trigger/TriggerAuthentication can't reach the broker | Install KEDA (bundled or external) and verify the trigger credentials |
| A datasource password shows up in the ConfigMap | `DATASOURCE_<NAME>_PASSWORD` placed under `common.configmap` instead of `secrets` | Move it to `secrets:` and rotate the exposed credential |
| SeaweedFS pods restart / IRSA breaks after upgrade | SeaweedFS ServiceAccount renamed to `reporter-seaweedfs` (chart 4.0.0) | Update IAM/IRSA/RoleBinding refs to the new SA name |
| Reports enqueue but never produce output | Object storage endpoint/bucket wrong, or worker not scaling | Verify `global.objectStorage.s3` + KEDA scaling (section 6) |
