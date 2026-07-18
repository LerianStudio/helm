{{/*
==============================================================================
lerian-common — OpenTelemetry (lib-observability).

OTEL is common to ~all charts and fully DERIVABLE — there is no env-wide address
(the collector is a per-node DaemonSet reached via the pod's HOST_IP), so nothing
lives in global.*. Two helpers:

  - otel.env     → the ConfigMap block (resource identity + telemetry toggle)
  - otel.podEnv  → the Deployment env fragment (HOST_IP fieldRef + OTLP endpoint,
                   optionally POD_IP + resource attributes)

Both derive from the component's name/version and accept configmap overrides for
the few keys an operator may want to pin, so adoption is render-equivalent.
==============================================================================
*/}}

{{/*
lerian-common.otel.env — OTEL resource identity + telemetry config for the ConfigMap.
Derives service name/library from `name`, version from image tag (falling back to
the chart AppVersion), environment from ENV_NAME; each key is overridable via the
component configmap. Caller places the output under the ConfigMap `data:` and nindents.

Usage (in a component configmap.yaml):
  # OPEN TELEMETRY
  {{- include "lerian-common.otel.env" (dict
        "name" .Values.ledger.name
        "imageTag" .Values.ledger.image.tag
        "appVersion" .Chart.AppVersion
        "configmap" .Values.ledger.configmap
      ) | nindent 2 }}

Inputs (dict):
  name       (req)  component name — OTEL_RESOURCE_SERVICE_NAME + library suffix
  imageTag   (opt)  image tag — OTEL_RESOURCE_SERVICE_VERSION (else appVersion)
  appVersion (opt)  chart AppVersion — version fallback
  configmap  (opt)  component `.configmap` map — per-key override source
*/}}
{{- define "lerian-common.otel.env" -}}
{{- $cm := .configmap | default dict -}}
{{- $name := .name -}}
OTEL_RESOURCE_SERVICE_NAME: {{ index $cm "OTEL_RESOURCE_SERVICE_NAME" | default $name | quote }}
OTEL_LIBRARY_NAME: {{ index $cm "OTEL_LIBRARY_NAME" | default (printf "github.com/LerianStudio/%s" $name) | quote }}
OTEL_RESOURCE_SERVICE_VERSION: {{ .imageTag | default .appVersion | quote }}
OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT: {{ index $cm "ENV_NAME" | default "development" | quote }}
OTEL_EXPORTER_OTLP_ENDPOINT_PORT: {{ index $cm "OTEL_EXPORTER_OTLP_ENDPOINT_PORT" | default "4317" | quote }}
OTEL_EXPORTER_OTLP_ENDPOINT: {{ index $cm "OTEL_EXPORTER_OTLP_ENDPOINT" | default "" | quote }}
ENABLE_TELEMETRY: {{ index $cm "ENABLE_TELEMETRY" | default "true" | quote }}
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
