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
================================================================================
WORKER HELPERS
The scheduler worker is a SECOND Deployment running the SAME flowker image with
its command overridden to /worker. It reuses the api ConfigMap + Secret and
layers worker-only env on top. It gets its OWN app.kubernetes.io/name so its
(immutable) selector never overlaps the api Deployment's.
================================================================================
*/}}

{{/* Worker resource name: "<fullname>-worker". */}}
{{- define "flowker.worker.fullname" -}}
{{- printf "%s-worker" (include "flowker.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/* Worker app name (distinct from the api so selectors don't overlap). */}}
{{- define "flowker.worker.name" -}}
{{- printf "%s-worker" (include "flowker.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/* Worker selector labels — distinct name keeps the two Deployments apart. */}}
{{- define "flowker.worker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "flowker.worker.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/* Worker common labels. */}}
{{/* FIXME(nitpick): app.kubernetes.io/version tracks the api image tag, not
     worker.image.tag when overridden (ring-helm, 2026-07-10, Cosmetic). */}}
{{- define "flowker.worker.labels" -}}
helm.sh/chart: {{ include "flowker.chart" .context }}
{{ include "flowker.worker.selectorLabels" (dict "context" .context) }}
app.kubernetes.io/version: {{ include "flowker.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
app.kubernetes.io/component: worker
{{- end }}

{{/* Worker ServiceAccount name (own SA, or reuse the api's when not creating). */}}
{{- define "flowker.worker.serviceAccountName" -}}
{{- $w := .Values.worker | default dict -}}
{{- $sa := $w.serviceAccount | default dict -}}
{{- if $sa.create }}
{{- default (include "flowker.worker.fullname" .) $sa.name }}
{{- else }}
{{- default (include "flowker.serviceAccountName" .) $sa.name }}
{{- end }}
{{- end }}

{{/* Worker enabled — gated by flowker.enabled; nil-aware on worker.enabled
     (unset/true enables, explicit false disables). */}}
{{- define "flowker.worker.enabled" -}}
{{- $w := .Values.worker | default dict -}}
{{- if and .Values.flowker.enabled (ne (toString $w.enabled) "false") -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

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
flowker.mongoHost — the MongoDB host used by the readiness init container and the assembled URI,
kept consistent across both. When the bundled Bitnami mongodb subchart is enabled, resolve the
in-cluster Service FQDN via Bitnami's own helper (honoring collapse/nameOverride/fullnameOverride).
On the EXTERNAL path (mongodb.enabled=false) there is no in-cluster Service — return the real
external host from flowker.configmap.MONGO_HOST so the init container actually probes the external
MongoDB instead of a non-existent <release>-mongodb Service.
*/}}
{{- define "flowker.mongoHost" -}}
{{- $mongo := default dict .Values.mongodb -}}
{{- if eq (include "flowker.mongoInternal" .) "true" -}}
{{- $mongoFullname := include "common.names.dependency.fullname" (dict "chartName" "mongodb" "chartValues" $mongo "context" .) -}}
{{- printf "%s.%s.svc.cluster.local" $mongoFullname (include "global.namespace" .) -}}
{{- else -}}
{{- required "flowker.configmap.MONGO_HOST is required when mongodb is external (mongodb.enabled=false)" .Values.flowker.configmap.MONGO_HOST -}}
{{- end -}}
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
{{- else }}
{{- fail "flowker.secrets.MONGO_PASSWORD is required when mongodb is external and mongodb.auth.existingSecret is not set" }}
{{- end }}
- name: MONGO_URI
  value: {{ printf "mongodb://%s:$(MONGO_PASSWORD)@%s:27017/?authSource=admin" $mongo.auth.rootUser (include "flowker.mongoHost" $ctx) | quote }}
{{- end }}
{{- end }}

{{/*
flowker.waitForMongoInit — the shared wait-for-mongodb init container, used by
both the api and worker Deployments so they never drift. Input (dict): context (root .).
*/}}
{{- define "flowker.waitForMongoInit" -}}
{{- $ctx := .context -}}
- name: wait-for-mongodb
  image: busybox:1.37
  command:
    - /bin/sh
    - -c
    - >
      TIMEOUT=300;
      ELAPSED=0;
      {{- $mongoHost := include "flowker.mongoHost" $ctx }}
      echo "Checking {{ $mongoHost }}:27017...";
      while ! nc -z "{{ $mongoHost }}" 27017; do
        if [ $ELAPSED -ge $TIMEOUT ]; then
          echo "Timeout waiting for MongoDB after ${TIMEOUT}s";
          exit 1;
        fi;
        echo "MongoDB is not ready yet, waiting... (${ELAPSED}s/${TIMEOUT}s)";
        sleep 5;
        ELAPSED=$((ELAPSED + 5));
      done;
      echo "MongoDB is ready!";
{{- end }}

{{/*
flowker.otelHostEnv — HOST_IP + OTEL endpoint env, emitted only when telemetry
is enabled. Shared by the api and worker Deployments. Input (dict): context (root .).
*/}}
{{- define "flowker.otelHostEnv" -}}
{{- $ctx := .context -}}
{{- if eq (toString $ctx.Values.flowker.configmap.ENABLE_TELEMETRY) "true" }}
- name: "HOST_IP"
  valueFrom:
    fieldRef:
      fieldPath: status.hostIP
- name: "OTEL_EXPORTER_OTLP_ENDPOINT"
  value: "$(HOST_IP):4317"
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
