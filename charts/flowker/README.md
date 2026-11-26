# Flowker Helm Chart

## Chart Contract

- Chart type: `multi-component`
- Required secrets: `flowker.secrets.LICENSE_KEY`, or `flowker.licenseFile.existingSecret` on a lib-license-go v5 image (flowker >= 1.6 does not boot without a license). With the bundled MongoDB subchart, `MONGO_URI` is assembled automatically from the subchart-generated Secret; supply `flowker.secrets.MONGO_URI` only when pointing at external MongoDB.
- Dependency notes: Bundles the Bitnami MongoDB subchart unless external MongoDB is configured. MongoDB credentials are single-sourced from the subchart Secret (`mongodb-root-password`) — operators do not supply them for the bundled instance.
- Production overrides: Provide production database credentials through chart secrets or an existing Secret where supported; override image tags, ingress, resources, and dependency persistence for the target environment.
- Source/license: Chart is maintained in `github.com/LerianStudio/helm` (`charts/flowker`); the Flowker application source is in `github.com/LerianStudio/flowker`.

A Helm chart for deploying Flowker - Workflow orchestration platform for financial validation.

## Components

The chart renders these workloads (all are toggleable; the api via `flowker.enabled`):

| Component | Toggle | Default | Description |
|-----------|--------|---------|-------------|
| api | `flowker.enabled` | on | The Flowker HTTP API Deployment (port 4021). |
| worker | `worker.enabled` | on | A second Deployment running the `/worker` binary from the same flowker image: the queue-backed scheduler consume server and background jobs (single replica, no HPA). |
| xsd-validator sidecar | `flowker.xsdValidator.enabled` | on | In-pod XML/XSD validation sidecar (port 8081) injected into the api and worker pods; reached over loopback. |
| valkey | `valkey.enabled` | off | Bundled Redis-compatible store backing the scheduler queue. When off, set `flowker.configmap.REDIS_HOST` to an external Redis. |
| aws-signing-helper sidecar | `aws.rolesAnywhere.enabled` | off | IAM Roles Anywhere credential sidecar for non-EKS clusters. On EKS use IRSA via `flowker.serviceAccount.annotations` instead. |

> The worker and XSD sidecar require an app image that bundles the `/worker` binary and a published `flowker-xsd-validator` sidecar image (>= `1.3.0`).
>
> The worker and XSD sidecar are also gated on `flowker.enabled` — setting `flowker.enabled=false` disables them regardless of their own toggle.

## Prerequisites

