{{/*
Chart name.
*/}}
{{- define "plugin-br-sisbajud.name" -}}
{{- default "plugin-br-sisbajud" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name (63-char DNS limit).
*/}}
{{- define "plugin-br-sisbajud.fullname" -}}
{{- default (include "plugin-br-sisbajud.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "plugin-br-sisbajud.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Release namespace, overridable for umbrella layouts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Selector labels. Input: dict "context" $ "component" <name>.
*/}}
{{- define "plugin-br-sisbajud.selectorLabels" -}}
app.kubernetes.io/name: {{ include "plugin-br-sisbajud.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Common labels. Input: dict "context" $ "component" <name>.
*/}}
{{- define "plugin-br-sisbajud.labels" -}}
helm.sh/chart: {{ include "plugin-br-sisbajud.chart" .context }}
{{ include "plugin-br-sisbajud.selectorLabels" . }}
app.kubernetes.io/version: {{ .context.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
app.kubernetes.io/part-of: {{ include "plugin-br-sisbajud.name" .context }}
{{- end }}

{{- define "plugin-br-sisbajud.serviceAccountName" -}}
{{- $sa := .Values.sisbajud.serviceAccount | default dict -}}
{{- if $sa.create -}}
{{- default (include "plugin-br-sisbajud.fullname" .) $sa.name -}}
{{- else -}}
{{- default "default" $sa.name -}}
{{- end -}}
{{- end }}

{{- define "plugin-br-sisbajud.webhookFullname" -}}
{{- printf "%s-webhook" (include "plugin-br-sisbajud.fullname" . | trunc 55 | trimSuffix "-") -}}
{{- end }}

{{- define "plugin-br-sisbajud.migrationsFullname" -}}
{{- printf "%s-migrations" (include "plugin-br-sisbajud.fullname" . | trunc 52 | trimSuffix "-") -}}
{{- end }}

{{- define "plugin-br-sisbajud.image" -}}
{{- printf "%s:%s" .Values.sisbajud.image.repository (.Values.sisbajud.image.tag | default .Chart.AppVersion | toString) -}}
{{- end }}

{{- define "plugin-br-sisbajud.migrationsImage" -}}
{{- printf "%s:%s" .Values.migrations.image.repository (.Values.migrations.image.tag | default .Chart.AppVersion | toString) -}}
{{- end }}

{{/*
imagePullSecrets list: component list, else global.imagePullSecrets.
Input: dict "context" $ "list" <component list>.
*/}}
{{- define "plugin-br-sisbajud.pullSecrets" -}}
{{- $l := .list | default ((.context.Values.global | default dict).imagePullSecrets) | default list -}}
{{- if $l -}}
{{- include "lerian-common.imagePullSecrets" $l -}}
{{- end -}}
{{- end }}

{{/*
isTrue — "true" for the tokens strconv.ParseBool accepts as true.
*/}}
{{- define "plugin-br-sisbajud.isTrue" -}}
{{- if has (. | toString) (list "1" "t" "T" "TRUE" "true" "True") -}}true{{- end -}}
{{- end -}}

{{/*
Name of the Secret the app reads (envFrom). Rejects a string useExistingSecret
("false" is truthy in templates) and an empty existingSecretName.
*/}}
{{- define "plugin-br-sisbajud.secretName" -}}
{{- $v := .Values.sisbajud -}}
{{- $use := $v.useExistingSecret -}}
{{- if and (not (kindIs "invalid" $use)) (not (kindIs "bool" $use)) -}}
{{- fail (printf "\n\nERROR: plugin-br-sisbajud: sisbajud.useExistingSecret must be a boolean, got %s (%v). Write it unquoted.\n" (kindOf $use) $use) -}}
{{- end -}}
{{- if $use -}}
{{- $name := trim (toString ($v.existingSecretName | default "")) -}}
{{- if not $name -}}
{{- fail "\n\nERROR: plugin-br-sisbajud: sisbajud.useExistingSecret is true but sisbajud.existingSecretName is empty.\n" -}}
{{- end -}}
{{- $name -}}
{{- else -}}
{{- include "plugin-br-sisbajud.fullname" . -}}
{{- end -}}
{{- end }}

{{/*
Bundled subchart state. Nil-aware (an explicit `false` must not coerce to true).
*/}}
{{- define "plugin-br-sisbajud.postgresBundled" -}}
{{- $pg := .Values.postgresql | default dict -}}
{{- ternary "true" "" (eq (toString $pg.enabled) "true") -}}
{{- end -}}

{{- define "plugin-br-sisbajud.valkeyBundled" -}}
{{- $vk := .Values.valkey | default dict -}}
{{- ternary "true" "" (eq (toString $vk.enabled) "true") -}}
{{- end -}}

{{/*
The infra password comes from the subchart Secret (bundled) or from
<subchart>.auth.existingSecret; otherwise from the app Secret.
*/}}
{{- define "plugin-br-sisbajud.postgresPasswordFromRef" -}}
{{- $auth := (.Values.postgresql | default dict).auth | default dict -}}
{{- ternary "true" "" (or (eq (include "plugin-br-sisbajud.postgresBundled" .) "true") (ne (toString ($auth.existingSecret | default "")) "")) -}}
{{- end -}}

{{- define "plugin-br-sisbajud.redisPasswordFromRef" -}}
{{- $auth := (.Values.valkey | default dict).auth | default dict -}}
{{- $bundledAuth := and (eq (include "plugin-br-sisbajud.valkeyBundled" .) "true") (ne (toString $auth.enabled) "false") -}}
{{- ternary "true" "" (or $bundledAuth (ne (toString ($auth.existingSecret | default "")) "")) -}}
{{- end -}}

{{/*
PostgreSQL connection (lerian-common.datastore.value). Host defaults to the
bundled subchart Service when postgresql.enabled; ssl to "disable" for the
bundled (plaintext) subchart and "require" otherwise.
*/}}
{{- define "plugin-br-sisbajud.postgres" -}}
{{- $cm := .Values.sisbajud.configmap | default dict -}}
{{- $ded := .Values.sisbajud.datastores | default dict -}}
{{- $dv := "lerian-common.datastore.value" -}}
{{- $bundled := eq (include "plugin-br-sisbajud.postgresBundled" .) "true" -}}
{{- $pgAuth := (.Values.postgresql | default dict).auth | default dict -}}
{{- $hostDefault := "" -}}
{{- if $bundled -}}
{{- $hostDefault = printf "%s.%s.svc.cluster.local" (include "lerian-common.dependency.fullname" (dict "chartName" "postgresql" "chartValues" .Values.postgresql "context" .)) (include "global.namespace" .) -}}
{{- end -}}
host: {{ include $dv (dict "context" . "dedicated" $ded "configmap" $cm "type" "postgres" "field" "host" "nativeKey" "POSTGRES_HOST" "default" $hostDefault) | quote }}
port: {{ include $dv (dict "context" . "dedicated" $ded "configmap" $cm "type" "postgres" "field" "port" "nativeKey" "POSTGRES_PORT" "default" "5432") | quote }}
user: {{ include $dv (dict "context" . "dedicated" $ded "configmap" $cm "type" "postgres" "field" "user" "nativeKey" "POSTGRES_USER" "default" (ternary ($pgAuth.username | default "sisbajud") "sisbajud" $bundled)) | quote }}
name: {{ include $dv (dict "context" . "dedicated" $ded "configmap" $cm "type" "postgres" "field" "name" "nativeKey" "POSTGRES_NAME" "default" (ternary ($pgAuth.database | default "sisbajud") "sisbajud" $bundled)) | quote }}
ssl: {{ include $dv (dict "context" . "dedicated" $ded "configmap" $cm "type" "postgres" "field" "ssl" "nativeKey" "POSTGRES_SSLMODE" "default" (ternary "disable" "require" $bundled)) | quote }}
replicaHost: {{ include $dv (dict "context" . "dedicated" $ded "configmap" $cm "type" "postgres" "field" "replicaHost" "nativeKey" "POSTGRES_REPLICA_HOST" "default" "") | quote }}
{{- end -}}

{{/*
REDIS_HOST in the app's "host:port" form. The mask host may carry the port or
not; a bare host gets `port` (mask field, default 6379) appended. Bundled
valkey -> the subchart primary Service.
*/}}
{{- define "plugin-br-sisbajud.redisHost" -}}
{{- $cm := .Values.sisbajud.configmap | default dict -}}
{{- $ded := .Values.sisbajud.datastores | default dict -}}
{{- $dv := "lerian-common.datastore.value" -}}
{{- if hasKey $cm "REDIS_HOST" -}}
{{- index $cm "REDIS_HOST" -}}
{{- else -}}
{{- $default := "" -}}
{{- if eq (include "plugin-br-sisbajud.valkeyBundled" .) "true" -}}
{{- $default = printf "%s-primary.%s.svc.cluster.local" (include "lerian-common.dependency.fullname" (dict "chartName" "valkey" "chartValues" .Values.valkey "context" .)) (include "global.namespace" .) -}}
{{- end -}}
{{- $host := include $dv (dict "context" . "dedicated" $ded "configmap" (dict) "type" "redis" "field" "host" "nativeKey" "REDIS_HOST" "default" $default) -}}
{{- $port := include $dv (dict "context" . "dedicated" $ded "configmap" (dict) "type" "redis" "field" "port" "nativeKey" "REDIS_PORT" "default" "6379") -}}
{{- if and $host (not (contains ":" $host)) -}}
{{- printf "%s:%s" $host $port -}}
{{- else -}}
{{- $host -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
KMS_PROVIDER: configmap.KMS_PROVIDER verbatim, else the lerian-common KMS mask
vendor mapped to the app vocabulary (hashicorp-vault|vault -> vault, aws|aws-kms -> aws).
*/}}
{{- define "plugin-br-sisbajud.kmsProvider" -}}
{{- $cm := .Values.sisbajud.configmap | default dict -}}
{{- if hasKey $cm "KMS_PROVIDER" -}}
{{- index $cm "KMS_PROVIDER" -}}
{{- else -}}
{{- $vendor := include "lerian-common.kms.value" (dict "context" . "dedicated" (.Values.sisbajud.kms | default dict) "configmap" $cm "field" "vendor" "nativeKey" "KMS_PROVIDER" "default" "hashicorp-vault") -}}
{{- $map := dict "hashicorp-vault" "vault" "vault" "vault" "aws" "aws" "aws-kms" "aws" -}}
{{- index $map $vendor | default $vendor -}}
{{- end -}}
{{- end -}}

{{/*
kv — one ConfigMap line through lerian-common.cfgValue
(configmap.<k> > params.<f> > d). opt=true omits the line when empty.
*/}}
{{- define "plugin-br-sisbajud.kv" -}}
{{- $v := include "lerian-common.cfgValue" (dict "configmap" .cm "nativeKey" .k "params" .p "field" .f "default" (toString (.d | default ""))) -}}
{{- if or (not .opt) $v }}
{{ .k }}: {{ $v | quote }}
{{- end -}}
{{- end -}}

{{/*
Resolved value of one key (same precedence as kv), for gates.
*/}}
{{- define "plugin-br-sisbajud.val" -}}
{{- include "lerian-common.cfgValue" (dict "configmap" .cm "nativeKey" .k "params" .p "field" .f "default" (toString (.d | default ""))) -}}
{{- end -}}

{{- define "plugin-br-sisbajud.multiTenantEnabled" -}}
{{- $cm := .Values.sisbajud.configmap | default dict -}}
{{- include "plugin-br-sisbajud.isTrue" (include "lerian-common.globalValue" (dict "context" . "configmap" $cm "block" "multiTenant" "field" "enabled" "nativeKey" "MULTI_TENANT_ENABLED" "default" "false")) -}}
{{- end -}}

{{- define "plugin-br-sisbajud.transport" -}}
{{- include "plugin-br-sisbajud.val" (dict "cm" (.Values.sisbajud.configmap | default dict) "k" "EXECUTOR_TRANSPORT" "p" .Values.sisbajud.executor "f" "transport" "d" "webhook") -}}
{{- end -}}

{{- define "plugin-br-sisbajud.webhookEnabled" -}}
{{- ternary "true" "" (eq (include "plugin-br-sisbajud.transport" .) "webhook") -}}
{{- end -}}

{{/*
True when the migrations run (enabled and single-tenant).
*/}}
{{- define "plugin-br-sisbajud.migrationsOn" -}}
{{- ternary "true" "" (and .Values.migrations.enabled (ne (include "plugin-br-sisbajud.multiTenantEnabled" .) "true")) -}}
{{- end -}}

{{/*
extraEnvVars as an env list (name: value map, sorted).
*/}}
{{- define "plugin-br-sisbajud.extraEnv" -}}
{{- range $k, $v := (.Values.sisbajud.extraEnvVars | default dict) }}
- name: {{ $k }}
  value: {{ $v | toString | quote }}
{{- end }}
{{- end -}}

{{/*
plugin-br-sisbajud.mensageriaTls — the resolved Mensageria TLS posture as YAML,
mirroring internal/adapters/mensageria/client.go NewTLSConfig and
config_executor.go validateExecutorModeConfig:
  mtls      MENSAGERIA_MTLS_ENABLED as rendered ("true" | "false"; blank = one-way).
  caSecret  server-trust CA source: mensageria.ca.existingSecret, else (backward
            compatible) mensageria.tls.existingSecret with tls.caKey. Optional in
            one-way TLS (blank = system trust store), required with mTLS.
  tlsSecret the executor client pair; mounted only with mTLS.
In-pod files are fixed: <ca.mountPath>/ca.crt, <tls.mountPath>/tls.crt|tls.key.
*/}}
{{- define "plugin-br-sisbajud.mensageriaTls" -}}
{{- $s := .Values.sisbajud -}}
{{- $cm := $s.configmap | default dict -}}
{{- $m := $s.mensageria | default dict -}}
{{- $tls := $m.tls | default dict -}}
{{- $ca := $m.ca | default dict -}}
{{- $raw := include "plugin-br-sisbajud.val" (dict "cm" $cm "k" "MENSAGERIA_MTLS_ENABLED" "p" $m "f" "mtlsEnabled" "d" "false") | trim -}}
{{- $caSecret := $ca.existingSecret | default "" -}}
{{- $caKey := $ca.key | default "ca.crt" -}}
{{- if and (not $caSecret) $tls.existingSecret -}}
{{- $caSecret = $tls.existingSecret -}}
{{- $caKey = $tls.caKey | default "ca.crt" -}}
{{- end -}}
{{- $caMount := $ca.mountPath | default "/etc/plugin-br-sisbajud/mensageria-ca" | trimSuffix "/" -}}
{{- $tlsMount := $tls.mountPath | default "/etc/plugin-br-sisbajud/mensageria" | trimSuffix "/" -}}
raw: {{ $raw | quote }}
mtls: {{ ternary "true" "false" (eq $raw "true") | quote }}
caSecret: {{ $caSecret | quote }}
caKey: {{ $caKey | quote }}
caMount: {{ $caMount | quote }}
caFile: {{ printf "%s/ca.crt" $caMount | quote }}
tlsSecret: {{ $tls.existingSecret | default "" | quote }}
certKey: {{ $tls.certKey | default "tls.crt" | quote }}
keyKey: {{ $tls.keyKey | default "tls.key" | quote }}
tlsMount: {{ $tlsMount | quote }}
certFile: {{ printf "%s/tls.crt" $tlsMount | quote }}
keyFile: {{ printf "%s/tls.key" $tlsMount | quote }}
{{- end -}}

{{/*
plugin-br-sisbajud.isAvpPlaceholder — "true" for an argocd-vault-plugin
placeholder (<path:...>), substituted only after `helm template`: scheme checks
cannot judge it at render time.
*/}}
{{- define "plugin-br-sisbajud.isAvpPlaceholder" -}}
{{- if hasPrefix "<path:" (trim (toString .)) -}}true{{- end -}}
{{- end -}}
