{{/*
==============================================================================
lerian-common — Observability / OTEL env.

Emits the shared telemetry keys (ENABLE_TELEMETRY + OTEL exporter endpoint) from
the `global.observability` contract, with the component's `configmap.<KEY>`
overriding. Per-service OTEL IDENTITY (OTEL_RESOURCE_SERVICE_NAME/VERSION,
OTEL_LIBRARY_NAME) stays inline in each component (same split as streaming).

Usage (component configmap.yaml):
  {{- include "lerian-common.otel.env" (dict
        "context" $ "configmap" .Values.ledger.configmap) | nindent 2 }}

Inputs (dict):
  context         (req)  root context ($) — reads global.observability
  configmap       (req)  the component's `.configmap` map (override source)
  enabledDefault  (opt)  legacy default for ENABLE_TELEMETRY (default "false")
  endpointDefault (opt)  legacy default for the OTLP endpoint (default "midaz-grafana:4317")
  deploymentEnvironmentDefault (opt)  legacy default for OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT
                                      (default "production"); the shared env-wide value comes
                                      from global.observability.deploymentEnvironment
==============================================================================
*/}}
{{- define "lerian-common.otel.env" -}}
ENABLE_TELEMETRY: {{ include "lerian-common.globalValue" (dict "context" .context "configmap" .configmap "block" "observability" "field" "enabled" "nativeKey" "ENABLE_TELEMETRY" "default" (.enabledDefault | default "false")) | quote }}
OTEL_EXPORTER_OTLP_ENDPOINT: {{ include "lerian-common.globalValue" (dict "context" .context "configmap" .configmap "block" "observability" "field" "otlpEndpoint" "nativeKey" "OTEL_EXPORTER_OTLP_ENDPOINT" "default" (.endpointDefault | default "midaz-grafana:4317")) | quote }}
OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT: {{ include "lerian-common.globalValue" (dict "context" .context "configmap" .configmap "block" "observability" "field" "deploymentEnvironment" "nativeKey" "OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT" "default" (.deploymentEnvironmentDefault | default "production")) | quote }}
{{- end -}}

{{/*
lerian-common.otel.podEnv — OTEL runtime env for the Deployment container.
Points OTEL_EXPORTER_OTLP_ENDPOINT at the node-local collector via the downward
HOST_IP. With podAttributes=true it also adds POD_IP + OTEL_RESOURCE_ATTRIBUTES.
Caller gates on whether the collector is enabled and nindents (usually 10).

Usage (in a component deployment.yaml, inside `env:`):
  {{- if (index .Values "otel-collector-lerian").enabled }}
  {{- include "lerian-common.otel.podEnv" (dict "port" 4317) | nindent 10 }}
  {{- end }}

Inputs (dict):
  port          (opt)  OTLP port (default 4317)
  podAttributes (opt)  bool — also emit POD_IP + OTEL_RESOURCE_ATTRIBUTES
*/}}
{{- define "lerian-common.otel.podEnv" -}}
- name: "HOST_IP"
  valueFrom:
    fieldRef:
      fieldPath: status.hostIP
- name: "OTEL_EXPORTER_OTLP_ENDPOINT"
  value: "$(HOST_IP):{{ .port | default 4317 }}"
{{- if .podAttributes }}
- name: "POD_IP"
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
- name: "OTEL_RESOURCE_ATTRIBUTES"
  value: "k8s.pod.ip=$(POD_IP)"
{{- end }}
{{- end -}}

