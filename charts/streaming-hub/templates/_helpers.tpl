{{/*
Expand the name of the chart.
*/}}
{{- define "streaming-hub.name" -}}
{{- default "streaming-hub" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Truncated at 63 chars because some Kubernetes name fields are limited to this
(by the DNS naming spec). When fullnameOverride is set it wins verbatim.
*/}}
{{- define "streaming-hub.fullname" -}}
{{- default (include "streaming-hub.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "streaming-hub.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Resolve the image tag, falling back to the chart appVersion when image.tag is "".
*/}}
{{- define "streaming-hub.defaultTag" -}}
{{- default .Chart.AppVersion .Values.streamingHub.image.tag }}
{{- end -}}

{{/*
Return a valid version label value (k8s label charset).
*/}}
{{- define "streaming-hub.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "streaming-hub.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Component fully-qualified name: <fullname>-<component>.
Input: dict { context, component }. Truncated to 63 chars.
Used by every per-role Deployment/Service/HPA/PDB so the three role variants
never collide on a name.
*/}}
{{- define "streaming-hub.componentFullname" -}}
{{- $fullname := include "streaming-hub.fullname" .context -}}
{{- printf "%s-%s" $fullname .component | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Base selector labels (no component).
Input: dict { context }.
*/}}
{{- define "streaming-hub.selectorLabels" -}}
app.kubernetes.io/name: {{ include "streaming-hub.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
Component-aware selector labels: base labels + app.kubernetes.io/component.
Input: dict { context, component }. The component label is the load-bearing
discriminator that keeps split-mode (ingest/delivery) Deployments from sharing
one ReplicaSet selector.
*/}}
{{- define "streaming-hub.componentSelectorLabels" -}}
{{ include "streaming-hub.selectorLabels" (dict "context" .context) }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Component-aware common labels (selector labels + chart/version/managed-by/part-of).
Input: dict { context, component }.
*/}}
{{- define "streaming-hub.labels" -}}
helm.sh/chart: {{ include "streaming-hub.chart" .context }}
{{ include "streaming-hub.componentSelectorLabels" (dict "context" .context "component" .component) }}
app.kubernetes.io/version: {{ include "streaming-hub.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
app.kubernetes.io/part-of: streaming-hub
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "streaming-hub.serviceAccountName" -}}
{{- if .Values.streamingHub.serviceAccount.create }}
{{- default (include "streaming-hub.fullname" .) .Values.streamingHub.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.streamingHub.serviceAccount.name }}
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
Resolve the shared Secret name a Deployment should reference:
existingSecretName when useExistingSecret, otherwise the shared chart Secret.
Input: root context (.).
*/}}
{{- define "streaming-hub.secretName" -}}
{{- if .Values.streamingHub.useExistingSecret -}}
{{- required "streamingHub.existingSecretName is required when streamingHub.useExistingSecret=true" .Values.streamingHub.existingSecretName -}}
{{- else -}}
{{- include "streaming-hub.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
streaming-hub.migrationDSN — STREAMING_HUB_POSTGRES_DSN for the migration-only
Secret hook. migration-secret.yaml renders only on the chart-managed credential
path (NOT migrations.useExistingSecret), and runs as a PreSync hook BEFORE the
normal app Secret exists, so the operator MUST supply the DSN here. Kept as a
named gate helper (not an inline `required`) to mirror the bank-transfer pattern.
Input: root context (.).
*/}}
{{- define "streaming-hub.migrationDSN" -}}
{{- $secrets := get (.Values.streamingHub | default dict) "secrets" | default dict -}}
{{- required "streamingHub.secrets.STREAMING_HUB_POSTGRES_DSN is required when migrations run with a chart-managed Secret (migrations.useExistingSecret=false)" (get $secrets "STREAMING_HUB_POSTGRES_DSN") -}}
{{- end -}}
