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
Host the console should use for MongoDB when nobody names one.

The bundled Bitnami subchart does not inherit this chart's namespaceOverride, so
its Service is created as <release>-mongodb in the subchart's own namespace while
the console sits in namespaceOverride. The historical default, the bare name
"mongodb", matches no Service in either namespace, so a default install pointed
the console at a host that does not exist. Resolved here as the subchart's own
FQDN instead.

With the subchart disabled the bare "mongodb" is kept, so an external MongoDB
published under that name keeps working untouched. Either way an operator's own
configmap.MONGO_HOST or global.datastores.mongo.host still wins: this is only
the fallback.
*/}}
{{- define "product-console.mongodb.host" -}}
{{- if .Values.mongodb.enabled -}}
{{- $name := default (printf "%s-mongodb" .Release.Name) .Values.mongodb.fullnameOverride -}}
{{- if and (not .Values.mongodb.fullnameOverride) .Values.mongodb.nameOverride -}}
{{- $name = printf "%s-%s" .Release.Name .Values.mongodb.nameOverride -}}
{{- end -}}
{{- /* The subchart resolves its own namespace from global.namespaceOverride and
   falls back to the release namespace; its LOCAL namespaceOverride is declared
   in its values but never read by its Service. Mirror that, so this host tracks
   where the Service is really created. */ -}}
{{- $ns := default .Release.Namespace .Values.global.namespaceOverride -}}
{{- printf "%s.%s.svc.cluster.local" $name $ns -}}
{{- else -}}
mongodb
{{- end -}}
{{- end }}
