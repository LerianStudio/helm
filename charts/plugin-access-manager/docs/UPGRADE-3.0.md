# Helm Upgrade from v2.x to v3.x

## Breaking Changes


### 1. License Key

The plugin now requires a license key to be started successfully.

You must provide it in the values.yaml file or as a [external secrets](#1-external-secrets-support).

This change affects the following components:

```yaml
auth:
    secrets:
        LICENSE_KEY: <your-license-key>
        ORGANIZATION_ID: <your-organization-id>
```

```yaml
identity:
    secrets:
        LICENSE_KEY: <your-license-key>
        ORGANIZATION_ID: <your-organization-id>
```
***Note:*** See the [auth secrets](https://github.com/LerianStudio/helm/blob/main/charts/plugin-access-manager/templates/auth/secrets.yaml) and [identity secrets](https://github.com/LerianStudio/helm/blob/main/charts/plugin-access-manager/templates/identity/secrets.yaml) templates for more details.

### 2. Consolidation of REDIS_PORT into REDIS_HOST

The REDIS_PORT environment variable has been removed. Its value must now be included directly in the REDIS_HOST variable as <host>:<port>. For example:

This change affects the following components:
- `auth`

#### Old configuration
```yaml
    REDIS_HOST=redis_host
    REDIS_PORT=redis_port 
```

#### New configuration
```yaml
    REDIS_HOST=redis_host:redis_port
```

***Note:*** See the [auth configmap](https://github.com/LerianStudio/helm/blob/main/charts/plugin-access-manager/templates/auth/configmap.yaml) template for more details.


⚠️ Make sure to remove REDIS_PORT from your environment and update REDIS_HOST accordingly to avoid connectivity issues.


## Additions

### 1. External Secrets Support

Now you can use external secrets to store sensitive data.

```yaml
auth:
    useExistingSecrets: true
    existingSecretName: <existing-secret-name>
```

***Note:*** See the [auth secrets template](https://github.com/LerianStudio/helm/blob/189e1124d61a03bd72a958aba923453039b3f409/charts/plugin-access-manager/templates/auth/secrets.yaml) for get the secrets names.

```yaml
identity:
    useExistingSecrets: true
    existingSecretName: <existing-secret-name>
```

***Note:*** See the [identity secrets template](https://github.com/LerianStudio/helm/blob/189e1124d61a03bd72a958aba923453039b3f409/charts/plugin-access-manager/templates/identity/secrets.yaml) for get the secrets names.

## Command to upgrade

```bash
$ helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 3.0.0 -n midaz-plugins
```
