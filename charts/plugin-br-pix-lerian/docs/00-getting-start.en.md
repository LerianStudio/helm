# plugin-br-pix-lerian — Installation Runbook

> Filled in from the chart itself (`README.md`, `values.schema.json`, templates) and
> the reference configuration in
> `lerian-internal-gitops/environments/benedita/helmfile/applications/dev-st/plugin-br-pix-lerian`.
> Goal: someone outside the squad, with only the chart and this runbook, can install a
> working release and knows what to check if something doesn't behave as expected.

---

## 0. Metadata

| Field | Value |
|---|---|
| Product / Chart | `plugin-br-pix-lerian` (chart 1.0.0 / app `1.0.0-beta.337`) |
| Owning squad | Pix Lerian |
| Last review of this runbook | 2026-09-14, against chart 1.0.0 |
| Escalation contact | Pix Lerian squad (see chart CODEOWNERS) |

---

## 1. Installation profiles

The chart does not expose a single "profile" flag — the profile is defined by which
of the 14 workloads you enable. `helm template`/`helm install` with no customized
values only validates chart structure; a working installation requires enabling the
workloads for your use case, pointing at Postgres, and setting `LICENSE_KEY` +
`ORGANIZATION_IDS` per your `DEPLOYMENT_MODE` (see section 3).

