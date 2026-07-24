{{/*
==============================================================================
lerian-common — Service Discovery env (lib-service-discovery contract).

Emits the SD_* env block into a ConfigMap `data` map, gated on `enabled`.
Per-service endpoints are derived from the chart's own primitives; the env-wide
constants are inherited from `global.serviceDiscovery` (set once per environment
in GitOps). The contract is identical for every app, so this lives here once.

The design goal is that an app enables discovery with ONLY `SD_ENABLED: "true"`
in its component `extraEnvVars`; everything else is derived here.

Usage (in a component configmap.yaml, emitted BEFORE the extraEnvVars
passthrough so an operator can still override any single SD_* key):

  {{- $cv := .Values.identity -}}
  {{- include "lerian-common.serviceDiscovery.env" (dict
        "context"     $
        "enabled"     (eq (toString (dig "SD_ENABLED" "false" ($cv.extraEnvVars | default dict))) "true")
        "name"        $cv.name
        "port"        $cv.service.port
        "namespace"   (include "global.namespace" $)
        "ingressHost" (include "lerian-common.firstIngressHost" (dict "ingress" $cv.ingress))
      ) | nindent 2 }}

Inputs (dict):
  context     (req)  root context ($) — used to read global.serviceDiscovery
  enabled     (req)  bool — whether to emit the block at all
  name        (req)  internal service DNS name (SD_INTERNAL_ADDRESS host)
  port        (req)  internal service port
  namespace   (req)  resolved namespace string
  ingressHost (opt)  external host; when non-empty, emits SD_EXTERNAL_*
                     (omit for consumer-only / internal-only instances)

global.serviceDiscovery (all optional except address when enabled):
  address, tls, tlsSkipVerify, workload, preferView, internalScheme, externalPort
==============================================================================
*/}}
{{- define "lerian-common.serviceDiscovery.env" -}}
{{- $sd := (.context.Values.global | default dict).serviceDiscovery | default dict -}}
{{- /*
  Derive ONLY when enabled AND global.serviceDiscovery.address is configured.
  This keeps adoption backward-compatible: a chart carrying this helper but
  deployed against a not-yet-migrated environment (SD_* still hand-set in
  extraEnvVars, no global.serviceDiscovery) stays INERT — extraEnvVars drives
  SD exactly as before, no duplicate keys, no render break. The environment
  opts into derivation by setting global.serviceDiscovery + stripping the
  per-app SD_* block down to just SD_ENABLED.
*/ -}}
{{- if and .enabled $sd.address -}}
{{- /* SD_ENABLED is NOT emitted here: it is the app's single knob and is
   rendered by the component's own extraEnvVars passthrough. Emitting it again
   would produce a duplicate key. This helper only adds the derived siblings. */ -}}
SD_ADDRESS: {{ $sd.address | quote }}
SD_TLS: {{ $sd.tls | default false | quote }}
SD_TLS_SKIP_VERIFY: {{ $sd.tlsSkipVerify | default false | quote }}
SD_WORKLOAD: {{ $sd.workload | default "" | quote }}
SD_PREFER_VIEW: {{ $sd.preferView | default "external" | quote }}
SD_INTERNAL_ADDRESS: {{ include "lerian-common.internalHost" (dict "name" .name "namespace" .namespace) | quote }}
SD_INTERNAL_PORT: {{ .port | quote }}
SD_INTERNAL_SCHEME: {{ $sd.internalScheme | default "http" | quote }}
{{- if .ingressHost }}
SD_EXTERNAL_ADDRESS: {{ printf "https://%s" .ingressHost | quote }}
SD_EXTERNAL_PORT: {{ $sd.externalPort | default 443 | quote }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
lerian-common.firstIngressHost — the first ingress host, or "" when ingress is
disabled/absent. Keeps the SD wiring a one-liner and consistent across charts.
Inputs: ingress (the component's `.ingress` map).
*/}}
{{- define "lerian-common.firstIngressHost" -}}
{{- $ing := .ingress | default dict -}}
{{- if and $ing.enabled $ing.hosts -}}
{{- (first $ing.hosts).host | default "" -}}
{{- end -}}
{{- end -}}

{{/*
==============================================================================
lerian-common.env.flatBlock — SHARED low-level ordered `KEY: value` emitter.

The generic primitive behind every `*.envFlat` helper (serviceDiscovery / otel /
multiTenant). It reproduces a chart's EXISTING hand-written env block
byte-for-byte: same keys, same values, same defaults, same quoting AND same line
order — without deriving anything. It just walks a caller-supplied ordered key
list and, per key, emits the component's native override if present else the
supplied default.

This is the "flat-passthrough" counterpart to the derivation-model helpers
(lerian-common.serviceDiscovery.env / .otel.env / .multiTenant.env). Those
DERIVE values from `global.*`; this one does NOT — it is a faithful mirror of the
per-chart block, so a productized chart can adopt lerian-common with zero render
diff before (optionally) moving to derivation later.

Precedence per key (presence-based, NOT sprig `default`):
  configmap.<KEY> (hasKey)  >  defaults.<KEY> (hasKey)  >  ""
Presence checks (hasKey) are used deliberately so an explicit `false`/empty in
the component configmap is respected instead of silently falling through to the
default (the sprig-`default` footgun this repo has already hit with booleans).

NOTE: under the REAL product values these keys are absent from `.configmap`
(they are hand-defaulted in the native template), so hasKey is false and the
`defaults.<KEY>` value is emitted — identical to the native `X | default "y"`.
The hasKey semantics only diverge from native when a key is explicitly set to an
empty string in configmap, which the native templates never do.

Output: `KEY: value` lines joined by "\n" with NO leading/trailing newline; the
caller `| nindent N`s it under the ConfigMap `data:` map.

Inputs (dict):
  configmap (req)  the component's `.configmap` map (native override source)
  keys      (req)  ordered list of env keys to emit (the subset + order)
  defaults  (opt)  dict key->default value, used when configmap lacks the key
  required  (opt)  dict key->error message; if the RESOLVED value is empty, fail
                   with that message (mirrors native `required`)
==============================================================================
*/}}
{{- define "lerian-common.env.flatBlock" -}}
{{- $cm := .configmap | default dict -}}
{{- $defaults := .defaults | default dict -}}
{{- $required := .required | default dict -}}
{{- $lines := list -}}
{{- range $k := .keys -}}
  {{- $v := "" -}}
  {{- if hasKey $cm $k -}}
    {{- $v = index $cm $k -}}
  {{- else if hasKey $defaults $k -}}
    {{- $v = index $defaults $k -}}
  {{- end -}}
  {{- if and (hasKey $required $k) (not $v) -}}
    {{- fail (index $required $k) -}}
  {{- end -}}
  {{- $lines = append $lines (printf "%s: %s" $k ($v | quote)) -}}
{{- end -}}
{{- join "\n" $lines -}}
{{- end -}}

