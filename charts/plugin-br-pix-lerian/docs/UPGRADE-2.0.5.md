<!-- {% raw %} -->
# Helm Upgrade from v2.0.4 to v2.0.5

## Topics

- **[Fixes](#fixes)**
  - [1. Pod Label Separation for Stable Checksums](#1-pod-label-separation-for-stable-checksums)
  - [2. Checksum Annotations Now Hash Only Data](#2-checksum-annotations-now-hash-only-data)
  - [3. Adapter Provider Mock Default URL Removed](#3-adapter-provider-mock-default-url-removed)
  - [4. RabbitMQ Comment Cleanup](#4-rabbitmq-comment-cleanup)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Pod Label Separation for Stable Checksums

**What changed:**

The chart now separates pod labels from Deployment/Service labels. A new `plugin-br-pix-lerian.podLabels` helper template has been introduced that excludes the `helm.sh/chart` label from pod templates. All Deployment `spec.template.metadata.labels` blocks now call `podLabels` instead of `labels`.

**Why it matters:**

Previously, the `helm.sh/chart` label (which includes the chart version) was applied to pod templates. This caused pods to be recreated on every chart version bump, even when no application configuration changed. By excluding `helm.sh/chart` from pod labels, pods are now rolled **only when ConfigMap or Secret data changes**, not when the chart version increments.

**How to handle it:**

No action is required. This is a transparent optimization that reduces unnecessary pod restarts during patch upgrades.

**Before (v2.0.4) _helpers.tpl:**

```yaml
{{- define "plugin-br-pix-lerian.labels" -}}
helm.sh/chart: {{ include "plugin-br-pix-lerian.chart" .context }}
{{ include "plugin-br-pix-lerian.selectorLabels" (dict "context" .context "component" .component) }}
app.kubernetes.io/version: {{ .context.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}
```

**After (v2.0.5) _helpers.tpl:**

```yaml
{{- define "plugin-br-pix-lerian.labels" -}}
helm.sh/chart: {{ include "plugin-br-pix-lerian.chart" .context }}
{{ include "plugin-br-pix-lerian.podLabels" (dict "context" .context "component" .component) }}
{{- end }}

{{/*
Labels for pod templates: common labels without helm.sh/chart. The checksum
annotations hash only the data, so a chart version bump alone does not roll pods.
*/}}
{{- define "plugin-br-pix-lerian.podLabels" -}}
{{ include "plugin-br-pix-lerian.selectorLabels" (dict "context" .context "component" .component) }}
app.kubernetes.io/version: {{ .context.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}
```

**Before (v2.0.4) deployment.yaml:**

```yaml
labels:
  {{- include "plugin-br-pix-lerian.labels" (dict "context" $ "component" $component) | nindent 8 }}
```

**After (v2.0.5) deployment.yaml:**

```yaml
labels:
  {{- include "plugin-br-pix-lerian.podLabels" (dict "context" $ "component" $component) | nindent 8 }}
```

**Affected components:**

All Deployment resources:
- `adapter-lerian`
- `adapter-lerian-systemplane`
- `adapter-provider-mock`
- `cob-hub`
- `cob-proxy`
- `cob-systemplane`
- `dict-hub`
- `dict-hub-vsync`
- `dict-proxy`
- `dict-systemplane`
- `pixauto`
- `pixauto-systemplane`
- `spi`
- `spi-systemplane`

### 2. Checksum Annotations Now Hash Only Data

**What changed:**

The `checksum/configmap` and `checksum/secret` annotations in pod templates now hash **only the data/stringData fields** of the ConfigMap and Secret, instead of hashing the entire rendered YAML (including metadata, labels, and annotations).

| Annotation | v2.0.4 | v2.0.5 |
|------------|--------|--------|
| `checksum/configmap` | Hash of entire ConfigMap YAML | Hash of `.data` field only |
| `checksum/secret` | Hash of entire Secret YAML | Hash of `.stringData` field only |

**Why it matters:**

Previously, any change to ConfigMap or Secret metadata (labels, annotations, or the `helm.sh/chart` label) would change the checksum and trigger a pod rollout, even if the actual configuration data was unchanged. Now, pods are rolled **only when the configuration data itself changes**.

Combined with the pod label separation (Fix #1), this ensures that:
- A chart version bump alone does **not** roll pods
- Pods are rolled **only** when ConfigMap data or Secret stringData changes

**How to handle it:**

No action is required. This is a transparent optimization that reduces unnecessary pod restarts.

**Before (v2.0.4) _helpers.tpl:**

```yaml
annotations:
  checksum/configmap: {{ include (print $ctx.Template.BasePath "/" $component "/configmap.yaml") $ctx | sha256sum }}
  {{- if not $extern }}
  checksum/secret: {{ include (print $ctx.Template.BasePath "/" $component "/secrets.yaml") $ctx | sha256sum }}
  {{- end }}
```

**After (v2.0.5) _helpers.tpl:**

```yaml
annotations:
  checksum/configmap: {{ (include (print $ctx.Template.BasePath "/" $component "/configmap.yaml") $ctx | fromYaml).data | toYaml | sha256sum }}
  {{- if not $extern }}
  checksum/secret: {{ (include (print $ctx.Template.BasePath "/" $component "/secrets.yaml") $ctx | fromYaml).stringData | toYaml | sha256sum }}
  {{- end }}
```

**Affected components:**

All components that use the `plugin-br-pix-lerian.podMetadata` helper:
- `adapter-lerian`
- `adapter-lerian-systemplane`
- `adapter-provider-mock`
- `cob-hub`
- `cob-proxy`
- `cob-systemplane`
- `dict-hub`
- `dict-hub-vsync`
- `dict-proxy`
- `dict-systemplane`
- `pixauto`
- `pixauto-systemplane`
- `spi`
- `spi-systemplane`

### 3. Adapter Provider Mock Default URL Removed

**What changed:**

The `PROVIDER_BASE_URL` ConfigMap key for the `adapter-provider-mock` component no longer defaults to the Lerian sandbox mock server (`https://mock-pix-lerian-server.sandbox.lerian.net`). The default is now an empty string.

| Setting | v2.0.4 | v2.0.5 |
|---------|--------|--------|
| `adapterProviderMock.configmap.PROVIDER_BASE_URL` | `"https://mock-pix-lerian-server.sandbox.lerian.net"` | `""` |

**Why it matters:**

The `adapterProviderMock` component ships disabled by default (`enabled: false`), so this change affects only installations that explicitly enable it. Previously, enabling the component without setting `PROVIDER_BASE_URL` would point it to the Lerian sandbox mock server. Now, **you must explicitly provide the mock server URL** when enabling the component, or the adapter will fail to boot.

**How to handle it:**

#### If adapterProviderMock is disabled (default)

No action is required. The component remains disabled, and the `PROVIDER_BASE_URL` value is not used.

#### If adapterProviderMock is enabled

You must now explicitly set `PROVIDER_BASE_URL` to point to your mock provider server:

```yaml
adapterProviderMock:
  enabled: true
  configmap:
    PROVIDER_BASE_URL: "https://your-mock-server.example.com"
```

> **Important:** The Lerian sandbox mock server is no longer the default. If you were relying on the implicit default, you must now set `PROVIDER_BASE_URL` explicitly before upgrading.

**Before (v2.0.4) configmap.yaml:**

```yaml
# -- Lerian sandbox mock server this component talks to. Safe as a
# default: adapterProviderMock ships disabled, so this reaches no
# installation that does not enable the component explicitly, and an
# operator who does enable it gets the right endpoint instead of having
# to ask for it. Point it elsewhere only to target your own mock server.
PROVIDER_BASE_URL: {{ $cm.PROVIDER_BASE_URL | default "https://mock-pix-lerian-server.sandbox.lerian.net" | quote }}
```

**After (v2.0.5) configmap.yaml:**

```yaml
# -- Required when adapterProviderMock is enabled: base URL of your mock provider server.
PROVIDER_BASE_URL: {{ $cm.PROVIDER_BASE_URL | default "" | quote }}
```

### 4. RabbitMQ Comment Cleanup

**What changed:**

The comment block for the `rabbitmq` subchart in `values.yaml` has been simplified. The reference to "anacleto chaos/fuzzing overlays" has been removed.

**Why it matters:**

This is a documentation-only change. The `rabbitmq` subchart remains disabled by default (`enabled: false`), and the operational behavior is unchanged. The comment now focuses solely on the technical reason for disabling the subchart (self-signed cert rejection by lib-commons).

**How to handle it:**

No action is required. This is a cosmetic change to the values file comments.

**Before (v2.0.4) values.yaml:**

```yaml
# Used only by dict-hub-vsync for RABBITMQ_URI.
# Chosen path: EXTERNAL broker with a CA-signed TLS cert (trusted by the system
# trust store) on amqps://:5671. The in-cluster subchart would present a
# self-signed cert that lib-commons rejects, so it stays disabled — the anacleto
# chaos/fuzzing overlays also migrate off the embedded broker to external.
rabbitmq:
  enabled: false
```

**After (v2.0.5) values.yaml:**

```yaml
# Used only by dict-hub-vsync for RABBITMQ_URI.
# Chosen path: EXTERNAL broker with a CA-signed TLS cert (trusted by the system
# trust store) on amqps://:5671. The in-cluster subchart would present a
# self-signed cert that lib-commons rejects, so it stays disabled.
rabbitmq:
  enabled: false
```

## Preview changes before upgrading

```bash
helm diff upgrade <release-name> oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm --namespace <namespace> --version 2.0.5
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade <release-name> oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm --namespace <namespace> --version 2.0.5
```
<!-- {% endraw %} -->
