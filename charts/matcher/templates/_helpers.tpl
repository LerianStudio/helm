{{/*
Expand the name of the chart.
*/}}
{{- define "matcher.name" -}}
{{- default (default "matcher" .Values.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name for matcher.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "matcher.fullname" -}}
{{- default (include "matcher.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "matcher.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create matcher app version
*/}}
{{- define "matcher.defaultTag" -}}
{{- default .Chart.AppVersion .Values.matcher.image.tag }}
{{- end -}}

{{/*
Return valid matcher version label
*/}}
{{- define "matcher.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "matcher.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "matcher.labels" -}}
helm.sh/chart: {{ include "matcher.chart" .context }}
{{ include "matcher.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "matcher.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "matcher.selectorLabels" -}}
app.kubernetes.io/name: {{ include "matcher.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "matcher.serviceAccountName" -}}
{{- if .Values.matcher.serviceAccount.create }}
{{- default (include "matcher.fullname" .) .Values.matcher.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.matcher.serviceAccount.name }}
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
{{- define "matcher.infraSecretRef" -}}
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
Enable internal dependencies
*/}}
{{- define "rabbitmq.enabled" -}}
{{- if not .Values.rabbitmq.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{- define "valkey.enabled" -}}
{{- if not .Values.valkey.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{- define "postgresql.enabled" -}}
{{- if not .Values.postgresql.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
==============================================================================
Component helpers (multi-component: migrations)
Names are derived from matcher.fullname so cross-references stay deterministic
and release-aware (e.g. the migration Job reads its PreSync Secret by name).
==============================================================================
*/}}

{{/* Migrations fullname (e.g. matcher-migrations) — Job and PreSync Secret reference this */}}
{{- define "matcher-migrations.fullname" -}}
{{- printf "%s-migrations" (include "matcher.fullname" . | trunc 52 | trimSuffix "-") | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Migrations labels */}}
{{- define "matcher-migrations.labels" -}}
helm.sh/chart: {{ include "matcher.chart" . }}
app.kubernetes.io/name: {{ include "matcher-migrations.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: migrations
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

{{/*
minImage is the first Matcher image that serves HEALTH_PORT.
*/}}
{{- define "matcher.health" -}}
{{- range $key := list "enabled" "minAvailable" "maxUnavailable" -}}
{{- if hasKey ($.Values.matcher.pdb | default dict) $key -}}
{{- fail (printf "matcher.pdb.%s is owned by the health preset" $key) -}}
{{- end -}}
{{- end -}}
{{- if hasKey .Values.matcher "deploymentUpdate" -}}
{{- fail "matcher.deploymentUpdate is owned by the health preset" -}}
{{- end -}}
{{- include "lerian-common.health" (dict
      "name" "matcher" "component" .Values.matcher "health" .Values.matcher.health
      "port" 8080 "minImage" "6.1.0-beta.1"
      "replicas" .Values.matcher.replicaCount "autoscaling" .Values.matcher.autoscaling) -}}
{{- end -}}

{{/*
Licence-file Secret name, nil-safe for `helm upgrade --reuse-values` over older releases.
Mounted whole at /etc/lerian/license, never as a subPath, so a rotated Secret reaches the pod.
*/}}
{{- define "matcher.licenseFileSecret" -}}
{{- (.Values.matcher.licenseFile | default dict).existingSecret | default "" -}}
{{- end }}

{{- define "matcher.licenseFileEnv" -}}
{{- if include "matcher.licenseFileSecret" . }}
- name: LICENSE_FILE_PATH
  value: /etc/lerian/license/license.lic
{{- end }}
{{- end }}

{{- define "matcher.licenseFileMount" -}}
{{- if include "matcher.licenseFileSecret" . }}
- name: license-file
  mountPath: /etc/lerian/license
  readOnly: true
{{- end }}
{{- end }}

{{- define "matcher.licenseFileVolume" -}}
{{- if include "matcher.licenseFileSecret" . }}
- name: license-file
  secret:
    secretName: {{ include "matcher.licenseFileSecret" . | quote }}
    defaultMode: 0444
    items:
      - key: license.lic
        path: license.lic
{{- end }}
{{- end }}

{{/* LICENSE_KEY as the app sees it from values: envFrom lists the Secret, then the ConfigMap (configmap keys, then extraEnvVars); the later source wins. */}}
{{- define "matcher.licenseKeyFromValues" -}}
{{- $key := (.Values.matcher.secrets | default dict).LICENSE_KEY | default "" | toString -}}
{{- range $m := list (.Values.matcher.configmap | default dict) (.Values.matcher.extraEnvVars | default dict) }}
{{- if hasKey $m "LICENSE_KEY" }}{{ $key = ($m.LICENSE_KEY | default "" | toString) }}{{ end }}
{{- end -}}
{{- $key -}}
{{- end }}
