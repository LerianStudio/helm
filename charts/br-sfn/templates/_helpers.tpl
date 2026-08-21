{{/*
Expand the name of the chart.
*/}}
{{- define "br-sfn.name" -}}
{{- default "br-sfn" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Truncated at 63 chars because some Kubernetes name fields are limited by the DNS spec.
*/}}
{{- define "br-sfn.fullname" -}}
{{- default (include "br-sfn.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "br-sfn.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the namespace of the release. Overridable for multi-namespace layouts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Name of the service account to use (shared by every component).
*/}}
{{- define "br-sfn.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "br-sfn.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
componentFullname — <chart fullname>-<component>, e.g. br-sfn-spb.
Input dict: root, name.
*/}}
{{- define "br-sfn.componentFullname" -}}
{{- printf "%s-%s" (include "br-sfn.fullname" .root | trunc (int (sub 62 (len .name))) | trimSuffix "-") .name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Selector labels for one component (stable across image bumps).
Input dict: root, name.
*/}}
{{- define "br-sfn.componentSelectorLabels" -}}
app.kubernetes.io/name: {{ include "br-sfn.componentFullname" . }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
{{- end }}

{{/*
Common labels for one component. Input dict: root, name.
*/}}
{{- define "br-sfn.componentLabels" -}}
helm.sh/chart: {{ include "br-sfn.chart" .root }}
{{ include "br-sfn.componentSelectorLabels" . }}
app.kubernetes.io/version: {{ .root.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
app.kubernetes.io/part-of: br-sfn
app.kubernetes.io/component: {{ .name }}
{{- end }}

{{/*
componentConfigData — the component's effective ConfigMap map: the optional
`shared` map (spi-family) merged under the component's own configmap (component
keys win). Input dict: comp, shared (optional). Emits YAML map or "".
*/}}
{{- define "br-sfn.componentConfigData" -}}
{{- $shared := .shared | default dict -}}
{{- $own := .comp.configmap | default dict -}}
{{- $merged := mergeOverwrite (deepCopy $shared) $own -}}
{{- if $merged -}}
{{- toYaml $merged -}}
{{- end -}}
{{- end }}

{{/*
componentSecretData — same merge for the Secret map. Input dict: comp, shared.
*/}}
{{- define "br-sfn.componentSecretData" -}}
{{- $shared := .shared | default dict -}}
{{- $own := .comp.secrets | default dict -}}
{{- $merged := mergeOverwrite (deepCopy $shared) $own -}}
{{- if $merged -}}
{{- toYaml $merged -}}
{{- end -}}
{{- end }}

{{/*
componentSecretName — the Secret the component's envFrom points at.
Fails loud when useExistingSecret is set without a name (per-component flag
first, then the spi-family shared flag). Input dict: root, name, comp,
sharedCfg (optional map carrying useExistingSecret/existingSecretName).
*/}}
{{- define "br-sfn.componentSecretName" -}}
{{- $shared := .sharedCfg | default dict -}}
{{- if .comp.useExistingSecret -}}
{{- required (printf "br-sfn: %s.existingSecretName must be set when %s.useExistingSecret is true" .name .name) .comp.existingSecretName -}}
{{- else if $shared.useExistingSecret -}}
{{- required "br-sfn: spi.existingSecretName must be set when spi.useExistingSecret is true" $shared.existingSecretName -}}
{{- else -}}
{{- include "br-sfn.componentFullname" (dict "root" .root "name" .name) -}}
{{- end -}}
{{- end }}

{{/*
componentConfigmap — ConfigMap for one component (only when it has data).
Input dict: root, name, comp, shared (optional).
*/}}
{{- define "br-sfn.componentConfigmap" -}}
{{- $data := include "br-sfn.componentConfigData" (dict "comp" .comp "shared" .shared) -}}
{{- if $data }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "br-sfn.componentFullname" (dict "root" .root "name" .name) }}
  namespace: {{ include "global.namespace" .root }}
  labels:
    {{- include "br-sfn.componentLabels" (dict "root" .root "name" .name) | nindent 4 }}
data:
  {{- $data | nindent 2 }}
{{- end }}
{{- end }}

{{/*
componentSecrets — Secret for one component (only when it has data and the
operator is not bringing their own). Input dict: root, name, comp, shared,
sharedCfg.
*/}}
{{- define "br-sfn.componentSecrets" -}}
{{- $sharedCfg := .sharedCfg | default dict -}}
{{- if not (or .comp.useExistingSecret $sharedCfg.useExistingSecret) -}}
{{- $data := include "br-sfn.componentSecretData" (dict "comp" .comp "shared" .shared) -}}
{{- if $data }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "br-sfn.componentFullname" (dict "root" .root "name" .name) }}
  namespace: {{ include "global.namespace" .root }}
  labels:
    {{- include "br-sfn.componentLabels" (dict "root" .root "name" .name) | nindent 4 }}
type: Opaque
stringData:
  {{- $data | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
componentImage — "<repository>:<tag|appVersion>".
Input dict: root, comp.
*/}}
{{- define "br-sfn.componentImage" -}}
{{- printf "%s:%s" .comp.image.repository (.comp.image.tag | default .root.Chart.AppVersion) -}}
{{- end }}

{{/*
componentPullSecrets — component override, else chart default, else global.
Input dict: root, comp. Emits a YAML list or "".
*/}}
{{- define "br-sfn.componentPullSecrets" -}}
{{- $secrets := .comp.imagePullSecrets | default (.root.Values.imagePullSecrets | default .root.Values.global.imagePullSecrets) -}}
{{- if $secrets -}}
{{- toYaml $secrets -}}
{{- end -}}
{{- end }}

{{/*
componentDeployment — the generic Deployment for one HTTP component.
Input dict:
  root         — the chart root context
  name         — component resource name segment ("spb", "spi-api", ...)
  comp         — the component values block
  shared       — optional shared configmap/secrets source (spi family)
  sharedCfg    — optional shared useExistingSecret carrier (spi family)
  defaultPort  — the container port matching the image's EXPOSE
  livenessPath — default liveness path ("/health"; cockpit passes "/")
  readyPath    — default readiness path ("/readyz"; cockpit passes "/")
*/}}
{{- define "br-sfn.componentDeployment" -}}
{{- $id := dict "root" .root "name" .name -}}
{{- $fullname := include "br-sfn.componentFullname" $id -}}
{{- /* configDataOverride (optional): a PRE-RENDERED ConfigMap body (used by the
       productized spi family, whose ConfigMap is template-rendered with defaults +
       dependency masks, not the bespoke shared/own merge). When absent, fall back
       to the legacy merge so the still-bespoke components render unchanged. */ -}}
{{- $configData := .configDataOverride | default (include "br-sfn.componentConfigData" (dict "comp" .comp "shared" .shared)) -}}
{{- $secretData := include "br-sfn.componentSecretData" (dict "comp" .comp "shared" .shared) -}}
{{- $sharedCfg := .sharedCfg | default dict -}}
{{- $hasSecret := or $secretData .comp.useExistingSecret $sharedCfg.useExistingSecret -}}
{{- $secCtx := .comp.securityContext | default .root.Values.securityContext -}}
{{- $liveness := .comp.livenessProbe | default dict -}}
{{- $readiness := .comp.readinessProbe | default dict -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $fullname }}
  namespace: {{ include "global.namespace" .root }}
  labels:
    {{- include "br-sfn.componentLabels" $id | nindent 4 }}
spec:
  revisionHistoryLimit: {{ .comp.revisionHistoryLimit | default 10 }}
  {{- if not .comp.autoscaling.enabled }}
  replicas: {{ .comp.replicaCount | default 1 }}
  {{- end }}
  strategy:
    type: {{ .comp.deploymentUpdate.type | default "RollingUpdate" }}
    {{- if eq (.comp.deploymentUpdate.type | default "RollingUpdate") "RollingUpdate" }}
    rollingUpdate:
      maxSurge: {{ .comp.deploymentUpdate.maxSurge | default 1 }}
      maxUnavailable: {{ .comp.deploymentUpdate.maxUnavailable | default 0 }}
    {{- end }}
  selector:
    matchLabels:
      {{- include "br-sfn.componentSelectorLabels" $id | nindent 6 }}
  template:
    metadata:
      annotations:
        {{- with .comp.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- if $configData }}
        checksum/config: {{ $configData | sha256sum }}
        {{- end }}
        {{- if $secretData }}
        checksum/secret: {{ $secretData | sha256sum }}
        {{- end }}
      labels:
        {{- include "br-sfn.componentSelectorLabels" $id | nindent 8 }}
    spec:
      {{- with (include "br-sfn.componentPullSecrets" (dict "root" .root "comp" .comp)) }}
      imagePullSecrets:
        {{- . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "br-sfn.serviceAccountName" .root }}
      automountServiceAccountToken: false
      securityContext:
        {{- toYaml .root.Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .name }}
          securityContext:
            {{- toYaml $secCtx | nindent 12 }}
          image: {{ include "br-sfn.componentImage" (dict "root" .root "comp" .comp) | quote }}
          imagePullPolicy: {{ .comp.image.pullPolicy | default "IfNotPresent" }}
          {{- if or $configData $hasSecret }}
          # Secret LAST: envFrom resolves duplicate keys to the last source, so
          # a key in both maps takes the credentialed value, never the ConfigMap.
          envFrom:
            {{- if $configData }}
            - configMapRef:
                name: {{ $fullname }}
            {{- end }}
            {{- if $hasSecret }}
            - secretRef:
                name: {{ include "br-sfn.componentSecretName" (dict "root" .root "name" .name "comp" .comp "sharedCfg" $sharedCfg) }}
            {{- end }}
          {{- end }}
          {{- with .comp.extraEnvVars }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          ports:
            - name: http
              containerPort: {{ .comp.service.port | default .defaultPort }}
              protocol: TCP
          livenessProbe:
            httpGet:
              path: {{ $liveness.path | default .livenessPath }}
              port: http
            initialDelaySeconds: {{ $liveness.initialDelaySeconds | default 15 }}
            periodSeconds: {{ $liveness.periodSeconds | default 20 }}
            timeoutSeconds: {{ $liveness.timeoutSeconds | default 5 }}
            successThreshold: {{ $liveness.successThreshold | default 1 }}
            failureThreshold: {{ $liveness.failureThreshold | default 3 }}
          readinessProbe:
            httpGet:
              path: {{ $readiness.path | default .readyPath }}
              port: http
            initialDelaySeconds: {{ $readiness.initialDelaySeconds | default 5 }}
            periodSeconds: {{ $readiness.periodSeconds | default 10 }}
            timeoutSeconds: {{ $readiness.timeoutSeconds | default 5 }}
            successThreshold: {{ $readiness.successThreshold | default 1 }}
            failureThreshold: {{ $readiness.failureThreshold | default 3 }}
          {{- with .comp.extraVolumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          resources:
            {{- toYaml .comp.resources | nindent 12 }}
      {{- with .comp.extraVolumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .comp.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .comp.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .comp.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}

{{/*
componentService — ClusterIP Service. Input dict: root, name, comp, defaultPort.
*/}}
{{- define "br-sfn.componentService" -}}
{{- $id := dict "root" .root "name" .name -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "br-sfn.componentFullname" $id }}
  namespace: {{ include "global.namespace" .root }}
  labels:
    {{- include "br-sfn.componentLabels" $id | nindent 4 }}
spec:
  type: {{ .comp.service.type | default "ClusterIP" }}
  ports:
    - port: {{ .comp.service.port | default .defaultPort }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "br-sfn.componentSelectorLabels" $id | nindent 4 }}
{{- end }}

{{/*
componentIngress — optional Ingress. Input dict: root, name, comp, defaultPort.
*/}}
{{- define "br-sfn.componentIngress" -}}
{{- if .comp.ingress.enabled -}}
{{- $id := dict "root" .root "name" .name -}}
{{- $fullname := include "br-sfn.componentFullname" $id -}}
{{- $port := .comp.service.port | default .defaultPort -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $fullname }}
  namespace: {{ include "global.namespace" .root }}
  labels:
    {{- include "br-sfn.componentLabels" $id | nindent 4 }}
  {{- with .comp.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- with .comp.ingress.className }}
  ingressClassName: {{ . }}
  {{- end }}
  {{- with .comp.ingress.tls }}
  tls:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  rules:
    {{- range .comp.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType | default "Prefix" }}
            backend:
              service:
                name: {{ $fullname }}
                port:
                  number: {{ $port }}
          {{- end }}
    {{- end }}
{{- end }}
{{- end }}

{{/*
componentHpa — optional HorizontalPodAutoscaler. Input dict: root, name, comp.
*/}}
{{- define "br-sfn.componentHpa" -}}
{{- if .comp.autoscaling.enabled -}}
{{- $id := dict "root" .root "name" .name -}}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "br-sfn.componentFullname" $id }}
  namespace: {{ include "global.namespace" .root }}
  labels:
    {{- include "br-sfn.componentLabels" $id | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "br-sfn.componentFullname" $id }}
  minReplicas: {{ .comp.autoscaling.minReplicas }}
  maxReplicas: {{ .comp.autoscaling.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .comp.autoscaling.targetCPUUtilizationPercentage }}
{{- end }}
{{- end }}

{{/*
componentPdb — optional PodDisruptionBudget. Input dict: root, name, comp.
*/}}
{{- define "br-sfn.componentPdb" -}}
{{- if .comp.pdb.enabled -}}
{{- $id := dict "root" .root "name" .name -}}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "br-sfn.componentFullname" $id }}
  namespace: {{ include "global.namespace" .root }}
  labels:
    {{- include "br-sfn.componentLabels" $id | nindent 4 }}
spec:
  minAvailable: {{ .comp.pdb.minAvailable | default 1 }}
  selector:
    matchLabels:
      {{- include "br-sfn.componentSelectorLabels" $id | nindent 6 }}
{{- end }}
{{- end }}

{{/*
migrationPgValue — resolve one migrations.postgres.* value with fallback to the
component's effective configmap key. Input dict: mig (migrations block), key
(postgres sub-key), cfg (merged configmap map), cfgKey (configmap key name),
fallback (last-resort literal).
*/}}
{{- define "br-sfn.migrationPgValue" -}}
{{- $fromMig := index (.mig.postgres | default dict) .key -}}
{{- if $fromMig -}}
{{- $fromMig -}}
{{- else if hasKey .cfg .cfgKey -}}
{{- index .cfg .cfgKey -}}
{{- else -}}
{{- .fallback -}}
{{- end -}}
{{- end }}

{{/*
componentMigrationJob — PreSync migration Job, two flavors:

  BAKED     (spb, scr, desk): the app image bakes its migrations tree; an
            initContainer copies it into an emptyDir and the shared
            migrate/migrate image applies it with an optional
            x-migrations-table. Requires a URL-safe Postgres password.
  DEDICATED (spi, siloc): the rail ships its own migrator image whose
            entrypoint owns module ordering and bookkeeping tables; the Job
            just runs it with the POSTGRES_* env contract.

hook-weight -1 puts the Job after any PreSync Secret and before the main-sync
Deployments, so no rail boots unmigrated.

Input dict: root, name (component), comp, shared, sharedCfg, flavor
("baked"|"dedicated"), dbCfgKey (optional — the ConfigMap key holding the
database name; defaults to POSTGRES_DB, correios reads POSTGRES_NAME).
*/}}
{{- define "br-sfn.componentMigrationJob" -}}
{{- $mig := .comp.migrations | default dict -}}
{{- if $mig.enabled -}}
{{- $id := dict "root" .root "name" (printf "%s-migrations" .name) -}}
{{- $compId := dict "root" .root "name" .name -}}
{{- $fullname := include "br-sfn.componentFullname" $id -}}
{{- /* configDataOverride (optional): pre-rendered ConfigMap body, so the migration Job
       resolves POSTGRES_* through the SAME datastore masks the productized app ConfigMap
       uses (configured-path parity). Falls back to the legacy merge when absent. */ -}}
{{- $cfgStr := .configDataOverride | default (include "br-sfn.componentConfigData" (dict "comp" .comp "shared" .shared)) -}}
{{- $cfg := dict -}}
{{- if $cfgStr }}{{ $cfg = fromYaml $cfgStr }}{{ end -}}
{{- $pgHost := include "br-sfn.migrationPgValue" (dict "mig" $mig "key" "host" "cfg" $cfg "cfgKey" "POSTGRES_HOST" "fallback" "") -}}
{{- if not $pgHost -}}
{{- fail (printf "br-sfn: %s migrations need a Postgres host — set %s.migrations.postgres.host or %s.configmap.POSTGRES_HOST" .name .name .name) -}}
{{- end -}}
{{- $pgPort := include "br-sfn.migrationPgValue" (dict "mig" $mig "key" "port" "cfg" $cfg "cfgKey" "POSTGRES_PORT" "fallback" "5432") -}}
{{- $pgUser := include "br-sfn.migrationPgValue" (dict "mig" $mig "key" "user" "cfg" $cfg "cfgKey" "POSTGRES_USER" "fallback" "") -}}
{{- if not $pgUser -}}
{{- fail (printf "br-sfn: %s migrations need a Postgres user — set %s.migrations.postgres.user or %s.configmap.POSTGRES_USER" .name .name .name) -}}
{{- end -}}
{{- $dbCfgKey := .dbCfgKey | default "POSTGRES_DB" -}}
{{- $pgDb := include "br-sfn.migrationPgValue" (dict "mig" $mig "key" "database" "cfg" $cfg "cfgKey" $dbCfgKey "fallback" "") -}}
{{- if not $pgDb -}}
{{- fail (printf "br-sfn: %s migrations need a Postgres database — set %s.migrations.postgres.database or %s.configmap.%s" .name .name .name $dbCfgKey) -}}
{{- end -}}
{{- $pgSsl := include "br-sfn.migrationPgValue" (dict "mig" $mig "key" "sslMode" "cfg" $cfg "cfgKey" "POSTGRES_SSLMODE" "fallback" "disable") -}}
{{- $pwSecret := ($mig.passwordSecret | default dict) -}}
{{- $pwKey := $pwSecret.key | default "POSTGRES_PASSWORD" -}}
{{- $sharedCfgM := .sharedCfg | default dict -}}
{{- $mergedSecrets := mergeOverwrite (deepCopy (.sharedSecrets | default dict)) (.comp.secrets | default dict) -}}
{{- $pwName := "" -}}
{{- $mintSecret := false -}}
{{- if $pwSecret.name -}}
{{- /* Operator-owned Secret: name + key are the operator's contract. */ -}}
{{- $pwName = $pwSecret.name -}}
{{- else if or .comp.useExistingSecret $sharedCfgM.useExistingSecret -}}
{{- /* Existing-secret override: resolve the SAME name the component resolves
       (component-level flag first, then the family-level one), so the Job and
       the Deployment always read one Secret. */ -}}
{{- $pwName = include "br-sfn.componentSecretName" (dict "root" .root "name" (.secretComponent | default .name) "comp" .comp "sharedCfg" $sharedCfgM) -}}
{{- else -}}
{{- /* Generated path: the component Secret is a MAIN-SYNC resource, so a
       PreSync Job racing it would sit in CreateContainerConfigError. Mint a
       dedicated PreSync hook Secret (weight -2, created before the Job at -1,
       BeforeHookCreation only so it survives the whole PreSync phase) carrying
       just the password. Fail loud when the key is missing — a Job pointing at
       an absent key would otherwise hang until activeDeadlineSeconds. */ -}}
{{- if not (hasKey $mergedSecrets $pwKey) -}}
{{- fail (printf "br-sfn: %s migrations need %s in %s.secrets (or set %s.migrations.passwordSecret.name to an operator-provided Secret)" .name $pwKey .name .name) -}}
{{- end -}}
{{- $pwName = include "br-sfn.componentFullname" $id -}}
{{- $mintSecret = true -}}
{{- end -}}
{{- if $mintSecret }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ $pwName }}
  namespace: {{ include "global.namespace" .root }}
  labels:
    {{- include "br-sfn.componentLabels" $id | nindent 4 }}
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-weight: "-2"
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
type: Opaque
stringData:
  {{ $pwKey }}: {{ index $mergedSecrets $pwKey | quote }}
