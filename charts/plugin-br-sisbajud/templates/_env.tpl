{{/*
==============================================================================
plugin-br-sisbajud.configmapData — every env key the chart models, as
ConfigMap `data` lines. Contract source: LerianStudio/plugin-br-sisbajud
internal/bootstrap/config*.go (env tags + validations), restricted to what the
process reads in EXECUTOR mode: MENSAGERIA_BASE_URL set, or EXECUTOR_ENABLED=true
without it (DIRECT-only, DR-07: no transport / Hub webhook / SQS keys). Dependency
connections go through the lerian-common masks/env helpers; the rest through
lerian-common.cfgValue (plugin-br-sisbajud.kv). No credential is emitted here.
==============================================================================
*/}}
{{- define "plugin-br-sisbajud.configmapData" -}}
{{- $ := . -}}
{{- $s := .Values.sisbajud -}}
{{- $cm := $s.configmap | default dict -}}
{{- $kv := "plugin-br-sisbajud.kv" -}}
{{- $ex := $s.executor | default dict -}}
{{- $wh := $ex.webhook | default dict -}}
{{- $sqs := $ex.sqs | default dict -}}
{{- $whTls := $wh.tls | default dict -}}
{{- $kmsDed := $s.kms | default dict -}}
{{- $pg := include "plugin-br-sisbajud.postgres" . | fromYaml -}}
{{- $envName := include "plugin-br-sisbajud.val" (dict "cm" $cm "k" "ENVIRONMENT_NAME" "p" $s.app "f" "environmentName" "d" "production") -}}
{{- $mtOn := eq (include "plugin-br-sisbajud.multiTenantEnabled" .) "true" -}}
{{- $transport := include "plugin-br-sisbajud.transport" . -}}
{{- $kmsProvider := include "plugin-br-sisbajud.kmsProvider" . -}}
{{- $mode := include "plugin-br-sisbajud.executorMode" . -}}
{{- $exOn := include "plugin-br-sisbajud.executorEnabled" . -}}
{{- $exDirect := $ex.direct | default dict -}}
{{- $direct := $s.direct | default dict }}
# --- Application -------------------------------------------------------------
ENVIRONMENT_NAME: {{ $envName | quote }}
ENV_NAME: {{ (hasKey $cm "ENV_NAME" | ternary (index $cm "ENV_NAME") $envName) | quote }}
{{- include $kv (dict "cm" $cm "p" $s.app "f" "logLevel" "k" "LOG_LEVEL" "d" "info") }}
{{- include $kv (dict "cm" $cm "p" $s.app "f" "deploymentMode" "k" "DEPLOYMENT_MODE" "d" "byoc") }}
{{- include $kv (dict "cm" $cm "p" $s.app "f" "defaultTenantId" "k" "DEFAULT_TENANT_ID" "d" "11111111-1111-1111-1111-111111111111") }}
{{- include $kv (dict "cm" $cm "p" $s.app "f" "systemplaneEnabled" "k" "SYSTEMPLANE_ENABLED" "d" "false") }}
{{- include $kv (dict "cm" $cm "p" $s.app "f" "infraConnectTimeoutSec" "k" "INFRA_CONNECT_TIMEOUT_SEC" "d" "30") }}
# --- HTTP server + CORS --------------------------------------------------------
SERVER_ADDRESS: {{ (hasKey $cm "SERVER_ADDRESS" | ternary (index $cm "SERVER_ADDRESS") (printf ":%v" $s.service.port)) | quote }}
{{- include $kv (dict "cm" $cm "p" $s.server "f" "bodyLimitBytes" "k" "HTTP_BODY_LIMIT_BYTES" "d" "104857600") }}
{{- include $kv (dict "cm" $cm "p" $s.server "f" "tlsTerminatedUpstream" "k" "TLS_TERMINATED_UPSTREAM" "d" "false") }}
{{- /* The app binds CORS_* (ServerConfig); the lib-commons CORS middleware reads
   ACCESS_CONTROL_*. Both are emitted from one resolution. */}}
{{- $cors := list (list "allowedOrigins" "CORS_ALLOWED_ORIGINS" "ACCESS_CONTROL_ALLOW_ORIGIN" "") (list "allowedMethods" "CORS_ALLOWED_METHODS" "ACCESS_CONTROL_ALLOW_METHODS" "GET,POST,PUT,PATCH,DELETE,OPTIONS") (list "allowedHeaders" "CORS_ALLOWED_HEADERS" "ACCESS_CONTROL_ALLOW_HEADERS" "Origin,Content-Type,Accept,Authorization,X-Request-ID") (list "exposeHeaders" "CORS_EXPOSE_HEADERS" "ACCESS_CONTROL_EXPOSE_HEADERS" "") (list "allowCredentials" "CORS_ALLOW_CREDENTIALS" "ACCESS_CONTROL_ALLOW_CREDENTIALS" "false") }}
{{- range $row := $cors }}
{{- $v := include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" (index $row 1) "params" $s.cors "field" (index $row 0) "default" (index $row 3)) }}
{{ index $row 1 }}: {{ $v | quote }}
{{ index $row 2 }}: {{ (hasKey $cm (index $row 2) | ternary (index $cm (index $row 2)) $v) | quote }}
{{- end }}
# --- License (LICENSE_KEY lives in the Secret) ---------------------------------
{{- include $kv (dict "cm" $cm "p" $s.license "f" "organizationIds" "k" "ORGANIZATION_IDS" "d" "global") }}
{{- include $kv (dict "cm" $cm "p" $s.license "f" "isDevelopment" "k" "IS_DEVELOPMENT" "opt" true) }}
# --- Executor: Sisbajud Mensageria (TLS; mTLS behind MENSAGERIA_MTLS_ENABLED) ------
{{- include $kv (dict "cm" $cm "p" $s.mensageria "f" "baseUrl" "k" "MENSAGERIA_BASE_URL" "d" "") }}
{{- $mt := include "plugin-br-sisbajud.mensageriaTls" . | fromYaml }}
MENSAGERIA_MTLS_ENABLED: {{ $mt.raw | default "false" | quote }}
{{- if $mt.caSecret }}
MENSAGERIA_TLS_CA_FILE: {{ $mt.caFile | quote }}
{{- else if index $cm "MENSAGERIA_TLS_CA_FILE" }}
MENSAGERIA_TLS_CA_FILE: {{ index $cm "MENSAGERIA_TLS_CA_FILE" | quote }}
{{- end }}
{{- if and (eq $mt.mtls "true") $mt.tlsSecret }}
MENSAGERIA_TLS_CLIENT_CERT_FILE: {{ $mt.certFile | quote }}
MENSAGERIA_TLS_CLIENT_KEY_FILE: {{ $mt.keyFile | quote }}
{{- else }}
{{- range $k := list "MENSAGERIA_TLS_CLIENT_CERT_FILE" "MENSAGERIA_TLS_CLIENT_KEY_FILE" }}
{{- if index $cm $k }}
{{ $k }}: {{ index $cm $k | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- include $kv (dict "cm" $cm "p" $ex "f" "m2mSubject" "k" "EXECUTOR_M2M_SUBJECT" "d" "") }}
{{- include $kv (dict "cm" $cm "p" $ex "f" "streamingHubTenantId" "k" "STREAMING_HUB_TENANT_ID" "opt" true) }}
{{- include $kv (dict "cm" $cm "p" $ex "f" "heartbeatEvery" "k" "EXECUTOR_HEARTBEAT_EVERY" "d" "") }}
{{- include $kv (dict "cm" $cm "p" $ex "f" "humanDecisionAfterBeats" "k" "EXECUTOR_HUMAN_DECISION_AFTER_BEATS" "d" "3") }}
{{- include $kv (dict "cm" $cm "p" $ex "f" "responseDeadlineMargin" "k" "RESPONSE_DEADLINE_MARGIN" "d" "") }}
{{- include $kv (dict "cm" $cm "p" $ex "f" "settleWindow" "k" "EXECUTOR_SETTLE_WINDOW" "opt" true) }}
{{- include $kv (dict "cm" $cm "p" $ex "f" "tickEvery" "k" "EXECUTOR_TICK_EVERY" "d" "30s") }}
{{- include $kv (dict "cm" $cm "p" $ex "f" "orphanReconcileWindow" "k" "EXECUTOR_ORPHAN_RECONCILE_WINDOW" "d" "48h") }}
{{- if $exOn }}
EXECUTOR_ENABLED: {{ $exOn | quote }}
{{- end }}
{{- include $kv (dict "cm" $cm "p" $ex "f" "resultMaxAttempts" "k" "EXECUTOR_RESULT_MAX_ATTEMPTS" "d" "12") }}
# --- Direct channel: drainer alarms + permanent-block switch ----------------------
{{- include $kv (dict "cm" $cm "p" $exDirect "f" "drainerInfraAlarmThreshold" "k" "EXECUTOR_DIRECT_DRAINER_INFRA_ALARM_THRESHOLD" "d" "3") }}
{{- include $kv (dict "cm" $cm "p" $exDirect "f" "purgeEligibleAlarmAfter" "k" "EXECUTOR_DIRECT_PURGE_ELIGIBLE_ALARM_AFTER" "d" "168h") }}
{{- include $kv (dict "cm" $cm "p" $direct "f" "permanentBlockEnabled" "k" "DIRECT_PERMANENT_BLOCK_ENABLED" "d" "false") }}
{{- if eq $mode "direct" }}
# --- DIRECT-only: no Mensageria intake; this key is the direct drainer's attempt cap
{{- include $kv (dict "cm" $cm "p" $wh "f" "maxHandleAttempts" "k" "EXECUTOR_HUB_WEBHOOK_MAX_HANDLE_ATTEMPTS" "d" "5") }}
{{- else }}
EXECUTOR_TRANSPORT: {{ $transport | quote }}
{{- if eq $transport "webhook" }}
# --- Executor: Streaming Hub webhook listener ------------------------------------
EXECUTOR_HUB_WEBHOOK_ADDRESS: {{ (hasKey $cm "EXECUTOR_HUB_WEBHOOK_ADDRESS" | ternary (index $cm "EXECUTOR_HUB_WEBHOOK_ADDRESS") (printf ":%v" ($wh.port | default 9082))) | quote }}
{{- include $kv (dict "cm" $cm "p" $wh "f" "path" "k" "EXECUTOR_HUB_WEBHOOK_PATH" "d" "/v1/webhooks/hub") }}
{{- include $kv (dict "cm" $cm "p" $wh "f" "maxSkewSec" "k" "EXECUTOR_HUB_WEBHOOK_MAX_SKEW_SEC" "d" "300") }}
{{- include $kv (dict "cm" $cm "p" $wh "f" "maxHandleAttempts" "k" "EXECUTOR_HUB_WEBHOOK_MAX_HANDLE_ATTEMPTS" "d" "5") }}
{{- include $kv (dict "cm" $cm "p" $wh "f" "upstreamTlsValidated" "k" "EXECUTOR_HUB_WEBHOOK_UPSTREAM_TLS_VALIDATED" "d" "false") }}
{{- if $whTls.existingSecret }}
EXECUTOR_HUB_WEBHOOK_TLS_CERT_FILE: {{ printf "%s/%s" (trimSuffix "/" $whTls.mountPath) $whTls.certKey | quote }}
EXECUTOR_HUB_WEBHOOK_TLS_KEY_FILE: {{ printf "%s/%s" (trimSuffix "/" $whTls.mountPath) $whTls.keyKey | quote }}
{{- else }}
{{- range $k := list "EXECUTOR_HUB_WEBHOOK_TLS_CERT_FILE" "EXECUTOR_HUB_WEBHOOK_TLS_KEY_FILE" }}
{{- with index $cm $k }}
{{ $k }}: {{ . | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- else }}
# --- Executor: SQS consumer ----------------------------------------------------------
{{- include $kv (dict "cm" $cm "p" $sqs "f" "queueUrl" "k" "EXECUTOR_SQS_QUEUE_URL" "d" "") }}
{{- include $kv (dict "cm" $cm "p" $sqs "f" "region" "k" "EXECUTOR_SQS_REGION" "d" "") }}
{{- include $kv (dict "cm" $cm "p" $sqs "f" "waitTimeSeconds" "k" "EXECUTOR_SQS_WAIT_TIME_SECONDS" "d" "20") }}
{{- include $kv (dict "cm" $cm "p" $sqs "f" "maxMessages" "k" "EXECUTOR_SQS_MAX_MESSAGES" "d" "10") }}
{{- include $kv (dict "cm" $cm "p" $sqs "f" "visibilityTimeoutSeconds" "k" "EXECUTOR_SQS_VISIBILITY_TIMEOUT_SECONDS" "d" "300") }}
{{- include $kv (dict "cm" $cm "p" $sqs "f" "maxReceiveCount" "k" "EXECUTOR_SQS_MAX_RECEIVE_COUNT" "d" "5") }}
{{- end }}
{{- end }}
# --- Midaz connector (ledger URL + credentials are per institution, in the DB) ----
{{- include $kv (dict "cm" $cm "p" $s.midaz "f" "crmMode" "k" "MIDAZ_CRM_MODE" "d" "legacy") }}
# --- Inbound auth + token minting (lerian-common.auth.env) -----------------------
{{ include "lerian-common.auth.env" (dict "context" $ "configmap" $cm "hostKey" "PLUGIN_AUTH_HOST" "hostDefault" "") }}
{{- include $kv (dict "cm" $cm "p" $s.auth "f" "productName" "k" "AUTH_PRODUCT_NAME" "opt" true) }}
{{- include $kv (dict "cm" $cm "p" $s.auth "f" "trustedProxies" "k" "TRUSTED_PROXIES" "d" "") }}
# --- Access Manager declaration publisher (lib-auth) ------------------------------
{{- include $kv (dict "cm" $cm "p" $s.identity "f" "declarationEnabled" "k" "IDP_DECLARATION_ENABLED" "d" "false") }}
{{- include $kv (dict "cm" $cm "p" $s.identity "f" "host" "k" "IDP_HOST" "opt" true) }}
# --- Multi-tenant (lerian-common.multiTenant.env; API key in the Secret) ----------
MULTI_TENANT_ENABLED: {{ ternary "true" "false" $mtOn | quote }}
{{- with (include "lerian-common.multiTenant.env" (dict "context" $ "configmap" $cm "enabled" $mtOn "requiredUrl" true "requiredRedisHost" true "emitRedis" true "emitPool" true "emitCache" true "emitAllowInsecure" true) | trim) }}
{{ . }}
{{- end }}
# --- PostgreSQL (lerian-common.datastore.value; password in the Secret) ----------
POSTGRES_HOST: {{ $pg.host | quote }}
POSTGRES_PORT: {{ $pg.port | quote }}
POSTGRES_USER: {{ $pg.user | quote }}
POSTGRES_NAME: {{ $pg.name | quote }}
POSTGRES_SSLMODE: {{ $pg.ssl | quote }}
{{- include $kv (dict "cm" $cm "p" $s.postgres "f" "maxOpenConns" "k" "POSTGRES_MAX_OPEN_CONNS" "d" "25") }}
{{- include $kv (dict "cm" $cm "p" $s.postgres "f" "maxIdleConns" "k" "POSTGRES_MAX_IDLE_CONNS" "d" "5") }}
{{- include $kv (dict "cm" $cm "p" $s.postgres "f" "connMaxLifetimeMins" "k" "POSTGRES_CONN_MAX_LIFETIME_MINS" "d" "30") }}
{{- include $kv (dict "cm" $cm "p" $s.postgres "f" "connMaxIdleTimeMins" "k" "POSTGRES_CONN_MAX_IDLE_TIME_MINS" "d" "5") }}
{{- include $kv (dict "cm" $cm "p" $s.postgres "f" "connectTimeoutSec" "k" "POSTGRES_CONNECT_TIMEOUT_SEC" "d" "10") }}
{{- if $pg.replicaHost }}
{{- $dv := "lerian-common.datastore.value" }}
{{- $ded := $s.datastores | default dict }}
POSTGRES_REPLICA_HOST: {{ $pg.replicaHost | quote }}
POSTGRES_REPLICA_PORT: {{ include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "postgres" "field" "replicaPort" "nativeKey" "POSTGRES_REPLICA_PORT" "default" $pg.port) | quote }}
POSTGRES_REPLICA_USER: {{ include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "postgres" "field" "replicaUser" "nativeKey" "POSTGRES_REPLICA_USER" "default" $pg.user) | quote }}
POSTGRES_REPLICA_NAME: {{ include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "postgres" "field" "replicaName" "nativeKey" "POSTGRES_REPLICA_NAME" "default" $pg.name) | quote }}
POSTGRES_REPLICA_SSLMODE: {{ include $dv (dict "context" $ "dedicated" $ded "configmap" $cm "type" "postgres" "field" "ssl" "nativeKey" "POSTGRES_REPLICA_SSLMODE" "default" $pg.ssl) | quote }}
{{- end }}
# --- Redis / Valkey (lerian-common.datastore.value; password in the Secret) ------
{{- $dsDed := $s.datastores | default dict }}
REDIS_HOST: {{ include "plugin-br-sisbajud.redisHost" . | quote }}
REDIS_TLS: {{ include "lerian-common.datastore.value" (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "redis" "field" "tls" "nativeKey" "REDIS_TLS" "default" "false") | quote }}
{{- with include "lerian-common.datastore.value" (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "redis" "field" "caCert" "nativeKey" "REDIS_CA_CERT" "default" "") }}
REDIS_CA_CERT: {{ . | quote }}
{{- end }}
{{- include $kv (dict "cm" $cm "p" $s.redis "f" "masterName" "k" "REDIS_MASTER_NAME" "opt" true) }}
{{- include $kv (dict "cm" $cm "p" $s.redis "f" "db" "k" "REDIS_DB" "d" "0") }}
{{- include $kv (dict "cm" $cm "p" $s.redis "f" "protocol" "k" "REDIS_PROTOCOL" "d" "3") }}
{{- if or (hasKey $cm "ALLOW_INSECURE_TLS") (eq (include "plugin-br-sisbajud.postgresBundled" .) "true") (eq (include "plugin-br-sisbajud.valkeyBundled" .) "true") }}
{{- /* lib-commons plaintext bypass: only for the bundled (plaintext) dev subcharts. */}}
ALLOW_INSECURE_TLS: {{ (hasKey $cm "ALLOW_INSECURE_TLS" | ternary (index $cm "ALLOW_INSECURE_TLS") "true") | quote }}
{{- end }}
# --- KMS (lerian-common.kms.value; VAULT_TOKEN / VAULT_APPROLE_SECRET_ID in the Secret)
KMS_PROVIDER: {{ $kmsProvider | quote }}
{{- if eq $kmsProvider "vault" }}
VAULT_ADDR: {{ include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "vaultAddr" "nativeKey" "VAULT_ADDR" "default" "") | quote }}
VAULT_AUTH_METHOD: {{ include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "vaultAuthMethod" "nativeKey" "VAULT_AUTH_METHOD" "default" "token") | quote }}
{{- with include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "vaultRoleId" "nativeKey" "VAULT_APPROLE_ROLE_ID" "default" "") }}
VAULT_APPROLE_ROLE_ID: {{ . | quote }}
{{- end }}
VAULT_TRANSIT_MOUNT_PATH: {{ include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "vaultMount" "nativeKey" "VAULT_TRANSIT_MOUNT_PATH" "default" "transit") | quote }}
{{- include $kv (dict "cm" $cm "p" $s.vault "f" "timeoutSec" "k" "VAULT_TIMEOUT_SEC" "d" "15") }}
{{- include $kv (dict "cm" $cm "p" $s.vault "f" "renewEnabled" "k" "VAULT_TOKEN_RENEW_ENABLED" "d" "true") }}
{{- include $kv (dict "cm" $cm "p" $s.vault "f" "renewMinIntervalSec" "k" "VAULT_TOKEN_RENEW_MIN_INTERVAL_SEC" "d" "60") }}
{{- end }}
{{- with include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "awsRegion" "nativeKey" "AWS_REGION" "default" "") }}
AWS_REGION: {{ . | quote }}
{{- end }}
# --- Envelope encryption + blind index ---------------------------------------------
{{- include $kv (dict "cm" $cm "p" $s.crypto "f" "dekCacheTtl" "k" "SISBAJUD_DEK_CACHE_TTL" "d" "5m") }}
{{- include $kv (dict "cm" $cm "p" $s.crypto "f" "hmacCoexistenceWindow" "k" "SISBAJUD_HMAC_COEXISTENCE_WINDOW" "d" "720h") }}
# --- Streaming: OFF in executor mode ------------------------------------------------
{{- /* Executor mode starts no producer or consumer (no outbox dispatcher, no balance
   consumer, no Midaz translator), so the chart renders it off explicitly (same as the
   app default) and an enabled value would only demand brokers the executor never uses. */}}
