# agent-helm

## Chart Contract

- Chart type: `single-service`
- Required secrets: `agent.secrets.AGENT_TOKEN` (and `agent.secrets.AGENT_ID` with a per-agent token) from the control plane's agent registration, or `agent.useExistingSecret` with a Secret carrying the same keys. `agent.configmap.CONTROL_PLANE_URL` is required as well.
- Dependency notes: No dependency chart is bundled. The agent only makes outbound requests: to the Lerian control plane, and to the registries it is allowed to pull from.
- Production overrides: `agent.managedNamespaces` (every namespace the agent may install into), `agent.useExistingSecret`, the registry allowlists, `agent.networkPolicy` CIDRs, resources, and `agent.image.digest` once the agent has moved itself to a newer build.
- Source/license: The chart is in `github.com/LerianStudio/helm` (Apache-2.0); the agent application is in `github.com/LerianStudio/agent`.

Installs the Lerian BYOC agent: it runs in your Kubernetes cluster, polls the
Lerian control plane over an outbound-only connection (no inbound ports, no
exposed services beyond an internal health and `/metrics` endpoint), and
executes the Helm operations the control plane assigns it.

## Prerequisites

- **Kubernetes 1.33 or newer.** The chart refuses to install below that floor
  (`kubeVersion` in `Chart.yaml`). It is the oldest Kubernetes the agent is
  actually installed on in Lerian's support fleet, not the oldest one its API
  versions would tolerate.
- Helm 3.8+.
- An agent registered with the control plane (see below), and every namespace
  listed in `agent.managedNamespaces` already created.

## Install

Register the agent with the control plane
(`POST /api/tenants/:tenantId/agents`) to get its token and ID, and put both in
a values file - `--set` would leave the token in your shell history and CI logs:

```yaml
# agent-values.yaml
agent:
  configmap:
    CONTROL_PLANE_URL: https://cp.example.com
  secrets:
    AGENT_TOKEN: <token-from-registration>
    AGENT_ID: <id-from-the-same-registration-response>
  # Namespaces this agent may install into. Omit for its own namespace only.
  managedNamespaces:
    - midaz
```

```bash
helm install lerian-agent oci://ghcr.io/lerianstudio/agent-helm \
  --namespace lerian-system --create-namespace \
  -f agent-values.yaml
```

The token only authenticates paired with the exact agent ID it was issued for,
so the chart refuses to render one without the other.

### Enrolling instead of registering

A cluster that does not exist yet can be handed a single-use **enrollment
token** instead (`POST /api/tenants/:tenantId/agents/enrollments`, a token
starting with `lerian_enroll_`). Set it as `AGENT_TOKEN` and leave `AGENT_ID`
empty: on its first call the agent redeems it, the control plane issues the
agent its own ID and per-agent token, and the enrollment token is dead from
that moment. The agent keeps the issued identity in the
`<fullname>-identity` Secret (`lerian-agent-identity` by default), so a
replacement pod reuses it instead of presenting a spent token. That Secret is
kept when the release is uninstalled.

### Using your own Secret

Set `agent.useExistingSecret: true` and `agent.existingSecretName` to a Secret
you manage (for example one synced by External Secrets Operator) with the keys
`AGENT_TOKEN` and, for a per-agent token, `AGENT_ID`. The chart then creates no
credential Secret. Rotating it needs `kubectl rollout restart` of the agent:
its lifecycle is yours, so the chart cannot roll the pod for you.

## Configuration

The agent follows the repository's values contract: everything about its
process lives under `agent`, its environment in `agent.configmap` and its
credential in `agent.secrets`. An empty `agent.configmap` value is not rendered,
and the agent applies its own default.

