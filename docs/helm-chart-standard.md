# Helm Chart Standard

This document defines the repository contract for Lerian Helm charts. It exists so charts do not drift by copying the nearest old outlier.

## Chart Types

Every `charts/*/Chart.yaml` must declare one chart type:

```yaml
annotations:
  lerian.studio/chart-type: single-service
```

Allowed values:

| Type | Use for | Required shape |
|------|---------|----------------|
| `single-service` | One deployable application or a constrained mock/stub | Root-level application templates |
| `multi-component` | Multiple deployable components in one chart | Component directories plus shared common templates |
| `dependency-wrapper` | A chart that primarily configures upstream dependencies | `Chart.yaml`, `Chart.lock`, `README.md`, `values.yaml`, optional `values-template.yaml`, optional `values.schema.json` |

`mock` is not a chart type. Mock charts use `single-service` and may carry temporary baseline exceptions while they are migrated.

`otel-collector-lerian` is the canonical `dependency-wrapper` example because it wraps the upstream OpenTelemetry Collector chart.

## Single-Service Tree

```text
charts/<service>/
├── Chart.yaml
├── Chart.lock
├── README.md
├── values.yaml
├── values-template.yaml
├── values.schema.json
├── charts/
└── templates/
    ├── _helpers.tpl
    ├── serviceaccount.yaml
    ├── configmap.yaml
    ├── secrets.yaml
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    ├── hpa.yaml
    ├── pdb.yaml
    ├── bootstrap-postgres.yaml
    ├── bootstrap-mongodb.yaml
    ├── bootstrap-rabbitmq.yaml
    └── NOTES.txt
```

Bootstrap files are optional and must exist only when the chart owns that bootstrap path.

## Multi-Component Tree

```text
charts/<service>/
├── Chart.yaml
├── Chart.lock
├── README.md
├── values.yaml
├── values-template.yaml
├── values.schema.json
├── charts/
└── templates/
    ├── _helpers.tpl
    ├── common/
    │   ├── serviceaccount.yaml
    │   ├── bootstrap-postgres.yaml
    │   ├── bootstrap-mongodb.yaml
    │   ├── bootstrap-rabbitmq.yaml
    │   └── NOTES.txt
    ├── <component-a>/
    │   ├── configmap.yaml
    │   ├── secrets.yaml
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   ├── ingress.yaml
    │   ├── hpa.yaml
    │   └── pdb.yaml
    └── <component-b>/
        ├── configmap.yaml
        ├── secrets.yaml
        ├── deployment.yaml
        ├── service.yaml
        ├── ingress.yaml
        ├── hpa.yaml
        └── pdb.yaml
```

Use `templates/common/` only for genuinely shared resources. Do not hide component-specific resources there to make the tree look smaller.

## Naming Rules

- Use `_helpers.tpl`, never `helpers.tpl`.
- Use `secrets.yaml`, never `secret.yaml` or `secrets.yml`.
- Use `serviceaccount.yaml`, `configmap.yaml`, `deployment.yaml`, `service.yaml`, `ingress.yaml`, `hpa.yaml`, and `pdb.yaml` for their matching resources.
- Commit `Chart.lock` for every chart with `dependencies:` in `Chart.yaml` unless the chart has a documented permanent exception.
- Keep generated dependency archives out of git.

## Values Contract

All application charts should converge on this shape. Multi-component charts repeat the component block per component.

```yaml
nameOverride: ""
fullnameOverride: ""
namespaceOverride: ""

global:
  imageRegistry: ""
  imagePullSecrets: []
  commonLabels: {}
  commonAnnotations: {}

serviceAccount:
  create: true
  annotations: {}
  name: ""

podSecurityContext:
  fsGroup: 1000

securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
  seccompProfile:
    type: RuntimeDefault

app:
  enabled: true
  replicaCount: 1
  image:
    repository: ""
    tag: ""
    pullPolicy: IfNotPresent
  configmap: {}
  secrets: {}
  existingSecret:
    name: ""
  service:
    type: ClusterIP
    port: 8080
    targetPort: http
  ingress:
    enabled: false
    className: ""
    annotations: {}
    hosts: []
    tls: []
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      memory: 256Mi
  livenessProbe:
    path: /health
    initialDelaySeconds: 15
  readinessProbe:
    path: /readyz
    initialDelaySeconds: 5
  startupProbe:
    enabled: false
  autoscaling:
    enabled: false
    minReplicas: 2
    maxReplicas: 5
    targetCPUUtilizationPercentage: 80
  pdb:
    enabled: true
    minAvailable: 1
```

