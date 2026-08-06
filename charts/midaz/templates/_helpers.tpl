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
Create a default fully qualified app name for CRM.
*/}}
{{- define "midaz-crm.fullname" -}}
{{- printf "%s-%s" (include "midaz.name" .) .Values.crm.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create CRM app version
*/}}
{{- define "crm.defaultTag" -}}
{{- default .Chart.AppVersion .Values.crm.image.tag }}
{{- end -}}

{{/*
Return valid CRM version label
*/}}
{{- define "crm.versionLabelValue" -}}
{{ regexReplaceAll "[^-A-Za-z0-9_.]" (include "crm.defaultTag" .) "-" | trunc 63 | trimAll "-" | trimAll "_" | trimAll "." | quote }}
{{- end -}}

{{/*
CRM Common labels
*/}}
{{- define "midaz-crm.labels" -}}
helm.sh/chart: {{ include "midaz.chart" .context }}
{{ include "midaz-crm.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "crm.versionLabelValue" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
CRM Selector labels
*/}}
{{- define "midaz-crm.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "midaz.name" .context }}-{{ .name }}
{{- end }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
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
{{- $tag := include "midaz-tracer.migrationsTag" . -}}
{{- printf "%s-migrations-%s" (include "midaz-tracer.fullname" .) (regexReplaceAll "[^a-z0-9.]+" (lower $tag) "-") | trunc 63 | trimSuffix "-" | trimSuffix "." -}}
{{- end -}}

{{- define "midaz-ledger.migrationsFullname" -}}
{{- $tag := include "midaz-ledger.migrationsTag" . -}}
{{- printf "%s-migrations-%s" (include "midaz-ledger.fullname" .) (regexReplaceAll "[^a-z0-9.]+" (lower $tag) "-") | trunc 63 | trimSuffix "-" | trimSuffix "." -}}
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
{{- if eq ($cm.API_KEY_ENABLED | default "false" | toString) "true" -}}
{{- if and (not $secrets.API_KEY) (not $tracer.useExistingSecret) -}}
{{- fail "tracer.secrets.API_KEY is required when API_KEY_ENABLED=true (ValidateAuthConfig rejects an empty key at boot); or set tracer.useExistingSecret" -}}
{{- end -}}
{{- if eq ($cm.CORS_ALLOWED_ORIGINS | default "*" | toString) "*" -}}
{{- fail "tracer.configmap.CORS_ALLOWED_ORIGINS=\"*\" is rejected at boot when API_KEY_ENABLED=true: any site could drive authenticated calls once the key leaks. Set a concrete origin allow-list" -}}
{{- end -}}
{{- end -}}
{{- if eq ($cm.MULTI_TENANT_ENABLED | default "false" | toString) "true" -}}
{{- if ne ($cm.PLUGIN_AUTH_ENABLED | default "false" | toString) "true" -}}
{{- fail "tracer.configmap.PLUGIN_AUTH_ENABLED must be \"true\" when MULTI_TENANT_ENABLED=true: API-key-only auth cannot verify tenant JWT signatures, so any caller could forge a tenantId" -}}
{{- end -}}
{{- if or (eq ($cm.API_KEY_ENABLED_ONLY_VALIDATION | default "false" | toString) "true") (eq (dig "API_KEY_ENABLED_ONLY_VALIDATION" "false" $extra | toString) "true") -}}
{{- fail "API_KEY_ENABLED_ONLY_VALIDATION=true is incompatible with MULTI_TENANT_ENABLED=true: it lets /v1/validations bypass plugin auth, reopening cross-tenant forgery" -}}
{{- end -}}
{{- if and (not $secrets.MULTI_TENANT_SERVICE_API_KEY) (not $tracer.useExistingSecret) -}}
{{- fail "tracer.secrets.MULTI_TENANT_SERVICE_API_KEY is required when MULTI_TENANT_ENABLED=true" -}}
{{- end -}}
{{- end -}}
{{- end -}}
