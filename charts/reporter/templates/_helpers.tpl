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
reporter.isTrue — "true" when the value is a truthy token (case-insensitive).
*/}}
{{- define "reporter.isTrue" -}}
{{- $v := lower (trim (toString .)) -}}
{{- if or (eq $v "true") (eq $v "1") (eq $v "yes") (eq $v "on") -}}true{{- end -}}
{{- end -}}

{{/*
reporter.commonConfigmapData — the SHARED (common) ConfigMap data block for both the
manager and worker surfaces. Dependency CONNECTIONS are resolved through lerian-common
typed masks/helpers (datastore.value / globalValue / streaming.env); everything else is
an escape-hatch passthrough (`$cm.KEY | default "X"`). Native `common.configmap.<KEY>`
still wins for every masked field (top mask precedence). An operator can add any other
key under common.configmap and it flows through the guarded range at the end.
Input: the root context ($).
*/}}
{{- define "reporter.commonConfigmapData" -}}
{{- $ := . -}}
{{- $cm := .Values.common.configmap | default dict -}}
{{- $ded := .Values.datastores | default dict -}}
{{- $dv := "lerian-common.datastore.value" -}}
{{- $osv := "lerian-common.objectStorage.value" -}}
{{- /* Broker host+mgmt-port resolved once (via the datastore mask) — reused by RABBITMQ_HOST,
   RABBITMQ_PORT_HOST and the derived RABBITMQ_HEALTH_CHECK_URL (single-source). */ -}}
{{- $rmqHost := include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "broker" "field" "host" "nativeKey" "RABBITMQ_HOST" "default" "reporter-rabbitmq") -}}
{{- $rmqMgmtPort := include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "broker" "field" "port" "nativeKey" "RABBITMQ_PORT_HOST" "default" "15672") -}}
{{- $streamingRaw := (($.Values.global | default dict).streaming | default dict).enabled -}}
{{- if hasKey $cm "STREAMING_ENABLED" }}{{- $streamingRaw = index $cm "STREAMING_ENABLED" -}}{{- end -}}
{{- $streamingEnabled := eq (include "reporter.isTrue" ($streamingRaw | default "false")) "true" -}}
{{- /* Multi-tenant toggle: configmap override > global.multiTenant.enabled > false. */ -}}
{{- $mtRaw := $cm.MULTI_TENANT_ENABLED | default ((($.Values.global | default dict).multiTenant | default dict).enabled) | default "false" -}}
{{- /* Keys emitted explicitly below; the guarded range must not re-emit them. */ -}}
{{- $explicit := list
    "ENV_NAME" "ALLOW_INSECURE_TLS" "LOG_LEVEL"
    "RABBITMQ_URI" "RABBITMQ_HOST" "RABBITMQ_PORT_HOST" "RABBITMQ_PORT_AMQP"
    "RABBITMQ_NUMBERS_OF_WORKERS" "RABBITMQ_EXCHANGE" "RABBITMQ_GENERATE_REPORT_QUEUE"
    "RABBITMQ_GENERATE_REPORT_KEY" "RABBITMQ_HEALTH_CHECK_URL" "RABBITMQ_REPORT_EVENTS_EXCHANGE"
    "REDIS_HOST" "REDIS_USER" "REDIS_MASTER_NAME" "REDIS_DB" "REDIS_PROTOCOL" "REDIS_TLS" "REDIS_CA_CERT"
    "GOOGLE_APPLICATION_CREDENTIALS" "REDIS_SERVICE_ACCOUNT"
    "OBJECT_STORAGE_ENDPOINT" "OBJECT_STORAGE_REGION" "OBJECT_STORAGE_USE_PATH_STYLE"
    "OBJECT_STORAGE_DISABLE_SSL" "OBJECT_STORAGE_BUCKET"
    "MONGO_URI" "MONGO_HOST" "MONGO_NAME" "MONGO_USER" "MONGO_PORT" "MONGO_MAX_POOL_SIZE"
    "MONGO_TLS_CA_CERT" "MONGO_PARAMETERS"
    "OTEL_LIBRARY_NAME" "OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT" "OTEL_EXPORTER_OTLP_ENDPOINT_PORT"
    "OTEL_EXPORTER_OTLP_ENDPOINT" "ENABLE_TELEMETRY" "OTEL_INSECURE_EXPORTER"
    "FETCHER_ENABLED" "FETCHER_URL" "MULTI_TENANT_ENABLED"
    "MULTI_TENANT_URL" "MULTI_TENANT_ENVIRONMENT" "MULTI_TENANT_ALLOW_INSECURE_HTTP"
    "MULTI_TENANT_MAX_TENANT_POOLS" "MULTI_TENANT_IDLE_TIMEOUT_SEC"
    "MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD" "MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC"
    "MULTI_TENANT_REDIS_HOST" "MULTI_TENANT_REDIS_PORT" "MULTI_TENANT_REDIS_TLS" "MULTI_TENANT_REDIS_CA_CERT"
    "MULTI_TENANT_TIMEOUT" "MULTI_TENANT_CACHE_TTL_SEC" "MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC"
    "PLUGIN_AUTH_ENABLED" "PLUGIN_AUTH_ADDRESS"
    "SD_ENABLED" "SD_ADDRESS" "SD_ADVERTISE_ADDRESS" "SD_ADVERTISE_PORT" "SD_WORKLOAD"
    "SD_TLS" "SD_TLS_SKIP_VERIFY" "STREAMING_ENABLED"
    "STREAMING_BROKERS" "STREAMING_CLOUDEVENTS_SOURCE" "STREAMING_CLIENT_ID"
    "STREAMING_COMPRESSION" "STREAMING_REQUIRED_ACKS"
    "DATASOURCE_ONBOARDING_CONFIG_NAME" "DATASOURCE_ONBOARDING_HOST" "DATASOURCE_ONBOARDING_PORT"
    "DATASOURCE_ONBOARDING_USER" "DATASOURCE_ONBOARDING_DATABASE" "DATASOURCE_ONBOARDING_TYPE"
    "DATASOURCE_ONBOARDING_SSLMODE" "DATASOURCE_ONBOARDING_SSLROOTCERT"
-}}
ENV_NAME: {{ $cm.ENV_NAME | default "development" | quote }}
ALLOW_INSECURE_TLS: {{ $cm.ALLOW_INSECURE_TLS | default "true" | quote }}
{{- /* RabbitMQ broker connection via datastore mask (host/port/user); tuning stays passthrough. */}}
RABBITMQ_URI: {{ $cm.RABBITMQ_URI | default "amqp" | quote }}
RABBITMQ_HOST: {{ $rmqHost | quote }}
RABBITMQ_PORT_HOST: {{ $rmqMgmtPort | quote }}
RABBITMQ_PORT_AMQP: {{ $cm.RABBITMQ_PORT_AMQP | default "5672" | quote }}
RABBITMQ_NUMBERS_OF_WORKERS: {{ $cm.RABBITMQ_NUMBERS_OF_WORKERS | default "5" | quote }}
RABBITMQ_EXCHANGE: {{ $cm.RABBITMQ_EXCHANGE | default "reporter.generate-report.exchange" | quote }}
RABBITMQ_GENERATE_REPORT_QUEUE: {{ $cm.RABBITMQ_GENERATE_REPORT_QUEUE | default "reporter.generate-report.queue" | quote }}
RABBITMQ_GENERATE_REPORT_KEY: {{ $cm.RABBITMQ_GENERATE_REPORT_KEY | default "reporter.generate-report.key" | quote }}
{{- /* Health-check URL single-sourced from the broker mask (host:mgmt-port); configmap override still wins. */}}
RABBITMQ_HEALTH_CHECK_URL: {{ $cm.RABBITMQ_HEALTH_CHECK_URL | default (printf "http://%s:%s" $rmqHost $rmqMgmtPort) | quote }}
{{- /* Redis/Valkey connection via datastore mask (host carries host:port). */}}
REDIS_HOST: {{ include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "redis" "field" "host" "nativeKey" "REDIS_HOST" "default" "reporter-valkey:6379") | quote }}
REDIS_USER: {{ include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "redis" "field" "user" "nativeKey" "REDIS_USER" "default" "") | quote }}
REDIS_MASTER_NAME: {{ $cm.REDIS_MASTER_NAME | default "" | quote }}
REDIS_DB: {{ $cm.REDIS_DB | default "0" | quote }}
REDIS_PROTOCOL: {{ $cm.REDIS_PROTOCOL | default "3" | quote }}
REDIS_TLS: {{ $cm.REDIS_TLS | default "false" | quote }}
REDIS_CA_CERT: {{ $cm.REDIS_CA_CERT | default "" | quote }}
GOOGLE_APPLICATION_CREDENTIALS: {{ $cm.GOOGLE_APPLICATION_CREDENTIALS | default "" | quote }}
REDIS_SERVICE_ACCOUNT: {{ $cm.REDIS_SERVICE_ACCOUNT | default "" | quote }}
{{- /* Object storage (S3/SeaweedFS) — non-secret fields passthrough; keys stay in the Secret. */}}
{{- /* Object storage via lerian-common.objectStorage.value mask (name "s3"); non-secret
   fields only — keys stay in the Secret. configmap.OBJECT_STORAGE_* overrides objectStorage.s3
   / global.objectStorage.s3 / default. */}}
