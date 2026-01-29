{{/*
Expand the name of the chart.
*/}}
{{- define "fetcher.name" -}}
{{- default (default "fetcher" .Values.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "fetcher.fullname" -}}
{{- default (include "fetcher.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "fetcher.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "fetcher.labels" -}}
helm.sh/chart: {{ include "fetcher.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Manager fullname
*/}}
{{- define "fetcher-manager.fullname" -}}
{{- printf "%s" .Values.manager.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Manager labels
*/}}
{{- define "fetcher-manager.labels" -}}
{{ include "fetcher.labels" . }}
app.kubernetes.io/name: {{ include "fetcher-manager.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: manager
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end }}

{{/*
Manager selector labels
*/}}
{{- define "fetcher-manager.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fetcher-manager.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Worker fullname
*/}}
{{- define "fetcher-worker.fullname" -}}
{{- printf "%s" .Values.worker.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Worker labels
*/}}
{{- define "fetcher-worker.labels" -}}
{{ include "fetcher.labels" . }}
app.kubernetes.io/name: {{ include "fetcher-worker.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: worker
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end }}

{{/*
Worker selector labels
*/}}
{{- define "fetcher-worker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fetcher-worker.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use for manager
*/}}
{{- define "fetcher-manager.serviceAccountName" -}}
{{- if .Values.manager.serviceAccount.create }}
{{- default (include "fetcher-manager.fullname" .) .Values.manager.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.manager.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Expand the namespace of the release.
*/}}
{{- define "fetcher.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}
