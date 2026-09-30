{{/*
Expand the name of the chart.
*/}}
{{- define "br-sta.name" -}}
{{- default "br-sta" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Base fully qualified name. The shared ConfigMap and Secret use it verbatim; each
component appends its own suffix (br-sta-manager, br-sta-worker, ...).
*/}}
{{- define "br-sta.fullname" -}}
{{- default (include "br-sta.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "br-sta.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the namespace of the release. Overridable for multi-namespace layouts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Name of the service account to use (shared by every workload of the release).
*/}}
{{- define "br-sta.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "br-sta.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
br-sta.componentFullname — "<fullname>-<component>". Input: dict root, component.
*/}}
{{- define "br-sta.componentFullname" -}}
{{- printf "%s-%s" (include "br-sta.fullname" .root | trunc 50 | trimSuffix "-") .component | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
br-sta.managerServiceName — the manager Service name: manager.service.name when
set (e.g. to keep a pre-existing in-cluster address), else <fullname>-manager.
*/}}
{{- define "br-sta.managerServiceName" -}}
{{- (.Values.manager.service | default dict).name | default (include "br-sta.componentFullname" (dict "root" . "component" "manager")) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
br-sta.managerPort — the port the manager container listens on (SERVER_ADDRESS
and containerPort). manager.containerPort, else manager.service.port, else 4028.
*/}}
{{- define "br-sta.managerPort" -}}
{{- .Values.manager.containerPort | default (.Values.manager.service | default dict).port | default 4028 -}}
{{- end }}

{{/*
Selector labels for one component (stable across image bumps). Each component
selects only its own pods, so the manager PDB never matches a Job or the worker.
Input: dict root, component.
*/}}
{{- define "br-sta.selectorLabels" -}}
app.kubernetes.io/name: {{ include "br-sta.name" .root }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Common labels for one component. Input: dict root, component.
*/}}
{{- define "br-sta.labels" -}}
helm.sh/chart: {{ include "br-sta.chart" .root }}
{{ include "br-sta.selectorLabels" . }}
app.kubernetes.io/version: {{ .root.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
{{- end }}

{{/*
Labels for the shared (component-less) ConfigMap / Secret / ServiceAccount.
*/}}
{{- define "br-sta.sharedLabels" -}}
helm.sh/chart: {{ include "br-sta.chart" . }}
app.kubernetes.io/name: {{ include "br-sta.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Labels for a bootstrap Job: its OWN app.kubernetes.io/name, so no component
selector (Deployment, PDB) ever matches its pods. Input: dict root, name, component.
*/}}
{{- define "br-sta.jobLabels" -}}
helm.sh/chart: {{ include "br-sta.chart" .root }}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
br-sta.secretName — the shared app Secret (chart-managed, or the operator's).
*/}}
{{- define "br-sta.secretName" -}}
{{- $c := .Values.common -}}
{{- if $c.useExistingSecret -}}
{{- required "\n\nERROR: br-sta: common.existingSecretName must be set when common.useExistingSecret is true.\n" $c.existingSecretName -}}
{{- else -}}
{{- include "br-sta.fullname" . -}}
{{- end -}}
{{- end }}

{{/*
br-sta.jobName — "<base>-<hash8>": a bootstrap Job named after a hash of its own
spec. A changed spec (new image tag, new bucket list) is a NEW Job, so the
immutable spec.template never blocks an upgrade, and an unchanged spec keeps
its name (no re-run). Input: dict base, spec (the rendered spec string).
*/}}
{{- define "br-sta.jobName" -}}
{{- printf "%s-%s" (.base | trunc 54 | trimSuffix "-") (.spec | sha256sum | trunc 8) -}}
{{- end }}

{{/*
Collapse-aware subchart resource name. Kept as a 1-line alias to the library
helper so bundled-subchart Secret/Service names follow the Bitnami rule.
*/}}
{{- define "common.names.dependency.fullname" -}}
{{- include "lerian-common.dependency.fullname" . -}}
{{- end -}}

{{/*
==============================================================================
Bundled-subchart state. `enabled` uses the nil-aware comparison from the chart
standard (an explicit `false` must not coerce back to true).
  postgresEnabled / valkeyEnabled: the subchart renders (host derivation).
  postgresInternal / valkeyInternal: the app reads the subchart Secret.
==============================================================================
*/}}
{{- define "br-sta.postgresEnabled" -}}
{{- $pg := .Values.postgresql | default dict -}}
{{- ternary "true" "false" (eq (toString $pg.enabled) "true") -}}
{{- end -}}

{{- define "br-sta.valkeyEnabled" -}}
{{- $vk := .Values.valkey | default dict -}}
{{- ternary "true" "false" (eq (toString $vk.enabled) "true") -}}
{{- end -}}

{{- define "br-sta.postgresInternal" -}}
{{- $pg := .Values.postgresql | default dict -}}
{{- ternary "true" "false" (and (eq (toString $pg.enabled) "true") (not $pg.external)) -}}
{{- end -}}

{{- define "br-sta.valkeyInternal" -}}
{{- $vk := .Values.valkey | default dict -}}
{{- $vkAuth := $vk.auth | default dict -}}
{{- ternary "true" "false" (and (eq (toString $vk.enabled) "true") (not $vk.external) (ne (toString $vkAuth.enabled) "false")) -}}
{{- end -}}

{{/*
Bundled RabbitMQ (groundhog2k/rabbitmq). Its Service is the standard Helm
fullname (collapse-aware "<release>-rabbitmq", honoring fullnameOverride /
nameOverride), AMQP on service.amqp.port (5672), in the release namespace.
*/}}
{{- define "br-sta.rabbitmqEnabled" -}}
{{- ternary "true" "false" (eq (toString (.Values.rabbitmq | default dict).enabled) "true") -}}
{{- end -}}

{{- define "br-sta.rabbitmqHost" -}}
{{- printf "%s.%s.svc.cluster.local." (include "lerian-common.dependency.fullname" (dict "chartName" "rabbitmq" "chartValues" (.Values.rabbitmq | default dict) "context" .)) .Release.Namespace -}}
{{- end -}}

{{/*
Bundled SeaweedFS (seaweedfs subchart). The subchart names its Services after
`seaweedfs.name` (nameOverride | "seaweedfs", NOT release-prefixed) and deploys
into the release namespace.
*/}}
{{- define "br-sta.seaweedfsEnabled" -}}
{{- ternary "true" "false" (eq (toString (.Values.seaweedfs | default dict).enabled) "true") -}}
{{- end -}}

{{- define "br-sta.seaweedfsName" -}}
{{- $sw := .Values.seaweedfs | default dict -}}
{{- default "seaweedfs" $sw.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "br-sta.seaweedfsS3Endpoint" -}}
{{- $sw := .Values.seaweedfs | default dict -}}
{{- $s3 := $sw.s3 | default dict -}}
{{- $filerS3 := ($sw.filer | default dict).s3 | default dict -}}
{{- $port := ternary ($s3.port | default 8333) ($filerS3.port | default 8333) (eq (toString $s3.enabled) "true") -}}
{{- printf "http://%s-s3.%s.svc.cluster.local:%v" (include "br-sta.seaweedfsName" .) .Release.Namespace $port -}}
{{- end -}}

{{/*
Bundled Redpanda (redpanda subchart). It names its Services after
fullnameOverride, else the RELEASE name (no suffix). Internal Kafka listener
port = listeners.kafka.port (9093).
*/}}
{{- define "br-sta.redpandaEnabled" -}}
{{- ternary "true" "false" (eq (toString (.Values.redpandaBundle | default dict).enabled) "true") -}}
{{- end -}}

{{- define "br-sta.redpandaBrokers" -}}
{{- $rp := .Values.redpanda | default dict -}}
{{- $name := $rp.fullnameOverride | default .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- $port := (($rp.listeners | default dict).kafka | default dict).port | default 9093 -}}
{{- printf "%s.%s.svc.cluster.local.:%v" $name .Release.Namespace $port -}}
{{- end -}}

{{/*
Bundled mock STA server (templates/bundle/mock-sta.yaml).
mockStaHost: the host[:port] the STA client dials (port omitted on 80, the
scheme default for http).
*/}}
{{- define "br-sta.mockStaEnabled" -}}
{{- ternary "true" "false" (eq (toString (.Values.mockSta | default dict).enabled) "true") -}}
{{- end -}}

{{- define "br-sta.mockStaHost" -}}
{{- $port := toString ((.Values.mockSta.service | default dict).port | default 80) -}}
{{- $host := printf "%s.%s.svc.cluster.local" (include "br-sta.componentFullname" (dict "root" . "component" "mock-sta")) (include "global.namespace" .) -}}
{{- if eq $port "80" -}}{{- $host -}}{{- else -}}{{- printf "%s:%s" $host $port -}}{{- end -}}
{{- end -}}

{{/*
br-sta.streamingGlobal — the global.streaming block handed to
lerian-common.streaming.env. With the bundled Redpanda on and no
global.streaming.brokers, it injects the derived brokers at the global tier, so
common.configmap.STREAMING_BROKERS still wins and an explicit global value is
untouched.
*/}}
{{- define "br-sta.streamingGlobal" -}}
{{- $gs := deepCopy (((.Values.global | default dict).streaming) | default dict) -}}
{{- if and (eq (include "br-sta.redpandaEnabled" .) "true") (not $gs.brokers) -}}
{{- $_ := set $gs "brokers" (include "br-sta.redpandaBrokers" .) -}}
{{- end -}}
{{- toYaml $gs -}}
{{- end -}}

{{/*
br-sta.saslUserFromSecret — "true" when STREAMING_SASL_USERNAME is NOT set in the
ConfigMap / global.streaming but the Secret carries it (common.secrets, or an
operator Secret via common.useExistingSecret).
*/}}
{{- define "br-sta.saslUserFromSecret" -}}
{{- $cm := .Values.common.configmap | default dict -}}
{{- $g := (.Values.global | default dict).streaming | default dict -}}
{{- $inCm := or (hasKey $cm "STREAMING_SASL_USERNAME") $g.saslUsername -}}
{{- $inSecret := or (index (.Values.common.secrets | default dict) "STREAMING_SASL_USERNAME") .Values.common.useExistingSecret -}}
{{- if and (not $inCm) $inSecret -}}true{{- else -}}false{{- end -}}
{{- end -}}

{{/*
br-sta.componentExtraEnv — one component's extraEnvVars as a YAML map
{NAME: value}, with "__valueFrom__" for entries sourced via valueFrom.
Input: dict root, component (manager | worker).
*/}}
{{- define "br-sta.componentExtraEnv" -}}
{{- $out := dict -}}
{{- range ((index .root.Values .component | default dict).extraEnvVars | default list) -}}
{{- if .name -}}
{{- if hasKey . "valueFrom" -}}
{{- $_ := set $out .name "__valueFrom__" -}}
{{- else -}}
{{- $_ := set $out .name (toString (.value | default "")) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- toYaml $out -}}
{{- end -}}

{{/*
br-sta.extraEnv — the extraEnvVars entries that reach EVERY enabled app pod:
the intersection of manager.extraEnvVars and worker.extraEnvVars (only the
enabled components count). Both binaries read the same configuration, so a
key set on one pod only must not satisfy the fail-fast gates (nor suppress the
chart's own Secret copy) for the other, and every pod must carry the SAME
value (a mismatch — e.g. an empty literal on one pod — does not count, and the
migrations Job never inherits a conflicting setting). Output: YAML map {NAME: value | "__valueFrom__"}.
*/}}
{{- define "br-sta.extraEnv" -}}
{{- $maps := list -}}
{{- range $comp := list "manager" "worker" -}}
{{- if (index $.Values $comp | default dict).enabled -}}
{{- $maps = append $maps (include "br-sta.componentExtraEnv" (dict "root" $ "component" $comp) | fromYaml | default dict) -}}
{{- end -}}
{{- end -}}
{{- $out := dict -}}
{{- if $maps -}}
{{- range $k, $v := first $maps -}}
{{- $inAll := true -}}
{{- range $m := rest $maps -}}
{{- if not (hasKey $m $k) -}}{{- $inAll = false -}}
{{- else if ne (toString (index $m $k)) (toString $v) -}}{{- $inAll = false -}}
{{- end -}}
{{- end -}}
{{- if $inAll -}}{{- $_ := set $out $k $v -}}{{- end -}}
{{- end -}}
{{- end -}}
{{- toYaml $out -}}
{{- end -}}

{{/*
br-sta.provided — "true" when env KEY reaches the pods from ANY source: the
resolved ConfigMap value passed in (value), common.secrets.<KEY>, or an
extraEnvVars entry every enabled app pod receives (br-sta.extraEnv). Inputs:
context, key, value (opt).
*/}}
{{- define "br-sta.provided" -}}
{{- $ctx := .context -}}
{{- $x := include "br-sta.extraEnv" $ctx | fromYaml -}}
{{- $s := $ctx.Values.common.secrets | default dict -}}
{{- if or (trim (toString (.value | default ""))) (index $s .key) (index $x .key) -}}
true
{{- end -}}
{{- end -}}

{{/*
br-sta.envName — the deployment environment, single-sourced for ENV_NAME and
the default OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT. Precedence:
common.configmap.ENV_NAME > global.env.name > "production". The app's production
gates fire on exactly "production" (fail-closed default).
*/}}
{{- define "br-sta.envName" -}}
{{- include "lerian-common.globalValue" (dict "context" . "configmap" (.Values.common.configmap | default dict) "block" "env" "field" "name" "nativeKey" "ENV_NAME" "default" "production") -}}
{{- end -}}

{{/*
br-sta.devClass — "true" when the env name is one of the app's
development-class names (br-sfn shared/envclass: development, develop, dev,
local, test; case-insensitive). Only there does the app accept
PLUGIN_AUTH_ENABLED=false, and only there does the chart render its dev-only
bundles.
*/}}
{{- define "br-sta.devClass" -}}
{{- $env := lower (trim (include "br-sta.envName" .)) -}}
{{- ternary "true" "false" (has $env (list "development" "develop" "dev" "local" "test")) -}}
{{- end -}}

{{/*
br-sta.production — "true" when ENV_NAME is exactly "production": the app's
production validators (TLS, license, mandatory audit transport, transfer bucket)
key off that literal.
*/}}
{{- define "br-sta.production" -}}
{{- ternary "true" "false" (eq (include "br-sta.envName" .) "production") -}}
{{- end -}}

{{- define "br-sta.isTrue" -}}
{{- ternary "true" "false" (has (toString .) (list "true" "1" "t" "T" "TRUE" "True")) -}}
{{- end -}}

{{- define "br-sta.multiTenantEnabled" -}}
{{- $cm := .Values.common.configmap | default dict -}}
{{- include "br-sta.isTrue" (include "lerian-common.globalValue" (dict "context" . "configmap" $cm "block" "multiTenant" "field" "enabled" "nativeKey" "MULTI_TENANT_ENABLED" "default" "false")) -}}
{{- end -}}

{{- define "br-sta.streamingEnabledRaw" -}}
{{- $cm := .Values.common.configmap | default dict -}}
{{- include "lerian-common.globalValue" (dict "context" . "configmap" $cm "block" "streaming" "field" "enabled" "nativeKey" "STREAMING_ENABLED" "default" "false") -}}
{{- end -}}

{{/*
br-sta.authEnabled — PLUGIN_AUTH_ENABLED. configmap > global.auth.enabled >
"false" in a development-class environment, "true" everywhere else. The app
refuses a blank value, so the chart always renders one.
*/}}
{{- define "br-sta.authEnabled" -}}
{{- $cm := .Values.common.configmap | default dict -}}
{{- $default := ternary "false" "true" (eq (include "br-sta.devClass" .) "true") -}}
{{- include "lerian-common.globalValue" (dict "context" . "configmap" $cm "block" "auth" "field" "enabled" "nativeKey" "PLUGIN_AUTH_ENABLED" "default" $default) -}}
{{- end -}}

{{/*
br-sta.postgres — the resolved primary Postgres connection as YAML
{host, port, user, name, ssl}, shared by the app ConfigMap and the migrations
Job so the two can never drift. Mask precedence (lerian-common.datastore.value):
configmap.POSTGRES_* > common.datastores.postgres > global.datastores.postgres
> global.cloud preset > default. The host defaults to the bundled subchart
Service only when postgresql.enabled; ssl defaults to "disable" for the bundled
(plaintext) subchart and "require" otherwise. The database/user default to
br_sta: the migration runner only accepts [a-zA-Z_][a-zA-Z0-9_]* database names.
*/}}
{{- define "br-sta.postgres" -}}
{{- $cm := .Values.common.configmap | default dict -}}
{{- $ded := .Values.common.datastores | default dict -}}
{{- $dv := "lerian-common.datastore.value" -}}
{{- $bundled := eq (include "br-sta.postgresEnabled" .) "true" -}}
{{- $hostDefault := "" -}}
{{- if $bundled -}}
{{- $hostDefault = printf "%s.%s.svc.cluster.local." (include "common.names.dependency.fullname" (dict "chartName" "postgresql" "chartValues" .Values.postgresql "context" .)) (include "global.namespace" .) -}}
{{- end -}}
host: {{ include $dv (dict "context" . "dedicated" $ded "configmap" $cm "type" "postgres" "field" "host" "nativeKey" "POSTGRES_HOST" "default" $hostDefault) | quote }}
port: {{ include $dv (dict "context" . "dedicated" $ded "configmap" $cm "type" "postgres" "field" "port" "nativeKey" "POSTGRES_PORT" "default" "5432") | quote }}
user: {{ include $dv (dict "context" . "dedicated" $ded "configmap" $cm "type" "postgres" "field" "user" "nativeKey" "POSTGRES_USER" "default" "br_sta") | quote }}
name: {{ include $dv (dict "context" . "dedicated" $ded "configmap" $cm "type" "postgres" "field" "name" "nativeKey" "POSTGRES_NAME" "default" "br_sta") | quote }}
ssl: {{ include $dv (dict "context" . "dedicated" $ded "configmap" $cm "type" "postgres" "field" "ssl" "nativeKey" "POSTGRES_SSLMODE" "default" (ternary "disable" "require" $bundled)) | quote }}
{{- end -}}

{{/*
br-sta.rabbitmqUser — RABBITMQ_DEFAULT_USER (datastores.broker.user). With the
bundled broker the same value is copied into the app Secret, where the broker
reads it (Pattern B), so both sides always agree.
*/}}
{{- define "br-sta.rabbitmqUser" -}}
{{- include "lerian-common.datastore.value" (dict "context" . "dedicated" (.Values.common.datastores | default dict) "configmap" (.Values.common.configmap | default dict) "type" "broker" "field" "user" "nativeKey" "RABBITMQ_DEFAULT_USER" "default" "br_sta") -}}
{{- end -}}

{{/*
br-sta.allowInsecureTLS — lib-commons' plaintext bypass for postgres / redis /
rabbitmq. configmap > common.security.allowInsecureTls > "true" only when a
bundled (plaintext) datastore is enabled, else "false".
*/}}
{{- define "br-sta.allowInsecureTLS" -}}
{{- $cm := .Values.common.configmap | default dict -}}
{{- $bundled := or (eq (include "br-sta.postgresEnabled" .) "true") (eq (include "br-sta.valkeyEnabled" .) "true") (eq (include "br-sta.rabbitmqEnabled" .) "true") -}}
{{- include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "ALLOW_INSECURE_TLS" "params" .Values.common.security "field" "allowInsecureTls" "default" (ternary "true" "false" $bundled)) -}}
{{- end -}}

