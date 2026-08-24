{{/*
==============================================================================
lerian-common — Datastore mask resolver.

Lets a product emit its native datastore env keys from an operator "mask", so the
operator writes `postgres.host` (not `DB_ONBOARDING_HOST`). Two deploy modes:

  - SHARED    → global.datastores.<type>.<field>       (all products, one instance)
  - DEDICATED → <product>.datastores.<type>.<field>    (this product's own instance)

Precedence per field (backward-compatible):
  native configmap key  >  dedicated (<product>.datastores)  >  shared (global.datastores)  >  default

Standalone (no umbrella, no mask): falls through to the native key or the default →
render-equivalent, existing users unaffected. In an umbrella, `.context.Values` is
the subchart's root, so `.Values.datastores` = the per-product `<product>.datastores`
block (dedicated) and `.Values.global.datastores` = the shared mask.
==============================================================================
*/}}

{{/*
lerian-common.datastore.value — resolve ONE datastore field via the mask.
Inputs (dict):
  context   (req)  product root ($)
  dedicated (opt)  the component's dedicated datastores map (`<component>.datastores`)
                   for a monolithic parent chart; when omitted, `.context.Values.
                   datastores` is used (subchart mode)
  configmap (req)  the component's `.configmap` map (native key — top precedence)
  type      (req)  mask block: postgres | mongo | redis | redisMt | broker | <role>
  field     (req)  canonical field. Shared across a product's modules:
                     host | replicaHost | user | port | ssl | params | caCert
                   Per-module fields (database/name) stay native, NOT masked.
  nativeKey (req)  the product's real env key (e.g. DB_ONBOARDING_HOST)
  default   (opt)  fallback when neither native key nor mask is set (keep it equal
                   to the pre-mask render so standalone stays byte-identical)
*/}}
{{- define "lerian-common.datastore.value" -}}
{{- $cm := .configmap | default dict -}}
{{- /* Dedicated source: an explicit `dedicated` map (passed by a MONOLITHIC parent
   chart whose per-component masks live at `<component>.datastores`, e.g. midaz's
   `ledger.datastores` / `crm.datastores`) takes precedence; otherwise fall back to
   `.context.Values.datastores`, which in a SUBCHART is that product's own block. */ -}}
{{- $dedicated := index (.dedicated | default (.context.Values.datastores | default dict)) .type | default dict -}}
{{- $shared := index ((.context.Values.global | default dict).datastores | default dict) .type | default dict -}}
{{- /* Cloud preset tier: global.cloud selects a topology column (see _cloud.tpl).
   Ranks BELOW an explicit shared/dedicated value (those are the override) and
   ABOVE the hardcoded default. Only fields present in the preset participate. */ -}}
{{- $cloudBlk := include "lerian-common.cloud.block" (dict "context" .context "kind" .type) | fromYaml -}}
{{/* Ordered presence checks (not chained sprig `default`) so an explicit `false`
     at any tier — native key, dedicated, shared, cloud preset, or default — wins
     instead of falling through to a lower-priority value. */}}
{{- if hasKey $cm .nativeKey -}}
{{- index $cm .nativeKey -}}
{{- else if hasKey $dedicated .field -}}
{{- index $dedicated .field -}}
{{- else if hasKey $shared .field -}}
{{- index $shared .field -}}
{{- else if hasKey $cloudBlk .field -}}
{{- index $cloudBlk .field -}}
{{- else if hasKey . "default" -}}
{{- .default -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}
