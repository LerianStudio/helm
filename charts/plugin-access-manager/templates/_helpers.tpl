{{/*
Component names are derived from the RELEASE name, never from the chart name.
The bundled subcharts (auth-database, valkey) name their Services after the
release, so a chart-name-derived component name only lines up when the release
happens to be called `plugin-access-manager`; under any other release name the
cross-component DNS in the ConfigMaps points at Services that never exist and
every `wait-for-dependencies` init container blocks forever.
`{identity,auth,caradhras}.name` stay available as explicit overrides (a legacy
`auth.backend.name` override is honored too — see caradhras.value below).
*/}}

{{/*
Expand the name of the chart and plugin identity.
*/}}
{{- define "plugin-identity.name" -}}
{{- default (printf "%s-identity" .Release.Name) .Values.identity.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart and plugin auth.
*/}}
{{- define "plugin-auth.name" -}}
{{- default (printf "%s-auth" .Release.Name) .Values.auth.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
caradhras.value — "new key wins, old key is a fallback alias" coalesce used
throughout the caradhras component (promoted from the legacy nested
`auth.backend`). Reads the new `caradhras.<field>` value first; if empty/unset
falls back to the legacy `auth.backend.<field>` value (kept alive only for
installs that still set it in THEIR OWN values files — this chart's own
values.yaml no longer ships a real `auth.backend` block); finally falls back
to a hardcoded chart default.
Input (dict): newVal, oldVal, default.
*/}}
{{- define "caradhras.value" -}}
{{- if not (empty .newVal) -}}
{{- .newVal -}}
{{- else if not (empty .oldVal) -}}
{{- .oldVal -}}
{{- else -}}
{{- .default -}}
{{- end -}}
{{- end }}

{{/*
Expand the name of the chart and plugin caradhras. Same "new wins, old is a
fallback alias" precedence as caradhras.value, applied to the component name
so a legacy `auth.backend.name` override (release-name pin) still works.
*/}}
{{- define "plugin-caradhras.name" -}}
{{- $resolved := include "caradhras.value" (dict "newVal" .Values.caradhras.name "oldVal" (dig "backend" "name" "" .Values.auth) "default" "") -}}
{{- default (printf "%s-caradhras" .Release.Name) $resolved | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create chart name and version as used by the chart label for plugin identity.
*/}}
{{- define "plugin-identity.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin auth.
*/}}
{{- define "plugin-auth.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label for plugin caradhras.
*/}}
{{- define "plugin-caradhras.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name identity.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-identity.fullname" -}}
{{- include "plugin-identity.name" . }}
{{- end }}

{{/*
Create a default fully qualified app name auth.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-auth.fullname" -}}
{{- include "plugin-auth.name" . }}
{{- end }}

{{/*
Create a default fully qualified app name caradhras.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plugin-caradhras.fullname" -}}
{{- include "plugin-caradhras.name" . }}
{{- end }}

{{/*
Create app version.
*/}}
{{- define "plugin.version" -}}
{{- printf "%s" .Chart.AppVersion | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels. The `name` key callers pass in the dict is ignored: the label
value always resolves through the component name helper, so it follows the
release name and stays in step with the resource names it must select.
*/}}

