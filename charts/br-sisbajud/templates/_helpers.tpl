{{/*
Expand the name of the chart.
*/}}
{{- define "br-sisbajud.name" -}}
{{- default "br-sisbajud" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Truncated at 63 chars because some Kubernetes name fields are limited by the DNS spec.
*/}}
{{- define "br-sisbajud.fullname" -}}
{{- default (include "br-sisbajud.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "br-sisbajud.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the namespace of the release. Overridable for multi-namespace layouts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Name of the service account to use.
*/}}
{{- define "br-sisbajud.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "br-sisbajud.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Selector labels (stable across image bumps).
*/}}
{{- define "br-sisbajud.selectorLabels" -}}
app.kubernetes.io/name: {{ include "br-sisbajud.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "br-sisbajud.labels" -}}
helm.sh/chart: {{ include "br-sisbajud.chart" . }}
{{ include "br-sisbajud.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Migrations fullname, e.g. br-sisbajud-migrations — Job and PreSync Secret reference this.
*/}}
{{- define "br-sisbajud-migrations.fullname" -}}
{{- printf "%s-migrations" (include "br-sisbajud.fullname" . | trunc 52 | trimSuffix "-") | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Migrations labels.
*/}}
{{- define "br-sisbajud-migrations.labels" -}}
helm.sh/chart: {{ include "br-sisbajud.chart" . }}
app.kubernetes.io/name: {{ include "br-sisbajud-migrations.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: migrations
{{- end }}

{{/*
Topics fullname, e.g. br-sisbajud-topics — the PreSync topics Job and Secret reference this.
*/}}
{{- define "br-sisbajud-topics.fullname" -}}
{{- printf "%s-topics" (include "br-sisbajud.fullname" . | trunc 56 | trimSuffix "-") | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Topics labels.
*/}}
{{- define "br-sisbajud-topics.labels" -}}
helm.sh/chart: {{ include "br-sisbajud.chart" . }}
app.kubernetes.io/name: {{ include "br-sisbajud-topics.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: topics
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
{{- define "br-sisbajud.postgresEnabled" -}}
{{- $pg := .Values.postgresql | default dict -}}
{{- ternary "true" "false" (ne (toString $pg.enabled) "false") -}}
{{- end -}}

{{- define "br-sisbajud.valkeyEnabled" -}}
{{- $vk := .Values.valkey | default dict -}}
{{- ternary "true" "false" (ne (toString $vk.enabled) "false") -}}
{{- end -}}

{{- define "br-sisbajud.postgresInternal" -}}
{{- $pg := .Values.postgresql | default dict -}}
{{- ternary "true" "false" (and (ne (toString $pg.enabled) "false") (not $pg.external)) -}}
{{- end -}}

{{- define "br-sisbajud.valkeyInternal" -}}
{{- $vk := .Values.valkey | default dict -}}
{{- $vkAuth := $vk.auth | default dict -}}
{{- ternary "true" "false" (and (ne (toString $vk.enabled) "false") (not $vk.external) (ne (toString $vkAuth.enabled) "false")) -}}
{{- end -}}

{{/*
Bundled SeaweedFS (seaweedfs subchart). The subchart names its Services after
`seaweedfs.name` (nameOverride | "seaweedfs", NOT release-prefixed) and deploys
into the release namespace.
  seaweedfsEnabled  : "true" when the subchart renders.
  seaweedfsName     : the subchart's resource-name prefix.
  seaweedfsS3Endpoint: the in-cluster S3 URL (standalone s3 Deployment when
                       seaweedfs.s3.enabled, else the filer-embedded S3).
*/}}
{{- define "br-sisbajud.seaweedfsEnabled" -}}
{{- $sw := .Values.seaweedfs | default dict -}}
{{- ternary "true" "false" (eq (toString $sw.enabled) "true") -}}
{{- end -}}

{{- define "br-sisbajud.seaweedfsName" -}}
{{- $sw := .Values.seaweedfs | default dict -}}
{{- default "seaweedfs" $sw.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "br-sisbajud.seaweedfsS3Endpoint" -}}
{{- $sw := .Values.seaweedfs | default dict -}}
{{- $s3 := $sw.s3 | default dict -}}
{{- $filerS3 := ($sw.filer | default dict).s3 | default dict -}}
{{- $port := ternary ($s3.port | default 8333) ($filerS3.port | default 8333) (eq (toString $s3.enabled) "true") -}}
{{- printf "http://%s-s3.%s.svc.cluster.local:%v" (include "br-sisbajud.seaweedfsName" .) .Release.Namespace $port -}}
{{- end -}}

{{/*
Bundled OpenBao (openbao subchart, dev mode). Service = openbao.fullname
(collapse-aware "<release>-openbao", honoring fullnameOverride/nameOverride),
port 8200, plain HTTP (global.tlsDisable default), in the release namespace.
*/}}
{{- define "br-sisbajud.openbaoEnabled" -}}
{{- ternary "true" "false" (eq (toString (.Values.openbao | default dict).enabled) "true") -}}
{{- end -}}

{{- define "br-sisbajud.openbaoAddr" -}}
{{- $ob := .Values.openbao | default dict -}}
{{- $port := (($ob.server | default dict).service | default dict).port | default 8200 -}}
{{- printf "http://%s.%s.svc.cluster.local:%v" (include "lerian-common.dependency.fullname" (dict "chartName" "openbao" "chartValues" $ob "context" .)) .Release.Namespace $port -}}
{{- end -}}

{{/*
br-sisbajud.openbaoTokenSecret — the Secret that carries the bundled OpenBao's
dev root token (under its configured secretKey). Its name/key are the ones openbao.server.
extraSecretEnvironmentVars feeds to BAO_DEV_ROOT_TOKEN_ID (single source: the
subchart reads it, and the app / Transit Job / transit initContainer read the same
Secret). BAO_DEV_ROOT_TOKEN_ID wins over the subchart's plaintext
VAULT_DEV_ROOT_TOKEN_ID (OpenBao api.ReadBaoVariable prefers BAO_*), so the
subchart's default "root" is not a working credential.
*/}}
{{- define "br-sisbajud.openbaoTokenSecretRef" -}}
{{- $ref := dict -}}
{{- range ((((.Values.openbao | default dict).server | default dict).extraSecretEnvironmentVars) | default list) -}}
{{- if eq .envName "BAO_DEV_ROOT_TOKEN_ID" -}}{{- $ref = dict "name" (.secretName | default "") "key" (.secretKey | default "") -}}{{- end -}}
{{- end -}}
{{- if or (not $ref.name) (not $ref.key) -}}
{{- fail "\n\nERROR: br-sisbajud: openbao.enabled needs an openbao.server.extraSecretEnvironmentVars entry for BAO_DEV_ROOT_TOKEN_ID with both secretName and secretKey; the chart creates that Secret under that key. See values.yaml.\n" -}}
{{- end -}}
{{- toYaml $ref -}}
{{- end -}}

{{/* Name / key of the dev-token Secret (the SAME entry OpenBao reads). */}}
{{- define "br-sisbajud.openbaoTokenSecret" -}}
{{- (include "br-sisbajud.openbaoTokenSecretRef" . | fromYaml).name -}}
{{- end -}}
{{- define "br-sisbajud.openbaoTokenKey" -}}
{{- (include "br-sisbajud.openbaoTokenSecretRef" . | fromYaml).key -}}
{{- end -}}

{{/*
Bundled Redpanda (redpanda subchart). It names its Services after
fullnameOverride, else the RELEASE name (no suffix). Internal Kafka listener
port = listeners.kafka.port (9093).
*/}}
{{- define "br-sisbajud.redpandaEnabled" -}}
{{- ternary "true" "false" (eq (toString (.Values.redpandaBundle | default dict).enabled) "true") -}}
{{- end -}}

{{- define "br-sisbajud.redpandaBrokers" -}}
{{- $rp := .Values.redpanda | default dict -}}
{{- $name := $rp.fullnameOverride | default .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- $port := (($rp.listeners | default dict).kafka | default dict).port | default 9093 -}}
{{- printf "%s.%s.svc.cluster.local.:%v" $name .Release.Namespace $port -}}
{{- end -}}

{{/*
br-sisbajud.streamingContext — the context handed to lerian-common.streaming.env.
With the bundled Redpanda on and no global.streaming.brokers, it injects the
derived brokers at the global tier, so configmap.STREAMING_BROKERS still wins
and an explicit global value is untouched.
*/}}
{{- define "br-sisbajud.streamingGlobal" -}}
{{- $gs := deepCopy (((.Values.global | default dict).streaming) | default dict) -}}
{{- if and (eq (include "br-sisbajud.redpandaEnabled" .) "true") (not $gs.brokers) -}}
{{- $_ := set $gs "brokers" (include "br-sisbajud.redpandaBrokers" .) -}}
{{- end -}}
{{- toYaml $gs -}}
{{- end -}}

{{/*
br-sisbajud.bundleGuard — OpenBao (dev mode: in-memory keys; a restart makes
encrypted data unrecoverable) and Redpanda (single broker, no TLS/SASL) are
dev-only and refused outside a development-class environment (devClass), which
includes staging: a staging tier holds data someone expects to keep. The
postgresql/valkey/seaweedfs bundles are allowed, as in the sibling charts, but
NOTES.txt warns in a production-like environment.
*/}}
{{- define "br-sisbajud.bundleGuard" -}}
{{- if ne (include "br-sisbajud.devClass" .) "true" -}}
{{- $bad := list -}}
{{- if eq (include "br-sisbajud.openbaoEnabled" .) "true" -}}{{- $bad = append $bad "openbao (dev mode: keys live in memory; a pod restart loses them and every value encrypted under them becomes unrecoverable)" -}}{{- end -}}
{{- if eq (include "br-sisbajud.redpandaEnabled" .) "true" -}}{{- $bad = append $bad "redpandaBundle / redpanda (single broker, no TLS, no SASL)" -}}{{- end -}}
{{- if $bad -}}
{{- fail (printf "\n\nERROR: br-sisbajud: dev-only bundle enabled outside a development-class environment (ENVIRONMENT_NAME=%q):\n  - %s\n  Use external Vault/AWS KMS and Kafka/Redpanda (global.kms / global.streaming), or set global.env.name to local|development|develop|dev|test|e2e for a dev install (values-dev.yaml).\n" (include "br-sisbajud.envName" .) (join "\n  - " $bad)) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
br-sisbajud.presyncJobAnnotations — hook annotations for the migrations/topics
Jobs. Against EXTERNAL infra they are ArgoCD PreSync hooks (the dependency
already exists, so the app never boots unmigrated / without topics). When the
dependency is BUNDLED it is created in the same sync, so a PreSync hook would
wait forever: the Job then runs as a Helm post-install/post-upgrade hook /
ArgoCD Sync hook next to the subchart and waits for it in its initContainer.
before-hook-creation replaces the Job each run, so the immutable spec.template
never blocks an upgrade. Input: dict "bundled" bool.
*/}}
{{- define "br-sisbajud.presyncJobAnnotations" -}}
{{- if .bundled -}}
helm.sh/hook: post-install,post-upgrade
helm.sh/hook-weight: "0"
helm.sh/hook-delete-policy: before-hook-creation
argocd.argoproj.io/hook: Sync
argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
{{- else -}}
helm.sh/hook: pre-install,pre-upgrade
helm.sh/hook-weight: "-1"
helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded
argocd.argoproj.io/hook: PreSync
argocd.argoproj.io/hook-weight: "-1"
argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookSucceeded
{{- end -}}
{{- end -}}

{{/*
br-sisbajud.presyncSecretAnnotations — the dedicated migrations/topics hook
Secrets (they carry credentials): created one weight BEFORE their Job.
  Helm: hook-succeeded removes them once the WHOLE hook phase has succeeded
        (Helm deletes succeeded hooks after the last hook of the phase, so the
        Job has already read the Secret). Nothing credential-bearing is left
        in the namespace after install/upgrade, and so none after uninstall.
  ArgoCD: BeforeHookCreation only (unchanged). A HookSucceeded Secret would be
        pruned as soon as it applies, before the Job reads it.
Input: dict "bundled".
*/}}
{{- define "br-sisbajud.presyncSecretAnnotations" -}}
{{- if .bundled -}}
helm.sh/hook: post-install,post-upgrade
helm.sh/hook-weight: "-1"
helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded
argocd.argoproj.io/hook: Sync
argocd.argoproj.io/hook-weight: "-1"
argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
{{- else -}}
helm.sh/hook: pre-install,pre-upgrade
helm.sh/hook-weight: "-2"
helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded
argocd.argoproj.io/hook: PreSync
argocd.argoproj.io/hook-weight: "-2"
argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
{{- end -}}
{{- end -}}

{{/*
br-sisbajud.podEnvList — the explicit pod `env:` entries the chart adds on top of
envFrom, as a YAML list: one secretKeyRef entry per brSisbajud.secretRefs.<KEY>
({name, key[, optional]}), sorted by KEY, followed by brSisbajud.extraEnvVars
verbatim. extraEnvVars wins on a name clash (the secretRefs entry is dropped, so
server-side apply never sees a duplicate). Every consumer that inspects "what
reaches the pod explicitly" (fail-fast gates, migrations/topics credential
resolution, CORS mirroring) reads this list.
*/}}
{{- define "br-sisbajud.podEnvList" -}}
{{- $extra := .Values.brSisbajud.extraEnvVars | default list -}}
{{- $names := dict -}}
{{- range $extra -}}{{- if .name -}}{{- $_ := set $names .name true -}}{{- end -}}{{- end -}}
{{- $out := list -}}
{{- $refs := .Values.brSisbajud.secretRefs | default dict -}}
{{- range $k := keys $refs | sortAlpha -}}
{{- $r := index $refs $k -}}
{{- if not (hasKey $names $k) -}}
{{- if or (not $r.name) (not $r.key) -}}
{{- fail (printf "\n\nERROR: br-sisbajud: brSisbajud.secretRefs.%s needs both name and key (the Kubernetes Secret and its data key).\n" $k) -}}
{{- end -}}
{{- $ref := dict "name" $r.name "key" $r.key -}}
{{- if hasKey $r "optional" -}}{{- $_ := set $ref "optional" $r.optional -}}{{- end -}}
{{- $out = append $out (dict "name" $k "valueFrom" (dict "secretKeyRef" $ref)) -}}
{{- end -}}
{{- end -}}
{{- toYaml (concat $out $extra) -}}
{{- end -}}

{{/*
br-sisbajud.effectiveEnvEntry — the env entry the app container actually gets for
one key, as JSON: the explicit pod env entry (secretRefs / extraEnvVars, verbatim
incl. valueFrom) when present, else {name, value} from the rendered ConfigMap
(or `default`). Init containers that probe or reuse an app connection key read
this, so they can never target a different endpoint than the app.
Input: dict "context" . "name" KEY ["default" VALUE].
*/}}
{{- define "br-sisbajud.effectiveEnvEntry" -}}
{{- $ctx := .context -}}
{{- $entry := dict -}}
{{- range (include "br-sisbajud.podEnvList" $ctx | fromYamlArray) -}}{{- if eq (toString .name) $.name -}}{{- $entry = . -}}{{- end -}}{{- end -}}
{{- if not $entry -}}
{{- $data := include "br-sisbajud.configmapData" $ctx | fromYaml -}}
{{- $entry = dict "name" .name "value" (index $data .name | default .default | default "" | toString) -}}
{{- end -}}
{{- toJson $entry -}}
{{- end -}}

{{/*
br-sisbajud.waitBrokerScript — waits for the first endpoint of $STREAMING_BROKERS,
read at runtime so a valueFrom entry works too.
*/}}
{{- define "br-sisbajud.waitBrokerScript" -}}
HP="${STREAMING_BROKERS%%,*}"; HP="$(echo "$HP" | tr -d ' ')"; H="${HP%:*}"; P="${HP##*:}";
echo "waiting for broker $H:$P...";
until nc -z "$H" "$P"; do echo "broker $H:$P not ready, waiting..."; sleep 5; done;
echo "broker is ready"
{{- end -}}

{{/*
br-sisbajud.extraEnv — brSisbajud.extraEnvVars as a YAML map {NAME: value},
with "__valueFrom__" for entries sourced via valueFrom. Lets the fail-fast gates
and the topics Job see values an operator supplies as explicit pod env (the
1.1.x way of wiring Vault/SASL/STA credentials), so those installs keep passing.
*/}}
{{- define "br-sisbajud.extraEnv" -}}
{{- $out := dict -}}
{{- range (include "br-sisbajud.podEnvList" . | fromYamlArray) -}}
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
br-sisbajud.provided — "true" when env KEY reaches the pod from ANY source:
the resolved ConfigMap value passed in (value), brSisbajud.secrets.<KEY>, or an
extraEnvVars entry (literal or valueFrom). Inputs: context, key, value (opt).
*/}}
{{- define "br-sisbajud.provided" -}}
{{- $ctx := .context -}}
{{- $x := include "br-sisbajud.extraEnv" $ctx | fromYaml -}}
{{- $s := $ctx.Values.brSisbajud.secrets | default dict -}}
{{- if or (trim (toString (.value | default ""))) (index $s .key) (index $x .key) -}}
true
{{- end -}}
{{- end -}}

{{/*
br-sisbajud.envName — the deployment environment, single-sourced for
ENVIRONMENT_NAME, ENV_NAME and OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT.
Precedence: extraEnvVars ENVIRONMENT_NAME (literal) > configmap.ENVIRONMENT_NAME
> configmap.ENV_NAME > global.env.name > "production". The app treats any value
outside local|development|staging|e2e|test as production-like (fail-closed).
*/}}
{{- define "br-sisbajud.envName" -}}
{{- $cm := .Values.brSisbajud.configmap | default dict -}}
{{- $x := include "br-sisbajud.extraEnv" . | fromYaml -}}
{{- $xv := index $x "ENVIRONMENT_NAME" | default "" -}}
{{- if and $xv (ne $xv "__valueFrom__") -}}
{{- $xv -}}
{{- else if hasKey $cm "ENVIRONMENT_NAME" -}}
{{- index $cm "ENVIRONMENT_NAME" -}}
{{- else -}}
{{- include "lerian-common.globalValue" (dict "context" . "configmap" $cm "block" "env" "field" "name" "nativeKey" "ENV_NAME" "default" "production") -}}
{{- end -}}
{{- end -}}

{{/*
br-sisbajud.productionLike — "true" unless the env name is one of the app's
recognized non-production names (config.go isNonProductionEnv).
*/}}
{{- define "br-sisbajud.productionLike" -}}
{{- $env := include "br-sisbajud.envName" . -}}
{{- ternary "false" "true" (has $env (list "local" "development" "staging" "e2e" "test")) -}}
{{- end -}}

{{/*
br-sisbajud.devClass — "true" when the env name is a development-class name
(local, development, develop, dev, test, e2e; case-insensitive), the same
vocabulary as br-sta plus the app's e2e. Only there does the chart render its
dev-only bundles (OpenBao dev mode, Redpanda). It is stricter than
productionLike on purpose: staging relaxes the app's own gates (license, TLS)
but must not run in-memory Transit keys. productionLike keeps driving the app
relaxations and the NOTES warnings.
*/}}
{{- define "br-sisbajud.devClass" -}}
{{- $env := lower (trim (include "br-sisbajud.envName" .)) -}}
{{- ternary "true" "false" (has $env (list "local" "development" "develop" "dev" "test" "e2e")) -}}
{{- end -}}

{{- define "br-sisbajud.isTrue" -}}
{{- ternary "true" "false" (has (toString .) (list "true" "1" "t" "T" "TRUE" "True")) -}}
{{- end -}}

{{- define "br-sisbajud.multiTenantEnabled" -}}
{{- $cm := .Values.brSisbajud.configmap | default dict -}}
{{- include "br-sisbajud.isTrue" (include "lerian-common.globalValue" (dict "context" . "configmap" $cm "block" "multiTenant" "field" "enabled" "nativeKey" "MULTI_TENANT_ENABLED" "default" "false")) -}}
{{- end -}}

{{- define "br-sisbajud.streamingEnabledRaw" -}}
{{- $cm := .Values.brSisbajud.configmap | default dict -}}
{{- include "lerian-common.globalValue" (dict "context" . "configmap" $cm "block" "streaming" "field" "enabled" "nativeKey" "STREAMING_ENABLED" "default" "false") -}}
{{- end -}}

{{/*
br-sisbajud.postgres — the resolved primary Postgres connection as YAML
{host, port, user, name, ssl}, shared by the app ConfigMap and the migrations
Job so the two can never drift. Mask precedence (lerian-common.datastore.value):
configmap.POSTGRES_* > brSisbajud.datastores.postgres > global.datastores.postgres
> global.cloud preset > default. The host defaults to the bundled subchart
Service only when postgresql.enabled; ssl defaults to "disable" for the bundled
(plaintext) subchart and "require" otherwise.
*/}}
{{- define "br-sisbajud.postgres" -}}
{{- $cm := .Values.brSisbajud.configmap | default dict -}}
{{- $ded := .Values.brSisbajud.datastores | default dict -}}
{{- $dv := "lerian-common.datastore.value" -}}
{{- $bundled := eq (include "br-sisbajud.postgresEnabled" .) "true" -}}
{{- $hostDefault := "" -}}
{{- if $bundled -}}
{{- $hostDefault = printf "%s.%s.svc.cluster.local." (include "common.names.dependency.fullname" (dict "chartName" "postgresql" "chartValues" .Values.postgresql "context" .)) (include "global.namespace" .) -}}
{{- end -}}
host: {{ include $dv (dict "context" . "dedicated" $ded "configmap" $cm "type" "postgres" "field" "host" "nativeKey" "POSTGRES_HOST" "default" $hostDefault) | quote }}
port: {{ include $dv (dict "context" . "dedicated" $ded "configmap" $cm "type" "postgres" "field" "port" "nativeKey" "POSTGRES_PORT" "default" "5432") | quote }}
user: {{ include $dv (dict "context" . "dedicated" $ded "configmap" $cm "type" "postgres" "field" "user" "nativeKey" "POSTGRES_USER" "default" "br_sisbajud") | quote }}
name: {{ include $dv (dict "context" . "dedicated" $ded "configmap" $cm "type" "postgres" "field" "name" "nativeKey" "POSTGRES_NAME" "default" "br_sisbajud") | quote }}
ssl: {{ include $dv (dict "context" . "dedicated" $ded "configmap" $cm "type" "postgres" "field" "ssl" "nativeKey" "POSTGRES_SSLMODE" "default" (ternary "disable" "require" $bundled)) | quote }}
{{- end -}}

{{/*
br-sisbajud.allowInsecureTLS — lib-commons' plaintext bypass for postgres/redis.
configmap > brSisbajud.security.allowInsecureTls > "true" only when a bundled
(plaintext) subchart is enabled, else "false".
*/}}
{{- define "br-sisbajud.allowInsecureTLS" -}}
{{- $cm := .Values.brSisbajud.configmap | default dict -}}
{{- $bundled := or (eq (include "br-sisbajud.postgresEnabled" .) "true") (eq (include "br-sisbajud.valkeyEnabled" .) "true") -}}
{{- include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "ALLOW_INSECURE_TLS" "params" .Values.brSisbajud.security "field" "allowInsecureTls" "default" (ternary "true" "false" $bundled)) -}}
{{- end -}}

{{/*
br-sisbajud.kv — emit ONE ConfigMap line resolved through lerian-common.cfgValue
(configmap.<k> > params.<f> > d). With opt=true the line is omitted when the
resolved value is empty (optional keys the app treats "unset" and "" alike, or
whose mere presence changes behavior).
Inputs (dict): cm, p (params map), f (field), k (env key), d (default), opt.
*/}}
{{- define "br-sisbajud.kv" -}}
{{- $v := include "lerian-common.cfgValue" (dict "configmap" .cm "nativeKey" .k "params" .p "field" .f "default" (toString (.d | default ""))) -}}
{{- if or (not .opt) $v }}
{{ .k }}: {{ $v | quote }}
{{- end -}}
{{- end -}}

{{/*
br-sisbajud.removedKeys — env keys app 1.x no longer reads. They are dropped
from the ConfigMap/Secret escape hatch (NOTES.txt lists any that are still set).
The Midaz/CRM connector routing and credentials moved to the per-institution
institution_config.connector_metadata row; STA institution identity moved to
the institution_config table.
*/}}
{{- define "br-sisbajud.removedKeys" -}}
{{- list "BALANCE_CONSUMER_DLQ_SUFFIX" "CONNECTOR_CREDS_USE_SECRET_STORE" "CRM_CLIENT_ID" "CRM_CLIENT_SECRET" "LEDGER_BALANCE_TOPIC" "MIDAZ_AUTH_ADDRESS" "MIDAZ_AUTH_ENABLED" "MIDAZ_BASE_URL" "MIDAZ_CLIENT_ID" "MIDAZ_CLIENT_SECRET" "OTEL_RESOURCE_SERVICE_VERSION" "SECRET_STORE_PROVIDER" "STA_INSTITUTION_CODE" "STA_INSTITUTION_ID" "VAULT_KV_MOUNT" | toJson -}}
{{- end -}}

{{/*
br-sisbajud.kmsProvider — KMS_PROVIDER from the lerian-common KMS mask.
configmap.KMS_PROVIDER wins verbatim; otherwise kms.vendor (dedicated
brSisbajud.kms > global.kms > "hashicorp-vault") is mapped to the app's
vocabulary: hashicorp-vault|vault -> vault, aws|aws-kms -> aws.
*/}}
{{- define "br-sisbajud.kmsProvider" -}}
{{- $cm := .Values.brSisbajud.configmap | default dict -}}
{{- if hasKey $cm "KMS_PROVIDER" -}}
{{- index $cm "KMS_PROVIDER" -}}
{{- else -}}
{{- $vendor := include "lerian-common.kms.value" (dict "context" . "dedicated" (.Values.brSisbajud.kms | default dict) "configmap" $cm "field" "vendor" "nativeKey" "KMS_PROVIDER" "default" "hashicorp-vault") -}}
{{- $map := dict "hashicorp-vault" "vault" "vault" "vault" "aws" "aws" "aws-kms" "aws" -}}
{{- index $map $vendor | default $vendor -}}
{{- end -}}
{{- end -}}

{{/*
br-sisbajud.configmapData — every app env key the chart models, as ConfigMap
`data` lines (one per line; blank lines are dropped by the caller). Dependency
connections go through the lerian-common masks/env helpers; every other key
goes through lerian-common.cfgValue (via br-sisbajud.kv). Contract source:
LerianStudio/br-sisbajud config/.env.example + internal/bootstrap/config.go.
*/}}
{{- define "br-sisbajud.configmapData" -}}
{{- $ := . -}}
{{- $b := .Values.brSisbajud -}}
{{- $cm := $b.configmap | default dict -}}
{{- $w := $b.workers | default dict -}}
{{- $dv := "lerian-common.datastore.value" -}}
{{- $osv := "lerian-common.objectStorage.value" -}}
{{- $kv := "br-sisbajud.kv" -}}
{{- $kmsDed := $b.kms | default dict -}}
{{- $osDed := $b.objectStorage | default dict -}}
{{- $dsDed := $b.datastores | default dict -}}
{{- $imageTag := $b.image.tag | default .Chart.AppVersion | toString -}}
{{- $envName := include "br-sisbajud.envName" . -}}
{{- $mtOn := eq (include "br-sisbajud.multiTenantEnabled" .) "true" -}}
{{- $pg := include "br-sisbajud.postgres" . | fromYaml -}}
{{- $streamingRaw := include "br-sisbajud.streamingEnabledRaw" . -}}
{{- $streamingOn := eq (include "br-sisbajud.isTrue" $streamingRaw) "true" -}}
{{- /* Bundled SeaweedFS: with no explicit endpoint (configmap / dedicated / global
   objectStorage), derive it from the subchart's S3 Service, same idea as the
   bundled POSTGRES_HOST/REDIS_HOST. STA_OBJECT_STORAGE_ENDPOINT follows it. */ -}}
{{- $seaweedDefault := "" -}}
{{- if eq (include "br-sisbajud.seaweedfsEnabled" .) "true" -}}
{{- $seaweedDefault = include "br-sisbajud.seaweedfsS3Endpoint" . -}}
{{- end -}}
{{- $seaweedEndpoint := include $osv (dict "context" $ "dedicated" $osDed "configmap" $cm "name" "sisbajud" "field" "endpoint" "nativeKey" "SEAWEEDFS_S3_ENDPOINT" "default" $seaweedDefault) -}}
{{- $staBucket := include $osv (dict "context" $ "dedicated" $osDed "configmap" $cm "name" "sta" "field" "bucket" "nativeKey" "STA_INBOUND_BUCKET" "default" "") -}}
{{- $telemetryDefault := "false" }}
# --- Application -------------------------------------------------------------
ENVIRONMENT_NAME: {{ $envName | quote }}
ENV_NAME: {{ (hasKey $cm "ENV_NAME" | ternary (index $cm "ENV_NAME") $envName) | quote }}
{{ include $kv (dict "cm" $cm "p" $b.app "f" "logLevel" "k" "LOG_LEVEL" "d" "info") }}
{{ include $kv (dict "cm" $cm "p" $b.app "f" "version" "k" "VERSION" "d" $imageTag) }}
{{ include $kv (dict "cm" $cm "p" $b.app "f" "deploymentMode" "k" "DEPLOYMENT_MODE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.app "f" "defaultTenantId" "k" "DEFAULT_TENANT_ID" "d" "11111111-1111-1111-1111-111111111111") }}
{{ include $kv (dict "cm" $cm "p" $b.app "f" "systemplaneEnabled" "k" "SYSTEMPLANE_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $b.app "f" "infraConnectTimeoutSec" "k" "INFRA_CONNECT_TIMEOUT_SEC" "d" "30") }}
{{ include $kv (dict "cm" $cm "p" $b.app "f" "dbMetricsIntervalSec" "k" "DB_METRICS_INTERVAL_SEC" "d" "15") }}
{{ include $kv (dict "cm" $cm "p" $b.app "f" "idempotencyRetryWindowSec" "k" "IDEMPOTENCY_RETRY_WINDOW_SEC" "d" "300") }}
{{ include $kv (dict "cm" $cm "p" $b.app "f" "circuitBreakerEnabled" "k" "CIRCUIT_BREAKER_ENABLED" "d" "false") }}
{{- /* Go runtime knobs (optional). */}}
{{ include $kv (dict "cm" $cm "p" $b.runtime "f" "godebug" "k" "GODEBUG" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.runtime "f" "gotraceback" "k" "GOTRACEBACK" "opt" true) }}
# --- HTTP server + CORS --------------------------------------------------------
{{ include $kv (dict "cm" $cm "p" $b.server "f" "address" "k" "SERVER_ADDRESS" "d" (printf "0.0.0.0:%v" ($b.service.port | default 4029))) }}
{{ include $kv (dict "cm" $cm "p" $b.server "f" "bodyLimitBytes" "k" "HTTP_BODY_LIMIT_BYTES" "d" "104857600") }}
{{ include $kv (dict "cm" $cm "p" $b.server "f" "tlsTerminatedUpstream" "k" "TLS_TERMINATED_UPSTREAM" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $b.server "f" "tlsCertFile" "k" "SERVER_TLS_CERT_FILE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.server "f" "tlsKeyFile" "k" "SERVER_TLS_KEY_FILE" "opt" true) }}
{{- /* CORS. The app's config binds CORS_* (config.go ServerConfig, re-exported by
   syncRuntimeEnvironment), but the middleware that enforces CORS is lib-commons
   v7.9.0 commons/net/http/withCORS.go, which reads ACCESS_CONTROL_ALLOW_ORIGIN /
   _METHODS / _HEADERS / _EXPOSE_HEADERS / _CREDENTIALS. Both families are emitted
   from ONE resolution: configmap.ACCESS_CONTROL_* > configmap.CORS_* (the 1.1.x
   escape hatch maps through) > brSisbajud.cors.<field> > default. With no origin
   the middleware falls back to "*" and then denies all (fail-closed). */}}
{{- $cors := list (list "allowedOrigins" "CORS_ALLOWED_ORIGINS" "ACCESS_CONTROL_ALLOW_ORIGIN" "") (list "allowedMethods" "CORS_ALLOWED_METHODS" "ACCESS_CONTROL_ALLOW_METHODS" "GET,POST,PUT,PATCH,DELETE,OPTIONS") (list "allowedHeaders" "CORS_ALLOWED_HEADERS" "ACCESS_CONTROL_ALLOW_HEADERS" "Origin,Content-Type,Accept,Authorization,X-Request-ID") (list "exposeHeaders" "CORS_EXPOSE_HEADERS" "ACCESS_CONTROL_EXPOSE_HEADERS" "") (list "allowCredentials" "CORS_ALLOW_CREDENTIALS" "ACCESS_CONTROL_ALLOW_CREDENTIALS" "false") }}
{{- range $row := $cors }}
{{- $v := include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" (index $row 1) "params" $b.cors "field" (index $row 0) "default" (index $row 3)) }}
{{ index $row 1 }}: {{ $v | quote }}
{{ index $row 2 }}: {{ (hasKey $cm (index $row 2) | ternary (index $cm (index $row 2)) $v) | quote }}
{{- end }}
# --- lib-commons security toggles -------------------------------------------
ALLOW_INSECURE_TLS: {{ include "br-sisbajud.allowInsecureTLS" . | quote }}
{{ include $kv (dict "cm" $cm "p" $b.security "f" "allowCorsWildcard" "k" "ALLOW_CORS_WILDCARD" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.security "f" "allowInsecureOtel" "k" "ALLOW_INSECURE_OTEL" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.security "f" "allowWebhookPrivateNetwork" "k" "ALLOW_WEBHOOK_PRIVATE_NETWORK" "opt" true) }}
# --- License (lib-license-go, GLOBAL mode); LICENSE_KEY lives in the Secret ------
{{ include $kv (dict "cm" $cm "p" $b.license "f" "organizationIds" "k" "ORGANIZATION_IDS" "d" "global") }}
{{ include $kv (dict "cm" $cm "p" $b.license "f" "isDevelopment" "k" "IS_DEVELOPMENT" "opt" true) }}
# --- Multi-tenant (lerian-common.multiTenant.env; secrets via multiTenant.secret) --
MULTI_TENANT_ENABLED: {{ include "lerian-common.globalValue" (dict "context" $ "configmap" $cm "block" "multiTenant" "field" "enabled" "nativeKey" "MULTI_TENANT_ENABLED" "default" "false") | quote }}
{{ include "lerian-common.multiTenant.env" (dict "context" $ "configmap" $cm "enabled" $mtOn "requiredUrl" true "requiredRedisHost" true "emitRedis" true "emitPool" true "emitCache" true "emitAllowInsecure" true) }}
# --- PostgreSQL (lerian-common.datastore.value) ------------------------------
POSTGRES_HOST: {{ $pg.host | quote }}
POSTGRES_PORT: {{ $pg.port | quote }}
POSTGRES_USER: {{ $pg.user | quote }}
POSTGRES_NAME: {{ $pg.name | quote }}
POSTGRES_SSLMODE: {{ $pg.ssl | quote }}
{{ include $kv (dict "cm" $cm "p" $b.postgres "f" "maxOpenConns" "k" "POSTGRES_MAX_OPEN_CONNS" "d" "25") }}
{{ include $kv (dict "cm" $cm "p" $b.postgres "f" "maxIdleConns" "k" "POSTGRES_MAX_IDLE_CONNS" "d" "5") }}
{{ include $kv (dict "cm" $cm "p" $b.postgres "f" "connMaxLifetimeMins" "k" "POSTGRES_CONN_MAX_LIFETIME_MINS" "d" "30") }}
{{ include $kv (dict "cm" $cm "p" $b.postgres "f" "connMaxIdleTimeMins" "k" "POSTGRES_CONN_MAX_IDLE_TIME_MINS" "d" "5") }}
{{ include $kv (dict "cm" $cm "p" $b.postgres "f" "connectTimeoutSec" "k" "POSTGRES_CONNECT_TIMEOUT_SEC" "d" "10") }}
{{- $replicaHost := include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "postgres" "field" "replicaHost" "nativeKey" "POSTGRES_REPLICA_HOST" "default" "") }}
{{- if $replicaHost }}
POSTGRES_REPLICA_HOST: {{ $replicaHost | quote }}
POSTGRES_REPLICA_PORT: {{ include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "postgres" "field" "port" "nativeKey" "POSTGRES_REPLICA_PORT" "default" $pg.port) | quote }}
POSTGRES_REPLICA_USER: {{ include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "postgres" "field" "user" "nativeKey" "POSTGRES_REPLICA_USER" "default" $pg.user) | quote }}
POSTGRES_REPLICA_NAME: {{ include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "postgres" "field" "name" "nativeKey" "POSTGRES_REPLICA_NAME" "default" $pg.name) | quote }}
POSTGRES_REPLICA_SSLMODE: {{ include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "postgres" "field" "ssl" "nativeKey" "POSTGRES_REPLICA_SSLMODE" "default" $pg.ssl) | quote }}
{{- end }}
# --- Redis / Valkey (lerian-common.datastore.value) --------------------------
{{- $redisHostDefault := "" }}
{{- if eq (include "br-sisbajud.valkeyEnabled" .) "true" }}
{{- $redisHostDefault = printf "%s-primary.%s.svc.cluster.local.:6379" (include "common.names.dependency.fullname" (dict "chartName" "valkey" "chartValues" .Values.valkey "context" .)) (include "global.namespace" .) }}
{{- end }}
REDIS_HOST: {{ include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "redis" "field" "host" "nativeKey" "REDIS_HOST" "default" $redisHostDefault) | quote }}
REDIS_TLS: {{ include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "redis" "field" "tls" "nativeKey" "REDIS_TLS" "default" "false") | quote }}
{{- $redisCa := include $dv (dict "context" $ "dedicated" $dsDed "configmap" $cm "type" "redis" "field" "caCert" "nativeKey" "REDIS_CA_CERT" "default" "") }}
{{- if $redisCa }}
REDIS_CA_CERT: {{ $redisCa | quote }}
{{- end }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "masterName" "k" "REDIS_MASTER_NAME" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "db" "k" "REDIS_DB" "d" "0") }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "protocol" "k" "REDIS_PROTOCOL" "d" "3") }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "poolSize" "k" "REDIS_POOL_SIZE" "d" "10") }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "minIdleConns" "k" "REDIS_MIN_IDLE_CONNS" "d" "2") }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "readTimeout" "k" "REDIS_READ_TIMEOUT" "d" "3") }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "writeTimeout" "k" "REDIS_WRITE_TIMEOUT" "d" "3") }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "dialTimeout" "k" "REDIS_DIAL_TIMEOUT" "d" "5") }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "poolTimeout" "k" "REDIS_POOL_TIMEOUT" "d" "2") }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "maxRetries" "k" "REDIS_MAX_RETRIES" "d" "3") }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "minRetryBackoff" "k" "REDIS_MIN_RETRY_BACKOFF" "d" "8") }}
{{ include $kv (dict "cm" $cm "p" $b.redis "f" "maxRetryBackoff" "k" "REDIS_MAX_RETRY_BACKOFF" "d" "1") }}
# --- KMS / Vault Transit (lerian-common.kms.value); token + secret-id in the Secret --
{{- $kmsProvider := include "br-sisbajud.kmsProvider" . }}
KMS_PROVIDER: {{ $kmsProvider | quote }}
VAULT_ADDR: {{ include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "vaultAddr" "nativeKey" "VAULT_ADDR" "default" (ternary (include "br-sisbajud.openbaoAddr" .) "" (eq (include "br-sisbajud.openbaoEnabled" .) "true"))) | quote }}
VAULT_AUTH_METHOD: {{ include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "vaultAuthMethod" "nativeKey" "VAULT_AUTH_METHOD" "default" "token") | quote }}
VAULT_APPROLE_ROLE_ID: {{ include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "vaultRoleId" "nativeKey" "VAULT_APPROLE_ROLE_ID" "default" "") | quote }}
VAULT_TRANSIT_MOUNT_PATH: {{ include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "vaultMount" "nativeKey" "VAULT_TRANSIT_MOUNT_PATH" "default" "transit") | quote }}
{{ include $kv (dict "cm" $cm "p" $b.vault "f" "timeoutSec" "k" "VAULT_TIMEOUT_SEC" "d" "15") }}
{{ include $kv (dict "cm" $cm "p" $b.vault "f" "tokenRenewEnabled" "k" "VAULT_TOKEN_RENEW_ENABLED" "d" "true") }}
{{ include $kv (dict "cm" $cm "p" $b.vault "f" "tokenRenewMinIntervalSec" "k" "VAULT_TOKEN_RENEW_MIN_INTERVAL_SEC" "d" "60") }}
{{ include $kv (dict "cm" $cm "p" $b.vault "f" "awsEndpointUrl" "k" "AWS_ENDPOINT_URL" "opt" true) }}
{{- $awsRegion := include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "awsRegion" "nativeKey" "AWS_REGION" "default" "") }}
{{- if $awsRegion }}
AWS_REGION: {{ $awsRegion | quote }}
{{- end }}
# --- Envelope encryption + blind index ---------------------------------------
{{ include $kv (dict "cm" $cm "p" $b.crypto "f" "dekCacheTtl" "k" "SISBAJUD_DEK_CACHE_TTL" "d" "5m") }}
{{ include $kv (dict "cm" $cm "p" $b.crypto "f" "dekCacheMaxEntries" "k" "SISBAJUD_DEK_CACHE_MAX_ENTRIES" "d" "50000") }}
{{ include $kv (dict "cm" $cm "p" $b.crypto "f" "hmacCoexistenceWindow" "k" "SISBAJUD_HMAC_COEXISTENCE_WINDOW" "d" "720h") }}
# --- Object storage (lerian-common.objectStorage.value); keys in the Secret -----
SEAWEEDFS_S3_ENDPOINT: {{ $seaweedEndpoint | quote }}
SEAWEEDFS_BUCKET: {{ include $osv (dict "context" $ "dedicated" $osDed "configmap" $cm "name" "sisbajud" "field" "bucket" "nativeKey" "SEAWEEDFS_BUCKET" "default" "sisbajud") | quote }}
SEAWEEDFS_REGION: {{ include $osv (dict "context" $ "dedicated" $osDed "configmap" $cm "name" "sisbajud" "field" "region" "nativeKey" "SEAWEEDFS_REGION" "default" "us-east-1") | quote }}
# --- STA (br-sta) file reception, consumer and transfers ---------------------
STA_INBOUND_BUCKET: {{ $staBucket | quote }}
{{- /* Bucket + endpoint parity is enforced by the app (sta_bucket_parity.go): the
   transfer bucket MUST be the inbound bucket and the STA endpoint MUST be the
   SeaweedFS endpoint, so both default to those values (single-sourced). */}}
