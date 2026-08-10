{{/*
==============================================================================
FLEET MANAGEMENT — remote configuration, off by default
==============================================================================
Renders the `remotecfg` block so enabling remote management is a flag, not a
config edit in the client cluster.

Facts this implementation is built on, each verified in the upstream docs:

  - it does NOT require the agent operator. `remotecfg` is a config block of the
    agent runtime, so the standalone chart is a supported path and we keep the
    operator's `bind`/`escalate` RBAC out of the cluster

  - transport is PULL, outbound HTTPS 443 only. Nothing dials into the client
    cluster, which is what makes it acceptable in a third-party network

  - local and remote configurations have SEPARATE component controllers:
    "Local and remote configurations cannot be in conflict." A remote pipeline
    cannot disable, replace or reference anything in the local config

  - therefore the sanitisation rules, which live in the local config, cannot be
    turned off remotely. That isolation is architectural, not a convention

⚠️ THE REAL RISK IS THE OPPOSITE OF THE OBVIOUS ONE.
Because the controllers are isolated, a remote pipeline cannot forward INTO our
local sanitisation either. A remote pipeline that declares its own exporter
would have a parallel egress path that never passes through masking.

So the hazard is not "remote turns my rule off" — it is "remote creates a path
that bypasses my rule". Mitigated by policy, not by config: use Fleet Management
for collection and discovery, and keep EXPORT local. See docs/FLEET-MANAGEMENT.md.

⚠️ Global blocks (logging, tracing, remotecfg itself, HTTP server) must stay
local — remote content is a module, not top-level config.
*/}}

{{- define "alloy-lerian.fleetEnabled" -}}
{{- $f := .Values.fleetManagement | default dict -}}
{{- ternary "true" "false" ($f.enabled | default false) -}}
{{- end -}}

{{/*
Renders the remotecfg block. Emits nothing when disabled, so the rendered config
is byte-identical to today's until someone opts in.
*/}}
{{- define "alloy-lerian.config.fleet" -}}
{{- if eq (include "alloy-lerian.fleetEnabled" .) "true" -}}
{{- $f := .Values.fleetManagement -}}
{{- if not $f.url -}}
{{- fail "\n\nalloy-lerian: fleetManagement.enabled is true but `fleetManagement.url` is empty.\n\nCopy the endpoint verbatim from the Fleet Management UI — the host format varies\nby stack and region, and building it by hand is a documented mistake.\n" -}}
{{- end -}}
{{- if not $f.username -}}
{{- fail "\n\nalloy-lerian: fleetManagement.enabled is true but `fleetManagement.username` is empty.\n\nIt is the numeric stack id shown in the Fleet Management UI.\n" -}}
{{- end -}}

// Remote configuration. Pull-based: this agent asks the service whether there is
// new configuration, on the interval below. Nothing connects inbound.
remotecfg {
  url = {{ $f.url | quote }}

  // Stable and unique per pod. NOT constants.hostname and NOT the auto-generated
  // seed: the seed is persisted to the agent's storage path, which on an
  // ephemeral pod is lost on every restart — producing a new collector identity
  // each time and churn in the fleet registry.
  id = sys.env("ALLOY_FLEET_COLLECTOR_ID")

  attributes = {
{{- range $k, $v := ($f.attributes | default dict) }}
    {{ $k | quote }} = {{ $v | quote }},
{{- end }}
  }

  poll_frequency = {{ $f.pollFrequency | default "1m" | quote }}

  basic_auth {
    username = {{ $f.username | quote }}
    password = sys.env("ALLOY_FLEET_TOKEN")
  }
}
{{- end -}}
{{- end -}}

{{/*
Environment for the fleet block: collector identity and token.

The identity is composed from the pod name, which the workload injects from the
object metadata — stable for the pod's lifetime and unique across the DaemonSet.
*/}}
{{- define "alloy-lerian.fleetEnv" -}}
{{- if eq (include "alloy-lerian.fleetEnabled" .) "true" -}}
{{- $f := .Values.fleetManagement -}}
- name: ALLOY_FLEET_POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: ALLOY_FLEET_COLLECTOR_ID
  value: {{ printf "%s-$(ALLOY_FLEET_POD_NAME)" (include "alloy-lerian.originId" .) | quote }}
- name: ALLOY_FLEET_TOKEN
  valueFrom:
    secretKeyRef:
      name: {{ $f.tokenSecret.name | default "alloy-fleet-token" | quote }}
      key: {{ $f.tokenSecret.key | default "token" | quote }}
      # Not optional: with remote management enabled, a missing token means the
      # agent silently never receives configuration.
      optional: false
{{- end -}}
{{- end -}}
