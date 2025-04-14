{{/*
Expand the name of the chart and plugin identity.
*/}}
{{- define "plugin-identity.name" -}}
{{- default (default .Values.identity.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart and plugin auth.
*/}}
{{- define "plugin-auth.name" -}}
{{- default (default .Values.auth.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart and plugin auth.
*/}}
{{- define "plugin-auth-backend.name" -}}
{{- default (default .Values.auth.backend.name) | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create chart name and version as used by the chart label for plugin identity.
*/}}
{{- define "plugin-identity.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin auth.
*/}}
{{- define "plugin-auth.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin auth.
*/}}
{{- define "plugin-auth-backend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name identity.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-identity.fullname" -}}
{{- default (default .Values.identity.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name auth.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-auth.fullname" -}}
{{- default (default .Values.auth.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name auth.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-auth-backend.fullname" -}}
{{- default (default .Values.auth.backend.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create app version.
*/}}
{{- define "plugin.version" -}}
{{- printf "%s" .Chart.AppVersion | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Identity Selector labels
*/}}
{{- define "plugin-identity.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-identity.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
Auth Selector labels
*/}}
{{- define "plugin-auth.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-auth.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
Auth Selector labels
*/}}
{{- define "plugin-auth-backend.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-auth-backend.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
Identity Common labels
*/}}
{{- define "plugin-identity.labels" -}}
helm.sh/chart: {{ include "plugin-identity.chart" .context }}
{{ include "plugin-identity.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Auth Common labels
*/}}
{{- define "plugin-auth.labels" -}}
helm.sh/chart: {{ include "plugin-auth.chart" .context }}
{{ include "plugin-auth.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Auth Backend Common labels
*/}}
{{- define "plugin-auth-backend.labels" -}}
helm.sh/chart: {{ include "plugin-auth-backend.chart" .context }}
{{ include "plugin-auth-backend.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Auth dataSourceName
*/}}
{{- define "plugin-auth-backend.dataSourceName" -}}
"user={{ .Values.auth.configmap.DB_USER }} password={{ .Values.auth.secrets.DB_PASSWORD }} host={{ .Values.auth.configmap.DB_HOST }} port={{ .Values.auth.configmap.DB_PORT }} sslmode=disable dbname={{ .Values.auth.configmap.DB_NAME }}"
{{- end }}

{{/*
Create the name of the identity service account to use
*/}}
{{- define "plugin-identity.serviceAccountName" -}}
{{- if .Values.identity.serviceAccount.create }}
{{- default (include "plugin-identity.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.identity.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the auth service account to use
*/}}
{{- define "plugin-auth.serviceAccountName" -}}
{{- if .Values.auth.serviceAccount.create }}
{{- default (include "plugin-auth.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.auth.serviceAccount.name }}
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
{{- define "valkey.enabled" -}}
{{- if not .Values.valkey.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}
{{- define "postgresql.enabled" -}}
{{- if not .Values.authdb.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}