| Profile | Enabled components | Use case |
|---|---|---|
| SPI only | `spi` + `spiSystemplane` | Payment initiation/settlement only |
| SPI + DICT + COB | `spi`+`spiSystemplane`, `dictHub`+`dictSystemplane` (+`dictHubVsync` if reconciliation is needed), `cobHub`+`cobSystemplane` | Recommended production topology, described in the [chart README](../README.md#production-quickstart) |
| + Pix Automático | production profile + `pixauto`+`pixautoSystemplane` | Product offers Pix Automático (payer side) |
| Homologation with provider mock | production profile + `adapterProviderMock` | End-to-end testing without a real provider — **restricted to controlled dev/homologation environments**, see section 5 |

- Every profile always pairs a domain's app with its matching Systemplane workload.
- `dictProxy`/`cobProxy` and `adapterLerian`/`adapterLerianSystemplane` exist for
  specific topologies (a provider already owns the domain's state, or a local
  development integration via the Lerian adapter) — enable them only when your
  provider topology calls for that tier; see
  [Hub and proxy are not interchangeable](../README.md#hub-and-proxy-are-not-interchangeable)
  in the chart README.

---

## 2. External dependencies

| Dependency | When it's needed | How the chart receives it |
|---|---|---|
| PostgreSQL | Per enabled domain — up to 5 possible databases: `pix-spi`, `pix-dict`, `pix-cob`, `pix-adapter-lerian`, `pix-pixauto` | `DATABASE_URL` / `SYSTEMPLANE_POSTGRES_DSN` in `secrets`, or an external Secret via `useExistingSecret` |
| Valkey/Redis | Required on `dictHubVsync` and on `adapterLerian` when enabled; optional (with cache degradation) on `spi`/`dictHub`/`cobHub`/`pixauto` | Mask `global.datastores.redis` (host/port/user/db/tls) — section 4 |
| RabbitMQ | Required when `dictHubVsync` is enabled; optional publish-only on `dictHub` | `RABBITMQ_URI` in `secrets` |
| Streaming (Kafka/Redpanda) | Optional — `spi`, `dictHub`, `cobHub`, `pixauto` can emit CloudEvents | Mask `global.streaming` — section 4. Leave `STREAMING_CLOUDEVENTS_SOURCE` empty (except on `pixauto`, which uses its own value — see section 4) |
| MongoDB | Not used by this chart | — |
| `plugin-access-manager` (auth) | Recommended in any exposed environment — see section 5 | Mask `global.auth` (`PLUGIN_AUTH_ENABLED` + `PLUGIN_AUTH_HOST`) |
| Vault / secret manager | Recommended in production | `useExistingSecret: true` + `existingSecretName` per component — the external Secret must carry the complete key set for that workload |
| Streaming Hub (callbacks) | External to this chart | This chart publishes events to the broker via `lib-streaming`; the Streaming Hub resolves subscriptions and performs the HTTP callback — no callback URL is configured here |

For development/homologation without a real provider, use `adapterProviderMock`
(section 5). Databases must exist with the correct connection role before
installation — the chart applies migrations, it does not create the database itself
(see [Database bootstrap and migrations](../README.md#database-bootstrap-and-migrations)).

---

## 3. Installation order

1. Provision the Postgres databases for the domains you will enable.
2. Create the external Secrets per workload (`useExistingSecret`) with the complete
   key set for that workload, before `helm install` — migration hooks read these
   Secrets at the start of the installation.
3. Set `LICENSE_KEY` and `ORGANIZATION_IDS` on the workloads that actually construct a
   license client: `spi`, `dictHub`, `dictHubVsync`, `cobHub`, `pixauto`. Other workloads
   (the `*Systemplane` components, `dictProxy`/`cobProxy`, `adapterLerian`) may carry a
   `LICENSE_KEY` slot, but it is inert — they never build the client, so the key is not
   required there. The chart's example `values.yaml` only sets `ORGANIZATION_IDS` on
   `adapterLerian` and `pixauto` — add it to the five workloads above if starting from
   the defaults.
4. `helm install` (installation is always fresh — there is no in-place upgrade path
   from an earlier chart).
5. If a domain's hub stays disabled, apply that domain's schema through another
   means — the migration Job is only rendered for an enabled hub.
6. Configure single-tenant identity (`ORGANIZATION_ID`, `ISPB`) on both the domain's
   app and its matching Systemplane workload — the Systemplane seeds the store and
   the app reads it back.
7. In a multi-tenant topology, provision each tenant's configuration separately —
   seeding from the environment does not run in that mode (see
   [Multi-tenant configuration](../README.md#multi-tenant-configuration)).

---

## 4. Shared configuration contract (masks / lerian-common)

This chart follows the `lerian-common` contract. The fields below are already
consolidated as masks in the `benedita/dev-st` reference environment and are the
recommended default for any new environment:

```yaml
global:
  datastores:
    redis:
      host: ""
      port: "6379"
      user: "default"
      db: "0"
      tls: "false"
  auth:
    enabled: "true"     # PLUGIN_AUTH_ENABLED on every component
    host: ""             # PLUGIN_AUTH_HOST
  streaming:
    brokers: ""
    tlsEnabled: "true"
    saslMechanism: "SCRAM-SHA-256"
    saslAllowPlaintext: "false"
```

| Global field | Effect | Affected components |
|---|---|---|
| `global.datastores.redis.*` | `REDIS_HOST`/`PORT`/`USER`/`DB`/`TLS` | `spi`, `dictHub`, `dictHubVsync`, `cobHub`, `pixauto` |
| `global.auth.enabled` / `.host` | `PLUGIN_AUTH_ENABLED` / `PLUGIN_AUTH_HOST` | All 14 components that read the toggle |
| `global.streaming.*` | `STREAMING_BROKERS`/`TLS_ENABLED`/`SASL_MECHANISM`/`SASL_ALLOW_PLAINTEXT` | `spi`, `dictHub`, `cobHub`, `pixauto` |

Each field above can be overridden per component via `<component>.configmap.<KEY>`
when that specific component needs a value different from the global one.

**Known exception:** keep `STREAMING_TENANT_ID` and `STREAMING_CLOUDEVENTS_SOURCE`
native (outside the mask) on `pixauto` — this component uses its own
`cloudeventsSource` value, different from the other three streaming components.

**Template parameters that are not mask-eligible** (setting these via `configmap`
has no effect, since no template in this version consumes them): `REDIS_PROTOCOL`,
`OTEL_EXPORTER_OTLP_ENDPOINT_PORT` (the actual OTLP endpoint is resolved via
`HOST_IP` by the chart itself), `global.image.tag` (there is no shared image; each
component pins its own tag under `<component>.image.tag`).

**Watch this cross-field dependency:** when enabling `dictProxy`/`cobProxy`, keep the
caller's "routing mode" for that domain (`spi` carries a mode for DICT and one for
COB; `cobHub` carries one for DICT) on the same tier as the matching `*_BASE_URL` —
the two are not cross-validated at boot.

---

## 5. Operational notes

| Topic | What to know | Before enabling / how to confirm |
|---|---|---|
| `PLUGIN_AUTH_ENABLED` vs `IDP_DECLARATION_ENABLED` (`pixauto`) | Two independent controls: `PLUGIN_AUTH_ENABLED` authenticates incoming requests; `IDP_DECLARATION_ENABLED` controls whether `pixauto` publishes its permission declaration to `plugin-access-manager` | Register `pixauto`'s M2M application in `plugin-access-manager` before enabling `IDP_DECLARATION_ENABLED`. Confirm in `plugin-access-manager` that the declaration was accepted for the `pixauto` slug |
| `PLUGIN_AUTH_ENABLED` | Gates authentication on business and M2M routes; defaults to `false` | Enable explicitly (via the `global.auth.enabled` mask) in any exposed environment — recommended on all 14 components |
| Proxy tier (`dictProxy`/`cobProxy`) | In this release, serves only `health`, `readyz`, and an OpenAPI document with no business operations | Do not route business traffic to the proxy; use the domain's hub for real traffic. Validate with an actual business transaction, not just the probe |
| Disabling a hub (`dictHub`/`cobHub`/`spi`) | The migration Job for that domain is only rendered for an enabled hub | If a hub stays disabled, apply that domain's schema through another means before starting the remaining workloads |
| `STREAMING_CLOUDEVENTS_SOURCE` | Must match the application's internal source, whether or not streaming is enabled | Leave empty, except on `pixauto` |
| `adapterLerian` | Expects `DEPLOYMENT_MODE=local`; it is the adapter used in development | Keep disabled (default) outside a local environment |
| `adapterProviderMock` | Its routes carry no authorization of their own, independent of `PLUGIN_AUTH_ENABLED` | Enable only in a controlled environment, never on a shared ingress reachable by untrusted callers |
| `ORGANIZATION_ID` on `pixauto` (single-tenant) | The app reads from the Systemplane store first, falling back to this value if the store is empty | Set `ORGANIZATION_ID` (or seed the store) before sending traffic — without it, requests return `403 TENANT_CONFIG_NOT_FOUND` |
| Systemplane "boot-captured" keys (identity, URLs, auth toggle, Postgres pool) | Changes made through the Systemplane admin API only take effect after a pod restart | Restart the affected workload after changing any of these keys via the API |

---

## 6. How to validate a successful install

```bash
kubectl get pods -n <namespace>
kubectl get jobs -n <namespace>   # confirm each enabled domain's migration Job completed
# health/readiness are served under each component's own path prefix, e.g. spi:
curl <spi-url>/spi/health
curl <spi-url>/spi/readyz
# dict-hub -> /dict-hub/{health,readyz}, cob-hub -> /cob-hub/{health,readyz}, etc.
```

| Check | Command/URL | Expected | If it doesn't match, check first |
|---|---|---|---|
| Pods of enabled workloads | `kubectl get pods -n <ns>` | `Running` | `CreateContainerConfigError` → missing Secret; `CrashLoopBackOff` → log names the missing variable |
| Migration Jobs | `kubectl get jobs -n <ns>` | `Complete` for each enabled domain | Missing Job → that domain's hub is disabled (section 5) |
| Readiness | `curl <hub>/readyz` | 200, no pending `required_keys` in the response body | The body lists the keys the Systemplane store is still missing |
| Auth active | business request without a token against a hub | 401/403 | If it returns 200, confirm `PLUGIN_AUTH_ENABLED` is `true` on that component |
| Correct routing | business request against `dictProxy`/`cobProxy` | 404 (expected in this release) | If you expected 200, confirm whether traffic should go to the hub instead |
| End-to-end transaction | real flow through `spi` (or `adapterProviderMock` in homologation) | Full success |

---

## 7. Known errors and what they mean

| Error/log | Cause | Fix |
|---|---|---|
| `403 TENANT_CONFIG_NOT_FOUND` on every request | Tenant/organization configuration missing from the Systemplane store | Single-tenant: set `ORGANIZATION_ID`/`ISPB`. Multi-tenant: provision the tenant explicitly |
| Pod `Ready`, but business requests fail with no visible error | Traffic routed to `dictProxy`/`cobProxy`, or the hub's schema was never migrated | Confirm routing mode and that domain's migration Job status |
| `CrashLoopBackOff` naming `LICENSE_KEY`/`ORGANIZATION_IDS` | One of the two is empty on a license-constructing workload | Set both on the 5 workloads listed in section 3 (`spi`, `dictHub`, `dictHubVsync`, `cobHub`, `pixauto`) |
| Render fails naming `RABBITMQ_URI` | `dictHubVsync` enabled without `RABBITMQ_URI` in `secrets` | Set `RABBITMQ_URI` before enabling `dictHubVsync` |
| `CrashLoopBackOff` on `adapterLerian` outside a local environment | `DEPLOYMENT_MODE` other than `local` with the component enabled | Keep disabled outside dev, or use `DEPLOYMENT_MODE=local` only for that component |
| Change via the Systemplane admin API "didn't take" | The key is boot-captured | Restart the affected workload's pod |
