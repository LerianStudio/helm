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
