{{/*
Expand the name of the chart.
*/}}
{{- define "midaz.name" -}}
{{- default (default "" .Values.nameOverride) .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "midaz-ledger.fullname" -}}
{{- printf "%s-%s" (include "midaz.name" .) .Values.ledger.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "midaz-audit.fullname" -}}
{{- printf "%s-%s" (include "midaz.name" .) .Values.audit.name | trunc 63 | trimSuffix "-" }}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "midaz.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create Ledger app version
*/}}
{{- define "ledger.defaultTag" -}}
{{- default .Chart.AppVersion .Values.ledger.image.tag }}
{{- end -}}

{{/*
Return valid Ledger version label
*/}}
{{- define "ledger.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "ledger.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "midaz.labels" -}}
helm.sh/chart: {{ include "midaz.chart" .context }}
{{ include "midaz.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "ledger.versionLabelValue" .context }}
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
{{- define "midaz-ledger.serviceAccountName" -}}
{{- if .Values.ledger.serviceAccount.create }}
{{- default (include "midaz-ledger.fullname" .) .Values.ledger.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.ledger.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "midaz-audit.serviceAccountName" -}}
{{- if .Values.audit.serviceAccount.create }}
{{- default (include "midaz-audit.fullname" .) .Values.audit.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.audit.serviceAccount.name }}
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
{{- define "redis.enabled" -}}
{{- if not .Values.redis.external -}}
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