STREAMING_ENABLED: {{ (hasKey $cm "STREAMING_ENABLED" | ternary (index $cm "STREAMING_ENABLED") "false") | quote }}
# --- OpenTelemetry (lerian-common.otel.env) ------------------------------------------
{{ include "lerian-common.otel.env" (dict "context" $ "configmap" $cm "enabledDefault" "false" "endpointDefault" "localhost:4317" "deploymentEnvironmentDefault" $envName) }}
{{- include $kv (dict "cm" $cm "p" $s.observability "f" "serviceName" "k" "OTEL_RESOURCE_SERVICE_NAME" "d" "plugin-br-sisbajud") }}
{{- include $kv (dict "cm" $cm "p" $s.observability "f" "libraryName" "k" "OTEL_LIBRARY_NAME" "d" "github.com/LerianStudio/plugin-br-sisbajud") }}
# --- Rate limiting (lerian-common.rateLimit.env) ------------------------------------
{{ include "lerian-common.rateLimit.env" (dict "configmap" $cm "params" $s.rateLimit) }}
# --- Swagger -----------------------------------------------------------------------
{{- include $kv (dict "cm" $cm "p" $s.swagger "f" "enabled" "k" "SWAGGER_ENABLED" "d" "false") }}
{{- end -}}

{{/*
==============================================================================
plugin-br-sisbajud.secretData — the chart Secret (stringData lines). Emit-when-
set: only non-empty sisbajud.secrets keys. Infra passwords sourced from a
subchart Secret (bundled / <subchart>.auth.existingSecret) are NOT copied
(single source). Multi-tenant keys come from lerian-common.multiTenant.secret,
which fails fast when MULTI_TENANT_SERVICE_API_KEY is missing.
==============================================================================
*/}}
{{- define "plugin-br-sisbajud.secretData" -}}
{{- $s := .Values.sisbajud -}}
{{- $sec := $s.secrets | default dict -}}
{{- $skip := list "MULTI_TENANT_SERVICE_API_KEY" "MULTI_TENANT_REDIS_PASSWORD" -}}
{{- if eq (include "plugin-br-sisbajud.postgresPasswordFromRef" .) "true" }}{{- $skip = append $skip "POSTGRES_PASSWORD" -}}{{- end -}}
{{- if eq (include "plugin-br-sisbajud.redisPasswordFromRef" .) "true" }}{{- $skip = append $skip "REDIS_PASSWORD" -}}{{- end -}}
{{- range $k := keys $sec | sortAlpha }}
{{- $v := index $sec $k }}
{{- if and (not (has $k $skip)) (ne (toString ($v | default "")) "") }}
{{ $k }}: {{ $v | toString | quote }}
{{- end }}
{{- end }}
{{- with (include "lerian-common.multiTenant.secret" (dict "context" . "secrets" $sec "secretName" (include "plugin-br-sisbajud.fullname" .) "valuesPrefix" "sisbajud.secrets." "mode" "stringData" "enabled" (eq (include "plugin-br-sisbajud.multiTenantEnabled" .) "true") "useExistingSecret" false) | trim) }}
{{ . }}
{{- end }}
{{- end -}}