---
{{- end }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ $fullname }}
  namespace: {{ include "global.namespace" .root }}
  labels:
    {{- include "br-sfn.componentLabels" $id | nindent 4 }}
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-weight: "-1"
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookSucceeded
spec:
  backoffLimit: {{ $mig.backoffLimit | default 3 }}
  activeDeadlineSeconds: {{ $mig.activeDeadlineSeconds | default 600 }}
  ttlSecondsAfterFinished: {{ $mig.ttlSecondsAfterFinished | default 600 }}
  template:
    metadata:
      labels:
        {{- include "br-sfn.componentLabels" $id | nindent 8 }}
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      securityContext:
        seccompProfile:
          type: RuntimeDefault
      {{- with (include "br-sfn.componentPullSecrets" (dict "root" .root "comp" (dict "imagePullSecrets" ($mig.imagePullSecrets | default .comp.imagePullSecrets)))) }}
      imagePullSecrets:
        {{- . | nindent 8 }}
      {{- end }}
      initContainers:
        - name: wait-for-postgres
          image: {{ .root.Values.waitImage | default "busybox:1.36" }}
          command:
            - /bin/sh
            - -c
            - >
              echo "waiting for {{ $pgHost }}:{{ $pgPort }}...";
              until nc -z {{ $pgHost }} {{ $pgPort }}; do
                echo "{{ $pgHost }}:{{ $pgPort }} not ready, waiting..."; sleep 5;
              done;
              echo "{{ $pgHost }}:{{ $pgPort }} is ready"
          securityContext:
            {{- toYaml .root.Values.securityContext | nindent 12 }}
        {{- if eq .flavor "baked" }}
        # The app image is the single source of the migrations tree; copy it
        # out so the migrate container never runs the service binary.
        - name: extract-migrations
          image: {{ include "br-sfn.componentImage" (dict "root" .root "comp" .comp) | quote }}
          imagePullPolicy: {{ .comp.image.pullPolicy | default "IfNotPresent" }}
          command:
            - /bin/sh
            - -c
            - cp -R {{ $mig.sourcePath | default "/migrations" }}/. /workdir/
          securityContext:
            {{- toYaml .root.Values.securityContext | nindent 12 }}
          volumeMounts:
            - name: migrations
              mountPath: /workdir
        {{- end }}
      containers:
        {{- if eq .flavor "baked" }}
        - name: migrations
          image: {{ .root.Values.migrateImage | default "migrate/migrate:v4.18.1" }}
          # URL assembled in-shell so the password rides a Secret env var, not
          # the rendered manifest. Passwords must be URL-safe (no @ : / ? # %) —
          # same constraint the compose migrators document.
          command:
            - /bin/sh
            - -c
            - >-
              migrate -path /migrations
              -database "postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}?sslmode=${POSTGRES_SSLMODE}{{ with $mig.table }}&x-migrations-table={{ . }}{{ end }}"
              up
          volumeMounts:
            - name: migrations
              mountPath: /migrations
              readOnly: true
        {{- else }}
        - name: migrations
          image: "{{ $mig.image.repository }}:{{ $mig.image.tag | default .root.Chart.AppVersion }}"
          imagePullPolicy: {{ $mig.image.pullPolicy | default "IfNotPresent" }}
        {{- end }}
          env:
            - name: POSTGRES_HOST
              value: {{ $pgHost | quote }}
            - name: POSTGRES_PORT
              value: {{ $pgPort | quote }}
            - name: POSTGRES_USER
              value: {{ $pgUser | quote }}
            # dbEnvName: the DB-name env the migrator reads (default POSTGRES_DB; a rail
            # whose migrator reads another name — br-sta uses POSTGRES_NAME — overrides it).
            - name: {{ .dbEnvName | default "POSTGRES_DB" }}
              value: {{ $pgDb | quote }}
            - name: POSTGRES_SSLMODE
              value: {{ $pgSsl | quote }}
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ $pwName }}
                  key: {{ $pwKey }}
            # extraMigrationEnv: optional extra env for a dedicated migrator needing more
            # than the POSTGRES_* contract (br-sta: MIGRATIONS_PATH, ALLOW_INSECURE_TLS).
            {{- range $k, $v := (.extraMigrationEnv | default dict) }}
            - name: {{ $k }}
              value: {{ $v | quote }}
            {{- end }}
          securityContext:
            {{- toYaml .root.Values.securityContext | nindent 12 }}
          resources:
            {{- toYaml ($mig.resources | default dict) | nindent 12 }}
      {{- if eq .flavor "baked" }}
      volumes:
        - name: migrations
          emptyDir: {}
      {{- end }}
{{- end }}
{{- end }}

