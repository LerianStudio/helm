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
  configmap (req)  the component's `.configmap` map (native key — top precedence)
  type      (req)  mask block: postgres | mongo | redis | redisMt | broker | <role>
  field     (req)  canonical field. Shared across a product's modules:
                     host | replicaHost | user | port | ssl | params
                   Per-module fields (database/name) stay native, NOT masked.
  nativeKey (req)  the product's real env key (e.g. DB_ONBOARDING_HOST)
  default   (opt)  fallback when neither native key nor mask is set (keep it equal
                   to the pre-mask render so standalone stays byte-identical)
*/}}
{{- define "lerian-common.datastore.value" -}}
{{- $cm := .configmap | default dict -}}
{{- $dedicated := index (.context.Values.datastores | default dict) .type | default dict -}}
{{- $shared := index ((.context.Values.global | default dict).datastores | default dict) .type | default dict -}}
{{- index $cm .nativeKey | default (index $dedicated .field) | default (index $shared .field) | default .default | default "" -}}
{{- end -}}