{{/*
==============================================================================
lerian-common.serviceDiscovery.envFlat — flat-passthrough SD_* block.

Reproduces the chart's EXISTING native SD_* env block byte-for-byte (no
derivation, no `global.serviceDiscovery`). It encodes the canonical SD contract:
the known key set + each key's STANDARD default. A chart opts into the SUBSET and
ORDER it currently emits via `keys`, and overrides any per-key default via
`defaults` (e.g. plugin-fees' whitespace-padded SD_ADDRESS). See
`lerian-common.env.flatBlock` (this file) for precedence/quoting semantics.

Usage (component configmap.yaml — replaces the hand-written SD_* block):

  # midaz-ledger / midaz-crm — full 17-key block, standard defaults:
  {{- include "lerian-common.serviceDiscovery.envFlat" (dict
        "configmap" .Values.ledger.configmap) | nindent 2 }}

  # plugin-fees — 7-key subset with its padded defaults:
  {{- include "lerian-common.serviceDiscovery.envFlat" (dict
        "configmap" .Values.fees.configmap
        "keys" (list "SD_ADDRESS" "SD_ENABLED" "SD_EXTERNAL_ADDRESS"
                     "SD_EXTERNAL_PORT" "SD_TLS" "SD_TLS_SKIP_VERIFY" "SD_WORKLOAD")
        "defaults" (dict
          "SD_ADDRESS" "localhost:8500       "
          "SD_EXTERNAL_ADDRESS" "            "
          "SD_EXTERNAL_PORT" "               "
          "SD_WORKLOAD" "                    ")) | nindent 2 }}

Inputs (dict):
  configmap (req)  the component's `.configmap` map (native override source)
  keys      (opt)  ordered subset to emit; defaults to the full 17-key block in
                   the canonical (alphabetical) order midaz emits
  defaults  (opt)  per-key default overrides (chart-specific defaults win over
                   the standard defaults baked in here)
==============================================================================
*/}}
{{- define "lerian-common.serviceDiscovery.envFlat" -}}
{{- $std := dict
      "SD_ADDRESS" "localhost:8500"
      "SD_ALLOW_STALE" ""
      "SD_DIAL_TIMEOUT" ""
      "SD_ENABLED" "false"
      "SD_EXTERNAL_ADDRESS" ""
      "SD_EXTERNAL_PORT" ""
      "SD_INTERNAL_ADDRESS" ""
      "SD_INTERNAL_PORT" ""
      "SD_INTERNAL_SCHEME" ""
      "SD_PREFER_VIEW" ""
      "SD_RESPONSE_HEADER_TIMEOUT" ""
      "SD_SEED_TIMEOUT" ""
      "SD_TLS" "false"
      "SD_TLS_HANDSHAKE_TIMEOUT" ""
      "SD_TLS_SKIP_VERIFY" "false"
      "SD_WATCH_WAIT_TIME" ""
      "SD_WORKLOAD" "" -}}
{{- $keys := .keys | default (list
      "SD_ADDRESS" "SD_ALLOW_STALE" "SD_DIAL_TIMEOUT" "SD_ENABLED"
      "SD_EXTERNAL_ADDRESS" "SD_EXTERNAL_PORT" "SD_INTERNAL_ADDRESS"
      "SD_INTERNAL_PORT" "SD_INTERNAL_SCHEME" "SD_PREFER_VIEW"
      "SD_RESPONSE_HEADER_TIMEOUT" "SD_SEED_TIMEOUT" "SD_TLS"
      "SD_TLS_HANDSHAKE_TIMEOUT" "SD_TLS_SKIP_VERIFY" "SD_WATCH_WAIT_TIME"
      "SD_WORKLOAD") -}}
{{- /* Overlay chart-supplied defaults onto the standard set. Use `set` (not sprig
   `merge`) so an explicit empty-string default from the chart wins — `merge`
   would treat an empty dst value as absent and refill it from `$std`. */ -}}
{{- $defaults := deepCopy $std -}}
{{- range $k, $v := (.defaults | default dict) -}}{{- $_ := set $defaults $k $v -}}{{- end -}}
{{- include "lerian-common.env.flatBlock" (dict "configmap" .configmap "keys" $keys "defaults" $defaults) -}}
{{- end -}}
