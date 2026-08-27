{{/*
Expand the name of the chart.
*/}}
{{- define "plugin-br-pix-lerian.name" -}}
{{- default "plugin-br-pix-lerian" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the namespace of the release.
Allows overriding via .Values.namespaceOverride for combined / umbrella charts.
*/}}
{{- define "global.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "plugin-br-pix-lerian.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Per-component fully-qualified name.
Usage: include "plugin-br-pix-lerian.componentFullname" (dict "context" $ "component" "spi")
Returns: <chartname>-<component-name>  (e.g. plugin-br-pix-lerian-spi)
*/}}
{{- define "plugin-br-pix-lerian.componentFullname" -}}
{{- $base := include "plugin-br-pix-lerian.name" .context -}}
{{- printf "%s-%s" $base .component | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Resolve image repository + tag for a component.
Each component sets its own image.repository (default to per-component image
shipped by the plugin-br-pix-lerian source repo). image.tag falls back to
.Chart.AppVersion when unset, which keeps the cohort in lockstep by default.

Override only image.tag at deploy time (per env) when you need to pin a
specific build.

Usage: include "plugin-br-pix-lerian.componentImage" (dict "context" $ "componentValues" .Values.spi)
*/}}
{{- define "plugin-br-pix-lerian.componentImage" -}}
{{- $repo := .componentValues.image.repository -}}
{{- $tag := default .context.Chart.AppVersion .componentValues.image.tag -}}
{{- printf "%s:%s" $repo $tag -}}
{{- end }}

{{/*
Resolve image pullPolicy for a component. Falls back to IfNotPresent — the
K8s convention for tagged images.
*/}}
{{- define "plugin-br-pix-lerian.componentPullPolicy" -}}
{{- default "IfNotPresent" .componentValues.image.pullPolicy -}}
{{- end }}

{{/*
Resolve imagePullSecrets for a component, falling back to global.
Returns YAML list (use with `toYaml | nindent`).
Usage: (include "plugin-br-pix-lerian.componentImagePullSecrets" (dict "context" $ "componentValues" .Values.spi)) | nindent 8
*/}}
{{- define "plugin-br-pix-lerian.componentImagePullSecrets" -}}
{{- $secrets := .componentValues.imagePullSecrets -}}
{{- if not $secrets -}}
{{- $secrets = .context.Values.global.imagePullSecrets -}}
{{- end -}}
{{- toYaml $secrets -}}
{{- end }}

