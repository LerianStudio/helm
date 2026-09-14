# br-spi-mock-bacen Helm Chart

## Chart Contract

- Chart type: `single-service`
- Required secrets: None for default render. The chart renders no Secret and reads no credential; every value it needs is non-sensitive configuration in the ConfigMap.
- Dependency notes: Not used. The chart has no subcharts, no `Chart.lock`, and no external service requirement — the mock runs standalone.
- Production overrides: None. This chart must not run in production. `environment` accepts only `local`, `development`, `test`, and `ci`; any other value fails the render. For a non-production deploy, override `app.image.tag` and, if you mirror images, `global.imageRegistry`.
- Source/license: Source is in `github.com/LerianStudio/helm`; the simulated service lives in `github.com/LerianStudio/br-sfn` (`services/spi/mock-bacen`). License is Apache-2.0.

## Purpose

`br-spi-mock-bacen` deploys the BACEN simulator used by the BR SFN **SPI (Pix)** rail
during development. It stands in for the Central Bank counterparty so SPI services can
exercise message flows, settlement timing, and error paths without a real connection.

It simulates responses only. It proves nothing about BACEN homologation, RSFN
connectivity, ICP-Brasil certificates, or regulatory conformance.

## Not for production

The mock is unauthenticated by design and fails closed outside development-like
environments. Three layers enforce that:

1. The binary refuses to start unless `ENV_NAME` is `local`, `development`, `test`, or `ci`.
2. `values.schema.json` restricts `environment` to the same four values.
3. `templates/_helpers.tpl` calls `fail` on any other value, so the render stops before
   a manifest exists.

```sh
# both of these fail, by design
helm template mock charts/br-spi-mock-bacen --set environment=production
helm template mock charts/br-spi-mock-bacen --set environment=prd
```

`app.service.type` is restricted to `ClusterIP` for the same reason, and the chart ships
**no Ingress template at all** — there is nothing to enable.

## Endpoints

| Endpoint | Purpose | Auth |
|----------|---------|------|
| `GET /health` | Liveness probe | none |
| `GET /readyz` | Readiness and startup probe | none |
| `/control/*` | Drives the simulated BACEN behaviour (inject failures, settlement outcomes, timings) | **none — deliberately** |

`/control/*` has no authentication because the mock is a test fixture, not a service.
Anything that can reach the Service can change how the simulator responds. That is
acceptable only because the Service is cluster-internal and the chart refuses to run
anywhere near production.

## Minimum configuration

| Value | Default | Notes |
|-------|---------|-------|
| `environment` | `development` | `local`, `development`, `test`, `ci` only. Rendered as `ENV_NAME`. |
| `app.image.repository` | `ghcr.io/lerianstudio/br-spi-mock-bacen` | |
| `app.image.tag` | `""` | Falls back to `.Chart.AppVersion`. Pin it for reproducible deploys. |
| `app.configmap.MOCK_BACEN_PORT` | `":9900"` | The listener address, in the `":<port>"` form the binary expects. The container port is derived from it; a bare `"9900"` fails the render. |
| `app.service.port` | `9900` | `ClusterIP` only. |
| `app.service.targetPort` | `http` | Pinned to the named container port. A numeric value is rejected: it could diverge from the Deployment's `containerPort` and leave the Service forwarding nowhere. |

`ENV_NAME` is **reserved**: it is always rendered from `environment`, is rejected inside
`app.configmap` by the schema, and is stripped in the template. There is no way for the
public value and the container env to drift.

## Install

```sh
helm upgrade --install br-spi-mock-bacen ./charts/br-spi-mock-bacen \
  --namespace br-sfn-mock-bacen-dev-st --create-namespace \
  --set environment=development \
  --set app.image.tag=1.0.0-beta.1
```

No `helm dependency build` is needed — the chart has no dependencies.

## Access

There is no Ingress. Manual access is via port-forward:

```sh
kubectl port-forward -n br-sfn-mock-bacen-dev-st \
  svc/br-spi-mock-bacen 9900:9900
```

Then point Postman or curl at:

```text
http://127.0.0.1:9900
```

```sh
curl -s http://127.0.0.1:9900/health
curl -s http://127.0.0.1:9900/readyz
```

In-cluster clients use the Kubernetes DNS name:

```text
http://br-spi-mock-bacen.br-sfn-mock-bacen-dev-st.svc.cluster.local:9900
```

### Object names

Both examples above assume the release named `br-spi-mock-bacen` from the install
command. Object names are release-aware:

| Release | Rendered name |
|---------|---------------|
| `br-spi-mock-bacen` | `br-spi-mock-bacen` (collapsed — the release name already contains the chart name) |
| `mock` | `mock-br-spi-mock-bacen` |
| any, with `fullnameOverride=custom-mock` | `custom-mock` |

