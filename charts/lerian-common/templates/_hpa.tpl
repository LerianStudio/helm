{{/*
==============================================================================
lerian-common — HorizontalPodAutoscaler (autoscaling/v2).

The HPA manifest is near-identical across ~40 workloads; only naming/labels and
the presence of a `namespace:` line differ per chart. This helper centralizes
the STRUCTURE (apiVersion, scaleTargetRef, cpu/memory metric blocks) and takes
naming/labels as strings ALREADY RENDERED by the chart's own helpers — so the
output stays byte-identical and no naming/label contract has to be unified first.

The caller owns the enable GATE (it varies: some charts also check the component
`.enabled`), so wrap the include in the chart's existing `{{- if ... }}`.

Usage (chart hpa.yaml):
  {{- if .Values.fees.autoscaling.enabled }}
  {{- include "lerian-common.hpa" (dict
        "autoscaling" .Values.fees.autoscaling
        "name" (include "plugin-fees.fullname" .)
        "labels" (include "plugin-fees.labels" (dict "context" . "name" .Values.fees.name))
      ) }}
  {{- end }}

Inputs (dict):
  autoscaling (req)  the component's `.autoscaling` map (minReplicas, maxReplicas,
                     targetCPUUtilizationPercentage, targetMemoryUtilizationPercentage)
  name        (req)  metadata.name (already rendered, e.g. include "<c>.fullname" .)
  labels      (req)  the labels block already rendered (no leading indent)
  namespace   (opt)  metadata.namespace (already rendered); omit the line when empty
  targetName  (opt)  scaleTargetRef.name (defaults to `name`)
==============================================================================
*/}}
{{- define "lerian-common.hpa" -}}
{{- $a := .autoscaling -}}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ .name }}
  {{- if .namespace }}
  namespace: {{ .namespace }}
  {{- end }}
  labels:
    {{- .labels | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ .targetName | default .name }}
  minReplicas: {{ $a.minReplicas }}
  maxReplicas: {{ $a.maxReplicas }}
  metrics:
    {{- if $a.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ $a.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if $a.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ $a.targetMemoryUtilizationPercentage }}
    {{- end }}
{{- end -}}