{{/*
Identity Selector labels
*/}}
{{- define "plugin-identity.selectorLabels" -}}
app.kubernetes.io/name: {{ include "plugin-identity.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
Auth Selector labels
*/}}
{{- define "plugin-auth.selectorLabels" -}}
app.kubernetes.io/name: {{ include "plugin-auth.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
Caradhras Selector labels
*/}}
{{- define "plugin-caradhras.selectorLabels" -}}
app.kubernetes.io/name: {{ include "plugin-caradhras.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{/*
Identity Common labels
*/}}
{{- define "plugin-identity.labels" -}}
helm.sh/chart: {{ include "plugin-identity.chart" .context }}
{{ include "plugin-identity.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Auth Common labels
*/}}
{{- define "plugin-auth.labels" -}}
helm.sh/chart: {{ include "plugin-auth.chart" .context }}
{{ include "plugin-auth.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Caradhras Common labels
*/}}
{{- define "plugin-caradhras.labels" -}}
helm.sh/chart: {{ include "plugin-caradhras.chart" .context }}
{{ include "plugin-caradhras.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
Caradhras UI Selector labels — the UI is a sub-resource of the caradhras
component, so it gets its own selector (app.kubernetes.io/component: ui)
while still deriving its base name from plugin-caradhras.name.
*/}}
{{- define "plugin-caradhras-ui.name" -}}
{{- printf "%s-ui" (include "plugin-caradhras.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "plugin-caradhras-ui.fullname" -}}
{{- include "plugin-caradhras-ui.name" . }}
{{- end }}

{{- define "plugin-caradhras-ui.selectorLabels" -}}
app.kubernetes.io/name: {{ include "plugin-caradhras-ui.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end }}

{{- define "plugin-caradhras-ui.labels" -}}
helm.sh/chart: {{ include "plugin-caradhras.chart" .context }}
{{ include "plugin-caradhras-ui.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}

{{/*
caradhras.imageRepository / .imageTag / .imagePullPolicy / .servicePort /
.replicaCount — the five fields with explicit backward-compat fallback to the
legacy `auth.backend.*` path (see caradhras.value above). Server image values
are explicit in values.yaml and take precedence; empty fields fall back to
legacy overrides and then the defaults below.
*/}}
{{- define "caradhras.imageRepository" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.image.repository "oldVal" (dig "backend" "image" "repository" "" .Values.auth) "default" "ghcr.io/lerianstudio/caradhras") -}}
{{- end }}

{{- define "caradhras.imageTag" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.image.tag "oldVal" (dig "backend" "image" "tag" "" .Values.auth) "default" "1.3.2") -}}
{{- end }}

{{- define "caradhras.imagePullPolicy" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.image.pullPolicy "oldVal" (dig "backend" "image" "pullPolicy" "" .Values.auth) "default" "Always") -}}
{{- end }}

{{- define "caradhras.servicePort" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.service.port "oldVal" (dig "backend" "service" "port" "" .Values.auth) "default" 8000) -}}
{{- end }}

{{- define "caradhras.replicaCount" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.replicaCount "oldVal" (dig "backend" "replicaCount" "" .Values.auth) "default" 1) -}}
{{- end }}

{{/*
caradhras.migrationsImageRepository / .migrationsImageTag /
.migrationsImagePullPolicy — same "new wins, old is a fallback alias"
precedence as caradhras.imageRepository/etc above, but for the migrations
Job image. Without this, an install that only overrode the legacy
auth.backend.migrations.image.* path would silently start running the NEW
caradhras-migrations image against a database still on the OLD (Casdoor)
schema the moment it upgraded. Keep these fields empty in values.yaml so
legacy overrides remain visible, including to the repository guard below.
*/}}
{{- define "caradhras.migrationsImageRepository" -}}
{{- $repo := include "caradhras.value" (dict "newVal" .Values.caradhras.migrations.image.repository "oldVal" (dig "backend" "migrations" "image" "repository" "" .Values.auth) "default" "ghcr.io/lerianstudio/caradhras-migrations") -}}
{{- if contains "casdoor-migrations" $repo -}}
{{- fail (printf "\n\nplugin-access-manager: the migration image repository resolves to %q, which points at the OLD casdoor-migrations image.\nOn v9.x the migration Job injects POSTGRES_* env vars, but casdoor-migrations reads DB_* and will fail at runtime with:\n  Missing required environment variables: DB_USER, DB_PASS, DB_HOST, DB_NAME\nIt is NOT a downgrade of casdoor:3.1.0 — caradhras-migrations 1.2.x is a different product line.\nSet caradhras.migrations.image.repository to ghcr.io/lerianstudio/caradhras-migrations (or leave it empty to accept the default),\nand clear any legacy auth.backend.migrations.image.repository override.\nSee docs/UPGRADE-8.6-to-9.2.md (Known Gotchas)." $repo) -}}
{{- end -}}
{{- $repo -}}
{{- end }}

{{- define "caradhras.migrationsImageTag" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.migrations.image.tag "oldVal" (dig "backend" "migrations" "image" "tag" "" .Values.auth) "default" "1.3.2") -}}
{{- end }}

{{- define "caradhras.migrationsImagePullPolicy" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.migrations.image.pullPolicy "oldVal" (dig "backend" "migrations" "image" "pullPolicy" "" .Values.auth) "default" "Always") -}}
{{- end }}

{{/*
caradhras.readinessProbeTimeoutSeconds / .livenessProbeTimeoutSeconds — same
fallback precedence, for the one probe field every known install actually
overrides (Caradhras/Casdoor's /readyz and /api/health can take 5-13s to
respond; the chart's own hardcoded default of 1s is a k8s API default, not
a validated-safe value for this app). An install relying only on the legacy
auth.backend.readinessProbe/livenessProbe.timeoutSeconds override would
otherwise silently revert to the 1s default on upgrade and start flapping
into CrashLoopBackOff from probe failures alone.
*/}}
{{- define "caradhras.readinessProbeTimeoutSeconds" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.readinessProbe.timeoutSeconds "oldVal" (dig "backend" "readinessProbe" "timeoutSeconds" "" .Values.auth) "default" 1) -}}
{{- end }}

