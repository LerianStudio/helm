# product-console — Installation Runbook

> Filled in from the chart itself (`README.md`, `values.yaml`, `templates/`) and the
> reference configuration in
> `lerian-internal-gitops/environments/benedita/helmfile/applications/dev-st/product-console`.
> Goal: someone outside the squad, with only the chart and this runbook, can install a
> working release and knows what to check if something doesn't behave as expected.

---

## 0. Metadata

| Field | Value |
|---|---|
| Product / Chart | `product-console` (chart `4.0.x` / app `1.12.0`) |
| Chart type | `single-service` — one Deployment (Next.js UI + BFF for Midaz) |
| Owning squad | Console / Frontend |
| Last review of this runbook | 2026-09-15, against chart `4.0.x` |
| Escalation contact | Console squad (see chart CODEOWNERS) |

The console is a single workload, not a multi-component app. Its "profile" is not
*which* components you enable (there is only one) but *what it points at*: the sibling
Lerian services, the MongoDB it stores console state in, whether authorization is on,
and which managed-cloud preset applies.

---

## 1. Installation profiles

| Profile | Shape | Use case |
|---|---|---|
| Standalone demo | Bundled MongoDB (`mongodb.enabled: true`, default), `ingress.enabled: false`, auth off | Local/kick-the-tyres only. **Not** for anything exposed. |
| Integrated dev/homolog | External MongoDB, ingress on, sibling base paths pointed at the real in-cluster services, auth on | The `benedita/dev-st` reference topology |
| Production | External managed MongoDB (DocumentDB via `global.cloud: aws`), ingress + TLS, auth on, `NEXTAUTH_SECRET` from a secret manager, `TRUSTED_PROXIES` set to the ingress CIDR | Client-facing |

- The bundled MongoDB subchart ships **enabled by default** — convenient for a demo,
  but see section 5 (it does not survive `namespaceOverride`, and it is not a managed
  database). Production must set `mongodb.enabled: false` and point at external Mongo.
- There is no "components" axis here; every knob below is a value on the single
  Deployment.

---

## 2. External dependencies

| Dependency | When it's needed | How the chart receives it |
|---|---|---|
| MongoDB | Always — the console stores its own state (organizations UI cache, settings) here | Bundled subchart (`mongodb.enabled: true`) **or** external via `MONGO_HOST`/`MONGODB_URI`/`MONGODB_USER` in `configmap` + `MONGODB_PASS` in `secrets`, or the `global.datastores.mongo` mask — section 4 |
| `lerian-common` (library chart) | Always | Chart dependency; provides HPA/PDB/Service/Ingress templates and the `global.*` masks. Nothing to configure. |
| Midaz ledger | Always (the console is a UI for it) | `MIDAZ_API_HOST` / `MIDAZ_BASE_PATH` / `MIDAZ_TRANSACTION_BASE_*` in `configmap` — defaults to `midaz-ledger.midaz.svc.cluster.local:3002` |
| plugin-access-manager (auth + identity) | Required when authorization is on (recommended everywhere exposed) | `PLUGIN_AUTH_*` / `PLUGIN_IDENTITY_*` in `configmap`, client id/secret in `secrets` — section 5 |
| Sibling plugins (CRM, Reporter, Fees, Tracer, Fetcher, Matcher, Flowker, Bank Transfer, Payments) | Only the features you enable in the UI | One `*_BASE_PATH` per service in `configmap`; each defaults to the sibling's in-cluster FQDN. A feature whose base path is wrong just fails that feature, not startup. |
| OTEL collector | Optional (telemetry) | `otel.external: true` injects `OTEL_URL_*`/`HOST_IP` for a node-local DaemonSet collector; or `ENABLE_TELEMETRY`/`global.observability` |
| Vault / secret manager | Recommended in production | `useExistingSecret: true` + `existingSecretName`, or Vault refs in the values `secrets:` block (the reference env uses `<path:...>` AVP refs) |

The console reaches its siblings by **in-cluster FQDN** (`<svc>.<ns>.svc.cluster.local`)
out of the box, so it works across namespaces with no mesh/DNS wiring — override a
`*_BASE_PATH` only when your service/namespace names differ.

---

## 3. Installation order

1. Decide the MongoDB story: bundled (`mongodb.enabled: true`, demo only) **or**
   external (`mongodb.enabled: false` + real `MONGO_HOST`/`MONGODB_URI` + `MONGODB_PASS`).
   For managed Mongo (DocumentDB) also set `global.cloud: aws` so the TLS connection
   string shape is applied automatically (section 5).
2. Provide the required production secrets **before** `helm install`:
   `secrets.NEXTAUTH_SECRET` (NextAuth signing key — the app is not safe without it),
   `secrets.MONGODB_PASS`, and — when auth is on — `PLUGIN_AUTH_CLIENT_ID`/`_SECRET`.
