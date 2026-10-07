{{/*
==============================================================================
lerian-common — Deployment sub-blocks (pod-spec fragments).

The full Deployment is too variable to share, but these pod-spec tail fragments
are byte-identical across ~51 workloads. Each renders NOTHING when its value is
empty, so wrap the include in the caller so it only appears when present:

  {{- if or .Values.fees.nodeSelector .Values.fees.affinity .Values.fees.tolerations }}
      {{- include "lerian-common.scheduling" .Values.fees | nindent 6 }}
  {{- end }}
  {{- with .Values.fees.imagePullSecrets }}
      {{- include "lerian-common.imagePullSecrets" . | nindent 6 }}
  {{- end }}

Emitting at base indent 0 (keys) + toYaml nindent 2; the caller's `nindent 6`
shifts keys to col 6 and values to col 8 — matching the hand-written blocks.
*/}}

{{/*
lerian-common.scheduling — nodeSelector / affinity / tolerations, plus (opt-in)
topologySpreadConstraints.

Input — TWO accepted shapes (the first is the original, unchanged contract):

  1. The component values map (legacy). Reads .nodeSelector/.affinity/.tolerations
     ONLY; never renders topologySpreadConstraints. Output is byte-identical to
     every release before the spread preset existed.

       {{- include "lerian-common.scheduling" .Values.fees | nindent 6 }}

  2. A dict with the keys `component` AND `selectorLabels` (spread-aware). Renders
     the same three fields from `component`, then the topologySpreadConstraints
     resolved by `lerian-common.topologySpreadConstraints` (see below):

       {{- with (include "lerian-common.scheduling" (dict
             "component"      .Values.manager
             "global"         .Values.global
             "selectorLabels" (include "myapp.selectorLabels" .)) | trim) }}
       {{- . | nindent 6 }}
       {{- end }}

     `selectorLabels` MUST be exactly the Deployment's spec.selector.matchLabels
     (a dict or the rendered YAML string of the chart's selectorLabels helper) —
     the library never guesses labels. Use shape 2 for Deployments only: Jobs /
     CronJobs keep shape 1 (spreading a run-to-completion pod is meaningless).
*/}}
{{- define "lerian-common.scheduling" -}}
{{- $in := . | default dict -}}
{{- $comp := $in -}}
{{- $spreadAware := false -}}
{{- if and (kindIs "map" $in) (hasKey $in "component") (hasKey $in "selectorLabels") -}}
{{- $comp = $in.component | default dict -}}
{{- $spreadAware = true -}}
{{- end -}}
{{- with $comp.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $comp.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $comp.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- if $spreadAware }}
{{- with (include "lerian-common.topologySpreadConstraints" $in) }}
{{ . }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
lerian-common.topologySpreadConstraints — the pod-spec `topologySpreadConstraints:`
block for ONE workload, or "" (nothing) when spreading is off. Emits at column 0
(caller nindents). Also usable standalone by charts that hand-write their
nodeSelector/affinity/tolerations.

Input dict:
  component      — the component values block (reads .spread / .topologySpreadConstraints)
  global         — the chart's .Values.global (reads .scheduling.spread); optional
  selectorLabels — the Deployment's spec.selector.matchLabels (dict, or the YAML
                   string rendered by the chart's selectorLabels helper). Required
                   whenever a constraint is rendered.

Resolution (first matching tier wins):
  1. component.topologySpreadConstraints — non-empty raw list; wins ENTIRELY (the
     preset is ignored). Rendered verbatim, except an entry WITHOUT a
     labelSelector gets `labelSelector.matchLabels: <selectorLabels>` (a selector-
     less constraint counts no pods and spreads nothing).
  2. Preset `spread`, resolved FIELD BY FIELD:
       component.spread.<field> > global.scheduling.spread.<field> > built-in
     Built-in: enabled=false (off), hostname="", zone="", maxSkew=1, minDomains=0 (off),
     nodeTaintsPolicy="" (omitted: Kubernetes default Ignore).
  3. Nothing.

Expected values shape (a library chart cannot ship defaults to its consumers —
each consumer declares these keys in its own values.yaml / schema):

  global:
    scheduling:
      spread:
        enabled: true            # bool — master switch for the preset
        hostname: ScheduleAnyway # ScheduleAnyway | DoNotSchedule | "" (off) — kubernetes.io/hostname
        zone: ScheduleAnyway     # ScheduleAnyway | DoNotSchedule | "" (off) — topology.kubernetes.io/zone
        maxSkew: 1               # int >= 1
        minDomains: 0            # int >= 0; 0 = off. Applied to DoNotSchedule constraints only
        nodeTaintsPolicy: ""     # Honor | Ignore | "" (omitted = Kubernetes default Ignore)
  <component>:
    spread: {}                   # same fields; each one set overrides the global one
    topologySpreadConstraints: [] # raw k8s list; non-empty = wins entirely

Every preset constraint carries `matchLabelKeys: [pod-template-hash]` so only
pods of the SAME ReplicaSet are counted: during a rolling update the old
ReplicaSet's pods do not block the new ones (avoids a DoNotSchedule deadlock).
Requires Kubernetes >= 1.27 with the MatchLabelKeysInPodTopologySpread feature
gate enabled (beta since 1.27 and on by default, including 1.33; it can be disabled).

minDomains (Kubernetes >= 1.30, GA): with fewer eligible domains than
minDomains the scheduler treats the global minimum as 0. Without it, a hard
(DoNotSchedule) hostname spread is satisfied by a SINGLE eligible node holding
every replica (skew is measured only against domains that exist), so e.g. 2
replicas on a 1-node Karpenter pool share that node. minDomains: 2 keeps the
second replica Pending until another node exists (Karpenter honours it). It is
only emitted on DoNotSchedule constraints: the API rejects minDomains with
ScheduleAnyway.

nodeTaintsPolicy (Kubernetes >= 1.26 beta, GA 1.33): with Ignore (the default)
nodes carrying taints the pod does not tolerate still count as domains, e.g. a
node Karpenter is draining (karpenter.sh/disrupted:NoSchedule) or a dedicated
tainted pool matched by the node affinity. They distort skew and can satisfy
minDomains while unable to take the pod. Honor counts only nodes whose taints the
pod tolerates (Karpenter honours it). Applied to every preset constraint.

Invalid input fails the render with an explicit message: unknown spread field,
non-bool enabled, whenUnsatisfiable outside {ScheduleAnyway, DoNotSchedule, ""},
non-integer or < 1 maxSkew, non-integer or < 0 minDomains, nodeTaintsPolicy
outside {Honor, Ignore, ""}, non-list
topologySpreadConstraints, or a constraint to render with empty selectorLabels.
*/}}
{{- define "lerian-common.topologySpreadConstraints" -}}
{{- $comp := .component | default dict -}}
{{- /* Type-check every explicitly supplied (non-null) value BEFORE `default`:
       `default` treats false / [] / {} as empty and would silently swallow a
       wrong-typed value. An empty map / list stays valid (documented default). */ -}}
{{- $globalScheduling := (.global | default dict).scheduling -}}
{{- if and (not (kindIs "invalid" $globalScheduling)) (not (kindIs "map" $globalScheduling)) -}}
{{- fail (printf "lerian-common.topologySpreadConstraints: global.scheduling must be a map, got %s" (kindOf $globalScheduling)) -}}
{{- end -}}
{{- $globalScheduling = $globalScheduling | default dict -}}
{{- if and (not (kindIs "invalid" $globalScheduling.spread)) (not (kindIs "map" $globalScheduling.spread)) -}}
{{- fail (printf "lerian-common.topologySpreadConstraints: global.scheduling.spread must be a map, got %s" (kindOf $globalScheduling.spread)) -}}
{{- end -}}
{{- if and (not (kindIs "invalid" $comp.spread)) (not (kindIs "map" $comp.spread)) -}}
{{- fail (printf "lerian-common.topologySpreadConstraints: <component>.spread must be a map, got %s" (kindOf $comp.spread)) -}}
{{- end -}}
{{- $globalSpread := $globalScheduling.spread | default dict -}}
{{- $compSpread := $comp.spread | default dict -}}
{{- $sel := .selectorLabels | default dict -}}
{{- if kindIs "string" $sel -}}
{{- $sel = fromYaml $sel | default dict -}}
{{- end -}}
{{- if hasKey $sel "Error" -}}
{{- fail (printf "lerian-common.topologySpreadConstraints: selectorLabels is not valid YAML (%s)" $sel.Error) -}}
{{- end -}}
{{- $constraints := list -}}
{{- $raw := $comp.topologySpreadConstraints -}}
{{- if and (not (kindIs "invalid" $raw)) (not (kindIs "slice" $raw)) -}}
{{- fail (printf "lerian-common.topologySpreadConstraints: <component>.topologySpreadConstraints must be a list, got %s" (kindOf $raw)) -}}
{{- end -}}
{{- if $raw -}}
{{- /* Tier 1: raw list wins entirely. */ -}}
{{- range $raw -}}
{{- $tsc := deepCopy . -}}
{{- if not (hasKey $tsc "labelSelector") -}}
{{- $_ := set $tsc "labelSelector" (dict "matchLabels" $sel) -}}
{{- end -}}
{{- $constraints = append $constraints $tsc -}}
{{- end -}}
{{- else -}}
{{- /* Tier 2: preset, field-level precedence. hasKey (not `default`/merge) so an
       explicit component `false` / "" overrides a global true / ScheduleAnyway. */ -}}
{{- $fields := list "enabled" "hostname" "zone" "maxSkew" "minDomains" "nodeTaintsPolicy" -}}
{{- $s := dict "enabled" false "hostname" "" "zone" "" "maxSkew" 1 "minDomains" 0 "nodeTaintsPolicy" "" -}}
{{- range $tier := list (list "global.scheduling.spread" $globalSpread) (list "<component>.spread" $compSpread) -}}
{{- $where := index $tier 0 -}}
{{- $t := index $tier 1 -}}
{{- if not (kindIs "map" $t) -}}
{{- fail (printf "lerian-common.topologySpreadConstraints: %s must be a map, got %s" $where (kindOf $t)) -}}
{{- end -}}
{{- range $k, $v := $t -}}
{{- if not (has $k $fields) -}}
{{- fail (printf "lerian-common.topologySpreadConstraints: unknown field %s.%s (allowed: enabled, hostname, zone, maxSkew, minDomains, nodeTaintsPolicy)" $where $k) -}}
{{- end -}}
{{- if not (kindIs "invalid" $v) -}}
{{- $_ := set $s $k $v -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if not (kindIs "bool" $s.enabled) -}}
{{- fail (printf "lerian-common.topologySpreadConstraints: spread.enabled must be a boolean, got %v (%s)" $s.enabled (kindOf $s.enabled)) -}}
{{- end -}}
{{- $skew := $s.maxSkew -}}
{{- if not (or (kindIs "int" $skew) (kindIs "int64" $skew) (kindIs "float64" $skew)) -}}
{{- fail (printf "lerian-common.topologySpreadConstraints: spread.maxSkew must be an integer >= 1, got %v (%s)" $skew (kindOf $skew)) -}}
{{- end -}}
{{- /* Numeric (not toString) integrality check: a large YAML number arrives as
       float64 and would stringify in scientific notation. Upper bound: int32 in the API. */ -}}
{{- if or (ne (float64 (int64 $skew)) (float64 $skew)) (lt (int64 $skew) 1) (gt (int64 $skew) 2147483647) -}}
{{- fail (printf "lerian-common.topologySpreadConstraints: spread.maxSkew must be an integer between 1 and 2147483647, got %v" $skew) -}}
{{- end -}}
{{- $minDomains := $s.minDomains -}}
{{- if not (or (kindIs "int" $minDomains) (kindIs "int64" $minDomains) (kindIs "float64" $minDomains)) -}}
{{- fail (printf "lerian-common.topologySpreadConstraints: spread.minDomains must be an integer >= 0 (0 = off), got %v (%s)" $minDomains (kindOf $minDomains)) -}}
{{- end -}}
{{- if or (ne (float64 (int64 $minDomains)) (float64 $minDomains)) (lt (int64 $minDomains) 0) (gt (int64 $minDomains) 2147483647) -}}
{{- fail (printf "lerian-common.topologySpreadConstraints: spread.minDomains must be an integer between 0 (off) and 2147483647, got %v" $minDomains) -}}
{{- end -}}
{{- $taintPolicy := $s.nodeTaintsPolicy -}}
{{- if not (and (kindIs "string" $taintPolicy) (has $taintPolicy (list "Honor" "Ignore" ""))) -}}
{{- fail (printf "lerian-common.topologySpreadConstraints: spread.nodeTaintsPolicy must be Honor, Ignore or \"\" (omitted), got %v" $taintPolicy) -}}
{{- end -}}
{{- range $k := list "hostname" "zone" -}}
{{- $w := index $s $k -}}
{{- if not (and (kindIs "string" $w) (has $w (list "ScheduleAnyway" "DoNotSchedule" ""))) -}}
{{- fail (printf "lerian-common.topologySpreadConstraints: spread.%s must be ScheduleAnyway, DoNotSchedule or \"\" (off), got %v" $k $w) -}}
{{- end -}}
{{- end -}}
{{- if $s.enabled -}}
{{- range $k, $topo := dict "hostname" "kubernetes.io/hostname" "zone" "topology.kubernetes.io/zone" -}}
{{- with (index $s $k) -}}
{{- $tsc := dict
      "maxSkew" (int64 $skew)
      "topologyKey" $topo
      "whenUnsatisfiable" .
      "labelSelector" (dict "matchLabels" $sel)
      "matchLabelKeys" (list "pod-template-hash") -}}
{{- if and (eq . "DoNotSchedule") (gt (int64 $minDomains) 0) -}}
{{- $_ := set $tsc "minDomains" (int64 $minDomains) -}}
{{- end -}}
{{- with $taintPolicy -}}
{{- $_ := set $tsc "nodeTaintsPolicy" . -}}
{{- end -}}
{{- $constraints = append $constraints $tsc -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if $constraints -}}
{{- if not $sel -}}
{{- fail "lerian-common.topologySpreadConstraints: selectorLabels is empty — pass the Deployment's spec.selector.matchLabels (an empty selector would spread against every pod in the namespace)" -}}
{{- end -}}
topologySpreadConstraints:
  {{- toYaml $constraints | nindent 2 }}
{{- end -}}
{{- end -}}

