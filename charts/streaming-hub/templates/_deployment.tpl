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
{{/* Postgres server CA bundle — mount + volume, both gated on the same switch. */}}
{{- $postgresCa := get (get ($.Values.postgres | default dict) "caBundle" | default dict) "enabled" -}}
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
      annotations:
        # Config-rollout trigger. Every role consumes the shared ConfigMap and the
        # chart Secret through envFrom ONLY, so a value change rewrites those objects
        # while leaving the pod template byte-identical — `helm upgrade` then cuts no
        # new ReplicaSet and the running pods keep the OLD config until an unrelated
        # restart. Hashing the rendered manifests into the template closes that.
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") $ | sha256sum }}
        {{- if not $sh.useExistingSecret }}
        # Only when the chart OWNS the Secret. Under useExistingSecret the Secret is
        # Vault/gitops-managed and changes outside Helm's view, so a hash of the
        # (empty) rendered template would be a constant that never triggers anything.
        checksum/secret: {{ include (print $.Template.BasePath "/secrets.yaml") $ | sha256sum }}
        {{- end }}
      {{- with $sh.podAnnotations }}
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
            # at render time, so the boot-critical keys are pinned via explicit
            # secretKeyRefs (mirrors the migrations Job). An external Secret missing
            # one of them now fails container creation with a clear "couldn't find
            # key" event instead of a silent app CrashLoopBackOff.
            - name: STREAMING_HUB_POSTGRES_DSN
              valueFrom:
                secretKeyRef:
                  name: {{ include "streaming-hub.secretName" $ }}
                  key: STREAMING_HUB_POSTGRES_DSN
            # Mandatory in EVERY mode from the 2.x line on (32 bytes, base64):
            # the app refuses to boot without it, so an ExternalSecret that has not
            # caught up should say which key is missing, not CrashLoopBackOff.
            - name: STREAMING_HUB_DASHBOARD_CURSOR_HMAC_KEY
              valueFrom:
                secretKeyRef:
                  name: {{ include "streaming-hub.secretName" $ }}
                  key: STREAMING_HUB_DASHBOARD_CURSOR_HMAC_KEY
            # The Lerian license (lib-license-go, GLOBAL mode). Required in EVERY
            # environment: the license-gated app refuses to boot without it.
            # Named, not left to envFrom, so a Secret that does not carry it
            # stops the container at creation ("couldn't find key LICENSE_KEY")
            # instead of booting a process that then refuses its own license.
            - name: LICENSE_KEY
              valueFrom:
                secretKeyRef:
                  name: {{ include "streaming-hub.secretName" $ }}
                  key: LICENSE_KEY
            {{- end }}
            {{- range $k, $v := $sh.extraEnvVars }}
            # Un-enumerated per-Deployment env hatch (key -> value map).
            - name: {{ $k }}
              value: {{ $v | quote }}
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
          {{- if $postgresCa }}
          # Postgres server CA. The app never reads this path by itself — the DSN's
          # sslrootcert names it, and the hardened 2.x boot refuses to connect
          # without a readable bundle there.
          volumeMounts:
            {{- include "streaming-hub.postgresCaVolumeMount" . | nindent 12 }}
          {{- end }}
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
      {{- if $postgresCa }}
      {{- /*
      lerian-common.rolesAnywhere.volume emits the `volumes:` key itself, so this
      block opens it only when that branch did not — a second `volumes:` would be
      a duplicate mapping key and the API server would reject the pod template.
      */}}
      {{- if not $rolesAnywhere }}
      volumes:
      {{- end }}
      {{- include "streaming-hub.postgresCaVolume" (dict "context" $ "hook" false) | nindent 8 }}
      {{- end }}
      {{- /* Scheduling: a component's nodeSelector / affinity / tolerations replace
             the shared ones; a component's spread overrides streamingHub.spread
             field by field (which overrides global.scheduling.spread); a raw
             topologySpreadConstraints list replaces the preset. selectorLabels
             MUST equal spec.selector.matchLabels above. */}}
      {{- $spread := merge (deepCopy ($cfg.spread | default dict)) (deepCopy ($sh.spread | default dict)) }}
      {{- $sched := dict
            "nodeSelector" ($cfg.nodeSelector | default $sh.nodeSelector)
            "affinity" ($cfg.affinity | default $sh.affinity)
            "tolerations" ($cfg.tolerations | default $sh.tolerations)
            "spread" $spread
            "topologySpreadConstraints" ($cfg.topologySpreadConstraints | default $sh.topologySpreadConstraints | default list) }}
      {{- with (include "lerian-common.scheduling" (dict
            "component" $sched
            "global" $.Values.global
            "selectorLabels" (include "streaming-hub.componentSelectorLabels" (dict "context" $ "component" $component))) | trim) }}
      {{- . | nindent 6 }}
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
{{/*
Fail-loud gate. lerian-common.hpa emits each metric behind its own `if`, so an
autoscaling block with BOTH targets unset (an operator nulling the values.yaml
defaults) renders an HPA with an EMPTY `metrics:` list — accepted by the API
server, permanently unable to scale — while the Deployment simultaneously omits
`replicas:` (see the autoscaling.enabled branch above), pinning the role at the
API default of 1. Refuse the render instead of shipping that silent pair.
*/}}
{{- if not (or $cfg.autoscaling.targetCPUUtilizationPercentage $cfg.autoscaling.targetMemoryUtilizationPercentage) -}}
{{- fail (printf "streamingHub.%s.autoscaling: set targetCPUUtilizationPercentage and/or targetMemoryUtilizationPercentage when autoscaling.enabled=true (an HPA with no metric never scales, and the Deployment drops replicas:)" $component) -}}
{{- end -}}
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
