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
path fails. `kebabcase component` is exactly the Service suffix for all 14
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
{{- /*
Resolve the Secret name a component's envFrom should reference.

Every component Deployment and the migration partial funnel through here, so
this is the one place that can guarantee the rendered `secretRef.name` is a
real, non-empty name. Two failure modes are rejected loudly instead of being
emitted as a broken manifest:

  1. useExistingSecret is a STRING. Go templates treat any non-empty string as
     truthy, so `useExistingSecret: "false"` — the exact thing an operator
     writes to turn the flag OFF, and what `--set-string` produces — selected
     the existing-secret branch and suppressed the chart-managed Secret. The
     schema now types this key, but a schema only guards values.yaml merges;
     this guard also covers `--set-string` and any caller that bypasses it.

  2. useExistingSecret is true while existingSecretName is empty. That produced
     `secretRef: {name: null}`, which the API server rejects, and the
     chart-managed Secret was suppressed as well, so there was nothing to fall
     back to. Failing the render surfaces the mistake at `helm template` time
     rather than as a CreateContainerConfigError after rollout.
*/ -}}
{{- define "plugin-br-pix-lerian.componentSecretName" -}}
{{- $component := .component -}}
{{- $values := .componentValues -}}
{{- $useExisting := $values.useExistingSecret -}}
{{- if and (not (kindIs "invalid" $useExisting)) (not (kindIs "bool" $useExisting)) -}}
{{- fail (printf "plugin-br-pix-lerian: %s.useExistingSecret must be a boolean, got %s (%#v). A quoted value such as \"false\" is truthy in Helm templates and would silently select an existing Secret; write it unquoted, and prefer --set over --set-string for this key." $component (kindOf $useExisting) $useExisting) -}}
{{- end -}}
{{- if $useExisting -}}
{{- $rawName := $values.existingSecretName -}}
{{- /*
  A non-string existingSecretName would survive toString as something like
  "map[key:value]" — non-empty, so it passes the emptiness check below, and
  then lands in secretRef.name where it is not a valid DNS subdomain and the
  API server rejects the Deployment. The schema already types this key, but
  --skip-schema-validation bypasses the schema and this helper is the last
  gate before the name is emitted.
*/ -}}
{{- if and (not (kindIs "invalid" $rawName)) (not (kindIs "string" $rawName)) -}}
{{- fail (printf "plugin-br-pix-lerian: %s.existingSecretName must be a string, got %s (%#v). secretRef.name has to be a DNS subdomain; a %s cannot render into one." $component (kindOf $rawName) $rawName (kindOf $rawName)) -}}
{{- end -}}
{{- $existingName := trim (toString (default "" $rawName)) -}}
{{- if eq $existingName "" -}}
{{- fail (printf "plugin-br-pix-lerian: %s.useExistingSecret is true but %s.existingSecretName is empty. Set existingSecretName to the name of the pre-existing Secret, or set useExistingSecret to false to let the chart render its own Secret." $component $component) -}}
{{- end -}}
{{- $existingName -}}
{{- else -}}
{{- include "plugin-br-pix-lerian.componentFullname" (dict "context" .context "component" $component) -}}
{{- end -}}
{{- end }}

{{/*
Wait-for-dependencies init container.
Parses DATABASE_URL / VALKEY_URL / RABBITMQ_URI from the
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
          # ##*@ (longest match), not #*@: a password may contain a literal
          # "@" - postgres://user:p@ss@db:5432/x - and the shortest match
          # would leave HOST="ss". A host part cannot contain "@", so the
          # last one is always the userinfo delimiter.
          *@*) REST="${REST##*@}" ;;
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

{{/*
plugin-br-pix-lerian.isTrue — "true" when the value is one of the tokens
strconv.ParseBool accepts as true, "" otherwise.

The apps load boolean env vars through ParseBool, so `TRUE`, `True`, `1`, `t`
and `T` all enable a feature at runtime. Comparing against the literal string
"true" would reject a valid `PLUGIN_AUTH_ENABLED=TRUE` at render time while the
process happily enables auth. Matching is exact (no trimming), like ParseBool:
" true" is false at runtime, so it must be false here too.

Modelled on midaz.isTrue (charts/midaz/templates/_helpers.tpl). It is duplicated
rather than shared because this chart does not declare the lerian-common-helm
dependency, and lerian-common ships no boolean helper anyway.
*/}}
{{- define "plugin-br-pix-lerian.isTrue" -}}
{{- if has (. | toString) (list "1" "t" "T" "TRUE" "true" "True") -}}true{{- end -}}
{{- end -}}

