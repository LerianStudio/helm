{{/*
==============================================================================
Shared workload library for the four SPI binaries (core / spi / brcode / dict).
All four are the same Go binary family with an identical deployment shape, so
the logic lives here once and each templates/<component>/*.yaml is a thin
include. This is deliberate: emitting env uniformly (especially STREAMING_*)
from ONE place removes the "one component silently drops a key" drift hazard.

Every template takes (dict "context" $ "component" "<name>").
==============================================================================
*/}}

{{/*
componentConfigMap — the component's ConfigMap.
STREAMING_* and the derived hosts are emitted first-class; everything else in
<component>.configmap is ranged verbatim (NOT a fixed allowlist — a fixed
allowlist is exactly what makes a producer boot as a silent NoopEmitter).
*/}}
{{- define "br-spi.componentConfigMap" -}}
{{- $ctx := .context -}}
{{- $c := .component -}}
{{- $cv := index $ctx.Values $c -}}
{{- if $cv.enabled -}}
{{- $reserved := list "POSTGRES_HOST" "REDIS_HOST" "STREAMING_ENABLED" "STREAMING_BROKERS" "STREAMING_CLOUDEVENTS_SOURCE" -}}
{{- $pgHost := $cv.configmap.POSTGRES_HOST -}}
{{- if and (not $pgHost) (ne (toString $ctx.Values.postgresql.enabled) "false") -}}
{{-   $pgHost = printf "%s.%s.svc.cluster.local." (include "common.names.dependency.fullname" (dict "chartName" "postgresql" "chartValues" $ctx.Values.postgresql "context" $ctx)) (include "global.namespace" $ctx) -}}
{{- end -}}
{{- $redisHost := $cv.configmap.REDIS_HOST -}}
{{- if and (not $redisHost) (ne (toString $ctx.Values.valkey.enabled) "false") -}}
{{-   $redisHost = printf "%s-primary.%s.svc.cluster.local.:6379" (include "common.names.dependency.fullname" (dict "chartName" "valkey" "chartValues" $ctx.Values.valkey "context" $ctx)) (include "global.namespace" $ctx) -}}
{{- end -}}
kind: ConfigMap
apiVersion: v1
metadata:
  name: {{ include "br-spi.componentFullname" (dict "context" $ctx "component" $c) }}
  namespace: {{ include "global.namespace" $ctx }}
  labels:
    {{- include "br-spi.componentLabels" (dict "context" $ctx "component" $c) | nindent 4 }}
data:
  # Streaming (CloudEvents producer knobs). First-class + always emitted: a
  # producer with STREAMING_ENABLED=true but empty STREAMING_BROKERS/SOURCE
  # fails closed at boot by design — it must never silently degrade to a
  # NoopEmitter because the chart dropped these keys.
  STREAMING_ENABLED: {{ $cv.configmap.STREAMING_ENABLED | default "false" | quote }}
  STREAMING_BROKERS: {{ $cv.configmap.STREAMING_BROKERS | default "" | quote }}
  STREAMING_CLOUDEVENTS_SOURCE: {{ $cv.configmap.STREAMING_CLOUDEVENTS_SOURCE | default "" | quote }}
  # Datastore hosts (derived from the bundled subchart when enabled, else the
  # operator-supplied value; on external infra these come from values/GitOps).
  POSTGRES_HOST: {{ $pgHost | default "" | quote }}
  REDIS_HOST: {{ $redisHost | default "" | quote }}
  {{- range $k, $v := $cv.configmap }}
  {{- if not (has $k $reserved) }}
  {{ $k }}: {{ $v | quote }}
  {{- end }}
  {{- end }}
{{- end -}}
{{- end -}}

