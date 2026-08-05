---
name: productize-chart-env
description: >-
  Productize a Lerian Helm chart's configuration from the app's config/.env.example
  onto lerian-common. Typed KNOBS are reserved for DEPENDENCY CONNECTIONS (db/cache/broker/
  streaming/service-discovery/tenant-manager/auth/object-storage) via domain helpers/masks;
  ALL other app config stays an escape-hatch passthrough with the default in the template;
  credentials become fail-fast secrets. Use when productizing a chart, or when the app
  added/renamed env vars and the chart must re-sync to the .env contract.
---

# Productize a chart's config from the app `.env` (the #1741 pattern)

## Premise (non-negotiable)

The **app's config is the authority — NOT the chart's prior render.** Use the `config/.env.example`
as the working surface, BUT the true authority is what the app actually READS — the config struct
(`config.go` / `config.ts` / `LoadConfig`). The `.env.example` is the *documented* surface and can
LAG the struct (real example: `STREAMING_SASL_MECHANISM` is read by the app + emitted by the
streaming helper but absent from br-ccs's `.env.example`). So: cross-check the `.env.example`
against the config struct, and never let a missing `.env` line hide a key the app reads — this is
exactly why the schema allowlist unions the `.env` keys with the chart's RENDERED keys (Step 8) and
why `coverage.py` FAILS on a struct/emitted key that the surface misses. (Aligns with
`ring-dev-team:creating-helm-charts`, which measures coverage against the config struct, not the
example file.)

Every ACTIVE env var must be COVERED (settable + defaulted), but coverage is TIERED — a typed knob is
NOT the goal for every key. **Reserve typed knobs for DEPENDENCY CONNECTIONS; everything else is
an escape-hatch passthrough with the default in the template.**

**The dividing question is by NATURE, not by helper: "is this how the app reaches a DEPENDENCY?"**
Databases, cache, broker, streaming, service-discovery, tenant-manager/auth, object storage — the
things a non-expert MUST wire to get running. Those get a masked, typed, validated knob. All the
rest — rate-limit, outbox, swagger, cors, pagination, probes, timeouts, retention, pool tuning —
has a sensible default and is reached only by the rare expert, via the escape hatch.

Every ACTIVE var is therefore exactly one of:

- **dependency knob** → `lerian-common.datastore.value` mask (db/cache/broker: host/port/user/ssl)
  OR a domain helper (`multiTenant.env`, `streaming.env`, `serviceDiscovery.env`, `otel.env`,
  `globalValue` auth) + `global.*` block OR a small typed mask for a dependency the lib doesn't
  cover yet (object storage: endpoint/region/bucket). This is the DOCUMENTED, schema-guarded surface.
- **passthrough config** → `{{ $cm.KEY | default "<.env value>" | quote }}` — default in the
  template, overridable via `configmap.<KEY>`. NOT a grouped param, NOT a `<comp>.<group>` block.
- **secret** → `secrets.yaml` + a fail-fast (`multiTenant.secret`, or a `required` guard)
- **gap** → recorded backlog (app declares it, chart can't cover it yet)
- **omitted** → with a written reason

Why this is not overengineering: the old model routed all ~120 keys through `cfgValue` grouped
params. That MASKS THE NAME but never REDUCES THE COUNT — a non-expert facing 120
`redis.connMaxIdleTimeMins` is no better off than facing 120 env vars, and each grouped param is a
hand-maintained PARALLEL contract that can silently diverge from the env key (the `postgresName`
vs `postgres.name` bug) with the schema unable to catch it. Tiering cuts the typed surface ~90→~15
knobs and the schema ~50% while staying byte-identical (the grouped params were freshly invented,
not the app's contract — dropping them changes nothing that shipped).

**Two escape hatches stay open (every mature chart keeps one — do NOT remove them):**
- `<comp>.configmap.<KEY>` — the PRIMARY override surface now: sets/overrides any passthrough key
  (`$cm.KEY` reads it first, before the template default).
- `<comp>.extraEnvVars` — injects ANY var, incl. one the app added before the chart re-synced.
The typed dependency knobs are the *documented, must-set* surface; the hatches carry the long tail.
See "Market alignment" at the end for why we still enumerate the .env (for the schema allowlist)
without turning every key into a knob.

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

**The closed dependency vocabulary — the STANDARD — lives in `references/dependency-contract.md`:
the full table (per domain: helper, `global.*` block, per-component knob, secrets), the
object-storage gap, and the rule for adding a new domain (extend lerian-common, never a per-chart
knob). Read it — it is what makes "knob IFF it matches a declared dependency domain" mechanical
instead of per-app judgment.** The quick table below is a summary; the contract is canonical.

Current at time of writing — **verify against Step 0**, the introspection is the source of truth.
These ALWAYS go to a helper (never a passthrough) — that is where `global.*` env-wide config lives.
The helpers already exist; you are only WIRING them.

| .env prefix | helper | global block | notes |
|---|---|---|---|
| `MULTI_TENANT_*` | `multiTenant.env` + `multiTenant.secret` | `global.multiTenant` | toggle via `<comp>.multiTenant.enabled`; URL/REDIS_HOST required when on; API_KEY fail-fast |
| `ENABLE_TELEMETRY`, `OTEL_*` | `otel.env` (+ `otel.envFlat` for identity) | `global.observability` | shared 3 keys derive; name/library/version per-component |
| `POSTGRES_*`/`REDIS_*`/`RABBITMQ_*` host+conn | `datastore.value` (type postgres/redis/broker) | `global.datastores` (+ `<comp>.datastores`) | host/port/user/ssl/replicaHost only; TUNING (pool/timeouts) stays cfgValue |
| `SD_*` | `serviceDiscovery.env` or `.envFlat` | `global.serviceDiscovery` | envFlat (flat passthrough) is the simplest for a consumer chart |
| `STREAMING_*` | `streaming.env` + `streaming.secret` | `global.streaming` | full SASL/broker contract; `STREAMING_SASL_PASSWORD` is a secret |
| `PLUGIN_AUTH_*` | `globalValue` (block `auth`) | `global.auth` | ENABLED always; HOST emitted only when non-empty |
| `OBJECT_STORAGE_*` (endpoint/region/bucket) | small typed mask under `<comp>.objectStorage` | — | S3/SeaweedFS IS a dependency connection → knob by NATURE even though the lib has no helper yet; access/secret keys go to `secrets`. Raise a lerian-common gap to add a real `objectStorage` mask helper. |

Everything NOT in this map is **passthrough config** (rate-limit, outbox, swagger, cors, pagination,
probes, timeouts, retention, pool/client tuning, service-specific knobs) → `{{ $cm.KEY | default
"X" }}`, NOT a grouped param. **Classify by NATURE, not by which helper exists:** a dependency
connection with no helper yet (object storage) still gets a knob (add a mask); a non-dependency
key never gets one even though `cfgValue` could route it. `cfgValue` is now used ONLY for the rare
case where a dependency knob needs the `configmap.<KEY>` › knob › default precedence (e.g. a
toggle the render-gate drives); prefer the plain passthrough otherwise.

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
5. **Emit each key by its tier** (declare `{{- $cm := .Values.<comp>.configmap | default dict -}}`
   at the top):
   - **Passthrough (the default — every non-dependency key):**
     `{{ $cm.KEY | default "<.env value>" | quote }}`. No group var, no `<comp>.<group>` block.
     Keep any `{{- if ... }}` / `range` conditional exactly. This is 80–90% of the keys.
   - **Dependency knob:** wire the domain helper/mask (Step 4) for db/cache/broker/streaming/SD/
     MT/auth; for object storage add a small typed `<comp>.objectStorage` mask (endpoint/region/
     bucket). Use `cfgValue` ONLY when a dependency knob genuinely needs the
     `configmap.<KEY>` › knob › default precedence (rare — e.g. a toggle the fixture drives).
   - Carry any value that DIFFERED from the template default into the passthrough `| default "X"`
     (Rule 3) — e.g. br-ccs `OBJECT_STORAGE_*_BUCKET` shipped real bucket names, so
     `| default "lerian-ccs"`, not `| default ""`.
6. **values.yaml holds ONLY the tiered surface:** `global.*`, the datastore mask + `external*Definitions`,
   the dependency toggles/blocks (`multiTenant`/`serviceDiscovery`/`streaming`/`objectStorage`), the
   k8s blocks, `configmap: {}` (now the PRIMARY override surface — document it prominently), and
   `extraEnvVars`. **No `<comp>.<group>` blocks for non-dependency config** — those defaults live in
   the template. Each kept knob carries a **`# -- <description>`** helm-docs annotation (P0 #2);
   `scripts/gen-docs.py --values <v.yaml> --out <chart>/README.params.md` regenerates the table
   (`--check` in CI). Also produce **`values-quickstart.yaml`** (Step 10) — the layperson layer.
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
   strict-where-safe: `additionalProperties:false` on the CLOSED typed DEPENDENCY blocks (a typo like
   `<comp>.redis.poolSizeX` is rejected at `helm template`), permissive on ROOT, subcharts, `global`.
   **The `configmap` escape hatch is now the primary surface — guard it with `propertyNames.enum`**
   = the flat allowlist of valid NATIVE_KEYs (`gen-schema.py --env <app>.env --rendered-keys <file>`).
   This restores typo protection the tiering would otherwise lose: `configmap.RATE_LIMIT_MAXX` is
   rejected while `configmap.RATE_LIMIT_MAX` is accepted — WITHOUT re-enumerating types or groups.
   **CRITICAL: the allowlist is the UNION of the `.env` keys AND the keys the chart RENDERS** — the
   `.env.example` alone is TOO STRICT (the app reads, and helpers emit, keys the .env omits: e.g.
   `STREAMING_SASL_MECHANISM` is an SD/streaming gap the streaming.env helper still emits — a
   .env-only enum wrongly rejects it and breaks the render-gate). Produce `--rendered-keys` with the
   schema DISABLED (chicken-and-egg — the strict schema would reject the fixture and render empty):
   `mv values.schema.json /tmp && helm template t <chart> -f <enable-all-fixture> -s templates/configmap.yaml | grep -oE '^  [A-Z][A-Z0-9_]+:' | tr -d ' :' | sort -u > keys.txt`.
   Keep `extraEnvVars` fully open (that IS the un-enumerated hatch).
   Values are typed `string` (env vars are strings) → operators use `--set-string` or quote;
   `default`-everything, `required` sparingly. `# -- (enum: a|b|c) desc` emits an `enum` for a
   closed set. Verify: `helm lint` passes, a dependency-block typo is rejected, AND an unknown
   `configmap.<KEY>` is rejected while a real one is accepted.
9. **Naming + hatches baseline** (verify present): `nameOverride`/`fullnameOverride`, camelCase
   keys, `enabled` toggles, and the standard escape hatches (`extraEnvVars`, `extraVolumes`/
   `extraVolumeMounts`, `extraContainers`, `podAnnotations`/`podLabels`, `resources`,
   `nodeSelector`/`tolerations`/`affinity`, `extraObjects`).
10. **`values-quickstart.yaml` — the layperson layer (the "two layers" model).** The full chart is
    the power-user / wizard API; ship a tiny quickstart the non-expert copies and fills. It holds
    ONLY the dependency-connection knobs to get running: db/cache/broker host+user, the enable
    toggles (`multiTenant`/`serviceDiscovery`/`streaming`), `image.tag`, `ingress` host, object
    storage endpoint/bucket, and the `secrets` (with `CHANGE_ME`), each with a `# comment` +
    example. Aim ~15–25 knob lines. A couple of common overrides may go under `configmap:` as
    examples. This is the artifact for "sees the chart from outside without reading templates" —
    the docs/README lead with it. (Do NOT base it on a stale `values-template.yaml`; those drift.)

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
   or emptying `configmap` breaks byte-identity. **The `.env.example` is the authority for the
   default's VALUE** — mirror it verbatim even when a value looks wrong (br-sta ships
   `REDIS_MIN_RETRY_BACKOFF=8` > `REDIS_MAX_RETRY_BACKOFF=1`; the chart must match, not "fix" it —
   an inverted default is an APP bug to report upstream, never silently corrected in the chart,
   which would drift the chart from the app's own default).
4. **Source of truth = MANAGER render**, not `awk` over values.yaml — a naive `^  configmap:`
   match also captures `worker.configmap`, injecting worker-only keys into the manager.
5. **`rateLimit.env` / `auth.env` emit a FIXED key set** that may not match the chart
   (rateLimit.env adds `ALLOW_RATELIMIT_DISABLED` + `RATE_LIMIT_REDIS_TIMEOUT_MS`; auth.env always
   emits HOST). If the chart's surface differs, use per-key `cfgValue`/`globalValue` instead.
6. **If you generate lines with a Python f-string, `}}` becomes `}`** — use a normal string or a
   post-regex to restore `| quote }}`.
7. **Optional/opt-in keys** (`{{- if $cm.X }}`, `if REPORTER_ENABLED`, `range` over lists) stay
   conditional — keep the guard when demoting to a passthrough (`{{- if $cm.X }}...{{- end }}`).
8. **A Go-template comment `{{/* … */}}` breaks if its TEXT contains `*/`** ("comment ends before
   closing delimiter"). Listing keys like `OTEL_RESOURCE_*/OTEL_LIBRARY_NAME` in a comment closes
   it early — write `OTEL_RESOURCE_* and OTEL_LIBRARY_NAME` instead.
9. **`additionalProperties:false` only on the finite typed DEPENDENCY blocks.** Never close k8s
   OPERATIONAL blocks (role/autoscaling/pdb/resources/tolerations/scheduling) — operators pass
   valid keys the generator never saw (`pdb.maxUnavailable`, `resources.limits`), and a closed
   block rejects them at `helm install`. The `configmap` escape hatch is NOT closed either — it is
   an open map guarded by `propertyNames.enum` (the .env allowlist), so unknown keys are rejected
   but any real NATIVE_KEY is accepted. `gen-schema.py` leaves generic dicts
   `additionalProperties:true` and operational scalars untyped (default/enum only) — verify after
   regen that a dependency-block typo AND an unknown `configmap.<KEY>` are both rejected, while
   valid operator input is accepted.
   CAVEAT: adding `items: {type: object}` to a `tolerations`/array field (so `["NoSchedule"]` is
   rejected) is a MANUAL delta — `gen-schema.py` can't infer array item types and will DROP it on
   the next regen. Either re-apply it after regen, or teach the generator the known array fields.
10. **Byte-identity validation is FALSE unless the schema is OFF on both sides.** A schema failure
    renders empty, so two empty renders diff as "identical". When comparing template changes,
    `mv values.schema.json` aside on BOTH the baseline (`git worktree add --detach <pre-commit>`
    or `git stash`) and the new tree, and make the fixture respect each default's TYPE
    (`tolerations: []` not `{}`; a map-vs-array `coalesce` silently renders empty).
11. **Resource-template partials aren't all byte-safe.** `lerian-common.service/.hpa/.pdb/
    .serviceAccount/.ingress` and `imagePullSecrets/.httpProbe` migrate cleanly, but
    `lerian-common.scheduling` emits a LEADING newline → trailing whitespace under `| nindent`,
    and `deploymentStrategy`'s `toYaml` reorders keys — keep those two INLINE (documented lib bugs
    to report, not work around). Ingress backend that points at a per-role service needs the lib's
    `backendName` param (name ≠ metadata.name).
12. **When lerian-common bumps, EVERY consumer must refresh** its `Chart.yaml` pin + `Chart.lock`
    (`git merge origin/main` → bump pin → `helm dependency update`), or the base=main merge-check
    fails `missing-dependency` in the render-gate. And for a NEW chart, productize INSIDE the
    add-PR — a productization branch stacked on an add-branch that lacks `charts/lerian-common`
    can never `helm dep build`.

## Self-check (the skill refuses to finish unless all pass)

Run `scripts/coverage.py --chart-dir <chart> --env <app>.env --fixture <enable-all>` — it
renders the WHOLE chart (one `helm template`, so worker / signer / mqbridge / sub-component
ConfigMaps are all included) and reconciles emitted keys vs the `.env`:

- **Coverage**: every ACTIVE `.env` var is emitted (as a dependency knob or a passthrough), an
  emit-when-set secret, or belongs to a WIRED domain — else it is a gap. A passthrough key still
  renders its default, so it counts as covered; it must also appear in the `propertyNames.enum`
  allowlist.
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

Modified `templates/configmap.yaml` (dependency keys via helpers/masks; everything else a
`$cm.KEY | default` passthrough), `templates/secrets.yaml`, `values.yaml` (only the tiered
surface — no `<comp>.<group>` blocks for non-dependency config), `values.schema.json` (closed
dependency blocks + `propertyNames.enum` allowlist on `configmap`), **`values-quickstart.yaml`**
(the layperson layer), a render fixture (`.github/configs/helm-render-values/<chart>.yaml`
enabling the dependency paths), and the coverage report. One chart per PR.

## Market alignment (why we diverge, and where we adopt)

Studied against consolidated OSS charts (Bitnami `common`/postgresql/redis, Grafana/Loki/
kube-prometheus-stack, cert-manager, ingress-nginx) + the Helm Chart Best Practices.

**Where we land (a deliberate MIDDLE):** the market splits into "type every knob" (Bitnami) and
"pass a structured config blob" (Grafana `grafana.ini`, ingress-nginx `controller.config`). We
reject both extremes. Full typing (our earlier model) masks the NAME but not the COUNT — 120
grouped params overwhelm a non-expert exactly as 120 env vars do, and each is a hand-maintained
parallel contract that silently drifts. The opaque blob throws away typing where it matters. Our
finite, app-owned `.env` lets us do better: **type only the dependency connections** (the must-set
surface a non-expert wires) and leave the long tail as a passthrough with template defaults —
Bitnami-style typing where it earns its keep, blob-style passthrough where it doesn't. We still
ENUMERATE the whole `.env`, but for the SCHEMA ALLOWLIST (`propertyNames.enum` on the escape hatch
→ typo protection) and the coverage check, NOT to mint a knob per key. `coverage.py` is what keeps
the allowlist in sync with the app.

**Where we were WRONG / adopt from the market:**
- Every mature chart — even 100%-typed Bitnami and 100%-blob Grafana — keeps an env escape hatch.
  Never remove `extraEnvVars` / the `configmap.<KEY>` override. `configmap: {}` = "no defaults",
  not "locked". (Premise section.)
- Ship a strict `values.schema.json` — `additionalProperties:false` on the typed dependency blocks
  + `propertyNames.enum` on the `configmap` escape hatch (typo protection without per-key typing).
  The user-facing guardrail. (Step 8.)
- Annotation-driven docs (`# --` / `@param`) + auto-generated README — never hand-write tables. (Step 6.)
- Secrets: `lookup`+manage (reuse-on-upgrade), not only fail-fast; + a leaked-secret guard. (Step 7.)
- A k8s-infra `global.*` tier for the umbrella (registry/pullSecrets/storageClass/commonLabels). (Domain map.)

**Exception:** if an app ever ships a genuinely NESTED config file (not flat env), model it as a
structured passthrough map rendered to a ConfigMap (grafana.ini pattern) — do NOT flatten every
leaf into a grouped param. Full enumeration is for the flat 12-factor `.env` surface only.
