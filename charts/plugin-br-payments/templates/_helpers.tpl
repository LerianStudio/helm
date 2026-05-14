{{/*
================================================================================
PLUGIN BR PAYMENTS - HELM TEMPLATE HELPERS
================================================================================
The plugin runs API + worker logic in a SINGLE process (SERVICE_TYPE=both).
One Deployment, one pod. No separate worker Deployment.
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
{{- define "plugin-br-payments.name" -}}
{{- default "plugin-br-payments" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Application name (single deployment).
*/}}
{{- define "plugin-br-payments.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- default "plugin-br-payments" .Values.app.name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
================================================================================
CHART HELPERS
================================================================================
*/}}

{{- define "plugin-br-payments.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Resolve the application image tag (Chart.appVersion if app.image.tag is empty).
*/}}
{{- define "plugin-br-payments.defaultTag" -}}
{{- default .Chart.AppVersion .Values.app.image.tag }}
{{- end -}}

{{/*
Sanitize tag for use in app.kubernetes.io/version label.
*/}}
{{- define "plugin-br-payments.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "plugin-br-payments.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
================================================================================
LABEL HELPERS
================================================================================
*/}}

{{/*
Common labels.
Usage: {{ include "plugin-br-payments.labels" (dict "context" .) }}
*/}}
{{- define "plugin-br-payments.labels" -}}
helm.sh/chart: {{ include "plugin-br-payments.chart" .context }}
{{ include "plugin-br-payments.selectorLabels" (dict "context" .context) }}
app.kubernetes.io/version: {{ include "plugin-br-payments.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
app.kubernetes.io/part-of: plugin-br-payments
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "plugin-br-payments.selectorLabels" -}}
app.kubernetes.io/name: {{ include "plugin-br-payments.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
================================================================================
SERVICE ACCOUNT HELPER
================================================================================
*/}}

{{- define "plugin-br-payments.serviceAccountName" -}}
{{- if .Values.app.serviceAccount.create }}
{{- default (include "plugin-br-payments.fullname" .) .Values.app.serviceAccount.name }}
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
================================================================================
DEPENDENCY ENABLED HELPER
================================================================================
*/}}

{{- define "postgresql.enabled" -}}
{{- if and (default true .Values.postgresql.enabled) (not .Values.postgresql.external) -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
================================================================================
VALIDATION HELPERS
================================================================================
ERRORS (fail) block deployment for truly required fields.
Mirrors the OUTBOX_ENABLED + provider/Midaz requirements documented in the
plugin-br-payments README.
================================================================================
*/}}

{{- define "plugin-br-payments.validateRequired" -}}

{{/* OUTBOX must be enabled for HTTP routes to register */}}
{{- if ne (.Values.app.configmap.OUTBOX_ENABLED | toString) "true" }}
{{- fail "\n\nERROR: app.configmap.OUTBOX_ENABLED must be \"true\".\n   plugin-br-payments only registers its routes when the outbox pattern is enabled.\n   See README -> 'Local Development Config'.\n" }}
{{- end }}

{{/* Provider integration — required for any write operation */}}
{{- if not .Values.app.configmap.PROVIDER_API_BASE_URL }}
{{- fail "\n\nERROR: app.configmap.PROVIDER_API_BASE_URL is REQUIRED.\n   Set the provider API base URL (e.g., https://api.btgpactual.com).\n" }}
{{- end }}

{{- if not .Values.app.configmap.PROVIDER_AUTH_URL }}
{{- fail "\n\nERROR: app.configmap.PROVIDER_AUTH_URL is REQUIRED.\n   Set the provider OAuth2 token endpoint URL.\n" }}
{{- end }}

{{- if not .Values.app.secrets.PROVIDER_CLIENT_ID }}
{{- fail "\n\nERROR: app.secrets.PROVIDER_CLIENT_ID is REQUIRED.\n   Set the provider OAuth2 client ID in the secrets section.\n" }}
{{- end }}

{{- if not .Values.app.secrets.PROVIDER_CLIENT_SECRET }}
{{- fail "\n\nERROR: app.secrets.PROVIDER_CLIENT_SECRET is REQUIRED.\n   Set the provider OAuth2 client secret in the secrets section.\n" }}
{{- end }}

{{- if not .Values.app.secrets.PROVIDER_WEBHOOK_SECRET }}
{{- fail "\n\nERROR: app.secrets.PROVIDER_WEBHOOK_SECRET is REQUIRED.\n   Set the provider webhook bearer token in the secrets section.\n" }}
{{- end }}

{{/* Midaz Ledger URLs — required for production */}}
{{- if not .Values.app.configmap.MIDAZ_ONBOARDING_URL }}
{{- fail "\n\nERROR: app.configmap.MIDAZ_ONBOARDING_URL is REQUIRED.\n   Set the Midaz onboarding service URL.\n" }}
{{- end }}