{{/*
lerian-common.imagePullSecrets — the imagePullSecrets block.
Input: the imagePullSecrets list (wrap the include in `{{- with }}` in the caller).
*/}}
{{- define "lerian-common.imagePullSecrets" -}}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end -}}

{{/*
lerian-common.deploymentStrategy — the `strategy:` block (type + optional
rollingUpdate). Byte-identical across the "type + if RollingUpdate" family
(~11 deployments) whose value shapes differ (flat `deploymentUpdate.*` vs
nested `deploymentStrategy.rollingUpdate.*`, some with inline `| default`).
The helper is shape-agnostic: the CALLER pre-resolves the three values (applying
its own defaults) so the output stays byte-identical.

Usage (flat deploymentUpdate shape):
  {{- include "lerian-common.deploymentStrategy" (dict
        "type" .Values.matcher.deploymentUpdate.type
        "maxSurge" .Values.matcher.deploymentUpdate.maxSurge
        "maxUnavailable" .Values.matcher.deploymentUpdate.maxUnavailable
      ) | nindent 2 }}

Usage (nested deploymentStrategy shape):
  {{- include "lerian-common.deploymentStrategy" (dict
        "type" .Values.manager.deploymentStrategy.type
        "maxSurge" .Values.manager.deploymentStrategy.rollingUpdate.maxSurge
        "maxUnavailable" .Values.manager.deploymentStrategy.rollingUpdate.maxUnavailable
      ) | nindent 2 }}

Inputs: type, maxSurge, maxUnavailable. Caller: nindent 2 (under spec:).
*/}}
{{- define "lerian-common.deploymentStrategy" -}}
strategy:
  type: {{ .type }}
  {{- if eq .type "RollingUpdate" }}
  rollingUpdate:
    maxSurge: {{ .maxSurge }}
    maxUnavailable: {{ .maxUnavailable }}
  {{- end }}
{{- end -}}

