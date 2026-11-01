{{/*
==============================================================================
lerian-common — health preset (probes, drain, grace, rollout, PDB, ALB check).

Liveness is process-only, readiness reports the pod's own state, and a shared
dependency is only reported: the lib serves /health and /readyz on HEALTH_PORT
(8099, never a Service port). Paths, ports, timings, strategy and grace are not
values: the preset owns them and the render refuses overrides.

Returns YAML; the caller reads it with `fromYaml` and places each key:

  {{- $h := include "lerian-common.health" (dict
        "name" "ledger" "component" .Values.ledger "health" .Values.ledger.health
        "port" .Values.ledger.service.port "minImage" "v3.1.0"
        "autoscaling" .Values.ledger.autoscaling) | fromYaml }}

  replicas / strategy       Deployment spec (`toYaml`)
  autoscaling               only when the caller's autoscaling is enabled on a non-singleton: its map with
                            minReplicas defaulted to 2 when unset; pass it to lerian-common.hpa
  terminationGracePeriodSeconds, ports, env, startupProbe, livenessProbe,
  readinessProbe, lifecycle pod spec / MAIN container (`ports` and `env` are
                            appended to the container's own lists; `lifecycle`
                            only for next/static/external)
  pdb                       absent for a singleton; else pass to lerian-common.pdb
  alb                       {path, port} for lerian-common.ingress `healthcheck`

The preset owns probes, grace and the drain env. shutdownSeconds >= 1 because the
lib refuses to boot with SHUTDOWN_TIMEOUT <= 0; startupBudgetSeconds >= 5.

Inputs: name, component (values map: reads image.tag, configmap, the probe keys), health (the component's `health` map), port (main container
port, required unless stack go-worker), minImage (first image serving the health
port, chart-owned), replicas (optional configured count), autoscaling (optional).

==============================================================================
*/}}
{{- define "lerian-common.health" -}}
{{- $n := .name -}}
{{- $c := .component | default dict -}}
{{- $h := .health | default dict -}}
{{- $stack := $h.stack | default "" -}}
{{- if not (has $stack (list "go" "go-worker" "next" "static" "external")) -}}
{{- fail (printf "lerian-common.health: %s: health.stack must be go, go-worker, next, static or external, got %q" $n $stack) -}}
{{- end -}}
{{- $allowed := list "stack" "drainSeconds" "shutdownSeconds" "singleton" -}}
{{- if eq $stack "external" -}}{{- $allowed = concat $allowed (list "livenessPath" "readinessPath" "port" "startupBudgetSeconds") -}}{{- end -}}
{{- range $k := keys $h -}}
{{- if not (has $k $allowed) -}}{{- fail (printf "lerian-common.health: %s: health.%s is not a value for stack %s (allowed: %s)" $n $k $stack (join ", " $allowed)) -}}{{- end -}}
{{- end -}}
{{- range $k := list "livenessProbe" "readinessProbe" "startupProbe" "terminationGracePeriodSeconds" -}}
{{- if index $c $k -}}{{- fail (printf "lerian-common.health: %s: %s is owned by the health preset; remove it (tune health.drainSeconds / health.shutdownSeconds)" $n $k) -}}{{- end -}}
{{- end -}}
{{- range $k := list "SHUTDOWN_DRAIN_DELAY" "SHUTDOWN_TIMEOUT" "HEALTH_PORT" -}}
{{- if and (kindIs "map" $c.configmap) (hasKey $c.configmap $k) -}}{{- fail (printf "lerian-common.health: %s: configmap.%s is owned by the health preset; use health.drainSeconds / health.shutdownSeconds" $n $k) -}}{{- end -}}
{{- end -}}
{{- if not .minImage -}}{{- fail (printf "lerian-common.health: %s: minImage is required" $n) -}}{{- end -}}
{{- $tag := toString (($c.image | default dict).tag | default "") -}}
{{- if and (regexMatch "^v?[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?(\\+[0-9A-Za-z.-]+)?$" $tag) (lt ((semver $tag).Compare (semver .minImage)) 0) -}}
{{- fail (printf "lerian-common.health: %s: image.tag %s is below %s, the first image that serves the health port" $n $tag .minImage) -}}
{{- end -}}
{{- if and (ne $stack "go-worker") (not .port) -}}{{- fail (printf "lerian-common.health: %s: port (main container port) is required for stack %s" $n $stack) -}}{{- end -}}
{{- $singleton := $h.singleton | default false -}}
{{- $replicas := 2 -}}
{{- if not (kindIs "invalid" .replicas) -}}{{- $replicas = int .replicas -}}{{- end -}}
{{- if $singleton -}}
{{- if kindIs "invalid" .replicas -}}{{- $replicas = 1 -}}{{- end -}}
{{- if gt $replicas 1 -}}{{- fail (printf "lerian-common.health: %s: a singleton runs 1 replica, got %v" $n .replicas) -}}{{- end -}}
{{- if (.autoscaling | default dict).enabled -}}{{- fail (printf "lerian-common.health: %s: a singleton has no autoscaling" $n) -}}{{- end -}}
{{- end -}}
{{- range $k, $min := dict "drainSeconds" 0 "shutdownSeconds" 1 "startupBudgetSeconds" 5 -}}
{{- if and (hasKey $h $k) (or (not (regexMatch "^[0-9]+$" (toString (index $h $k)))) (lt (int (index $h $k)) $min)) -}}{{- fail (printf "lerian-common.health: %s: health.%s must be an integer number of seconds >= %d" $n $k $min) -}}{{- end -}}
{{- end -}}
{{- $d := 15 -}}{{- if hasKey $h "drainSeconds" -}}{{- $d = int $h.drainSeconds -}}{{- end -}}
{{- $t := 30 -}}{{- if hasKey $h "shutdownSeconds" -}}{{- $t = int $h.shutdownSeconds -}}{{- end -}}
{{- $out := dict "replicas" $replicas "strategy" (dict "type" "Recreate") -}}
{{- if not $singleton -}}
{{- if (.autoscaling | default dict).enabled -}}{{- $a := deepCopy .autoscaling -}}{{- if kindIs "invalid" $a.minReplicas -}}{{- $_ := set $a "minReplicas" 2 -}}{{- end -}}{{- $_ := set $out "autoscaling" $a -}}{{- end -}}
{{- $_ := set $out "strategy" (dict "type" "RollingUpdate" "rollingUpdate" (dict "maxSurge" "25%" "maxUnavailable" 0)) -}}
{{- $_ := set $out "pdb" (dict "maxUnavailable" 1 "unhealthyPodEvictionPolicy" "AlwaysAllow") -}}
{{- end -}}
{{- $probePort := "health" -}}{{- $live := "/health" -}}{{- $ready := "/readyz" -}}
{{- $sleep := 0 -}}{{- $grace := 0 -}}
{{- if or (eq $stack "go") (eq $stack "go-worker") -}}
{{- if eq $stack "go-worker" -}}{{- $d = 0 -}}{{- end -}}
{{- $grace = add $d $t 10 -}}
{{- $_ := set $out "ports" (list (dict "name" "health" "containerPort" 8099)) -}}
{{- $_ := set $out "env" (list (dict "name" "HEALTH_PORT" "value" "8099") (dict "name" "SHUTDOWN_DRAIN_DELAY" "value" (printf "%ds" $d)) (dict "name" "SHUTDOWN_TIMEOUT" "value" (printf "%ds" $t))) -}}
{{- else -}}
{{- $probePort = int .port -}}
{{- if eq $stack "next" -}}
{{- $live = "/api/admin/health/alive" -}}{{- $ready = "/api/admin/health/readyz" -}}{{- $sleep = $d -}}{{- $grace = add $d 15 -}}
{{- else if eq $stack "static" -}}
{{- $live = "/healthz" -}}{{- $ready = "/healthz" -}}{{- $sleep = 5 -}}{{- $grace = 15 -}}
{{- else -}}
{{- if not (and $h.livenessPath $h.readinessPath) -}}{{- fail (printf "lerian-common.health: %s: stack external requires health.livenessPath and health.readinessPath" $n) -}}{{- end -}}
{{- $live = $h.livenessPath -}}{{- $ready = $h.readinessPath -}}{{- $sleep = $d -}}{{- $grace = add $d $t 10 -}}
{{- if $h.port -}}{{- $probePort = int $h.port -}}{{- end -}}
{{- end -}}
{{- $_ := set $out "lifecycle" (dict "preStop" (dict "exec" (dict "command" (list "sleep" (toString $sleep))))) -}}
{{- end -}}
{{- $startThreshold := 60 -}}{{- if $h.startupBudgetSeconds -}}{{- $startThreshold = div (add (int $h.startupBudgetSeconds) 4) 5 -}}{{- end -}}
{{- $_ := set $out "terminationGracePeriodSeconds" $grace -}}
{{- $get := dict "path" $live "port" $probePort -}}
{{- $_ := set $out "startupProbe" (dict "httpGet" $get "periodSeconds" 5 "timeoutSeconds" 3 "failureThreshold" $startThreshold) -}}
{{- $_ := set $out "livenessProbe" (dict "httpGet" $get "periodSeconds" 10 "timeoutSeconds" 3 "failureThreshold" 3) -}}
{{- $_ := set $out "readinessProbe" (dict "httpGet" (set (deepCopy $get) "path" $ready) "periodSeconds" 5 "timeoutSeconds" 3 "failureThreshold" 3) -}}
{{- if .port -}}
{{- $albPort := int .port -}}{{- if and (eq $stack "external") $h.port -}}{{- $albPort = int $h.port -}}{{- end -}}
{{- $_ := set $out "alb" (dict "path" $live "port" $albPort) -}}
{{- end -}}
{{- toYaml $out -}}
{{- end -}}

