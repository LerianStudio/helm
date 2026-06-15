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
SINGLE-SOURCE INFRA SECRETS (Pattern A)
================================================================================
Bitnami postgresql / mongodb auto-generate their password into their OWN Secret.
The application reads it via a discrete secretKeyRef env entry rather than keeping
a second copy in the app Secret. valkey.io has no Secret-based password, so
REDIS_PASSWORD stays operator-provided (see README).
See docs/helm-chart-standard.md "Single-Source Infra Secrets".
================================================================================
*/}}

{{/*
plugin-br-pix-indirect-btg.postgresInternal — true when the bundled Bitnami postgresql
subchart provides the DB (enabled and not flagged external). Nil-aware: an explicit
`postgresql.enabled=false` correctly yields false (Helm `default` would coerce it back to true).
*/}}
{{- define "plugin-br-pix-indirect-btg.postgresInternal" -}}
{{- $pg := default dict .Values.postgresql -}}
{{- if and (ne (toString $pg.enabled) "false") (not $pg.external) -}}true{{- else -}}false{{- end -}}
{{- end }}

{{/*
plugin-br-pix-indirect-btg.mongoInternal — true when the bundled Bitnami mongodb subchart
provides the DB.
*/}}
{{- define "plugin-br-pix-indirect-btg.mongoInternal" -}}
{{- $mongo := default dict .Values.mongodb -}}
{{- if and (ne (toString $mongo.enabled) "false") (not $mongo.external) -}}true{{- else -}}false{{- end -}}
{{- end }}

{{/*
plugin-br-pix-indirect-btg.compUsesExistingSecret — true when the component is configured to consume
an operator-managed existing Secret (useExistingSecrets: true with a non-empty existingSecretName).
That Secret supplies the infra credentials via envFrom (the documented "Creating ... Secret Manually"
workflow), so the chart trusts it the same way the deployment's envFrom does: no app Secret is rendered,
and the infra-password gates/discrete-env emission stand down on the external path.
Input (dict): context (root .), component (component key under .Values).
*/}}
{{- define "plugin-br-pix-indirect-btg.compUsesExistingSecret" -}}
{{- $comp := index .context.Values .component -}}
{{- if and $comp.useExistingSecrets $comp.existingSecretName -}}true{{- else -}}false{{- end -}}
{{- end }}

{{/*
plugin-br-pix-indirect-btg.infraSecretRef — emit a `- name: <envName> valueFrom: secretKeyRef: {name,key}`
env entry pointing at a Bitnami subchart's generated Secret (or the operator's existingSecret override).
Inputs (dict): context (root .), subchart ("postgresql"|"mongodb"), key, envName.
*/}}
{{- define "plugin-br-pix-indirect-btg.infraSecretRef" -}}
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
plugin-br-pix-indirect-btg.postgresHost — collapse-aware Bitnami postgresql Service name (the
primary/standalone Service shares the dependency fullname). Honors nameOverride/fullnameOverride
and the release-name collapse via common.names.dependency.fullname. Derived ONLY when the subchart
is bundled — when postgresql is external/disabled the common library is not loaded, so this returns
empty and the operator must set DB_HOST explicitly.
*/}}
{{- define "plugin-br-pix-indirect-btg.postgresHost" -}}
{{- if eq (include "plugin-br-pix-indirect-btg.postgresInternal" .) "true" -}}
{{- include "common.names.dependency.fullname" (dict "chartName" "postgresql" "chartValues" .Values.postgresql "context" .) -}}
{{- end -}}
{{- end }}

{{/*
plugin-br-pix-indirect-btg.mongoHost — collapse-aware Bitnami mongodb Service name. Derived ONLY
when the subchart is bundled (see postgresHost).
*/}}
{{- define "plugin-br-pix-indirect-btg.mongoHost" -}}
{{- if eq (include "plugin-br-pix-indirect-btg.mongoInternal" .) "true" -}}
{{- include "common.names.dependency.fullname" (dict "chartName" "mongodb" "chartValues" .Values.mongodb "context" .) -}}
{{- end -}}
{{- end }}

