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

  // Origin plus pod name: stable for the pod's lifetime and unique across the
  // DaemonSet. Composed here rather than read from one variable, because the
  // origin is known at render time and only the pod name needs the environment.
  //
  // NOT constants.hostname (resolves to the node in a DaemonSet) and NOT the
  // auto-generated seed: the seed is persisted to the agent's storage path,
  // which an ephemeral pod loses on every restart — producing a new collector
  // identity each time and churn in the fleet registry.
  id = {{ printf "%s-" (include "alloy-lerian.originId" .) | quote }} + sys.env("ALLOY_FLEET_POD_NAME")

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
==============================================================================
GUARD — the fleet block needs environment the subchart values must carry
==============================================================================
The `remotecfg` block reads ALLOY_FLEET_POD_NAME and ALLOY_FLEET_TOKEN from
the environment. Those entries live in the subchart's `extraEnv`, which is static
YAML — a parent template cannot inject a fieldRef into it.

So the chart cannot wire them automatically. It CAN refuse to render a
configuration that would fail at startup, which is what this guard does: without
it, enabling fleet management would produce an agent that cannot authenticate and
never receives configuration, and the failure would only appear in the pod log.

Verified: the helper that used to render these entries was never invoked, so the
environment never reached the container. This guard is what makes that class of
mistake impossible rather than merely unlikely.
*/}}
{{- define "alloy-lerian.assertFleetEnv" -}}
{{- if eq (include "alloy-lerian.fleetEnabled" .) "true" -}}
{{- range $papel := list "node" "singleton" -}}
{{- $cfg := index $.Values $papel -}}
{{- if $cfg -}}
{{- if $cfg.enabled -}}
{{- $env := ($cfg.alloy).extraEnv | default list -}}
{{- $nomes := list -}}
{{- range $e := $env -}}{{- $nomes = append $nomes $e.name -}}{{- end -}}
{{- if not (has "ALLOY_FLEET_POD_NAME" $nomes) -}}
{{- fail (printf "\n\nalloy-lerian: fleetManagement está habilitado, mas `%s.alloy.extraEnv` não\ndeclara ALLOY_FLEET_POD_NAME.\n\nO bloco remotecfg lê essa variável. Sem ela o agente não inicia, e a falha só\napareceria no log do pod.\n\nAcrescente ao values do papel %s:\n\n  %s:\n    alloy:\n      extraEnv:\n        - name: ALLOY_FLEET_POD_NAME\n          valueFrom:\n            fieldRef:\n              fieldPath: metadata.name\n        - name: ALLOY_FLEET_POD_NAME\n          value: \"%s-$(ALLOY_FLEET_POD_NAME)\"\n        - name: ALLOY_FLEET_TOKEN\n          valueFrom:\n            secretKeyRef:\n              name: alloy-lerian\n              key: fleet-token\n" $papel $papel $papel (include "alloy-lerian.originId" $)) -}}
{{- end -}}
{{- if not (has "ALLOY_FLEET_TOKEN" $nomes) -}}
{{- fail (printf "\n\nalloy-lerian: fleetManagement está habilitado, mas `%s.alloy.extraEnv` não\ndeclara ALLOY_FLEET_TOKEN.\n\nSem o token o agente autentica e falha, e nunca recebe configuração.\n" $papel) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
