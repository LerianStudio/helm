{{/*
Expand the name of the chart.
*/}}
{{- define "lerian-agent.name" -}}
{{- default "lerian-agent" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name for the agent.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).

It is not derived from the release name on purpose: the agent is one per
cluster, and the name is part of its contract - the Deployment the self-update
may patch, the identity Secret beside it (<fullname>-identity) and every RBAC
object pinned to them by resourceNames.
*/}}
{{- define "lerian-agent.fullname" -}}
{{- default (include "lerian-agent.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "lerian-agent.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create agent app version
*/}}
{{- define "lerian-agent.defaultTag" -}}
{{- default .Chart.AppVersion .Values.agent.image.tag }}
{{- end -}}

{{/*
Return valid agent version label
*/}}
{{- define "lerian-agent.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "lerian-agent.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "lerian-agent.labels" -}}
helm.sh/chart: {{ include "lerian-agent.chart" .context }}
{{ include "lerian-agent.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "lerian-agent.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "lerian-agent.selectorLabels" -}}
app.kubernetes.io/name: {{ include "lerian-agent.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "lerian-agent.serviceAccountName" -}}
{{- if .Values.agent.serviceAccount.create }}
{{- default (include "lerian-agent.fullname" .) .Values.agent.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.agent.serviceAccount.name }}
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
The Secret holding the agent's control-plane credential: the one this chart
creates, or agent.existingSecretName.
*/}}
{{- define "lerian-agent.secretName" -}}
{{- if .Values.agent.useExistingSecret -}}
{{ required "agent.existingSecretName is required when agent.useExistingSecret is true" .Values.agent.existingSecretName }}
{{- else -}}
{{ include "lerian-agent.fullname" . }}
{{- end -}}
{{- end -}}

{{/*
The namespaces the agent may write to, as JSON. Blank entries are dropped
before the default applies: a list of only blank entries is the same statement
as no list at all, and letting it through would render a Role for no namespace.
*/}}
{{- define "lerian-agent.managedNamespaces" -}}
{{- .Values.agent.managedNamespaces | compact | uniq | default (list (include "global.namespace" .)) | toJson -}}
{{- end -}}

{{/*
A comma-separated configmap value as a JSON list, blank entries dropped.
*/}}
{{- define "lerian-agent.csv" -}}
{{- $out := list -}}
{{- range splitList "," (toString .) -}}
{{- with trim . }}{{ $out = append $out . }}{{ end -}}
{{- end -}}
{{- $out | toJson -}}
{{- end -}}

{{/*
The Secret holding the OCI chart-registry credential: the one this chart
creates, or agent.chartRegistry.existingSecret. Separate from the credential
Secret above because the two answer to different lifecycles - the control-plane
token is rotated by the control plane, a registry token by whoever owns the
registry.
*/}}
{{- define "lerian-agent.chartRegistrySecretName" -}}
{{- $registry := .Values.agent.chartRegistry | default dict -}}
{{- if $registry.existingSecret -}}
{{ $registry.existingSecret }}
{{- else -}}
{{ include "lerian-agent.fullname" . }}-chart-registry
{{- end -}}
{{- end -}}

{{/*
Whether a chart-registry credential is configured at all.
*/}}
{{- define "lerian-agent.chartRegistryEnabled" -}}
{{- $registry := .Values.agent.chartRegistry | default dict -}}
{{- if or $registry.username $registry.existingSecret }}true{{ end -}}
{{- end -}}

{{/*
The key the chart-owned registry credential is written under: a host, or a host
followed by the repository prefix the credential is scoped to
("ghcr.io/lerianstudio" - the least privilege form, and the one to prefer).

Folded: surrounding whitespace, the case of the HOST, ONE "oci://", "https://"
or "http://" scheme and one trailing slash. Refused: an empty host (a guessed
default would hand the password to a registry nobody named) and a second
scheme. Everything else a host cannot be is refused by the agent at boot, by
the same code that compares the key against a chart reference.
*/}}
{{- define "lerian-agent.chartRegistryHost" -}}
{{- $raw := (.Values.agent.chartRegistry | default dict).host | default "" -}}
{{- $host := $raw | trim -}}
{{- if hasPrefix "oci://" $host -}}
{{- $host = trimPrefix "oci://" $host -}}
{{- else if hasPrefix "https://" $host -}}
{{- $host = trimPrefix "https://" $host -}}
{{- else if hasPrefix "http://" $host -}}
{{- $host = trimPrefix "http://" $host -}}
{{- end -}}
{{- $host = trimSuffix "/" $host -}}
{{- if not $host -}}
{{- fail "agent.chartRegistry.host is required alongside agent.chartRegistry.username/password: it is the registry the credential is keyed for, and there is no default because a guessed host would hand your registry token to a registry nobody named." -}}
{{- end -}}
{{- if contains "://" $host -}}
{{- fail (printf "agent.chartRegistry.host %q carries a URL scheme after one was already removed; write a bare host such as \"ghcr.io\", or a host and organisation such as \"ghcr.io/lerianstudio\"." $raw) -}}
{{- end -}}
{{- if contains "/" $host -}}
{{- $parts := splitn "/" 2 $host -}}
{{ printf "%s/%s" (lower (index $parts "_0")) (index $parts "_1") }}
{{- else -}}
{{ lower $host }}
{{- end -}}
{{- end -}}

{{/*
Where the chart-registry credential is mounted, and the file the agent reads.
A whole-volume mount, never subPath: the kubelet refreshes a projected Secret
in place, and a subPath mount is the one shape it cannot refresh.
*/}}
{{- define "lerian-agent.chartRegistryMountPath" -}}
/etc/lerian/chart-registry
{{- end -}}

{{- define "lerian-agent.chartRegistryFile" -}}
{{ include "lerian-agent.chartRegistryMountPath" . }}/.dockerconfigjson
{{- end -}}

{{/*
The agent image. image.digest wins over image.tag when set, so a routine
`helm upgrade` cannot walk back a control-plane-driven self-update.
*/}}
{{- define "lerian-agent.image" -}}
{{- $image := .Values.agent.image -}}
{{- if and $image.digest (not (regexMatch "^sha256:[0-9a-f]{64}$" $image.digest)) -}}
{{- fail (printf "agent.image.digest must be written as sha256:<64 lowercase hex characters> (got %q): anything else renders an image reference the kubelet cannot pull." $image.digest) -}}
{{- end -}}
{{- if $image.digest -}}
{{ $image.repository }}@{{ $image.digest }}
{{- else -}}
{{ $image.repository }}:{{ include "lerian-agent.defaultTag" . }}
{{- end -}}
{{- end -}}

{{/*
The port a host names ("reg:5000", "[fd00::1]:8443"), or nothing.
*/}}
{{- define "lerian-agent.hostPort" -}}
{{- $afterHost := . -}}
{{- if contains "]" . }}{{ $afterHost = last (splitList "]" .) }}{{ end -}}
{{- if contains ":" $afterHost }}{{ last (splitList ":" $afterHost) }}{{ end -}}
{{- end -}}
