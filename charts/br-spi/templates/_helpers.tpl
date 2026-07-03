{{/*
Expand the name of the chart.
*/}}
{{- define "br-spi.name" -}}
{{- default (default "br-spi" .Values.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Truncated at 63 chars because some Kubernetes name fields are limited by the DNS spec.
*/}}
{{- define "br-spi.fullname" -}}
{{- default (include "br-spi.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "br-spi.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the namespace of the release. Overridable for multi-namespace layouts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Name of the service account to use (single, shared across all components).
*/}}
{{- define "br-spi.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "br-spi.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
==============================================================================
Component helpers (multi-component: core / spi / brcode / dict).
Names derive from br-spi.fullname so cross-references stay deterministic and
release-aware (e.g. the migration Job and MCP-style refs resolve by name).
Inputs (dict): context (root .), component ("core"|"spi"|"brcode"|"dict").
==============================================================================
*/}}

{{/* Component fullname, e.g. br-spi-core */}}
{{- define "br-spi.componentFullname" -}}
{{- $base := include "br-spi.fullname" .context | trunc 57 | trimSuffix "-" -}}
{{- printf "%s-%s" $base .component | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Component version label — the component's image tag, falling back to AppVersion */}}
{{- define "br-spi.componentVersion" -}}
{{- $cv := index .context.Values .component -}}
{{- default .context.Chart.AppVersion $cv.image.tag -}}
{{- end -}}

{{/* Component selector labels (stable across image bumps) */}}
{{- define "br-spi.componentSelectorLabels" -}}
app.kubernetes.io/name: {{ include "br-spi.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/* Component labels */}}
{{- define "br-spi.componentLabels" -}}
helm.sh/chart: {{ include "br-spi.chart" .context }}
{{ include "br-spi.componentSelectorLabels" (dict "context" .context "component" .component) }}
app.kubernetes.io/version: {{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "br-spi.componentVersion" .) "-" | trunc 63 | trimAll "-" | quote }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end -}}

{{/* Migrations fullname, e.g. br-spi-migrations — Job and PreSync Secret reference this */}}
{{- define "br-spi-migrations.fullname" -}}
{{- printf "%s-migrations" (include "br-spi.fullname" . | trunc 52 | trimSuffix "-") | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Migrations labels */}}
{{- define "br-spi-migrations.labels" -}}
helm.sh/chart: {{ include "br-spi.chart" . }}
app.kubernetes.io/name: {{ include "br-spi-migrations.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: migrations
{{- end -}}

{{/*
infraSecretRef — emit a `- name: <envName> valueFrom: secretKeyRef: {name,key}`
env entry pointing at a Bitnami subchart's generated Secret (or the operator's
existingSecret override). Only used on the bundled-subchart path; the external
path reads the app's own Secret. See docs/helm-chart-standard.md
"Single-Source Infra Secrets".
Inputs (dict): context (root .), subchart, key, envName.
*/}}
{{- define "br-spi.infraSecretRef" -}}
{{- $ctx := .context -}}
{{- $sub := .subchart -}}
{{- $auth := default dict (index $ctx.Values $sub "auth") -}}
{{- $secretName := "" -}}
{{- if $auth.existingSecret -}}
{{- $secretName = $auth.existingSecret -}}
{{- else -}}
{{- $secretName = include "common.names.dependency.fullname" (dict "chartName" $sub "chartValues" (index $ctx.Values $sub) "context" $ctx) -}}
{{- end -}}
- name: {{ .envName }}
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: {{ .key }}
{{- end }}

{{/*
Vendored from Bitnami common (charts/common/templates/_names.tpl) so infra
Secret/Service names render even when all bundled subcharts are disabled
(external-infra path). Self-contained: no other common.* helpers required.
*/}}
{{- define "common.names.dependency.fullname" -}}
{{- if .chartValues.fullnameOverride -}}
{{- .chartValues.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .chartName .chartValues.nameOverride -}}
{{- if contains $name .context.Release.Name -}}
{{- .context.Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .context.Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}
