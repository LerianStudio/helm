{{/*
Expand the name of the chart.
*/}}
{{- define "flowker.name" -}}
{{- default (default "flowker" .Values.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name for flowker.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "flowker.fullname" -}}
{{- default (include "flowker.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "flowker.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create flowker app version
*/}}
{{- define "flowker.defaultTag" -}}
{{- default .Chart.AppVersion .Values.flowker.image.tag }}
{{- end -}}

{{/*
Return valid flowker version label
*/}}
{{- define "flowker.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "flowker.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "flowker.labels" -}}
helm.sh/chart: {{ include "flowker.chart" .context }}
{{ include "flowker.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "flowker.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "flowker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "flowker.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "flowker.serviceAccountName" -}}
{{- if .Values.flowker.serviceAccount.create }}
{{- default (include "flowker.fullname" .) .Values.flowker.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.flowker.serviceAccount.name }}
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
flowker.mongoInternal — true when the bundled Bitnami mongodb subchart provides the DB.
*/}}
{{- define "flowker.mongoInternal" -}}
{{- $mongo := default dict .Values.mongodb -}}
{{- if and (ne (toString $mongo.enabled) "false") (not $mongo.external) -}}true{{- else -}}false{{- end -}}
{{- end }}

{{/*
flowker.mongoHost — the bundled subchart Service host. Used by the readiness init container and
the assembled URI so they stay consistent. When the bundled Bitnami mongodb subchart is enabled,
resolve the Service name via Bitnami's own helper so it matches the collapse/override rules
(release name containing "mongodb", nameOverride, fullnameOverride). On the external path the
subchart templates are not loaded, so common.names.dependency.fullname is out of scope — fall back
to self-contained logic mirroring it (fullnameOverride, then nameOverride, then the collapse).
*/}}
{{- define "flowker.mongoHost" -}}
{{- $mongo := default dict .Values.mongodb -}}
{{- $mongoFullname := "" -}}
{{- if eq (include "flowker.mongoInternal" .) "true" -}}
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
flowker.mongoEnv — single-source the MongoDB connection (the app is URI-only).
Emits MONGO_PASSWORD (secretKeyRef) then MONGO_URI referencing it via $(MONGO_PASSWORD)
expansion (MONGO_PASSWORD MUST precede MONGO_URI in the env list). flowker authenticates as the
mongodb ROOT user (mongodb.auth.rootUser), so the Bitnami key is mongodb-root-password.
- Bundled subchart: MONGO_PASSWORD <- <release>-mongodb / mongodb-root-password.
- existingSecret override: MONGO_PASSWORD <- <existingSecret> / mongodb-root-password.
- External inline: MONGO_PASSWORD <- app Secret / MONGO_PASSWORD.
An explicit flowker.secrets.MONGO_URI wins verbatim (no assembly).
Input (dict): context (root .), secretName (app Secret name for the external-inline fallback).
*/}}
{{- define "flowker.mongoEnv" -}}
{{- $ctx := .context -}}
{{- $mongo := default dict $ctx.Values.mongodb -}}
{{- $mongoAuth := default dict $mongo.auth -}}
{{- $internal := eq (include "flowker.mongoInternal" $ctx) "true" -}}
{{- if $ctx.Values.flowker.secrets.MONGO_URI }}
- name: MONGO_URI
  value: {{ $ctx.Values.flowker.secrets.MONGO_URI | quote }}
{{- else if not $ctx.Values.flowker.useExistingSecret }}
{{- if or $internal $mongoAuth.existingSecret }}
{{- $secretName := $mongoAuth.existingSecret }}
{{- if not $secretName }}
{{- $secretName = include "common.names.dependency.fullname" (dict "chartName" "mongodb" "chartValues" $mongo "context" $ctx) }}
{{- end }}
- name: MONGO_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: mongodb-root-password
{{- else if $ctx.Values.flowker.secrets.MONGO_PASSWORD }}
- name: MONGO_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .secretName }}
      key: MONGO_PASSWORD
{{- end }}
- name: MONGO_URI
  value: {{ printf "mongodb://%s:$(MONGO_PASSWORD)@%s:27017/?authSource=admin" $mongo.auth.rootUser (include "flowker.mongoHost" $ctx) | quote }}
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
