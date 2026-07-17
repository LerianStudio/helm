{{/*
Expand the name of the chart.
*/}}
{{- define "lender.name" -}}
{{- default "lender" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name for the lender API component.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "lender.fullname" -}}
{{- default (include "lender.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified name for the lender console (UI) component.
*/}}
{{- define "lenderConsole.fullname" -}}
{{- $base := include "lender.fullname" . | trunc 55 | trimSuffix "-" }}
{{- printf "%s-console" $base | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "lender.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Resolve the lender API image tag (falls back to Chart.AppVersion).
*/}}
{{- define "lender.defaultTag" -}}
{{- default .Chart.AppVersion .Values.lender.image.tag }}
{{- end -}}

{{/*
Return valid lender version label value.
*/}}
{{- define "lender.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "lender.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "lender.labels" -}}
helm.sh/chart: {{ include "lender.chart" .context }}
{{ include "lender.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "lender.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "lender.selectorLabels" -}}
app.kubernetes.io/name: {{ include "lender.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "lender.serviceAccountName" -}}
{{- if .Values.lender.serviceAccount.create }}
{{- default (include "lender.fullname" .) .Values.lender.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.lender.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Expand the namespace of the release.
Allows overriding it for multi-namespace deployments in combined charts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}
