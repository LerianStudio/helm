{{/*
=============================================================================
streaming-hub.deployment — the shared, component-parameterized Deployment.
Input: dict { root (the root context "."), component ("all"|"ingest"|"delivery") }.

All three roles run the SAME image and serve the SAME full control plane on
:8080. They differ ONLY in:
  - STREAMING_HUB_ROLE (the literal component)
  - Postgres pool sizing (poolMaxOpenConns / poolMaxIdleConns)
  - replicas / resources / scheduling

The role-specific vars are injected as EXPLICIT per-Deployment env, which WINS
over envFrom (k8s precedence: env > envFrom). So a per-role pool size cleanly
overrides any shared default, and the shared ConfigMap deliberately omits
STREAMING_HUB_ROLE / the pool vars.
=============================================================================
*/}}
{{- define "streaming-hub.deployment" -}}
{{- $ := .root -}}
{{- $component := .component -}}
{{- $cfg := index $.Values.streamingHub $component -}}
{{- $sh := $.Values.streamingHub -}}
{{/* Hoisted so the four Roles Anywhere sites below cannot drift apart. */}}
{{- $rolesAnywhere := and $.Values.aws $.Values.aws.rolesAnywhere $.Values.aws.rolesAnywhere.enabled -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "streaming-hub.componentFullname" (dict "context" $ "component" $component) }}
  namespace: {{ include "global.namespace" $ }}
  labels:
    {{- include "streaming-hub.labels" (dict "context" $ "component" $component) | nindent 4 }}
  {{- with $sh.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  revisionHistoryLimit: {{ $sh.revisionHistoryLimit | default 10 }}
  {{- with $sh.deploymentStrategy }}
  strategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if not $cfg.autoscaling.enabled }}
  replicas: {{ $cfg.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "streaming-hub.componentSelectorLabels" (dict "context" $ "component" $component) | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "streaming-hub.labels" (dict "context" $ "component" $component) | nindent 8 }}
      {{- with $sh.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
    spec:
      {{- with $sh.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "streaming-hub.serviceAccountName" $ }}
      automountServiceAccountToken: {{ $sh.serviceAccount.automountServiceAccountToken | default false }}
      terminationGracePeriodSeconds: {{ $sh.terminationGracePeriodSeconds | default 80 }}
      {{- if $rolesAnywhere }}
      # IAM Roles Anywhere: fsGroup lets the sidecar's non-root user (65532) read the
      # 0440 iam-certs projection. MERGED into the chart's podSecurityContext — fsGroup
      # is enforced, every other pod-level setting the deployer configured survives.
      securityContext:
        {{- toYaml (merge (dict "fsGroup" 65532) (default (dict) $sh.podSecurityContext)) | nindent 8 }}
      {{- else }}
      {{- with $sh.podSecurityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- end }}
      containers:
        - name: streaming-hub
          securityContext:
            {{- toYaml $sh.securityContext | nindent 12 }}
          image: "{{ $sh.image.repository }}:{{ include "streaming-hub.defaultTag" $ }}"
          imagePullPolicy: {{ $sh.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ $sh.service.port }}
              protocol: TCP
          envFrom:
            - secretRef:
                name: {{ include "streaming-hub.secretName" $ }}
            - configMapRef:
                name: {{ include "streaming-hub.fullname" $ }}
          env:
            # --- role differentiator (explicit env WINS over envFrom) ---
            - name: STREAMING_HUB_ROLE
              value: {{ $component | quote }}
            - name: STREAMING_HUB_POSTGRES_MAX_OPEN_CONNS
              value: {{ $cfg.poolMaxOpenConns | quote }}
            - name: STREAMING_HUB_POSTGRES_MAX_IDLE_CONNS
              value: {{ $cfg.poolMaxIdleConns | quote }}
            {{- if $sh.useExistingSecret }}
            # Existing-Secret path: Helm cannot inspect the external Secret's keys
            # at render time, so the ONE boot-critical key is pinned via an explicit
            # secretKeyRef (mirrors the migrations Job). An external Secret missing
            # STREAMING_HUB_POSTGRES_DSN now fails container creation with a clear
            # "couldn't find key" event instead of a silent app CrashLoopBackOff.
            - name: STREAMING_HUB_POSTGRES_DSN
              valueFrom:
                secretKeyRef:
                  name: {{ include "streaming-hub.secretName" $ }}
                  key: STREAMING_HUB_POSTGRES_DSN
            {{- end }}
            {{- with $sh.extraEnvVars }}
            {{- range . }}
            - name: {{ .name }}
              value: {{ .value | quote }}
            {{- end }}
            {{- end }}
            {{- if $sh.telemetry.enabled }}
            # OTEL endpoint is overridden per-pod via the node host IP (DaemonSet
            # collector pattern). Gated on the CHART-level streamingHub.telemetry.enabled.
            - name: HOST_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.hostIP
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "$(HOST_IP):4317"
            {{- end }}
            {{- if $rolesAnywhere }}
            # Point the AWS SDK's IMDS lookup at the aws-signing-helper sidecar, which
            # vends short-lived credentials from the IAM Roles Anywhere exchange.
            - name: AWS_EC2_METADATA_SERVICE_ENDPOINT
              value: "http://127.0.0.1:{{ $.Values.aws.rolesAnywhere.sidecar.port | default 9911 }}"
            - name: AWS_EC2_METADATA_SERVICE_ENDPOINT_MODE
              value: "IPv4"
            {{- end }}
          livenessProbe:
            httpGet:
              path: /healthz
              port: http
            initialDelaySeconds: {{ $sh.livenessProbe.initialDelaySeconds | default 15 }}
            periodSeconds: {{ $sh.livenessProbe.periodSeconds | default 20 }}
            timeoutSeconds: {{ $sh.livenessProbe.timeoutSeconds | default 5 }}
            successThreshold: {{ $sh.livenessProbe.successThreshold | default 1 }}
            failureThreshold: {{ $sh.livenessProbe.failureThreshold | default 3 }}
          readinessProbe:
            httpGet:
              path: /readyz
              port: http
            initialDelaySeconds: {{ $sh.readinessProbe.initialDelaySeconds | default 10 }}
            periodSeconds: {{ $sh.readinessProbe.periodSeconds | default 10 }}
            timeoutSeconds: {{ $sh.readinessProbe.timeoutSeconds | default 5 }}
            successThreshold: {{ $sh.readinessProbe.successThreshold | default 1 }}
            failureThreshold: {{ $sh.readinessProbe.failureThreshold | default 3 }}
          resources:
            {{- toYaml $cfg.resources | nindent 12 }}
        {{- if $rolesAnywhere }}
        # IAM Roles Anywhere credential sidecar. Serves an IMDS-compatible endpoint on
        # 127.0.0.1:<port>, exchanging the X.509 client cert (mounted from iam-certs)
        # for short-lived AWS credentials. Shared by every role, since this define
        # renders all of them (all / ingest / delivery).
        - name: aws-signing-helper
          image: "{{ $.Values.aws.rolesAnywhere.sidecar.image.repository }}:{{ $.Values.aws.rolesAnywhere.sidecar.image.tag }}"
          imagePullPolicy: {{ $.Values.aws.rolesAnywhere.sidecar.image.pullPolicy | default "IfNotPresent" }}
          args:
            - serve
            - --certificate
            - /certs/tls.crt
            - --private-key
            - /certs/tls.key
            - --trust-anchor-arn
            - "{{ required "aws.rolesAnywhere.trustAnchorArn is required when rolesAnywhere is enabled" $.Values.aws.rolesAnywhere.trustAnchorArn }}"
            - --profile-arn
            - "{{ required "aws.rolesAnywhere.profileArn is required when rolesAnywhere is enabled" $.Values.aws.rolesAnywhere.profileArn }}"
            - --role-arn
            - "{{ required "aws.rolesAnywhere.roleArn is required when rolesAnywhere is enabled" $.Values.aws.rolesAnywhere.roleArn }}"
            - --region
            - "{{ $.Values.aws.rolesAnywhere.region | default "us-east-2" }}"
            - --session-duration
            - "{{ $.Values.aws.rolesAnywhere.sessionDuration | default 3600 }}"
            - --port
            - "{{ $.Values.aws.rolesAnywhere.sidecar.port | default 9911 }}"
          ports:
            - name: imds
              containerPort: {{ $.Values.aws.rolesAnywhere.sidecar.port | default 9911 }}
              protocol: TCP
          volumeMounts:
            - name: iam-certs
              mountPath: /certs
              readOnly: true
          securityContext:
            runAsNonRoot: true
            runAsUser: 65532
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            readOnlyRootFilesystem: true
          resources:
            {{- toYaml $.Values.aws.rolesAnywhere.sidecar.resources | nindent 12 }}
        {{- end }}
      {{- if $rolesAnywhere }}
      # X.509 client cert/key for the Roles Anywhere exchange. Produced outside the
      # chart (a cert-manager Certificate in the deploying overlay) and mounted 0440
      # so only the sidecar's fsGroup can read it.
      volumes:
        - name: iam-certs
          secret:
            secretName: {{ $.Values.aws.rolesAnywhere.certificateSecretName | default (printf "%s-iam-tls" (include "streaming-hub.fullname" $)) }}
            defaultMode: 0440
            items:
              - key: tls.crt
                path: tls.crt
              - key: tls.key
                path: tls.key
      {{- end }}
      {{- with $cfg.nodeSelector | default $sh.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $cfg.affinity | default $sh.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $cfg.tolerations | default $sh.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end -}}


{{/*
=============================================================================
streaming-hub.service — the shared, component-parameterized ClusterIP Service.
Input: dict { root, component }. One Service per active role, selecting only
that role's pods via componentSelectorLabels.
=============================================================================
*/}}
{{- define "streaming-hub.service" -}}
{{- $ := .root -}}
{{- $component := .component -}}
{{- $sh := $.Values.streamingHub -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "streaming-hub.componentFullname" (dict "context" $ "component" $component) }}
  namespace: {{ include "global.namespace" $ }}
  labels:
    {{- include "streaming-hub.labels" (dict "context" $ "component" $component) | nindent 4 }}
  {{- with $sh.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ $sh.service.type }}
  ports:
    - port: {{ $sh.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "streaming-hub.componentSelectorLabels" (dict "context" $ "component" $component) | nindent 4 }}
{{- end -}}


{{/*
=============================================================================
streaming-hub.hpa — the shared, component-parameterized HPA (autoscaling/v2).
Input: dict { root, component }. Emitted only when that role's
autoscaling.enabled. CONNECTION-BUDGET HAZARD: maxReplicas multiplies the
Postgres connection draw — Σ(maxReplicas × poolMaxOpenConns) ≤ max_connections.
=============================================================================
*/}}
{{- define "streaming-hub.hpa" -}}
{{- $ := .root -}}
{{- $component := .component -}}
{{- $cfg := index $.Values.streamingHub $component -}}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "streaming-hub.componentFullname" (dict "context" $ "component" $component) }}
  namespace: {{ include "global.namespace" $ }}
  labels:
    {{- include "streaming-hub.labels" (dict "context" $ "component" $component) | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "streaming-hub.componentFullname" (dict "context" $ "component" $component) }}
  minReplicas: {{ $cfg.autoscaling.minReplicas }}
  maxReplicas: {{ $cfg.autoscaling.maxReplicas }}
  metrics:
    {{- if $cfg.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ $cfg.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if $cfg.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ $cfg.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
{{- end -}}


{{/*
=============================================================================
streaming-hub.pdb — the shared, component-parameterized PDB (policy/v1).
Input: dict { root, component }. Emitted only when that role's pdb.enabled.
maxUnavailable wins over minAvailable when both are set (mirrors the template).
=============================================================================
*/}}
{{- define "streaming-hub.pdb" -}}
{{- $ := .root -}}
{{- $component := .component -}}
{{- $cfg := index $.Values.streamingHub $component -}}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "streaming-hub.componentFullname" (dict "context" $ "component" $component) }}
  namespace: {{ include "global.namespace" $ }}
  labels:
    {{- include "streaming-hub.labels" (dict "context" $ "component" $component) | nindent 4 }}
  {{- with $cfg.pdb.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if and (hasKey $cfg.pdb "maxUnavailable") (ne $cfg.pdb.maxUnavailable nil) }}
  maxUnavailable: {{ $cfg.pdb.maxUnavailable }}
  {{- else }}
  minAvailable: {{ $cfg.pdb.minAvailable | default 1 }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "streaming-hub.componentSelectorLabels" (dict "context" $ "component" $component) | nindent 6 }}
{{- end -}}
