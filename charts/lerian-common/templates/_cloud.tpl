{{/*
lerian-common.cloud.table — the ENVIRONMENT-TOPOLOGY presets, keyed by managed
cloud. A single knob `global.cloud: aws|gcp|azure` selects a column; every chart
that resolves connection/observability values through `lerian-common.datastore.value`
and `lerian-common.globalValue` inherits it with NO chart change.

Precedence (in those helpers): native configmap key > dedicated > shared
(global.datastores/global.<block>) > CLOUD PRESET (this table) > hardcoded default.
So a cloud preset is a smart DEFAULT — an explicit global.datastores.<type>.<field>
still overrides it (the exception: e.g. ElastiCache without TLS).

Only ENDPOINTS (host/port/user) stay client-supplied — a cloud can't know your RDS
host. Topology (tls/scheme/ports/ssl/object-storage path-style) is per-cloud and
lives here.

`global.cloud` unset (or "opensource") => no column matches => hardcoded defaults
(bundled in-cluster infra, plaintext). Nobody running open source needs to know
this knob exists.

Deliberately ABSENT:
  - `broker` for gcp/azure — no managed RabbitMQ there; leave the bundled default
    (or set global.datastores.broker explicitly for CloudAMQP).
  - object-storage AUTH annotation (IRSA/WI/AAD) — that is a serviceAccount
    annotation KEY, not a configmap value; handled by lerian-common.cloud.saAnnotations.
  - `observability.enabled` — a cloud choice does NOT imply telemetry on/off;
    those are orthogonal (a managed-cloud install may still run its own OTel
    collector/agent). Coupling them meant selecting a cloud silently turned
    telemetry OFF for anyone who didn't also explicitly re-enable it — exactly
    backwards for a production install. The chart's own default (and any
    explicit global.observability.enabled/configmap.ENABLE_TELEMETRY) governs
    telemetry; the cloud table only sets connection/transport topology.

Keys mirror the datastore-mask field vocabulary (host/port/user/ssl/tls/scheme/
amqpPort/params/caCert/protocol).
*/}}
{{- define "lerian-common.cloud.table" -}}
aws:
  redis:         { tls: "true" }
  broker:        { scheme: "amqps", amqpPort: "5671", port: "15671" }
  postgres:      { ssl: "require" }
  objectStorage: { usePathStyle: "false", disableSSL: "false" }
gcp:
  redis:         { tls: "true" }
  postgres:      { ssl: "require" }
  objectStorage: { usePathStyle: "false", disableSSL: "false" }
azure:
  redis:         { tls: "true", port: "6380" }
  postgres:      { ssl: "require" }
  objectStorage: { usePathStyle: "true", disableSSL: "false" }
{{- end -}}

{{/*
lerian-common.cloud.block — the preset sub-block for the active cloud + a kind
(datastore type or global block). Returns YAML of the field map (possibly empty);
callers `fromYaml` it and `hasKey`-check the field. Args: context, kind.
*/}}
{{- define "lerian-common.cloud.block" -}}
{{- $cloud := (.context.Values.global | default dict).cloud | default "" -}}
{{- $table := include "lerian-common.cloud.table" . | fromYaml -}}
{{- index (index $table $cloud | default dict) .kind | default dict | toYaml -}}
{{- end -}}

{{/*
lerian-common.cloud.saAnnotations — the object-storage workload-identity annotation
for the active cloud. This is the ONE cloud dimension that is NOT a configmap value:
the annotation KEY differs per cloud (IRSA / GKE Workload Identity / Azure AD WI),
while the client supplies a single identity string at global.objectStorage.identity
(role ARN on AWS, GCP service-account email, Azure client-id). Emits nothing when
the identity or cloud is unset (opensource / static-key path). Arg: context.

Usage in a chart's serviceAccount template:
  annotations:
    {{- include "lerian-common.cloud.saAnnotations" (dict "context" $) | nindent 4 }}
    {{- with .Values.<comp>.serviceAccount.annotations }}{{- toYaml . | nindent 4 }}{{- end }}
*/}}
{{- define "lerian-common.cloud.saAnnotations" -}}
{{- $cloud := (.context.Values.global | default dict).cloud | default "" -}}
{{- $id := ((.context.Values.global | default dict).objectStorage | default dict).identity | default "" -}}
{{- if $id -}}
{{- if eq $cloud "aws" }}
eks.amazonaws.com/role-arn: {{ $id | quote }}
{{- else if eq $cloud "gcp" }}
iam.gke.io/gcp-service-account: {{ $id | quote }}
{{- else if eq $cloud "azure" }}
azure.workload.identity/client-id: {{ $id | quote }}
{{- end }}
{{- end -}}
{{- end -}}
