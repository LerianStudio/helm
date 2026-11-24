{{/*
br-ccs boot contract.

The app (br-sfn services/ccs, 1.1.x) refuses to boot on a set of values that
`helm lint` and `helm template` used to accept: the operator only found out
when the pod crash-looped, one variable at a time. Each check below mirrors one
boot refusal of the app, so the same mistake now fails at render time with the
variable to fix. App references are to services/ccs/internal/bootstrap at the
ccs-v1.1.2 tag.

Values are read the way templates/configmap.yaml renders them: a key in
brCcs.extraEnvVars wins, then brCcs.configmap, then the chart default.
Secret keys are refused in brCcs.extraEnvVars: it renders into the ConfigMap.
With brCcs.useExistingSecret the Secret is not visible here, so the checks on
secret values are skipped and the app stays the last gate for them.
*/}}

{{/* br-ccs.envValue — effective value of one env key (extraEnvVars > configmap > default). */}}
{{- define "br-ccs.envValue" -}}
{{- $extra := .context.Values.brCcs.extraEnvVars | default dict -}}
{{- $cm := .context.Values.brCcs.configmap | default dict -}}
{{- if hasKey $extra .key -}}
{{- $v := index $extra .key -}}{{- if not (kindIs "invalid" $v) -}}{{- toString $v | trim -}}{{- end -}}
{{- else if and (hasKey $cm .key) (not (kindIs "invalid" (index $cm .key))) (ne (toString (index $cm .key)) "") -}}
{{- toString (index $cm .key) | trim -}}
{{- else -}}
{{- toString (.default | default "") | trim -}}
{{- end -}}
{{- end -}}

{{/* br-ccs.cmValue — one brCcs.configmap key as the ConfigMap renders it: a
     present value as a string, a YAML boolean false included; "" when unset. */}}
{{- define "br-ccs.cmValue" -}}
{{- $cm := .context.Values.brCcs.configmap | default dict -}}
{{- if and (hasKey $cm .key) (not (kindIs "invalid" (index $cm .key))) -}}
{{- toString (index $cm .key) -}}
{{- end -}}
{{- end -}}

{{/* br-ccs.secretValue — effective value of one key the app reads from the Secret.
     A non-secret key (a client id) may come from extraEnvVars; a secret key in
     extraEnvVars is refused by check 0. */}}
{{- define "br-ccs.secretValue" -}}
{{- $extra := .context.Values.brCcs.extraEnvVars | default dict -}}
{{- $s := .context.Values.brCcs.secrets | default dict -}}
{{- if hasKey $extra .key -}}
{{- $v := index $extra .key -}}{{- if not (kindIs "invalid" $v) -}}{{- toString $v | trim -}}{{- end -}}
{{- else -}}
{{- toString (index $s .key | default "") | trim -}}
{{- end -}}
{{- end -}}

{{/* br-ccs.valkeyBundled — "true" when the bundled valkey subchart serves Redis:
     the subchart is on and REDIS_HOST is empty or exactly its Service name.
     Any other REDIS_HOST (configmap, datastores, global, extraEnvVars) is
     external Redis, even with the subchart left on. */}}
{{- define "br-ccs.valkeyBundled" -}}
{{- $vk := .Values.valkey | default dict -}}
{{- if and (ne (toString $vk.enabled) "false") (not $vk.external) -}}
{{- $defaultHost := include "br-ccs.valkey.defaultHost" . -}}
{{- $host := include "lerian-common.datastore.value" (dict "context" . "dedicated" (.Values.brCcs.datastores | default dict) "configmap" (.Values.brCcs.configmap | default dict) "type" "redis" "field" "host" "nativeKey" "REDIS_HOST" "default" $defaultHost) -}}
{{- $extra := .Values.brCcs.extraEnvVars | default dict -}}
{{- if hasKey $extra "REDIS_HOST" -}}{{- $host = toString (index $extra "REDIS_HOST") -}}{{- end -}}
{{- if has (trim $host) (list "" $defaultHost) -}}true{{- end -}}
{{- end -}}
{{- end -}}

