# product-console — Installation Runbook

> Filled in from the chart itself (`README.md`, `values.yaml`, `templates/`).
> Goal: someone outside the squad, with only the chart and this runbook, can install a
> working release and knows what to check if something doesn't behave as expected.

---

## 0. Metadata

| Field | Value |
|---|---|
| Product / Chart | `product-console` (chart `4.0.x` onward; app version: `appVersion` in `Chart.yaml` / `image.tag` in `values.yaml`) |
| Chart type | `single-service` — one Deployment (Next.js UI + BFF for Midaz) |
| Owning squad | Console / Frontend |
| Escalation contact | Lerian Studio, support@lerian.studio (maintainer in `Chart.yaml`) |

The console is a single workload, not a multi-component app. Its "profile" is not
*which* components you enable (there is only one) but *what it points at*: the sibling
Lerian services, the MongoDB it stores console state in, whether authorization is on,
and which managed-cloud preset applies.

---

## 1. Installation profiles

| Profile | Shape | Use case |
|---|---|---|
| Standalone demo | Bundled MongoDB (`mongodb.enabled: true`, default), `ingress.enabled: false`, auth off | Local/kick-the-tyres only. The published image will not start with auth off (section 5): set `global.auth.enabled: "true"` here too. **Not** for anything exposed. |
| Integrated dev/homolog | External MongoDB, ingress on, sibling base paths pointed at the real in-cluster services, auth on | Shared dev or homologation environment |
| Production | External managed MongoDB (DocumentDB via `global.cloud: aws`), ingress + TLS, auth on, `NEXTAUTH_SECRET` from a secret manager, `TRUSTED_PROXIES` set to the ingress and load-balancer addresses in front of the console | Client-facing |

- The bundled MongoDB subchart ships **enabled by default** — convenient for a demo,
  but see section 5 (it is not a managed
  database). Production must set `mongodb.enabled: false` and point at external Mongo.
- There is no "components" axis here; every knob below is a value on the single
  Deployment.

---

## 2. External dependencies

| Dependency | When it's needed | How the chart receives it |
|---|---|---|
| MongoDB | Always — the console stores its own state (organizations UI cache, settings) here | Bundled subchart (`mongodb.enabled: true`) **or** external via `MONGO_HOST`/`MONGODB_USER` in `configmap` + `MONGODB_PASS` in `secrets`, or the `global.datastores.mongo` mask — section 4 |
| `lerian-common` (library chart) | Always | Chart dependency; provides HPA/PDB/Service/Ingress templates and the `global.*` masks. Nothing to configure. |
| Midaz ledger | Always (the console is a UI for it) | `MIDAZ_BASE_PATH` / `MIDAZ_TRANSACTION_BASE_PATH` / `MIDAZ_V2_BASE_PATH` in `configmap` — defaults to `midaz-ledger.midaz.svc.cluster.local:3002` |
| plugin-access-manager (auth + identity) | Required when authorization is on (recommended everywhere exposed) | `PLUGIN_AUTH_*` / `PLUGIN_IDENTITY_*` in `configmap`, client id/secret in `secrets` — section 3 (install order) |
| Sibling services (Reporter, Tracer, Matcher, Flowker, Lender, Bank Transfer, Payments, …) | Only the features you enable in the UI | One `*_BASE_PATH` per service. `REPORTER_BASE_PATH` has an in-cluster default; `TRACER_BASE_PATH`, `MATCHER_BASE_PATH`, `FLOWKER_BASE_PATH` and `LENDER_BASE_PATH` are declared without one; any other service's key goes through `extraEnvVars`. CRM and Fees are served by the ledger through `MIDAZ_V2_BASE_PATH`. A feature whose base path is wrong just fails that feature, not startup. |
| OTEL collector | Optional (telemetry) | `otel.external: true` injects `OTEL_URL_*`/`HOST_IP` for a node-local DaemonSet collector; or `ENABLE_TELEMETRY`/`global.observability` |
| Vault / secret manager | Recommended in production | `useExistingSecret: true` + `existingSecretName`, or Vault refs in the values `secrets:` block |