OBJECT_STORAGE_ENDPOINT: {{ include $osv (dict "context" $ "configmap" $cm "name" "s3" "field" "endpoint" "nativeKey" "OBJECT_STORAGE_ENDPOINT" "default" "http://seaweedfs-s3:8333") | quote }}
OBJECT_STORAGE_REGION: {{ include $osv (dict "context" $ "configmap" $cm "name" "s3" "field" "region" "nativeKey" "OBJECT_STORAGE_REGION" "default" "us-east-1") | quote }}
OBJECT_STORAGE_USE_PATH_STYLE: {{ include $osv (dict "context" $ "configmap" $cm "name" "s3" "field" "usePathStyle" "nativeKey" "OBJECT_STORAGE_USE_PATH_STYLE" "default" "true") | quote }}
OBJECT_STORAGE_DISABLE_SSL: {{ include $osv (dict "context" $ "configmap" $cm "name" "s3" "field" "disableSSL" "nativeKey" "OBJECT_STORAGE_DISABLE_SSL" "default" "true") | quote }}
OBJECT_STORAGE_BUCKET: {{ include $osv (dict "context" $ "configmap" $cm "name" "s3" "field" "bucket" "nativeKey" "OBJECT_STORAGE_BUCKET" "default" "reporter-storage") | quote }}
{{- /* MongoDB connection via datastore mask (host/port/user); name/tuning stay passthrough. */}}
MONGO_URI: {{ $cm.MONGO_URI | default "mongodb" | quote }}
MONGO_HOST: {{ include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "mongo" "field" "host" "nativeKey" "MONGO_HOST" "default" "reporter-mongodb") | quote }}
MONGO_NAME: {{ $cm.MONGO_NAME | default "reporter-db" | quote }}
MONGO_USER: {{ include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "mongo" "field" "user" "nativeKey" "MONGO_USER" "default" "reporter") | quote }}
MONGO_PORT: {{ include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "mongo" "field" "port" "nativeKey" "MONGO_PORT" "default" "27017") | quote }}
MONGO_MAX_POOL_SIZE: {{ $cm.MONGO_MAX_POOL_SIZE | default "20" | quote }}
MONGO_TLS_CA_CERT: {{ $cm.MONGO_TLS_CA_CERT | default "" | quote }}
MONGO_PARAMETERS: {{ $cm.MONGO_PARAMETERS | default "maxIdleTimeMS=60000" | quote }}
{{- /* Observability: enable/endpoint/deployment-env via lerian-common.otel.env (global.observability);
   identity (library/port/insecure) stays inline. configmap.<KEY> still overrides via otel.env. */}}