3. Turn authorization **on explicitly** for any exposed environment:
   `global.auth.enabled: "true"` (or `configmap.PLUGIN_AUTH_ENABLED: "true"`). The
   console does **not** fail closed on a missing switch — see section 5.
4. Point the inter-service base paths at your real services if the namespaces differ
   from the defaults (Midaz, access-manager, CRM, Reporter, …).
5. Set `TRUSTED_PROXIES` to the CIDR of the hops in front of the console (normally the
   ingress controller's pod/service CIDR) — empty means no client IP is ever resolved
   and the tenant IP allowlist is never enforced (section 5).
6. Configure `ingress` (class, host, TLS) and set `NEXTAUTH_URL` to the public URL the
   browser uses for OAuth callbacks (defaults to the first ingress host as `https://…`).
7. `helm install … -n <ns> --create-namespace`. Leave `namespaceOverride` empty unless
   you know you need it — with the bundled MongoDB it splits resources across namespaces
   (section 5).

---

## 4. Shared configuration contract (masks / lerian-common)

The console consumes `lerian-common` masks: set a value **once per environment** under
`global.*` and every consuming key picks it up. A native `configmap.<KEY>` always wins
over the mask.

```yaml
global:
  # Access Manager gate/host — TURN THIS ON for any exposed env (default is OFF)
  auth:
    enabled: "true"
    host: "plugin-access-manager-auth.<ns>.svc.cluster.local"
  # Telemetry
  observability:
    enabled: "true"
  # Env-wide MongoDB connection (external Mongo). MONGODB_DB_NAME stays per-app.
  datastores:
    mongo:
      host: ""
      port: "27017"
      user: ""
      params: ""     # leave empty on AWS — global.cloud: aws sets the DocumentDB shape
  # Managed-cloud preset (AWS DocumentDB TLS connection string), applied when no
  # more specific override is set. gcp/azure have no Mongo preset today.
  cloud: "aws"
```

| Global field | Effect (env var) | Overriding native key |
|---|---|---|
| `global.auth.enabled` / `.host` | `PLUGIN_AUTH_ENABLED` / `PLUGIN_AUTH_HOST` | `configmap.PLUGIN_AUTH_ENABLED` / `PLUGIN_AUTH_HOST` |
| `global.observability.enabled` | `ENABLE_TELEMETRY` | `configmap.ENABLE_TELEMETRY` |
| `global.datastores.mongo.{uri,host,port,user,params}` | `MONGODB_URI`/`MONGO_HOST`/`MONGO_PORT`/`MONGODB_USER`/`MONGO_PARAMETERS` | the matching `configmap.<KEY>` |
| `global.cloud: aws` | Sets `MONGO_PARAMETERS` to the DocumentDB shape (`tls=true&tlsInsecure=true&directConnection=true&retryWrites=false&…`) | `configmap.MONGO_PARAMETERS` or `global.datastores.mongo.params` |

**Every `configmap.<KEY>` default lives in `templates/configmap.yaml`** (as
`KEY | default "…"`), never in `values.yaml` — the `configmap:` map ships empty. Set a
key there only to override a shipped default.

**`TRUSTED_PROXIES` is a plain `configmap` key** (not a mask): it renders into the
ConfigMap only on chart versions that carry the allowlisted key (LerianStudio/helm
#2120). On earlier charts the key is accepted by `helm lint`/`template` and **silently
discarded** — set it and confirm it lands (section 6).

---

## 5. Operational notes

| Topic | What to know | Before enabling / how to confirm |
|---|---|---|
| **Authorization is OFF by default** | The console enforces permissions only when the rendered value is the literal word `true` (`PLUGIN_AUTH_ENABLED` server-side, `NEXT_PUBLIC_PLUGIN_AUTH_ENABLED` browser-side). `false`/empty/`1`/`TRUE`/`yes` all read as OFF; the console does **not** fail closed. | Set `global.auth.enabled: "true"` (or the native key) on every staging/prod release. Confirm with an unauthenticated request → must be 401/403. |
| **Server vs browser auth split** | The browser key copies the server value only while `NEXT_PUBLIC_PLUGIN_AUTH_ENABLED` is unset/empty. A non-empty browser key is used verbatim and never reconciled with the server — `"TRUE"` next to an enabled server gives server ON / browser OFF. | Leave the browser key unset, or set both to the exact word `true`. |
| **`NEXTAUTH_SECRET` is mandatory for production** | Empty NextAuth secret ⇒ sessions are not safely signed. | Provide it via `secrets` / a secret manager before install. |
| **`TRUSTED_PROXIES` empty = no client IP** | Empty means no `X-Forwarded-For` hop is believed, so the tenant IP allowlist is never enforced and outbound calls carry `X-Client-Ip-Resolution: unresolved; reason=trusted-proxies-not-configured`. | Set it to the ingress pod/service CIDR (e.g. `10.42.0.0/16`). **Do not widen** — a range covering real callers hides them. |
| **Bundled MongoDB does not survive `namespaceOverride`** | The subchart Service is `<release>-mongodb` in the **release** namespace; it does not inherit `namespaceOverride`. With `namespaceOverride` set and `MONGO_HOST: "mongodb"`, the console points at a host that exists nowhere and never becomes Ready. | For anything beyond a same-namespace demo, use **external** Mongo. If you keep the bundled one, leave `namespaceOverride` empty and set `MONGO_HOST` to the real `<release>-mongodb`. |
| **ServiceAccount namespace** | On charts before the fix (LerianStudio/helm #2120), `templates/serviceaccount.yaml` pinned no namespace, so with `namespaceOverride` the SA landed in the release namespace while pods asked for it in the override namespace → pods never created (`Replicas: 0/1`). | Use a chart version that pins the SA namespace, or leave `namespaceOverride` empty. |
| **Managed cloud preset** | `global.cloud: aws` auto-sets the DocumentDB `MONGO_PARAMETERS` shape when nothing more specific overrides it. `gcp`/`azure` have no Mongo preset today. | On DocumentDB, don't hand-write `MONGO_PARAMETERS` — let the preset apply. |
| **OTEL is external by default in the reference env** | `otel.external: true` injects `HOST_IP`/`OTEL_URL_*` for a node-local DaemonSet collector; it does not install a collector. | Point at a real collector, or set `ENABLE_TELEMETRY: "false"` if none exists. |

---

## 6. How to validate a successful install

```bash
kubectl get pods -n <namespace>
kubectl get deploy,svc,cm -n <namespace> -l app.kubernetes.io/name=product-console
# health endpoints (served by the BFF on the service port, 8081):
kubectl -n <namespace> port-forward svc/product-console 8081:8081 &
curl -fsS http://localhost:8081/api/admin/health/alive   # liveness
curl -fsS http://localhost:8081/api/admin/health/readyz  # readiness
```

| Check | Command/URL | Expected | If it doesn't match, check first |
|---|---|---|---|
| Pod | `kubectl get pods -n <ns>` | `Running`, `1/1` | `0/1` no pod → SA-namespace bug (section 5); `CreateContainerConfigError` → missing Secret; `CrashLoopBackOff` → log names the missing var |
| Liveness | `curl …/api/admin/health/alive` | `200` | Container up but not serving → check `MIDAZ_CONSOLE_PORT`/`service.port` match (8081) |
| Readiness | `curl …/api/admin/health/readyz` | `200` | Not Ready → most often the console can't reach MongoDB (section 5) |
| `TRUSTED_PROXIES` landed | `kubectl get cm product-console -n <ns> -o jsonpath='{.data.TRUSTED_PROXIES}'` | your CIDR | Empty/absent on a chart older than #2120 → the key is silently discarded; bump the chart |
| Auth active | unauthenticated request to a protected route | `401`/`403` | `200` → `PLUGIN_AUTH_ENABLED` is not the literal `true` (section 5) |
| UI reachable | ingress host / port-forward | login or app loads | 502/504 → ingress `proxy-buffer-size` too small for the Next.js payload (the reference env raises it) |

---

## 7. Known errors and what they mean

| Error/log | Cause | Fix |
|---|---|---|
| Release "installed", Deployment stuck `Replicas: 0/1`, no pod | `namespaceOverride` + a chart where the ServiceAccount pins no namespace → SA lands in the release namespace, pods demand it in the override namespace | Use a chart version that pins the SA namespace (#2120), or clear `namespaceOverride` |
| Pod runs but never Ready | Console can't reach MongoDB — most often bundled Mongo + `namespaceOverride`, or `MONGO_HOST` pointing at a name that resolves nowhere | Use external Mongo, or align `MONGO_HOST` with the real `<release>-mongodb` in the release namespace |
| Pages open with no permission check / upstream calls carry no bearer | Authorization is OFF: the rendered `PLUGIN_AUTH_ENABLED` is not the literal `true` | Set `global.auth.enabled: "true"` (or native key); confirm with an unauthenticated request |
| Server enforces auth but the browser doesn't (or vice-versa) | `NEXT_PUBLIC_PLUGIN_AUTH_ENABLED` set to a non-`true` word, used verbatim and never reconciled with the server | Leave the browser key unset, or set both to `true` |
| `TRUSTED_PROXIES` set but the tenant IP allowlist never enforces | On a chart older than #2120 the key is accepted and discarded; or the value is empty; or a too-wide range trusts the real caller away | Bump to a chart that renders the key (confirm in the ConfigMap), and keep the range narrow |
| `502`/`504` on the UI through ingress | Next.js response larger than the ingress proxy buffer | Raise `nginx.ingress.kubernetes.io/proxy-buffer-size` (reference env uses `512k`) |
| Mongo TLS handshake failures on DocumentDB | `MONGO_PARAMETERS` missing the managed-TLS shape | Set `global.cloud: aws` (applies the DocumentDB preset) instead of hand-writing params |
