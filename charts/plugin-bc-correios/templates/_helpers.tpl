{{/*
Expand the name of the chart.
*/}}
{{- define "bc-correios.name" -}}
{{- default (default "bc-correios" .Values.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name for bc-correios.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "bc-correios.fullname" -}}
{{- default (include "bc-correios.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "bc-correios.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create bc-correios app version
*/}}
{{- define "bc-correios.defaultTag" -}}
{{- $component := index .Values "bc-correios" -}}
{{- default .Chart.AppVersion $component.image.tag }}
{{- end -}}

{{/*
Return valid bc-correios version label
*/}}
{{- define "bc-correios.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "bc-correios.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "bc-correios.labels" -}}
helm.sh/chart: {{ include "bc-correios.chart" .context }}
{{ include "bc-correios.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "bc-correios.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "bc-correios.selectorLabels" -}}
app.kubernetes.io/name: {{ include "bc-correios.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "bc-correios.serviceAccountName" -}}
{{- $component := index .Values "bc-correios" -}}
{{- if $component.serviceAccount.create }}
{{- default (include "bc-correios.fullname" .) $component.serviceAccount.name }}
{{- else }}
{{- default "default" $component.serviceAccount.name }}
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
bc-correios.infraSecretRef — emit a `- name: <envName> valueFrom: secretKeyRef: {name,key}` entry
pointing at a Bitnami subchart's generated Secret (or the operator's existingSecret override).
Inputs (dict): context (root .), subchart, key, envName.
See docs/helm-chart-standard.md "Single-Source Infra Secrets".
*/}}
{{- define "bc-correios.infraSecretRef" -}}
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
bc-correios.rabbitmqErlangCookieRequired — fail when the bundled groundhog2k rabbitmq subchart is
enabled but no erlang cookie is provided. The broker is pointed at the app Secret via
authentication.existingSecret, which sources the cookie from secretKey RABBITMQ_ERLANG_COOKIE, so a
stable operator-provided cookie is mandatory for clustering across restarts. Stands down when the
bundled broker is disabled/external or an existing app Secret is used (useExistingSecret).
*/}}
{{- define "bc-correios.rabbitmqErlangCookieRequired" -}}
{{- $component := index .Values "bc-correios" -}}
{{- $rmq := default dict .Values.rabbitmq -}}
{{- $rmqEnabled := ne (toString $rmq.enabled) "false" -}}
{{- if and $rmqEnabled (not $component.useExistingSecret) (not $component.secrets.RABBITMQ_ERLANG_COOKIE) -}}
{{- fail "\n\nERROR: bc-correios.secrets.RABBITMQ_ERLANG_COOKIE is REQUIRED when the bundled rabbitmq subchart is enabled.\n   The broker reads its Erlang cookie from the application Secret (single source).\n   Provide a stable value (it must not change across upgrades) e.g.: openssl rand -hex 32\n" -}}
{{- end -}}
{{- end }}

{{/*
bc-correios.rabbitmqExistingSecretConsistent — fail when the bundled rabbitmq subchart is enabled and
still carries the SHIPPED DEFAULT authentication.existingSecret ("bc-correios") but the app Secret has
been renamed (fullnameOverride / nameOverride), so the broker would reference a Secret that does not
exist. values.yaml cannot template, so this render-time gate catches the drift. Custom (non-default)
existingSecret values are the operator's responsibility and pass untouched.
*/}}
{{- define "bc-correios.rabbitmqExistingSecretConsistent" -}}
{{- $rmq := default dict .Values.rabbitmq -}}
{{- $rmqEnabled := ne (toString $rmq.enabled) "false" -}}
{{- $auth := default dict $rmq.authentication -}}
{{- $secretName := include "bc-correios.fullname" . -}}
{{- if and $rmqEnabled (eq (default "" $auth.existingSecret) "bc-correios") (ne $secretName "bc-correios") -}}
{{- fail (printf "\n\nERROR: rabbitmq.authentication.existingSecret is still the shipped default \"bc-correios\" but the app Secret renders as %q.\n   The broker would reference a Secret that does not exist.\n   Update rabbitmq.authentication.existingSecret to %q (or set it to your own existing Secret).\n" $secretName $secretName) -}}
{{- end -}}
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

{{- define "seaweedfs.enabled" -}}
{{- if .Values.seaweedfs.enabled -}}
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
