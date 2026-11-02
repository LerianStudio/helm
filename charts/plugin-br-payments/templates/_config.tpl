{{/*
================================================================================
Configuration resolution (lerian-common masks).

The ConfigMap and Secret render a FIXED, template-owned key set (see
templates/configmap.yaml and templates/secrets.yaml); app.configmap.<KEY> and
app.secrets.<KEY> override one key each, and values.schema.json rejects any key
this chart does not render. Connection endpoints resolve through the
lerian-common masks, with the native key always winning:

  app.configmap.<KEY>  >  datastores.<type>.<field>  >  global.datastores.<type>.<field>
                       >  global.cloud preset  >  chart default

A null in an overlay means "unset": it falls through to the next tier (or, for
a key with no chart default, drops the key) instead of rendering an empty value,
which the application would read as set-but-empty rather than as its default.
================================================================================
*/}}

{{/*
plugin-br-payments.cfg — resolve ONE app.configmap key: the overlay value when it
is set and not null, else the chart default. Input dict: root, key, default.
*/}}
{{- define "plugin-br-payments.cfg" -}}
{{- $cm := .root.Values.app.configmap | default dict -}}
{{- if and (hasKey $cm .key) (not (kindIs "invalid" (index $cm .key))) -}}
{{- index $cm .key -}}
{{- else -}}
{{- .default -}}
{{- end -}}
{{- end -}}

{{/*
plugin-br-payments.bundledPostgresHost — the in-cluster Service of the bundled
postgresql subchart ("" when it is not enabled). Derived from the subchart's own
name helper, so it honours release-name collapse, nameOverride and
fullnameOverride; "-primary" in replication architecture.
*/}}
{{- define "plugin-br-payments.bundledPostgresHost" -}}
{{- if eq (include "postgresql.enabled" .) "true" -}}
{{- $pgFullname := include "common.names.dependency.fullname" (dict "chartName" "postgresql" "chartValues" (index .Values "postgresql") "context" .) -}}
{{- if eq (default "standalone" .Values.postgresql.architecture) "replication" -}}
{{- printf "%s-primary.%s.svc.cluster.local" $pgFullname (include "global.namespace" .) -}}
{{- else -}}
{{- printf "%s.%s.svc.cluster.local" $pgFullname (include "global.namespace" .) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
plugin-br-payments.pg — resolve ONE Postgres field through the datastore mask.
The ConfigMap, the Deployment's wait-for-postgres init container, the bootstrap
Job and the control-plane migrations Job all call this, so the app and its
PreSync Jobs can never target different databases.
Input dict: root, field (host|port|user|name|ssl|replicaHost), nativeKey, default.
An empty host falls back to the bundled subchart's Service.
*/}}
{{- define "plugin-br-payments.pg" -}}
{{- $cm := dict -}}
{{- range $k, $v := (.root.Values.app.configmap | default dict) -}}
{{- if not (kindIs "invalid" $v) }}{{- $_ := set $cm $k $v -}}{{- end -}}
{{- end -}}
{{- $v := include "lerian-common.datastore.value" (dict "context" .root "configmap" $cm "type" "postgres" "field" .field "nativeKey" .nativeKey "default" .default) -}}
{{- if and (eq .field "host") (not $v) -}}
{{- $v = include "plugin-br-payments.bundledPostgresHost" .root -}}
{{- end -}}
{{- $v -}}
{{- end -}}

{{/* Shorthands for the five primary connection fields (defaults = the chart's
     historical values, so an install that sets nothing renders as before). */}}
{{- define "plugin-br-payments.pgHost" -}}{{ include "plugin-br-payments.pg" (dict "root" . "field" "host" "nativeKey" "POSTGRES_HOST" "default" "") }}{{- end -}}
{{- define "plugin-br-payments.pgPort" -}}{{ include "plugin-br-payments.pg" (dict "root" . "field" "port" "nativeKey" "POSTGRES_PORT" "default" "5432") }}{{- end -}}
{{- define "plugin-br-payments.pgUser" -}}{{ include "plugin-br-payments.pg" (dict "root" . "field" "user" "nativeKey" "POSTGRES_USER" "default" "plugin_br_payments") }}{{- end -}}
{{- define "plugin-br-payments.pgDb" -}}{{ include "plugin-br-payments.pg" (dict "root" . "field" "name" "nativeKey" "POSTGRES_DB" "default" "plugin_br_payments") }}{{- end -}}
{{- define "plugin-br-payments.pgSsl" -}}{{ include "plugin-br-payments.pg" (dict "root" . "field" "ssl" "nativeKey" "POSTGRES_SSLMODE" "default" "require") }}{{- end -}}

{{/*
plugin-br-payments.multiTenantEnabled — "true" when multi-tenancy is on, from
app.configmap.MULTI_TENANT_ENABLED or, env-wide, global.multiTenant.enabled.
The single gate every guard and Job reads.
*/}}
{{- define "plugin-br-payments.multiTenantEnabled" -}}
{{- $cm := dict -}}
{{- range $k, $v := (.Values.app.configmap | default dict) -}}
{{- if not (kindIs "invalid" $v) }}{{- $_ := set $cm $k $v -}}{{- end -}}
{{- end -}}
{{- $raw := include "lerian-common.globalValue" (dict "context" . "configmap" $cm "block" "multiTenant" "field" "enabled" "nativeKey" "MULTI_TENANT_ENABLED" "default" "") -}}
{{- if eq (toString $raw | trim | lower) "true" }}true{{ end -}}
{{- end -}}
