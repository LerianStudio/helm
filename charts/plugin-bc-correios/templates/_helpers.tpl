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
bc-correios.valkeyPasswordFromSubchart — renders "true" when CACHE_PASSWORD must be read from the
Valkey Secret via secretKeyRef instead of the app Secret: the bundled Bitnami Valkey with auth enabled
(it generates and enforces its own password), or any Valkey with valkey.auth.existingSecret set while
the bundled one is off (external Valkey whose password lives in an existing Secret). Renders nothing
otherwise (bundled Valkey with auth.enabled=false, or external Valkey without existingSecret), in which
case CACHE_PASSWORD comes from bc-correios.secrets.CACHE_PASSWORD through envFrom.
*/}}
{{- define "bc-correios.valkeyPasswordFromSubchart" -}}
{{- $vk := .Values.valkey | default dict -}}
{{- $auth := $vk.auth | default dict -}}
{{- $bundled := and (ne (toString $vk.enabled) "false") (not $vk.external) -}}
{{- if or (and $bundled (ne (toString $auth.enabled) "false")) (and (not $bundled) $auth.existingSecret) -}}
true
{{- end -}}
{{- end }}

{{/*
bc-correios.valkeyPasswordKey — data key holding the Valkey password. Mirrors the subchart: only
valkey.auth.existingSecretPasswordKey (honoured together with existingSecret), else "valkey-password".
*/}}
{{- define "bc-correios.valkeyPasswordKey" -}}
{{- $auth := (.Values.valkey | default dict).auth | default dict -}}
{{- if and $auth.existingSecret $auth.existingSecretPasswordKey -}}
{{- $auth.existingSecretPasswordKey -}}
{{- else -}}
valkey-password
{{- end -}}
{{- end }}

{{/*
bc-correios.envName — the ENV_NAME the app reads: the operator value (configmap or extraEnvVars;
extraEnvVars win), "production" when neither is set.
*/}}
{{- define "bc-correios.envName" -}}
{{- $component := index .Values "bc-correios" -}}
{{- $cm := merge (deepCopy (default dict $component.extraEnvVars)) $component.configmap -}}
{{- default "production" $cm.ENV_NAME -}}
{{- end }}

{{/*
bc-correios.bootGuards — fail at render on config the app refuses at boot. Always: empty LICENSE_KEY
or blank STREAMING_BROKERS (unless useExistingSecret). ENV_NAME not "development": POSTGRES_SSLMODE
"disable", ALLOWED_ORIGINS empty or "*".
*/}}
{{- define "bc-correios.bootGuards" -}}
{{- $component := index .Values "bc-correios" -}}
{{- $cm := merge (deepCopy (default dict $component.extraEnvVars)) $component.configmap -}}
{{- if not $component.useExistingSecret -}}
{{- if not (trim (toString (default "" $cm.LICENSE_KEY))) -}}
{{- fail "\n\nERROR: bc-correios.configmap.LICENSE_KEY is required (the app refuses to start without a license in every environment). Set it, or put LICENSE_KEY in the Secret of bc-correios.useExistingSecret.\n" -}}
{{- end -}}
{{- if not (trim (replace "," "" (toString (default "" $cm.STREAMING_BROKERS)))) -}}
{{- fail "\n\nERROR: bc-correios.configmap.STREAMING_BROKERS is required (the app refuses to start without a streaming broker). Set it to the Kafka-API broker list, e.g. \"broker.example.com:9092\", or put STREAMING_BROKERS in the Secret of bc-correios.useExistingSecret.\n" -}}
{{- end -}}
{{- end -}}
{{- if ne (include "bc-correios.envName" .) "development" -}}
{{- if eq (default "disable" $cm.POSTGRES_SSLMODE) "disable" -}}
{{- fail "\n\nERROR: bc-correios.configmap.POSTGRES_SSLMODE must not be \"disable\" when ENV_NAME is not \"development\" (the app refuses to start). A development install sets bc-correios.configmap.ENV_NAME \"development\".\n   Set a TLS mode such as \"require\". The bundled PostgreSQL has TLS off: set postgresql.tls.enabled and postgresql.tls.autoGenerated to true, or use an external PostgreSQL with TLS.\n" -}}
{{- end -}}
{{- if has (default "*" $cm.ALLOWED_ORIGINS) (list "*") -}}
{{- fail "\n\nERROR: bc-correios.configmap.ALLOWED_ORIGINS must be set to explicit origins, not \"*\", when ENV_NAME is not \"development\" (the app refuses to start). A development install sets bc-correios.configmap.ENV_NAME \"development\".\n   Example: \"https://app.example.com\".\n" -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
A flag that defaults to "true". Sprig `default` treats an explicit boolean false
as empty, so a bool is rendered as-is. Input: the value.
*/}}
{{- define "bc-correios.flagDefaultTrue" -}}
{{- if kindIs "bool" . }}{{ . }}{{ else }}{{ . | default "true" }}{{ end -}}
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
