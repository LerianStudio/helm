{{/*
==============================================================================
lerian-common — KMS mask resolver (envelope encryption / HashiCorp Vault).

The KMS backend is a DEPENDENCY connection (how the app reaches its key
management / Vault), so — like datastores and object storage — the operator
writes a typed mask (`kms.vaultAddr`) instead of the app's native env key
(`KMS_VAULT_ADDR`). Unlike datastores/objectStorage there is a single KMS per
app (no named backends), so the mask is resolved directly (no name/type sub-key).

  - SHARED    → global.kms.<field>       (all products, one Vault)
  - DEDICATED → <product>.kms.<field>    (this product's own KMS config)

Precedence per field (backward-compatible):
  native configmap key  >  dedicated (<product>.kms)  >  shared (global.kms)  >  default

Standalone (no umbrella, no mask): falls through to the native key or the default →
render-equivalent, existing users unaffected.

Canonical fields: vendor (none|hashicorp-vault) | vaultAddr | vaultAuthMethod |
vaultRoleId | vaultMount. The AppRole SECRET (`KMS_VAULT_SECRET_ID`) is NOT
resolved here — it is credential material and goes to the chart's own Secret
(fail-fast when vendor=hashicorp-vault), exactly like datastore passwords.
==============================================================================
*/}}

{{/*
lerian-common.kms.value — resolve ONE KMS field via the mask.
Inputs (dict):
  context   (req)  product root ($)
  dedicated (opt)  the component's dedicated kms map (`<component>.kms`); when
                   omitted, `.context.Values.kms` is used (subchart mode)
  configmap (req)  the component's `.configmap` map (native key — top precedence)
  field     (req)  canonical field: vendor | vaultAddr | vaultAuthMethod | vaultRoleId | vaultMount
  nativeKey (req)  the product's real env key (e.g. KMS_VAULT_ADDR)
  default   (opt)  fallback when neither native key nor mask is set (keep it equal
                   to the pre-mask render so standalone stays byte-identical)
*/}}
{{- define "lerian-common.kms.value" -}}
{{- $cm := .configmap | default dict -}}
{{- $dedicated := .dedicated | default (.context.Values.kms | default dict) -}}
{{- $shared := (.context.Values.global | default dict).kms | default dict -}}
{{/* Ordered presence checks (not chained sprig `default`) so an explicit `false`
     at any tier — native key, dedicated, shared, or default — wins instead of
     falling through to a lower-priority value. */}}
{{- if hasKey $cm .nativeKey -}}
{{- index $cm .nativeKey -}}
{{- else if hasKey $dedicated .field -}}
{{- index $dedicated .field -}}
{{- else if hasKey $shared .field -}}
{{- index $shared .field -}}
{{- else if hasKey . "default" -}}
{{- .default -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}
