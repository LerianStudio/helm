{{/* Partition runner helpers. The midaz.partition* defines take (dict "context" . "product" "ledger"|"tracer"). */}}

{{/* Explicit settings win; auto enables inside the product's range; every image in it ships the runner. */}}
{{- define "midaz.partitionEnabled" -}}
{{- $p := index .context.Values .product | default dict -}}
{{- $enabled := dig "partition" "enabled" nil $p -}}
{{- if kindIs "invalid" $enabled -}}
{{- $tag := $p.image.tag | default .context.Chart.AppVersion | toString | trimPrefix "v" -}}
{{- /* Same anchored SemVer 2.0.0 guard as midaz.tagIsV4: semverCompare aborts the
       render on a malformed version instead of resolving to "off". */ -}}
{{- if regexMatch "^[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$" $tag -}}
{{- if semverCompare (index (dict "ledger" ">=4.5.0-beta.1" "tracer" ">=4.6.0-beta.11") .product) $tag -}}true{{- end -}}
{{- end -}}
{{- else if eq (toString $enabled) "true" -}}
true
{{- end -}}
{{- end -}}

{{/* Argo CD gates a sync on a resource's health only while a later wave, or a hook in the same wave, is
     still pending: both products' CronJobs go after every hook and Deployment so a Degraded one cannot stop them. */}}
{{- define "midaz.partitionLastWave" -}}
{{- $v := .context.Values -}}
{{- $w := list (dig "migrations" "deploymentSyncWave" "1" ($v.ledger | default dict) | int) (dig "migrations" "deploymentSyncWave" "1" ($v.tracer | default dict) | int) (dig "partition" "reconcile" "syncWave" "1" ($v.ledger | default dict) | int) -}}
{{- if and $v.tracer.enabled (include "midaz.partitionEnabled" (dict "context" .context "product" "tracer")) -}}
{{- $w = append $w (dig "partition" "reconcile" "syncWave" "1" $v.tracer | int) -}}
{{- end -}}
{{- $m := first $w -}}
{{- range $w }}{{ $m = max $m . }}{{ end -}}
{{- add 1 $m -}}
{{- end -}}

{{/* A CronJob name is capped at 52 characters (the controller appends an 11-character suffix to each Job it spawns). */}}
{{- define "midaz.partitionCronJobName" -}}
{{- $full := include (printf "midaz-%s.fullname" .product) .context -}}
{{- if or (eq .product "ledger") (le (len $full) 42) -}}
{{- printf "%s-partition" ($full | trunc 42 | trimSuffix "-") -}}
{{- else -}}
{{- /* Truncation drops the "-tracer" tail: a hash of the whole name keeps it apart from the ledger's. */ -}}
{{- printf "%s-%s-partition" ($full | trunc 33 | trimSuffix "-" | trimSuffix ".") (sha256sum $full | trunc 8) -}}
{{- end -}}
{{- end -}}

{{/* Include the image tag in the immutable reconcile Job name. */}}
{{- define "midaz.partitionReconcileJobName" -}}
{{- $p := index .context.Values .product -}}
{{- include "midaz.migrationsJobName" (dict "base" (include (printf "midaz-%s.fullname" .product) .context) "tag" ($p.image.tag | default .context.Chart.AppVersion | toString) "suffix" "partition-reconcile" "hashBase" (ne .product "ledger")) -}}
{{- end -}}

{{- define "midaz.partitionLicenseHookSecretName" -}}
{{- printf "%s-license-hook" (include (printf "midaz-%s.fullname" .product) .context) -}}
{{- end -}}

{{/* The daily pass retries index reconciliation and never prunes partitions. */}}
{{- define "midaz.partitionCronJob" -}}
{{- $ctx := .context -}}
{{- $partition := (index $ctx.Values .product).partition | default dict -}}
{{- $component := printf "%s-partition" (index $ctx.Values .product).name -}}
{{- $labels := dict "context" $ctx "component" $component "name" $component }}
{{- $labelsFn := ternary "midaz.labels" "midaz-tracer.labels" (eq .product "ledger") }}
{{- $podLabelsFn := ternary "midaz.podLabels" "midaz-tracer.podLabels" (eq .product "ledger") }}
apiVersion: batch/v1
kind: CronJob
metadata:
  name: {{ include "midaz.partitionCronJobName" . }}
  labels:
    {{- include $labelsFn $labels | nindent 4 }}
  annotations:
    argocd.argoproj.io/sync-wave: {{ include "midaz.partitionLastWave" . | quote }}
spec:
  schedule: {{ $partition.schedule | default "0 6 * * *" | quote }}
  {{- with $partition.timeZone }}
  timeZone: {{ . | quote }}
  {{- end }}
  concurrencyPolicy: Forbid
  startingDeadlineSeconds: 3600
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    metadata:
      labels:
        {{- include $labelsFn $labels | nindent 8 }}
    spec:
      backoffLimit: 0
      activeDeadlineSeconds: {{ $partition.activeDeadlineSeconds | default 1800 }}
      template:
        metadata:
          labels:
            {{- include $podLabelsFn $labels | nindent 12 }}
        spec:
          {{- include "midaz.partitionPodSpec" (dict "context" $ctx "product" .product "args" (list "ensure" "--reconcile-indexes")) | nindent 10 }}
{{- end -}}