{{/*
Common labels applied to every resource.
Usage: include "plugin-br-pix-lerian.labels" (dict "context" $ "component" "spi")
*/}}
{{- define "plugin-br-pix-lerian.labels" -}}
helm.sh/chart: {{ include "plugin-br-pix-lerian.chart" .context }}
{{ include "plugin-br-pix-lerian.selectorLabels" (dict "context" .context "component" .component) }}
app.kubernetes.io/version: {{ .context.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
app.kubernetes.io/part-of: {{ include "plugin-br-pix-lerian.name" .context }}
{{- end }}

{{/*
Selector labels (immutable subset for matchLabels).
Usage: include "plugin-br-pix-lerian.selectorLabels" (dict "context" $ "component" "spi")
*/}}
{{- define "plugin-br-pix-lerian.selectorLabels" -}}
app.kubernetes.io/name: {{ include "plugin-br-pix-lerian.componentFullname" (dict "context" .context "component" .component) }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Per-component service account name.
Usage: include "plugin-br-pix-lerian.componentServiceAccountName" (dict "context" $ "component" "spi" "componentValues" .Values.spi)
*/}}
{{- define "plugin-br-pix-lerian.componentServiceAccountName" -}}
{{- if .componentValues.serviceAccount.create -}}
{{- default (include "plugin-br-pix-lerian.componentFullname" (dict "context" .context "component" .component)) .componentValues.serviceAccount.name -}}
{{- else -}}
{{- default "default" .componentValues.serviceAccount.name -}}
{{- end -}}
{{- end }}

{{/*
Routed Ingress body shared by ingress-apps.yaml, ingress-providers.yaml and
ingress-systemplane.yaml. The three differ only in the values key, the ingress
component label and their file header comment, so the rendering logic lives
here once — the port-source defect that had to be fixed in all three files is
exactly the maintenance cost this removes.

Each route in `config.routes` names its target component twice:
  component   -- values key (camelCase, e.g. dictHub): source of BOTH the
                 enabled flag and service.port
  serviceName -- kebab-case Service suffix (e.g. dict-hub), optional; it is
                 derived from `component` when omitted
Both spellings must describe the SAME component, otherwise the rule pairs one
component's Service with another component's port and every request to that
path fails. `kebabcase component` is exactly the Service suffix for all 15
component keys, so a mismatch is a render error rather than a silent misroute.

Usage:
  {{- include "plugin-br-pix-lerian.routedIngress" (dict "context" $ "component" "apps" "config" .Values.appsIngress) }}
*/}}
{{- define "plugin-br-pix-lerian.routedIngress" -}}
{{- $ctx := .context }}
{{- $cfg := .config }}
{{- $component := .component }}
{{- $fullName := include "plugin-br-pix-lerian.componentFullname" (dict "context" $ctx "component" $component) }}
{{- /* Collect routes whose target component is enabled. */}}
{{- $renderedRoutes := list }}
{{- range $route := $cfg.routes }}
  {{- $componentValues := index $ctx.Values $route.component }}
  {{- if not $componentValues }}
    {{- fail (printf "\n\nERROR: %s ingress route %q names unknown component %q.\n" $component $route.path $route.component) }}
  {{- end }}
  {{- $expectedServiceName := kebabcase $route.component }}
  {{- if and $route.serviceName (ne $route.serviceName $expectedServiceName) }}
    {{- fail (printf "\n\nERROR: %s ingress route %q sets serviceName %q but component %q resolves to Service suffix %q — the two must name the same component, otherwise the rule pairs one component's Service with another component's port.\n" $component $route.path $route.serviceName $route.component $expectedServiceName) }}
  {{- end }}
  {{- if $componentValues.enabled }}
    {{- $renderedRoutes = append $renderedRoutes $route }}
  {{- end }}
{{- end }}
{{- if $renderedRoutes }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $fullName }}
  namespace: {{ include "global.namespace" $ctx }}
  labels:
    {{- include "plugin-br-pix-lerian.labels" (dict "context" $ctx "component" $component) | nindent 4 }}
  {{- with $cfg.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- with $cfg.className }}
  ingressClassName: {{ . }}
  {{- end }}
  {{- with $cfg.tls }}
  tls:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  rules:
    {{- range $host := $cfg.hosts }}
    - host: {{ $host | quote }}
      http:
        paths:
          {{- range $route := $renderedRoutes }}
          {{- $componentValues := index $ctx.Values $route.component }}
          {{- $serviceFullname := include "plugin-br-pix-lerian.componentFullname" (dict "context" $ctx "component" (default (kebabcase $route.component) $route.serviceName)) }}
          - path: {{ $route.path }}
            pathType: {{ default "Prefix" $route.pathType }}
            backend:
              service:
                name: {{ $serviceFullname }}
                port:
                  number: {{ $componentValues.service.port }}
          {{- end }}
    {{- end }}
{{- end }}
{{- end }}

{{/*
Resolve the secret name to use for envFrom.
When useExistingSecret=true, returns the externally-managed name; otherwise the chart-rendered one.
*/}}
{{- define "plugin-br-pix-lerian.componentSecretName" -}}
{{- if .componentValues.useExistingSecret -}}
{{- .componentValues.existingSecretName -}}
{{- else -}}
{{- include "plugin-br-pix-lerian.componentFullname" (dict "context" .context "component" .component) -}}
{{- end -}}
{{- end }}