| Key | Default | Description |
| --- | --- | --- |
| `agent.configmap.CONTROL_PLANE_URL` | `""` | Base URL of the control plane. Required, and must be `https://` |
| `agent.configmap.AGENT_ALLOW_INSECURE_HTTP` | `"false"` | Accept an `http://` control plane URL. Isolated dev/test clusters only |
| `agent.configmap.HELM_TIMEOUT` | `"15m"` | How long one install/upgrade may take. Raise `agent.terminationGracePeriodSeconds` with it |
| `agent.configmap.AGENT_ALLOWED_CHART_REGISTRIES` | agent default | Comma-separated registries charts may be pulled from |
| `agent.configmap.AGENT_ALLOWED_IMAGE_REGISTRIES` | agent default | Registries the agent may pull its own image from |
| `agent.secretVault.*` | empty | Your own secret manager, through External Secrets |
| `agent.secrets.AGENT_TOKEN` / `AGENT_ID` | `""` | The agent's credential |
| `agent.useExistingSecret` / `agent.existingSecretName` | `false` / `""` | Use your own credential Secret |
| `agent.managedNamespaces` | release namespace | Namespaces the agent may write to |
| `agent.chartRegistry.*` | empty | Credential for pulling charts from a private registry |
| `agent.trust.additionalCABundle` | `""` | ConfigMap with your own root certificates |
| `agent.networkPolicy.*` | enabled, open CIDRs | Egress of the agent |
| `agent.image.digest` | `""` | Pins the agent image by digest, wins over the tag |
| `agent.serviceMonitor.enabled` / `agent.prometheusRule.enabled` | `false` | Prometheus Operator resources |
| `agent.extraEnvVars` | `[]` | Extra environment variables (e.g. `HTTPS_PROXY`) |

For every value, see [values.yaml](values.yaml).

## Which namespaces the agent may write to

`agent.managedNamespaces` lists every namespace this agent may install,
upgrade and uninstall releases in, write their Secrets to, and read pod logs
and events of when an install fails. Empty means the release namespace only.
Outside that list the agent can only read cluster-shape information (nodes,
namespace existence, pod and Service counts, capability checks) - it cannot
create a pod there, so it cannot mount another ServiceAccount's token.

Each listed namespace must already exist, and adding one later needs a
`helm upgrade` of this chart. Add `lerian-infra` if you want the deployer to
install the cluster components a failed preflight offers (a default
StorageClass, for example) instead of reporting them.

On Cilium, `ipBlock` rules do not match in-cluster addresses by default, so
when the API server runs on cluster nodes (kubeadm, k3s, RKE2, Talos) the
policy's `agent.networkPolicy.kubernetesApiCidr` rule lets nothing through to
it. Set Cilium's `policyCIDRMatchMode: nodes`, or add a `CiliumNetworkPolicy`
allowing the `kube-apiserver` entity for the agent's pods.

The full list of grants, and why each exists, is in
[`templates/rbac.yaml`](templates/rbac.yaml).

## Which registries the agent may pull from

The control plane tells the agent exactly which bytes to install (a content
digest), but a digest never says whose host served them. The allowlists are
the other half: the digest fixes what, the allowlist fixes from whom. Matching
is by path component (`ghcr.io/lerianstudio` allows
`ghcr.io/lerianstudio/midaz` and refuses `ghcr.io/lerianstudio-evil/midaz`),
and there is no value meaning "any registry".

To pull charts from a registry that refuses anonymous reads, set
`agent.chartRegistry.host` (prefer `ghcr.io/lerianstudio` to all of `ghcr.io`)
with `username` and `password`, or `agent.chartRegistry.existingSecret` naming
a `kubernetes.io/dockerconfigjson` Secret. The credential is mounted as a file,
offered only to the registry it is keyed for, and re-read on every pull, so
rotating it needs no restart.

## Cloud infrastructure

The agent provisions no cloud infrastructure. The cluster and the managed
datastores a stack uses (RDS, ElastiCache, DocumentDB, Amazon MQ) are created
with lerian-cli (`lerian infra`). The agent holds no cloud credential, and a
provisioning work item is refused with that answer.