{{/*
==============================================================================
lerian-common.otel.envFlat — flat-passthrough OTEL block (no derivation).

Reproduces the chart's EXISTING native OTEL env block byte-for-byte. Unlike
`lerian-common.otel.env` (which DERIVES from `global.observability`), this is a
faithful mirror of the per-chart block, driven only by per-chart inputs.

Scope: the 6 OTEL keys every productized chart currently emits, in the shared
order — OTEL_RESOURCE_SERVICE_NAME, OTEL_LIBRARY_NAME,
OTEL_RESOURCE_SERVICE_VERSION, OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT,
OTEL_EXPORTER_OTLP_ENDPOINT_PORT, OTEL_EXPORTER_OTLP_ENDPOINT.
ENABLE_TELEMETRY is intentionally NOT emitted here — it stays inline in the
component configmap as its own knob (same split as `lerian-common.otel.env`).

The three OTEL identity values are chart-specific and NOT `configmap.<KEY>`
driven in the native templates:
  - OTEL_RESOURCE_SERVICE_NAME / OTEL_LIBRARY_NAME differ per component;
  - OTEL_RESOURCE_SERVICE_VERSION is `image.tag | default .Chart.AppVersion`
    (no configmap key at all);
  - OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT keys off configmap.OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT
    for midaz-ledger but off configmap.ENV_NAME for midaz-crm / plugin-fees.
So the CHART resolves each of these and passes it as the per-key `defaults`
entry (see uses). Because the corresponding key is absent from `.configmap`
under real values, `flatBlock` emits the supplied default — byte-identical to
the native render. See `lerian-common.env.flatBlock` for precedence/quoting.

Usage (component configmap.yaml — replaces the hand-written OTEL block):

  # midaz-ledger:
  {{- include "lerian-common.otel.envFlat" (dict
        "configmap" .Values.ledger.configmap
        "defaults" (dict
          "OTEL_RESOURCE_SERVICE_NAME" "ledger"
          "OTEL_LIBRARY_NAME" "github.com/LerianStudio/midaz/v3/components/ledger"
          "OTEL_RESOURCE_SERVICE_VERSION" (.Values.ledger.image.tag | default .Chart.AppVersion)
          "OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT" (.Values.ledger.configmap.OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT | default "production")))
    | nindent 2 }}

  # plugin-fees (endpoint default "" + deployment-env keyed off ENV_NAME):
  {{- include "lerian-common.otel.envFlat" (dict
        "configmap" .Values.fees.configmap
        "defaults" (dict
          "OTEL_RESOURCE_SERVICE_NAME" "plugin-fees"
          "OTEL_LIBRARY_NAME" "github.com/LerianStudio/plugin-fees"
          "OTEL_RESOURCE_SERVICE_VERSION" (.Values.fees.image.tag | default .Chart.AppVersion)
          "OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT" (.Values.fees.configmap.ENV_NAME | default "development")
          "OTEL_EXPORTER_OTLP_ENDPOINT" "")) | nindent 2 }}

Inputs (dict):
  configmap (req)  the component's `.configmap` map (native override source)
  keys      (opt)  ordered subset; defaults to the full 6-key block above
  defaults  (opt)  per-key default overrides (identity values live here; chart
                   defaults win over the standard defaults baked in here)
==============================================================================
*/}}
{{- define "lerian-common.otel.envFlat" -}}
{{- $std := dict
      "OTEL_RESOURCE_SERVICE_NAME" ""
      "OTEL_LIBRARY_NAME" ""
      "OTEL_RESOURCE_SERVICE_VERSION" ""
      "OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT" "production"
      "OTEL_EXPORTER_OTLP_ENDPOINT_PORT" "4317"
      "OTEL_EXPORTER_OTLP_ENDPOINT" "midaz-grafana:4317" -}}
{{- $keys := .keys | default (list
      "OTEL_RESOURCE_SERVICE_NAME"
      "OTEL_LIBRARY_NAME"
      "OTEL_RESOURCE_SERVICE_VERSION"
      "OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT"
      "OTEL_EXPORTER_OTLP_ENDPOINT_PORT"
      "OTEL_EXPORTER_OTLP_ENDPOINT") -}}
{{- include "lerian-common.env.flatBlock" (dict "configmap" .configmap "keys" $keys "defaults" (.defaults | default dict) "stdDefaults" $std) -}}
{{- end -}}
