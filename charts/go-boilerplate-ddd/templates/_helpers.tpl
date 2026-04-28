{{/*
Expand the name of the chart.
*/}}
{{- define "boilerplate.name" -}}
{{- default (default "go-boilerplate-ddd" .Values.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name for go-boilerplate-ddd.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "boilerplate.fullname" -}}
{{- default (include "boilerplate.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "boilerplate.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create go-boilerplate-ddd app version
*/}}
{{- define "boilerplate.defaultTag" -}}
{{- default .Chart.AppVersion .Values.boilerplate.image.tag }}
{{- end -}}

{{/*
Return valid go-boilerplate-ddd version label
*/}}
{{- define "boilerplate.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "boilerplate.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "boilerplate.labels" -}}
helm.sh/chart: {{ include "boilerplate.chart" .context }}
{{ include "boilerplate.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "boilerplate.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "boilerplate.selectorLabels" -}}
app.kubernetes.io/name: {{ include "boilerplate.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "boilerplate.serviceAccountName" -}}
{{- if .Values.boilerplate.serviceAccount.create }}
{{- default (include "boilerplate.fullname" .) .Values.boilerplate.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.boilerplate.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Expand the namespace of the release.
Allows overriding it for multi-namespace deployments in combined charts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}