{{- if not .Values.app.configmap.MIDAZ_TRANSACTION_URL }}
{{- fail "\n\nERROR: app.configmap.MIDAZ_TRANSACTION_URL is REQUIRED.\n   Set the Midaz transaction service URL.\n" }}
{{- end }}

{{/* PostgreSQL password — required */}}
{{- if not .Values.app.secrets.POSTGRES_PASSWORD }}
{{- fail "\n\nERROR: app.secrets.POSTGRES_PASSWORD is REQUIRED.\n   Set the PostgreSQL application password.\n" }}
{{- end }}

{{/* Multi-tenant required fields when enabled */}}
{{- if eq (.Values.app.configmap.MULTI_TENANCY_ENABLED | toString) "true" }}
{{- if not .Values.app.configmap.MULTI_TENANT_MANAGER_URL }}
{{- fail "\n\nERROR: app.configmap.MULTI_TENANT_MANAGER_URL is REQUIRED when MULTI_TENANCY_ENABLED=true.\n" }}
{{- end }}
{{- if not .Values.app.secrets.MULTI_TENANT_SERVICE_API_KEY }}
{{- fail "\n\nERROR: app.secrets.MULTI_TENANT_SERVICE_API_KEY is REQUIRED when MULTI_TENANCY_ENABLED=true.\n" }}
{{- end }}
{{- end }}

{{/* Internal API key + credential encryption — required when worker runs in-process or as worker pod */}}
{{- $svcType := .Values.app.configmap.SERVICE_TYPE | default "both" | toString }}
{{- if or (eq $svcType "both") (eq $svcType "worker") }}
{{- if not .Values.app.secrets.INTERNAL_API_KEY }}
{{- fail "\n\nERROR: app.secrets.INTERNAL_API_KEY is REQUIRED when SERVICE_TYPE includes worker (\"both\" or \"worker\").\n   The plugin uses this key for cross-pod token retrieval.\n   Must be at least 32 characters. Generate with: openssl rand -hex 32\n" }}
{{- end }}
{{- if lt (len (.Values.app.secrets.INTERNAL_API_KEY | toString)) 32 }}
{{- fail "\n\nERROR: app.secrets.INTERNAL_API_KEY must be at least 32 characters.\n   Generate with: openssl rand -hex 32\n" }}
{{- end }}
{{- if not .Values.app.secrets.CREDENTIAL_ENCRYPTION_KEY }}
{{- fail "\n\nERROR: app.secrets.CREDENTIAL_ENCRYPTION_KEY is REQUIRED when SERVICE_TYPE includes worker (\"both\" or \"worker\").\n   The plugin uses this key to encrypt provider OAuth credentials at rest.\n   Must be a base64-encoded AES-256 key (32 random bytes).\n   Generate with: openssl rand -base64 32\n" }}
{{- end }}
{{- end }}

{{/* Split-deployment API mode requires INTERNAL_WORKER_URL */}}
{{- if eq $svcType "api" }}
{{- if not .Values.app.configmap.INTERNAL_WORKER_URL }}
{{- fail "\n\nERROR: app.configmap.INTERNAL_WORKER_URL is REQUIRED when SERVICE_TYPE=\"api\".\n   API pods need to reach the worker pod's internal token endpoint.\n" }}
{{- end }}
{{- if not .Values.app.secrets.INTERNAL_API_KEY }}
{{- fail "\n\nERROR: app.secrets.INTERNAL_API_KEY is REQUIRED when SERVICE_TYPE=\"api\".\n" }}
{{- end }}
{{- end }}

{{- end }}

{{/*
Generate annotation listing default-value warnings (non-blocking).
*/}}
{{- define "plugin-br-payments.secretWarnings" -}}
{{- $warnings := list -}}
{{- if eq (.Values.app.secrets.POSTGRES_PASSWORD | toString) "lerian" -}}
{{- $warnings = append $warnings "POSTGRES_PASSWORD is using default value 'lerian'" -}}
{{- end -}}
{{- if .Values.postgresql.enabled -}}
{{- if eq (.Values.postgresql.auth.password | toString) "lerian" -}}
{{- $warnings = append $warnings "postgresql.auth.password is using default value 'lerian'" -}}
{{- end -}}
{{- end -}}
{{- if not .Values.app.secrets.LICENSE_KEY -}}
{{- $warnings = append $warnings "LICENSE_KEY is empty - required for production" -}}
{{- end -}}
{{- if gt (len $warnings) 0 -}}
lerian.studio/security-warnings: {{ $warnings | join "; " | quote }}
{{- end -}}
{{- end -}}
