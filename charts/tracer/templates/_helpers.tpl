{{/*
Expand the name of the chart.
*/}}
{{- define "tracer.name" -}}
{{- default (default "tracer" .Values.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name for tracer.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "tracer.fullname" -}}
{{- default (include "tracer.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tracer.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create tracer app version
*/}}
{{- define "tracer.defaultTag" -}}
{{- default .Chart.AppVersion .Values.tracer.image.tag }}
{{- end -}}

{{/*
Return valid tracer version label
*/}}
{{- define "tracer.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "tracer.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "tracer.labels" -}}
helm.sh/chart: {{ include "tracer.chart" .context }}
{{ include "tracer.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "tracer.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tracer.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tracer.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "tracer.serviceAccountName" -}}
{{- if .Values.tracer.serviceAccount.create }}
{{- default (include "tracer.fullname" .) .Values.tracer.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.tracer.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Expand the namespace of the release.
Allows overriding it for multi-namespace deployments in combined charts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}
