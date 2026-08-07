{{/*
Expand the name of the chart.
*/}}
{{- define "midaz.name" -}}
{{- default (default "midaz" .Values.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "midaz-grafana.fullname" -}}
{{- printf "%s-%s" (include "midaz.name" .) .Values.grafana.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "midaz.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "midaz.labels" -}}
helm.sh/chart: {{ include "midaz.chart" .context }}
{{ include "midaz.selectorLabels" (dict "context" .context "component" .component "name" .name) }}
app.kubernetes.io/version: {{ include "ledger.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "midaz.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "midaz.name" .context }}-{{ .name }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}


{{/*
Create a default fully qualified app name for ledger.
*/}}
{{- define "midaz-ledger.fullname" -}}
{{- printf "%s-%s" (include "midaz.name" .) .Values.ledger.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create ledger app version
*/}}
{{- define "ledger.defaultTag" -}}
{{- default .Chart.AppVersion .Values.ledger.image.tag }}
{{- end -}}

{{/*
Return valid ledger version label
*/}}
{{- define "ledger.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "ledger.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Create the name of the service account to use for ledger
*/}}
{{- define "midaz-ledger.serviceAccountName" -}}
{{- if .Values.ledger.serviceAccount.create }}
{{- default (include "midaz-ledger.fullname" .) .Values.ledger.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.ledger.serviceAccount.name }}
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
infraSecretRef — emit a `- name: <envName> valueFrom: secretKeyRef: {name,key}` env entry
pointing at a Bitnami subchart's generated Secret (or the operator's existingSecret override).
Inputs (dict): context (root .), subchart, key, envName.
See docs/helm-chart-standard.md "Single-Source Infra Secrets".
*/}}
{{- define "midaz.infraSecretRef" -}}
{{- $ctx := .context -}}
{{- $sub := .subchart -}}
{{- $subValues := default dict (index $ctx.Values $sub) -}}
{{- $auth := default dict (index $subValues "auth") -}}
{{- $secretName := "" -}}
{{- if $auth.existingSecret -}}
{{- $secretName = $auth.existingSecret -}}
{{- else -}}
{{- $secretName = include "common.names.dependency.fullname" (dict "chartName" $sub "chartValues" $subValues "context" $ctx) -}}
{{- end -}}
- name: {{ .envName }}
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: {{ .key }}
{{- end }}

{{/*
midaz.mongodbAuthRequired — fail when the bundled Bitnami mongodb subchart is internal
(enabled and not external) but mongodb.auth.enabled is disabled and no mongodb.auth.existingSecret
is provided. Bitnami's mongodb emits NO `<release>-mongodb` Secret when auth.enabled=false (its
secrets.yaml is wrapped in `if .Values.auth.enabled`), yet ledger and crm still reference
`mongodb-root-password` via secretKeyRef — a dangling ref that yields CreateContainerConfigError.
Fail loud at render time so the operator fixes the configuration.
*/}}
{{- define "midaz.mongodbAuthRequired" -}}
{{- $mongo := .Values.mongodb | default dict -}}
{{- $mongoAuth := $mongo.auth | default dict -}}
{{- if and (ne (toString $mongo.enabled) "false") (not $mongo.external) (not $mongoAuth.enabled) (not $mongoAuth.existingSecret) -}}
{{- fail "\n\nERROR: mongodb.auth.enabled is REQUIRED when the bundled mongodb subchart is internal.\n   ledger and crm read MONGO_*_PASSWORD from the mongodb Secret (single source), but Bitnami\n   mongodb creates no Secret when auth.enabled=false, leaving a dangling secretKeyRef.\n   Choose one: set mongodb.auth.enabled=true, or provide mongodb.auth.existingSecret, or set mongodb.external=true.\n" -}}
{{- end -}}
{{- end }}

{{/*
Create a default fully qualified app name for Tracer.
*/}}
{{- define "midaz-tracer.fullname" -}}
{{- if .Values.tracer.fullnameOverride }}
{{- .Values.tracer.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" (include "midaz.name" .) (default .Values.tracer.name .Values.tracer.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create Tracer app version
*/}}
{{- define "tracer.defaultTag" -}}
{{- default .Chart.AppVersion .Values.tracer.image.tag }}
{{- end -}}

