{{/*
Expand the name of the chart.
*/}}
{{- define "system-facts.name" -}}
{{- default "system-facts" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name for boilerplate.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "system-facts.fullname" -}}
{{- default (include "system-facts.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "system-facts.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create boilerplate app version
*/}}
{{- define "system-facts.defaultTag" -}}
{{- default .Chart.AppVersion (index .Values "system-facts").image.tag }}
{{- end -}}

{{/*
Return valid boilerplate version label
*/}}
{{- define "system-facts.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "system-facts.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "system-facts.labels" -}}
helm.sh/chart: {{ include "system-facts.chart" .context }}
{{ include "system-facts.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "system-facts.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- include "system-facts.extraCommonLabels" .context }}
{{- end }}

{{/*
User-supplied .Values.commonLabels, one "key: value" per line, each line led by
a newline so it can be appended to a labels block. Never part of selectorLabels:
selectors are immutable and must not change with extra labels.
*/}}
{{- define "system-facts.extraCommonLabels" -}}
{{- range $k, $v := .Values.commonLabels }}
{{ $k }}: {{ $v | quote }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "system-facts.selectorLabels" -}}
app.kubernetes.io/name: {{ include "system-facts.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "system-facts.serviceAccountName" -}}
{{- if (index .Values "system-facts").serviceAccount.create }}
{{- default (include "system-facts.fullname" .) (index .Values "system-facts").serviceAccount.name }}
{{- else }}
{{- default "default" (index .Values "system-facts").serviceAccount.name }}
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
Env entry reading a datastore password straight from the bundled subchart's own
Secret. Used only when that subchart is enabled: the app's own Secret then never
carries a duplicate of the password, and nothing has to be kept in sync.

`env` beats `envFrom` in Kubernetes for the same variable name, so emitting this
alongside the existing `envFrom: secretRef` is what makes the subchart's
password win over anything inherited from the app Secret.
*/}}
{{- define "system-facts.infraSecretRef" -}}
{{- $ctx := .context -}}
{{- $sub := .subchart -}}
{{- $vals := default dict (index $ctx.Values $sub) -}}
{{- $auth := default dict $vals.auth -}}
{{- $globalAuth := dig $sub "auth" dict (default dict $ctx.Values.global) -}}
{{/*
Secret name, in the same precedence the Bitnami subcharts themselves use:
the subchart's own auth.existingSecret, then the global.<sub>.auth.existingSecret
form, then the name the subchart generates. Resolving only the first would point
at a generated Secret that was never created whenever an operator supplied their
own through either of the other two.
*/}}
{{- $secretName := "" -}}
{{- if $auth.existingSecret -}}
{{- $secretName = $auth.existingSecret -}}
{{- else if $globalAuth.existingSecret -}}
{{- $secretName = $globalAuth.existingSecret -}}
{{- else -}}
{{- $secretName = include "common.names.dependency.fullname" (dict "chartName" $sub "chartValues" $vals "context" $ctx) -}}
{{- end -}}
{{/*
Key name. `.key` is only the fallback: both subcharts let the key be renamed,
and a hardcoded one resolves to a missing key that blocks startup.
  postgresql -> auth.secretKeys.userPasswordKey  (default "password")
  valkey     -> auth.existingSecretPasswordKey   (honoured with an existing secret)
*/}}
{{- $key := .key -}}
{{- if eq $sub "postgresql" -}}
{{- $key = dig "secretKeys" "userPasswordKey" $key $auth -}}
{{- else if and (eq $sub "valkey") $auth.existingSecretPasswordKey -}}
{{- $key = $auth.existingSecretPasswordKey -}}
{{- end -}}
- name: {{ .envName }}
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: {{ $key }}
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