{{/*
lerian-common.health.prometheusRule — opt-in PrometheusRule with the health
alerts (BYOC). Renders nothing unless monitoring.prometheusRule.enabled. The
health_* rules need the OTLP metrics of the Lerian services; the kube_* rules
work on any kube-prometheus-stack. Severity: page > ticket > warning.

Inputs: monitoring (.Values.monitoring: prometheusRule.{enabled, labels}),
name, labels (rendered block), namespace (the release namespace; also scopes
the kube_* rules).
*/}}
{{- define "lerian-common.health.prometheusRule" -}}
{{- $pr := ((.monitoring | default dict).prometheusRule) | default dict -}}
{{- if $pr.enabled -}}
{{- $ns := .namespace -}}
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: {{ .name }}
  namespace: {{ $ns }}
  labels:
    {{- .labels | nindent 4 }}
    {{- with $pr.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  groups:
    - name: {{ .name }}
      rules:
        - alert: HealthStoreDown
          expr: min by (job, check) (health_check_status{status="down", mode="startup"}) == 1
          for: 3m
          labels: {severity: page}
          annotations: {summary: "A request-path store is down on every pod of the service"}
        - alert: HealthStoreDownSomePods
          expr: max by (job, check) (health_check_status{status="down", mode="startup"}) == 1 and min by (job, check) (health_check_status{status="down", mode="startup"}) == 0
          for: 5m
          labels: {severity: page}
          annotations: {summary: "A request-path store is down on some pods of the service"}
        - alert: HealthReportCheckDown
          expr: max by (job, check) (health_check_status{status=~"down|degraded", mode="report"}) == 1
          for: 15m
          labels: {severity: warning}
          annotations: {summary: "A reported dependency is down or degraded"}
        - alert: HealthPodNotReady
          expr: health_ready < 1
          for: 10m
          labels: {severity: ticket}
          annotations: {summary: "A pod has not passed its own startup checks"}
        - alert: ServiceNoReadyReplicas
          expr: kube_deployment_status_replicas_available{namespace="{{ $ns }}"} == 0 and kube_deployment_spec_replicas{namespace="{{ $ns }}"} > 0
          for: 2m
          labels: {severity: page}
          annotations: {summary: "A deployment has no ready replica"}
        - alert: ContainerRestarting
          expr: increase(kube_pod_container_status_restarts_total{namespace="{{ $ns }}"}[15m]) > 2
          for: 0m
          labels: {severity: page}
          annotations: {summary: "A container restarted more than twice in 15 minutes"}
        - alert: CertificateExpiresSoon
          expr: cert_not_after_timestamp_seconds - time() < 30 * 86400
          for: 1h
          labels: {severity: warning}
          annotations: {summary: "A certificate expires in less than 30 days"}
        - alert: CertificateExpiresVerySoon
          expr: cert_not_after_timestamp_seconds - time() < 7 * 86400
          for: 1h
          labels: {severity: page}
          annotations: {summary: "A certificate expires in less than 7 days"}
        - alert: CalendarCoverageEnding
          expr: calendar_coverage_end_timestamp_seconds - time() < 90 * 86400
          for: 1h
          labels: {severity: warning}
          annotations: {summary: "The business calendar ends in less than 90 days"}
{{- end -}}
{{- end -}}
