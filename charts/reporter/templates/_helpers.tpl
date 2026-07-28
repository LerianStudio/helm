{{/*
Expand the name of the chart.
*/}}
{{- define "reporter.name" -}}
{{- default "reporter" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart and plugin manager.
*/}}
{{- define "plugin-manager.name" -}}
{{- default "reporter-manager" .Values.manager.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart and plugin worker.
*/}}
{{- define "plugin-worker.name" -}}
{{- default "reporter-worker" .Values.worker.name | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create chart name and version as used by the chart label for plugin manager.
*/}}
{{- define "plugin-manager.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin worker.
*/}}
{{- define "plugin-worker.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create a default fully qualified app name manager.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-manager.fullname" -}}
{{- default "reporter-manager" .Values.manager.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a unique name for cluster-scoped resources (ClusterRole, ClusterRoleBinding).
Includes namespace to avoid conflicts when multiple releases exist in different namespaces.
*/}}
{{- define "plugin-manager.clusterResourceName" -}}
{{- $namespace := include "global.namespace" . -}}
{{- $name := default "reporter-manager" .Values.manager.name -}}
{{- printf "%s-%s" $name $namespace | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name worker.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-worker.fullname" -}}
{{- default "reporter-worker" .Values.worker.name | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create app version.
*/}}
{{- define "plugin.version" -}}
{{- printf "%s" .Chart.AppVersion | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
manager Selector labels
*/}}
{{- define "plugin-manager.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-manager.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
worker Selector labels
*/}}
{{- define "plugin-worker.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "plugin-worker.name" .context }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}


{{/*
manager Common labels
*/}}
{{- define "plugin-manager.labels" -}}
helm.sh/chart: {{ include "plugin-manager.chart" .context }}
{{ include "plugin-manager.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
worker Common labels
*/}}
{{- define "plugin-worker.labels" -}}
helm.sh/chart: {{ include "plugin-worker.chart" .context }}
{{ include "plugin-worker.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}


{{/*
Create the name of the manager service account to use
*/}}
{{- define "plugin-manager.serviceAccountName" -}}
{{- if .Values.manager.serviceAccount.create }}
{{- default (include "plugin-manager.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.manager.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the worker service account to use
*/}}
{{- define "plugin-worker.serviceAccountName" -}}
{{- if .Values.worker.serviceAccount.create }}
{{- default (include "plugin-worker.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.worker.serviceAccount.name }}
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
reporter.infraSecretRef — emit a `- name: <envName> valueFrom: secretKeyRef: {name,key}` entry
pointing at a Bitnami subchart's generated Secret (or the operator's existingSecret override).
Inputs (dict): context (root .), subchart ("mongodb"), key, envName.
See docs/helm-chart-standard.md "Single-Source Infra Secrets".
*/}}
{{- define "reporter.infraSecretRef" -}}
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
reporter.mongoInternal — true when the bundled Bitnami mongodb subchart provides the DB.
*/}}
{{- define "reporter.mongoInternal" -}}
{{- $mongo := default dict .Values.mongodb -}}
{{- if and (ne (toString $mongo.enabled) "false") (not $mongo.external) -}}true{{- else -}}false{{- end -}}
{{- end }}

{{/*
reporter.mongoExternalSecretData — emit the MONGO_PASSWORD app-Secret data entry ONLY for an
external MongoDB without an existingSecret (the operator supplies it inline). For the bundled
subchart the password lives in <release>-mongodb and this emits nothing.
*/}}
{{- define "reporter.mongoExternalSecretData" -}}
{{- $mongo := default dict .Values.mongodb -}}
{{- $mongoAuth := default dict $mongo.auth -}}
{{- if and (ne (include "reporter.mongoInternal" .) "true") (not $mongoAuth.existingSecret) .Values.secrets.MONGO_PASSWORD -}}
MONGO_PASSWORD: {{ .Values.secrets.MONGO_PASSWORD | toString | b64enc | quote }}
{{- end -}}
{{- end }}

{{/*
reporter.mongoPasswordEnv — emit the MONGO_PASSWORD env entry for an app workload, single-sourced.
Bundled subchart -> secretKeyRef to <release>-mongodb/mongodb-root-password (or existingSecret).
External inline -> secretKeyRef to the given app Secret name / MONGO_PASSWORD.
Input (dict): context (root .), secretName (the app Secret name for the external-inline fallback).
*/}}
{{- define "reporter.mongoPasswordEnv" -}}
{{- $ctx := .context -}}
{{- $mongo := default dict $ctx.Values.mongodb -}}
{{- $mongoAuth := default dict $mongo.auth -}}
{{- if or (eq (include "reporter.mongoInternal" $ctx) "true") $mongoAuth.existingSecret -}}
{{ include "reporter.infraSecretRef" (dict "context" $ctx "subchart" "mongodb" "key" "mongodb-root-password" "envName" "MONGO_PASSWORD") }}
{{- else if $ctx.Values.secrets.MONGO_PASSWORD -}}
- name: MONGO_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .secretName }}
      key: MONGO_PASSWORD
{{- end -}}
{{- end }}

{{/*
reporter.rabbitmqErlangCookieRequired — fail when the bundled groundhog2k rabbitmq subchart is
enabled but no erlang cookie is provided. The broker is pointed at the app Secret via
authentication.existingSecret, which suppresses the inline cookie value, so a stable
operator-provided cookie is mandatory for clustering across restarts.
*/}}
{{- define "reporter.rabbitmqErlangCookieRequired" -}}
{{- $rmq := default dict .Values.rabbitmq -}}
{{- $rmqEnabled := true -}}
{{- if hasKey $rmq "enabled" -}}{{- $rmqEnabled = $rmq.enabled -}}{{- end -}}
{{- if and $rmqEnabled (not .Values.secrets.RABBITMQ_ERLANG_COOKIE) -}}
{{- fail "\n\nERROR: secrets.RABBITMQ_ERLANG_COOKIE is REQUIRED when the bundled rabbitmq subchart is enabled.\n   The broker reads its Erlang cookie from the application Secret (single source).\n   Provide a stable value (it must not change across upgrades) e.g.: openssl rand -hex 32\n" -}}
{{- end -}}
{{- end }}

{{/*
reporter.rabbitmqExistingSecretConsistent — fail when the bundled groundhog2k rabbitmq subchart is
enabled and still carries the SHIPPED DEFAULT authentication.existingSecret ("reporter-manager") but
the manager Secret has been renamed (manager.name / fullnameOverride), so the broker would reference a
Secret that does not exist. values.yaml cannot template, so this render-time gate catches the drift.
Custom (non-default) existingSecret values are the operator's responsibility and pass untouched.
*/}}
{{- define "reporter.rabbitmqExistingSecretConsistent" -}}
{{- $rmq := default dict .Values.rabbitmq -}}
{{- $rmqEnabled := true -}}
{{- if hasKey $rmq "enabled" -}}{{- $rmqEnabled = $rmq.enabled -}}{{- end -}}
{{- $auth := default dict $rmq.authentication -}}
{{- $managerName := ternary .Values.manager.existingSecretName (include "plugin-manager.fullname" .) .Values.manager.useExistingSecret -}}
{{- if and $rmqEnabled (eq (default "" $auth.existingSecret) "reporter-manager") (ne $managerName "reporter-manager") -}}
{{- fail (printf "\n\nERROR: rabbitmq.authentication.existingSecret is still the shipped default \"reporter-manager\" but the manager Secret renders as %q.\n   The broker would reference a Secret that does not exist.\n   Update rabbitmq.authentication.existingSecret to %q (or set it to your own existing Secret).\n" $managerName $managerName) -}}
{{- end -}}
{{- end }}

{{/*
==============================================================================
reporter.commonConfigData — the SHARED (common) ConfigMap block, emitted
identically by both the manager and worker ConfigMaps (mirrors the legacy
`common.configmap` map that both components ranged over).

Every key routes through lerian-common helpers so the productized grouped params
(`common.<group>.<field>`) work while the legacy raw key still WINS:
  precedence: <merged configmap native key>  >  common.<group>.<field>  >  default
The `default` for each key equals the pre-productization render, so a default
install stays byte-identical. Datastore hosts/user/port go through the
`lerian-common.datastore.value` mask (global.datastores / <chart>.datastores).

Inputs (dict):
  context (req)  product root ($)
  cm      (req)  the component's MERGED legacy override map
                 (`merge <component>.configmap common.configmap`, component wins)
==============================================================================
*/}}
{{- define "reporter.commonConfigData" -}}
{{- $ := .context -}}
{{- $cm := .cm | default dict -}}
{{- $common := $.Values.common | default dict -}}
{{- $broker := $common.broker | default dict -}}
{{- $redis := $common.redis | default dict -}}
{{- $os := $common.objectStorage | default dict -}}
{{- $mongo := $common.mongo | default dict -}}
{{- $fetcher := $common.fetcher | default dict -}}
{{- $mt := $common.multiTenant | default dict -}}
{{- $ds := ($common.datasource | default dict).onboarding | default dict -}}
{{- $rabbitHost := include "lerian-common.datastore.value" (dict "context" $ "configmap" $cm "type" "broker" "field" "host" "nativeKey" "RABBITMQ_HOST" "default" "reporter-rabbitmq.reporter.svc.cluster.local") -}}
{{- $portHost := include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "RABBITMQ_PORT_HOST" "params" $broker "field" "portHost" "default" "15672") -}}
# ENV
ENV_NAME: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "ENV_NAME" "params" $common "field" "env" "default" "development") | quote }}
# RABBITMQ
RABBITMQ_URI: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "RABBITMQ_URI" "params" $broker "field" "uri" "default" "amqp") | quote }}
RABBITMQ_PORT_HOST: {{ $portHost | quote }}
RABBITMQ_HOST: {{ $rabbitHost | quote }}
RABBITMQ_PORT_AMQP: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "RABBITMQ_PORT_AMQP" "params" $broker "field" "portAmqp" "default" "5672") | quote }}
RABBITMQ_NUMBERS_OF_WORKERS: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "RABBITMQ_NUMBERS_OF_WORKERS" "params" $broker "field" "workers" "default" "5") | quote }}
RABBITMQ_EXCHANGE: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "RABBITMQ_EXCHANGE" "params" $broker "field" "exchange" "default" "reporter.generate-report.exchange") | quote }}
RABBITMQ_GENERATE_REPORT_QUEUE: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "RABBITMQ_GENERATE_REPORT_QUEUE" "params" $broker "field" "generateReportQueue" "default" "reporter.generate-report.queue") | quote }}
RABBITMQ_GENERATE_REPORT_KEY: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "RABBITMQ_GENERATE_REPORT_KEY" "params" $broker "field" "generateReportKey" "default" "reporter.generate-report.key") | quote }}
RABBITMQ_HEALTH_CHECK_URL: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "RABBITMQ_HEALTH_CHECK_URL" "params" $broker "field" "healthCheckUrl" "default" "http://reporter-rabbitmq.reporter.svc.cluster.local:15672") | quote }}
# REDIS
REDIS_MASTER_NAME: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "REDIS_MASTER_NAME" "params" $redis "field" "masterName" "default" "") | quote }}
REDIS_HOST: {{ include "lerian-common.datastore.value" (dict "context" $ "configmap" $cm "type" "redis" "field" "host" "nativeKey" "REDIS_HOST" "default" "reporter-valkey.reporter.svc.cluster.local:6379") | quote }}
REDIS_DB: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "REDIS_DB" "params" $redis "field" "db" "default" "0") | quote }}
REDIS_PROTOCOL: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "REDIS_PROTOCOL" "params" $redis "field" "protocol" "default" "3") | quote }}
REDIS_TLS: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "REDIS_TLS" "params" $redis "field" "tls" "default" "false") | quote }}
REDIS_CA_CERT: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "REDIS_CA_CERT" "params" $redis "field" "caCert" "default" "") | quote }}
GOOGLE_APPLICATION_CREDENTIALS: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "GOOGLE_APPLICATION_CREDENTIALS" "params" $redis "field" "googleAppCredentials" "default" "") | quote }}
REDIS_SERVICE_ACCOUNT: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "REDIS_SERVICE_ACCOUNT" "params" $redis "field" "serviceAccount" "default" "") | quote }}
# OBJECT STORAGE (SeaweedFS by default; endpoint via the datastore mask)
OBJECT_STORAGE_ENDPOINT: {{ include "lerian-common.datastore.value" (dict "context" $ "configmap" $cm "type" "objectStorage" "field" "endpoint" "nativeKey" "OBJECT_STORAGE_ENDPOINT" "default" "http://seaweedfs-s3.reporter.svc.cluster.local:8333") | quote }}
OBJECT_STORAGE_REGION: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "OBJECT_STORAGE_REGION" "params" $os "field" "region" "default" "us-east-1") | quote }}
OBJECT_STORAGE_USE_PATH_STYLE: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "OBJECT_STORAGE_USE_PATH_STYLE" "params" $os "field" "usePathStyle" "default" "true") | quote }}
OBJECT_STORAGE_DISABLE_SSL: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "OBJECT_STORAGE_DISABLE_SSL" "params" $os "field" "disableSsl" "default" "true") | quote }}
OBJECT_STORAGE_BUCKET: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "OBJECT_STORAGE_BUCKET" "params" $os "field" "bucket" "default" "reporter-storage") | quote }}
# MONGO DB (host/user/port via the datastore mask; identity/tuning via grouped params)
MONGO_URI: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "MONGO_URI" "params" $mongo "field" "uri" "default" "mongodb") | quote }}
MONGO_HOST: {{ include "lerian-common.datastore.value" (dict "context" $ "configmap" $cm "type" "mongo" "field" "host" "nativeKey" "MONGO_HOST" "default" "reporter-mongodb.reporter.svc.cluster.local") | quote }}
MONGO_NAME: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "MONGO_NAME" "params" $mongo "field" "name" "default" "reporter-db") | quote }}
MONGO_USER: {{ include "lerian-common.datastore.value" (dict "context" $ "configmap" $cm "type" "mongo" "field" "user" "nativeKey" "MONGO_USER" "default" "reporter") | quote }}
MONGO_PORT: {{ include "lerian-common.datastore.value" (dict "context" $ "configmap" $cm "type" "mongo" "field" "port" "nativeKey" "MONGO_PORT" "default" "27017") | quote }}
MONGO_MAX_POOL_SIZE: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "MONGO_MAX_POOL_SIZE" "params" $mongo "field" "maxPoolSize" "default" "1000") | quote }}
MONGO_TLS_CA_CERT: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "MONGO_TLS_CA_CERT" "params" $mongo "field" "tlsCaCert" "default" "") | quote }}
MONGO_PARAMETERS: {{ include "lerian-common.datastore.value" (dict "context" $ "configmap" $cm "type" "mongo" "field" "params" "nativeKey" "MONGO_PARAMETERS" "default" "") | quote }}
# FETCHER INTEGRATION
FETCHER_ENABLED: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "FETCHER_ENABLED" "params" $fetcher "field" "enabled" "default" "false") | quote }}
FETCHER_URL: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "FETCHER_URL" "params" $fetcher "field" "url" "default" "") | quote }}
# MULTI-TENANT (reporter exposes only the ENABLED knob; no gated MT block today)
MULTI_TENANT_ENABLED: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "MULTI_TENANT_ENABLED" "params" $mt "field" "enabled" "default" "false") | quote }}
# MIDAZ ONBOARDING DATASOURCE (host/port/user/ssl via the postgres datastore mask)
DATASOURCE_ONBOARDING_CONFIG_NAME: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "DATASOURCE_ONBOARDING_CONFIG_NAME" "params" $ds "field" "configName" "default" "midaz_onboarding") | quote }}
DATASOURCE_ONBOARDING_HOST: {{ include "lerian-common.datastore.value" (dict "context" $ "configmap" $cm "type" "postgres" "field" "host" "nativeKey" "DATASOURCE_ONBOARDING_HOST" "default" "midaz-postgresql-replication.midaz.svc.cluster.local") | quote }}
DATASOURCE_ONBOARDING_PORT: {{ include "lerian-common.datastore.value" (dict "context" $ "configmap" $cm "type" "postgres" "field" "port" "nativeKey" "DATASOURCE_ONBOARDING_PORT" "default" "5432") | quote }}
DATASOURCE_ONBOARDING_USER: {{ include "lerian-common.datastore.value" (dict "context" $ "configmap" $cm "type" "postgres" "field" "user" "nativeKey" "DATASOURCE_ONBOARDING_USER" "default" "midaz") | quote }}
DATASOURCE_ONBOARDING_DATABASE: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "DATASOURCE_ONBOARDING_DATABASE" "params" $ds "field" "database" "default" "onboarding") | quote }}
DATASOURCE_ONBOARDING_TYPE: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "DATASOURCE_ONBOARDING_TYPE" "params" $ds "field" "type" "default" "postgresql") | quote }}
DATASOURCE_ONBOARDING_SSLMODE: {{ include "lerian-common.datastore.value" (dict "context" $ "configmap" $cm "type" "postgres" "field" "ssl" "nativeKey" "DATASOURCE_ONBOARDING_SSLMODE" "default" "disable") | quote }}
DATASOURCE_ONBOARDING_SSLROOTCERT: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "DATASOURCE_ONBOARDING_SSLROOTCERT" "params" $ds "field" "sslRootCert" "default" "") | quote }}
{{- $sd := $common.serviceDiscovery | default dict }}
{{- $streaming := $common.streaming | default dict }}
# SERVICE DISCOVERY (lib-service-discovery) — shared by manager + worker.
# Env-wide server config (Consul address/TLS/workload/preferView) comes from
# global.serviceDiscovery; the advertise endpoints (SD_INTERNAL_*/SD_EXTERNAL_*,
# which the lib accepts in place of legacy SD_ADVERTISE_*) derive from the reporter
# API (manager) Service + ingress — reporter registers under that identity.
# SD_ENABLED resolves via cfgValue (legacy configmap.SD_ENABLED WINS over the
# grouped param; compared to "true" so a legacy "false" is not truthy). The SAME
# resolved bool gates both the emitted SD_ENABLED and the helper. INERT until
# enabled AND global.serviceDiscovery.address is set (backward-compatible).
{{- $sdEnabled := eq (include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "SD_ENABLED" "params" $sd "field" "enabled" "default" "false")) "true" }}
SD_ENABLED: {{ $sdEnabled | quote }}
{{- with (include "lerian-common.serviceDiscovery.env" (dict
      "context" $
      "enabled" $sdEnabled
      "name" (include "plugin-manager.fullname" $)
      "port" $.Values.manager.service.port
      "namespace" (include "global.namespace" $)
      "ingressHost" (include "lerian-common.firstIngressHost" (dict "ingress" $.Values.manager.ingress)))) }}
{{ . }}
{{- end }}
# STREAMING (lib-streaming) — shared by manager + worker. Brokers/SASL/TLS come
# from global.streaming; client identity (clientId/cloudeventsSource) is shared.
# STREAMING_ENABLED resolves via cfgValue (legacy configmap.STREAMING_ENABLED WINS);
# the SAME resolved bool gates the env var and the helper. INERT until enabled AND
# global.streaming.brokers is set (backward-compatible).
{{- $streamingEnabled := eq (include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "STREAMING_ENABLED" "params" $streaming "field" "enabled" "default" "false")) "true" }}
STREAMING_ENABLED: {{ $streamingEnabled | quote }}
{{- with (include "lerian-common.streaming.env" (dict
      "context" $
      "enabled" $streamingEnabled
      "clientId" ($streaming.clientId | default "reporter")
      "cloudeventsSource" ($streaming.cloudeventsSource | default "//lerian.reporter"))) }}
{{ . }}
{{- end }}
{{- end }}