{{/*
componentSecret — the component's Opaque Secret. Minted only when the component
is enabled and not using an existingSecret. Infra passwords are single-sourced
from the Bitnami subchart when bundled (read via secretKeyRef in the Deployment),
so they are emitted here ONLY on the external path (subchart disabled, no
existingSecret). Optional at-rest / PII keys are emitted only when set.
*/}}
{{- define "br-spi.componentSecret" -}}
{{- $ctx := .context -}}
{{- $c := .component -}}
{{- $cv := index $ctx.Values $c -}}
{{- if and $cv.enabled (not $cv.useExistingSecret) -}}
{{- $pg := $ctx.Values.postgresql | default dict -}}
{{- $pgAuth := $pg.auth | default dict -}}
{{- $pgInternal := and (ne (toString $pg.enabled) "false") (not $pg.external) -}}
{{- $vk := $ctx.Values.valkey | default dict -}}
{{- $vkAuth := $vk.auth | default dict -}}
{{- $vkInternal := and (ne (toString $vk.enabled) "false") (not $vk.external) $vkAuth.enabled -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "br-spi.componentFullname" (dict "context" $ctx "component" $c) }}
  namespace: {{ include "global.namespace" $ctx }}
  labels:
    {{- include "br-spi.componentLabels" (dict "context" $ctx "component" $c) | nindent 4 }}
type: Opaque
data:
  # PostgreSQL password — single-sourced from the postgresql subchart Secret when
  # bundled; emitted here only for external Postgres without an existingSecret.
  {{- if and (not $pgInternal) (not $pgAuth.existingSecret) $cv.secrets.POSTGRES_PASSWORD }}
  POSTGRES_PASSWORD: {{ $cv.secrets.POSTGRES_PASSWORD | b64enc | quote }}
  {{- end }}
  # Redis/Valkey password — single-sourced from the valkey subchart Secret when
  # bundled; emitted here only for external Redis without an existingSecret.
  {{- if and (not $vkInternal) (not $vkAuth.existingSecret) $cv.secrets.REDIS_PASSWORD }}
  REDIS_PASSWORD: {{ $cv.secrets.REDIS_PASSWORD | b64enc | quote }}
  {{- end }}
  {{- range $k, $v := $cv.secrets }}
  {{- if and (not (has $k (list "POSTGRES_PASSWORD" "REDIS_PASSWORD"))) $v }}
  {{ $k }}: {{ $v | b64enc | quote }}
  {{- end }}
  {{- end }}
{{- end -}}
{{- end -}}

{{/*
componentDeployment — the component's Deployment.
*/}}
{{- define "br-spi.componentDeployment" -}}
{{- $ctx := .context -}}
{{- $c := .component -}}
{{- $cv := index $ctx.Values $c -}}
{{- if $cv.enabled -}}
{{- $fullname := include "br-spi.componentFullname" (dict "context" $ctx "component" $c) -}}
{{- $secretName := ternary $cv.existingSecretName $fullname $cv.useExistingSecret -}}
{{- $pullSecrets := $cv.imagePullSecrets | default $ctx.Values.imagePullSecrets -}}
{{- $telemetry := eq (toString $cv.configmap.ENABLE_TELEMETRY) "true" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $fullname }}
  namespace: {{ include "global.namespace" $ctx }}
  labels:
    {{- include "br-spi.componentLabels" (dict "context" $ctx "component" $c) | nindent 4 }}
