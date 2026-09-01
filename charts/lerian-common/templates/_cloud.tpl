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
  - `mongo` for gcp/azure — no Lerian-owned managed Mongo-compatible service
    there (GCP has no native Mongo-API service; Azure Cosmos DB for MongoDB
    uses a materially different connection-string convention we haven't
    validated against real infra). Set global.datastores.mongo.params
    explicitly if you have one.
  - `broker` for gcp/azure — no managed RabbitMQ there; leave the bundled default
    (or set global.datastores.broker explicitly for CloudAMQP).
  - `redis.tls` for gcp — Memorystore for Redis ships with in-transit encryption
    OFF by default; TLS is an opt-in, CREATE-TIME-ONLY instance flag
    (transit-encryption-mode=SERVER_AUTHENTICATION). Unlike Postgres (a client
    can always request SSL; the server just doesn't enforce it), a Redis
    instance provisioned without that flag has NO TLS LISTENER at all — a
    client TLS handshake fails outright, it doesn't just fall back to
    plaintext. Defaulting this to "true" would silently break connectivity for
    anyone on GCP's own default Memorystore topology. Set
    global.datastores.redis.tls=true explicitly once your instance actually
    has in-transit encryption enabled.
  - object-storage AUTH annotation (IRSA/WI/AAD) — that is a serviceAccount
    annotation KEY, not a configmap value; handled by lerian-common.cloud.saAnnotations.
  - `observability.enabled` — a cloud choice does NOT imply telemetry on/off;
    those are orthogonal (a managed-cloud install may still run its own OTel
    collector/agent). Coupling them meant selecting a cloud silently turned
    telemetry OFF for anyone who didn't also explicitly re-enable it — exactly
    backwards for a production install. The chart's own default (and any
    explicit global.observability.enabled/configmap.ENABLE_TELEMETRY) governs
    telemetry; the cloud table only sets connection/transport topology.

Azure note: Azure Blob Storage has NO native S3 API — `objectStorage.usePathStyle:
"true"` below only applies if you front it with an S3-compatible gateway (e.g.
Flexify.IO, S3Proxy); path-style is the common convention for self-hosted/
gateway S3 endpoints (vs. AWS/GCS's virtual-hosted-style). Native Azure Blob
access (SDK, not the S3 mask) is a separate integration this chart doesn't
model yet.

AWS values verified against this org's own CloudFormation provisioning
(lerian-cloudformation-foundation/templates/{elasticache,rds,amazonmq,documentdb}.yaml)
AND a real production GitOps values file (lerian-aws-gitops
environments/staging/helmfile/applications/midaz-mt/values.yaml):
ElastiCache TransitEncryptionEnabled=true+required, RDS ForceSSL default "1".
AmazonMQ: the CFN security group opens 5671 (AMQPS)/15671/443, but the actual
production values file uses RABBITMQ_PORT_AMQP=443 (+ RABBITMQ_PROTOCOL=https)
— not 15671 — so `broker.port` here is 443 to match what this org actually
runs, even though AWS's own docs call 443/15671 interchangeable. DocumentDB
EnableTLS default "enabled" — the mongo.params below are the exact
connection-string shape this org runs against DocumentDB in production:
tlsInsecure (DocumentDB doesn't ship AWS's public CA in every client trust
store by default), directConnection (skip replica-set topology discovery,
which DocumentDB's replica endpoints don't expose the way vanilla MongoDB
does), retryWrites=false (DocumentDB doesn't support retryable writes — the
driver's default retryWrites=true errors on every write without this), plus
connect/serverSelection timeouts tuned for DocumentDB's failover behavior.
Azure redis tls/6380 verified against Microsoft Learn (TLS-only
is the actual default on new Azure Cache for Redis instances; the non-TLS port
ships disabled). GCP/Azure have no equivalent Lerian-owned provisioning today
(AWS-only Marketplace product) — those columns are best-effort, not validated
against real infra.

Keys mirror the datastore-mask field vocabulary (host/port/user/ssl/tls/scheme/
amqpPort/params/caCert/protocol).
*/}}
{{- define "lerian-common.cloud.table" -}}
aws:
  redis:         { tls: "true" }
  broker:        { scheme: "amqps", amqpPort: "5671", port: "443" }
  postgres:      { ssl: "require" }
  mongo:         { params: "tls=true&tlsInsecure=true&directConnection=true&retryWrites=false&connectTimeoutMS=10000&serverSelectionTimeoutMS=10000" }
  objectStorage: { usePathStyle: "false", disableSSL: "false" }
gcp:
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