This is separate from the preflight repair described above: installing a
cluster component such as a default StorageClass is an ordinary Helm release
into `lerian-infra`, inside the cluster, which the agent still performs.

## Updating the agent

The control plane can move the agent to a newer build: the agent runs the
target build once as a throwaway pod, and only a clean exit lets it patch its
own Deployment's image, by digest, from an allowed registry. Record that
digest in `agent.image.digest`, or the next routine `helm upgrade` re-renders
the tag and walks the agent back:

```bash
kubectl -n lerian-system get deploy lerian-agent \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## What leaves your cluster

This is the complete list of what this agent sends Lerian, grouped by what
causes it. Most of it leaves while everything is working, not only when
something breaks. The same inventory, with the code behind every claim, is the
"What leaves the cluster" section of
[`docs/threat-model.md`](https://github.com/LerianStudio/deployer/blob/main/docs/threat-model.md); this is it in the place
you are reading before you install. Every ceiling and interval it refers to is
in the closed table at the end of this section.

| What leaves | Occasion | Who causes it | Where it lands, and for how long |
| --- | --- | --- | --- |
| **A heartbeat** - this agent's id, the moment, that it is connected, the build it runs, and (if you set `agent.secretVault`) which vault your secrets live in: provider, store name and kind, **path prefix**, refresh interval. No secret material. Plus the registries your cluster holds a chart-pull credential for - the hostnames and path prefixes off your pull Secret's own keys, re-read on every beat, never the credential. Plus your cluster's own identity - the UID Kubernetes gave the `kube-system` namespace when the cluster was created, read once at start and restated on every beat. It identifies the cluster and nothing inside it, and it is what makes an operator's command naming one of your ledgers refuse to run against somebody else's cluster. Part of the same list also leaves inside a failed chart pull's error text, cut to the named-scopes ceiling below | Continuous, at the observation interval | Nobody; the agent's own clock | Lerian's database, upserted in place so only the latest exists |
| **Health of a release** - Helm's status word, your workloads and their replica counts, your pods with phase, readiness and restart count, a derived sentence saying what is wrong, and a list of what the agent was refused. Workloads and pods are each kept up to the entry ceiling below; the sentence and the refusals have ceilings of their own | Continuous, at the observation interval, per release the control plane asked this agent to watch, **whatever the capture switch says** | Nobody | Lerian's database, latest observation only: the next one overwrites it |
| **Container output** - the tail of what the stopped containers of an UNWELL release printed, with secret-shaped fields removed by name inside your cluster before anything goes on the wire. That pass runs on five fields and no others - a pod's status message, a container's waiting and terminated messages, a container's log tail, and a Warning event's message. **Nothing else this agent sends is redacted** | Continuous, at the observation interval, only for a release that already looks wrong, capture switch on | Nobody | Lerian's database (overwritten as above) and, where the control plane is configured with a telemetry store, Lerian's per-tenant log store under the declared telemetry retention |
| **Warning events** about the release's own objects - the object, reason, message and count; where image-pull, scheduling and quota refusals live. The namespace's Warnings are all listed, because the cluster offers no way to ask for one release's; the ones about anything else, including another release installed alongside this one, are discarded inside your cluster and never leave it | The same occasions, in the same report | Nobody | The same two places |
| **Five numbers per release** - CPU millicores, memory bytes, desired and ready replicas, restarts. Summed over the release's own pods; **no pod name, no container name, no image, no label of yours** | Continuous, at the observation interval, capture switch on | Nobody | Nothing in Lerian's database. The latest sample is held in memory and scraped into Lerian's metrics store; it is dropped after the staleness window below, and the history there lives under that store's retention |
| **Failure evidence** - the same output and the same events, read the same way | On a failed install, upgrade, rollback or uninstall | Whoever ran the operation | A row against the deployment revision, whose body is cleared when you delete the deployment; and the log store copy, which the deletion does NOT touch and which expires only under that store's retention |
| **The text of a failure** - the error string verbatim plus a sentence naming the operation. **Not redacted**: the redaction pass reaches container output and the cluster's own messages, nothing else. It can carry a permission denial naming your ServiceAccount, verb, resource and namespace; an admission webhook's rejection echoing part of a manifest; a registry's or TLS stack's own words. A failure family and a failure code ride with it, both from a closed set the agent chooses from, carrying nothing of yours | On failure of ANY requested operation | Whoever ran the operation | The work item, and the deployment's and revision's error message, which have no expiry |
| **A preflight report** - a verdict and one entry per check, each a sentence and a remediation, plus the platforms your nodes run (`linux/arm64`). Those sentences carry your own naming: **your StorageClass and IngressClass names**, what in-cluster DNS resolves to, registry hosts your pod cannot reach, names of nodes a stack cannot land on and why, and - if your cluster serves no IngressClass - **one Service, its namespace and its public load-balancer address**. They also carry: your image-pull Secrets by name, referenced or not, with a ready-to-paste `kubectl create secret docker-registry` line; a managed datastore's host and port with its security posture, **which leaves on a passing check too**; CRD kinds, API groups and cluster-scoped object names; a required Secret's namespace and name; your cluster's Kubernetes version (the raw version string when it will not parse), how many nodes are schedulable out of how many, and the CPU and memory left on them; and, wherever a check could not reach an answer, the Kubernetes API's or the registry's own error text verbatim, cut to the recorded-read-error ceiling below | On request, before a stack is created or installed | A Lerian operator, or the install gate acting for one | Lerian's database, pruned at the report retention below unless an install was signed against it |
| **A status check's answer** - Helm's status word and revision, the chart and its app version, your workloads by kind and name with their desired and ready counts, **your full pod list with name, phase, readiness, restart count and reason**, and what the cluster refused to answer. This is what a status check sends when it goes RIGHT; the failure row above covers it going wrong | On request | A Lerian operator | The work item, deleted on the same clock as the rows below |
| **A release's computed values** - everything Helm would use for that release | On request | A Lerian operator | The work item. Deleted by the next sweep after the item expires - the sweep runs on its own interval below. The item's clock starts when it became CLAIMABLE, not when it finished: it runs for the retention window below, extended while the operation is still going, up to the lifetime ceiling below |
| **Live resource stats for one release** - per-pod CPU and memory **with the pod's name**, replica counts, and your HorizontalPodAutoscaler by name. If the metrics API will not answer, the read still SUCCEEDS and carries a note holding that API's own refusal verbatim, cut to the recorded-read-error ceiling below | On request | A Lerian operator | The work item. Deleted by the next sweep after the item expires - the sweep runs on its own interval below. The item's clock starts when it became CLAIMABLE, not when it finished: it runs for the retention window below, extended while the operation is still going, up to the lifetime ceiling below |
| **An upgrade preview** - not one body but several: the manifests CURRENTLY DEPLOYED, read live out of your cluster, so every object the release owns as it stands; the manifests the upgrade would render; and a line diff of the two, which is not a summary - an added or removed resource contributes every one of its lines, and so does a change too large for the comparison budget | On request, before an upgrade is approved | A Lerian operator | The work item (deleted by the next sweep after the item expires - the sweep runs on its own interval below. The item's clock starts when it became CLAIMABLE, not when it finished: it runs for the retention window below, extended while the operation is still going, up to the lifetime ceiling below) and the deployment's history, where it has no expiry at all |

**What never leaves:**

- **Your complete continuous log.** Nothing here ships a log stream. What
  leaves is the tail above, only for a release that already looks wrong, and
  only inside the ceilings below. A release that is behaving is never asked
  what it printed.
- **Your own logging setup.** This chart installs no log store and no
  dashboard, and the deployer's catalogue offers neither: where your continuous
  logs live is your arrangement, and turning the switch below off does not take
  it away.

**What `agent.managedNamespaces` actually bounds, per read.** It is enforced by
RBAC for the two reads that carry your application content - container output
(`pods/log`) and Warning events - whose grants live in a Role rendered once per
namespace you declared and reach nothing outside it. It is NOT what bounds the
health read or the five numbers: pods, services, nodes and `metrics.k8s.io` are
granted cluster-wide in the ClusterRole this chart renders, read-only, and what
keeps those reads to your own releases is the agent's code selecting on the
release label. And the preflight reads cluster-wide on purpose - it lists
Services everywhere and may name one of them and its public address, because
otherwise "will anything route to this stack's hostnames" is unanswerable on
exactly the clusters where it matters. Every one of those grants is written out
with what a holder of it gets in `docs/threat-model.md`.

**The switch.** Every deployment carries an evidence-capture switch, on by
default, which you turn off with your own credential at
`PUT /api/tenants/:id/deployments/:deploymentId/evidence-capture`. Off, the
agent stops asking the cluster and the control plane refuses to store what an
agent sent anyway - both sides, because a promise kept only by the party it
constrains is not one. What stops is the container output, the Warning events
and the five numbers. **What goes on leaving.** Your releases are still
observed and their health is still reported; what a Lerian operator loses is
the WHY, never the WHAT. The HEARTBEAT is untouched - the switch is per
deployment and the heartbeat is per agent - so everything its row above lists
keeps leaving, your declared registries included. And with the switch off a
Lerian operator who asks for an upgrade preview, your computed values, live
resource stats or a preflight still gets them; what gates
those is the consent you granted, not this switch.

**Who reads it.** A Lerian operator reaching any of this through the control
plane needs a live consent you granted, and the read is written to your access
log; every on-request row above is read that way. Two reads are not: a named
NOC team reads the log store in Grafana without a per-incident prompt, because
during an incident such a prompt is answered too late to matter, and Lerian
operators read your releases' CPU and memory history the same way from the
metrics store. Both are bounded by who Grafana gives those datasources to,
which is a Grafana setting and not something this chart can show you.

**Your pod and container names are searchable in Lerian's log store.** They
are not stream labels - a name that changes on every restart would multiply
the streams the store keeps open - but they travel as structured metadata on
each line, which is what makes "show me what THAT pod printed" answerable. A
Warning event carries the object it is about the same way.

**The whole telemetry ceiling list, which is closed:**

| Ceiling | Value | Where it is enforced |
| --- | --- | --- |
| `observation interval` | `30s` | `internal/bootstrap/config.go`, `DefaultHeartbeatInterval`; `charts/agent/values.yaml`, `agent.configmap.HEARTBEAT_INTERVAL` |
| `log lines per container` | `50` | `internal/kubernetes/evidence.go`, `evidenceLogLines` |
| `log bytes per container` | `8192` | `internal/kubernetes/evidence.go`, `evidenceMaxLogBytes` |
| `log read per container` | `10s` | `internal/kubernetes/evidence.go`, `evidenceMaxLogWait` |
| `warning events per report` | `20` | `internal/kubernetes/evidence.go`, `evidenceMaxEvents` |
| `events listed per namespace` | `200` | `internal/kubernetes/evidence.go`, `evidenceEventListLimit` |
| `recorded read error` | `2048` | `internal/kubernetes/evidence.go`, `evidenceMaxErrorBytes` |
| `evidence sent per release` | `65536` | `internal/kubernetes/evidence.go`, `EvidenceMaxBytes` |
| `releases per report` | `500` | `components/control-plane/internal/services/deployment_observed_health.go`, `maxReleaseStatusReports` |
| `evidence accepted per release` | `131072` | `components/control-plane/internal/services/deployment_observed_health.go`, `evidenceMaxBytes` |
| `workloads and pods kept per observation` | `50` | `components/control-plane/internal/services/deployment_observed_health.go`, `observedDetailMaxEntries` |
| `refusals kept per observation` | `4` | `components/control-plane/internal/services/deployment_observed_health.go`, `unreadableMaxClaims` |
| `characters per refusal` | `300` | `components/control-plane/internal/services/deployment_observed_health.go`, `unreadableMaxChars` |
| `characters in the derived reason` | `500` | `components/control-plane/internal/services/deployment_observed_health.go`, `observedReasonMaxChars` |
| `characters kept of a release, workload or pod name` | `253` | `components/control-plane/internal/services/deployment_observed_health.go`, `observedNameMaxChars` |
| `characters kept of a namespace or workload kind` | `63` | `components/control-plane/internal/services/deployment_observed_health.go`, `observedLabelMaxChars` |
| `characters kept of a helm status or pod phase` | `64` | `components/control-plane/internal/services/deployment_observed_health.go`, `observedWordMaxChars` |
| `characters kept of a pod reason` | `300` | `components/control-plane/internal/services/deployment_observed_health.go`, `observedPodReasonMaxChars` |
| `characters of agent-supplied text one stored observation can carry` | `179802` | `components/control-plane/internal/services/deployment_observed_health_bounds_test.go`, `storedObservationMaxChars`: summed by that test from the rows above it that bound one observation (every workload and pod kept, the release name, namespace and status, the refusals, the evidence and the derived reason). An upper bound in characters, not the stored byte size: the JSON encoder escapes quotes, backslashes, angle brackets, ampersands and control characters, and evidence is counted in bytes |
| `observation age the store accepts` | `7d` | `components/control-plane/internal/services/deployment_telemetry.go`, `observationMaxAge` |
| `runes kept of a release or namespace name` | `253` | `components/control-plane/internal/services/deployment_telemetry.go`, `labelMaxRunes` |
| `clock skew ahead the store accepts` | `5m` | `components/control-plane/internal/services/deployment_observed_health.go`, `observedAtSkewAllowance` |
| `push body per request` | `4194304` | `components/control-plane/internal/logstore/loki.go`, `maxPushBytes` |
| `unwell releases explained per pass` | `8` | `components/control-plane/pkg/config/config.go`, `defaultCapturePerPass` (`TELEMETRY_CAPTURE_PER_PASS`) |
| `highest per-pass ceiling settable` | `64` | `components/control-plane/pkg/config/config.go`, `maxCapturePerPass` |
| `releases measured per report` | `256` | `components/control-plane/internal/services/release_metrics.go`, `releaseMetricsPerBatch` |
| `metrics series dropped after` | `90s` | `components/control-plane/internal/services/release_metrics.go`, `releaseMetricsStaleAfter` |
| `certificate watch verdict dropped after` | `90s` | `components/control-plane/internal/services/certificate_alerts.go`, `certificateWatchStaleAfter` |
| `preflight report retention` | `7d` | `components/control-plane/internal/services/work_queue_service.go`, `preflightReportRetention` |
| `characters kept of a completion's message or error` | `8192` | `components/control-plane/internal/services/completion_bounds.go`, `completionTextMaxChars` |
| `preflight checks kept of one agent report` | `64` | `components/control-plane/internal/services/completion_bounds.go`, `preflightChecksMaxPerReport` |
| `characters kept of a preflight check name` | `64` | `components/control-plane/internal/services/completion_bounds.go`, `preflightCheckNameMaxChars` |
| `characters kept of a preflight check verdict` | `16` | `components/control-plane/internal/services/completion_bounds.go`, `preflightCheckVerdictMaxChars` |
| `characters of blocking checks a preflight refusal quotes` | `8192` | `components/control-plane/internal/services/completion_bounds.go`, `preflightBlockingSummaryMaxChars` |
| `telemetry pushes per tenant per second` | `10` | `components/control-plane/pkg/config/config.go`, `TELEMETRY_INGEST_RATE` |
| `telemetry series retention` | `30d` | `components/control-plane/pkg/config/config.go`, `TELEMETRY_RETENTION_DAYS` — **declared by the control plane, enforced by the store** |
| `registries one cluster can declare` | `32` | `components/control-plane/internal/services/agent_service.go`, `maxDeclaredRegistryScopes` |
| `bytes per declared registry` | `256` | `components/control-plane/internal/services/agent_service.go`, `maxDeclaredScopeLength` |
| `work item result retention window` | `1h` | `components/control-plane/pkg/config/config.go`, `WORK_ITEM_EXPIRY_WINDOW`, installed into the work queue at boot |
| `upgrade preview retention` | `14d` | `components/control-plane/internal/adapters/postgres/work_queue_expiry.go`, `PreviewRetentionWindow` |
| `work item lifetime` | `6h` | `components/control-plane/pkg/config/config.go`, `WORK_ITEM_MAX_LIFETIME` |
| `sweep interval` | `1h` | `components/control-plane/pkg/config/config.go`, `WORK_SWEEP_INTERVAL` |
| `incident account lines per source` | `50` | `components/control-plane/internal/services/incident_timeline.go`, `incidentTrailLines` |
| `incident account bytes per entry body` | `1024` | `components/control-plane/internal/services/incident_timeline.go`, `incidentAccountBodyBytes` |
| `analysis context lines per source` | `200` | `components/control-plane/internal/services/analysis_context_service.go`, `analysisContextItemsPerSource` |
| `analysis context bytes per free text` | `2048` | `components/control-plane/internal/services/analysis_context_service.go`, `analysisContextTextBytes` |
| `analysis context bytes per repeated list in a line` | `16384` | `components/control-plane/internal/services/analysis_context_service.go`, `analysisContextListBytes` |
| `analysis context elements per repeated list` | `256` | `components/control-plane/internal/services/analysis_context_service.go`, `analysisContextListItems` |
| `analysis context displaced origins per path` | `4` | `components/control-plane/internal/services/analysis_context_service.go`, `analysisContextOriginsPerPath` |
| `bytes per webhook destination address` | `2048` | `components/control-plane/pkg/model/notification.go`, `MaxWebhookAddressBytes`, refused past it on write; older rows cut to it on read in `components/control-plane/internal/services/notification_service.go` |
| `bytes per email destination address` | `254` | `components/control-plane/pkg/model/notification.go`, `MaxEmailAddressBytes`, refused past it on write; older rows cut to it on read in `components/control-plane/internal/services/notification_service.go` |
| `characters per slack destination label` | `80` | `components/control-plane/pkg/model/notification.go`, `MaxSlackLabelRunes`, refused past it on write; older rows cut to it on read in `components/control-plane/internal/services/notification_service.go` |
| `registries named in a failed pull's error` | `3` | `internal/helm/download.go`, `maxNamedScopesInAPullError` |

Two notes a number alone would mislead you about. The events-listed ceiling is
a PAGE, not a ranking: the Kubernetes API returns a namespace's events by name
rather than by recency, so in a namespace holding more than that the release's
own Warnings can fall outside the page (every stack gets its own namespace,
where the count stays far below it). And the telemetry retention is declared by
the control plane and enforced by the store behind it, so it is a contract
rather than a limit this code applies.

## Uninstall

```bash
helm uninstall lerian-agent --namespace lerian-system
```

The `lerian-agent-identity` Secret is kept (`helm.sh/resource-policy: keep`),
so a reinstall carrying the same enrollment keeps the agent's identity. Delete
it by hand to start over.

## Source

- Chart: [LerianStudio/helm](https://github.com/LerianStudio/helm/tree/main/charts/agent)
- Agent: [LerianStudio/agent](https://github.com/LerianStudio/agent)