## Secret Policy

- Do not put passwords, tokens, private keys, signing secrets, credential-bearing URLs, or DSNs with credentials in `configmap` sections or ConfigMaps.
- Do not publish real or reusable default credentials such as `"lerian"` in `values.yaml`.
- Prefer `existingSecret.name` for production credentials.
- `values-template.yaml` may contain empty placeholders for required secrets.
- If a secret is required, use a clear Helm `required` message and mirror the key in `values-template.yaml`.

## Single-Source Infra Secrets

Each infrastructure credential (Postgres / Mongo / Valkey / RabbitMQ password) must live in exactly **one** place. The hazard being eliminated: an application chart historically kept its own copy of the infra password (in `<component>.secrets.*`) **and** the subchart kept another (`<subchart>.auth.*`), with no link between them. The operator had to set the same value twice; an old `| default "lerian"` masked the mismatch. The rule: pick a single owner per credential based on subchart provenance, and have the other side reference it.

### Pattern A — Bitnami subcharts (app references subchart)

For Bitnami `postgresql` / `mongodb` / `valkey`, leave the password empty so the subchart auto-generates it into its **own** Secret, then have the application container read that Secret via a discrete `secretKeyRef` env entry. The app's own Secret (delivered by `envFrom: secretRef`) keeps only non-infra keys (client secrets, encryption keys).

Generated Secret name and data keys, **verified against rendered output at this repo's pinned subchart versions** (version-sensitive — re-verify on subchart bump):

| Subchart | Pinned version(s) | Secret name pattern | Data key(s) |
|----------|-------------------|---------------------|-------------|
| postgresql | 16.3.5 | derived (see below), default `<release>-postgresql` | `postgres-password` (admin/superuser), `password` (the `auth.username` user), `replication-password` |
| mongodb | 16.4.0 / 16.4.12 | derived (see below), default `<release>-mongodb` | `mongodb-root-password` (root user); `mongodb-passwords` (array, only when `auth.usernames`/`auth.passwords` provision non-root users) |
| valkey | 0.7.4 / 2.4.6 / 2.4.7 | derived (see below), default `<release>-valkey` | `valkey-password` |

Every Bitnami dependency is pinned to an **exact** version in `Chart.yaml` (no `~`/`^` ranges). Versions are not yet uniform across charts; the table lists the versions in use. Re-verify the Secret name and data keys against `helm template` output whenever a chart bumps its pin.

Name resolution rule — **do not** hardcode `printf "%s-%s" .Release.Name "<subchart>"`. The Bitnami `common` library collapses `<release>-<subchart>` to just `<subchart>` when the release name already contains the subchart name (the release-name collapse), so a hardcoded `<release>-<subchart>` dangles when the operator names the release after the subchart. Derive the name through the upstream helper instead:

```
{{ include "common.names.dependency.fullname" (dict "chartName" "<subchart-or-alias>" "chartValues" (index .Values "<subchart>") "context" $) }}
```

- `chartName` is the dependency **alias** when the dependency is aliased in `Chart.yaml`, otherwise the dependency name. Example: `plugin-access-manager` aliases `postgresql` as `auth-database`, so its helper passes `"chartName" "auth-database"` and indexes `.Values "auth-database"`.
- `chartValues` is the subchart's own values block (`index .Values "<subchart>"`), so `nameOverride`/`fullnameOverride` on the subchart are honored automatically.
- `existingSecret` override: when the operator sets `<subchart>.auth.existingSecret`, that name wins. The helper must prefer it before deriving.
- The helper ships with the Bitnami `common` library chart, which is pulled in transitively under every Bitnami dependency; it is available to any chart that bundles `postgresql`/`mongodb`/`valkey`. Built dependency archives under `charts/*/charts/` are gitignored, so the definition is not in the repo source — `helm dependency build` materializes it.
- Root vs non-root key: use `mongodb-root-password` when the app authenticates as the root user (`auth.rootUser`), `password`/`mongodb-passwords` when it authenticates as a provisioned non-root user. Confirm which user the app connects as before choosing the key.

