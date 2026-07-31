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
{{- $configData := include "br-sfn.componentConfigData" (dict "comp" .comp "shared" .shared) -}}
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
("baked"|"dedicated").
*/}}
{{- define "br-sfn.componentMigrationJob" -}}
{{- $mig := .comp.migrations | default dict -}}
{{- if $mig.enabled -}}
{{- $id := dict "root" .root "name" (printf "%s-migrations" .name) -}}
{{- $compId := dict "root" .root "name" .name -}}
{{- $fullname := include "br-sfn.componentFullname" $id -}}
{{- $cfgStr := include "br-sfn.componentConfigData" (dict "comp" .comp "shared" .shared) -}}
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
{{- $pgDb := include "br-sfn.migrationPgValue" (dict "mig" $mig "key" "database" "cfg" $cfg "cfgKey" "POSTGRES_DB" "fallback" "") -}}
{{- if not $pgDb -}}
{{- fail (printf "br-sfn: %s migrations need a Postgres database — set %s.migrations.postgres.database or %s.configmap.POSTGRES_DB" .name .name .name) -}}
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
            - name: POSTGRES_DB
              value: {{ $pgDb | quote }}
            - name: POSTGRES_SSLMODE
              value: {{ $pgSsl | quote }}
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ $pwName }}
                  key: {{ $pwKey }}
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
