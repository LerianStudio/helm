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
      ) | nindent 2 }}

Inputs (dict):
  context           (req)  root context ($) — reads global.streaming
  enabled           (req)  bool — whether to emit the constants
  clientId          (opt)  STREAMING_CLIENT_ID — emitted only when provided
  cloudeventsSource (opt)  STREAMING_CLOUDEVENTS_SOURCE — emitted only when provided
  configmap         (opt)  the component's legacy `.configmap` map. When a key is
                           present here, its flat `configmap.STREAMING_*` value
                           WINS over the global value below (backward-compat for
                           the flat configmap API). Defaults to an empty dict → every
                           key falls through to global/default (byte-identical to
                           a no-configmap caller, aside from the new knobs below).

global.streaming (all optional except brokers, which gates emission):
  brokers, tlsEnabled, saslMechanism, saslUsername, saslAllowPlaintext,
  compression, requiredAcks, batchLingerMs, importantEmitTimeoutMs
==============================================================================
*/}}
{{- define "lerian-common.streaming.env" -}}
{{- $s := (.context.Values.global | default dict).streaming | default dict -}}
{{- /* Legacy flat configmap source: a present `configmap.STREAMING_*` key WINS
   over the global value (mirrors multiTenant.env / serviceDiscovery.env). Empty
   dict when omitted. */ -}}
{{- $c := .configmap | default dict -}}
{{- /* Activate when enabled AND brokers are configured — via EITHER the env-wide
   global.streaming.brokers OR a legacy flat configmap.STREAMING_BROKERS (mirrors
   serviceDiscovery.env). Each key resolves by PRESENCE (hasKey) so an explicit
   configmap value survives even when it is a YAML false / 0 / "" — sprig `default`
   would treat those as empty and wrongly fall back to the global/derived value. */ -}}
{{- if and .enabled (or $s.brokers (hasKey $c "STREAMING_BROKERS")) -}}
{{- $brokers := $s.brokers -}}{{- if hasKey $c "STREAMING_BROKERS" -}}{{- $brokers = index $c "STREAMING_BROKERS" -}}{{- end -}}
{{- $tlsEnabled := ($s.tlsEnabled | default false) -}}{{- if hasKey $c "STREAMING_TLS_ENABLED" -}}{{- $tlsEnabled = index $c "STREAMING_TLS_ENABLED" -}}{{- end -}}
{{- $saslMechanism := ($s.saslMechanism | default "") -}}{{- if hasKey $c "STREAMING_SASL_MECHANISM" -}}{{- $saslMechanism = index $c "STREAMING_SASL_MECHANISM" -}}{{- end -}}
{{- $saslUsername := ($s.saslUsername | default "") -}}{{- if hasKey $c "STREAMING_SASL_USERNAME" -}}{{- $saslUsername = index $c "STREAMING_SASL_USERNAME" -}}{{- end -}}
{{- $saslAllowPlaintext := ($s.saslAllowPlaintext | default "false") -}}{{- if hasKey $c "STREAMING_SASL_ALLOW_PLAINTEXT" -}}{{- $saslAllowPlaintext = index $c "STREAMING_SASL_ALLOW_PLAINTEXT" -}}{{- end -}}
{{- $compression := ($s.compression | default "lz4") -}}{{- if hasKey $c "STREAMING_COMPRESSION" -}}{{- $compression = index $c "STREAMING_COMPRESSION" -}}{{- end -}}
{{- $requiredAcks := ($s.requiredAcks | default "all") -}}{{- if hasKey $c "STREAMING_REQUIRED_ACKS" -}}{{- $requiredAcks = index $c "STREAMING_REQUIRED_ACKS" -}}{{- end -}}
{{- $batchLingerMs := ($s.batchLingerMs | default "5") -}}{{- if hasKey $c "STREAMING_BATCH_LINGER_MS" -}}{{- $batchLingerMs = index $c "STREAMING_BATCH_LINGER_MS" -}}{{- end -}}
{{- $importantEmitTimeoutMs := ($s.importantEmitTimeoutMs | default "5000") -}}{{- if hasKey $c "STREAMING_IMPORTANT_EMIT_TIMEOUT_MS" -}}{{- $importantEmitTimeoutMs = index $c "STREAMING_IMPORTANT_EMIT_TIMEOUT_MS" -}}{{- end -}}
{{- /* SASL contract validation — lib-streaming fails closed at bootstrap otherwise.
   Enforced here in the ConfigMap (which ALWAYS renders, even when the Secret is external
   via useExistingSecret), so mechanism/username/TLS are validated regardless of the secret
   source. When a mechanism is set it must be a supported one, a username is required, and
   TLS must be on unless plaintext SASL is explicitly opted into. */ -}}
{{- /* Normalize like lib-streaming does: the mechanism is case-insensitive and
   TrimSpace'd, and an all-whitespace value means "no SASL" (disabled). The booleans
   follow strconv.ParseBool (case-insensitive true/1/t). Validate on the normalized
   values so a valid lowercase/whitespace-padded config is not falsely rejected. */ -}}
{{- $saslMechNorm := upper (trim (toString $saslMechanism)) -}}
{{- if $saslMechNorm -}}
{{- $allowedSasl := list "PLAIN" "SCRAM-SHA-256" "SCRAM-SHA-512" -}}
{{- if not (has $saslMechNorm $allowedSasl) -}}
{{- fail (printf "\n[lerian-common] Unsupported STREAMING_SASL_MECHANISM %q — lib-streaming accepts only PLAIN, SCRAM-SHA-256, SCRAM-SHA-512 (case-insensitive).\n" $saslMechanism) -}}
{{- end -}}
{{- if not (trim (toString $saslUsername)) -}}
{{- fail (printf "\n[lerian-common] Value required but empty: STREAMING_SASL_USERNAME\n  a SASL mechanism (%s) is set, which requires a username (and a password).\n  set:     configmap.STREAMING_SASL_USERNAME (or global.streaming.saslUsername)\n" $saslMechanism) -}}
{{- end -}}
{{- /* Match strconv.ParseBool EXACTLY (what the runtime's GetenvBoolOrDefault uses): the
   true set is 1/t/T/TRUE/true/True with no trimming — anything else (e.g. "TrUe", " true ")
   parses as an error and the runtime falls back to false. Using lower()/trim() here would
   wrongly accept those and ship a SASL-without-TLS config that crashes at bootstrap. */ -}}
{{- $parseBoolTrue := list "1" "t" "T" "TRUE" "true" "True" -}}
{{- $tlsOn := has (toString $tlsEnabled) $parseBoolTrue -}}
{{- $plaintextOn := has (toString $saslAllowPlaintext) $parseBoolTrue -}}
{{- if not (or $tlsOn $plaintextOn) -}}
{{- fail (printf "\n[lerian-common] SASL requires TLS: mechanism %s is set but STREAMING_TLS_ENABLED is not true.\n  set:     STREAMING_TLS_ENABLED=true (recommended), or opt into plaintext SASL with STREAMING_SASL_ALLOW_PLAINTEXT=true.\n" $saslMechanism) -}}
{{- end -}}
{{- end -}}
STREAMING_BROKERS: {{ $brokers | quote }}
STREAMING_TLS_ENABLED: {{ $tlsEnabled | quote }}
STREAMING_SASL_MECHANISM: {{ $saslMechanism | quote }}
STREAMING_SASL_USERNAME: {{ $saslUsername | quote }}
STREAMING_SASL_ALLOW_PLAINTEXT: {{ $saslAllowPlaintext | quote }}
STREAMING_COMPRESSION: {{ $compression | quote }}
STREAMING_REQUIRED_ACKS: {{ $requiredAcks | quote }}
STREAMING_BATCH_LINGER_MS: {{ $batchLingerMs | quote }}
STREAMING_IMPORTANT_EMIT_TIMEOUT_MS: {{ $importantEmitTimeoutMs | quote }}
{{- if hasKey . "clientId" }}
{{- $clientId := .clientId -}}{{- if hasKey $c "STREAMING_CLIENT_ID" -}}{{- $clientId = index $c "STREAMING_CLIENT_ID" -}}{{- end }}
STREAMING_CLIENT_ID: {{ $clientId | quote }}
{{- end }}
{{- if hasKey . "cloudeventsSource" }}
{{- $cloudeventsSource := .cloudeventsSource -}}{{- if hasKey $c "STREAMING_CLOUDEVENTS_SOURCE" -}}{{- $cloudeventsSource = index $c "STREAMING_CLOUDEVENTS_SOURCE" -}}{{- end }}
STREAMING_CLOUDEVENTS_SOURCE: {{ $cloudeventsSource | quote }}
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
  # Resolve mechanism + username with the SAME configmap-over-global precedence the
  # ConfigMap uses (streaming.env), so a ConfigMap-only mechanism is still validated and
  # a ConfigMap-only username does not cause a false failure. An explicit empty ConfigMap
  # value is preserved (hasKey) so validation still fails when it should.
  {{- $saslMech := (((.Values.global | default dict).streaming | default dict).saslMechanism | default "") }}
  {{- if hasKey .Values.ledger.configmap "STREAMING_SASL_MECHANISM" }}{{- $saslMech = index .Values.ledger.configmap "STREAMING_SASL_MECHANISM" }}{{- end }}
  {{- $saslUser := (((.Values.global | default dict).streaming | default dict).saslUsername | default "") }}
  {{- if hasKey .Values.ledger.configmap "STREAMING_SASL_USERNAME" }}{{- $saslUser = index .Values.ledger.configmap "STREAMING_SASL_USERNAME" }}{{- end }}
  {{- with (include "lerian-common.streaming.secret" (dict
        "context" . "secrets" .Values.ledger.secrets
        "secretName" (include "midaz.ledger.fullname" .)
        "valuesPrefix" "ledger.secrets." "mode" "data"
        "enabled" true "useExistingSecret" .Values.ledger.useExistingSecret
        "saslMechanism" $saslMech "saslUsername" $saslUser)) }}
  {{- . | nindent 2 }}
  {{- end }}