{{- define "caradhras.livenessProbeTimeoutSeconds" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.livenessProbe.timeoutSeconds "oldVal" (dig "backend" "livenessProbe" "timeoutSeconds" "" .Values.auth) "default" 1) -}}
{{- end }}

{{/*
Create the name of the identity service account to use
*/}}
{{- define "plugin-identity.serviceAccountName" -}}
{{- if .Values.identity.serviceAccount.create }}
{{- default (include "plugin-identity.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.identity.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the auth service account to use
*/}}
{{- define "plugin-auth.serviceAccountName" -}}
{{- if .Values.auth.serviceAccount.create }}
{{- default (include "plugin-auth.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.auth.serviceAccount.name }}
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
Service name of the bundled `auth-database` (aliased Bitnami postgresql) primary.
Derived through common.names.dependency.fullname so it follows the release name
and the Bitnami release-name collapse, and honors the subchart's own
nameOverride/fullnameOverride. Used as the DB_HOST default.
*/}}
{{- define "plugin-access-manager.authDatabaseHost" -}}
{{- include "common.names.dependency.fullname" (dict "chartName" "auth-database" "chartValues" (index .Values "auth-database") "context" .) -}}
{{- end }}

{{/*
Service name of the bundled `valkey` primary, derived the same way. Bitnami valkey
names the primary Service `<fullname>-primary` in both standalone and replication
architectures. Used as the REDIS_HOST default.
*/}}
{{- define "plugin-access-manager.valkeyHost" -}}
{{- printf "%s-primary" (include "common.names.dependency.fullname" (dict "chartName" "valkey" "chartValues" .Values.valkey "context" .)) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
plugin-auth.dbPasswordEnv — emit a single `- name: <envName> valueFrom: secretKeyRef: {name,key}`
entry for the auth database password, single-sourced. With the bundled `auth-database`
(aliased Bitnami postgresql) subchart, it reads the Secret this chart keeps across uninstall
(<release>-auth-database, key "password"); honors auth-database.auth.existingSecret; and
falls back to the app's plugin-auth Secret (key DB_PASSWORD) only for an external database.
Used by the auth, caradhras, and migrations/init-user workloads.
Input (dict): context (root .), envName (container env var name, e.g. DB_PASSWORD or DB_PASS).
See docs/helm-chart-standard.md "Single-Source Infra Secrets".
*/}}
{{- define "plugin-auth.dbPasswordEnv" -}}
{{- $ctx := .context -}}
{{- $db := default dict (index $ctx.Values "auth-database") -}}
{{- $opSecret := include "plugin-access-manager.operatorDbSecret" $ctx -}}
{{- $internal := and (ne (toString $db.enabled) "false") (not $db.external) -}}
- name: {{ .envName }}
  valueFrom:
    secretKeyRef:
    {{- if $opSecret }}
      name: {{ $opSecret }}
      key: password
    {{- else if $internal }}
      name: {{ include "common.names.dependency.fullname" (dict "chartName" "auth-database" "chartValues" (index $ctx.Values "auth-database") "context" $ctx) }}
      key: password
    {{- else }}
      {{- if not $ctx.Values.auth.useExistingSecret }}{{- $_ := required "\n\nERROR: auth-database is external or disabled.\n   The DB password is no longer single-sourced from the subchart Secret, so you must provide it.\n   Set auth.secrets.DB_PASSWORD, or point auth-database.auth.existingSecret at an external Secret.\n" $ctx.Values.auth.secrets.DB_PASSWORD -}}{{- end }}
      name: {{ if $ctx.Values.auth.useExistingSecret }}{{ required "\n\nERROR: auth.useExistingSecret is true but auth.existingSecretName is empty.\n   Set auth.existingSecretName to the name of the Secret holding DB_PASSWORD.\n" $ctx.Values.auth.existingSecretName }}{{ else }}{{ include "plugin-auth.fullname" $ctx }}{{ end }}
      key: DB_PASSWORD
    {{- end }}
{{- end }}

{{/*
plugin-access-manager.operatorDbSecret — the Secret an operator named in auth-database.auth.existingSecret,
"" when none. The chart default renders a name only inside the subchart (templates/auth-database/secrets.yaml).
*/}}
{{- define "plugin-access-manager.operatorDbSecret" -}}
{{- tpl (dig "auth" "existingSecret" "" (index .Values "auth-database" | default dict) | toString) . -}}
{{- end }}



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
plugin-caradhras.sessionRedisTls — value for the caradhras `redisTls` config key.

Resolved through the SAME lerian-common datastore mask the auth component uses
for REDIS_TLS (templates/auth/configmap.yaml), so a managed-cloud profile that
sets `redis.tls` once covers both components instead of two knobs that can skew.
Precedence: native `caradhras.configmap.redisTls` > `caradhras.datastores.redis.tls`
> `global.datastores.redis.tls` > cloud preset > "false".

Deliberately NOT applied to `redisEndpoint`: that value is a connection string
that may carry a password (beego's redis session provider takes
`host:port,poolsize,password,dbnum`), and the mask only knows host and port. A
derived endpoint would be silently wrong — and unauthenticated — against every
Redis that requires AUTH, so the endpoint stays explicit.
*/}}
{{- define "plugin-caradhras.sessionRedisTls" -}}
{{- $cm := .Values.caradhras.configmap | default dict -}}
{{- /* values.yaml ships redisTls: "" so the key is discoverable. The mask reads
   the native tier with hasKey, so an empty native value would win over the mask
   and pin every install to "". Drop it when unset. */ -}}
{{- if eq (toString ($cm.redisTls | default "")) "" -}}
{{- $cm = omit $cm "redisTls" -}}
{{- end -}}
{{- include "lerian-common.datastore.value" (dict
      "context" .
      "dedicated" (.Values.datastores | default dict)
      "configmap" $cm
      "type" "redis"
      "field" "tls"
      "nativeKey" "redisTls"
      "default" "false") -}}
{{- end }}

