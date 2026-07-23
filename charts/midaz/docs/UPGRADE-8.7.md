# Helm Upgrade from v8.6.0 to v8.7.0

## Topics

- **[Features](#features)**
  - [1. Application version bump to 3.8.0](#1-application-version-bump-to-380)
  - [2. Service Discovery (Consul) integration](#2-service-discovery-consul-integration)
  - [3. Key Management Service (KMS) configuration for CRM](#3-key-management-service-kms-configuration-for-crm)
  - [4. Streaming enablement flags](#4-streaming-enablement-flags)
  - [5. Swagger version configuration for Ledger](#5-swagger-version-configuration-for-ledger)
- **[Configuration Reference](#configuration-reference)**
  - [Service Discovery environment variables](#service-discovery-environment-variables)
  - [KMS environment variables](#kms-environment-variables)
  - [Streaming environment variables](#streaming-environment-variables)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Application version bump to 3.8.0

The Midaz application components have been upgraded from version `3.7.8` to `3.8.0`.

| Component | v8.6.0 | v8.7.0 |
|-----------|--------|--------|
| appVersion | 3.7.8 | 3.8.0 |
| ledger.image.tag | 3.7.8 | 3.8.0 |
| crm.image.tag | 3.7.8 | 3.8.0 |

This version includes new capabilities for service discovery, KMS integration, and streaming features. Refer to the [Midaz application changelog](https://github.com/LerianStudio/midaz/blob/main/CHANGELOG.md) for detailed application-level changes.

### 2. Service Discovery (Consul) integration

Both the **Ledger** and **CRM** services now support integration with HashiCorp Consul for service discovery. This feature is disabled by default and can be enabled when you have a Consul cluster available.

#### New environment variables

The following service discovery configuration variables have been added to both `ledger.configmap` and `crm.configmap`:

| Variable | Default | Description |
|----------|---------|-------------|
| SD_ENABLED | `false` | Enable or disable service discovery integration |
| SD_ADDRESS | `localhost:8500` | Consul server address |
| SD_WORKLOAD | `""` | Service workload identifier for registration |
| SD_EXTERNAL_ADDRESS | `""` | External address for service registration |
| SD_EXTERNAL_PORT | `""` | External port for service registration |
| SD_INTERNAL_ADDRESS | `""` | Internal address for service registration |
| SD_INTERNAL_PORT | `""` | Internal port for service registration |
| SD_INTERNAL_SCHEME | `""` | Internal scheme (http/https) |
| SD_TLS | `false` | Enable TLS for Consul communication |
| SD_TLS_SKIP_VERIFY | `false` | Skip TLS certificate verification |
| SD_TLS_HANDSHAKE_TIMEOUT | `""` | TLS handshake timeout duration |
| SD_DIAL_TIMEOUT | `""` | Connection dial timeout |
| SD_RESPONSE_HEADER_TIMEOUT | `""` | HTTP response header timeout |
| SD_SEED_TIMEOUT | `""` | Initial seed timeout |
| SD_WATCH_WAIT_TIME | `""` | Watch query wait time |
| SD_ALLOW_STALE | `""` | Allow stale reads from Consul |
| SD_PREFER_VIEW | `""` | Preferred consistency view |

#### Consul ACL token secret

A new secret field has been added for Consul ACL authentication:

**Ledger:**
```yaml
ledger:
  secrets:
    SD_TOKEN: ""
```

**CRM:**
```yaml
crm:
  secrets:
    SD_TOKEN: ""
```

> **Note:** The `SD_TOKEN` secret should only be set when your Consul server enforces ACLs. Leave it empty if ACLs are not enabled.

#### Example configuration

To enable service discovery for the Ledger service with Consul:

```yaml
ledger:
  configmap:
    SD_ENABLED: "true"
    SD_ADDRESS: "consul.consul.svc.cluster.local:8500"
    SD_WORKLOAD: "midaz-ledger"
    SD_INTERNAL_ADDRESS: "midaz-ledger.midaz.svc.cluster.local"
    SD_INTERNAL_PORT: "3000"
    SD_INTERNAL_SCHEME: "http"
    SD_TLS: "false"
  secrets:
    SD_TOKEN: "your-consul-acl-token-here"
```

### 3. Key Management Service (KMS) configuration for CRM

The **CRM** service now includes configuration for integrating with HashiCorp Vault as a Key Management Service (KMS) provider.

#### New environment variables

The following KMS configuration variables have been added to `crm.configmap`:

| Variable | Default | Description |
|----------|---------|-------------|
| KMS_VENDOR | `hashicorp-vault` | KMS vendor identifier |
| KMS_VAULT_ADDR | `http://midaz-hc-vault:8200` | Vault server address |
| KMS_VAULT_AUTH_METHOD | `token` | Vault authentication method |

#### Example configuration

To configure CRM to use an external Vault instance:

```yaml
crm:
  configmap:
    KMS_VENDOR: "hashicorp-vault"
    KMS_VAULT_ADDR: "https://vault.example.com:8200"
    KMS_VAULT_AUTH_METHOD: "kubernetes"
```

> **Note:** The KMS integration requires additional Vault-specific authentication credentials to be configured separately, depending on the chosen `KMS_VAULT_AUTH_METHOD`.

### 4. Streaming enablement flags

Both **Ledger** and **CRM** services now include an explicit flag to enable or disable streaming functionality.

#### New environment variable

| Variable | Default | Description |
|----------|---------|-------------|
| STREAMING_ENABLED | `false` | Enable or disable streaming integration |

This flag works in conjunction with the existing streaming configuration (SASL credentials, TLS certificates) that was already present in the chart.

#### Example configuration

To enable streaming for both services:

```yaml
ledger:
  configmap:
    STREAMING_ENABLED: "true"

crm:
  configmap:
    STREAMING_ENABLED: "true"
```

> **Important:** Setting `STREAMING_ENABLED: "true"` requires that you also configure the streaming backend credentials and connection details via the existing `STREAMING_*` environment variables and secrets.

### 5. Swagger version configuration for Ledger

The **Ledger** service now includes a configurable Swagger version variable.

#### New environment variable

| Variable | Default | Description |
|----------|---------|-------------|
| SWAGGER_VERSION | `${VERSION}` | Swagger API documentation version |

This allows operators to control the version displayed in the Swagger UI independently of the application version.

#### Example configuration

```yaml
ledger:
  configmap:
    SWAGGER_VERSION: "v3.8.0"
```

## Configuration Reference

### Service Discovery environment variables

The following table summarizes all service discovery configuration options available in both `ledger.configmap` and `crm.configmap`:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| SD_ENABLED | ConfigMap | `false` | Enable service discovery |
| SD_ADDRESS | ConfigMap | `localhost:8500` | Consul server address |
| SD_WORKLOAD | ConfigMap | `""` | Service workload name |
| SD_EXTERNAL_ADDRESS | ConfigMap | `""` | External service address |
| SD_EXTERNAL_PORT | ConfigMap | `""` | External service port |
| SD_INTERNAL_ADDRESS | ConfigMap | `""` | Internal service address |
| SD_INTERNAL_PORT | ConfigMap | `""` | Internal service port |
| SD_INTERNAL_SCHEME | ConfigMap | `""` | Internal scheme (http/https) |
| SD_TLS | ConfigMap | `false` | Enable TLS |
| SD_TLS_SKIP_VERIFY | ConfigMap | `false` | Skip TLS verification |
| SD_TLS_HANDSHAKE_TIMEOUT | ConfigMap | `""` | TLS handshake timeout |
| SD_DIAL_TIMEOUT | ConfigMap | `""` | Dial timeout |
| SD_RESPONSE_HEADER_TIMEOUT | ConfigMap | `""` | Response header timeout |
| SD_SEED_TIMEOUT | ConfigMap | `""` | Seed timeout |
| SD_WATCH_WAIT_TIME | ConfigMap | `""` | Watch wait time |
| SD_ALLOW_STALE | ConfigMap | `""` | Allow stale reads |
| SD_PREFER_VIEW | ConfigMap | `""` | Preferred view |
| SD_TOKEN | Secret | `""` | Consul ACL token |

### KMS environment variables

The following table summarizes KMS configuration options available in `crm.configmap`:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| KMS_VENDOR | ConfigMap | `hashicorp-vault` | KMS vendor |
| KMS_VAULT_ADDR | ConfigMap | `http://midaz-hc-vault:8200` | Vault address |
| KMS_VAULT_AUTH_METHOD | ConfigMap | `token` | Vault auth method |

### Streaming environment variables

The following table summarizes the new streaming enablement flag:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| STREAMING_ENABLED | ConfigMap | `false` | Enable streaming |

## Migration Steps

This is a **non-breaking** minor version upgrade. No mandatory migration steps are required. All new features are disabled by default.

### Optional: Enable service discovery

If you want to integrate with Consul for service discovery:

1. Ensure you have a Consul cluster available and accessible from your Kubernetes cluster.

2. Update your `values.yaml` to enable service discovery for Ledger and/or CRM:

```yaml
ledger:
  configmap:
    SD_ENABLED: "true"
    SD_ADDRESS: "consul.consul.svc.cluster.local:8500"
    SD_WORKLOAD: "midaz-ledger"
    SD_INTERNAL_ADDRESS: "midaz-ledger.midaz.svc.cluster.local"
    SD_INTERNAL_PORT: "3000"
  secrets:
    SD_TOKEN: "your-consul-acl-token"

crm:
  configmap:
    SD_ENABLED: "true"
    SD_ADDRESS: "consul.consul.svc.cluster.local:8500"
    SD_WORKLOAD: "midaz-crm"
    SD_INTERNAL_ADDRESS: "midaz-crm.midaz.svc.cluster.local"
    SD_INTERNAL_PORT: "3001"
  secrets:
    SD_TOKEN: "your-consul-acl-token"
```

3. Upgrade the chart using the command in the final section.

### Optional: Enable streaming

If you want to enable the streaming feature:

1. Ensure your streaming backend (Kafka, RabbitMQ, etc.) is configured and the existing `STREAMING_*` credentials are set.

2. Update your `values.yaml`:

```yaml
ledger:
  configmap:
    STREAMING_ENABLED: "true"

crm:
  configmap:
    STREAMING_ENABLED: "true"
```

3. Upgrade the chart using the command in the final section.

### Optional: Configure KMS for CRM

If you want to use an external Vault instance for key management in CRM:

1. Update your `values.yaml`:

```yaml
crm:
  configmap:
    KMS_VAULT_ADDR: "https://vault.example.com:8200"
    KMS_VAULT_AUTH_METHOD: "kubernetes"
```

2. Configure Vault authentication credentials according to your chosen auth method.

3. Upgrade the chart using the command in the final section.

> **Note:** If you do not explicitly configure these new features, the upgrade will proceed with all new functionality disabled, maintaining backward compatibility with v8.6.0 behavior.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.7.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.7.0 -n midaz
```
