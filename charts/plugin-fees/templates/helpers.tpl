{{/*
Expand the name of the chart and plugin fees.
*/}}
{{- define "plugin-fees.name" -}}
{{- default (default .Values.fees.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart and plugin fees frontend.
*/}}
{{- define "plugin-frontend.name" -}}
{{- default (default .Values.frontend.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart and plugin fees.
*/}}
{{- define "plugin-fees-backend.name" -}}
{{- default (default .Values.fees.backend.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin fees.
*/}}
{{- define "plugin-fees.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin fees.
*/}}
{{- define "plugin-fees-backend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin fees.
*/}}
{{- define "plugin-frontend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name fees.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-fees.fullname" -}}
{{- default (default .Values.fees.name) | trunc 63 | trimSuffix "-" }}
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
Create a default fully qualified app name fees.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-fees-backend.fullname" -}}
{{- default (default .Values.fees.backend.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create app version.
*/}}
{{- define "plugin.version" -}}
{{- printf "%s" .Chart.AppVersion | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
fees Selector labels
*/}}
{{- define "plugin-fees.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-fees.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
fees Selector labels
*/}}
{{- define "plugin-fees-backend.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-fees-backend.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
frontend Selector labels
*/}}
{{- define "plugin-frontend.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-frontend.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}


{{/*
fees Common labels
*/}}
{{- define "plugin-fees.labels" -}}
helm.sh/chart: {{ include "plugin-fees.chart" .context }}
{{ include "plugin-fees.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
fees Backend Common labels
*/}}
{{- define "plugin-fees-backend.labels" -}}
helm.sh/chart: {{ include "plugin-fees-backend.chart" .context }}
{{ include "plugin-fees-backend.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
frontend Common labels
*/}}
{{- define "plugin-frontend.labels" -}}
helm.sh/chart: {{ include "plugin-frontend.chart" .context }}
{{ include "plugin-frontend.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
fees dataSourceName
*/}}
{{- define "plugin-fees-backend.dataSourceName" -}}
"user={{ .Values.fees.configmap.DB_USER }} password={{ .Values.fees.secrets.DB_PASSWORD }} host={{ .Values.fees.configmap.DB_HOST }} port={{ .Values.fees.configmap.DB_PORT }} sslmode=disable dbname={{ .Values.fees.configmap.DB_NAME }}"
{{- end }}

{{/*
Create the name of the fees service account to use
*/}}
{{- define "plugin-fees.serviceAccountName" -}}
{{- if .Values.fees.serviceAccount.create }}
{{- default (include "plugin-fees.fullname" .) .Values.fees.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.fees.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Expand the namespace of the release.
Allows overriding it for multi-namespace deployments in combined charts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.fees.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}


{{/*
Enable dependencies
*/}}
{{- define "mongodb.enabled" -}}
{{- if not .Values.fees.mongodob.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}