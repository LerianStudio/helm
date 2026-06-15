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
These helpers check both .enabled and .external flags
*/}}
{{- define "rabbitmq.enabled" -}}
{{- if and (default true .Values.rabbitmq.enabled) (not .Values.rabbitmq.external) -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{- define "valkey.enabled" -}}
{{- if and (default true .Values.valkey.enabled) (not .Values.valkey.external) -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{- define "postgresql.enabled" -}}
{{- if and (default true .Values.postgresql.enabled) (not .Values.postgresql.external) -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{- define "mongodb.enabled" -}}
{{- if and (default true .Values.mongodb.enabled) (not .Values.mongodb.external) -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
bank-transfer.infraSecretRef — emit a `- name: <envName> valueFrom: secretKeyRef: {name,key}`
entry pointing at a Bitnami subchart's generated Secret (or the operator's existingSecret
override). Inputs (dict): context (root .), subchart, key, envName.
See docs/helm-chart-standard.md "Single-Source Infra Secrets".
*/}}
{{- define "bank-transfer.infraSecretRef" -}}
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
bank-transfer.mongoInternal — true when the bundled Bitnami mongodb subchart provides the DB.
*/}}
{{- define "bank-transfer.mongoInternal" -}}
{{- $mongo := default dict .Values.mongodb -}}
{{- if and (ne (toString $mongo.enabled) "false") (not $mongo.external) -}}true{{- else -}}false{{- end -}}
{{- end }}

{{/*
bank-transfer.mongoEnv — single-source the MongoDB connection.
Emits a MONGO_PASSWORD env (secretKeyRef) followed by a MONGO_URI env that references it via
$(MONGO_PASSWORD) shell-style expansion (Kubernetes expands against earlier env entries in the
same list, so MONGO_PASSWORD MUST precede MONGO_URI). The app is URI-only, so the URI is
assembled here rather than embedding a plaintext password in the Secret.
- Bundled subchart: MONGO_PASSWORD <- the mongodb subchart Secret / mongodb-passwords (user bank_transfer).
- existingSecret override: MONGO_PASSWORD <- <existingSecret> / mongodb-passwords.
- External inline: MONGO_PASSWORD <- app Secret / MONGO_PASSWORD.
If the operator sets bankTransfer.secrets.MONGO_URI explicitly, that wins and is emitted verbatim
(no $(MONGO_PASSWORD) assembly). The host tracks the mongodb subchart's Bitnami fullname (Service and
Secret names share it, honoring nameOverride/fullnameOverride and the name-collapse rule).
Input (dict): context (root .), secretName (app Secret name for the external-inline fallback).
*/}}
{{- define "bank-transfer.mongoEnv" -}}
{{- $ctx := .context -}}
{{- $ns := include "global.namespace" $ctx -}}
{{- $mongo := default dict $ctx.Values.mongodb -}}
{{- $mongoAuth := default dict $mongo.auth -}}
{{- $internal := eq (include "bank-transfer.mongoInternal" $ctx) "true" -}}
{{- $mongoFullname := include "common.names.dependency.fullname" (dict "chartName" "mongodb" "chartValues" $mongo "context" $ctx) -}}
{{- if not $ctx.Values.bankTransfer.useExistingSecret }}
{{- if or $internal $mongoAuth.existingSecret }}
{{- $secretName := $mongoAuth.existingSecret | default $mongoFullname }}
- name: MONGO_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: mongodb-passwords
{{- else if $ctx.Values.bankTransfer.secrets.MONGO_PASSWORD }}
- name: MONGO_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .secretName }}
      key: MONGO_PASSWORD
{{- end }}
{{- if $ctx.Values.bankTransfer.secrets.MONGO_URI }}
- name: MONGO_URI
  value: {{ $ctx.Values.bankTransfer.secrets.MONGO_URI | quote }}
{{- else if $internal }}
- name: MONGO_URI
  value: {{ printf "mongodb://bank_transfer:$(MONGO_PASSWORD)@%s.%s.svc.cluster.local:27017/?authSource=admin" $mongoFullname $ns | quote }}
{{- end }}
{{- end }}
{{- end }}


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
