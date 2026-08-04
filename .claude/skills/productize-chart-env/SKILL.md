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

The chart's `configmap` / `configmap.data` ends up **`{}`** — `{}` means "no DEFAULTS shipped
here", NOT "overrides forbidden". Defaults live in the template. Result: the operator configures
a clean typed API (`<comp>.redis.poolSize`), never a raw env var.

**Two escape hatches stay open (every mature chart keeps one — do NOT remove them):**
- `configmap.<KEY>` — overrides an ENUMERATED key (top of `cfgValue` precedence:
  `configmap.<KEY>` › `<comp>.<group>.<field>` › default).
- `<comp>.extraEnvVars` (a `range`-emitted map at the end of the ConfigMap) — injects ANY
  UN-enumerated var, so a var the app adds before the chart re-syncs is still settable.
This is why enumeration is safe: the typed groups are the *documented* surface, the hatches are
the *safety valve*. Enumerating a finite, app-owned `.env` (unlike Grafana/NGINX wrapping a
foreign open-ended config) is the deliberate divergence — see "Market alignment" at the end.

## Values structure (STANDARD)

Top-level tiers:

1. **`global:`** — config shared across MORE THAN ONE component (env-wide). Helm-special (propagates
   to subcharts). Holds: `observability`, `multiTenant` (infra), `datastores` (SHARED mask),
   `serviceDiscovery`, `streaming`, plus k8s-infra `imageRegistry` / `imagePullSecrets` / `commonLabels`.
2. **One `<componentName>:` block PER INDEPENDENT DEPLOYMENT.** `componentName` = the deployment's
   name in **camelCase, NO hyphen** (`brCcs`, `brSta`, `worker`) — access via `.Values.brSta`,
   NEVER `index .Values "br-sta"`. Holds that deployment's cfgValue config groups (`redis`,
   `rateLimit`, …), `datastores` (DEDICATED mask), `externalXDefinitions` (our bootstrap-for-external
   deps), `image`/`service`/`resources`/`replicaCount`/`ingress` (k8s), `configmap: {}` (escape hatch),
   `extraEnvVars`, `secrets`. Example: br-ccs → `brCcs:`; br-sta → `brSta:` + `worker:`.
3. **Subchart dependencies** (`postgresql`/`valkey`/`rabbitmq`/…): Helm REQUIRES subchart values at
   the ROOT under the subchart name — they CANNOT be nested (Helm passes `.Values.postgresql` to the
   `postgresql` subchart by name). Group them visually with a `# --- dependencies ---` comment. Our
   ABSTRACTION over them (the `datastores` mask + `externalXDefinitions` bootstrap) lives inside the
   `<componentName>`, not at root.

**EXCEPTION — single-deployment chart with in-pod sidecars stays FLAT.** A chart that is ONE
Deployment whose extra containers are SIDECARS in the same pod (br-slc: app + signer + xsd-validator
+ mqbridge + a migrations Job) does NOT wrap under a component key. Its sidecars/jobs share pod-level
config (`securityContext`, `serviceAccount`, `nodeSelector`, `resources`, the app `image`) — nesting
the app under `<componentName>` while the sidecars reference `.Values.securityContext` breaks them.
Keep it FLAT: config groups + k8s at root, sidecars/migrations as their own top-level blocks. The
chart IS the component; the umbrella's subchart-name namespacing already scopes it (`br-slc.redis`).

**Still non-conformant (fix on sight):** a hyphenated component key needing `index .Values "br-sta"`
(early br-sta) — always camelCase. Note the umbrella cost: a wrapped chart is `br-ccs.brCcs.redis`
(double level) vs a flat one `br-slc.redis` (single) — the wrapper is the accepted price of one
block per deployment when a chart genuinely has more than one.

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

**Two `global.*` tiers (P1 #4):** the domain blocks above (`global.observability`,
`global.multiTenant`, `global.datastores`, `global.serviceDiscovery`, `global.streaming`,
`global.auth`) are the env-wide CONFIG tier. Additionally ensure the k8s-INFRA tier exists for
the umbrella: `global.imageRegistry`, `global.imagePullSecrets`, `global.storageClass`,
`commonLabels` — shared once at the umbrella and read by every component subchart.

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
   Keep nesting ≤ 3 levels (`<comp>.<group>.<field>`) — deeper only for native k8s structs
   (securityContext). Do not nest single, unrelated knobs (Helm favours flat for simplicity).