{{/* Run after migrations; the daily pass retries unavailable databases or indexes. */}}
{{- define "midaz.partitionReconcileJob" -}}
{{- $ctx := .context -}}
{{- $p := index $ctx.Values .product -}}
{{- $reconcile := dig "partition" "reconcile" dict $p -}}
{{- $component := printf "%s-partition-reconcile" $p.name -}}
{{- $labels := dict "context" $ctx "component" $component "name" $component }}
{{- $labelsFn := ternary "midaz.labels" "midaz-tracer.labels" (eq .product "ledger") }}
{{- $podLabelsFn := ternary "midaz.podLabels" "midaz-tracer.podLabels" (eq .product "ledger") }}
{{- $hookSecret := and (eq .product "ledger") $p.secrets.LICENSE_KEY (not $p.useExistingSecret) }}
{{- if $hookSecret }}
{{- /* The hook runs before this release's Secret is written: carry LICENSE_KEY alone, ahead of the Job. */}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "midaz.partitionLicenseHookSecretName" . }}
  labels:
    {{- include $labelsFn $labels | nindent 4 }}
  annotations:
    argocd.argoproj.io/hook: Sync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
    argocd.argoproj.io/sync-wave: {{ sub (dig "syncWave" "1" $reconcile | int) 1 | toString | quote }}
    helm.sh/hook: pre-install,pre-upgrade
    helm.sh/hook-weight: "5"
    helm.sh/hook-delete-policy: before-hook-creation
type: Opaque
data:
  LICENSE_KEY: {{ $p.secrets.LICENSE_KEY | b64enc | quote }}
---
{{- end }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "midaz.partitionReconcileJobName" . }}
  labels:
    {{- include $labelsFn $labels | nindent 4 }}
  annotations:
    argocd.argoproj.io/hook: Sync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookSucceeded
    argocd.argoproj.io/sync-wave: {{ dig "syncWave" "1" $reconcile | toString | quote }}
    helm.sh/hook: {{ ternary "post-install,pre-upgrade" "post-install,post-upgrade" (eq .product "ledger") }}
    helm.sh/hook-weight: "10"
    helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded
spec:
  backoffLimit: 2
  activeDeadlineSeconds: {{ dig "activeDeadlineSeconds" 1800 $reconcile }}
  ttlSecondsAfterFinished: {{ dig "ttlSecondsAfterFinished" 259200 $reconcile }}
  template:
    metadata:
      labels:
        {{- include $podLabelsFn $labels | nindent 8 }}
    spec:
      {{- include "midaz.partitionPodSpec" (dict "context" $ctx "product" .product "args" (list "reconcile-indexes" "--tolerate-unavailable") "licenseHook" $hookSecret) | nindent 6 }}
{{- end -}}

