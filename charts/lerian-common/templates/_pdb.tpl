{{/*
==============================================================================
lerian-common — PodDisruptionBudget (policy/v1).

Present in ~39 charts, near-identical. Naming/labels/selector are passed ALREADY
RENDERED by the chart's own helpers (byte-identical, no contract to unify); the
caller owns the enable gate. Two spec styles are supported via `specStyle`:

  "preferMax" (default, majority: fees/matcher/underwriter):
      with .maxUnavailable -> maxUnavailable; else -> minAvailable (| default N)
  "explicit" (tracer): emit minAvailable and/or maxUnavailable only when set

annotations render via toYaml; since no chart sets PDB annotations today this is
byte-identical to the range/quote style those charts used (empty -> nothing).

Usage (chart pdb.yaml):
  {{- if .Values.fees.pdb.enabled }}
  {{- include "lerian-common.pdb" (dict
        "pdb" .Values.fees.pdb
        "name" (include "plugin-fees.fullname" .)
        "labels" (include "plugin-fees.labels" (dict "context" . "name" .Values.fees.name))
        "selector" (include "plugin-fees.selectorLabels" (dict "context" . "name" .Values.fees.name))
        "minAvailableDefault" 0
      ) }}
  {{- end }}

Inputs (dict):
  pdb                 (req)  the component's `.pdb` map (minAvailable/maxUnavailable/annotations)
  name                (req)  metadata.name (already rendered)
  labels              (req)  labels block already rendered (no leading indent)
  selector            (req)  selector labels block already rendered (no leading indent)
  namespace           (opt)  metadata.namespace (already rendered); omitted when empty
  minAvailableDefault (opt)  default for minAvailable in "preferMax" (default 1; some charts use 0)
  specStyle           (opt)  "preferMax" (default) | "explicit"
==============================================================================
*/}}
{{- define "lerian-common.pdb" -}}
{{- $pdb := .pdb -}}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ .name }}
  {{- if .namespace }}
  namespace: {{ .namespace }}
  {{- end }}
  labels:
    {{- .labels | nindent 4 }}
  {{- with $pdb.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- /* hasKey (not truthiness) so an explicit 0 is honored, not treated as absent. */ -}}
  {{- $miDefault := 1 -}}
  {{- if hasKey . "minAvailableDefault" }}{{- $miDefault = .minAvailableDefault -}}{{- end }}
  {{- if eq (.specStyle | default "preferMax") "explicit" }}
  {{- if hasKey $pdb "minAvailable" }}
  minAvailable: {{ $pdb.minAvailable }}
  {{- end }}
  {{- if hasKey $pdb "maxUnavailable" }}
  maxUnavailable: {{ $pdb.maxUnavailable }}
  {{- end }}
  {{- else }}
  {{- if hasKey $pdb "maxUnavailable" }}
  maxUnavailable: {{ $pdb.maxUnavailable }}
  {{- else if hasKey $pdb "minAvailable" }}
  minAvailable: {{ $pdb.minAvailable }}
  {{- else }}
  minAvailable: {{ $miDefault }}
  {{- end }}
  {{- end }}
  selector:
    matchLabels:
      {{- .selector | nindent 6 }}
{{- end -}}