A small number of non-Bitnami subcharts (e.g. `groundhog2k/rabbitmq`) have their own name derivation; charts replicate it collapse-aware in their own `_helpers.tpl` rather than reusing `common.names.dependency.fullname` (which is Bitnami-specific).

### `infraSecretRef` helper contract

Application charts have no first-party shared library chart, so this helper lives per-chart in `templates/_helpers.tpl` (it wraps the transitively-available Bitnami `common.names.dependency.fullname`). Each chart that adopts Pattern A defines:

```
{{/*
infraSecretRef — emit a `- name: <envName> valueFrom: secretKeyRef: {name,key}` env entry
pointing at a Bitnami subchart's generated Secret (or the operator's existingSecret override).
Inputs (dict): context (root .), subchart ("postgresql"|"mongodb"|"valkey"),
key (data key), envName (container env var name).
*/}}
{{- define "<chart>.infraSecretRef" -}}
{{- $ctx := .context -}}
{{- $sub := .subchart -}}
{{- $auth := default dict (index $ctx.Values $sub "auth") -}}
{{- $secretName := "" -}}
{{- if $auth.existingSecret -}}
{{-   $secretName = $auth.existingSecret -}}
{{- else -}}
{{-   $secretName = include "common.names.dependency.fullname" (dict "chartName" $sub "chartValues" (index $ctx.Values $sub) "context" $ctx) -}}
{{- end -}}
- name: {{ .envName }}
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: {{ .key }}
{{- end -}}
```

When the dependency is aliased, pass the alias as the subchart key (the chart's `dbPasswordEnv`-style helpers index `.Values` under the alias and pass `"chartName" "<alias>"`; see `plugin-access-manager`'s `plugin-auth.dbPasswordEnv` reading `auth-database`).

Usage on the app container:

```
env:
  {{- include "<chart>.infraSecretRef" (dict "context" $ "subchart" "mongodb" "key" "mongodb-root-password" "envName" "MONGO_PASSWORD") | nindent 12 }}
```

Rules:
- The infra-internal key (e.g. `MONGO_PASSWORD`) is **removed** from the chart's own `secrets.yaml` and from `<component>.secrets.*` in `values.yaml`, and added as a discrete `secretKeyRef` env entry. The app's `envFrom: secretRef` keeps the remaining non-infra keys. Avoid double-definition (do not leave the key in both the `envFrom` Secret and the discrete `env:`).
- This **replaces** any review-era `required "<component>.secrets.<KEY> is required"` gate on an infra-internal key. External-boundary keys (third-party client secrets, AES/encryption keys, license keys) keep their `required` gate — they are operator-provided and have no subchart to source them from.
- All wiring is GitOps-safe: resolution happens in-pod via `secretKeyRef`, never via Helm `lookup` at template time.

### Pattern B — non-Bitnami brokers (subchart references app)

For non-Bitnami brokers the password stays in the **application** Secret and the broker is pointed at it via the subchart's own external-secret mechanism. The application keeps the broker keys in its own `secrets.yaml` (no `required` removal needed — the app Secret is the source); only the **subchart values** change to reference them.

**`groundhog2k/rabbitmq`** exposes a per-field existing-secret model:

```yaml
rabbitmq:
  authentication:
    existingSecret: <app-secret-name>      # e.g. the manager Secret
    user:
      secretKey: RABBITMQ_DEFAULT_USER
    password:
      secretKey: RABBITMQ_DEFAULT_PASS
    erlangCookie:
      secretKey: RABBITMQ_ERLANG_COOKIE
```

