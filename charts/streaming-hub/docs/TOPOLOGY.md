# streaming-hub deployment topology

streaming-hub ships as **one image, one binary**, selected into a role at
**runtime** via `STREAMING_HUB_ROLE` ∈ `{all, ingest, delivery}`. There is no
build-time split — no `cmd/ingest`/`cmd/delivery`, no `ARG ROLE`. This chart
exposes that runtime choice through the single `streamingHub.mode` switch.

## The role model

Every role serves the **full** Fiber control plane on `:8080`
(`/healthz`, `/readyz`, `/metrics`, `/v1`, `/admin`). The role gates **which
background Launcher Apps register** and **which Kafka clients dial** — not which
HTTP routes mount.

| Role | Background apps | Kafka clients | Postgres pool (open/idle) |
|------|-----------------|---------------|---------------------------|
| `all` | every app (ingest + delivery co-resident) | all three | 25 / 12 |
| `ingest` | consumer + manifest-refresh + partition-cron + idempotency-reaper | ingest consumer only | 8 / 4 |
| `delivery` | dispatcher + dlq-consumer + dlq-prune + topic-reconciler | DLQ + reconciler-admin | 16 / 10 |

## How the chart maps mode → workloads

- **`mode: all`** → `templates/all/*` render: one `streaming-hub-all` Deployment
  with `STREAMING_HUB_ROLE=all`, plus its Service (and HPA/PDB when enabled).
- **`mode: split`** → `templates/ingest/*` and `templates/delivery/*` render:
  two Deployments (`streaming-hub-ingest`, `streaming-hub-delivery`) with the
  matching role env, plus their Services (and per-role HPA/PDB).

The shared singletons (`templates/configmap.yaml`, `templates/secret.yaml`,
`templates/serviceaccount.yaml`) are role-invariant and rendered exactly once
regardless of mode. The Deployment/Service/HPA/PDB bodies are a single
parameterized partial (`templates/_deployment.tpl`) invoked by thin
mode-gated wrappers — no per-role body duplication.

### Why the role-specific vars are explicit `env`, not in the ConfigMap

`STREAMING_HUB_ROLE` and the Postgres pool sizes differ per role. Kubernetes env
precedence is **`env` > `envFrom`**, so the chart injects those three vars as
explicit per-Deployment `env:` while everything role-invariant stays in the one
shared ConfigMap consumed via `envFrom`. A role's pool size therefore cleanly
overrides any shared default, and the ConfigMap never has to fork per role.

## Independent scaling and the consumer group

In `mode: split`, ingest and delivery scale independently as **N + M** replicas
in one ingest consumer group; delivery's DLQ consumer is a structurally-disjoint
second group. Background singleton crons stay singleton across replicas via the
hub's `internal/shared/dblock` advisory-lock registry — the chart does not need
to pin them to a single replica.

> **Never overlap `mode: all` with `mode: split` on the same Kafka cluster.**
> `all` and `ingest` join the same consumer group → double-consume. See the
> README's double-consume hazard callout.

For the full architecture, see `streaming-hub/docs/architecture.md`.
