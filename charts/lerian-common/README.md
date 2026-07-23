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
