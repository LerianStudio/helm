# alloy-lerian

Telemetry collection agent for client clusters. Wraps the upstream Grafana Alloy
chart and renders the collection pipeline from semantic parameters.

## Chart Contract

- Chart type: `dependency-wrapper`
- Required secrets: `alloy-lerian` (key `telemetry-token`) — created by the client before install, from a token we hand over, in the `client` profile. The chart reads it and never creates it. When Fleet Management is enabled, the same Secret carries a second key, `fleet-token`. One Secret, one command: it is the only manual step.
- Dependency notes: three dependency entries, all pinned exactly. `alloy` 1.11.1 appears **twice** under the `node` and `singleton` aliases, each condition-gated on its own `enabled` value, because the upstream chart delivers one set of workloads and the design needs two topologies. `kube-state-metrics` 8.2.0 is condition-gated on `kube-state-metrics.enabled` so clusters that already run it can reuse the existing instance.
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
| **Node infrastructure** | not collected today; the profile permits enabling it | **not collected, and enabling it fails the render** |
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

**Seven classes** are covered: person name, email address, phone number, bank
account and branch, Pix key, postal address, authentication credential.
Identifiers stay in clear by decision (2026-10-10): CPF, CNPJ, matricula, contract
numbers, UUIDs and resource ids.

### ⚠️ Read this before treating the list above as coverage

The classes split into two kinds, and **the difference decides what happens
when an application starts logging something new**:

| | How it recognises the data | If a field is renamed or a new app logs it |
|---|---|---|
| **By FORM** | the value's own shape (`+5511…`, `x@y.z`, `Bearer <token>`) | **still masked** — the field name is irrelevant |
| **By FIELD NAME** | an expected label (`customerName=`, `endereco=`, `chave_pix=`, `password=`) | **passes through unmasked** |

(Ten rules across seven classes: some classes need two rules.)

By form: phone, email, and the scheme form of credential (`Bearer <token>`).

By field name: person name, bank account and branch, Pix key, postal address, and
the key and assignment forms of credential (`token=`, `password=`).

**Why the second kind cannot simply be fixed:** `João Silva` is indistinguishable
from `Rua Augusta` without the field label. Names and addresses have no distinctive
form, so the anchor is unavoidable — this is a property of the data, not a shortcut.

**Measured on a live cluster:** 500 real records carried **22 distinct field names,
and none** was one of the labels the anchored rules look for. Those rules
protect a naming convention that nothing enforces.

### What the CI gate does and does not prove

`sanitizacao/porta-de-entrega.sh` runs every fixed input/expected pair in
`sanitizacao/casos/` against the pinned agent. It answers *"do the rules still do what we wrote?"* — a regression
test, and a load-bearing one: a malformed rule produces **no error** under
`error_mode = "ignore"`, only output that looks masked (verified — the wrong
backreference notation emits the literal text `$1.***.***-**`).

It does **not** answer *"do the rules cover what the applications emit?"* Proven by
injection: removing only `holder` from the person-name rule exposes
`holderName=Ana Silva`, and the gate still reports 36 cases, 0 failures.

**A green gate is not evidence that PII is protected.** Treating it as such is worse
than not having it, because it grants confidence that does not correspond.

What each class preserves, and why:

| Class | Preserved | Reason |
|---|---|---|
| Person name | **given name only** | the surname is the most identifying term — preserving it defeats the rule |
| Email address | 1–2 local chars + **whole domain** | the domain identifies the provider, not the person |
| Phone number | country + area code | region is useful; the number is not |
| Bank account and branch | nothing, the label only | the value has no form that tells it from `count:7` |
| Pix key | nothing, the label only | the value may be a CPF or UUID, which have no form of their own to mask |
| **Postal address** | **nothing — masked entirely** | **any fragment sharply narrows the search for a person** |
| **Authentication credential** | **scheme name only** (`Bearer`, `Basic`) | a leaked token is access, not identification; a preserved JWT prefix would disclose the signing algorithm |

### Two further limits, documented rather than implied

**Log BODIES only.** Measured: a value masked in a log body was left intact in a
metric label and a span attribute, in the same agent, at the same instant. Rewriting a metric label creates a
new series, which is what this migration exists to reduce.

**String bodies only.** A `kvlist`/`map` body traverses every rule untouched.
Measured: 20 of 20 real records have string bodies, so it does not manifest in
current traffic — but the mechanism allows it. Covered by an explicit test case
(`risco-corpo-estruturado`) that passes by *recognising* the gap and fails if the
premise changes.

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

## BYOC installation

### 1. Create the Secret

Both tokens are handed over by Lerian through a secure channel. The chart reads
this Secret and never creates it.

