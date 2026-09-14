{{/*
Expand the name of the chart.
*/}}
{{- define "fetcher.name" -}}
{{- default (default "fetcher" .Values.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "fetcher.fullname" -}}
{{- default (include "fetcher.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "fetcher.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "fetcher.labels" -}}
helm.sh/chart: {{ include "fetcher.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Manager fullname
*/}}
{{- define "fetcher-manager.fullname" -}}
{{- printf "%s" .Values.manager.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Manager labels
*/}}
{{- define "fetcher-manager.labels" -}}
{{ include "fetcher.labels" . }}
app.kubernetes.io/name: {{ include "fetcher-manager.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: manager
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end }}

{{/*
Manager selector labels
*/}}
{{- define "fetcher-manager.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fetcher-manager.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Worker fullname
*/}}
{{- define "fetcher-worker.fullname" -}}
{{- printf "%s" .Values.worker.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Worker labels
*/}}
{{- define "fetcher-worker.labels" -}}
{{ include "fetcher.labels" . }}
app.kubernetes.io/name: {{ include "fetcher-worker.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: worker
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end }}

{{/*
Worker selector labels
*/}}
{{- define "fetcher-worker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fetcher-worker.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use for manager
*/}}
{{- define "fetcher-manager.serviceAccountName" -}}
{{- if .Values.manager.serviceAccount.create }}
{{- default (include "fetcher-manager.fullname" .) .Values.manager.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.manager.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use for worker
*/}}
{{- define "fetcher-worker.serviceAccountName" -}}
{{- if .Values.worker.serviceAccount.create }}
{{- default (include "fetcher-worker.fullname" .) .Values.worker.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.worker.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Expand the namespace of the release.
*/}}
{{- define "fetcher.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
fetcher.isTrue — "true" when the value is a truthy token (case-insensitive).
*/}}
{{- define "fetcher.isTrue" -}}
{{- $v := lower (trim (toString .)) -}}
{{- if or (eq $v "true") (eq $v "1") (eq $v "yes") (eq $v "on") -}}true{{- end -}}
{{- end -}}

{{/*
fetcher.commonConfigmapData — the SHARED (common) ConfigMap data block for both
the manager and worker surfaces. Dependency CONNECTIONS are resolved through
lerian-common typed masks/helpers (datastore.value / otel.env / multiTenant.env);
everything else is an escape-hatch passthrough (`$cm.KEY | default "X"`). Native
`common.configmap.<KEY>` still wins for every masked field (top mask precedence).
An operator can add any other key under common.configmap and it flows through
the guarded range at the end.
Input: the root context ($).
*/}}
{{- define "fetcher.commonConfigmapData" -}}
{{- $ := . -}}
{{- $cm := .Values.common.configmap | default dict -}}
{{- $ded := .Values.datastores | default dict -}}
{{- $dv := "lerian-common.datastore.value" -}}
{{- /* Broker host+mgmt-port resolved once (via the datastore mask) — reused by
   RABBITMQ_HOST, RABBITMQ_PORT_HOST and the derived RABBITMQ_HEALTH_CHECK_URL
   (single-source; these were two independent hardcoded literals before). */ -}}
{{- $rmqHost := include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "broker" "field" "host" "nativeKey" "RABBITMQ_HOST" "default" "rabbitmq") -}}
{{- $rmqMgmtPort := include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "broker" "field" "port" "nativeKey" "RABBITMQ_PORT_HOST" "default" "15672") -}}
{{- /* Multi-tenant toggle: configmap override > global.multiTenant.enabled > false.
   Presence-based (hasKey), not sprig `default` — an explicit
   `common.configmap.MULTI_TENANT_ENABLED: false` must win over a true
   global.multiTenant.enabled instead of silently falling through. */ -}}
{{- $mtRaw := (($.Values.global | default dict).multiTenant | default dict).enabled -}}
{{- if hasKey $cm "MULTI_TENANT_ENABLED" }}{{- $mtRaw = index $cm "MULTI_TENANT_ENABLED" -}}{{- end -}}
{{- if kindIs "invalid" $mtRaw }}{{- $mtRaw = "false" -}}{{- end -}}
{{- /* Keys emitted explicitly below; the guarded range must not re-emit them. */ -}}
{{- $explicit := list
    "MONGO_URI" "MONGO_HOST" "MONGO_NAME" "MONGO_PORT" "MONGO_MAX_POOL_SIZE"
    "MONGO_PARAMETERS" "MONGO_TLS_CA_CERT"
    "RABBITMQ_URI" "RABBITMQ_HOST" "RABBITMQ_PORT_AMQP" "RABBITMQ_PORT_HOST" "RABBITMQ_HEALTH_CHECK_URL"
    "SEAWEEDFS_HOST" "SEAWEEDFS_FILER_PORT" "SEAWEEDFS_TTL"
    "REDIS_HOST" "REDIS_PORT" "REDIS_DB"
    "OTEL_RESOURCE_SERVICE_NAME" "OTEL_LIBRARY_NAME" "OTEL_RESOURCE_SERVICE_VERSION"
    "OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT" "OTEL_EXPORTER_OTLP_ENDPOINT_PORT"
    "OTEL_EXPORTER_OTLP_ENDPOINT" "ENABLE_TELEMETRY" "OTEL_INSECURE_EXPORTER"
    "ALLOW_INSECURE_TLS"
    "MULTI_TENANT_ENABLED" "MULTI_TENANT_URL" "MULTI_TENANT_ENVIRONMENT"
    "MULTI_TENANT_MAX_TENANT_POOLS" "MULTI_TENANT_IDLE_TIMEOUT_SEC"
    "MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD" "MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC"
-}}
{{- /* MongoDB connection via datastore mask (host/port/params); name/tuning stay
   passthrough (no shared MongoDB-wide "database name" concept to mask — each
   product picks its own db). */ -}}
