{{/*
================================================================================
BR-STA - HELM TEMPLATE HELPERS
================================================================================
br-sta is a Go/Fiber HTTP service. One Deployment, one pod, one process
(the /service binary). It requires PostgreSQL and Redis/Valkey.
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
{{- define "br-sta.name" -}}
{{- default "br-sta" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Application name (single deployment).
*/}}
{{- define "br-sta.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- default "br-sta" .Values.app.name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
================================================================================
CHART HELPERS
================================================================================
*/}}

{{- define "br-sta.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Resolve the application image tag (Chart.appVersion if app.image.tag is empty).
*/}}
{{- define "br-sta.defaultTag" -}}
{{- default .Chart.AppVersion .Values.app.image.tag }}
{{- end -}}

{{/*
Sanitize tag for use in app.kubernetes.io/version label.
*/}}
{{- define "br-sta.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "br-sta.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
================================================================================
LABEL HELPERS
================================================================================
*/}}

{{/*
Common labels.
Usage: {{ include "br-sta.labels" (dict "context" .) }}
*/}}
{{- define "br-sta.labels" -}}
helm.sh/chart: {{ include "br-sta.chart" .context }}
{{ include "br-sta.selectorLabels" (dict "context" .context) }}
app.kubernetes.io/version: {{ include "br-sta.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
app.kubernetes.io/part-of: br-sta
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "br-sta.selectorLabels" -}}
app.kubernetes.io/name: {{ include "br-sta.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
================================================================================
SERVICE ACCOUNT HELPER
================================================================================
*/}}

{{- define "br-sta.serviceAccountName" -}}
{{- if .Values.app.serviceAccount.create }}
{{- default (include "br-sta.fullname" .) .Values.app.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.app.serviceAccount.name }}
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

{{/*
infraSecretRef — emit a `- name: <envName> valueFrom: secretKeyRef: {name,key}` env entry
pointing at a Bitnami subchart's generated Secret (or the operator's existingSecret override).
Inputs (dict): context (root .), subchart ("postgresql"|"valkey"),
key (data key), envName (container env var name).
See docs/helm-chart-standard.md "Single-Source Infra Secrets".
*/}}
{{- define "br-sta.infraSecretRef" -}}
{{- $ctx := .context -}}
{{- $sub := .subchart -}}
{{- $auth := default dict (index $ctx.Values $sub "auth") -}}
{{- $secretName := "" -}}
{{- if $auth.existingSecret -}}
{{- $secretName = $auth.existingSecret -}}
{{- else -}}
{{- $secretName = include "common.names.dependency.fullname" (dict "chartName" $sub "chartValues" (index $ctx.Values $sub) "context" $ctx) -}}
{{- end -}}
- name: {{ .envName }}
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: {{ .key }}
{{- end }}

{{/*
================================================================================
DEPENDENCY ENABLED HELPERS
================================================================================
*/}}

{{/* Nil-aware: ne (toString .enabled) "false" is true for unset/true, false only for
     an explicit false — avoids the `default true` coercion GOTCHA in the standard. */}}
{{- define "postgresql.enabled" -}}
{{- if and (ne (toString .Values.postgresql.enabled) "false") (not .Values.postgresql.external) -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{- define "valkey.enabled" -}}
{{- if and (ne (toString .Values.valkey.enabled) "false") (not .Values.valkey.external) -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/* RabbitMQ is OPTIONAL and disabled by default, so an unset value must NOT
     coerce to enabled — the nil-aware check treats unset/true as enabled and an
     explicit false (the default) as disabled. Honors .external for external mode. */}}
{{- define "rabbitmq.enabled" -}}
{{- $rmq := .Values.rabbitmq | default dict -}}
{{- if and (ne (toString $rmq.enabled) "false") (not $rmq.external) -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
================================================================================
VALIDATION HELPERS
================================================================================
ERRORS (fail) block deployment for truly required fields. br-sta only requires
operator input for optional integrations that have been toggled on (multi-tenant).
================================================================================
*/}}

{{- define "br-sta.validateRequired" -}}

{{/* PostgreSQL password is single-sourced from the postgresql subchart Secret
     via secretKeyRef; see docs/helm-chart-standard.md "Single-Source Infra
     Secrets". No gate here: for the bundled subchart the value is generated;
     for external Postgres the operator supplies postgresql.auth.existingSecret
     or app.secrets.POSTGRES_PASSWORD. The same reasoning applies to Valkey. */}}

{{/* Multi-tenant required fields when enabled */}}
{{- if eq (.Values.app.configmap.MULTI_TENANT_ENABLED | toString) "true" }}
{{- if not .Values.app.configmap.MULTI_TENANT_URL }}
{{- fail "\n\nERROR: app.configmap.MULTI_TENANT_URL is REQUIRED when MULTI_TENANT_ENABLED=true.\n" }}
{{- end }}
{{- if not .Values.app.secrets.MULTI_TENANT_SERVICE_API_KEY }}
{{- fail "\n\nERROR: app.secrets.MULTI_TENANT_SERVICE_API_KEY is REQUIRED when MULTI_TENANT_ENABLED=true.\n" }}
{{- end }}
{{- end }}

{{- end }}

{{/*
Generate annotation listing default-value warnings (non-blocking).
*/}}
{{- define "br-sta.secretWarnings" -}}
{{- $warnings := list -}}
{{- if .Values.postgresql.enabled -}}
{{- if eq (.Values.postgresql.auth.password | toString) "lerian" -}}
{{- $warnings = append $warnings "postgresql.auth.password is using default value 'lerian'" -}}
{{- end -}}
{{- end -}}
{{- if .Values.valkey.enabled -}}
{{- if eq (.Values.valkey.auth.password | toString) "lerian" -}}
{{- $warnings = append $warnings "valkey.auth.password is using default value 'lerian'" -}}
{{- end -}}
{{- end -}}
{{- if gt (len $warnings) 0 -}}
lerian.studio/security-warnings: {{ $warnings | join "; " | quote }}
{{- end -}}
{{- end -}}

{{/*
Vendored from Bitnami common (charts/common/templates/_names.tpl) so infra
Secret/Service names render even when all bundled subcharts are disabled
(external-infra path). Self-contained: no other common.* helpers required.
*/}}
{{- define "common.names.dependency.fullname" -}}
{{- if .chartValues.fullnameOverride -}}
{{- .chartValues.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .chartName .chartValues.nameOverride -}}
{{- if contains $name .context.Release.Name -}}
{{- .context.Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .context.Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}
