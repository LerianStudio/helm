{{/*
Expand the name of the chart and plugin manager.
*/}}
{{- define "plugin-manager.name" -}}
{{- default (default .Values.manager.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart and plugin worker.
*/}}
{{- define "plugin-worker.name" -}}
{{- default (default .Values.worker.name) | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create chart name and version as used by the chart label for plugin manager.
*/}}
{{- define "plugin-manager.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin worker.
*/}}
{{- define "plugin-worker.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create a default fully qualified app name manager.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-manager.fullname" -}}
{{- default (default .Values.manager.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name worker.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-worker.fullname" -}}
{{- default (default .Values.worker.name) | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create app version.
*/}}
{{- define "plugin.version" -}}
{{- printf "%s" .Chart.AppVersion | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
manager Selector labels
*/}}
{{- define "plugin-manager.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-manager.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
worker Selector labels
*/}}
{{- define "plugin-worker.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-worker.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}


{{/*
manager Common labels
*/}}
{{- define "plugin-manager.labels" -}}
helm.sh/chart: {{ include "plugin-manager.chart" .context }}
{{ include "plugin-manager.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
worker Common labels
*/}}
{{- define "plugin-worker.labels" -}}
helm.sh/chart: {{ include "plugin-worker.chart" .context }}
{{ include "plugin-worker.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}


{{/*
Manager dataSourceName
*/}}
{{- define "plugin-manager-backend.dataSourceName" -}}
"user={{ .Values.manager.configmap.DB_USER }} password={{ .Values.manager.secrets.DB_PASSWORD }} host={{ .Values.manager.configmap.DB_HOST }} port={{ .Values.manager.configmap.DB_PORT }} sslmode=disable dbname={{ .Values.manager.configmap.DB_NAME }}"
{{- end }}

{{/*
Create the name of the manager service account to use
*/}}
{{- define "plugin-manager.serviceAccountName" -}}
{{- if .Values.manager.serviceAccount.create }}
{{- default (include "plugin-manager.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.manager.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the worker service account to use
*/}}
{{- define "plugin-worker.serviceAccountName" -}}
{{- if .Values.worker.serviceAccount.create }}
{{- default (include "plugin-worker.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.worker.serviceAccount.name }}
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
{{- define "rabbitmq.enabled" -}}
{{- if not .Values.rabbitmq.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}
{{- define "mongodb.enabled" -}}
{{- if not .Values.mongodb.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}
{{- define "seaweedfs.enabled" -}}
{{- if not .Values.seaweedfs.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}
{{- define "keda.enabled" -}}
{{- if not .Values.keda.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}