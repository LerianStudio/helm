{{/*
Expand the name of the chart.
*/}}
{{- define "midaz.name" -}}
{{- default (default "midaz" .Values.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "midaz-onboarding.fullname" -}}
{{- printf "%s-%s" (include "midaz.name" .) .Values.onboarding.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "midaz-console.fullname" -}}
{{- printf "%s-%s" (include "midaz.name" .) .Values.console.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "midaz-transaction.fullname" -}}
{{- printf "%s-%s" (include "midaz.name" .) .Values.transaction.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "midaz-grafana.fullname" -}}
{{- printf "%s-%s" (include "midaz.name" .) .Values.grafana.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "midaz.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create Onboarding app version
*/}}
{{- define "onboarding.defaultTag" -}}
{{- default .Chart.AppVersion .Values.onboarding.image.tag }}
{{- end -}}

{{/*
Return valid Onboarding version label
*/}}
{{- define "onboarding.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "onboarding.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "midaz.labels" -}}
helm.sh/chart: {{ include "midaz.chart" .context }}
{{ include "midaz.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "onboarding.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "midaz.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "midaz.name" .context }}-{{ .name }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}


{{/*
Create the name of the service account to use
*/}}
{{- define "midaz-onboarding.serviceAccountName" -}}
{{- if .Values.onboarding.serviceAccount.create }}
{{- default (include "midaz-onboarding.fullname" .) .Values.onboarding.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.onboarding.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "midaz-console.serviceAccountName" -}}
{{- if .Values.console.serviceAccount.create }}
{{- default (include "midaz-console.fullname" .) .Values.console.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.console.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "midaz-transaction.serviceAccountName" -}}
{{- if .Values.transaction.serviceAccount.create }}
{{- default (include "midaz-transaction.fullname" .) .Values.transaction.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.transaction.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create a default fully qualified app name for ledger.
*/}}
{{- define "midaz-ledger.fullname" -}}
{{- printf "%s-%s" (include "midaz.name" .) .Values.ledger.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create ledger app version
*/}}
{{- define "ledger.defaultTag" -}}
{{- default .Chart.AppVersion .Values.ledger.image.tag }}
{{- end -}}

{{/*
Return valid ledger version label
*/}}
{{- define "ledger.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "ledger.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Create the name of the service account to use for ledger
*/}}
{{- define "midaz-ledger.serviceAccountName" -}}
{{- if .Values.ledger.serviceAccount.create }}
{{- default (include "midaz-ledger.fullname" .) .Values.ledger.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.ledger.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Helper to check if migration.allowAllServices is enabled.
This flag is NOT in the public values.yaml - it defaults to false.
Internal teams can override it in their values to run all 3 services simultaneously.
*/}}
{{- define "migration.allowAllServices" -}}
{{- if .Values.migration }}
{{- .Values.migration.allowAllServices | default false }}
{{- else }}
{{- false }}
{{- end }}
{{- end -}}

{{/*
Helper to determine if onboarding should be deployed.
Deploys if: onboarding.enabled AND (ledger is disabled OR allowAllServices is true)
*/}}
{{- define "onboarding.shouldDeploy" -}}
{{- $allowAll := include "migration.allowAllServices" . }}
{{- if and .Values.onboarding.enabled (or (not .Values.ledger.enabled) (eq $allowAll "true")) -}}
true
{{- end -}}
{{- end -}}

{{/*
Helper to determine if transaction should be deployed.
Deploys if: transaction.enabled AND (ledger is disabled OR allowAllServices is true)
*/}}
{{- define "transaction.shouldDeploy" -}}
{{- $allowAll := include "migration.allowAllServices" . }}
{{- if and .Values.transaction.enabled (or (not .Values.ledger.enabled) (eq $allowAll "true")) -}}
true
{{- end -}}
{{- end -}}

{{/*
Helper to get the target service for onboarding ingress.
Returns ledger fullname if ledger is enabled and allowAllServices is false.
*/}}
{{- define "onboarding.ingress.targetService" -}}
{{- $allowAll := include "migration.allowAllServices" . }}
{{- if and .Values.ledger.enabled (ne $allowAll "true") -}}
{{- include "midaz-ledger.fullname" . }}
{{- else -}}
{{- include "midaz-onboarding.fullname" . }}
{{- end -}}
{{- end -}}

{{/*
Helper to get the target port for onboarding ingress.
Returns ledger port if ledger is enabled and allowAllServices is false.
*/}}
{{- define "onboarding.ingress.targetPort" -}}
{{- $allowAll := include "migration.allowAllServices" . }}
{{- if and .Values.ledger.enabled (ne $allowAll "true") -}}
{{- .Values.ledger.service.port }}
{{- else -}}
{{- .Values.onboarding.service.port }}
{{- end -}}
{{- end -}}

{{/*
Helper to get the target service for transaction ingress.
Returns ledger fullname if ledger is enabled and allowAllServices is false.
*/}}
{{- define "transaction.ingress.targetService" -}}
{{- $allowAll := include "migration.allowAllServices" . }}
{{- if and .Values.ledger.enabled (ne $allowAll "true") -}}
{{- include "midaz-ledger.fullname" . }}
{{- else -}}
{{- include "midaz-transaction.fullname" . }}
{{- end -}}
{{- end -}}

{{/*
Helper to get the target port for transaction ingress.
Returns ledger port if ledger is enabled and allowAllServices is false.
*/}}
{{- define "transaction.ingress.targetPort" -}}
{{- $allowAll := include "migration.allowAllServices" . }}
{{- if and .Values.ledger.enabled (ne $allowAll "true") -}}
{{- .Values.ledger.service.port }}
{{- else -}}
{{- .Values.transaction.service.port }}
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
Enable internal dependencies
*/}}
{{- define "mongodb.enabled" -}}
{{- if not .Values.mongodb.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}
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
