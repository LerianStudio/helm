# agent-helm

## Chart Contract

- Chart type: `single-service`
- Required secrets: `agent.token` and `agent.id` from the control plane's agent registration (or an enrollment token), or `agent.existingSecret` naming a Secret that carries them. `controlPlane.url` is required as well.
- Dependency notes: No dependency chart is bundled. The agent only makes outbound requests to the Lerian control plane and to the registries it is allowed to pull from.
- Production overrides: `agent.managedNamespaces` (every namespace the agent may install into), `agent.existingSecret`, the registry allowlists, `agent.infraRunner.image` when cloud provisioning is used, resources, and `image.digest` once the agent has been moved to a newer build.
- Source/license: The chart is in `github.com/LerianStudio/helm` (Apache-2.0); the agent application is in `github.com/LerianStudio/agent`.

Installs the Lerian BYOC agent: it runs in your Kubernetes cluster, polls
the Lerian control plane over an outbound-only connection (no inbound
ports, no exposed services beyond an internal `/metrics` endpoint), and
executes the Helm operations the control plane assigns it.

## Supported Kubernetes versions

**Kubernetes 1.33 through 1.36.** The chart refuses to install below that
floor (`kubeVersion` in `Chart.yaml`).

That floor moved up: charts published before the fleet landed declared
`>=1.23.0-0`, a version nothing had ever been installed on. If you are running
a cluster between 1.23 and 1.32, `helm upgrade` to this chart is refused, not
degraded — upgrade the cluster first, or stay on the chart version you have.

