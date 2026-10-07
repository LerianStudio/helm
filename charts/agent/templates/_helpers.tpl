{{/*
Fixed resource name. The agent is one-per-cluster by design (see
values.yaml hpa/pdb comments), so resource names are not templated with the
release name - this also keeps the chart's ClusterRole/ClusterRoleBinding
names stable and matches the existing kustomize manifests it replaces.
*/}}
{{- define "lerian-agent.name" -}}
lerian-agent
{{- end -}}

{{- define "lerian-agent.chart" -}}
{{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{/*
Common labels for all resources.
*/}}
{{- define "lerian-agent.labels" -}}
app.kubernetes.io/name: {{ include "lerian-agent.name" . }}
app.kubernetes.io/component: agent
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "lerian-agent.chart" . }}
{{- end -}}

{{/*
Selector labels. Includes the plain "app" label alongside the standard
app.kubernetes.io/* ones because the ported kustomize manifests select on
"app: lerian-agent" (Service, NetworkPolicy, PDB, HPA).
*/}}
{{- define "lerian-agent.selectorLabels" -}}
app: {{ include "lerian-agent.name" . }}
app.kubernetes.io/name: {{ include "lerian-agent.name" . }}
app.kubernetes.io/component: agent
{{- end -}}

{{/*
Name of the Secret holding agent credentials: either the one this chart
creates, or the caller's existingSecret.
*/}}
{{- define "lerian-agent.secretName" -}}
{{- if .Values.agent.existingSecret -}}
{{ .Values.agent.existingSecret }}
{{- else -}}
lerian-agent-credentials
{{- end -}}
{{- end -}}

{{/*
Name of the Secret holding the OCI chart-registry credential: either the one
this chart creates, or the caller's existingSecret. Separate from the agent's
own credentials Secret above because the two answer to different lifecycles -
the control-plane token is rotated by the control plane, a registry token by
whoever owns the registry.
*/}}
{{- define "lerian-agent.chartRegistrySecretName" -}}
{{- $registry := .Values.agent.chartRegistry | default dict -}}
{{- if $registry.existingSecret -}}
{{ $registry.existingSecret }}
{{- else -}}
lerian-agent-chart-registry
{{- end -}}
{{- end -}}

{{/*
The key the chart-owned credential Secret is written under: the registry host,
or a host followed by the repository prefix the credential is scoped to.

A repository prefix is passed straight through, because it is the LEAST
privilege form and the one to prefer: the agent matches a docker config key by
longest prefix at a path boundary, so "ghcr.io/lerianstudio" buys read access
to Lerian's charts and to nothing else on ghcr.io. Refusing it - which this
helper used to do, pointing at the allowlist - refused the recommended value.

Folded, because they all name one registry and an operator copies them out of a
chart reference: surrounding whitespace, case, ONE "oci://", "https://" or
"http://" scheme, and one trailing slash.

Two refusals, and only two. A credential with no host has no scope, and there
is no default because a guessed one would hand this password to a registry
nobody named. And a scheme surviving the fold is a second scheme, which names
nothing: stripping every scheme in a loop - which this helper used to do - made
"oci://https://evil.com" render as "evil.com", a host the agent then refuses at
boot, so the chart and the agent disagreed about the one value whose whole job
is to decide where a credential goes.

Everything else a host cannot be - whitespace inside it, credentials before it,
an empty port, the DNS root dot - is refused by the agent at boot, by the same
code that compares the key against a chart reference. Restating those here
bought nothing and drifted: the stacked scheme above is what drift looks like.
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
{{- fail "agent.chartRegistry.host is required alongside agent.chartRegistry.username/password: it is the registry the credential is keyed for, and there is no default because a guessed host would hand your registry token to a registry nobody named - agent.allowedChartRegistries deliberately admits registries that are not Lerian's." -}}
{{- end -}}
{{- if contains "://" $host -}}
{{- fail (printf "agent.chartRegistry.host %q carries a URL scheme after one was already removed; write a bare host such as \"ghcr.io\", or a host and organisation such as \"ghcr.io/lerianstudio\"." $raw) -}}
{{- end -}}
{{- /*
The host is lower-cased and the repository prefix is not: OCI path components
are lowercase by specification, so folding one would be the bypass rather than
the convenience. The agent splits the key at the same place.
*/ -}}
{{- if contains "/" $host -}}
{{- $parts := splitn "/" 2 $host -}}
{{ printf "%s/%s" (lower (index $parts "_0")) (index $parts "_1") }}
{{- else -}}
{{ lower $host }}
{{- end -}}
{{- end -}}

{{/*
Where the chart-registry credential is mounted in the agent's container, and
the file within it the agent reads. A whole-volume mount, never subPath: the
kubelet refreshes a projected Secret in place, and a subPath mount is the one
shape it cannot refresh - which would turn every rotation into a silent, stale
credential until somebody restarted the pod.
*/}}
{{- define "lerian-agent.chartRegistryMountPath" -}}
/etc/lerian/chart-registry
{{- end -}}

{{- define "lerian-agent.chartRegistryFile" -}}
{{ include "lerian-agent.chartRegistryMountPath" . }}/.dockerconfigjson
{{- end -}}
