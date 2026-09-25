{{/*
==============================================================================
lerian-common — Deployment sub-blocks (pod-spec fragments).

The full Deployment is too variable to share, but these pod-spec tail fragments
are byte-identical across ~51 workloads. Each renders NOTHING when its value is
empty, so wrap the include in the caller so it only appears when present:

  {{- if or .Values.fees.nodeSelector .Values.fees.affinity .Values.fees.tolerations }}
      {{- include "lerian-common.scheduling" .Values.fees | nindent 6 }}
  {{- end }}
  {{- with .Values.fees.imagePullSecrets }}
      {{- include "lerian-common.imagePullSecrets" . | nindent 6 }}
  {{- end }}

Emitting at base indent 0 (keys) + toYaml nindent 2; the caller's `nindent 6`
shifts keys to col 6 and values to col 8 — matching the hand-written blocks.
*/}}

{{/*
lerian-common.scheduling — nodeSelector / affinity / tolerations.
Input: the component values map (reads .nodeSelector/.affinity/.tolerations).
*/}}
{{- define "lerian-common.scheduling" -}}
{{- with .nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{/*
lerian-common.imagePullSecrets — the imagePullSecrets block.
Input: the imagePullSecrets list (wrap the include in `{{- with }}` in the caller).
*/}}
{{- define "lerian-common.imagePullSecrets" -}}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end -}}

{{/*
lerian-common.deploymentStrategy — the `strategy:` block (type + optional
rollingUpdate). Byte-identical across the "type + if RollingUpdate" family
(~11 deployments) whose value shapes differ (flat `deploymentUpdate.*` vs
nested `deploymentStrategy.rollingUpdate.*`, some with inline `| default`).
The helper is shape-agnostic: the CALLER pre-resolves the three values (applying
its own defaults) so the output stays byte-identical.

Usage (flat deploymentUpdate shape):
  {{- include "lerian-common.deploymentStrategy" (dict
        "type" .Values.matcher.deploymentUpdate.type
        "maxSurge" .Values.matcher.deploymentUpdate.maxSurge
        "maxUnavailable" .Values.matcher.deploymentUpdate.maxUnavailable
      ) | nindent 2 }}

Usage (nested deploymentStrategy shape):
  {{- include "lerian-common.deploymentStrategy" (dict
        "type" .Values.manager.deploymentStrategy.type
        "maxSurge" .Values.manager.deploymentStrategy.rollingUpdate.maxSurge
        "maxUnavailable" .Values.manager.deploymentStrategy.rollingUpdate.maxUnavailable
      ) | nindent 2 }}

Inputs: type, maxSurge, maxUnavailable. Caller: nindent 2 (under spec:).
*/}}
{{- define "lerian-common.deploymentStrategy" -}}
strategy:
  type: {{ .type }}
  {{- if eq .type "RollingUpdate" }}
  rollingUpdate:
    maxSurge: {{ .maxSurge }}
    maxUnavailable: {{ .maxUnavailable }}
  {{- end }}
{{- end -}}

{{/*
lerian-common.httpProbe — one httpGet probe block (readiness/liveness/startup).
Probes appear in ~49 deployments with an identical structure but the ORDER and
DEFAULTS vary per chart, so this emits ONE block; the chart calls it once per
probe in its own order, passing its own defaults (byte-identical).

Usage (deployment.yaml, preserving the chart's existing probe order):
          {{- include "lerian-common.httpProbe" (dict
                "kind" "readinessProbe" "probe" .Values.fees.readinessProbe
                "port" .Values.fees.service.port
                "path" "/readyz" "initialDelay" 10 "period" 5 "timeout" 1 "success" 1 "failure" 3
              ) | nindent 10 }}
          {{- include "lerian-common.httpProbe" (dict
                "kind" "livenessProbe" "probe" .Values.fees.livenessProbe
                "port" .Values.fees.service.port
                "path" "/health" "initialDelay" 5 "period" 5 "timeout" 1 "success" 1 "failure" 3
              ) | nindent 10 }}

Inputs: kind, probe (values map), port, path, initialDelay, period, timeout, success, failure.
*/}}
{{- define "lerian-common.httpProbe" -}}
{{- $p := .probe | default dict -}}
{{ .kind }}:
  httpGet:
    path: {{ $p.path | default .path }}
    port: {{ .port }}
  {{- /* hasKey (not | default) so an explicit 0 override is honored, not treated as absent. */}}
  initialDelaySeconds: {{ if hasKey $p "initialDelaySeconds" }}{{ $p.initialDelaySeconds }}{{ else }}{{ .initialDelay }}{{ end }}
  periodSeconds: {{ if hasKey $p "periodSeconds" }}{{ $p.periodSeconds }}{{ else }}{{ .period }}{{ end }}
  timeoutSeconds: {{ if hasKey $p "timeoutSeconds" }}{{ $p.timeoutSeconds }}{{ else }}{{ .timeout }}{{ end }}
  successThreshold: {{ if hasKey $p "successThreshold" }}{{ $p.successThreshold }}{{ else }}{{ .success }}{{ end }}
  failureThreshold: {{ if hasKey $p "failureThreshold" }}{{ $p.failureThreshold }}{{ else }}{{ .failure }}{{ end }}
{{- end -}}