{{/*
Return valid Tracer version label
*/}}
{{- define "tracer.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "tracer.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
Tracer Common labels
*/}}
{{- define "midaz-tracer.labels" -}}
helm.sh/chart: {{ include "midaz.chart" .context }}
{{ include "midaz-tracer.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "tracer.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Tracer Selector labels
*/}}
{{- define "midaz-tracer.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "midaz.name" .context }}-{{ .name }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
Enable internal dependencies
*/}}
{{- define "mongodb.enabled" -}}
{{- if not .Values.mongodb.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}
{{- define "rabbitmq.enabled" -}}
{{- if not .Values.rabbitmq.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}
{{- define "valkey.enabled" -}}
{{- if not .Values.valkey.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}
{{- define "postgresql.enabled" -}}
{{- if not .Values.postgresql.external -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
Vendored from Bitnami common (charts/common/templates/_names.tpl) so infra
Secret/Service names render even when all bundled subcharts are disabled
(external-infra path). Self-contained: no other common.* helpers required.
*/}}
{{- define "common.names.dependency.fullname" -}}
{{- if .chartValues.fullnameOverride -}}
{{- .chartValues.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .chartName .chartValues.nameOverride -}}
{{- if contains $name .context.Release.Name -}}
{{- .context.Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .context.Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
midaz.tagIsV4 — reports "true" when the passed image tag is a semver >= 4.0.0
(pre-releases included), "" otherwise. Non-semver tags ("latest", digests,
branch builds) resolve to "" so they never trip a version-gated requirement.

Midaz v4 changed two boot contracts that 3.x does not have: the unified ledger
binary serves CRM in-process (so it initializes the CRM cipher at startup) and
neither ledger nor tracer migrates its schema anymore. Both are gated on this
helper so 3.x releases keep rendering exactly as before.
*/}}
{{- define "midaz.tagIsV4" -}}
{{- $tag := . | toString | trimPrefix "v" -}}
{{- /* Anchored, complete SemVer 2.0.0 match: semverCompare hard-fails rendering
       on a malformed version, so a prefix-only test would let "4.0.0.1" through
       and abort the render instead of resolving to "not v4". */ -}}
{{- if regexMatch "^[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$" $tag -}}
{{- if semverCompare ">=4.0.0-0" $tag -}}true{{- end -}}
{{- end -}}
{{- end -}}

{{/*
midaz.ledgerMigrationsEnabled — resolves the tri-state ledger.migrations.enabled.
Unset (null) means "auto": on for 4.x ledger tags, off for 3.x, which still runs
its migrations in-process. An explicit true/false always wins, so operators who
apply the schema out-of-band (managed-Postgres S3 pipeline) can pin it off.
*/}}
{{- define "midaz.ledgerMigrationsEnabled" -}}
{{- $enabled := dig "migrations" "enabled" nil .Values.ledger -}}
{{- if kindIs "invalid" $enabled -}}
{{- include "midaz.tagIsV4" (.Values.ledger.image.tag | default .Chart.AppVersion) -}}
{{- else if eq (toString $enabled) "true" -}}
true
{{- end -}}
{{- end -}}

{{/*
midaz-tracer.migrationsFullname — one Job name per migration image tag. A Job
spec is immutable, so a stable name would silently skip the run on upgrade; the
tag suffix makes every version bump create a new Job. Re-running is safe:
golang-migrate tracks progress in the schema_migrations table.
*/}}
{{- define "midaz-tracer.migrationsFullname" -}}
{{- include "midaz.migrationsJobName" (dict "base" (include "midaz-tracer.fullname" .) "tag" (include "midaz-tracer.migrationsTag" .)) -}}
{{- end -}}

{{- define "midaz-ledger.migrationsFullname" -}}
{{- include "midaz.migrationsJobName" (dict "base" (include "midaz-ledger.fullname" .) "tag" (include "midaz-ledger.migrationsTag" .)) -}}
{{- end -}}

{{/*
midaz.migrationsJobName — "<base>-migrations-<tag>" while it fits in the 63
character limit. Beyond that, truncating the whole string would cut the tag off
and make two releases collide on one immutable Job name, so the long form
truncates the base and ends in a hash of the tag, which stays discriminating.
*/}}
{{- define "midaz.migrationsJobName" -}}
{{- $tag := regexReplaceAll "[^a-z0-9.]+" (lower .tag) "-" -}}
{{- $name := printf "%s-migrations-%s" .base $tag -}}
{{- if le (len $name) 63 -}}
{{- $name | trimSuffix "-" | trimSuffix "." -}}
{{- else -}}
{{- printf "%s-migrations-%s" (trunc 42 .base | trimSuffix "-" | trimSuffix ".") (sha256sum $tag | trunc 8) -}}
{{- end -}}
{{- end -}}

{{/*
Migration-runner image tags default to the matching application image tag so the
schema and the binary reading it can never drift when only one is bumped.
*/}}
{{- define "midaz-tracer.migrationsTag" -}}
{{- dig "migrations" "image" "tag" "" .Values.tracer | default .Values.tracer.image.tag | default .Chart.AppVersion -}}
{{- end -}}

{{- define "midaz-ledger.migrationsTag" -}}
{{- dig "migrations" "image" "tag" "" .Values.ledger | default .Values.ledger.image.tag | default .Chart.AppVersion -}}
{{- end -}}

{{/*
midaz-tracer.validate — render-time mirror of the tracer bootstrap validators
(components/tracer/internal/bootstrap). Every rule below is a configuration the
v4 process rejects at boot, so failing the render turns a CrashLoopBackOff into
a helm error the operator can read.
*/}}
{{- define "midaz-tracer.validate" -}}
{{- $tracer := .Values.tracer -}}
{{- $cm := $tracer.configmap | default dict -}}
{{- $secrets := $tracer.secrets | default dict -}}
{{- $extra := $tracer.extraEnvVars | default dict -}}
{{- if and $tracer.useExistingSecret (not $tracer.existingSecretName) -}}
{{- fail "tracer.useExistingSecret=true requires tracer.existingSecretName (an empty secretRef.name is rejected by the API server)" -}}
{{- end -}}
{{- if include "midaz.isTrue" ($cm.API_KEY_ENABLED | default "false") -}}
{{- if and (not $secrets.API_KEY) (not $tracer.useExistingSecret) -}}
{{- fail "tracer.secrets.API_KEY is required when API_KEY_ENABLED=true (ValidateAuthConfig rejects an empty key at boot); or set tracer.useExistingSecret" -}}
{{- end -}}
{{- if eq ($cm.CORS_ALLOWED_ORIGINS | default "*" | toString) "*" -}}
{{- fail "tracer.configmap.CORS_ALLOWED_ORIGINS=\"*\" is rejected at boot when API_KEY_ENABLED=true: any site could drive authenticated calls once the key leaks. Set a concrete origin allow-list" -}}
{{- end -}}
{{- end -}}
{{- if include "midaz.isTrue" ($cm.MULTI_TENANT_ENABLED | default "false") -}}
{{- if not (include "midaz.isTrue" ($cm.PLUGIN_AUTH_ENABLED | default "false")) -}}
{{- fail "tracer.configmap.PLUGIN_AUTH_ENABLED must be \"true\" when MULTI_TENANT_ENABLED=true: API-key-only auth cannot verify tenant JWT signatures, so any caller could forge a tenantId" -}}
{{- end -}}
{{- if or (include "midaz.isTrue" ($cm.API_KEY_ENABLED_ONLY_VALIDATION | default "false")) (include "midaz.isTrue" (dig "API_KEY_ENABLED_ONLY_VALIDATION" "false" $extra)) -}}
{{- fail "API_KEY_ENABLED_ONLY_VALIDATION=true is incompatible with MULTI_TENANT_ENABLED=true: it lets /v1/validations bypass plugin auth, reopening cross-tenant forgery" -}}
{{- end -}}
{{- if and (not $secrets.MULTI_TENANT_SERVICE_API_KEY) (not $tracer.useExistingSecret) -}}
{{- fail "tracer.secrets.MULTI_TENANT_SERVICE_API_KEY is required when MULTI_TENANT_ENABLED=true" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
midaz.isTrue — "true" when the value is one of the tokens strconv.ParseBool
accepts as true, "" otherwise. Midaz loads boolean env vars through ParseBool,
so `TRUE`, `True`, `1`, `t` and `T` all enable a feature at runtime; comparing
against the literal string "true" would let those render past a validation the
process then fails, and would reject a valid `PLUGIN_AUTH_ENABLED=TRUE`.
Matching is exact (no trimming), like ParseBool: " true" is false at runtime.
*/}}
{{- define "midaz.isTrue" -}}
{{- if has (. | toString) (list "1" "t" "T" "TRUE" "true" "True") -}}true{{- end -}}
{{- end -}}

{{/*
midaz.postgresqlPrimaryHost — in-cluster hostname of the bundled PostgreSQL
primary for THIS release, so a release named something other than `midaz` still
resolves its database. Bitnami names the Service `<fullname>-primary` in the
replication topology and `<fullname>` when standalone. Returns "" when
PostgreSQL is external, where only the operator knows the address.
*/}}
{{- define "midaz.postgresqlPrimaryHost" -}}
{{- $pg := .Values.postgresql | default dict -}}
{{- if and (ne (toString $pg.enabled) "false") (not $pg.external) -}}
{{- $fullname := include "common.names.dependency.fullname" (dict "chartName" "postgresql" "chartValues" $pg "context" .) -}}
{{- if eq ($pg.architecture | default "standalone") "replication" -}}
{{- printf "%s-primary" $fullname -}}
{{- else -}}
{{- $fullname -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
midaz-tracer.dbHost — explicit tracer.configmap.DB_HOST, else the bundled
PostgreSQL primary of this release. Fails when neither is available, which is
the external-PostgreSQL case where a wrong guess would silently point the
Deployment and the migration Job at a host that does not exist.
*/}}
{{/*
midaz-tracer.grpcPort — the numeric gRPC container/Service port, kept in sync with the app's
listen address. When tracer.configmap.TRACER_GRPC_PORT is set (e.g. ":5000") the port is its
numeric tail; otherwise tracer.service.grpcPort (default 4021). Prevents the container/Service
from exposing 4021 while the app listens on a custom TRACER_GRPC_PORT.
*/}}
{{- define "midaz-tracer.grpcPort" -}}
{{- $listen := (.Values.tracer.configmap | default dict).TRACER_GRPC_PORT -}}
{{- if $listen -}}
{{- regexFind "[0-9]+$" (toString $listen) -}}
{{- else -}}
{{- .Values.tracer.service.grpcPort | default 4021 -}}
{{- end -}}
{{- end }}

{{- define "midaz-tracer.dbHost" -}}
{{- $explicit := (.Values.tracer.configmap | default dict).DB_HOST -}}
{{- if $explicit -}}
{{- $explicit -}}
{{- else -}}
{{- $bundled := include "midaz.postgresqlPrimaryHost" . -}}
{{- if $bundled -}}
{{- $bundled -}}
{{- else -}}
{{- fail "tracer.configmap.DB_HOST is required when PostgreSQL is external (postgresql.enabled=false / postgresql.external=true)" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
midaz.validateLcryptoKey — LCRYPTO_ENCRYPT_SECRET_KEY is hex-decoded and handed
to aes.NewCipher (lib-commons Crypto.InitializeCipher), so it must be hex
encoding 16, 24 or 32 bytes. A non-hex value fails at boot with
"encoding/hex: invalid byte" and a wrong length with "crypto/aes: invalid key
size", both of which this catches at render time instead. Only applies to keys
supplied through values; an existing Secret is opaque to the chart.
*/}}
{{- define "midaz.validateLcryptoKey" -}}
{{- $key := .key | toString -}}
{{- if $key -}}
{{- if not (regexMatch "^[0-9a-fA-F]+$" $key) -}}
{{- fail (printf "%s must be a hex-encoded AES key (0-9a-f only): it is hex-decoded before aes.NewCipher, so a non-hex value fails at boot" .name) -}}
{{- end -}}
{{- if not (has (len $key) (list 32 48 64)) -}}
{{- fail (printf "%s must be 32, 48 or 64 hex characters (AES-128/192/256); got %d" .name (len $key)) -}}
{{- end -}}
{{- end -}}
{{- end -}}
