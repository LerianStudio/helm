# Plugin BR Pix Switch Helm Chart

Helm chart for deploying the Plugin BR Pix Switch service on Kubernetes.

## Overview

This chart deploys a single Go microservice for PIX switching operations, along with its dependencies:

- **Plugin BR Pix Switch** - Main API service (HTTP port 4000, gRPC port 7001)
- **PostgreSQL** - Primary database (Bitnami subchart)
- **Valkey** - Redis-compatible cache (Bitnami subchart)
- **OpenTelemetry Collector** - Observability (Lerian subchart)

## Prerequisites

- Kubernetes 1.19+
- Helm 3.x

## Installation

```bash
# Add dependencies
helm dependency build

# Install the chart
helm install plugin-br-pix-switch . -n midaz-plugins --create-namespace
```

## Configuration

### Key Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `pixSwitch.image.repository` | Container image repository | `ghcr.io/lerianstudio/plugin-br-pix-switch` |
| `pixSwitch.image.tag` | Container image tag | `1.8.0-beta.2` |
| `pixSwitch.service.port` | HTTP service port | `4000` |
| `pixSwitch.service.grpcPort` | gRPC service port | `7001` |
| `pixSwitch.replicaCount` | Number of replicas | `1` |
| `pixSwitch.autoscaling.enabled` | Enable HPA | `true` |
| `pixSwitch.ingress.enabled` | Enable ingress | `false` |
| `postgresql.enabled` | Enable PostgreSQL subchart | `true` |
| `valkey.enabled` | Enable Valkey subchart | `true` |

### Health Endpoints

The service exposes the following health endpoints:

- `/health` - General health check
- `/ready` - Readiness probe (used by Kubernetes)
- `/live` - Liveness probe (used by Kubernetes)

### Using External Database

To use an external PostgreSQL database instead of the bundled subchart:

```yaml
postgresql:
  enabled: false

pixSwitch:
  configmap:
    DB_HOST: "your-external-db-host"
    DB_USER: "your-db-user"
    DB_NAME: "your-db-name"
    DB_PORT: "5432"
  secrets:
    DB_PASSWORD: "your-db-password"
```

### Using External Cache

To use an external Redis/Valkey instance:

```yaml
valkey:
  enabled: false

pixSwitch:
  configmap:
    VALKEY_HOST: "your-external-cache-host"
    VALKEY_PORT: "6379"
  secrets:
    VALKEY_PASSWORD: "your-cache-password"
```

## Production Notes

- The bundled PostgreSQL and Valkey subcharts are intended for **development only**
- For production, use managed database and cache services
- Configure `pixSwitch.useExistingSecrets: true` to use pre-existing Kubernetes secrets
- Enable ingress and TLS for external access
