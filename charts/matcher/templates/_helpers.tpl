{{/*
Expand the name of the chart.
*/}}
{{- define "matcher.name" -}}
{{- default (default "matcher" .Values.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name for matcher.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "matcher.fullname" -}}
{{- default (include "matcher.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "matcher.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create matcher app version
*/}}
{{- define "matcher.defaultTag" -}}
{{- default .Chart.AppVersion .Values.matcher.image.tag }}
{{- end -}}

{{/*
Return valid matcher version label
*/}}
{{- define "matcher.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "matcher.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "matcher.labels" -}}
helm.sh/chart: {{ include "matcher.chart" .context }}
{{ include "matcher.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "matcher.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "matcher.selectorLabels" -}}
app.kubernetes.io/name: {{ include "matcher.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "matcher.serviceAccountName" -}}
{{- if .Values.matcher.serviceAccount.create }}
{{- default (include "matcher.fullname" .) .Values.matcher.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.matcher.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Expand the namespace of the release.
Allows overriding it for multi-namespace deployments in combined charts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
infraSecretRef — emit a `- name: <envName> valueFrom: secretKeyRef: {name,key}` env entry
pointing at a Bitnami subchart's generated Secret (or the operator's existingSecret override).
Inputs (dict): context (root .), subchart, key, envName.
See docs/helm-chart-standard.md "Single-Source Infra Secrets".
*/}}
{{- define "matcher.infraSecretRef" -}}
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
Enable internal dependencies
*/}}
{{- define "rabbitmq.enabled" -}}
{{- if not .Values.rabbitmq.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{- define "valkey.enabled" -}}
{{- if not .Values.valkey.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{- define "postgresql.enabled" -}}
{{- if not .Values.postgresql.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
==============================================================================
Component helpers (multi-component: ui / mcp / migrations)
Names are derived from matcher.fullname so cross-references stay deterministic
and release-aware (e.g. the UI ingress routes /v1 to the API Service by name,
and the migration Job reads its PreSync Secret by name).
==============================================================================
*/}}

{{/* UI fullname (e.g. matcher-ui) */}}
{{- define "matcher-ui.fullname" -}}
{{- printf "%s-ui" (include "matcher.fullname" . | trunc 60 | trimSuffix "-") | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* UI selector labels */}}
{{- define "matcher-ui.selectorLabels" -}}
app.kubernetes.io/name: {{ include "matcher-ui.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: ui
{{- end -}}

{{/* UI labels */}}
{{- define "matcher-ui.labels" -}}
helm.sh/chart: {{ include "matcher.chart" . }}
{{ include "matcher-ui.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.ui.image.tag }}
app.kubernetes.io/version: {{ . | quote }}
{{- end }}
{{- end -}}

{{/* MCP fullname (e.g. matcher-mcp) */}}
{{- define "matcher-mcp.fullname" -}}
{{- printf "%s-mcp" (include "matcher.fullname" . | trunc 59 | trimSuffix "-") | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* MCP selector labels */}}
{{- define "matcher-mcp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "matcher-mcp.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: mcp
{{- end -}}

{{/* MCP labels */}}
{{- define "matcher-mcp.labels" -}}
helm.sh/chart: {{ include "matcher.chart" . }}
{{ include "matcher-mcp.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.mcp.image.tag }}
app.kubernetes.io/version: {{ . | quote }}
{{- end }}
{{- end -}}

{{/* Migrations fullname (e.g. matcher-migrations) — Job and PreSync Secret reference this */}}
{{- define "matcher-migrations.fullname" -}}
{{- printf "%s-migrations" (include "matcher.fullname" . | trunc 52 | trimSuffix "-") | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Migrations labels */}}
{{- define "matcher-migrations.labels" -}}
helm.sh/chart: {{ include "matcher.chart" . }}
app.kubernetes.io/name: {{ include "matcher-migrations.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: migrations
{{- end -}}

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
