---
name: productize-chart-env
description: >-
  Productize a Lerian Helm chart's configuration from the app's config/.env.example
  onto lerian-common — every env var becomes a grouped cfgValue param, a domain helper
  (multiTenant/otel/datastore/serviceDiscovery/streaming/auth), or a fail-fast secret;
  NO raw env vars remain in values.yaml. Use when productizing a chart, or when the app
  added/renamed env vars and the chart must re-sync to the .env contract.
---

# Productize a chart's config from the app `.env` (the #1741 pattern)

## Premise (non-negotiable)

The app's **`config/.env.example` is the authority** — NOT the chart's prior render.
Every ACTIVE env var the app reads must be covered by the chart as exactly one of:

- **config** → grouped `lerian-common.cfgValue` param (`configmap.<KEY>` › `<comp>.<group>.<field>` › default)
- **datastore** → `lerian-common.datastore.value` mask (host/port/user/ssl/replicaHost)
- **helper** → a domain env helper + `global.*` block (see the domain map)
- **secret** → `secrets.yaml` + a fail-fast (`multiTenant.secret`, or a `required` guard)
- **gap** → recorded backlog (app declares it, chart can't cover it yet)
- **omitted** → with a written reason

The chart's `configmap` / `configmap.data` ends up **`{}`** (an override escape-hatch);
all defaults live in the template. Result: the operator configures a clean typed API
(`<comp>.redis.poolSize`), never a raw env var, and `configmap.<KEY>` still wins as an override.

## Inputs

- The chart dir (e.g. `charts/br-ccs`).
- The app's `config/.env.example`. Fetch it (repos are private but reachable):
  `gh api repos/LerianStudio/<app>/contents/config/.env.example --jq '.content' | base64 -d`
- The component root: single-service uses `.Values.<comp>` (br-ccs `brCcs`), or a flat chart
  uses `.Values` directly (br-slc: config under `.Values.configmap.data`). Multi-component
  (br-sta manager+worker): productize the **manager** only — the worker inherits via envFrom.

## Step 0 — Introspect lerian-common FIRST (do not assume the domain map)

Before classifying anything, enumerate what the vendored lerian-common actually offers, so
the skill wires whatever exists TODAY (and picks up new domain helpers as the lib evolves):

```bash
# every helper the chart's lerian-common exposes
grep -rhoE 'define "lerian-common\.[a-zA-Z.]+"' charts/lerian-common/templates/ | sort -u
# read a helper's contract (inputs + Usage) before wiring it
sed -n '/define "lerian-common.serviceDiscovery.env"/,/^{{- end/p' \
    charts/lerian-common/templates/_service_discovery.tpl
# authoritative reference (versioned): the lib's doc.go / chart docs
```

Match each `.env` domain prefix to a helper that EXISTS. If a cross-cutting prefix has no
helper (e.g. a brand-new subsystem), record it as a `gap` — do NOT hand-roll the domain env;
raise it so lerian-common gains the helper first. Confirm the lib version in the chart's
`Chart.yaml` dependency and check its `docs/UPGRADE-*.md` for contract changes.

## Domain map (cross-cutting → lerian-common helper + global block)

Current at time of writing — **verify against Step 0**, the introspection is the source of truth.
These ALWAYS go to a helper (never cfgValue) — that is where `global.*` env-wide config lives.
The helpers already exist; you are only WIRING them.

| .env prefix | helper | global block | notes |
|---|---|---|---|
| `MULTI_TENANT_*` | `multiTenant.env` + `multiTenant.secret` | `global.multiTenant` | toggle via `<comp>.multiTenant.enabled`; URL/REDIS_HOST required when on; API_KEY fail-fast |
| `ENABLE_TELEMETRY`, `OTEL_*` | `otel.env` (+ `otel.envFlat` for identity) | `global.observability` | shared 3 keys derive; name/library/version per-component |
| `POSTGRES_*`/`REDIS_*`/`RABBITMQ_*` host+conn | `datastore.value` (type postgres/redis/broker) | `global.datastores` (+ `<comp>.datastores`) | host/port/user/ssl/replicaHost only; TUNING (pool/timeouts) stays cfgValue |
| `SD_*` | `serviceDiscovery.env` or `.envFlat` | `global.serviceDiscovery` | envFlat (flat passthrough) is the simplest for a consumer chart |
| `STREAMING_*` | `streaming.env` + `streaming.secret` | `global.streaming` | full SASL/broker contract; `STREAMING_SASL_PASSWORD` is a secret |
| `PLUGIN_AUTH_*` | `globalValue` (block `auth`) | `global.auth` | ENABLED always; HOST emitted only when non-empty |

Everything NOT in this map is **config** (long-tail: rate-limit, outbox, swagger, cors, pagination,
object-storage, service-specific knobs) → route each via `cfgValue` into a grouped block.

## Classification (config vs secret)

Per Lerian `values.md`: a var is a **secret** if it carries credential material
(`*PASSWORD`, `*_SECRET`, `*API_KEY` value, `*CLIENT_SECRET`, `*CRYPTO*`, `LICENSE_KEY`,
`*ACCESS_KEY`/`*SECRET_KEY`, `ORGANIZATION_IDS`, `*_TOKEN` value). Secrets go to `secrets.yaml`,
emitted only when provided, with a fail-fast when the owning feature is enabled.
BEWARE false positives: a credential-*named* var that is actually a PATH or an empty-default
config (`WEBHOOK_API_KEY_FILE`, `AWS_ACCESS_KEY_ID=""`) stays **config** — see Rule 1 below.

## Procedure

1. **Fetch + split** the `.env.example` into ACTIVE (`^KEY=`) and COMMENTED (`^# KEY=`) vars.
   Both are part of the contract (commented = optional).
2. **Source of truth for defaults = the PRIOR MANAGER render**, not values.yaml. Render the
   pre-change chart (`helm template ... -s templates/configmap.yaml`) and read `KEY: value`.
   (Reading values.yaml directly mixes in the worker's `configmap` — Rule 4.)
3. **Classify** every var via the domain map + secret rules above.
4. **Emit the domain helpers** (MT/OTEL/datastore/SD/streaming/auth) exactly as their Usage docs
   show, gated + `global.*`, adding the matching `global.<block>` + `<comp>.<group>` values.
5. **Emit config via cfgValue**, one line per key:
   `{{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "KEY" "params" $group "field" "camelField" "default" "<.env value>") | quote }}`
   Declare `{{- $group := .Values.<comp>.<group> | default dict -}}` vars at the top. Group by
   prefix (`CORS_`→cors, `REDIS_`→redis, `OUTBOX_`→outbox, `RATE_LIMIT`→rateLimit, `SWAGGER_`→swagger,
   `OBJECT_STORAGE_`→objectStorage, …); field = camelCase of the key minus the group prefix.
6. **Empty the raw config** in values.yaml (`configmap: {}` / `data: {}`) and add the grouped
   blocks (`<group>: {}` with a field-list comment). Carry any value that DIFFERED from the
   template default into the group default (Rule 3).
7. **Secrets** → `secrets.yaml`: passthrough emit-when-set for the long tail, `required` /
   `multiTenant.secret` fail-fast when the owning feature is enabled.

## RULES (the gotchas — every one cost real debugging; bake them in)

1. **Credential-like NAMED config keys** trip the `secret-in-configmap` gate, which only
   recognises `| default "X"` (not cfgValue's `"default" "X"`). For such a key, append a literal
   `| default "<val>"` after the cfgValue (`… ) | default "" | quote }}`) so the gate sees a
   non-credential default and skips it — or keep it a plain `$cm.KEY | default "" | quote`
   passthrough for `*_FILE` paths.
2. **Comments between rendered lines** must be YAML `#`, never `{{- /* */ -}}` — the `{{-`/`-}}`
   trim markers eat the surrounding newlines and glue two keys onto one line.
3. **Non-default shipped values**: any key whose values.yaml value differed from the template's
   default (e.g. br-ccs `OBJECT_STORAGE_*_BUCKET`) MUST be carried into the grouped param default,
   or emptying `configmap` breaks byte-identity.
4. **Source of truth = MANAGER render**, not `awk` over values.yaml — a naive `^  configmap:`
   match also captures `worker.configmap`, injecting worker-only keys into the manager.
5. **`rateLimit.env` / `auth.env` emit a FIXED key set** that may not match the chart
   (rateLimit.env adds `ALLOW_RATELIMIT_DISABLED` + `RATE_LIMIT_REDIS_TIMEOUT_MS`; auth.env always
   emits HOST). If the chart's surface differs, use per-key `cfgValue`/`globalValue` instead.
6. **If you generate lines with a Python f-string, `}}` becomes `}`** — use a normal string or a
   post-regex to restore `| quote }}`.
7. **Optional/opt-in keys** (`{{- if $cm.X }}`, `if REPORTER_ENABLED`, `range` over lists) stay
   conditional — do not force them into unconditional cfgValue.

## Self-check (the skill refuses to finish unless all pass)

Run `scripts/coverage.py` (renders the chart, diffs vs the `.env` + the manifest it writes):

- **Coverage**: every ACTIVE `.env` var is config/datastore/helper/secret/gap/omitted — none unhandled.
- **No raw drift**: every emitted ConfigMap key is accounted for (in a group/helper) — none raw.
- **Byte-identical** (regression guard, NOT completeness): default render == prior productized
  render, except intentionally-gated keys (MT/streaming infra now only render when enabled).
- `helm lint` + the repo render-gate + strict standard all green.

Emit a **coverage report** at the end: N config / N secret / N helper / N datastore / gaps list.
For any judgment call the heuristics were unsure about, print `REVIEW: <key> classified as <kind>`
so the human confirms in the PR — the skill proposes, the reviewer decides.

## Output

Modified `templates/configmap.yaml`, `templates/secrets.yaml`, `values.yaml`, a render fixture
(`.github/configs/helm-render-values/<chart>.yaml` enabling the productized paths), and the
coverage report. One chart per PR.
