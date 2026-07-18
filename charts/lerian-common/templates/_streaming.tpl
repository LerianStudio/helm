{{/*
==============================================================================
lerian-common — Streaming env (lib-streaming / RedPanda contract).

Streaming is becoming standard across all Lerian charts. This helper emits the
env-wide streaming CONSTANTS (broker + SASL/TLS transport) into a ConfigMap
`data` map from `global.streaming`, set once per environment. Per-app IDENTITY
(STREAMING_CLIENT_ID, STREAMING_CLOUDEVENTS_SOURCE) stays in each component
(extraEnvVars), same split as OTEL service identity. The SECRETS
(STREAMING_SASL_PASSWORD, STREAMING_TLS_CA_CERT) are emitted into the chart's own
Secret by the companion `lerian-common.streaming.secret` helper below (values are
per-component; never in the ConfigMap).

Like serviceDiscovery.env:
  - it does NOT emit STREAMING_ENABLED (that is the app's knob, rendered by the
    component's own extraEnvVars passthrough — emitting it here would duplicate);
  - it is backward-compatible: derives ONLY when enabled AND
    global.streaming.brokers is set, otherwise stays INERT so a not-yet-migrated
    environment (STREAMING_* still hand-set in extraEnvVars) renders unchanged.

Usage (in a component configmap.yaml, BEFORE the extraEnvVars passthrough):

  {{- $cv := .Values.ledger -}}
  {{- include "lerian-common.streaming.env" (dict
        "context" $
        "enabled" (eq (toString (dig "STREAMING_ENABLED" "false" ($cv.extraEnvVars | default dict))) "true")
        "name" $cv.name
      ) | nindent 2 }}

Inputs (dict):
  context  (req)  root context ($) — reads global.streaming
  enabled  (req)  bool — whether to emit the constants
  name     (opt)  fallback for STREAMING_CLIENT_ID / STREAMING_CLOUDEVENTS_SOURCE
                  when global.streaming.clientId / .cloudeventsSource are unset

global.streaming (all optional except brokers, which gates emission):
  brokers, tlsEnabled, saslMechanism, saslUsername,
  clientId          → STREAMING_CLIENT_ID (else falls back to `name`)
  cloudeventsSource → STREAMING_CLOUDEVENTS_SOURCE (else falls back to `name`)
==============================================================================
*/}}
{{- define "lerian-common.streaming.env" -}}
{{- $s := (.context.Values.global | default dict).streaming | default dict -}}
{{- if and .enabled $s.brokers -}}
STREAMING_BROKERS: {{ $s.brokers | quote }}
STREAMING_TLS_ENABLED: {{ $s.tlsEnabled | default false | quote }}
STREAMING_SASL_MECHANISM: {{ $s.saslMechanism | default "" | quote }}
STREAMING_SASL_USERNAME: {{ $s.saslUsername | default "" | quote }}
{{- /* Per-app identity: pulled from global.streaming; falls back to `name`. */ -}}
{{- $clientId := $s.clientId | default .name -}}
{{- if $clientId }}
STREAMING_CLIENT_ID: {{ $clientId | quote }}
{{- end }}
{{- $ceSource := $s.cloudeventsSource | default .name -}}
{{- if $ceSource }}
STREAMING_CLOUDEVENTS_SOURCE: {{ $ceSource | quote }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
------------------------------------------------------------------------------
lerian-common.streaming.secret — the uniform streaming Secret keys.

Companion to streaming.env: the .env helper emits the non-secret constants into
the ConfigMap; this one emits the SECRET keys into the chart's own Secret. Key
names are uniform across all charts (only the value differs per environment).

Emits nothing (and never fails) unless BOTH: the feature is enabled AND the chart
is not using an external Secret — the value lives outside the chart when
useExistingSecret=true, so requiring it inline is wrong. When active:
STREAMING_SASL_PASSWORD is required only when a SASL mechanism is configured (auth
in use) — i.e. enabled AND saslMechanism; STREAMING_TLS_CA_CERT is always optional.
For a required-but-empty key it fails with an actionable message (Bitnami-style),
on install AND upgrade (these values are operator/Vault-provided, never generated).

`mode` matches the chart's Secret form: "data" (b64enc) | "stringData". Output is
`KEY: value` lines with no leading/trailing newline; the caller nindents under the
matching `data:`/`stringData:` key:

  # STREAMING SECRETS
  {{- with (include "lerian-common.streaming.secret" (dict
        "context" . "secrets" .Values.ledger.secrets
        "secretName" (include "midaz.ledger.fullname" .)
        "valuesPrefix" "ledger.secrets." "mode" "data"
        "enabled" true "useExistingSecret" .Values.ledger.useExistingSecret
        "saslMechanism" (dig "streaming" "saslMechanism" "" (.Values.global | default dict)))) }}
  {{- . | nindent 2 }}
  {{- end }}

Inputs: context, secrets, secretName, valuesPrefix, mode,
        enabled (bool — STREAMING_ENABLED),
        useExistingSecret (bool — skip entirely when true),
        saslMechanism (string — when non-empty, SASL_PASSWORD becomes required).
------------------------------------------------------------------------------
*/}}
{{- define "lerian-common.streaming.secret" -}}
{{- if and .enabled (not .useExistingSecret) -}}
{{- $s := .secrets | default dict -}}
{{- $b64 := eq (.mode | default "stringData") "data" -}}
{{- $ns := .context.Release.Namespace -}}
{{- $lines := list -}}
{{- /* STREAMING_SASL_PASSWORD — required only when a SASL mechanism is set */ -}}
{{- $sasl := index $s "STREAMING_SASL_PASSWORD" -}}
{{- if and .saslMechanism (not $sasl) -}}
{{- fail (printf "\n[lerian-common] Secret value required but empty: STREAMING_SASL_PASSWORD\n  set:     --set %sSTREAMING_SASL_PASSWORD=<value>   (or configure an existingSecret)\n  recover: kubectl get secret %s -n %s -o jsonpath=\"{.data.STREAMING_SASL_PASSWORD}\" | base64 -d\n" .valuesPrefix .secretName $ns) -}}
{{- end -}}
{{- if $sasl -}}
{{- $lines = append $lines (printf "STREAMING_SASL_PASSWORD: %s" (ternary ($sasl | b64enc | quote) ($sasl | quote) $b64)) -}}
{{- end -}}
{{- /* STREAMING_TLS_CA_CERT — optional */ -}}
{{- $ca := index $s "STREAMING_TLS_CA_CERT" -}}
{{- if $ca -}}
{{- $lines = append $lines (printf "STREAMING_TLS_CA_CERT: %s" (ternary ($ca | b64enc | quote) ($ca | quote) $b64)) -}}
{{- end -}}
{{- join "\n" $lines -}}
{{- end -}}
{{- end -}}
