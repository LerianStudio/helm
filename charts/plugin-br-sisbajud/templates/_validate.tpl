{{/*
==============================================================================
plugin-br-sisbajud.validate — fail the render, naming the exact value to set,
for every configuration the app itself refuses at boot in executor mode
(internal/bootstrap/config_validation.go, config_executor.go,
config_executor_m2m.go, config_vault_scheme.go). helm lint treats these as INFO.
==============================================================================
*/}}

{{/*
provided — "true" when a CREDENTIAL key reaches the pod: a non-empty
sisbajud.secrets.<KEY>, an extraEnvVars entry, or an external Secret (opaque to
the chart, trusted). Input: dict "context" $ "key" KEY.
*/}}
{{- define "plugin-br-sisbajud.provided" -}}
{{- $s := .context.Values.sisbajud -}}
{{- $sec := $s.secrets | default dict -}}
{{- $extra := $s.extraEnvVars | default dict -}}
{{- if or $s.useExistingSecret (hasKey $extra .key) (ne (toString (index $sec .key | default "")) "") -}}true{{- end -}}
{{- end -}}

{{- define "plugin-br-sisbajud.fail" -}}
{{- fail (printf "\n\nERROR: plugin-br-sisbajud: %s\n  set: %s\n" .msg .set) -}}
{{- end -}}

{{- define "plugin-br-sisbajud.nonProduction" -}}
{{- $cm := .Values.sisbajud.configmap | default dict -}}
{{- $env := include "plugin-br-sisbajud.val" (dict "cm" $cm "k" "ENVIRONMENT_NAME" "p" .Values.sisbajud.app "f" "environmentName" "d" "production") | trim | lower -}}
{{- if has $env (list "local" "development" "staging" "e2e" "test") -}}true{{- end -}}
{{- end -}}

{{/*
plaintextSecretTransport — "true" when the app lets a secret (the Vault token)
travel over plain http: ENVIRONMENT_NAME local|development|test only
(config_helpers.go plaintextSecretTransportEnvNames; staging/e2e excluded).
*/}}
{{- define "plugin-br-sisbajud.plaintextSecretTransport" -}}
{{- $cm := .Values.sisbajud.configmap | default dict -}}
{{- $env := include "plugin-br-sisbajud.val" (dict "cm" $cm "k" "ENVIRONMENT_NAME" "p" .Values.sisbajud.app "f" "environmentName" "d" "production") | trim | lower -}}
{{- if has $env (list "local" "development" "test") -}}true{{- end -}}
{{- end -}}

{{- define "plugin-br-sisbajud.validate" -}}
{{- $ := . -}}
{{- $s := .Values.sisbajud -}}
{{- $cm := $s.configmap | default dict -}}
{{- $ex := $s.executor | default dict -}}
{{- $wh := $ex.webhook | default dict -}}
{{- $mt := include "plugin-br-sisbajud.mensageriaTls" . | fromYaml -}}
{{- $f := "plugin-br-sisbajud.fail" -}}
{{- $val := "plugin-br-sisbajud.val" -}}
{{- $nonProd := eq (include "plugin-br-sisbajud.nonProduction" .) "true" -}}

{{- /* --- values the health preset now owns ------------------------------------- */ -}}
{{- range $k, $why := dict "pdb" "the preset renders the PodDisruptionBudget" "deploymentStrategy" "the preset sets the rollout (maxUnavailable 0)" "readinessProbe" "probes are served on the health port by the preset" "livenessProbe" "probes are served on the health port by the preset" "terminationGracePeriodSeconds" "the grace period is drain + health.shutdownSeconds + 10" -}}
{{- if hasKey $s $k -}}
{{- include $f (dict "msg" (printf "sisbajud.%s is owned by the health preset (%s)." $k $why) "set" (printf "remove sisbajud.%s from your values (tune sisbajud.health.shutdownSeconds)" $k)) -}}
{{- end -}}
{{- end -}}

{{- /* --- tenant + license ------------------------------------------------- */ -}}
{{- $tenant := include $val (dict "cm" $cm "k" "DEFAULT_TENANT_ID" "p" $s.app "f" "defaultTenantId" "d" "11111111-1111-1111-1111-111111111111") | trim -}}
{{- if not (regexMatch "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$" $tenant) -}}
{{- include $f (dict "msg" (printf "DEFAULT_TENANT_ID must be a UUID (got %q)." $tenant) "set" "sisbajud.app.defaultTenantId") -}}
{{- end -}}
{{- $org := include $val (dict "cm" $cm "k" "ORGANIZATION_IDS" "p" $s.license "f" "organizationIds" "d" "global") | trim | lower -}}
{{- if ne $org "global" -}}
{{- include $f (dict "msg" "ORGANIZATION_IDS must be \"global\" (the app supports GLOBAL license mode only)." "set" "sisbajud.license.organizationIds=global") -}}
{{- end -}}
{{- if not (include "plugin-br-sisbajud.provided" (dict "context" $ "key" "LICENSE_KEY")) -}}
{{- include $f (dict "msg" "LICENSE_KEY is required in every environment (the app has no unlicensed mode)." "set" "sisbajud.secrets.LICENSE_KEY (or sisbajud.useExistingSecret)") -}}
{{- end -}}