{{/* br-ccs.redisInsecureAllowed — "true" when the operator set a plaintext Redis
     bypass the app honours (lib-commons commons/security.go: ALLOW_INSECURE_REDIS
     or ALLOW_INSECURE_TLS, trimmed, case-insensitive, true/1/yes/on). */}}
{{- define "br-ccs.redisInsecureAllowed" -}}
{{- $ctx := . -}}
{{- range $k := list "ALLOW_INSECURE_REDIS" "ALLOW_INSECURE_TLS" -}}
{{- if has (lower (include "br-ccs.envValue" (dict "context" $ctx "key" $k))) (list "1" "true" "yes" "on") -}}true{{- end -}}
{{- end -}}
{{- end -}}

{{/* br-ccs.redisTLSDefault — the REDIS_TLS the chart renders when the operator
     leaves it unset: "false" with the bundled valkey subchart (it serves no TLS);
     for external Redis, "false" when a plaintext bypass is set (an install that
     booted on plaintext Redis before REDIS_TLS was rendered keeps booting),
     "true" otherwise. */}}
{{- define "br-ccs.redisTLSDefault" -}}
{{- if or (include "br-ccs.valkeyBundled" .) (include "br-ccs.redisInsecureAllowed" .) -}}false{{- else -}}true{{- end -}}
{{- end -}}

{{- define "br-ccs.validateBootContract" -}}
{{- $ctx := . -}}
{{- $useExisting := .Values.brCcs.useExistingSecret -}}
{{- $devNames := list "development" "develop" "dev" "local" "test" -}}
{{- $envRaw := include "br-ccs.envValue" (dict "context" $ctx "key" "ENV_NAME" "default" "production") -}}
{{- $envName := lower $envRaw -}}
{{- $isDev := has $envName $devNames -}}
{{- /* ENV_NAME feeds the logger (shared/envclass LoggerEnvironment): a
       development-class name in any case (local included), otherwise one of
       the zap profiles lib-observability accepts, byte-exact. "homolog" or "Production" render
       fine and the boot fails with "invalid environment". */ -}}
{{- if not (or $isDev (has $envRaw (list "production" "staging" "uat"))) -}}
{{- fail (printf "br-ccs: ENV_NAME=%q is not accepted by the app logger. Use production, staging or uat (lowercase), or a development name (development, develop, dev, local, test)." $envRaw) -}}
{{- end -}}
{{- $isProd := eq $envName "production" -}}
{{- $isSaaS := eq (lower (include "br-ccs.envValue" (dict "context" $ctx "key" "DEPLOYMENT_MODE" "default" "byoc"))) "saas" -}}
{{- $extra := .Values.brCcs.extraEnvVars | default dict -}}
{{- $cm := .Values.brCcs.configmap | default dict -}}

{{- /* 0. Secret keys belong in brCcs.secrets: every brCcs.extraEnvVars entry is
       rendered into the ConfigMap, in plaintext for anyone who reads it. Checked
       with useExistingSecret too. The list is every credential the Secret
       renders (templates/secrets.yaml and the lerian-common streaming and
       multi-tenant blocks it includes): passwords, keys, tokens, client
       secrets. Ids, access-key ids and CA certificates are not credentials. */ -}}
{{- $secretKeys := list "LICENSE_KEY" "CCS_CRYPTO_MASTER_KEY" "FETCHER_CRYPTO_KEY" "POSTGRES_PASSWORD" "POSTGRES_REPLICA_PASSWORD" "REDIS_PASSWORD" "MULTI_TENANT_REDIS_PASSWORD" "STREAMING_SASL_PASSWORD" "STA_EVENT_HMAC_MASTER_KEYS" "SD_TOKEN" "MULTI_TENANT_SERVICE_API_KEY" "OBJECT_STORAGE_STA_SECRET_KEY" "OBJECT_STORAGE_CCS_SECRET_KEY" "OBJECT_STORAGE_FETCHER_SECRET_KEY" "FETCHER_API_KEY" "REPORTER_API_KEY" "STA_API_KEY" "FETCHER_CLIENT_SECRET" "REPORTER_CLIENT_SECRET" "STA_CLIENT_SECRET" "CRM_CLIENT_SECRET" "IDP_M2M_CLIENT_SECRET" -}}
{{- range $k := $secretKeys -}}
{{- if hasKey $extra $k -}}
{{- fail (printf "br-ccs: %s is a secret: set it in brCcs.secrets, not brCcs.extraEnvVars (extraEnvVars renders into the ConfigMap in plaintext)." $k) -}}
{{- end -}}
{{- end -}}