{{/*
plugin-caradhras.multiReplica — true when the operator has PINNED caradhras to
more than one pod: either replicas are fixed above 1 (autoscaling off), or the
HPA floor is above 1. Not merely "could scale": with autoscaling on, the
Deployment omits `replicas` entirely (templates/caradhras/deployment.yaml), so a
leftover `replicaCount` is inert and must not be read as intent.
*/}}
{{- define "plugin-caradhras.multiReplica" -}}
{{- $as := .Values.caradhras.autoscaling | default dict -}}
{{- $pinned := and (not $as.enabled) (gt (int (include "caradhras.replicaCount" .)) 1) -}}
{{- $floor := and $as.enabled (gt (int ($as.minReplicas | default 1)) 1) -}}
{{- if or $pinned $floor -}}true{{- end -}}
{{- end }}

{{/*
plugin-caradhras.sessionSecretName — name of the Secret holding the caradhras
`redisEndpoint` connection string. Same convention as auth/identity:
`caradhras.useExistingSecret` hands the Secret over to the operator,
`caradhras.existingSecretName` names it; otherwise the chart owns
<release>-caradhras (templates/caradhras/secrets.yaml).
*/}}
{{- define "plugin-caradhras.sessionSecretName" -}}
{{- if .Values.caradhras.useExistingSecret -}}
{{- required "\n\nERROR: caradhras.useExistingSecret is true but caradhras.existingSecretName is empty.\n   Set caradhras.existingSecretName to the name of the Secret holding the redisEndpoint key.\n" .Values.caradhras.existingSecretName -}}
{{- else -}}
{{- include "plugin-caradhras.fullname" . -}}
{{- end -}}
{{- end }}

{{/*
plugin-caradhras.sessionFromSecret — "true" when the session endpoint is
delivered by Secret: either inline in `caradhras.secrets.redisEndpoint` (the
chart writes the Secret) or in an operator-managed Secret
(`caradhras.useExistingSecret` + `existingSecretName`, key `redisEndpoint`).
*/}}
{{- define "plugin-caradhras.sessionFromSecret" -}}
{{- $secrets := .Values.caradhras.secrets | default dict -}}
{{- $inline := $secrets.redisEndpoint | default "" | toString -}}
{{- $existing := and .Values.caradhras.useExistingSecret (.Values.caradhras.existingSecretName | default "") -}}
{{- if or $inline $existing -}}true{{- end -}}
{{- end }}

{{/*
plugin-caradhras.sessionFromConfigMap — "true" when the session endpoint is
delivered in the clear by `caradhras.configmap.redisEndpoint`. That path is for
a Redis WITHOUT AUTH only; the password variant goes through the Secret.
*/}}
{{- define "plugin-caradhras.sessionFromConfigMap" -}}
{{- $ccm := .Values.caradhras.configmap | default dict -}}
{{- if $ccm.redisEndpoint | default "" | toString -}}true{{- end -}}
{{- end }}

{{/*
plugin-caradhras.sessionStoreConfigured — "true" when a shared session store is
configured by EITHER path. This is what the multi-replica guard and NOTES.txt
test: which channel carried the endpoint is irrelevant to whether sessions are
shared.
*/}}
{{- define "plugin-caradhras.sessionStoreConfigured" -}}
{{- if or (include "plugin-caradhras.sessionFromConfigMap" .) (include "plugin-caradhras.sessionFromSecret" .) -}}true{{- end -}}
{{- end }}