{{- /* --- executor switches (closed sets, trimmed, case-sensitive) ----------- */ -}}
{{- $exOn := include "plugin-br-sisbajud.executorEnabled" . -}}
{{- if not (has $exOn (list "" "true" "false")) -}}
{{- include $f (dict "msg" (printf "EXECUTOR_ENABLED must be true or false (or unset), got %q." $exOn) "set" "sisbajud.executor.enabled") -}}
{{- end -}}
{{- $pb := include $val (dict "cm" $cm "k" "DIRECT_PERMANENT_BLOCK_ENABLED" "p" ($s.direct | default dict) "f" "permanentBlockEnabled" "d" "true") | trim -}}
{{- if not (has $pb (list "" "true" "false")) -}}
{{- include $f (dict "msg" (printf "DIRECT_PERMANENT_BLOCK_ENABLED must be true or false, got %q." $pb) "set" "sisbajud.direct.permanentBlockEnabled") -}}
{{- end -}}
{{- /* --- streaming (the balance-change stream of the permanent block) ------- */ -}}
{{- $se := include "plugin-br-sisbajud.streamingEnabled" . -}}
{{- $sb := include "plugin-br-sisbajud.streamingBrokers" . -}}
{{- if and (eq $pb "true") (or (ne $se "true") (not $sb)) -}}
{{- include $f (dict "msg" "sisbajud.direct.permanentBlockEnabled is true (the chart default) and needs STREAMING_ENABLED=true and STREAMING_BROKERS: the permanent block reads the balance-change stream (the app refuses the boot otherwise)." "set" "global.streaming.brokers (+ global.streaming.tlsEnabled/SASL in production), or sisbajud.direct.permanentBlockEnabled=false for an install without brokers (e.g. Mensageria-only)") -}}
{{- end -}}
{{- /* The permanent path is served only single-tenant with inbound auth on
   (extensions_executor_permanent.go servable): the app refuses the boot otherwise. */ -}}
{{- if eq $pb "true" -}}
{{- $permAuth := include "lerian-common.globalValue" (dict "context" $ "configmap" $cm "block" "auth" "field" "enabled" "nativeKey" "PLUGIN_AUTH_ENABLED" "default" "false") -}}
{{- if ne (include "plugin-br-sisbajud.isTrue" $permAuth) "true" -}}
{{- include $f (dict "msg" "sisbajud.direct.permanentBlockEnabled is true (the chart default) and requires inbound auth on (PLUGIN_AUTH_ENABLED=true): the permanent block is served only with auth on (the app refuses the boot otherwise)." "set" "global.auth.enabled=true, or sisbajud.direct.permanentBlockEnabled=false") -}}
{{- end -}}
{{- if eq (include "plugin-br-sisbajud.multiTenantEnabled" .) "true" -}}
{{- include $f (dict "msg" "sisbajud.direct.permanentBlockEnabled is true (the chart default) and requires a single-tenant install (MULTI_TENANT_ENABLED=false): the permanent block is not served multi-tenant (the app refuses the boot otherwise)." "set" "global.multiTenant.enabled=false, or sisbajud.direct.permanentBlockEnabled=false") -}}
{{- end -}}
{{- end -}}
{{- if eq $se "true" -}}
{{- if not $sb -}}
{{- include $f (dict "msg" "STREAMING_BROKERS is required with STREAMING_ENABLED=true (lib-streaming refuses the boot without a broker)." "set" "global.streaming.brokers (or sisbajud.configmap.STREAMING_BROKERS)") -}}
{{- end -}}
{{- $gs := (.Values.global | default dict).streaming | default dict -}}
{{- $tls := hasKey $cm "STREAMING_TLS_ENABLED" | ternary (index $cm "STREAMING_TLS_ENABLED") ($gs.tlsEnabled | default false) | toString -}}
{{- if and (not (include "plugin-br-sisbajud.nonProduction" .)) (not (has $tls (list "1" "t" "T" "TRUE" "true" "True"))) -}}
{{- include $f (dict "msg" "STREAMING_TLS_ENABLED=true is required with STREAMING_ENABLED=true in a production-like environment (the app refuses the boot)." "set" "global.streaming.tlsEnabled=true (+ sisbajud.secrets.STREAMING_TLS_CA_CERT for a private CA)") -}}
{{- end -}}
{{- $mech := hasKey $cm "STREAMING_SASL_MECHANISM" | ternary (index $cm "STREAMING_SASL_MECHANISM") ($gs.saslMechanism | default "") | toString | trim -}}
{{- if and $mech (not (include "plugin-br-sisbajud.provided" (dict "context" $ "key" "STREAMING_SASL_PASSWORD"))) -}}
{{- include $f (dict "msg" (printf "STREAMING_SASL_PASSWORD is required with STREAMING_SASL_MECHANISM=%s." $mech) "set" "sisbajud.secrets.STREAMING_SASL_PASSWORD (or sisbajud.useExistingSecret)") -}}
{{- end -}}
{{- end -}}
{{- $sweep := include $val (dict "cm" $cm "k" "EXECUTOR_ORDER_SWEEP_ENABLED" "p" ($s.executor | default dict) "f" "orderSweepEnabled" "d" "false") | trim -}}
{{- if not (has $sweep (list "" "true" "false")) -}}
{{- include $f (dict "msg" (printf "EXECUTOR_ORDER_SWEEP_ENABLED must be true or false, got %q." $sweep) "set" "sisbajud.executor.orderSweepEnabled") -}}
{{- end -}}
{{- $emit := include $val (dict "cm" $cm "k" "EXECUTOR_PERMANENT_RESULT_EMITTER_ENABLED" "p" ($s.direct | default dict) "f" "permanentResultEmitterEnabled" "d" "") | trim | default $se -}}
{{- if not (has $emit (list "" "true" "false")) -}}
{{- include $f (dict "msg" (printf "EXECUTOR_PERMANENT_RESULT_EMITTER_ENABLED must be true or false, got %q." $emit) "set" "sisbajud.direct.permanentResultEmitterEnabled") -}}
{{- end -}}
{{- /* The emitter needs the permanent path wired: with the opener off that is the
   maintenance, which runs only with streaming on (executorgraph/permanent_emitter.go). */ -}}
{{- if and (eq $emit "true") (ne $se "true") -}}
{{- include $f (dict "msg" "EXECUTOR_PERMANENT_RESULT_EMITTER_ENABLED=true needs STREAMING_ENABLED=true and STREAMING_BROKERS (the permanent path it publishes from runs only on the balance-change stream; the app refuses the boot otherwise)." "set" "global.streaming.enabled=true and global.streaming.brokers, or sisbajud.direct.permanentResultEmitterEnabled=\"\" (follows the stream) / \"false\"") -}}
{{- end -}}
{{- $mode := include "plugin-br-sisbajud.executorMode" . -}}
{{- if not $mode -}}
{{- include $f (dict "msg" "MENSAGERIA_BASE_URL is required, or EXECUTOR_ENABLED=true for a DIRECT-only executor: one of them is what runs the process as the executor (without both the binary boots the retired monolith and refuses STA_INBOUND_BUCKET)." "set" "sisbajud.mensageria.baseUrl=https://<mensageria-host> (or sisbajud.executor.enabled=true)") -}}
{{- end -}}

