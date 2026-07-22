{{/*
==============================================================================
lerian-common — generic global-contract resolver.

Same idea as the datastore mask, for any cross-product concern that lives under
`global.<block>` (auth, observability, ...). A product emits its native env key
from a shared default, so the operator declares it ONCE at the umbrella level.

Precedence (backward-compatible):
  native configmap key  >  global.<block>.<field>  >  default

Standalone (no umbrella / no global.<block>): falls through to the native key or
the default → render-equivalent, existing users unaffected. Keep `default` equal
to the pre-contract render so standalone stays byte-identical.

Inputs (dict):
  context   (req)  product root ($)
  configmap (req)  the component's `.configmap` map (native key — top precedence)
  block     (req)  the global sub-block: auth | observability | ...
  field     (req)  canonical field within the block: enabled | host | ...
  nativeKey (req)  the product's real env key (e.g. PLUGIN_AUTH_HOST)
  default   (opt)  fallback when neither native key nor global is set
*/}}
{{- define "lerian-common.globalValue" -}}
{{- $cm := .configmap | default dict -}}
{{- $blk := index (.context.Values.global | default dict) .block | default dict -}}
{{- $native := index $cm .nativeKey -}}
{{/* Use presence checks (not sprig `default`) so an explicit boolean `false` in the
     global block wins instead of falling through to the default. */}}
{{- if not (empty $native) -}}
{{- $native -}}
{{- else if hasKey $blk .field -}}
{{- index $blk .field -}}
{{- else -}}
{{- .default | default "" -}}
{{- end -}}
{{- end -}}

{{/*
lerian-common.cfgValue — productized config resolver (product-level, no global block).
Lets a chart expose a clean grouped param (e.g. ledger.audit.enabled) while the raw
`configmap.<KEY>` still works and wins — backward-compatible with the legacy format.

Precedence:  configmap native key  >  clean param (params.<field>)  >  default

Presence-aware (hasKey) so an explicit boolean `false` in the clean param wins.
Inputs (dict):
  configmap (req)  the component's `.configmap` map (legacy native key — top precedence)
  nativeKey (req)  the real env key (e.g. AUDIT_LOG_ENABLED)
  params    (req)  the clean param sub-map (e.g. .Values.ledger.audit)
  field     (req)  field within params (e.g. enabled)
  default   (opt)  fallback = the legacy template default (keeps standalone byte-identical)
*/}}
{{- define "lerian-common.cfgValue" -}}
{{- $cm := .configmap | default dict -}}
{{- $p := .params | default dict -}}
{{- $native := index $cm .nativeKey -}}
{{- if not (empty $native) -}}
{{- $native -}}
{{- else if hasKey $p .field -}}
{{- index $p .field -}}
{{- else -}}
{{- .default | default "" -}}
{{- end -}}
{{- end -}}