{{- /* 0b. Booleans the app parses strictly (lib-commons v7.26.0 commons/os.go
        parseEnvBool): exactly "true" or "false" after trimming, so "1", "t",
        "TRUE" or "yes" render fine and are refused at boot. Empty keeps the
        chart or app default. */ -}}
{{- range $b := list (dict "key" "REDIS_TLS" "default" (include "br-ccs.redisTLSDefault" $ctx)) (dict "key" "OUTBOX_ENABLED" "default" "true") (dict "key" "CIRCUIT_BREAKER_ENABLED" "default" "true") (dict "key" "CCS_DETAIL_MESSAGE_EMIT_ENABLED" "default" "") -}}
{{- $v := include "br-ccs.envValue" (dict "context" $ctx "key" $b.key "default" $b.default) -}}
{{- if and $v (not (has $v (list "true" "false"))) -}}
{{- fail (printf "br-ccs: %s must be exactly \"true\" or \"false\" (the app refuses any other spelling at boot); got %q." $b.key $v) -}}
{{- end -}}
{{- end -}}

{{- /* 1. Inbound auth switch (shared/envclass ResolveAuthSwitch, config.go:957).
       Exactly "true" or "false"; "false" only in a development-class ENV_NAME
       outside DEPLOYMENT_MODE=saas. */ -}}
{{- $auth := "" -}}
{{- if hasKey $extra "PLUGIN_AUTH_ENABLED" -}}
{{- $auth = toString (index $extra "PLUGIN_AUTH_ENABLED") | trim -}}
{{- else -}}
{{- $auth = include "lerian-common.globalValue" (dict "context" $ctx "configmap" $cm "block" "auth" "field" "enabled" "nativeKey" "PLUGIN_AUTH_ENABLED" "default" "true") | trim -}}
{{- end -}}
{{- if not (has $auth (list "true" "false")) -}}
{{- fail (printf "br-ccs: PLUGIN_AUTH_ENABLED must be exactly \"true\" or \"false\" (got %q). Set brCcs.configmap.PLUGIN_AUTH_ENABLED or global.auth.enabled." $auth) -}}
{{- end -}}
{{- if and (eq $auth "false") (or (not $isDev) $isSaaS) -}}
{{- fail (printf "br-ccs: PLUGIN_AUTH_ENABLED=false is only accepted with a development ENV_NAME (development, develop, dev, local, test) outside DEPLOYMENT_MODE=saas; got ENV_NAME=%q. Set PLUGIN_AUTH_ENABLED=\"true\" and PLUGIN_AUTH_HOST." $envName) -}}
{{- end -}}