{{/*
plugin-caradhras.validateSessionStore — the render-time guards for the session
store. Included once, from templates/caradhras/configmap.yaml (always rendered).

1. The two delivery channels are mutually exclusive. Caradhras reads ONE env
   named `redisEndpoint`; the ConfigMap arrives by envFrom and the Secret by
   env, and a key defined twice is exactly the undefined behavior this chart
   already warns about for STREAMING_CLOUDEVENTS_SOURCE.
2. The ConfigMap channel must not carry a password. Beego's endpoint is
   positional — host:port,poolsize,password,dbnum — so a third field IS the
   password, and a ConfigMap is readable by any principal with get on it.
3. Caradhras pinned above one replica needs a session store, either channel.
*/}}
{{- define "plugin-caradhras.validateSessionStore" -}}
{{- if and .Values.caradhras.useExistingSecret (not (.Values.caradhras.existingSecretName | default "")) -}}
{{- fail "caradhras.useExistingSecret is true but caradhras.existingSecretName is empty. Without a name the chart creates no Secret and wires no endpoint, so caradhras would silently fall back to per-pod file sessions. Name the Secret holding the redisEndpoint key, or set caradhras.useExistingSecret=false." -}}
{{- end -}}
{{- $ccm := .Values.caradhras.configmap | default dict -}}
{{- $plain := $ccm.redisEndpoint | default "" | toString -}}
{{- $fromSecret := include "plugin-caradhras.sessionFromSecret" . -}}
{{- if and $plain $fromSecret -}}
{{- fail "caradhras.configmap.redisEndpoint and the caradhras session Secret both define redisEndpoint. Caradhras reads a single env named redisEndpoint, and defining it in both the ConfigMap (envFrom) and the Secret (env) is undefined behavior. Keep the password-free endpoint in caradhras.configmap.redisEndpoint, OR the endpoint with its password in caradhras.secrets.redisEndpoint (or an operator-managed Secret via caradhras.useExistingSecret) — not both." -}}
{{- end -}}
{{- $fields := splitList "," $plain -}}
{{- if and (ge (len $fields) 3) (index $fields 2) -}}
{{- fail "caradhras.configmap.redisEndpoint carries a password. Beego's endpoint is positional — host:port,poolsize,password,dbnum — so the third field is the Redis password, and this value is rendered into a ConfigMap, which gives no Secret-equivalent protection: anyone who can read the ConfigMap recovers the password. Move the whole connection string to caradhras.secrets.redisEndpoint (the chart writes it to the caradhras Secret and injects it with secretKeyRef), or point caradhras.useExistingSecret/caradhras.existingSecretName at a Secret you manage, and leave caradhras.configmap.redisEndpoint empty." -}}
{{- end -}}
{{- if include "plugin-caradhras.redisPasswordEnabled" . -}}
{{- $inline := ($ccm.redisEndpoint | default "" | toString) -}}
{{- $fromSecrets := ((.Values.caradhras.secrets | default dict).redisEndpoint | default "" | toString) -}}
{{- range $candidate := (list $inline $fromSecrets) -}}
{{- if and $candidate (contains "," $candidate) -}}
{{- fail (printf "caradhras.redisPassword.enabled is true and the session endpoint %q carries beego savePath fields. Caradhras compares the endpoint's own password field with redisPassword and refuses to boot when they differ — and an endpoint with fields but an EMPTY password field differs from any password, so this pair crashloops even though neither value looks wrong. With redisPassword the endpoint must be a bare host:port and nothing else: caradhras composes the savePath itself. Drop the extra fields, or set caradhras.redisPassword.enabled=false and keep the whole connection string in caradhras.secrets.redisEndpoint." $candidate) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if and (include "plugin-caradhras.multiReplica" .) (not (include "plugin-caradhras.sessionStoreConfigured" .)) -}}
{{- fail (printf "caradhras is pinned to more than one replica but has no shared session store. Beego keeps login sessions on the pod's own filesystem when redisEndpoint is unset, so a login that starts on one pod and finishes on another fails with \"unknown authentication type\". Set caradhras.configmap.redisEndpoint to the host:port of a Redis/Valkey both pods reach when it needs no AUTH; when it does need AUTH, set the full connection string in caradhras.secrets.redisEndpoint instead (it is delivered by Secret, never by ConfigMap). Or scale caradhras back to a single replica.%s" (ternary (printf " The Valkey bundled with this release is %s:6379." (include "plugin-access-manager.valkeyHost" .)) "" (ne (toString .Values.valkey.enabled) "false"))) -}}
{{- end -}}
{{- end }}