6. **Empty the raw config** in values.yaml (`configmap: {}` / `data: {}`) and add the grouped
   blocks. Each documented value carries a **`# -- <description>`** helm-docs annotation (P0 #2);
   the README table auto-generates via `scripts/gen-docs.py --values <v.yaml> --out <chart>/
   README.params.md` (run `--check` in CI to fail on drift). Keep `<comp>.extraEnvVars` as the
   documented injection hatch. Carry any value that DIFFERED from the template default into the
   group default (Rule 3).
7. **Secrets** → `secrets.yaml`. Prefer the `existingSecret` reference model; then per var:
   - **fail-fast** (`required` / `multiTenant.secret`) when the owning feature is enabled — for
     money-path credentials that must be operator-provided.
   - **generate-or-reuse** for chart-owned generated secrets: use the lerian-common
     `secrets.manage` helper (existingSecret › `lookup` the live Secret to REUSE on upgrade ›
     random generate on first install › fail-on-empty-upgrade). This prevents password churn on
     `helm upgrade`. (If the helper is missing, record it as a lerian-common gap — do not
     hand-roll `lookup`.)
   - Emit-when-set passthrough for the optional long tail.
   Backstop: a leaked-secret guard — a value classified secret must NEVER land in a plaintext
   ConfigMap; route it to the Secret (fail the render if it would leak).
8. **Ship a strict `values.schema.json`** (P0 #1) — run `scripts/gen-schema.py --values <v.yaml>
   --chart-dir <chart> --out <chart>/values.schema.json`. It parses BOTH values.yaml AND
   `templates/configmap.yaml` (the grouped blocks ship empty `{}`, so the group FIELDS are read
   from the `cfgValue "field"/"default"` args — template-as-source-of-truth). Output is
   strict-where-safe: `additionalProperties:false` on the CLOSED typed group blocks (a typo like
   `<comp>.redis.poolSizeX` is rejected at `helm template`), permissive (`true`) on ROOT,
   subcharts, `global`, and OPEN maps (`configmap`/`extraEnvVars`) so legitimate keys never break.
   Config fields are typed `string` (env vars are strings) → operators use `--set-string` or quote
   in values; `default`-everything, `required` sparingly (like cert-manager). Add a
   `# -- (enum: a|b|c) desc` annotation to emit an `enum` for a closed set. Verify: `helm lint`
   passes AND a deliberate typo is rejected.
9. **Naming + hatches baseline** (verify present): `nameOverride`/`fullnameOverride`, camelCase
   keys, `enabled` toggles, and the standard escape hatches (`extraEnvVars`, `extraVolumes`/
   `extraVolumeMounts`, `extraContainers`, `podAnnotations`/`podLabels`, `resources`,
   `nodeSelector`/`tolerations`/`affinity`, `extraObjects`).

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

Run `scripts/coverage.py --chart-dir <chart> --env <app>.env --fixture <enable-all>` — it
renders the WHOLE chart (one `helm template`, so worker / signer / mqbridge / sub-component
ConfigMaps are all included) and reconciles emitted keys vs the `.env`:

- **Coverage**: every ACTIVE `.env` var is emitted, an emit-when-set secret, or belongs to a
  WIRED domain — else it is a gap.
- **Helper actually wired** (not just prefix-matched): a domain (SD/streaming/MT/OTEL/auth) counts
  as covered only when its ANCHOR key (`SD_ENABLED`, `STREAMING_ENABLED`, …) renders. An `SD_*`
  var in the `.env` with the helper UNWIRED is a hard FAIL ("domain helper not wired") — this is
  what catches a whole domain the chart forgot (byte-identical to the prior chart would hide it).
- **No raw drift**: an emitted key not in the `.env` is flagged chart-only (dead config or `.env` gap).
- **Byte-identical** (regression guard, NOT completeness): default render == prior productized
  render, except intentionally-gated keys (MT/streaming infra now only render when enabled).
- **Schema**: `helm lint`/`template` validates against the shipped `values.schema.json` — a
  typo'd key under a closed block is rejected (that is the user-facing half of the coverage check).
- **Docs**: the README parameter table regenerates from the `# --` annotations with no diff.
- `helm lint` + the repo render-gate + strict standard all green.

Emit a **coverage report** at the end: N config / N secret / N helper / N datastore / gaps list.
For any judgment call the heuristics were unsure about, print `REVIEW: <key> classified as <kind>`
so the human confirms in the PR — the skill proposes, the reviewer decides.

## Output

Modified `templates/configmap.yaml`, `templates/secrets.yaml`, `values.yaml`, `values.schema.json`,
a render fixture (`.github/configs/helm-render-values/<chart>.yaml` enabling the productized paths),
and the coverage report. One chart per PR.

## Market alignment (why we diverge, and where we adopt)

Studied against consolidated OSS charts (Bitnami `common`/postgresql/redis, Grafana/Loki/
kube-prometheus-stack, cert-manager, ingress-nginx) + the Helm Chart Best Practices.

**Where our premise is JUSTIFIED (keep):** the market splits into "enumerate every knob"
(Bitnami) and "pass a structured config blob" (Grafana `grafana.ini`, ingress-nginx
`controller.config`). The blob exists because those charts wrap FOREIGN apps with hundreds of
fast-churning config keys they don't own — it decouples the chart from that churn. **That reason
does not apply to us**: our `.env.example` is a finite, versioned, app-owned 12-factor contract,
so enumerate-and-type buys typing, validation, per-key defaults, grouping and fail-fast secrets.
Copying the blob would be cargo-culting. The coverage check is what makes enumeration
sustainable (our substitute for the "stay-in-sync" the blob dodges).

**Where we were WRONG / adopt from the market:**
- Every mature chart — even 100%-typed Bitnami and 100%-blob Grafana — keeps an env escape hatch.
  Never remove `extraEnvVars` / the `configmap.<KEY>` override. `configmap: {}` = "no defaults",
  not "locked". (Premise section.)
- Ship a strict `values.schema.json` (`additionalProperties:false`) — the single biggest gap; it
  is the user-facing guardrail our "everything typed" premise earns. (Step 8.)
- Annotation-driven docs (`# --` / `@param`) + auto-generated README — never hand-write tables. (Step 6.)
- Secrets: `lookup`+manage (reuse-on-upgrade), not only fail-fast; + a leaked-secret guard. (Step 7.)
- A k8s-infra `global.*` tier for the umbrella (registry/pullSecrets/storageClass/commonLabels). (Domain map.)

**Exception:** if an app ever ships a genuinely NESTED config file (not flat env), model it as a
structured passthrough map rendered to a ConfigMap (grafana.ini pattern) — do NOT flatten every
leaf into a grouped param. Full enumeration is for the flat 12-factor `.env` surface only.
