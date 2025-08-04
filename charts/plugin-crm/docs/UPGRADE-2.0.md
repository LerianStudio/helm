# Helm Upgrade from v1.x to v2.x

# Topics  

- ***[Breaking Changes](#breaking-changes)***
    - [1. License Key](#1-license-key)
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
crm:
    secrets:
        LICENSE_KEY: <your-license-key>
        ORGANIZATION_ID: <your-organization-id>
```
***Note:*** See the [crm secrets](https://github.com/LerianStudio/helm/blob/main/charts/plugin-crm/templates/crm/secrets.yaml) templates for more details.

# Additions

### 1. Plugin UI

Now you can enable the plugin-frontend to access the user interface.

```yaml
frontend:
    enabled: true
    configmap:
        NEXT_PUBLIC_MIDAZ_CONSOLE_BASE_URL: "http://midaz-nginx.midaz.svc.cluster.local.:8080" # @default -- "http://midaz-nginx.midaz.svc.cluster.local.:8080" if ingress is enabled set the ingress.hostname value
```
To access the plugin UI you need to enable this plugin in midaz-console [values.yaml](https://github.com/LerianStudio/helm/blob/main/charts/plugin-crm/values.yaml) and access midaz-console UI.

```yaml
console:
    plugins:
        enabled: true
        plugins:
            - name: "plugin-crm"
              port: 8082
              enabled: true
```

***Note:*** See the [plugins section in values.yaml](https://github.com/LerianStudio/helm/blob/main/charts/plugin-crm/values.yaml) for get the secrets names.

### 2. External Secrets Support

Now you can use external secrets to store the license key and organization id.

```yaml
crm:
    useExistingSecret: true
    existingSecretName: <your-secret-name>
```
***Note:*** See the [secrets template](https://github.com/LerianStudio/helm/blob/main/charts/plugin-crm/templates/crm/secrets.yaml) for get the secrets keys.

# Command to upgrade

```bash
$ helm upgrade plugin-crm oci://registry-1.docker.io/lerianstudio/plugin-crm --version 2.0.0 -n midaz-plugins
```