{{/*
plugin-caradhras.redisPasswordEnabled — "true" when the operator opted in to
injecting the Redis AUTH password as the separate `redisPassword` config key.
Off by default: a Redis without AUTH must not start needing anything.
*/}}
{{- define "plugin-caradhras.redisPasswordEnabled" -}}
{{- $rp := .Values.caradhras.redisPassword | default dict -}}
{{- if $rp.enabled -}}true{{- end -}}
{{- end }}

{{/*
plugin-caradhras.redisPasswordSecretName — Secret holding the Redis AUTH
password. `caradhras.redisPassword.secretName` names it explicitly; empty falls
back to the auth Secret, which is where the caradhras DB_PASSWORD already reads
from (plugin-auth.dbPasswordEnv) and which already carries a REDIS_PASSWORD key
(templates/auth/secrets.yaml). Honors auth.useExistingSecret so the fallback
still resolves when the auth Secret is operator-managed.
*/}}
{{- define "plugin-caradhras.redisPasswordSecretName" -}}
{{- $rp := .Values.caradhras.redisPassword | default dict -}}
{{- if $rp.secretName -}}
{{- $rp.secretName -}}
{{- else if .Values.auth.useExistingSecret -}}
{{- required "\n\nERROR: caradhras.redisPassword.enabled is true and auth.useExistingSecret is true, but auth.existingSecretName is empty.\n   The password defaults to the auth Secret, which the chart does not create in this mode.\n   Set auth.existingSecretName, or name the Secret directly in caradhras.redisPassword.secretName.\n" .Values.auth.existingSecretName -}}
{{- else -}}
{{- include "plugin-auth.fullname" . -}}
{{- end -}}
{{- end }}

{{/*
plugin-caradhras.redisPasswordEnv — the `redisPassword` container env, by
secretKeyRef, exactly as DB_PASSWORD is delivered on the same workload. Renders
nothing when the opt-in is off, so a Redis without AUTH keeps its current
rendering byte for byte.

Caradhras reads `redisPassword` as its own config key and gives it to BOTH redis
consumers from one resolution: the beego session store (composed into its
positional savePath) and the lib-commons rate-limit/idempotency client
(StaticPasswordAuth). So the endpoint stays a bare `host:port` and the credential
never has to be spliced into a connection string.
*/}}
{{- define "plugin-caradhras.redisPasswordEnv" -}}
{{- $rp := .Values.caradhras.redisPassword | default dict -}}
- name: redisPassword
  valueFrom:
    secretKeyRef:
      name: {{ include "plugin-caradhras.redisPasswordSecretName" . }}
      key: {{ $rp.secretKey | default "REDIS_PASSWORD" }}
{{- end }}

{{/*
plugin-access-manager.ssoCallbackPath — the console route the identity provider
sends the browser back to. This path is OUR contract, not the operator's: it is
the Next.js route src/app/(auth-routes)/signin/sso/callback in product-console.
Changing it here without changing the console breaks every SSO login.
*/}}
{{- define "plugin-access-manager.ssoCallbackPath" -}}
/signin/sso/callback
{{- end }}

{{/*
plugin-access-manager.ssoCallbackSource — which values field produced the
callback URL for ONE component, as a human-readable path. Used only so a
validation failure can name the field the operator actually wrote.

Arguments: context (the root $), component ("auth" or "identity").
*/}}
{{- define "plugin-access-manager.ssoCallbackSource" -}}
{{- $ctx := .context -}}
{{- $cm := (index $ctx.Values .component).configmap | default dict -}}
{{- $sso := ($ctx.Values.common | default dict).sso | default dict -}}
{{- if $cm.PLUGIN_AUTH_SSO_CALLBACK_URL -}}
{{- printf "%s.configmap.PLUGIN_AUTH_SSO_CALLBACK_URL" .component -}}
{{- else if $sso.callbackUrl -}}
common.sso.callbackUrl
{{- else if $sso.baseUrl -}}
common.sso.baseUrl
{{- end -}}
{{- end }}

