{{/*
================================================================================
PLUGIN BR PAYMENTS FAKEBTG - HELM TEMPLATE HELPERS
================================================================================
Stand-in HTTP server that mocks the BTG provider API surface for dev/staging.
Single Deployment, single pod, no dependencies.
================================================================================
*/}}

{{/*
================================================================================
NAME HELPERS
================================================================================
*/}}

{{/*
Top-level chart name.
*/}}
{{- define "plugin-br-payments-fakebtg.name" -}}
{{- default "plugin-br-payments-fakebtg" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Application name (single deployment).
*/}}
{{- define "plugin-br-payments-fakebtg.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- default "plugin-br-payments-fakebtg" .Values.fakebtg.name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
================================================================================
CHART HELPERS
================================================================================
*/}}

{{- define "plugin-br-payments-fakebtg.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Resolve the application image tag (Chart.appVersion if fakebtg.image.tag is empty).
*/}}
{{- define "plugin-br-payments-fakebtg.defaultTag" -}}
{{- default .Chart.AppVersion .Values.fakebtg.image.tag }}
{{- end -}}

{{/*
Sanitize tag for use in app.kubernetes.io/version label.
*/}}
{{- define "plugin-br-payments-fakebtg.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "plugin-br-payments-fakebtg.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
================================================================================
LABEL HELPERS
================================================================================
*/}}

{{/*
Common labels.
Usage: {{ include "plugin-br-payments-fakebtg.labels" (dict "context" .) }}
*/}}
{{- define "plugin-br-payments-fakebtg.labels" -}}
helm.sh/chart: {{ include "plugin-br-payments-fakebtg.chart" .context }}
{{ include "plugin-br-payments-fakebtg.selectorLabels" (dict "context" .context) }}
app.kubernetes.io/version: {{ include "plugin-br-payments-fakebtg.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
app.kubernetes.io/part-of: plugin-br-payments
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "plugin-br-payments-fakebtg.selectorLabels" -}}
app.kubernetes.io/name: {{ include "plugin-br-payments-fakebtg.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
================================================================================
SERVICE ACCOUNT HELPER
================================================================================
*/}}

{{- define "plugin-br-payments-fakebtg.serviceAccountName" -}}
{{- if .Values.fakebtg.serviceAccount.create }}
{{- default (include "plugin-br-payments-fakebtg.fullname" .) .Values.fakebtg.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.fakebtg.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
================================================================================
NAMESPACE HELPER
================================================================================
*/}}

{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}