{{/*
=============================================================================
spiConfigData — the productized SPI-family ConfigMap body (the "manager"
surface the 4 sub-deployments spi-api/dict/brcode/core share).

Dependency CONNECTIONS are typed knobs via lerian-common masks/helpers
(Postgres + Redis via datastore.value, observability via otel.env, auth via
globalValue over global.auth); EVERYTHING else is an escape-hatch passthrough
with the app's struct default, overridable via spi.configmap.<KEY> (shared) or
spi.<comp>.configmap.<KEY> (per sub-deployment; wins). Credentials NEVER render
here — they live in the Secret.

Input dict: root ($), comp (the sub-deployment values block — image/configmap),
port (the sub-deployment service port; SERVER_ADDRESS defaults to it).
=============================================================================
*/}}
{{- define "br-sfn.spiConfigData" -}}
{{- $root := .root -}}
{{- $ds := $root.Values.spi.datastores | default dict -}}
{{- $port := .port -}}
{{- /* precedence in ONE map: per-sub-deployment configmap wins over the shared
       spi.configmap escape hatch; masks/helpers read this merged map as the native
       (top-precedence) source. */ -}}
{{- $cm := mergeOverwrite (deepCopy ($root.Values.spi.configmap | default dict)) (.comp.configmap | default dict) -}}
  # =============================================================================
  # DATABASE — PostgreSQL (host/port/user/db/ssl/replicaHost via datastore mask;
  # POOL/replica tuning stays passthrough below). POSTGRES_PASSWORD -> Secret.
  # =============================================================================
  POSTGRES_HOST: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "host" "nativeKey" "POSTGRES_HOST" "default" "localhost") | quote }}
  POSTGRES_PORT: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "port" "nativeKey" "POSTGRES_PORT" "default" "5432") | quote }}
  POSTGRES_USER: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "user" "nativeKey" "POSTGRES_USER" "default" "brspi") | quote }}
  POSTGRES_DB: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "name" "nativeKey" "POSTGRES_DB" "default" "brspi") | quote }}
  POSTGRES_SSLMODE: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "ssl" "nativeKey" "POSTGRES_SSLMODE" "default" "disable") | quote }}
  # ALLOW_INSECURE_TLS (lib-commons bypass to accept a non-TLS Postgres/Redis; dev/dev-st
  # only). SECURE default false; NEVER default true. Set <rail>.configmap.ALLOW_INSECURE_TLS=true only in dev.
  ALLOW_INSECURE_TLS: {{ $cm.ALLOW_INSECURE_TLS | default "false" | quote }}
  POSTGRES_REPLICA_HOST: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "replicaHost" "nativeKey" "POSTGRES_REPLICA_HOST" "default" "") | quote }}

  # REDIS / Valkey (combined host:port via datastore mask; composes the shared
  # redis {host,port} tier too). REDIS_PASSWORD -> Secret.
  REDIS_HOST: {{ include "br-sfn.redisComposedAddr" (dict "root" $root "ds" $ds "cm" $cm "hostKey" "REDIS_HOST" "hostDefault" "localhost:6379") | quote }}

  # =============================================================================
  # OBSERVABILITY — per-service identity inline; ENABLE_TELEMETRY / OTLP endpoint /
  # deployment-env shared via global.observability (lerian-common.otel.env).
  # =============================================================================
  OTEL_RESOURCE_SERVICE_NAME: {{ $cm.OTEL_RESOURCE_SERVICE_NAME | default (.svcName | default "br-spi") | quote }}
  OTEL_LIBRARY_NAME: {{ $cm.OTEL_LIBRARY_NAME | default "github.com/LerianStudio/br-spi" | quote }}
  OTEL_RESOURCE_SERVICE_VERSION: {{ $cm.OTEL_RESOURCE_SERVICE_VERSION | default (.comp.image.tag | default $root.Chart.AppVersion) | quote }}
  {{- include "lerian-common.otel.env" (dict "context" $root "configmap" $cm "enabledDefault" "false" "endpointDefault" "localhost:4317" "deploymentEnvironmentDefault" "development") | nindent 2 }}

  # =============================================================================
  # AUTH (plugin-access-manager) — enable/host via global.auth. AUTH_ENABLED is the
  # app's canonical gate; PLUGIN_AUTH_ENABLED is the lib-auth alias (both track
  # global.auth.enabled so they never diverge). PLUGIN_AUTH_ADDRESS is the host.
  # =============================================================================
  AUTH_ENABLED: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "auth" "field" "enabled" "nativeKey" "AUTH_ENABLED" "default" "false") | quote }}
  PLUGIN_AUTH_ENABLED: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "auth" "field" "enabled" "nativeKey" "PLUGIN_AUTH_ENABLED" "default" "false") | quote }}
  PLUGIN_AUTH_ADDRESS: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "auth" "field" "host" "nativeKey" "PLUGIN_AUTH_ADDRESS" "default" "") | quote }}

  # SERVER_ADDRESS defaults to this sub-deployment's own service port, so the app
  # listens on the port the Service and health probes target (each binary differs).
  SERVER_ADDRESS: {{ $cm.SERVER_ADDRESS | default (printf ":%v" $port) | quote }}

  # APP / SERVER
  ENV_NAME: {{ $cm.ENV_NAME | default "development" | quote }}
  LOG_LEVEL: {{ $cm.LOG_LEVEL | default "info" | quote }}
  SYSTEMPLANE_ENABLED: {{ $cm.SYSTEMPLANE_ENABLED | default "true" | quote }}
  HTTP_BODY_LIMIT_BYTES: {{ $cm.HTTP_BODY_LIMIT_BYTES | default "1048576" | quote }}
  PUBLIC_BASE_URL: {{ $cm.PUBLIC_BASE_URL | default "" | quote }}
  TLS_TERMINATED_UPSTREAM: {{ $cm.TLS_TERMINATED_UPSTREAM | default "false" | quote }}
  TRUSTED_PROXIES: {{ $cm.TRUSTED_PROXIES | default "" | quote }}
  BACEN_CALLBACK_TRUSTED_PROXY_CIDRS: {{ $cm.BACEN_CALLBACK_TRUSTED_PROXY_CIDRS | default "" | quote }}
  SERVER_TLS_CERT_FILE: {{ $cm.SERVER_TLS_CERT_FILE | default "" | quote }}
  SERVER_TLS_KEY_FILE: {{ $cm.SERVER_TLS_KEY_FILE | default "" | quote }}
  SERVER_TLS_CLIENT_CA_FILE: {{ $cm.SERVER_TLS_CLIENT_CA_FILE | default "" | quote }}
  ACCESS_CONTROL_ALLOW_ORIGIN: {{ $cm.ACCESS_CONTROL_ALLOW_ORIGIN | default "http://localhost:3000" | quote }}
  ACCESS_CONTROL_ALLOW_METHODS: {{ $cm.ACCESS_CONTROL_ALLOW_METHODS | default "GET,POST,PUT,PATCH,DELETE,OPTIONS" | quote }}
  ACCESS_CONTROL_ALLOW_HEADERS: {{ $cm.ACCESS_CONTROL_ALLOW_HEADERS | default "Origin,Content-Type,Accept,Authorization,X-Request-ID,X-Correlation-ID,Idempotency-Key" | quote }}

  # SWAGGER
  SWAGGER_ENABLED: {{ $cm.SWAGGER_ENABLED | default "false" | quote }}

  # RATE LIMIT
  RATE_LIMIT_ENABLED: {{ $cm.RATE_LIMIT_ENABLED | default "true" | quote }}
  RATE_LIMIT_MAX: {{ $cm.RATE_LIMIT_MAX | default "100" | quote }}
  RATE_LIMIT_EXPIRY_SEC: {{ $cm.RATE_LIMIT_EXPIRY_SEC | default "60" | quote }}

  # OUTBOX
  OUTBOX_ENABLED: {{ $cm.OUTBOX_ENABLED | default "true" | quote }}
  OUTBOX_DISPATCH_INTERVAL_MS: {{ $cm.OUTBOX_DISPATCH_INTERVAL_MS | default "2000" | quote }}
  OUTBOX_BATCH_SIZE: {{ $cm.OUTBOX_BATCH_SIZE | default "50" | quote }}
  OUTBOX_MAX_DISPATCH_ATTEMPTS: {{ $cm.OUTBOX_MAX_DISPATCH_ATTEMPTS | default "10" | quote }}
  OUTBOX_PROCESSING_TIMEOUT_MS: {{ $cm.OUTBOX_PROCESSING_TIMEOUT_MS | default "600000" | quote }}
  OUTBOX_RETRY_WINDOW_MS: {{ $cm.OUTBOX_RETRY_WINDOW_MS | default "300000" | quote }}

  # SCHEDULER
  SCHEDULER_APPROVAL_EXPIRY_ENABLED: {{ $cm.SCHEDULER_APPROVAL_EXPIRY_ENABLED | default "false" | quote }}
  SCHEDULER_CLAIM_DEADLINE_ENABLED: {{ $cm.SCHEDULER_CLAIM_DEADLINE_ENABLED | default "false" | quote }}
  SCHEDULER_DICT_AUDIT_RETENTION_ENABLED: {{ $cm.SCHEDULER_DICT_AUDIT_RETENTION_ENABLED | default "false" | quote }}
  SCHEDULER_DICT_RECONCILIATION_FULL_ENABLED: {{ $cm.SCHEDULER_DICT_RECONCILIATION_FULL_ENABLED | default "false" | quote }}
  SCHEDULER_DICT_RECONCILIATION_INCREMENTAL_ENABLED: {{ $cm.SCHEDULER_DICT_RECONCILIATION_INCREMENTAL_ENABLED | default "false" | quote }}
  SCHEDULER_ENABLED: {{ $cm.SCHEDULER_ENABLED | default "false" | quote }}
  SCHEDULER_INBOUND_DISCOVERY_ENABLED: {{ $cm.SCHEDULER_INBOUND_DISCOVERY_ENABLED | default "false" | quote }}
  SCHEDULER_MED_DEADLINE_ENABLED: {{ $cm.SCHEDULER_MED_DEADLINE_ENABLED | default "false" | quote }}
  SCHEDULER_PORTABILITY_DEADLINE_ENABLED: {{ $cm.SCHEDULER_PORTABILITY_DEADLINE_ENABLED | default "false" | quote }}
  SCHEDULER_QUOTA_RESET_ENABLED: {{ $cm.SCHEDULER_QUOTA_RESET_ENABLED | default "false" | quote }}

  # IDEMPOTENCY / INFRA
  IDEMPOTENCY_RETRY_WINDOW_SEC: {{ $cm.IDEMPOTENCY_RETRY_WINDOW_SEC | default "86400" | quote }}
  INFRA_CONNECT_TIMEOUT_SEC: {{ $cm.INFRA_CONNECT_TIMEOUT_SEC | default "30" | quote }}

  # BACEN SPI (primary CPM / ICOM secondary channel)
  BACEN_SPI_ALLOWED_ENDPOINT_HOSTS: {{ $cm.BACEN_SPI_ALLOWED_ENDPOINT_HOSTS | default "" | quote }}
  BACEN_SPI_CATALOGUE_ROOT: {{ $cm.BACEN_SPI_CATALOGUE_ROOT | default "" | quote }}
  BACEN_SPI_CATALOGUE_VERSION: {{ $cm.BACEN_SPI_CATALOGUE_VERSION | default "5.12.1" | quote }}
  BACEN_SPI_ENDPOINT: {{ $cm.BACEN_SPI_ENDPOINT | default "http://localhost:9900" | quote }}
  BACEN_SPI_INBOUND_CALLBACK_TIMEOUT_MS: {{ $cm.BACEN_SPI_INBOUND_CALLBACK_TIMEOUT_MS | default "250" | quote }}
  BACEN_SPI_INBOUND_SIGNER_COMMON_NAME: {{ $cm.BACEN_SPI_INBOUND_SIGNER_COMMON_NAME | default "" | quote }}
  BACEN_SPI_INITIATION_TIMEOUT_MS: {{ $cm.BACEN_SPI_INITIATION_TIMEOUT_MS | default "150" | quote }}
  BACEN_SPI_KMIP_BASE_URL: {{ $cm.BACEN_SPI_KMIP_BASE_URL | default "" | quote }}
  BACEN_SPI_KMIP_CRYPTO_USER: {{ $cm.BACEN_SPI_KMIP_CRYPTO_USER | default "" | quote }}
  BACEN_SPI_KMIP_DIGEST_INFO_PREFIX: {{ $cm.BACEN_SPI_KMIP_DIGEST_INFO_PREFIX | default "false" | quote }}
  BACEN_SPI_KMIP_SIGN_PRIVATE_KEY_UID: {{ $cm.BACEN_SPI_KMIP_SIGN_PRIVATE_KEY_UID | default "" | quote }}
  BACEN_SPI_KMIP_SIGN_PUBLIC_KEY_UID: {{ $cm.BACEN_SPI_KMIP_SIGN_PUBLIC_KEY_UID | default "" | quote }}
  BACEN_SPI_KMIP_VHSM: {{ $cm.BACEN_SPI_KMIP_VHSM | default "" | quote }}
  BACEN_SPI_OCSP_CACHE_TTL_CAP_SEC: {{ $cm.BACEN_SPI_OCSP_CACHE_TTL_CAP_SEC | default "3600" | quote }}
  BACEN_SPI_OCSP_CRL_CACHE_TTL_SEC: {{ $cm.BACEN_SPI_OCSP_CRL_CACHE_TTL_SEC | default "3600" | quote }}
  BACEN_SPI_OCSP_MODE: {{ $cm.BACEN_SPI_OCSP_MODE | default "soft_fail" | quote }}
  BACEN_SPI_OCSP_TIMEOUT_MS: {{ $cm.BACEN_SPI_OCSP_TIMEOUT_MS | default "3000" | quote }}
  BACEN_SPI_OUTBOUND_QUOTA_BURST: {{ $cm.BACEN_SPI_OUTBOUND_QUOTA_BURST | default "" | quote }}
  BACEN_SPI_OUTBOUND_QUOTA_ENABLED: {{ $cm.BACEN_SPI_OUTBOUND_QUOTA_ENABLED | default "false" | quote }}
  BACEN_SPI_OUTBOUND_QUOTA_LIMIT: {{ $cm.BACEN_SPI_OUTBOUND_QUOTA_LIMIT | default "" | quote }}
  BACEN_SPI_PARTICIPANT_ISPB: {{ $cm.BACEN_SPI_PARTICIPANT_ISPB | default "" | quote }}
  BACEN_SPI_PAYLOAD_RESOLVER_IN_MEMORY_MAX_BYTES: {{ $cm.BACEN_SPI_PAYLOAD_RESOLVER_IN_MEMORY_MAX_BYTES | default "134217728" | quote }}
  BACEN_SPI_PAYLOAD_RESOLVER_KIND: {{ $cm.BACEN_SPI_PAYLOAD_RESOLVER_KIND | default "in_memory" | quote }}
  BACEN_SPI_PAYLOAD_RESOLVER_TTL_SEC: {{ $cm.BACEN_SPI_PAYLOAD_RESOLVER_TTL_SEC | default "86400" | quote }}
  BACEN_SPI_PKCS11_KEY_LABEL: {{ $cm.BACEN_SPI_PKCS11_KEY_LABEL | default "" | quote }}
  BACEN_SPI_PKCS11_MODULE_PATH: {{ $cm.BACEN_SPI_PKCS11_MODULE_PATH | default "" | quote }}
  BACEN_SPI_PKCS11_PIN_FILE: {{ $cm.BACEN_SPI_PKCS11_PIN_FILE | default "" | quote }}
  BACEN_SPI_PKCS11_TOKEN_LABEL: {{ $cm.BACEN_SPI_PKCS11_TOKEN_LABEL | default "" | quote }}
  BACEN_SPI_RETRY_ATTEMPTS: {{ $cm.BACEN_SPI_RETRY_ATTEMPTS | default "3" | quote }}
  BACEN_SPI_RETRY_INITIAL_BACKOFF_MS: {{ $cm.BACEN_SPI_RETRY_INITIAL_BACKOFF_MS | default "500" | quote }}
  BACEN_SPI_RETRY_MAX_BACKOFF_MS: {{ $cm.BACEN_SPI_RETRY_MAX_BACKOFF_MS | default "5000" | quote }}
  BACEN_SPI_SECONDARY_ALLOWED_ENDPOINT_HOSTS: {{ $cm.BACEN_SPI_SECONDARY_ALLOWED_ENDPOINT_HOSTS | default "" | quote }}
  BACEN_SPI_SECONDARY_ENDPOINT: {{ $cm.BACEN_SPI_SECONDARY_ENDPOINT | default "" | quote }}
  BACEN_SPI_SIGNER_COMMON_NAME: {{ $cm.BACEN_SPI_SIGNER_COMMON_NAME | default "" | quote }}
  BACEN_SPI_SIGNER_KIND: {{ $cm.BACEN_SPI_SIGNER_KIND | default "file" | quote }}
  BACEN_SPI_SIGNING_CERT_FILE: {{ $cm.BACEN_SPI_SIGNING_CERT_FILE | default "" | quote }}
  BACEN_SPI_TIMEOUT_SEC: {{ $cm.BACEN_SPI_TIMEOUT_SEC | default "30" | quote }}
  BACEN_SPI_XSD_DIR: {{ $cm.BACEN_SPI_XSD_DIR | default "docs/pre-dev/bacen-references/spi/spi.5.12.1/xsd" | quote }}

  # BACEN ICOM (pull-stream consumer)
  BACEN_ICOM_BASE_URL: {{ $cm.BACEN_ICOM_BASE_URL | default "" | quote }}
  BACEN_ICOM_CONSUMER_ENABLED: {{ $cm.BACEN_ICOM_CONSUMER_ENABLED | default "false" | quote }}
  BACEN_ICOM_ISPB: {{ $cm.BACEN_ICOM_ISPB | default "" | quote }}
  BACEN_ICOM_LONGPOLL_TIMEOUT_MS: {{ $cm.BACEN_ICOM_LONGPOLL_TIMEOUT_MS | default "90000" | quote }}
  BACEN_ICOM_SECONDARY_CONSUMER_ENABLED: {{ $cm.BACEN_ICOM_SECONDARY_CONSUMER_ENABLED | default "false" | quote }}

  # BACEN ARQ (file transfer)
  BACEN_ARQ_ALLOWED_ENDPOINT_HOSTS: {{ $cm.BACEN_ARQ_ALLOWED_ENDPOINT_HOSTS | default "" | quote }}
  BACEN_ARQ_ENDPOINT: {{ $cm.BACEN_ARQ_ENDPOINT | default "" | quote }}

  # BACEN TLS (shared CERTPIC mTLS material — file paths)
  BACEN_TLS_CERT_FILE: {{ $cm.BACEN_TLS_CERT_FILE | default "" | quote }}
  BACEN_TLS_KEY_FILE: {{ $cm.BACEN_TLS_KEY_FILE | default "" | quote }}
  BACEN_TLS_CA_FILE: {{ $cm.BACEN_TLS_CA_FILE | default "" | quote }}

  # BACEN DICT
  BACEN_DICT_ALLOWED_ENDPOINT_HOSTS: {{ $cm.BACEN_DICT_ALLOWED_ENDPOINT_HOSTS | default "" | quote }}
  BACEN_DICT_ENDPOINT: {{ $cm.BACEN_DICT_ENDPOINT | default "http://localhost:9900" | quote }}
  BACEN_DICT_KMIP_BASE_URL: {{ $cm.BACEN_DICT_KMIP_BASE_URL | default "" | quote }}
  BACEN_DICT_KMIP_CRYPTO_USER: {{ $cm.BACEN_DICT_KMIP_CRYPTO_USER | default "" | quote }}
  BACEN_DICT_KMIP_DIGEST_INFO_PREFIX: {{ $cm.BACEN_DICT_KMIP_DIGEST_INFO_PREFIX | default "false" | quote }}
  BACEN_DICT_KMIP_SIGN_PRIVATE_KEY_UID: {{ $cm.BACEN_DICT_KMIP_SIGN_PRIVATE_KEY_UID | default "" | quote }}
  BACEN_DICT_KMIP_SIGN_PUBLIC_KEY_UID: {{ $cm.BACEN_DICT_KMIP_SIGN_PUBLIC_KEY_UID | default "" | quote }}
  BACEN_DICT_KMIP_VHSM: {{ $cm.BACEN_DICT_KMIP_VHSM | default "" | quote }}
  BACEN_DICT_NP_ALLOWED_ENDPOINT_HOSTS: {{ $cm.BACEN_DICT_NP_ALLOWED_ENDPOINT_HOSTS | default "" | quote }}
  BACEN_DICT_NP_ENDPOINT: {{ $cm.BACEN_DICT_NP_ENDPOINT | default "" | quote }}
  BACEN_DICT_PARTICIPANT_ISPB: {{ $cm.BACEN_DICT_PARTICIPANT_ISPB | default "" | quote }}
  BACEN_DICT_PKCS11_KEY_LABEL: {{ $cm.BACEN_DICT_PKCS11_KEY_LABEL | default "" | quote }}
  BACEN_DICT_PKCS11_MODULE_PATH: {{ $cm.BACEN_DICT_PKCS11_MODULE_PATH | default "" | quote }}
  BACEN_DICT_PKCS11_PIN_FILE: {{ $cm.BACEN_DICT_PKCS11_PIN_FILE | default "" | quote }}
  BACEN_DICT_PKCS11_TOKEN_LABEL: {{ $cm.BACEN_DICT_PKCS11_TOKEN_LABEL | default "" | quote }}
  BACEN_DICT_SIGNER_KIND: {{ $cm.BACEN_DICT_SIGNER_KIND | default "file" | quote }}
  BACEN_DICT_SIGNING_CERT_FILE: {{ $cm.BACEN_DICT_SIGNING_CERT_FILE | default "" | quote }}
  BACEN_DICT_SIGNING_KEY_FILE: {{ $cm.BACEN_DICT_SIGNING_KEY_FILE | default "" | quote }}
  BACEN_DICT_TIMEOUT_SEC: {{ $cm.BACEN_DICT_TIMEOUT_SEC | default "10" | quote }}
  BACEN_DICT_VERIFY_CERT_FILE: {{ $cm.BACEN_DICT_VERIFY_CERT_FILE | default "" | quote }}

  # BACEN BRCODE JOSE (public payload signing)
  BACEN_BRCODE_JOSE_KID: {{ $cm.BACEN_BRCODE_JOSE_KID | default "" | quote }}
  BACEN_BRCODE_JOSE_KMIP_BASE_URL: {{ $cm.BACEN_BRCODE_JOSE_KMIP_BASE_URL | default "" | quote }}
  BACEN_BRCODE_JOSE_KMIP_CRYPTO_USER: {{ $cm.BACEN_BRCODE_JOSE_KMIP_CRYPTO_USER | default "" | quote }}
  BACEN_BRCODE_JOSE_KMIP_DIGEST_INFO_PREFIX: {{ $cm.BACEN_BRCODE_JOSE_KMIP_DIGEST_INFO_PREFIX | default "false" | quote }}
  BACEN_BRCODE_JOSE_KMIP_SIGN_PRIVATE_KEY_UID: {{ $cm.BACEN_BRCODE_JOSE_KMIP_SIGN_PRIVATE_KEY_UID | default "" | quote }}
  BACEN_BRCODE_JOSE_KMIP_SIGN_PUBLIC_KEY_UID: {{ $cm.BACEN_BRCODE_JOSE_KMIP_SIGN_PUBLIC_KEY_UID | default "" | quote }}
  BACEN_BRCODE_JOSE_KMIP_VHSM: {{ $cm.BACEN_BRCODE_JOSE_KMIP_VHSM | default "" | quote }}
  BACEN_BRCODE_JOSE_PKCS11_KEY_LABEL: {{ $cm.BACEN_BRCODE_JOSE_PKCS11_KEY_LABEL | default "" | quote }}
  BACEN_BRCODE_JOSE_PKCS11_MODULE_PATH: {{ $cm.BACEN_BRCODE_JOSE_PKCS11_MODULE_PATH | default "" | quote }}
  BACEN_BRCODE_JOSE_PKCS11_PIN_FILE: {{ $cm.BACEN_BRCODE_JOSE_PKCS11_PIN_FILE | default "" | quote }}
  BACEN_BRCODE_JOSE_PKCS11_TOKEN_LABEL: {{ $cm.BACEN_BRCODE_JOSE_PKCS11_TOKEN_LABEL | default "" | quote }}
  BACEN_BRCODE_JOSE_SIGNER_KIND: {{ $cm.BACEN_BRCODE_JOSE_SIGNER_KIND | default "" | quote }}
  BACEN_BRCODE_JOSE_SIGNING_CERT_FILE: {{ $cm.BACEN_BRCODE_JOSE_SIGNING_CERT_FILE | default "" | quote }}
  BACEN_BRCODE_JOSE_SIGNING_KEY_FILE: {{ $cm.BACEN_BRCODE_JOSE_SIGNING_KEY_FILE | default "" | quote }}

  # BRCODE SETTLEMENT CONSUMER
  BRCODE_SETTLEMENT_CONSUMER_CLIENT_ID: {{ $cm.BRCODE_SETTLEMENT_CONSUMER_CLIENT_ID | default "" | quote }}
  BRCODE_SETTLEMENT_CONSUMER_GROUP: {{ $cm.BRCODE_SETTLEMENT_CONSUMER_GROUP | default "br-spi-brcode-settlement-consumer" | quote }}
  BRCODE_SETTLEMENT_CONSUMER_TOPIC: {{ $cm.BRCODE_SETTLEMENT_CONSUMER_TOPIC | default "br-spi.spi.payment" | quote }}

  # CERT READINESS
  CERT_READINESS_MIN_DAYS: {{ $cm.CERT_READINESS_MIN_DAYS | default "14" | quote }}

  # POSTGRES tuning (host/port/user/db/ssl/replicaHost via datastore mask above)
  POSTGRES_MAX_OPEN_CONNS: {{ $cm.POSTGRES_MAX_OPEN_CONNS | default "25" | quote }}
  POSTGRES_MAX_IDLE_CONNS: {{ $cm.POSTGRES_MAX_IDLE_CONNS | default "5" | quote }}
  POSTGRES_CONN_MAX_LIFETIME_MINS: {{ $cm.POSTGRES_CONN_MAX_LIFETIME_MINS | default "30" | quote }}
  POSTGRES_CONN_MAX_IDLE_TIME_MINS: {{ $cm.POSTGRES_CONN_MAX_IDLE_TIME_MINS | default "5" | quote }}
  POSTGRES_CONNECT_TIMEOUT_SEC: {{ $cm.POSTGRES_CONNECT_TIMEOUT_SEC | default "10" | quote }}
  POSTGRES_REPLICA_PORT: {{ $cm.POSTGRES_REPLICA_PORT | default "" | quote }}
  POSTGRES_REPLICA_USER: {{ $cm.POSTGRES_REPLICA_USER | default "" | quote }}
  POSTGRES_REPLICA_DB: {{ $cm.POSTGRES_REPLICA_DB | default "" | quote }}
  POSTGRES_REPLICA_SSLMODE: {{ $cm.POSTGRES_REPLICA_SSLMODE | default "" | quote }}

  # REDIS tuning (host via datastore mask above)
  REDIS_MASTER_NAME: {{ $cm.REDIS_MASTER_NAME | default "" | quote }}
  REDIS_DB: {{ $cm.REDIS_DB | default "0" | quote }}
  REDIS_PROTOCOL: {{ $cm.REDIS_PROTOCOL | default "3" | quote }}
  REDIS_TLS: {{ $cm.REDIS_TLS | default "false" | quote }}
  REDIS_CA_CERT: {{ $cm.REDIS_CA_CERT | default "" | quote }}
  REDIS_POOL_SIZE: {{ $cm.REDIS_POOL_SIZE | default "10" | quote }}
  REDIS_MIN_IDLE_CONNS: {{ $cm.REDIS_MIN_IDLE_CONNS | default "2" | quote }}
  REDIS_READ_TIMEOUT_MS: {{ $cm.REDIS_READ_TIMEOUT_MS | default "3000" | quote }}
  REDIS_WRITE_TIMEOUT_MS: {{ $cm.REDIS_WRITE_TIMEOUT_MS | default "3000" | quote }}
  REDIS_DIAL_TIMEOUT_MS: {{ $cm.REDIS_DIAL_TIMEOUT_MS | default "5000" | quote }}

  # AUTH (enable/host via global.auth below; trust-upstream is passthrough)
  AUTH_TRUST_UPSTREAM_METADATA: {{ $cm.AUTH_TRUST_UPSTREAM_METADATA | default "false" | quote }}

  # OBSERVABILITY (OTLP/enable via global.observability below; Prometheus scrape passthrough)
  TELEMETRY_REQUIRED: {{ $cm.TELEMETRY_REQUIRED | default "false" | quote }}
  METRICS_PROMETHEUS_ENABLED: {{ $cm.METRICS_PROMETHEUS_ENABLED | default "false" | quote }}
  METRICS_PROMETHEUS_ADDRESS: {{ $cm.METRICS_PROMETHEUS_ADDRESS | default "127.0.0.1:9090" | quote }}
{{- end }}

