{{/*
==============================================================================
lerian-common — ServiceAccount.

Identical across charts modulo naming/labels and the presence of a `namespace:`
line. Naming and labels are passed ALREADY RENDERED by the chart's own helpers,
so the output is byte-identical without unifying any contract. The caller owns
the create/enable gate. `namespace` and `annotations` are emitted only when set.

Usage (chart serviceaccount.yaml):
  {{- if .Values.fees.serviceAccount.create -}}
  {{- include "lerian-common.serviceAccount" (dict
        "serviceAccount" .Values.fees.serviceAccount
        "name" (include "plugin-fees.fullname" .)
        "labels" (include "plugin-fees.labels" (dict "context" . "name" .Values.fees.name))
      ) }}
  {{- end }}

Inputs (dict):
  serviceAccount (req)  the component's `.serviceAccount` map (optional annotations)
  name           (req)  metadata.name (already rendered)
  labels         (req)  labels block already rendered (no leading indent)
  namespace      (opt)  metadata.namespace (already rendered); line omitted when empty
==============================================================================
*/}}
{{- define "lerian-common.serviceAccount" -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .name }}
  {{- if .namespace }}
  namespace: {{ .namespace }}
  {{- end }}
  labels:
    {{- .labels | nindent 4 }}
  {{- with .serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end -}}
