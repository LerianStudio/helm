{{/*
==============================================================================
lerian-common — Streaming env (lib-streaming / RedPanda contract).

Streaming is becoming standard across all Lerian charts. This helper emits the
env-wide streaming CONSTANTS (broker + SASL/TLS transport) into a ConfigMap
`data` map from `global.streaming`, set once per environment. Per-app IDENTITY
(STREAMING_CLIENT_ID, STREAMING_CLOUDEVENTS_SOURCE) and the SECRETS
(STREAMING_SASL_PASSWORD, STREAMING_TLS_CA_CERT) are NOT env-wide — they stay in
each component (extraEnvVars / secrets), same split as OTEL service identity.

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
      ) | nindent 2 }}

Inputs (dict):
  context           (req)  root context ($) — reads global.streaming
  enabled           (req)  bool — whether to emit the constants
  clientId          (opt)  STREAMING_CLIENT_ID — emitted only when provided
  cloudeventsSource (opt)  STREAMING_CLOUDEVENTS_SOURCE — emitted only when provided

global.streaming (all optional except brokers, which gates emission):
  brokers, tlsEnabled, saslMechanism, saslUsername
==============================================================================
*/}}
{{- define "lerian-common.streaming.env" -}}
{{- $s := (.context.Values.global | default dict).streaming | default dict -}}
{{- if and .enabled $s.brokers -}}
STREAMING_BROKERS: {{ $s.brokers | quote }}
STREAMING_TLS_ENABLED: {{ $s.tlsEnabled | default false | quote }}
STREAMING_SASL_MECHANISM: {{ $s.saslMechanism | default "" | quote }}
STREAMING_SASL_USERNAME: {{ $s.saslUsername | default "" | quote }}
{{- if hasKey . "clientId" }}
STREAMING_CLIENT_ID: {{ .clientId | quote }}
{{- end }}
{{- if hasKey . "cloudeventsSource" }}
STREAMING_CLOUDEVENTS_SOURCE: {{ .cloudeventsSource | quote }}
{{- end }}
{{- end -}}
{{- end -}}
