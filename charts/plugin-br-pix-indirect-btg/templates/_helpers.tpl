{{/*
================================================================================
PLUGIN BR PIX INDIRECT BTG - HELM TEMPLATE HELPERS
================================================================================
This file contains all helper templates for the chart.
Unified from helpers.tpl and _helpers.tpl
================================================================================
*/}}

{{/*
================================================================================
NAME HELPERS
================================================================================
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "plugin-br-pix-indirect-btg.name" -}}
{{- default .Values.pix.name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name for inbound worker.
*/}}
{{- define "inbound.name" -}}
{{- default "plugin-br-pix-indirect-btg-worker-inbound" .Values.inbound.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name for outbound worker.
*/}}
{{- define "outbound.name" -}}
{{- default "plugin-br-pix-indirect-btg-worker-outbound" .Values.outbound.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name for reconciliation worker.
*/}}
{{- define "reconciliation.name" -}}
{{- default "plugin-br-pix-indirect-btg-worker-reconciliation" .Values.reconciliation.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
================================================================================
FULLNAME HELPERS
================================================================================
*/}}

{{/*
Create a default fully qualified app name for pix.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "plugin-br-pix-indirect-btg.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- default "plugin-br-pix-indirect-btg" .Values.pix.name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create a default fully qualified app name for inbound worker.
*/}}
{{- define "inbound.fullname" -}}
{{- default "plugin-br-pix-indirect-btg-worker-inbound" .Values.inbound.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name for outbound worker.
*/}}
{{- define "outbound.fullname" -}}
{{- default "plugin-br-pix-indirect-btg-worker-outbound" .Values.outbound.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name for reconciliation worker.
*/}}
{{- define "reconciliation.fullname" -}}
{{- default "plugin-br-pix-indirect-btg-worker-reconciliation" .Values.reconciliation.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
================================================================================
CHART HELPERS
================================================================================
*/}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "plugin-br-pix-indirect-btg.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name for inbound.
*/}}
{{- define "inbound.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name for outbound.
*/}}
{{- define "outbound.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name for reconciliation.
*/}}
{{- define "reconciliation.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create app version.
*/}}
{{- define "plugin.version" -}}
{{- printf "%s" .Chart.AppVersion | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
================================================================================
LABEL HELPERS
================================================================================
*/}}

{{/*
Common labels for pix
*/}}
{{- define "plugin-br-pix-indirect-btg.labels" -}}
helm.sh/chart: {{ include "plugin-br-pix-indirect-btg.chart" .context }}
{{ include "plugin-br-pix-indirect-btg.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Common labels for inbound
*/}}
{{- define "inbound.labels" -}}
helm.sh/chart: {{ include "inbound.chart" .context }}
{{ include "inbound.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Common labels for outbound
*/}}
{{- define "outbound.labels" -}}
helm.sh/chart: {{ include "outbound.chart" .context }}
{{ include "outbound.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Common labels for reconciliation
*/}}
{{- define "reconciliation.labels" -}}
helm.sh/chart: {{ include "reconciliation.chart" .context }}
{{ include "reconciliation.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
================================================================================
SELECTOR LABEL HELPERS
================================================================================
*/}}

