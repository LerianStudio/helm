{{/*
Expand the name of the chart.
*/}}
{{- define "product-console.name" -}}
{{- default (default "product-console" .Values.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "product-console.fullname" -}}
{{- default (include "product-console.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "product-console.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "product-console.labels" -}}
helm.sh/chart: {{ include "product-console.chart" . }}
{{ include "product-console.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "product-console.selectorLabels" -}}
app.kubernetes.io/name: {{ include "product-console.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "product-console.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "product-console.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Expand the namespace of the release.
Allows overriding it for multi-namespace deployments in combined charts.
*/}}
{{- define "product-console.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Name of the bundled MongoDB subchart's own resources (Service, Secret,
StatefulSet), resolved the way the subchart resolves them rather than hardcoded.

lerian-common.dependency.fullname is the vendored copy of the Bitnami rule the
subchart itself uses: fullnameOverride wins, else nameOverride, else
<release>-mongodb -- except that the name COLLAPSES to the bare release name
when the release name already contains it, so `helm install mongodb` creates a
Service called "mongodb", not "mongodb-mongodb". Hardcoding printf
"%s-mongodb" .Release.Name misses that collapse and points at nothing.
*/}}
{{- define "product-console.mongodb.fullname" -}}
{{- include "lerian-common.dependency.fullname" (dict "chartName" "mongodb" "chartValues" .Values.mongodb "context" .) -}}
{{- end }}

{{/*
Namespace the bundled MongoDB subchart's resources are created in.

A subchart does not inherit this chart's namespaceOverride. The Bitnami chart
resolves its own namespace from global.namespaceOverride and falls back to the
release namespace; its LOCAL namespaceOverride is declared in its values and
never read by its templates. Mirror that exactly.
*/}}
{{- define "product-console.mongodb.namespace" -}}
{{- if and .Values.global .Values.global.namespaceOverride -}}
{{- .Values.global.namespaceOverride -}}
{{- else -}}
{{- .Release.Namespace -}}
{{- end -}}
{{- end }}

{{/*
Secret the bundled MongoDB subchart's root password lives in: the one the
operator supplied through mongodb.auth.existingSecret, else the one the subchart
generates under its own name. Same resolution as the subchart's mongodb.secretName.
*/}}
{{- define "product-console.mongodb.secretName" -}}
{{- if .Values.mongodb.auth.existingSecret -}}
{{- .Values.mongodb.auth.existingSecret -}}
{{- else -}}
{{- include "product-console.mongodb.fullname" . -}}
{{- end -}}
{{- end }}

{{/*
Host the console should use for MongoDB when nobody names one.

The historical default, the bare name "mongodb", matches no Service the release
creates, so a default install pointed the console at a host that does not exist.
Resolved here as the bundled subchart's own Service FQDN instead.

With the subchart disabled the bare "mongodb" is kept, so an external MongoDB
published under that name keeps working untouched. Either way an operator's own
configmap.MONGO_HOST or global.datastores.mongo.host still wins: this is only
the fallback.
*/}}
{{- define "product-console.mongodb.host" -}}
{{- if .Values.mongodb.enabled -}}
{{- include "lerian-common.internalHost" (dict "name" (include "product-console.mongodb.fullname" .) "namespace" (include "product-console.mongodb.namespace" .)) -}}
{{- else -}}
mongodb
{{- end -}}
{{- end }}
