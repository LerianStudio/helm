{{/*
================================================================================
LERIAN NOTIFICATION - HELM TEMPLATE HELPERS
================================================================================
Topology:
  - api             (HTTP service + ingress)
  - worker-email    (consumer, health probe only)
  - worker-sms      (consumer, health probe only)
  - worker-webhook  (consumer, health probe only)
External deps (no subcharts): Postgres, Redis, RabbitMQ.
================================================================================
*/}}

{{/*
================================================================================
NAME HELPERS
================================================================================
*/}}

{{- define "lerian-notification.name" -}}
{{- default .Values.api.name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "workerEmail.name" -}}
{{- default "lerian-notification-worker-email" .Values.workerEmail.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "workerSms.name" -}}
{{- default "lerian-notification-worker-sms" .Values.workerSms.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "workerWebhook.name" -}}
{{- default "lerian-notification-worker-webhook" .Values.workerWebhook.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
================================================================================
FULLNAME HELPERS
================================================================================
*/}}

{{- define "lerian-notification.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- default "lerian-notification" .Values.api.name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "workerEmail.fullname" -}}
{{- default "lerian-notification-worker-email" .Values.workerEmail.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "workerSms.fullname" -}}
{{- default "lerian-notification-worker-sms" .Values.workerSms.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "workerWebhook.fullname" -}}
{{- default "lerian-notification-worker-webhook" .Values.workerWebhook.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
================================================================================
CHART / VERSION HELPERS
================================================================================
*/}}

{{- define "lerian-notification.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "lerian-notification.version" -}}
{{- printf "%s" .Chart.AppVersion | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
================================================================================
LABEL HELPERS (parametric: pass dict with "context" and "name")
================================================================================
*/}}

{{- define "lerian-notification.labels" -}}
helm.sh/chart: {{ include "lerian-notification.chart" .context }}
{{ include "lerian-notification.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "lerian-notification.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
app.kubernetes.io/part-of: lerian-notification
{{- end }}

{{- define "lerian-notification.selectorLabels" -}}
{{- if .name }}
app.kubernetes.io/name: {{ .name }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .name }}
app.kubernetes.io/component: {{ .name }}
{{- end }}
{{- end }}

{{/*
================================================================================
SERVICE ACCOUNT HELPER
================================================================================
*/}}

{{- define "lerian-notification.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "lerian-notification.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
================================================================================
SHARED CONFIGMAP / SECRET REFS
================================================================================
All components consume the same env contract, so we point envFrom at a single
ConfigMap and Secret (overridable via .Values.secretRef.name for AVP / external
secrets integration).
*/}}

{{- define "lerian-notification.configMapName" -}}
{{- default (include "lerian-notification.fullname" .) .Values.configMapNameOverride }}
{{- end }}

{{- define "lerian-notification.secretName" -}}
{{- if .Values.secretRef.name }}
{{- .Values.secretRef.name }}
{{- else }}
{{- include "lerian-notification.fullname" . }}
{{- end }}
{{- end }}

{{/*
================================================================================
NAMESPACE HELPER
================================================================================
*/}}

{{- define "lerian-notification.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}