```console
read -rs TELEMETRY_TOKEN   # paste, no echo
read -rs FLEET_TOKEN       # paste, no echo
kubectl create secret generic alloy-lerian -n monitoring \
  --from-file=telemetry-token=<(printf '%s' "$TELEMETRY_TOKEN") \
  --from-file=fleet-token=<(printf '%s' "$FLEET_TOKEN")
```

> **Never use `--from-literal` for a token.** The value is visible in
> `ps -eo args` while the command runs, and it lands in shell history.

### 2. values.yaml

The full client values file. Everything that is the same for every client —
destination, Fleet Management, collection perimeter — is a chart default and is
deliberately absent here.

```yaml
profile: client

origin:
  # <client>-<stage>, lowercase, stage = stg | prd.
  # The client name is ONE word: acme-prd, never acme-corp-prd.
  id: acme-prd

# The only reason these blocks exist is to mark the Secret as REQUIRED.
# The chart cannot decide that on its own: the correct value depends on the
# PROFILE, and `extraEnv` is static subchart YAML that cannot read it. The chart
# default is `optional: true`, which is correct for the `own` profile — there
# the destination does not authenticate and no Secret exists.
#
# ⚠️ `extraEnv` is a LIST and lists do not merge: declaring yours replaces the
# chart's entirely. That is why the Fleet entries reappear here — they are the
# same as the default and have to come back with it.
node:
  alloy:
    extraEnv:
      - name: ALLOY_DESTINATION_CREDENTIAL
        valueFrom:
          secretKeyRef:
            name: alloy-lerian
            key: telemetry-token
            optional: false
      - name: ALLOY_FLEET_POD_NAME
        valueFrom:
          fieldRef:
            fieldPath: metadata.name
      - name: ALLOY_FLEET_TOKEN
        valueFrom:
          secretKeyRef:
            name: alloy-lerian
            key: fleet-token
            optional: false

singleton:
  alloy:
    extraEnv:
      - name: ALLOY_DESTINATION_CREDENTIAL
        valueFrom:
          secretKeyRef:
            name: alloy-lerian
            key: telemetry-token
            optional: false
      - name: ALLOY_FLEET_POD_NAME
        valueFrom:
          fieldRef:
            fieldPath: metadata.name
      - name: ALLOY_FLEET_TOKEN
        valueFrom:
          secretKeyRef:
            name: alloy-lerian
            key: fleet-token
            optional: false
```

### 3. Install

```console
helm install alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm \
  --version <pinned> -n monitoring --create-namespace -f values.yaml
```

### What is NOT in the file, and why

| Setting | Default | Why the client does not set it |
|---|---|---|
| `ALLOY_CLIENT_ID` | derived from `origin.id` | Delivered through `envFrom`, from a ConfigMap the chart renders. It used to be repeated by hand and could drift — and when it drifts nothing fails: telemetry arrives stamped with the **wrong** client, in someone else's dashboard. The render is refused if an explicit value diverges. |
| `ALLOY_DESTINATION_ENDPOINT` | derived from `destination.endpoint` | Same mechanism, same reason. |
| `destination.endpoint` | `https://telemetry.lerian.io` | Our edge, not a client choice. |
| `fleetManagement` | enabled, `url` and `username` filled in | This is what lets collection be adjusted without asking the client for anything: no chart upgrade, no maintenance window. The client supplies only the token, through the Secret above. |
| `collection.onlyNamespaces` | `^midaz$`, `^midaz-plugins$` | Where our products are installed. Override only if this client installed them elsewhere. |

## Agent log level

`error` by default: the cluster belongs to the client, and the agent should not
spend their disk narrating normal operation. MEASURED on an idle install —
99 `info` lines to 7 `error`.

```yaml
logging:
  level: error     # error | warn | info | debug
```

To diagnose, raise it, reproduce, then put it back:

```console
helm upgrade ... --set logging.level=debug
```

Any other value fails the render. Without that guard the agent would reject the
config at startup, and the rejection would surface only in the pod log — the
very log being configured.

### ⚠️ What `error` hides

Worth knowing before you need it:

- **`successfully loaded remote configuration` is `info`.** It is the
  confirmation that Fleet loaded, and in BYOC Fleet governs the whole collection
  pipeline. At `error` there is no positive line saying the remote config came
  through; silence becomes the only success signal.

- **Delivery failure appears at two levels, and only the worse one is `error`:**

  ```
  level=error  "Exporting failed. Dropping data."              <- discarded
  level=info   "Exporting failed. Will retry the request..."   <- retrying
  ```

  So at `error` the client sees permanent loss but **not** a flaky destination
  that still recovers on retry. An unstable endpoint stays invisible until it
  starts discarding.

`debug` deserves care in a client cluster: volume grows sharply and the agent
narrates component evaluation every cycle. It is not a PII leak path — the
sanitisation rules act on the body in TRANSIT, and the agent log does not
transcribe record bodies — but `livedebugging` does carry raw payloads, which is
why it is refused in the `client` profile.
