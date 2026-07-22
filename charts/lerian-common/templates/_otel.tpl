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