The floor is not the oldest Kubernetes the chart's API versions would
tolerate - it is the oldest one the chart is actually installed on. The
window lives in a single file, [`hack/fleet-matrix.json`](https://github.com/LerianStudio/deployer/blob/main/hack/fleet-matrix.json),
which pins one `kindest/node` image per version by digest;
`hack/smoke-agent-install.sh` boots a throwaway cluster from any entry and
runs a real install against it. CI runs every one of those entries nightly,
crossed with each shape of degraded cluster the fleet covers, and reports a
verdict per cell (`.github/workflows/fleet.yml`) - so "installed on" means
every version in the window, not the newest one somebody happened to try.
`hack/fleet-support-window.sh` fails the
build if either the floor in `Chart.yaml` or the window named in the line
above ever drifts from that file, so neither can promise a Kubernetes
nothing ever ran.

Newer minors than the ceiling are not blocked: the chart installs there,
they are simply untested.

## Install

Register the agent with the control plane first to get its token and ID
(`POST /api/tenants/:tenantId/agents`), then put them in a values file
rather than on the command line - `--set agent.token=...` puts the token in
your shell history and in plain text in every CI log that runs it:

```yaml
# agent-values.yaml
controlPlane:
  url: https://cp.example.com
agent:
  token: <token-from-registration>
  id: <id-from-the-same-registration-response>
  # Namespaces this agent may install into. Omit for its own namespace only.
  # See "Which namespaces the agent may write to" below.
  managedNamespaces:
    - midaz
```

```bash
helm install lerian-agent oci://ghcr.io/lerianstudio/agent-helm \
  --namespace lerian-system --create-namespace \
  -f agent-values.yaml
```

Quick-start / throwaway demo only, not for anything you'd keep around:

```bash
helm install lerian-agent oci://ghcr.io/lerianstudio/agent-helm \
  --namespace lerian-system --create-namespace \
  --set controlPlane.url=https://cp.example.com \
  --set-string agent.token="$AGENT_TOKEN" \
  --set-string agent.id="$AGENT_ID"
```

`--set-string` stops Helm from coercing token/ID values that look numeric,
and reading them from environment variables keeps the literal secret out of
your shell history. Note that Helm persists every supplied value (including
the token) in plain text inside the release Secret and its revision history,
so for production use `agent.existingSecret` and keep credentials out of
Helm values entirely.

`--namespace`/`--create-namespace` is required: this chart does not create
or reference a `Namespace` object itself, every resource just goes into
whatever namespace the release targets (`.Release.Namespace`). A
chart-owned Namespace object was tried and dropped: it put the Helm
release secret in the `default` namespace instead of the agent's own,
made install fail outright if the namespace already existed, and made
`helm uninstall` delete the namespace as if the chart owned everything in
it. Pass a different `--namespace <yours>` if you don't want
`lerian-system`.

## Enrolling instead of registering

For a cluster that does not exist yet - `lerian bootstrap aws`, or the
Marketplace CloudFormation stack - there is nobody to run the registration
call and nowhere to put the answer. Those install with an **enrollment
token** instead:

```bash
# On the operator's machine, against the control plane:
#   POST /api/tenants/<tenant>/agents/enrollments  {"name": "sa-east-1 cluster"}
# returns a token starting with lerian_enroll_

helm install lerian-agent oci://ghcr.io/lerianstudio/agent-helm \
  --namespace lerian-system --create-namespace \
  -f agent-values.yaml   # controlPlane.url + agent.token, no agent.id
```

The token is single-use, short-lived and bound to one tenant. The agent
redeems it on its first call; the control plane creates the agent under the
name the token was issued with, hands back that agent's own id and bearer
token, and burns the token. A token that leaks after a cluster has enrolled
with it opens nothing, and it can never create an agent in another client's
tenant - the redeeming call names no tenant at all.

Leave `agent.id` empty with an enrollment token: the control plane assigns
it. The agent keeps both halves of the identity it is issued in a Secret
named after its own Deployment (`lerian-agent-identity` by default) — so a replacement
pod (an agent version rollout, a `helm upgrade`, a node drain, an eviction)
reuses that identity instead of presenting a token that has already been
spent. Writing it needs the agent to be allowed Secrets in its own
namespace. The chart grants `get` and `update` on that one Secret through a
dedicated Role pinned by `resourceNames`; it does not require the release
namespace in `agent.managedNamespaces`, and it grants no access to any other
Secret there. A hand-rolled install that omits this Role, and grants no other
access to that Secret, fails its boot on the identity read instead of enrolling.

The chart creates the Secret's empty shell so the narrow RBAC grant can name an
object that already exists; the payload is the agent's. Every chart revision
declares the same empty payload, so Helm's three-way patch has no data change to
apply on upgrade or rollback and preserves the keys the agent added to the live
object. The `helm.sh/resource-policy: keep` annotation leaves it behind on
uninstall. A
later install carrying a **different** enrollment token ignores the old payload
and enrols fresh, so a re-install is not poisoned by the identity of the cluster
before it.

That Secret appears **before** the token is redeemed, holding one key: a
recovery proof the agent generates for itself. Redeeming has a moment where
the control plane has already created the agent while the answer carrying its
credential is still travelling back, and a pod killed there used to come back
holding nothing but a spent token — an orphaned cluster needing a new token
and another install. Written first, the proof lets the replacement ask for the
same identity again; presenting it rotates that agent's token and hands back a
working one. Only the proof does that, so a spent enrollment token on its own
is as useless as it always was. The window closes after the enrollment's own
lifetime, counted from when it was redeemed.

## Why `agent.id` matters

A **per-agent** `agent.token` and `agent.id` come from the *same*
registration call and are not independently useful: the control plane
validates a token against the bcrypt hash stored for one specific agent ID,
so a token paired with the wrong ID (or no ID) can never authenticate. The
chart enforces this: setting a per-agent `agent.token` without `agent.id`
fails `helm template`/`install` immediately with an explicit error, instead
of installing something that polls forever with a mismatched identity.
Always pass both, taken from the same response.

The one exception is the enrollment token above - it is recognised by its
`lerian_enroll_` prefix, and it is precisely the credential that has no id
to pair with yet. Setting both `agent.token` and `agent.existingSecret` is
still a hard error - they're mutually exclusive ways of providing the same
credentials.

## Values

| Key | Required | Default | Description |
|---|---|---|---|
| `controlPlane.url` | Yes | `""` | Base URL the agent polls and sends heartbeats to. Must be `https://` (the agent sends its bearer token on every request); a cleartext `http://` URL fails `helm template`/`install` unless `controlPlane.allowInsecureURL` is set. |
| `controlPlane.allowInsecureURL` | No | `false` | Explicit opt-in for a cleartext `http://` `controlPlane.url`, for isolated dev/test clusters only (also sets `AGENT_ALLOW_INSECURE_HTTP=true` on the agent). Never enable in production. |
| `agent.token` | Yes, unless `agent.existingSecret` is set (mutually exclusive with it) | `""` | Either the per-agent bearer token from registration, or a single-use enrollment token (`lerian_enroll_...`) the agent trades for one on its first call. |
| `agent.id` | Yes whenever `agent.token` is a per-agent token; must be empty with an enrollment token | `""` | Agent UUID from the same registration response as `agent.token`. |
| `agent.existingSecret` | No | `""` | Name of a Secret you manage yourself (e.g. via External Secrets Operator) instead of `agent.token`/`agent.id`. Must have key `token`; `agent-id` is optional and omitted for an enrolling agent. |
| `agent.managedNamespaces` | No | `[]` (the release's own namespace) | Every namespace this agent may install releases into, write release Secrets in, and read failure evidence from. The enrollment identity Secret has its own object-pinned Role and does not require the release namespace in an explicit list. Each listed namespace must already exist at install time, and adding one later needs a `helm upgrade`. Blank entries are dropped, and a list of only blank entries is read as no list at all. See below. |
| `agent.allowedChartRegistries` | No | `[]` (`ghcr.io/lerianstudio` + `registry-1.docker.io/lerianstudio`) | Registries this agent may pull charts from. Matched by path component, so `ghcr.io/lerianstudio` allows `ghcr.io/lerianstudio/midaz` and refuses `ghcr.io/lerianstudio-evil/midaz`. Empty means Lerian's own chart hosts; there is no value meaning "any registry". See below. |
| `agent.allowedImageRegistries` | No | `[]` (`ghcr.io/lerianstudio`) | Registries this agent may pull its own image from. Same matching rules. Narrower than the chart list: every deployer image is published to `ghcr.io/lerianstudio` alone, while the product catalog is still on Docker Hub. A host-less image name means Docker Hub to a container runtime, so `lerianstudio/agent` is refused by this default — write the host out. |
| `agent.chartRegistry.host` | Yes, with `username`/`password` | `""` | The scope the chart-pull credential below is keyed for. Prefer a host **and organization** (`ghcr.io/lerianstudio`) over a bare `ghcr.io`: the agent matches by longest prefix at a path boundary, so the narrow key is offered for Lerian's charts and for nothing else on that registry. A chart from a scope no key covers is pulled anonymously, exactly as an agent with no credential pulls it, never with this password. The chart folds case (of the host only), one `oci://`/`https://`/`http://` scheme and one trailing slash; a `:443` port and Docker Hub's other names are written **as you spell them** and folded by the agent when it reads the file. A second scheme, and a host with no credential beside it, are refused at render time. There is no default. Not used with `existingSecret`, where the scopes are inside the Secret. TLS only. |
| `agent.chartRegistry.username` / `agent.chartRegistry.password` | No, both or neither | `""` | Credential for pulling charts from a registry that refuses anonymous reads (a `ghcr.io` package with `internal` visibility, a private mirror). Unset - the default - means every chart pull is anonymous. The chart renders them into a `kubernetes.io/dockerconfigjson` Secret. Only one of the two set is refused at render time. See below. |
| `agent.chartRegistry.existingSecret` | No | `""` | Name of a `kubernetes.io/dockerconfigjson` Secret you manage yourself - what `kubectl create secret docker-registry` writes, or what External Secrets Operator syncs - instead of the three values above (mutually exclusive with all of them). May name several registries at once; `--docker-server=ghcr.io/lerianstudio` narrows an entry to one organisation. The chart then creates no registry Secret, mounts only this Secret's `.dockerconfigjson` key into the agent, and adds it to no workload's `imagePullSecrets`. |
| `image.repository` / `image.tag` | No | `ghcr.io/lerianstudio/agent` / `""` (falls back to the chart's `appVersion`) | Agent image. |
| `image.digest` | No | `""` | Pins the agent image by content and wins over `image.tag`. Must be written as `sha256:` followed by 64 lowercase hex characters, with no leading `@`; anything else is refused at render time rather than turned into a reference no registry resolves. Set it after the control plane has moved this agent to a newer build, or the next routine `helm upgrade` re-renders `image.tag` and walks the agent back a version silently. See below. |
| `resources` | No | 64Mi/100m requests, 128Mi/200m limits | Pod resources. |
| `networkPolicy.enabled` | No | `true` | Restrict the egress of the agent and of its provisioning Jobs to DNS, the Kubernetes API, the control plane and chart registries. The rule opens the port `controlPlane.url` names, 443, and every port an `agent.allowedChartRegistries` entry names. |
| `networkPolicy.extraEgress` | No | `[]` | Egress rules appended verbatim to both policies: a proxy, a chart registry on a CIDR the control-plane rule does not cover. With both `networkPolicy.kubernetesApi.cidr` and `networkPolicy.controlPlane.cidr` narrowed, the cloud provider API endpoints the infra runner calls and the registry its `tofu init` downloads provider plugins from (`registry.opentofu.org`, or your mirror) must be added here too. |
| `serviceMonitor.enabled` | No | `false` | Requires the `monitoring.coreos.com` CRDs. |
| `serviceMonitor.labels` | No | `{}` | Extra labels on the ServiceMonitor object (e.g. `release: prometheus` for kube-prometheus-stack). Also applied to `prometheusRule` below. |
| `prometheusRule.enabled` | No | `false` | The agent's 4 baseline alerts (circuit breaker open, high poll error rate, stuck work items, agent down). Requires the `monitoring.coreos.com` CRDs. |
| `prometheusRule.volumeAlerts.enabled` | No | `false` | Disk-filling alerts for the volumes of the releases this agent manages, from `kubelet_volume_stats_*`. Requires `prometheusRule.enabled` and a Prometheus that scrapes those series (kube-prometheus-stack does). This is the one signal Lerian does NOT collect - see below. |
| `prometheusRule.volumeAlerts.freeRatio` | No | `0.15` | Fire when less than this fraction of a volume's capacity is free. |
| `prometheusRule.volumeAlerts.for` | No | `15m` | ...and has been for this long. |
| `trust.additionalCABundle` | No | `""` | Name of a ConfigMap in this namespace holding PEM root certificates. The agent adds them to the public roots on every connection it opens (control plane, chart pulls, the certificate check) and in the provisioning Job; behind a TLS-inspecting proxy, the proxy's CA goes here. Needs no RBAC; read once at start. |
| `hpa.enabled` | No | `false` | One agent per cluster is the supported model; only enable after verifying work-item idempotency. |
| `pdb.enabled` | No | `false` | |
| `imagePullSecrets` | No | `[]` | For pulling the agent image from a private registry/mirror. |
| `extraEnv` | No | `[]` | Extra container env vars (e.g. `HTTPS_PROXY`, `HELM_TIMEOUT` - see below - or overriding a default like `LOG_LEVEL`; later entries win on a duplicate name). With a proxy set, the agent adds the in-cluster Kubernetes API to `NO_PROXY` itself and hands the three proxy variables to the provisioning runner; add your other internal hosts to `NO_PROXY`. |
| `nodeSelector` / `tolerations` | No | `{}` / `[]` | For clusters with dedicated or tainted node pools. |

Set either `agent.token` (+ `agent.id`) **or** `agent.existingSecret` -
never both, and the chart refuses to render if you do. When
`agent.existingSecret` is set, this chart creates no Secret at all.

### Why disk usage is your Prometheus' job and not the agent's

Every other Epic-4.2 signal reaches Lerian through the agent. This one does
not, on purpose.

A PersistentVolumeClaim's *capacity* is in the Kubernetes API; its *used bytes*
are not. They are published by the kubelet, and the only grant that reaches a
kubelet from inside the cluster is `nodes/proxy`. That grant is not narrow: the
API server proxies the request with its own privileged client certificate, so
the kubelet's authorization never gates the caller, and a holder of
`nodes/proxy get` reaches every kubelet endpoint on an ordinary cluster -
`/logs/...` on every node included. With `create` it reaches `/exec`.

Lerian will not ask for that to learn a disk-usage percentage. So the agent's
RBAC does not include it, no volume numbers ever leave your cluster, and
`prometheusRule.volumeAlerts.enabled` gives you the same alert from the
Prometheus you already run, inside your own cluster, reaching your own
Alertmanager.

### Telling the agent about your own certificate authority

If you terminate TLS with an internal PKI, every address you publish is
reported as one the agent cannot validate — correctly, since its trust store
really does not contain your root — and you get a warning about each of them.
Put the root in a ConfigMap and name it in `trust.additionalCABundle`:

```
kubectl -n lerian-system create configmap corporate-roots --from-file=root.pem
helm upgrade ... --set trust.additionalCABundle=corporate-roots
```

It is mounted read-only and read **once, at start**, so changing the ConfigMap
needs `kubectl rollout restart deploy/lerian-agent`. It grants the agent no
permission: a mounted ConfigMap is the kubelet's read, not the agent's. Your
roots are *added* to the public ones, so public addresses you also publish keep
being judged normally.

Three failure modes, each with a different symptom:

- **A key that is not a certificate** — a note, a truncated PEM — is skipped
  with a warning and the agent starts on the public roots alone. Nothing
  refuses to come up, because one bad key must not take an agent down; so what
  you see is the alert flood the bundle was supposed to stop. Grep the agent's
  log for `additional certificate authority bundle` after mounting one.
- **A private key in the bundle** is ignored the same way, and only its
  filename is logged.
- **A ConfigMap that does not exist**, with the knob set, is the loud one: the
  pod schedules and then sits in `ContainerCreating` with a `FailedMount` event
  naming the missing ConfigMap. `kubectl describe pod` says which name it
  wanted.

### Certificate watching and a narrowed NetworkPolicy

The agent learns when a published address's certificate is about to expire by
making an ordinary TLS handshake to that address on 443 - the same connection a
browser makes - from inside your cluster. Those dials leave through whichever
egress rule admits them, and both `networkPolicy.kubernetesApi` and
`networkPolicy.controlPlane` open TCP 443.

Egress rules are a union: a packet leaves if any rule admits it. So narrowing
`networkPolicy.controlPlane.cidr` alone does not stop the dials while
`networkPolicy.kubernetesApi.cidr` is still `0.0.0.0/0`, and narrowing
`kubernetesApi` alone does not stop them either. Narrow **both**, which is the
production shape, and every dial is dropped and no expiry date is ever learned
again - the certificate alerts go quiet, not because the certificates are
healthy, but because nobody can see them.

What you will see is not one clean verdict per address. A blocked dial is
dropped rather than refused, so it hangs for the full five-second probe
timeout, and one pass has fifteen seconds for all of them: the two or three
addresses a pass reaches are reported as unreachable, and the rest repeat their
last answer or are reported as not observed. When you narrow the second of the
two, add the addresses your releases publish on 443 to
`networkPolicy.extraEgress`.

## Which namespaces the agent may write to

The permissions this chart asks for come in four scopes.

**Cluster-wide, and read-only.** The node list, whether metrics-server
answers, what the cluster's pods already request, whether a LoadBalancer
Service with an address exists, whether a default StorageClass exists,
which IngressClasses are served, whether a named cert-manager ClusterIssuer
is present, and one read of the `kube-system` namespace that fingerprints the
cluster. These answer "does this cluster fit the stack you are about to
install" and "is it healthy", which are questions about the cluster as a
whole. Nothing in this half reads a Secret or creates a pod.
Two named writes are the only exceptions: `create` on namespaces, for Helm's
`--create-namespace`, and the StorageClass verbs, which are what let the
deployer install the component that gives a cluster a default StorageClass
when the preflight finds it has none - see "Repairing a cluster from its
preflight" below.

**Managed namespaces.** Installing, upgrading and uninstalling
releases; writing the Secrets a release needs; reading pod logs and events
when an install fails. This half exists once per namespace in
`agent.managedNamespaces`, and nowhere else.

**One identity Secret.** The chart creates `lerian-agent-identity` with an empty
declared payload and grants the agent only `get` and `update` on that exact
`resourceName`. Keeping the declared payload identical in every release makes
Helm preserve the agent-owned live keys on upgrade and rollback, and the object
is kept on uninstall, so the identity outlives both pod and release without
granting access to any other Secret in the agent's namespace.

**One Deployment, and its self-check.** Self-update gets `get` and `patch` on
the agent's own Deployment, also pinned by `resourceNames`, and `create`, `get`
and `delete` on pods in the agent's namespace for the throwaway Pod it runs a
new build in first; see the detailed section below.

The split is not cosmetic. `create` on pods anywhere in the cluster, plus
access to ServiceAccounts, lets whoever controls the agent schedule a pod
that mounts any ServiceAccount's token - cluster-admin included. Confining
every mutating verb to namespaces you declared is what turns "the agent
manages these namespaces" into a boundary rather than a description.

To keep the broad Helm Role out of the agent's own namespace, provide an explicit
list that leaves that namespace out unless a release actually installs there.
An empty list retains the compatibility default of managing the release namespace.
Enrollment persistence uses the dedicated identity-Secret Role, not this list. A
pre-registered or enrolling agent needs no blanket stack-management access where
it lives, and listing that
namespace hands a blanket Helm Role over the agent's own Deployment, which
the pinned self-update grant below otherwise keeps to a single object.
`agent.managedNamespaces: [midaz]` with the agent in `lerian-system` is the
tightest shape for either a pre-registered or enrolling agent that manages
Midaz.

Two consequences worth knowing before you install:

- **Every namespace you list must already exist.** The chart creates Role
  and RoleBinding objects inside them, and Kubernetes refuses to create an
  object in a namespace that is not there. `kubectl create namespace midaz`
  first, or the install fails naming the missing namespace.
- **Installing a stack into a new namespace is a two-step operation.** Add
  it to `agent.managedNamespaces` and `helm upgrade` this chart, then
  deploy the stack. Without the upgrade the install fails with `Forbidden`
  from the API server. This is the price of the boundary: an agent that
  could grant itself a new namespace would not be bounded by the list.

### Repairing a cluster from its preflight

A preflight that refuses an install names what the cluster is missing, and
where the deployer has a catalogue component that answers it, an operator can
accept the repair instead of opening a terminal. Those components install as
ordinary Helm releases into **`lerian-infra`**, so **add `lerian-infra` to
`agent.managedNamespaces`** (and create the namespace) if you want that path
to work. Without it the repair is queued, dispatched, and refused by the API
server with `Forbidden` - the same boundary as any other namespace, applied to
the deployer's own installs.

That refusal leaves something behind: the failed repair keeps holding its Helm
release name, so adding `lerian-infra` afterwards and accepting the same repair
again is answered `409 RELEASE_CONFLICT` rather than installing. Add the
namespace first, then remove the failed repair, then accept again - the order
and the commands are in
[the control plane's README](https://github.com/LerianStudio/deployer/blob/main/components/control-plane/README.md#chart-registry),
under "Retrying a repair that failed".

Which components can be installed this way, and which stay a written
instruction because they would need cluster-scoped grants this agent
deliberately does not hold, is listed in
[`docs/threat-model.md`](https://github.com/LerianStudio/deployer/blob/main/docs/threat-model.md).

Verify what a cluster actually granted, at any time:

```bash
kubectl auth can-i --list \
  --as=system:serviceaccount:lerian-system:lerian-agent
kubectl auth can-i get secrets --all-namespaces \
  --as=system:serviceaccount:lerian-system:lerian-agent   # expect: no
```

Every rule this chart asks for is written out one by one in
[`docs/threat-model.md`](https://github.com/LerianStudio/deployer/blob/main/docs/threat-model.md) - the code that needs it,
and what whoever held the agent would get from it. That table is compared
against this chart as rendered on every pull request, so it cannot describe a
smaller agent than the one you install.

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
| **A provisioning run's result** - whether plan or apply succeeded, the approved change addresses and attribute paths (never their values), and **the answers the module published, names and values**: your managed datastore's endpoint, port and database name. On failure, a sentence the agent composed - not your engine's output. The state backend is sent TO the agent, so it does not leave | On request, when a stack has a managed datastore | A Lerian operator approving the run | The work item (deleted by the next sweep after the item expires - the sweep runs on its own interval below. The item's clock starts when it became CLAIMABLE, not when it finished: it runs for the retention window below, extended while the operation is still going, up to the lifetime ceiling below) and the stack member's row |

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
resource stats, a preflight or a provisioning run still gets them; what gates
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
| `observation interval` | `30s` | `internal/bootstrap/config.go`, `DefaultHeartbeatInterval`; `charts/lerian-agent/templates/deployment.yaml`, `HEARTBEAT_INTERVAL` |
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

## Which registries the agent may pull from

The control plane tells the agent exactly which bytes to install, as a content
digest. A digest is a complete answer to "which bytes" and no answer at all to
"from whose host" - so on its own it would let a control plane that had been
taken over name `oci://registry.attacker.example/...` with a digest that
verifies perfectly, for the attacker's own chart.

`agent.allowedChartRegistries` is the other half. The agent refuses any chart
whose registry is not on the list, before it looks at the digest, and the
refusal names the registry so you can see where you were being sent. It applies
to installs, upgrades and the pre-upgrade preview alike.

Three things about the matching are worth knowing before you set it:

- **It compares path components, not text.** `ghcr.io/lerianstudio` allows
  `ghcr.io/lerianstudio/midaz` and refuses `ghcr.io/lerianstudio-evil/midaz`.
  A bare host (`registry.internal.example`) allows everything on that host.
  You can go the other way too and name one exact repository
  (`ghcr.io/lerianstudio/charts/lerian-agent`), which allows that repository
  and nothing beside it - the tag or digest a chart is pulled by is not part
  of the comparison, so pinning the repository does not mean pinning a
  version.
- **Credentials are refused; ports match exactly.** A reference like
  `user:pass@ghcr.io/...` is rejected outright. A private mirror on a
  non-default port is allowed only when the entry names the same endpoint,
  such as `registry.internal.example:5000/mirrors`; an entry without `:5000`
  does not allow it. Docker Hub host names remain portless because adding a
  port changes the shorthand rules container runtimes apply to those names.
- **Empty means Lerian's own hosts, not "anything".** The default covers the
  two hosts Lerian publishes charts to - `ghcr.io/lerianstudio` for the
  deployer's own charts, `registry-1.docker.io/lerianstudio` for the product
  catalog - and nothing else. There is no permissive
  value. An allowlist that allows nothing is a configuration error the agent
  reports at boot, naming the entry it could not parse.

Set it when you mirror Lerian charts into your own registry, or when you
install a chart Lerian does not publish:

```bash
--set 'agent.allowedChartRegistries={ghcr.io/lerianstudio,registry.internal.example/mirrors}'
```

Adding a registry here is a decision, not a setting: you are accepting whoever
operates that registry into the set of people who can put code in this cluster.
Nothing in the agent can weigh that for you.

`agent.allowedImageRegistries` is the same list for the agent's own image, kept
separate because Lerian publishes charts and images to different hosts - one
list would either refuse the agent's own image or widen the chart surface to a
whole public registry. It is checked against the repository a container runtime
resolves `image.repository` to, not the string: a name with no host means Docker
Hub, so if you mirror the agent image internally, write the host in
`image.repository` as well - a host-less name goes to Docker Hub whatever you
allow here.

### Pulling a chart from a private registry

The allowlist above says which registries this agent may pull from.
`agent.chartRegistry` says how it proves who it is at one of them - for a
`ghcr.io` package published with `internal` visibility, or your own private
mirror. They are different questions and the credential widens nothing: a chart
from a host the allowlist refuses is refused before the credential is reached.

The credential reaches the agent as a `kubernetes.io/dockerconfigjson` Secret -
the ordinary pull-secret shape - mounted read-only as a file. Two ways to get
one there.

**Let the chart create it:**

```bash
--set agent.chartRegistry.host=ghcr.io \
--set agent.chartRegistry.username=<org member> \
--set agent.chartRegistry.password=<token with read:packages>
```

**Or point at one you manage,** which is the better path and the only one that
can name more than one registry:

```bash
kubectl create secret docker-registry chart-pull \
  --docker-server=ghcr.io \
  --docker-username=<org member> \
  --docker-password=<token with read:packages> \
  -n lerian-system

helm upgrade ... --set agent.chartRegistry.existingSecret=chart-pull
```

Unset - the default - every chart pull is anonymous, which is all a public
chart needs and is exactly what this agent did before the option existed.

Four things worth knowing:

- **Rotation needs no restart.** Update the Secret and the next chart pull uses
  the new value. The kubelet refreshes a mounted Secret in place, about a
  minute after it changes, and the agent re-reads the file on every pull - so
  there is no `kubectl rollout restart` step, on either path. What a rotation
  must not be is half-written: a file the agent cannot parse makes it refuse
  the pull with the file named, rather than quietly falling back to an
  anonymous one.
- **One credential per registry, and that is why holding one is safe.** Each
  credential is offered only to the host its entry is keyed for. That matters
  because the chart reference arrives from the control plane: a credential that
  followed whatever host a reference named would let whoever writes that
  reference choose where your registry token goes. Spelling differences that do
  not change which registry is meant are folded - case, a leading `oci://` or
  `https://`, one trailing slash, a `:443` port, and Docker Hub's several
  names, which all resolve to `registry-1.docker.io`. Anything that cannot be a
  host - an organisation path like `ghcr.io/lerianstudio`, credentials before
  the host, an empty port, a trailing dot - is refused when the chart renders,
  because the agent refuses it at boot and a failure at `helm install` names
  the value while a `CrashLoopBackOff` names nothing.
- **A Secret with several registries works.** A `dockerconfigjson` holds one
  entry per host, and the agent honours every one of them; an entry may also
  narrow to an organisation (`ghcr.io/lerianstudio`), in which case the most
  specific entry that covers the chart wins. Only the `existingSecret` path can
  express this - `host`/`username`/`password` render exactly one entry.
- **TLS only.** The credential travels as an HTTP Basic header and the agent
  never downgrades a request to cleartext, so a plain-HTTP mirror cannot be
  reached with one. That is deliberate: a registry password in clear on the
  wire is worse than a failed pull. Put your mirror behind TLS.

Two failure modes to recognise. A Secret that does not exist yet, or has not
synced, leaves the pod `ContainerCreating` waiting on the volume - it never
starts and pulls anonymously. A file the agent can read but whose entries name
no registry the chart comes from produces an anonymous pull and a warning
naming both the chart's registry and the ones you did configure, which is the
thread to pull when a private chart comes back `unauthorized`.

The credential buys read access to charts. It grants nothing inside this
cluster, and it is never sent to the control plane.

### Updating the agent without touching the cluster

The chart grants `get` and `patch` on one single object: the agent's own
Deployment, pinned by `resourceNames`. That is what lets the control plane
hand a running agent a new image without anyone opening a shell against your
cluster. It reaches no other workload, not even in the agent's own namespace.

It is granted at install time deliberately. Adding it later would mean a
second RBAC change against clusters that already approved the first one,
and re-approving an agent's permissions is a contract renegotiation, not an
upgrade.

**What actually happens.** The control plane names a build in its answer to
the agent's heartbeat, as a version and an image digest. The agent first runs
that build once, as a throwaway Pod with its own ServiceAccount, pull secrets
and environment, which loads its configuration, makes one read from the
control plane and exits; see "If the new build does not come up" below. Only
then does it write the image of its own Deployment, always
`<your image.repository>@sha256:...`, never a tag, recorded in the
annotation `lerian.studio/self-update-image` - and Kubernetes replaces the
pod. It stops claiming new work the moment that patch lands, so nothing is
taken on that the departing pod cannot finish. A pod still running two
minutes later is not being replaced: the agent logs that and goes back to
work on the build it has. Anything already running
is finished by the departing pod or, if it is killed first, expires and is
picked up again by the replacement.

Four things bound it, and they are worth knowing before you grant it:

- **Your repository, not theirs.** The repository half of the image comes
  from the pod spec that is already running. The control plane chooses the
  digest and nothing else, so a new build can never move the agent to a
  different registry - and the assembled reference is checked against
  `agent.allowedImageRegistries` regardless.
- **By digest, never by tag.** A tag can be re-pointed in the registry after
  you approved it; a digest cannot.
- **The image written, one object granted.** The agent writes the image and
  the annotation recording it, nothing else: a conditional JSON patch that replaces it only after testing
  that the Deployment and its sole container are still the object it just
  read. Your env, volumes, probes and `securityContext` are untouched, and
  the chart stays their author. Be clear about what enforces that, though,
  because it is not RBAC: Kubernetes pins a grant to an object name, never to
  a field path, so the permission you hand over covers every mutable field of
  the one `lerian-agent` Deployment. No other workload is reachable, and the
  only `serviceAccountName` it could name is one already in the agent's own
  namespace - which is why that namespace should hold the agent and nothing
  more privileged than it. Restricting the patch to the image at the API
  server would take a cluster-scoped `ValidatingAdmissionPolicy`, which this
  chart deliberately does not ask for the rights to install.
- **Never a manifest.** The agent does not fetch YAML from the control plane
  and apply it. The manifest is this chart, and this chart is yours.

Turn it off by not letting the agent know which Deployment is its own:
`--set-string extraEnv[0].name=AGENT_SELF_DEPLOYMENT --set-string extraEnv[0].value=""`.
The agent then still reports the build it runs and logs the build the
control plane wants, so the divergence stays visible; you upgrade the chart
by hand.

**Recording the update.** The chart does not learn what the agent did. Once
an update has landed, read the digest off the running Deployment and put it
in your values, or the next routine `helm upgrade` re-renders `image.tag`
and walks the agent back to the older build with nothing in the diff saying
so:

```bash
kubectl -n <namespace> get deploy lerian-agent \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
# ghcr.io/lerianstudio/agent@sha256:...   -> set image.digest to that
```

Your declared state wins. When your tooling takes the image back (that
`helm upgrade` on Helm 3, an ArgoCD client-side apply, or a `kubectl apply`,
server-side with `--force-conflicts` included), the agent does not write
that build again: it logs `set image.digest=<digest> in the lerian-agent
chart values` and keeps running what your tooling declared, until you set
the digest or Lerian names another build.

**If the new build does not come up.** The Deployment uses `strategy:
Recreate`, so the old pod is stopped before the new one starts, and nothing
brings it back. That is why the new build proves itself first: the throwaway
Pod is pulled by your nodes with their own credentials and started in your
cluster, and only an exit code of 0 within 60 seconds lets the patch through.
An image your nodes cannot pull, a build that crashes on start, or a Pod your
API server refuses is logged by the agent as one error naming the build, and
the agent keeps running the one it has and tries again later with a growing
wait. The Pod is deleted however it ended. The chart's NetworkPolicy selects
it with the agent, so a default-deny NetworkPolicy of your own that blocks its
egress refuses the update rather than breaking the agent.

**Recovery is two steps, in this order.** Putting the old image back first
does not work, and the reason is worth understanding before 3am: the target
is still standing on the control plane. A recovered agent's first heartbeat
- inside thirty seconds - is answered with the same broken digest, and it
patches itself straight back onto it. What that looks like is a rollback
that "did not work", on a loop.

1. **Take the target off, on the control plane**, so there is nothing to
   converge back onto:

   ```bash
   lerian agents target unset          # if this tenant is pinned
   lerian agents target set --digest sha256:<previous>
   ```

   `unset` is enough only when the tenant was pinned to the bad build. If
   the bad build is the control plane's fleet-wide default
   (`lerian agents target set --fleet`), unsetting the pin
   drops this tenant *onto* it - pin the previous build instead, which also
   holds while the fleet default is being corrected. `lerian agents target`
   says which of the two you are looking at.

2. **Then put the old image back in the cluster:**

   ```bash
   kubectl -n <namespace> rollout undo deployment/lerian-agent
   ```

   or `helm upgrade` this chart with the previous `image.tag`/`image.digest`.

If you cannot reach the control plane at all, step 1 has a local
equivalent: clear `AGENT_SELF_DEPLOYMENT` (see above). The agent then
reports and logs the divergence and changes nothing, which breaks the loop
from inside the cluster.

### Deploy timeout (`HELM_TIMEOUT`)

`HELM_TIMEOUT` bounds how long the agent waits for one `helm
install`/`upgrade` to become ready before giving up and reporting the
deploy as failed. It applies per operation, not per work item. Default
`15m`.

Raise it for heavy charts - a full Midaz stack, or anything waiting on PVC
provisioning or cold-node image pulls, can exceed 15 minutes; lower it if
you would rather fail fast. Any Go duration string works (`30m`, `1h`):

```yaml
extraEnv:
  - name: HELM_TIMEOUT
    value: "30m"
```

### Rotating `agent.token`

`helm upgrade` with a new `agent.token` updates the chart-owned Secret, and
the Deployment picks up the change automatically (a checksum of the Secret
is baked into the pod template, so Kubernetes rolls the pod the moment the
Secret's content changes). If you use `agent.existingSecret` instead, that
Secret's lifecycle is yours, not the chart's - after updating it, run
`kubectl rollout restart deployment/lerian-agent -n <namespace>` yourself,
or the running pod keeps polling with the old token until something else
happens to bounce it.

There is no tenant value: the control plane resolves which tenant an agent
belongs to server-side, from the authenticated token, not from anything the
agent claims about itself - a client-editable tenant field would let a
misconfigured (or compromised) agent claim to be a different tenant's,
which is exactly the failure mode multi-tenant systems must not allow.

## The default image

`image.repository` defaults to `ghcr.io/lerianstudio/agent` - the
name the release pipeline actually publishes (`app_name_prefix: "deployer"` +
the `components/agent` directory name, see `.github/workflows/release.yml`),
on the one registry it publishes to. `image.tag` is empty and falls back to
`appVersion`, which the publish workflow rewrites to the release tag, so a
chart pulled from `oci://ghcr.io/lerianstudio/charts` already points at the
agent image built from that same tag - and `chart-publish.yml` refuses to
push a chart whose default image cannot be pulled **anonymously**.

The host is part of the default on purpose. A host-less name means Docker
Hub to every container runtime, and `docker.io/lerianstudio/deployer-*` is no
longer on the published path, so the short form would name a repository that
receives no build.

Set `image.repository` and `image.tag` explicitly whenever those two
conditions do not hold: installing from a git checkout instead of a
published chart (the `appVersion` committed to `Chart.yaml` is not kept in
step with the release tags - only the packaged chart's is - so the default
tag can name an image that was never built), or pulling from a mirror of
your own. Mirroring means setting `agent.allowedImageRegistries` too: the
default admits `ghcr.io/lerianstudio` and nothing else, so an agent pointed
at a mirror without it installs fine and then refuses its first
self-update.

**Anonymous pull.** `agent` is to be published **public**, along with
`agent-infra-runner`: a client's kubelet pulls both with no credential, and
`chart-publish.yml` refuses to publish this chart unless an anonymous inspect
of its default image succeeds. (The control plane is different - that image is
published `internal` and its chart takes an `imagePullSecrets`. It is not
installed in the client's cluster.)

At the time of writing the packages are still `internal` on the org, so the
switch to public visibility has not happened yet and a BYOC cluster needs
`imagePullSecrets` or a mirror until it does. That is one setting on the org's
packages, not a chart change - and the publish gate fails the release rather
than shipping a chart nobody can install.

## Relationship to the kustomize manifests

`deploy/base/` (kustomize) predates this chart and remains
for internal Lerian use during the migration window. This chart is the
supported install path for customers and is kept in parity with it for
ServiceAccount, RBAC, Secret, ConfigMap, Deployment and Service - same
resources, same names, just templated. The one deliberate difference: the
kustomize base also owns a Namespace object, this chart does not (see
"Install" above for why).
