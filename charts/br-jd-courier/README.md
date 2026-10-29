# br-jd-courier

Helm chart for [`br-jd-courier`](https://github.com/LerianStudio/br-jd-courier), the
Lerian JD Courier: it carries SPB and Pix traffic between JD Consultores and the
Lerian rail engines.

## Chart Contract

- Chart type: `multi-component`
- Required secrets: one existing Secret, named by `secrets.existingSecret` (default: the release fullname), carrying `LICENSE_KEY`, `POSTGRES_PASSWORD`, `DATABASE_URL` for the migration Job and, single-tenant, `IDP_M2M_CLIENT_SECRET` and `JD_PASSWORD`. The chart renders no Secret and no secret value, and refuses the render when any of them is given as a plain value.
- Dependency notes: no subcharts. PostgreSQL, the Access Manager and the licence gateway are external services.
- Production overrides: `jd-courier.image.tag`, `secrets.existingSecret`; under `config`: `ENVIRONMENT_NAME=production` ([Environment](#environment)), `ORGANIZATION_IDS`, `POSTGRES_*` (`POSTGRES_SSLMODE=verify-full`), `PLUGIN_AUTH_HOST`, `AWS_REGION` ([AWS identity](#aws-identity)); single-tenant, `IDP_DECLARATION_ENABLED`, `IDP_HOST`, `IDP_M2M_CLIENT_ID` ([Access Manager](#access-manager)) and `JD_BASE_URL`, `JD_LEGACY_CODE`, `JD_USER_CODE` for the SPB roles; `roles.spbSender` TLS ([SOAP TLS](#soap-tls-spb-sender)); JD's partner and address ([Pix ingress (JD)](#pix-ingress-jd)); `serviceAccount` ([AWS identity](#aws-identity)). Multi-tenant installs must set `migrations.enabled=false`.
- Source/license: [LerianStudio/br-jd-courier](https://github.com/LerianStudio/br-jd-courier). The Courier is closed source; this chart is published from [LerianStudio/helm](https://github.com/LerianStudio/helm).

## Install

The chart is published as an OCI artifact on GHCR. Anonymous `helm show chart`
resolves it:

```bash
helm show chart oci://ghcr.io/lerianstudio/br-jd-courier-helm --version <chart version>
helm upgrade --install <release> oci://ghcr.io/lerianstudio/br-jd-courier-helm \
  --version <chart version> --namespace <namespace> --values values.yaml
```

Pin `--version`. From a checkout, use `charts/br-jd-courier` instead of the OCI
reference. The `docs/UPGRADE-*.md` guides show a Docker Hub reference
(`registry-1.docker.io/lerianstudio/...`); an anonymous pull of it is refused
with `401`, so use the GHCR reference above unless you hold Docker Hub access.

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
| `admin` | `<release>-br-jd-courier-admin` | HTTP port, plus `ports.pixTransit` (8082) with the [Pix transit](#pix-transit-admin) | N (≥1) | `RollingUpdate` |

## Environment

`config.ENVIRONMENT_NAME` is **required**: the render fails without it. The
service reads it to turn its production checks on (`production`, exact), and
uses it as the environment segment of every Pix engine `credentialRef` and
multi-tenant JD bundle path (`tenants/{env}/...`). Unset, it would boot as
`development` with none of those checks. The service still reads the deprecated
`ENV_NAME` as a fallback; the chart does not, so rename `config.ENV_NAME` to
`config.ENVIRONMENT_NAME`.

The production checks run in the service at boot, not in the render: a
production pod refuses to start on `POSTGRES_SSLMODE=disable` or with no TLS on
the spb-sender's SOAP listener. The chart checks neither, nor
`ALLOW_INSECURE_TLS`. In particular, `helm lint` and `helm template` succeed on
`config.ENVIRONMENT_NAME=production` with no SOAP TLS shape (no `ingress`, no
`soapTls.existingSecret`, no `soapTls.terminatedUpstream`); the failure shows up
only when the spb-sender pod starts and crash-loops. Treat a clean render as
no evidence that the SOAP TLS shape is present: check the values against the
[SOAP TLS](#soap-tls-spb-sender) table before you install.

Every Courier boolean under `config` is the exact word `true` or `false`: `1`,
`t` or `TRUE` refuses the boot, and every role crash-loops.

`config.DEPLOYMENT_MODE` defaults to `byoc` (`local`, `byoc`, `saas`). Only
`saas` makes the service refuse a datastore connection without TLS; set it on
Lerian Cloud.

## Access Manager

Single-tenant (BYOC), the Courier publishes its own grants to the client's Access
Manager at boot, and nothing else does. Without them a first install refuses every
operator (`403`) and every engine and JD (`401`) while every pod reads Ready:
`/readyz` answers `200` with `permission_declaration` `degraded`. A green rollout
proves nothing here; check that `IDP_DECLARATION_ENABLED` is `true` and the entry
reads `up` (with the flag off it can read `up` on the partner opt-in alone).

| Key | Where | Value |
|---|---|---|
| `IDP_DECLARATION_ENABLED` | `config` | `"true"` |
| `IDP_HOST` | `config` | the Access Manager identity address, e.g. `http://plugin-access-manager-identity.<namespace>.svc.cluster.local:4001` |
| `IDP_M2M_CLIENT_ID` | `config` | the Courier's M2M application |
| `IDP_M2M_CLIENT_SECRET` | the Secret | that application's secret; refused under `config` |

Nothing provisions that application: the install's admin issues it once, as a
person, with `POST /v1/applications/service-credentials`, `source` `jd-courier` and
`target` `plugin-identity` (Access Manager 3.13.0 or later). Only the create answer
shows the `clientSecret`. With the flag on, a missing key refuses the boot. A
refused credential or manifest logs an ERROR and leaves the entry `degraded`; after
the fix, `kubectl rollout restart` the Deployments. Multi-tenant ignores all four
keys: the RI catalog and the tenant manager's reconcile carry the grants.

## Pix ingress (JD)

JD reaches the pix-ingress only as the client's partner in the Access Manager. The
client admin creates the JD partner in the Console with one grant, `jd-courier`
`pix-ingress` `post`, and issues JD's application under it; any other credential
gets `401`. The partner's opt-in reaches the Access Manager with the keys above
(with `IDP_DECLARATION_ENABLED` off, only when `IDP_HOST` and the M2M pair are
set). It needs Access Manager 3.14.0 and Caradhras 1.9.0-beta.1 or later: below
that the client admin cannot create the partner. Where
`charts/plugin-access-manager` pins older ones, override `identity.image.tag` and
`auth.image.tag` (3.14.0 or later), and `caradhras.image.tag` and
`caradhras.migrations.image.tag` together. Courier 1.2.0 removed
`PIX_VENDOR_SUBJECTS`; drop it from `config`, where nothing reads it.

The pix-ingress Service is ClusterIP on `ports.http`, and the chart renders no
Ingress for it. JD calls an HTTPS address the client exposes (its own Ingress or
load balancer). Route only JD's paths, `/v1/webhooks/` and `/v1/pix-automatico/`:
the same port answers the probes and `/version`. Health-check `/health` on
`ports.http`. Behind a proxy, set `config.TRUSTED_PROXIES` to its CIDRs: lib-auth
takes the caller's address from that list alone, and a tenant with an IP allowlist
refuses a caller without one. An entry that is not an IP or CIDR refuses the boot;
a bare address or a range wider than /8 is dropped with an ERROR.

## SOAP TLS (spb-sender)

The spb-sender's SOAP listener (`ports.soap`) is what the engines call, and they
refuse plain HTTP, so it needs TLS in homologation as much as in production.
Three shapes, all off by default; in production the spb-sender refuses to boot
with none of them:

| Shape | Values | What the chart does |
|---|---|---|
| Ingress | `roles.spbSender.ingress.enabled=true`, plus `className`, `annotations`, `hosts`, `tls` | renders an Ingress to the SOAP Service and sets `SOAP_TLS_TERMINATED_UPSTREAM=true` |
| Certificate in the pod | `roles.spbSender.soapTls.existingSecret=<kubernetes.io/tls Secret>` | mounts it read-only at `/etc/jd-courier/soap-tls` and sets `SOAP_TLS_CERT_FILE`/`SOAP_TLS_KEY_FILE`; the listener serves TLS itself |
| Terminated outside the chart | `roles.spbSender.soapTls.terminatedUpstream=true` | sets `SOAP_TLS_TERMINATED_UPSTREAM=true`, for a mesh or load balancer the chart does not render |

The Ingress must terminate TLS (a `tls:` block or the controller's certificate
annotation); the chart sets `SOAP_TLS_TERMINATED_UPSTREAM=true` without checking.
On AWS, use the ALB with `target-type: ip` (the Service is ClusterIP). The
Ingress routes only the SOAP port, and the SOAP listener is not a health
endpoint: point the ALB health check at `/health` on `ports.http` (8080 unless
overridden), the liveness probe's endpoint:

```yaml
roles:
  spbSender:
    ingress:
      enabled: true
      className: alb
      annotations:
        alb.ingress.kubernetes.io/target-type: ip
        alb.ingress.kubernetes.io/certificate-arn: <ACM certificate ARN>
        alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
        alb.ingress.kubernetes.io/healthcheck-port: "8080"
        alb.ingress.kubernetes.io/healthcheck-path: /health
        alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
```

Combining the Ingress with `soapTls.existingSecret` re-encrypts to the pod: set
`alb.ingress.kubernetes.io/backend-protocol: HTTPS`; the health check stays
HTTP on 8080. The certificate is read once at boot; rotating the Secret needs
`kubectl rollout restart`. `config.SOAP_TLS_*` is refused: those keys follow
these values.

## Pix transit (admin)

The admin can serve the outbound Pix transit: Pix engines call it in place of
JD's JDPI address, and the admin carries each call to JD on the Courier's own
JDPI token. Off by default. `roles.admin.pixTransit.enabled=true` sets `PIX_TRANSIT_SERVER_ADDRESS` from `ports.pixTransit` (8082) and adds that
port, named `pix-transit`, to the admin container and the admin Service. It
needs Courier image 1.2.0 or later (`jd-courier.image.tag`): an older admin
binds nothing there, and outbound Pix fails without an error.

In-cluster engines call `<release>-br-jd-courier-admin:8082`. An engine outside
the cluster (the institution's legacy core) needs an exposure this chart does not
render, with TLS, and authenticates with its Courier-issued transit credential.

The engines refuse plain HTTP, so the render fails unless one shape is set:

| Shape | Values | What the chart does |
|---|---|---|
| Certificate in the pod | `roles.admin.pixTransit.tls.existingSecret=<kubernetes.io/tls Secret>` | mounts it read-only at `/etc/jd-courier/pix-transit-tls` and sets `PIX_TRANSIT_TLS_CERT_FILE`/`PIX_TRANSIT_TLS_KEY_FILE`; the listener serves TLS itself |
| Terminated outside the chart | `roles.admin.pixTransit.tls.terminatedUpstream=true` | sets `PIX_TRANSIT_TLS_TERMINATED_UPSTREAM=true`, for a mesh or load balancer the chart does not render |

The certificate must name what the engines dial, and is read once at boot:
rotating the Secret needs `kubectl rollout restart`. `config.PIX_TRANSIT_*` is
refused: those keys follow these values. No proxy between an engine and the
transit may retry a `503`: a retry of JD's own `503` could come back as the
Courier's not-sent and release a hold JD may still settle.

Single-tenant, the transit reaches JD with the institution's SPI credential:
`config.JD_SPI_BASE_URL` (https in production), `config.JD_SPI_CLIENT_ID`, and
`JD_SPI_CLIENT_SECRET` in the Secret (refused under `config`). Multi-tenant
reads each tenant's `jd-spi` bundle from Secrets Manager instead. In both,
`config.JD_ALLOW_PRIVATE_NETWORK` governs the transit's JD client as it does the
SPB roles'.

The admin calls the Pix engines (async validation delivery) and JD's SPI
gateway. The chart renders no NetworkPolicy; a cluster that restricts egress
must allow both.

## AWS identity

The Courier reads AWS Secrets Manager: each engine's `credentialRef`, and in
multi-tenant each tenant's JD bundles. Give it an IAM role through
`serviceAccount` (off by default; every role then runs as the namespace's
`default`):

```yaml
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<account>:role/<role>   # IRSA
```

`serviceAccount.name` runs every role as an existing ServiceAccount instead.
An EKS Pod Identity association works on either. Every role Deployment uses it;
the migration Job does not.
Pods keep `automountServiceAccountToken: false`: the Courier never calls the
Kubernetes API, and IRSA and Pod Identity project their own token regardless.

The Courier reads the Secrets Manager region from `AWS_REGION` alone, defaults it
to `us-east-1`, and pins its AWS client to it, ahead of `AWS_DEFAULT_REGION` and
instance metadata. With the wrong region every engine credential lookup fails (Pix
deliveries and the cross-core relay) and, multi-tenant, every JD bundle. On EKS,
IRSA and Pod Identity inject the cluster's region into the container's `env`, which
wins over `config`: keep the engine credentials in the cluster's region. Elsewhere, set `config.AWS_REGION`.

## The single-writer guard

`spb-consumer` drains the vendor queue with a **destructive** read. A second
replica is lost traffic, not throughput. `helm template` fails when
`roles.spbConsumer.replicas` is above one, and the consumer uses `Recreate`
because a rolling update runs two consumers during every rollout.

The chart cannot read the rail registry, so its list of single-writer roles
duplicates a fact the rail descriptor owns. The boot guard (layer 1) and the
epoch fence (layer 2) are the other two layers; this one catches what never
reaches a boot.

All three cover the Courier's own replicas only. Any other reader of the same JD
queue (same ISPB and legacy code) erases messages the Courier would have read:
the legacy core's own receive, an engine, or another environment sharing the
credentials. Installing is safe: the drain reads only tenants whose
SPB channel is `ACTIVE`. Activate the SPB channel only after the client confirms
in writing that every other reader of that queue has stopped (the Courier's
`docs/runbooks/legacy-core-cutover.md`, "One reader").

## Secrets

The chart renders **no Secret and no secret value**. Every role loads one
existing Secret through `envFrom` — `secrets.existingSecret`, defaulting to the
release fullname — which must exist before install and carry:

| Key | Read by |
|---|---|
| `LICENSE_KEY` | every role |
| `POSTGRES_PASSWORD` | every role |
| `DATABASE_URL` | the migration Job (`postgres://…?sslmode=…`) |
| `JD_PASSWORD` | both SPB roles (`spb-consumer`, `spb-sender`), single-tenant only |
| `JD_SPI_CLIENT_SECRET` | the admin with the [Pix transit](#pix-transit-admin), single-tenant only |
| `IDP_M2M_CLIENT_SECRET` | every role, single-tenant ([Access Manager](#access-manager)) |

```bash
RELEASE_NAME=courier  # the name you pass to helm install
kubectl create secret generic "${RELEASE_NAME}-br-jd-courier" --from-literal=LICENSE_KEY=… \
  --from-literal=POSTGRES_PASSWORD=… --from-literal=DATABASE_URL=… \
  --from-literal=JD_PASSWORD=… --from-literal=IDP_M2M_CLIENT_SECRET=…   # single-tenant
```

The name follows `secrets.existingSecret` when set; otherwise it is the release
fullname, `<release>-br-jd-courier` (just `<release>` when the release name
already contains `br-jd-courier`).

`LICENSE_KEY` is read by name (`secretKeyRef`), not through `envFrom`: a Secret
that lacks it stops the container at creation with `CreateContainerConfigError`,
which names the missing key, rather than letting the pod boot and refuse its own
licence.

Putting any of these, or `COURIER_ROLES`, under `config` refuses the render, as
do `M2M_CLIENT_SECRET` (lib-auth's deprecated alias), `REDIS_PASSWORD`,
`MULTI_TENANT_REDIS_PASSWORD`, `MULTI_TENANT_SERVICE_API_KEY` and
`POSTGRES_REPLICA_PASSWORD` (put those in the Secret too).
Each engine's Pix credential is read from Secrets Manager at runtime. JD's
credentials are per-tenant Secrets Manager bundles in multi-tenant; in
single-tenant they come from this Secret (`JD_PASSWORD`, `JD_SPI_CLIENT_SECRET`).

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
against **one** database. It schedules with the roles' `nodeSelector`,
`tolerations` and `affinity`.

**From Courier 1.1.x:** the Job migrates before the rollout, and the 1.2.0
migrations drop schema the running 1.1.x pods still read (the engine credential
column and the bypass table). Until the rollout replaces them, the old
spb-sender, pix-ingress and admin pods fail every engine lookup: engine SOAP
sends are refused and deliveries fail. The old spb-consumer stops reading from JD
until it is replaced; messages wait in JD's queue. Upgrade an install with an
active channel in a quiet window.

From 1.1.x, JD's current credential stops working at the rollout: 1.2.0 admits
JD only under a partner ([Pix ingress (JD)](#pix-ingress-jd)), and the Access
Manager accepts that partner only after a 1.2.0 pod publishes the opt-in. In
order: upgrade with the [Access Manager](#access-manager) keys set; wait for
`permission_declaration` to read `up`; the client admin creates JD's partner and
issues JD's application; JD switches to it. Inbound Pix answers `401` to JD from
the rollout until then, so schedule the switch with JD.

⚠️ **Multi-tenant installs are not covered.** Nothing on the platform applies
per-tenant migrations on deploy. The chart refuses `migrations.enabled=true`
together with `config.MULTI_TENANT_ENABLED=true`; per-tenant migrations are the
tenant manager's own operation.

The chart only sees `config`. A `MULTI_TENANT_ENABLED` placed in the Secret
(`secrets.existingSecret`) is out of its sight: the render passes and the Job
migrates the one database `DATABASE_URL` names. Keep the flag in `config`, where
the guard can read it.

## Telemetry

Metrics and traces leave over OTLP only; nothing is scraped. Every role sends
to `telemetry.otlpEndpoint`, by default `$(NODE_IP):4317`, the collector on the
pod's own node. `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` follows
`config.ENVIRONMENT_NAME` unless `config` sets it. The chart sets it in the pod env, where Kubernetes expands
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
- No Ingress beyond the spb-sender's SOAP one ([Pix ingress (JD)](#pix-ingress-jd)
  covers the pix-ingress's exposure), no NetworkPolicy, HPA or
  PodDisruptionBudget. `spb-consumer` must never get an HPA.

## Checks

```bash
helm lint charts/br-jd-courier
helm template t charts/br-jd-courier -f .github/configs/helm-render-values/br-jd-courier.yaml
cd .github/scripts && go test ./validate-helm-charts -run Courier   # the render contract above
```