{{/*
spiConfigmap — one ConfigMap per SPI sub-deployment (spi-api/dict/brcode/core),
each carrying the shared productized surface merged with its own overrides.
Input dict: root, name, comp, port.
*/}}
{{- define "br-sfn.spiConfigmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "br-sfn.componentFullname" (dict "root" .root "name" .name) }}
  namespace: {{ include "global.namespace" .root }}
  labels:
    {{- include "br-sfn.componentLabels" (dict "root" .root "name" .name) | nindent 4 }}
data:
{{ include "br-sfn.spiConfigData" (dict "root" .root "comp" .comp "port" .port "svcName" .svcName) }}
{{- end }}

{{/*
=============================================================================
spbConfigData — the productized SPB/STR (TED) ConfigMap body.

SPB is a SINGLE deployment. Dependency CONNECTIONS are typed knobs via
lerian-common masks/helpers (Postgres + Redis + RabbitMQ via datastore.value,
observability + auth via globalValue over global.observability/global.auth);
EVERYTHING else is an escape-hatch passthrough with the app default, overridable
via spb.configmap.<KEY>. Credentials NEVER render here — they live in the Secret.

Input dict: root ($), comp (.Values.spb), port (the service port; SERVER_PORT
defaults to it).
=============================================================================
*/}}
{{- define "br-sfn.spbConfigData" -}}
{{- $root := .root -}}
{{- $ds := $root.Values.spb.datastores | default dict -}}
{{- $port := .port -}}
{{- $cm := .comp.configmap | default dict -}}
  # =============================================================================
  # DATABASE — PostgreSQL (host/port/user/db/ssl/replicaHost via datastore mask;
  # pool/replica tuning passthrough below). POSTGRES_PASSWORD -> Secret.
  # =============================================================================
  POSTGRES_HOST: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "host" "nativeKey" "POSTGRES_HOST" "default" "localhost") | quote }}
  POSTGRES_PORT: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "port" "nativeKey" "POSTGRES_PORT" "default" "5432") | quote }}
  POSTGRES_USER: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "user" "nativeKey" "POSTGRES_USER" "default" "postgres") | quote }}
  POSTGRES_DB: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "name" "nativeKey" "POSTGRES_DB" "default" "br_bank_transfer_jota") | quote }}
  POSTGRES_SSLMODE: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "ssl" "nativeKey" "POSTGRES_SSLMODE" "default" "require") | quote }}
  # ALLOW_INSECURE_TLS (lib-commons bypass to accept a non-TLS Postgres/Redis; dev/dev-st
  # only). SECURE default false; NEVER default true. Set <rail>.configmap.ALLOW_INSECURE_TLS=true only in dev.
  ALLOW_INSECURE_TLS: {{ $cm.ALLOW_INSECURE_TLS | default "false" | quote }}
  POSTGRES_REPLICA_HOST: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "replicaHost" "nativeKey" "POSTGRES_REPLICA_HOST" "default" "") | quote }}

  # REDIS / Valkey (host+port via datastore mask; tuning passthrough below). REDIS_PASSWORD -> Secret.
  REDIS_HOST: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "redis" "field" "host" "nativeKey" "REDIS_HOST" "default" "localhost") | quote }}
  REDIS_PORT: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "redis" "field" "port" "nativeKey" "REDIS_PORT" "default" "6379") | quote }}

  # RABBITMQ (host/port/user via datastore broker mask; tuning passthrough below). RABBITMQ_PASSWORD -> Secret.
  RABBITMQ_HOST: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "broker" "field" "host" "nativeKey" "RABBITMQ_HOST" "default" "") | quote }}
  RABBITMQ_PORT: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "broker" "field" "port" "nativeKey" "RABBITMQ_PORT" "default" "5672") | quote }}
  RABBITMQ_USER: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "broker" "field" "user" "nativeKey" "RABBITMQ_USER" "default" "guest") | quote }}

  # =============================================================================
  # OBSERVABILITY — identity inline; ENABLE_TELEMETRY / OTLP endpoint shared via
  # global.observability (spb reads no OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT, so
  # the 2 shared keys are wired individually rather than via otel.env).
  # =============================================================================
  OTEL_RESOURCE_SERVICE_NAME: {{ $cm.OTEL_RESOURCE_SERVICE_NAME | default "br-spb" | quote }}
  ENABLE_TELEMETRY: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "observability" "field" "enabled" "nativeKey" "ENABLE_TELEMETRY" "default" "false") | quote }}
  OTEL_EXPORTER_OTLP_ENDPOINT: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "observability" "field" "otlpEndpoint" "nativeKey" "OTEL_EXPORTER_OTLP_ENDPOINT" "default" "http://localhost:4318") | quote }}

  # =============================================================================
  # AUTH (plugin-access-manager) — enable/host via global.auth. spb uses
  # PLUGIN_AUTH_ENABLED as its canonical gate (default true).
  # =============================================================================
  PLUGIN_AUTH_ENABLED: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "auth" "field" "enabled" "nativeKey" "PLUGIN_AUTH_ENABLED" "default" "true") | quote }}
  PLUGIN_AUTH_ADDRESS: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "auth" "field" "host" "nativeKey" "PLUGIN_AUTH_ADDRESS" "default" "http://localhost:4000") | quote }}

  # SERVER_PORT defaults to the service port so the app listens where the Service/probes target.
  SERVER_PORT: {{ $cm.SERVER_PORT | default (printf "%v" $port) | quote }}

  # APP / SERVER
  ENV_NAME: {{ $cm.ENV_NAME | default "develop" | quote }}
  SERVICE_NAME: {{ $cm.SERVICE_NAME | default "br-spb" | quote }}
  LOG_LEVEL: {{ $cm.LOG_LEVEL | default "info" | quote }}
  CORS_ALLOWED_ORIGINS: {{ $cm.CORS_ALLOWED_ORIGINS | default "http://localhost:3000" | quote }}
  TRUSTED_PROXIES: {{ $cm.TRUSTED_PROXIES | default "" | quote }}
  ENABLE_DEV_DEBUG_ROUTES: {{ $cm.ENABLE_DEV_DEBUG_ROUTES | default "false" | quote }}
  SYSTEMPLANE_LISTEN_CHANNEL: {{ $cm.SYSTEMPLANE_LISTEN_CHANNEL | default "br_spb_systemplane_changes" | quote }}

  # SWAGGER
  SWAGGER_ENABLED: {{ $cm.SWAGGER_ENABLED | default "false" | quote }}

  # IBM MQ / STR transport (RSFN)
  STR_MQ_HOST: {{ $cm.STR_MQ_HOST | default "" | quote }}
  STR_MQ_PORT: {{ $cm.STR_MQ_PORT | default "1414" | quote }}
  STR_MQ_CHANNEL: {{ $cm.STR_MQ_CHANNEL | default "DEV.APP.SVRCONN" | quote }}
  STR_MQ_QUEUE_MGR: {{ $cm.STR_MQ_QUEUE_MGR | default "QM1" | quote }}
  STR_MQ_USER: {{ $cm.STR_MQ_USER | default "app" | quote }}
  STR_MQ_TLS_ENABLED: {{ $cm.STR_MQ_TLS_ENABLED | default "false" | quote }}
  MQSSLKEYR: {{ $cm.MQSSLKEYR | default "" | quote }}
  STR_MQ_SEND_QUEUE: {{ $cm.STR_MQ_SEND_QUEUE | default "QR.REQ.00000000.00038166.01" | quote }}
  STR_MQ_RESPONSE_QUEUE: {{ $cm.STR_MQ_RESPONSE_QUEUE | default "QL.RSP.00038166.00000000.01" | quote }}
  STR_MQ_RECEIVE_QUEUE: {{ $cm.STR_MQ_RECEIVE_QUEUE | default "QL.REQ.00038166.00000000.01" | quote }}
  STR_ISPB: {{ $cm.STR_ISPB | default "00000000" | quote }}
  SILOC_ISPB: {{ $cm.SILOC_ISPB | default "02992335" | quote }}
  STR_MQ_MOCK: {{ $cm.STR_MQ_MOCK | default "false" | quote }}
  STR_MQ_MOCK_HOST: {{ $cm.STR_MQ_MOCK_HOST | default "http://localhost:8080" | quote }}
  STR_MQ_MOCK_ALLOWED_HOSTS: {{ $cm.STR_MQ_MOCK_ALLOWED_HOSTS | default "" | quote }}
  ALLOW_MOCK_TRANSPORT: {{ $cm.ALLOW_MOCK_TRANSPORT | default "false" | quote }}
  MQ_HEARTBEAT_INTERVAL: {{ $cm.MQ_HEARTBEAT_INTERVAL | default "300s" | quote }}
  MQ_DISCONNECT_INTERVAL: {{ $cm.MQ_DISCONNECT_INTERVAL | default "6000s" | quote }}
  MQ_SEQ_WRAP: {{ $cm.MQ_SEQ_WRAP | default "99999999" | quote }}
  MQ_ADOPTNEWMCA: {{ $cm.MQ_ADOPTNEWMCA | default "ALL" | quote }}

  # CIRCUIT BREAKER
  CB_MAX_REQUESTS: {{ $cm.CB_MAX_REQUESTS | default "3" | quote }}
  CB_INTERVAL: {{ $cm.CB_INTERVAL | default "30s" | quote }}
  CB_TIMEOUT: {{ $cm.CB_TIMEOUT | default "10s" | quote }}
  CB_CONSECUTIVE_FAILURES: {{ $cm.CB_CONSECUTIVE_FAILURES | default "5" | quote }}
  CB_FAILURE_RATIO: {{ $cm.CB_FAILURE_RATIO | default "0.5" | quote }}
  CB_MIN_REQUESTS: {{ $cm.CB_MIN_REQUESTS | default "10" | quote }}

  # OBSERVABILITY (OTLP/enable via global.observability; identity + prometheus passthrough)
  METRICS_PROMETHEUS_ENABLED: {{ $cm.METRICS_PROMETHEUS_ENABLED | default "false" | quote }}
  METRICS_PROMETHEUS_ADDRESS: {{ $cm.METRICS_PROMETHEUS_ADDRESS | default "127.0.0.1:9090" | quote }}

  # CERTIFICATES / SIGNER (SPB_SIGNER_KIND custody; file paths + labels)
  CERT_PATH: {{ $cm.CERT_PATH | default "" | quote }}
  KEY_PATH: {{ $cm.KEY_PATH | default "" | quote }}
  CERT_BASE_PATH: {{ $cm.CERT_BASE_PATH | default "/certs" | quote }}
  BACEN_PUBLIC_CERT_PATH: {{ $cm.BACEN_PUBLIC_CERT_PATH | default "" | quote }}
  CERT_READINESS_MIN_DAYS: {{ $cm.CERT_READINESS_MIN_DAYS | default "30" | quote }}
  PROCESS_CERT_PATH: {{ $cm.PROCESS_CERT_PATH | default "" | quote }}
  PROCESS_PRIVATE_KEY_PATH: {{ $cm.PROCESS_PRIVATE_KEY_PATH | default "" | quote }}
  SPB_SIGNER_KIND: {{ $cm.SPB_SIGNER_KIND | default "file" | quote }}
  SPB_PKCS11_MODULE_PATH: {{ $cm.SPB_PKCS11_MODULE_PATH | default "" | quote }}
  SPB_PKCS11_TOKEN_LABEL: {{ $cm.SPB_PKCS11_TOKEN_LABEL | default "" | quote }}
  SPB_PKCS11_PIN_FILE: {{ $cm.SPB_PKCS11_PIN_FILE | default "" | quote }}
  SPB_PKCS11_KEY_LABEL: {{ $cm.SPB_PKCS11_KEY_LABEL | default "" | quote }}
  SPB_KMIP_BASE_URL: {{ $cm.SPB_KMIP_BASE_URL | default "" | quote }}
  SPB_KMIP_VHSM: {{ $cm.SPB_KMIP_VHSM | default "" | quote }}
  SPB_KMIP_CRYPTO_USER: {{ $cm.SPB_KMIP_CRYPTO_USER | default "" | quote }}
  SPB_KMIP_SIGN_PRIVATE_KEY_UID: {{ $cm.SPB_KMIP_SIGN_PRIVATE_KEY_UID | default "" | quote }}
  SPB_KMIP_SIGN_PUBLIC_KEY_UID: {{ $cm.SPB_KMIP_SIGN_PUBLIC_KEY_UID | default "" | quote }}
  SPB_KMIP_DECRYPT_KEY_UID: {{ $cm.SPB_KMIP_DECRYPT_KEY_UID | default "" | quote }}
  SPB_KMIP_DIGEST_INFO_PREFIX: {{ $cm.SPB_KMIP_DIGEST_INFO_PREFIX | default "false" | quote }}
  INBOUND_ALLOW_CLEARTEXT_FALLBACK: {{ $cm.INBOUND_ALLOW_CLEARTEXT_FALLBACK | default "false" | quote }}

  # POSTGRES tuning (host/port/user/db/ssl/replicaHost via datastore mask above)
  POSTGRES_MAX_OPEN_CONNS: {{ $cm.POSTGRES_MAX_OPEN_CONNS | default "25" | quote }}
  POSTGRES_MAX_IDLE_CONNS: {{ $cm.POSTGRES_MAX_IDLE_CONNS | default "10" | quote }}
  POSTGRES_CONN_MAX_LIFETIME: {{ $cm.POSTGRES_CONN_MAX_LIFETIME | default "5m" | quote }}
  POSTGRES_CONN_MAX_IDLE_TIME: {{ $cm.POSTGRES_CONN_MAX_IDLE_TIME | default "2m" | quote }}
  POSTGRES_REPLICA_PORT: {{ $cm.POSTGRES_REPLICA_PORT | default "" | quote }}
  POSTGRES_REPLICA_USER: {{ $cm.POSTGRES_REPLICA_USER | default "" | quote }}
  POSTGRES_REPLICA_DB: {{ $cm.POSTGRES_REPLICA_DB | default "" | quote }}
  POSTGRES_REPLICA_SSLMODE: {{ $cm.POSTGRES_REPLICA_SSLMODE | default "" | quote }}

  # REDIS tuning (host/port via datastore mask above)
  REDIS_DB: {{ $cm.REDIS_DB | default "0" | quote }}
  REDIS_TLS_ENABLED: {{ $cm.REDIS_TLS_ENABLED | default "false" | quote }}
  REDIS_TLS_CA_CERT_BASE64: {{ $cm.REDIS_TLS_CA_CERT_BASE64 | default "" | quote }}
  REDIS_POOL_SIZE: {{ $cm.REDIS_POOL_SIZE | default "20" | quote }}
  REDIS_MIN_IDLE_CONNS: {{ $cm.REDIS_MIN_IDLE_CONNS | default "5" | quote }}

  # RABBITMQ (host/port/user via datastore broker mask above)
  RABBITMQ_VHOST: {{ $cm.RABBITMQ_VHOST | default "/" | quote }}
  RABBITMQ_STR_EXCHANGE: {{ $cm.RABBITMQ_STR_EXCHANGE | default "str.events" | quote }}
  RABBITMQ_TLS_ENABLED: {{ $cm.RABBITMQ_TLS_ENABLED | default "false" | quote }}

  # OUTBOX / EVENT DELIVERY / DISPATCH
  EMISSION_REQUIRED: {{ $cm.EMISSION_REQUIRED | default "false" | quote }}
  OUTBOX_DISPATCH_INTERVAL: {{ $cm.OUTBOX_DISPATCH_INTERVAL | default "2s" | quote }}
  OUTBOX_BATCH_SIZE: {{ $cm.OUTBOX_BATCH_SIZE | default "50" | quote }}
  OUTBOX_MAX_PUBLISH_ATTEMPTS: {{ $cm.OUTBOX_MAX_PUBLISH_ATTEMPTS | default "3" | quote }}
  OUTBOX_POSTGRES_MAX_OPEN_CONNS: {{ $cm.OUTBOX_POSTGRES_MAX_OPEN_CONNS | default "10" | quote }}
  OUTBOX_POSTGRES_MAX_IDLE_CONNS: {{ $cm.OUTBOX_POSTGRES_MAX_IDLE_CONNS | default "5" | quote }}
  EVENT_DELIVERY_BATCH_SIZE: {{ $cm.EVENT_DELIVERY_BATCH_SIZE | default "25" | quote }}
  EVENT_DELIVERY_MAX_ATTEMPTS: {{ $cm.EVENT_DELIVERY_MAX_ATTEMPTS | default "3" | quote }}
  EVENT_DELIVERY_RETRY_BACKOFF: {{ $cm.EVENT_DELIVERY_RETRY_BACKOFF | default "30s" | quote }}
  DISPATCH_MAX_AUTO_ATTEMPTS: {{ $cm.DISPATCH_MAX_AUTO_ATTEMPTS | default "8" | quote }}
  DISPATCH_RETRY_BACKOFF_CEILING: {{ $cm.DISPATCH_RETRY_BACKOFF_CEILING | default "30m" | quote }}

  # RATE LIMIT
  RATE_LIMIT_IP_MAX: {{ $cm.RATE_LIMIT_IP_MAX | default "300" | quote }}
  RATE_LIMIT_IP_WINDOW: {{ $cm.RATE_LIMIT_IP_WINDOW | default "1m" | quote }}
  RATE_LIMIT_KEY_MAX: {{ $cm.RATE_LIMIT_KEY_MAX | default "100" | quote }}
  RATE_LIMIT_KEY_WINDOW: {{ $cm.RATE_LIMIT_KEY_WINDOW | default "1m" | quote }}

  # IDEMPOTENCY
  IDEMPOTENCY_ENABLED: {{ $cm.IDEMPOTENCY_ENABLED | default "true" | quote }}
  IDEMPOTENCY_DEFAULT_TTL_SEC: {{ $cm.IDEMPOTENCY_DEFAULT_TTL_SEC | default "300" | quote }}

  # EMISSION APPROVAL (alcada maker-checker; OFF by default)
  APPROVAL_ALCADA_BANDS: {{ $cm.APPROVAL_ALCADA_BANDS | default "" | quote }}
  APPROVAL_DEADLINE_WINDOW: {{ $cm.APPROVAL_DEADLINE_WINDOW | default "" | quote }}
  APPROVAL_EXPIRY_ENABLED: {{ $cm.APPROVAL_EXPIRY_ENABLED | default "true" | quote }}
  APPROVAL_EXPIRY_SWEEP_INTERVAL: {{ $cm.APPROVAL_EXPIRY_SWEEP_INTERVAL | default "1m" | quote }}
{{- end }}

{{/*
spbConfigmap — the single SPB ConfigMap (productized surface + escape hatch).
Input dict: root, name, comp, port.
*/}}
{{- define "br-sfn.spbConfigmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "br-sfn.componentFullname" (dict "root" .root "name" .name) }}
  namespace: {{ include "global.namespace" .root }}
  labels:
    {{- include "br-sfn.componentLabels" (dict "root" .root "name" .name) | nindent 4 }}
data:
{{ include "br-sfn.spbConfigData" (dict "root" .root "comp" .comp "port" .port) }}
{{- end }}

{{/*
=============================================================================
silocConfigData — the productized SILOC (Núclea card settlement) ConfigMap body.

SINGLE deployment. Native DB naming is DB_* and REDIS_ADDRESS and AUTH_* (NOT the
POSTGRES_* and PLUGIN_AUTH_* of spi/spb) — the datastore and global masks absorb
that via nativeKey. Dependency CONNECTIONS are typed knobs (Postgres + Redis via
datastore.value; observability + auth via globalValue over global.observability/
global.auth); everything else is escape-hatch passthrough. Credentials -> Secret.

siloc has NO broker/streaming/SD/multiTenant/objectStorage/kms env contract (the
IBM MQ SILOC leg is plain passthrough, like spb's STR_MQ_*).

Input dict: root ($), comp (.Values.siloc), port (service port; SERVER_PORT defaults to it).
=============================================================================
*/}}
{{- define "br-sfn.silocConfigData" -}}
{{- $root := .root -}}
{{- $ds := $root.Values.siloc.datastores | default dict -}}
{{- $port := .port -}}
{{- $cm := deepCopy (.comp.configmap | default dict) -}}
{{- /* Backward-compat: pre-productization siloc had no fixed native keys (pure
   passthrough), so upgrading operators may have set the legacy POSTGRES_HOST,
   POSTGRES_PORT and REDIS_HOST names used by every other rail's migration-job
   convention. Accept them as a fallback when the productized native key
   (DB_HOST, DB_PORT, REDIS_ADDRESS) is unset, so an old values.yaml keeps
   working functionally, not just schema-valid. */ -}}
{{- if and (not (hasKey $cm "DB_HOST")) (hasKey $cm "POSTGRES_HOST") -}}
{{- $cm = set $cm "DB_HOST" (index $cm "POSTGRES_HOST") -}}
{{- end -}}
{{- if and (not (hasKey $cm "DB_PORT")) (hasKey $cm "POSTGRES_PORT") -}}
{{- $cm = set $cm "DB_PORT" (index $cm "POSTGRES_PORT") -}}
{{- end -}}
{{- if and (not (hasKey $cm "REDIS_ADDRESS")) (hasKey $cm "REDIS_HOST") -}}
{{- $cm = set $cm "REDIS_ADDRESS" (index $cm "REDIS_HOST") -}}
{{- end -}}
  # =============================================================================
  # DATABASE — PostgreSQL (native DB_*; host/port/user/name/ssl/replicaHost via
  # datastore mask). DB_PASSWORD -> Secret.
  # =============================================================================
  DB_HOST: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "host" "nativeKey" "DB_HOST" "default" "") | quote }}
  DB_PORT: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "port" "nativeKey" "DB_PORT" "default" "5432") | quote }}
  DB_USER: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "user" "nativeKey" "DB_USER" "default" "") | quote }}
  DB_NAME: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "name" "nativeKey" "DB_NAME" "default" "") | quote }}
  DB_SSLMODE: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "ssl" "nativeKey" "DB_SSLMODE" "default" "disable") | quote }}
  # ALLOW_INSECURE_TLS (lib-commons bypass to accept a non-TLS Postgres/Redis; dev/dev-st
  # only). SECURE default false; NEVER default true. Set <rail>.configmap.ALLOW_INSECURE_TLS=true only in dev.
  ALLOW_INSECURE_TLS: {{ $cm.ALLOW_INSECURE_TLS | default "false" | quote }}
  DB_REPLICA_HOST: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "replicaHost" "nativeKey" "DB_REPLICA_HOST" "default" "") | quote }}

  # REDIS / Valkey (native REDIS_ADDRESS via datastore host mask). REDIS_PASSWORD -> Secret.
  REDIS_ADDRESS: {{ include "br-sfn.redisComposedAddr" (dict "root" $root "ds" $ds "cm" $cm "hostKey" "REDIS_ADDRESS" "hostDefault" "") | quote }}
  REDIS_DB: {{ $cm.REDIS_DB | default "0" | quote }}
  REDIS_TLS: {{ $cm.REDIS_TLS | default "false" | quote }}

  # =============================================================================
  # OBSERVABILITY — ENABLE_TELEMETRY / OTLP endpoint via global.observability
  # (siloc uses SERVICE_NAME for identity; no OTEL_RESOURCE_* keys).
  # =============================================================================
  ENABLE_TELEMETRY: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "observability" "field" "enabled" "nativeKey" "ENABLE_TELEMETRY" "default" "false") | quote }}
  OTEL_EXPORTER_OTLP_ENDPOINT: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "observability" "field" "otlpEndpoint" "nativeKey" "OTEL_EXPORTER_OTLP_ENDPOINT" "default" "") | quote }}

  # =============================================================================
  # AUTH (lib-auth plugin) — enable/host via global.auth. Native keys AUTH_ENABLED
  # (default true, default-closed) / AUTH_ADDRESS.
  # =============================================================================
  AUTH_ENABLED: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "auth" "field" "enabled" "nativeKey" "AUTH_ENABLED" "default" "true") | quote }}
  AUTH_ADDRESS: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "auth" "field" "host" "nativeKey" "AUTH_ADDRESS" "default" "") | quote }}

  # SERVER_PORT defaults to the service port so the app listens where the Service/probes target.
  SERVER_PORT: {{ $cm.SERVER_PORT | default (printf "%v" $port) | quote }}

  # APP / SERVER
  SERVICE_NAME: {{ $cm.SERVICE_NAME | default "br-siloc" | quote }}
  ENV_NAME: {{ $cm.ENV_NAME | default "development" | quote }}
  LOG_LEVEL: {{ $cm.LOG_LEVEL | default "info" | quote }}
  DEPLOYMENT_MODE: {{ $cm.DEPLOYMENT_MODE | default "" | quote }}
  CERT_READINESS_MIN_DAYS: {{ $cm.CERT_READINESS_MIN_DAYS | default "30" | quote }}
  CAMARA_PAG_ISPB: {{ $cm.CAMARA_PAG_ISPB | default "02992335" | quote }}

  # IBM MQ — Núclea SILOC settlement leg (single QM; plain passthrough)
  MQ_HOST: {{ $cm.MQ_HOST | default "" | quote }}
  MQ_PORT: {{ $cm.MQ_PORT | default "" | quote }}
  MQ_CHANNEL: {{ $cm.MQ_CHANNEL | default "" | quote }}
  MQ_QUEUE_MANAGER: {{ $cm.MQ_QUEUE_MANAGER | default "" | quote }}
  MQ_SEND_QUEUE: {{ $cm.MQ_SEND_QUEUE | default "" | quote }}
  MQ_RECEIVE_QUEUE: {{ $cm.MQ_RECEIVE_QUEUE | default "" | quote }}
  MQ_TLS_ENABLED: {{ $cm.MQ_TLS_ENABLED | default "false" | quote }}
  MQ_SSL_KEY_REPOSITORY: {{ $cm.MQ_SSL_KEY_REPOSITORY | default "" | quote }}

  # SFN CUSTODY / TRUST (file paths + cache tuning)
  SFN_TRUST_MANIFEST_PATH: {{ $cm.SFN_TRUST_MANIFEST_PATH | default "" | quote }}
  SFN_CUSTODY_CONFIG_PATH: {{ $cm.SFN_CUSTODY_CONFIG_PATH | default "" | quote }}
  SFN_CUSTODY_CACHE_ENTRIES: {{ $cm.SFN_CUSTODY_CACHE_ENTRIES | default "16" | quote }}
{{- end }}

