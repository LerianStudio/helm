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

| Subchart | Pinned version | Secret name pattern | Data key(s) |
|----------|----------------|---------------------|-------------|
| postgresql | 16.3 | `<release>-postgresql` | `postgres-password` (admin/superuser), `password` (the `auth.username` user), `replication-password` |
| mongodb | 16.4.0 | `<release>-mongodb` | `mongodb-root-password` (root user); `mongodb-passwords` (array, only when `auth.usernames`/`auth.passwords` provision non-root users) |
| valkey | 2.4.7 | `<release>-valkey` | `valkey-password` |

Name resolution rule:
- Default: `printf "%s-%s" .Release.Name "<subchart>"` — the Secret name tracks the **release name**, not the chart name. Charts that hardcode the service host to a fixed name (e.g. `plugin-fees-mongodb`) therefore assume a fixed release name; document that assumption in the chart README.
- `nameOverride`/`fullnameOverride` on the subchart shifts the Secret name accordingly; account for it when set.
- `existingSecret` override: when the operator sets `<subchart>.auth.existingSecret`, that name wins. The helper must prefer it.
- Root vs non-root key: use `mongodb-root-password` when the app authenticates as the root user (`auth.rootUser`), `password`/`mongodb-passwords` when it authenticates as a provisioned non-root user. Confirm which user the app connects as before choosing the key.

### `infraSecretRef` helper contract

Application charts have no shared library chart, so the helper lives per-chart in `templates/_helpers.tpl`. Each chart that adopts Pattern A defines:

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
{{- $auth := index $ctx.Values $sub "auth" | default dict -}}
{{- $secretName := "" -}}
{{- if $auth.existingSecret -}}
{{-   $secretName = $auth.existingSecret -}}
{{- else -}}
{{-   $secretName = printf "%s-%s" $ctx.Release.Name $sub -}}
{{- end -}}
- name: {{ .envName }}
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: {{ .key }}
{{- end -}}
```

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

## Validation

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

Every chart must pass the repository validator:

```sh
cd .github/scripts
go run ./validate-helm-charts.go --root ../.. --strict
```

The migration baseline must stay empty. Use `--baseline` only for local audit workflows; CI uses strict mode so new drift cannot be hidden by editing the baseline in the same pull request.

Every chart must also render through the repository render gate:

```sh
cd .github/scripts
go run ./validate-helm-charts.go --root ../.. --render-gate --all
```

Charts with required production values use dummy CI-only fixtures under `.github/configs/helm-render-values/<chart>.yaml`. These files are not production examples and must not contain real credentials.
