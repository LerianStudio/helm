{{/*
Expand the name of the chart.
*/}}
{{- define "flowker.name" -}}
{{- default (default "flowker" .Values.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name for flowker.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "flowker.fullname" -}}
{{- default (include "flowker.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "flowker.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create flowker app version
*/}}
{{- define "flowker.defaultTag" -}}
{{- default .Chart.AppVersion .Values.flowker.image.tag }}
{{- end -}}

{{/*
Return valid flowker version label
*/}}
{{- define "flowker.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "flowker.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "flowker.labels" -}}
helm.sh/chart: {{ include "flowker.chart" .context }}
{{ include "flowker.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "flowker.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "flowker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "flowker.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "flowker.serviceAccountName" -}}
{{- if .Values.flowker.serviceAccount.create }}
{{- default (include "flowker.fullname" .) .Values.flowker.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.flowker.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Expand the namespace of the release.
Allows overriding it for multi-namespace deployments in combined charts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}