{{- include "plugin-br-sisbajud.validateMidazConnection" . -}}

{{- if eq $mode "mensageria" -}}
{{- /* --- Sisbajud Mensageria (executor mode) -------------------------------- */ -}}
{{- $base := include $val (dict "cm" $cm "k" "MENSAGERIA_BASE_URL" "p" $s.mensageria "f" "baseUrl" "d" "") | trim -}}
{{- if and (not (include "plugin-br-sisbajud.isAvpPlaceholder" $base)) (not (regexMatch "^(?i)https://[^/?#]+" $base)) -}}
{{- include $f (dict "msg" (printf "MENSAGERIA_BASE_URL must be an https URL with a host (TLS in every deployment mode), got %q." $base) "set" "sisbajud.mensageria.baseUrl") -}}
{{- end -}}
{{- /* MENSAGERIA_MTLS_ENABLED: blank|true|false (config_executor.go). With "true"
   the CA and the client pair are required; one-way TLS needs nothing (blank CA =
   system trust store) and never loads the pair. */ -}}
{{- if not (has $mt.raw (list "" "true" "false")) -}}
{{- include $f (dict "msg" (printf "MENSAGERIA_MTLS_ENABLED must be true or false, got %q." $mt.raw) "set" "sisbajud.mensageria.mtlsEnabled") -}}
{{- end -}}
{{- if and $mt.caSecret (hasKey $cm "MENSAGERIA_TLS_CA_FILE") -}}
{{- include $f (dict "msg" (printf "MENSAGERIA_TLS_CA_FILE is derived from the mounted CA Secret %q; remove sisbajud.configmap.MENSAGERIA_TLS_CA_FILE." $mt.caSecret) "set" "sisbajud.mensageria.ca.{existingSecret,key,mountPath}") -}}
{{- end -}}
{{- if eq $mt.mtls "true" -}}
{{- if and (not $mt.caSecret) (not (index $cm "MENSAGERIA_TLS_CA_FILE")) -}}
{{- include $f (dict "msg" "MENSAGERIA_MTLS_ENABLED=true requires the Mensageria server CA (MENSAGERIA_TLS_CA_FILE)." "set" "sisbajud.mensageria.ca.existingSecret (or mensageria.tls.existingSecret with caKey)") -}}
{{- end -}}
{{- range $k := list "MENSAGERIA_TLS_CLIENT_CERT_FILE" "MENSAGERIA_TLS_CLIENT_KEY_FILE" -}}
{{- if and $mt.tlsSecret (hasKey $cm $k) -}}
{{- include $f (dict "msg" (printf "%s is derived from the mounted client Secret %q; remove sisbajud.configmap.%s." $k $mt.tlsSecret $k) "set" "sisbajud.mensageria.tls.{certKey,keyKey,mountPath}") -}}
{{- end -}}
{{- if and (not $mt.tlsSecret) (not (index $cm $k)) -}}
{{- include $f (dict "msg" "MENSAGERIA_MTLS_ENABLED=true requires the executor client pair (MENSAGERIA_TLS_CLIENT_CERT_FILE / _KEY_FILE)." "set" "sisbajud.mensageria.tls.existingSecret=<secret with tls.crt, tls.key>") -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- /* Executor-common keys. DIRECT-only requires only the first three plus the tick
   (config_executor.go validateExecutorDirectConfig); STREAMING_HUB_TENANT_ID is a
   Mensageria-mode key. */ -}}
{{- $req := list (list "m2mSubject" "EXECUTOR_M2M_SUBJECT" "the `sub` of the executor's M2M token (execution_owner)") (list "heartbeatEvery" "EXECUTOR_HEARTBEAT_EVERY" "the INDETERMINATE heartbeat period, a Go duration > 0 (e.g. 1m)") (list "responseDeadlineMargin" "RESPONSE_DEADLINE_MARGIN" "a Go duration > 0, the SAME value as the Sisbajud Mensageria (e.g. 2h)") -}}
{{- if eq $mode "mensageria" -}}
{{- $req = append $req (list "streamingHubTenantId" "STREAMING_HUB_TENANT_ID" "the Streaming Hub tenant the probe answerer accepts (the hub deployment's own STREAMING_HUB_TENANT_ID)") -}}
{{- else -}}
{{- $req = append $req (list "tickEvery" "EXECUTOR_TICK_EVERY" "the runner tick, a Go duration > 0 (default 30s)") -}}
{{- $mha := include $val (dict "cm" $cm "k" "EXECUTOR_HUB_WEBHOOK_MAX_HANDLE_ATTEMPTS" "p" $wh "f" "maxHandleAttempts" "d" "5") | trim -}}
{{- if not (regexMatch "^[1-9][0-9]*$" $mha) -}}
{{- include $f (dict "msg" (printf "EXECUTOR_HUB_WEBHOOK_MAX_HANDLE_ATTEMPTS is the direct drainer's attempt cap in a DIRECT-only executor: an integer >= 1, got %q." $mha) "set" "sisbajud.executor.webhook.maxHandleAttempts") -}}
{{- end -}}
{{- end -}}
{{- range $row := $req -}}
{{- if not (include $val (dict "cm" $cm "k" (index $row 1) "p" $ex "f" (index $row 0) "d" "") | trim) -}}
{{- include $f (dict "msg" (printf "%s is required in executor mode: %s." (index $row 1) (index $row 2)) "set" (printf "sisbajud.executor.%s" (index $row 0))) -}}
{{- end -}}
{{- end -}}
{{- if eq $mode "mensageria" -}}
{{- range $k := list "MENSAGERIA_CLIENT_ID" "MENSAGERIA_CLIENT_SECRET" -}}
{{- if not (include "plugin-br-sisbajud.provided" (dict "context" $ "key" $k)) -}}
{{- include $f (dict "msg" (printf "%s is required: the executor's own M2M client at the Mensageria (minted at PLUGIN_AUTH_HOST)." $k) "set" (printf "sisbajud.secrets.%s (or sisbajud.useExistingSecret)" $k)) -}}
{{- end -}}
{{- end -}}
{{- if not (include "lerian-common.globalValue" (dict "context" $ "configmap" $cm "block" "auth" "field" "host" "nativeKey" "PLUGIN_AUTH_HOST" "default" "")) -}}
{{- include $f (dict "msg" "PLUGIN_AUTH_HOST is required: the executor mints its Mensageria token there (even with PLUGIN_AUTH_ENABLED=false)." "set" "global.auth.host (or sisbajud.configmap.PLUGIN_AUTH_HOST)") -}}
{{- end -}}
{{- else -}}
{{- if not (include "lerian-common.globalValue" (dict "context" $ "configmap" $cm "block" "auth" "field" "host" "nativeKey" "PLUGIN_AUTH_HOST" "default" "")) -}}
{{- include $f (dict "msg" "PLUGIN_AUTH_HOST is required: the direct channel is served only with inbound auth on (config_validation.go requires the host with PLUGIN_AUTH_ENABLED=true)." "set" "global.auth.host (or sisbajud.configmap.PLUGIN_AUTH_HOST)") -}}
{{- end -}}
{{- $authOn := include "lerian-common.globalValue" (dict "context" $ "configmap" $cm "block" "auth" "field" "enabled" "nativeKey" "PLUGIN_AUTH_ENABLED" "default" "false") -}}
{{- if ne (include "plugin-br-sisbajud.isTrue" $authOn) "true" -}}
{{- include $f (dict "msg" (printf "PLUGIN_AUTH_ENABLED must be true in a DIRECT-only executor, got %q: the direct channel is served only with inbound auth on (with auth off every direct route answers 501)." (toString $authOn)) "set" "global.auth.enabled=true (or sisbajud.configmap.PLUGIN_AUTH_ENABLED=\"true\")") -}}
{{- end -}}
{{- end -}}

