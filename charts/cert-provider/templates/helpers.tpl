{{/*
Expand the name of the chart and plugin fees.
*/}}
{{- define "cert-provider.name" -}}
{{- default (default .Values.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart and plugin fees.
*/}}
{{- define "cert-provider-backend.name" -}}
{{- default (default .Values.backend.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin fees.
*/}}
{{- define "cert-provider.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin fees.
*/}}
{{- define "cert-provider-backend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name fees.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cert-provider.fullname" -}}
{{- default (default .Values.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name fees.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cert-provider-backend.fullname" -}}
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
{{- define "cert-provider.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "cert-provider.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
fees Selector labels
*/}}
{{- define "cert-provider-backend.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "cert-provider-backend.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}


{{/*
fees Common labels
*/}}
{{- define "cert-provider.labels" -}}
helm.sh/chart: {{ include "cert-provider.chart" .context }}
{{ include "cert-provider.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
fees Backend Common labels
*/}}
{{- define "cert-provider-backend.labels" -}}
helm.sh/chart: {{ include "cert-provider-backend.chart" .context }}
{{ include "cert-provider-backend.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
fees dataSourceName
*/}}
{{- define "cert-provider-backend.dataSourceName" -}}
"user={{ .Values.configmap.DB_USER }} password={{ .Values.secrets.DB_PASSWORD }} host={{ .Values.configmap.DB_HOST }} port={{ .Values.configmap.DB_PORT }} sslmode=disable dbname={{ .Values.configmap.DB_NAME }}"
{{- end }}

{{/*
Create the name of the fees service account to use
*/}}
{{- define "cert-provider.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cert-provider.fullname" .) .Values.serviceAccount.name }}
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