{{- /* 2. With auth on: PLUGIN_AUTH_HOST and the Reporter and STA M2M pairs, even
       with STA_ENABLED=false (config_validation.go:234-318). */ -}}
{{- if eq $auth "true" -}}
{{- $authHost := "" -}}
{{- if hasKey $extra "PLUGIN_AUTH_HOST" -}}
{{- $authHost = toString (index $extra "PLUGIN_AUTH_HOST") | trim -}}
{{- else -}}
{{- $authHost = include "lerian-common.globalValue" (dict "context" $ctx "configmap" $cm "block" "auth" "field" "host" "nativeKey" "PLUGIN_AUTH_HOST" "default" "") | trim -}}
{{- end -}}
{{- if not $authHost -}}
{{- fail "br-ccs: PLUGIN_AUTH_HOST is required when PLUGIN_AUTH_ENABLED=true. Set brCcs.configmap.PLUGIN_AUTH_HOST or global.auth.host (the plugin-access-manager URL)." -}}
{{- end -}}
{{- if not $useExisting -}}
{{- range $k := list "REPORTER_CLIENT_ID" "REPORTER_CLIENT_SECRET" "STA_CLIENT_ID" "STA_CLIENT_SECRET" -}}
{{- if not (include "br-ccs.secretValue" (dict "context" $ctx "key" $k)) -}}
{{- fail (printf "br-ccs: brCcs.secrets.%s is required when PLUGIN_AUTH_ENABLED=true (the app requires the Reporter and STA M2M credentials even with STA_ENABLED=false)." $k) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- /* 3. Object-storage encryption: a bound bucket needs an explicit SSE posture
       (config_storage_encryption.go:148-200). The chart always binds both
       buckets (default names), so both need it. */ -}}
{{- range $b := list (dict "prefix" "OBJECT_STORAGE_STA" "bucket" "sta-files") (dict "prefix" "OBJECT_STORAGE_CCS" "bucket" "lerian-ccs") -}}
{{- $bucket := include "br-ccs.envValue" (dict "context" $ctx "key" (printf "%s_BUCKET" $b.prefix) "default" $b.bucket) -}}
{{- if $bucket -}}
{{- $algVar := printf "%s_SSE_ALGORITHM" $b.prefix -}}
{{- $alg := lower (include "br-ccs.envValue" (dict "context" $ctx "key" $algVar)) -}}
{{- if not $alg -}}
{{- fail (printf "br-ccs: brCcs.configmap.%s is required (bucket %q is bound). Accepted values: AES256 (recommended), aws:kms (with %s_SSE_KMS_KEY_ID), none (development only)." $algVar $bucket $b.prefix) -}}
{{- end -}}
{{- if not (has $alg (list "aes256" "aws:kms" "none")) -}}
{{- fail (printf "br-ccs: %s=%q is not accepted. Accepted values: AES256, aws:kms, none." $algVar $alg) -}}
{{- end -}}
{{- if and (eq $alg "none") (or (not $isDev) $isSaaS) -}}
{{- fail (printf "br-ccs: %s=none is only accepted with a development ENV_NAME outside DEPLOYMENT_MODE=saas; got ENV_NAME=%q. Use AES256 or aws:kms." $algVar $envName) -}}
{{- end -}}
{{- if and (eq $alg "aws:kms") (not (include "br-ccs.envValue" (dict "context" $ctx "key" (printf "%s_SSE_KMS_KEY_ID" $b.prefix)))) -}}
{{- fail (printf "br-ccs: %s_SSE_KMS_KEY_ID is required when %s=aws:kms." $b.prefix $algVar) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- if not $useExisting -}}
{{- /* 4. License, in every environment (config_validation.go:130-139). The chart
       mounts no license file, so a LICENSE_FILE_PATH set through extraEnvVars
       points at nothing: LICENSE_KEY is the only route it can deliver. */ -}}
{{- if not (include "br-ccs.secretValue" (dict "context" $ctx "key" "LICENSE_KEY")) -}}
{{- fail "br-ccs: brCcs.secrets.LICENSE_KEY is required in every environment (the app refuses to boot without a license)." -}}
{{- end -}}
{{- /* 5. Crypto master key: hex AES-256, 64 chars (factory_crypto.go:70-77).
       The shape check skips an argocd-vault-plugin placeholder (<path:...>):
       the plugin replaces it after the render, and the app sees the key. */ -}}
{{- $masterKey := include "br-ccs.secretValue" (dict "context" $ctx "key" "CCS_CRYPTO_MASTER_KEY") -}}
{{- if not $masterKey -}}
{{- fail "br-ccs: brCcs.secrets.CCS_CRYPTO_MASTER_KEY is required: AES-256 key, 64 hex chars (openssl rand -hex 32)." -}}
{{- end -}}
{{- if and (not (hasPrefix "<path:" $masterKey)) (not (regexMatch "^[0-9a-fA-F]{64}$" $masterKey)) -}}
{{- fail (printf "br-ccs: brCcs.secrets.CCS_CRYPTO_MASTER_KEY must be 64 hex chars (openssl rand -hex 32); got %d chars or a non-hex value." (len $masterKey)) -}}
{{- end -}}
{{- end -}}

