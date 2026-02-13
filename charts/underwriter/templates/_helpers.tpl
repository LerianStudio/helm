{{/*
Expand the name of the chart.
*/}}
{{- define "underwriter.name" -}}
{{- default (default "underwriter" .Values.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name for underwriter.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "underwriter.fullname" -}}
{{- default (include "underwriter.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "underwriter.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create underwriter app version
*/}}
{{- define "underwriter.defaultTag" -}}
{{- default .Chart.AppVersion .Values.underwriter.image.tag }}
{{- end -}}

{{/*
Return valid underwriter version label
*/}}
{{- define "underwriter.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "underwriter.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "underwriter.labels" -}}
helm.sh/chart: {{ include "underwriter.chart" .context }}
{{ include "underwriter.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "underwriter.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "underwriter.selectorLabels" -}}
app.kubernetes.io/name: {{ include "underwriter.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "underwriter.serviceAccountName" -}}
{{- if .Values.underwriter.serviceAccount.create }}
{{- default (include "underwriter.fullname" .) .Values.underwriter.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.underwriter.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Expand the namespace of the release.
Allows overriding it for multi-namespace deployments in combined charts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}
