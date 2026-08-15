{{/*
Expand the name of the chart.
*/}}
{{- define "br-ccs.name" -}}
{{- default (default "br-ccs" .Values.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name for br-ccs.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "br-ccs.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default "br-ccs" .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "br-ccs.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create br-ccs app version
*/}}
{{- define "br-ccs.defaultTag" -}}
{{- default .Chart.AppVersion .Values.brCcs.image.tag }}
{{- end -}}

{{/*
Return valid br-ccs version label
*/}}
{{- define "br-ccs.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "br-ccs.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "br-ccs.labels" -}}
helm.sh/chart: {{ include "br-ccs.chart" .context }}
{{ include "br-ccs.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "br-ccs.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "br-ccs.selectorLabels" -}}
app.kubernetes.io/name: {{ include "br-ccs.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "br-ccs.serviceAccountName" -}}
{{- if .Values.brCcs.serviceAccount.create }}
{{- default (include "br-ccs.fullname" .) .Values.brCcs.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.brCcs.serviceAccount.name }}
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
br-ccs.postgresql.internal — single source of truth for the "bundled (internal)
PostgreSQL subchart" decision. Internal means postgresql.enabled is not
explicitly false AND postgresql.external is not truthy. Every template that
branches on internal vs external Postgres MUST use this helper so the decision
never drifts between manifests.
*/}}
{{- define "br-ccs.postgresql.internal" -}}
{{- $pg := .Values.postgresql | default dict -}}
{{- if and (ne (toString $pg.enabled) "false") (not $pg.external) -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
br-ccs.infraSecretRef — emit a `- name: <envName> valueFrom: secretKeyRef: {name,key}`
entry pointing at a Bitnami subchart's generated Secret (or the operator's existingSecret
override). Inputs (dict): context (root .), subchart, key, envName.
*/}}
{{- define "br-ccs.infraSecretRef" -}}
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
br-ccs.migrationPostgresPassword — POSTGRES_PASSWORD for the migration-only Secret.
migration-secret.yaml renders ONLY on the EXTERNAL Postgres path (the bundled subchart path
reads the subchart Secret via secretKeyRef instead), so the operator MUST supply the password.
*/}}
{{- define "br-ccs.migrationPostgresPassword" -}}
{{- $secrets := get (.Values.brCcs | default dict) "secrets" | default dict -}}
{{- required "brCcs.secrets.POSTGRES_PASSWORD is required when migrations run against external PostgreSQL with a chart-managed Secret" (get $secrets "POSTGRES_PASSWORD") -}}
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
