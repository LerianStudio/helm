# lerian-common

Shared Helm **library chart** for the LerianStudio product charts. It renders
nothing on its own — it provides render-equivalent helpers (`define`s) consumed
via `include` by the product charts that declare it as a dependency.

## Helpers

- **Env contracts:** `lerian-common.serviceDiscovery.env`, `lerian-common.streaming.env`,
  `lerian-common.multiTenant.env` — env-wide constants come from `global.*`
  (set once per environment); the per-app enable knob stays in the component's
  `extraEnvVars`/`configmap`; a component value overrides the global default; and
  each helper stays **inert until `global.*` is set** (backward-compatible);
  `serviceDiscovery.env` additionally activates from a legacy `configmap.SD_ADDRESS`,
  and a component `configmap.SD_*` value takes precedence over the `global.*` default.
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
- **Deployment pod-spec fragments:** `lerian-common.scheduling`, `.imagePullSecrets`,
  `.httpProbe`, `.rolesAnywhere.{sidecar,volume,imdsEnv,podSecurityContext}`.
- **Dependency helpers:** `lerian-common.dependency.fullname`, `.infraSecretRef`.
- **`lerian-common.deploymentStrategy`.**

See `values.yaml` for the standard `global.{serviceDiscovery,streaming,multiTenant}` template.

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