{{/*
silocMigrationConfig — POSTGRES_* env for the dedicated br-siloc-migrations image,
mapped from the SAME postgres datastore mask the app DB_* reads (nativeKey DB_*).
So one operator mask (siloc.datastores.postgres / global.datastores.postgres) feeds
BOTH the app (DB_*) and the migrator (POSTGRES_*). Fed to componentMigrationJob via
configDataOverride; its migrationPgValue reads these POSTGRES_* keys.
Input dict: root ($).
*/}}
{{- define "br-sfn.silocMigrationConfig" -}}
{{- $root := .root -}}
{{- $ds := $root.Values.siloc.datastores | default dict -}}
{{- $cm := deepCopy ($root.Values.siloc.configmap | default dict) -}}
{{- /* Same legacy alias as silocConfigData — keep the dedicated migrator's view
   of DB_HOST/DB_PORT consistent with the app's view. */ -}}
{{- if and (not (hasKey $cm "DB_HOST")) (hasKey $cm "POSTGRES_HOST") -}}
{{- $cm = set $cm "DB_HOST" (index $cm "POSTGRES_HOST") -}}
{{- end -}}
{{- if and (not (hasKey $cm "DB_PORT")) (hasKey $cm "POSTGRES_PORT") -}}
{{- $cm = set $cm "DB_PORT" (index $cm "POSTGRES_PORT") -}}
{{- end -}}
POSTGRES_HOST: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "host" "nativeKey" "DB_HOST" "default" "") | quote }}
POSTGRES_PORT: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "port" "nativeKey" "DB_PORT" "default" "5432") | quote }}
POSTGRES_USER: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "user" "nativeKey" "DB_USER" "default" "") | quote }}
POSTGRES_DB: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "name" "nativeKey" "DB_NAME" "default" "") | quote }}
POSTGRES_SSLMODE: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "ssl" "nativeKey" "DB_SSLMODE" "default" "disable") | quote }}
{{- end }}

{{/*
silocConfigmap — the single SILOC ConfigMap. Input dict: root, name, comp, port.
*/}}
{{- define "br-sfn.silocConfigmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "br-sfn.componentFullname" (dict "root" .root "name" .name) }}
  namespace: {{ include "global.namespace" .root }}
  labels:
    {{- include "br-sfn.componentLabels" (dict "root" .root "name" .name) | nindent 4 }}
data:
{{ include "br-sfn.silocConfigData" (dict "root" .root "comp" .comp "port" .port) }}
{{- end }}

{{/*
=============================================================================
scrConfigData — the productized SCR (Sistema de Informacoes de Credito) body.

SINGLE deployment. Dependency CONNECTIONS are typed knobs (Postgres + Redis via
datastore.value; observability + auth via globalValue; MULTI-TENANT via
lerian-common.multiTenant.env). App and migrator BOTH use POSTGRES_* (no mapper).

STREAMING NOTE: scr reaches RedPanda through lib-streaming but exposes its own
SCR_STREAMING_* env names (NOT lib-streaming's canonical STREAMING_* contract that
lerian-common.streaming.env emits) — so the helper does not fit and these stay
escape-hatch passthrough (all non-secret; no SASL/password key). Recorded as a
lerian-common gap, not hand-rolled as a bespoke knob.

Input dict: root ($), comp (.Values.scr), port (service port; SERVER_PORT defaults to it).
=============================================================================
*/}}
{{- define "br-sfn.scrConfigData" -}}
{{- $root := .root -}}
{{- $ds := $root.Values.scr.datastores | default dict -}}
{{- $port := .port -}}
{{- $cm := .comp.configmap | default dict -}}
  # =============================================================================
  # DATABASE — PostgreSQL (host/port/user/db/ssl via datastore mask; pool tuning
  # passthrough below). POSTGRES_PASSWORD -> Secret. No read replica in scr.
  # =============================================================================
  POSTGRES_HOST: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "host" "nativeKey" "POSTGRES_HOST" "default" "localhost") | quote }}
  POSTGRES_PORT: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "port" "nativeKey" "POSTGRES_PORT" "default" "5432") | quote }}
  POSTGRES_USER: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "user" "nativeKey" "POSTGRES_USER" "default" "scr") | quote }}
  POSTGRES_DB: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "name" "nativeKey" "POSTGRES_DB" "default" "scr") | quote }}
  POSTGRES_SSLMODE: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "ssl" "nativeKey" "POSTGRES_SSLMODE" "default" "disable") | quote }}
  # ALLOW_INSECURE_TLS (lib-commons bypass to accept a non-TLS Postgres/Redis; dev/dev-st
  # only). SECURE default false; NEVER default true. Set <rail>.configmap.ALLOW_INSECURE_TLS=true only in dev.
  ALLOW_INSECURE_TLS: {{ $cm.ALLOW_INSECURE_TLS | default "false" | quote }}

  # REDIS / Valkey (host+port via datastore mask; tuning passthrough below). REDIS_PASSWORD -> Secret.
  REDIS_HOST: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "redis" "field" "host" "nativeKey" "REDIS_HOST" "default" "localhost") | quote }}
  REDIS_PORT: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "redis" "field" "port" "nativeKey" "REDIS_PORT" "default" "6379") | quote }}

  # =============================================================================
  # MULTI-TENANT — knob inline; gated block (URL only, required when enabled) via
  # lerian-common.multiTenant.env. MULTI_TENANT_SERVICE_API_KEY -> Secret.
  # =============================================================================
  {{- $mtEnabled := eq ($cm.MULTI_TENANT_ENABLED | default "false" | toString) "true" }}
  MULTI_TENANT_ENABLED: {{ $cm.MULTI_TENANT_ENABLED | default "false" | quote }}
  {{- include "lerian-common.multiTenant.env" (dict "context" $root "configmap" $cm "enabled" $mtEnabled "requiredUrl" true "circuitBreaker" false) | nindent 2 }}

  # =============================================================================
  # OBSERVABILITY — ENABLE_TELEMETRY / OTLP endpoint via global.observability
  # (scr uses SERVICE_NAME for identity; Prometheus scrape passthrough below).
  # =============================================================================
  ENABLE_TELEMETRY: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "observability" "field" "enabled" "nativeKey" "ENABLE_TELEMETRY" "default" "false") | quote }}
  OTEL_EXPORTER_OTLP_ENDPOINT: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "observability" "field" "otlpEndpoint" "nativeKey" "OTEL_EXPORTER_OTLP_ENDPOINT" "default" "") | quote }}

  # =============================================================================
  # AUTH (lib-auth M2M) — enable/host via global.auth.
  # =============================================================================
  PLUGIN_AUTH_ENABLED: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "auth" "field" "enabled" "nativeKey" "PLUGIN_AUTH_ENABLED" "default" "false") | quote }}
  PLUGIN_AUTH_ADDRESS: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "auth" "field" "host" "nativeKey" "PLUGIN_AUTH_ADDRESS" "default" "http://localhost:4000") | quote }}

  # SERVER_PORT defaults to the service port so the app listens where the Service/probes target.
  SERVER_PORT: {{ $cm.SERVER_PORT | default (printf "%v" $port) | quote }}

  # APP / SERVER
  SERVICE_NAME: {{ $cm.SERVICE_NAME | default "br-scr" | quote }}
  ENV_NAME: {{ $cm.ENV_NAME | default "development" | quote }}
  LOG_LEVEL: {{ $cm.LOG_LEVEL | default "info" | quote }}
  DEPLOYMENT_MODE: {{ $cm.DEPLOYMENT_MODE | default "local" | quote }}
  TRUSTED_PROXIES: {{ $cm.TRUSTED_PROXIES | default "" | quote }}
  PROXY_HEADER: {{ $cm.PROXY_HEADER | default "X-Forwarded-For" | quote }}

  # POSTGRES tuning (host/port/user/db/ssl via datastore mask above)
  POSTGRES_MAX_OPEN_CONNS: {{ $cm.POSTGRES_MAX_OPEN_CONNS | default "25" | quote }}
  POSTGRES_MAX_IDLE_CONNS: {{ $cm.POSTGRES_MAX_IDLE_CONNS | default "10" | quote }}
  POSTGRES_CONN_LIFETIME: {{ $cm.POSTGRES_CONN_LIFETIME | default "30m" | quote }}
  POSTGRES_CONN_IDLE_TIME: {{ $cm.POSTGRES_CONN_IDLE_TIME | default "5m" | quote }}

  # REDIS tuning (host/port via datastore mask above)
  REDIS_TLS_ENABLED: {{ $cm.REDIS_TLS_ENABLED | default "false" | quote }}
  SCR_REDIS_DISABLED: {{ $cm.SCR_REDIS_DISABLED | default "false" | quote }}

  # STREAMING (SCR_STREAMING_* — app-prefixed; lib-streaming helper does NOT fit this naming, so escape-hatch passthrough — see lerian-common gap)
  SCR_STREAMING_BROKERS: {{ $cm.SCR_STREAMING_BROKERS | default "" | quote }}
  SCR_STREAMING_TOPIC: {{ $cm.SCR_STREAMING_TOPIC | default "br-scr.consulta" | quote }}
  SCR_STREAMING_CLIENT_ID: {{ $cm.SCR_STREAMING_CLIENT_ID | default "br-scr" | quote }}
  SCR_STREAMING_SOURCE: {{ $cm.SCR_STREAMING_SOURCE | default "//br-scr" | quote }}
  SCR_STREAMING_TLS: {{ $cm.SCR_STREAMING_TLS | default "false" | quote }}
  SCR_STREAMING_EMISSION_DISABLED: {{ $cm.SCR_STREAMING_EMISSION_DISABLED | default "false" | quote }}

  # wsscr2n outbound (BACEN SCR3 consulta)
  SCR_WSSCR2N_BASE_URL: {{ $cm.SCR_WSSCR2N_BASE_URL | default "http://localhost:8080/wsscr2n" | quote }}
  SCR_WSSCR2N_BASIC_USER: {{ $cm.SCR_WSSCR2N_BASIC_USER | default "UUUUUDDDD.OPERADOR" | quote }}

  # SECRET STORE (vault selection; ADR-005)
  {{- /* Default empty, NOT "env": the app treats an empty/unset SECRET_STORE_KIND as
     the "env" backing (config.go defaultSecretStoreKind = SecretStoreKindEnv), so an
     empty default is behaviour-identical AND keeps this SECRET-named selector off the
     chart-standard template-default-secret gate (it is a store-kind selector, not a
     credential). Operators pick "aws" via scr.configmap.SECRET_STORE_KIND. */}}
  SECRET_STORE_KIND: {{ $cm.SECRET_STORE_KIND | default "" | quote }}
  AWS_REGION: {{ $cm.AWS_REGION | default "" | quote }}
  SECRET_STORE_PREFIX: {{ $cm.SECRET_STORE_PREFIX | default "" | quote }}

  # METRICS (Prometheus scrape; OTLP/enable via global.observability)
  METRICS_PROMETHEUS_ENABLED: {{ $cm.METRICS_PROMETHEUS_ENABLED | default "false" | quote }}
  METRICS_PROMETHEUS_ADDRESS: {{ $cm.METRICS_PROMETHEUS_ADDRESS | default "127.0.0.1:9075" | quote }}
{{- end }}

{{/*
scrConfigmap — the single SCR ConfigMap. Input dict: root, name, comp, port.
*/}}
{{- define "br-sfn.scrConfigmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "br-sfn.componentFullname" (dict "root" .root "name" .name) }}
  namespace: {{ include "global.namespace" .root }}
  labels:
    {{- include "br-sfn.componentLabels" (dict "root" .root "name" .name) | nindent 4 }}
data:
{{ include "br-sfn.scrConfigData" (dict "root" .root "comp" .comp "port" .port) }}
{{- end }}

{{/*
=============================================================================
deskConfigData — the productized DESK (cabine operator-state / four-eyes) body.

SINGLE deployment. Native DB naming is DB_* (like siloc, NOT POSTGRES_*); the
mask absorbs it via nativeKey and deskMigrationConfig re-maps it to POSTGRES_* for
the baked migrator. Dependency CONNECTIONS: Postgres via datastore.value;
observability + auth via globalValue. desk has NO Redis/broker/streaming/MT.

AUTH is dual: the inbound lib-auth middleware (PLUGIN_AUTH_ENABLED/ADDRESS) AND an
outbound M2M client to access-manager (PLUGIN_ACCESS_MANAGER_URL/CLIENT_ID/SECRET,
for the four-eyes user-deletion call). enable + all three host-ish URLs resolve
from global.auth (enabled + host); the M2M CLIENT_ID is a non-secret identity
passthrough and CLIENT_SECRET is a Secret (the auth helper contract covers only
enabled/host, so the M2M credential is handled by the secret rule, not a knob).

Input dict: root ($), comp (.Values.desk), port (service port; SERVER_PORT defaults to it).
=============================================================================
*/}}
{{- define "br-sfn.deskConfigData" -}}
{{- $root := .root -}}
{{- $ds := $root.Values.desk.datastores | default dict -}}
{{- $port := .port -}}
{{- $cm := deepCopy (.comp.configmap | default dict) -}}
{{- /* Backward-compat: pre-productization desk had no fixed native keys (pure
   passthrough), so upgrading operators may have set the POSTGRES_* names used
   by every other rail's migration-job convention. Accept them as a fallback
   when the productized native key (DB_*) is unset. */ -}}
{{- if and (not (hasKey $cm "DB_HOST")) (hasKey $cm "POSTGRES_HOST") -}}
{{- $cm = set $cm "DB_HOST" (index $cm "POSTGRES_HOST") -}}
{{- end -}}
{{- if and (not (hasKey $cm "DB_PORT")) (hasKey $cm "POSTGRES_PORT") -}}
{{- $cm = set $cm "DB_PORT" (index $cm "POSTGRES_PORT") -}}
{{- end -}}
  # =============================================================================
  # DATABASE — PostgreSQL (native DB_*; host/port/user/name/ssl via datastore mask;
  # pool tuning passthrough). DB_PASSWORD -> Secret. No read replica.
  # =============================================================================
  DB_HOST: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "host" "nativeKey" "DB_HOST" "default" "localhost") | quote }}
  DB_PORT: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "port" "nativeKey" "DB_PORT" "default" "5432") | quote }}
  DB_USER: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "user" "nativeKey" "DB_USER" "default" "desk") | quote }}
  DB_NAME: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "name" "nativeKey" "DB_NAME" "default" "desk") | quote }}
  DB_SSLMODE: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "ssl" "nativeKey" "DB_SSLMODE" "default" "disable") | quote }}
  # ALLOW_INSECURE_TLS (lib-commons bypass to accept a non-TLS Postgres/Redis; dev/dev-st
  # only). SECURE default false; NEVER default true. Set <rail>.configmap.ALLOW_INSECURE_TLS=true only in dev.
  ALLOW_INSECURE_TLS: {{ $cm.ALLOW_INSECURE_TLS | default "false" | quote }}
  DB_MAX_OPEN_CONNS: {{ $cm.DB_MAX_OPEN_CONNS | default "25" | quote }}
  DB_MAX_IDLE_CONNS: {{ $cm.DB_MAX_IDLE_CONNS | default "10" | quote }}
  DB_CONN_MAX_LIFETIME: {{ $cm.DB_CONN_MAX_LIFETIME | default "10m" | quote }}
  DB_CONN_MAX_IDLE_TIME: {{ $cm.DB_CONN_MAX_IDLE_TIME | default "5m" | quote }}

  # =============================================================================
  # OBSERVABILITY — ENABLE_TELEMETRY / OTLP endpoint via global.observability
  # (desk uses SERVICE_NAME for identity; Prometheus scrape passthrough).
  # =============================================================================
  ENABLE_TELEMETRY: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "observability" "field" "enabled" "nativeKey" "ENABLE_TELEMETRY" "default" "false") | quote }}
  OTEL_EXPORTER_OTLP_ENDPOINT: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "observability" "field" "otlpEndpoint" "nativeKey" "OTEL_EXPORTER_OTLP_ENDPOINT" "default" "") | quote }}
  METRICS_PROMETHEUS_ENABLED: {{ $cm.METRICS_PROMETHEUS_ENABLED | default "false" | quote }}
  METRICS_PROMETHEUS_ADDRESS: {{ $cm.METRICS_PROMETHEUS_ADDRESS | default "127.0.0.1:9074" | quote }}

  # =============================================================================
  # AUTH — inbound middleware + outbound M2M to access-manager. enable + host(s)
  # via global.auth. CLIENT_SECRET -> Secret; CLIENT_ID is a non-secret passthrough.
  # =============================================================================
  PLUGIN_AUTH_ENABLED: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "auth" "field" "enabled" "nativeKey" "PLUGIN_AUTH_ENABLED" "default" "false") | quote }}
  PLUGIN_AUTH_ADDRESS: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "auth" "field" "host" "nativeKey" "PLUGIN_AUTH_ADDRESS" "default" "") | quote }}
  PLUGIN_ACCESS_MANAGER_URL: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "auth" "field" "host" "nativeKey" "PLUGIN_ACCESS_MANAGER_URL" "default" "") | quote }}
  PLUGIN_ACCESS_MANAGER_CLIENT_ID: {{ $cm.PLUGIN_ACCESS_MANAGER_CLIENT_ID | default "" | quote }}

  # SERVER_PORT defaults to the service port so the app listens where the Service/probes target.
  SERVER_PORT: {{ $cm.SERVER_PORT | default (printf "%v" $port) | quote }}

  # APP / SERVER
  SERVICE_NAME: {{ $cm.SERVICE_NAME | default "br-desk" | quote }}
  ENV_NAME: {{ $cm.ENV_NAME | default "development" | quote }}
  LOG_LEVEL: {{ $cm.LOG_LEVEL | default "info" | quote }}
  DEPLOYMENT_MODE: {{ $cm.DEPLOYMENT_MODE | default "local" | quote }}

  # CORS (cockpit SPA) + ACK workflow (OS.2)
  DESK_CORS_ALLOWED_ORIGINS: {{ $cm.DESK_CORS_ALLOWED_ORIGINS | default "http://localhost:5173" | quote }}
  DESK_ACK_TTL: {{ $cm.DESK_ACK_TTL | default "720h" | quote }}
  DESK_ACK_GC_INTERVAL: {{ $cm.DESK_ACK_GC_INTERVAL | default "1h" | quote }}
{{- end }}

