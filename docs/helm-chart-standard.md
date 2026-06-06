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
