{{/*
Expand the name of the chart and plugin crm.
*/}}
{{- define "plugin-crm.name" -}}
{{- default (default .Values.crm.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart and plugin crm frontend.
*/}}
{{- define "plugin-frontend.name" -}}
{{- default (default .Values.frontend.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart and plugin crm.
*/}}
{{- define "plugin-crm-backend.name" -}}
{{- default (default .Values.crm.backend.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin crm.
*/}}
{{- define "plugin-crm.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin crm.
*/}}
{{- define "plugin-crm-backend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin crm.
*/}}
{{- define "plugin-frontend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name crm.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-crm.fullname" -}}
{{- default .Values.crm.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name crm.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-crm-backend.fullname" -}}
{{- default (default .Values.crm.backend.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name frontend.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-frontend.fullname" -}}
{{- default (default .Values.frontend.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create app version.
*/}}
{{- define "plugin.version" -}}
{{- printf "%s" .Chart.AppVersion | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
crm Selector labels
*/}}
{{- define "plugin-crm.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-crm.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
crm Selector labels
*/}}
{{- define "plugin-crm-backend.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-crm-backend.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
crm Selector labels
*/}}
{{- define "plugin-frontend.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-frontend.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}


{{/*
crm Common labels
*/}}
{{- define "plugin-crm.labels" -}}
helm.sh/chart: {{ include "plugin-crm.chart" .context }}
{{ include "plugin-crm.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
crm Backend Common labels
*/}}
{{- define "plugin-crm-backend.labels" -}}
helm.sh/chart: {{ include "plugin-crm-backend.chart" .context }}
{{ include "plugin-crm-backend.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
crm Frontend Common labels
*/}}
{{- define "plugin-frontend.labels" -}}
helm.sh/chart: {{ include "plugin-frontend.chart" .context }}
{{ include "plugin-frontend.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
crm dataSourceName
*/}}
{{- define "plugin-crm-backend.dataSourceName" -}}
"user={{ .Values.crm.configmap.DB_USER }} password={{ .Values.crm.secrets.DB_PASSWORD }} host={{ .Values.crm.configmap.DB_HOST }} port={{ .Values.crm.configmap.DB_PORT }} sslmode=disable dbname={{ .Values.crm.configmap.DB_NAME }}"
{{- end }}

{{/*
Create the name of the crm service account to use
*/}}
{{- define "plugin-crm.serviceAccountName" -}}
{{- if .Values.crm.serviceAccount.create }}
{{- default (include "plugin-crm.fullname" .) .Values.crm.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.crm.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Expand the namespace of the release.
Allows overriding it for multi-namespace deployments in combined charts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.crm.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}


{{/*
Enable dependencies
*/}}
{{- define "mongodb.enabled" -}}
{{- if not .Values.crm.mongodob.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}