{{/*
lerian-common.httpProbe — one httpGet probe block (readiness/liveness/startup).
Probes appear in ~49 deployments with an identical structure but the ORDER and
DEFAULTS vary per chart, so this emits ONE block; the chart calls it once per
probe in its own order, passing its own defaults (byte-identical).

Usage (deployment.yaml, preserving the chart's existing probe order):
          {{- include "lerian-common.httpProbe" (dict
                "kind" "readinessProbe" "probe" .Values.fees.readinessProbe
                "port" .Values.fees.service.port
                "path" "/readyz" "initialDelay" 10 "period" 5 "timeout" 1 "success" 1 "failure" 3
              ) | nindent 10 }}
          {{- include "lerian-common.httpProbe" (dict
                "kind" "livenessProbe" "probe" .Values.fees.livenessProbe
                "port" .Values.fees.service.port
                "path" "/health" "initialDelay" 5 "period" 5 "timeout" 1 "success" 1 "failure" 3
              ) | nindent 10 }}

Inputs: kind, probe (values map), port, path, initialDelay, period, timeout, success, failure.
*/}}
{{- define "lerian-common.httpProbe" -}}
{{- $p := .probe | default dict -}}
{{ .kind }}:
  httpGet:
    path: {{ $p.path | default .path }}
    port: {{ .port }}
  {{- /* hasKey (not | default) so an explicit 0 override is honored, not treated as absent. */}}
  initialDelaySeconds: {{ if hasKey $p "initialDelaySeconds" }}{{ $p.initialDelaySeconds }}{{ else }}{{ .initialDelay }}{{ end }}
  periodSeconds: {{ if hasKey $p "periodSeconds" }}{{ $p.periodSeconds }}{{ else }}{{ .period }}{{ end }}
  timeoutSeconds: {{ if hasKey $p "timeoutSeconds" }}{{ $p.timeoutSeconds }}{{ else }}{{ .timeout }}{{ end }}
  successThreshold: {{ if hasKey $p "successThreshold" }}{{ $p.successThreshold }}{{ else }}{{ .success }}{{ end }}
  failureThreshold: {{ if hasKey $p "failureThreshold" }}{{ $p.failureThreshold }}{{ else }}{{ .failure }}{{ end }}
{{- end -}}
