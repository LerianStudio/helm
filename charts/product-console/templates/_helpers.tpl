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
reads global.namespaceOverride in its own "mongodb.namespace" helper
(mongodb-16.4.0, templates/_helpers.tpl), falling back to the release
namespace, and that helper is what its Service, Secret and StatefulSet carry,
which is what this one has to track. Its LOCAL namespaceOverride is read by
four of its templates (networkpolicy, and the three update-password ones)
through common.names.namespace, so those four alone can land elsewhere.
Mirror the rule the Service and the Secret follow.
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

That resolution serves the topology this chart ships, and only that one: a
STANDALONE subchart whose Service carries the subchart's own fullname. Bitnami
names that Service through mongodb.service.nameOverride when it is set, and in
replicaset architecture publishes "<fullname>-headless" plus one DNS name per
replica instead (mongodb-16.4.0, templates/_helpers.tpl "mongodb.service.
nameOverride"), so neither configuration has a single correct default. The chart
refuses to render for those two rather than write a host that resolves nowhere,
and the refusal names the value to set.

With the subchart disabled the bare "mongodb" is kept, so an external MongoDB
published under that name keeps working untouched. Either way an operator's own
configmap.MONGO_HOST or global.datastores.mongo.host still wins: this is only
the fallback, and naming one is also what lifts the two refusals.
*/}}
{{- define "product-console.mongodb.host" -}}
{{- if .Values.mongodb.enabled -}}
{{- /* Resolved through the same mask the ConfigMap uses, minus the default, so
   "did anybody name a host" is answered by lerian-common's own precedence
   (native configmap key, then the dedicated mask, then the shared one) rather
   than by a second copy of it here. */ -}}
{{- $named := include "lerian-common.datastore.value" (dict "context" . "configmap" (.Values.configmap | default dict) "type" "mongo" "field" "host" "nativeKey" "MONGO_HOST") -}}
{{- $ns := include "product-console.mongodb.namespace" . -}}
{{- $arch := .Values.mongodb.architecture | default "standalone" -}}
{{- $svcName := (.Values.mongodb.service | default dict).nameOverride | default "" -}}
{{- if and (not $named) (ne $arch "standalone") -}}
{{- $headless := printf "%s-headless.%s.svc.cluster.local" (include "product-console.mongodb.fullname" .) $ns -}}
{{- fail (printf "product-console: mongodb.architecture is %s, so the bundled MongoDB publishes the headless Service %s and one DNS name per replica rather than a single Service, and configmap.MONGO_HOST has no correct default. Set configmap.MONGO_HOST to %s, and add replicaSet=%s to configmap.MONGO_PARAMETERS so the driver reads the whole replica set." $arch $headless $headless (.Values.mongodb.replicaSetName | default "rs0")) -}}
{{- end -}}
{{- if and (not $named) $svcName -}}
{{- fail (printf "product-console: mongodb.service.nameOverride is %s, so the bundled MongoDB's Service is named %s and the configmap.MONGO_HOST default would name a Service the release does not create. Set configmap.MONGO_HOST to %s.%s.svc.cluster.local." $svcName $svcName $svcName $ns) -}}
{{- end -}}
{{- include "lerian-common.internalHost" (dict "name" (include "product-console.mongodb.fullname" .) "namespace" $ns) -}}
{{- else -}}
mongodb
{{- end -}}
{{- end }}