For any release name that does not contain `br-spi-mock-bacen`, substitute the rendered
name in the port-forward command and the DNS host. To read the rendered name and the
ready-made access commands back from a release:

```sh
helm get notes <release> -n <namespace>
```

`helm install` and `helm upgrade` print the same notes. `helm template` does not render
`NOTES.txt`; use `kubectl get svc -n <namespace>` if the release is not installed yet.

## Expected use by the SPI rail

In a development environment, the SPI services point their BACEN endpoint at the mock's
in-cluster DNS name instead of the RSFN counterparty. The mock accepts the rail's
messages, applies the configured settlement delay
(`app.configmap.MOCK_PIX_SETTLEMENT_DELAY_MS`), and returns simulated responses. Test
scenarios drive edge cases through `/control/*`.

## Runtime security

The Pod runs with:

- `runAsNonRoot: true`, UID/GID `65532` (matching the distroless `nonroot` user);
- `readOnlyRootFilesystem: true` and no writable volume;
- `allowPrivilegeEscalation: false` and `capabilities.drop: [ALL]`;
- `seccompProfile.type: RuntimeDefault`;
- `automountServiceAccountToken: false` on both the Pod and the ServiceAccount — the mock
  never calls the Kubernetes API.

The image is distroless, so the container runs no shell and the chart overrides no
`command` or `args`.

### Schema-enforced, not merely defaulted

The Deployment renders `podSecurityContext` and `securityContext` verbatim, so both are
**closed objects** in `values.schema.json`: a field the chart does not declare is
rejected at render time rather than passed through to the Pod.

`podSecurityContext` accepts exactly two fields:

| Field | Accepted value |
|-------|----------------|
| `runAsNonRoot` | `true` |
| `seccompProfile.type` | `RuntimeDefault` (`seccompProfile` is itself a closed object) |

`securityContext` accepts exactly these:

| Field | Accepted value |
|-------|----------------|
| `runAsNonRoot` | `true` |
| `runAsUser` | `65532` |
| `runAsGroup` | `65532` |
| `allowPrivilegeEscalation` | `false` |
| `readOnlyRootFilesystem` | `true` |
| `privileged` | `false` |
| `capabilities.drop` | an array containing `ALL` (`capabilities` is closed to `drop`) |

UID and GID are pinned to `65532` — the `nonroot` user of the published distroless image
— rather than left as a range. Everything else is rejected, including `procMount`, a
container-level `seccompProfile`, `capabilities.add`, `supplementalGroups`, `sysctls`,
and `fsGroup`. `serviceAccount.automountServiceAccountToken` must likewise be `false`.

An operator cannot weaken the baseline through values. Widening it means editing the
schema in a reviewed change, not passing a flag.

## Reserved keys

Three keys are chart-owned and cannot be set through the operator maps:

| Key | Where | Why |
|-----|-------|-----|
| `ENV_NAME` | `app.configmap` | Always rendered from `environment`; rejected by the schema and stripped in the template. |
| `app.kubernetes.io/name`, `app.kubernetes.io/instance` | `global.commonLabels`, `app` `podLabels` | They are the Deployment selector; an operator value would detach the Pods. |
| `checksum/config` | Pod-template annotations only (`podAnnotations` and `global.commonAnnotations` as they reach the Pod template) | It is the config-rollout trigger; an operator value there would suppress the rollout. The key is not filtered from object metadata (Deployment, ConfigMap, Service, ServiceAccount), where it is inert. |

Colliding entries are dropped, not merged, so no duplicate YAML key ever
reaches the API server. Precedence on a label collision is
chart-owned > `global.commonLabels` > `podLabels`; for annotations,
`podAnnotations` wins over `global.commonAnnotations`.

## Disabled render

With `app.enabled=false` the chart renders **nothing**: no Deployment, no Service, no
ConfigMap, and no ServiceAccount. The ServiceAccount is gated on `app.enabled` as well as
`serviceAccount.create` so a disabled release leaves no orphan resource behind.

## Deliberate omissions

| Not present | Why |
|-------------|-----|
| Ingress | The mock must never be publicly reachable. No template exists, so none can be enabled. |
| Secret | The mock holds no credential. |
| HPA / PDB | A single replica test fixture does not need availability guarantees. |
| Dependencies | The mock is standalone; no database, broker, or cache. |

## Schema maintenance

`values.schema.json` is hand-maintained for this chart rather than produced by
`.github/scripts/generate-values-schemas`. The generator leaves component blocks open
(`additionalProperties: true`), which cannot express this chart's security invariants:
the `environment` enum, the `ClusterIP`-only `app.service.type`, and the `ENV_NAME`
prohibition inside `app.configmap`. Update it by hand when the values contract changes.