{{/*
plugin-br-pix-lerian.envGateState — the EFFECTIVE state of a boolean env var for
one component, resolved across the three sources the container actually reads.

WHY A RESOLVER. Every component's Deployment builds its environment as

    envFrom:
      - configMapRef: <component configmap>
      - secretRef:    <component secret>
    env:
      - <extraEnvVars entries>

Kubernetes resolves that in a fixed order: explicit `env` entries always win
over `envFrom`, and among `envFrom` sources the LAST one wins on a duplicate
key. All fourteen Deployments in this chart list configMapRef first and
secretRef second, so the effective precedence is

    extraEnvVars  >  secrets  >  configmap  >  default

A gate that reads only `.configmap.<KEY>` therefore inspects the LOWEST-priority
source. An operator who sets the key in `secrets` or `extraEnvVars` gets a
render decision made from a value the container will never see.

RETURN VALUE, one of:
  "on"       the effective value parses as true
  "off"      the effective value parses as false
  "unknown"  the decision depends on a Secret this template cannot read

"unknown" is returned when useExistingSecret=true AND the winning visible source
sits BELOW the Secret in the precedence order (i.e. the value came from
`configmap` or from the default). The external Secret can override those, and
Helm cannot inspect it, so any verdict would be a guess. When the winner is
`extraEnvVars` the answer is knowable even with an external Secret, because
explicit `env` beats every envFrom source - so that case still returns on/off.
This mirrors the repo's doctrine for external-Secret opacity, stated in
charts/lerian-common/templates/_streaming.tpl ("the value lives outside the
chart when useExistingSecret=true, so requiring it inline is wrong") and already
applied by this chart in templates/_migrations.tpl.

CONFLICTING OVERRIDES ARE FATAL. `secrets` and `extraEnvVars` are both
deliberate operator overrides, and there is no reading under which setting them
to opposing values is intentional, so that combination fails the render naming
both sources and values. `configmap` is NOT treated as a conflicting source: the
chart's own values.yaml already ships PLUGIN_AUTH_ENABLED there for all fourteen
components, so requiring the key to live in exactly one place would make
`secrets` and `extraEnvVars` unusable for it without first deleting the chart's
default. Against `configmap` the precedence rule applies and the override simply
wins - which is the whole point of an override. Identical values in several
sources are redundant but unambiguous, so they pass. The fatal-conflict shape
follows the modelled-key collision check in
charts/br-ccs/templates/configmap.yaml.

Inputs (dict):
  componentValues (req)  the component's values block (.Values.pixauto, ...)
  componentKey    (req)  its values path, for error messages ("pixauto")
  key             (req)  the env var name
  default         (opt)  value when no source carries the key (default "false")
*/}}
{{- define "plugin-br-pix-lerian.envGateState" -}}
{{- $cv := .componentValues | default dict -}}
{{- $key := .key -}}
{{- $ck := .componentKey -}}
{{/* `default dict` also absorbs an explicit `configmap: null` / `secrets: null`
     / `extraEnvVars: null` in values, which yields nil and would panic hasKey. */}}
{{- $cm := $cv.configmap | default dict -}}
{{- $sec := $cv.secrets | default dict -}}
{{- $extra := $cv.extraEnvVars | default dict -}}
{{- $external := eq (include "plugin-br-pix-lerian.isTrue" (default false $cv.useExistingSecret)) "true" -}}
{{/* Highest precedence first. An inline `secrets` map is not rendered at all
     when useExistingSecret=true, so it is not a source in that case. */}}
{{- $srcs := list -}}
{{- $vals := list -}}
{{- if hasKey $extra $key -}}
{{- $srcs = append $srcs (printf "%s.extraEnvVars.%s" $ck $key) -}}
{{- $vals = append $vals (toString (index $extra $key)) -}}
{{- end -}}
{{- if and (not $external) (hasKey $sec $key) -}}
{{- $srcs = append $srcs (printf "%s.secrets.%s" $ck $key) -}}
{{- $vals = append $vals (toString (index $sec $key)) -}}
{{- end -}}
{{- if hasKey $cm $key -}}
{{- $srcs = append $srcs (printf "%s.configmap.%s" $ck $key) -}}
{{- $vals = append $vals (toString (index $cm $key)) -}}
{{- end -}}
{{/* Conflict check across the two OVERRIDE sources only - see the note above on
     why `configmap` is excluded. */}}
{{- if and (hasKey $extra $key) (and (not $external) (hasKey $sec $key)) -}}
{{- $ev := toString (index $extra $key) -}}
{{- $sv := toString (index $sec $key) -}}
{{- if ne (include "plugin-br-pix-lerian.isTrue" $ev) (include "plugin-br-pix-lerian.isTrue" $sv) -}}
{{- fail (printf "plugin-br-pix-lerian: %s is overridden in two places with opposing values: %s.extraEnvVars.%s=%q and %s.secrets.%s=%q. Kubernetes would apply the extraEnvVars value (an explicit env entry beats every envFrom source), but two deliberate overrides disagreeing is an operator mistake rather than a preference to resolve. Remove one of them." $key $ck $key $ev $ck $key $sv) -}}
{{- end -}}
{{- end -}}
{{- if and $external (or (eq (len $srcs) 0) (ne (index $srcs 0) (printf "%s.extraEnvVars.%s" $ck $key))) -}}
{{- "unknown" -}}
{{- else -}}
{{/* if/else, not ternary: ternary evaluates BOTH branches, and `index` on an
     empty list is an error - which is exactly the no-source case. */}}
{{- $effective := toString (default "false" .default) -}}
{{- if gt (len $vals) 0 -}}
{{- $effective = index $vals 0 -}}
{{- end -}}
{{- if eq (include "plugin-br-pix-lerian.isTrue" $effective) "true" -}}
{{- "on" -}}
{{- else -}}
{{- "off" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
plugin-br-pix-lerian.podAnnotations — the pod template's annotations block:
the config-rollout checksums plus the operator's podAnnotations.

WHY A HELPER. The checksums must be emitted BEFORE the operator's map so the
block reads chart-owned-then-operator-owned, but that ordering is exactly what
lets an operator's `podAnnotations` key of the same name win: duplicate YAML
mapping keys resolve last-wins, so `podAnnotations["checksum/configmap"]` would
silently replace the rollout trigger and pods would stop restarting on a config
change. Six of the seven charts in this repo that emit checksums have that hole.
The keys are therefore RESERVED: setting one is refused outright, naming the
key, rather than dropped with `omit` - a silently ignored value is the same
class of bug in the other direction. Same shape as the modelled-key collision
check in charts/br-ccs/templates/configmap.yaml.

checksum/secret is emitted only when the chart renders the Secret. With
useExistingSecret=true the component's secrets.yaml renders nothing, so the hash
would be a constant that never changes and never triggers a rollout - it would
be noise claiming to be a trigger. Same gate as
charts/br-ccs/templates/deployment.yaml and
charts/plugin-fees/templates/fees/deployment.yaml. The annotation is still
reserved in that case, so an operator cannot quietly occupy the name.

The `checksum/configmap` spelling is kept as-is. Most charts here use
`checksum/config`, but renaming an annotation on a live Deployment changes the
pod template hash and forces one extra rollout across every component for no
behavioural gain.

Inputs (dict):
  context         (req)  root context ($)
  component       (req)  the component's template directory AND values-block
                         name in kebab-case ("spi", "dict-hub-vsync")
  componentKey    (req)  its values path, for error messages ("dictHubVsync")
  componentValues (req)  the component's values block
*/}}
{{- define "plugin-br-pix-lerian.podAnnotations" -}}
{{- $ctx := .context -}}
{{- $component := .component -}}
{{- $ck := .componentKey -}}
{{- $values := .componentValues | default dict -}}
{{- $reserved := list "checksum/configmap" "checksum/secret" -}}
{{- $extern := eq (include "plugin-br-pix-lerian.isTrue" (default false $values.useExistingSecret)) "true" -}}
{{- $pod := $values.podAnnotations | default dict -}}
{{- range $k, $_ := $pod -}}
{{- if has $k $reserved -}}
{{- fail (printf "plugin-br-pix-lerian: %s.podAnnotations.%q is reserved by this chart. It carries the checksum that rolls the pods when the component's ConfigMap or Secret changes, so overriding it would stop config updates from restarting the pods. Remove the key from podAnnotations; the chart emits it. Reserved keys: %s." $ck $k (join ", " $reserved)) -}}
{{- end -}}
{{- end -}}
annotations:
  checksum/configmap: {{ include (print $ctx.Template.BasePath "/" $component "/configmap.yaml") $ctx | sha256sum }}
  {{- if not $extern }}
  checksum/secret: {{ include (print $ctx.Template.BasePath "/" $component "/secrets.yaml") $ctx | sha256sum }}
  {{- end }}
  {{- with $pod }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end -}}

{{/*
Probe initialDelaySeconds, defaulted on key PRESENCE rather than truthiness.

`{{ $values.readinessProbe.initialDelaySeconds | default 10 }}` is wrong for
this one knob: Go templates treat 0 as empty, so an operator who sets
`initialDelaySeconds: 0` -- a legal value meaning "start probing immediately" --
silently gets the chart default instead. `dig` keys off whether the key is
present, so an explicit 0 survives. Same trap `_migrations.tpl` documents for
its own knobs.

Only initialDelaySeconds needs this. periodSeconds, timeoutSeconds,
successThreshold and failureThreshold all have a Kubernetes minimum of 1, so 0
is not a value the API server accepts there and `default` is harmless.

Usage:
  {{ include "plugin-br-pix-lerian.probeInitialDelay" (dict "probe" $values.readinessProbe "default" 10) }}
*/}}
{{- define "plugin-br-pix-lerian.probeInitialDelay" -}}
{{- dig "initialDelaySeconds" .default (.probe | default dict) -}}
{{- end -}}