{{- /* --- notice transport --------------------------------------------------- */ -}}
{{- $transport := include "plugin-br-sisbajud.transport" . -}}
{{- if eq $mode "direct" -}}
{{- /* DIRECT-only: no intake transport is read (no Hub webhook, no SQS). */ -}}
{{- else if eq $transport "webhook" -}}
{{- if not (include "plugin-br-sisbajud.provided" (dict "context" $ "key" "EXECUTOR_HUB_WEBHOOK_SECRET")) -}}
{{- include $f (dict "msg" "EXECUTOR_HUB_WEBHOOK_SECRET is required with EXECUTOR_TRANSPORT=webhook (the Streaming Hub subscription signing secret)." "set" "sisbajud.secrets.EXECUTOR_HUB_WEBHOOK_SECRET (or sisbajud.useExistingSecret)") -}}
{{- end -}}
{{- $mode := include $val (dict "cm" $cm "k" "DEPLOYMENT_MODE" "p" $s.app "f" "deploymentMode" "d" "byoc") | trim | lower -}}
{{- $upstream := eq (include "plugin-br-sisbajud.isTrue" (include $val (dict "cm" $cm "k" "EXECUTOR_HUB_WEBHOOK_UPSTREAM_TLS_VALIDATED" "p" $wh "f" "upstreamTlsValidated" "d" "false"))) "true" -}}
{{- $ownTls := or (($wh.tls | default dict).existingSecret) (index $cm "EXECUTOR_HUB_WEBHOOK_TLS_CERT_FILE") -}}
{{- if and (ne $mode "local") (not $ownTls) (not $upstream) -}}
{{- include $f (dict "msg" (printf "DEPLOYMENT_MODE=%s: the webhook listener needs its own TLS pair or TLS terminated (and validated) in front of it." $mode) "set" "sisbajud.executor.webhook.tls.existingSecret, or sisbajud.executor.webhook.upstreamTlsValidated=true") -}}
{{- end -}}
{{- else if eq $transport "sqs" -}}
{{- range $row := list (list "queueUrl" "EXECUTOR_SQS_QUEUE_URL") (list "region" "EXECUTOR_SQS_REGION") -}}
{{- if not (include $val (dict "cm" $cm "k" (index $row 1) "p" ($ex.sqs | default dict) "f" (index $row 0) "d" "")) -}}
{{- include $f (dict "msg" (printf "%s is required with EXECUTOR_TRANSPORT=sqs." (index $row 1)) "set" (printf "sisbajud.executor.sqs.%s" (index $row 0))) -}}
{{- end -}}
{{- end -}}
{{- else -}}
{{- include $f (dict "msg" (printf "EXECUTOR_TRANSPORT must be webhook or sqs, got %q." $transport) "set" "sisbajud.executor.transport") -}}
{{- end -}}

