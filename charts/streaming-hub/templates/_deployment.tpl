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
      {{- with $sh.podSecurityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
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
          {{- include "lerian-common.httpProbe" (dict
                "kind" "livenessProbe" "probe" $sh.livenessProbe "port" "http" "path" "/healthz"
                "initialDelay" 15 "period" 20 "timeout" 5 "success" 1 "failure" 3) | nindent 10 }}
          {{- include "lerian-common.httpProbe" (dict
                "kind" "readinessProbe" "probe" $sh.readinessProbe "port" "http" "path" "/readyz"
                "initialDelay" 10 "period" 10 "timeout" 5 "success" 1 "failure" 3) | nindent 10 }}
          resources:
            {{- toYaml $cfg.resources | nindent 12 }}
      {{- /* scheduling stays inline: lerian-common.scheduling emits a leading newline
         that becomes a trailing-whitespace blank line under `| nindent`, and the inline
         form cleanly expresses the per-role `$cfg.X | default $sh.X` fallback. */ -}}
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
{{- include "lerian-common.service" (dict
      "service" $sh.service
      "name" (include "streaming-hub.componentFullname" (dict "context" $ "component" $component))
      "namespace" (include "global.namespace" $)
      "labels" (include "streaming-hub.labels" (dict "context" $ "component" $component))
      "selector" (include "streaming-hub.componentSelectorLabels" (dict "context" $ "component" $component))
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
      "namespace" (include "global.namespace" $)
      "labels" (include "streaming-hub.labels" (dict "context" $ "component" $component))
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
      "namespace" (include "global.namespace" $)
      "labels" (include "streaming-hub.labels" (dict "context" $ "component" $component))
      "selector" (include "streaming-hub.componentSelectorLabels" (dict "context" $ "component" $component))
    ) }}
{{- end -}}