OTEL_LIBRARY_NAME: {{ $cm.OTEL_LIBRARY_NAME | default "github.com/LerianStudio/reporter" | quote }}
OTEL_EXPORTER_OTLP_ENDPOINT_PORT: {{ $cm.OTEL_EXPORTER_OTLP_ENDPOINT_PORT | default "4317" | quote }}
OTEL_INSECURE_EXPORTER: {{ $cm.OTEL_INSECURE_EXPORTER | default "false" | quote }}
{{- include "lerian-common.otel.env" (dict "context" $ "configmap" $cm "enabledDefault" "true" "endpointDefault" "otlp://midaz-otel-lgtm:4317" "deploymentEnvironmentDefault" "production") | nindent 0 }}
FETCHER_ENABLED: {{ $cm.FETCHER_ENABLED | default "false" | quote }}
FETCHER_URL: {{ $cm.FETCHER_URL | default "" | quote }}
MULTI_TENANT_ENABLED: {{ $mtRaw | quote }}
{{- /* Multi-tenant (lib-commons/multitenancy) via lerian-common.multiTenant.env — gated on
   MULTI_TENANT_ENABLED; emits nothing when off. RABBITMQ_MULTI_TENANT_* stay passthrough
   (reporter-specific). configmap.MULTI_TENANT_* overrides global.multiTenant. */}}
{{- include "lerian-common.multiTenant.env" (dict "context" $ "configmap" $cm
      "enabled" (eq (include "reporter.isTrue" $mtRaw) "true")
      "emitRedis" true "emitRedisCaCert" true "emitPool" true "emitCache" true
      "emitEnvironment" true "emitAllowInsecure" true) | nindent 0 }}
{{- /* Auth (access-manager) via lerian-common.auth.env → global.auth.{enabled,host}. The reporter
   app reads PLUGIN_AUTH_ADDRESS (NOT _HOST), so hostKey pins the correct native key. A native
   common.configmap.PLUGIN_AUTH_ENABLED/_ADDRESS still overrides (globalValue precedence). */}}
{{- include "lerian-common.auth.env" (dict "context" $ "configmap" $cm "hostKey" "PLUGIN_AUTH_ADDRESS" "hostDefault" "http://plugin-access-manager-auth:4000") | nindent 0 }}
{{- /* Service discovery via lerian-common.serviceDiscovery.envFlat (lib-service-discovery
   advertise contract: SD_ADDRESS + SD_ADVERTISE_* + SD_WORKLOAD + SD_TLS*). SD_ADDRESS default
   "" (reporter) overrides the helper's "localhost:8500"; configmap.SD_* still overrides. */}}
{{- include "lerian-common.serviceDiscovery.envFlat" (dict "configmap" $cm
      "keys" (list "SD_ENABLED" "SD_ADDRESS" "SD_ADVERTISE_ADDRESS" "SD_ADVERTISE_PORT" "SD_WORKLOAD" "SD_TLS" "SD_TLS_SKIP_VERIFY")
      "defaults" (dict "SD_ADDRESS" "")) | nindent 0 }}
{{- /* Streaming: knob inline; brokers/SASL/TLS transport + identity via global.streaming
   (gated — inert unless enabled AND global.streaming.brokers is set). RABBITMQ_REPORT_EVENTS_EXCHANGE
   is reporter-specific (RabbitMQ transport) and stays passthrough. */}}
