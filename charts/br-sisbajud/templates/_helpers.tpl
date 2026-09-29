{{/*
Expand the name of the chart.
*/}}
{{- define "br-sisbajud.name" -}}
{{- default "br-sisbajud" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Truncated at 63 chars because some Kubernetes name fields are limited by the DNS spec.
*/}}
{{- define "br-sisbajud.fullname" -}}
{{- default (include "br-sisbajud.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "br-sisbajud.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the namespace of the release. Overridable for multi-namespace layouts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Name of the service account to use.
*/}}
{{- define "br-sisbajud.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "br-sisbajud.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Selector labels (stable across image bumps).
*/}}
{{- define "br-sisbajud.selectorLabels" -}}
app.kubernetes.io/name: {{ include "br-sisbajud.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "br-sisbajud.labels" -}}
helm.sh/chart: {{ include "br-sisbajud.chart" . }}
{{ include "br-sisbajud.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Migrations fullname, e.g. br-sisbajud-migrations — Job and PreSync Secret reference this.
*/}}
{{- define "br-sisbajud-migrations.fullname" -}}
{{- printf "%s-migrations" (include "br-sisbajud.fullname" . | trunc 52 | trimSuffix "-") | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Migrations labels.
*/}}
{{- define "br-sisbajud-migrations.labels" -}}
helm.sh/chart: {{ include "br-sisbajud.chart" . }}
app.kubernetes.io/name: {{ include "br-sisbajud-migrations.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: migrations
{{- end }}

{{/*
Topics fullname, e.g. br-sisbajud-topics — the PreSync topics Job and Secret reference this.
*/}}
{{- define "br-sisbajud-topics.fullname" -}}
{{- printf "%s-topics" (include "br-sisbajud.fullname" . | trunc 56 | trimSuffix "-") | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Topics labels.
*/}}
{{- define "br-sisbajud-topics.labels" -}}
helm.sh/chart: {{ include "br-sisbajud.chart" . }}
app.kubernetes.io/name: {{ include "br-sisbajud-topics.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: topics
{{- end }}

{{/*
Collapse-aware subchart resource name. Kept as a 1-line alias to the library
helper so bundled-subchart Secret/Service names follow the Bitnami rule.
*/}}
{{- define "common.names.dependency.fullname" -}}
{{- include "lerian-common.dependency.fullname" . -}}
{{- end -}}

{{/*
==============================================================================
Bundled-subchart state. `enabled` uses the nil-aware comparison from the chart
standard (an explicit `false` must not coerce back to true).
  postgresEnabled / valkeyEnabled: the subchart renders (host derivation).
  postgresInternal / valkeyInternal: the app reads the subchart Secret.
==============================================================================
*/}}
{{- define "br-sisbajud.postgresEnabled" -}}
{{- $pg := .Values.postgresql | default dict -}}
{{- ternary "true" "false" (ne (toString $pg.enabled) "false") -}}
{{- end -}}

{{- define "br-sisbajud.valkeyEnabled" -}}
{{- $vk := .Values.valkey | default dict -}}
{{- ternary "true" "false" (ne (toString $vk.enabled) "false") -}}
{{- end -}}

{{- define "br-sisbajud.postgresInternal" -}}
{{- $pg := .Values.postgresql | default dict -}}
{{- ternary "true" "false" (and (ne (toString $pg.enabled) "false") (not $pg.external)) -}}
{{- end -}}

{{- define "br-sisbajud.valkeyInternal" -}}
{{- $vk := .Values.valkey | default dict -}}
{{- $vkAuth := $vk.auth | default dict -}}
{{- ternary "true" "false" (and (ne (toString $vk.enabled) "false") (not $vk.external) (ne (toString $vkAuth.enabled) "false")) -}}
{{- end -}}

{{/*
Bundled SeaweedFS (seaweedfs subchart). The subchart names its Services after
`seaweedfs.name` (nameOverride | "seaweedfs", NOT release-prefixed) and deploys
into the release namespace.
  seaweedfsEnabled  : "true" when the subchart renders.
  seaweedfsName     : the subchart's resource-name prefix.
  seaweedfsS3Endpoint: the in-cluster S3 URL (standalone s3 Deployment when
                       seaweedfs.s3.enabled, else the filer-embedded S3).
*/}}
{{- define "br-sisbajud.seaweedfsEnabled" -}}
{{- $sw := .Values.seaweedfs | default dict -}}
{{- ternary "true" "false" (eq (toString $sw.enabled) "true") -}}
{{- end -}}

{{- define "br-sisbajud.seaweedfsName" -}}
{{- $sw := .Values.seaweedfs | default dict -}}
{{- default "seaweedfs" $sw.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "br-sisbajud.seaweedfsS3Endpoint" -}}
{{- $sw := .Values.seaweedfs | default dict -}}
{{- $s3 := $sw.s3 | default dict -}}
{{- $filerS3 := ($sw.filer | default dict).s3 | default dict -}}
{{- $port := ternary ($s3.port | default 8333) ($filerS3.port | default 8333) (eq (toString $s3.enabled) "true") -}}
{{- printf "http://%s-s3.%s.svc.cluster.local:%v" (include "br-sisbajud.seaweedfsName" .) .Release.Namespace $port -}}
{{- end -}}

{{/*
br-sisbajud.extraEnv — brSisbajud.extraEnvVars as a YAML map {NAME: value},
with "__valueFrom__" for entries sourced via valueFrom. Lets the fail-fast gates
and the topics Job see values an operator supplies as explicit pod env (the
1.1.x way of wiring Vault/SASL/STA credentials), so those installs keep passing.
*/}}
{{- define "br-sisbajud.extraEnv" -}}
{{- $out := dict -}}
{{- range (.Values.brSisbajud.extraEnvVars | default list) -}}
{{- if .name -}}
{{- if hasKey . "valueFrom" -}}
{{- $_ := set $out .name "__valueFrom__" -}}
{{- else -}}
{{- $_ := set $out .name (toString (.value | default "")) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- toYaml $out -}}
{{- end -}}

{{/*
br-sisbajud.provided — "true" when env KEY reaches the pod from ANY source:
the resolved ConfigMap value passed in (value), brSisbajud.secrets.<KEY>, or an
extraEnvVars entry (literal or valueFrom). Inputs: context, key, value (opt).
*/}}
{{- define "br-sisbajud.provided" -}}
{{- $ctx := .context -}}
{{- $x := include "br-sisbajud.extraEnv" $ctx | fromYaml -}}
{{- $s := $ctx.Values.brSisbajud.secrets | default dict -}}
{{- if or (trim (toString (.value | default ""))) (index $s .key) (index $x .key) -}}
true
{{- end -}}
{{- end -}}

{{/*
br-sisbajud.envName — the deployment environment, single-sourced for
ENVIRONMENT_NAME, ENV_NAME and OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT.
Precedence: extraEnvVars ENVIRONMENT_NAME (literal) > configmap.ENVIRONMENT_NAME
> configmap.ENV_NAME > global.env.name > "production". The app treats any value
outside local|development|staging|e2e|test as production-like (fail-closed).
*/}}
{{- define "br-sisbajud.envName" -}}
{{- $cm := .Values.brSisbajud.configmap | default dict -}}
{{- $x := include "br-sisbajud.extraEnv" . | fromYaml -}}
{{- $xv := index $x "ENVIRONMENT_NAME" | default "" -}}
{{- if and $xv (ne $xv "__valueFrom__") -}}
{{- $xv -}}
{{- else if hasKey $cm "ENVIRONMENT_NAME" -}}
{{- index $cm "ENVIRONMENT_NAME" -}}
{{- else -}}
{{- include "lerian-common.globalValue" (dict "context" . "configmap" $cm "block" "env" "field" "name" "nativeKey" "ENV_NAME" "default" "production") -}}
{{- end -}}
{{- end -}}

{{/*
br-sisbajud.productionLike — "true" unless the env name is one of the app's
recognized non-production names (config.go isNonProductionEnv).
*/}}
{{- define "br-sisbajud.productionLike" -}}
{{- $env := include "br-sisbajud.envName" . -}}
{{- ternary "false" "true" (has $env (list "local" "development" "staging" "e2e" "test")) -}}
{{- end -}}

{{- define "br-sisbajud.isTrue" -}}
{{- ternary "true" "false" (has (toString .) (list "true" "1" "t" "T" "TRUE" "True")) -}}
{{- end -}}

{{- define "br-sisbajud.multiTenantEnabled" -}}
{{- $cm := .Values.brSisbajud.configmap | default dict -}}
{{- include "br-sisbajud.isTrue" (include "lerian-common.globalValue" (dict "context" . "configmap" $cm "block" "multiTenant" "field" "enabled" "nativeKey" "MULTI_TENANT_ENABLED" "default" "false")) -}}
{{- end -}}

{{- define "br-sisbajud.streamingEnabledRaw" -}}
{{- $cm := .Values.brSisbajud.configmap | default dict -}}
{{- include "lerian-common.globalValue" (dict "context" . "configmap" $cm "block" "streaming" "field" "enabled" "nativeKey" "STREAMING_ENABLED" "default" "true") -}}
{{- end -}}

{{/*
br-sisbajud.postgres — the resolved primary Postgres connection as YAML
{host, port, user, name, ssl}, shared by the app ConfigMap and the migrations
Job so the two can never drift. Mask precedence (lerian-common.datastore.value):
configmap.POSTGRES_* > brSisbajud.datastores.postgres > global.datastores.postgres
> global.cloud preset > default. The host defaults to the bundled subchart
Service only when postgresql.enabled; ssl defaults to "disable" for the bundled
(plaintext) subchart and "require" otherwise.
*/}}
{{- define "br-sisbajud.postgres" -}}
{{- $cm := .Values.brSisbajud.configmap | default dict -}}
{{- $ded := .Values.brSisbajud.datastores | default dict -}}
{{- $dv := "lerian-common.datastore.value" -}}
{{- $bundled := eq (include "br-sisbajud.postgresEnabled" .) "true" -}}
{{- $hostDefault := "" -}}
{{- if $bundled -}}
{{- $hostDefault = printf "%s.%s.svc.cluster.local." (include "common.names.dependency.fullname" (dict "chartName" "postgresql" "chartValues" .Values.postgresql "context" .)) (include "global.namespace" .) -}}
{{- end -}}
host: {{ include $dv (dict "context" . "dedicated" $ded "configmap" $cm "type" "postgres" "field" "host" "nativeKey" "POSTGRES_HOST" "default" $hostDefault) | quote }}
port: {{ include $dv (dict "context" . "dedicated" $ded "configmap" $cm "type" "postgres" "field" "port" "nativeKey" "POSTGRES_PORT" "default" "5432") | quote }}
user: {{ include $dv (dict "context" . "dedicated" $ded "configmap" $cm "type" "postgres" "field" "user" "nativeKey" "POSTGRES_USER" "default" "br_sisbajud") | quote }}
name: {{ include $dv (dict "context" . "dedicated" $ded "configmap" $cm "type" "postgres" "field" "name" "nativeKey" "POSTGRES_NAME" "default" "br_sisbajud") | quote }}
ssl: {{ include $dv (dict "context" . "dedicated" $ded "configmap" $cm "type" "postgres" "field" "ssl" "nativeKey" "POSTGRES_SSLMODE" "default" (ternary "disable" "require" $bundled)) | quote }}
{{- end -}}

{{/*
br-sisbajud.allowInsecureTLS — lib-commons' plaintext bypass for postgres/redis.
configmap > brSisbajud.security.allowInsecureTls > "true" only when a bundled
(plaintext) subchart is enabled, else "false".
*/}}
{{- define "br-sisbajud.allowInsecureTLS" -}}
{{- $cm := .Values.brSisbajud.configmap | default dict -}}
{{- $bundled := or (eq (include "br-sisbajud.postgresEnabled" .) "true") (eq (include "br-sisbajud.valkeyEnabled" .) "true") -}}
{{- include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "ALLOW_INSECURE_TLS" "params" .Values.brSisbajud.security "field" "allowInsecureTls" "default" (ternary "true" "false" $bundled)) -}}
{{- end -}}

{{/*
br-sisbajud.kv — emit ONE ConfigMap line resolved through lerian-common.cfgValue
(configmap.<k> > params.<f> > d). With opt=true the line is omitted when the
resolved value is empty (optional keys the app treats "unset" and "" alike, or
whose mere presence changes behavior).
Inputs (dict): cm, p (params map), f (field), k (env key), d (default), opt.
*/}}
{{- define "br-sisbajud.kv" -}}
{{- $v := include "lerian-common.cfgValue" (dict "configmap" .cm "nativeKey" .k "params" .p "field" .f "default" (toString (.d | default ""))) -}}
{{- if or (not .opt) $v }}
{{ .k }}: {{ $v | quote }}
{{- end -}}
{{- end -}}

{{/*
br-sisbajud.removedKeys — env keys app 1.0.x no longer reads. They are dropped
from the ConfigMap/Secret escape hatch (NOTES.txt lists any that are still set).
The Midaz/CRM connector routing and credentials moved to the per-institution
institution_config.connector_metadata row; STA institution identity moved to
the institution_config table.
*/}}
{{- define "br-sisbajud.removedKeys" -}}
{{- list "BALANCE_CONSUMER_DLQ_SUFFIX" "CONNECTOR_CREDS_USE_SECRET_STORE" "CRM_CLIENT_ID" "CRM_CLIENT_SECRET" "LEDGER_BALANCE_TOPIC" "MIDAZ_AUTH_ADDRESS" "MIDAZ_AUTH_ENABLED" "MIDAZ_BASE_URL" "MIDAZ_CLIENT_ID" "MIDAZ_CLIENT_SECRET" "OTEL_RESOURCE_SERVICE_VERSION" "SECRET_STORE_PROVIDER" "STA_INSTITUTION_CODE" "STA_INSTITUTION_ID" "VAULT_KV_MOUNT" | toJson -}}
{{- end -}}

{{/*
br-sisbajud.kmsProvider — KMS_PROVIDER from the lerian-common KMS mask.
configmap.KMS_PROVIDER wins verbatim; otherwise kms.vendor (dedicated
brSisbajud.kms > global.kms > "hashicorp-vault") is mapped to the app's
vocabulary: hashicorp-vault|vault -> vault, aws|aws-kms -> aws.
*/}}
{{- define "br-sisbajud.kmsProvider" -}}
{{- $cm := .Values.brSisbajud.configmap | default dict -}}
{{- if hasKey $cm "KMS_PROVIDER" -}}
{{- index $cm "KMS_PROVIDER" -}}
{{- else -}}
{{- $vendor := include "lerian-common.kms.value" (dict "context" . "dedicated" (.Values.brSisbajud.kms | default dict) "configmap" $cm "field" "vendor" "nativeKey" "KMS_PROVIDER" "default" "hashicorp-vault") -}}
{{- $map := dict "hashicorp-vault" "vault" "vault" "vault" "aws" "aws" "aws-kms" "aws" -}}
{{- index $map $vendor | default $vendor -}}
{{- end -}}
{{- end -}}

{{/*
br-sisbajud.configmapData — every app env key the chart models, as ConfigMap
`data` lines (one per line; blank lines are dropped by the caller). Dependency
connections go through the lerian-common masks/env helpers; every other key
goes through lerian-common.cfgValue (via br-sisbajud.kv). Contract source:
LerianStudio/br-sisbajud config/.env.example + internal/bootstrap/config.go.
*/}}
{{- define "br-sisbajud.configmapData" -}}
{{- $ := . -}}
{{- $b := .Values.brSisbajud -}}
{{- $cm := $b.configmap | default dict -}}
{{- $w := $b.workers | default dict -}}
{{- $dv := "lerian-common.datastore.value" -}}
{{- $osv := "lerian-common.objectStorage.value" -}}
{{- $kv := "br-sisbajud.kv" -}}
{{- $kmsDed := $b.kms | default dict -}}
{{- $osDed := $b.objectStorage | default dict -}}
{{- $dsDed := $b.datastores | default dict -}}
{{- $imageTag := $b.image.tag | default .Chart.AppVersion | toString -}}
{{- $envName := include "br-sisbajud.envName" . -}}
{{- $mtOn := eq (include "br-sisbajud.multiTenantEnabled" .) "true" -}}
{{- $pg := include "br-sisbajud.postgres" . | fromYaml -}}
{{- $streamingRaw := include "br-sisbajud.streamingEnabledRaw" . -}}
{{- $streamingOn := eq (include "br-sisbajud.isTrue" $streamingRaw) "true" -}}
{{- /* Bundled SeaweedFS: with no explicit endpoint (configmap / dedicated / global
   objectStorage), derive it from the subchart's S3 Service, same idea as the
   bundled POSTGRES_HOST/REDIS_HOST. STA_OBJECT_STORAGE_ENDPOINT follows it. */ -}}
{{- $seaweedDefault := "" -}}
{{- if eq (include "br-sisbajud.seaweedfsEnabled" .) "true" -}}
{{- $seaweedDefault = include "br-sisbajud.seaweedfsS3Endpoint" . -}}
{{- end -}}
{{- $seaweedEndpoint := include $osv (dict "context" $ "dedicated" $osDed "configmap" $cm "name" "sisbajud" "field" "endpoint" "nativeKey" "SEAWEEDFS_S3_ENDPOINT" "default" $seaweedDefault) -}}
{{- $staBucket := include $osv (dict "context" $ "dedicated" $osDed "configmap" $cm "name" "sta" "field" "bucket" "nativeKey" "STA_INBOUND_BUCKET" "default" "") -}}
{{- $telemetryDefault := "false" }}
# --- Application -------------------------------------------------------------
ENVIRONMENT_NAME: {{ $envName | quote }}
ENV_NAME: {{ (hasKey $cm "ENV_NAME" | ternary (index $cm "ENV_NAME") $envName) | quote }}
{{ include $kv (dict "cm" $cm "p" $b.app "f" "logLevel" "k" "LOG_LEVEL" "d" "info") }}
{{ include $kv (dict "cm" $cm "p" $b.app "f" "version" "k" "VERSION" "d" $imageTag) }}
{{ include $kv (dict "cm" $cm "p" $b.app "f" "deploymentMode" "k" "DEPLOYMENT_MODE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.app "f" "defaultTenantId" "k" "DEFAULT_TENANT_ID" "d" "11111111-1111-1111-1111-111111111111") }}
{{ include $kv (dict "cm" $cm "p" $b.app "f" "systemplaneEnabled" "k" "SYSTEMPLANE_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $b.app "f" "infraConnectTimeoutSec" "k" "INFRA_CONNECT_TIMEOUT_SEC" "d" "30") }}
{{ include $kv (dict "cm" $cm "p" $b.app "f" "dbMetricsIntervalSec" "k" "DB_METRICS_INTERVAL_SEC" "d" "15") }}
{{ include $kv (dict "cm" $cm "p" $b.app "f" "idempotencyRetryWindowSec" "k" "IDEMPOTENCY_RETRY_WINDOW_SEC" "d" "300") }}
{{ include $kv (dict "cm" $cm "p" $b.app "f" "circuitBreakerEnabled" "k" "CIRCUIT_BREAKER_ENABLED" "d" "false") }}
# --- HTTP server + CORS --------------------------------------------------------
{{ include $kv (dict "cm" $cm "p" $b.server "f" "address" "k" "SERVER_ADDRESS" "d" (printf "0.0.0.0:%v" ($b.service.port | default 4029))) }}
{{ include $kv (dict "cm" $cm "p" $b.server "f" "bodyLimitBytes" "k" "HTTP_BODY_LIMIT_BYTES" "d" "104857600") }}
{{ include $kv (dict "cm" $cm "p" $b.server "f" "tlsTerminatedUpstream" "k" "TLS_TERMINATED_UPSTREAM" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $b.server "f" "tlsCertFile" "k" "SERVER_TLS_CERT_FILE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.server "f" "tlsKeyFile" "k" "SERVER_TLS_KEY_FILE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.cors "f" "allowedOrigins" "k" "CORS_ALLOWED_ORIGINS" "d" "") }}
{{ include $kv (dict "cm" $cm "p" $b.cors "f" "allowedMethods" "k" "CORS_ALLOWED_METHODS" "d" "GET,POST,PUT,PATCH,DELETE,OPTIONS") }}
{{ include $kv (dict "cm" $cm "p" $b.cors "f" "allowedHeaders" "k" "CORS_ALLOWED_HEADERS" "d" "Origin,Content-Type,Accept,Authorization,X-Request-ID") }}
{{ include $kv (dict "cm" $cm "p" $b.cors "f" "exposeHeaders" "k" "CORS_EXPOSE_HEADERS" "d" "") }}
{{ include $kv (dict "cm" $cm "p" $b.cors "f" "allowCredentials" "k" "CORS_ALLOW_CREDENTIALS" "d" "false") }}
# --- lib-commons security toggles -------------------------------------------
ALLOW_INSECURE_TLS: {{ include "br-sisbajud.allowInsecureTLS" . | quote }}
{{ include $kv (dict "cm" $cm "p" $b.security "f" "allowCorsWildcard" "k" "ALLOW_CORS_WILDCARD" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.security "f" "allowInsecureOtel" "k" "ALLOW_INSECURE_OTEL" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.security "f" "allowWebhookPrivateNetwork" "k" "ALLOW_WEBHOOK_PRIVATE_NETWORK" "opt" true) }}
# --- License (lib-license-go, GLOBAL mode); LICENSE_KEY lives in the Secret ------
{{ include $kv (dict "cm" $cm "p" $b.license "f" "organizationIds" "k" "ORGANIZATION_IDS" "d" "global") }}
{{ include $kv (dict "cm" $cm "p" $b.license "f" "isDevelopment" "k" "IS_DEVELOPMENT" "opt" true) }}
# --- Multi-tenant (lerian-common.multiTenant.env; secrets via multiTenant.secret) --
MULTI_TENANT_ENABLED: {{ include "lerian-common.globalValue" (dict "context" $ "configmap" $cm "block" "multiTenant" "field" "enabled" "nativeKey" "MULTI_TENANT_ENABLED" "default" "false") | quote }}
{{ include "lerian-common.multiTenant.env" (dict "context" $ "configmap" $cm "enabled" $mtOn "requiredUrl" true "requiredRedisHost" true "emitRedis" true "emitPool" true "emitCache" true "emitAllowInsecure" true) }}
# --- PostgreSQL (lerian-common.datastore.value) ------------------------------
POSTGRES_HOST: {{ $pg.host | quote }}
POSTGRES_PORT: {{ $pg.port | quote }}
POSTGRES_USER: {{ $pg.user | quote }}
POSTGRES_NAME: {{ $pg.name | quote }}
POSTGRES_SSLMODE: {{ $pg.ssl | quote }}
{{ include $kv (dict "cm" $cm "p" $b.postgres "f" "maxOpenConns" "k" "POSTGRES_MAX_OPEN_CONNS" "d" "25") }}
{{ include $kv (dict "cm" $cm "p" $b.postgres "f" "maxIdleConns" "k" "POSTGRES_MAX_IDLE_CONNS" "d" "5") }}
{{ include $kv (dict "cm" $cm "p" $b.postgres "f" "connMaxLifetimeMins" "k" "POSTGRES_CONN_MAX_LIFETIME_MINS" "d" "30") }}
{{ include $kv (dict "cm" $cm "p" $b.postgres "f" "connMaxIdleTimeMins" "k" "POSTGRES_CONN_MAX_IDLE_TIME_MINS" "d" "5") }}
{{ include $kv (dict "cm" $cm "p" $b.postgres "f" "connectTimeoutSec" "k" "POSTGRES_CONNECT_TIMEOUT_SEC" "d" "10") }}
{{- $replicaHost := include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "postgres" "field" "replicaHost" "nativeKey" "POSTGRES_REPLICA_HOST" "default" "") }}
{{- if $replicaHost }}
POSTGRES_REPLICA_HOST: {{ $replicaHost | quote }}
POSTGRES_REPLICA_PORT: {{ include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "postgres" "field" "port" "nativeKey" "POSTGRES_REPLICA_PORT" "default" $pg.port) | quote }}
POSTGRES_REPLICA_USER: {{ include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "postgres" "field" "user" "nativeKey" "POSTGRES_REPLICA_USER" "default" $pg.user) | quote }}
POSTGRES_REPLICA_NAME: {{ include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "postgres" "field" "name" "nativeKey" "POSTGRES_REPLICA_NAME" "default" $pg.name) | quote }}
POSTGRES_REPLICA_SSLMODE: {{ include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "postgres" "field" "ssl" "nativeKey" "POSTGRES_REPLICA_SSLMODE" "default" $pg.ssl) | quote }}
{{- end }}
# --- Redis / Valkey (lerian-common.datastore.value) --------------------------
{{- $redisHostDefault := "" }}
{{- if eq (include "br-sisbajud.valkeyEnabled" .) "true" }}
{{- $redisHostDefault = printf "%s-primary.%s.svc.cluster.local.:6379" (include "common.names.dependency.fullname" (dict "chartName" "valkey" "chartValues" .Values.valkey "context" .)) (include "global.namespace" .) }}
{{- end }}
REDIS_HOST: {{ include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "redis" "field" "host" "nativeKey" "REDIS_HOST" "default" $redisHostDefault) | quote }}
REDIS_TLS: {{ include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "redis" "field" "tls" "nativeKey" "REDIS_TLS" "default" "false") | quote }}
{{- $redisCa := include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "redis" "field" "caCert" "nativeKey" "REDIS_CA_CERT" "default" "") }}
{{- if $redisCa }}
REDIS_CA_CERT: {{ $redisCa | quote }}
{{- end }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "masterName" "k" "REDIS_MASTER_NAME" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "db" "k" "REDIS_DB" "d" "0") }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "protocol" "k" "REDIS_PROTOCOL" "d" "3") }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "poolSize" "k" "REDIS_POOL_SIZE" "d" "10") }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "minIdleConns" "k" "REDIS_MIN_IDLE_CONNS" "d" "2") }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "readTimeout" "k" "REDIS_READ_TIMEOUT" "d" "3") }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "writeTimeout" "k" "REDIS_WRITE_TIMEOUT" "d" "3") }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "dialTimeout" "k" "REDIS_DIAL_TIMEOUT" "d" "5") }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "poolTimeout" "k" "REDIS_POOL_TIMEOUT" "d" "2") }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "maxRetries" "k" "REDIS_MAX_RETRIES" "d" "3") }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "minRetryBackoff" "k" "REDIS_MIN_RETRY_BACKOFF" "d" "8") }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "maxRetryBackoff" "k" "REDIS_MAX_RETRY_BACKOFF" "d" "1") }}
# --- KMS / Vault Transit (lerian-common.kms.value); token + secret-id in the Secret --
{{- $kmsProvider := include "br-sisbajud.kmsProvider" . }}
KMS_PROVIDER: {{ $kmsProvider | quote }}
VAULT_ADDR: {{ include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "vaultAddr" "nativeKey" "VAULT_ADDR" "default" "") | quote }}
VAULT_AUTH_METHOD: {{ include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "vaultAuthMethod" "nativeKey" "VAULT_AUTH_METHOD" "default" "token") | quote }}
VAULT_APPROLE_ROLE_ID: {{ include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "vaultRoleId" "nativeKey" "VAULT_APPROLE_ROLE_ID" "default" "") | quote }}
VAULT_TRANSIT_MOUNT_PATH: {{ include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "vaultMount" "nativeKey" "VAULT_TRANSIT_MOUNT_PATH" "default" "transit") | quote }}
{{ include $kv (dict "cm" $cm "p" $b.vault "f" "timeoutSec" "k" "VAULT_TIMEOUT_SEC" "d" "15") }}
{{ include $kv (dict "cm" $cm "p" $b.vault "f" "tokenRenewEnabled" "k" "VAULT_TOKEN_RENEW_ENABLED" "d" "true") }}
{{ include $kv (dict "cm" $cm "p" $b.vault "f" "tokenRenewMinIntervalSec" "k" "VAULT_TOKEN_RENEW_MIN_INTERVAL_SEC" "d" "60") }}
{{ include $kv (dict "cm" $cm "p" $b.vault "f" "awsEndpointUrl" "k" "AWS_ENDPOINT_URL" "opt" true) }}
{{- $awsRegion := include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "awsRegion" "nativeKey" "AWS_REGION" "default" "") }}
{{- if $awsRegion }}
AWS_REGION: {{ $awsRegion | quote }}
{{- end }}
# --- Envelope encryption + blind index ---------------------------------------
{{ include $kv (dict "cm" $cm "p" $b.crypto "f" "dekCacheTtl" "k" "SISBAJUD_DEK_CACHE_TTL" "d" "5m") }}
{{ include $kv (dict "cm" $cm "p" $b.crypto "f" "dekCacheMaxEntries" "k" "SISBAJUD_DEK_CACHE_MAX_ENTRIES" "d" "50000") }}
{{ include $kv (dict "cm" $cm "p" $b.crypto "f" "hmacCoexistenceWindow" "k" "SISBAJUD_HMAC_COEXISTENCE_WINDOW" "d" "720h") }}
# --- Object storage (lerian-common.objectStorage.value); keys in the Secret -----
SEAWEEDFS_S3_ENDPOINT: {{ $seaweedEndpoint | quote }}
SEAWEEDFS_BUCKET: {{ include $osv (dict "context" $ "dedicated" $osDed "configmap" $cm "name" "sisbajud" "field" "bucket" "nativeKey" "SEAWEEDFS_BUCKET" "default" "sisbajud") | quote }}
SEAWEEDFS_REGION: {{ include $osv (dict "context" $ "dedicated" $osDed "configmap" $cm "name" "sisbajud" "field" "region" "nativeKey" "SEAWEEDFS_REGION" "default" "us-east-1") | quote }}
# --- STA (br-sta) file reception, consumer and transfers ---------------------
STA_INBOUND_BUCKET: {{ $staBucket | quote }}
{{- /* Bucket + endpoint parity is enforced by the app (sta_bucket_parity.go): the
   transfer bucket MUST be the inbound bucket and the STA endpoint MUST be the
   SeaweedFS endpoint, so both default to those values (single-sourced). */}}
