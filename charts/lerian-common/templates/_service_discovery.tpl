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
  ingressHost (opt)  external host; when non-empty, derives SD_EXTERNAL_*
                     from it. The external endpoint is ALSO emitted (regardless
                     of ingressHost) when the operator supplies it explicitly via
                     legacy configmap.SD_EXTERNAL_ADDRESS / SD_EXTERNAL_PORT —
                     the on-prem-without-Ingress case. Omitted only for
                     consumer-only / internal-only instances (no ingressHost and
                     no legacy SD_EXTERNAL_* keys).
  configmap   (opt)  the component's legacy `.configmap` map. When a key is
                     present here, its flat `configmap.SD_*` value WINS over the
                     global/derived value below (backward-compat for the flat
                     configmap API). Defaults to an empty dict → every key falls
                     through to the derived value (byte-identical to no-configmap).

global.serviceDiscovery (all optional except address when enabled):
  address, tls, tlsSkipVerify, workload, preferView, internalScheme, externalPort
==============================================================================
*/}}
{{- define "lerian-common.serviceDiscovery.env" -}}
{{- $sd := (.context.Values.global | default dict).serviceDiscovery | default dict -}}
{{- /* Legacy flat configmap source: a present `configmap.SD_*` key WINS over the
   global/derived value (mirrors multiTenant.env). Empty dict when omitted, so a
   no-configmap caller renders byte-identical to before. */ -}}
{{- $c := .configmap | default dict -}}
{{- /*
  Derive ONLY when enabled AND an SD address is configured — via EITHER the
  environment-wide `global.serviceDiscovery.address` OR the legacy flat
  `configmap.SD_ADDRESS` (on-prem/client values that predate global). Gating on
  both preserves the documented backward-compat contract: a chart deployed with
  `configmap.SD_ENABLED=true` + `configmap.SD_ADDRESS` (no global) still derives
  the full sibling block, matching pre-refactor output.
  This keeps adoption backward-compatible: a chart carrying this helper but
  deployed against a not-yet-migrated environment (SD_* still hand-set in
  extraEnvVars, no global.serviceDiscovery, no configmap.SD_ADDRESS) stays
  INERT — extraEnvVars drives SD exactly as before, no duplicate keys, no render
  break. The environment opts into derivation by setting global.serviceDiscovery
  (or configmap.SD_ADDRESS) + stripping the per-app SD_* block down to SD_ENABLED.
*/ -}}
{{- /* Activation gate is PRESENCE-based on the configmap key (hasKey), not its
   truthiness: a present-but-empty `configmap.SD_ADDRESS` must still activate the
   block. Sprig `index ... | default` (and `or`) would treat "" / false / 0 as
   empty and wrongly fall through to global — the footgun this fix removes. */ -}}
{{- if and .enabled (or $sd.address (hasKey $c "SD_ADDRESS")) -}}
{{- /* SD_ENABLED is NOT emitted here: it is the app's single knob and is
   rendered by the component's own extraEnvVars passthrough. Emitting it again
   would produce a duplicate key. This helper only adds the derived siblings.

   Precedence per key is PRESENCE-based: a PRESENT `configmap.SD_*` key WINS
   even when its value is empty / false / 0; the global/derived value is the
   fallback only when the key is ABSENT (hasKey false). Do NOT reintroduce
   sprig `default` here — it collapses explicit empty/false/0 to the fallback.

   Resolution is done up-front (each assignment line fully whitespace-trimmed so
   it emits nothing), then the KEY: value lines below are plain literals — this
   keeps the rendered block byte-identical to the pre-fix output when no
   configmap.SD_* key is present. */ -}}
{{- $addr := $sd.address -}}{{- if hasKey $c "SD_ADDRESS" -}}{{- $addr = index $c "SD_ADDRESS" -}}{{- end -}}
{{- $tls := ($sd.tls | default false) -}}{{- if hasKey $c "SD_TLS" -}}{{- $tls = index $c "SD_TLS" -}}{{- end -}}
{{- $tlsSkip := ($sd.tlsSkipVerify | default false) -}}{{- if hasKey $c "SD_TLS_SKIP_VERIFY" -}}{{- $tlsSkip = index $c "SD_TLS_SKIP_VERIFY" -}}{{- end -}}
{{- $workload := ($sd.workload | default "") -}}{{- if hasKey $c "SD_WORKLOAD" -}}{{- $workload = index $c "SD_WORKLOAD" -}}{{- end -}}
{{- $preferView := ($sd.preferView | default "internal") -}}{{- if hasKey $c "SD_PREFER_VIEW" -}}{{- $preferView = index $c "SD_PREFER_VIEW" -}}{{- end -}}
{{- $internalAddr := (include "lerian-common.internalHost" (dict "name" .name "namespace" .namespace)) -}}{{- if hasKey $c "SD_INTERNAL_ADDRESS" -}}{{- $internalAddr = index $c "SD_INTERNAL_ADDRESS" -}}{{- end -}}
{{- $internalPort := .port -}}{{- if hasKey $c "SD_INTERNAL_PORT" -}}{{- $internalPort = index $c "SD_INTERNAL_PORT" -}}{{- end -}}
{{- $internalScheme := ($sd.internalScheme | default "http") -}}{{- if hasKey $c "SD_INTERNAL_SCHEME" -}}{{- $internalScheme = index $c "SD_INTERNAL_SCHEME" -}}{{- end -}}
{{- $externalAddr := "" -}}{{- if .ingressHost -}}{{- $externalAddr = (printf "https://%s" .ingressHost) -}}{{- end -}}{{- if hasKey $c "SD_EXTERNAL_ADDRESS" -}}{{- $externalAddr = index $c "SD_EXTERNAL_ADDRESS" -}}{{- end -}}
{{- $externalPort := ($sd.externalPort | default 443) -}}{{- if hasKey $c "SD_EXTERNAL_PORT" -}}{{- $externalPort = index $c "SD_EXTERNAL_PORT" -}}{{- end -}}
SD_ADDRESS: {{ $addr | quote }}
SD_TLS: {{ $tls | quote }}
SD_TLS_SKIP_VERIFY: {{ $tlsSkip | quote }}
SD_WORKLOAD: {{ $workload | quote }}
SD_PREFER_VIEW: {{ $preferView | quote }}
SD_INTERNAL_ADDRESS: {{ $internalAddr | quote }}
SD_INTERNAL_PORT: {{ $internalPort | quote }}
SD_INTERNAL_SCHEME: {{ $internalScheme | quote }}
{{- /* Emit the external endpoint when it can be derived from an Ingress host
   OR when the operator supplied it explicitly via legacy configmap.SD_EXTERNAL_*
   keys (on-prem without Ingress). Honors the configmap.SD_* -> global -> default
   precedence contract; omitted only for internal-only / consumer-only instances. */ -}}
{{- if or .ingressHost (hasKey $c "SD_EXTERNAL_ADDRESS") (hasKey $c "SD_EXTERNAL_PORT") }}
SD_EXTERNAL_ADDRESS: {{ $externalAddr | quote }}
SD_EXTERNAL_PORT: {{ $externalPort | quote }}
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
  stdDefaults (opt) dict of standard/baked defaults; lowest precedence. Resolution
                   order per key: configmap > defaults (caller) > stdDefaults > "".
  required  (opt)  dict key->error message; if the RESOLVED value is empty, fail
                   with that message (mirrors native `required`)
==============================================================================
*/}}
{{- define "lerian-common.env.flatBlock" -}}
{{- $cm := .configmap | default dict -}}
{{- $defaults := .defaults | default dict -}}
{{- $std := .stdDefaults | default dict -}}
{{- $required := .required | default dict -}}
{{- $lines := list -}}
{{- range $k := .keys -}}
  {{- $v := "" -}}
  {{- /* Precedence: native configmap key > caller default > standard default > "".
     Presence-based (hasKey) so an explicit empty-string/false at any tier wins. */ -}}
  {{- if hasKey $cm $k -}}
    {{- $v = index $cm $k -}}
  {{- else if hasKey $defaults $k -}}
    {{- $v = index $defaults $k -}}
  {{- else if hasKey $std $k -}}
    {{- $v = index $std $k -}}
  {{- end -}}
  {{- if kindIs "invalid" $v -}}{{- $v = "" -}}{{- end -}}
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
{{- include "lerian-common.env.flatBlock" (dict "configmap" .configmap "keys" $keys "defaults" (.defaults | default dict) "stdDefaults" $std) -}}
{{- end -}}
