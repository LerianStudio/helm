{{/*
Expand the name of the chart.
*/}}
{{- define "plugin-br-pix-switch.name" -}}
{{- default "plugin-br-pix-switch" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "plugin-br-pix-switch.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Per-component fully-qualified name.
Usage: include "plugin-br-pix-switch.componentFullname" (dict "context" $ "component" "spi")
Returns: <chartname>-<component-name>  (e.g. plugin-br-pix-switch-spi)
*/}}
{{- define "plugin-br-pix-switch.componentFullname" -}}
{{- $base := include "plugin-br-pix-switch.name" .context -}}
{{- printf "%s-%s" $base .component | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Resolve image repository for a component, falling back to the global default.
Usage: include "plugin-br-pix-switch.componentImage" (dict "context" $ "componentValues" .Values.spi)
*/}}
{{- define "plugin-br-pix-switch.componentImage" -}}
{{- $repo := default .context.Values.global.image.repository .componentValues.image.repository -}}
{{- $tag := default .context.Chart.AppVersion .componentValues.image.tag -}}
{{- printf "%s:%s" $repo $tag -}}
{{- end }}

{{/*
Resolve image pullPolicy for a component, falling back to the global default.
*/}}
{{- define "plugin-br-pix-switch.componentPullPolicy" -}}
{{- default .context.Values.global.image.pullPolicy .componentValues.image.pullPolicy -}}
{{- end }}

{{/*
Resolve imagePullSecrets for a component, falling back to global.
Returns YAML list (use with `toYaml | nindent`).
Usage: (include "plugin-br-pix-switch.componentImagePullSecrets" (dict "context" $ "componentValues" .Values.spi)) | nindent 8
*/}}
{{- define "plugin-br-pix-switch.componentImagePullSecrets" -}}
{{- $secrets := .componentValues.imagePullSecrets -}}
{{- if not $secrets -}}
{{- $secrets = .context.Values.global.imagePullSecrets -}}
{{- end -}}
{{- toYaml $secrets -}}
{{- end }}

{{/*
Common labels applied to every resource.
Usage: include "plugin-br-pix-switch.labels" (dict "context" $ "component" "spi")
*/}}
{{- define "plugin-br-pix-switch.labels" -}}
helm.sh/chart: {{ include "plugin-br-pix-switch.chart" .context }}
{{ include "plugin-br-pix-switch.selectorLabels" (dict "context" .context "component" .component) }}
app.kubernetes.io/version: {{ .context.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
app.kubernetes.io/part-of: {{ include "plugin-br-pix-switch.name" .context }}
{{- end }}

{{/*
Selector labels (immutable subset for matchLabels).
Usage: include "plugin-br-pix-switch.selectorLabels" (dict "context" $ "component" "spi")
*/}}
{{- define "plugin-br-pix-switch.selectorLabels" -}}
app.kubernetes.io/name: {{ include "plugin-br-pix-switch.componentFullname" (dict "context" .context "component" .component) }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Per-component service account name.
Usage: include "plugin-br-pix-switch.componentServiceAccountName" (dict "context" $ "component" "spi" "componentValues" .Values.spi)
*/}}
{{- define "plugin-br-pix-switch.componentServiceAccountName" -}}
{{- if .componentValues.serviceAccount.create -}}
{{- default (include "plugin-br-pix-switch.componentFullname" (dict "context" .context "component" .component)) .componentValues.serviceAccount.name -}}
{{- else -}}
{{- default "default" .componentValues.serviceAccount.name -}}
{{- end -}}
{{- end }}

{{/*
Resolve the secret name to use for envFrom.
When useExistingSecret=true, returns the externally-managed name; otherwise the chart-rendered one.
*/}}
{{- define "plugin-br-pix-switch.componentSecretName" -}}
{{- if .componentValues.useExistingSecret -}}
{{- .componentValues.existingSecretName -}}
{{- else -}}
{{- include "plugin-br-pix-switch.componentFullname" (dict "context" .context "component" .component) -}}
{{- end -}}
{{- end }}