{{/*
plugin-br-pix-indirect-btg.valkeyHost — collapse-aware valkey.io Service name. valkey.io is NOT
Bitnami: its fullname helper collapses <release>-valkey to just <release> when the release name
already contains "valkey", and emits a single Service (no -master/-primary split). Replicated here
because common.names.dependency.fullname is Bitnami-specific.
*/}}
{{- define "plugin-br-pix-indirect-btg.valkeyHost" -}}
{{- $vk := default dict .Values.valkey -}}
{{- $name := default "valkey" $vk.nameOverride -}}
{{- if $vk.fullnameOverride -}}
{{- $vk.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{/*
plugin-br-pix-indirect-btg.dbPasswordRequired — fail-loud gate. When the bundled postgresql
subchart is NOT the source (external or disabled) and no operator credential or existingSecret is
supplied, fail the render naming the exact value. On the bundled path the password comes from the
subchart Secret, so the gate does not fire.
Input (dict): context (root .), component (component key under .Values).
*/}}
{{- define "plugin-br-pix-indirect-btg.dbPasswordRequired" -}}
{{- $ctx := .context -}}
{{- $comp := .component -}}
{{- $pgAuth := default dict (index $ctx.Values "postgresql" "auth") -}}
{{- $secrets := default dict (index $ctx.Values $comp "secrets") -}}
{{- $usesExisting := eq (include "plugin-br-pix-indirect-btg.compUsesExistingSecret" (dict "context" $ctx "component" $comp)) "true" -}}
{{- if and (ne (include "plugin-br-pix-indirect-btg.postgresInternal" $ctx) "true") (not $pgAuth.existingSecret) (not $secrets.DB_PASSWORD) (not $usesExisting) -}}
{{- fail (printf "\n\nERROR: %s.secrets.DB_PASSWORD is REQUIRED when the bundled postgresql subchart is disabled or external.\n   The password is no longer sourced from the subchart Secret.\n   Set %s.secrets.DB_PASSWORD, set postgresql.auth.existingSecret, or provide it via %s.useExistingSecrets + %s.existingSecretName.\n" $comp $comp $comp $comp) -}}
{{- end -}}
{{- end }}

{{/*
plugin-br-pix-indirect-btg.mongoPasswordRequired — fail-loud gate for MongoDB, mirror of the
postgres gate. Only invoked for components that consume MongoDB.
Input (dict): context (root .), component (component key under .Values).
*/}}
{{- define "plugin-br-pix-indirect-btg.mongoPasswordRequired" -}}
{{- $ctx := .context -}}
{{- $comp := .component -}}
{{- $mongoAuth := default dict (index $ctx.Values "mongodb" "auth") -}}
{{- $secrets := default dict (index $ctx.Values $comp "secrets") -}}
{{- $usesExisting := eq (include "plugin-br-pix-indirect-btg.compUsesExistingSecret" (dict "context" $ctx "component" $comp)) "true" -}}
{{- if and (ne (include "plugin-br-pix-indirect-btg.mongoInternal" $ctx) "true") (not $mongoAuth.existingSecret) (not $secrets.MONGO_PASSWORD) (not $usesExisting) -}}
{{- fail (printf "\n\nERROR: %s.secrets.MONGO_PASSWORD is REQUIRED when the bundled mongodb subchart is disabled or external.\n   The password is no longer sourced from the subchart Secret.\n   Set %s.secrets.MONGO_PASSWORD, set mongodb.auth.existingSecret, or provide it via %s.useExistingSecrets + %s.existingSecretName.\n" $comp $comp $comp $comp) -}}
{{- end -}}
{{- end }}

{{/*
plugin-br-pix-indirect-btg.dbHostRequired — fail-loud. When the bundled postgresql subchart is not
the source (external/disabled), the host helper returns empty, so the operator MUST set
<component>.configmap.DB_HOST. On the bundled path the host is derived; the gate does not fire.
Input (dict): context (root .), component (component key under .Values).
*/}}
{{- define "plugin-br-pix-indirect-btg.dbHostRequired" -}}
{{- $ctx := .context -}}
{{- $comp := .component -}}
{{- $cfg := default dict (index $ctx.Values $comp "configmap") -}}
{{- if and (ne (include "plugin-br-pix-indirect-btg.postgresInternal" $ctx) "true") (not $cfg.DB_HOST) -}}
{{- fail (printf "\n\nERROR: %s.configmap.DB_HOST is REQUIRED when the bundled postgresql subchart is disabled or external.\n   The in-cluster Service name is not derived on the external path.\n   Set %s.configmap.DB_HOST to the external PostgreSQL host.\n" $comp $comp) -}}
{{- end -}}
{{- end }}

{{/*
plugin-br-pix-indirect-btg.mongoHostRequired — fail-loud gate for MongoDB, mirror of the postgres
host gate. Only invoked for components that consume MongoDB.
Input (dict): context (root .), component (component key under .Values).
*/}}
{{- define "plugin-br-pix-indirect-btg.mongoHostRequired" -}}
{{- $ctx := .context -}}
{{- $comp := .component -}}
{{- $cfg := default dict (index $ctx.Values $comp "configmap") -}}
{{- if and (ne (include "plugin-br-pix-indirect-btg.mongoInternal" $ctx) "true") (not $cfg.MONGO_HOST) -}}
{{- fail (printf "\n\nERROR: %s.configmap.MONGO_HOST is REQUIRED when the bundled mongodb subchart is disabled or external.\n   Set %s.configmap.MONGO_HOST to the external MongoDB host.\n" $comp $comp) -}}
{{- end -}}
{{- end }}

{{/*
plugin-br-pix-indirect-btg.infraEnv — emit the discrete infra-password env entries for a component
container, single-sourced.
- DB_PASSWORD / DB_REPLICA_PASSWORD: bundled postgresql -> secretKeyRef to <dep>/password (the
  auth.username user; postgres is standalone here so the replica reuses the same Secret/key).
  External/disabled with operator DB_PASSWORD -> secretKeyRef to the component Secret. With
  postgresql.auth.existingSecret -> that Secret/password.
- MONGO_PASSWORD (only when the component declares it in secrets): bundled mongodb -> secretKeyRef
  to <dep>/mongodb-root-password (the app connects as the root user pix_btg). External/disabled with
  operator MONGO_PASSWORD -> component Secret. With mongodb.auth.existingSecret -> that Secret/mongodb-root-password.
The fail-loud gates above guarantee a credential exists before this emits a component-Secret ref.
On the external path with the component's own useExistingSecrets, the discrete entry is SKIPPED: the
app Secret is not rendered (so a fullname ref would dangle) and the operator's existing Secret already
delivers the key via envFrom. The bundled path always emits the subchart ref, which wins over envFrom
(discrete env beats envFrom), keeping the subchart Secret the single source even when an existing app
Secret is also mounted.
Input (dict): context (root .), component (component key), secretName (component Secret name for the external+inline fallback).
*/}}
{{- define "plugin-br-pix-indirect-btg.infraEnv" -}}
{{- $ctx := .context -}}
{{- $comp := .component -}}
{{- $secretName := .secretName -}}
{{- $pgInternal := eq (include "plugin-br-pix-indirect-btg.postgresInternal" $ctx) "true" -}}
{{- $pgAuth := default dict (index $ctx.Values "postgresql" "auth") -}}
{{- $compSecrets := default dict (index $ctx.Values $comp "secrets") -}}
{{- $usesExisting := eq (include "plugin-br-pix-indirect-btg.compUsesExistingSecret" (dict "context" $ctx "component" $comp)) "true" -}}
{{- if or $pgInternal $pgAuth.existingSecret }}
{{ include "plugin-br-pix-indirect-btg.infraSecretRef" (dict "context" $ctx "subchart" "postgresql" "key" "password" "envName" "DB_PASSWORD") }}
{{ include "plugin-br-pix-indirect-btg.infraSecretRef" (dict "context" $ctx "subchart" "postgresql" "key" "password" "envName" "DB_REPLICA_PASSWORD") }}
{{- else if not $usesExisting }}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: DB_PASSWORD
- name: DB_REPLICA_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: DB_REPLICA_PASSWORD
{{- end }}
{{- if hasKey $compSecrets "MONGO_PASSWORD" }}
{{- $mongoInternal := eq (include "plugin-br-pix-indirect-btg.mongoInternal" $ctx) "true" -}}
{{- $mongoAuth := default dict (index $ctx.Values "mongodb" "auth") -}}
{{- if or $mongoInternal $mongoAuth.existingSecret }}
{{ include "plugin-br-pix-indirect-btg.infraSecretRef" (dict "context" $ctx "subchart" "mongodb" "key" "mongodb-root-password" "envName" "MONGO_PASSWORD") }}
{{- else if not $usesExisting }}
- name: MONGO_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: MONGO_PASSWORD
{{- end }}
{{- end }}
{{- end }}

{{/*
plugin-br-pix-indirect-btg.dbSecretData — emit DB_PASSWORD / DB_REPLICA_PASSWORD app-Secret data
entries ONLY on the external/disabled postgresql path (operator supplies them inline). On the bundled
path the password lives in the subchart Secret and these emit nothing (avoids double-definition).
Input (dict): context (root .), component (component key).
*/}}
{{- define "plugin-br-pix-indirect-btg.dbSecretData" -}}
{{- $ctx := .context -}}
{{- $comp := .component -}}
{{- $pgAuth := default dict (index $ctx.Values "postgresql" "auth") -}}
{{- $secrets := default dict (index $ctx.Values $comp "secrets") -}}
{{- if and (ne (include "plugin-br-pix-indirect-btg.postgresInternal" $ctx) "true") (not $pgAuth.existingSecret) -}}
DB_PASSWORD: {{ $secrets.DB_PASSWORD | default "" | toString | b64enc | quote }}
DB_REPLICA_PASSWORD: {{ $secrets.DB_REPLICA_PASSWORD | default "" | toString | b64enc | quote }}
{{- end -}}
{{- end }}

{{/*
plugin-br-pix-indirect-btg.mongoSecretData — emit MONGO_PASSWORD app-Secret data entry ONLY on the
external/disabled mongodb path. On the bundled path it lives in the subchart Secret.
Input (dict): context (root .), component (component key).
*/}}
{{- define "plugin-br-pix-indirect-btg.mongoSecretData" -}}
{{- $ctx := .context -}}
{{- $comp := .component -}}
{{- $mongoAuth := default dict (index $ctx.Values "mongodb" "auth") -}}
{{- $secrets := default dict (index $ctx.Values $comp "secrets") -}}
{{- if and (ne (include "plugin-br-pix-indirect-btg.mongoInternal" $ctx) "true") (not $mongoAuth.existingSecret) -}}
MONGO_PASSWORD: {{ $secrets.MONGO_PASSWORD | default "" | toString | b64enc | quote }}
{{- end -}}
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
{{- fail "\n\nERROR: pix.configmap.BTG_BASE_URL is required. Set your BTG API URL (e.g., https://api.btgpactual.com or https://api.sandbox.developer.btgpactual.com).\n" }}
{{- end }}

{{- if not .Values.pix.configmap.PIX_ISPB }}
{{- fail "\n\nERROR: pix.configmap.PIX_ISPB is required. Set your bank's ISPB (8-digit code).\n" }}
{{- end }}

{{/* Midaz Configuration - Required */}}
{{- if not .Values.pix.configmap.MIDAZ_ORGANIZATION_ID }}
{{- fail "\n\nERROR: pix.configmap.MIDAZ_ORGANIZATION_ID is required. Set your Midaz organization ID.\n" }}
{{- end }}

{{- if not .Values.pix.configmap.MIDAZ_LEDGER_ID }}
{{- fail "\n\nERROR: pix.configmap.MIDAZ_LEDGER_ID is required. Set your Midaz ledger ID.\n" }}
{{- end }}

{{/* BTG Secrets - Required */}}
{{- if not .Values.pix.secrets.BTG_CLIENT_ID }}
{{- fail "\n\nERROR: pix.secrets.BTG_CLIENT_ID is required. Set your BTG client ID in secrets section.\n" }}
{{- end }}

{{- if not .Values.pix.secrets.BTG_CLIENT_SECRET }}
{{- fail "\n\nERROR: pix.secrets.BTG_CLIENT_SECRET is required. Set your BTG client secret in secrets section.\n" }}
{{- end }}

{{/* HMAC Internal Webhook Secret - Required (shared between pix and inbound) */}}
{{- if not .Values.pix.secrets.INTERNAL_WEBHOOK_SECRET }}
{{- fail "\n\nERROR: pix.secrets.INTERNAL_WEBHOOK_SECRET is required. Set your HMAC internal webhook secret (minimum 32 characters). This value is shared between pix and inbound components.\n" }}
{{- end }}

{{/* Midaz Secrets - Required */}}
{{- if not .Values.pix.secrets.MIDAZ_CLIENT_ID }}
{{- fail "\n\nERROR: pix.secrets.MIDAZ_CLIENT_ID is required. Set your Midaz client ID in secrets section.\n" }}
{{- end }}

{{- if not .Values.pix.secrets.MIDAZ_CLIENT_SECRET }}
{{- fail "\n\nERROR: pix.secrets.MIDAZ_CLIENT_SECRET is required. Set your Midaz client secret in secrets section.\n" }}
{{- end }}

{{/* License - Required */}}
{{- if not .Values.pix.secrets.LICENSE_KEY }}
{{- fail "\n\nERROR: pix.secrets.LICENSE_KEY is required. Set your license key in secrets section.\n" }}
{{- end }}

{{/* Organization IDs - Required */}}
{{- if not .Values.pix.configmap.ORGANIZATION_IDS }}
{{- fail "\n\nERROR: pix.configmap.ORGANIZATION_IDS is required. Set your organization IDs (comma-separated list or 'global' for all organizations).\n" }}
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
