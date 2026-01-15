# Product Console Helm Chart

A Helm chart for deploying Product Console - Lerian Studio's web interface for managing Midaz ledger.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+

## Installing the Chart

To install the chart with the release name `product-console`:

```bash
helm repo add lerianstudio https://charts.lerian.studio
helm install product-console lerianstudio/product-console-helm
```

## Configuration

See [values.yaml](values.yaml) for the full list of configuration options.

### Quick Start

Copy `values-template.yaml` and customize it for your deployment:

```bash
cp values-template.yaml my-values.yaml
# Edit my-values.yaml with your configuration
helm install product-console lerianstudio/product-console-helm -f my-values.yaml
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
| `secrets.NEXTAUTH_SECRET` | NextAuth secret | `change-me-in-production` |

## Uninstalling the Chart

```bash
helm uninstall product-console
```
