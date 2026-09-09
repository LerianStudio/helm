{{- /*
Shared partial that renders the migration-only Secret for one component.

WHY THIS EXISTS. The migration Job below is a Helm hook (pre-upgrade,
post-install), which ArgoCD maps to PreSync. Hook resources are applied BEFORE
the release's normal resources, but the component's application Secret is a
normal resource. This chart is installed as a NEW release in a NEW namespace,
so on the very first sync EVERY enabled component hits the same deadlock:

  1. PreSync starts <component>-migrations
  2. the application Secret does not exist yet, so the pod cannot start
     (CreateContainerConfigError: secret "<component>" not found)
  3. PreSync fails, the sync aborts, and the Secret is therefore never applied
  4. repeat forever

The fix is a minimal Secret carrying ONLY DATABASE_URL, applied as a hook one
weight EARLIER than the Job (-10 vs -5) so it is guaranteed to exist when the
Job runs. The full application Secret deliberately stays a NORMAL resource so
its sensitive runtime keys are never left behind as orphaned hooks on uninstall.
Same pattern as charts/streaming-hub and charts/br-ccs.

DELETE POLICY is before-hook-creation ONLY - deliberately NOT hook-succeeded.
Both Helm and ArgoCD treat a Secret as "succeeded" the moment it applies, so a
hook-succeeded policy would delete the DSN at the end of weight -10, BEFORE the
Job at weight -5 can read it, reintroducing the very failure this exists to fix.
The Secret lingers after the run, but it only duplicates a DSN the application
Secret already holds permanently, so it adds no new exposure.

NOT rendered when useExistingSecret=true: the operator owns that Secret and it
is a normal cluster object that already exists before any sync, so the Job reads
it directly.

Required inputs in the dict:
  context     -- root $ context
  component   -- yaml key (e.g. "spi", "dictHub", "cobHub")
  serviceName -- kebab-case service suffix (e.g. "spi", "dict-hub", "cob-hub")
*/}}
{{- define "plugin-br-pix-lerian.migrationSecret" -}}
{{- $ctx := .context -}}
{{- $component := .component -}}
{{- $serviceName := .serviceName -}}
{{- $componentValues := index $ctx.Values $component -}}
{{- $migrationsCfg := default (dict) $componentValues.migrations -}}
{{- /*
  Detect 'enabled' explicitly, for the same reason the Job partial does: Go
  templates treat boolean false as "empty", so `default true` would flip it.
*/}}
{{- $migrationsEnabled := true }}
{{- if hasKey $migrationsCfg "enabled" }}
  {{- $migrationsEnabled = $migrationsCfg.enabled }}
{{- end }}
{{- $dsn := toString (default "" (dig "secrets" "DATABASE_URL" "" $componentValues)) -}}
{{- if and $componentValues.enabled $migrationsEnabled (not $componentValues.useExistingSecret) (ne $dsn "") }}
{{- $componentFullname := include "plugin-br-pix-lerian.componentFullname" (dict "context" $ctx "component" $serviceName) }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ printf "%s-migrations" $componentFullname | trunc 63 | trimSuffix "-" }}
  namespace: {{ include "global.namespace" $ctx }}
  labels:
    {{- include "plugin-br-pix-lerian.labels" (dict "context" $ctx "component" (printf "%s-migrations" $serviceName)) | nindent 4 }}
  {{- /*
  before-hook-creation, NOT hook-succeeded: the Job at weight -5 still has to read
  this Secret after this hook completes.

  Lifecycle, so operators know what to expect. Argo CD removes this Secret along with
  the rest of the Application's resources on delete, because a hook is a child
  resource of the Application. Helm does not: it does not track hook resources as
  release resources, so `helm uninstall` leaves <component>-migrations behind, and so
  does clearing DATABASE_URL or disabling migrations on a release that already created
  it. Those cases need a manual `kubectl delete secret <component>-migrations`. The DSN
  it carries is the same one the application Secret holds, so this widens exposure in
  time, not in scope.
  */}}
  annotations:
    helm.sh/hook: pre-install,pre-upgrade
    helm.sh/hook-weight: "-10"
    helm.sh/hook-delete-policy: before-hook-creation
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/sync-wave: "-10"
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
type: Opaque
stringData:
  DATABASE_URL: {{ $dsn | quote }}
{{- end }}
{{- end }}