{{/* Both partition workloads use the product's connections and migration credentials. */}}
{{- define "midaz.partitionPodSpec" -}}
{{- $ctx := .context -}}
{{- $p := index $ctx.Values .product -}}
{{- $partition := $p.partition | default dict -}}
{{- $secretName := ternary $p.existingSecretName (include (printf "midaz-%s.fullname" .product) $ctx) $p.useExistingSecret -}}
restartPolicy: Never
automountServiceAccountToken: false
{{- with $p.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
securityContext:
  {{- toYaml $p.podSecurityContext | nindent 2 }}
containers:
  - name: partition
    image: "{{ $p.image.repository }}:{{ $p.image.tag | default $ctx.Chart.AppVersion }}"
    imagePullPolicy: {{ $p.image.pullPolicy }}
    command: ["/partition"]
    args: {{ toJson .args }}
    securityContext:
      {{- toYaml $p.securityContext | nindent 6 }}
    envFrom:
      - secretRef:
          name: {{ $secretName }}
      - configMapRef:
          name: {{ include (printf "midaz-%s.fullname" .product) $ctx }}
    env:
      {{- with include "midaz.licenseFileEnv" $p }}
      {{- . | nindent 6 }}
      {{- end }}
      {{- if .licenseHook }}
      - name: LICENSE_KEY
        valueFrom:
          secretKeyRef:
            name: {{ include "midaz.partitionLicenseHookSecretName" . }}
            key: LICENSE_KEY
            optional: true
      {{- end }}
      {{- if eq .product "ledger" }}
      {{- range $name, $value := include "midaz-ledger.partitionInlineEnv" $ctx | fromYaml }}
      - name: {{ $name }}
        value: {{ $value | toString | quote }}
      {{- end }}
      {{- end }}
      {{- with include (printf "midaz-%s.partitionSecretEnv" .product) (dict "context" $ctx "secretName" $secretName) }}
      {{- . | nindent 6 }}
      {{- end }}
    {{- with include "midaz.licenseFileVolumeMount" $p }}
    volumeMounts:
      {{- . | nindent 6 }}
    {{- end }}
    resources:
      {{- toYaml $partition.resources | nindent 6 }}
{{- with include "midaz.licenseFileVolume" $p }}
volumes:
  {{- . | nindent 2 }}
{{- end }}
{{- with $p.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $p.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $p.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{/* Inline values override stale ConfigMaps during pre-upgrade hooks. */}}
{{- define "midaz-ledger.partitionInlineEnv" -}}
{{- $cm := .Values.ledger.configmap | default dict -}}
{{- $dsl := .Values.ledger.datastores -}}
{{- $dv := "lerian-common.datastore.value" -}}
{{- $mtEnabled := eq (include "midaz.isTrue" ($cm.MULTI_TENANT_ENABLED | default "false")) "true" }}
DB_TRANSACTION_HOST: {{ include $dv (dict "context" . "dedicated" $dsl "configmap" $cm "type" "postgresTransaction" "field" "host" "nativeKey" "DB_TRANSACTION_HOST" "default" "midaz-postgresql-primary") | quote }}
DB_TRANSACTION_PORT: {{ include $dv (dict "context" . "dedicated" $dsl "configmap" $cm "type" "postgresTransaction" "field" "port" "nativeKey" "DB_TRANSACTION_PORT" "default" "5432") | quote }}
DB_TRANSACTION_NAME: {{ include $dv (dict "context" . "dedicated" $dsl "configmap" $cm "type" "postgresTransaction" "field" "name" "nativeKey" "DB_TRANSACTION_NAME" "default" "transaction") | quote }}
DB_TRANSACTION_USER: {{ include $dv (dict "context" . "dedicated" $dsl "configmap" $cm "type" "postgresTransaction" "field" "user" "nativeKey" "DB_TRANSACTION_USER" "default" "midaz") | quote }}
DB_TRANSACTION_SSLMODE: {{ include $dv (dict "context" . "dedicated" $dsl "configmap" $cm "type" "postgres" "field" "ssl" "nativeKey" "DB_TRANSACTION_SSLMODE" "default" "disable") | quote }}
MULTI_TENANT_ENABLED: {{ $cm.MULTI_TENANT_ENABLED | default "false" | quote }}
{{ include "lerian-common.multiTenant.env" (dict "context" . "configmap" $cm "enabled" $mtEnabled "serviceName" "ledger" "emitRedis" true "requiredUrl" true "requiredRedisHost" true) }}
{{- end -}}

{{/* Password env: single-tenant runners use the migrations' PostgreSQL Secret; multi-tenant ones the licence store's Valkey. */}}
{{- define "midaz-ledger.partitionSecretEnv" -}}
{{- $ctx := .context -}}
{{- $values := $ctx.Values -}}
{{- $pg := $values.postgresql | default dict -}}
{{- $pgInternal := or (and (ne (toString $pg.enabled) "false") (not $pg.external)) (include "midaz.operatorSecret" (dict "context" $ctx "subchart" "postgresql")) -}}
{{- if ne (include "midaz.isTrue" ($values.ledger.configmap.MULTI_TENANT_ENABLED | default "false")) "true" }}
{{- if $pgInternal }}
{{- include "midaz.infraSecretRef" (dict "context" $ctx "subchart" "postgresql" "key" "password" "envName" "DB_TRANSACTION_PASSWORD") }}
{{- else if or $values.ledger.useExistingSecret $values.ledger.secrets.DB_TRANSACTION_PASSWORD -}}
- name: DB_TRANSACTION_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .secretName }}
      key: DB_TRANSACTION_PASSWORD
{{- end }}
{{- else }}
{{- $vk := $values.valkey | default dict }}
{{- $vkAuth := $vk.auth | default dict }}
{{- if or (and (ne (toString $vk.enabled) "false") (not $vk.external) $vkAuth.enabled) $vkAuth.existingSecret }}
{{- include "midaz.infraSecretRef" (dict "context" $ctx "subchart" "valkey" "key" "valkey-password" "envName" "REDIS_PASSWORD") }}
{{- end }}
{{- end }}
{{- end -}}

{{/* Password env: single-tenant runners read the bundled PostgreSQL Secret here (an external password arrives through envFrom); multi-tenant ones add nothing (the Tracer Secret carries the tenant settings). */}}
{{- define "midaz-tracer.partitionSecretEnv" -}}
{{- $ctx := .context -}}
{{- $tracer := $ctx.Values.tracer -}}
{{- $pg := $ctx.Values.postgresql | default dict -}}
{{- $pgInternal := or (and (ne (toString $pg.enabled) "false") (not $pg.external)) (include "midaz.operatorSecret" (dict "context" $ctx "subchart" "postgresql")) -}}
{{- if ne (include "midaz.isTrue" (($tracer.configmap | default dict).MULTI_TENANT_ENABLED | default "false")) "true" }}
{{- if $pgInternal }}
{{- include "midaz.infraSecretRef" (dict "context" $ctx "subchart" "postgresql" "key" "password" "envName" "DB_PASSWORD") }}
{{- end }}
{{- end }}
{{- end -}}
