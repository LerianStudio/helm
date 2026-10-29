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
A flag that defaults to "true". Sprig `default` treats an explicit boolean false
as empty, so a bool is rendered as-is. Input: the value.
*/}}
{{- define "bank-transfer.flagDefaultTrue" -}}
{{- if kindIs "bool" . }}{{ . }}{{ else }}{{ . | default "true" }}{{ end -}}
{{- end }}

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
bank-transfer.migrationPostgresPassword — POSTGRES_PASSWORD for the migration-only Secret.
migration-secret.yaml renders ONLY on the EXTERNAL Postgres path (the bundled subchart path
never renders it; it reads the subchart Secret via secretKeyRef instead), so there is no
subchart Secret to single-source from here and the operator MUST supply the password. Kept as
a named gate helper (not an inline `required` in the Secret template) per
docs/helm-chart-standard.md "Single-Source Infra Secrets" so the dual-secret static check passes.
*/}}
{{- define "bank-transfer.migrationPostgresPassword" -}}
{{- $secrets := get (.Values.bankTransfer | default dict) "secrets" | default dict -}}
{{- required "bankTransfer.secrets.POSTGRES_PASSWORD is required when migrations run against external PostgreSQL with a chart-managed Secret" (get $secrets "POSTGRES_PASSWORD") -}}
{{- end }}

{{/*
bank-transfer.postgresInternal — true when the bundled Bitnami postgresql subchart provides the
DB. It decides where migrations run: the hook Job (external) or the app pods (bundled).
*/}}
{{- define "bank-transfer.postgresInternal" -}}
{{- $pg := default dict .Values.postgresql -}}
{{- and (eq (lower (toString $pg.enabled)) "true") (ne (lower (toString $pg.external)) "true") -}}
{{- end }}

{{/*
bank-transfer.mongoInternal — true when the bundled Bitnami mongodb subchart provides the DB.
*/}}
{{- define "bank-transfer.mongoInternal" -}}
{{- $mongo := default dict .Values.mongodb -}}
{{- if and (ne (toString $mongo.enabled) "false") (not $mongo.external) -}}true{{- else -}}false{{- end -}}
{{- end }}

{{/*
bank-transfer.mongoEnv — the bundled MongoDB connection. The app reads only MONGO_URI, so the
deployment assembles it from a MONGO_PASSWORD env (secretKeyRef on the subchart Secret, or
mongodb.auth.existingSecret, key mongodb-passwords) via $(MONGO_PASSWORD) expansion; kubelet
expands only earlier literal env entries, so MONGO_PASSWORD MUST precede MONGO_URI. User and
authSource are mongodb.auth.usernames[0] / databases[0]; the host tracks the subchart's Bitnami
fullname. An explicit bankTransfer.secrets.MONGO_URI (external, or overriding the bundled one)
reaches the pod from the app Secret through envFrom, so nothing is emitted here for it.
Input (dict): context (root .).
*/}}
{{- define "bank-transfer.mongoEnv" -}}
{{- $ctx := .context -}}
{{- $mongo := default dict $ctx.Values.mongodb -}}
{{- $mongoAuth := default dict $mongo.auth -}}
{{- $mongoFullname := include "common.names.dependency.fullname" (dict "chartName" "mongodb" "chartValues" $mongo "context" $ctx) -}}
{{- if and (not $ctx.Values.bankTransfer.useExistingSecret) (eq (include "bank-transfer.mongoInternal" $ctx) "true") (not $ctx.Values.bankTransfer.secrets.MONGO_URI) }}
- name: MONGO_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ $mongoAuth.existingSecret | default $mongoFullname }}
      key: mongodb-passwords
- name: MONGO_URI
  value: {{ printf "mongodb://%s:$(MONGO_PASSWORD)@%s.%s.svc.cluster.local:27017/?authSource=%s" (first $mongoAuth.usernames) $mongoFullname (include "global.namespace" $ctx) (first $mongoAuth.databases) | quote }}
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
