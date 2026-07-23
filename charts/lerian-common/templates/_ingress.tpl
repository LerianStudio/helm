{{/*
==============================================================================
lerian-common — Ingress (standard Helm-scaffold shape).

23 of ~29 chart ingresses are the standard scaffold: KubeVersion-aware
apiVersion + backend, ingressClassName (>=1.18), optional tls, and rules over
hosts/paths. Naming/labels are passed ALREADY RENDERED by the chart; the caller
owns the enable gate. Charts with a non-standard ingress keep it inline.

Usage (chart ingress.yaml):
  {{- if .Values.fees.ingress.enabled -}}
  {{- include "lerian-common.ingress" (dict
        "context" .
        "ingress" .Values.fees.ingress
        "name" (include "plugin-fees.fullname" .)
        "labels" (include "plugin-fees.labels" (dict "context" . "name" .Values.fees.name))
        "svcPort" .Values.fees.service.port
      ) }}
  {{- end }}

Inputs (dict):
  context   (req)  root context ($) — for .Capabilities.KubeVersion
  ingress   (req)  the component's `.ingress` map (className/annotations/tls/hosts)
  name      (req)  metadata.name + backend service name (already rendered)
  labels    (req)  labels block already rendered (no leading indent)
  svcPort   (req)  backend service port
  namespace (opt)  metadata.namespace (already rendered); omitted when empty
==============================================================================
*/}}
{{- define "lerian-common.ingress" -}}
{{- $ctx := .context -}}
{{- $ing := .ingress -}}
{{- $name := .name -}}
{{- $svcPort := .svcPort -}}
{{- if and $ing.className (not (semverCompare ">=1.18-0" $ctx.Capabilities.KubeVersion.GitVersion)) }}
  {{- if not (hasKey $ing.annotations "kubernetes.io/ingress.class") }}
  {{- $_ := set $ing.annotations "kubernetes.io/ingress.class" $ing.className }}
  {{- end }}
{{- end }}
{{- if semverCompare ">=1.19-0" $ctx.Capabilities.KubeVersion.GitVersion -}}
apiVersion: networking.k8s.io/v1
{{- else if semverCompare ">=1.14-0" $ctx.Capabilities.KubeVersion.GitVersion -}}
apiVersion: networking.k8s.io/v1beta1
{{- else -}}
apiVersion: extensions/v1beta1
{{- end }}
kind: Ingress
metadata:
  name: {{ $name }}
  {{- if .namespace }}
  namespace: {{ .namespace }}
  {{- end }}
  labels:
    {{- .labels | nindent 4 }}
  {{- with $ing.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if and $ing.className (semverCompare ">=1.18-0" $ctx.Capabilities.KubeVersion.GitVersion) }}
  ingressClassName: {{ $ing.className }}
  {{- end }}
  {{- if $ing.tls }}
  tls:
    {{- range $ing.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
    {{- range $ing.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            {{- if and .pathType (semverCompare ">=1.18-0" $ctx.Capabilities.KubeVersion.GitVersion) }}
            pathType: {{ .pathType }}
            {{- end }}
            backend:
              {{- if semverCompare ">=1.19-0" $ctx.Capabilities.KubeVersion.GitVersion }}
              service:
                name: {{ $name }}
                port:
                  number: {{ $svcPort }}
              {{- else }}
              serviceName: {{ $name }}
              servicePort: {{ $svcPort }}
              {{- end }}
          {{- end }}
    {{- end }}
{{- end -}}