{{- /* 6. Production gates (config_validation.go:63-193): TRUSTED_PROXIES and
       CORS_ALLOWED_ORIGINS, both non-empty and without a wildcard. */ -}}
{{- if $isProd -}}
{{- $proxies := list -}}
{{- range $p := splitList "," (include "br-ccs.envValue" (dict "context" $ctx "key" "TRUSTED_PROXIES")) -}}{{- if trim $p -}}{{- $proxies = append $proxies (trim $p) -}}{{- end -}}{{- end -}}
{{- if not $proxies -}}
{{- fail "br-ccs: brCcs.configmap.TRUSTED_PROXIES is required when ENV_NAME=production (comma-separated IPs or CIDRs of the L7 proxies, e.g. 10.0.0.0/8)." -}}
{{- end -}}
{{- if or (has "0.0.0.0/0" $proxies) (has "::/0" $proxies) -}}
{{- fail "br-ccs: TRUSTED_PROXIES must not contain 0.0.0.0/0 or ::/0 when ENV_NAME=production." -}}
{{- end -}}
{{- $origins := list -}}
{{- range $o := splitList "," (include "br-ccs.envValue" (dict "context" $ctx "key" "CORS_ALLOWED_ORIGINS")) -}}{{- if trim $o -}}{{- $origins = append $origins (trim $o) -}}{{- end -}}{{- end -}}
{{- if not $origins -}}
{{- fail "br-ccs: brCcs.configmap.CORS_ALLOWED_ORIGINS is required when ENV_NAME=production (comma-separated origins, e.g. https://console.example.com)." -}}
{{- end -}}
{{- if has "*" $origins -}}
{{- fail "br-ccs: CORS_ALLOWED_ORIGINS must not contain \"*\" when ENV_NAME=production." -}}
{{- end -}}
{{- end -}}

{{- /* 7. Reporter detail templates, an ID or a NAME each: CCS0002, CCS0004 and
       ACCS005 with message emission on (default), ACCS005 alone with it off
       (config_detail_reporter.go:93-132). */ -}}
{{- $emit := include "br-ccs.envValue" (dict "context" $ctx "key" "CCS_DETAIL_MESSAGE_EMIT_ENABLED") -}}
{{- $needed := list "CCS0002" "CCS0004" "ACCS005" -}}
{{- if eq $emit "false" -}}{{- $needed = list "ACCS005" -}}{{- end -}}
{{- range $t := $needed -}}
{{- if and (not (include "br-ccs.envValue" (dict "context" $ctx "key" (printf "REPORTER_TEMPLATE_ID_%s" $t)))) (not (include "br-ccs.envValue" (dict "context" $ctx "key" (printf "REPORTER_TEMPLATE_NAME_%s" $t)))) -}}
{{- fail (printf "br-ccs: brCcs.configmap.REPORTER_TEMPLATE_NAME_%s (or REPORTER_TEMPLATE_ID_%s) is required: the app renders the %s detail answer through the Reporter." $t $t $t) -}}
{{- end -}}
{{- end -}}