Inputs: context, secrets, secretName, valuesPrefix, mode,
        enabled (bool — STREAMING_ENABLED),
        useExistingSecret (bool — skip entirely when true),
        saslMechanism (string — when non-empty, both SASL_USERNAME and SASL_PASSWORD become required),
        saslUsername (string — the resolved STREAMING_SASL_USERNAME; required when saslMechanism is set).
------------------------------------------------------------------------------
*/}}
{{- define "lerian-common.streaming.secret" -}}
{{- if and .enabled (not .useExistingSecret) -}}
{{- $s := .secrets | default dict -}}
{{- $b64 := eq (.mode | default "stringData") "data" -}}
{{- $ns := .context.Release.Namespace -}}
{{- $lines := list -}}
{{- /* STREAMING_SASL_USERNAME — required (with the password) whenever a SASL mechanism
   is set; lib-streaming rejects a mechanism without BOTH credentials. The username is a
   ConfigMap value (not a secret), resolved by the caller with the same precedence
   (configmap.STREAMING_SASL_USERNAME -> global.streaming.saslUsername) and passed here so
   the render fails fast instead of shipping a boot-crashing config. */ -}}
{{- if and .saslMechanism (not .saslUsername) -}}
{{- fail (printf "\n[lerian-common] Value required but empty: STREAMING_SASL_USERNAME\n  a SASL mechanism (%s) is set, which requires both a username and a password.\n  set:     configmap.STREAMING_SASL_USERNAME (or global.streaming.saslUsername)\n" .saslMechanism) -}}
{{- end -}}
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
