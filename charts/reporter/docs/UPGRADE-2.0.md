# Helm Upgrade from v1.x to v2.x

# Topics  

- ***[Breaking Changes](#breaking-changes)***
    - [1. License Key](#1-license-key)
    - [2. Redis Configuration](#2-redis-configuration)
- ***[Additions](#additions)***
    - [1. Plugin UI](#1-plugin-ui)
    - [2. External Secrets Support](#2-external-secrets-support)
- ***[Command to upgrade](#command-to-upgrade)***

# Breaking Changes

### 1. License Key

The plugin now requires a license key to be started successfully.

You must provide it in the values.yaml file or as a [external secrets](#2-external-secrets-support).

This change affects the following components:

```yaml
fees:
    secrets:
        LICENSE_KEY: <your-license-key>
        ORGANIZATION_ID: <your-organization-id>
```

***Note:*** See the [fees secrets](https://github.com/LerianStudio/helm/blob/main/charts/plugin-fees/templates/fees/secrets.yaml) templates for more details.

### 2. Redis Configuration

The plugin now requires a redis configuration to be started successfully.

You must provide it in the values.yaml file or as a [external secrets](#2-external-secrets-support).

This change affects the following components:

```yaml
common:
    configmap:
        # Redis Configs
        REDIS_MASTER_NAME: ""
        REDIS_HOST: reporter-valkey-primary.reporter.svc.cluster.local
        REDIS_PORT: 6379
        REDIS_DB: 0
        REDIS_PROTOCOL: "3"
        REDIS_TLS: "false"
        REDIS_CA_CERT: ""
        GOOGLE_APPLICATION_CREDENTIALS: ""
        REDIS_SERVICE_ACCOUNT: ""
```

***Note:*** See the [common configmap section in values.yaml](https://github.com/LerianStudio/helm/blob/main/charts/reporter/values.yaml) templates for more details.

# Additions

### 1. Plugin UI

Now you can enable the plugin-frontend to access the user interface.

```yaml
frontend:
    enabled: true
    configmap:
        NEXT_PUBLIC_MIDAZ_CONSOLE_BASE_URL: "http://midaz-nginx.midaz.svc.cluster.local.:8080" # @default -- "http://midaz-nginx.midaz.svc.cluster.local.:8080" if ingress is enabled set the ingress.hostname value
```
To access the plugin UI you need to enable this plugin in midaz-console [values.yaml](https://github.com/LerianStudio/helm/blob/main/charts/midaz/values.yaml) and access midaz-console UI.

```yaml
console:
    plugins:
        enabled: true
        plugins:
            - name: "plugin-fees"
              port: 8084
              enabled: true
```

***Note:*** See the [plugins section in values.yaml](https://github.com/LerianStudio/helm/blob/main/charts/plugin-fees/values.yaml) for get the secrets names.

### 2. External Secrets Support

Now you can use external secrets to store the license key and organization id.

```yaml
manager:
    useExistingSecret: true
    existingSecretName: <your-secret-name>
```
***Note:*** See the [secrets section in values.yaml](https://github.com/LerianStudio/helm/blob/main/charts/reporter/values.yaml) for get the secrets keys.

# Command to upgrade

```bash
$ helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter --version 2.0.0 -n midaz-plugins
```
