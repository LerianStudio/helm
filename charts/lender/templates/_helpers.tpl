{{/*
Expand the name of the chart.
*/}}
{{- define "lender.name" -}}
{{- default "lender" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name for the lender API component.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "lender.fullname" -}}
{{- default (include "lender.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified name for the lender console (UI) component.
*/}}
{{- define "lenderConsole.fullname" -}}
{{- $base := include "lender.fullname" . | trunc 55 | trimSuffix "-" }}
{{- printf "%s-console" $base | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "lender.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Resolve the lender API image tag (falls back to Chart.AppVersion).
*/}}
{{- define "lender.defaultTag" -}}
{{- default .Chart.AppVersion .Values.lender.image.tag }}
{{- end -}}

{{/*
Return valid lender version label value.
*/}}
{{- define "lender.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "lender.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "lender.labels" -}}
helm.sh/chart: {{ include "lender.chart" .context }}
{{ include "lender.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "lender.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "lender.selectorLabels" -}}
app.kubernetes.io/name: {{ include "lender.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "lender.serviceAccountName" -}}
{{- if .Values.lender.serviceAccount.create }}
{{- default (include "lender.fullname" .) .Values.lender.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.lender.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Expand the namespace of the release.
Allows overriding it for multi-namespace deployments in combined charts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Hardened security gate — render-time mirror of the lender application's own boot
validation: internal/bootstrap/config_validation.go (hardenedSecurityGateArmed,
validateHardenedSecurityConfig, normalizeSecurityModes,
validateExplicitSecurityModeEnvironment) and internal/bootstrap/tls_enforcement.go
(moneyPathRequiresTLS).

The application stays the authority: it re-validates every one of these at boot and
refuses to start when they fail. This gate exists only so the operator learns at
`helm install`/`helm upgrade` time instead of through a CrashLoopBackOff whose reason
is buried in the pod log. ANY drift between the two must be resolved in the
application's favour — fix this helper, never the application.

The Deployment injects the whole ConfigMap through envFrom, so every key declared in
lender.configmap is a SET environment variable in the container. A key present but
blank is therefore rejected exactly as the app rejects it; a key removed from an
overlay with `null` is genuinely absent and falls back to the app default
(ENV_NAME=development, DEPLOYMENT_MODE=local).
*/}}
{{- define "lender.validateHardenedSecurity" -}}
{{- $cm := .Values.lender.configmap | default dict -}}
{{- $rawEnvName := "development" -}}
{{- if hasKey $cm "ENV_NAME" -}}{{- $rawEnvName = $cm.ENV_NAME | toString -}}{{- end -}}
{{- $rawMode := "local" -}}
{{- if hasKey $cm "DEPLOYMENT_MODE" -}}{{- $rawMode = $cm.DEPLOYMENT_MODE | toString -}}{{- end -}}
{{- $envName := $rawEnvName | trim | lower -}}
{{- $mode := $rawMode | trim | lower -}}
{{- if not (has $envName (list "development" "local" "test" "staging" "production")) -}}
{{- fail (printf "\n\nlender.configmap.ENV_NAME=%q is not a valid environment.\nValid values: development, local, test, staging, production.\nThe lender application refuses to boot on any other value (internal/bootstrap/config_validation.go).\n" $rawEnvName) -}}
{{- end -}}
{{- if not (has $mode (list "local" "test" "staging" "production" "saas" "byoc")) -}}
{{- fail (printf "\n\nlender.configmap.DEPLOYMENT_MODE=%q is not a valid deployment mode.\nValid values: local, test, staging, production, saas, byoc.\nThe lender application refuses to boot on any other value (internal/bootstrap/config_validation.go).\n" $rawMode) -}}
{{- end -}}
{{/* strconv.ParseBool truthy set, lowercased — matching it exactly keeps the gate from
     rejecting a value ("1", "t") that the application would happily accept. */}}
{{- $truthy := list "true" "t" "1" -}}
{{- $ack := has ($cm.AUTH_M2M_INVERSION_ENABLED | default "false" | toString | trim | lower) $truthy -}}
{{- $tlsUpstream := has ($cm.TLS_TERMINATED_UPSTREAM | default "false" | toString | trim | lower) $truthy -}}
{{- $trustProxy := has ($cm.TRUST_PROXY_ENABLED | default "false" | toString | trim | lower) $truthy -}}
{{- $trustedProxies := $cm.TRUSTED_PROXIES | default "" | toString | trim -}}
{{- $armed := or (has $mode (list "saas" "production" "byoc")) (eq $envName "production") -}}
{{- if and $trustProxy (empty $trustedProxies) -}}
{{- fail (printf "\n\nlender.configmap.TRUST_PROXY_ENABLED=true with an empty lender.configmap.TRUSTED_PROXIES.\nThe lender application refuses to boot: trusting proxy headers with no trusted proxy list\nlets any client spoof the client IP.\nSet lender.configmap.TRUSTED_PROXIES to the ingress/load-balancer IPs or CIDRs (e.g. \"10.0.0.0/8\").\n") -}}
{{- end -}}
{{- if $armed -}}
{{- if not $ack -}}
{{- fail (printf "\n\nHardened deployment (DEPLOYMENT_MODE=%q, ENV_NAME=%q) requires the M2M inversion acknowledgement.\nSet:\n  lender.configmap.AUTH_M2M_INVERSION_ENABLED: \"true\"\nWhy: in a hardened posture the lender issues its own machine-to-machine credentials\ninstead of forwarding the caller's token. The flag is a conscious acknowledgement, so\nthe chart does not default it — the lender application refuses to boot without it\n(internal/bootstrap/config_validation.go).\nThe gate arms when DEPLOYMENT_MODE is one of saas, production, byoc, or ENV_NAME is production.\n" $mode $envName) -}}
{{- end -}}
{{- if and $tlsUpstream (or (not $trustProxy) (empty $trustedProxies)) -}}
{{- fail (printf "\n\nHardened deployment (DEPLOYMENT_MODE=%q, ENV_NAME=%q) with TLS_TERMINATED_UPSTREAM=true requires trusted proxies.\nSet BOTH:\n  lender.configmap.TRUST_PROXY_ENABLED: \"true\"\n  lender.configmap.TRUSTED_PROXIES: \"10.0.0.0/8\"   # ingress/load-balancer IPs or CIDRs\nWhy: TLS terminates upstream, so the client IP and scheme reach the lender only through\nproxy headers. Honouring those headers without a trusted proxy list would let any client\nspoof them — the lender application refuses to boot in that state\n(internal/bootstrap/config_validation.go).\n" $mode $envName) -}}
{{- end -}}
{{- end -}}
{{- end }}
