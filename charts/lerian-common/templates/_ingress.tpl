{{/*
==============================================================================
lerian-common — Ingress (standard Helm-scaffold shape) + shared contract.

Most chart ingresses are the standard scaffold: KubeVersion-aware apiVersion +
backend, ingressClassName (>=1.18), optional tls, and rules over hosts/paths.
Naming/labels are passed ALREADY RENDERED by the chart; the caller owns the
enable gate. Charts with a non-standard ingress keep it inline.

SHARED CONTRACT (optional): pass `global` (=.Values.global.ingress) and a
`subdomain`, and each field falls back to the umbrella-level default — so an
operator declares className/domain/annotations/tls ONCE and every product derives
its host as "<subdomain>.<domain>". Per-product values always win.

Resolution (per field):
  className   : <chart>.ingress.className  | global.ingress.className
  annotations : merge(global.ingress.annotations, <chart>.ingress.annotations)  (chart wins)
  tls         : <chart>.ingress.tls        | global.ingress.tls
  hosts       : <chart>.ingress.hosts (explicit list wins)
                else derived [{ host: "<subdomain>.<global.ingress.domain>", paths: [/ Prefix] }]

Standalone (no `global`): every field falls back to the chart's own ingress.* →
render is byte-equivalent to the previous hand-written scaffold.

Usage (chart ingress.yaml):
  {{- if .Values.fees.ingress.enabled -}}
  {{- include "lerian-common.ingress" (dict
        "context" .
        "ingress" .Values.fees.ingress
        "global" (.Values.global).ingress
        "subdomain" "fees"
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
  global    (opt)  `.Values.global.ingress` — shared contract defaults
  subdomain (opt)  host prefix used with global.ingress.domain to derive the host
  namespace (opt)  metadata.namespace (already rendered); omitted when empty
==============================================================================
*/}}
{{- define "lerian-common.ingress" -}}
{{- $ctx := .context -}}
{{- $ing := .ingress -}}
{{- $g := .global | default dict -}}
{{- $name := .name -}}
{{- $svcPort := .svcPort -}}
{{- $className := $ing.className | default $g.className -}}
{{- $annotations := merge (deepCopy ($g.annotations | default dict)) ($ing.annotations | default dict) -}}
{{- $tls := $g.tls -}}
{{- if hasKey $ing "tls" -}}{{- $tls = $ing.tls -}}{{- end -}}
{{- $hosts := $ing.hosts | default list -}}
{{- if and (eq (len $hosts) 0) $g.domain .subdomain -}}
{{- $hosts = list (dict "host" (printf "%s.%s" .subdomain $g.domain) "paths" (list (dict "path" "/" "pathType" "Prefix"))) -}}
{{- end -}}
{{- if and $className (not (semverCompare ">=1.18-0" $ctx.Capabilities.KubeVersion.GitVersion)) }}
  {{- if not (hasKey $annotations "kubernetes.io/ingress.class") }}
  {{- $_ := set $annotations "kubernetes.io/ingress.class" $className }}
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
  {{- with $annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if and $className (semverCompare ">=1.18-0" $ctx.Capabilities.KubeVersion.GitVersion) }}
  ingressClassName: {{ $className }}
  {{- end }}
  {{- if $tls }}
  tls:
    {{- range $tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
    {{- range $hosts }}
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
