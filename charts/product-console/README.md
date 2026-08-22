# Product Console Helm Chart

## Chart Contract

- Chart type: `single-service`
- Required secrets: None for default render.
- Dependency notes: Uses a local MongoDB dependency chart unless external MongoDB is configured. Also depends on `lerian-common-helm` (shared library chart) for the HPA/PDB/Service/Ingress templates and the `global.*` config masks below.
- Production overrides: Provide production MongoDB credentials through chart secrets or dependency Secret settings; override image tags, ingress, resources, namespace, and persistence.
- Source/license: Source is in `github.com/LerianStudio/helm`; license is Apache-2.0.

A Helm chart for deploying Product Console - Lerian Studio's web interface for managing Midaz ledger.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.8.0+ (OCI registry support is enabled by default)

## Installing the Chart

To install the chart with the release name `product-console`:

```bash
helm install product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version <version> -n midaz --create-namespace
```

## Configuration

See [values.yaml](values.yaml) for the full list of configuration options.

### Quick Start

Copy `values-template.yaml` and customize it for your deployment:

```bash
cp values-template.yaml my-values.yaml
# Edit my-values.yaml with your configuration
helm install product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version <version> -f my-values.yaml -n midaz --create-namespace
```

### Key Configuration Options

Every `configmap.<KEY>` and its shipped default are declared in
`templates/configmap.yaml` (`values.yaml`'s `configmap:` map is intentionally
empty — set a key there only to override its shipped default).

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Container image repository | `lerianstudio/product-console` |
| `image.tag` | Container image tag | Chart appVersion |
| `ingress.enabled` | Enable ingress | `false` |
| `configmap.NODE_ENV` | Node environment | `production` |
| `configmap.MIDAZ_CONSOLE_PORT` | Console port | `8081` |
| `configmap.MIDAZ_BASE_PATH` | Midaz API base path | `http://midaz-ledger.midaz.svc.cluster.local:3002/v1` |
| `configmap.NEXTAUTH_URL` | Public URL NextAuth uses for OAuth callbacks | `ingress.hosts[0].host` (as `https://<host>`) when ingress is enabled with a host, else `http://localhost:8081` |
| `secrets.NEXTAUTH_SECRET` | NextAuth secret (must be supplied for production) | `""` |
| `secrets.PLUGIN_AUTH_CLIENT_ID` | Alternative to `configmap.PLUGIN_AUTH_CLIENT_ID` when the client_id shouldn't sit in a ConfigMap; when set, the ConfigMap key is omitted | `""` |

### Inter-service defaults (cross-namespace)

Product Console talks to several sibling Lerian services (Midaz ledger,
plugin-access-manager, CRM, Reporter). By default these are addressed by the
standard in-cluster FQDN (`<service>.<namespace>.svc.cluster.local`), so the
chart works out of the box even when each dependency is deployed in its own
namespace — no service mesh or DNS wiring required. Override the
corresponding `configmap.<KEY>` if your environment uses different
service/namespace names.

| Service | `configmap` keys | Default host |
|---|---|---|
| Midaz ledger | `MIDAZ_API_HOST`, `MIDAZ_TRANSACTION_BASE_HOST` (+ `*_PORT`/`*_PATH`) | `midaz-ledger.midaz.svc.cluster.local` |
| plugin-access-manager (auth) | `PLUGIN_AUTH_HOST` (+ `PLUGIN_AUTH_PORT`/`PLUGIN_AUTH_BASE_PATH`) | `plugin-access-manager-auth.plugin-access-manager.svc.cluster.local` |
| plugin-access-manager (identity) | `PLUGIN_IDENTITY_HOST` (+ `PLUGIN_IDENTITY_PORT`/`PLUGIN_IDENTITY_BASE_PATH`) | `plugin-access-manager-identity.plugin-access-manager.svc.cluster.local` |
| CRM plugin | `CRM_BASE_PATH` | `http://midaz-crm.midaz.svc.cluster.local:4003/v1/` |
| Reporter | `REPORTER_BASE_PATH` | `http://reporter-manager.reporter.svc.cluster.local:4005/v1` |

### Managed Cloud (`global.cloud`)

These fields are consumed by `lerian-common` and let an operator set a value
ONCE per environment for every chart that shares it, instead of pinning it
per-component. A native `configmap.<KEY>` (see table above / `values.yaml`)
always wins over the corresponding mask.

| `global.*` field | Consumed by | Overriding native key(s) |
|---|---|---|
| `global.auth.enabled` / `global.auth.host` | `lerian-common.auth.env` | `configmap.PLUGIN_AUTH_ENABLED` / `configmap.PLUGIN_AUTH_HOST` |
| `global.observability.enabled` | `lerian-common.globalValue` | `configmap.ENABLE_TELEMETRY` |
| `global.datastores.mongo.{uri,host,port,user,params}` | `lerian-common.datastore.value` | `configmap.MONGODB_URI` / `MONGO_HOST` / `MONGO_PORT` / `MONGODB_USER` / `MONGO_PARAMETERS` |

`global.cloud: aws` also applies automatically (no chart change needed): it
sets `MONGO_PARAMETERS` to the real DocumentDB connection-string shape
(`tls=true&tlsInsecure=true&directConnection=true&retryWrites=false&...`)
whenever no more specific override (native key or `global.datastores.mongo.params`)
is set. `gcp`/`azure` have no Mongo preset today.

## Uninstalling the Chart

```bash
helm uninstall product-console
```
