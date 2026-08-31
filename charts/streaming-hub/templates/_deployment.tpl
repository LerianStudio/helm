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
      {{- include "lerian-common.imagePullSecrets" . | nindent 6 }}
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
            {{- include "lerian-common.otel.podEnv" (dict "port" 4317) | nindent 12 }}
            {{- end }}
            {{- if $rolesAnywhere }}
            # Point the AWS SDK's IMDS lookup at the aws-signing-helper sidecar, which
            # vends short-lived credentials from the IAM Roles Anywhere exchange.
            {{- include "lerian-common.rolesAnywhere.imdsEnv" (dict "aws" $.Values.aws) | nindent 12 }}
            {{- end }}
          {{- include "lerian-common.httpProbe" (dict
                "kind" "livenessProbe" "probe" $sh.livenessProbe
                "port" "http" "path" "/healthz"
                "initialDelay" 15 "period" 20 "timeout" 5 "success" 1 "failure" 3
              ) | nindent 10 }}
          {{- include "lerian-common.httpProbe" (dict
                "kind" "readinessProbe" "probe" $sh.readinessProbe
                "port" "http" "path" "/readyz"
                "initialDelay" 10 "period" 10 "timeout" 5 "success" 1 "failure" 3
              ) | nindent 10 }}
          resources:
            {{- toYaml $cfg.resources | nindent 12 }}
        {{- if $rolesAnywhere }}
        # IAM Roles Anywhere credential sidecar. Serves an IMDS-compatible endpoint on
        # 127.0.0.1:<port>, exchanging the X.509 client cert (mounted from iam-certs)
        # for short-lived AWS credentials. Shared by every role, since this define
        # renders all of them (all / ingest / delivery).
        {{- include "lerian-common.rolesAnywhere.sidecar" (dict "aws" $.Values.aws) | nindent 8 }}
        {{- end }}
      {{- if $rolesAnywhere }}
      # X.509 client cert/key for the Roles Anywhere exchange. Produced outside the
      # chart (a cert-manager Certificate in the deploying overlay) and mounted 0440
      # so only the sidecar's fsGroup can read it.
      {{- include "lerian-common.rolesAnywhere.volume" (dict "aws" $.Values.aws "iamTlsDefault" (printf "%s-iam-tls" (include "streaming-hub.fullname" $))) | nindent 6 }}
      {{- end }}
      {{- include "lerian-common.scheduling" (dict
            "nodeSelector" ($cfg.nodeSelector | default $sh.nodeSelector)
            "affinity" ($cfg.affinity | default $sh.affinity)
            "tolerations" ($cfg.tolerations | default $sh.tolerations)
          ) | nindent 6 }}
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
{{- include "lerian-common.service" (dict
      "service" $sh.service
      "name" (include "streaming-hub.componentFullname" (dict "context" $ "component" $component))
      "labels" (include "streaming-hub.labels" (dict "context" $ "component" $component))
      "selector" (include "streaming-hub.componentSelectorLabels" (dict "context" $ "component" $component))
      "namespace" (include "global.namespace" $)
    ) }}
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
{{- include "lerian-common.hpa" (dict
      "autoscaling" $cfg.autoscaling
      "name" (include "streaming-hub.componentFullname" (dict "context" $ "component" $component))
      "labels" (include "streaming-hub.labels" (dict "context" $ "component" $component))
      "namespace" (include "global.namespace" $)
    ) }}
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
{{- include "lerian-common.pdb" (dict
      "pdb" $cfg.pdb
      "name" (include "streaming-hub.componentFullname" (dict "context" $ "component" $component))
      "labels" (include "streaming-hub.labels" (dict "context" $ "component" $component))
      "selector" (include "streaming-hub.componentSelectorLabels" (dict "context" $ "component" $component))
      "namespace" (include "global.namespace" $)
      "minAvailableDefault" 1
    ) }}
{{- end -}}