{{/*
Selector labels for pix
*/}}
{{- define "plugin-br-pix-indirect-btg.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-br-pix-indirect-btg.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .name }}
app.kubernetes.io/component: {{ .name }}
{{- end }}
{{- end }}

{{/*
Selector labels for inbound
*/}}
{{- define "inbound.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "inbound.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
Selector labels for outbound
*/}}
{{- define "outbound.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "outbound.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
Selector labels for reconciliation
*/}}
{{- define "reconciliation.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "reconciliation.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
================================================================================
SERVICE ACCOUNT HELPER
================================================================================
*/}}

{{/*
Create the name of the service account to use
*/}}
{{- define "plugin-br-pix-indirect-btg.serviceAccountName" -}}
{{- if .Values.pix.serviceAccount.create }}
{{- default (include "plugin-br-pix-indirect-btg.fullname" .) .Values.pix.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.pix.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
================================================================================
NAMESPACE HELPER
================================================================================
*/}}

{{/*
Expand the namespace of the release.
Allows overriding it for multi-namespace deployments in combined charts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.pix.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
================================================================================
VALIDATION HELPERS
================================================================================
These validations run before deployment to ensure critical fields are set.
- ERRORS (fail): Block deployment - used for truly required fields
- WARNINGS (print): Show message but allow deployment - used for recommended fields
================================================================================
*/}}

{{/*
Validate required configuration fields
*/}}
{{- define "plugin-br-pix-indirect-btg.validateRequired" -}}

{{/* ========== REQUIRED FIELDS (Block deployment) ========== */}}

{{/* BTG Configuration - Required */}}
{{- if not .Values.pix.configmap.BTG_BASE_URL }}
{{- fail "\n\n❌ ERROR: pix.configmap.BTG_BASE_URL is REQUIRED\n   Please set your BTG API URL (e.g., https://api.btgpactual.com or https://api.sandbox.developer.btgpactual.com)\n" }}
{{- end }}

{{- if not .Values.pix.configmap.PIX_ISPB }}
{{- fail "\n\n❌ ERROR: pix.configmap.PIX_ISPB is REQUIRED\n   Please set your bank's ISPB (8-digit code)\n" }}
{{- end }}

{{/* Midaz Configuration - Required */}}
{{- if not .Values.pix.configmap.MIDAZ_ORGANIZATION_ID }}
{{- fail "\n\n❌ ERROR: pix.configmap.MIDAZ_ORGANIZATION_ID is REQUIRED\n   Please set your Midaz organization ID\n" }}
{{- end }}

{{- if not .Values.pix.configmap.MIDAZ_LEDGER_ID }}
{{- fail "\n\n❌ ERROR: pix.configmap.MIDAZ_LEDGER_ID is REQUIRED\n   Please set your Midaz ledger ID\n" }}
{{- end }}

{{/* BTG Secrets - Required */}}
{{- if not .Values.pix.secrets.BTG_CLIENT_ID }}
{{- fail "\n\n❌ ERROR: pix.secrets.BTG_CLIENT_ID is REQUIRED\n   Please set your BTG client ID in secrets section\n" }}
{{- end }}

{{- if not .Values.pix.secrets.BTG_CLIENT_SECRET }}
{{- fail "\n\n❌ ERROR: pix.secrets.BTG_CLIENT_SECRET is REQUIRED\n   Please set your BTG client secret in secrets section\n" }}
{{- end }}

{{/* Midaz Secrets - Required */}}
{{- if not .Values.pix.secrets.MIDAZ_CLIENT_ID }}
{{- fail "\n\n❌ ERROR: pix.secrets.MIDAZ_CLIENT_ID is REQUIRED\n   Please set your Midaz client ID in secrets section\n" }}
{{- end }}

{{- if not .Values.pix.secrets.MIDAZ_CLIENT_SECRET }}
{{- fail "\n\n❌ ERROR: pix.secrets.MIDAZ_CLIENT_SECRET is REQUIRED\n   Please set your Midaz client secret in secrets section\n" }}
{{- end }}

{{/* License - Required */}}
{{- if not .Values.pix.secrets.LICENSE_KEY }}
{{- fail "\n\n❌ ERROR: pix.secrets.LICENSE_KEY is REQUIRED\n   Please set your license key in secrets section\n" }}
{{- end }}

{{/* Organization IDs - Required */}}
{{- if not .Values.pix.configmap.ORGANIZATION_IDS }}
{{- fail "\n\n❌ ERROR: pix.configmap.ORGANIZATION_IDS is REQUIRED\n   Please set your organization IDs (comma-separated list or 'global' for all organizations)\n" }}
{{- end }}

{{/* HMAC Internal Webhook Secret - Required (must match between pix and inbound) */}}
{{- if not .Values.pix.secrets.INTERNAL_WEBHOOK_SECRET }}
{{- fail "\n\n❌ ERROR: pix.secrets.INTERNAL_WEBHOOK_SECRET is REQUIRED\n   Please set your HMAC internal webhook secret (minimum 32 characters)\n   This value must match inbound.secrets.INTERNAL_WEBHOOK_SECRET\n" }}
{{- end }}

{{- if not .Values.inbound.secrets.INTERNAL_WEBHOOK_SECRET }}
{{- fail "\n\n❌ ERROR: inbound.secrets.INTERNAL_WEBHOOK_SECRET is REQUIRED\n   Please set your HMAC internal webhook secret (minimum 32 characters)\n   This value must match pix.secrets.INTERNAL_WEBHOOK_SECRET\n" }}
{{- end }}

{{- end }}

{{/*
Validate PostgreSQL configuration (warnings only)
*/}}
{{- define "plugin-br-pix-indirect-btg.validatePostgreSQL" -}}
{{/* Warnings are logged but do not block deployment */}}
{{- end }}

{{/*
Validate MongoDB configuration (warnings only)
*/}}
{{- define "plugin-br-pix-indirect-btg.validateMongoDB" -}}
{{/* Warnings are logged but do not block deployment */}}
{{- end }}

{{/*
================================================================================
WARNING ANNOTATIONS
================================================================================
These are informational annotations added to resources when using default values.
They serve as reminders without blocking deployment.
================================================================================
*/}}

{{/*
Generate warning annotations for secrets using default values
*/}}
{{- define "plugin-br-pix-indirect-btg.secretWarnings" -}}
{{- $warnings := list -}}
{{- if eq .Values.pix.secrets.DB_PASSWORD "lerian" -}}
{{- $warnings = append $warnings "DB_PASSWORD is using default value 'lerian'" -}}
{{- end -}}
{{- if eq .Values.pix.secrets.MONGO_PASSWORD "lerian" -}}
{{- $warnings = append $warnings "MONGO_PASSWORD is using default value 'lerian'" -}}
{{- end -}}
{{- if .Values.postgresql.enabled -}}
{{- if eq .Values.postgresql.auth.password "lerian" -}}
{{- $warnings = append $warnings "postgresql.auth.password is using default value 'lerian'" -}}
{{- end -}}
{{- end -}}
{{- if .Values.mongodb.enabled -}}
{{- if eq .Values.mongodb.auth.rootPassword "lerian" -}}
{{- $warnings = append $warnings "mongodb.auth.rootPassword is using default value 'lerian'" -}}
{{- end -}}
{{- end -}}
{{- if gt (len $warnings) 0 -}}
lerian.studio/security-warnings: {{ $warnings | join "; " | quote }}
{{- end -}}
{{- end -}}

{{/*
Generate warning annotations for missing webhook configuration
*/}}
{{- define "plugin-br-pix-indirect-btg.webhookWarnings" -}}
{{- $warnings := list -}}
{{- if .Values.outbound -}}
{{- if not .Values.outbound.configmap.WEBHOOK_CLIENT_URL -}}
{{- $warnings = append $warnings "WEBHOOK_CLIENT_URL is empty - outbound notifications disabled" -}}
{{- end -}}
{{- end -}}
{{- if gt (len $warnings) 0 -}}
lerian.studio/webhook-warnings: {{ $warnings | join "; " | quote }}
{{- end -}}
{{- end -}}
