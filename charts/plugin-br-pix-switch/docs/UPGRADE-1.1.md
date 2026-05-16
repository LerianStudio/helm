# Helm Upgrade from v1.0.x to v1.1.x
## Topics
- **[Overview](#overview)**- **[Version changes](#version-changes)**- **[Configuration changes](#configuration-changes)**- **[Template changes](#template-changes)**- **[Migration steps](#migration-steps)**- **[Preview changes before upgrading](#preview-changes-before-upgrading)**- **[Command to upgrade](#command-to-upgrade)**

## Overview
This guide covers the `plugin-br-pix-switch` chart upgrade from `1.0.1-beta.1` to `1.1.0-beta.10`. It was generated retroactively from the chart history and focuses on minor version changes; patch-only releases are intentionally ignored.

Because this is a minor upgrade, the expected path is an in-place Helm upgrade after reviewing new values and changed defaults.

## Version changes

| Field | Previous | Current |
|-------|----------|---------|
| Chart version | `1.0.1-beta.1` | `1.1.0-beta.10` |
| App version | `1.0.0-beta.1` | `1.0.0-beta.101` |

## Configuration changes

### Added values

```yaml
adapterBtgMock.args: "[0 items]"
adapterBtgMock.autoscaling.enabled: false
adapterBtgMock.autoscaling.maxReplicas: 1
adapterBtgMock.autoscaling.minReplicas: 1
adapterBtgMock.command: "[0 items]"
adapterBtgMock.configmap.ADAPTER_ISPB: ""
adapterBtgMock.configmap.APPLICATION_NAME: "pix-adapter-btg-mock"
adapterBtgMock.configmap.COB_BASE_URL: "http://plugin-br-pix-switch-cob-hub:4108"
adapterBtgMock.configmap.DEPLOYMENT_MODE: "byoc"
adapterBtgMock.configmap.DICT_BASE_URL: "http://plugin-br-pix-switch-dict-hub:4104"
adapterBtgMock.configmap.ENV_NAME: "development"
adapterBtgMock.configmap.LOG_LEVEL: "info"
adapterBtgMock.configmap.OTEL_EXPORTER_OTLP_ENDPOINT: ""
adapterBtgMock.configmap.OTEL_LIBRARY_NAME: "github.com/LerianStudio/plugin-br-pix-switch"
adapterBtgMock.configmap.OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT: "development"
adapterBtgMock.configmap.OTEL_RESOURCE_SERVICE_NAME: "pix-adapter-btg-mock"
adapterBtgMock.configmap.PLUGIN_AUTH_ENABLED: "false"
adapterBtgMock.configmap.PLUGIN_AUTH_URL: "http://plugin-access-manager-auth.midaz-plugins.svc.cluster.local:4000"
adapterBtgMock.configmap.POLLER_INTERVAL_SEC: "30"
adapterBtgMock.configmap.PROVIDER_BASE_URL: ""
adapterBtgMock.configmap.REQUEST_TIMEOUT_SEC: "30"
adapterBtgMock.configmap.SERVER_ADDRESS: ":4103"
adapterBtgMock.configmap.SPI_BASE_URL: "http://plugin-br-pix-switch-spi:4101"
adapterBtgMock.configmap.TELEMETRY_ENABLED: "false"
adapterBtgMock.deploymentStrategy.rollingUpdate.maxSurge: 1
adapterBtgMock.deploymentStrategy.rollingUpdate.maxUnavailable: 1
adapterBtgMock.deploymentStrategy.type: "RollingUpdate"
adapterBtgMock.description: "BTG provider mock"
adapterBtgMock.enabled: false
adapterBtgMock.existingSecretName: ""
adapterBtgMock.image.pullPolicy: ""
adapterBtgMock.image.repository: "ghcr.io/lerianstudio/plugin-br-pix-switch-adapter-btg-mock-api"
adapterBtgMock.image.tag: ""
adapterBtgMock.imagePullSecrets: "[0 items]"
adapterBtgMock.ingress.enabled: false
adapterBtgMock.livenessProbe.path: "/btg-mock/health"
adapterBtgMock.name: "adapter-btg-mock"
adapterBtgMock.pdb.enabled: false
adapterBtgMock.pdb.maxUnavailable: 1
adapterBtgMock.pdb.minAvailable: 0
adapterBtgMock.readinessProbe.path: "/btg-mock/readyz"
adapterBtgMock.replicaCount: 1
adapterBtgMock.resources.limits.cpu: "200m"
adapterBtgMock.resources.limits.memory: "256Mi"
adapterBtgMock.resources.requests.cpu: "50m"
adapterBtgMock.resources.requests.memory: "64Mi"
adapterBtgMock.revisionHistoryLimit: 10
adapterBtgMock.secrets.LICENSE_KEY: ""
adapterBtgMock.secrets.PROVIDER_CLIENT_ID: ""
adapterBtgMock.secrets.PROVIDER_CLIENT_SECRET: ""
adapterBtgMock.securityContext.capabilities.drop: "[1 items]"
adapterBtgMock.securityContext.readOnlyRootFilesystem: true
adapterBtgMock.securityContext.runAsGroup: 1000
adapterBtgMock.securityContext.runAsNonRoot: true
adapterBtgMock.securityContext.runAsUser: 1000
adapterBtgMock.service.port: 4103
adapterBtgMock.service.type: "ClusterIP"
adapterBtgMock.serviceAccount.create: true
adapterBtgMock.serviceAccount.name: ""
adapterBtgMock.tolerations: "[0 items]"
adapterBtgMock.useExistingSecret: false
appsIngress.className: "nginx"
appsIngress.enabled: false
appsIngress.hosts: "[0 items]"
appsIngress.routes: "[5 items]"
appsIngress.tls: "[0 items]"
cobHub.args: "[0 items]"
cobHub.autoscaling.enabled: false
cobHub.autoscaling.maxReplicas: 3
cobHub.autoscaling.minReplicas: 1
cobHub.command: "[0 items]"
cobHub.configmap.APPLICATION_NAME: "pix-cob-hub"
cobHub.configmap.DATABASE_URL: "postgres://pixswitch:lerian@plugin-br-pix-switch-postgresql:5432/pix-cob?sslmode=disable"
cobHub.configmap.DEPLOYMENT_MODE: "byoc"
cobHub.configmap.ENV_NAME: "development"
cobHub.configmap.LICENSE_ORGANIZATION_IDS: "global"
cobHub.configmap.LOG_LEVEL: "info"
cobHub.configmap.MULTI_TENANT_ENABLED: "false"
cobHub.configmap.MULTI_TENANT_URL: ""
cobHub.configmap.ORGANIZATION_ID: ""
# ... 618 more entries
```

### Removed values

```yaml
otel-collector-lerian.enabled: true
pixSwitch.autoscaling.enabled: true
pixSwitch.autoscaling.maxReplicas: 3
pixSwitch.autoscaling.minReplicas: 1
pixSwitch.autoscaling.targetCPUUtilizationPercentage: 80
pixSwitch.autoscaling.targetMemoryUtilizationPercentage: 80
pixSwitch.configmap.DB_HOST: ""
pixSwitch.configmap.DB_NAME: "pixswitch"
pixSwitch.configmap.DB_PORT: "5432"
pixSwitch.configmap.DB_REPLICA_HOST: ""
pixSwitch.configmap.DB_REPLICA_NAME: "pixswitch"
pixSwitch.configmap.DB_REPLICA_PORT: "5432"
pixSwitch.configmap.DB_REPLICA_SSL_MODE: "disable"
pixSwitch.configmap.DB_REPLICA_USER: "pixswitch"
pixSwitch.configmap.DB_SSL_MODE: "disable"
pixSwitch.configmap.DB_USER: "pixswitch"
pixSwitch.configmap.ENABLE_TELEMETRY: "true"
pixSwitch.configmap.ENV_NAME: "development"
pixSwitch.configmap.LOG_LEVEL: "info"
pixSwitch.configmap.ORGANIZATION_IDS: "global"
pixSwitch.configmap.OTEL_EXPORTER_OTLP_ENDPOINT: "midaz-otel-lgtm:4317"
pixSwitch.configmap.OTEL_EXPORTER_OTLP_ENDPOINT_PORT: "4317"
pixSwitch.configmap.OTEL_LIBRARY_NAME: "github.com/LerianStudio/plugin-br-pix-switch"
pixSwitch.configmap.OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT: "development"
pixSwitch.configmap.OTEL_RESOURCE_SERVICE_NAME: "plugin-br-pix-switch"
pixSwitch.configmap.OTEL_RESOURCE_SERVICE_VERSION: "1.0.0-beta.1"
pixSwitch.configmap.PLUGIN_AUTH_ADDRESS: ""
pixSwitch.configmap.PLUGIN_AUTH_ENABLED: "false"
pixSwitch.configmap.PROTO_PORT: "7001"
pixSwitch.configmap.SERVER_PORT: "4000"
pixSwitch.configmap.SWAGGER_BASE_PATH: "/"
pixSwitch.configmap.SWAGGER_DESCRIPTION: "Plugin BR Pix Switch API"
pixSwitch.configmap.SWAGGER_HOST: ""
pixSwitch.configmap.SWAGGER_LEFT_DELIMITER: "{{"
pixSwitch.configmap.SWAGGER_RIGHT_DELIMITER: "}}"
pixSwitch.configmap.SWAGGER_SCHEMES: "http"
pixSwitch.configmap.SWAGGER_TITLE: "Plugin BR Pix Switch"
pixSwitch.configmap.VALKEY_HOST: ""
pixSwitch.configmap.VALKEY_PORT: "6379"
pixSwitch.configmap.VALKEY_USER: "pixswitch"
pixSwitch.configmap.VERSION: "1.0.0-beta.1"
pixSwitch.deploymentStrategy.rollingUpdate.maxSurge: 1
pixSwitch.deploymentStrategy.rollingUpdate.maxUnavailable: 1
pixSwitch.deploymentStrategy.type: "RollingUpdate"
pixSwitch.description: "Plugin BR Pix Switch for Midaz"
pixSwitch.existingSecretName: ""
pixSwitch.fullnameOverride: ""
pixSwitch.image.pullPolicy: "Always"
pixSwitch.image.repository: "ghcr.io/lerianstudio/plugin-br-pix-switch"
pixSwitch.image.tag: "1.0.0-beta.1"
pixSwitch.ingress.className: ""
pixSwitch.ingress.enabled: false
pixSwitch.ingress.hosts: "[1 items]"
pixSwitch.ingress.tls: "[0 items]"
pixSwitch.name: "plugin-br-pix-switch"
pixSwitch.nameOverride: ""
pixSwitch.pdb.enabled: true
pixSwitch.pdb.maxUnavailable: 1
pixSwitch.pdb.minAvailable: 0
pixSwitch.replicaCount: 1
pixSwitch.resources.limits.cpu: "200m"
pixSwitch.resources.limits.memory: "256Mi"
pixSwitch.resources.requests.cpu: "100m"
pixSwitch.resources.requests.memory: "128Mi"
pixSwitch.revisionHistoryLimit: 10
pixSwitch.secrets.DB_PASSWORD: ""
pixSwitch.secrets.DB_REPLICA_PASSWORD: ""
pixSwitch.secrets.LICENSE_KEY: ""
pixSwitch.secrets.VALKEY_PASSWORD: ""
pixSwitch.securityContext.capabilities.drop: "[1 items]"
pixSwitch.securityContext.readOnlyRootFilesystem: true
pixSwitch.securityContext.runAsGroup: 1000
pixSwitch.securityContext.runAsNonRoot: true
pixSwitch.securityContext.runAsUser: 1000
pixSwitch.service.grpcPort: 7001
pixSwitch.service.port: 4000
pixSwitch.service.type: "ClusterIP"
pixSwitch.tolerations: "[0 items]"
pixSwitch.useExistingSecrets: false
postgresql.auth.enabled: true
# ... 6 more entries
```

### Changed operational values

```yaml
# postgresql.enabled
#   previous: true
#   current:  false
# valkey.auth.enabled
#   previous: false
#   current:  true
# valkey.enabled
#   previous: true
#   current:  false
```

## Template changes

### Added files

- `charts/plugin-br-pix-switch/templates/_helpers.tpl`
- `charts/plugin-br-pix-switch/templates/_migrations.tpl`
- `charts/plugin-br-pix-switch/templates/adapter-btg-mock/configmap.yaml`
- `charts/plugin-br-pix-switch/templates/adapter-btg-mock/deployment.yaml`
- `charts/plugin-br-pix-switch/templates/adapter-btg-mock/hpa.yaml`
- `charts/plugin-br-pix-switch/templates/adapter-btg-mock/ingress.yaml`
- `charts/plugin-br-pix-switch/templates/adapter-btg-mock/pdb.yaml`
- `charts/plugin-br-pix-switch/templates/adapter-btg-mock/secrets.yaml`
- `charts/plugin-br-pix-switch/templates/adapter-btg-mock/service.yaml`
- `charts/plugin-br-pix-switch/templates/adapter-btg-mock/serviceaccount.yaml`
- `charts/plugin-br-pix-switch/templates/bootstrap-mongodb.yaml`
- `charts/plugin-br-pix-switch/templates/bootstrap-postgres.yaml`
- `charts/plugin-br-pix-switch/templates/cob-hub/configmap.yaml`
- `charts/plugin-br-pix-switch/templates/cob-hub/deployment.yaml`
- `charts/plugin-br-pix-switch/templates/cob-hub/hpa.yaml`
- `charts/plugin-br-pix-switch/templates/cob-hub/migrations-job.yaml`
- `charts/plugin-br-pix-switch/templates/cob-hub/pdb.yaml`
- `charts/plugin-br-pix-switch/templates/cob-hub/secrets.yaml`
- `charts/plugin-br-pix-switch/templates/cob-hub/service.yaml`
- `charts/plugin-br-pix-switch/templates/cob-hub/serviceaccount.yaml`
- `charts/plugin-br-pix-switch/templates/cob-proxy/configmap.yaml`
- `charts/plugin-br-pix-switch/templates/cob-proxy/deployment.yaml`
- `charts/plugin-br-pix-switch/templates/cob-proxy/hpa.yaml`
- `charts/plugin-br-pix-switch/templates/cob-proxy/pdb.yaml`
- `charts/plugin-br-pix-switch/templates/cob-proxy/secrets.yaml`
- `charts/plugin-br-pix-switch/templates/cob-proxy/service.yaml`
- `charts/plugin-br-pix-switch/templates/cob-proxy/serviceaccount.yaml`
- `charts/plugin-br-pix-switch/templates/cob-systemplane/configmap.yaml`
- `charts/plugin-br-pix-switch/templates/cob-systemplane/deployment.yaml`
- `charts/plugin-br-pix-switch/templates/cob-systemplane/hpa.yaml`
- `charts/plugin-br-pix-switch/templates/cob-systemplane/pdb.yaml`
- `charts/plugin-br-pix-switch/templates/cob-systemplane/secrets.yaml`
- `charts/plugin-br-pix-switch/templates/cob-systemplane/service.yaml`
- `charts/plugin-br-pix-switch/templates/cob-systemplane/serviceaccount.yaml`
- `charts/plugin-br-pix-switch/templates/dict-hub-vsync/configmap.yaml`
- `charts/plugin-br-pix-switch/templates/dict-hub-vsync/deployment.yaml`
- `charts/plugin-br-pix-switch/templates/dict-hub-vsync/hpa.yaml`
- `charts/plugin-br-pix-switch/templates/dict-hub-vsync/pdb.yaml`
- `charts/plugin-br-pix-switch/templates/dict-hub-vsync/secrets.yaml`
- `charts/plugin-br-pix-switch/templates/dict-hub-vsync/service.yaml`
- `charts/plugin-br-pix-switch/templates/dict-hub-vsync/serviceaccount.yaml`
- `charts/plugin-br-pix-switch/templates/dict-hub/configmap.yaml`
- `charts/plugin-br-pix-switch/templates/dict-hub/deployment.yaml`
- `charts/plugin-br-pix-switch/templates/dict-hub/hpa.yaml`
- `charts/plugin-br-pix-switch/templates/dict-hub/migrations-job.yaml`
- `charts/plugin-br-pix-switch/templates/dict-hub/pdb.yaml`
- `charts/plugin-br-pix-switch/templates/dict-hub/secrets.yaml`
- `charts/plugin-br-pix-switch/templates/dict-hub/service.yaml`
- `charts/plugin-br-pix-switch/templates/dict-hub/serviceaccount.yaml`
- `charts/plugin-br-pix-switch/templates/dict-proxy/configmap.yaml`
- `charts/plugin-br-pix-switch/templates/dict-proxy/deployment.yaml`
- `charts/plugin-br-pix-switch/templates/dict-proxy/hpa.yaml`
- `charts/plugin-br-pix-switch/templates/dict-proxy/pdb.yaml`
- `charts/plugin-br-pix-switch/templates/dict-proxy/secrets.yaml`
- `charts/plugin-br-pix-switch/templates/dict-proxy/service.yaml`
- `charts/plugin-br-pix-switch/templates/dict-proxy/serviceaccount.yaml`
- `charts/plugin-br-pix-switch/templates/dict-systemplane/configmap.yaml`
- `charts/plugin-br-pix-switch/templates/dict-systemplane/deployment.yaml`
- `charts/plugin-br-pix-switch/templates/dict-systemplane/hpa.yaml`
- `charts/plugin-br-pix-switch/templates/dict-systemplane/pdb.yaml`
- `charts/plugin-br-pix-switch/templates/dict-systemplane/secrets.yaml`
- `charts/plugin-br-pix-switch/templates/dict-systemplane/service.yaml`
- `charts/plugin-br-pix-switch/templates/dict-systemplane/serviceaccount.yaml`
- `charts/plugin-br-pix-switch/templates/ingress-apps.yaml`
- `charts/plugin-br-pix-switch/templates/ingress-providers.yaml`
- `charts/plugin-br-pix-switch/templates/ingress-systemplane.yaml`
- `charts/plugin-br-pix-switch/templates/spi-systemplane/configmap.yaml`
- `charts/plugin-br-pix-switch/templates/spi-systemplane/deployment.yaml`
- `charts/plugin-br-pix-switch/templates/spi-systemplane/hpa.yaml`
- `charts/plugin-br-pix-switch/templates/spi-systemplane/pdb.yaml`
- `charts/plugin-br-pix-switch/templates/spi-systemplane/secrets.yaml`
- `charts/plugin-br-pix-switch/templates/spi-systemplane/service.yaml`
- `charts/plugin-br-pix-switch/templates/spi-systemplane/serviceaccount.yaml`
- `charts/plugin-br-pix-switch/templates/spi/configmap.yaml`
- `charts/plugin-br-pix-switch/templates/spi/deployment.yaml`
- `charts/plugin-br-pix-switch/templates/spi/hpa.yaml`
- `charts/plugin-br-pix-switch/templates/spi/migrations-job.yaml`
- `charts/plugin-br-pix-switch/templates/spi/pdb.yaml`
- `charts/plugin-br-pix-switch/templates/spi/secrets.yaml`
- `charts/plugin-br-pix-switch/templates/spi/service.yaml`
- ... 1 more

### Removed files

- `charts/plugin-br-pix-switch/templates/helpers.tpl`
- `charts/plugin-br-pix-switch/templates/plugin-br-pix-switch/configmap.yaml`
- `charts/plugin-br-pix-switch/templates/plugin-br-pix-switch/deployment.yaml`
- `charts/plugin-br-pix-switch/templates/plugin-br-pix-switch/hpa.yaml`
- `charts/plugin-br-pix-switch/templates/plugin-br-pix-switch/ingress.yaml`
- `charts/plugin-br-pix-switch/templates/plugin-br-pix-switch/pdb.yaml`
- `charts/plugin-br-pix-switch/templates/plugin-br-pix-switch/secrets.yaml`
- `charts/plugin-br-pix-switch/templates/plugin-br-pix-switch/service.yaml`

### Modified files

- `charts/plugin-br-pix-switch/CHANGELOG.md`
- `charts/plugin-br-pix-switch/Chart.yaml`
- `charts/plugin-br-pix-switch/README.md`
- `charts/plugin-br-pix-switch/templates/NOTES.txt`
- `charts/plugin-br-pix-switch/values-template.yaml`
- `charts/plugin-br-pix-switch/values.yaml`

## Migration steps

1. Read this guide and compare your custom values against `charts/plugin-br-pix-switch/values.yaml`.
2. Remove values that no longer exist in the chart before running the upgrade.
3. Add any required new values for your environment, especially secrets, configmaps, probes, ingress, and service settings.
4. Render the chart locally with your production values and review the manifest diff.
5. Apply the upgrade in a controlled environment before production.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-switch ./charts/plugin-br-pix-switch \
  --namespace <namespace> \
  --values <your-values.yaml>
```

## Command to upgrade

```bash
helm upgrade plugin-br-pix-switch ./charts/plugin-br-pix-switch \
  --namespace <namespace> \
  --values <your-values.yaml>
```