{{- /* 8. Redis TLS (lib-commons v7.26.0 commons/redis/redis.go:520-533): plaintext
       only with ALLOW_INSECURE_REDIS or ALLOW_INSECURE_TLS set to a true value.
       The bypass is read as templates/configmap.yaml renders it: the operator's
       ALLOW_INSECURE_REDIS (extraEnvVars, then configmap) when set, otherwise the
       "true" the chart adds for the bundled valkey. */ -}}
{{- $redisTLS := include "br-ccs.envValue" (dict "context" $ctx "key" "REDIS_TLS" "default" (include "br-ccs.redisTLSDefault" $ctx)) -}}
{{- if ne $redisTLS "true" -}}
{{- $allowRedisSet := or (hasKey $extra "ALLOW_INSECURE_REDIS") (include "br-ccs.cmValue" (dict "context" $ctx "key" "ALLOW_INSECURE_REDIS")) -}}
{{- $chartBypass := and (include "br-ccs.valkeyBundled" $ctx) (not $allowRedisSet) -}}
{{- if not (or $chartBypass (include "br-ccs.redisInsecureAllowed" $ctx)) -}}
{{- fail "br-ccs: REDIS_TLS=false needs ALLOW_INSECURE_REDIS=\"true\" (the app refuses plaintext Redis otherwise). Prefer REDIS_TLS=\"true\", with brCcs.secrets.REDIS_CA_CERT (base64 PEM) for a private CA." -}}
{{- end -}}
{{- end -}}

{{- /* 9. CRM: absolute URL, https outside development, and the organization id
       (extensions_crm.go:87-111). */ -}}
{{- $crmURL := include "br-ccs.envValue" (dict "context" $ctx "key" "CRM_URL") -}}
{{- if not (regexMatch "^[A-Za-z][A-Za-z0-9+.-]*://[^/?#]+" $crmURL) -}}
{{- fail "br-ccs: brCcs.configmap.CRM_URL is required: the absolute URL of the Midaz CRM (https outside development)." -}}
{{- end -}}
{{- if and (not $isDev) (not (hasPrefix "https://" (lower $crmURL))) -}}
{{- fail (printf "br-ccs: CRM_URL must use https outside a development ENV_NAME; got ENV_NAME=%q." $envName) -}}
{{- end -}}
{{- if not (include "br-ccs.envValue" (dict "context" $ctx "key" "CRM_ORGANIZATION_ID")) -}}
{{- fail "br-ccs: brCcs.configmap.CRM_ORGANIZATION_ID is required (the Midaz organization the CRM reads)." -}}
{{- end -}}

{{- /* 10. Reporter: the app always dials it and no longer reads REPORTER_ENABLED
        (extensions_reporter.go:445-456); its handler rides the outbox and the
        circuit breaker. */ -}}
{{- if not (include "br-ccs.envValue" (dict "context" $ctx "key" "REPORTER_URL")) -}}
{{- fail "br-ccs: brCcs.configmap.REPORTER_URL is required: the app always dials the Reporter (REPORTER_ENABLED is no longer read)." -}}
{{- end -}}
{{- if ne (include "br-ccs.envValue" (dict "context" $ctx "key" "OUTBOX_ENABLED" "default" "true")) "true" -}}
{{- fail "br-ccs: OUTBOX_ENABLED must be \"true\": the Reporter registers its dispatch handler on the outbox at boot." -}}
{{- end -}}
{{- if ne (include "br-ccs.envValue" (dict "context" $ctx "key" "CIRCUIT_BREAKER_ENABLED" "default" "true")) "true" -}}
{{- fail "br-ccs: CIRCUIT_BREAKER_ENABLED must be \"true\": the Reporter integration refuses to boot without the circuit breaker." -}}
{{- end -}}
{{- end -}}
