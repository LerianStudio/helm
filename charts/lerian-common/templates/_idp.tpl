{{/*
==============================================================================
lerian-common — Access Manager permission declaration (IDP_*).

lib-auth's `declaration.WireFromEnv` publishes the app's permission manifest to
the Access Manager at boot. It reads four env keys:

  IDP_DECLARATION_ENABLED  ConfigMap  gate, "true" | "false"
  IDP_HOST                 ConfigMap  Access Manager identity base URL
  IDP_M2M_CLIENT_ID        Secret     M2M client the app publishes with
  IDP_M2M_CLIENT_SECRET    Secret

With the gate on, the app refuses to boot without the host and the client pair,
so the gate is per component and the credentials are per component; only the
host is a natural env-wide constant.

Helpers:
  lerian-common.idp.env     ConfigMap lines (IDP_DECLARATION_ENABLED, IDP_HOST)
  lerian-common.idp.secret  Secret lines (IDP_M2M_CLIENT_ID, IDP_M2M_CLIENT_SECRET)
  lerian-common.idp.keys    JSON list of the keys a helper owns, so a chart can
                            skip them in its generic ranges / extraEnvVars
                            passthrough (a duplicate key is rejected server-side)
==============================================================================
*/}}

{{/*
lerian-common.idp.keys — the keys the helpers below own, as a JSON list.

Inputs (dict):
  kind (opt)  "env" (ConfigMap keys) | "secret" (Secret keys) | "" (all four)

Usage:
  {{- $idpEnvKeys := include "lerian-common.idp.keys" (dict "kind" "env") | fromJsonArray }}
  {{- range $k, $v := .Values.app.configmap }}
  {{- if not (has $k $idpEnvKeys) }}
  {{ $k }}: {{ $v | quote }}
  {{- end }}
  {{- end }}
*/}}
{{- define "lerian-common.idp.keys" -}}
{{- $env := list "IDP_DECLARATION_ENABLED" "IDP_HOST" -}}
{{- $secret := list "IDP_M2M_CLIENT_ID" "IDP_M2M_CLIENT_SECRET" -}}
{{- $kind := (. | default dict).kind | default "" -}}
{{- if eq $kind "env" -}}
{{- toJson $env -}}
{{- else if eq $kind "secret" -}}
{{- toJson $secret -}}
{{- else -}}
{{- toJson (concat $env $secret) -}}
{{- end -}}
{{- end -}}

{{/*
lerian-common.idp.env — ConfigMap keys of the permission declaration.

Precedence (presence-based, so an explicit "false" wins):
  configmap.<KEY>  >  extraEnvVars.<KEY> (legacy)  >  global.idp.<field>  >  default

  IDP_DECLARATION_ENABLED  field `declarationEnabled`, default "false", ALWAYS emitted
  IDP_HOST                 field `host`, default "", emitted only when non-empty

`extraEnvVars` is a compatibility input: environments that set the gate and the
host through the component's extraEnvVars before this helper existed keep
working. The caller must then skip the env keys in its extraEnvVars passthrough
(see lerian-common.idp.keys) so they are not emitted twice.

Setting global.idp.declarationEnabled turns the gate on for EVERY component of
the release, and each of them then needs its own client pair; prefer the
component's configmap for the gate and global.idp.host for the host.

Usage (component configmap.yaml, under `data:`):
  {{- include "lerian-common.idp.env" (dict
        "context" $ "configmap" .Values.app.configmap
        "extraEnvVars" .Values.app.extraEnvVars) | nindent 2 }}

Inputs (dict):
  context      (req)  root context ($) — reads global.idp
  configmap    (req)  the component's `.configmap` map (top precedence)
  extraEnvVars (opt)  the component's `.extraEnvVars` map (legacy override)
*/}}
{{- define "lerian-common.idp.env" -}}
{{- $cm := deepCopy (.configmap | default dict) -}}
{{- $extra := .extraEnvVars | default dict -}}
{{- range $k := include "lerian-common.idp.keys" (dict "kind" "env") | fromJsonArray -}}
{{- if and (hasKey $extra $k) (not (hasKey $cm $k)) -}}
{{- $_ := set $cm $k (index $extra $k) -}}
{{- end -}}
{{- end -}}
{{- $enabled := include "lerian-common.globalValue" (dict "context" .context "configmap" $cm "block" "idp" "field" "declarationEnabled" "nativeKey" "IDP_DECLARATION_ENABLED" "default" "false") -}}
{{- $host := include "lerian-common.globalValue" (dict "context" .context "configmap" $cm "block" "idp" "field" "host" "nativeKey" "IDP_HOST" "default" "") -}}
IDP_DECLARATION_ENABLED: {{ $enabled | quote }}
{{- if ne (trim $host) "" }}
IDP_HOST: {{ $host | quote }}
{{- end -}}
{{- end -}}

{{/*
lerian-common.idp.secret — Secret keys of the permission declaration.

Emits IDP_M2M_CLIENT_ID / IDP_M2M_CLIENT_SECRET from the component's secrets
map, each one only when set to a non-empty value, so an unset key never masks
the same key from another Secret earlier in envFrom. Emits nothing with
useExistingSecret (the pair then lives in the operator's Secret). Returns
`KEY: value` lines with no leading/trailing newline; the caller nindents them
under the matching `data:`/`stringData:` key (guard with `with` so an empty
result leaves no blank line):

  {{- with (include "lerian-common.idp.secret" (dict
        "secrets" .Values.app.secrets "mode" "data"
        "useExistingSecret" .Values.app.useExistingSecret)) }}
  {{- . | nindent 2 }}
  {{- end }}

Inputs (dict):
  secrets           (req)  the map holding IDP_M2M_CLIENT_ID / IDP_M2M_CLIENT_SECRET
  mode              (opt)  "stringData" (default, plain) | "data" (base64)
  useExistingSecret (opt)  bool — emit nothing when true
*/}}
{{- define "lerian-common.idp.secret" -}}
{{- if not .useExistingSecret -}}
{{- $s := .secrets | default dict -}}
{{- $b64 := eq (.mode | default "stringData") "data" -}}
{{- $lines := list -}}
{{- range $k := include "lerian-common.idp.keys" (dict "kind" "secret") | fromJsonArray -}}
{{- $v := toString (index $s $k | default "") -}}
{{- if ne $v "" -}}
{{- $lines = append $lines (printf "%s: %s" $k (ternary ($v | b64enc | quote) ($v | quote) $b64)) -}}
{{- end -}}
{{- end -}}
{{- join "\n" $lines -}}
{{- end -}}
{{- end -}}