spec:
  revisionHistoryLimit: {{ $cv.revisionHistoryLimit | default 10 }}
  {{- if not $cv.autoscaling.enabled }}
  replicas: {{ $cv.replicaCount | default 1 }}
  {{- end }}
  strategy:
    type: {{ $cv.deploymentUpdate.type | default "RollingUpdate" }}
    {{- if eq ($cv.deploymentUpdate.type | default "RollingUpdate") "RollingUpdate" }}
    rollingUpdate:
      maxSurge: {{ $cv.deploymentUpdate.maxSurge | default "100%" }}
      maxUnavailable: {{ $cv.deploymentUpdate.maxUnavailable | default 0 }}
    {{- end }}
  selector:
    matchLabels:
      {{- include "br-spi.componentSelectorLabels" (dict "context" $ctx "component" $c) | nindent 6 }}
  template:
    metadata:
      {{- with $cv.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "br-spi.componentLabels" (dict "context" $ctx "component" $c) | nindent 8 }}
    spec:
      {{- with $pullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "br-spi.serviceAccountName" $ctx }}
      securityContext:
        {{- toYaml $ctx.Values.podSecurityContext | nindent 8 }}
      initContainers:
        - name: wait-for-dependencies
          image: {{ $cv.waitImage | default "busybox" }}
          envFrom:
            - configMapRef:
                name: {{ $fullname }}
          command:
            - /bin/sh
            - -c
            - >
              if [ -n "$POSTGRES_HOST" ]; then
                echo "waiting for postgres $POSTGRES_HOST:${POSTGRES_PORT:-5432}...";
                until nc -z "$POSTGRES_HOST" "${POSTGRES_PORT:-5432}"; do
                  echo "postgres not ready, waiting..."; sleep 5;
                done;
                echo "postgres is ready";
              fi;
              if [ -n "$REDIS_HOST" ]; then
                RH=$(echo "$REDIS_HOST" | cut -d: -f1);
                RP=$(echo "$REDIS_HOST" | cut -d: -f2);
                [ -z "$RP" ] && RP=6379;
                echo "waiting for redis $RH:$RP...";
                until nc -z "$RH" "$RP"; do
                  echo "redis not ready, waiting..."; sleep 5;
                done;
                echo "redis is ready";
              fi;
              echo "dependencies ready"
          securityContext:
            {{- toYaml $ctx.Values.securityContext | nindent 12 }}
      containers:
        - name: {{ $fullname }}
          securityContext:
            {{- toYaml $ctx.Values.securityContext | nindent 12 }}
          image: "{{ $cv.image.repository }}:{{ $cv.image.tag | default $ctx.Chart.AppVersion }}"
          imagePullPolicy: {{ $cv.image.pullPolicy | default "IfNotPresent" }}
          envFrom:
            - secretRef:
                name: {{ $secretName }}
            - configMapRef:
                name: {{ $fullname }}
          env:
            {{- $pg := $ctx.Values.postgresql | default dict }}
            {{- $pgAuth := $pg.auth | default dict }}
            {{- if or (and (ne (toString $pg.enabled) "false") (not $pg.external)) $pgAuth.existingSecret }}
            {{- include "br-spi.infraSecretRef" (dict "context" $ctx "subchart" "postgresql" "key" "password" "envName" "POSTGRES_PASSWORD") | nindent 12 }}
            {{- else if $cv.secrets.POSTGRES_PASSWORD }}
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ $secretName }}
                  key: POSTGRES_PASSWORD
            {{- end }}
            {{- $vk := $ctx.Values.valkey | default dict }}
            {{- $vkAuth := $vk.auth | default dict }}
            {{- if or (and (ne (toString $vk.enabled) "false") (not $vk.external) $vkAuth.enabled) $vkAuth.existingSecret }}
            {{- include "br-spi.infraSecretRef" (dict "context" $ctx "subchart" "valkey" "key" "valkey-password" "envName" "REDIS_PASSWORD") | nindent 12 }}
            {{- else if $cv.secrets.REDIS_PASSWORD }}
            - name: REDIS_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ $secretName }}
                  key: REDIS_PASSWORD
            {{- end }}
            {{- if $telemetry }}
            - name: HOST_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.hostIP
            # SPI exports OTLP over gRPC on 4317 (no scheme), to the node-local collector.
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "$(HOST_IP):4317"
            {{- end }}
            {{- with $cv.extraEnvVars }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
          livenessProbe:
            httpGet:
              path: {{ $cv.livenessProbe.path | default "/health" }}
              port: http
            initialDelaySeconds: {{ $cv.livenessProbe.initialDelaySeconds | default 15 }}
            periodSeconds: {{ $cv.livenessProbe.periodSeconds | default 20 }}
            timeoutSeconds: {{ $cv.livenessProbe.timeoutSeconds | default 5 }}
            successThreshold: {{ $cv.livenessProbe.successThreshold | default 1 }}
            failureThreshold: {{ $cv.livenessProbe.failureThreshold | default 3 }}
          readinessProbe:
            httpGet:
              path: {{ $cv.readinessProbe.path | default "/readyz" }}
              port: http
            initialDelaySeconds: {{ $cv.readinessProbe.initialDelaySeconds | default 5 }}
            periodSeconds: {{ $cv.readinessProbe.periodSeconds | default 10 }}
            timeoutSeconds: {{ $cv.readinessProbe.timeoutSeconds | default 5 }}
            successThreshold: {{ $cv.readinessProbe.successThreshold | default 1 }}
            failureThreshold: {{ $cv.readinessProbe.failureThreshold | default 3 }}
          resources:
            {{- toYaml $cv.resources | nindent 12 }}
      {{- with $cv.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $cv.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $cv.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end -}}
{{- end -}}

{{/*
componentService — the component's ClusterIP Service.
*/}}
{{- define "br-spi.componentService" -}}
{{- $ctx := .context -}}
{{- $c := .component -}}
{{- $cv := index $ctx.Values $c -}}
{{- if $cv.enabled -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "br-spi.componentFullname" (dict "context" $ctx "component" $c) }}
  namespace: {{ include "global.namespace" $ctx }}
  labels:
    {{- include "br-spi.componentLabels" (dict "context" $ctx "component" $c) | nindent 4 }}
  {{- with $cv.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ $cv.service.type | default "ClusterIP" }}
  ports:
    - port: {{ $cv.service.port | default 8080 }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "br-spi.componentSelectorLabels" (dict "context" $ctx "component" $c) | nindent 4 }}
{{- end -}}
{{- end -}}

