{{/* Chart and naming helpers. */}}
{{- define "br-consignado-gw.name" -}}
{{- default "br-consignado-gw" .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "br-consignado-gw.fullname" -}}
{{- default (include "br-consignado-gw.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "br-consignado-gw.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "br-consignado-gw.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Component helpers take dict {root: $, name: "api"|"ui"|"migrations"}. */}}
{{- define "br-consignado-gw.componentFullname" -}}
{{- printf "%s-%s" (include "br-consignado-gw.fullname" .root) .name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "br-consignado-gw.componentSelectorLabels" -}}
app.kubernetes.io/name: {{ include "br-consignado-gw.name" .root }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .name }}
{{- end -}}

{{- define "br-consignado-gw.componentLabels" -}}
helm.sh/chart: {{ include "br-consignado-gw.chart" .root }}
{{ include "br-consignado-gw.componentSelectorLabels" . }}
app.kubernetes.io/version: {{ .root.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
app.kubernetes.io/part-of: br-consignado-gw
{{- end -}}

{{- define "br-consignado-gw.componentImage" -}}
{{- printf "%s:%s" .comp.image.repository (default .root.Chart.AppVersion .comp.image.tag) -}}
{{- end -}}

{{- define "br-consignado-gw.componentPullSecrets" -}}
{{- $pullSecrets := .comp.imagePullSecrets | default .root.Values.imagePullSecrets -}}
{{- with $pullSecrets }}{{ toYaml . }}{{ end -}}
{{- end -}}

{{- define "br-consignado-gw.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "br-consignado-gw.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "br-consignado-gw.apiFullname" -}}
{{- include "br-consignado-gw.componentFullname" (dict "root" . "name" "api") -}}
{{- end -}}

{{- define "br-consignado-gw.uiFullname" -}}
{{- include "br-consignado-gw.componentFullname" (dict "root" . "name" "ui") -}}
{{- end -}}

{{- define "br-consignado-gw.migrationsFullname" -}}
{{- include "br-consignado-gw.componentFullname" (dict "root" . "name" "migrations") -}}
{{- end -}}

{{- define "br-consignado-gw.apiSecretName" -}}
{{- if .Values.api.useExistingSecret -}}
{{- required "api.existingSecretName is required when api.useExistingSecret=true" .Values.api.existingSecretName -}}
{{- else -}}
{{- include "br-consignado-gw.apiFullname" . -}}
{{- end -}}
{{- end -}}
