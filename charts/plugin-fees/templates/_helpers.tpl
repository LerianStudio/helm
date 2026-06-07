{{/*
Expand the name of the chart and plugin fees.
*/}}
{{- define "plugin-fees.name" -}}
{{- default (default .Values.fees.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart and plugin fees.
*/}}
{{- define "plugin-fees-backend.name" -}}
{{- default (default .Values.fees.backend.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin fees.
*/}}
{{- define "plugin-fees.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin fees.
*/}}
{{- define "plugin-fees-backend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name fees.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-fees.fullname" -}}
{{- default (default .Values.fees.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name fees.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-fees-backend.fullname" -}}
{{- default (default .Values.fees.backend.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create app version.
*/}}
{{- define "plugin.version" -}}
{{- printf "%s" .Chart.AppVersion | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
fees Selector labels
*/}}
{{- define "plugin-fees.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-fees.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
fees Selector labels
*/}}
{{- define "plugin-fees-backend.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-fees-backend.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
fees Common labels
*/}}
{{- define "plugin-fees.labels" -}}
helm.sh/chart: {{ include "plugin-fees.chart" .context }}
{{ include "plugin-fees.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
fees Backend Common labels
*/}}
{{- define "plugin-fees-backend.labels" -}}
helm.sh/chart: {{ include "plugin-fees-backend.chart" .context }}
{{ include "plugin-fees-backend.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Create the name of the fees service account to use
*/}}
{{- define "plugin-fees.serviceAccountName" -}}
{{- if .Values.fees.serviceAccount.create }}
{{- default (include "plugin-fees.fullname" .) .Values.fees.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.fees.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Expand the namespace of the release.
Allows overriding it for multi-namespace deployments in combined charts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.fees.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
plugin-fees.mongoInternal — true when the bundled Bitnami mongodb subchart provides the DB.
*/}}
{{- define "plugin-fees.mongoInternal" -}}
{{- $mongo := default dict .Values.mongodb -}}
{{- if and (ne (toString $mongo.enabled) "false") (not $mongo.external) -}}true{{- else -}}false{{- end -}}
{{- end }}

{{/*
plugin-fees.mongoHost — the bundled subchart Service host used as the MONGO_HOST default so it
stays consistent with the rendered mongodb Service. When the bundled Bitnami mongodb subchart is
enabled, resolve the Service name via Bitnami's own helper so it matches the collapse/override
rules (release name containing "mongodb", nameOverride, fullnameOverride). On the external path the
subchart templates are not loaded, so common.names.dependency.fullname is out of scope — fall back
to self-contained logic mirroring it (fullnameOverride, then nameOverride, then the collapse).
*/}}
{{- define "plugin-fees.mongoHost" -}}
{{- $mongo := default dict .Values.mongodb -}}
{{- $mongoFullname := "" -}}
{{- if eq (include "plugin-fees.mongoInternal" .) "true" -}}
{{- $mongoFullname = include "common.names.dependency.fullname" (dict "chartName" "mongodb" "chartValues" $mongo "context" .) -}}
{{- else if $mongo.fullnameOverride -}}
{{- $mongoFullname = $mongo.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "mongodb" $mongo.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- $mongoFullname = .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $mongoFullname = printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- printf "%s.%s.svc.cluster.local" $mongoFullname (include "global.namespace" .) -}}
{{- end }}

{{/*
infraSecretRef — emit a `- name: <envName> valueFrom: secretKeyRef: {name,key}` env entry
pointing at a Bitnami subchart's generated Secret (or the operator's existingSecret override).
Inputs (dict): context (root .), subchart ("postgresql"|"mongodb"|"valkey"),
key (data key), envName (container env var name).
See docs/helm-chart-standard.md "Single-Source Infra Secrets".
*/}}
{{- define "plugin-fees.infraSecretRef" -}}
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


