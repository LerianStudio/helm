{{/*
==============================================================================
lerian-common — Rate-limit env.

Emits the shared three-tier rate-limit keys (Redis-backed) that every Lerian app
exposes with the SAME contract. Productized surface: the operator sets clean
`<product>.rateLimit.<field>` params; the raw `configmap.<KEY>` still works and
OVERRIDES (backward-compatible). Defaults match the legacy template defaults, so
existing installs render byte-identical.

Usage (component configmap.yaml):
  {{- include "lerian-common.rateLimit.env" (dict
        "configmap" .Values.ledger.configmap
        "params"    .Values.ledger.rateLimit) | nindent 2 }}

Inputs (dict):
  configmap  (req)  the component's `.configmap` map (native key — top precedence)
  params     (opt)  the component's `.rateLimit` map (productized knobs)

Precedence per key: native configmap.<KEY>  >  params.<field>  >  default.
Reason strings ALLOW_RATELIMIT_DISABLED / ALLOW_RATELIMIT_FAIL_OPEN are productized
too (params.allowDisabled / allowFailOpen; default "" = not set).
==============================================================================
*/}}
{{- define "lerian-common.rateLimit.env" -}}
{{- $cm := .configmap | default dict -}}
{{- $rl := .params | default dict -}}
RATE_LIMIT_ENABLED: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "RATE_LIMIT_ENABLED" "params" $rl "field" "enabled" "default" "true") | quote }}
ALLOW_RATELIMIT_DISABLED: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "ALLOW_RATELIMIT_DISABLED" "params" $rl "field" "allowDisabled" "default" "") | quote }}
ALLOW_RATELIMIT_FAIL_OPEN: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "ALLOW_RATELIMIT_FAIL_OPEN" "params" $rl "field" "allowFailOpen" "default" "") | quote }}
RATE_LIMIT_MAX: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "RATE_LIMIT_MAX" "params" $rl "field" "max" "default" "500") | quote }}
RATE_LIMIT_WINDOW_SEC: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "RATE_LIMIT_WINDOW_SEC" "params" $rl "field" "windowSec" "default" "60") | quote }}
AGGRESSIVE_RATE_LIMIT_MAX: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "AGGRESSIVE_RATE_LIMIT_MAX" "params" $rl "field" "aggressiveMax" "default" "100") | quote }}
AGGRESSIVE_RATE_LIMIT_WINDOW_SEC: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "AGGRESSIVE_RATE_LIMIT_WINDOW_SEC" "params" $rl "field" "aggressiveWindowSec" "default" "60") | quote }}
RELAXED_RATE_LIMIT_MAX: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "RELAXED_RATE_LIMIT_MAX" "params" $rl "field" "relaxedMax" "default" "1000") | quote }}
RELAXED_RATE_LIMIT_WINDOW_SEC: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "RELAXED_RATE_LIMIT_WINDOW_SEC" "params" $rl "field" "relaxedWindowSec" "default" "60") | quote }}
RATE_LIMIT_REDIS_TIMEOUT_MS: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "RATE_LIMIT_REDIS_TIMEOUT_MS" "params" $rl "field" "redisTimeoutMs" "default" "500") | quote }}
{{- end -}}
