# Helm Upgrade from v2.x to v3.x

# Topics  

- ***[Breaking Changes](#breaking-changes)***
    - [1. License Key](#1-license-key)
- ***[Additions](#additions)***
    - [1. External Secrets Support](#1-external-secrets-support)
    - [2. Redis Configuration for Auth Service](#2-redis-configuration-for-auth-service)
- ***[Command to upgrade](#command-to-upgrade)***

# Breaking Changes

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

# Additions

### 1. External Secrets Support

Now you can use external secrets to store sensitive data.

You must provide it in the values.yaml file or as a [external secrets](#1-external-secrets-support).

```yaml
auth:
    useExistingSecrets: true
    existingSecretName: <existing-secret-name>

identity:
    useExistingSecrets: true
    existingSecretName: <existing-secret-name>
```

***Note:*** See the [auth secrets template](https://github.com/LerianStudio/helm/blob/main/charts/plugin-access-manager/templates/auth/secrets.yaml) and [identity secrets template](https://github.com/LerianStudio/helm/blob/main/charts/plugin-access-manager/templates/identity/secrets.yaml) for get the secrets keys.

### 2. Redis Configuration for Auth Service
The following environment variables have been introduced to the auth service:

```yaml
REDIS_MASTER_NAME: <your-redis-master-name>
REDIS_TLS: <your-redis-tls>
REDIS_CA_CERT: <your-redis-ca-cert>
REDIS_USE_GCP_IAM: <your-redis-use-gcp-iam>
GOOGLE_APPLICATION_CREDENTIALS: <your-google-application-credentials>
REDIS_SERVICE_ACCOUNT: <your-redis-service-account>
REDIS_TOKEN_LIFETIME: <your-redis-token-lifetime>
REDIS_TOKEN_REFRESH_DURATION: <your-redis-token-refresh-duration>
REDIS_DB: <your-redis-db>
REDIS_PROTOCOL: <your-redis-protocol>
```

***Note:*** You can keep the default values or modify them as needed. See the [auth configmap](https://github.com/LerianStudio/helm/blob/main/charts/plugin-access-manager/templates/auth/configmap.yaml) template for more details.

# Command to upgrade

```bash
$ helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 3.0.0 -n midaz-plugins
```