STREAMING_ENABLED: {{ $cm.STREAMING_ENABLED | default "false" | quote }}
RABBITMQ_REPORT_EVENTS_EXCHANGE: {{ $cm.RABBITMQ_REPORT_EVENTS_EXCHANGE | default "reporter.events" | quote }}
{{- if $streamingEnabled }}
{{- include "lerian-common.streaming.env" (dict
      "context" $
      "enabled" $streamingEnabled
      "configmap" $cm
      "clientId" ($cm.STREAMING_CLIENT_ID | default "reporter")
      "cloudeventsSource" ($cm.STREAMING_CLOUDEVENTS_SOURCE | default "//lerian.reporter")) | nindent 0 }}
{{- end }}
{{- /* External midaz datasource (direct-query mode) via postgres datastore mask. */}}
DATASOURCE_ONBOARDING_CONFIG_NAME: {{ $cm.DATASOURCE_ONBOARDING_CONFIG_NAME | default "midaz_onboarding" | quote }}
DATASOURCE_ONBOARDING_HOST: {{ include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "postgres" "field" "host" "nativeKey" "DATASOURCE_ONBOARDING_HOST" "default" "midaz-postgresql-replication.midaz.svc.cluster.local") | quote }}
DATASOURCE_ONBOARDING_PORT: {{ include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "postgres" "field" "port" "nativeKey" "DATASOURCE_ONBOARDING_PORT" "default" "5432") | quote }}
DATASOURCE_ONBOARDING_USER: {{ include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "postgres" "field" "user" "nativeKey" "DATASOURCE_ONBOARDING_USER" "default" "midaz") | quote }}
DATASOURCE_ONBOARDING_DATABASE: {{ $cm.DATASOURCE_ONBOARDING_DATABASE | default "onboarding" | quote }}
DATASOURCE_ONBOARDING_TYPE: {{ $cm.DATASOURCE_ONBOARDING_TYPE | default "postgresql" | quote }}
DATASOURCE_ONBOARDING_SSLMODE: {{ include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "postgres" "field" "ssl" "nativeKey" "DATASOURCE_ONBOARDING_SSLMODE" "default" "disable") | quote }}
DATASOURCE_ONBOARDING_SSLROOTCERT: {{ $cm.DATASOURCE_ONBOARDING_SSLROOTCERT | default "" | quote }}
{{- /* Escape hatch: any OTHER key the operator adds under common.configmap. */}}
{{- range $key, $value := $cm }}
{{- if not (has $key $explicit) }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
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
