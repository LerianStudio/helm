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

plugin-br-payments is intentionally OUT of scope. Its keys are canonical
(same names this helper uses) but its ConfigMap is built by a generic `range`
over the merged `app.configmap` map (templates/configmap.yaml), not a
per-key emit like this helper's — so a default this helper injected for a
key the component's own values.yaml leaves absent would render into that
component's ConfigMap the same way a literal default in its own values.yaml
would, which is exactly the class of bug this contract exists to avoid.
Keep it inline.

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
  emitRedisCaCert    (opt)  bool — MULTI_TENANT_REDIS_CA_CERT (default ""); under emitRedis.
                            For charts whose tenant-redis supports a CA cert (e.g. reporter).
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
{{- /* URL: universal. Component overrides global; then required or default "".
   Resolve by PRESENCE (hasKey) so an explicit configmap value survives even as a
   YAML false / 0 / "" — sprig `default` would drop those to the global value. */ -}}
{{- $url := ($g.url | default "") -}}{{- if hasKey $c "MULTI_TENANT_URL" -}}{{- $url = index $c "MULTI_TENANT_URL" -}}{{- end -}}
{{- if .requiredUrl }}
MULTI_TENANT_URL: {{ required "lerian-common: MULTI_TENANT_URL is required when MULTI_TENANT_ENABLED=true (set component configmap.MULTI_TENANT_URL or global.multiTenant.url)" $url | quote }}
{{- else }}
MULTI_TENANT_URL: {{ $url | quote }}
{{- end }}
{{- if .serviceName }}
{{- $svcName := .serviceName -}}{{- if hasKey $c "MULTI_TENANT_SERVICE_NAME" -}}{{- $svcName = index $c "MULTI_TENANT_SERVICE_NAME" -}}{{- end }}
MULTI_TENANT_SERVICE_NAME: {{ $svcName | quote }}
{{- end }}
{{- if not (and (hasKey . "circuitBreaker") (eq .circuitBreaker false)) }}
{{- $cbThreshold := "5" -}}{{- if hasKey $c "MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD" -}}{{- $cbThreshold = index $c "MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD" -}}{{- end }}
MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD: {{ $cbThreshold | quote }}
{{- $cbTimeout := "30" -}}{{- if hasKey $c "MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC" -}}{{- $cbTimeout = index $c "MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC" -}}{{- end }}
MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC: {{ $cbTimeout | quote }}
{{- end }}
{{- if .emitRedis }}
{{- $redisHost := ($g.redisHost | default "") -}}{{- if hasKey $c "MULTI_TENANT_REDIS_HOST" -}}{{- $redisHost = index $c "MULTI_TENANT_REDIS_HOST" -}}{{- end -}}
{{- if .requiredRedisHost }}
MULTI_TENANT_REDIS_HOST: {{ required "lerian-common: MULTI_TENANT_REDIS_HOST is required when MULTI_TENANT_ENABLED=true (set component configmap.MULTI_TENANT_REDIS_HOST or global.multiTenant.redisHost)" $redisHost | quote }}
{{- else }}
MULTI_TENANT_REDIS_HOST: {{ $redisHost | quote }}
{{- end }}
{{- $redisPort := ($g.redisPort | default "6379") -}}{{- if hasKey $c "MULTI_TENANT_REDIS_PORT" -}}{{- $redisPort = index $c "MULTI_TENANT_REDIS_PORT" -}}{{- end }}
MULTI_TENANT_REDIS_PORT: {{ $redisPort | quote }}
{{- $redisTls := ($g.redisTls | default (.redisTlsDefault | default "false")) -}}{{- if hasKey $c "MULTI_TENANT_REDIS_TLS" -}}{{- $redisTls = index $c "MULTI_TENANT_REDIS_TLS" -}}{{- end }}
MULTI_TENANT_REDIS_TLS: {{ $redisTls | quote }}
{{- if .emitRedisCaCert }}
{{- $redisCaCert := ($g.redisCaCert | default "") -}}{{- if hasKey $c "MULTI_TENANT_REDIS_CA_CERT" -}}{{- $redisCaCert = index $c "MULTI_TENANT_REDIS_CA_CERT" -}}{{- end }}
MULTI_TENANT_REDIS_CA_CERT: {{ $redisCaCert | quote }}
{{- end }}
{{- end }}
{{- if .emitPool }}
{{- $maxPools := "100" -}}{{- if hasKey $c "MULTI_TENANT_MAX_TENANT_POOLS" -}}{{- $maxPools = index $c "MULTI_TENANT_MAX_TENANT_POOLS" -}}{{- end }}
MULTI_TENANT_MAX_TENANT_POOLS: {{ $maxPools | quote }}
{{- $idleTimeout := "300" -}}{{- if hasKey $c "MULTI_TENANT_IDLE_TIMEOUT_SEC" -}}{{- $idleTimeout = index $c "MULTI_TENANT_IDLE_TIMEOUT_SEC" -}}{{- end }}
MULTI_TENANT_IDLE_TIMEOUT_SEC: {{ $idleTimeout | quote }}
{{- end }}
{{- if .emitCache }}
{{- $mtTimeout := "30" -}}{{- if hasKey $c "MULTI_TENANT_TIMEOUT" -}}{{- $mtTimeout = index $c "MULTI_TENANT_TIMEOUT" -}}{{- end }}
MULTI_TENANT_TIMEOUT: {{ $mtTimeout | quote }}
{{- $cacheTtl := "120" -}}{{- if hasKey $c "MULTI_TENANT_CACHE_TTL_SEC" -}}{{- $cacheTtl = index $c "MULTI_TENANT_CACHE_TTL_SEC" -}}{{- end }}
MULTI_TENANT_CACHE_TTL_SEC: {{ $cacheTtl | quote }}
{{- $connCheck := "30" -}}{{- if hasKey $c "MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC" -}}{{- $connCheck = index $c "MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC" -}}{{- end }}
MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC: {{ $connCheck | quote }}
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
{{/*
==============================================================================
lerian-common.multiTenant.envFlat — flat-passthrough MULTI_TENANT_* block.

Reproduces the chart's EXISTING native multi-tenant env block byte-for-byte (no
derivation, no `global.multiTenant`). Complements `lerian-common.multiTenant.env`
(the derivation-model helper): this one is a faithful mirror of the per-chart
block for charts adopting lerian-common with zero render diff.

Always emits `MULTI_TENANT_ENABLED` first (the knob) — UNLIKE
`lerian-common.multiTenant.env`, which leaves it inline. Then, ONLY when enabled
(`MULTI_TENANT_ENABLED == "true"`), emits the gated subset the chart opts into
via `keys`, in that order, with `flatBlock` precedence/quoting. The gate is
computed from the resolved MULTI_TENANT_ENABLED using presence (hasKey) over the
configmap, falling back to `enabledDefault`.

The SECRET keys (MULTI_TENANT_SERVICE_API_KEY / MULTI_TENANT_REDIS_PASSWORD) are
NOT emitted here — use the companion `lerian-common.multiTenant.secret`.

Usage (component configmap.yaml — replaces the hand-written MT block):

  # midaz-ledger (8 keys: ENABLED + 7 gated; SERVICE_NAME default "ledger"):
  {{- include "lerian-common.multiTenant.envFlat" (dict
        "configmap" .Values.ledger.configmap
        "keys" (list "MULTI_TENANT_URL" "MULTI_TENANT_SERVICE_NAME"
                     "MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD" "MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC"
                     "MULTI_TENANT_REDIS_HOST" "MULTI_TENANT_REDIS_PORT" "MULTI_TENANT_REDIS_TLS")
        "defaults" (dict "MULTI_TENANT_SERVICE_NAME" "ledger")
        "required" (dict
          "MULTI_TENANT_URL" "ledger.configmap.MULTI_TENANT_URL is required when MULTI_TENANT_ENABLED=true"
          "MULTI_TENANT_REDIS_HOST" "ledger.configmap.MULTI_TENANT_REDIS_HOST is required when MULTI_TENANT_ENABLED=true"))
    | nindent 2 }}

  # plugin-fees (14 keys: ENABLED + 13 gated; all standard defaults):
  {{- include "lerian-common.multiTenant.envFlat" (dict
        "configmap" .Values.fees.configmap
        "keys" (list "MULTI_TENANT_URL" "MULTI_TENANT_ALLOW_INSECURE_HTTP" "MULTI_TENANT_ENVIRONMENT"
                     "MULTI_TENANT_MAX_TENANT_POOLS" "MULTI_TENANT_IDLE_TIMEOUT_SEC"
                     "MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD" "MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC"
                     "MULTI_TENANT_REDIS_HOST" "MULTI_TENANT_REDIS_PORT" "MULTI_TENANT_REDIS_TLS"
                     "MULTI_TENANT_TIMEOUT" "MULTI_TENANT_CACHE_TTL_SEC" "MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC")
        "required" (dict
          "MULTI_TENANT_URL" "fees.configmap.MULTI_TENANT_URL is required when MULTI_TENANT_ENABLED=true"
          "MULTI_TENANT_REDIS_HOST" "fees.configmap.MULTI_TENANT_REDIS_HOST is required when MULTI_TENANT_ENABLED=true"))
    | nindent 2 }}

Inputs (dict):
  configmap      (req)  the component's `.configmap` map (native override source)
  keys           (req)  ordered gated subset (WITHOUT MULTI_TENANT_ENABLED)
  enabledDefault (opt)  default for MULTI_TENANT_ENABLED (default "false")
  defaults       (opt)  per-key default overrides (e.g. SERVICE_NAME "ledger");
                        chart defaults win over the standard defaults baked here
  required       (opt)  dict key->message; fail if the resolved value is empty
==============================================================================
*/}}
{{- define "lerian-common.multiTenant.envFlat" -}}
{{- $cm := .configmap | default dict -}}
{{- $enabledVal := .enabledDefault | default "false" -}}
{{- if hasKey $cm "MULTI_TENANT_ENABLED" -}}{{- $enabledVal = index $cm "MULTI_TENANT_ENABLED" -}}{{- end -}}
{{- $std := dict
      "MULTI_TENANT_URL" ""
      "MULTI_TENANT_SERVICE_NAME" ""
      "MULTI_TENANT_ALLOW_INSECURE_HTTP" "false"
      "MULTI_TENANT_ENVIRONMENT" ""
      "MULTI_TENANT_MAX_TENANT_POOLS" "100"
      "MULTI_TENANT_IDLE_TIMEOUT_SEC" "300"
      "MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD" "5"
      "MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC" "30"
      "MULTI_TENANT_REDIS_HOST" ""
      "MULTI_TENANT_REDIS_PORT" "6379"
      "MULTI_TENANT_REDIS_TLS" "false"
      "MULTI_TENANT_REDIS_CA_CERT" ""
      "MULTI_TENANT_TIMEOUT" "30"
      "MULTI_TENANT_CACHE_TTL_SEC" "120"
      "MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC" "30" -}}
{{- if kindIs "invalid" $enabledVal -}}{{- $enabledVal = "false" -}}{{- end -}}
{{- /* Guard: only emit non-secret multi-tenant keys from the known contract
   ($std). Rejects a caller passing MULTI_TENANT_ENABLED again (emitted above)
   or a secret-only name into the ConfigMap. */ -}}
{{- $safeKeys := list -}}
{{- range $k := (.keys | default list) -}}{{- if hasKey $std $k -}}{{- $safeKeys = append $safeKeys $k -}}{{- end -}}{{- end -}}
MULTI_TENANT_ENABLED: {{ $enabledVal | quote }}
{{- if eq (toString $enabledVal) "true" }}
{{ include "lerian-common.env.flatBlock" (dict "configmap" $cm "keys" $safeKeys "defaults" (.defaults | default dict) "stdDefaults" $std "required" (.required | default dict)) }}
{{- end -}}
{{- end -}}

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
