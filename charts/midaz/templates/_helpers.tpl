{{/*
Expand the name of the chart.
*/}}
{{- define "midaz.name" -}}
{{- default (default "midaz" .Values.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "midaz-grafana.fullname" -}}
{{- printf "%s-%s" (include "midaz.name" .) .Values.grafana.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "midaz.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "midaz.labels" -}}
helm.sh/chart: {{ include "midaz.chart" .context }}
{{ include "midaz.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "ledger.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "midaz.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "midaz.name" .context }}-{{ .name }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}


{{/*
Create a default fully qualified app name for ledger.
*/}}
{{- define "midaz-ledger.fullname" -}}
{{- printf "%s-%s" (include "midaz.name" .) .Values.ledger.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create ledger app version
*/}}
{{- define "ledger.defaultTag" -}}
{{- default .Chart.AppVersion .Values.ledger.image.tag }}
{{- end -}}

{{/*
Return valid ledger version label
*/}}
{{- define "ledger.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "ledger.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Create the name of the service account to use for ledger
*/}}
{{- define "midaz-ledger.serviceAccountName" -}}
{{- if .Values.ledger.serviceAccount.create }}
{{- default (include "midaz-ledger.fullname" .) .Values.ledger.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.ledger.serviceAccount.name }}
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
infraSecretRef — emit a `- name: <envName> valueFrom: secretKeyRef: {name,key}` env entry
pointing at a Bitnami subchart's generated Secret (or the operator's existingSecret override).
Inputs (dict): context (root .), subchart, key, envName.
See docs/helm-chart-standard.md "Single-Source Infra Secrets".
*/}}
{{- define "midaz.infraSecretRef" -}}
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
midaz.mongodbAuthRequired — fail when the bundled Bitnami mongodb subchart is internal
(enabled and not external) but mongodb.auth.enabled is disabled and no mongodb.auth.existingSecret
is provided. Bitnami's mongodb emits NO `<release>-mongodb` Secret when auth.enabled=false (its
secrets.yaml is wrapped in `if .Values.auth.enabled`), yet ledger and crm still reference
`mongodb-root-password` via secretKeyRef — a dangling ref that yields CreateContainerConfigError.
Fail loud at render time so the operator fixes the configuration.
*/}}
{{- define "midaz.mongodbAuthRequired" -}}
{{- $mongo := .Values.mongodb | default dict -}}
{{- $mongoAuth := $mongo.auth | default dict -}}
{{- if and (ne (toString $mongo.enabled) "false") (not $mongo.external) (not $mongoAuth.enabled) (not $mongoAuth.existingSecret) -}}
{{- fail "\n\nERROR: mongodb.auth.enabled is REQUIRED when the bundled mongodb subchart is internal.\n   ledger and crm read MONGO_*_PASSWORD from the mongodb Secret (single source), but Bitnami\n   mongodb creates no Secret when auth.enabled=false, leaving a dangling secretKeyRef.\n   Choose one: set mongodb.auth.enabled=true, or provide mongodb.auth.existingSecret, or set mongodb.external=true.\n" -}}
{{- end -}}
{{- end }}

{{/*
Create a default fully qualified app name for CRM.
*/}}
{{- define "midaz-crm.fullname" -}}
{{- printf "%s-%s" (include "midaz.name" .) .Values.crm.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create CRM app version
*/}}
{{- define "crm.defaultTag" -}}
{{- default .Chart.AppVersion .Values.crm.image.tag }}
{{- end -}}

{{/*
Return valid CRM version label
*/}}
{{- define "crm.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "crm.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
CRM Common labels
*/}}
{{- define "midaz-crm.labels" -}}
helm.sh/chart: {{ include "midaz.chart" .context }}
{{ include "midaz-crm.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "crm.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
CRM Selector labels
*/}}
{{- define "midaz-crm.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "midaz.name" .context }}-{{ .name }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
Enable internal dependencies
*/}}
{{- define "mongodb.enabled" -}}
{{- if not .Values.mongodb.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}
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
