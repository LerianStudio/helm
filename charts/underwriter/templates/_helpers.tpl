{{/*
Expand the name of the chart.
*/}}
{{- define "underwriter.name" -}}
{{- default (default "underwriter" .Values.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name for underwriter.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "underwriter.fullname" -}}
{{- default (include "underwriter.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "underwriter.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create underwriter app version
*/}}
{{- define "underwriter.defaultTag" -}}
{{- default .Chart.AppVersion .Values.underwriter.image.tag }}
{{- end -}}

{{/*
Return valid underwriter version label
*/}}
{{- define "underwriter.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "underwriter.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "underwriter.labels" -}}
helm.sh/chart: {{ include "underwriter.chart" .context }}
{{ include "underwriter.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "underwriter.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "underwriter.selectorLabels" -}}
app.kubernetes.io/name: {{ include "underwriter.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "underwriter.serviceAccountName" -}}
{{- if .Values.underwriter.serviceAccount.create }}
{{- default (include "underwriter.fullname" .) .Values.underwriter.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.underwriter.serviceAccount.name }}
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
{{- define "underwriter.infraSecretRef" -}}
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
underwriter.dbPasswordRequired — fail-loud gate. When the bundled postgresql subchart is NOT the
source (external or disabled) and no operator credential or existingSecret is supplied, fail the
render naming the exact value. On the bundled path the password comes from the subchart Secret, so
the gate does not fire. Stands down when the operator supplies an existing app Secret via
underwriter.useExistingSecret + existingSecretName (delivered through envFrom).
*/}}
{{- define "underwriter.dbPasswordRequired" -}}
{{- $pg := .Values.postgresql | default dict -}}
{{- $pgAuth := $pg.auth | default dict -}}
{{- $internal := and (ne (toString $pg.enabled) "false") (not $pg.external) -}}
{{- $usesExisting := and .Values.underwriter.useExistingSecret .Values.underwriter.existingSecretName -}}
{{- if and (not $internal) (not $pgAuth.existingSecret) (not .Values.underwriter.secrets.POSTGRES_PASSWORD) (not $usesExisting) -}}
{{- fail "\n\nERROR: underwriter.secrets.POSTGRES_PASSWORD is REQUIRED when the bundled postgresql subchart is disabled or external.\n   Set underwriter.secrets.POSTGRES_PASSWORD, set postgresql.auth.existingSecret, or provide it via underwriter.useExistingSecret + underwriter.existingSecretName.\n" -}}
{{- end -}}
{{- end }}

{{/*
underwriter.redisPasswordRequired — fail-loud gate for Valkey. Only fires when valkey auth is
enabled AND the bundled subchart is NOT the source (external or disabled) AND no operator credential
or existingSecret is supplied. When valkey auth is disabled no REDIS_PASSWORD is wired at all, so the
gate stays silent. Stands down on the existing-app-Secret path (envFrom).
*/}}
{{- define "underwriter.redisPasswordRequired" -}}
{{- $vk := .Values.valkey | default dict -}}
{{- $vkAuth := $vk.auth | default dict -}}
{{- $internal := and (ne (toString $vk.enabled) "false") (not $vk.external) -}}
{{- $usesExisting := and .Values.underwriter.useExistingSecret .Values.underwriter.existingSecretName -}}
{{- if and $vkAuth.enabled (not $internal) (not $vkAuth.existingSecret) (not .Values.underwriter.secrets.REDIS_PASSWORD) (not $usesExisting) -}}
{{- fail "\n\nERROR: underwriter.secrets.REDIS_PASSWORD is REQUIRED when valkey auth is enabled but the bundled subchart is disabled or external.\n   Set underwriter.secrets.REDIS_PASSWORD, set valkey.auth.existingSecret, or use underwriter.useExistingSecret + existingSecretName.\n" -}}
{{- end -}}
{{- end }}

{{/*
underwriter.postgresqlInternal — true when the bundled Bitnami postgresql subchart provides the DB.
*/}}
{{- define "underwriter.postgresqlInternal" -}}
{{- $pg := default dict .Values.postgresql -}}
{{- if and (ne (toString $pg.enabled) "false") (not $pg.external) -}}true{{- else -}}false{{- end -}}
{{- end }}

{{/*
underwriter.valkeyInternal — true when the bundled Bitnami valkey subchart provides the cache.
*/}}
{{- define "underwriter.valkeyInternal" -}}
{{- $vk := default dict .Values.valkey -}}
{{- if and (ne (toString $vk.enabled) "false") (not $vk.external) -}}true{{- else -}}false{{- end -}}
{{- end }}

{{/*
underwriter.postgresqlHost — collapse-aware default for POSTGRES_HOST. The bundled PostgreSQL uses
`architecture: replication`, so the primary Service is `<dependency-fullname>-primary`. When the
bundled subchart is enabled, resolve the base via Bitnami's own helper so it matches the
collapse/override rules (release name containing "postgresql", nameOverride, fullnameOverride). On
the external path the subchart templates are not loaded, so common.names.dependency.fullname is out
of scope — fall back to self-contained logic mirroring it.
*/}}
{{- define "underwriter.postgresqlHost" -}}
{{- $pg := default dict .Values.postgresql -}}
{{- $base := "" -}}
{{- if eq (include "underwriter.postgresqlInternal" .) "true" -}}
{{- $base = include "common.names.dependency.fullname" (dict "chartName" "postgresql" "chartValues" $pg "context" .) -}}
{{- else if $pg.fullnameOverride -}}
{{- $base = $pg.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "postgresql" $pg.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- $base = .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $base = printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- printf "%s-primary" $base -}}
{{- end }}

{{/*
underwriter.valkeyHost — collapse-aware default for REDIS_HOST (host:port). The bundled Valkey uses
`architecture: replication`, so the primary Service is `<dependency-fullname>-primary`. Resolution
mirrors underwriter.postgresqlHost; the `:6379` port is appended to match the previous default.
*/}}
{{- define "underwriter.valkeyHost" -}}
{{- $vk := default dict .Values.valkey -}}
{{- $base := "" -}}
{{- if eq (include "underwriter.valkeyInternal" .) "true" -}}
{{- $base = include "common.names.dependency.fullname" (dict "chartName" "valkey" "chartValues" $vk "context" .) -}}
{{- else if $vk.fullnameOverride -}}
{{- $base = $vk.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "valkey" $vk.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- $base = .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $base = printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- printf "%s-primary:6379" $base -}}
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