{{/*
br-sta.kv — emit ONE ConfigMap line resolved through lerian-common.cfgValue
(configmap.<k> > params.<f> > d). With opt=true the line is omitted when the
resolved value is empty (optional keys the app treats "unset" and "" alike,
whose envDefault must keep applying, or whose mere presence changes behavior).
Inputs (dict): cm, p (params map), f (field), k (env key), d (default), opt.
*/}}
{{- define "br-sta.kv" -}}
{{- $v := include "lerian-common.cfgValue" (dict "configmap" .cm "nativeKey" .k "params" .p "field" .f "default" (toString (.d | default ""))) -}}
{{- if or (not .opt) $v }}
{{ .k }}: {{ $v | quote }}
{{- end -}}
{{- end -}}

{{/*
br-sta.kmsProvider — MASTER_KEY_PROVIDER from the KMS mask. configmap wins
verbatim; otherwise kms.vendor (common.kms > global.kms > "envvar") is mapped to
the app's vocabulary: envvar|none|"" -> envvar, aws|aws-kms -> aws-kms.
*/}}
{{- define "br-sta.kmsProvider" -}}
{{- $cm := .Values.common.configmap | default dict -}}
{{- if hasKey $cm "MASTER_KEY_PROVIDER" -}}
{{- index $cm "MASTER_KEY_PROVIDER" -}}
{{- else -}}
{{- $vendor := include "lerian-common.kms.value" (dict "context" . "dedicated" (.Values.common.kms | default dict) "configmap" $cm "field" "vendor" "nativeKey" "MASTER_KEY_PROVIDER" "default" "envvar") -}}
{{- $map := dict "envvar" "envvar" "none" "envvar" "aws" "aws-kms" "aws-kms" "aws-kms" -}}
{{- index $map $vendor | default $vendor -}}
{{- end -}}
{{- end -}}

{{/*
br-sta.objectStorage — the resolved transfer + audit-export object storage as
YAML. Shared by the ConfigMap and the bucket Job. The audit-export endpoint,
region and path style default to the transfer ones (one S3 backend is the
common case); its bucket is separate.
*/}}
{{- define "br-sta.objectStorage" -}}
{{- $cm := .Values.common.configmap | default dict -}}
{{- $ded := .Values.common.objectStorage | default dict -}}
{{- $osv := "lerian-common.objectStorage.value" -}}
{{- $bundled := eq (include "br-sta.seaweedfsEnabled" .) "true" -}}
{{- $epDefault := ternary (include "br-sta.seaweedfsS3Endpoint" .) "" $bundled -}}
{{- $ep := include $osv (dict "context" . "dedicated" $ded "configmap" $cm "name" "sta" "field" "endpoint" "nativeKey" "TRANSFER_S3_ENDPOINT" "default" $epDefault) -}}
{{- $region := include $osv (dict "context" . "dedicated" $ded "configmap" $cm "name" "sta" "field" "region" "nativeKey" "TRANSFER_S3_REGION" "default" "us-east-1") -}}
{{- $path := include $osv (dict "context" . "dedicated" $ded "configmap" $cm "name" "sta" "field" "usePathStyle" "nativeKey" "TRANSFER_S3_PATH_STYLE" "default" (ternary "true" "false" $bundled)) -}}
transferBucket: {{ include $osv (dict "context" . "dedicated" $ded "configmap" $cm "name" "sta" "field" "bucket" "nativeKey" "TRANSFER_OBJECT_STORAGE_BUCKET" "default" "") | quote }}
transferEndpoint: {{ $ep | quote }}
transferRegion: {{ $region | quote }}
transferPathStyle: {{ $path | quote }}
auditBucket: {{ include $osv (dict "context" . "dedicated" $ded "configmap" $cm "name" "staAuditExports" "field" "bucket" "nativeKey" "AUDIT_EXPORT_GENERATOR_S3_BUCKET" "default" "") | quote }}
auditEndpoint: {{ include $osv (dict "context" . "dedicated" $ded "configmap" $cm "name" "staAuditExports" "field" "endpoint" "nativeKey" "AUDIT_EXPORT_GENERATOR_S3_ENDPOINT" "default" $ep) | quote }}
auditRegion: {{ include $osv (dict "context" . "dedicated" $ded "configmap" $cm "name" "staAuditExports" "field" "region" "nativeKey" "AUDIT_EXPORT_GENERATOR_S3_REGION" "default" $region) | quote }}
auditPathStyle: {{ include $osv (dict "context" . "dedicated" $ded "configmap" $cm "name" "staAuditExports" "field" "usePathStyle" "nativeKey" "AUDIT_EXPORT_GENERATOR_S3_PATH_STYLE" "default" $path) | quote }}
{{- end -}}

