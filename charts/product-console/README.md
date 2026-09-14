# Product Console Helm Chart

## Chart Contract

- Chart type: `single-service`
- Required secrets: None for default render.
- Dependency notes: Uses a local MongoDB dependency chart unless external MongoDB is configured.
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

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Container image repository | `lerianstudio/product-console` |
| `image.tag` | Container image tag | Chart appVersion |
| `ingress.enabled` | Enable ingress | `false` |
| `configmap.NODE_ENV` | Node environment | `production` |
| `configmap.MIDAZ_CONSOLE_PORT` | Console port | `8081` |
| `configmap.MIDAZ_BASE_PATH` | Midaz API base path | `http://midaz-onboarding:3000/v1` |
| `configmap.TRUSTED_PROXIES` | Comma-separated CIDRs of the proxies in front of the console. Empty means no caller is named and the tenant IP allowlist is not enforceable. See [Trusted proxies](#trusted-proxies) | `""` |
| `secrets.NEXTAUTH_SECRET` | NextAuth secret (must be supplied for production) | `""` |

### Trusted proxies

`configmap.TRUSTED_PROXIES` is the list of CIDRs the console treats as its own
infrastructure when it reads `X-Forwarded-For`. The console walks that header
from right to left, discards every hop inside these ranges, and calls the first
hop outside them the caller.

Set it per environment, in that environment's gitops repo, to the ranges
requests actually arrive from: the ingress controller's pod or service CIDR,
plus any load balancer in front of it that appends to the header.

Neither way of getting it wrong stops the deployment. Both degrade at request
time instead:

- **Left empty** (the default), no forwarding header is believed at all. The
  tenant IP allowlist screen reports the caller as `unknown`, an allowlist built
  from that screen is unusable, and every call the console makes to a Lerian
  backend carries `X-Client-Ip-Resolution: unresolved`, so nothing upstream can
  restrict or meter by caller either.
- **Too broad**, an entry wider than `/8` (IPv4) or `/48` (IPv6) is dropped, as
  is an entry that is not a CIDR (a single host still has to be written `/32` or
  `/128`). Dropped entries are reported in the console's own logs, and a list
  whose entries all drop behaves exactly like an empty one.

```yaml
configmap:
  TRUSTED_PROXIES: '10.42.0.0/16,192.168.0.0/16'
```

Set more than one range from a values file, as above. Helm's `--set` splits on
commas, so passing several ranges that way fails with `key "0/16" has no value`;
escape them (`--set-string configmap.TRUSTED_PROXIES='10.42.0.0/16\,192.168.0.0/16'`)
if you must use a flag.

## Uninstalling the Chart

```bash
helm uninstall product-console
```
