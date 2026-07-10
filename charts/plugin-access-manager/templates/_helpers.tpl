{{/*
Expand the name of the chart and plugin identity.
*/}}
{{- define "plugin-identity.name" -}}
{{- default "plugin-access-manager-identity" .Values.identity.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart and plugin auth.
*/}}
{{- define "plugin-auth.name" -}}
{{- default "plugin-access-manager-auth" .Values.auth.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart and plugin auth.
*/}}
{{- define "plugin-auth-backend.name" -}}
{{- default "plugin-access-manager-auth-backend" .Values.auth.backend.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart and plugin auth ui.
*/}}
{{- define "plugin-auth-ui.name" -}}
{{- default "plugin-access-manager-auth-ui" .Values.auth.ui.name | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create chart name and version as used by the chart label for plugin identity.
*/}}
{{- define "plugin-identity.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin auth.
*/}}
{{- define "plugin-auth.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin auth.
*/}}
{{- define "plugin-auth-backend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin auth ui.
*/}}
{{- define "plugin-auth-ui.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name identity.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-identity.fullname" -}}
{{- default "plugin-access-manager-identity" .Values.identity.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name auth.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-auth.fullname" -}}
{{- default "plugin-access-manager-auth" .Values.auth.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name auth.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-auth-backend.fullname" -}}
{{- default "plugin-access-manager-auth-backend" .Values.auth.backend.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name auth ui.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-auth-ui.fullname" -}}
{{- default "plugin-access-manager-auth-ui" .Values.auth.ui.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create app version.
*/}}
{{- define "plugin.version" -}}
{{- printf "%s" .Chart.AppVersion | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Identity Selector labels
*/}}
{{- define "plugin-identity.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-identity.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
Auth Selector labels
*/}}
{{- define "plugin-auth.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-auth.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
Auth Selector labels
*/}}
{{- define "plugin-auth-backend.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-auth-backend.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
Auth UI Selector labels
*/}}
{{- define "plugin-auth-ui.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-auth-ui.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
Identity Common labels
*/}}
{{- define "plugin-identity.labels" -}}
helm.sh/chart: {{ include "plugin-identity.chart" .context }}
{{ include "plugin-identity.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Auth Common labels
*/}}
{{- define "plugin-auth.labels" -}}
helm.sh/chart: {{ include "plugin-auth.chart" .context }}
{{ include "plugin-auth.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Auth Backend Common labels
*/}}
{{- define "plugin-auth-backend.labels" -}}
helm.sh/chart: {{ include "plugin-auth-backend.chart" .context }}
{{ include "plugin-auth-backend.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Auth UI Common labels
*/}}
{{- define "plugin-auth-ui.labels" -}}
helm.sh/chart: {{ include "plugin-auth-ui.chart" .context }}
{{ include "plugin-auth-ui.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Create the name of the identity service account to use
*/}}
{{- define "plugin-identity.serviceAccountName" -}}
{{- if .Values.identity.serviceAccount.create }}
{{- default (include "plugin-identity.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.identity.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the auth service account to use
*/}}
{{- define "plugin-auth.serviceAccountName" -}}
{{- if .Values.auth.serviceAccount.create }}
{{- default (include "plugin-auth.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.auth.serviceAccount.name }}
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
plugin-auth.dbPasswordEnv — emit a single `- name: <envName> valueFrom: secretKeyRef: {name,key}`
entry for the auth database password, single-sourced. With the bundled `auth-database`
(aliased Bitnami postgresql) subchart, it reads the generated Secret
(<release>-auth-database, key "password"); honors auth-database.auth.existingSecret; and
falls back to the app's plugin-auth Secret (key DB_PASSWORD) only for an external database.
Input (dict): context (root .), envName (container env var name, e.g. DB_PASSWORD or DB_PASS).
See docs/helm-chart-standard.md "Single-Source Infra Secrets".
*/}}
{{- define "plugin-auth.dbPasswordEnv" -}}
{{- $ctx := .context -}}
{{- $db := default dict (index $ctx.Values "auth-database") -}}
{{- $dbAuth := default dict $db.auth -}}
{{- $internal := and (ne (toString $db.enabled) "false") (not $db.external) -}}
- name: {{ .envName }}
  valueFrom:
    secretKeyRef:
    {{- if $dbAuth.existingSecret }}
      name: {{ $dbAuth.existingSecret }}
      key: password
    {{- else if $internal }}
      name: {{ include "common.names.dependency.fullname" (dict "chartName" "auth-database" "chartValues" (index $ctx.Values "auth-database") "context" $ctx) }}
      key: password
    {{- else }}
      {{- if not $ctx.Values.auth.useExistingSecret }}{{- $_ := required "\n\nERROR: auth-database is external or disabled.\n   The DB password is no longer single-sourced from the subchart Secret, so you must provide it.\n   Set auth.secrets.DB_PASSWORD, or point auth-database.auth.existingSecret at an external Secret.\n" $ctx.Values.auth.secrets.DB_PASSWORD -}}{{- end }}
      name: {{ if $ctx.Values.auth.useExistingSecret }}{{ required "\n\nERROR: auth.useExistingSecret is true but auth.existingSecretName is empty.\n   Set auth.existingSecretName to the name of the Secret holding DB_PASSWORD.\n" $ctx.Values.auth.existingSecretName }}{{ else }}{{ include "plugin-auth.fullname" $ctx }}{{ end }}
      key: DB_PASSWORD
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