TRANSFER_OBJECT_STORAGE_BUCKET: {{ (hasKey $cm "TRANSFER_OBJECT_STORAGE_BUCKET" | ternary (index $cm "TRANSFER_OBJECT_STORAGE_BUCKET") $staBucket) | quote }}
STA_OBJECT_STORAGE_ENDPOINT: {{ include $osv (dict "context" $ "dedicated" $osDed "configmap" $cm "name" "sta" "field" "endpoint" "nativeKey" "STA_OBJECT_STORAGE_ENDPOINT" "default" $seaweedEndpoint) | quote }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "fileLockTtl" "k" "STA_FILE_LOCK_TTL" "d" "5") }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "consumerEnabled" "k" "STA_CONSUMER_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "consumerGroup" "k" "STA_CONSUMER_GROUP" "d" "sisbajud-sta-consumer") }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "consumerRetryBudget" "k" "STA_CONSUMER_RETRY_BUDGET" "d" "3") }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "sourceProduct" "k" "STA_SOURCE_PRODUCT" "d" "br-sisbajud") }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "bacenSystemCode" "k" "STA_BACEN_SYSTEM_CODE" "d" "JUD") }}
{{- /* Presence-validated by the app when the consumer is on: always emitted (empty is legitimate). */}}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "expectedTenantSt" "k" "STA_EXPECTED_TENANT_ST" "d" "") }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "maxInboundSizeBytes" "k" "STA_MAX_INBOUND_SIZE_BYTES" "d" "52428800") }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "transfersEnabled" "k" "STA_TRANSFERS_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "transfersBaseUrl" "k" "STA_TRANSFERS_BASE_URL" "d" "") }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "documentTypeAjud302" "k" "STA_DOCUMENT_TYPE_AJUD302" "d" "AJUD302") }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "documentTypeAjud309" "k" "STA_DOCUMENT_TYPE_AJUD309" "d" "AJUD309") }}
{{ include $kv (dict "cm" $cm "p" $b.sta "f" "clientId" "k" "STA_CLIENT_ID" "d" "") }}
# --- Background workers ------------------------------------------------------
{{ include $kv (dict "cm" $cm "p" $w.permanentBlockExpiry "f" "enabled" "k" "PERMANENT_BLOCK_EXPIRY_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $w.permanentBlockExpiry "f" "scanInterval" "k" "PERMANENT_BLOCK_EXPIRY_SCAN_INTERVAL" "d" "86400") }}
{{ include $kv (dict "cm" $cm "p" $w.permanentBlockExpiry "f" "batchSize" "k" "PERMANENT_BLOCK_EXPIRY_BATCH_SIZE" "d" "500") }}
{{ include $kv (dict "cm" $cm "p" $w.kekRewrapBackfill "f" "enabled" "k" "KEK_REWRAP_BACKFILL_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $w.kekRewrapBackfill "f" "scanInterval" "k" "KEK_REWRAP_BACKFILL_SCAN_INTERVAL" "d" "300") }}
{{ include $kv (dict "cm" $cm "p" $w.kekRewrapBackfill "f" "batchSize" "k" "KEK_REWRAP_BACKFILL_BATCH_SIZE" "d" "100") }}
{{ include $kv (dict "cm" $cm "p" $w.rehashBackfill "f" "enabled" "k" "REHASH_BACKFILL_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $w.rehashBackfill "f" "scanInterval" "k" "REHASH_BACKFILL_SCAN_INTERVAL" "d" "300") }}
{{ include $kv (dict "cm" $cm "p" $w.rehashBackfill "f" "batchSize" "k" "REHASH_BACKFILL_BATCH_SIZE" "d" "100") }}
{{ include $kv (dict "cm" $cm "p" $w.rehashBackfill "f" "dropPreviousKeyEnabled" "k" "REHASH_BACKFILL_DROP_PREVIOUS_KEY_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $w.reconciliation "f" "enabled" "k" "RECONCILIATION_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $w.reconciliation "f" "scanInterval" "k" "RECONCILIATION_SCAN_INTERVAL" "d" "3600") }}
{{ include $kv (dict "cm" $cm "p" $w.reconciliation "f" "batchSize" "k" "RECONCILIATION_BATCH_SIZE" "d" "500") }}
{{ include $kv (dict "cm" $cm "p" $w.reconciliation "f" "intensifiedEnabled" "k" "RECONCILIATION_INTENSIFIED_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $w.reconciliation "f" "intensifiedScanInterval" "k" "RECONCILIATION_INTENSIFIED_SCAN_INTERVAL" "d" "300") }}
{{ include $kv (dict "cm" $cm "p" $w.reconciliation "f" "nearDeadlinePercent" "k" "RECONCILIATION_NEAR_DEADLINE_PERCENT" "d" "75") }}
{{ include $kv (dict "cm" $cm "p" $w.slaAlert "f" "enabled" "k" "SLA_ALERT_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $w.slaAlert "f" "scanInterval" "k" "SLA_ALERT_SCAN_INTERVAL" "d" "60") }}
{{ include $kv (dict "cm" $cm "p" $w.returnFile "f" "enabled" "k" "RETURN_FILE_GENERATION_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $w.returnFile "f" "scanInterval" "k" "RETURN_FILE_GENERATION_SCAN_INTERVAL" "d" "3600") }}
{{ include $kv (dict "cm" $cm "p" $w.returnFile "f" "limit" "k" "RETURN_FILE_GENERATION_LIMIT" "d" "500") }}
{{ include $kv (dict "cm" $cm "p" $w.returnFile "f" "environment" "k" "RETURN_FILE_ENVIRONMENT" "d" "HOMOLOGATION") }}
{{ include $kv (dict "cm" $cm "p" $w.informationReturnFile "f" "enabled" "k" "INFORMATION_RETURN_FILE_GENERATION_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $w.informationReturnFile "f" "scanInterval" "k" "INFORMATION_RETURN_FILE_GENERATION_SCAN_INTERVAL" "d" "3600") }}
{{ include $kv (dict "cm" $cm "p" $w.informationReturnFile "f" "limit" "k" "INFORMATION_RETURN_FILE_GENERATION_LIMIT" "d" "500") }}
{{ include $kv (dict "cm" $cm "p" $w.informationRequest "f" "enabled" "k" "INFORMATION_REQUEST_ENABLED" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $w.informationRequest "f" "scanInterval" "k" "INFORMATION_REQUEST_SCAN_INTERVAL" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $w.informationRequest "f" "batchSize" "k" "INFORMATION_REQUEST_BATCH_SIZE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $w.informationRequest "f" "lockTtl" "k" "INFORMATION_REQUEST_LOCK_TTL" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $w.monitoringExpiry "f" "enabled" "k" "MONITORING_EXPIRY_ENABLED" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $w.monitoringExpiry "f" "scanInterval" "k" "MONITORING_EXPIRY_SCAN_INTERVAL" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $w.monitoringExpiry "f" "batchSize" "k" "MONITORING_EXPIRY_BATCH_SIZE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $w.execution "f" "enabled" "k" "EXECUTION_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $w.execution "f" "orchestratorLockTtl" "k" "ORCHESTRATOR_LOCK_TTL" "d" "30") }}
{{ include $kv (dict "cm" $cm "p" $w.execution "f" "orchestratorRenewInterval" "k" "ORCHESTRATOR_RENEW_INTERVAL" "d" "10") }}
{{ include $kv (dict "cm" $cm "p" $w.execution "f" "unblockScanInterval" "k" "UNBLOCK_EXECUTION_SCAN_INTERVAL" "d" "60") }}
{{ include $kv (dict "cm" $cm "p" $w.execution "f" "unblockBatchSize" "k" "UNBLOCK_EXECUTION_BATCH_SIZE" "d" "500") }}
{{ include $kv (dict "cm" $cm "p" $w.processingLockReaper "f" "enabled" "k" "PROCESSING_LOCK_REAPER_ENABLED" "d" "true") }}
{{ include $kv (dict "cm" $cm "p" $w.processingLockReaper "f" "intervalSec" "k" "PROCESSING_LOCK_REAPER_INTERVAL_SEC" "d" "300") }}
# --- Remittance layout ---------------------------------------------------------
{{ include $kv (dict "cm" $cm "p" $b.layout "f" "responseLayout" "k" "SISBAJUD_RESPONSE_LAYOUT" "d" "auto") }}
{{ include $kv (dict "cm" $cm "p" $b.layout "f" "remittanceLayouts" "k" "SISBAJUD_REMITTANCE_LAYOUTS" "d" "v111,v2026") }}
# --- Outbox (durability path for streaming) -----------------------------------
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "enabled" "k" "OUTBOX_ENABLED" "d" "true") }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "tableName" "k" "OUTBOX_TABLE_NAME" "d" "outbox_events") }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "dispatchIntervalSec" "k" "OUTBOX_DISPATCH_INTERVAL_SEC" "d" "2") }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "batchSize" "k" "OUTBOX_BATCH_SIZE" "d" "50") }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "publishMaxAttempts" "k" "OUTBOX_PUBLISH_MAX_ATTEMPTS" "d" "3") }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "publishBackoffMs" "k" "OUTBOX_PUBLISH_BACKOFF_MS" "d" "200") }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "retryWindowSec" "k" "OUTBOX_RETRY_WINDOW_SEC" "d" "300") }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "maxDispatchAttempts" "k" "OUTBOX_MAX_DISPATCH_ATTEMPTS" "d" "10") }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "processingTimeoutSec" "k" "OUTBOX_PROCESSING_TIMEOUT_SEC" "d" "600") }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "maxFailedPerBatch" "k" "OUTBOX_MAX_FAILED_PER_BATCH" "d" "25") }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "includeTenantMetrics" "k" "OUTBOX_INCLUDE_TENANT_METRICS" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "priorityEventTypes" "k" "OUTBOX_PRIORITY_EVENT_TYPES" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.outbox "f" "allowEmptyTenant" "k" "OUTBOX_ALLOW_EMPTY_TENANT" "d" "true") }}
# --- Streaming (lerian-common.streaming.env; SASL password/CA via streaming.secret) --
STREAMING_ENABLED: {{ $streamingRaw | quote }}
{{ include $kv (dict "cm" $cm "p" $b.streaming "f" "cloudeventsSource" "k" "STREAMING_CLOUDEVENTS_SOURCE" "d" "br-sisbajud") }}
{{ include $kv (dict "cm" $cm "p" $b.streaming "f" "clientId" "k" "STREAMING_CLIENT_ID" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.streaming "f" "healthCheckTimeout" "k" "STREAMING_HEALTH_CHECK_TIMEOUT" "d" "2s") }}
{{ include "lerian-common.streaming.env" (dict "context" (dict "Values" (dict "global" (dict "streaming" (include "br-sisbajud.streamingGlobal" . | fromYaml)))) "enabled" $streamingOn "configmap" $cm) }}
{{ include $kv (dict "cm" $cm "p" $b.balanceConsumer "f" "group" "k" "BALANCE_CONSUMER_GROUP" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.balanceConsumer "f" "dedupTtl" "k" "BALANCE_DEDUP_TTL" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.balanceConsumer "f" "retryBudget" "k" "BALANCE_CONSUMER_RETRY_BUDGET" "opt" true) }}
# --- Midaz ledger (balance translator + connector surface) ---------------------
{{ include $kv (dict "cm" $cm "p" $b.midaz "f" "balanceTopic" "k" "MIDAZ_BALANCE_TOPIC" "d" "lerian.streaming.ledger") }}
{{ include $kv (dict "cm" $cm "p" $b.midaz "f" "balanceConsumerGroup" "k" "MIDAZ_BALANCE_CONSUMER_GROUP" "d" "sisbajud-midaz-balance-translator") }}
{{ include $kv (dict "cm" $cm "p" $b.midaz "f" "balanceDefaultAccountType" "k" "MIDAZ_BALANCE_DEFAULT_ACCOUNT_TYPE" "d" "deposit") }}
{{ include $kv (dict "cm" $cm "p" $b.midaz "f" "crmMode" "k" "MIDAZ_CRM_MODE" "d" "legacy") }}
{{ include $kv (dict "cm" $cm "p" $b.midaz "f" "manifestCheckInterval" "k" "MIDAZ_MANIFEST_CHECK_INTERVAL" "d" "15m") }}
# --- Inbound auth (lerian-common.auth.env) -------------------------------------
{{ include "lerian-common.auth.env" (dict "context" $ "configmap" $cm "hostKey" "PLUGIN_AUTH_HOST" "hostDefault" "") }}
{{ include $kv (dict "cm" $cm "p" $b.auth "f" "trustedProxies" "k" "TRUSTED_PROXIES" "d" "") }}
{{ include $kv (dict "cm" $cm "p" $b.auth "f" "productName" "k" "AUTH_PRODUCT_NAME" "opt" true) }}
# --- Access-manager declaration publisher (lib-auth); client secret in the Secret --
{{ include $kv (dict "cm" $cm "p" $b.identity "f" "declarationEnabled" "k" "IDP_DECLARATION_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $b.identity "f" "host" "k" "IDP_HOST" "d" "") }}
{{ include $kv (dict "cm" $cm "p" $b.identity "f" "m2mClientId" "k" "IDP_M2M_CLIENT_ID" "d" "") }}
# --- M2M credential provider (multi-tenant) -----------------------------------
{{ include $kv (dict "cm" $cm "p" $b.m2m "f" "targetService" "k" "M2M_TARGET_SERVICE" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.m2m "f" "credentialCacheTtlSec" "k" "M2M_CREDENTIAL_CACHE_TTL_SEC" "d" "300") }}
# --- OpenTelemetry (lerian-common.otel.env) ------------------------------------
{{ include "lerian-common.otel.env" (dict "context" $ "configmap" $cm "enabledDefault" $telemetryDefault "endpointDefault" "localhost:4317" "deploymentEnvironmentDefault" $envName) }}
{{ include $kv (dict "cm" $cm "p" $b.observability "f" "serviceName" "k" "OTEL_RESOURCE_SERVICE_NAME" "d" "br-sisbajud") }}
{{ include $kv (dict "cm" $cm "p" $b.observability "f" "libraryName" "k" "OTEL_LIBRARY_NAME" "d" "github.com/LerianStudio/br-sisbajud") }}
# --- Rate limiting (lerian-common.rateLimit.env) -------------------------------
{{ include "lerian-common.rateLimit.env" (dict "configmap" $cm "params" $b.rateLimit) }}
# --- Swagger -------------------------------------------------------------------
{{ include $kv (dict "cm" $cm "p" $b.swagger "f" "enabled" "k" "SWAGGER_ENABLED" "d" "false") }}
{{ include $kv (dict "cm" $cm "p" $b.swagger "f" "title" "k" "SWAGGER_TITLE" "d" "br-sisbajud") }}
{{ include $kv (dict "cm" $cm "p" $b.swagger "f" "version" "k" "SWAGGER_VERSION" "d" $imageTag) }}
{{ include $kv (dict "cm" $cm "p" $b.swagger "f" "basePath" "k" "SWAGGER_BASE_PATH" "d" "/") }}
{{ include $kv (dict "cm" $cm "p" $b.swagger "f" "leftDelim" "k" "SWAGGER_LEFT_DELIM" "d" "{{") }}
{{ include $kv (dict "cm" $cm "p" $b.swagger "f" "rightDelim" "k" "SWAGGER_RIGHT_DELIM" "d" "}}") }}
{{ include $kv (dict "cm" $cm "p" $b.swagger "f" "description" "k" "SWAGGER_DESCRIPTION" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.swagger "f" "host" "k" "SWAGGER_HOST" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.swagger "f" "schemes" "k" "SWAGGER_SCHEMES" "opt" true) }}
# --- Pagination + admin read API -----------------------------------------------
{{ include $kv (dict "cm" $cm "p" $b.pagination "f" "maxLimit" "k" "MAX_PAGINATION_LIMIT" "d" "100") }}
{{ include $kv (dict "cm" $cm "p" $b.pagination "f" "maxMonthDateRange" "k" "MAX_PAGINATION_MONTH_DATE_RANGE" "d" "3") }}
{{ include $kv (dict "cm" $cm "p" $b.admin "f" "maxFileContentBytes" "k" "ADMIN_MAX_FILE_CONTENT_BYTES" "d" "104857600") }}
{{ include $kv (dict "cm" $cm "p" $b.admin "f" "maxAuditVerifyWindow" "k" "ADMIN_MAX_AUDIT_VERIFY_WINDOW" "opt" true) }}
{{- end -}}

{{/*
br-sisbajud.secretData — the chart-modeled Secret keys (stringData lines).
Infra passwords are written only for EXTERNAL infra without an
<subchart>.auth.existingSecret (the bundled path is single-sourced from the
subchart Secret via secretKeyRef on the Deployment). Streaming and multi-tenant
keys come from the lerian-common companion helpers, which also fail fast when a
required one is missing.
*/}}
{{- define "br-sisbajud.secretData" -}}
{{- $b := .Values.brSisbajud -}}
{{- $s := $b.secrets | default dict -}}
{{- $cm := $b.configmap | default dict -}}
{{- $x := include "br-sisbajud.extraEnv" . | fromYaml -}}
{{- $pg := .Values.postgresql | default dict -}}
{{- $pgAuth := $pg.auth | default dict -}}
{{- $vk := .Values.valkey | default dict -}}
{{- $vkAuth := $vk.auth | default dict -}}
{{- $pgInternal := eq (include "br-sisbajud.postgresInternal" .) "true" -}}
{{- $vkInternal := eq (include "br-sisbajud.valkeyInternal" .) "true" -}}
{{- if and (not $pgInternal) (not $pgAuth.existingSecret) $s.POSTGRES_PASSWORD }}
POSTGRES_PASSWORD: {{ $s.POSTGRES_PASSWORD | quote }}
{{- end }}
{{- if and (not $vkInternal) (not $vkAuth.existingSecret) $s.REDIS_PASSWORD }}
REDIS_PASSWORD: {{ $s.REDIS_PASSWORD | quote }}
{{- end }}
{{- range $k := list "POSTGRES_REPLICA_PASSWORD" "LICENSE_KEY" "VAULT_TOKEN" "VAULT_APPROLE_SECRET_ID" "SEAWEEDFS_ACCESS_KEY" "SEAWEEDFS_SECRET_KEY" "STA_CLIENT_SECRET" "IDP_M2M_CLIENT_SECRET" }}
{{- with index $s $k }}
{{ $k }}: {{ . | quote }}
{{- end }}
{{- end }}
{{- /* Streaming SASL password / CA cert. The mechanism and username are resolved
   with the same configmap-over-global precedence as the ConfigMap. When the
   password already reaches the pod as an explicit extraEnvVars entry (the 1.1.x
   wiring), the helper's fail-fast is skipped and only the CA is copied here. */}}
{{- $gs := (.Values.global | default dict).streaming | default dict }}
{{- $saslMech := $gs.saslMechanism | default "" }}
{{- if hasKey $cm "STREAMING_SASL_MECHANISM" }}{{- $saslMech = index $cm "STREAMING_SASL_MECHANISM" }}{{- end }}
{{- $saslUser := $gs.saslUsername | default "" }}
{{- if hasKey $cm "STREAMING_SASL_USERNAME" }}{{- $saslUser = index $cm "STREAMING_SASL_USERNAME" }}{{- end }}
{{- $streamingOn := eq (include "br-sisbajud.isTrue" (include "br-sisbajud.streamingEnabledRaw" .)) "true" }}
{{- if hasKey $x "STREAMING_SASL_PASSWORD" }}
{{- with $s.STREAMING_TLS_CA_CERT }}
STREAMING_TLS_CA_CERT: {{ . | quote }}
{{- end }}
{{- else }}
{{ include "lerian-common.streaming.secret" (dict "context" . "secrets" $s "secretName" (include "br-sisbajud.fullname" .) "valuesPrefix" "brSisbajud.secrets." "mode" "stringData" "enabled" $streamingOn "useExistingSecret" false "saslMechanism" $saslMech "saslUsername" $saslUser) }}
{{- end }}
{{- /* Multi-tenant service API key (required when MT is on) + tenant Redis password. */}}
{{- $mtOn := eq (include "br-sisbajud.multiTenantEnabled" .) "true" }}
{{- if hasKey $x "MULTI_TENANT_SERVICE_API_KEY" }}
{{- with $s.MULTI_TENANT_REDIS_PASSWORD }}
MULTI_TENANT_REDIS_PASSWORD: {{ . | quote }}
{{- end }}
{{- else }}
{{ include "lerian-common.multiTenant.secret" (dict "context" . "secrets" $s "secretName" (include "br-sisbajud.fullname" .) "valuesPrefix" "brSisbajud.secrets." "mode" "stringData" "enabled" $mtOn "useExistingSecret" false) }}
{{- end }}
{{- end -}}

{{/*
br-sisbajud.required — fail with an actionable message when KEY does not reach
the pod from any source. Inputs: context, key, value (resolved ConfigMap value,
opt), secret (bool: the key is a credential, so useExistingSecret satisfies it),
why (condition text), set (where to set it).
*/}}
{{- define "br-sisbajud.required" -}}
{{- $ctx := .context -}}
{{- $skip := and .secret $ctx.Values.brSisbajud.useExistingSecret -}}
{{- if and (not $skip) (not (include "br-sisbajud.provided" (dict "context" $ctx "key" .key "value" .value))) -}}
{{- fail (printf "\n\nERROR: br-sisbajud: %s is required %s.\n  set: %s\n  (or pass it as a brSisbajud.extraEnvVars entry%s)\n" .key .why .set (ternary " / via brSisbajud.useExistingSecret" "" (eq (toString .secret) "true"))) -}}
{{- end -}}
{{- end -}}

{{/*
br-sisbajud.validate — fail-fast gates mirroring the app's boot validation
(internal/bootstrap/config_validation.go), so a values mistake fails the render
instead of CrashLooping the pod. Invoked from configmap.yaml.
*/}}
{{- define "br-sisbajud.validate" -}}
{{- $ := . -}}
{{- $b := .Values.brSisbajud -}}
{{- $cm := $b.configmap | default dict -}}
{{- include "br-sisbajud.bundleGuard" . -}}
{{- $data := include "br-sisbajud.configmapData" . | fromYaml -}}
{{- $req := "br-sisbajud.required" -}}
{{- $prodLike := eq (include "br-sisbajud.productionLike" .) "true" -}}
{{- $envName := include "br-sisbajud.envName" . -}}
{{- $mtOn := eq (include "br-sisbajud.multiTenantEnabled" .) "true" -}}
{{- /* STA inbound bucket: validated unconditionally by the app (no default by policy). */ -}}
{{- include $req (dict "context" $ "key" "STA_INBOUND_BUCKET" "value" (index $data "STA_INBOUND_BUCKET") "why" "(the app refuses to boot without it; it must match br-sta's transfer bucket for the tier)" "set" "global.objectStorage.sta.bucket (or brSisbajud.objectStorage.sta.bucket)") -}}
{{- /* Single-tenant datastores. */ -}}
{{- if not $mtOn -}}
{{- include $req (dict "context" $ "key" "POSTGRES_HOST" "value" (index $data "POSTGRES_HOST") "why" "when multi-tenancy is off (or enable the bundled postgresql subchart)" "set" "global.datastores.postgres.host") -}}
{{- include $req (dict "context" $ "key" "REDIS_HOST" "value" (index $data "REDIS_HOST") "why" "when multi-tenancy is off (or enable the bundled valkey subchart)" "set" "global.datastores.redis.host (host:port)") -}}
{{- $pg := .Values.postgresql | default dict -}}
{{- $pgAuth := $pg.auth | default dict -}}
{{- if and $prodLike (ne (include "br-sisbajud.postgresInternal" .) "true") (not $pgAuth.existingSecret) -}}
{{- include $req (dict "context" $ "key" "POSTGRES_PASSWORD" "secret" true "why" (printf "in a production-like environment (ENVIRONMENT_NAME=%q) with external Postgres" $envName) "set" "brSisbajud.secrets.POSTGRES_PASSWORD") -}}
{{- end -}}
{{- end -}}
{{- /* License: fail-closed in production-like environments. */ -}}
{{- if $prodLike -}}
{{- include $req (dict "context" $ "key" "LICENSE_KEY" "secret" true "why" (printf "in a production-like environment (ENVIRONMENT_NAME=%q; use development|staging|... to run without a license)" $envName) "set" "brSisbajud.secrets.LICENSE_KEY") -}}
{{- end -}}
{{- /* KMS backend. */ -}}
{{- $kms := index $data "KMS_PROVIDER" -}}
{{- if not (has $kms (list "vault" "aws")) -}}
{{- fail (printf "\n\nERROR: br-sisbajud: KMS_PROVIDER must be vault or aws (got %q).\n  set: global.kms.vendor (hashicorp-vault | aws) or brSisbajud.configmap.KMS_PROVIDER\n" $kms) -}}
{{- end -}}
{{- if eq $kms "vault" -}}
{{- include $req (dict "context" $ "key" "VAULT_ADDR" "value" (index $data "VAULT_ADDR") "why" "when KMS_PROVIDER=vault" "set" "global.kms.vaultAddr (or brSisbajud.kms.vaultAddr)") -}}
{{- $auth := lower (index $data "VAULT_AUTH_METHOD" | default "token") -}}
{{- if eq $auth "approle" -}}
{{- include $req (dict "context" $ "key" "VAULT_APPROLE_ROLE_ID" "value" (index $data "VAULT_APPROLE_ROLE_ID") "why" "when VAULT_AUTH_METHOD=approle" "set" "global.kms.vaultRoleId (or brSisbajud.kms.vaultRoleId)") -}}
{{- include $req (dict "context" $ "key" "VAULT_APPROLE_SECRET_ID" "secret" true "why" "when VAULT_AUTH_METHOD=approle" "set" "brSisbajud.secrets.VAULT_APPROLE_SECRET_ID") -}}
{{- else if eq $auth "token" -}}
{{- if eq $envName "production" -}}
{{- include $req (dict "context" $ "key" "VAULT_TOKEN" "secret" true "why" "when VAULT_AUTH_METHOD=token and ENVIRONMENT_NAME=production (prefer approle)" "set" "brSisbajud.secrets.VAULT_TOKEN") -}}
{{- end -}}
{{- else -}}
{{- fail (printf "\n\nERROR: br-sisbajud: VAULT_AUTH_METHOD must be token or approle (got %q).\n  set: global.kms.vaultAuthMethod\n" $auth) -}}
{{- end -}}
{{- else -}}
{{- include $req (dict "context" $ "key" "AWS_REGION" "value" (index $data "AWS_REGION") "why" "when KMS_PROVIDER=aws" "set" "global.kms.awsRegion (or brSisbajud.kms.awsRegion)") -}}
{{- end -}}
{{- /* Streaming: the app fails at boot when enabled without brokers. */ -}}
{{- if eq (include "br-sisbajud.isTrue" (index $data "STREAMING_ENABLED")) "true" -}}
{{- include $req (dict "context" $ "key" "STREAMING_BROKERS" "value" (index $data "STREAMING_BROKERS") "why" "when STREAMING_ENABLED=true (streaming is off by default; enable it together with brokers/TLS/SASL and keep OUTBOX_ENABLED=true)" "set" "global.streaming.brokers") -}}
{{- else if or (index $data "STREAMING_BROKERS") (index $cm "STREAMING_BROKERS") -}}
{{- /* The app refuses STREAMING_BROKERS with STREAMING_ENABLED=false (validateStreamingEnablement). */ -}}
{{- fail "\n\nERROR: br-sisbajud: STREAMING_BROKERS is set while STREAMING_ENABLED=false (the app refuses to boot: the Midaz balance translator would publish into a no-op).\n  set: global.streaming.enabled=true, or unset brSisbajud.configmap.STREAMING_BROKERS\n" -}}
{{- end -}}
{{- /* The STA consumer reads br-sta's facts off STREAMING_BROKERS, which the app only accepts with streaming on. */ -}}
{{- if and (eq (include "br-sisbajud.isTrue" (index $data "STA_CONSUMER_ENABLED")) "true") (ne (include "br-sisbajud.isTrue" (index $data "STREAMING_ENABLED")) "true") -}}
{{- fail "\n\nERROR: br-sisbajud: STA_CONSUMER_ENABLED=true requires STREAMING_ENABLED=true (the consumer needs STREAMING_BROKERS, which the app refuses while streaming is off).\n  set: global.streaming.enabled=true + global.streaming.brokers, or brSisbajud.sta.consumerEnabled=false\n" -}}
{{- end -}}
{{- /* STA transfers client (m2m to br-sta). */ -}}
{{- if eq (include "br-sisbajud.isTrue" (index $data "STA_TRANSFERS_ENABLED")) "true" -}}
{{- include $req (dict "context" $ "key" "STA_TRANSFERS_BASE_URL" "value" (index $data "STA_TRANSFERS_BASE_URL") "why" "when STA_TRANSFERS_ENABLED=true" "set" "brSisbajud.sta.transfersBaseUrl") -}}
{{- include $req (dict "context" $ "key" "STA_CLIENT_ID" "value" (index $data "STA_CLIENT_ID") "why" "when STA_TRANSFERS_ENABLED=true" "set" "brSisbajud.sta.clientId") -}}
{{- include $req (dict "context" $ "key" "STA_CLIENT_SECRET" "secret" true "why" "when STA_TRANSFERS_ENABLED=true" "set" "brSisbajud.secrets.STA_CLIENT_SECRET") -}}
{{- include $req (dict "context" $ "key" "PLUGIN_AUTH_HOST" "value" (index $data "PLUGIN_AUTH_HOST") "why" "when STA_TRANSFERS_ENABLED=true (the m2m bearer is minted from it, even with PLUGIN_AUTH_ENABLED=false)" "set" "global.auth.host") -}}
{{- end -}}
{{- /* Inbound auth. */ -}}
{{- if eq (include "br-sisbajud.isTrue" (index $data "PLUGIN_AUTH_ENABLED")) "true" -}}
{{- include $req (dict "context" $ "key" "PLUGIN_AUTH_HOST" "value" (index $data "PLUGIN_AUTH_HOST") "why" "when PLUGIN_AUTH_ENABLED=true" "set" "global.auth.host") -}}
{{- end -}}
{{- /* Access-manager declaration publisher. */ -}}
{{- if eq (include "br-sisbajud.isTrue" (index $data "IDP_DECLARATION_ENABLED")) "true" -}}
{{- include $req (dict "context" $ "key" "IDP_HOST" "value" (index $data "IDP_HOST") "why" "when IDP_DECLARATION_ENABLED=true" "set" "brSisbajud.identity.host") -}}
{{- include $req (dict "context" $ "key" "IDP_M2M_CLIENT_ID" "value" (index $data "IDP_M2M_CLIENT_ID") "why" "when IDP_DECLARATION_ENABLED=true" "set" "brSisbajud.identity.m2mClientId") -}}
{{- include $req (dict "context" $ "key" "IDP_M2M_CLIENT_SECRET" "secret" true "why" "when IDP_DECLARATION_ENABLED=true" "set" "brSisbajud.secrets.IDP_M2M_CLIENT_SECRET") -}}
{{- end -}}
{{- /* License mode: GLOBAL only. */ -}}
{{- $org := trim (toString (index $data "ORGANIZATION_IDS")) -}}
{{- if and $org (ne (lower $org) "global") -}}
{{- fail (printf "\n\nERROR: br-sisbajud: ORGANIZATION_IDS must be \"global\" (got %q): the app supports GLOBAL license mode only.\n" $org) -}}
{{- end -}}
{{- end -}}

{{/*
br-sisbajud.migrationsConn — the resolved migrations connection, shared by the
migrations Job and (bundled Postgres) the app's migrations initContainer.
*/}}
{{- define "br-sisbajud.migrationsConn" -}}
{{- /* Connection: migrations.postgres.* override > the app's resolved POSTGRES_*
   (br-sisbajud.postgres: configmap > datastores > global > cloud > default), so
   the Job and the app can never point at different databases. */ -}}
{{- $app := include "br-sisbajud.postgres" . | fromYaml -}}
{{- $mp := .Values.migrations.postgres | default dict -}}
{{- $pgHost := $mp.host | default $app.host -}}
{{- $pgPort := $mp.port | default $app.port | toString -}}
{{- $pgUser := $mp.user | default $app.user -}}
{{- $pgDb := $mp.database | default $app.name -}}
{{- $pgSslMode := $mp.sslMode | default $app.ssl -}}
{{- $pgConnectTimeout := $mp.connectTimeoutSec | default (include "lerian-common.cfgValue" (dict "configmap" (.Values.brSisbajud.configmap | default dict) "nativeKey" "POSTGRES_CONNECT_TIMEOUT_SEC" "params" .Values.brSisbajud.postgres "field" "connectTimeoutSec" "default" "10")) -}}
{{- if not $pgHost -}}
{{- fail "\n\nERROR: br-sisbajud: the migrations Job needs a Postgres host.\n  set: global.datastores.postgres.host (or migrations.postgres.host), or disable it with migrations.enabled=false\n" -}}
{{- end -}}
{{- if and .Values.migrations.useExistingSecret (not .Values.migrations.existingSecretName) -}}
{{- fail "migrations.existingSecretName is required when migrations.useExistingSecret is true" -}}
{{- end -}}
{{- $secretName := ternary .Values.migrations.existingSecretName (include "br-sisbajud-migrations.fullname" .) .Values.migrations.useExistingSecret }}
{{- /* Bundled (or existingSecret) Postgres: the password is single-sourced from the
   subchart Secret, same as the app. */ -}}
{{- $pgAuth := (.Values.postgresql | default dict).auth | default dict -}}
{{- $pgFromSubchartBundled := eq (include "br-sisbajud.postgresInternal" .) "true" -}}
{{- $pgFromSubchart := and (not .Values.migrations.useExistingSecret) (or (eq (include "br-sisbajud.postgresInternal" .) "true") $pgAuth.existingSecret) -}}
{{- /* ALLOW_INSECURE_TLS: lib-commons' migrator refuses non-TLS Postgres unless this
   is true; sslmode=disable alone is not enough. Resolution:
   migrations.allowInsecureTLS > brSisbajud.extraEnvVars > the app's resolved
   ALLOW_INSECURE_TLS (configmap > brSisbajud.security.allowInsecureTls > default). */ -}}
{{- $x := include "br-sisbajud.extraEnv" . | fromYaml -}}
{{- $allowInsecureTLS := include "br-sisbajud.allowInsecureTLS" . -}}
{{- if hasKey .Values.migrations "allowInsecureTLS" -}}
{{- $allowInsecureTLS = toString .Values.migrations.allowInsecureTLS -}}
{{- else if and (hasKey $x "ALLOW_INSECURE_TLS") (ne (index $x "ALLOW_INSECURE_TLS") "__valueFrom__") -}}
{{- $allowInsecureTLS = index $x "ALLOW_INSECURE_TLS" -}}
{{- end }}
host: {{ $pgHost | quote }}
port: {{ $pgPort | quote }}
user: {{ $pgUser | quote }}
db: {{ $pgDb | quote }}
ssl: {{ $pgSslMode | quote }}
connectTimeout: {{ $pgConnectTimeout | quote }}
allowInsecureTLS: {{ $allowInsecureTLS | quote }}
fromSubchart: {{ ternary "true" "false" (eq (toString $pgFromSubchart) "true") | quote }}
bundled: {{ ternary "true" "false" $pgFromSubchartBundled | quote }}
secretName: {{ $secretName | quote }}
{{- /* POSTGRES_PASSWORD source for the migrations container — the SAME credential
   the app uses, in the app's own effective precedence (explicit pod env wins
   over the subchart secretKeyRef, which wins over envFrom), so the two can never
   drift. Explicit migration-only overrides come first:
     1. migrations.useExistingSecret                    -> migrations.existingSecretName
     2. migrations.postgres.password (explicit override) -> the dedicated hook Secret
     3. brSisbajud.extraEnvVars POSTGRES_PASSWORD        -> the same entry, verbatim
     4. bundled subchart / postgresql.auth.existingSecret -> that Secret (secretKeyRef)
     5. brSisbajud.useExistingSecret                     -> brSisbajud.existingSecretName
     6. brSisbajud.secrets.POSTGRES_PASSWORD             -> copied into the hook Secret
   (the app Secret does not exist yet during PreSync/pre-install)
   otherwise the render fails instead of migrating with an empty password. */ -}}
{{- $envByName := dict -}}
{{- range (include "br-sisbajud.podEnvList" . | fromYamlArray) -}}{{- if .name -}}{{- $_ := set $envByName .name . -}}{{- end -}}{{- end -}}
{{- $appSecrets := .Values.brSisbajud.secrets | default dict -}}
{{- $pwEnv := dict -}}
{{- $hookPassword := "" -}}
{{- if .Values.migrations.useExistingSecret -}}
{{- $pwEnv = dict "name" "POSTGRES_PASSWORD" "valueFrom" (dict "secretKeyRef" (dict "name" .Values.migrations.existingSecretName "key" "POSTGRES_PASSWORD")) -}}
{{- else if $mp.password -}}
{{- $hookPassword = $mp.password -}}
{{- else if index $envByName "POSTGRES_PASSWORD" -}}
{{- $pwEnv = index $envByName "POSTGRES_PASSWORD" -}}
{{- else if $pgFromSubchart -}}
{{- $pwEnv = include "lerian-common.infraSecretRef" (dict "context" . "subchart" "postgresql" "key" "password" "envName" "POSTGRES_PASSWORD") | fromYamlArray | first -}}
{{- else if .Values.brSisbajud.useExistingSecret -}}
{{- $pwEnv = dict "name" "POSTGRES_PASSWORD" "valueFrom" (dict "secretKeyRef" (dict "name" .Values.brSisbajud.existingSecretName "key" "POSTGRES_PASSWORD")) -}}
{{- else if $appSecrets.POSTGRES_PASSWORD -}}
{{- $hookPassword = $appSecrets.POSTGRES_PASSWORD -}}
{{- else -}}
{{- fail "\n\nERROR: br-sisbajud: the migrations Job has no Postgres password: none of the app's sources is set (bundled postgresql, postgresql.auth.existingSecret, brSisbajud.useExistingSecret, brSisbajud.extraEnvVars POSTGRES_PASSWORD, brSisbajud.secrets.POSTGRES_PASSWORD).\n  set: brSisbajud.secrets.POSTGRES_PASSWORD (or migrations.postgres.password / migrations.useExistingSecret), or disable it with migrations.enabled=false\n" -}}
{{- end -}}
{{- if $hookPassword -}}
{{- $pwEnv = dict "name" "POSTGRES_PASSWORD" "valueFrom" (dict "secretKeyRef" (dict "name" (include "br-sisbajud-migrations.fullname" .) "key" "POSTGRES_PASSWORD")) -}}
{{- end }}
passwordEnv: {{ toJson $pwEnv | quote }}
hookSecret: {{ ternary "true" "false" (ne (toString $hookPassword) "") | quote }}
{{- end -}}

{{/*
br-sisbajud.migrationsHookPassword — the value the dedicated migrations hook
Secret carries (sources 2 and 6 above); empty when another source is used.
*/}}
{{- define "br-sisbajud.migrationsHookPassword" -}}
{{- $mp := .Values.migrations.postgres | default dict -}}
{{- $c := include "br-sisbajud.migrationsConn" . | fromYaml -}}
{{- if eq $c.hookSecret "true" -}}
{{- $mp.password | default (.Values.brSisbajud.secrets | default dict).POSTGRES_PASSWORD -}}
{{- end -}}
{{- end -}}

{{/*
br-sisbajud.migrationsContainer — the migrations container (golang-migrate `up`,
idempotent and lock-protected). Used by the Job and, with a bundled Postgres, as
an app initContainer so the app never boots on an unmigrated schema.
*/}}
{{- define "br-sisbajud.migrationsContainer" -}}
{{- $c := include "br-sisbajud.migrationsConn" . | fromYaml -}}
{{- $pgHost := $c.host -}}{{- $pgPort := $c.port -}}{{- $pgUser := $c.user -}}{{- $pgDb := $c.db -}}{{- $pgSslMode := $c.ssl -}}
{{- $pgConnectTimeout := $c.connectTimeout -}}{{- $allowInsecureTLS := $c.allowInsecureTLS -}}{{- $secretName := $c.secretName -}}
{{- $pgFromSubchart := eq $c.fromSubchart "true" -}}

- name: migrations
  image: "{{ .Values.migrations.image.repository }}:{{ .Values.migrations.image.tag | default .Chart.AppVersion }}"
  imagePullPolicy: {{ .Values.migrations.image.pullPolicy | default "IfNotPresent" }}
  env:
    - name: MIGRATIONS_PATH
      value: "/migrations"
    - name: POSTGRES_HOST
      value: {{ $pgHost | quote }}
    - name: POSTGRES_PORT
      value: {{ $pgPort | quote }}
    - name: POSTGRES_USER
      value: {{ $pgUser | quote }}
    - name: POSTGRES_NAME
      value: {{ $pgDb | quote }}
    - name: POSTGRES_SSLMODE
      value: {{ $pgSslMode | quote }}
    - name: ALLOW_INSECURE_TLS
      value: {{ $allowInsecureTLS | quote }}
    - name: ENV_NAME
      value: {{ include "br-sisbajud.envName" . | quote }}
    - name: POSTGRES_CONNECT_TIMEOUT_SEC
      value: {{ $pgConnectTimeout | quote }}
    - {{ $c.passwordEnv | fromJson | toYaml | nindent 6 | trim }}
  securityContext:
    runAsUser: 65532
    runAsGroup: 65532
    runAsNonRoot: true
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
  resources:
    {{- toYaml .Values.migrations.resources | nindent 4 }}
{{- end -}}

{{/*
br-sisbajud.bundleInitContainers — boot ordering for the dev bundle. The bundled
Postgres, Redpanda and OpenBao are created in the SAME install/sync as the app,
and their bootstrap Jobs are post-install hooks that start only after the
Deployment exists. Without these initContainers, the app boots:
  - before the schema exists (outbox queries fail),
  - before its streaming topics exist (the balance consumer on `.commands` would
    subscribe to a missing topic and fail silently),
  - before Transit is mounted (KEK provisioning fails the boot).
Each step is idempotent: `migrate up` is lock-protected, the topics entrypoint
lists then creates, and the Transit step only WAITS for the mount the
openbao-transit Job creates. Nothing renders against external infra: there the
migrations/topics Jobs are PreSync hooks and already run first.
*/}}
{{- define "br-sisbajud.bundleInitContainers" -}}
{{- $data := include "br-sisbajud.configmapData" . | fromYaml -}}
{{- $sc := dict "runAsUser" 65532 "runAsGroup" 65532 "runAsNonRoot" true "allowPrivilegeEscalation" false "readOnlyRootFilesystem" true "capabilities" (dict "drop" (list "ALL")) -}}
{{- $wait := .Values.brSisbajud.waitImage | default "busybox:1.36" -}}
{{- $secretName := ternary .Values.brSisbajud.existingSecretName (include "br-sisbajud.fullname" .) .Values.brSisbajud.useExistingSecret -}}
{{- if and .Values.migrations.enabled (eq (include "br-sisbajud.postgresInternal" .) "true") }}
{{- /* The migrations hook Secret is a post-install hook here (created after the
   Deployment, deleted once the hooks succeed), so this initContainer can never
   read it: a hook-sourced password would wedge every pod start. */ -}}
{{- if eq (include "br-sisbajud.migrationsConn" . | fromYaml).hookSecret "true" }}
{{- fail "\n\nERROR: br-sisbajud: migrations.postgres.password cannot be used with the bundled postgresql.\n  The app's migrations initContainer would read it from the migrations hook Secret, which only exists while the post-install hooks run.\n  unset: migrations.postgres.password (the bundled subchart Secret is used), or set migrations.useExistingSecret + migrations.existingSecretName\n" }}
{{- end }}
{{ include "br-sisbajud.migrationsContainer" . }}
{{- end }}
{{- $streamingOn := eq (include "br-sisbajud.isTrue" (index $data "STREAMING_ENABLED")) "true" }}
{{- if and .Values.topics.enabled $streamingOn (eq (include "br-sisbajud.redpandaEnabled" .) "true") }}
{{- $brokersEnv := include "br-sisbajud.effectiveEnvEntry" (dict "context" . "name" "STREAMING_BROKERS") | fromJson }}
{{- $tlsEnv := include "br-sisbajud.effectiveEnvEntry" (dict "context" . "name" "STREAMING_TLS_ENABLED" "default" "false") | fromJson }}
- name: wait-for-broker
  image: {{ $wait }}
  env:
    - {{ toYaml $brokersEnv | nindent 6 | trim }}
  command:
    - /bin/sh
    - -c
    - >
      {{- include "br-sisbajud.waitBrokerScript" . | nindent 6 }}
  securityContext:
    {{- toYaml $sc | nindent 4 }}
- name: topics
  image: "{{ .Values.topics.image.repository }}:{{ .Values.topics.image.tag | default .Chart.AppVersion }}"
  imagePullPolicy: {{ .Values.topics.image.pullPolicy | default "IfNotPresent" }}
  env:
    - name: HOME
      value: /tmp
    - name: TOPICS
      value: {{ join " " .Values.topics.list | quote }}
    - name: TOPIC_PARTITIONS
      value: {{ .Values.topics.partitions | default 1 | quote }}
    - name: TOPIC_REPLICAS
      value: {{ .Values.topics.replicationFactor | default 1 | quote }}
    - {{ toYaml $brokersEnv | nindent 6 | trim }}
    - {{ toYaml $tlsEnv | nindent 6 | trim }}
  securityContext:
    {{- toYaml $sc | nindent 4 }}
  volumeMounts:
    - name: bundle-tmp
      mountPath: /tmp
  resources:
    {{- toYaml .Values.topics.resources | nindent 4 }}
{{- end }}
{{- if eq (include "br-sisbajud.openbaoEnabled" .) "true" }}
- name: transit
  # Mounts Transit ITSELF (idempotent) instead of waiting for the post-install
  # openbao-transit Job: with `helm install/upgrade --wait` Helm runs
  # post-install hooks only after the Deployment is Ready, so a wait here would
  # deadlock until the timeout.
  image: "{{ .Values.openbaoTransit.image.repository }}:{{ .Values.openbaoTransit.image.tag }}"
  imagePullPolicy: {{ .Values.openbaoTransit.image.pullPolicy | default "IfNotPresent" }}
  env:
    - name: HOME
      value: /tmp
    - name: BAO_ADDR
      value: {{ index $data "VAULT_ADDR" | quote }}
    - name: TRANSIT_MOUNT
      value: {{ index $data "VAULT_TRANSIT_MOUNT_PATH" | default "transit" | quote }}
    - name: BAO_TOKEN
      valueFrom:
        secretKeyRef:
          name: {{ include "br-sisbajud.openbaoTokenSecret" . }}
          key: {{ include "br-sisbajud.openbaoTokenKey" . }}
  command:
    - /bin/sh
    - -ec
    - |
      {{- include "br-sisbajud.openbaoTransitScript" . | nindent 6 }}
  securityContext:
    {{- toYaml $sc | nindent 4 }}
  volumeMounts:
    - name: bundle-tmp
      mountPath: /tmp
  resources:
    {{- toYaml .Values.openbaoTransit.resources | nindent 4 }}
{{- end }}
{{- end -}}

{{/*
br-sisbajud.corsExtraEnv — legacy CORS overrides passed as brSisbajud.extraEnvVars.
An extraEnvVars CORS_* entry wins in the pod over the ConfigMap, but the CORS
middleware reads ACCESS_CONTROL_* (lib-commons withCORS.go), which the ConfigMap
derives from configmap/grouped values only. So each extraEnvVars CORS_* entry
(literal or valueFrom) is mirrored as an explicit ACCESS_CONTROL_* pod env
entry, unless ACCESS_CONTROL_* is set explicitly (configmap or extraEnvVars).
*/}}
{{- define "br-sisbajud.corsExtraEnv" -}}
{{- $cm := .Values.brSisbajud.configmap | default dict -}}
{{- $envByName := dict -}}
{{- range (include "br-sisbajud.podEnvList" . | fromYamlArray) -}}{{- if .name -}}{{- $_ := set $envByName .name . -}}{{- end -}}{{- end -}}
{{- $out := list -}}
{{- range $pair := list (list "CORS_ALLOWED_ORIGINS" "ACCESS_CONTROL_ALLOW_ORIGIN") (list "CORS_ALLOWED_METHODS" "ACCESS_CONTROL_ALLOW_METHODS") (list "CORS_ALLOWED_HEADERS" "ACCESS_CONTROL_ALLOW_HEADERS") (list "CORS_EXPOSE_HEADERS" "ACCESS_CONTROL_EXPOSE_HEADERS") (list "CORS_ALLOW_CREDENTIALS" "ACCESS_CONTROL_ALLOW_CREDENTIALS") -}}
{{- $src := index $envByName (index $pair 0) -}}
{{- if and $src (not (hasKey $envByName (index $pair 1))) (not (hasKey $cm (index $pair 1))) -}}
{{- $e := deepCopy $src -}}
{{- $_ := set $e "name" (index $pair 1) -}}
{{- $out = append $out $e -}}
{{- end -}}
{{- end -}}
{{- if $out }}{{ toYaml $out }}{{ end -}}
{{- end -}}

{{/*
br-sisbajud.openbaoTransitScript — idempotent Transit mount (bao CLI): wait for
OpenBao, enable the engine at $TRANSIT_MOUNT only when absent, verify. Shared by
the openbao-transit hook Job and the app's `transit` initContainer.
*/}}
{{- define "br-sisbajud.openbaoTransitScript" -}}
i=0
until bao status >/dev/null 2>&1; do
  i=$((i + 1)); [ "$i" -ge 60 ] && { echo "timeout waiting for $BAO_ADDR"; exit 1; }
  echo "waiting for $BAO_ADDR..."; sleep 5
done
if bao secrets list -format=json | grep -Fq -- "\"${TRANSIT_MOUNT}/\""; then
  echo "transit already mounted at ${TRANSIT_MOUNT}/"
else
  bao secrets enable -path="$TRANSIT_MOUNT" transit || bao secrets list -format=json | grep -Fq -- "\"${TRANSIT_MOUNT}/\""
  echo "transit enabled at ${TRANSIT_MOUNT}/"
fi
bao secrets list -format=json | grep -Fq -- "\"${TRANSIT_MOUNT}/\"" || { echo "transit mount missing"; exit 1; }
{{- end -}}