{{/*
deskMigrationConfig — POSTGRES_* for the baked migrator, mapped from the SAME
postgres mask the app DB_* reads (nativeKey DB_*). col-0 (fromYaml). See siloc.
Input dict: root ($).
*/}}
{{- define "br-sfn.deskMigrationConfig" -}}
{{- $root := .root -}}
{{- $ds := $root.Values.desk.datastores | default dict -}}
{{- $cm := deepCopy ($root.Values.desk.configmap | default dict) -}}
{{- /* Same legacy alias as deskConfigData — keep the baked migrator's view of
   DB_HOST/DB_PORT consistent with the app's view. */ -}}
{{- if and (not (hasKey $cm "DB_HOST")) (hasKey $cm "POSTGRES_HOST") -}}
{{- $cm = set $cm "DB_HOST" (index $cm "POSTGRES_HOST") -}}
{{- end -}}
{{- if and (not (hasKey $cm "DB_PORT")) (hasKey $cm "POSTGRES_PORT") -}}
{{- $cm = set $cm "DB_PORT" (index $cm "POSTGRES_PORT") -}}
{{- end -}}
POSTGRES_HOST: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "host" "nativeKey" "DB_HOST" "default" "localhost") | quote }}
POSTGRES_PORT: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "port" "nativeKey" "DB_PORT" "default" "5432") | quote }}
POSTGRES_USER: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "user" "nativeKey" "DB_USER" "default" "desk") | quote }}
POSTGRES_DB: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "name" "nativeKey" "DB_NAME" "default" "desk") | quote }}
POSTGRES_SSLMODE: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "ssl" "nativeKey" "DB_SSLMODE" "default" "disable") | quote }}
{{- end }}

{{/*
deskConfigmap — the single DESK ConfigMap. Input dict: root, name, comp, port.
*/}}
{{- define "br-sfn.deskConfigmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "br-sfn.componentFullname" (dict "root" .root "name" .name) }}
  namespace: {{ include "global.namespace" .root }}
  labels:
    {{- include "br-sfn.componentLabels" (dict "root" .root "name" .name) | nindent 4 }}
data:
{{ include "br-sfn.deskConfigData" (dict "root" .root "comp" .comp "port" .port) }}
{{- end }}

{{/*
=============================================================================
correiosConfigData — the productized CORREIOS (BC Correio regulatory mailbox) body.

SINGLE deployment. Dependency CONNECTIONS: Postgres via datastore.value (native
db-name key is POSTGRES_NAME); Redis/Valkey CACHE via datastore.value (CACHE_ADDR
host:port); S3/SeaweedFS via objectStorage.value; observability + auth via
globalValue; multi-tenant url + lifecycle-redis via globalValue (block multiTenant).
App and baked migrator BOTH use POSTGRES_* (no mapper; migration dbCfgKey=POSTGRES_NAME).

NOT wired (naming does not fit a 1.4.0 helper, so escape-hatch passthrough — recorded
as gaps): RABBITMQ_URL is a full AMQP URL (embeds creds -> Secret; NOT the broker
mask's host/port/user shape); the MT tuning tail (per-tenant conn caps, event channel,
CA cert) exceeds multiTenant.env's fixed key set (wired per-key via globalValue for the
shared url/redis bits, passthrough for the rest); observability enable is split
(TRACING_ENABLED / METRICS_ENABLED), not a single ENABLE_TELEMETRY.

Input dict: root ($), comp (.Values.correios), port (service port; SERVER_PORT defaults to it).
=============================================================================
*/}}
{{- define "br-sfn.correiosConfigData" -}}
{{- $root := .root -}}
{{- $ds := $root.Values.correios.datastores | default dict -}}
{{- $os := $root.Values.correios.objectStorage | default dict -}}
{{- $port := .port -}}
{{- $cm := .comp.configmap | default dict -}}
  # =============================================================================
  # DATABASE — PostgreSQL (host/port/user/name/ssl via datastore mask; POSTGRES_NAME
  # is the db-name native key). Pool tuning passthrough. POSTGRES_PASSWORD -> Secret.
  # =============================================================================
  POSTGRES_HOST: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "host" "nativeKey" "POSTGRES_HOST" "default" "localhost") | quote }}
  POSTGRES_PORT: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "port" "nativeKey" "POSTGRES_PORT" "default" "5450") | quote }}
  POSTGRES_USER: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "user" "nativeKey" "POSTGRES_USER" "default" "plugin-bc-correios") | quote }}
  POSTGRES_NAME: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "name" "nativeKey" "POSTGRES_NAME" "default" "plugin-bc-correios") | quote }}
  POSTGRES_SSLMODE: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "ssl" "nativeKey" "POSTGRES_SSLMODE" "default" "disable") | quote }}
  # ALLOW_INSECURE_TLS (lib-commons bypass to accept a non-TLS Postgres/Redis; dev/dev-st
  # only). SECURE default false; NEVER default true. Set <rail>.configmap.ALLOW_INSECURE_TLS=true only in dev.
  ALLOW_INSECURE_TLS: {{ $cm.ALLOW_INSECURE_TLS | default "false" | quote }}

  # CACHE — Redis/Valkey (addr host:port via datastore mask). CACHE_PASSWORD -> Secret.
  CACHE_ADDR: {{ include "br-sfn.redisComposedAddr" (dict "root" $root "ds" $ds "cm" $cm "hostKey" "CACHE_ADDR" "hostDefault" "localhost:6390") | quote }}

  # OBJECT STORAGE — S3/SeaweedFS (endpoint/region/bucket/pathStyle via objectStorage mask).
  # OBJECT_STORAGE_ACCESS_KEY / _SECRET_KEY -> Secret.
  OBJECT_STORAGE_ENDPOINT: {{ include "lerian-common.objectStorage.value" (dict "context" $root "dedicated" $os "configmap" $cm "name" "default" "field" "endpoint" "nativeKey" "OBJECT_STORAGE_ENDPOINT" "default" "http://localhost:8343") | quote }}
  OBJECT_STORAGE_REGION: {{ include "lerian-common.objectStorage.value" (dict "context" $root "dedicated" $os "configmap" $cm "name" "default" "field" "region" "nativeKey" "OBJECT_STORAGE_REGION" "default" "us-east-1") | quote }}
  OBJECT_STORAGE_BUCKET: {{ include "lerian-common.objectStorage.value" (dict "context" $root "dedicated" $os "configmap" $cm "name" "default" "field" "bucket" "nativeKey" "OBJECT_STORAGE_BUCKET" "default" "bc-correios-attachments") | quote }}
  OBJECT_STORAGE_PATH_STYLE: {{ include "lerian-common.objectStorage.value" (dict "context" $root "dedicated" $os "configmap" $cm "name" "default" "field" "usePathStyle" "nativeKey" "OBJECT_STORAGE_PATH_STYLE" "default" "true") | quote }}

  # OBSERVABILITY — OTLP endpoint + deployment-env via global.observability (identity + enables passthrough).
  OTEL_EXPORTER_OTLP_ENDPOINT: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "observability" "field" "otlpEndpoint" "nativeKey" "OTEL_EXPORTER_OTLP_ENDPOINT" "default" "http://localhost:4337") | quote }}
  OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "observability" "field" "deploymentEnvironment" "nativeKey" "OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT" "default" "development") | quote }}

  # AUTH — enable/host via global.auth (lib-auth/v2).
  PLUGIN_AUTH_ENABLED: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "auth" "field" "enabled" "nativeKey" "PLUGIN_AUTH_ENABLED" "default" "false") | quote }}
  PLUGIN_AUTH_ADDRESS: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "auth" "field" "host" "nativeKey" "PLUGIN_AUTH_ADDRESS" "default" "") | quote }}

  # MULTI-TENANT — ENABLED knob inline; url + tenant-lifecycle redis via global.multiTenant.
  # SERVICE_API_KEY + REDIS_PASSWORD -> Secret. Tuning tail passthrough below.
  MULTI_TENANT_ENABLED: {{ $cm.MULTI_TENANT_ENABLED | default "false" | quote }}
  MULTI_TENANT_URL: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "multiTenant" "field" "url" "nativeKey" "MULTI_TENANT_URL" "default" "") | quote }}
  MULTI_TENANT_REDIS_HOST: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "multiTenant" "field" "redisHost" "nativeKey" "MULTI_TENANT_REDIS_HOST" "default" "") | quote }}
  MULTI_TENANT_REDIS_PORT: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "multiTenant" "field" "redisPort" "nativeKey" "MULTI_TENANT_REDIS_PORT" "default" "6379") | quote }}
  MULTI_TENANT_REDIS_TLS: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "multiTenant" "field" "redisTls" "nativeKey" "MULTI_TENANT_REDIS_TLS" "default" "false") | quote }}

  # SERVER_PORT defaults to the service port so the app listens where the Service/probes target.
  SERVER_PORT: {{ $cm.SERVER_PORT | default (printf "%v" $port) | quote }}

  # APP / SERVER
  APP_NAME: {{ $cm.APP_NAME | default "br-correios" | quote }}
  APP_VERSION: {{ $cm.APP_VERSION | default "0.1.0" | quote }}
  ENV_NAME: {{ $cm.ENV_NAME | default "development" | quote }}
  LOG_LEVEL: {{ $cm.LOG_LEVEL | default "info" | quote }}
  DEPLOYMENT_MODE: {{ $cm.DEPLOYMENT_MODE | default "local" | quote }}
  SERVER_READ_TIMEOUT_SEC: {{ $cm.SERVER_READ_TIMEOUT_SEC | default "30" | quote }}
  SERVER_WRITE_TIMEOUT_SEC: {{ $cm.SERVER_WRITE_TIMEOUT_SEC | default "30" | quote }}
  SERVER_SHUTDOWN_TIMEOUT_SEC: {{ $cm.SERVER_SHUTDOWN_TIMEOUT_SEC | default "30" | quote }}
  TRUSTED_PROXIES: {{ $cm.TRUSTED_PROXIES | default "127.0.0.1,::1" | quote }}
  ALLOWED_ORIGINS: {{ $cm.ALLOWED_ORIGINS | default "*" | quote }}

  # POSTGRES tuning (host/port/user/name/ssl via datastore mask above)
  POSTGRES_MAX_CONNS: {{ $cm.POSTGRES_MAX_CONNS | default "50" | quote }}
  POSTGRES_MIN_CONNS: {{ $cm.POSTGRES_MIN_CONNS | default "5" | quote }}

  # CACHE tuning (addr via datastore redis mask above; CACHE_PASSWORD -> Secret)
  CACHE_DB: {{ $cm.CACHE_DB | default "0" | quote }}
  CACHE_TLS: {{ $cm.CACHE_TLS | default "false" | quote }}
  CACHE_CA_CERT: {{ $cm.CACHE_CA_CERT | default "" | quote }}
  CACHE_TTL_SEC: {{ $cm.CACHE_TTL_SEC | default "60" | quote }}
  CACHE_POOL_SIZE: {{ $cm.CACHE_POOL_SIZE | default "10" | quote }}
  CACHE_MAX_ACTIVE_CONNS: {{ $cm.CACHE_MAX_ACTIVE_CONNS | default "20" | quote }}

  # RABBITMQ (URL embeds creds -> Secret; user non-secret passthrough)
  RABBITMQ_USER: {{ $cm.RABBITMQ_USER | default "CHANGE_ME_USER" | quote }}

  # OBJECT STORAGE (endpoint/region/bucket/pathStyle via mask above; keys -> Secret)
  OBJECT_STORAGE_PROVIDER: {{ $cm.OBJECT_STORAGE_PROVIDER | default "s3" | quote }}
  OBJECT_STORAGE_LOCAL_PATH: {{ $cm.OBJECT_STORAGE_LOCAL_PATH | default "/data/bc-correios/storage" | quote }}

  # LICENSE (lib-license-go; LICENSE_KEY -> Secret)
  LICENSE_VALIDATION_DISABLED: {{ $cm.LICENSE_VALIDATION_DISABLED | default "false" | quote }}
  ORGANIZATION_IDS: {{ $cm.ORGANIZATION_IDS | default "global" | quote }}
  READYZ_LICENSE_TIMEOUT_SECONDS: {{ $cm.READYZ_LICENSE_TIMEOUT_SECONDS | default "5" | quote }}

  # AUTH extras (enable/host via global.auth; CLIENT_SECRET -> Secret)
  PLUGIN_AUTH_CLIENT_ID: {{ $cm.PLUGIN_AUTH_CLIENT_ID | default "plugin-bc-correios" | quote }}
  DEFAULT_TENANT_ID: {{ $cm.DEFAULT_TENANT_ID | default "00000000-0000-0000-0000-000000000001" | quote }}
  MARK_VERIFIED_PANIC: {{ $cm.MARK_VERIFIED_PANIC | default "false" | quote }}

  # MULTI-TENANT tuning (ENABLED knob + url/redis via global.multiTenant above; API_KEY/REDIS_PASSWORD -> Secret)
  MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD: {{ $cm.MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD | default "5" | quote }}
  MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC: {{ $cm.MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC | default "30" | quote }}
  MULTI_TENANT_MAX_TENANT_POOLS: {{ $cm.MULTI_TENANT_MAX_TENANT_POOLS | default "100" | quote }}
  MULTI_TENANT_IDLE_TIMEOUT_SEC: {{ $cm.MULTI_TENANT_IDLE_TIMEOUT_SEC | default "300" | quote }}
  MULTI_TENANT_MAX_OPEN_CONNS_PER_TENANT: {{ $cm.MULTI_TENANT_MAX_OPEN_CONNS_PER_TENANT | default "0" | quote }}
  MULTI_TENANT_MAX_IDLE_CONNS_PER_TENANT: {{ $cm.MULTI_TENANT_MAX_IDLE_CONNS_PER_TENANT | default "0" | quote }}
  MULTI_TENANT_ALLOW_INSECURE_HTTP: {{ $cm.MULTI_TENANT_ALLOW_INSECURE_HTTP | default "false" | quote }}
  MULTI_TENANT_EVENT_CHANNEL: {{ $cm.MULTI_TENANT_EVENT_CHANNEL | default "tenant-events" | quote }}
  MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC: {{ $cm.MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC | default "30" | quote }}
  MULTI_TENANT_REDIS_CA_CERT: {{ $cm.MULTI_TENANT_REDIS_CA_CERT | default "" | quote }}
  MT_FAIL_CLOSED_ON_MISSING_CTX: {{ $cm.MT_FAIL_CLOSED_ON_MISSING_CTX | default "true" | quote }}
  SYSTEMPLANE_LAZY_MIGRATE: {{ $cm.SYSTEMPLANE_LAZY_MIGRATE | default "true" | quote }}

  # RATE LIMIT
  RATE_LIMIT_ENABLED: {{ $cm.RATE_LIMIT_ENABLED | default "true" | quote }}
  ALLOW_RATELIMIT_FAIL_OPEN: {{ $cm.ALLOW_RATELIMIT_FAIL_OPEN | default "false" | quote }}
  RATE_LIMIT_REDIS_TIMEOUT_MS: {{ $cm.RATE_LIMIT_REDIS_TIMEOUT_MS | default "500" | quote }}

  # BCB SOAP (third-party Correios/BCB outbound; base URL override is BC_CORREIO_ENDPOINT_URL, allowlisted)
  BC_CORREIO_ENVIRONMENT: {{ $cm.BC_CORREIO_ENVIRONMENT | default "mock" | quote }}
  BC_CORREIO_TLS_MIN_VERSION: {{ $cm.BC_CORREIO_TLS_MIN_VERSION | default "TLSv1.2" | quote }}
  BC_CORREIO_CONNECT_TIMEOUT_SEC: {{ $cm.BC_CORREIO_CONNECT_TIMEOUT_SEC | default "30" | quote }}

  # ENCRYPTION — ENCRYPTION_KEY -> Secret (no config here)

  # OBSERVABILITY (OTLP endpoint/deployment-env via global.observability; identity + enables passthrough)
  TRACING_ENABLED: {{ $cm.TRACING_ENABLED | default "false" | quote }}
  METRICS_ENABLED: {{ $cm.METRICS_ENABLED | default "false" | quote }}
  OTEL_SERVICE_NAME: {{ $cm.OTEL_SERVICE_NAME | default "br-correios" | quote }}
  OTEL_LIBRARY_NAME: {{ $cm.OTEL_LIBRARY_NAME | default "br-correios" | quote }}
  OTEL_RESOURCE_SERVICE_VERSION: {{ $cm.OTEL_RESOURCE_SERVICE_VERSION | default "0.1.0" | quote }}

  # IDEMPOTENCY / ATTACHMENT / TRANSMISSION
  IDEMPOTENCY_TTL_SEC: {{ $cm.IDEMPOTENCY_TTL_SEC | default "86400" | quote }}
  ATTACHMENT_BANDWIDTH_BUDGET_MB_PER_MIN: {{ $cm.ATTACHMENT_BANDWIDTH_BUDGET_MB_PER_MIN | default "500" | quote }}
  TRANSMISSION_PENDING_GRACE_SEC: {{ $cm.TRANSMISSION_PENDING_GRACE_SEC | default "30" | quote }}
  TRANSMISSION_RETRY_MAX_ATTEMPTS: {{ $cm.TRANSMISSION_RETRY_MAX_ATTEMPTS | default "3" | quote }}
  TRANSMISSION_METRICS_QUERY_TIMEOUT_SEC: {{ $cm.TRANSMISSION_METRICS_QUERY_TIMEOUT_SEC | default "2" | quote }}

  # STREAMING OUTBOX / AUDIT OUTBOX dispatchers
  STREAMING_OUTBOX_BATCH_LIMIT: {{ $cm.STREAMING_OUTBOX_BATCH_LIMIT | default "50" | quote }}
  STREAMING_OUTBOX_MAX_ATTEMPTS: {{ $cm.STREAMING_OUTBOX_MAX_ATTEMPTS | default "50" | quote }}
  STREAMING_OUTBOX_MULTI_TENANT_ENABLED: {{ $cm.STREAMING_OUTBOX_MULTI_TENANT_ENABLED | default "false" | quote }}
  STREAMING_OUTBOX_POLL_INTERVAL_SEC: {{ $cm.STREAMING_OUTBOX_POLL_INTERVAL_SEC | default "2" | quote }}
  STREAMING_OUTBOX_RETENTION_DAYS: {{ $cm.STREAMING_OUTBOX_RETENTION_DAYS | default "7" | quote }}
  AUDIT_OUTBOX_POLL_INTERVAL_SEC: {{ $cm.AUDIT_OUTBOX_POLL_INTERVAL_SEC | default "2" | quote }}
  AUDIT_OUTBOX_BATCH_LIMIT: {{ $cm.AUDIT_OUTBOX_BATCH_LIMIT | default "50" | quote }}
  AUDIT_OUTBOX_MAX_ATTEMPTS: {{ $cm.AUDIT_OUTBOX_MAX_ATTEMPTS | default "50" | quote }}
  AUDIT_OUTBOX_RETENTION_DAYS: {{ $cm.AUDIT_OUTBOX_RETENTION_DAYS | default "7" | quote }}

  # FEATURE FLAGS
  FEATURE_AI_INSIGHTS_ENABLED: {{ $cm.FEATURE_AI_INSIGHTS_ENABLED | default "true" | quote }}
  FEATURE_AUDIT_ENABLED: {{ $cm.FEATURE_AUDIT_ENABLED | default "true" | quote }}

  # AI (per-tenant BYOK; tuning only — no provider keys here, per-tenant via API)
  AI_DEFAULT_SYSTEM_PROMPT: {{ $cm.AI_DEFAULT_SYSTEM_PROMPT | default "" | quote }}
  AI_DEFAULT_MODEL_OPENAI: {{ $cm.AI_DEFAULT_MODEL_OPENAI | default "gpt-4o-mini" | quote }}
  AI_DEFAULT_MODEL_ANTHROPIC: {{ $cm.AI_DEFAULT_MODEL_ANTHROPIC | default "claude-sonnet-4-20250514" | quote }}
  AI_DEFAULT_MODEL_GEMINI: {{ $cm.AI_DEFAULT_MODEL_GEMINI | default "gemini-2.0-flash" | quote }}
  AI_TENANT_RATE_LIMIT_PER_MIN: {{ $cm.AI_TENANT_RATE_LIMIT_PER_MIN | default "50" | quote }}
  AI_CIRCUIT_BREAKER_THRESHOLD: {{ $cm.AI_CIRCUIT_BREAKER_THRESHOLD | default "5" | quote }}
  AI_CIRCUIT_BREAKER_HALF_OPEN_SEC: {{ $cm.AI_CIRCUIT_BREAKER_HALF_OPEN_SEC | default "30" | quote }}
  AI_TENANT_MAX_CONCURRENT: {{ $cm.AI_TENANT_MAX_CONCURRENT | default "3" | quote }}
  AI_GLOBAL_MAX_CONCURRENT: {{ $cm.AI_GLOBAL_MAX_CONCURRENT | default "15" | quote }}
  AI_ACQUIRE_TIMEOUT_SEC: {{ $cm.AI_ACQUIRE_TIMEOUT_SEC | default "30" | quote }}
  AI_INLINE_PROVIDER_TIMEOUT_SEC: {{ $cm.AI_INLINE_PROVIDER_TIMEOUT_SEC | default "15" | quote }}
  AI_BODY_INLINE_THRESHOLD: {{ $cm.AI_BODY_INLINE_THRESHOLD | default "200" | quote }}
  AI_HTTP_ACQUIRE_TIMEOUT_SEC: {{ $cm.AI_HTTP_ACQUIRE_TIMEOUT_SEC | default "5" | quote }}
{{- end }}

