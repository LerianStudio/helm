<!-- {% raw %} -->
# Helm Upgrade from v2.3.0 to v2.4.0

## Topics ToC

- **[Features](#features)**
  - [1. Access Manager Permission Declaration (IDP)](#1-access-manager-permission-declaration-idp)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Access Manager Permission Declaration (IDP)

The `lerian-common` chart v2.4.0 introduces three new helpers for **Access Manager permission declaration** (IDP_*). These helpers emit environment variables and secrets that the **lib-auth** library's `declaration.WireFromEnv` function reads to publish a component's permission manifest to the Access Manager at boot.

**What changed:**

Three new template helpers have been added:

- `lerian-common.idp.env` — emits ConfigMap keys (`IDP_DECLARATION_ENABLED`, `IDP_HOST`)
- `lerian-common.idp.secret` — emits Secret keys (`IDP_M2M_CLIENT_ID`, `IDP_M2M_CLIENT_SECRET`)
- `lerian-common.idp.keys` — returns a JSON list of keys owned by the IDP helpers (for use in generic ranges to avoid duplicate key emission)

**Why it matters:**

When `IDP_DECLARATION_ENABLED` is set to `"true"`, the application refuses to boot without the Access Manager host and a valid M2M client pair. This ensures that components with permission manifests are properly registered with the Access Manager before serving traffic.

**Environment variables emitted:**

| Variable | Source | Default | Description |
|----------|--------|---------|-------------|
| `IDP_DECLARATION_ENABLED` | ConfigMap | `false` | Gate for permission declaration (always emitted) |
| `IDP_HOST` | ConfigMap | `""` | Access Manager identity base URL (emitted only when non-empty) |
| `IDP_M2M_CLIENT_ID` | Secret | `""` | M2M client ID for publishing permissions (emitted only when non-empty) |
| `IDP_M2M_CLIENT_SECRET` | Secret | `""` | M2M client secret (emitted only when non-empty) |

**Configuration block (umbrella `values.yaml`):**

```yaml
global:
  idp:
    host: "http://plugin-access-manager-identity.prod.svc.cluster.local:4001"
    declarationEnabled: false  # Prefer per-component override — see warning below
```

> **Warning:** Setting `global.idp.declarationEnabled: true` turns the gate on for **EVERY** component in the release. Each component then requires its own M2M client pair (set under the component's `.secrets`), or it will refuse to boot. Prefer setting `IDP_DECLARATION_ENABLED` per component via `configmap.IDP_DECLARATION_ENABLED`.

**Precedence:**

Component-level `configmap.<KEY>` > `extraEnvVars.<KEY>` (legacy) > `global.idp.<field>` > helper default

**Usage in product charts (ConfigMap):**

Product chart maintainers include the `lerian-common.idp.env` helper in their ConfigMap template:

```yaml
# templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "myapp.fullname" . }}
data:
  {{- include "lerian-common.idp.env" (dict
        "context" $ "configmap" .Values.myapp.configmap
        "extraEnvVars" .Values.myapp.extraEnvVars) | nindent 2 }}
  # Other config keys...
```

**Usage in product charts (Secret):**

Product chart maintainers include the `lerian-common.idp.secret` helper in their Secret template:

```yaml
# templates/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "myapp.fullname" . }}
type: Opaque
{{- $idpSecret := include "lerian-common.idp.secret" (dict
      "secrets" .Values.myapp.secrets "mode" "data"
      "useExistingSecret" .Values.myapp.useExistingSecret) }}
{{- if $idpSecret }}
data:
  {{- $idpSecret | nindent 2 }}
  # Other secret keys...
{{- end }}
```

**Usage in product charts (avoiding duplicate keys):**

When a product chart has a generic range over `configmap` or `extraEnvVars`, use `lerian-common.idp.keys` to skip IDP keys (duplicate keys are rejected server-side):

```yaml
# templates/configmap.yaml
data:
  {{- include "lerian-common.idp.env" (dict
        "context" $ "configmap" .Values.myapp.configmap
        "extraEnvVars" .Values.myapp.extraEnvVars) | nindent 2 }}
  {{- $idpEnvKeys := include "lerian-common.idp.keys" (dict "kind" "env") | fromJsonArray }}
  {{- range $k, $v := .Values.myapp.configmap }}
  {{- if not (has $k $idpEnvKeys) }}
  {{ $k }}: {{ $v | quote }}
  {{- end }}
  {{- end }}
```

**Backward compatibility:**

The helpers support a **legacy `extraEnvVars` input** for components that set `IDP_DECLARATION_ENABLED` or `IDP_HOST` via `extraEnvVars` before this helper existed. If a key is present in both `extraEnvVars` and `configmap`, the `configmap` value wins.

**Example: Enabling permission declaration for a component**

**Before (v2.3.0):**

Operators set IDP variables manually in the component's `configmap` or `extraEnvVars`:

```yaml
# values.yaml
myapp:
  configmap:
    IDP_DECLARATION_ENABLED: "true"
    IDP_HOST: "http://plugin-access-manager-identity.prod.svc.cluster.local:4001"
  secrets:
    IDP_M2M_CLIENT_ID: "myapp-client-id"
    IDP_M2M_CLIENT_SECRET: "myapp-client-secret"
```

**After (v2.4.0):**

Operators can declare the host once at the umbrella level and enable the gate per component:

```yaml
# umbrella values.yaml
global:
  idp:
    host: "http://plugin-access-manager-identity.prod.svc.cluster.local:4001"

myapp:
  configmap:
    IDP_DECLARATION_ENABLED: "true"
  secrets:
    IDP_M2M_CLIENT_ID: "myapp-client-id"
    IDP_M2M_CLIENT_SECRET: "myapp-client-secret"
```

> **Note:** The M2M client credentials (`IDP_M2M_CLIENT_ID`, `IDP_M2M_CLIENT_SECRET`) are **per-component secrets** and must never be set in `global.idp`. Each component that enables permission declaration requires its own client pair.

## Configuration Reference

The following `global.idp` block has been added to the shared contract in v2.4.0:

```yaml
global:
  idp:
    host: ""                 # IDP_HOST — Access Manager identity URL (e.g. http://plugin-access-manager-identity.<ns>.svc.cluster.local:4001)
    declarationEnabled: false # IDP_DECLARATION_ENABLED — Turns the gate on for EVERY component (prefer per-component override)
```

**Configuration flags:**

| Block | Field | Default | Description |
|-------|-------|---------|-------------|
| `global.idp` | `host` | `""` | Access Manager identity base URL (emitted only when non-empty) |
| `global.idp` | `declarationEnabled` | `false` | Enable permission declaration for all components (prefer per-component `configmap.IDP_DECLARATION_ENABLED`) |

**Per-component configuration:**

| Block | Field | Default | Description |
|-------|-------|---------|-------------|
| `<component>.configmap` | `IDP_DECLARATION_ENABLED` | `false` | Enable permission declaration for this component |
| `<component>.configmap` | `IDP_HOST` | `""` | Override Access Manager host for this component |
| `<component>.secrets` | `IDP_M2M_CLIENT_ID` | `""` | M2M client ID for this component |
| `<component>.secrets` | `IDP_M2M_CLIENT_SECRET` | `""` | M2M client secret for this component |

## Migration Steps

### For Operators (Umbrella Deployments)

If you manage Lerian product charts via an umbrella chart and want to adopt the shared `global.idp` contract:

1. **Declare the `global.idp.host`** in your umbrella `values.yaml`:

```yaml
global:
  idp:
    host: "http://plugin-access-manager-identity.prod.svc.cluster.local:4001"
```

2. **Enable permission declaration per component** by setting `IDP_DECLARATION_ENABLED` in the component's `configmap`:

```yaml
myapp:
  configmap:
    IDP_DECLARATION_ENABLED: "true"
  secrets:
    IDP_M2M_CLIENT_ID: "myapp-client-id"
    IDP_M2M_CLIENT_SECRET: "myapp-client-secret"
```

3. **Ensure product charts consume the helpers.** If you are using product charts that have already adopted `lerian-common` v2.4.0, no further action is required. If not, coordinate with chart maintainers to refactor product charts.

4. **Upgrade the umbrella chart:**

```bash
helm upgrade my-umbrella . -n lerian --values values.yaml
```

### For Chart Maintainers (Product Charts)

If you maintain a Lerian product chart and want to refactor it to consume the new IDP helpers:

1. **Update the `lerian-common` dependency** in your product chart's `Chart.yaml`:

```yaml
dependencies:
  - name: lerian-common
    version: 2.4.0
    repository: oci://registry-1.docker.io/lerianstudio
```

2. **Update dependencies:**

```bash
helm dependency update
```

3. **Refactor the ConfigMap template** to use `lerian-common.idp.env`:

**Before (v2.3.0):**

```yaml
# templates/configmap.yaml
data:
  {{- range $k, $v := .Values.myapp.configmap }}
  {{ $k }}: {{ $v | quote }}
  {{- end }}
```

**After (v2.4.0):**

```yaml
# templates/configmap.yaml
data:
  {{- include "lerian-common.idp.env" (dict
        "context" $ "configmap" .Values.myapp.configmap
        "extraEnvVars" .Values.myapp.extraEnvVars) | nindent 2 }}
  {{- $idpEnvKeys := include "lerian-common.idp.keys" (dict "kind" "env") | fromJsonArray }}
  {{- range $k, $v := .Values.myapp.configmap }}
  {{- if not (has $k $idpEnvKeys) }}
  {{ $k }}: {{ $v | quote }}
  {{- end }}
  {{- end }}
```

4. **Refactor the Secret template** to use `lerian-common.idp.secret`:

**Before (v2.3.0):**

```yaml
# templates/secret.yaml
{{- if not .Values.myapp.useExistingSecret }}
data:
  {{- range $k, $v := .Values.myapp.secrets }}
  {{ $k }}: {{ $v | b64enc | quote }}
  {{- end }}
{{- end }}
```

**After (v2.4.0):**

```yaml
# templates/secret.yaml
{{- if not .Values.myapp.useExistingSecret }}
{{- $idpSecret := include "lerian-common.idp.secret" (dict
      "secrets" .Values.myapp.secrets "mode" "data"
      "useExistingSecret" .Values.myapp.useExistingSecret) }}
{{- if $idpSecret }}
data:
  {{- $idpSecret | nindent 2 }}
  {{- $idpSecretKeys := include "lerian-common.idp.keys" (dict "kind" "secret") | fromJsonArray }}
  {{- range $k, $v := .Values.myapp.secrets }}
  {{- if not (has $k $idpSecretKeys) }}
  {{ $k }}: {{ $v | b64enc | quote }}
  {{- end }}
  {{- end }}
{{- end }}
{{- end }}
```

5. **Test render equivalence** (ensure output is byte-identical for existing users):

```bash
helm template my-chart . --values test-values.yaml > before.yaml
# (after refactor)
helm template my-chart . --values test-values.yaml > after.yaml
diff before.yaml after.yaml
```

### For Standalone Deployments

If you deploy a single product chart without an umbrella:

**No action required.** The `lerian-common.idp.*` helpers are backward-compatible: with `global.idp` absent, they fall back to existing component values, producing identical output.

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.4.0 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Important:** Since `lerian-common` is a library chart, `helm diff` will show no resource changes (library charts render nothing). To preview the impact of adopting `lerian-common` v2.4.0, run `helm diff` on the **product charts** that consume it.

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.4.0 -n lerian-common
```

> **Note:** Since `lerian-common` is a library chart, you typically do **not** install or upgrade it directly. Instead, update the dependency version in your umbrella or product chart's `Chart.yaml` to `2.4.0` and run `helm dependency update`.
<!-- {% endraw %} -->