{{/*
Wait-for-dependencies init container.
Parses DATABASE_URL / VALKEY_URL / MONGO_URL / RABBITMQ_URI from the
component's ConfigMap and Secret and waits for each to be reachable via nc -z.
Skips any URL that is empty / unset.

Usage:
  initContainers:
    {{- include "plugin-br-pix-lerian.waitForDependencies" (dict "context" $ "component" $component "componentValues" $values) | nindent 8 }}
*/}}
{{- define "plugin-br-pix-lerian.waitForDependencies" -}}
- name: wait-for-dependencies
  securityContext:
    runAsGroup: 1000
    runAsUser: 1000
    runAsNonRoot: true
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
    seccompProfile:
      type: RuntimeDefault
  image: busybox:1.37
  envFrom:
    - configMapRef:
        name: {{ include "plugin-br-pix-lerian.componentFullname" (dict "context" .context "component" .component) }}
    - secretRef:
        name: {{ include "plugin-br-pix-lerian.componentSecretName" (dict "context" .context "component" .component "componentValues" .componentValues) }}
  command:
    - /bin/sh
    - -c
    - |
      set -eu
      MAX_ATTEMPTS=60
      SLEEP_SECONDS=5

      wait_for_service() {
        local NAME="$1"
        local HOST="$2"
        local PORT="$3"
        if [ -z "$HOST" ]; then
          echo "skip: $NAME (not configured)"
          return 0
        fi
        local ATTEMPTS=0
        echo "wait: $NAME at $HOST:$PORT"
        while ! nc -z "$HOST" "$PORT" 2>/dev/null; do
          ATTEMPTS=$((ATTEMPTS + 1))
          if [ "$ATTEMPTS" -ge "$MAX_ATTEMPTS" ]; then
            echo "timeout: $NAME at $HOST:$PORT after $((MAX_ATTEMPTS * SLEEP_SECONDS))s"
            exit 1
          fi
          echo "  $NAME not ready (attempt $ATTEMPTS/$MAX_ATTEMPTS)"
          sleep "$SLEEP_SECONDS"
        done
        echo "ready: $NAME at $HOST:$PORT"
      }

      # Parse URL of the form scheme://[user[:pass]@]host[:port]/path
      # Outputs: HOST PORT  (port empty when scheme default applies)
      parse_url() {
        local URL="$1"
        if [ -z "$URL" ]; then
          echo ""
          return
        fi
        # Strip scheme
        local REST="${URL#*://}"
        # Strip userinfo if present
        case "$REST" in
          *@*) REST="${REST#*@}" ;;
        esac
        # Strip path/query/fragment
        REST="${REST%%/*}"
        REST="${REST%%\?*}"
        # Split host:port
        local HOST="${REST%%:*}"
        local PORT="${REST##*:}"
        if [ "$HOST" = "$PORT" ]; then
          PORT=""
        fi
        echo "$HOST $PORT"
      }

      # PostgreSQL (DATABASE_URL)
      set -- $(parse_url "${DATABASE_URL:-}")
      wait_for_service "postgres" "${1:-}" "${2:-5432}"

      # Valkey/Redis (VALKEY_URL)
      set -- $(parse_url "${VALKEY_URL:-}")
      wait_for_service "valkey" "${1:-}" "${2:-6379}"

      # MongoDB (MONGO_URL)
      set -- $(parse_url "${MONGO_URL:-}")
      wait_for_service "mongo" "${1:-}" "${2:-27017}"

      # RabbitMQ (RABBITMQ_URI) — TLS-only: default to the amqps port (5671).
      # All documented URIs carry an explicit :5671; this fallback only applies
      # to a portless amqps:// URI, so it must not assume the plaintext 5672.
      RABBIT_DEFAULT_PORT=5671
      case "${RABBITMQ_URI:-}" in
        amqp://*) RABBIT_DEFAULT_PORT=5672 ;;
        amqps://*) RABBIT_DEFAULT_PORT=5671 ;;
      esac
      set -- $(parse_url "${RABBITMQ_URI:-}")
      wait_for_service "rabbitmq" "${1:-}" "${2:-$RABBIT_DEFAULT_PORT}"

      echo "all dependencies ready"
{{- end }}