{{/*
correiosConfigmap — the single CORREIOS ConfigMap. Input dict: root, name, comp, port.
*/}}
{{- define "br-sfn.correiosConfigmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "br-sfn.componentFullname" (dict "root" .root "name" .name) }}
  namespace: {{ include "global.namespace" .root }}
  labels:
    {{- include "br-sfn.componentLabels" (dict "root" .root "name" .name) | nindent 4 }}
data:
{{ include "br-sfn.correiosConfigData" (dict "root" .root "comp" .comp "port" .port) }}
{{- end }}

{{/*
=============================================================================
slcEdgeConfigData — the productized SLC-EDGE (Cabine SLC authenticated passthrough
edge) body. STATELESS: no datastore/broker/auth/secret of its own — it relays the
inbound bearer credential verbatim to the br-slc core and has NO migrations.

Dependency CONNECTIONS: observability enable/endpoint via global.observability.
SLC_UPSTREAM_URL points at the br-slc CORE, a SIBLING service that is NOT a
component of THIS chart — so internalURL/dependency.fullname cannot derive its
address. Per the dependency-contract it stays an allowlisted escape-hatch
PASSTHROUGH URL (a plain cross-service URL when SD is not driving it), NOT a
hand-rolled domain knob.

Input dict: root ($), comp (.Values.slcEdge), port (service port; SERVER_PORT defaults to it).
=============================================================================
*/}}
{{- define "br-sfn.slcEdgeConfigData" -}}
{{- $root := .root -}}
{{- $port := .port -}}
{{- $cm := .comp.configmap | default dict -}}
  # =============================================================================
  # OBSERVABILITY — ENABLE_TELEMETRY / OTLP endpoint via global.observability
  # (slc-edge uses SERVICE_NAME for identity; Prometheus scrape passthrough).
  # =============================================================================
  ENABLE_TELEMETRY: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "observability" "field" "enabled" "nativeKey" "ENABLE_TELEMETRY" "default" "false") | quote }}
  OTEL_EXPORTER_OTLP_ENDPOINT: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "observability" "field" "otlpEndpoint" "nativeKey" "OTEL_EXPORTER_OTLP_ENDPOINT" "default" "") | quote }}
  METRICS_PROMETHEUS_ENABLED: {{ $cm.METRICS_PROMETHEUS_ENABLED | default "false" | quote }}
  METRICS_PROMETHEUS_ADDRESS: {{ $cm.METRICS_PROMETHEUS_ADDRESS | default "127.0.0.1:9075" | quote }}

  # =============================================================================
  # UPSTREAM — br-slc CORE (inter-service). NOT a component of this chart, so this
  # is a plain passthrough URL (allowlisted escape hatch), not a derived knob.
  # =============================================================================
  SLC_UPSTREAM_URL: {{ $cm.SLC_UPSTREAM_URL | default "http://localhost:3010" | quote }}
  SLC_UPSTREAM_TIMEOUT: {{ $cm.SLC_UPSTREAM_TIMEOUT | default "30s" | quote }}

  # SERVER_PORT defaults to the service port so the app listens where the Service/probes target.
  SERVER_PORT: {{ $cm.SERVER_PORT | default (printf "%v" $port) | quote }}

  # SERVER DEADLINES (passthrough tuning; 0 disables a deadline)
  SLC_READ_TIMEOUT: {{ $cm.SLC_READ_TIMEOUT | default "120s" | quote }}
  SLC_WRITE_TIMEOUT: {{ $cm.SLC_WRITE_TIMEOUT | default "0s" | quote }}
  SLC_IDLE_TIMEOUT: {{ $cm.SLC_IDLE_TIMEOUT | default "120s" | quote }}

  # APP / SERVER
  SERVICE_NAME: {{ $cm.SERVICE_NAME | default "br-slc-edge" | quote }}
  ENV_NAME: {{ $cm.ENV_NAME | default "development" | quote }}
  LOG_LEVEL: {{ $cm.LOG_LEVEL | default "info" | quote }}
  DEPLOYMENT_MODE: {{ $cm.DEPLOYMENT_MODE | default "local" | quote }}

  # CORS (cockpit SPA)
  SLC_EDGE_CORS_ALLOWED_ORIGINS: {{ $cm.SLC_EDGE_CORS_ALLOWED_ORIGINS | default "http://localhost:5173" | quote }}
{{- end }}

