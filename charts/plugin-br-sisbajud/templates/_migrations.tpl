{{/*
==============================================================================
Migrations — the dedicated runner image (cmd/postgres-migrations, ENTRYPOINT
/postgres-migrations; reads POSTGRES_HOST/PORT/USER/PASSWORD/NAME/SSLMODE,
MIGRATIONS_TIMEOUT_SEC, POSTGRES_CONNECT_TIMEOUT_SEC; refuses multi-tenant).

  External PostgreSQL -> pre-install/pre-upgrade hook Job (ArgoCD PreSync),
                         weight -5, after its password Secret at -10, before
                         the Deployment (wave 0). Same ordering as
                         plugin-br-pix-lerian.
  Bundled postgresql  -> initContainer of the app pod (the subchart is a normal
                         resource, unreachable from a pre-install hook).

The connection is rendered INLINE (the app ConfigMap is a normal resource and
does not exist yet when a pre-install hook runs).
==============================================================================
*/}}

{{/*
Password env entry for the runner, or nothing when no source exists (the
runner container then fails the render: it requires POSTGRES_PASSWORD).
Input: dict "context" $ "hook" bool.
*/}}
{{- define "plugin-br-sisbajud.migrationsPasswordEnv" -}}
{{- $ctx := .context -}}
{{- $s := $ctx.Values.sisbajud -}}
{{- $extra := $s.extraEnvVars | default dict -}}
{{- $pgAuth := ($ctx.Values.postgresql | default dict).auth | default dict -}}
{{- if eq (include "plugin-br-sisbajud.postgresPasswordFromRef" $ctx) "true" -}}
{{- include "lerian-common.infraSecretRef" (dict "context" $ctx "subchart" "postgresql" "key" "password" "envName" "POSTGRES_PASSWORD") -}}
{{- else if $ctx.Values.migrations.existingSecret -}}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ $ctx.Values.migrations.existingSecret }}
      key: POSTGRES_PASSWORD
{{- else if hasKey $extra "POSTGRES_PASSWORD" -}}
- name: POSTGRES_PASSWORD
  value: {{ index $extra "POSTGRES_PASSWORD" | toString | quote }}
{{- else if $s.useExistingSecret -}}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "plugin-br-sisbajud.secretName" $ctx }}
      key: POSTGRES_PASSWORD
{{- else if ($s.secrets | default dict).POSTGRES_PASSWORD -}}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ ternary (include "plugin-br-sisbajud.migrationsFullname" $ctx) (include "plugin-br-sisbajud.fullname" $ctx) .hook }}
      key: POSTGRES_PASSWORD
{{- end -}}
{{- end -}}

{{/*
The runner container. Input: dict "context" $ "name" <container name> "hook" bool.
*/}}
{{- define "plugin-br-sisbajud.migrationsContainer" -}}
{{- $ctx := .context -}}
{{- $m := $ctx.Values.migrations -}}
{{- $pg := include "plugin-br-sisbajud.postgres" $ctx | fromYaml -}}
{{- $cm := $ctx.Values.sisbajud.configmap | default dict -}}
- name: {{ .name }}
  image: {{ include "plugin-br-sisbajud.migrationsImage" $ctx | quote }}
  imagePullPolicy: {{ $m.image.pullPolicy | default "IfNotPresent" }}
  env:
    - name: POSTGRES_HOST
      value: {{ $pg.host | quote }}
    - name: POSTGRES_PORT
      value: {{ $pg.port | quote }}
    - name: POSTGRES_USER
      value: {{ $pg.user | quote }}
    - name: POSTGRES_NAME
      value: {{ $pg.name | quote }}
    - name: POSTGRES_SSLMODE
      value: {{ $pg.ssl | quote }}
    - name: POSTGRES_CONNECT_TIMEOUT_SEC
      value: {{ include "plugin-br-sisbajud.val" (dict "cm" $cm "k" "POSTGRES_CONNECT_TIMEOUT_SEC" "p" $ctx.Values.sisbajud.postgres "f" "connectTimeoutSec" "d" "10") | quote }}
    - name: MIGRATIONS_TIMEOUT_SEC
      value: {{ $m.timeoutSec | default "300" | toString | quote }}
    - name: LOG_LEVEL
      value: {{ include "plugin-br-sisbajud.val" (dict "cm" $cm "k" "LOG_LEVEL" "p" $ctx.Values.sisbajud.app "f" "logLevel" "d" "info") | quote }}
    {{- $pwEnv := include "plugin-br-sisbajud.migrationsPasswordEnv" (dict "context" $ctx "hook" .hook) | trim }}
    {{- if not $pwEnv }}
    {{- fail "plugin-br-sisbajud: migrations need a Postgres password (the runner refuses to start without POSTGRES_PASSWORD, in every environment). Set sisbajud.secrets.POSTGRES_PASSWORD, migrations.existingSecret, sisbajud.useExistingSecret, or enable the bundled postgresql." }}
    {{- end }}
    {{- $pwEnv | nindent 4 }}
  securityContext:
    {{- toYaml $ctx.Values.sisbajud.securityContext | nindent 4 }}
  {{- with $m.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end -}}