{{/*
reporter.commonConfigKeys — space-separated list of every SHARED env key that
`reporter.commonConfigData` (+ the OTEL block) emits explicitly. Each component
ConfigMap uses it to build the "reserved" set so its legacy passthrough range
(preserving arbitrary keys like DATASOURCE_EXTERNAL_*) never double-emits a key
already rendered by the enumerated block.
*/}}
{{- define "reporter.commonConfigKeys" -}}
ENV_NAME RABBITMQ_URI RABBITMQ_PORT_HOST RABBITMQ_HOST RABBITMQ_PORT_AMQP RABBITMQ_NUMBERS_OF_WORKERS RABBITMQ_EXCHANGE RABBITMQ_GENERATE_REPORT_QUEUE RABBITMQ_GENERATE_REPORT_KEY RABBITMQ_HEALTH_CHECK_URL REDIS_MASTER_NAME REDIS_HOST REDIS_DB REDIS_PROTOCOL REDIS_TLS REDIS_CA_CERT GOOGLE_APPLICATION_CREDENTIALS REDIS_SERVICE_ACCOUNT OBJECT_STORAGE_ENDPOINT OBJECT_STORAGE_REGION OBJECT_STORAGE_USE_PATH_STYLE OBJECT_STORAGE_DISABLE_SSL OBJECT_STORAGE_BUCKET MONGO_URI MONGO_HOST MONGO_NAME MONGO_USER MONGO_PORT MONGO_MAX_POOL_SIZE MONGO_TLS_CA_CERT MONGO_PARAMETERS FETCHER_ENABLED FETCHER_URL MULTI_TENANT_ENABLED DATASOURCE_ONBOARDING_CONFIG_NAME DATASOURCE_ONBOARDING_HOST DATASOURCE_ONBOARDING_PORT DATASOURCE_ONBOARDING_USER DATASOURCE_ONBOARDING_DATABASE DATASOURCE_ONBOARDING_TYPE DATASOURCE_ONBOARDING_SSLMODE DATASOURCE_ONBOARDING_SSLROOTCERT SD_ENABLED SD_ADDRESS SD_TLS SD_TLS_SKIP_VERIFY SD_WORKLOAD SD_PREFER_VIEW SD_INTERNAL_ADDRESS SD_INTERNAL_PORT SD_INTERNAL_SCHEME SD_EXTERNAL_ADDRESS SD_EXTERNAL_PORT STREAMING_ENABLED STREAMING_BROKERS STREAMING_TLS_ENABLED STREAMING_SASL_MECHANISM STREAMING_SASL_USERNAME STREAMING_CLIENT_ID STREAMING_CLOUDEVENTS_SOURCE OTEL_RESOURCE_SERVICE_NAME OTEL_LIBRARY_NAME OTEL_RESOURCE_SERVICE_VERSION OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT OTEL_EXPORTER_OTLP_ENDPOINT_PORT OTEL_EXPORTER_OTLP_ENDPOINT ENABLE_TELEMETRY OTEL_INSECURE_EXPORTER VERSION annotations
{{- end }}

{{/*
reporter.legacyConfigPassthrough — emit any leftover key in the merged legacy
override map (`merge <component>.configmap common.configmap`) that the enumerated
block did NOT already render. Preserves full backward-compat for arbitrary raw
keys (e.g. DATASOURCE_EXTERNAL_*). Emits nothing when configmap is empty (default).
Inputs (dict): cm (merged map), reserved (space-separated reserved key list).
*/}}
{{- define "reporter.legacyConfigPassthrough" -}}
{{- $cm := .cm | default dict -}}
{{- $reserved := dict -}}
{{- range (splitList " " .reserved) -}}{{- $reserved = set $reserved . true -}}{{- end -}}
{{- range $k, $v := $cm -}}
{{- if not (hasKey $reserved $k) }}
{{ $k }}: {{ $v | quote }}
{{- end -}}
{{- end -}}
{{- end }}

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
