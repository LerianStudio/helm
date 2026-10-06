# lerian-common

Shared Helm **library chart** for the LerianStudio product charts. It renders
nothing on its own — it provides render-equivalent helpers (`define`s) consumed
via `include` by the product charts that declare it as a dependency.

## Helpers

- **Env contracts:** `lerian-common.serviceDiscovery.env`, `lerian-common.streaming.env`,
  `lerian-common.multiTenant.env` — env-wide constants come from `global.*`
  (set once per environment); the per-app enable knob stays in the component's
  `extraEnvVars`/`configmap`; a component value overrides the global default; and
  each helper stays **inert until enabled** (backward-compatible); `serviceDiscovery.env`
  activates on the app's `SD_ENABLED` knob (`.enabled`) and, when enabled, emits the full
  SD_* contract with `SD_ADDRESS` defaulting to `localhost:8500`; `global.serviceDiscovery.
  address` or a legacy `configmap.SD_ADDRESS` override that default, and a component
  `configmap.SD_*` value takes precedence over the `global.*` default. Ownership: the caller
  supplies exactly one SD key — `SD_ENABLED` (via `extraEnvVars`/`configmap`) — and the helper
  owns every derived `SD_*` sibling; keep those derived keys out of `extraEnvVars` (leaving one
  there too would duplicate it).
  The external endpoint (`SD_EXTERNAL_ADDRESS`/`SD_EXTERNAL_PORT`) is derived from
  the Ingress host when present, **and** is preserved when supplied explicitly via
  legacy `configmap.SD_EXTERNAL_*` even with no Ingress (on-prem) — honoring the
  `configmap.SD_*` → `global.*` → default precedence in that case too. Advanced
  tuning knobs with no grouped param (`SD_DIAL_TIMEOUT`, `SD_TLS_HANDSHAKE_TIMEOUT`,
  `SD_RESPONSE_HEADER_TIMEOUT`, `SD_SEED_TIMEOUT`, `SD_WATCH_WAIT_TIME`,
  `SD_ALLOW_STALE`) pass through from `configmap.SD_*` when set (emitted only when
  present, so the block stays clean by default).
- **Env contracts (flat-passthrough):** `lerian-common.serviceDiscovery.envFlat`,
  `lerian-common.otel.envFlat`, `lerian-common.multiTenant.envFlat` — reproduce a
  chart's EXISTING native env block **byte-for-byte** (same keys, defaults, quoting
  and line order) with **no derivation** from `global.*`. The generic primitive
  behind them is `lerian-common.env.flatBlock` (ordered `KEY: value` emitter,
  `configmap.<KEY>` > `defaults.<KEY>` > `""`, presence-based). Each chart opts into
  its own SUBSET + ORDER via `keys` and its per-key defaults via `defaults`; adoption
  is a zero-diff refactor, before optionally migrating to the derivation helpers above.
