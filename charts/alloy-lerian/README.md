# alloy-lerian

Telemetry collection agent for client clusters. Wraps the upstream Grafana Alloy
chart and renders the collection pipeline from semantic parameters.

## Chart Contract

- Chart type: `dependency-wrapper`
- Required secrets: `alloy-api-key` (key `api-key`) — operator-provisioned in the origin cluster before install, in the `client` profile. Not created by this chart. Omitted in the `own` profile, where the internal platform does not validate it.
- Dependency notes: two external dependencies, pinned exactly. `alloy` 1.11.1 (upstream agent) is unconditional; `kube-state-metrics` 8.2.0 is condition-gated on `kube-state-metrics.enabled` so clusters that already run it can reuse the existing instance.
- Production overrides: `profile` and `origin.id` are required and have no default — the render fails without them. `destination.endpoint` is required. Override `destination.retry.maxElapsedTime` and `destination.queue.size` from measured volume per environment.
- Source/license: [grafana/alloy](https://github.com/grafana/alloy) (Apache-2.0), [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics) (Apache-2.0).

## What this chart does differently

The processing chain is **not** part of the values surface. Consumers declare
intent; the chart derives the wiring.

That is deliberate. In this agent, components form a graph through `output`
references rather than an ordered list, so swapping two stages produces **no
error** — it produces telemetry without enrichment, silently. Three ordering
constraints are contractual and each was verified by deliberately breaking it:

| Constraint | What inverting it produces |
|---|---|
| Admission first | Load is allocated before being shed |
| Enrichment before batching | Batching discards the connection context the association path reads, so telemetry arrives with no pod attribution |
| Batching last | Enrichment operates on individual records |

## Profiles

`profile` is required, has no default, and is not inferable. The boundary is
operational responsibility, not preference.

| | `own` | `client` |
|---|---|---|
| Application telemetry over the standard protocol | yes | yes |
| Cluster-scope state | yes | yes |
| Cluster-object metrics | yes | yes |
| **Node infrastructure** | **yes** | **no** |
| In-transit data inspection | configurable, off by default | **parameter does not exist** |
| Regulated-data sanitisation | yes | yes |
| Destination credential | omitted by default | required |

Node infrastructure is excluded in the `client` profile because the node belongs
to the client: collecting it asks for data we have no standing to act on, and
adds traffic across the public network for no return.

**Sanitisation does not vary by profile.** There is no profile without it.

## Roles

The chart delivers roles, not one agent.

| Role | Topology | Observes |
|---|---|---|
| `node` | one per node | application telemetry pushed to it — push cannot duplicate |
| `singleton` | exactly one replica | cluster-scope state and cluster-object metrics |

A cluster-scoped watcher replicated per node writes the same series from every
replica, with no attribute distinguishing the writers: cost grows with cluster
size while information does not. Measured before this chart existed — writes per
minute equalled the node count exactly, across five environments.

## Regulated-data sanitisation

Runs at the edge, before anything leaves the origin cluster, and is **not
configurable**. There is no value that disables a rule, weakens one, or produces
unsanitised output. The absence of those knobs is the guarantee.

Seven classes are covered: fiscal document, person name, email address, phone
number, payment key, postal address, opaque resource identifier.

What each class preserves, and why:

| Class | Preserved | Reason |
|---|---|---|
| Fiscal document | first 3 digits | correlation without reconstruction |
| Person name | first and last term | legibility in diagnosis |
| Email address | 2 local chars + **whole domain** | the domain identifies the provider, not the person |
| Phone number | country + area code | region is useful; the number is not |
| Payment key | first and last block | traceability without reconstruction |
| **Postal address** | **nothing — masked entirely** | **any fragment sharply narrows the search for a person** |
| Opaque identifier | prefix + 4 chars | correlation of the same resource |

Correctness is asserted in CI against a known input and expected output, and
blocks release on mismatch. This is not belt-and-braces: the rules run with
errors ignored, so a malformed rule produces **no error** — it produces output
that looks masked and is not. Verified: the wrong backreference form emits the
literal text `$1` with no warning at all.

**Known and accepted false positive:** the document rule masks any 11+ digit
run, including transaction identifiers and latency values. Measured at roughly
2% of log lines. Accepted because a false positive costs legibility while a
false negative leaks a document. Requiring a field prefix was evaluated and
rejected — the canonical case is a bare document in running text.

## Delivery guarantees

Queue and retry are enabled. Without them any blip in the destination is
definitive, unrecorded loss.

Retry classification is by status code and is **not symmetric**: `429`, `502`,
`503` and `504` are retryable; everything else is permanent and discarded
immediately. A rejected credential (`401`, `403`) therefore causes continuous
silent loss rather than a growing queue — which is why permanent discard must
be alerted separately from queue saturation. They are different causes: the
former is misconfiguration and does not resolve itself.

The queue is in memory. Persistence is out of scope: the durable backend sits
below the agent's stable component tier, and enabling it would require lowering
the stability floor **globally**, un-gating every unstable component in a
financial-institution cluster. Consequence accepted — a process restart loses
the in-flight queue.

## Collection interval

Floor of 60 seconds, enforced. A lower value is **rejected, not clamped** —
clamping would hide the divergent intent of whoever set it.

Cost at the destination is series × writes per minute. Collecting faster than
anyone queries wastes CPU in the client cluster, bandwidth across the public
network, and processing at the destination.

## Origin identifier

Required, no default, and validated against a canonical form that accepts
hyphenated composition.

It marks **provenance, not identity**. The credential authenticates the sender;
the marker is self-declared, so an authenticated origin could claim another's
identifier. Out of scope by decision, recorded as a known limit.

⚠️ Changing the identifier for a live environment is a **data migration**, not a
configuration tweak. The marker is part of series identity at the destination, so
a new value creates new series and orphans every existing one.

## Minimal installation

```yaml
profile: client
origin:
  id: acme-prd
destination:
  endpoint: https://telemetry.example.net
```

```console
helm install alloy oci://ghcr.io/lerianstudio/alloy-lerian-helm \
  --version <pinned> -n monitoring -f values-acme.yaml
```

The credential Secret must exist in the namespace before install.