{{/*
plugin-access-manager.ssoCallbackUrl — the browser-facing URL the identity
provider sends the user back to after an SSO login, resolved for ONE component.

Arguments: context (the root $), component ("auth" or "identity").

The host is the CLIENT's: they map the console on a domain the chart cannot know
or derive. The PATH is ours. So the normal channel is common.sso.baseUrl — the
operator gives scheme + host (plus a path prefix when the console is served
under one) and the chart appends the console route itself, which takes the most
likely and least diagnosable mistake (a mistyped path) off the table: Casdoor
rejects a redirect_uri that is not on its allow-list without saying why.

common.sso.callbackUrl is the escape hatch for a literal full URL — a custom
console route, or a proxy that rewrites the path — and a per-component
configmap.PLUGIN_AUTH_SSO_CALLBACK_URL wins over both, for migration.

Empty means the key is not emitted at all, so an install that does not use SSO
renders exactly as it did before this key existed.

The value is NOT derived from PLUGIN_AUTH_ADDRESS: that is the in-cluster
address the components use to reach each other, while this one has to be
reachable by the end user's browser.
*/}}
{{- define "plugin-access-manager.ssoCallbackUrl" -}}
{{- $ctx := .context -}}
{{- $cm := (index $ctx.Values .component).configmap | default dict -}}
{{- $sso := ($ctx.Values.common | default dict).sso | default dict -}}
{{- $literal := $cm.PLUGIN_AUTH_SSO_CALLBACK_URL | default $sso.callbackUrl | default "" | toString -}}
{{- $base := $sso.baseUrl | default "" | toString -}}
{{- if $literal -}}
{{- $literal -}}
{{- else if $base -}}
{{- printf "%s%s" (trimSuffix "/" $base) (include "plugin-access-manager.ssoCallbackPath" $ctx) -}}
{{- end -}}
{{- end }}