Caveat: setting `authentication.existingSecret` suppresses the inline `erlangCookie.value`, and the Erlang cookie is **mandatory**. Add a stable `RABBITMQ_ERLANG_COOKIE` key to the application Secret and reference it via `erlangCookie.secretKey`. The cookie must not change across upgrades (it breaks clustering) — make it operator-provided and `required` when the bundled broker is enabled, not chart-generated (`randAlphaNum` regenerates each render and is not GitOps-safe). Pointing the broker at the app Secret also lets the app and broker agree on the username (removing drift).

**`valkey.io/valkey`** (NOT Bitnami valkey) exposes **no** Secret-based password mechanism — auth is an inline ACL written to a plaintext ConfigMap (`auth.aclConfig`), and ships disabled (`auth.enabled: false`). There is no clean single-source wiring for it; if a password is ever required, it must be injected via mounted config, not a Secret reference. Document this per chart rather than forcing a pattern. (Bitnami `valkey` — a different subchart — does follow Pattern A with key `valkey-password`.)

### Fail-loud credential gates

When a credential is no longer single-sourced from a bundled subchart — the infra is external or the subchart is disabled — the chart must **fail the render** with a clear operator message rather than emit an empty or dangling value. Each chart defines a named gate helper in `_helpers.tpl` and invokes it from the relevant Secret/Deployment template:

- A **required gate** fails when the operator-provided key is missing on the path that needs it. The canonical idiom is a `fail`/`required` inside a named helper, e.g. `reporter.rabbitmqErlangCookieRequired` (`fail` when the bundled rabbitmq is enabled but `secrets.RABBITMQ_ERLANG_COOKIE` is unset) or the inline `required` in `plugin-auth.dbPasswordEnv` (fails when `auth-database` is external/disabled and no `DB_PASSWORD` or `existingSecret` is supplied).
- A **consistency gate** fails when two values that must agree have drifted, e.g. `reporter.rabbitmqExistingSecretConsistent` fails when the broker still points at the shipped-default existing Secret name but the app Secret has been renamed, which would otherwise render a dangling reference that `values.yaml` cannot catch.

Rules for these gates:
- The message must name the exact value to set and why (clustering breaks, password not sourced, Secret renamed). Use `\n\nERROR: ...` so it stands out in `helm` output.
- Gate only on the path that actually needs the credential. For the bundled-subchart path the password comes from the subchart Secret, so no gate fires; the gate is for the external/disabled path.
- An operator-provided credential that has **no subchart to source it from** (third-party client secrets, AES/encryption keys, license keys, the RabbitMQ Erlang cookie) keeps its gate unconditionally when the consumer is active.

### `enabled` coercion (GOTCHA)

When guarding "is the bundled subchart active", do **not** write `(default true $sub.enabled)` — Helm's `default` treats an explicit `false` as empty and coerces it back to `true`, so `--set <sub>.enabled=false` would still take the subchart branch and dangle a `secretKeyRef` at a Secret that no longer renders. Use a nil-aware comparison instead:

```
{{- if or (and (ne (toString $sub.enabled) "false") (not $sub.external)) $subAuth.existingSecret }}
```

`ne (toString $sub.enabled) "false"` yields true for unset/`true` and false only for an explicit `false`.

## Security Defaults

Application containers should default to:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
  seccompProfile:
    type: RuntimeDefault
```

Any root user, writable root filesystem, or privilege escalation exception must be documented in the chart README and represented in the standard baseline until removed.

## values.schema.json

Every chart ships a `values.schema.json` so operator typos at the top level fail Helm's schema validation at render time. The schemas are **generated deterministically**, not hand-written — do not edit them by hand. Regenerate after any change to a chart's top-level `values.yaml` keys or its `Chart.yaml` dependencies:

```sh
cd .github/scripts
go run ./generate-values-schemas --root ../..
```

Policy enforced by the generator:

- The **root** schema is a closed object: `additionalProperties: false` over the chart's actual top-level `values.yaml` keys plus `global` (which Helm always injects). A top-level key the chart does not define fails validation.
- **Third-party subchart blocks** (any `Chart.yaml` dependency name/alias, plus a known set such as `postgresql`/`mongodb`/`valkey`/`rabbitmq`/`auth-database`/`otel-collector-lerian`) are left **opaque**: `type: object, additionalProperties: true`. Their value surface belongs to the dependency, so the chart does not constrain it.
- App component / app config blocks are `type: object, additionalProperties: true` (nested structure is not over-constrained); `secrets`/`configmap` sub-keys are declared as objects when present.
- Top-level scalars are type-checked (string/boolean/integer/number) against their `values.yaml` default; `required` lists the chart's top-level keys (Helm validates coalesced values, so defaults always satisfy it — it guards against a block being dropped).

## README Contract

Every chart README must include a short `## Chart Contract` block with these fields:

