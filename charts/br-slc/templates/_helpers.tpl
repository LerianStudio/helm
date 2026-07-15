{{/*
Expand the name of the chart. The chart is named "br-slc-helm" (helm-repo
convention), but every workload/label uses the service name "br-slc".
*/}}
{{- define "br-slc.name" -}}
{{- default "br-slc" .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name. Truncated to 63 chars (K8s name
length limit) and trimmed of a trailing "-".
*/}}
{{- define "br-slc.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "br-slc" .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Chart name and version as used by the chart label.
*/}}
{{- define "br-slc.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels.
*/}}
{{- define "br-slc.labels" -}}
helm.sh/chart: {{ include "br-slc.chart" . }}
{{ include "br-slc.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels.
*/}}
{{- define "br-slc.selectorLabels" -}}
app.kubernetes.io/name: {{ include "br-slc.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
ServiceAccount name to use.
*/}}
{{- define "br-slc.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "br-slc.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Secret name to use for the 7 secret-bearing env vars: either the chart-created
Secret (secrets.create=true) or an externally managed Secret
(secrets.existingSecretName) — BYOC default is the latter.
*/}}
{{- define "br-slc.secretName" -}}
{{- if .Values.secrets.existingSecretName -}}
{{- .Values.secrets.existingSecretName -}}
{{- else -}}
{{- printf "%s-secrets" (include "br-slc.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Resolved image reference: "repository:tag", defaulting tag to .Chart.AppVersion
when empty.
*/}}
{{- define "br-slc.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end -}}

{{/*
Same-pod signer container image reference, defaulting tag to .Chart.AppVersion.
*/}}
{{- define "br-slc.signerImage" -}}
{{- $tag := .Values.signer.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.signer.image.repository $tag -}}
{{- end -}}

{{/*
Same-pod xsd-validator container image reference, defaulting tag to
.Chart.AppVersion.
*/}}
{{- define "br-slc.validatorImage" -}}
{{- $tag := .Values.xsdValidator.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.xsdValidator.image.repository $tag -}}
{{- end -}}

{{/*
Same-pod mqbridge container image reference, defaulting tag to
.Chart.AppVersion. Rendered only when mqbridge.enabled (Decisão 21).
*/}}
{{- define "br-slc.mqbridgeImage" -}}
{{- $tag := .Values.mqbridge.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.mqbridge.image.repository $tag -}}
{{- end -}}

{{/*
Signer-scoped Secret name (ADR-9 custody): the chart-created signer Secret
(signer.secrets.create=true) or an externally managed one
(signer.secrets.existingSecretName). Distinct from the app's br-slc.secretName
so signing-key material is never in the app container's Secret.
*/}}
{{- define "br-slc.signerSecretName" -}}
{{- if .Values.signer.secrets.existingSecretName -}}
{{- .Values.signer.secrets.existingSecretName -}}
{{- else -}}
{{- printf "%s-signer-secrets" (include "br-slc.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Mqbridge-scoped Secret name (Decisão 21): the chart-created mqbridge Secret
(mqbridge.secrets.create=true) or an externally managed one
(mqbridge.secrets.existingSecretName). Distinct from the app's br-slc.secretName
so MQ credential material stays scoped to the mqbridge container's env.
*/}}
{{- define "br-slc.mqbridgeSecretName" -}}
{{- if .Values.mqbridge.secrets.existingSecretName -}}
{{- .Values.mqbridge.secrets.existingSecretName -}}
{{- else -}}
{{- printf "%s-mqbridge-secrets" (include "br-slc.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Expand the namespace of the release. Overridable for multi-namespace layouts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Migrations fullname, e.g. br-slc-migrations — the PreSync Job and Secret
reference this.
*/}}
{{- define "br-slc-migrations.fullname" -}}
{{- printf "%s-migrations" (include "br-slc.fullname" . | trunc 52 | trimSuffix "-") | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Migrations labels.
*/}}
{{- define "br-slc-migrations.labels" -}}
helm.sh/chart: {{ include "br-slc.chart" . }}
app.kubernetes.io/name: {{ include "br-slc-migrations.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: migrations
{{- end -}}

{{/*
Per-container securityContext (ADR-12 hardening). Same key set for every
same-pod container; only the values differ. Call with the container's
securityContext dict as context, e.g.:
  securityContext:
    {{- include "br-slc.containerSecurityContext" .Values.signer.securityContext | nindent 12 }}
*/}}
{{- define "br-slc.containerSecurityContext" -}}
runAsNonRoot: {{ .runAsNonRoot }}
runAsUser: {{ .runAsUser }}
runAsGroup: {{ .runAsGroup }}
allowPrivilegeEscalation: {{ .allowPrivilegeEscalation }}
{{- if hasKey . "readOnlyRootFilesystem" }}
readOnlyRootFilesystem: {{ .readOnlyRootFilesystem }}
{{- end }}
seccompProfile:
  type: {{ .seccompProfile.type }}
capabilities:
  drop:
    {{- range .capabilities.drop }}
    - {{ . }}
    {{- end }}
{{- end -}}

{{/*
HTTP liveness/readiness probe body. Call with the probe dict as context, e.g.:
  livenessProbe:
    {{- include "br-slc.httpProbe" .Values.signer.livenessProbe | nindent 12 }}
*/}}
{{- define "br-slc.httpProbe" -}}
httpGet:
  path: {{ .httpGet.path }}
  port: {{ .httpGet.port }}
initialDelaySeconds: {{ .initialDelaySeconds }}
periodSeconds: {{ .periodSeconds }}
timeoutSeconds: {{ .timeoutSeconds }}
failureThreshold: {{ .failureThreshold }}
{{- end -}}

{{/*
mock-nuclea (Núclea clearing-house simulator) — a SEPARATE Deployment+Service,
NOT a same-pod sidecar: it must be independently gated OFF (safe-by-default) and
reached over cluster DNS by the app. DEV/HML FIXTURE ONLY — never enable in
production/BYOC. Mirrors the detached-`migrations` component's own-fullname /
own-labels convention so the app Service selector never captures the mock pod.
*/}}
{{- define "br-slc-mock-nuclea.fullname" -}}
{{- printf "%s-mock-nuclea" (include "br-slc.fullname" . | trunc 51 | trimSuffix "-") | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
mock-nuclea selector labels — distinct name from the app so the app's Service
(br-slc.selectorLabels) never routes to the mock and vice-versa.
*/}}
{{- define "br-slc-mock-nuclea.selectorLabels" -}}
app.kubernetes.io/name: {{ include "br-slc-mock-nuclea.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
mock-nuclea labels.
*/}}
{{- define "br-slc-mock-nuclea.labels" -}}
helm.sh/chart: {{ include "br-slc.chart" . }}
{{ include "br-slc-mock-nuclea.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: mock-nuclea
{{- end -}}

{{/*
mock-nuclea image reference, defaulting tag to .Chart.AppVersion when empty.
Distinct image from the app (its own release-pipeline artifact).
*/}}
{{- define "br-slc.mockNucleaImage" -}}
{{- $tag := .Values.mockNuclea.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.mockNuclea.image.repository $tag -}}
{{- end -}}
