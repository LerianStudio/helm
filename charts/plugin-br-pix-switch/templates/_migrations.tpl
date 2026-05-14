{{- /*
Shared partial that renders a Postgres migration Job for one component.

The per-component image (built from apps/<app>/components/<comp>/Dockerfile)
ships two relevant files at the image root:
  /migrate     -- statically-linked golang-migrate binary (added in
                  plugin-br-pix-switch#143)
  /migrations  -- the app's SQL migration files

The pod's ENTRYPOINT is /app, but the Job overrides `command:` to
invoke /migrate against the database referenced by DATABASE_URL (the
same Secret the app reads).

The Job is a Helm hook so it runs before the regular pod rollout and is
not part of the regular release lifecycle:

  helm.sh/hook: pre-upgrade,post-install
  helm.sh/hook-weight: -5     (run before bootstrap-postgres? no — that
                              uses default 0; -5 ensures migrations run
                              before pods come up on upgrade)
  helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded

Required inputs in the dict:
  context     -- root $ context
  component   -- yaml key (e.g. "spi", "dictHub", "cobHub")
  serviceName -- kebab-case service suffix (e.g. "spi", "dict-hub", "cob-hub")
*/}}
{{- define "plugin-br-pix-switch.migrationJob" -}}
{{- $ctx := .context -}}
{{- $component := .component -}}
{{- $serviceName := .serviceName -}}
{{- $componentValues := index $ctx.Values $component -}}
{{- $migrationsCfg := default (dict) $componentValues.migrations -}}
{{- /*
  Detect 'enabled' explicitly. We can't use `default true .enabled` —
  Go templates treat boolean false as "empty", so `default` would
  override it to true. Check hasKey instead.
*/}}
{{- $migrationsEnabled := true }}
{{- if hasKey $migrationsCfg "enabled" }}
  {{- $migrationsEnabled = $migrationsCfg.enabled }}
{{- end }}
{{- if and $componentValues.enabled $migrationsEnabled }}
{{- $componentFullname := include "plugin-br-pix-switch.componentFullname" (dict "context" $ctx "component" $serviceName) }}
{{- $componentImage := include "plugin-br-pix-switch.componentImage" (dict "context" $ctx "componentValues" $componentValues) }}
{{- $componentPullPolicy := include "plugin-br-pix-switch.componentPullPolicy" (dict "context" $ctx "componentValues" $componentValues) }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ $componentFullname }}-migrations
  namespace: {{ include "global.namespace" $ctx }}
  labels:
    {{- include "plugin-br-pix-switch.labels" (dict "context" $ctx "component" (printf "%s-migrations" $serviceName)) | nindent 4 }}
  annotations:
    helm.sh/hook: pre-upgrade,post-install
    helm.sh/hook-weight: "-5"
    helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded
spec:
  ttlSecondsAfterFinished: {{ default 300 $migrationsCfg.ttlSecondsAfterFinished }}
  backoffLimit: {{ default 3 $migrationsCfg.backoffLimit }}
  template:
    metadata:
      labels:
        {{- include "plugin-br-pix-switch.selectorLabels" (dict "context" $ctx "component" (printf "%s-migrations" $serviceName)) | nindent 8 }}
    spec:
      restartPolicy: OnFailure
      {{- $pullSecrets := include "plugin-br-pix-switch.componentImagePullSecrets" (dict "context" $ctx "componentValues" $componentValues) | trim }}
      {{- if and $pullSecrets (ne $pullSecrets "[]") }}
      imagePullSecrets:
        {{- $pullSecrets | nindent 8 }}
      {{- end }}
      securityContext:
        runAsGroup: 1000
        runAsUser: 1000
        runAsNonRoot: true
      containers:
        - name: migrate
          image: {{ $componentImage | quote }}
          imagePullPolicy: {{ $componentPullPolicy }}
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
            readOnlyRootFilesystem: true
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: {{ $componentFullname }}
                  key: DATABASE_URL
          command:
            - /migrate
          args:
            - -path
            - {{ default "/migrations" $migrationsCfg.migrationsPath | quote }}
            - -database
            - $(DATABASE_URL)
            - up
{{- end }}
{{- end }}