{{/*
slcEdgeConfigmap — the single SLC-EDGE ConfigMap. Input dict: root, name, comp, port.
*/}}
{{- define "br-sfn.slcEdgeConfigmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "br-sfn.componentFullname" (dict "root" .root "name" .name) }}
  namespace: {{ include "global.namespace" .root }}
  labels:
    {{- include "br-sfn.componentLabels" (dict "root" .root "name" .name) | nindent 4 }}
data:
{{ include "br-sfn.slcEdgeConfigData" (dict "root" .root "comp" .comp "port" .port) }}
{{- end }}

{{/*
redisComposedAddr — resolve a COMBINED redis address (`<host>:<port>`) from the
datastore redis mask, for rails whose app reads a single combined-address env
(spi REDIS_HOST, siloc REDIS_ADDRESS, correios CACHE_ADDR) rather than split
host/port (spb/scr). Reads BOTH mask fields so the shared tier
`global.datastores.redis.{host,port}` (separate) reaches these rails too.

Behaviour-safe: appends `:<port>` ONLY when a separate mask port is present AND
the resolved host has no embedded `:` — so the legacy embedded-port style
(host="valkey:6379", no separate port) is unchanged and no stray `:` is added.

Input dict: root ($), ds (dedicated datastores map), cm (configmap map),
hostKey (native host env key), hostDefault (legacy default for host).
*/}}
{{- define "br-sfn.redisComposedAddr" -}}
{{- $host := include "lerian-common.datastore.value" (dict "context" .root "dedicated" .ds "configmap" .cm "type" "redis" "field" "host" "nativeKey" .hostKey "default" .hostDefault) -}}
{{- /* No native configmap key for the port on a combined-address rail — the app
   reads only the combined host env — so use a sentinel nativeKey that is never in
   the configmap; the mask then resolves dedicated/shared redis.port (or ""). */ -}}
{{- $port := include "lerian-common.datastore.value" (dict "context" .root "dedicated" .ds "configmap" .cm "type" "redis" "field" "port" "nativeKey" "__BR_SFN_NO_NATIVE_REDIS_PORT__" "default" "") -}}
{{- /* IPv6-aware composition. Colon count decides whether the host already carries a
   port: 0 colons -> bare host, append :port; >1 colon -> bare IPv6 literal, bracket
   then append [host]:port; exactly 1 colon -> legacy host:port / ipv4:port, leave as-is.
   A host already ending in "]:<port>" (bracketed IPv6 WITH an embedded port) is
   emitted verbatim. A bracketed IPv6 host WITHOUT an embedded port (e.g.
   "[2001:db8::10]") is NOT verbatim -- a configured port must still be appended,
   otherwise it would be silently dropped. An unset port is always emitted verbatim. */ -}}
{{- $colons := sub (len (splitList ":" $host)) 1 -}}
{{- if not $port -}}
{{- $host -}}
{{- else if regexMatch "\\]:[0-9]+$" $host -}}
{{- $host -}}
{{- else if contains "]" $host -}}
{{- printf "%s:%s" $host $port -}}
{{- else if eq $colons 0 -}}
{{- printf "%s:%s" $host $port -}}
{{- else if gt $colons 1 -}}
{{- printf "[%s]:%s" $host $port -}}
{{- else -}}
{{- $host -}}
{{- end -}}
{{- end -}}

{{/*
=============================================================================
staConfigData — the productized STA (Sistema de Transferencia de Arquivos)
MANAGER ConfigMap body. Translated from the already-productized br-sta chart into
br-sfn's per-rail shape (external-infra only: bundled-subchart host fallbacks
DROPPED — Postgres/Redis/RabbitMQ resolve via the datastore mask with default "").

Dependency CONNECTIONS: Postgres + RabbitMQ(broker) via datastore.value; Redis via
br-sfn.redisComposedAddr (combined host:port); observability via otel.env + otel.envFlat
identity; auth via globalValue (global.auth, native PLUGIN_AUTH_HOST); multi-tenant via
multiTenant.env (full: redis/pool/cache); service-discovery via serviceDiscovery.env;
streaming via streaming.env. App AND dedicated migrator both use POSTGRES_* (db-name is
POSTGRES_NAME). Object storage (TRUST_STORE_S3_* / TRANSFER_OBJECT_STORAGE_BUCKET) stays
escape-hatch passthrough (carried from br-sta; see lerian-common gap note).

Input dict: root ($), comp (.Values.sta — image tag), port (manager service port),
cm (the manager configmap map .Values.sta.configmap).
=============================================================================
*/}}
{{- define "br-sfn.staConfigData" -}}
{{- $root := .root -}}
{{- $ds := $root.Values.sta.datastores | default dict -}}
{{- $comp := .comp -}}
{{- $port := .port -}}
{{- $cm := .cm | default dict -}}
{{- $mt := $root.Values.sta.multiTenant | default dict -}}
{{- $sd := $root.Values.sta.serviceDiscovery | default dict -}}
{{- $strm := $root.Values.sta.streaming | default dict -}}
{{- $tag := $comp.image.tag | default $root.Chart.AppVersion -}}
{{- $name := include "br-sfn.componentFullname" (dict "root" $root "name" "sta") -}}
{{- $namespace := include "global.namespace" $root -}}
{{- $mtEnabled := eq (include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "MULTI_TENANT_ENABLED" "params" $mt "field" "enabled" "default" "false")) "true" -}}
{{- $sdEnabled := eq (include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "SD_ENABLED" "params" $sd "field" "enabled" "default" "false")) "true" -}}
{{- $streamingEnabled := eq (include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "STREAMING_ENABLED" "params" $strm "field" "enabled" "default" "false")) "true" -}}
  # =============================================================================
  # PASSTHROUGH CONFIG — configmap.<KEY> escape hatch over the template default.
  # =============================================================================
  AGGRESSIVE_RATE_LIMIT_MAX: {{ $cm.AGGRESSIVE_RATE_LIMIT_MAX | default "100" | quote }}
  AGGRESSIVE_RATE_LIMIT_WINDOW_SEC: {{ $cm.AGGRESSIVE_RATE_LIMIT_WINDOW_SEC | default "60" | quote }}
  AWS_REGION: {{ $cm.AWS_REGION | default "us-east-1" | quote }}
  CIRCUIT_BREAKER_ENABLED: {{ $cm.CIRCUIT_BREAKER_ENABLED | default "false" | quote }}
  CORS_ALLOWED_HEADERS: {{ $cm.CORS_ALLOWED_HEADERS | default "Origin,Content-Type,Accept,Authorization,X-Request-ID" | quote }}
  CORS_ALLOWED_METHODS: {{ $cm.CORS_ALLOWED_METHODS | default "GET,POST,PUT,PATCH,DELETE,OPTIONS" | quote }}
  CORS_ALLOWED_ORIGINS: {{ $cm.CORS_ALLOWED_ORIGINS | default "*" | quote }}
  CORS_ALLOW_CREDENTIALS: {{ $cm.CORS_ALLOW_CREDENTIALS | default "false" | quote }}
  CORS_EXPOSE_HEADERS: {{ $cm.CORS_EXPOSE_HEADERS | default "" | quote }}
  DB_METRICS_INTERVAL_SEC: {{ $cm.DB_METRICS_INTERVAL_SEC | default "15" | quote }}
  DEFAULT_TENANT_ID: {{ $cm.DEFAULT_TENANT_ID | default "11111111-1111-1111-1111-111111111111" | quote }}
  ENV_NAME: {{ $cm.ENV_NAME | default "production" | quote }}
  EXAMPLE_STATUS_PROVIDER_MODE: {{ $cm.EXAMPLE_STATUS_PROVIDER_MODE | default "healthy" | quote }}
  HTTP_BODY_LIMIT_BYTES: {{ $cm.HTTP_BODY_LIMIT_BYTES | default "104857600" | quote }}
  IDEMPOTENCY_RETRY_WINDOW_SEC: {{ $cm.IDEMPOTENCY_RETRY_WINDOW_SEC | default "300" | quote }}
  INFRA_CONNECT_TIMEOUT_SEC: {{ $cm.INFRA_CONNECT_TIMEOUT_SEC | default "30" | quote }}
  LOG_LEVEL: {{ $cm.LOG_LEVEL | default "info" | quote }}
  M2M_CREDENTIAL_CACHE_TTL_SEC: {{ $cm.M2M_CREDENTIAL_CACHE_TTL_SEC | default "300" | quote }}
  MAX_PAGINATION_LIMIT: {{ $cm.MAX_PAGINATION_LIMIT | default "100" | quote }}
  MAX_PAGINATION_MONTH_DATE_RANGE: {{ $cm.MAX_PAGINATION_MONTH_DATE_RANGE | default "3" | quote }}
  MIGRATIONS_PATH: {{ $cm.MIGRATIONS_PATH | default "migrations" | quote }}
  OUTBOX_ALLOW_EMPTY_TENANT: {{ $cm.OUTBOX_ALLOW_EMPTY_TENANT | default "true" | quote }}
  OUTBOX_BATCH_SIZE: {{ $cm.OUTBOX_BATCH_SIZE | default "50" | quote }}
  OUTBOX_DISPATCH_INTERVAL_SEC: {{ $cm.OUTBOX_DISPATCH_INTERVAL_SEC | default "2" | quote }}
  OUTBOX_ENABLED: {{ $cm.OUTBOX_ENABLED | default "false" | quote }}
  OUTBOX_INCLUDE_TENANT_METRICS: {{ $cm.OUTBOX_INCLUDE_TENANT_METRICS | default "false" | quote }}
  OUTBOX_MAX_DISPATCH_ATTEMPTS: {{ $cm.OUTBOX_MAX_DISPATCH_ATTEMPTS | default "10" | quote }}
  OUTBOX_MAX_FAILED_PER_BATCH: {{ $cm.OUTBOX_MAX_FAILED_PER_BATCH | default "25" | quote }}
  OUTBOX_PROCESSING_TIMEOUT_SEC: {{ $cm.OUTBOX_PROCESSING_TIMEOUT_SEC | default "600" | quote }}
  OUTBOX_PUBLISH_BACKOFF_MS: {{ $cm.OUTBOX_PUBLISH_BACKOFF_MS | default "200" | quote }}
  OUTBOX_PUBLISH_MAX_ATTEMPTS: {{ $cm.OUTBOX_PUBLISH_MAX_ATTEMPTS | default "3" | quote }}
  OUTBOX_RETRY_WINDOW_SEC: {{ $cm.OUTBOX_RETRY_WINDOW_SEC | default "300" | quote }}
  OUTBOX_TABLE_NAME: {{ $cm.OUTBOX_TABLE_NAME | default "outbox_events" | quote }}
  POSTGRES_CONNECT_TIMEOUT_SEC: {{ $cm.POSTGRES_CONNECT_TIMEOUT_SEC | default "10" | quote }}
  POSTGRES_CONN_MAX_IDLE_TIME_MINS: {{ $cm.POSTGRES_CONN_MAX_IDLE_TIME_MINS | default "5" | quote }}
  POSTGRES_CONN_MAX_LIFETIME_MINS: {{ $cm.POSTGRES_CONN_MAX_LIFETIME_MINS | default "30" | quote }}
  POSTGRES_MAX_IDLE_CONNS: {{ $cm.POSTGRES_MAX_IDLE_CONNS | default "5" | quote }}
  POSTGRES_MAX_OPEN_CONNS: {{ $cm.POSTGRES_MAX_OPEN_CONNS | default "25" | quote }}
  RABBITMQ_ALLOW_INSECURE_HEALTH_CHECK: {{ $cm.RABBITMQ_ALLOW_INSECURE_HEALTH_CHECK | default "false" | quote }}
  RABBITMQ_ALLOW_INSECURE_TLS: {{ $cm.RABBITMQ_ALLOW_INSECURE_TLS | default "false" | quote }}
  RABBITMQ_ENABLED: {{ $cm.RABBITMQ_ENABLED | default "false" | quote }}
  RABBITMQ_EXCHANGE: {{ $cm.RABBITMQ_EXCHANGE | default "events" | quote }}
  RABBITMQ_PORT_HOST: {{ $cm.RABBITMQ_PORT_HOST | default "15672" | quote }}
  RABBITMQ_PUBLISHER_CONFIRM_TIMEOUT_MS: {{ $cm.RABBITMQ_PUBLISHER_CONFIRM_TIMEOUT_MS | default "5000" | quote }}
  RABBITMQ_PUBLISHER_MAX_RECOVERIES: {{ $cm.RABBITMQ_PUBLISHER_MAX_RECOVERIES | default "10" | quote }}
  RABBITMQ_PUBLISHER_RECOVERY_INITIAL_MS: {{ $cm.RABBITMQ_PUBLISHER_RECOVERY_INITIAL_MS | default "1000" | quote }}
  RABBITMQ_PUBLISHER_RECOVERY_MAX_MS: {{ $cm.RABBITMQ_PUBLISHER_RECOVERY_MAX_MS | default "30000" | quote }}
  RABBITMQ_REQUIRE_HEALTH_ALLOWED_HOSTS: {{ $cm.RABBITMQ_REQUIRE_HEALTH_ALLOWED_HOSTS | default "false" | quote }}
  RABBITMQ_VHOST: {{ $cm.RABBITMQ_VHOST | default "/" | quote }}
  RATE_LIMIT_ENABLED: {{ $cm.RATE_LIMIT_ENABLED | default "true" | quote }}
  RATE_LIMIT_MAX: {{ $cm.RATE_LIMIT_MAX | default "500" | quote }}
  RATE_LIMIT_WINDOW_SEC: {{ $cm.RATE_LIMIT_WINDOW_SEC | default "60" | quote }}
  REDIS_DB: {{ $cm.REDIS_DB | default "0" | quote }}
  REDIS_DIAL_TIMEOUT: {{ $cm.REDIS_DIAL_TIMEOUT | default "5" | quote }}
  REDIS_MAX_RETRIES: {{ $cm.REDIS_MAX_RETRIES | default "3" | quote }}
  REDIS_MAX_RETRY_BACKOFF: {{ $cm.REDIS_MAX_RETRY_BACKOFF | default "1" | quote }}
  REDIS_MIN_IDLE_CONNS: {{ $cm.REDIS_MIN_IDLE_CONNS | default "2" | quote }}
  REDIS_MIN_RETRY_BACKOFF: {{ $cm.REDIS_MIN_RETRY_BACKOFF | default "8" | quote }}
  REDIS_POOL_SIZE: {{ $cm.REDIS_POOL_SIZE | default "10" | quote }}
  REDIS_POOL_TIMEOUT: {{ $cm.REDIS_POOL_TIMEOUT | default "2" | quote }}
  REDIS_PROTOCOL: {{ $cm.REDIS_PROTOCOL | default "3" | quote }}
  REDIS_READ_TIMEOUT: {{ $cm.REDIS_READ_TIMEOUT | default "3" | quote }}
  REDIS_TLS: {{ $cm.REDIS_TLS | default "false" | quote }}
  REDIS_WRITE_TIMEOUT: {{ $cm.REDIS_WRITE_TIMEOUT | default "3" | quote }}
  RELAXED_RATE_LIMIT_MAX: {{ $cm.RELAXED_RATE_LIMIT_MAX | default "1000" | quote }}
  RELAXED_RATE_LIMIT_WINDOW_SEC: {{ $cm.RELAXED_RATE_LIMIT_WINDOW_SEC | default "60" | quote }}
  SWAGGER_BASE_PATH: {{ $cm.SWAGGER_BASE_PATH | default "/" | quote }}
  SWAGGER_ENABLED: {{ $cm.SWAGGER_ENABLED | default "false" | quote }}
  SWAGGER_LEFT_DELIM: {{ $cm.SWAGGER_LEFT_DELIM | default "{{" | quote }}
  SWAGGER_RIGHT_DELIM: {{ $cm.SWAGGER_RIGHT_DELIM | default "}}" | quote }}
  SWAGGER_TITLE: {{ $cm.SWAGGER_TITLE | default "br-sta" | quote }}
  SWAGGER_VERSION: {{ $cm.SWAGGER_VERSION | default "1.0.0" | quote }}
  SYSTEMPLANE_ENABLED: {{ $cm.SYSTEMPLANE_ENABLED | default "false" | quote }}
  TLS_TERMINATED_UPSTREAM: {{ $cm.TLS_TERMINATED_UPSTREAM | default "true" | quote }}
  MULTI_TENANT_POOL_MAX_CONNS: {{ $cm.MULTI_TENANT_POOL_MAX_CONNS | default "20" | quote }}
  MULTI_TENANT_POOL_MAX_IDLE_CONNS: {{ $cm.MULTI_TENANT_POOL_MAX_IDLE_CONNS | default "5" | quote }}
  AUDIT_EXPORT_RATE_LIMIT_MAX: {{ $cm.AUDIT_EXPORT_RATE_LIMIT_MAX | default "10" | quote }}
  AUDIT_EXPORT_RATE_LIMIT_WINDOW_SEC: {{ $cm.AUDIT_EXPORT_RATE_LIMIT_WINDOW_SEC | default "60" | quote }}
  AUDIT_PUBLISHER_ALTERNATE_EXCHANGE: {{ $cm.AUDIT_PUBLISHER_ALTERNATE_EXCHANGE | default "sta.audit.dlq" | quote }}
  AUDIT_PUBLISHER_CONFIRM_TIMEOUT_SEC: {{ $cm.AUDIT_PUBLISHER_CONFIRM_TIMEOUT_SEC | default "5" | quote }}
  BACEN_ENVIRONMENT: {{ $cm.BACEN_ENVIRONMENT | default "homologation" | quote }}
  CREDENTIALS_RECOVERY_ON_BOOT: {{ $cm.CREDENTIALS_RECOVERY_ON_BOOT | default "true" | quote }}
  MASTER_KEY_PROVIDER: {{ $cm.MASTER_KEY_PROVIDER | default "envvar" | quote }}
  MASTER_KEY_VERSION: {{ $cm.MASTER_KEY_VERSION | default "v1" | quote }}
  POSTGRES_MAX_CONNECTIONS: {{ $cm.POSTGRES_MAX_CONNECTIONS | default "100" | quote }}
  POSTGRES_SHARED_BUFFERS: {{ $cm.POSTGRES_SHARED_BUFFERS | default "128MB" | quote }}
  RABBITMQ_SCHEME: {{ $cm.RABBITMQ_SCHEME | default "amqp" | quote }}
  SERVER_TRUSTED_PROXIES: {{ $cm.SERVER_TRUSTED_PROXIES | default "" | quote }}
  TRANSFER_INBOUND_ENABLED: {{ $cm.TRANSFER_INBOUND_ENABLED | default "false" | quote }}
  TRANSFER_INBOUND_MAX_FILE_SIZE_BYTES: {{ $cm.TRANSFER_INBOUND_MAX_FILE_SIZE_BYTES | default "5368709120" | quote }}
  TRANSFER_OBJECT_STORAGE_BUCKET: {{ $cm.TRANSFER_OBJECT_STORAGE_BUCKET | default "" | quote }}
  TRUST_STORE_DEFAULT_PAGE_SIZE: {{ $cm.TRUST_STORE_DEFAULT_PAGE_SIZE | default "25" | quote }}
  TRUST_STORE_EXPIRING_SOON_DAYS: {{ $cm.TRUST_STORE_EXPIRING_SOON_DAYS | default "30" | quote }}
  TRUST_STORE_MAX_CERT_SIZE_BYTES: {{ $cm.TRUST_STORE_MAX_CERT_SIZE_BYTES | default "65536" | quote }}
  TRUST_STORE_MAX_PAGE_SIZE: {{ $cm.TRUST_STORE_MAX_PAGE_SIZE | default "100" | quote }}
  TRUST_STORE_S3_BUCKET: {{ $cm.TRUST_STORE_S3_BUCKET | default "br-sta-truststore" | quote }}
  TRUST_STORE_S3_ENDPOINT: {{ $cm.TRUST_STORE_S3_ENDPOINT | default "http://localhost:8333" | quote }}
  TRUST_STORE_S3_PATH_STYLE: {{ $cm.TRUST_STORE_S3_PATH_STYLE | default "true" | quote }}
  TRUST_STORE_S3_REGION: {{ $cm.TRUST_STORE_S3_REGION | default "us-east-1" | quote }}
  SERVER_ADDRESS: {{ $cm.SERVER_ADDRESS | default "0.0.0.0:8080" | quote }}
  VERSION: {{ $tag | quote }}

  # =============================================================================
  # DATABASE — PostgreSQL (host/port/user/name/ssl via datastore mask; db-name is
  # POSTGRES_NAME). POSTGRES_PASSWORD -> Secret. External infra: no bundled fallback.
  # =============================================================================
  {{- $pgName := include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "name" "nativeKey" "POSTGRES_NAME" "default" "br_sta") }}
  POSTGRES_HOST: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "host" "nativeKey" "POSTGRES_HOST" "default" "") | quote }}
  POSTGRES_PORT: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "port" "nativeKey" "POSTGRES_PORT" "default" "5432") | quote }}
  POSTGRES_USER: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "user" "nativeKey" "POSTGRES_USER" "default" "br_sta") | quote }}
  POSTGRES_NAME: {{ $pgName | quote }}
  POSTGRES_SSLMODE: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "ssl" "nativeKey" "POSTGRES_SSLMODE" "default" "require") | quote }}
  # ALLOW_INSECURE_TLS (lib-commons bypass to accept a non-TLS Postgres/Redis; dev/dev-st
  # only). SECURE default false; NEVER default true. Set <rail>.configmap.ALLOW_INSECURE_TLS=true only in dev.
  ALLOW_INSECURE_TLS: {{ $cm.ALLOW_INSECURE_TLS | default "false" | quote }}
  {{- $replicaHost := include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "replicaHost" "nativeKey" "POSTGRES_REPLICA_HOST" "default" "") }}
  {{- if $replicaHost }}
  POSTGRES_REPLICA_HOST: {{ $replicaHost | quote }}
  POSTGRES_REPLICA_PORT: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "port" "nativeKey" "POSTGRES_REPLICA_PORT" "default" "5432") | quote }}
  POSTGRES_REPLICA_USER: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "user" "nativeKey" "POSTGRES_REPLICA_USER" "default" "br_sta") | quote }}
  POSTGRES_REPLICA_NAME: {{ $cm.POSTGRES_REPLICA_NAME | default $pgName | quote }}
  POSTGRES_REPLICA_SSLMODE: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "postgres" "field" "ssl" "nativeKey" "POSTGRES_REPLICA_SSLMODE" "default" "require") | quote }}
  {{- end }}

  # REDIS / Valkey (combined host:port via datastore mask; composes shared {host,port}). REDIS_PASSWORD -> Secret.
  REDIS_HOST: {{ include "br-sfn.redisComposedAddr" (dict "root" $root "ds" $ds "cm" $cm "hostKey" "REDIS_HOST" "hostDefault" "") | quote }}

  # RABBITMQ (host/port/user via datastore broker mask). RABBITMQ_DEFAULT_PASS / RABBITMQ_URL -> Secret.
  RABBITMQ_HOST: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "broker" "field" "host" "nativeKey" "RABBITMQ_HOST" "default" "") | quote }}
  RABBITMQ_PORT_AMQP: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "broker" "field" "port" "nativeKey" "RABBITMQ_PORT_AMQP" "default" "5672") | quote }}
  RABBITMQ_DEFAULT_USER: {{ include "lerian-common.datastore.value" (dict "context" $root "dedicated" $ds "configmap" $cm "type" "broker" "field" "user" "nativeKey" "RABBITMQ_DEFAULT_USER" "default" "br_sta") | quote }}

  # =============================================================================
  # AUTH (inbound) — enable/host via global.auth (native key PLUGIN_AUTH_HOST).
  # =============================================================================
  PLUGIN_AUTH_ENABLED: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "auth" "field" "enabled" "nativeKey" "PLUGIN_AUTH_ENABLED" "default" "false") | quote }}
  PLUGIN_AUTH_HOST: {{ include "lerian-common.globalValue" (dict "context" $root "configmap" $cm "block" "auth" "field" "host" "nativeKey" "PLUGIN_AUTH_HOST" "default" "") | quote }}

  # =============================================================================
  # MULTI-TENANCY — knob inline; URL + redis/pool/cache via multiTenant.env
  # (global.multiTenant). SERVICE_API_KEY / REDIS_PASSWORD -> Secret.
  # =============================================================================
  MULTI_TENANT_ENABLED: {{ $mtEnabled | quote }}
  {{- include "lerian-common.multiTenant.env" (dict "context" $root "configmap" $cm "enabled" $mtEnabled "emitRedis" true "emitPool" true "emitCache" true "emitAllowInsecure" true "requiredUrl" true "requiredRedisHost" true) | nindent 2 }}
  {{- if $mtEnabled }}
  MULTI_TENANT_POOL_MAX_CONNS: {{ $cm.MULTI_TENANT_POOL_MAX_CONNS | default "20" | quote }}
  MULTI_TENANT_POOL_MAX_IDLE_CONNS: {{ $cm.MULTI_TENANT_POOL_MAX_IDLE_CONNS | default "5" | quote }}
  {{- end }}

  # =============================================================================
  # OBSERVABILITY — shared enable/endpoint/deployment-env via global.observability;
  # identity (name/library/version) per-service.
  # =============================================================================
  {{- include "lerian-common.otel.env" (dict "context" $root "configmap" $cm "enabledDefault" "false" "endpointDefault" "" "deploymentEnvironmentDefault" "production") | nindent 2 }}
  {{- include "lerian-common.otel.envFlat" (dict "configmap" $cm "keys" (list "OTEL_RESOURCE_SERVICE_NAME" "OTEL_LIBRARY_NAME" "OTEL_RESOURCE_SERVICE_VERSION") "defaults" (dict "OTEL_RESOURCE_SERVICE_NAME" "br-sta" "OTEL_LIBRARY_NAME" "github.com/LerianStudio/br-sta" "OTEL_RESOURCE_SERVICE_VERSION" $tag)) | nindent 2 }}

  # =============================================================================
  # SERVICE DISCOVERY — knob inline; server config from global.serviceDiscovery,
  # endpoints derived from this rail's own service/ingress. SD_TOKEN -> Secret.
  # =============================================================================
  SD_ENABLED: {{ $sdEnabled | quote }}
  {{- include "lerian-common.serviceDiscovery.env" (dict "context" $root "enabled" $sdEnabled "configmap" $cm "name" $name "port" $port "namespace" $namespace "ingressHost" (include "lerian-common.firstIngressHost" (dict "ingress" ($root.Values.sta.ingress | default dict)))) | nindent 2 }}

  # =============================================================================
  # STREAMING — knob inline; brokers/SASL/TLS from global.streaming. STREAMING_SASL_PASSWORD -> Secret.
  # =============================================================================
  STREAMING_ENABLED: {{ $streamingEnabled | quote }}
  {{- include "lerian-common.streaming.env" (dict "context" $root "enabled" $streamingEnabled "configmap" $cm "clientId" $name "cloudeventsSource" "lerian.br-sta") | nindent 2 }}
  {{- /* extraEnvVars is a DEPLOYMENT-env concern (list of {name,value}) rendered into
     container env: by componentDeployment / the worker deployment — NOT into this
     ConfigMap (which is map-typed). Do not re-render it here. */ -}}
{{- end }}

{{/*
staConfigmap — the single STA manager ConfigMap. Input dict: root, name, comp, port.
*/}}
{{- define "br-sfn.staConfigmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "br-sfn.componentFullname" (dict "root" .root "name" .name) }}
  namespace: {{ include "global.namespace" .root }}
  labels:
    {{- include "br-sfn.componentLabels" (dict "root" .root "name" .name) | nindent 4 }}
data:
{{ include "br-sfn.staConfigData" (dict "root" .root "comp" .comp "port" .port "cm" (.comp.configmap | default dict)) }}
{{- end }}

{{/*
staWorkerConfigData — worker-only env, layered on top of the manager ConfigMap via
envFrom in the worker Deployment (worker keys win). SERVER_ADDRESS is the worker
probe-server bind (its own port); the rest come from sta.worker.configmap.
Input dict: root ($), port (worker probe port).
*/}}
{{- define "br-sfn.staWorkerConfigData" -}}
{{- $w := .root.Values.sta.worker | default dict -}}
  # Worker-only env, layered on the manager ConfigMap (envFrom order → worker keys win).
  SERVER_ADDRESS: {{ printf "0.0.0.0:%v" (($w.service | default dict).port | default 8081) | quote }}
  {{- range $k, $v := ($w.configmap | default dict) }}
  {{- if ne $k "SERVER_ADDRESS" }}
  {{ $k }}: {{ $v | quote }}
  {{- end }}
  {{- end }}
{{- end }}

{{/*
staWorkerConfigmap — the STA worker ConfigMap. Input dict: root, name, port.
*/}}
{{- define "br-sfn.staWorkerConfigmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "br-sfn.componentFullname" (dict "root" .root "name" .name) }}
  namespace: {{ include "global.namespace" .root }}
  labels:
    {{- include "br-sfn.componentLabels" (dict "root" .root "name" .name) | nindent 4 }}
data:
{{ include "br-sfn.staWorkerConfigData" (dict "root" .root "port" .port) }}
{{- end }}
