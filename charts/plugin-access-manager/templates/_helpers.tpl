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
legacy `auth.backend.*` path (see caradhras.value above). values.yaml ships
these EMPTY on the `caradhras` block on purpose so the hardcoded defaults
here are the single source of truth.
*/}}
{{- define "caradhras.imageRepository" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.image.repository "oldVal" (dig "backend" "image" "repository" "" .Values.auth) "default" "ghcr.io/lerianstudio/caradhras") -}}
{{- end }}

{{- define "caradhras.imageTag" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.image.tag "oldVal" (dig "backend" "image" "tag" "" .Values.auth) "default" "1.2.0") -}}
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
schema the moment it upgraded — the exact kind of wrong-migration-chain
risk the 1.2.0-beta.x vs 3.2.0-beta.x GHCR-train warning above is about,
just triggered by a missing fallback instead of a tag typo.
*/}}
{{- define "caradhras.migrationsImageRepository" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.migrations.image.repository "oldVal" (dig "backend" "migrations" "image" "repository" "" .Values.auth) "default" "ghcr.io/lerianstudio/caradhras-migrations") -}}
{{- end }}

{{- define "caradhras.migrationsImageTag" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.migrations.image.tag "oldVal" (dig "backend" "migrations" "image" "tag" "" .Values.auth) "default" "1.2.0") -}}
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
(aliased Bitnami postgresql) subchart, it reads the generated Secret
(<release>-auth-database, key "password"); honors auth-database.auth.existingSecret; and
falls back to the app's plugin-auth Secret (key DB_PASSWORD) only for an external database.
Used by the auth, caradhras, and migrations/init-user workloads.
Input (dict): context (root .), envName (container env var name, e.g. DB_PASSWORD or DB_PASS).
See docs/helm-chart-standard.md "Single-Source Infra Secrets".
*/}}
{{- define "plugin-auth.dbPasswordEnv" -}}
{{- $ctx := .context -}}
{{- $db := default dict (index $ctx.Values "auth-database") -}}
{{- $dbAuth := default dict $db.auth -}}
{{- $internal := and (ne (toString $db.enabled) "false") (not $db.external) -}}
- name: {{ .envName }}
  valueFrom:
    secretKeyRef:
    {{- if $dbAuth.existingSecret }}
      name: {{ $dbAuth.existingSecret }}
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
