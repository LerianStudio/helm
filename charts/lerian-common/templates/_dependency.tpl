{{/*
==============================================================================
lerian-common — subchart dependency helpers (PostgreSQL, Valkey, MongoDB,
RabbitMQ, SeaweedFS bundled via Bitnami-style subcharts).

These centralize logic each chart duplicates today:
  - dependency.fullname : the collapse-aware subchart resource name (vendored
    from Bitnami common; identical in ~16 charts). Consumers keep their existing
    `common.names.dependency.fullname` as a 1-line alias to this.
  - infraSecretRef      : a container env entry (secretKeyRef) that single-sources
    an infra password from the subchart's own Secret (external path uses an
    existingSecret). Duplicated in ~12 charts.
==============================================================================
*/}}

{{/*
lerian-common.dependency.fullname — collapse-aware "<release>-<name>" (honors
release-name collapse, nameOverride, fullnameOverride).
Inputs: chartName, chartValues, context.
*/}}
{{- define "lerian-common.dependency.fullname" -}}
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

{{/*
lerian-common.infraSecretRef — a single `env:` entry (secretKeyRef) sourcing an
infra password from the subchart Secret (or its existingSecret override).
Inputs: context, subchart, key (secret key), envName (container env var name).
*/}}
{{- define "lerian-common.infraSecretRef" -}}
{{- $ctx := .context -}}
{{- $sub := .subchart -}}
{{- $auth := default dict (index $ctx.Values $sub "auth") -}}
{{- $secretName := "" -}}
{{- if $auth.existingSecret -}}
{{- $secretName = $auth.existingSecret -}}
{{- else -}}
{{- $secretName = include "lerian-common.dependency.fullname" (dict "chartName" $sub "chartValues" (index $ctx.Values $sub) "context" $ctx) -}}
{{- end -}}
- name: {{ .envName }}
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: {{ .key }}
{{- end -}}