TRANSFER_OBJECT_STORAGE_BUCKET: {{ (hasKey $cm "TRANSFER_OBJECT_STORAGE_BUCKET" | ternary (index $cm "TRANSFER_OBJECT_STORAGE_BUCKET") $staBucket) | quote }}
STA_OBJECT_STORAGE_ENDPOINT: {{ include $osv (dict "context" $ "dedicated" $osDed "configmap" $cm "name" "sta" "field" "endpoint" "nativeKey" "STA_OBJECT_STORAGE_ENDPOINT" "default" $seaweedEndpoint) | quote }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "fileLockTtl" "k" "STA_FILE_LOCK_TTL" "d" "5") }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "consumerEnabled" "k" "STA_CONSUMER_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "consumerGroup" "k" "STA_CONSUMER_GROUP" "d" "sisbajud-sta-consumer") }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "consumerRetryBudget" "k" "STA_CONSUMER_RETRY_BUDGET" "d" "3") }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "sourceProduct" "k" "STA_SOURCE_PRODUCT" "d" "br-sisbajud") }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "bacenSystemCode" "k" "STA_BACEN_SYSTEM_CODE" "d" "JUD") }}
{{- /* Presence-validated by the app when the consumer is on: always emitted (empty is legitimate). */}}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "expectedTenantSt" "k" "STA_EXPECTED_TENANT_ST" "d" "") }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "maxInboundSizeBytes" "k" "STA_MAX_INBOUND_SIZE_BYTES" "d" "52428800") }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "transfersEnabled" "k" "STA_TRANSFERS_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "transfersBaseUrl" "k" "STA_TRANSFERS_BASE_URL" "d" "") }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "documentTypeAjud302" "k" "STA_DOCUMENT_TYPE_AJUD302" "d" "AJUD302") }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "documentTypeAjud309" "k" "STA_DOCUMENT_TYPE_AJUD309" "d" "AJUD309") }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "clientId" "k" "STA_CLIENT_ID" "d" "") }}
# --- Background workers ------------------------------------------------------
{{ include $kv (dict "cm" $cm "p" $w.permanentBlockExpiry "f" "enabled" "k" "PERMANENT_BLOCK_EXPIRY_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $w.permanentBlockExpiry "f" "scanInterval" "k" "PERMANENT_BLOCK_EXPIRY_SCAN_INTERVAL" "d" "86400") }}
{{ include $kv (dict "cm" $cm "p" $w.permanentBlockExpiry "f" "batchSize" "k" "PERMANENT_BLOCK_EXPIRY_BATCH_SIZE" "d" "500") }}
{{ include $kv (dict "cm" $cm "p" $w.kekRewrapBackfill "f" "enabled" "k" "KEK_REWRAP_BACKFILL_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $w.kekRewrapBackfill "f" "scanInterval" "k" "KEK_REWRAP_BACKFILL_SCAN_INTERVAL" "d" "300") }}
{{ include $kv (dict "cm" $cm "p" $w.kekRewrapBackfill "f" "batchSize" "k" "KEK_REWRAP_BACKFILL_BATCH_SIZE" "d" "100") }}
{{ include $kv (dict "cm" $cm "p" $w.rehashBackfill "f" "enabled" "k" "REHASH_BACKFILL_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $w.rehashBackfill "f" "scanInterval" "k" "REHASH_BACKFILL_SCAN_INTERVAL" "d" "300") }}
{{ include $kv (dict "cm" $cm "p" $w.rehashBackfill "f" "batchSize" "k" "REHASH_BACKFILL_BATCH_SIZE" "d" "100") }}
{{ include $kv (dict "cm" $cm "p" $w.rehashBackfill "f" "dropPreviousKeyEnabled" "k" "REHASH_BACKFILL_DROP_PREVIOUS_KEY_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $w.reconciliation "f" "enabled" "k" "RECONCILIATION_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $w.reconciliation "f" "scanInterval" "k" "RECONCILIATION_SCAN_INTERVAL" "d" "3600") }}
{{ include $kv (dict "cm" $cm "p" $w.reconciliation "f" "batchSize" "k" "RECONCILIATION_BATCH_SIZE" "d" "500") }}
{{ include $kv (dict "cm" $cm "p" $w.reconciliation "f" "intensifiedEnabled" "k" "RECONCILIATION_INTENSIFIED_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $w.reconciliation "f" "intensifiedScanInterval" "k" "RECONCILIATION_INTENSIFIED_SCAN_INTERVAL" "d" "300") }}
{{ include $kv (dict "cm" $cm "p" $w.reconciliation "f" "nearDeadlinePercent" "k" "RECONCILIATION_NEAR_DEADLINE_PERCENT" "d" "75") }}
{{ include $kv (dict "cm" $cm "p" $w.slaAlert "f" "enabled" "k" "SLA_ALERT_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $w.slaAlert "f" "scanInterval" "k" "SLA_ALERT_SCAN_INTERVAL" "d" "60") }}
{{ include $kv (dict "cm" $cm "p" $w.returnFile "f" "enabled" "k" "RETURN_FILE_GENERATION_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $w.returnFile "f" "scanInterval" "k" "RETURN_FILE_GENERATION_SCAN_INTERVAL" "d" "3600") }}
{{ include $kv (dict "cm" $cm "p" $w.returnFile "f" "limit" "k" "RETURN_FILE_GENERATION_LIMIT" "d" "500") }}
{{ include $kv (dict "cm" $cm "p" $w.returnFile "f" "environment" "k" "RETURN_FILE_ENVIRONMENT" "d" "HOMOLOGATION") }}
{{ include $kv (dict "cm" $cm "p" $w.informationReturnFile "f" "enabled" "k" "INFORMATION_RETURN_FILE_GENERATION_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $w.informationReturnFile "f" "scanInterval" "k" "INFORMATION_RETURN_FILE_GENERATION_SCAN_INTERVAL" "d" "3600") }}
{{ include $kv (dict "cm" $cm "p" $w.informationReturnFile "f" "limit" "k" "INFORMATION_RETURN_FILE_GENERATION_LIMIT" "d" "500") }}
{{ include $kv (dict "cm" $cm "p" $w.informationRequest "f" "enabled" "k" "INFORMATION_REQUEST_ENABLED" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $w.informationRequest "f" "scanInterval" "k" "INFORMATION_REQUEST_SCAN_INTERVAL" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $w.informationRequest "f" "batchSize" "k" "INFORMATION_REQUEST_BATCH_SIZE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $w.informationRequest "f" "lockTtl" "k" "INFORMATION_REQUEST_LOCK_TTL" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $w.monitoringExpiry "f" "enabled" "k" "MONITORING_EXPIRY_ENABLED" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $w.monitoringExpiry "f" "scanInterval" "k" "MONITORING_EXPIRY_SCAN_INTERVAL" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $w.monitoringExpiry "f" "batchSize" "k" "MONITORING_EXPIRY_BATCH_SIZE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $w.execution "f" "enabled" "k" "EXECUTION_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $w.execution "f" "orchestratorLockTtl" "k" "ORCHESTRATOR_LOCK_TTL" "d" "30") }}
{{ include $kv (dict "cm" $cm "p" $w.execution "f" "orchestratorRenewInterval" "k" "ORCHESTRATOR_RENEW_INTERVAL" "d" "10") }}
{{ include $kv (dict "cm" $cm "p" $w.execution "f" "unblockScanInterval" "k" "UNBLOCK_EXECUTION_SCAN_INTERVAL" "d" "60") }}
{{ include $kv (dict "cm" $cm "p" $w.execution "f" "unblockBatchSize" "k" "UNBLOCK_EXECUTION_BATCH_SIZE" "d" "500") }}
{{ include $kv (dict "cm" $cm "p" $w.processingLockReaper "f" "enabled" "k" "PROCESSING_LOCK_REAPER_ENABLED" "d" "true") }}
{{ include $kv (dict "cm" $cm "p" $w.processingLockReaper "f" "intervalSec" "k" "PROCESSING_LOCK_REAPER_INTERVAL_SEC" "d" "300") }}
# --- Remittance layout ---------------------------------------------------------
{{ include $kv (dict "cm" $cm "p" $b.layout "f" "responseLayout" "k" "SISBAJUD_RESPONSE_LAYOUT" "d" "auto") }}
{{ include $kv (dict "cm" $cm "p" $b.layout "f" "remittanceLayouts" "k" "SISBAJUD_REMITTANCE_LAYOUTS" "d" "v111,v2026") }}
# --- Outbox (durability path for streaming) -----------------------------------
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "enabled" "k" "OUTBOX_ENABLED" "d" "true") }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "tableName" "k" "OUTBOX_TABLE_NAME" "d" "outbox_events") }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "dispatchIntervalSec" "k" "OUTBOX_DISPATCH_INTERVAL_SEC" "d" "2") }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "batchSize" "k" "OUTBOX_BATCH_SIZE" "d" "50") }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "publishMaxAttempts" "k" "OUTBOX_PUBLISH_MAX_ATTEMPTS" "d" "3") }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "publishBackoffMs" "k" "OUTBOX_PUBLISH_BACKOFF_MS" "d" "200") }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "retryWindowSec" "k" "OUTBOX_RETRY_WINDOW_SEC" "d" "300") }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "maxDispatchAttempts" "k" "OUTBOX_MAX_DISPATCH_ATTEMPTS" "d" "10") }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "processingTimeoutSec" "k" "OUTBOX_PROCESSING_TIMEOUT_SEC" "d" "600") }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "maxFailedPerBatch" "k" "OUTBOX_MAX_FAILED_PER_BATCH" "d" "25") }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "includeTenantMetrics" "k" "OUTBOX_INCLUDE_TENANT_METRICS" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "priorityEventTypes" "k" "OUTBOX_PRIORITY_EVENT_TYPES" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "allowEmptyTenant" "k" "OUTBOX_ALLOW_EMPTY_TENANT" "d" "true") }}
# --- Streaming (lerian-common.streaming.env; SASL password/CA via streaming.secret) --
STREAMING_ENABLED: {{ $streamingRaw | quote }}
{{ include $kv (dict "cm" $cm "p" $b.streaming "f" "cloudeventsSource" "k" "STREAMING_CLOUDEVENTS_SOURCE" "d" "br-sisbajud") }}
{{ include $kv (dict "cm" $cm "p" $b.streaming "f" "clientId" "k" "STREAMING_CLIENT_ID" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.streaming "f" "healthCheckTimeout" "k" "STREAMING_HEALTH_CHECK_TIMEOUT" "d" "2s") }}
{{ include "lerian-common.streaming.env" (dict "context" $ "enabled" $streamingOn "configmap" $cm) }}
{{ include $kv (dict "cm" $cm "p" $b.balanceConsumer "f" "group" "k" "BALANCE_CONSUMER_GROUP" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.balanceConsumer "f" "dedupTtl" "k" "BALANCE_DEDUP_TTL" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.balanceConsumer "f" "retryBudget" "k" "BALANCE_CONSUMER_RETRY_BUDGET" "opt" true) }}
# --- Midaz ledger (balance translator + connector surface) ---------------------
{{ include $kv (dict "cm" $cm "p" $b.midaz "f" "balanceTopic" "k" "MIDAZ_BALANCE_TOPIC" "d" "lerian.streaming.ledger") }}
{{ include $kv (dict "cm" $cm "p" $b.midaz "f" "balanceConsumerGroup" "k" "MIDAZ_BALANCE_CONSUMER_GROUP" "d" "sisbajud-midaz-balance-translator") }}
{{ include $kv (dict "cm" $cm "p" $b.midaz "f" "balanceDefaultAccountType" "k" "MIDAZ_BALANCE_DEFAULT_ACCOUNT_TYPE" "d" "deposit") }}
{{ include $kv (dict "cm" $cm "p" $b.midaz "f" "crmMode" "k" "MIDAZ_CRM_MODE" "d" "legacy") }}
{{ include $kv (dict "cm" $cm "p" $b.midaz "f" "manifestCheckInterval" "k" "MIDAZ_MANIFEST_CHECK_INTERVAL" "d" "15m") }}
# --- Inbound auth (lerian-common.auth.env) -------------------------------------
{{ include "lerian-common.auth.env" (dict "context" $ "configmap" $cm "hostKey" "PLUGIN_AUTH_HOST" "hostDefault" "") }}
{{ include $kv (dict "cm" $cm "p" $b.auth "f" "trustedProxies" "k" "TRUSTED_PROXIES" "d" "") }}
{{ include $kv (dict "cm" $cm "p" $b.auth "f" "productName" "k" "AUTH_PRODUCT_NAME" "opt" true) }}
# --- Access-manager declaration publisher (lib-auth); client secret in the Secret --
{{ include $kv (dict "cm" $cm "p" $b.identity "f" "declarationEnabled" "k" "IDP_DECLARATION_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $b.identity "f" "host" "k" "IDP_HOST" "d" "") }}
{{ include $kv (dict "cm" $cm "p" $b.identity "f" "m2mClientId" "k" "IDP_M2M_CLIENT_ID" "d" "") }}
# --- M2M credential provider (multi-tenant) -----------------------------------
{{ include $kv (dict "cm" $cm "p" $b.m2m "f" "targetService" "k" "M2M_TARGET_SERVICE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.m2m "f" "credentialCacheTtlSec" "k" "M2M_CREDENTIAL_CACHE_TTL_SEC" "d" "300") }}
# --- OpenTelemetry (lerian-common.otel.env) ------------------------------------
{{ include "lerian-common.otel.env" (dict "context" $ "configmap" $cm "enabledDefault" $telemetryDefault "endpointDefault" "localhost:4317" "deploymentEnvironmentDefault" $envName) }}
{{ include $kv (dict "cm" $cm "p" $b.observability "f" "serviceName" "k" "OTEL_RESOURCE_SERVICE_NAME" "d" "br-sisbajud") }}
{{ include $kv (dict "cm" $cm "p" $b.observability "f" "libraryName" "k" "OTEL_LIBRARY_NAME" "d" "github.com/LerianStudio/br-sisbajud") }}
# --- Rate limiting (lerian-common.rateLimit.env) -------------------------------
{{ include "lerian-common.rateLimit.env" (dict "configmap" $cm "params" $b.rateLimit) }}
# --- Swagger -------------------------------------------------------------------
{{ include $kv (dict "cm" $cm "p" $b.swagger "f" "enabled" "k" "SWAGGER_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $b.swagger "f" "title" "k" "SWAGGER_TITLE" "d" "br-sisbajud") }}
{{ include $kv (dict "cm" $cm "p" $b.swagger "f" "version" "k" "SWAGGER_VERSION" "d" $imageTag) }}
{{ include $kv (dict "cm" $cm "p" $b.swagger "f" "basePath" "k" "SWAGGER_BASE_PATH" "d" "/") }}
{{ include $kv (dict "cm" $cm "p" $b.swagger "f" "leftDelim" "k" "SWAGGER_LEFT_DELIM" "d" "{{") }}
{{ include $kv (dict "cm" $cm "p" $b.swagger "f" "rightDelim" "k" "SWAGGER_RIGHT_DELIM" "d" "}}") }}
{{ include $kv (dict "cm" $cm "p" $b.swagger "f" "description" "k" "SWAGGER_DESCRIPTION" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.swagger "f" "host" "k" "SWAGGER_HOST" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.swagger "f" "schemes" "k" "SWAGGER_SCHEMES" "opt" true) }}
# --- Pagination + admin read API -----------------------------------------------
{{ include $kv (dict "cm" $cm "p" $b.pagination "f" "maxLimit" "k" "MAX_PAGINATION_LIMIT" "d" "100") }}
{{ include $kv (dict "cm" $cm "p" $b.pagination "f" "maxMonthDateRange" "k" "MAX_PAGINATION_MONTH_DATE_RANGE" "d" "3") }}
{{ include $kv (dict "cm" $cm "p" $b.admin "f" "maxFileContentBytes" "k" "ADMIN_MAX_FILE_CONTENT_BYTES" "d" "104857600") }}
{{ include $kv (dict "cm" $cm "p" $b.admin "f" "maxAuditVerifyWindow" "k" "ADMIN_MAX_AUDIT_VERIFY_WINDOW" "opt" true) }}
{{- end -}}

{{/*
br-sisbajud.secretData — the chart-modeled Secret keys (stringData lines).
Infra passwords are written only for EXTERNAL infra without an
<subchart>.auth.existingSecret (the bundled path is single-sourced from the
subchart Secret via secretKeyRef on the Deployment). Streaming and multi-tenant
keys come from the lerian-common companion helpers, which also fail fast when a
required one is missing.
*/}}
{{- define "br-sisbajud.secretData" -}}
{{- $b := .Values.brSisbajud -}}
{{- $s := $b.secrets | default dict -}}
{{- $cm := $b.configmap | default dict -}}
{{- $x := include "br-sisbajud.extraEnv" . | fromYaml -}}
{{- $pg := .Values.postgresql | default dict -}}
{{- $pgAuth := $pg.auth | default dict -}}
{{- $vk := .Values.valkey | default dict -}}
{{- $vkAuth := $vk.auth | default dict -}}
{{- $pgInternal := eq (include "br-sisbajud.postgresInternal" .) "true" -}}
{{- $vkInternal := eq (include "br-sisbajud.valkeyInternal" .) "true" -}}
{{- if and (not $pgInternal) (not $pgAuth.existingSecret) $s.POSTGRES_PASSWORD }}
POSTGRES_PASSWORD: {{ $s.POSTGRES_PASSWORD | quote }}
{{- end }}
{{- if and (not $vkInternal) (not $vkAuth.existingSecret) $s.REDIS_PASSWORD }}
REDIS_PASSWORD: {{ $s.REDIS_PASSWORD | quote }}
{{- end }}
{{- range $k := list "POSTGRES_REPLICA_PASSWORD" "LICENSE_KEY" "VAULT_TOKEN" "VAULT_APPROLE_SECRET_ID" "SEAWEEDFS_ACCESS_KEY" "SEAWEEDFS_SECRET_KEY" "STA_CLIENT_SECRET" "IDP_M2M_CLIENT_SECRET" }}
{{- with index $s $k }}
{{ $k }}: {{ . | quote }}
{{- end }}
{{- end }}
{{- /* Streaming SASL password / CA cert. The mechanism and username are resolved
   with the same configmap-over-global precedence as the ConfigMap. When the
   password already reaches the pod as an explicit extraEnvVars entry (the 1.1.x
   wiring), the helper's fail-fast is skipped and only the CA is copied here. */}}
{{- $gs := (.Values.global | default dict).streaming | default dict }}
{{- $saslMech := $gs.saslMechanism | default "" }}
{{- if hasKey $cm "STREAMING_SASL_MECHANISM" }}{{- $saslMech = index $cm "STREAMING_SASL_MECHANISM" }}{{- end }}
{{- $saslUser := $gs.saslUsername | default "" }}
{{- if hasKey $cm "STREAMING_SASL_USERNAME" }}{{- $saslUser = index $cm "STREAMING_SASL_USERNAME" }}{{- end }}
{{- $streamingOn := eq (include "br-sisbajud.isTrue" (include "br-sisbajud.streamingEnabledRaw" .)) "true" }}
{{- if hasKey $x "STREAMING_SASL_PASSWORD" }}
{{- with $s.STREAMING_TLS_CA_CERT }}
STREAMING_TLS_CA_CERT: {{ . | quote }}
{{- end }}
{{- else }}
{{ include "lerian-common.streaming.secret" (dict "context" . "secrets" $s "secretName" (include "br-sisbajud.fullname" .) "valuesPrefix" "brSisbajud.secrets." "mode" "stringData" "enabled" $streamingOn "useExistingSecret" false "saslMechanism" $saslMech "saslUsername" $saslUser) }}
{{- end }}
{{- /* Multi-tenant service API key (required when MT is on) + tenant Redis password. */}}
{{- $mtOn := eq (include "br-sisbajud.multiTenantEnabled" .) "true" }}
{{- if hasKey $x "MULTI_TENANT_SERVICE_API_KEY" }}
{{- with $s.MULTI_TENANT_REDIS_PASSWORD }}
MULTI_TENANT_REDIS_PASSWORD: {{ . | quote }}
{{- end }}
{{- else }}
{{ include "lerian-common.multiTenant.secret" (dict "context" . "secrets" $s "secretName" (include "br-sisbajud.fullname" .) "valuesPrefix" "brSisbajud.secrets." "mode" "stringData" "enabled" $mtOn "useExistingSecret" false) }}
{{- end }}
{{- end -}}

{{/*
br-sisbajud.required — fail with an actionable message when KEY does not reach
the pod from any source. Inputs: context, key, value (resolved ConfigMap value,
opt), secret (bool: the key is a credential, so useExistingSecret satisfies it),
why (condition text), set (where to set it).
*/}}
{{- define "br-sisbajud.required" -}}
{{- $ctx := .context -}}
{{- $skip := and .secret $ctx.Values.brSisbajud.useExistingSecret -}}
{{- if and (not $skip) (not (include "br-sisbajud.provided" (dict "context" $ctx "key" .key "value" .value))) -}}
{{- fail (printf "\n\nERROR: br-sisbajud: %s is required %s.\n  set: %s\n  (or pass it as a brSisbajud.extraEnvVars entry%s)\n" .key .why .set (ternary " / via brSisbajud.useExistingSecret" "" (eq (toString .secret) "true"))) -}}
{{- end -}}
{{- end -}}

{{/*
br-sisbajud.validate — fail-fast gates mirroring the app's boot validation
(internal/bootstrap/config_validation.go), so a values mistake fails the render
instead of CrashLooping the pod. Invoked from configmap.yaml.
*/}}
{{- define "br-sisbajud.validate" -}}
{{- $ := . -}}
{{- $b := .Values.brSisbajud -}}
{{- $cm := $b.configmap | default dict -}}
{{- $data := include "br-sisbajud.configmapData" . | fromYaml -}}
{{- $req := "br-sisbajud.required" -}}
{{- $prodLike := eq (include "br-sisbajud.productionLike" .) "true" -}}
{{- $envName := include "br-sisbajud.envName" . -}}
{{- $mtOn := eq (include "br-sisbajud.multiTenantEnabled" .) "true" -}}
{{- /* STA inbound bucket: validated unconditionally by the app (no default by policy). */ -}}
{{- include $req (dict "context" $ "key" "STA_INBOUND_BUCKET" "value" (index $data "STA_INBOUND_BUCKET") "why" "(the app refuses to boot without it; it must match br-sta's transfer bucket for the tier)" "set" "global.objectStorage.sta.bucket (or brSisbajud.objectStorage.sta.bucket)") -}}
{{- /* Single-tenant datastores. */ -}}
{{- if not $mtOn -}}
{{- include $req (dict "context" $ "key" "POSTGRES_HOST" "value" (index $data "POSTGRES_HOST") "why" "when multi-tenancy is off (or enable the bundled postgresql subchart)" "set" "global.datastores.postgres.host") -}}
{{- include $req (dict "context" $ "key" "REDIS_HOST" "value" (index $data "REDIS_HOST") "why" "when multi-tenancy is off (or enable the bundled valkey subchart)" "set" "global.datastores.redis.host (host:port)") -}}
{{- $pg := .Values.postgresql | default dict -}}
{{- $pgAuth := $pg.auth | default dict -}}
{{- if and $prodLike (ne (include "br-sisbajud.postgresInternal" .) "true") (not $pgAuth.existingSecret) -}}
{{- include $req (dict "context" $ "key" "POSTGRES_PASSWORD" "secret" true "why" (printf "in a production-like environment (ENVIRONMENT_NAME=%q) with external Postgres" $envName) "set" "brSisbajud.secrets.POSTGRES_PASSWORD") -}}
{{- end -}}
{{- end -}}
{{- /* License: fail-closed in production-like environments. */ -}}
{{- if $prodLike -}}
{{- include $req (dict "context" $ "key" "LICENSE_KEY" "secret" true "why" (printf "in a production-like environment (ENVIRONMENT_NAME=%q; use development|staging|... to run without a license)" $envName) "set" "brSisbajud.secrets.LICENSE_KEY") -}}
{{- end -}}
{{- /* KMS backend. */ -}}
{{- $kms := index $data "KMS_PROVIDER" -}}
{{- if not (has $kms (list "vault" "aws")) -}}
{{- fail (printf "\n\nERROR: br-sisbajud: KMS_PROVIDER must be vault or aws (got %q).\n  set: global.kms.vendor (hashicorp-vault | aws) or brSisbajud.configmap.KMS_PROVIDER\n" $kms) -}}
{{- end -}}
{{- if eq $kms "vault" -}}
{{- include $req (dict "context" $ "key" "VAULT_ADDR" "value" (index $data "VAULT_ADDR") "why" "when KMS_PROVIDER=vault" "set" "global.kms.vaultAddr (or brSisbajud.kms.vaultAddr)") -}}
{{- $auth := lower (index $data "VAULT_AUTH_METHOD" | default "token") -}}
{{- if eq $auth "approle" -}}
{{- include $req (dict "context" $ "key" "VAULT_APPROLE_ROLE_ID" "value" (index $data "VAULT_APPROLE_ROLE_ID") "why" "when VAULT_AUTH_METHOD=approle" "set" "global.kms.vaultRoleId (or brSisbajud.kms.vaultRoleId)") -}}
{{- include $req (dict "context" $ "key" "VAULT_APPROLE_SECRET_ID" "secret" true "why" "when VAULT_AUTH_METHOD=approle" "set" "brSisbajud.secrets.VAULT_APPROLE_SECRET_ID") -}}
{{- else if eq $auth "token" -}}
{{- if eq $envName "production" -}}
{{- include $req (dict "context" $ "key" "VAULT_TOKEN" "secret" true "why" "when VAULT_AUTH_METHOD=token and ENVIRONMENT_NAME=production (prefer approle)" "set" "brSisbajud.secrets.VAULT_TOKEN") -}}
{{- end -}}
{{- else -}}
{{- fail (printf "\n\nERROR: br-sisbajud: VAULT_AUTH_METHOD must be token or approle (got %q).\n  set: global.kms.vaultAuthMethod\n" $auth) -}}
{{- end -}}
{{- else -}}
{{- include $req (dict "context" $ "key" "AWS_REGION" "value" (index $data "AWS_REGION") "why" "when KMS_PROVIDER=aws" "set" "global.kms.awsRegion (or brSisbajud.kms.awsRegion)") -}}
{{- end -}}
{{- /* Streaming: the app fails at boot when enabled without brokers. */ -}}
{{- if eq (include "br-sisbajud.isTrue" (index $data "STREAMING_ENABLED")) "true" -}}
{{- include $req (dict "context" $ "key" "STREAMING_BROKERS" "value" (index $data "STREAMING_BROKERS") "why" "when STREAMING_ENABLED=true (streaming is on by default; disable it together with OUTBOX_ENABLED)" "set" "global.streaming.brokers") -}}
{{- end -}}
{{- /* STA transfers client (m2m to br-sta). */ -}}
{{- if eq (include "br-sisbajud.isTrue" (index $data "STA_TRANSFERS_ENABLED")) "true" -}}
{{- include $req (dict "context" $ "key" "STA_TRANSFERS_BASE_URL" "value" (index $data "STA_TRANSFERS_BASE_URL") "why" "when STA_TRANSFERS_ENABLED=true" "set" "brSisbajud.sta.transfersBaseUrl") -}}
{{- include $req (dict "context" $ "key" "STA_CLIENT_ID" "value" (index $data "STA_CLIENT_ID") "why" "when STA_TRANSFERS_ENABLED=true" "set" "brSisbajud.sta.clientId") -}}
{{- include $req (dict "context" $ "key" "STA_CLIENT_SECRET" "secret" true "why" "when STA_TRANSFERS_ENABLED=true" "set" "brSisbajud.secrets.STA_CLIENT_SECRET") -}}
{{- include $req (dict "context" $ "key" "PLUGIN_AUTH_HOST" "value" (index $data "PLUGIN_AUTH_HOST") "why" "when STA_TRANSFERS_ENABLED=true (the m2m bearer is minted from it, even with PLUGIN_AUTH_ENABLED=false)" "set" "global.auth.host") -}}
{{- end -}}
{{- /* Inbound auth. */ -}}
{{- if eq (include "br-sisbajud.isTrue" (index $data "PLUGIN_AUTH_ENABLED")) "true" -}}
{{- include $req (dict "context" $ "key" "PLUGIN_AUTH_HOST" "value" (index $data "PLUGIN_AUTH_HOST") "why" "when PLUGIN_AUTH_ENABLED=true" "set" "global.auth.host") -}}
{{- end -}}
{{- /* Access-manager declaration publisher. */ -}}
{{- if eq (include "br-sisbajud.isTrue" (index $data "IDP_DECLARATION_ENABLED")) "true" -}}
{{- include $req (dict "context" $ "key" "IDP_HOST" "value" (index $data "IDP_HOST") "why" "when IDP_DECLARATION_ENABLED=true" "set" "brSisbajud.identity.host") -}}
{{- include $req (dict "context" $ "key" "IDP_M2M_CLIENT_ID" "value" (index $data "IDP_M2M_CLIENT_ID") "why" "when IDP_DECLARATION_ENABLED=true" "set" "brSisbajud.identity.m2mClientId") -}}
{{- include $req (dict "context" $ "key" "IDP_M2M_CLIENT_SECRET" "secret" true "why" "when IDP_DECLARATION_ENABLED=true" "set" "brSisbajud.secrets.IDP_M2M_CLIENT_SECRET") -}}
{{- end -}}
{{- /* License mode: GLOBAL only. */ -}}
{{- $org := trim (toString (index $data "ORGANIZATION_IDS")) -}}
{{- if and $org (ne (lower $org) "global") -}}
{{- fail (printf "\n\nERROR: br-sisbajud: ORGANIZATION_IDS must be \"global\" (got %q): the app supports GLOBAL license mode only.\n" $org) -}}
{{- end -}}
{{- end -}}
