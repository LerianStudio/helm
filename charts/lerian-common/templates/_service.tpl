{{/*
==============================================================================
lerian-common — Service (ClusterIP, single http port).

Near-identical across charts: a single `http` port with targetPort http. Naming,
labels and selector are passed ALREADY RENDERED by the chart's own helpers, so
the output is byte-identical and no naming/label contract must be unified. The
caller owns the enable gate. `namespace` and `annotations` are emitted only when
provided (some charts include them, some don't).

Usage (chart service.yaml):
  {{- include "lerian-common.service" (dict
        "service" .Values.fees.service
        "name" (include "plugin-fees.fullname" .)
        "labels" (include "plugin-fees.labels" (dict "context" . "name" .Values.fees.name))
        "selector" (include "plugin-fees.selectorLabels" (dict "context" . "name" .Values.fees.name))
      ) }}

Inputs (dict):
  service   (req)  the component's `.service` map (type, port, optional annotations)
  name      (req)  metadata.name (already rendered)
  labels    (req)  labels block already rendered (no leading indent)
  selector  (req)  selector labels block already rendered (no leading indent)
  namespace (opt)  metadata.namespace (already rendered); line omitted when empty
==============================================================================
*/}}
{{- define "lerian-common.service" -}}
{{- $svc := .service -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ .name }}
  {{- if .namespace }}
  namespace: {{ .namespace }}
  {{- end }}
  labels:
    {{- .labels | nindent 4 }}
  {{- with $svc.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ $svc.type }}
  ports:
    - port: {{ $svc.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- .selector | nindent 4 }}
{{- end -}}
