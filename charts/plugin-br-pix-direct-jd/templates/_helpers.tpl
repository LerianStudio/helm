{{/*
Expand the name of the chart and plugin pix.
*/}}
{{- define "plugin-br-pix-direct-jd.name" -}}
{{- default (default .Values.pix.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart and plugin plugin-br-pix-direct-jd-qr-code.
*/}}
{{- define "plugin-br-pix-direct-jd-qr-code.name" -}}
{{- default (default .Values.qrcode.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart and plugin plugin-br-pix-direct-jd-job.
*/}}
{{- define "plugin-br-pix-direct-jd-job.name" -}}
{{- default (default .Values.job.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin pix.
*/}}
{{- define "plugin-br-pix-direct-jd.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin plugin-br-pix-direct-jd-qr-code.
*/}}
{{- define "plugin-br-pix-direct-jd-qr-code.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin pix.
*/}}
{{- define "plugin-br-pix-direct-jd-job.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create a default fully qualified app name pix.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-br-pix-direct-jd.fullname" -}}
{{- default .Values.pix.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name plugin-br-pix-direct-jd-qr-code.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-br-pix-direct-jd-qr-code.fullname" -}}
{{- default (default .Values.qrcode.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name plugin-br-pix-direct-jd-job.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-br-pix-direct-jd-job.fullname" -}}
{{- default (default .Values.job.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create app version.
*/}}
{{- define "plugin.version" -}}
{{- printf "%s" .Chart.AppVersion | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
plugin-br-pix-direct-jd Selector labels
*/}}
{{- define "plugin-br-pix-direct-jd.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-br-pix-direct-jd.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
plugin-br-pix-direct-jd-qr-code Selector labels
*/}}
{{- define "plugin-br-pix-direct-jd-qr-code.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-br-pix-direct-jd-qr-code.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
plugin-br-pix-direct-jd-job Selector labels
*/}}
{{- define "plugin-br-pix-direct-jd-job.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-br-pix-direct-jd-job.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
pix Common labels
*/}}
{{- define "plugin-br-pix-direct-jd.labels" -}}
helm.sh/chart: {{ include "plugin-br-pix-direct-jd.chart" .context }}
{{ include "plugin-br-pix-direct-jd.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
plugin-br-pix-direct-jd-qr-code Common labels
*/}}
{{- define "plugin-br-pix-direct-jd-qr-code.labels" -}}
helm.sh/chart: {{ include "plugin-br-pix-direct-jd-qr-code.chart" .context }}
{{ include "plugin-br-pix-direct-jd-qr-code.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
plugin-br-pix-direct-jd-job Common labels
*/}}
{{- define "plugin-br-pix-direct-jd-job.labels" -}}
helm.sh/chart: {{ include "plugin-br-pix-direct-jd-job.chart" .context }}
{{ include "plugin-br-pix-direct-jd-job.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Create the name of the plugin-br-pix-direct-jd-qr-code service account to use
*/}}
{{- define "plugin-br-pix-direct-jd-qr-code.serviceAccountName" -}}
{{- if .Values.qrcode.serviceAccount.create }}
{{- default (include "plugin-br-pix-direct-jd-qr-code.fullname" .) .Values.qrcode.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.qrcode.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the plugin-br-pix-direct-jd service account to use
*/}}
{{- define "plugin-br-pix-direct-jd.serviceAccountName" -}}
{{- if .Values.pix.serviceAccount.create }}
{{- default (include "plugin-br-pix-direct-jd.fullname" .) .Values.pix.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.pix.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the plugin-br-pix-direct-jd-job service account to use
*/}}
{{- define "plugin-br-pix-direct-jd-job.serviceAccountName" -}}
{{- if .Values.pix.serviceAccount.create }}
{{- default (include "plugin-br-pix-direct-jd-job.fullname" .) .Values.pix.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.job.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Expand the namespace of the release.
Allows overriding it for multi-namespace deployments in combined charts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.pix.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}
