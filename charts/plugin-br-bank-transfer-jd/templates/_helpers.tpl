{{/*
Expand the name of the chart.
*/}}
{{- define "bank-transfer.name" -}}
{{- default (default "bank-transfer" .Values.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name for bank-transfer.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "bank-transfer.fullname" -}}
{{- default (include "bank-transfer.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "bank-transfer.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create bank-transfer app version
*/}}
{{- define "bank-transfer.defaultTag" -}}
{{- default .Chart.AppVersion .Values.bankTransfer.image.tag }}
{{- end -}}

{{/*
Return valid bank-transfer version label
*/}}
{{- define "bank-transfer.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "bank-transfer.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "bank-transfer.labels" -}}
helm.sh/chart: {{ include "bank-transfer.chart" .context }}
{{ include "bank-transfer.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "bank-transfer.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "bank-transfer.selectorLabels" -}}
app.kubernetes.io/name: {{ include "bank-transfer.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "bank-transfer.serviceAccountName" -}}
{{- if .Values.bankTransfer.serviceAccount.create }}
{{- default (include "bank-transfer.fullname" .) .Values.bankTransfer.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.bankTransfer.serviceAccount.name }}
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

{{- define "mongodb.enabled" -}}
{{- if not .Values.mongodb.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}