{{- /* --- KMS (no in-memory provider: the app refuses to boot without one) ---- */ -}}
{{- $kms := include "plugin-br-sisbajud.kmsProvider" . -}}
{{- $kmsDed := $s.kms | default dict -}}
{{- if eq $kms "vault" -}}
{{- $addr := include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "vaultAddr" "nativeKey" "VAULT_ADDR" "default" "") -}}
{{- if not $addr -}}
{{- include $f (dict "msg" "VAULT_ADDR is required with KMS_PROVIDER=vault." "set" "global.kms.vaultAddr (or sisbajud.kms.vaultAddr)") -}}
{{- end -}}
{{- $plainOk := eq (include "plugin-br-sisbajud.plaintextSecretTransport" .) "true" -}}
{{- $loopback := regexMatch "^(?i)http://(localhost|127\\.[0-9.]+|\\[::1\\])(:[0-9]+)?(/.*)?$" $addr -}}
{{- if and (not $plainOk) (not $loopback) (not (include "plugin-br-sisbajud.isAvpPlaceholder" $addr)) (not (hasPrefix "https://" (lower $addr))) -}}
{{- include $f (dict "msg" (printf "VAULT_ADDR must be https (http only for a loopback host or ENVIRONMENT_NAME local|development|test), got %q." $addr) "set" "global.kms.vaultAddr") -}}
{{- end -}}
{{- $method := include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "vaultAuthMethod" "nativeKey" "VAULT_AUTH_METHOD" "default" "token") | lower -}}
{{- if eq $method "approle" -}}
{{- if not (include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "vaultRoleId" "nativeKey" "VAULT_APPROLE_ROLE_ID" "default" "")) -}}
{{- include $f (dict "msg" "VAULT_APPROLE_ROLE_ID is required with VAULT_AUTH_METHOD=approle." "set" "global.kms.vaultRoleId (or sisbajud.kms.vaultRoleId)") -}}
{{- end -}}
{{- if not (include "plugin-br-sisbajud.provided" (dict "context" $ "key" "VAULT_APPROLE_SECRET_ID")) -}}
{{- include $f (dict "msg" "VAULT_APPROLE_SECRET_ID is required with VAULT_AUTH_METHOD=approle." "set" "sisbajud.secrets.VAULT_APPROLE_SECRET_ID (or sisbajud.useExistingSecret)") -}}
{{- end -}}
{{- else if eq $method "token" -}}
{{- if not (include "plugin-br-sisbajud.provided" (dict "context" $ "key" "VAULT_TOKEN")) -}}
{{- include $f (dict "msg" "VAULT_TOKEN is required with VAULT_AUTH_METHOD=token." "set" "sisbajud.secrets.VAULT_TOKEN (or use approle / sisbajud.useExistingSecret)") -}}
{{- end -}}
{{- else -}}
{{- include $f (dict "msg" (printf "VAULT_AUTH_METHOD must be token or approle, got %q." $method) "set" "global.kms.vaultAuthMethod") -}}
{{- end -}}
{{- else if eq $kms "aws" -}}
{{- if not (include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "awsRegion" "nativeKey" "AWS_REGION" "default" "")) -}}
{{- include $f (dict "msg" "AWS_REGION is required with KMS_PROVIDER=aws." "set" "global.kms.awsRegion (or sisbajud.kms.awsRegion)") -}}
{{- end -}}
{{- /* The app refuses aws with multi-tenant (validateAWSKMSDeployment). Checked
   right after AWS_REGION so the key-mode gates below never pre-empt it; the
   resolved flag covers global.multiTenant.enabled and sisbajud.configmap.MULTI_TENANT_ENABLED. */ -}}
{{- if eq (include "plugin-br-sisbajud.multiTenantEnabled" .) "true" -}}
{{- include $f (dict "msg" "KMS_PROVIDER=aws is single-tenant (BYOC) only; the app refuses it with MULTI_TENANT_ENABLED=true." "set" "global.multiTenant.enabled=false (or KMS_PROVIDER=vault)") -}}
{{- end -}}
{{- $awsMode := include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "awsKeyMode" "nativeKey" "KMS_AWS_KEY_MODE" "default" "") | trim -}}
{{- if not (has $awsMode (list "managed" "provided")) -}}
{{- include $f (dict "msg" (printf "KMS_PROVIDER=aws now requires KMS_AWS_KEY_MODE (managed | provided), got %q." $awsMode) "set" "sisbajud.kms.awsKeyMode (or global.kms.awsKeyMode)") -}}
{{- end -}}
{{- $awsKeyArn := include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "awsKeyArn" "nativeKey" "KMS_AWS_KEY_ARN" "default" "") | trim -}}
{{- $awsCredArn := include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "awsCredentialsKeyArn" "nativeKey" "KMS_AWS_CREDENTIALS_KEY_ARN" "default" "") | trim -}}
{{- if eq $awsMode "provided" -}}
{{- if not $awsKeyArn -}}
{{- include $f (dict "msg" "KMS_AWS_KEY_ARN is required when KMS_AWS_KEY_MODE=provided." "set" "sisbajud.kms.awsKeyArn (or global.kms.awsKeyArn)") -}}
{{- end -}}
{{- if not $awsCredArn -}}
{{- include $f (dict "msg" "KMS_AWS_CREDENTIALS_KEY_ARN is required when KMS_AWS_KEY_MODE=provided." "set" "sisbajud.kms.awsCredentialsKeyArn (or global.kms.awsCredentialsKeyArn)") -}}
{{- end -}}
{{- if eq $awsKeyArn $awsCredArn -}}
{{- include $f (dict "msg" "KMS_AWS_KEY_ARN and KMS_AWS_CREDENTIALS_KEY_ARN must name distinct keys." "set" "sisbajud.kms.awsKeyArn / sisbajud.kms.awsCredentialsKeyArn") -}}
{{- end -}}
{{- else -}}
{{- if $awsKeyArn -}}
{{- include $f (dict "msg" "KMS_AWS_KEY_ARN must be empty when KMS_AWS_KEY_MODE=managed (the app creates and owns the key)." "set" "unset sisbajud.kms.awsKeyArn and global.kms.awsKeyArn, or sisbajud.kms.awsKeyMode=provided") -}}
{{- end -}}
{{- if $awsCredArn -}}
{{- include $f (dict "msg" "KMS_AWS_CREDENTIALS_KEY_ARN must be empty when KMS_AWS_KEY_MODE=managed (the app creates and owns the key)." "set" "unset sisbajud.kms.awsCredentialsKeyArn and global.kms.awsCredentialsKeyArn, or sisbajud.kms.awsKeyMode=provided") -}}
{{- end -}}
{{- end -}}
{{- /* Timeout and rotation interval are validated in EVERY aws mode: the plugin app
   parses both always (applyAWSTimeout / applyAWSRotationCheckInterval) — the
   opposite of br-sisbajud, which reads the interval only in provided mode. */ -}}
{{- range $row := list (list "KMS_AWS_TIMEOUT_SEC" "awsKmsTimeoutSec" 600) (list "KMS_AWS_ROTATION_CHECK_INTERVAL_SEC" "awsKmsRotationCheckIntervalSec" 86400) -}}
{{- $raw := include $val (dict "cm" $cm "k" (index $row 0) "p" ($s.vault | default dict) "f" (index $row 1) "d" "") | trim -}}
{{- if and $raw (or (not (regexMatch "^[0-9]+$" $raw)) (lt (atoi $raw) 1) (gt (atoi $raw) (index $row 2))) -}}
{{- include $f (dict "msg" (printf "%s must be a whole number of seconds between 1 and %d, got %q." (index $row 0) (index $row 2) $raw) "set" (printf "sisbajud.vault.%s" (index $row 1))) -}}
{{- end -}}
{{- end -}}
{{- /* Image-tag gate: images before 1.1.0-beta.1 ignore KMS_AWS_KEY_MODE /
   KMS_AWS_KEY_ARN and create their own KMS key, silently. Same effective tag as
   plugin-br-sisbajud.image:
   - a tag is verifiable ONLY in the canonical form
     ^v?MAJOR.MINOR.PATCH(-(alpha|beta|rc).N)?$ (no "@", no leading zeros: SemVer
     2.0.0 forbids leading zeros, so it is unverifiable, not lower). Such a tag is compared with
     $min (the acknowledgement is NOT consulted): below it fails even with the flag.
   - everything else FAILS CLOSED unless acknowledged, and with the
     acknowledgement no version check is made: "@" (tag@digest or digest-only; the
     kubelet pulls by digest, so the label may lie), other suffixes (-amd64, beta1,
     -beta.1-amd64), build metadata (+x), non-SemVer (latest, mirror tags).
   The acknowledgement is sisbajud.kms.allowUnverifiableImageTag only:
   global.kms.allowUnverifiableImageTag is intentionally ignored because the minimum
   tag differs per chart. */ -}}
{{- $rawTag := $.Values.sisbajud.image.tag | default $.Chart.AppVersion | toString -}}
{{- $min := "1.1.0-beta.1" -}}
{{- $ackTag := eq (toString (($s.kms | default dict).allowUnverifiableImageTag)) "true" -}}
{{- if regexMatch "^v?(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-(alpha|beta|rc)\\.(0|[1-9][0-9]*))?$" $rawTag -}}
{{- if semverCompare (printf "<%s" $min) (trimPrefix "v" $rawTag) -}}
{{- include $f (dict "msg" (printf "image tag %q with KMS_PROVIDER=aws ignores KMS_AWS_KEY_MODE/KMS_AWS_KEY_ARN and creates its own KMS key." $rawTag) "set" (printf "sisbajud.image.tag >= %s" $min)) -}}
{{- end -}}
{{- else if not $ackTag -}}
{{- include $f (dict "msg" (printf "image tag %q is not in the canonical form vX.Y.Z[-(alpha|beta|rc).N] (digest pins, arch suffixes, build metadata and non-SemVer tags are refused), so the chart cannot verify it is >= %s (older images with KMS_PROVIDER=aws ignore KMS_AWS_KEY_MODE/KMS_AWS_KEY_ARN and create their own KMS key)." $rawTag $min) "set" (printf "a canonical sisbajud.image.tag >= %s, or sisbajud.kms.allowUnverifiableImageTag: true to acknowledge the image is >= %s" $min $min)) -}}
{{- end -}}
{{- else -}}
{{- include $f (dict "msg" (printf "KMS_PROVIDER must be vault or aws (the app has no in-memory provider), got %q." $kms) "set" "global.kms.vendor=hashicorp-vault|aws") -}}
{{- end -}}