- Kubernetes 1.27+ (`Chart.yaml` `kubeVersion`; the health preset's PDB uses `unhealthyPodEvictionPolicy`)
- Helm 3.2.0+
- MongoDB database (bundled or external)

## Installation

For a step-by-step installation (quickstart, production), validation and known errors, see the getting-started runbook: [English](docs/00-getting-start.en.md) · [Português](docs/00-getting-start.md).

Install from the public OCI registry (no login needed):

```bash
helm install flowker oci://ghcr.io/lerianstudio/flowker-helm \
  --version <chart-version> -n flowker --create-namespace
```

Or from a local checkout of this repository:

```bash
helm install flowker ./charts/flowker -n flowker --create-namespace
```

## Configuration

### Namespace Override

By default, resources are deployed to the `flowker` namespace. Override with:

```bash
helm install flowker ./charts/flowker --set namespaceOverride=custom-namespace -n custom-namespace
```

### MongoDB

The chart includes a MongoDB subchart (Bitnami) enabled by default. To use an external MongoDB instance, disable the bundled one:

```yaml
mongodb:
  enabled: false

flowker:
  secrets:
    MONGO_URI: "mongodb://user:password@your-mongo-host:27017/flowker?authSource=admin"
```

### Licence file

`flowker.licenseFile.existingSecret` names a Secret holding the signed licence file under key `license.lic`. It is mounted as a directory at `/etc/lerian/license` on the api and the worker, and `LICENSE_FILE_PATH` points at the file, so `LICENSE_KEY` becomes optional. File mode needs an image on lib-license-go v5. `LICENSE_KEY` itself is not chart-managed: supply it in the Secret named by `flowker.existingSecretName`, which the api and worker both load whole.

### Existing Secrets

To use an existing Kubernetes secret instead of the chart-managed one:

```yaml
flowker:
  useExistingSecret: true
  existingSecretName: "my-flowker-secret"
```

The secret must contain the keys defined in `flowker.secrets` (e.g., `MONGO_URI`, `LICENSE_KEY`, and `IDP_M2M_CLIENT_ID`/`IDP_M2M_CLIENT_SECRET` when the RI declaration is enabled).

### Access Manager permission declaration (RI)

The API binary publishes its embedded `permissions.yaml` to the Access Manager at boot (lib-auth `declaration.WireFromEnv`). The worker never publishes. It is off by default:

```yaml
flowker:
  configmap:
    PLUGIN_AUTH_ENABLED: "true"
    PLUGIN_AUTH_ADDRESS: "http://plugin-access-manager-auth:4000"
    IDP_DECLARATION_ENABLED: "true"
    IDP_HOST: "https://identity.example.com"
  secrets:
    IDP_M2M_CLIENT_ID: "<client-id>"
    IDP_M2M_CLIENT_SECRET: "<client-secret>"
  xsdValidator:
    pluginAuth:
      # The XSD sidecar inherits PLUGIN_AUTH_* and refuses a cleartext http://
      # address unless acknowledged. The chart fails at render without this.
      allowInsecureHttp: "true"
```

- `IDP_DECLARATION_ENABLED` is always rendered in the ConfigMap (default `"false"`); `IDP_HOST` only when non-empty.
- `IDP_M2M_CLIENT_ID` / `IDP_M2M_CLIENT_SECRET` go to the chart Secret only when set. With `useExistingSecret: true`, put them in the existing Secret.
- A value for `IDP_DECLARATION_ENABLED` or `IDP_HOST` in `flowker.extraEnvVars` still wins over `flowker.configmap` (legacy path), and is not emitted twice.

## Health, drain and rollout

Probes, grace, the rollout strategy, the PDB and the drain env come from the `lerian-common` health preset and are not values.

- `startupProbe` and `livenessProbe`: `GET /health` on the internal `health` port `8099` (`HEALTH_PORT`), process only. `readinessProbe`: `GET /readyz` on the same port. `/metrics` is served there too; the main port keeps `/health` and `/version`.
- Port `8099` is an internal ClusterIP Service port (`health`), never an Ingress backend. On `className: alb` the target-group health check is `/health` on the main port and wins over `flowker.ingress.annotations`.
- The api runs 2 replicas, rolls with `maxSurge 25%` and `maxUnavailable 0`, and has a PDB (`maxUnavailable 1`, `unhealthyPodEvictionPolicy AlwaysAllow`, Kubernetes 1.27 or later).
- The worker is a singleton (1 replica, `Recreate`, no PDB, no HPA) with no drain.
- The chart refuses an `image.tag` below `1.7.0-beta.50`; the image and the chart move together, and a rollback moves both. It also refuses `flowker.readinessProbe`, `flowker.livenessProbe`, `flowker.deploymentUpdate`, `flowker.pdb.enabled|minAvailable|maxUnavailable`, `worker.readinessProbe`, `worker.livenessProbe`, `worker.deploymentStrategy`, `worker.terminationGracePeriodSeconds` and `SHUTDOWN_DRAIN_DELAY`, `SHUTDOWN_TIMEOUT` or `HEALTH_PORT` in a ConfigMap.

## Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespaceOverride` | Override the namespace for all resources | `flowker` |
| `flowker.enabled` | Enable flowker deployment | `true` |
| `flowker.replicaCount` | Number of api replicas (the worker is a fixed singleton) | `2` |
| `flowker.image.repository` | Image repository | `ghcr.io/lerianstudio/flowker` |
| `flowker.image.tag` | Image tag (must bundle `/worker`, >= `1.3.0`; older images read `SCHEDULER_REDIS_*`, which this chart no longer emits). The chart refuses a tag below `1.7.0-beta.50`, the first image that serves the health port | `1.7.0` |
| `flowker.service.port` | Service port | `4021` |
| `flowker.ingress.enabled` | Enable ingress | `false` |
| `flowker.autoscaling.enabled` | Enable HPA | `true` |
| `flowker.pdb.annotations` | PodDisruptionBudget annotations (the PDB itself is rendered by the health preset) | `{}` |
| `flowker.health.drainSeconds` | `SHUTDOWN_DRAIN_DELAY`: listeners keep serving this long after SIGTERM | `15` |
| `flowker.health.shutdownSeconds` | `SHUTDOWN_TIMEOUT`: total shutdown budget; grace = drain + shutdown + 10 | `30` |
| `worker.health.shutdownSeconds` | Worker `SHUTDOWN_TIMEOUT` (no drain: no Service routes to the worker); grace = shutdown + 10 | `30` |
| `flowker.useExistingSecret` | Use an existing secret | `false` |
| `flowker.existingSecretName` | Name of the existing secret | `""` |
| `flowker.workosTmEnabled` | Enable WorkOS Tenant Manager token mint (all-or-none) | `false` |
| `flowker.xsdValidator.enabled` | Inject the in-pod XSD validator sidecar | `true` |
| `worker.enabled` | Deploy the scheduler worker Deployment | `true` |
| `valkey.enabled` | Bundle valkey as the scheduler queue Redis | `false` |
| `aws.rolesAnywhere.enabled` | Inject the IAM Roles Anywhere signing sidecar | `false` |
| `mongodb.enabled` | Enable bundled MongoDB subchart | `true` |

For full configuration options, see [values.yaml](values.yaml).
