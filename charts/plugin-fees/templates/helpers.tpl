{{/*
Expand the name of the chart and plugin fees.
*/}}
{{- define "plugin-fees.name" -}}
{{- default (default .Values.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart and plugin fees.
*/}}
{{- define "plugin-fees-backend.name" -}}
{{- default (default .Values.backend.name) | trunc 63 | trimSuffix "-" }}
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
Create a default fully qualified app name fees.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-fees.fullname" -}}
{{- default (default .Values.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name fees.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-fees-backend.fullname" -}}
{{- default (default .Values.backend.name) | trunc 63 | trimSuffix "-" }}
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
fees dataSourceName
*/}}
{{- define "plugin-fees-backend.dataSourceName" -}}
"user={{ .Values.configmap.DB_USER }} password={{ .Values.secrets.DB_PASSWORD }} host={{ .Values.configmap.DB_HOST }} port={{ .Values.configmap.DB_PORT }} sslmode=disable dbname={{ .Values.configmap.DB_NAME }}"
{{- end }}

{{/*
Create the name of the fees service account to use
*/}}
{{- define "plugin-fees.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "plugin-fees.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
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
Enable dependencies
*/}}
{{- define "mongodb.enabled" -}}
{{- if not .Values.mongodob.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}