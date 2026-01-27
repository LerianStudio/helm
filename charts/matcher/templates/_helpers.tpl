{{/*
Expand the name of the chart.
*/}}
{{- define "matcher.name" -}}
{{- default (default "matcher" .Values.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name for matcher.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "matcher.fullname" -}}
{{- printf "%s-%s" (include "matcher.name" .) .Values.matcher.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "matcher.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create matcher app version
*/}}
{{- define "matcher.defaultTag" -}}
{{- default .Chart.AppVersion .Values.matcher.image.tag }}
{{- end -}}

{{/*
Return valid matcher version label
*/}}
{{- define "matcher.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "matcher.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "matcher.labels" -}}
helm.sh/chart: {{ include "matcher.chart" .context }}
{{ include "matcher.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "matcher.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "matcher.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "matcher.name" .context }}-{{ .name }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "matcher.serviceAccountName" -}}
{{- if .Values.matcher.serviceAccount.create }}
{{- default (include "matcher.fullname" .) .Values.matcher.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.matcher.serviceAccount.name }}
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
Enable internal dependencies
*/}}
{{- define "rabbitmq.enabled" -}}
{{- if not .Values.rabbitmq.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{- define "valkey.enabled" -}}
{{- if not .Values.valkey.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{- define "postgresql.enabled" -}}
{{- if not .Values.postgresql.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}