MONGO_URI: {{ $cm.MONGO_URI | default "mongodb" | quote }}
MONGO_HOST: {{ include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "mongo" "field" "host" "nativeKey" "MONGO_HOST" "default" "mongodb") | quote }}
MONGO_NAME: {{ $cm.MONGO_NAME | default "fetcher-db" | quote }}
MONGO_PORT: {{ include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "mongo" "field" "port" "nativeKey" "MONGO_PORT" "default" "27017") | quote }}
MONGO_MAX_POOL_SIZE: {{ $cm.MONGO_MAX_POOL_SIZE | default "1000" | quote }}
MONGO_PARAMETERS: {{ include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "mongo" "field" "params" "nativeKey" "MONGO_PARAMETERS" "default" "") | quote }}
MONGO_TLS_CA_CERT: {{ $cm.MONGO_TLS_CA_CERT | default "" | quote }}
{{- /* RabbitMQ broker connection via datastore mask. host/port(mgmt) plus the
   topology fields scheme (amqp|amqps) and amqpPort — so a managed-broker
   profile (e.g. AmazonMQ over TLS) sets global.datastores.broker.{scheme,
   amqpPort,port} once instead of scattering RABBITMQ_* into common.configmap.
   Defaults keep the bundled amqp/5672/15672 topology. */}}
RABBITMQ_URI: {{ include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "broker" "field" "scheme" "nativeKey" "RABBITMQ_URI" "default" "amqp") | quote }}
RABBITMQ_HOST: {{ $rmqHost | quote }}
RABBITMQ_PORT_AMQP: {{ include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "broker" "field" "amqpPort" "nativeKey" "RABBITMQ_PORT_AMQP" "default" "5672") | quote }}
RABBITMQ_PORT_HOST: {{ $rmqMgmtPort | quote }}
{{- /* Health-check URL single-sourced from the broker mask (host:mgmt-port);
   configmap override still wins. Previously an independent hardcoded literal
   that could silently drift from RABBITMQ_HOST/_PORT_HOST. */}}
RABBITMQ_HEALTH_CHECK_URL: {{ $cm.RABBITMQ_HEALTH_CHECK_URL | default (printf "http://%s:%s" $rmqHost $rmqMgmtPort) | quote }}
{{- /* SeaweedFS filer wire protocol — no lerian-common mask models this (it is
   NOT the S3-shaped objectStorage mask; that is worker's OBJECT_STORAGE_* for
   the extraction bucket). Passthrough only. */}}
SEAWEEDFS_HOST: {{ $cm.SEAWEEDFS_HOST | default "seaweedfs-filer" | quote }}
SEAWEEDFS_FILER_PORT: {{ $cm.SEAWEEDFS_FILER_PORT | default "8888" | quote }}
SEAWEEDFS_TTL: {{ $cm.SEAWEEDFS_TTL | default "6M" | quote }}
{{- /* Redis/Valkey connection via datastore mask. */}}
REDIS_HOST: {{ include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "redis" "field" "host" "nativeKey" "REDIS_HOST" "default" "valkey") | quote }}
REDIS_PORT: {{ include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "redis" "field" "port" "nativeKey" "REDIS_PORT" "default" "6379") | quote }}
REDIS_DB: {{ $cm.REDIS_DB | default "0" | quote }}
{{- /* Observability: enable/endpoint/deployment-env via lerian-common.otel.env
   (global.observability); identity (library/service-name/port/insecure) stays
   inline. configmap.<KEY> still overrides via otel.env. */}}
OTEL_RESOURCE_SERVICE_NAME: {{ $cm.OTEL_RESOURCE_SERVICE_NAME | default "fetcher" | quote }}
OTEL_LIBRARY_NAME: {{ $cm.OTEL_LIBRARY_NAME | default "github.com/LerianStudio/fetcher" | quote }}
OTEL_RESOURCE_SERVICE_VERSION: {{ $cm.OTEL_RESOURCE_SERVICE_VERSION | default "1.0.0-beta.1" | quote }}
OTEL_EXPORTER_OTLP_ENDPOINT_PORT: {{ $cm.OTEL_EXPORTER_OTLP_ENDPOINT_PORT | default "4317" | quote }}
OTEL_INSECURE_EXPORTER: {{ $cm.OTEL_INSECURE_EXPORTER | default "false" | quote }}
{{- include "lerian-common.otel.env" (dict "context" $ "configmap" $cm "enabledDefault" "false" "endpointDefault" "http://$(HOST_IP):4317" "deploymentEnvironmentDefault" "development") | nindent 0 }}
{{- /* TLS - bundled dev-mode MongoDB/RabbitMQ/Redis have no TLS; the app
   refuses to connect unless this is set. Not cloud/global masked (every
   Lerian chart keeps this as a plain per-chart default). */}}
ALLOW_INSECURE_TLS: {{ $cm.ALLOW_INSECURE_TLS | default "true" | quote }}
MULTI_TENANT_ENABLED: {{ $mtRaw | quote }}
{{- /* Multi-tenant (lib-commons/multitenancy) via lerian-common.multiTenant.env —
   gated on MULTI_TENANT_ENABLED. configmap.MULTI_TENANT_* overrides global.multiTenant. */}}
{{- include "lerian-common.multiTenant.env" (dict "context" $ "configmap" $cm
      "enabled" (eq (include "fetcher.isTrue" $mtRaw) "true")
      "emitPool" true "emitEnvironment" true) | nindent 0 }}
{{- /* Escape hatch: any OTHER key the operator adds under common.configmap. */}}
{{- range $key, $value := $cm }}
{{- if not (has $key $explicit) }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}
