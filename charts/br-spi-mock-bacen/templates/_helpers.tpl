{{/*
Expand the name of the chart.
*/}}
{{- define "br-spi-mock-bacen.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name, truncated at 63 chars for the DNS label limit.

Release-aware: two releases in the same namespace would otherwise render
identically named objects and the second install would fail on resources owned
by the first. The name collapses to the bare chart name when the release name
already contains it, so the canonical release (`helm install br-spi-mock-bacen`)
still renders `br-spi-mock-bacen` and the documented service name is unchanged.
*/}}
{{- define "br-spi-mock-bacen.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := include "br-spi-mock-bacen.name" . }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart name and version as used by the chart label.
*/}}
{{- define "br-spi-mock-bacen.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the namespace of the release. Overridable for multi-namespace layouts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Image tag, sanitized so it is a valid label value.
*/}}
{{- define "br-spi-mock-bacen.versionLabelValue" -}}
{{- $tag := default .Chart.AppVersion .Values.app.image.tag -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" $tag "-" | trunc 63 | trimAll "-" | quote }}
{{- end }}

{{/*
Selector labels — stable across image bumps.
*/}}
{{- define "br-spi-mock-bacen.selectorLabels" -}}
app.kubernetes.io/name: {{ include "br-spi-mock-bacen.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
br-spi-mock-bacen.reservedLabelKeys — the label keys this chart owns.

app.kubernetes.io/name and app.kubernetes.io/instance are the Deployment
selector: an operator value there would detach the Pods from their Deployment.
The rest would render a duplicate YAML key. Operator labels that collide with
any of them are dropped rather than merged.
*/}}
{{- define "br-spi-mock-bacen.reservedLabelKeys" -}}
{{- list "helm.sh/chart" "app.kubernetes.io/name" "app.kubernetes.io/instance" "app.kubernetes.io/version" "app.kubernetes.io/managed-by" "app.kubernetes.io/part-of" | toJson -}}
{{- end }}

{{/*
Common labels. global.commonLabels is appended so an operator can tag the whole
release without editing every template, minus the chart-owned keys above.
*/}}
{{- define "br-spi-mock-bacen.labels" -}}
{{- $reserved := include "br-spi-mock-bacen.reservedLabelKeys" . | fromJsonArray -}}
{{- $extra := dict -}}
{{- range $key, $value := ((.Values.global | default dict).commonLabels | default dict) -}}
{{- if not (has $key $reserved) -}}
{{- $_ := set $extra $key $value -}}
{{- end -}}
{{- end -}}
helm.sh/chart: {{ include "br-spi-mock-bacen.chart" . }}
{{ include "br-spi-mock-bacen.selectorLabels" . }}
app.kubernetes.io/version: {{ include "br-spi-mock-bacen.versionLabelValue" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: br-sfn
{{- with $extra }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Common annotations, applied to every rendered object.
*/}}
{{- define "br-spi-mock-bacen.commonAnnotations" -}}
{{- with (.Values.global | default dict).commonAnnotations }}
{{- toYaml . }}
{{- end }}
{{- end }}

{{/*
Name of the service account to use.
*/}}
{{- define "br-spi-mock-bacen.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "br-spi-mock-bacen.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
------------------------------------------------------------------------------
br-spi-mock-bacen.image — the fully qualified image reference.

`global.imageRegistry` prefixes the repository when set, so an air-gapped or
mirrored registry is a single top-level override. An empty tag falls back to
.Chart.AppVersion.
------------------------------------------------------------------------------
*/}}
{{- define "br-spi-mock-bacen.image" -}}
{{- $registry := ((.Values.global | default dict).imageRegistry | default "") -}}
{{- /* An empty repository printf'd to ":<tag>" is valid YAML but rejected at
   admission with InvalidImageName. Fail at render with the value to set. */ -}}
{{- $repository := required "\n\nERROR: app.image.repository is empty.\nAn empty repository renders as \":<tag>\", which the API server rejects with\nInvalidImageName. Set app.image.repository (default: ghcr.io/lerianstudio/br-spi-mock-bacen).\n" (.Values.app.image.repository | default "") -}}
{{- if $registry -}}
{{- $repository = printf "%s/%s" (trimSuffix "/" $registry) $repository -}}
{{- end -}}
{{- printf "%s:%s" $repository (.Values.app.image.tag | default .Chart.AppVersion) -}}
{{- end }}

{{/*
------------------------------------------------------------------------------
br-spi-mock-bacen.validateEnvironment — production block.

This chart deploys a BACEN SIMULATOR with unauthenticated /control/* endpoints.
It must never run in a production-like environment. `environment` is the single
public value; the ConfigMap renders ENV_NAME from it, and the binary itself
fails closed on any other value. The gate is enforced here so the render stops
before anything reaches a cluster.
------------------------------------------------------------------------------
*/}}
{{- define "br-spi-mock-bacen.validateEnvironment" -}}
{{- $allowed := list "local" "development" "test" "ci" -}}
{{- $env := toString (.Values.environment | default "") -}}
{{- if not (has $env $allowed) -}}
{{- fail (printf "\n\nERROR: environment=%q is not allowed for br-spi-mock-bacen.\n   This chart deploys a BACEN simulator with UNAUTHENTICATED /control/* endpoints.\n   It must never be rendered for a production-like environment.\n   Set environment to one of: %s\n" $env (join ", " $allowed)) -}}
{{- end -}}
{{- end }}

{{/*
------------------------------------------------------------------------------
br-spi-mock-bacen.validateService — exposure block.

The mock has no authentication, so only an in-cluster ClusterIP Service is a
valid exposure. LoadBalancer/NodePort would publish /control/* to the network.
------------------------------------------------------------------------------
*/}}
{{- define "br-spi-mock-bacen.validateService" -}}
{{- $type := toString (.Values.app.service.type | default "") -}}
{{- if ne $type "ClusterIP" -}}
{{- fail (printf "\n\nERROR: app.service.type=%q is not allowed for br-spi-mock-bacen.\n   The mock exposes UNAUTHENTICATED /control/* endpoints, so only an in-cluster\n   ClusterIP Service is supported. Use kubectl port-forward for manual access.\n" $type) -}}
{{- end -}}
{{- end }}

{{/*
------------------------------------------------------------------------------
br-spi-mock-bacen.configmapData — the ConfigMap payload.

ENV_NAME is RESERVED and always rendered from .Values.environment, so the
public value and the container env cannot drift. Any ENV_NAME supplied inside
app.configmap is dropped here (values.schema.json also rejects it outright).
Remaining keys render in sorted order so the checksum is deterministic.
------------------------------------------------------------------------------
*/}}
{{- define "br-spi-mock-bacen.configmapData" -}}
ENV_NAME: {{ .Values.environment | quote }}
{{- $free := omit (.Values.app.configmap | default dict) "ENV_NAME" }}
{{- range $key, $value := $free }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}

{{/*
------------------------------------------------------------------------------
br-spi-mock-bacen.containerPort — the port the binary actually listens on.

The mock reads its listener from MOCK_BACEN_PORT (":9900" form). Deriving the
containerPort from that same key keeps the Pod spec and the process in sync
instead of hardcoding 9900 twice and letting them drift.
------------------------------------------------------------------------------
*/}}
{{- define "br-spi-mock-bacen.containerPort" -}}
{{- $raw := toString ((.Values.app.configmap | default dict).MOCK_BACEN_PORT | default ":9900") -}}
{{- /* Validate the RAW value, not the trimmed one: the binary reads
   MOCK_BACEN_PORT verbatim and expects the ":<port>" form, so a bare "9900"
   must be rejected here instead of silently yielding a valid containerPort. */ -}}
{{- if not (regexMatch "^:[0-9]+$" $raw) -}}
{{- fail (printf "\n\nERROR: app.configmap.MOCK_BACEN_PORT=%q is not a listener address.\n   Use the \":<port>\" form, e.g. \":9900\".\n" $raw) -}}
{{- end -}}
{{- $port := trimPrefix ":" $raw -}}
{{- if or (lt (int $port) 1) (gt (int $port) 65535) -}}
{{- fail (printf "\n\nERROR: app.configmap.MOCK_BACEN_PORT=%q is outside the valid port range 1-65535.\n" $raw) -}}
{{- end -}}
{{- $port -}}
{{- end }}