The console reaches the ledger, the Access Manager, CRM and Reporter by **in-cluster FQDN** (`<svc>.<ns>.svc.cluster.local`)
out of the box, so they work across namespaces with no mesh/DNS wiring — override a
`*_BASE_PATH` only when your service/namespace names differ.

---

## 3. Installation order

1. Decide the MongoDB story: bundled (`mongodb.enabled: true`, demo only) **or**
   external (`mongodb.enabled: false` + a real `MONGO_HOST` + `MONGODB_PASS`; `MONGODB_URI` is only the scheme: `mongodb`. The console always adds `MONGO_PORT`, which a `mongodb+srv` URI refuses).
   For managed Mongo (DocumentDB) also set `global.cloud: aws` so the TLS connection
   string shape is applied automatically (section 5).
2. Provide the required production secrets **before** `helm install`: `secrets.NEXTAUTH_SECRET` (NextAuth signing key — the console refuses to start without it), `secrets.MONGODB_PASS` for an external MongoDB only (with the bundled MongoDB, leave it empty: the chart wires the password, except with `useExistingSecret: true`, where your Secret must carry `MONGODB_PASS` set to the bundled MongoDB root password), and — when auth is on — `PLUGIN_AUTH_CLIENT_ID`/`_SECRET`.
3. Turn authorization **on explicitly** for any exposed environment:
   `global.auth.enabled: "true"` (or `configmap.PLUGIN_AUTH_ENABLED: "true"`). The
   published console image refuses to start with authorization off (it exits 1) — see section 5.
4. Point the inter-service base paths at your real services if the namespaces differ
   from the defaults (Midaz, access-manager, Reporter, …).
5. Set `TRUSTED_PROXIES` to the ingress and load-balancer addresses in front of the console, as they appear as `X-Forwarded-For` hops. Never use the pod or Service CIDR (see the chart README, "Client IP resolution"). Empty means no client IP is ever resolved, so a tenant IP allowlist has nothing to judge (section 5).
6. Configure `ingress` (class, host, TLS) and set `NEXTAUTH_URL` to the public URL the
   browser uses for OAuth callbacks (defaults to the first ingress host as `https://…`).
   Set `configmap.ALLOWED_ORIGINS` explicitly whenever there is no ingress host, or the browser-facing URL differs from that first ingress host (custom domain, CDN, or extra origins). It defaults to the first ingress host's origin, or to empty without one — **not** to `NEXTAUTH_URL` — and the console rejects every write (POST, PUT, PATCH, DELETE) from an origin outside it with `403`.
7. `helm install … -n product-console --create-namespace`. The chart ships `namespaceOverride: product-console` and writes it into every console resource, so install into `product-console`, or set `namespaceOverride` to the namespace you pass to `-n` (see the chart README).

---

## 4. Shared configuration contract (masks / lerian-common)

The console consumes `lerian-common` masks: set a value **once per environment** under
`global.*` and every consuming key picks it up. A native `configmap.<KEY>` always wins
over the mask.

```yaml
global:
  # Access Manager gate — TURN THIS ON for any exposed env (default is OFF)
  auth:
    enabled: "true"
  # Telemetry
  observability:
    enabled: "true"
  # Env-wide MongoDB connection (external Mongo). MONGODB_DB_NAME stays per-app.
  datastores:
    mongo:
      host: ""
      port: "27017"
      user: ""
      # params: omit on AWS. Any value here, "" included, overrides the global.cloud: aws preset
  # Managed-cloud preset (AWS DocumentDB TLS connection string), applied when no
  # more specific override is set. gcp/azure have no Mongo preset today.
  cloud: "aws"
# Telemetry on needs an exporter, or the render fails (section 5)
otel:
  external: true
```

| Global field | Effect (env var) | Overriding native key |
|---|---|---|
| `global.auth.enabled` | `PLUGIN_AUTH_ENABLED` | `configmap.PLUGIN_AUTH_ENABLED` |
| `global.observability.enabled` | `ENABLE_TELEMETRY` | `configmap.ENABLE_TELEMETRY` |
| `global.datastores.mongo.{uri,host,port,user,params}` | `MONGODB_URI`/`MONGO_HOST`/`MONGO_PORT`/`MONGODB_USER`/`MONGO_PARAMETERS` | the matching `configmap.<KEY>` |
| `global.cloud: aws` | Sets `MONGO_PARAMETERS` to the DocumentDB shape (`tls=true&tlsInsecure=true&directConnection=true&retryWrites=false&…`) | `configmap.MONGO_PARAMETERS` or `global.datastores.mongo.params` |

