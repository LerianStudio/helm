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
