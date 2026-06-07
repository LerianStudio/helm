{{/*
Expand the name of the chart.
*/}}
{{- define "reporter.name" -}}
{{- default "reporter" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart and plugin manager.
*/}}
{{- define "plugin-manager.name" -}}
{{- default (default .Values.manager.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart and plugin worker.
*/}}
{{- define "plugin-worker.name" -}}
{{- default (default .Values.worker.name) | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create chart name and version as used by the chart label for plugin manager.
*/}}
{{- define "plugin-manager.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin worker.
*/}}
{{- define "plugin-worker.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create a default fully qualified app name manager.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-manager.fullname" -}}
{{- default (default .Values.manager.name) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a unique name for cluster-scoped resources (ClusterRole, ClusterRoleBinding).
Includes namespace to avoid conflicts when multiple releases exist in different namespaces.
*/}}
{{- define "plugin-manager.clusterResourceName" -}}
{{- $namespace := include "global.namespace" . -}}
{{- $name := default .Values.manager.name -}}
{{- printf "%s-%s" $name $namespace | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name worker.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-worker.fullname" -}}
{{- default (default .Values.worker.name) | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create app version.
*/}}
{{- define "plugin.version" -}}
{{- printf "%s" .Chart.AppVersion | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
manager Selector labels
*/}}
{{- define "plugin-manager.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-manager.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
worker Selector labels
*/}}
{{- define "plugin-worker.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-worker.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}


{{/*
manager Common labels
*/}}
{{- define "plugin-manager.labels" -}}
helm.sh/chart: {{ include "plugin-manager.chart" .context }}
{{ include "plugin-manager.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
worker Common labels
*/}}
{{- define "plugin-worker.labels" -}}
helm.sh/chart: {{ include "plugin-worker.chart" .context }}
{{ include "plugin-worker.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}


{{/*
Create the name of the manager service account to use
*/}}
{{- define "plugin-manager.serviceAccountName" -}}
{{- if .Values.manager.serviceAccount.create }}
{{- default (include "plugin-manager.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.manager.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the worker service account to use
*/}}
{{- define "plugin-worker.serviceAccountName" -}}
{{- if .Values.worker.serviceAccount.create }}
{{- default (include "plugin-worker.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.worker.serviceAccount.name }}
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
reporter.infraSecretRef — emit a `- name: <envName> valueFrom: secretKeyRef: {name,key}` entry
pointing at a Bitnami subchart's generated Secret (or the operator's existingSecret override).
Inputs (dict): context (root .), subchart ("mongodb"), key, envName.
See docs/helm-chart-standard.md "Single-Source Infra Secrets".
*/}}
{{- define "reporter.infraSecretRef" -}}
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
reporter.mongoInternal — true when the bundled Bitnami mongodb subchart provides the DB.
*/}}
{{- define "reporter.mongoInternal" -}}
{{- $mongo := default dict .Values.mongodb -}}
{{- if and (ne (toString $mongo.enabled) "false") (not $mongo.external) -}}true{{- else -}}false{{- end -}}
{{- end }}

{{/*
reporter.mongoExternalSecretData — emit the MONGO_PASSWORD app-Secret data entry ONLY for an
external MongoDB without an existingSecret (the operator supplies it inline). For the bundled
subchart the password lives in <release>-mongodb and this emits nothing.
*/}}
{{- define "reporter.mongoExternalSecretData" -}}
{{- $mongo := default dict .Values.mongodb -}}
{{- $mongoAuth := default dict $mongo.auth -}}
{{- if and (ne (include "reporter.mongoInternal" .) "true") (not $mongoAuth.existingSecret) .Values.secrets.MONGO_PASSWORD -}}
MONGO_PASSWORD: {{ .Values.secrets.MONGO_PASSWORD | toString | b64enc | quote }}
{{- end -}}
{{- end }}

{{/*
reporter.mongoPasswordEnv — emit the MONGO_PASSWORD env entry for an app workload, single-sourced.
Bundled subchart -> secretKeyRef to <release>-mongodb/mongodb-root-password (or existingSecret).
External inline -> secretKeyRef to the given app Secret name / MONGO_PASSWORD.
Input (dict): context (root .), secretName (the app Secret name for the external-inline fallback).
*/}}
{{- define "reporter.mongoPasswordEnv" -}}
{{- $ctx := .context -}}
{{- $mongo := default dict $ctx.Values.mongodb -}}
{{- $mongoAuth := default dict $mongo.auth -}}
{{- if or (eq (include "reporter.mongoInternal" $ctx) "true") $mongoAuth.existingSecret -}}
{{ include "reporter.infraSecretRef" (dict "context" $ctx "subchart" "mongodb" "key" "mongodb-root-password" "envName" "MONGO_PASSWORD") }}
{{- else if $ctx.Values.secrets.MONGO_PASSWORD -}}
- name: MONGO_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .secretName }}
      key: MONGO_PASSWORD
{{- end -}}
{{- end }}

{{/*
reporter.rabbitmqErlangCookieRequired — fail when the bundled groundhog2k rabbitmq subchart is
enabled but no erlang cookie is provided. The broker is pointed at the app Secret via
authentication.existingSecret, which suppresses the inline cookie value, so a stable
operator-provided cookie is mandatory for clustering across restarts.
*/}}
{{- define "reporter.rabbitmqErlangCookieRequired" -}}
{{- $rmq := default dict .Values.rabbitmq -}}
{{- $rmqEnabled := true -}}
{{- if hasKey $rmq "enabled" -}}{{- $rmqEnabled = $rmq.enabled -}}{{- end -}}
{{- if and $rmqEnabled (not .Values.secrets.RABBITMQ_ERLANG_COOKIE) -}}
{{- fail "\n\nERROR: secrets.RABBITMQ_ERLANG_COOKIE is REQUIRED when the bundled rabbitmq subchart is enabled.\n   The broker reads its Erlang cookie from the application Secret (single source).\n   Provide a stable value (it must not change across upgrades) e.g.: openssl rand -hex 32\n" -}}
{{- end -}}
{{- end }}

{{/*
reporter.rabbitmqExistingSecretConsistent — fail when the bundled groundhog2k rabbitmq subchart is
enabled and still carries the SHIPPED DEFAULT authentication.existingSecret ("reporter-manager") but
the manager Secret has been renamed (manager.name / fullnameOverride), so the broker would reference a
Secret that does not exist. values.yaml cannot template, so this render-time gate catches the drift.
Custom (non-default) existingSecret values are the operator's responsibility and pass untouched.
*/}}
{{- define "reporter.rabbitmqExistingSecretConsistent" -}}
{{- $rmq := default dict .Values.rabbitmq -}}
{{- $rmqEnabled := true -}}
{{- if hasKey $rmq "enabled" -}}{{- $rmqEnabled = $rmq.enabled -}}{{- end -}}
{{- $auth := default dict $rmq.authentication -}}
{{- $managerName := include "plugin-manager.fullname" . -}}
{{- if and $rmqEnabled (eq (default "" $auth.existingSecret) "reporter-manager") (ne $managerName "reporter-manager") -}}
{{- fail (printf "\n\nERROR: rabbitmq.authentication.existingSecret is still the shipped default \"reporter-manager\" but the manager Secret renders as %q.\n   The broker would reference a Secret that does not exist.\n   Update rabbitmq.authentication.existingSecret to %q (or set it to your own existing Secret).\n" $managerName $managerName) -}}
{{- end -}}
{{- end }}