{{- /* --- PostgreSQL / Redis --------------------------------------------------- */ -}}
{{- $pg := include "plugin-br-sisbajud.postgres" . | fromYaml -}}
{{- if not $pg.host -}}
{{- include $f (dict "msg" "POSTGRES_HOST is required (external PostgreSQL), or enable the bundled postgresql (development only)." "set" "global.datastores.postgres.host (or sisbajud.datastores.postgres.host)") -}}
{{- end -}}
{{- if eq (include "plugin-br-sisbajud.postgresBundled" .) "true" -}}
{{- if not $nonProd -}}
{{- include $f (dict "msg" "the bundled postgresql is development-only (plaintext, POSTGRES_SSLMODE=disable is refused by the app in a production-like environment)." "set" "sisbajud.app.environmentName=development, or postgresql.enabled=false with an external PostgreSQL") -}}
{{- end -}}
{{- else -}}
{{- if and (not $nonProd) (eq (lower $pg.ssl) "disable") -}}
{{- include $f (dict "msg" "POSTGRES_SSLMODE=disable is refused by the app in a production-like environment." "set" "global.datastores.postgres.ssl=require (or verify-full)") -}}
{{- end -}}
{{- if and (not $nonProd) (ne (include "plugin-br-sisbajud.postgresPasswordFromRef" .) "true") (not (include "plugin-br-sisbajud.provided" (dict "context" $ "key" "POSTGRES_PASSWORD"))) -}}
{{- include $f (dict "msg" "POSTGRES_PASSWORD is required in a production-like environment." "set" "sisbajud.secrets.POSTGRES_PASSWORD (or postgresql.auth.existingSecret / sisbajud.useExistingSecret)") -}}
{{- end -}}
{{- end -}}
{{- if not (include "plugin-br-sisbajud.redisHost" .) -}}
{{- include $f (dict "msg" "REDIS_HOST is required (readiness is down without Redis/Valkey), or enable the bundled valkey (development only)." "set" "global.datastores.redis.host (or sisbajud.datastores.redis.host)") -}}
{{- end -}}
{{- end -}}

