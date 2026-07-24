# lerian-common

Shared Helm **library chart** for the LerianStudio product charts. It renders
nothing on its own — it provides render-equivalent helpers (`define`s) consumed
via `include` by the product charts that declare it as a dependency.

## Helpers

- **Env contracts:** `lerian-common.serviceDiscovery.env`, `lerian-common.streaming.env`,
  `lerian-common.multiTenant.env` — env-wide constants come from `global.*`
  (set once per environment); the per-app enable knob stays in the component's
  `extraEnvVars`/`configmap`; a component value overrides the global default; and
  each helper stays **inert until `global.*` is set** (backward-compatible).
- **Env contracts (flat-passthrough):** `lerian-common.serviceDiscovery.envFlat`,
  `lerian-common.otel.envFlat`, `lerian-common.multiTenant.envFlat` — reproduce a
  chart's EXISTING native env block **byte-for-byte** (same keys, defaults, quoting
  and line order) with **no derivation** from `global.*`. The generic primitive
  behind them is `lerian-common.env.flatBlock` (ordered `KEY: value` emitter,
  `configmap.<KEY>` > `defaults.<KEY>` > `""`, presence-based). Each chart opts into
  its own SUBSET + ORDER via `keys` and its per-key defaults via `defaults`; adoption
  is a zero-diff refactor, before optionally migrating to the derivation helpers above.
  `serviceDiscovery.envFlat` additionally accepts OPTIONAL topology inputs
  (`serviceName`, `namespace`, `servicePort`, `ingressHost`) that DERIVE
  `SD_INTERNAL_ADDRESS` (`<serviceName>.<namespace>.svc.cluster.local`, only when both
  given), `SD_INTERNAL_PORT` (`servicePort | toString`) and `SD_EXTERNAL_ADDRESS`
  (`ingressHost`); each stays `""` when its inputs are absent. It also bakes the
  opinionated platform defaults `SD_PREFER_VIEW="internal"`, `SD_TLS_SKIP_VERIFY="true"`,
  `SD_EXTERNAL_PORT="443"`, `SD_INTERNAL_SCHEME="http"` unconditionally. All of these are
  lowest precedence — per key: `configmap.SD_<KEY>` (legacy) > `defaults.SD_<KEY>`
  (grouped param) > derived/opinionated default > `""`.
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