{{/*
plugin-access-manager.validateSsoCallbackUrl — render-time guards for the SSO
callback URL. Included once, from templates/auth/configmap.yaml (always
rendered).

1. baseUrl and callbackUrl are mutually exclusive. One says "compose the path",
   the other says "use this literally"; setting both is a contradiction with no
   correct answer, and silently preferring one hides a half-finished migration.
2. The base must not already end in the console route, which is what a full URL
   pasted into the base field looks like — composing it would double the path.
3. The resolved URL must be what the binary accepts: an absolute http(s) URL
   with a concrete path. identity refuses to configure SSO otherwise
   (isAbsoluteCallbackURL, components/identity/internal/services/sso_provider.go),
   and a path-less entry would widen Casdoor's allow-list to every path on the
   host and its subdomains instead of authorising one endpoint. Failing here
   names the values field; failing there is a provider that saves and never
   completes a login.
3b. The resolved URL must END in the console route. The host is the operator's
   and the chart never questions it; the path is this platform's contract, and
   a value that merely looks plausible — /sso/callback, /signin/callback — is
   rejected by Caradhras at the first login as an unlisted redirect_uri, with
   no indication of which part was wrong. baseUrl cannot trip this (the chart
   appends the route itself); a literal can. Lifted, deliberately and by name,
   by common.sso.allowCustomCallbackPath for a console on a custom route or
   behind a path-rewriting proxy.
4. auth and identity must resolve to the SAME value. identity writes the URL
   into the Caradhras provider's redirect allow-list; auth then sends it as the
   redirect_uri of the code relay, and Caradhras rejects any redirect_uri the
   allow-list does not carry. A skew therefore does not fail at deploy time — it
   fails at the first login, as a rejected redirect_uri that names neither
   component. The shared common.sso.* fields satisfy this for free; the guard
   exists for the per-component override.
5. The named key and <component>.extraEnvVars must not both carry it. Both land
   in the same ConfigMap `data` map, so the key would be emitted twice and which
   one survives is the YAML parser's business, not the chart's — the same
   undefined behavior this chart already refuses for the caradhras session
   endpoint. Scoped to this key: an install that only uses extraEnvVars (no
   named key) is untouched.
*/}}
{{- define "plugin-access-manager.validateSsoCallbackUrl" -}}
{{- $sso := (.Values.common | default dict).sso | default dict -}}
{{- $base := $sso.baseUrl | default "" | toString -}}
{{- $literal := $sso.callbackUrl | default "" | toString -}}
{{- $path := include "plugin-access-manager.ssoCallbackPath" . -}}
{{- $custom := eq (toString ($sso.allowCustomCallbackPath | default false)) "true" -}}
{{- if and $base $literal -}}
{{- fail (printf "common.sso.baseUrl (%q) and common.sso.callbackUrl (%q) are both set. They are alternatives, not layers: baseUrl asks the chart to append the console route %s, callbackUrl supplies the whole URL literally. Keep baseUrl — it is the normal case, and it makes the path impossible to mistype — and drop callbackUrl unless the console really answers SSO on some other route." $base $literal $path) -}}
{{- end -}}
{{- if and $base (hasSuffix $path (trimSuffix "/" $base)) -}}
{{- fail (printf "common.sso.baseUrl (%q) already ends in %s. That field takes only the part that is yours — scheme, host, and a path prefix if the console is served under one — because the chart appends the route itself; as written the callback would come out as %q. Drop the route from baseUrl, or use common.sso.callbackUrl if you really mean to pin the whole URL literally." $base $path (printf "%s%s" (trimSuffix "/" $base) $path)) -}}
{{- end -}}
{{- range $component := (list "auth" "identity") -}}
{{- $url := include "plugin-access-manager.ssoCallbackUrl" (dict "context" $ "component" $component) -}}
{{- if and $url (not (regexMatch `^https?://[^/?#]+/[^?#]+` $url)) -}}
{{- fail (printf "%s resolves the SSO callback URL to %q, which is not an absolute http(s) URL with a path. plugin-identity refuses to configure any SSO provider with such a value, so the provider would look saved while no login through it could ever complete; a host with no path is refused as well, because Casdoor would then treat the allow-list entry as a wildcard over every path on that host and its subdomains. Give scheme, host and — when the console sits under one — its path prefix, for example \"https://console.example.com\"." (include "plugin-access-manager.ssoCallbackSource" (dict "context" $ "component" $component)) $url) -}}
{{- end -}}
{{- if and $url (not $custom) (not (hasSuffix $path $url)) -}}
{{- fail (printf "%s resolves the SSO callback URL to %q, whose path is not %s.\n  expected path: %s\n  received:      %s\nThe HOST is yours — any domain you serve the console on is fine, and the chart never questions it. The PATH is this platform's contract: it is the console route the identity provider returns the browser to, and Caradhras rejects a redirect_uri that is not on its allow-list without saying which part was wrong, so a near-miss like /sso/callback deploys cleanly and breaks the first login. Set common.sso.baseUrl to just the scheme and host (plus a path prefix when the console sits under one) and let the chart append the route. If this deployment really answers SSO on another path — a custom console route, or a proxy that rewrites it — set common.sso.allowCustomCallbackPath=true to take that on deliberately." (include "plugin-access-manager.ssoCallbackSource" (dict "context" $ "component" $component)) $url $path $path $url) -}}
{{- end -}}
{{- end -}}
{{- $authUrl := include "plugin-access-manager.ssoCallbackUrl" (dict "context" . "component" "auth") -}}
{{- $idUrl := include "plugin-access-manager.ssoCallbackUrl" (dict "context" . "component" "identity") -}}
{{- if ne $authUrl $idUrl -}}
{{- fail (printf "PLUGIN_AUTH_SSO_CALLBACK_URL resolves to %q on auth and %q on identity. The two MUST be identical: identity registers this URL in the Caradhras provider's redirect allow-list, and auth sends it as the redirect_uri of the code relay, which Caradhras rejects when it is not on that list — so a skew deploys cleanly and then breaks every SSO login with a rejected redirect_uri. Set it ONCE in common.sso.baseUrl instead of per component." $authUrl $idUrl) -}}
{{- end -}}
{{- range $component := (list "auth" "identity") -}}
{{- $extra := (index $.Values $component).extraEnvVars | default dict -}}
{{- if and (include "plugin-access-manager.ssoCallbackUrl" (dict "context" $ "component" $component)) (hasKey $extra "PLUGIN_AUTH_SSO_CALLBACK_URL") -}}
{{- fail (printf "PLUGIN_AUTH_SSO_CALLBACK_URL is set as a named chart key AND in %s.extraEnvVars. Both render into the same ConfigMap data map, so the key would be emitted twice and the effective value is whatever the YAML parser keeps — undefined behavior. Keep it in common.sso.baseUrl (or common.sso.callbackUrl / %s.configmap.PLUGIN_AUTH_SSO_CALLBACK_URL) and remove it from %s.extraEnvVars." $component $component $component) -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
plugin-access-manager.validateMfaEnabled — same collision guard for MFA_ENABLED,
which the auth component alone reads.
*/}}
{{- define "plugin-access-manager.validateMfaEnabled" -}}
{{- $cm := .Values.auth.configmap | default dict -}}
{{- $extra := .Values.auth.extraEnvVars | default dict -}}
{{- if and (not (kindIs "invalid" $cm.MFA_ENABLED)) (ne ($cm.MFA_ENABLED | toString) "") (hasKey $extra "MFA_ENABLED") -}}
{{- fail "MFA_ENABLED is set both in auth.configmap and in auth.extraEnvVars. Both render into the same ConfigMap data map, so the key would be emitted twice and the effective value is whatever the YAML parser keeps — undefined behavior. Keep it in auth.configmap.MFA_ENABLED and remove it from auth.extraEnvVars." -}}
{{- end -}}
{{- end }}