{{/*
validateMidazConnection — the Midaz connection from the environment (v2.0.0;
the app's validateConnectorEnvConnection and its executor-mode requirement).
Multi-tenant: every MIDAZ_* connection key is refused (each institution keeps
its own connection). Single-tenant executor: MIDAZ_BASE_URL, MIDAZ_AUTH_ADDRESS
and the ledger client pair are required, and the CRM pair too with
MIDAZ_CRM_MODE=legacy; in either mode the CRM pair needs MIDAZ_CRM_BASE_URL,
and with auth on that URL needs the pair (a row may override legacy); the URLs are https (http only outside production), and
each client pair is whole. A refusal names the key, never the value. An external
Secret (useExistingSecret) is opaque: its keys are trusted.
*/}}
{{- define "plugin-br-sisbajud.validateMidazConnection" -}}
{{- $s := .Values.sisbajud -}}
{{- $cm := $s.configmap | default dict -}}
{{- $f := "plugin-br-sisbajud.fail" -}}
{{- $val := "plugin-br-sisbajud.val" -}}
{{- $midaz := $s.midaz | default dict -}}
{{- $base := include $val (dict "cm" $cm "k" "MIDAZ_BASE_URL" "p" $midaz "f" "baseUrl" "d" "") | trim -}}
{{- $authAddr := include $val (dict "cm" $cm "k" "MIDAZ_AUTH_ADDRESS" "p" $midaz "f" "authAddress" "d" "") | trim -}}
{{- $crmBase := include $val (dict "cm" $cm "k" "MIDAZ_CRM_BASE_URL" "p" $midaz "f" "crmBaseUrl" "d" "") | trim -}}
{{- $urlField := dict "MIDAZ_BASE_URL" "baseUrl" "MIDAZ_AUTH_ADDRESS" "authAddress" "MIDAZ_CRM_BASE_URL" "crmBaseUrl" -}}
{{- $pairs := list (list "MIDAZ_LEDGER_CLIENT_ID" "MIDAZ_LEDGER_CLIENT_SECRET") (list "MIDAZ_CRM_CLIENT_ID" "MIDAZ_CRM_CLIENT_SECRET") -}}
{{- if eq (include "plugin-br-sisbajud.multiTenantEnabled" .) "true" -}}
{{- $sec := $s.secrets | default dict -}}
{{- $extra := $s.extraEnvVars | default dict -}}
{{- range $k, $v := dict "MIDAZ_BASE_URL" $base "MIDAZ_AUTH_ADDRESS" $authAddr "MIDAZ_CRM_BASE_URL" $crmBase -}}
{{- if $v -}}
{{- include $f (dict "msg" (printf "%s is single-tenant only: with multi-tenant on, each institution keeps its own Midaz connection." $k) "set" (printf "remove sisbajud.midaz.%s" (index $urlField $k))) -}}
{{- end -}}
{{- end -}}
{{- range $pair := $pairs -}}
{{- range $k := $pair -}}
{{- if or (hasKey $extra $k) (ne (toString (index $sec $k | default "")) "") -}}
{{- include $f (dict "msg" (printf "%s is single-tenant only: with multi-tenant on, each institution keeps its own Midaz credentials." $k) "set" (printf "remove sisbajud.secrets.%s" $k)) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- else -}}
{{- $insecureOK := eq (include "plugin-br-sisbajud.nonProduction" .) "true" -}}
{{- if not $base -}}
{{- include $f (dict "msg" "MIDAZ_BASE_URL is required in single-tenant (v2.0.0): the Midaz connection comes from the environment." "set" "sisbajud.midaz.baseUrl=https://<host>") -}}
{{- end -}}
{{- range $k, $v := dict "MIDAZ_BASE_URL" $base "MIDAZ_AUTH_ADDRESS" $authAddr "MIDAZ_CRM_BASE_URL" $crmBase -}}
{{- $loopback := regexMatch "^(?i)http://(localhost|127\\.[0-9.]+|\\[::1\\])(:[0-9]+)?(/.*)?$" $v -}}
{{- if and $v (not (or (include "plugin-br-sisbajud.isAvpPlaceholder" $v) (regexMatch "^(?i)https://[^/?#]+" $v) $loopback (and $insecureOK (regexMatch "^(?i)http://[^/?#]+" $v)))) -}}
{{- include $f (dict "msg" (printf "%s must be an absolute https URL with a host (http only to a loopback host, or outside production)." $k) "set" (printf "sisbajud.midaz.%s" (index $urlField $k))) -}}
{{- end -}}
{{- end -}}
{{- /* The auth group (MIDAZ_AUTH_ADDRESS + the ledger client pair) is optional and
   all-or-nothing: Midaz without auth needs none of it. A key counts as set when
   it is inline (secrets or extraEnvVars); an existing Secret is opaque, so there
   the group is decided by MIDAZ_AUTH_ADDRESS and the Secret is trusted. */ -}}
{{- $sec := $s.secrets | default dict -}}
{{- $extra := $s.extraEnvVars | default dict -}}
{{- $inline := dict -}}
{{- range $pair := $pairs -}}
{{- range $k := $pair -}}
{{- $_ := set $inline $k (or (hasKey $extra $k) (ne (toString (index $sec $k | default "")) "")) -}}
{{- end -}}
{{- end -}}
{{- $group := or (ne $authAddr "") (index $inline "MIDAZ_LEDGER_CLIENT_ID") (index $inline "MIDAZ_LEDGER_CLIENT_SECRET") -}}
{{- if $group -}}
{{- $missing := list -}}
{{- if not $authAddr -}}{{- $missing = append $missing "MIDAZ_AUTH_ADDRESS (sisbajud.midaz.authAddress)" -}}{{- end -}}
{{- range $k := index $pairs 0 -}}
{{- if not (include "plugin-br-sisbajud.provided" (dict "context" $ "key" $k)) -}}{{- $missing = append $missing (printf "%s (sisbajud.secrets.%s)" $k $k) -}}{{- end -}}
{{- end -}}
{{- if $missing -}}
{{- include $f (dict "msg" "MIDAZ_AUTH_ADDRESS, MIDAZ_LEDGER_CLIENT_ID and MIDAZ_LEDGER_CLIENT_SECRET are set together or not at all (the Midaz auth group)." "set" (join ", " $missing)) -}}
{{- end -}}
{{- end -}}
{{- $legacy := eq (include $val (dict "cm" $cm "k" "MIDAZ_CRM_MODE" "p" $midaz "f" "crmMode" "d" "embedded") | trim) "legacy" -}}
{{- $crm := index $pairs 1 -}}
{{- $crmID := index $inline (index $crm 0) -}}
{{- if ne $crmID (index $inline (index $crm 1)) -}}
{{- include $f (dict "msg" "MIDAZ_CRM_CLIENT_ID and MIDAZ_CRM_CLIENT_SECRET must be set together." "set" "sisbajud.secrets.MIDAZ_CRM_CLIENT_ID and sisbajud.secrets.MIDAZ_CRM_CLIENT_SECRET") -}}
{{- end -}}
{{- if and $crmID (not $authAddr) -}}
{{- include $f (dict "msg" "MIDAZ_CRM_CLIENT_ID requires MIDAZ_AUTH_ADDRESS." "set" "sisbajud.midaz.authAddress") -}}
{{- end -}}
{{- /* A row may override crmMode=legacy under the embedded default, so the CRM
   URL and pair are valid in either mode. An existing Secret is opaque: there
   the auth group stands for the pair. */ -}}
{{- if and $group $crmBase (not (include "plugin-br-sisbajud.provided" (dict "context" $ "key" (index $crm 0)))) -}}
{{- include $f (dict "msg" "MIDAZ_CRM_BASE_URL requires MIDAZ_CRM_CLIENT_ID and MIDAZ_CRM_CLIENT_SECRET when the Midaz auth group is set." "set" "sisbajud.secrets.MIDAZ_CRM_CLIENT_ID and sisbajud.secrets.MIDAZ_CRM_CLIENT_SECRET (or useExistingSecret with both keys)") -}}
{{- end -}}
{{- if and (not $crmBase) (or $crmID (and $legacy $group)) -}}
{{- include $f (dict "msg" "MIDAZ_CRM_CLIENT_ID and MIDAZ_CRM_CLIENT_SECRET require MIDAZ_CRM_BASE_URL: the CRM bearer only goes to the configured CRM." "set" "sisbajud.midaz.crmBaseUrl=https://<crm-host>") -}}
{{- end -}}
{{- if and $group $legacy (not (include "plugin-br-sisbajud.provided" (dict "context" $ "key" (index $crm 0)))) -}}
{{- include $f (dict "msg" "MIDAZ_CRM_CLIENT_ID and MIDAZ_CRM_CLIENT_SECRET are required with MIDAZ_CRM_MODE=legacy when the Midaz auth group is set." "set" "sisbajud.secrets.MIDAZ_CRM_CLIENT_ID and sisbajud.secrets.MIDAZ_CRM_CLIENT_SECRET (or useExistingSecret with both keys)") -}}
{{- end -}}
{{- end -}}
{{- end -}}