```markdown
## Chart Contract

- Chart type: `single-service`
- Required secrets: List the operator-provided secret keys, or state `None for default render`.
- Dependency notes: State whether dependencies are local subcharts, external services, or not used.
- Production overrides: Name the values operators must override for production, including `existingSecret` behavior when supported.
- Source/license: Link to the source repository and license.
```

Keep the block concise. Detailed operational notes can live elsewhere in the README, but these fields are the minimum public contract that CI validates.

## Validation

The CI tooling lives one directory per tool under `.github/scripts/` (`validate-helm-charts/`, `generate-values-schemas/`). The `helm-chart-standard.yml` workflow runs the static validator in strict mode and the render gate on every pull request that touches charts or the standard.

Every chart must pass the repository validator:

```sh
cd .github/scripts
go run ./validate-helm-charts --root ../.. --strict
```

Beyond the structural checks (chart type, required files, template naming, README contract, `Chart.lock`), the static validator is **path-aware** about secrets:

- It flags credential-like keys defaulted to a non-empty literal in `values.yaml` **and in templates** (`| default "..."`), credential-bearing values under `configmap`, and secret-like data keys authored into ConfigMap **templates** (not just `values.yaml`). The classifier looks through generic `value:` carriers (e.g. `erlangCookie.value`) to the meaningful parent key.
- The **dual-secret** rule fails when an app-owned infra password is `required` in a Secret template while the matching bundled Bitnami subchart is declared as a dependency — the smell that the credential is not single-sourced.

The migration baseline must stay empty. Use `--baseline` only for local audit workflows; CI uses strict mode so new drift cannot be hidden by editing the baseline in the same pull request.

Every chart must also render through the repository render gate:

```sh
cd .github/scripts
go run ./validate-helm-charts --root ../.. --render-gate --all
```

The render gate runs `helm dependency build` + `helm template` per chart and asserts:

- **Dangling secret references**: every `secretKeyRef`, `envFrom.secretRef`, and `volume.secret.secretName` in the rendered output must point at a Secret rendered in the same release.
- **Release-name collapse**: for each bundled Bitnami dependency, the chart is re-rendered with the release name set to that dependency's name (or alias). This reproduces the collapse where `common.names.dependency.fullname` shortens `<release>-<subchart>` to `<subchart>`; any helper that hardcoded `<release>-<subchart>` instead surfaces here as a dangling reference. This is why infra Secret names must be derived through the helper (see "Single-Source Infra Secrets").

A documented allowlist exempts Secrets that are intentionally provisioned out of band (each entry must carry a justification):

- `otel-api-key` — operator-provisioned before install (`otel-collector-lerian`).
- `kedaorg-certs` — self-managed at runtime by the KEDA operator's cert rotation (`reporter`).

Charts with required production values use dummy CI-only fixtures under `.github/configs/helm-render-values/<chart>.yaml`. These files are not production examples and must not contain real credentials.

## KEDA Autoscaling

KEDA `cpu` and `memory` scalers must **not** carry an `authenticationRef` — those scalers read the metrics server, not an authenticated external source, and a stray `authenticationRef` makes the ScaledObject invalid. Gate it on the trigger type, e.g. `{{- if not (has .type (list "cpu" "memory")) }}` around the `authenticationRef` block. Queue/broker scalers (e.g. rabbitmq) keep their `authenticationRef`.
