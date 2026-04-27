{{/*
Expand the name of the chart and plugin pix-switch.
*/}}
{{- define "plugin-br-pix-switch.name" -}}
{{- default (default .Values.pixSwitch.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin pix-switch.
*/}}
{{- define "plugin-br-pix-switch.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name pix-switch.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-br-pix-switch.fullname" -}}
{{- default .Values.pixSwitch.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create app version.
*/}}
{{- define "plugin.version" -}}
{{- printf "%s" .Chart.AppVersion | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
plugin-br-pix-switch Selector labels
*/}}
{{- define "plugin-br-pix-switch.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-br-pix-switch.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
pix-switch Common labels
*/}}
{{- define "plugin-br-pix-switch.labels" -}}
helm.sh/chart: {{ include "plugin-br-pix-switch.chart" .context }}
{{ include "plugin-br-pix-switch.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Create the name of the plugin-br-pix-switch service account to use
*/}}
{{- define "plugin-br-pix-switch.serviceAccountName" -}}
{{- if .Values.pixSwitch.serviceAccount.create }}
{{- default (include "plugin-br-pix-switch.fullname" .) .Values.pixSwitch.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.pixSwitch.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Expand the namespace of the release.
Allows overriding it for multi-namespace deployments in combined charts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.pixSwitch.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}
