{{/*
==============================================================================
lerian-common — Multi-tenant env (lib-commons/multitenancy contract).

Unlike serviceDiscovery/streaming, multi-tenant does NOT have a single flat
common block: across the 8 charts that use it, only 4 vars are universal
(ENABLED, URL, CIRCUIT_BREAKER_THRESHOLD, CIRCUIT_BREAKER_TIMEOUT_SEC) and each
chart emits a different subset of the long tail (redis / pool / cache / etc.).

So this helper centralizes the canonical DEFAULTS and var NAMES, and each chart
opts into the GROUPS it currently emits via flags — reproducing its existing
block exactly (render-equivalent) while removing the duplicated defaults.

Like the other env helpers, it does NOT emit MULTI_TENANT_ENABLED: that stays
inline in the component configmap as the knob (and the gate source). This helper
emits only the gated ConfigMap block. The SECRETS (MULTI_TENANT_SERVICE_API_KEY,
MULTI_TENANT_REDIS_PASSWORD) are emitted into the chart's own Secret by the
companion `lerian-common.multiTenant.secret` helper below (never in the ConfigMap).

plugin-br-payments is intentionally OUT of scope (different contract:
MULTI_TENANCY_ENABLED + range-generated configmap) — keep it inline.

Usage (in a component configmap.yaml, replacing the hand-written gated block;
keep the inline `MULTI_TENANT_ENABLED:` line as the knob):

  {{- include "lerian-common.multiTenant.env" (dict
        "configmap" .Values.fees.configmap
        "enabled" (eq (.Values.fees.configmap.MULTI_TENANT_ENABLED | default "false" | toString) "true")
        "requiredUrl" true "requiredRedisHost" true
        "emitRedis" true "emitPool" true "emitCache" true
        "emitEnvironment" true "emitAllowInsecure" true
      ) | nindent 2 }}

Inputs (dict):
  configmap          (req)  the component's `.configmap` map (override source)
  enabled            (req)  bool — gate; emit the block only when true
  requiredUrl        (opt)  bool — MULTI_TENANT_URL uses `required` vs default ""
  serviceName        (opt)  string — emit MULTI_TENANT_SERVICE_NAME (default = this)
  circuitBreaker     (opt)  bool (default true) — CB_THRESHOLD (5) + CB_TIMEOUT_SEC (30)
  emitRedis          (opt)  bool — REDIS_HOST / REDIS_PORT (6379) / REDIS_TLS
  requiredRedisHost  (opt)  bool — REDIS_HOST uses `required` vs default ""
  redisTlsDefault    (opt)  string — default for REDIS_TLS ("false"; "true" for tracer)
  emitPool           (opt)  bool — MAX_TENANT_POOLS (100) + IDLE_TIMEOUT_SEC (300)
  emitCache          (opt)  bool — TIMEOUT (30) + CACHE_TTL_SEC (120) + CONNECTIONS_CHECK_INTERVAL_SEC (30)
  emitEnvironment    (opt)  bool — MULTI_TENANT_ENVIRONMENT (default "")
  emitAllowInsecure  (opt)  bool — MULTI_TENANT_ALLOW_INSECURE_HTTP (default "false")
==============================================================================
*/}}
{{- define "lerian-common.multiTenant.env" -}}
{{- $c := .configmap | default dict -}}
{{- /* Env-wide defaults from global.multiTenant (tenant-manager URL + its redis are
   environment infra, like global.serviceDiscovery/global.streaming). Component
   .configmap overrides global. Guarded on .context so callers that don't pass it
   still work (global stays empty → identical to the pre-global behavior). */ -}}
{{- $g := dict -}}
{{- with .context }}{{- $g = ((.Values.global | default dict).multiTenant | default dict) -}}{{- end -}}
{{- if .enabled -}}
{{- /* URL: universal. Component overrides global; then required or default "". */ -}}
{{- $url := index $c "MULTI_TENANT_URL" | default $g.url -}}
{{- if .requiredUrl }}
MULTI_TENANT_URL: {{ required "lerian-common: MULTI_TENANT_URL is required when MULTI_TENANT_ENABLED=true (set component configmap.MULTI_TENANT_URL or global.multiTenant.url)" $url | quote }}
{{- else }}
MULTI_TENANT_URL: {{ $url | default "" | quote }}
{{- end }}
{{- if .serviceName }}
MULTI_TENANT_SERVICE_NAME: {{ index $c "MULTI_TENANT_SERVICE_NAME" | default .serviceName | quote }}
{{- end }}
{{- if not (and (hasKey . "circuitBreaker") (eq .circuitBreaker false)) }}
MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD: {{ index $c "MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD" | default "5" | quote }}
MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC: {{ index $c "MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC" | default "30" | quote }}
{{- end }}
{{- if .emitRedis }}
{{- $redisHost := index $c "MULTI_TENANT_REDIS_HOST" | default $g.redisHost -}}
{{- if .requiredRedisHost }}
MULTI_TENANT_REDIS_HOST: {{ required "lerian-common: MULTI_TENANT_REDIS_HOST is required when MULTI_TENANT_ENABLED=true (set component configmap.MULTI_TENANT_REDIS_HOST or global.multiTenant.redisHost)" $redisHost | quote }}
{{- else }}
MULTI_TENANT_REDIS_HOST: {{ $redisHost | default "" | quote }}
{{- end }}
MULTI_TENANT_REDIS_PORT: {{ index $c "MULTI_TENANT_REDIS_PORT" | default $g.redisPort | default "6379" | quote }}
MULTI_TENANT_REDIS_TLS: {{ index $c "MULTI_TENANT_REDIS_TLS" | default $g.redisTls | default (.redisTlsDefault | default "false") | quote }}
{{- end }}
{{- if .emitPool }}
MULTI_TENANT_MAX_TENANT_POOLS: {{ index $c "MULTI_TENANT_MAX_TENANT_POOLS" | default "100" | quote }}
MULTI_TENANT_IDLE_TIMEOUT_SEC: {{ index $c "MULTI_TENANT_IDLE_TIMEOUT_SEC" | default "300" | quote }}
{{- end }}
{{- if .emitCache }}
MULTI_TENANT_TIMEOUT: {{ index $c "MULTI_TENANT_TIMEOUT" | default "30" | quote }}
MULTI_TENANT_CACHE_TTL_SEC: {{ index $c "MULTI_TENANT_CACHE_TTL_SEC" | default "120" | quote }}
MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC: {{ index $c "MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC" | default "30" | quote }}
{{- end }}
{{- if .emitEnvironment }}
MULTI_TENANT_ENVIRONMENT: {{ index $c "MULTI_TENANT_ENVIRONMENT" | default "" | quote }}
{{- end }}
{{- if .emitAllowInsecure }}
MULTI_TENANT_ALLOW_INSECURE_HTTP: {{ index $c "MULTI_TENANT_ALLOW_INSECURE_HTTP" | default "false" | quote }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
------------------------------------------------------------------------------
lerian-common.multiTenant.secret — the uniform multi-tenant Secret keys.

Companion to multiTenant.env: the .env helper emits the non-secret block into the
ConfigMap; this one emits the SECRET keys into the chart's own Secret. Key names
are uniform across all charts (only the value differs per environment).

Emits nothing (and never fails) unless BOTH: the feature is enabled AND the chart
is not using an external Secret — the value lives outside the chart when
useExistingSecret=true, so requiring it inline is wrong. When active:
MULTI_TENANT_SERVICE_API_KEY is required; MULTI_TENANT_REDIS_PASSWORD is optional.
For a required-but-empty key it fails with an actionable message (Bitnami-style),
on install AND upgrade (these values are operator/Vault-provided, never generated).

`mode` matches the chart's Secret form: "data" (b64enc) | "stringData". Output is
`KEY: value` lines with no leading/trailing newline; the caller nindents under the
matching `data:`/`stringData:` key:

  # Multi-Tenant Secrets
  {{- with (include "lerian-common.multiTenant.secret" (dict
        "context" . "secrets" .Values.ledger.secrets
        "secretName" (include "midaz.ledger.fullname" .)
        "valuesPrefix" "ledger.secrets." "mode" "data"
        "enabled" (eq (.Values.ledger.configmap.MULTI_TENANT_ENABLED | default "false" | toString) "true")
        "useExistingSecret" .Values.ledger.useExistingSecret)) }}
  {{- . | nindent 2 }}
  {{- end }}

Inputs: context, secrets, secretName, valuesPrefix, mode,
        enabled (bool — MULTI_TENANT_ENABLED),
        useExistingSecret (bool — skip entirely when true).
------------------------------------------------------------------------------
*/}}
{{- define "lerian-common.multiTenant.secret" -}}
{{- if and .enabled (not .useExistingSecret) -}}
{{- $s := .secrets | default dict -}}
{{- $b64 := eq (.mode | default "stringData") "data" -}}
{{- $ns := .context.Release.Namespace -}}
{{- $lines := list -}}
{{- /* MULTI_TENANT_SERVICE_API_KEY — required */ -}}
{{- $apiKey := index $s "MULTI_TENANT_SERVICE_API_KEY" -}}
{{- if not $apiKey -}}
{{- fail (printf "\n[lerian-common] Secret value required but empty: MULTI_TENANT_SERVICE_API_KEY\n  set:     --set %sMULTI_TENANT_SERVICE_API_KEY=<value>   (or configure an existingSecret)\n  recover: kubectl get secret %s -n %s -o jsonpath=\"{.data.MULTI_TENANT_SERVICE_API_KEY}\" | base64 -d\n" .valuesPrefix .secretName $ns) -}}
{{- end -}}
{{- $lines = append $lines (printf "MULTI_TENANT_SERVICE_API_KEY: %s" (ternary ($apiKey | b64enc | quote) ($apiKey | quote) $b64)) -}}
{{- /* MULTI_TENANT_REDIS_PASSWORD — optional */ -}}
{{- $redisPw := index $s "MULTI_TENANT_REDIS_PASSWORD" -}}
{{- if $redisPw -}}
{{- $lines = append $lines (printf "MULTI_TENANT_REDIS_PASSWORD: %s" (ternary ($redisPw | b64enc | quote) ($redisPw | quote) $b64)) -}}
{{- end -}}
{{- join "\n" $lines -}}
{{- end -}}
{{- end -}}