{{/*
br-sta.configmapData — every SHARED app env key the chart models (manager +
worker), as ConfigMap `data` lines (blank lines are dropped by the caller).
Dependency connections go through the lerian-common masks/env helpers; every
other key goes through lerian-common.cfgValue (via br-sta.kv). Contract source:
the STA service config/.env.example + internal/bootstrap/config.go
(app sta-v1.0.0; identical to the sta-v1.2.0-beta.16 contract).
*/}}
{{- define "br-sta.configmapData" -}}
{{- $ := . -}}
{{- $c := .Values.common -}}
{{- $cm := $c.configmap | default dict -}}
{{- $dv := "lerian-common.datastore.value" -}}
{{- $kv := "br-sta.kv" -}}
{{- $kmsDed := $c.kms | default dict -}}
{{- $dsDed := $c.datastores | default dict -}}
{{- $imageTag := .Values.manager.image.tag | default .Chart.AppVersion | toString -}}
{{- $envName := include "br-sta.envName" . -}}
{{- $mtOn := eq (include "br-sta.multiTenantEnabled" .) "true" -}}
{{- $pg := include "br-sta.postgres" . | fromYaml -}}
{{- $os := include "br-sta.objectStorage" . | fromYaml -}}
{{- $streamingRaw := include "br-sta.streamingEnabledRaw" . -}}
{{- $streamingOn := eq (include "br-sta.isTrue" $streamingRaw) "true" -}}
{{- $mockOn := eq (include "br-sta.mockStaEnabled" .) "true" -}}
# --- Application -------------------------------------------------------------
ENV_NAME: {{ $envName | quote }}
{{ include $kv (dict "cm" $cm "p" $c.app "f" "logLevel" "k" "LOG_LEVEL" "d" "info") }}
{{ include $kv (dict "cm" $cm "p" $c.app "f" "deploymentMode" "k" "DEPLOYMENT_MODE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.app "f" "defaultTenantId" "k" "DEFAULT_TENANT_ID" "d" "11111111-1111-1111-1111-111111111111") }}
{{ include $kv (dict "cm" $cm "p" $c.app "f" "systemplaneEnabled" "k" "SYSTEMPLANE_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $c.app "f" "infraConnectTimeoutSec" "k" "INFRA_CONNECT_TIMEOUT_SEC" "d" "30") }}
{{ include $kv (dict "cm" $cm "p" $c.app "f" "dbMetricsIntervalSec" "k" "DB_METRICS_INTERVAL_SEC" "d" "15") }}
{{ include $kv (dict "cm" $cm "p" $c.app "f" "idempotencyRetryWindowSec" "k" "IDEMPOTENCY_RETRY_WINDOW_SEC" "d" "300") }}
{{ include $kv (dict "cm" $cm "p" $c.app "f" "circuitBreakerEnabled" "k" "CIRCUIT_BREAKER_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $c.app "f" "configApiEnabled" "k" "CONFIG_API_ENABLED" "opt" true) }}
# --- HTTP server + CORS --------------------------------------------------------
{{ include $kv (dict "cm" $cm "p" $c.server "f" "address" "k" "SERVER_ADDRESS" "d" (printf "0.0.0.0:%v" (include "br-sta.managerPort" .))) }}
{{ include $kv (dict "cm" $cm "p" $c.server "f" "bodyLimitBytes" "k" "HTTP_BODY_LIMIT_BYTES" "d" "104857600") }}
{{ include $kv (dict "cm" $cm "p" $c.server "f" "tlsTerminatedUpstream" "k" "TLS_TERMINATED_UPSTREAM" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $c.server "f" "tlsCertFile" "k" "SERVER_TLS_CERT_FILE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.server "f" "tlsKeyFile" "k" "SERVER_TLS_KEY_FILE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.server "f" "trustedProxies" "k" "SERVER_TRUSTED_PROXIES" "d" "") }}
{{ include $kv (dict "cm" $cm "p" $c.cors "f" "allowedOrigins" "k" "CORS_ALLOWED_ORIGINS" "d" "") }}
{{ include $kv (dict "cm" $cm "p" $c.cors "f" "allowedMethods" "k" "CORS_ALLOWED_METHODS" "d" "GET,POST,PUT,PATCH,DELETE,OPTIONS") }}
{{ include $kv (dict "cm" $cm "p" $c.cors "f" "allowedHeaders" "k" "CORS_ALLOWED_HEADERS" "d" "Origin,Content-Type,Accept,Authorization,X-Request-ID") }}
{{ include $kv (dict "cm" $cm "p" $c.cors "f" "exposeHeaders" "k" "CORS_EXPOSE_HEADERS" "d" "") }}
{{ include $kv (dict "cm" $cm "p" $c.cors "f" "allowCredentials" "k" "CORS_ALLOW_CREDENTIALS" "d" "false") }}
{{- /* lib-commons' CORS middleware (WithCORS, v7) reads the ACCESS_CONTROL_* keys,
   NOT CORS_*. The origin is always rendered from cors.allowedOrigins (a native
   CORS_ALLOWED_ORIGINS maps too): empty/unset means "*" to the middleware, which
   it turns into deny-all unless ALLOW_CORS_WILDCARD=true. Methods, headers,
   expose headers and credentials render only when set through the cors group
   (or a native CORS_* key); otherwise the middleware keeps its own defaults.
   A native ACCESS_CONTROL_* key always wins. */}}
{{- range $pair := list (list "allowedOrigins" "CORS_ALLOWED_ORIGINS" "ACCESS_CONTROL_ALLOW_ORIGIN" false) (list "allowedMethods" "CORS_ALLOWED_METHODS" "ACCESS_CONTROL_ALLOW_METHODS" true) (list "allowedHeaders" "CORS_ALLOWED_HEADERS" "ACCESS_CONTROL_ALLOW_HEADERS" true) (list "exposeHeaders" "CORS_EXPOSE_HEADERS" "ACCESS_CONTROL_EXPOSE_HEADERS" true) (list "allowCredentials" "CORS_ALLOW_CREDENTIALS" "ACCESS_CONTROL_ALLOW_CREDENTIALS" true) }}
{{- $field := index $pair 0 }}{{- $corsKey := index $pair 1 }}{{- $acKey := index $pair 2 }}{{- $optional := index $pair 3 }}
{{- if hasKey $cm $acKey }}
{{ $acKey }}: {{ index $cm $acKey | toString | quote }}
{{- else if or (not $optional) (hasKey $cm $corsKey) (hasKey ($c.cors | default dict) $field) }}
{{ $acKey }}: {{ include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" $corsKey "params" $c.cors "field" $field "default" "") | toString | quote }}
{{- end }}
{{- end }}
# --- lib-commons security toggles -------------------------------------------
ALLOW_INSECURE_TLS: {{ include "br-sta.allowInsecureTLS" . | quote }}
{{ include $kv (dict "cm" $cm "p" $c.security "f" "allowCorsWildcard" "k" "ALLOW_CORS_WILDCARD" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.security "f" "allowInsecureOtel" "k" "ALLOW_INSECURE_OTEL" "opt" true) }}
# --- License (lib-license-go); LICENSE_KEY lives in the Secret ------------------
{{ include $kv (dict "cm" $cm "p" $c.license "f" "organizationIds" "k" "ORGANIZATION_IDS" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.license "f" "isDevelopment" "k" "IS_DEVELOPMENT" "opt" true) }}
# --- Multi-tenant (lerian-common.multiTenant.env; secrets via multiTenant.secret) --
MULTI_TENANT_ENABLED: {{ include "lerian-common.globalValue" (dict "context" $ "configmap" $cm "block" "multiTenant" "field" "enabled" "nativeKey" "MULTI_TENANT_ENABLED" "default" "false") | quote }}
{{- /* Tenant-manager client tuning as grouped params (common.multiTenant.*): the
   library helper reads only native keys, so a set field is injected as its
   native key unless common.configmap already carries it (native still wins). */}}
{{- $mtCm := deepCopy $cm }}
{{- range $pair := list (list "maxTenantPools" "MULTI_TENANT_MAX_TENANT_POOLS") (list "idleTimeoutSec" "MULTI_TENANT_IDLE_TIMEOUT_SEC") (list "timeoutSec" "MULTI_TENANT_TIMEOUT") (list "cacheTtlSec" "MULTI_TENANT_CACHE_TTL_SEC") (list "connectionsCheckIntervalSec" "MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC") (list "circuitBreakerThreshold" "MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD") (list "circuitBreakerTimeoutSec" "MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC") (list "allowInsecureHttp" "MULTI_TENANT_ALLOW_INSECURE_HTTP") }}
{{- if and (hasKey ($c.multiTenant | default dict) (index $pair 0)) (not (hasKey $cm (index $pair 1))) }}
{{- $_ := set $mtCm (index $pair 1) (toString (index $c.multiTenant (index $pair 0))) }}
{{- end }}
{{- end }}
{{ include "lerian-common.multiTenant.env" (dict "context" $ "configmap" $mtCm "enabled" $mtOn "requiredUrl" true "requiredRedisHost" true "emitRedis" true "emitRedisCaCert" true "emitPool" true "emitCache" true "emitAllowInsecure" true) }}
{{- if $mtOn }}
{{ include $kv (dict "cm" $cm "p" $c.multiTenant "f" "poolMaxConns" "k" "MULTI_TENANT_POOL_MAX_CONNS" "d" "20") }}
{{ include $kv (dict "cm" $cm "p" $c.multiTenant "f" "poolMaxIdleConns" "k" "MULTI_TENANT_POOL_MAX_IDLE_CONNS" "d" "5") }}
{{- end }}
# --- PostgreSQL (lerian-common.datastore.value) ------------------------------
POSTGRES_HOST: {{ $pg.host | quote }}
POSTGRES_PORT: {{ $pg.port | quote }}
POSTGRES_USER: {{ $pg.user | quote }}
POSTGRES_NAME: {{ $pg.name | quote }}
POSTGRES_SSLMODE: {{ $pg.ssl | quote }}
{{ include $kv (dict "cm" $cm "p" $c.postgres "f" "maxOpenConns" "k" "POSTGRES_MAX_OPEN_CONNS" "d" "25") }}
{{ include $kv (dict "cm" $cm "p" $c.postgres "f" "maxIdleConns" "k" "POSTGRES_MAX_IDLE_CONNS" "d" "5") }}
{{ include $kv (dict "cm" $cm "p" $c.postgres "f" "connMaxLifetimeMins" "k" "POSTGRES_CONN_MAX_LIFETIME_MINS" "d" "30") }}
{{ include $kv (dict "cm" $cm "p" $c.postgres "f" "connMaxIdleTimeMins" "k" "POSTGRES_CONN_MAX_IDLE_TIME_MINS" "d" "5") }}
{{ include $kv (dict "cm" $cm "p" $c.postgres "f" "connectTimeoutSec" "k" "POSTGRES_CONNECT_TIMEOUT_SEC" "d" "10") }}
{{- $replicaHost := include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "postgres" "field" "replicaHost" "nativeKey" "POSTGRES_REPLICA_HOST" "default" "") }}
{{- if $replicaHost }}
POSTGRES_REPLICA_HOST: {{ $replicaHost | quote }}
POSTGRES_REPLICA_PORT: {{ include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "postgres" "field" "port" "nativeKey" "POSTGRES_REPLICA_PORT" "default" $pg.port) | quote }}
POSTGRES_REPLICA_USER: {{ include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "postgres" "field" "user" "nativeKey" "POSTGRES_REPLICA_USER" "default" $pg.user) | quote }}
POSTGRES_REPLICA_NAME: {{ (hasKey $cm "POSTGRES_REPLICA_NAME" | ternary (index $cm "POSTGRES_REPLICA_NAME") $pg.name) | quote }}
POSTGRES_REPLICA_SSLMODE: {{ include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "postgres" "field" "ssl" "nativeKey" "POSTGRES_REPLICA_SSLMODE" "default" $pg.ssl) | quote }}
{{- end }}
# --- Redis / Valkey (lerian-common.datastore.value) --------------------------
{{- $redisHostDefault := "" }}
{{- if eq (include "br-sta.valkeyEnabled" .) "true" }}
{{- $redisHostDefault = printf "%s-primary.%s.svc.cluster.local.:6379" (include "common.names.dependency.fullname" (dict "chartName" "valkey" "chartValues" .Values.valkey "context" .)) (include "global.namespace" .) }}
{{- end }}
REDIS_HOST: {{ include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "redis" "field" "host" "nativeKey" "REDIS_HOST" "default" $redisHostDefault) | quote }}
REDIS_TLS: {{ include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "redis" "field" "tls" "nativeKey" "REDIS_TLS" "default" "false") | quote }}
{{- $redisCa := include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "redis" "field" "caCert" "nativeKey" "REDIS_CA_CERT" "default" "") }}
{{- if $redisCa }}
REDIS_CA_CERT: {{ $redisCa | quote }}
{{- end }}
{{ include $kv (dict "cm" $cm "p" $c.redis "f" "masterName" "k" "REDIS_MASTER_NAME" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.redis "f" "db" "k" "REDIS_DB" "d" "0") }}
{{ include $kv (dict "cm" $cm "p" $c.redis "f" "protocol" "k" "REDIS_PROTOCOL" "d" "3") }}
{{ include $kv (dict "cm" $cm "p" $c.redis "f" "poolSize" "k" "REDIS_POOL_SIZE" "d" "10") }}
{{ include $kv (dict "cm" $cm "p" $c.redis "f" "minIdleConns" "k" "REDIS_MIN_IDLE_CONNS" "d" "2") }}
{{ include $kv (dict "cm" $cm "p" $c.redis "f" "readTimeout" "k" "REDIS_READ_TIMEOUT" "d" "3") }}
{{ include $kv (dict "cm" $cm "p" $c.redis "f" "writeTimeout" "k" "REDIS_WRITE_TIMEOUT" "d" "3") }}
{{ include $kv (dict "cm" $cm "p" $c.redis "f" "dialTimeout" "k" "REDIS_DIAL_TIMEOUT" "d" "5") }}
{{ include $kv (dict "cm" $cm "p" $c.redis "f" "poolTimeout" "k" "REDIS_POOL_TIMEOUT" "d" "2") }}
{{ include $kv (dict "cm" $cm "p" $c.redis "f" "maxRetries" "k" "REDIS_MAX_RETRIES" "d" "3") }}
{{ include $kv (dict "cm" $cm "p" $c.redis "f" "minRetryBackoff" "k" "REDIS_MIN_RETRY_BACKOFF" "d" "8") }}
{{ include $kv (dict "cm" $cm "p" $c.redis "f" "maxRetryBackoff" "k" "REDIS_MAX_RETRY_BACKOFF" "d" "1") }}
# --- RabbitMQ: audit transport + business channel (datastore broker mask) -----
{{ include $kv (dict "cm" $cm "p" $c.rabbitmq "f" "enabled" "k" "RABBITMQ_ENABLED" "d" "true") }}
{{- $rmqBundled := eq (include "br-sta.rabbitmqEnabled" .) "true" }}
{{- $rmqHostDefault := ternary (include "br-sta.rabbitmqHost" .) "" $rmqBundled }}
{{- $rmqHost := include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "broker" "field" "host" "nativeKey" "RABBITMQ_HOST" "default" $rmqHostDefault) }}
{{- $rmqScheme := include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "broker" "field" "scheme" "nativeKey" "RABBITMQ_SCHEME" "default" "amqp") }}
{{- $rmqMgmtPort := include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "broker" "field" "port" "nativeKey" "RABBITMQ_PORT_HOST" "default" "15672") }}
RABBITMQ_HOST: {{ $rmqHost | quote }}
RABBITMQ_SCHEME: {{ $rmqScheme | quote }}
RABBITMQ_PORT_AMQP: {{ include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "broker" "field" "amqpPort" "nativeKey" "RABBITMQ_PORT_AMQP" "default" "5672") | quote }}
RABBITMQ_PORT_HOST: {{ $rmqMgmtPort | quote }}
RABBITMQ_DEFAULT_USER: {{ include "br-sta.rabbitmqUser" . | quote }}
{{ include $kv (dict "cm" $cm "p" $c.rabbitmq "f" "vhost" "k" "RABBITMQ_VHOST" "d" "/") }}
{{ include $kv (dict "cm" $cm "p" $c.rabbitmq "f" "exchange" "k" "RABBITMQ_EXCHANGE" "d" "events") }}
{{ include $kv (dict "cm" $cm "p" $c.rabbitmq "f" "queue" "k" "RABBITMQ_QUEUE" "opt" true) }}
{{- /* lib-commons dials the management API health check on EVERY connect and
   refuses an empty URL, so it defaults to the broker's own management endpoint
   (https for an amqps broker), with the broker host as the SSRF allowlist. The
   bundled broker serves it over plain HTTP, hence its insecure opt-in default. */}}
{{- $rmqHealthHost := trimSuffix "." $rmqHost }}
{{- $rmqHealthDefault := "" }}
{{- if $rmqHealthHost }}{{- $rmqHealthDefault = printf "%s://%s:%v/api/health/checks/alarms" (ternary "https" "http" (eq $rmqScheme "amqps")) $rmqHealthHost $rmqMgmtPort }}{{- end }}
{{ include $kv (dict "cm" $cm "p" $c.rabbitmq "f" "healthCheckUrl" "k" "RABBITMQ_HEALTH_CHECK_URL" "d" $rmqHealthDefault "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.rabbitmq "f" "healthCheckAllowedHosts" "k" "RABBITMQ_HEALTH_CHECK_ALLOWED_HOSTS" "d" $rmqHealthHost "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.rabbitmq "f" "requireHealthAllowedHosts" "k" "RABBITMQ_REQUIRE_HEALTH_ALLOWED_HOSTS" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $c.rabbitmq "f" "allowInsecureHealthCheck" "k" "RABBITMQ_ALLOW_INSECURE_HEALTH_CHECK" "d" (ternary "true" "false" $rmqBundled)) }}
{{ include $kv (dict "cm" $cm "p" $c.rabbitmq "f" "allowInsecureTls" "k" "RABBITMQ_ALLOW_INSECURE_TLS" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $c.rabbitmq "f" "publisherConfirmTimeoutMs" "k" "RABBITMQ_PUBLISHER_CONFIRM_TIMEOUT_MS" "d" "5000") }}
{{ include $kv (dict "cm" $cm "p" $c.rabbitmq "f" "publisherRecoveryInitialMs" "k" "RABBITMQ_PUBLISHER_RECOVERY_INITIAL_MS" "d" "1000") }}
{{ include $kv (dict "cm" $cm "p" $c.rabbitmq "f" "publisherRecoveryMaxMs" "k" "RABBITMQ_PUBLISHER_RECOVERY_MAX_MS" "d" "30000") }}
{{ include $kv (dict "cm" $cm "p" $c.rabbitmq "f" "publisherMaxRecoveries" "k" "RABBITMQ_PUBLISHER_MAX_RECOVERIES" "d" "10") }}
# --- Outbox (lib-commons; production requires it) -----------------------------
{{ include $kv (dict "cm" $cm "p" $c.outbox "f" "enabled" "k" "OUTBOX_ENABLED" "d" "true") }}
{{ include $kv (dict "cm" $cm "p" $c.outbox "f" "tableName" "k" "OUTBOX_TABLE_NAME" "d" "outbox_events") }}
{{ include $kv (dict "cm" $cm "p" $c.outbox "f" "dispatchIntervalSec" "k" "OUTBOX_DISPATCH_INTERVAL_SEC" "d" "2") }}
{{ include $kv (dict "cm" $cm "p" $c.outbox "f" "batchSize" "k" "OUTBOX_BATCH_SIZE" "d" "50") }}
{{ include $kv (dict "cm" $cm "p" $c.outbox "f" "publishMaxAttempts" "k" "OUTBOX_PUBLISH_MAX_ATTEMPTS" "d" "3") }}
{{ include $kv (dict "cm" $cm "p" $c.outbox "f" "publishBackoffMs" "k" "OUTBOX_PUBLISH_BACKOFF_MS" "d" "200") }}
{{ include $kv (dict "cm" $cm "p" $c.outbox "f" "retryWindowSec" "k" "OUTBOX_RETRY_WINDOW_SEC" "d" "300") }}
{{ include $kv (dict "cm" $cm "p" $c.outbox "f" "maxDispatchAttempts" "k" "OUTBOX_MAX_DISPATCH_ATTEMPTS" "d" "10") }}
{{ include $kv (dict "cm" $cm "p" $c.outbox "f" "processingTimeoutSec" "k" "OUTBOX_PROCESSING_TIMEOUT_SEC" "d" "600") }}
{{ include $kv (dict "cm" $cm "p" $c.outbox "f" "maxFailedPerBatch" "k" "OUTBOX_MAX_FAILED_PER_BATCH" "d" "25") }}
{{ include $kv (dict "cm" $cm "p" $c.outbox "f" "includeTenantMetrics" "k" "OUTBOX_INCLUDE_TENANT_METRICS" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $c.outbox "f" "priorityEventTypes" "k" "OUTBOX_PRIORITY_EVENT_TYPES" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.outbox "f" "allowEmptyTenant" "k" "OUTBOX_ALLOW_EMPTY_TENANT" "d" "true") }}
# --- Streaming: business facts on lerian.streaming.br-sta (lerian-common.streaming.env) --
STREAMING_ENABLED: {{ $streamingRaw | quote }}
{{ include $kv (dict "cm" $cm "p" $c.streaming "f" "cloudeventsSource" "k" "STREAMING_CLOUDEVENTS_SOURCE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.streaming "f" "clientId" "k" "STREAMING_CLIENT_ID" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.streaming "f" "cbFailureRatio" "k" "STREAMING_CB_FAILURE_RATIO" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.streaming "f" "cbMinRequests" "k" "STREAMING_CB_MIN_REQUESTS" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.streaming "f" "cbTimeoutSec" "k" "STREAMING_CB_TIMEOUT_S" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.streaming "f" "closeTimeoutSec" "k" "STREAMING_CLOSE_TIMEOUT_S" "opt" true) }}
{{- /* STREAMING_SASL_USERNAME may live in the Secret (common.secrets or an existing
   Secret): the library requires it in the ConfigMap/global when a mechanism is set,
   so it is fed a placeholder and that line is dropped — the Secret value is what
   the pods see. */}}
{{- $strmCm := deepCopy $cm }}
{{- $userFromSecret := eq (include "br-sta.saslUserFromSecret" .) "true" }}
{{- if $userFromSecret }}{{- $_ := set $strmCm "STREAMING_SASL_USERNAME" "from-secret" }}{{- end }}
{{- $strmOut := include "lerian-common.streaming.env" (dict "context" (dict "Values" (dict "global" (dict "streaming" (include "br-sta.streamingGlobal" . | fromYaml)))) "enabled" $streamingOn "configmap" $strmCm) }}
{{- if $userFromSecret }}{{- $strmOut = regexReplaceAll "(?m)^STREAMING_SASL_USERNAME: .*$" $strmOut "" }}{{- end }}
{{ $strmOut }}
# --- Inbound auth (plugin-access-manager); the app refuses a blank switch --------
PLUGIN_AUTH_ENABLED: {{ include "br-sta.authEnabled" . | quote }}
PLUGIN_AUTH_HOST: {{ include "lerian-common.globalValue" (dict "context" $ "configmap" $cm "block" "auth" "field" "host" "nativeKey" "PLUGIN_AUTH_HOST" "default" "") | quote }}
{{ include $kv (dict "cm" $cm "p" $c.auth "f" "trustedProxies" "k" "TRUSTED_PROXIES" "d" "") }}
# --- Access-manager declaration publisher (lib-auth, manager only) ----------------
{{ include $kv (dict "cm" $cm "p" $c.identity "f" "declarationEnabled" "k" "IDP_DECLARATION_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $c.identity "f" "host" "k" "IDP_HOST" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.identity "f" "m2mClientId" "k" "IDP_M2M_CLIENT_ID" "opt" true) }}
# --- M2M credential provider + AWS SDK ------------------------------------------
{{ include $kv (dict "cm" $cm "p" $c.m2m "f" "targetService" "k" "M2M_TARGET_SERVICE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.m2m "f" "credentialCacheTtlSec" "k" "M2M_CREDENTIAL_CACHE_TTL_SEC" "d" "300") }}
{{ include $kv (dict "cm" $cm "p" $c.aws "f" "region" "k" "AWS_REGION" "d" "us-east-1") }}
# --- OpenTelemetry (lerian-common.otel.env) ------------------------------------
{{ include "lerian-common.otel.env" (dict "context" $ "configmap" $cm "enabledDefault" "false" "endpointDefault" "localhost:4317" "deploymentEnvironmentDefault" $envName) }}
{{ include $kv (dict "cm" $cm "p" $c.observability "f" "serviceName" "k" "OTEL_RESOURCE_SERVICE_NAME" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.observability "f" "libraryName" "k" "OTEL_LIBRARY_NAME" "opt" true) }}
# --- Rate limiting (the app forces it on in production) ------------------------
{{ include $kv (dict "cm" $cm "p" $c.rateLimit "f" "enabled" "k" "RATE_LIMIT_ENABLED" "d" "true") }}
{{ include $kv (dict "cm" $cm "p" $c.rateLimit "f" "max" "k" "RATE_LIMIT_MAX" "d" "100") }}
{{ include $kv (dict "cm" $cm "p" $c.rateLimit "f" "windowSec" "k" "RATE_LIMIT_WINDOW_SEC" "d" "60") }}
{{ include $kv (dict "cm" $cm "p" $c.rateLimit "f" "aggressiveMax" "k" "AGGRESSIVE_RATE_LIMIT_MAX" "d" "100") }}
{{ include $kv (dict "cm" $cm "p" $c.rateLimit "f" "aggressiveWindowSec" "k" "AGGRESSIVE_RATE_LIMIT_WINDOW_SEC" "d" "60") }}
{{ include $kv (dict "cm" $cm "p" $c.rateLimit "f" "relaxedMax" "k" "RELAXED_RATE_LIMIT_MAX" "d" "1000") }}
{{ include $kv (dict "cm" $cm "p" $c.rateLimit "f" "relaxedWindowSec" "k" "RELAXED_RATE_LIMIT_WINDOW_SEC" "d" "60") }}
{{ include $kv (dict "cm" $cm "p" $c.rateLimit "f" "auditExportMax" "k" "AUDIT_EXPORT_RATE_LIMIT_MAX" "d" "10") }}
{{ include $kv (dict "cm" $cm "p" $c.rateLimit "f" "auditExportWindowSec" "k" "AUDIT_EXPORT_RATE_LIMIT_WINDOW_SEC" "d" "60") }}
# --- Swagger (the app forces it off in production) ----------------------------
{{ include $kv (dict "cm" $cm "p" $c.swagger "f" "enabled" "k" "SWAGGER_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $c.swagger "f" "title" "k" "SWAGGER_TITLE" "d" "BR-STA Service API") }}
{{ include $kv (dict "cm" $cm "p" $c.swagger "f" "version" "k" "SWAGGER_VERSION" "d" $imageTag) }}
{{ include $kv (dict "cm" $cm "p" $c.swagger "f" "basePath" "k" "SWAGGER_BASE_PATH" "d" "/") }}
{{ include $kv (dict "cm" $cm "p" $c.swagger "f" "leftDelim" "k" "SWAGGER_LEFT_DELIM" "d" "{{") }}
{{ include $kv (dict "cm" $cm "p" $c.swagger "f" "rightDelim" "k" "SWAGGER_RIGHT_DELIM" "d" "}}") }}
{{ include $kv (dict "cm" $cm "p" $c.swagger "f" "description" "k" "SWAGGER_DESCRIPTION" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.swagger "f" "host" "k" "SWAGGER_HOST" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.swagger "f" "schemes" "k" "SWAGGER_SCHEMES" "opt" true) }}
# --- Pagination + audit read API ------------------------------------------------
{{ include $kv (dict "cm" $cm "p" $c.pagination "f" "maxLimit" "k" "MAX_PAGINATION_LIMIT" "d" "100") }}
{{ include $kv (dict "cm" $cm "p" $c.pagination "f" "maxMonthDateRange" "k" "MAX_PAGINATION_MONTH_DATE_RANGE" "d" "3") }}
{{ include $kv (dict "cm" $cm "p" $c.auditApi "f" "defaultPageSize" "k" "AUDIT_API_DEFAULT_PAGE_SIZE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.auditApi "f" "maxPageSize" "k" "AUDIT_API_MAX_PAGE_SIZE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.auditApi "f" "maxExportDateRangeDays" "k" "AUDIT_API_MAX_EXPORT_DATE_RANGE_DAYS" "opt" true) }}
# --- Credential envelope encryption (KMS mask); MASTER_KEYS lives in the Secret --
MASTER_KEY_PROVIDER: {{ include "br-sta.kmsProvider" . | quote }}
{{ include $kv (dict "cm" $cm "p" $c.credentials "f" "masterKeyVersion" "k" "MASTER_KEY_VERSION" "d" "v1") }}
{{- $kmsKeyId := include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "keyId" "nativeKey" "MASTER_KEY_KMS_KEY_ID" "default" "") }}
{{- if $kmsKeyId }}
MASTER_KEY_KMS_KEY_ID: {{ $kmsKeyId | quote }}
{{- end }}
{{- $kmsRegion := include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "awsRegion" "nativeKey" "MASTER_KEY_KMS_REGION" "default" "") }}
{{- if $kmsRegion }}
MASTER_KEY_KMS_REGION: {{ $kmsRegion | quote }}
{{- end }}
# --- BACEN upstream + STA client redirect (dev/test mock only) -----------------
{{ include $kv (dict "cm" $cm "p" $c.bacen "f" "environment" "k" "BACEN_ENVIRONMENT" "d" "homologation") }}
{{- /* A set STA_* key activates the app's mock profile (and relaxes the production
   trust-store readiness gate), so they render only when set or derived from the
   bundled mock. */}}
{{ include $kv (dict "cm" $cm "p" $c.sta "f" "scheme" "k" "STA_SCHEME" "d" (ternary "http" "" $mockOn) "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.sta "f" "fileHost" "k" "STA_FILE_HOST" "d" (ternary (include "br-sta.mockStaHost" .) "" $mockOn) "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.sta "f" "passwordHost" "k" "STA_PASSWORD_HOST" "d" (ternary (include "br-sta.mockStaHost" .) "" $mockOn) "opt" true) }}
# --- BACEN transfers + object storage (lerian-common.objectStorage.value); keys in the Secret --
TRANSFER_OBJECT_STORAGE_BUCKET: {{ $os.transferBucket | quote }}
TRANSFER_S3_ENDPOINT: {{ $os.transferEndpoint | quote }}
TRANSFER_S3_REGION: {{ $os.transferRegion | quote }}
TRANSFER_S3_PATH_STYLE: {{ $os.transferPathStyle | quote }}
{{ include $kv (dict "cm" $cm "p" $c.transfer "f" "schedulerEnabled" "k" "TRANSFER_SCHEDULER_ENABLED" "d" "true") }}
{{ include $kv (dict "cm" $cm "p" $c.transfer "f" "inboundEnabled" "k" "TRANSFER_INBOUND_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $c.transfer "f" "maxFileSizeBytes" "k" "TRANSFER_MAX_FILE_SIZE_BYTES" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.transfer "f" "inboundMaxFileSizeBytes" "k" "TRANSFER_INBOUND_MAX_FILE_SIZE_BYTES" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.transfer "f" "inboundExtractMaxExpansionRatio" "k" "TRANSFER_INBOUND_EXTRACT_MAX_EXPANSION_RATIO" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.transfer "f" "inboundExtractMaxExtractedBytes" "k" "TRANSFER_INBOUND_EXTRACT_MAX_EXTRACTED_BYTES" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.transfer "f" "chunkSizeBytes" "k" "TRANSFER_CHUNK_SIZE_BYTES" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.transfer "f" "maxAttempts" "k" "TRANSFER_MAX_ATTEMPTS" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.transfer "f" "ttlHours" "k" "TRANSFER_TTL_HOURS" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.transfer "f" "pollIntervalSeconds" "k" "TRANSFER_POLL_INTERVAL_SECONDS" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.transfer "f" "workerConcurrency" "k" "TRANSFER_WORKER_CONCURRENCY" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.transfer "f" "inboundLockClassId" "k" "TRANSFER_INBOUND_LOCK_CLASS_ID" "opt" true) }}
{{- /* The manager serves audit-export downloads from the bucket the worker writes. */}}
AUDIT_EXPORT_GENERATOR_S3_BUCKET: {{ $os.auditBucket | quote }}
AUDIT_EXPORT_GENERATOR_S3_ENDPOINT: {{ $os.auditEndpoint | quote }}
AUDIT_EXPORT_GENERATOR_S3_REGION: {{ $os.auditRegion | quote }}
AUDIT_EXPORT_GENERATOR_S3_PATH_STYLE: {{ $os.auditPathStyle | quote }}
# --- Business-event delivery channel (RedPanda + RabbitMQ; production requires it) --
{{ include $kv (dict "cm" $cm "p" $c.businessEvents "f" "enabled" "k" "BUSINESS_EVENTS_ENABLED" "d" "true") }}
{{ include $kv (dict "cm" $cm "p" $c.businessEvents "f" "exchange" "k" "BUSINESS_EVENTS_EXCHANGE" "d" "sta.business.events") }}
{{ include $kv (dict "cm" $cm "p" $c.businessEvents "f" "intervalSec" "k" "BUSINESS_EVENTS_INTERVAL_SEC" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.businessEvents "f" "batchSize" "k" "BUSINESS_EVENTS_BATCH_SIZE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.businessEvents "f" "maxAttempts" "k" "BUSINESS_EVENTS_MAX_ATTEMPTS" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.businessEvents "f" "serviceName" "k" "BUSINESS_EVENTS_SERVICE_NAME" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.businessEvents "f" "lockClassId" "k" "BUSINESS_EVENTS_LOCK_CLASS_ID" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.businessEvents "f" "confirmTimeoutSec" "k" "BUSINESS_EVENTS_CONFIRM_TIMEOUT_SEC" "opt" true) }}
# --- Reporter -> BACEN bridge consumer ----------------------------------------------
{{ include $kv (dict "cm" $cm "p" $c.reporterEvents "f" "consumerEnabled" "k" "REPORTER_EVENTS_CONSUMER_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $c.reporterEvents "f" "exchange" "k" "REPORTER_EVENTS_CONSUMER_EXCHANGE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.reporterEvents "f" "queue" "k" "REPORTER_EVENTS_CONSUMER_QUEUE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.reporterEvents "f" "dlqExchange" "k" "REPORTER_EVENTS_CONSUMER_DLQ_EXCHANGE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.reporterEvents "f" "alternateExchange" "k" "REPORTER_EVENTS_CONSUMER_ALTERNATE_EXCHANGE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.reporterEvents "f" "idleWindowSec" "k" "REPORTER_EVENTS_CONSUMER_IDLE_WINDOW_SEC" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.reporterEvents "f" "dedupTtlSec" "k" "REPORTER_EVENTS_DEDUP_TTL_SEC" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.reporterEvents "f" "reconciliationWindowSec" "k" "REPORTER_EVENTS_RECONCILIATION_WINDOW_SEC" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.reporterEvents "f" "redeliveryWindowSec" "k" "REPORTER_EVENTS_REDELIVERY_WINDOW_SEC" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.reporterEvents "f" "doctypeResolver" "k" "REPORTER_EVENTS_DOCTYPE_RESOLVER" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $c.reporterEvents "f" "doctypeMap" "k" "REPORTER_EVENTS_DOCTYPE_MAP" "opt" true) }}
{{- end -}}

{{/*
br-sta.workerConfigmapData — the worker-only keys, rendered into the worker
ConfigMap that envFrom loads AFTER the shared one (a key here wins for the
worker). Every job toggle is explicit so the worker's behavior is readable from
the rendered ConfigMap; tuning knobs are emitted only when set (the app
envDefaults apply otherwise).
*/}}
{{- define "br-sta.workerConfigmapData" -}}
{{- $w := .Values.worker -}}
{{- $cm := $w.configmap | default dict -}}
{{- $kv := "br-sta.kv" -}}
{{- $os := include "br-sta.objectStorage" . | fromYaml -}}
# --- Probe server bind (WorkerMode: /health, /readyz, /version, /metrics) --------
{{ include $kv (dict "cm" $cm "p" dict "f" "address" "k" "SERVER_ADDRESS" "d" (printf "0.0.0.0:%v" ($w.port | default 4029))) }}
# --- Scheduler (leader-gated BACEN verdict polling + maintenance jobs) -----------
{{- $s := $w.scheduler | default dict }}
{{ include $kv (dict "cm" $cm "p" $s "f" "enabled" "k" "SCHEDULER_ENABLED" "d" "true") }}
{{ include $kv (dict "cm" $cm "p" $s "f" "serviceName" "k" "SCHEDULER_SERVICE_NAME" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $s "f" "leaderTtlSeconds" "k" "SCHEDULER_LEADER_TTL_SECONDS" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $s "f" "heartbeatSeconds" "k" "SCHEDULER_HEARTBEAT_SECONDS" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $s "f" "credentialIntervalHours" "k" "SCHEDULER_CREDENTIAL_INTERVAL_HOURS" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $s "f" "staleCleanupIntervalHours" "k" "SCHEDULER_STALE_CLEANUP_INTERVAL_HOURS" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $s "f" "retentionIntervalHours" "k" "SCHEDULER_RETENTION_INTERVAL_HOURS" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $s "f" "quarantineRetentionDays" "k" "SCHEDULER_QUARANTINE_RETENTION_DAYS" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $s "f" "filingSweepEnabled" "k" "SCHEDULER_FILING_SWEEP_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $s "f" "filingSweepIntervalMinutes" "k" "SCHEDULER_FILING_SWEEP_INTERVAL_MINUTES" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $s "f" "filingSweepAgeMinutes" "k" "SCHEDULER_FILING_SWEEP_AGE_MINUTES" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $s "f" "filingSweepBatchLimit" "k" "SCHEDULER_FILING_SWEEP_BATCH_LIMIT" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $w.credentials "f" "recoveryOnBoot" "k" "CREDENTIALS_RECOVERY_ON_BOOT" "d" "true") }}
# --- Audit trail (publisher -> RabbitMQ -> consumer -> hash-chained tables) ------
{{- $ap := $w.auditPublisher | default dict }}
{{ include $kv (dict "cm" $cm "p" $ap "f" "enabled" "k" "AUDIT_PUBLISHER_ENABLED" "d" "true") }}
{{ include $kv (dict "cm" $cm "p" $ap "f" "intervalSec" "k" "AUDIT_PUBLISHER_INTERVAL_SEC" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $ap "f" "batchSize" "k" "AUDIT_PUBLISHER_BATCH_SIZE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $ap "f" "maxAttempts" "k" "AUDIT_PUBLISHER_MAX_ATTEMPTS" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $ap "f" "exchange" "k" "AUDIT_PUBLISHER_EXCHANGE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $ap "f" "lockClassId" "k" "AUDIT_PUBLISHER_LOCK_CLASS_ID" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $ap "f" "serviceName" "k" "AUDIT_PUBLISHER_SERVICE_NAME" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $ap "f" "alternateExchange" "k" "AUDIT_PUBLISHER_ALTERNATE_EXCHANGE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $ap "f" "confirmTimeoutSec" "k" "AUDIT_PUBLISHER_CONFIRM_TIMEOUT_SEC" "opt" true) }}
{{- $ac := $w.auditConsumer | default dict }}
{{ include $kv (dict "cm" $cm "p" $ac "f" "enabled" "k" "AUDIT_CONSUMER_ENABLED" "d" "true") }}
{{ include $kv (dict "cm" $cm "p" $ac "f" "queue" "k" "AUDIT_CONSUMER_QUEUE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $ac "f" "exchange" "k" "AUDIT_CONSUMER_EXCHANGE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $ac "f" "dedupTtlSec" "k" "AUDIT_CONSUMER_DEDUP_TTL_SEC" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $ac "f" "lockClassId" "k" "AUDIT_CONSUMER_LOCK_CLASS_ID" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $ac "f" "maxRetryAttempts" "k" "AUDIT_CONSUMER_MAX_RETRY_ATTEMPTS" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $ac "f" "dlqExchange" "k" "AUDIT_CONSUMER_DLQ_EXCHANGE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $ac "f" "serviceName" "k" "AUDIT_CONSUMER_SERVICE_NAME" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $ac "f" "alternateExchange" "k" "AUDIT_CONSUMER_ALTERNATE_EXCHANGE" "opt" true) }}
{{- $apm := $w.auditPartition | default dict }}
{{ include $kv (dict "cm" $cm "p" $apm "f" "enabled" "k" "AUDIT_PARTITION_MANAGER_ENABLED" "d" "true") }}
{{ include $kv (dict "cm" $cm "p" $apm "f" "intervalHours" "k" "AUDIT_PARTITION_INTERVAL_HOURS" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $apm "f" "lookaheadMonths" "k" "AUDIT_PARTITION_LOOKAHEAD_MONTHS" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $apm "f" "serviceName" "k" "AUDIT_PARTITION_SERVICE_NAME" "opt" true) }}
{{- $acl := $w.auditCleanup | default dict }}
{{ include $kv (dict "cm" $cm "p" $acl "f" "enabled" "k" "AUDIT_CLEANUP_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $acl "f" "intervalHours" "k" "AUDIT_CLEANUP_INTERVAL_HOURS" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $acl "f" "retentionDays" "k" "AUDIT_CLEANUP_RETENTION_DAYS" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $acl "f" "serviceName" "k" "AUDIT_CLEANUP_SERVICE_NAME" "opt" true) }}
{{- $av := $w.auditVerifier | default dict }}
{{ include $kv (dict "cm" $cm "p" $av "f" "enabled" "k" "AUDIT_VERIFIER_ENABLED" "d" "true") }}
{{ include $kv (dict "cm" $cm "p" $av "f" "intervalHours" "k" "AUDIT_VERIFIER_INTERVAL_HOURS" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $av "f" "sampleRows" "k" "AUDIT_VERIFIER_SAMPLE_ROWS" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $av "f" "serviceName" "k" "AUDIT_VERIFIER_SERVICE_NAME" "opt" true) }}
{{- $ae := $w.auditExportGenerator | default dict }}
{{ include $kv (dict "cm" $cm "p" $ae "f" "enabled" "k" "AUDIT_EXPORT_GENERATOR_ENABLED" "d" (ternary "true" "false" (ne $os.auditBucket ""))) }}
{{ include $kv (dict "cm" $cm "p" $ae "f" "intervalSec" "k" "AUDIT_EXPORT_GENERATOR_INTERVAL_SEC" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $ae "f" "batchSize" "k" "AUDIT_EXPORT_GENERATOR_BATCH_SIZE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $ae "f" "objectPrefix" "k" "AUDIT_EXPORT_GENERATOR_OBJECT_PREFIX" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $ae "f" "serviceName" "k" "AUDIT_EXPORT_GENERATOR_SERVICE_NAME" "opt" true) }}
{{- end -}}

{{/*
br-sta.secretData — the chart-modeled Secret keys (stringData lines).
Infra passwords are written only for EXTERNAL infra without an
<subchart>.auth.existingSecret (the bundled Bitnami path is single-sourced from
the subchart Secret via secretKeyRef on the Deployments). With the bundled
RabbitMQ the broker reads RABBITMQ_DEFAULT_USER / _PASS / RABBITMQ_ERLANG_COOKIE
from THIS Secret (Pattern B). Streaming and multi-tenant keys come from the
lerian-common companion helpers, which also fail fast when a required one is
missing.
*/}}
{{- define "br-sta.secretData" -}}
{{- $c := .Values.common -}}
{{- $s := $c.secrets | default dict -}}
{{- $cm := $c.configmap | default dict -}}
{{- $x := include "br-sta.extraEnv" . | fromYaml -}}
{{- $pgAuth := (.Values.postgresql | default dict).auth | default dict -}}
{{- $vkAuth := (.Values.valkey | default dict).auth | default dict -}}
{{- $pgInternal := eq (include "br-sta.postgresInternal" .) "true" -}}
{{- $vkInternal := eq (include "br-sta.valkeyInternal" .) "true" -}}
{{- if and (not $pgInternal) (not $pgAuth.existingSecret) $s.POSTGRES_PASSWORD }}
POSTGRES_PASSWORD: {{ $s.POSTGRES_PASSWORD | quote }}
{{- end }}
{{- if and (not $vkInternal) (not $vkAuth.existingSecret) $s.REDIS_PASSWORD }}
REDIS_PASSWORD: {{ $s.REDIS_PASSWORD | quote }}
{{- end }}
{{- if eq (include "br-sta.rabbitmqEnabled" .) "true" }}
{{- /* Bundled broker (Pattern B): the broker's initial user is read from here. */}}
RABBITMQ_DEFAULT_USER: {{ include "br-sta.rabbitmqUser" . | quote }}
{{- end }}
{{- /* ORGANIZATION_IDS (an identifier whose home is common.license.organizationIds)
   is also accepted in common.secrets for tiers that source it from the secret
   store: it flows through the verbatim pass-through below, and the production
   gate counts it there. */}}
{{- range $k := list "RABBITMQ_DEFAULT_PASS" "RABBITMQ_URL" "RABBITMQ_ERLANG_COOKIE" "POSTGRES_REPLICA_PASSWORD" "MASTER_KEYS" "LICENSE_KEY" "AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" "IDP_M2M_CLIENT_SECRET" }}
{{- with index $s $k }}
{{ $k }}: {{ . | quote }}
{{- end }}
{{- end }}
{{- /* Streaming SASL password / CA cert, with the mechanism and username resolved
   with the same configmap-over-global precedence as the ConfigMap. When the
   password already reaches the pods as an explicit extraEnvVars entry, the
   helper's fail-fast is skipped and only the CA is copied here. */}}
{{- $gs := (.Values.global | default dict).streaming | default dict }}
{{- $saslMech := $gs.saslMechanism | default "" }}
{{- if hasKey $cm "STREAMING_SASL_MECHANISM" }}{{- $saslMech = index $cm "STREAMING_SASL_MECHANISM" }}{{- end }}
{{- $saslUser := $gs.saslUsername | default "" }}
{{- if hasKey $cm "STREAMING_SASL_USERNAME" }}{{- $saslUser = index $cm "STREAMING_SASL_USERNAME" }}{{- end }}
{{- $streamingOn := eq (include "br-sta.isTrue" (include "br-sta.streamingEnabledRaw" .)) "true" }}
{{- if hasKey $x "STREAMING_SASL_PASSWORD" }}
{{- with $s.STREAMING_TLS_CA_CERT }}
STREAMING_TLS_CA_CERT: {{ . | quote }}
{{- end }}
{{- else }}
{{- if eq (include "br-sta.saslUserFromSecret" .) "true" }}{{- $saslUser = "from-secret" }}{{- end }}
{{ include "lerian-common.streaming.secret" (dict "context" . "secrets" $s "secretName" (include "br-sta.fullname" .) "valuesPrefix" "common.secrets." "mode" "stringData" "enabled" $streamingOn "useExistingSecret" false "saslMechanism" $saslMech "saslUsername" $saslUser) }}
{{- end }}
{{- /* Multi-tenant service API key (required when MT is on) + tenant Redis password. */}}
{{- $mtOn := eq (include "br-sta.multiTenantEnabled" .) "true" }}
{{- if hasKey $x "MULTI_TENANT_SERVICE_API_KEY" }}
{{- with $s.MULTI_TENANT_REDIS_PASSWORD }}
MULTI_TENANT_REDIS_PASSWORD: {{ . | quote }}
{{- end }}
{{- else }}
{{ include "lerian-common.multiTenant.secret" (dict "context" . "secrets" $s "secretName" (include "br-sta.fullname" .) "valuesPrefix" "common.secrets." "mode" "stringData" "enabled" $mtOn "useExistingSecret" false) }}
{{- end }}
{{- end -}}

{{/*
br-sta.required — fail with an actionable message when KEY does not reach the
pods from any source. Inputs: context, key, value (resolved ConfigMap value,
opt), secret (bool: the key is a credential, so useExistingSecret satisfies it),
why (condition text), set (where to set it).
*/}}
{{- define "br-sta.required" -}}
{{- $ctx := .context -}}
{{- $key := .key -}}
{{- /* An explicit empty literal in a pod's extraEnvVars overrides every other
   source for that pod (env beats envFrom), so it is a missing value there. */ -}}
{{- range $comp := list "manager" "worker" -}}
{{- if (index $ctx.Values $comp | default dict).enabled -}}
{{- $cx := include "br-sta.componentExtraEnv" (dict "root" $ctx "component" $comp) | fromYaml | default dict -}}
{{- if and (hasKey $cx $key) (not (trim (toString (index $cx $key)))) -}}
{{- fail (printf "\n\nERROR: br-sta: %s is set to an empty value in %s.extraEnvVars, which overrides the ConfigMap/Secret for that pod.\n  set: a non-empty value (or remove the entry)\n" $key $comp) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- $skip := and .secret $ctx.Values.common.useExistingSecret -}}
{{- if and (not $skip) (not (include "br-sta.provided" (dict "context" $ctx "key" .key "value" .value))) -}}
{{- fail (printf "\n\nERROR: br-sta: %s is required %s.\n  set: %s\n  (or pass it as an extraEnvVars entry on BOTH manager and worker%s)\n" .key .why .set (ternary " / via common.useExistingSecret" "" (eq (toString .secret) "true"))) -}}
{{- end -}}
{{- end -}}

{{/*
br-sta.bundleGuard — the Redpanda bundle (single plaintext broker) and the mock
STA server (a BACEN stand-in) are dev-only and refused outside a
development-class environment. The postgresql / valkey / rabbitmq / seaweedfs
bundles are allowed, as in the sibling charts, but NOTES.txt warns.
*/}}
{{- define "br-sta.bundleGuard" -}}
{{- if ne (include "br-sta.devClass" .) "true" -}}
{{- $bad := list -}}
{{- if eq (include "br-sta.redpandaEnabled" .) "true" -}}{{- $bad = append $bad "redpandaBundle / redpanda (single broker, no TLS, no SASL)" -}}{{- end -}}
{{- if eq (include "br-sta.mockStaEnabled" .) "true" -}}{{- $bad = append $bad "mockSta (a BACEN STA simulator: transfers would never reach BACEN)" -}}{{- end -}}
{{- if $bad -}}
{{- fail (printf "\n\nERROR: br-sta: dev-only bundle enabled outside a development-class environment (ENV_NAME=%q):\n  - %s\n  Use an external Kafka/Redpanda (global.streaming) and the real BACEN STA, or set global.env.name to development|develop|dev|local|test for a dev install (values-dev.yaml).\n" (include "br-sta.envName" .) (join "\n  - " $bad)) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
br-sta.validate — fail-fast gates mirroring the app's boot validation
(internal/bootstrap/config_validation.go, config_auth_switch.go,
config_streaming.go), so a values mistake fails the render instead of
CrashLooping the pods. Invoked from the shared ConfigMap.
*/}}
{{- define "br-sta.validate" -}}
{{- $ := . -}}
{{- $c := .Values.common -}}
{{- $s := $c.secrets | default dict -}}
{{- include "br-sta.bundleGuard" . -}}
{{- $data := include "br-sta.configmapData" . | fromYaml -}}
{{- $req := "br-sta.required" -}}
{{- $prod := eq (include "br-sta.production" .) "true" -}}
{{- $devClass := eq (include "br-sta.devClass" .) "true" -}}
{{- $envName := include "br-sta.envName" . -}}
{{- $mtOn := eq (include "br-sta.multiTenantEnabled" .) "true" -}}
{{- $isTrue := "br-sta.isTrue" -}}
{{- /* Inbound auth switch (shared/envclass.ResolveAuthSwitch). */ -}}
{{- $auth := toString (index $data "PLUGIN_AUTH_ENABLED") -}}
{{- if not (has $auth (list "true" "false")) -}}
{{- fail (printf "\n\nERROR: br-sta: PLUGIN_AUTH_ENABLED must be exactly \"true\" or \"false\" (got %q).\n  set: global.auth.enabled\n" $auth) -}}
{{- end -}}
{{- if eq $auth "false" -}}
{{- if not $devClass -}}
{{- fail (printf "\n\nERROR: br-sta: PLUGIN_AUTH_ENABLED=false is only accepted in a development-class environment (development, develop, dev, local, test); ENV_NAME=%q.\n  set: global.auth.enabled=true + global.auth.host, or global.env.name for a dev install\n" $envName) -}}
{{- end -}}
{{- if eq (lower (toString (index $data "DEPLOYMENT_MODE" | default ""))) "saas" -}}
{{- fail "\n\nERROR: br-sta: PLUGIN_AUTH_ENABLED=false is never accepted with DEPLOYMENT_MODE=saas.\n  set: global.auth.enabled=true + global.auth.host\n" -}}
{{- end -}}
{{- else -}}
{{- include $req (dict "context" $ "key" "PLUGIN_AUTH_HOST" "value" (index $data "PLUGIN_AUTH_HOST") "why" (printf "when PLUGIN_AUTH_ENABLED=true (the chart default outside a development-class environment; ENV_NAME=%q)" $envName) "set" "global.auth.host") -}}
{{- end -}}
{{- if and $mtOn (ne $auth "true") -}}
{{- fail "\n\nERROR: br-sta: PLUGIN_AUTH_ENABLED must be true when MULTI_TENANT_ENABLED=true.\n  set: global.auth.enabled=true + global.auth.host\n" -}}
{{- end -}}
{{- /* CORS origin. The middleware treats an empty origin as "*". In production a
   wildcard is refused outright (explicit trusted origins only), opt-in or not;
   elsewhere it needs lib-commons' explicit opt-in. */ -}}
{{- $acOrigin := nospace (toString (index $data "ACCESS_CONTROL_ALLOW_ORIGIN")) -}}
{{- $corsWildcardOptIn := eq (include $isTrue (index $data "ALLOW_CORS_WILDCARD" | default "")) "true" -}}
{{- if and $prod (or (has "*" (splitList "," $acOrigin)) (and (not $acOrigin) $corsWildcardOptIn)) -}}
{{- fail "\n\nERROR: br-sta: a wildcard CORS origin (\"*\", or an empty origin with ALLOW_CORS_WILDCARD=true) is not allowed in production.\n  set: common.cors.allowedOrigins to the explicit trusted origins (CSV)\n" -}}
{{- end -}}
{{- if and (has "*" (splitList "," (nospace (toString (index $data "ACCESS_CONTROL_ALLOW_ORIGIN"))))) (ne (include $isTrue (index $data "ALLOW_CORS_WILDCARD" | default "")) "true") -}}
{{- fail "\n\nERROR: br-sta: the CORS origin is \"*\" without ALLOW_CORS_WILDCARD=true (lib-commons' CORS middleware would silently fall back to deny-all).\n  set: common.cors.allowedOrigins to the real origins (recommended), or common.security.allowCorsWildcard=true\n" -}}
{{- end -}}
{{- /* Server TLS: both files or neither. */ -}}
{{- if ne (empty (index $data "SERVER_TLS_CERT_FILE")) (empty (index $data "SERVER_TLS_KEY_FILE")) -}}
{{- fail "\n\nERROR: br-sta: SERVER_TLS_CERT_FILE and SERVER_TLS_KEY_FILE must be set together.\n  set: common.server.tlsCertFile + common.server.tlsKeyFile\n" -}}
{{- end -}}
{{- /* Credential envelope encryption: ALWAYS on (the manager aborts boot without key material). */ -}}
{{- $provider := toString (index $data "MASTER_KEY_PROVIDER") -}}
{{- if not (has $provider (list "envvar" "aws-kms")) -}}
{{- fail (printf "\n\nERROR: br-sta: MASTER_KEY_PROVIDER must be envvar or aws-kms (got %q).\n  set: global.kms.vendor (envvar | aws)\n" $provider) -}}
{{- end -}}
{{- $keyVersion := trim (toString (index $data "MASTER_KEY_VERSION")) -}}
{{- if not $keyVersion -}}
{{- fail "\n\nERROR: br-sta: MASTER_KEY_VERSION is required (the active version inside MASTER_KEYS).\n  set: common.credentials.masterKeyVersion\n" -}}
{{- end -}}
{{- include $req (dict "context" $ "key" "MASTER_KEYS" "secret" true "why" "(the credential envelope-encryption key material: the manager aborts boot without it)" "set" "common.secrets.MASTER_KEYS (\"v1:<64 hex chars>\" for envvar; \"v1:<base64 KMS ciphertext>\" for aws-kms)") -}}
{{- $mk := toString ($s.MASTER_KEYS | default "") -}}
{{- /* Shape check only on literal key material: an AVP <path:...> or any <placeholder>
   is resolved outside Helm. */ -}}
{{- if and $mk (not (contains "<" $mk)) (not $c.useExistingSecret) -}}
{{- $versions := list -}}
{{- range $entry := splitList "," $mk -}}
{{- $entry = trim $entry -}}
{{- if $entry -}}
{{- $parts := splitList ":" $entry -}}
{{- if or (lt (len $parts) 2) (not (trim (first $parts))) (not (trim (join ":" (rest $parts)))) -}}
{{- fail "\n\nERROR: br-sta: MASTER_KEYS must be a comma-separated list of \"version:key\" entries.\n  set: common.secrets.MASTER_KEYS\n" -}}
{{- end -}}
{{- $keyMaterial := trim (join ":" (rest $parts)) -}}
{{- if and (eq $provider "envvar") (not (regexMatch "^([0-9a-fA-F]{2})+$" $keyMaterial)) -}}
{{- fail (printf "\n\nERROR: br-sta: MASTER_KEYS entry %q is not hex-encoded key material (MASTER_KEY_PROVIDER=envvar). Generate one with: openssl rand -hex 32\n  set: common.secrets.MASTER_KEYS\n" (trim (first $parts))) -}}
{{- end -}}
{{- $versions = append $versions (trim (first $parts)) -}}
{{- end -}}
{{- end -}}
{{- if not (has $keyVersion $versions) -}}
{{- fail (printf "\n\nERROR: br-sta: MASTER_KEY_VERSION=%q must reference a key present in MASTER_KEYS (versions: %s).\n  set: common.credentials.masterKeyVersion or common.secrets.MASTER_KEYS\n" $keyVersion (join ", " $versions)) -}}
{{- end -}}
{{- end -}}
{{- if eq $provider "aws-kms" -}}
{{- include $req (dict "context" $ "key" "MASTER_KEY_KMS_KEY_ID" "value" (index $data "MASTER_KEY_KMS_KEY_ID") "why" "when MASTER_KEY_PROVIDER=aws-kms" "set" "global.kms.keyId (or common.kms.keyId)") -}}
{{- end -}}
{{- /* Single-tenant datastores. */ -}}
{{- if not $mtOn -}}
{{- include $req (dict "context" $ "key" "POSTGRES_HOST" "value" (index $data "POSTGRES_HOST") "why" "when multi-tenancy is off (or enable the bundled postgresql subchart)" "set" "global.datastores.postgres.host") -}}
{{- include $req (dict "context" $ "key" "REDIS_HOST" "value" (index $data "REDIS_HOST") "why" "when multi-tenancy is off (or enable the bundled valkey subchart)" "set" "global.datastores.redis.host (host:port)") -}}
{{- end -}}
{{- $pgAuth := (.Values.postgresql | default dict).auth | default dict -}}
{{- $pgExternal := and (ne (include "br-sta.postgresInternal" .) "true") (not $pgAuth.existingSecret) -}}
{{- if $prod -}}
{{- if $pgExternal -}}
{{- include $req (dict "context" $ "key" "POSTGRES_PASSWORD" "secret" true "why" "in production (ENV_NAME=production)" "set" "common.secrets.POSTGRES_PASSWORD") -}}
{{- end -}}
{{- if eq (lower (toString (index $data "POSTGRES_SSLMODE"))) "disable" -}}
{{- fail "\n\nERROR: br-sta: POSTGRES_SSLMODE=disable is not allowed in production.\n  set: global.datastores.postgres.ssl (require | verify-ca | verify-full)\n" -}}
{{- end -}}
{{- if eq (lower (toString (index $data "POSTGRES_REPLICA_SSLMODE" | default ""))) "disable" -}}
{{- fail "\n\nERROR: br-sta: POSTGRES_REPLICA_SSLMODE=disable is not allowed in production.\n" -}}
{{- end -}}
{{- end -}}
{{- /* RabbitMQ: the audit transport + business channel. */ -}}
{{- $rmqOn := eq (include $isTrue (index $data "RABBITMQ_ENABLED")) "true" -}}
{{- /* With useExistingSecret a full RABBITMQ_URL may live in the operator Secret. */ -}}
{{- if and $rmqOn (not (index $data "RABBITMQ_HOST")) (not (include "br-sta.provided" (dict "context" $ "key" "RABBITMQ_URL"))) (not $c.useExistingSecret) -}}
{{- fail "\n\nERROR: br-sta: RABBITMQ_HOST (or a full RABBITMQ_URL secret) is required when RABBITMQ_ENABLED=true (the default: the audit transport is mandatory in production).\n  set: global.datastores.broker.host (or common.secrets.RABBITMQ_URL), or enable the bundled rabbitmq subchart\n" -}}
{{- end -}}
{{- if and $rmqOn (not (trim (toString (index $data "RABBITMQ_HEALTH_CHECK_URL" | default "")))) -}}
{{- fail "\n\nERROR: br-sta: RABBITMQ_HEALTH_CHECK_URL is required when RABBITMQ_ENABLED=true (lib-commons checks the management API on every connect and refuses an empty URL). It defaults to <http|https>://<broker host>:<broker port>/api/health/checks/alarms once global.datastores.broker.host is set.\n  set: common.rabbitmq.healthCheckUrl (or global.datastores.broker.host / .port)\n" -}}
{{- end -}}
{{- if and $rmqOn (hasPrefix "http://" (toString (index $data "RABBITMQ_HEALTH_CHECK_URL" | default ""))) (ne (include $isTrue (index $data "RABBITMQ_ALLOW_INSECURE_HEALTH_CHECK")) "true") -}}
{{- fail "\n\nERROR: br-sta: RABBITMQ_HEALTH_CHECK_URL is plain http but RABBITMQ_ALLOW_INSECURE_HEALTH_CHECK is not true (lib-commons refuses basic auth over http).\n  set: an https management endpoint (global.datastores.broker.scheme: amqps / common.rabbitmq.healthCheckUrl), or common.rabbitmq.allowInsecureHealthCheck=true (non-production)\n" -}}
{{- end -}}
{{- if and $rmqOn $prod (not (include "br-sta.provided" (dict "context" $ "key" "RABBITMQ_URL"))) (not (eq (include "br-sta.rabbitmqEnabled" .) "true")) -}}
{{- include $req (dict "context" $ "key" "RABBITMQ_DEFAULT_PASS" "secret" true "why" "in production (the app otherwise falls back to guest)" "set" "common.secrets.RABBITMQ_DEFAULT_PASS (or a full common.secrets.RABBITMQ_URL)") -}}
{{- end -}}
{{- if eq (include "br-sta.rabbitmqEnabled" .) "true" -}}
{{- $rmqAuth := (.Values.rabbitmq | default dict).authentication | default dict -}}
{{- if ne (toString $rmqAuth.existingSecret) (include "br-sta.secretName" .) -}}
{{- fail (printf "\n\nERROR: br-sta: the bundled rabbitmq reads its credentials from the app Secret, but rabbitmq.authentication.existingSecret=%q while the app Secret is %q.\n  set: rabbitmq.authentication.existingSecret=%s\n" (toString $rmqAuth.existingSecret) (include "br-sta.secretName" .) (include "br-sta.secretName" .)) -}}
{{- end -}}
{{- include $req (dict "context" $ "key" "RABBITMQ_DEFAULT_PASS" "secret" true "why" "when the bundled rabbitmq is enabled (it is the broker's only login)" "set" "common.secrets.RABBITMQ_DEFAULT_PASS") -}}
{{- include $req (dict "context" $ "key" "RABBITMQ_ERLANG_COOKIE" "secret" true "why" "when the bundled rabbitmq is enabled (mandatory; must stay STABLE across upgrades — openssl rand -hex 32)" "set" "common.secrets.RABBITMQ_ERLANG_COOKIE") -}}
{{- end -}}
{{- if $prod -}}
{{- if not $rmqOn -}}
{{- fail "\n\nERROR: br-sta: RABBITMQ_ENABLED must be true in production (the audit transport is mandatory).\n  set: common.rabbitmq.enabled=true\n" -}}
{{- end -}}
{{- if ne (include $isTrue (index $data "OUTBOX_ENABLED")) "true" -}}
{{- fail "\n\nERROR: br-sta: OUTBOX_ENABLED must be true in production (the audit transport is mandatory).\n  set: common.outbox.enabled=true\n" -}}
{{- end -}}
{{- range $k := list "RABBITMQ_ALLOW_INSECURE_TLS" "RABBITMQ_ALLOW_INSECURE_HEALTH_CHECK" -}}
{{- if eq (include $isTrue (index $data $k)) "true" -}}
{{- fail (printf "\n\nERROR: br-sta: %s=true is not allowed in production.\n" $k) -}}
{{- end -}}
{{- end -}}
{{- /* Transfer bucket, business channel and license: production-only gates. */ -}}
{{- include $req (dict "context" $ "key" "TRANSFER_OBJECT_STORAGE_BUCKET" "value" (index $data "TRANSFER_OBJECT_STORAGE_BUCKET") "why" "in production (the bucket that holds both transfer directions)" "set" "global.objectStorage.sta.bucket (or common.objectStorage.sta.bucket)") -}}
{{- if ne (include $isTrue (index $data "BUSINESS_EVENTS_ENABLED")) "true" -}}
{{- fail "\n\nERROR: br-sta: BUSINESS_EVENTS_ENABLED must be true in production (outbound result delivery is mandatory).\n  set: common.businessEvents.enabled=true\n" -}}
{{- end -}}
{{- if not (trim (toString (index $data "BUSINESS_EVENTS_EXCHANGE"))) -}}
{{- fail "\n\nERROR: br-sta: BUSINESS_EVENTS_EXCHANGE is required in production.\n  set: common.businessEvents.exchange\n" -}}
{{- end -}}
{{- include $req (dict "context" $ "key" "LICENSE_KEY" "secret" true "why" "in production (ENV_NAME=production; any other ENV_NAME runs without license enforcement)" "set" "common.secrets.LICENSE_KEY") -}}
{{- include $req (dict "context" $ "key" "ORGANIZATION_IDS" "value" (index $data "ORGANIZATION_IDS") "secret" true "why" "in production" "set" "common.license.organizationIds") -}}
{{- end -}}
{{- /* Streaming: brokers + the pinned CloudEvents source. */ -}}
{{- if eq (include $isTrue (index $data "STREAMING_ENABLED")) "true" -}}
{{- include $req (dict "context" $ "key" "STREAMING_BROKERS" "value" (index $data "STREAMING_BROKERS") "why" "when STREAMING_ENABLED=true" "set" "global.streaming.brokers (or enable the bundled redpanda for a dev install)") -}}
{{- end -}}
{{- $ceSource := index $data "STREAMING_CLOUDEVENTS_SOURCE" | default "" -}}
{{- if and (hasKey $data "STREAMING_CLOUDEVENTS_SOURCE") (ne (toString $ceSource) "br-sta") -}}
{{- fail (printf "\n\nERROR: br-sta: STREAMING_CLOUDEVENTS_SOURCE must be left unset or equal \"br-sta\" exactly (got %q): the topic and the Kafka ACLs derive from it and the app refuses to boot otherwise.\n" (toString $ceSource)) -}}
{{- end -}}
{{- /* Access-manager declaration publisher. */ -}}
{{- if eq (include $isTrue (index $data "IDP_DECLARATION_ENABLED")) "true" -}}
{{- include $req (dict "context" $ "key" "IDP_HOST" "value" (index $data "IDP_HOST") "why" "when IDP_DECLARATION_ENABLED=true" "set" "common.identity.host") -}}
{{- include $req (dict "context" $ "key" "IDP_M2M_CLIENT_ID" "value" (index $data "IDP_M2M_CLIENT_ID") "why" "when IDP_DECLARATION_ENABLED=true" "set" "common.identity.m2mClientId") -}}
{{- include $req (dict "context" $ "key" "IDP_M2M_CLIENT_SECRET" "secret" true "why" "when IDP_DECLARATION_ENABLED=true" "set" "common.secrets.IDP_M2M_CLIENT_SECRET") -}}
{{- end -}}
{{- /* M2M target service is interpolated into a Valkey key suffix. */ -}}
{{- if contains ":" (toString (index $data "M2M_TARGET_SERVICE" | default "")) -}}
{{- fail "\n\nERROR: br-sta: M2M_TARGET_SERVICE must not contain ':' (it is interpolated into the Valkey credential key suffix).\n" -}}
{{- end -}}
{{- /* Reporter -> BACEN bridge: no default exchange or resolver by design. */ -}}
{{- if eq (include $isTrue (index $data "REPORTER_EVENTS_CONSUMER_ENABLED")) "true" -}}
{{- include $req (dict "context" $ "key" "REPORTER_EVENTS_CONSUMER_EXCHANGE" "value" (index $data "REPORTER_EVENTS_CONSUMER_EXCHANGE") "why" "when the reporter-events consumer is on (no default by design)" "set" "common.reporterEvents.exchange") -}}
{{- $resolver := toString (index $data "REPORTER_EVENTS_DOCTYPE_RESOLVER" | default "") -}}
{{- if not (has $resolver (list "payload" "static")) -}}
{{- fail (printf "\n\nERROR: br-sta: REPORTER_EVENTS_DOCTYPE_RESOLVER must be payload or static when the reporter-events consumer is on (got %q).\n  set: common.reporterEvents.doctypeResolver=payload\n" $resolver) -}}
{{- end -}}
{{- if and (eq $resolver "static") (or $prod (ne (toString (index $data "BACEN_ENVIRONMENT")) "homologation")) -}}
{{- fail "\n\nERROR: br-sta: REPORTER_EVENTS_DOCTYPE_RESOLVER=static is refused in production and outside BACEN_ENVIRONMENT=homologation.\n  set: common.reporterEvents.doctypeResolver=payload\n" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
br-sta.waitScript — the wait-for-dependencies initContainer script: Postgres,
Redis and RabbitMQ, each skipped when its host is empty (multi-tenant / URL).
*/}}
{{- define "br-sta.waitScript" -}}
if [ -n "$POSTGRES_HOST" ]; then
  echo "waiting for postgres $POSTGRES_HOST:${POSTGRES_PORT:-5432}...";
  until nc -z "$POSTGRES_HOST" "${POSTGRES_PORT:-5432}"; do echo "postgres not ready, waiting..."; sleep 5; done;
fi;
if [ -n "$REDIS_HOST" ]; then
  RH=$(echo "$REDIS_HOST" | cut -d: -f1); RP=$(echo "$REDIS_HOST" | cut -s -d: -f2); [ -z "$RP" ] && RP=6379;
  echo "waiting for redis $RH:$RP...";
  until nc -z "$RH" "$RP"; do echo "redis not ready, waiting..."; sleep 5; done;
fi;
if [ "$RABBITMQ_ENABLED" = "true" ] && [ -n "$RABBITMQ_HOST" ]; then
  echo "waiting for rabbitmq $RABBITMQ_HOST:${RABBITMQ_PORT_AMQP:-5672}...";
  until nc -z "$RABBITMQ_HOST" "${RABBITMQ_PORT_AMQP:-5672}"; do echo "rabbitmq not ready, waiting..."; sleep 5; done;
fi;
echo "dependencies ready"
{{- end -}}

{{/*
br-sta.appEnv — the explicit `env:` entries of the manager and worker pods: bundled (or existingSecret) infra passwords single-sourced from the
subchart Secrets, and the node-local OTLP endpoint. Input: dict root, component.
*/}}
{{- define "br-sta.appEnv" -}}
{{- $component := .component -}}
{{- with .root -}}
{{- $cm := .Values.common.configmap | default dict -}}
{{- /* This pod's own extraEnvVars: an explicit endpoint there replaces the
   node-local default for this pod only. */ -}}
{{- $x := include "br-sta.componentExtraEnv" (dict "root" . "component" $component) | fromYaml | default dict -}}
{{- $pgAuth := (.Values.postgresql | default dict).auth | default dict -}}
{{- if or (eq (include "br-sta.postgresInternal" .) "true") $pgAuth.existingSecret }}
{{ include "lerian-common.infraSecretRef" (dict "context" . "subchart" "postgresql" "key" "password" "envName" "POSTGRES_PASSWORD") }}
{{- end }}
{{- $vkAuth := (.Values.valkey | default dict).auth | default dict }}
{{- if or (eq (include "br-sta.valkeyInternal" .) "true") $vkAuth.existingSecret }}
{{ include "lerian-common.infraSecretRef" (dict "context" . "subchart" "valkey" "key" "valkey-password" "envName" "REDIS_PASSWORD") }}
{{- end }}
{{- /* Telemetry on and NO explicit endpoint (configmap / global.observability /
   extraEnvVars): ship to the node-local collector at http://$(HOST_IP):4317. */}}
{{- $telemetry := eq (include "br-sta.isTrue" (include "lerian-common.globalValue" (dict "context" . "configmap" $cm "block" "observability" "field" "enabled" "nativeKey" "ENABLE_TELEMETRY" "default" "false"))) "true" }}
{{- $obs := (.Values.global | default dict).observability | default dict }}
{{- if and $telemetry (not (or (hasKey $cm "OTEL_EXPORTER_OTLP_ENDPOINT") $obs.otlpEndpoint (hasKey $x "OTEL_EXPORTER_OTLP_ENDPOINT"))) }}
{{ include "lerian-common.otel.podEnv" (dict "port" 4317) }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
br-sta.presyncAnnotations — hook annotations for the migrations Secret (weight -2)
and Job (weight -1) against EXTERNAL Postgres: the database already exists, so the
app never boots unmigrated, under Helm (pre-install/pre-upgrade) and ArgoCD
(PreSync) alike. Helm deletes both after the hook phase succeeds (the Secret is
still there while the Job reads it, since Helm runs the hooks in weight order and
only then applies the delete policy). ArgoCD keeps the Secret for the whole PreSync
phase (BeforeHookCreation only). Input: weight, deletePolicy (ArgoCD).
*/}}
{{- define "br-sta.presyncAnnotations" -}}
helm.sh/hook: pre-install,pre-upgrade
helm.sh/hook-weight: {{ .weight | quote }}
helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded
argocd.argoproj.io/hook: PreSync
argocd.argoproj.io/hook-weight: {{ .weight | quote }}
argocd.argoproj.io/hook-delete-policy: {{ .deletePolicy | default "BeforeHookCreation,HookSucceeded" }}
{{- end -}}

{{/*
br-sta.jobPodSecurity — PSS-restricted container securityContext for the
bootstrap Jobs. Input: uid.
*/}}
{{- define "br-sta.jobContainerSecurity" -}}
runAsNonRoot: true
runAsUser: {{ .uid | default 65532 }}
runAsGroup: {{ .uid | default 65532 }}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop:
    - ALL
seccompProfile:
  type: RuntimeDefault
{{- end -}}

{{/*
br-sta.meshAnnotations — run a service-mesh proxy as a native sidecar so a Job
can complete (Istio / Linkerd); inert without a mesh.
*/}}
{{- define "br-sta.meshAnnotations" -}}
sidecar.istio.io/nativeSidecar: "true"
config.alpha.linkerd.io/proxy-enable-native-sidecar: "true"
{{- end -}}

{{/*
br-sta.removedKeys — env keys the app (>= 1.2.0-beta.16 / 1.0.0) no longer reads (inert). They are
dropped from the ConfigMap/Secret escape hatch; NOTES.txt lists any still set.
The reporter-events routing key became a code constant; the ACOS010 producer
category moved into a code table; the expected-tenant comparison was removed;
the POSTGRES_* server-tuning pair is docker-compose only; the TRUST_STORE_* knobs
are not read by the current service.
*/}}
{{- define "br-sta.removedKeys" -}}
{{- list "REPORTER_EVENTS_CONSUMER_ROUTING_KEY" "REPORTER_EVENTS_ACOS010_PRODUCER_CATEGORY" "REPORTER_EVENTS_EXPECTED_TENANT" "POSTGRES_MAX_CONNECTIONS" "POSTGRES_SHARED_BUFFERS" "TRUST_STORE_DEFAULT_PAGE_SIZE" "TRUST_STORE_EXPIRING_SOON_DAYS" "TRUST_STORE_MAX_CERT_SIZE_BYTES" "TRUST_STORE_MAX_PAGE_SIZE" "TRUST_STORE_S3_BUCKET" "TRUST_STORE_S3_ENDPOINT" "TRUST_STORE_S3_PATH_STYLE" "TRUST_STORE_S3_REGION" | toJson -}}
{{- end -}}
