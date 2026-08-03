{{/*
==============================================================================
lerian-common — Auth env (plugin-access-manager).

Emits the auth ConfigMap keys from the shared `global.auth` contract, with the
component's own `configmap.<KEY>` overriding (same precedence as the other env
helpers). Enable is env-wide (global.auth.enabled) with per-component override.

The host env key differs per product (ledger uses PLUGIN_AUTH_HOST, crm uses
PLUGIN_AUTH_ADDRESS), so the caller passes `hostKey`.

Usage (component configmap.yaml):
  {{- include "lerian-common.auth.env" (dict
        "context" $ "configmap" .Values.ledger.configmap
        "hostKey" "PLUGIN_AUTH_HOST") | nindent 2 }}

Inputs (dict):
  context     (req)  root context ($) — reads global.auth
  configmap   (req)  the component's `.configmap` map (override source)
  hostKey     (req)  the host env key (PLUGIN_AUTH_HOST | PLUGIN_AUTH_ADDRESS)
  hostDefault (opt)  legacy default for the host key (keeps standalone identical)
==============================================================================
*/}}
{{- define "lerian-common.auth.env" -}}
PLUGIN_AUTH_ENABLED: {{ include "lerian-common.globalValue" (dict "context" .context "configmap" .configmap "block" "auth" "field" "enabled" "nativeKey" "PLUGIN_AUTH_ENABLED" "default" "false") | quote }}
{{ .hostKey }}: {{ include "lerian-common.globalValue" (dict "context" .context "configmap" .configmap "block" "auth" "field" "host" "nativeKey" .hostKey "default" (.hostDefault | default "")) | quote }}
{{- end -}}