{{- /*
Shared partial that renders a Postgres migration Job for one component.

The per-component image (built from apps/<app>/components/<comp>/Dockerfile)
ships two relevant files at the image root:
  /migrate     -- statically-linked golang-migrate binary (added in
                  plugin-br-pix-lerian#143)
  /migrations  -- the app's SQL migration files

The pod's ENTRYPOINT is /app, but the Job overrides `command:` to
invoke /migrate against the database referenced by DATABASE_URL (read
from the migration-only Secret above, or from the operator-owned Secret
when useExistingSecret=true).

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
{{- define "plugin-br-pix-lerian.migrationJob" -}}
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
{{- /*
  Skip the Job when the chart-managed Secret carries an empty DATABASE_URL:
  /migrate -database "" is rejected by golang-migrate (no URL scheme), so the
  hook would fail the release before any pod starts. The Job is still rendered
  for useExistingSecret=true — the template cannot inspect an external Secret,
  and skipping there would silently drop migrations from a valid deployment.
*/}}
{{- $hasDatabaseURL := or $componentValues.useExistingSecret (ne (toString (default "" (dig "secrets" "DATABASE_URL" "" $componentValues))) "") -}}
{{- if and $componentValues.enabled $migrationsEnabled $hasDatabaseURL }}
{{- $componentFullname := include "plugin-br-pix-lerian.componentFullname" (dict "context" $ctx "component" $serviceName) }}
{{- /*
  Resolve which Secret carries DATABASE_URL for this Job.

  Default: the migration-only Secret rendered by the partial above, a hook at
  weight -10 that is guaranteed to exist when this Job runs at -5. Pointing at
  the application Secret instead is the deadlock documented there - it is a
  normal resource and does not exist yet on the sync that first installs this
  release.

  Fall back to componentSecretName when useExistingSecret=true: that Secret is
  operator-owned, already exists in the cluster before any sync, and carries the
  DSN itself, so no hook is needed. The $hasDatabaseURL guard above guarantees
  the other branch is reached only when a DSN was declared, which is exactly
  when the partial rendered the Secret - the two conditions are complements,
  never both false.
*/}}
{{- $migrationSecretName := include "plugin-br-pix-lerian.componentSecretName" (dict "context" $ctx "component" $serviceName "componentValues" $componentValues) }}
{{- if not $componentValues.useExistingSecret }}
{{- $migrationSecretName = printf "%s-migrations" $componentFullname | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- $componentImage := include "plugin-br-pix-lerian.componentImage" (dict "context" $ctx "componentValues" $componentValues) }}
{{- $componentPullPolicy := include "plugin-br-pix-lerian.componentPullPolicy" (dict "context" $ctx "componentValues" $componentValues) }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ $componentFullname }}-migrations
  namespace: {{ include "global.namespace" $ctx }}
  labels:
    {{- include "plugin-br-pix-lerian.labels" (dict "context" $ctx "component" (printf "%s-migrations" $serviceName)) | nindent 4 }}
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
        {{- include "plugin-br-pix-lerian.selectorLabels" (dict "context" $ctx "component" (printf "%s-migrations" $serviceName)) | nindent 8 }}
    spec:
      restartPolicy: OnFailure
      {{- $pullSecrets := include "plugin-br-pix-lerian.componentImagePullSecrets" (dict "context" $ctx "componentValues" $componentValues) | trim }}
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
                  name: {{ $migrationSecretName }}
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