- **In-cluster host primitives:** `lerian-common.internalHost`, `lerian-common.internalURL`.
- **Resource helpers:** `lerian-common.hpa`, `.service`, `.serviceAccount`, `.pdb`, `.ingress`.
- **Deployment pod-spec fragments:** `lerian-common.scheduling`, `.topologySpreadConstraints`,
  `.imagePullSecrets`, `.httpProbe`, `.rolesAnywhere.{sidecar,volume,imdsEnv,podSecurityContext}`.
  See [Pod spreading](#pod-spreading-topologyspreadconstraints).
- **Dependency helpers:** `lerian-common.dependency.fullname`, `.infraSecretRef`.
- **`lerian-common.deploymentStrategy`.**

See `values.yaml` for the standard `global.{serviceDiscovery,streaming,multiTenant}` template.

## Pod spreading (topologySpreadConstraints)

`lerian-common.scheduling` accepts two input shapes:

1. **The component values map** (original contract) — renders `nodeSelector` /
   `affinity` / `tolerations` only. Output is byte-identical to earlier releases;
   no `topologySpreadConstraints` is ever rendered. Keep this shape for Jobs.
2. **A dict with `component` + `selectorLabels`** (and optional `global`) — renders
   the same three fields plus the `topologySpreadConstraints` resolved by
   `lerian-common.topologySpreadConstraints` (also callable on its own by charts
   that hand-write the other scheduling fields).

{% raw %}
```yaml
# consumer templates/<component>/deployment.yaml (pod spec, column 6)
      {{- with (include "lerian-common.scheduling" (dict
            "component" .Values.manager
            "global" .Values.global
            "selectorLabels" (include "myapp.manager.selectorLabels" .)) | trim) }}
      {{- . | nindent 6 }}
      {{- end }}
```
{% endraw %}

`selectorLabels` must be exactly the Deployment's `spec.selector.matchLabels` (a
dict, or the YAML string the chart's selectorLabels helper renders). The library
never guesses labels.

Resolution, first match wins:

1. `<component>.topologySpreadConstraints` — non-empty raw list, replaces the preset
   entirely. An entry without `labelSelector` gets the component's selector labels.
2. The `spread` preset, **field by field**: `<component>.spread.<field>` >
   `global.scheduling.spread.<field>` > built-in (`enabled: false`, `hostname: ""`,
   `zone: ""`, `maxSkew: 1`).
3. Nothing.

| Field | Values | Renders |
|-------|--------|---------|
| `enabled` | bool | master switch for the preset |
| `hostname` | `ScheduleAnyway` \| `DoNotSchedule` \| `""` (off) | constraint on `kubernetes.io/hostname` |
| `zone` | `ScheduleAnyway` \| `DoNotSchedule` \| `""` (off) | constraint on `topology.kubernetes.io/zone` |
| `maxSkew` | integer >= 1 (default 1) | `maxSkew` of every preset constraint |

Every preset constraint carries `labelSelector.matchLabels: <selectorLabels>` and
`matchLabelKeys: [pod-template-hash]`, so only pods of the same ReplicaSet are
counted and a rolling update never deadlocks on the old ReplicaSet's pods
(Kubernetes >= 1.27 with the `MatchLabelKeysInPodTopologySpread` feature gate
enabled: beta since 1.27 and on by default, including 1.33, but it can be disabled).
Invalid input fails the render with an explicit
`lerian-common.topologySpreadConstraints: ...` message (unknown field, non-bool
`enabled`, bad `whenUnsatisfiable`, `maxSkew` < 1 or non-integer, non-list raw
constraints, empty `selectorLabels`).

A library chart cannot ship defaults to its consumers: each consumer declares the
keys in its own `values.yaml` and `values.schema.json`. Recommended consumer
defaults (soft, so an upgrade never leaves pods `Pending`):

```yaml
global:
  scheduling:
    spread: { enabled: true, hostname: ScheduleAnyway, zone: ScheduleAnyway, maxSkew: 1 }
<component>:
  spread: {}
  topologySpreadConstraints: []
```

`global.scheduling` may hold other env-wide scheduling keys (e.g. `nodeSelector`,
`tolerations` in charts that support them); this helper reads only
`global.scheduling.spread`.

## Usage

```yaml
# consumer Chart.yaml
dependencies:
  - name: lerian-common
    version: "0.1.0"
    repository: "file://../lerian-common"
```

```yaml
# consumer template (example)
{{- with (include "lerian-common.serviceDiscovery.env" (dict
      "context" $ "enabled" true "name" (include "myapp.fullname" .)
      "port" .Values.app.service.port "namespace" (include "global.namespace" $))) }}
{{ . | nindent 2 }}
{{- end }}
```

## Chart Contract

- Chart type: `library`
- **Required secrets:** none — this is a library chart; it declares and manages no secrets.
- **Dependency notes:** no subchart dependencies of its own. Consumers reference it via
  `repository: "file://../lerian-common"` (monorepo) and vendor it at
  `helm dependency build`; packaged consumer charts embed it in their `.tgz`.
- **Production overrides:** set `global.serviceDiscovery`, `global.streaming` and
  `global.multiTenant` once per environment (umbrella/GitOps). Helpers stay inert until set.
- **Source/License:** https://github.com/LerianStudio/helm — © Lerian Studio.