The console does not read `PLUGIN_AUTH_HOST`: set `configmap.PLUGIN_AUTH_BASE_PATH` to change its Access Manager address.

**Every `configmap.<KEY>` default lives in `templates/configmap.yaml`** (as
`KEY | default "…"`), never in `values.yaml` — the `configmap:` map ships empty. Set a
key there only to override a shipped default.

**`TRUSTED_PROXIES` is a plain `configmap` key** (not a mask): it renders into the
ConfigMap only on chart versions that carry the allowlisted key (chart 4.1.0 onward). On earlier charts the key is accepted by `helm lint`/`template` and **silently
discarded** — set it and confirm it lands (section 6).

---

## 5. Operational notes

| Topic | What to know | Before enabling / how to confirm |
|---|---|---|
| **Authorization is OFF by default** | The console enforces permissions only when the rendered value is the literal word `true` (`PLUGIN_AUTH_ENABLED` server-side, `NEXT_PUBLIC_PLUGIN_AUTH_ENABLED` browser-side). `false`/empty/`1`/`TRUE`/`yes` all read as OFF. The published image refuses to start when both `PLUGIN_AUTH_ENABLED` and `OAUTH_ENABLED` are not `true` (`[startup] FATAL`, exit 1), so the chart default `false` crash-loops rather than serving an open console. | Set `global.auth.enabled: "true"` (or the native key) on every staging/prod release. Confirm with an unauthenticated request → must be 401/403. |
| **Server vs browser auth split** | The browser key copies the server value only while `NEXT_PUBLIC_PLUGIN_AUTH_ENABLED` is unset/empty. A non-empty browser key is used verbatim and never reconciled with the server — `"TRUE"` next to an enabled server gives server ON / browser OFF. | Leave the browser key unset, or set both to the exact word `true`. |
| **`NEXTAUTH_SECRET` is mandatory** | The published image refuses to start when it is empty (`[startup] FATAL`, exit 1). | Provide it via `secrets` / a secret manager before install. |
| **`TRUSTED_PROXIES` empty = no client IP** | Empty means no `X-Forwarded-For` hop is believed, so a tenant IP allowlist has nothing to judge, and outbound calls carry `X-Client-Ip-Resolution: unresolved; reason=trusted-proxies-not-configured`. | Set it to the ingress and load-balancer addresses in front of the console. Never use the pod or Service CIDR (see the chart README, "Client IP resolution"). **Do not widen** — a range covering real callers hides them. |
| **Bundled MongoDB and namespaces** | `MONGO_HOST` defaults to the bundled MongoDB's Service FQDN. The chart wires its password only while the subchart and the console share a namespace, which `-n product-console` with `global.namespaceOverride` unset gives you. | For a namespace split, follow the chart README, "MongoDB and readiness". |
| **ServiceAccount namespace** | On charts before the fix (LerianStudio/helm #2120), `templates/serviceaccount.yaml` pinned no namespace, so with `namespaceOverride` the SA landed in the release namespace while pods asked for it in the override namespace → pods never created (`Replicas: 0/1`). | Use a chart version that pins the SA namespace, or leave `namespaceOverride` empty. |
| **Managed cloud preset** | `global.cloud: aws` auto-sets the DocumentDB `MONGO_PARAMETERS` shape when nothing more specific overrides it. `gcp`/`azure` have no Mongo preset today. | On DocumentDB, don't hand-write `MONGO_PARAMETERS` — let the preset apply. |
| **⚠️ The AWS preset skips Mongo cert verification** | The `global.cloud: aws` preset includes `tlsInsecure=true` — TLS is on but the DocumentDB server certificate is **not verified** (open to MITM). It is a convenience default, **not production-safe by itself**. | For a security-strict production, drop `tlsInsecure=true` from `configmap.MONGO_PARAMETERS` and give the console the CA bundle as `MONGO_TLS_CA_CERT` (base64 of the PEM) in `secrets`. This chart has no value that mounts a file. |
| **`otel.external` installs no collector** | `otel.external: true` injects `HOST_IP`/`OTEL_URL_*` for a node-local DaemonSet collector; it does not install a collector. | Point at a real collector, or set `ENABLE_TELEMETRY: "false"` if none exists. |

---

## 6. How to validate a successful install

```bash
kubectl get pods -n <namespace>
kubectl get deploy,svc,cm -n <namespace> -l app.kubernetes.io/name=product-console
# health endpoints (served by the BFF on the service port, 8081):
kubectl -n <namespace> port-forward svc/product-console 8081:8081 &
# wait (bounded, ~30s) for the forward before curling — avoids a transient
# connection-refused without hanging forever if the pod never comes up:
for i in $(seq 1 30); do curl -fsS --max-time 2 http://localhost:8081/api/admin/health/alive >/dev/null 2>&1 && break; sleep 1; done
curl -fsS http://localhost:8081/api/admin/health/alive   # liveness
curl -fsS http://localhost:8081/api/admin/health/readyz  # readiness
```

| Check | Command/URL | Expected | If it doesn't match, check first |
|---|---|---|---|
| Pod | `kubectl get pods -n <ns>` | `Running`, `1/1` | `0/1` no pod → SA-namespace bug (section 5); `CreateContainerConfigError` → missing Secret; `CrashLoopBackOff` → log names the missing var |
| Liveness | `curl …/api/admin/health/alive` | `200` | Container up but not serving → check that `service.port` is 8081, the port the image listens on |
| Readiness | `curl …/api/admin/health/readyz` | `200` | Not Ready → most often the console can't reach MongoDB (section 5) |
| `TRUSTED_PROXIES` landed | `kubectl get cm product-console -n <ns> -o jsonpath='{.data.TRUSTED_PROXIES}'` | your CIDR | Empty/absent on a chart older than 4.1.0 → the key is silently discarded; bump the chart |
| Auth active | unauthenticated request to a protected route | `401`/`403` | `200` → `PLUGIN_AUTH_ENABLED` is not the literal `true` (section 5) |
| UI reachable | ingress host / port-forward | login or app loads | 502/504 → ingress `proxy-buffer-size` too small for the Next.js payload |

---

## 7. Known errors and what they mean

| Error/log | Cause | Fix |
|---|---|---|
| Release "installed", Deployment stuck `Replicas: 0/1`, no pod | `namespaceOverride` + a chart where the ServiceAccount pins no namespace → SA lands in the release namespace, pods demand it in the override namespace | Use a chart version that pins the SA namespace (#2120), or clear `namespaceOverride` |
| Pod restarts (`CrashLoopBackOff`), log `[startup] FATAL: [MongoDB] All connection attempts failed.` | The console cannot reach or authenticate to MongoDB at startup: it retries, then exits 1 | Check `MONGO_HOST` and `MONGODB_PASS` against the chart README, "MongoDB and readiness" |
| Pages open with no permission check / upstream calls carry no bearer | Authorization is OFF: the rendered `PLUGIN_AUTH_ENABLED` is not the literal `true` | Set `global.auth.enabled: "true"` (or native key); confirm with an unauthenticated request |
| Server enforces auth but the browser doesn't (or vice-versa) | `NEXT_PUBLIC_PLUGIN_AUTH_ENABLED` set to a non-`true` word, used verbatim and never reconciled with the server | Leave the browser key unset, or set both to `true` |
| `TRUSTED_PROXIES` set but the tenant IP allowlist never enforces | On a chart older than 4.1.0 the key is accepted and discarded; or the value is empty; or a too-wide range trusts the real caller away | Bump to a chart that renders the key (confirm in the ConfigMap), and keep the range narrow |
| `502`/`504` on the UI through ingress | Next.js response larger than the ingress proxy buffer | Raise `nginx.ingress.kubernetes.io/proxy-buffer-size` |
| Mongo TLS handshake failures on DocumentDB | `MONGO_PARAMETERS` missing the managed-TLS shape | Set `global.cloud: aws` (applies the DocumentDB preset) instead of hand-writing params |