{{/*
componentIngress — optional per-component Ingress (disabled by default).
*/}}
{{- define "br-spi.componentIngress" -}}
{{- $ctx := .context -}}
{{- $c := .component -}}
{{- $cv := index $ctx.Values $c -}}
{{- if and $cv.enabled $cv.ingress.enabled -}}
{{- $svcName := include "br-spi.componentFullname" (dict "context" $ctx "component" $c) -}}
{{- $svcPort := $cv.service.port | default 8080 -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $svcName }}
  namespace: {{ include "global.namespace" $ctx }}
  labels:
    {{- include "br-spi.componentLabels" (dict "context" $ctx "component" $c) | nindent 4 }}
  {{- with $cv.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- with $cv.ingress.className }}
  ingressClassName: {{ . }}
  {{- end }}
  {{- with $cv.ingress.tls }}
  tls:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  rules:
    {{- range $cv.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType | default "Prefix" }}
            backend:
              service:
                name: {{ $svcName }}
                port:
                  number: {{ $svcPort }}
          {{- end }}
    {{- end }}
{{- end -}}
{{- end -}}

{{/*
componentHPA — optional per-component HorizontalPodAutoscaler.
*/}}
{{- define "br-spi.componentHPA" -}}
{{- $ctx := .context -}}
{{- $c := .component -}}
{{- $cv := index $ctx.Values $c -}}
{{- if and $cv.enabled $cv.autoscaling.enabled -}}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "br-spi.componentFullname" (dict "context" $ctx "component" $c) }}
  namespace: {{ include "global.namespace" $ctx }}
  labels:
    {{- include "br-spi.componentLabels" (dict "context" $ctx "component" $c) | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "br-spi.componentFullname" (dict "context" $ctx "component" $c) }}
  minReplicas: {{ $cv.autoscaling.minReplicas | default 1 }}
  maxReplicas: {{ $cv.autoscaling.maxReplicas | default 3 }}
  metrics:
    {{- with $cv.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ . }}
    {{- end }}
    {{- with $cv.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ . }}
    {{- end }}
{{- end -}}
{{- end -}}

{{/*
componentPDB — optional per-component PodDisruptionBudget.
*/}}
{{- define "br-spi.componentPDB" -}}
{{- $ctx := .context -}}
{{- $c := .component -}}
{{- $cv := index $ctx.Values $c -}}
{{- if and $cv.enabled $cv.pdb.enabled -}}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "br-spi.componentFullname" (dict "context" $ctx "component" $c) }}
  namespace: {{ include "global.namespace" $ctx }}
  labels:
    {{- include "br-spi.componentLabels" (dict "context" $ctx "component" $c) | nindent 4 }}
  {{- with $cv.pdb.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if $cv.pdb.maxUnavailable }}
  maxUnavailable: {{ $cv.pdb.maxUnavailable }}
  {{- else }}
  minAvailable: {{ $cv.pdb.minAvailable | default 1 }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "br-spi.componentSelectorLabels" (dict "context" $ctx "component" $c) | nindent 6 }}
{{- end -}}
{{- end -}}
