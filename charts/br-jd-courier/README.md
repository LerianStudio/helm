# br-jd-courier

Helm chart for [`br-jd-courier`](https://github.com/LerianStudio/br-jd-courier), the
Lerian JD Courier: it carries SPB and Pix traffic between JD Consultores and the
Lerian rail engines.

## Chart Contract

- Chart type: `multi-component`
- Required secrets: one existing Secret, named by `secrets.existingSecret` (default: the release fullname), carrying `LICENSE_KEY`, `POSTGRES_PASSWORD` and, for the migration Job, `DATABASE_URL`. The chart renders no Secret and no secret value, and refuses the render when any of them is given as a plain value.
- Dependency notes: no subcharts. PostgreSQL, the Access Manager and the licence gateway are external services.
- Production overrides: `jd-courier.image.tag`, `secrets.existingSecret`, and under `config`: `ENVIRONMENT_NAME=production`, `ORGANIZATION_IDS`, the `POSTGRES_*` connection keys (`POSTGRES_SSLMODE=verify-full`), `PLUGIN_AUTH_HOST`, and `PIX_VENDOR_SUBJECTS` (single-tenant) or `SYSTEMPLANE_ENABLED=true` (multi-tenant). Multi-tenant installs must set `migrations.enabled=false`.
- Source/license: [LerianStudio/br-jd-courier](https://github.com/LerianStudio/br-jd-courier). The Courier is closed source; this chart is published from [LerianStudio/helm](https://github.com/LerianStudio/helm).

## Release bump

On a stable tag the Courier release dispatches `app-sync.yml` here, which writes the
new version to `jd-courier.image.tag` (the `helm_values_key_mappings` of the Courier
release workflow) and to `appVersion`. The image is
`ghcr.io/lerianstudio/br-jd-courier` (the release publishes the same tag to
Docker Hub as `lerianstudio/br-jd-courier`); registry tags have no leading `v`.

## Roles

One binary, four roles, **four Deployments off one image**. Each
Deployment sets `COURIER_ROLES` to its own role; the chart refuses an override.

| Role | Deployment | Service | Replicas | Strategy |
|---|---|---|---|---|
| `spb-consumer` | `<release>-br-jd-courier-spb-consumer` | none | **exactly 1** | `Recreate` |
| `spb-sender` | `<release>-br-jd-courier-spb-sender` | SOAP port (`ports.soap`, 8081) | N | `RollingUpdate` |
| `pix-ingress` | `<release>-br-jd-courier-pix-ingress` | HTTP port (`ports.http`, 8080) | N | `RollingUpdate` |
| `admin` | `<release>-br-jd-courier-admin` | HTTP port | N (≥1) | `RollingUpdate` |

## The single-writer guard

`spb-consumer` drains the vendor queue with a **destructive** read. A second
replica is lost traffic, not throughput. `helm template` fails when
`roles.spbConsumer.replicas` is above one, and the consumer uses `Recreate`
because a rolling update runs two consumers during every rollout.

The chart cannot read the rail registry, so its list of single-writer roles
duplicates a fact the rail descriptor owns. The boot guard (layer 1) and the
epoch fence (layer 2) are the other two layers; this one catches what never
reaches a boot.

## Secrets

The chart renders **no Secret and no secret value**. Every role loads one
existing Secret through `envFrom` — `secrets.existingSecret`, defaulting to the
release fullname — which must exist before install and carry:

| Key | Read by |
|---|---|
| `LICENSE_KEY` | every role |
| `POSTGRES_PASSWORD` | every role |
| `DATABASE_URL` | the migration Job (`postgres://…?sslmode=…`) |

```bash
RELEASE_NAME=courier  # the name you pass to helm install
kubectl create secret generic "${RELEASE_NAME}-br-jd-courier" --from-literal=LICENSE_KEY=… --from-literal=POSTGRES_PASSWORD=… --from-literal=DATABASE_URL=…
```

The name follows `secrets.existingSecret` when set; otherwise it is the release
fullname, `<release>-br-jd-courier` (just `<release>` when the release name
already contains `br-jd-courier`).

`LICENSE_KEY` is read by name (`secretKeyRef`), not through `envFrom`: a Secret
that lacks it stops the container at creation with `CreateContainerConfigError`,
which names the missing key, rather than letting the pod boot and refuse its own
licence.

Putting any of these, or `COURIER_ROLES`, under `config` refuses the render.
The vendor and engine credentials are per-tenant secret bundles resolved at
runtime, not chart values.

Non-secret environment goes under `config` and lands in one ConfigMap shared by
all roles.

## Licence

A revoked licence does not restart the pod: the process stays up, answers its
probes and refuses business traffic with `503 JDC-0902`. Liveness (`/health`)
never fails over the licence, so look at the logs, `/readyz` and the
`jdc_license_state` gauge (0 valid, 1 grace, 2 revoked, 3 gateway
grace: expired, inside the gateway's grace window), not at the
restart count. **Revoked heals by itself**: while revoked the process
re-validates after 1 minute, doubling to every 15 minutes, and serves again at
the first valid answer or gateway-reported grace, with no restart. Do not restart a pod while the licence
is still invalid: it validates at boot, refuses to start and crash-loops until
the licence is fixed.

## Migrations

A `pre-install` / `pre-upgrade` hook Job runs `migrate up` from the same image
against **one** database.

⚠️ **Multi-tenant installs are not covered.** Nothing on the platform applies
per-tenant migrations on deploy. The chart refuses `migrations.enabled=true`
together with `config.MULTI_TENANT_ENABLED` set to any spelling the service reads
as true (`1`, `t`, `true`, in any case); per-tenant migrations are the tenant
manager's own operation.

The chart only sees `config`. A `MULTI_TENANT_ENABLED` placed in the Secret
(`secrets.existingSecret`) is out of its sight: the render passes and the Job
migrates the one database `DATABASE_URL` names. Keep the flag in `config`, where
the guard can read it.

## Telemetry

Metrics and traces leave over OTLP only; nothing is scraped. Every role sends
to `telemetry.otlpEndpoint`, by default `$(NODE_IP):4317`, the collector on the
pod's own node. The chart sets it in the pod env, where Kubernetes expands
`$(NODE_IP)`, and refuses `config.OTEL_EXPORTER_OTLP_ENDPOINT`, which the pod
env would silently shadow. **Production boots with the defaults:** that hop never
leaves the node, so for the default endpoint alone the chart sets
`ALLOW_INSECURE_OTEL`, which lib-observability requires before it sends
plaintext under `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT=production`. A remote
endpoint must be `https://`, or `config.ALLOW_INSECURE_OTEL` must carry its own
reason; otherwise the boot refuses and names both fixes.
Page on the absence of Courier telemetry: a silent Courier is otherwise
indistinguishable from an idle one.

## Not provided

- **Co-locating `admin` with `spb-sender`** (a BYOC knob to
  save a pod at the cost of one NetworkPolicy covering operator and engine
  traffic) is not a value yet. Disable `roles.admin` only once it exists.
- No Ingress, NetworkPolicy, HPA or PodDisruptionBudget. `spb-consumer` must
  never get an HPA.

## Checks

```bash
helm lint charts/br-jd-courier
cd .github/scripts && go test ./validate-helm-charts -run Courier   # the render contract above
```
