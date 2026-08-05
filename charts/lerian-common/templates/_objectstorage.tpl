{{/*
==============================================================================
lerian-common — Object storage mask resolver (S3 / SeaweedFS).

Object storage is a DEPENDENCY connection (how the app reaches an S3/SeaweedFS
backend), so — like datastores — the operator writes a typed mask
(`objectStorage.ccs.bucket`) instead of the app's native env key
(`OBJECT_STORAGE_CCS_BUCKET`). Mirrors `lerian-common.datastore.value`, but keyed
by a backend NAME (an app may reach several buckets: br-ccs → ccs / fetcher / sta)
rather than a datastore TYPE.

  - SHARED    → global.objectStorage.<name>.<field>       (all products, one backend)
  - DEDICATED → <product>.objectStorage.<name>.<field>    (this product's own backend)

Precedence per field (backward-compatible):
  native configmap key  >  dedicated (<product>.objectStorage)  >  shared (global.objectStorage)  >  default

Standalone (no umbrella, no mask): falls through to the native key or the default →
render-equivalent, existing users unaffected. In an umbrella, `.context.Values` is
the subchart's root, so `.Values.objectStorage` = the per-product
`<product>.objectStorage` block (dedicated) and `.Values.global.objectStorage` =
the shared mask.

NOTE: masks only the NON-SECRET connection fields (endpoint / region / bucket /
disableSSL / usePathStyle). The credentials (`*_ACCESS_KEY_ID`, `*_SECRET_ACCESS_KEY`)
are NOT resolved here — they go to the chart's own Secret (fail-fast when the backend
is used), exactly like datastore passwords.
==============================================================================
*/}}

{{/*
lerian-common.objectStorage.value — resolve ONE object-storage field via the mask.
Inputs (dict):
  context   (req)  product root ($)
  dedicated (opt)  the component's dedicated objectStorage map (`<component>.objectStorage`)
                   for a monolithic parent chart; when omitted, `.context.Values.
                   objectStorage` is used (subchart mode)
  configmap (req)  the component's `.configmap` map (native key — top precedence)
  name      (req)  backend name: the mask sub-block (e.g. ccs | fetcher | sta | default)
  field     (req)  canonical field: endpoint | region | bucket | disableSSL | usePathStyle
  nativeKey (req)  the product's real env key (e.g. OBJECT_STORAGE_CCS_BUCKET)
  default   (opt)  fallback when neither native key nor mask is set (keep it equal
                   to the pre-mask render so standalone stays byte-identical)
*/}}
{{- define "lerian-common.objectStorage.value" -}}
{{- $cm := .configmap | default dict -}}
{{- /* Dedicated source: an explicit `dedicated` map (passed by a MONOLITHIC parent
   chart whose per-component masks live at `<component>.objectStorage`) takes
   precedence; otherwise fall back to `.context.Values.objectStorage`, which in a
   SUBCHART is that product's own block. */ -}}
{{- $dedicated := index (.dedicated | default (.context.Values.objectStorage | default dict)) .name | default dict -}}
{{- $shared := index ((.context.Values.global | default dict).objectStorage | default dict) .name | default dict -}}
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
