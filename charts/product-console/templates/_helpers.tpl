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
Secret carrying the console's own environment.

useExistingSecret switches from the Secret this chart creates to one the
operator brings, and existingSecretName is the key that names it. The half-set
state is refused here: an empty name renders a secretRef with no name at all,
which helm lint, helm template and the render gate all accept, and which the API
server then rejects at apply time with an error naming neither key. Trimmed
first, because `required` only rejects the empty string and a name of spaces
reaches the API server as the same nothing.
*/}}
{{- define "product-console.secretName" -}}
{{- if .Values.useExistingSecret -}}
{{- required "product-console: useExistingSecret is true, so existingSecretName must name the Secret holding the console's environment. Set existingSecretName, or set useExistingSecret to false to use the Secret this chart creates." (.Values.existingSecretName | default "" | trim) -}}
{{- else -}}
{{- include "product-console.fullname" . -}}
{{- end -}}
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
refuses to render for those two, and for both at once, rather than write a host
that resolves nowhere, and the refusal names the Service Bitnami really creates
for that combination plus the value to set.

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
{{- $replicaSet := ne $arch "standalone" -}}
{{- if and (not $named) (or $replicaSet $svcName) -}}
{{- /* ONE Bitnami helper answers for BOTH architectures (mongodb-16.4.0,
   templates/_helpers.tpl "mongodb.service.nameOverride"): the override wins
   whenever it is set, and only without one does a replica set fall back to
   "<fullname>-headless". Resolve the name the same way, or the refusal sends an
   operator to a Service the release never creates, which is the defect it
   exists to prevent. Both settings at once is a reachable combination, and it
   is the rename that wins there. */ -}}
{{- $svc := $svcName | default (ternary (printf "%s-headless" (include "product-console.mongodb.fullname" .)) (include "product-console.mongodb.fullname" .) $replicaSet) -}}
{{- $why := list -}}
{{- if $replicaSet -}}
{{- $why = append $why (printf "mongodb.architecture is %s" $arch) -}}
{{- end -}}
{{- if $svcName -}}
{{- $why = append $why (printf "mongodb.service.nameOverride is %s" $svcName) -}}
{{- end -}}
{{- $msg := printf "product-console: %s, so the bundled MongoDB's Service is named %s and configmap.MONGO_HOST has no correct default. Set configmap.MONGO_HOST to %s.%s.svc.cluster.local." (join " and " $why) $svc $svc $ns -}}
{{- if $replicaSet -}}
{{- $msg = printf "%s Architecture %s also publishes one DNS name per replica, so add replicaSet=%s to configmap.MONGO_PARAMETERS for the driver to read the whole set." $msg $arch (.Values.mongodb.replicaSetName | default "rs0") -}}
{{- end -}}
{{- fail $msg -}}
{{- end -}}
{{- include "lerian-common.internalHost" (dict "name" (include "product-console.mongodb.fullname" .) "namespace" $ns) -}}
{{- else -}}
mongodb
{{- end -}}
{{- end }}

{{/*
The configmap keys the chart declares WITHOUT a shipped default, because no
default is safe to invent: an address, a deployment-wide assertion, or a
frontend flag that is only correct once the operator states it. They are
emitted only when set, so a default render carries none of them and the
application's own built-in default stays in force.
*/}}
{{- define "product-console.optionalConfigKeys" -}}
{{- list
  "FETCHER_BASE_PATH"
  "FLOWKER_BASE_PATH"
  "MFA_ENABLED"
  "MIDAZ_CONSOLE_BASE_PATH"
  "MIDAZ_CONSOLE_SERVICE_HOST"
  "MULTI_TENANT_ENABLED"
  "NEXT_PUBLIC_DEMO_MODE"
  "NEXT_PUBLIC_MIDAZ_APPLICATION_OPTIONS"
  "PLUGIN_AUTH_PUBLIC_BASE_PATH"
  "PLUGIN_FEES_BASE_PATH"
  "TRACER_BASE_PATH"
  "TRUSTED_PROXIES"
  | join " " -}}
{{- end }}

{{/*
Render one optional key as a ConfigMap data entry, or nothing at all.
Args: dict "cm" <.Values.configmap> "key" <KEY>.
An unset key and an empty string mean the same thing here: leave it to the
application. That is what keeps the default render byte-identical.
*/}}
{{- define "product-console.optionalConfigKey" -}}
{{- $v := index .cm .key -}}
{{- if and (not (kindIs "invalid" $v)) (ne ($v | toString) "") -}}
{{ .key }}: {{ $v | toString | quote }}
{{- end -}}
{{- end }}

{{/*
Refuse to render when an optional key is supplied through BOTH configmap and
extraEnvVars: both write into the same ConfigMap data map, so the key would be
emitted twice and the surviving value is whatever the YAML parser happens to
keep. Only the keys listed above are checked, so installs that still deliver
them through extraEnvVars alone keep working untouched.
*/}}
{{- define "product-console.validateOptionalConfigKeys" -}}
{{- $cm := .Values.configmap | default dict -}}
{{- $extra := .Values.extraEnvVars | default dict -}}
{{- range $key := (splitList " " (include "product-console.optionalConfigKeys" .)) -}}
{{- $v := index $cm $key -}}
{{- if and (not (kindIs "invalid" $v)) (ne ($v | toString) "") (hasKey $extra $key) -}}
{{- fail (printf "%s is set both in configmap and in extraEnvVars. Both render into the same ConfigMap data map, so the key would be emitted twice and the effective value is whatever the YAML parser keeps - undefined behavior. Keep it in configmap.%s and remove it from extraEnvVars." $key $key) -}}
{{- end -}}
{{- end -}}
{{- end }}
