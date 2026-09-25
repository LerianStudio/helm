# Helm Upgrade from v1.4.0 to v1.5.0

## Topics ToC

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. KMS Mask Resolver](#1-kms-mask-resolver)
  - [2. Object Storage Mask Resolver](#2-object-storage-mask-resolver)
  - [3. Service Discovery Activation Toggle](#3-service-discovery-activation-toggle)
  - [4. Service Discovery Advertise Address](#4-service-discovery-advertise-address)
  - [5. Streaming Activation Toggle](#5-streaming-activation-toggle)
  - [6. Multi-Tenant Redis CA Certificate](#6-multi-tenant-redis-ca-certificate)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

The `lerian-common` chart v1.5.0 introduces **six new features** that extend the shared infrastructure contract for Lerian product charts. This release adds mask resolvers for KMS (HashiCorp Vault) and object storage (S3/SeaweedFS), environment-wide activation toggles for service discovery and streaming, and support for Redis CA certificates in multi-tenant configurations.

**What's new:**

- **KMS mask resolver** — operators declare `global.kms.vaultAddr` once instead of setting `KMS_VAULT_ADDR` per product
- **Object storage mask resolver** — operators declare `global.objectStorage.ccs.bucket` once instead of setting `OBJECT_STORAGE_CCS_BUCKET` per product
- **Service discovery activation toggle** — `global.serviceDiscovery.enabled` turns SD on for the entire umbrella with per-component override support
- **Service discovery advertise address** — new `SD_ADVERTISE_ADDRESS` and `SD_ADVERTISE_PORT` fields for service registration
- **Streaming activation toggle** — `global.streaming.enabled` turns streaming on for the entire umbrella with per-component override support
- **Multi-tenant Redis CA certificate** — new `MULTI_TENANT_REDIS_CA_CERT` field for TLS-enabled tenant Redis

**Backward compatibility:**

All new helpers are **render-equivalent** when adopted: with `global.*` blocks absent, helpers fall back to existing component values, producing identical output. Adopting these helpers is a refactor for chart maintainers, not a breaking change for operators.

**Who should upgrade:**

- Operators managing Lerian product charts in an umbrella/GitOps deployment who want to centralize KMS or object storage configuration
- Chart maintainers refactoring product charts to consume the new KMS and object storage helpers
- Operators who want environment-wide activation toggles for service discovery and streaming

## Features

### 1. KMS Mask Resolver

The `lerian-common.kms.value` helper resolves KMS (Key Management Service) connection fields from an operator-friendly "mask" instead of requiring operators to set product-specific environment variable keys.

**Problem solved:**

Instead of setting `KMS_VAULT_ADDR`, `KMS_VAULT_AUTH_METHOD`, `KMS_VAULT_ROLE_ID` separately per product, operators declare `kms.vaultAddr` once (shared) or per-product (dedicated).

**Deploy modes:**

- **SHARED:** `global.kms.<field>` — all products use one Vault instance
- **DEDICATED:** `<product>.kms.<field>` — each product has its own KMS config

**Supported fields:**

- `vendor` — KMS vendor (`none` or `hashicorp-vault`)
- `vaultAddr` — Vault server address (e.g. `https://vault.prod.example.com:8200`)
- `vaultAuthMethod` — Vault authentication method (e.g. `approle`)
- `vaultRoleId` — Vault AppRole role ID
- `vaultMount` — Vault mount path

> **Important:** `KMS_VAULT_SECRET_ID` is a **secret** and must be set per component under `.secrets`, never in `global.kms`.

**Precedence:**

Native configmap key > dedicated (`<product>.kms`) > shared (`global.kms`) > default

**Configuration example (umbrella `values.yaml`):**

```yaml
# Shared Vault (all products)
global:
  kms:
    vendor: "hashicorp-vault"
    vaultAddr: "https://vault.prod.example.com:8200"
    vaultAuthMethod: "approle"
    vaultRoleId: "lerian-role-id"
    vaultMount: "secret"

# Dedicated Vault for ledger
ledger:
  kms:
    vaultAddr: "https://vault-ledger.prod.example.com:8200"
    vaultRoleId: "ledger-role-id"
```

**Usage in product charts:**

```yaml
# templates/configmap.yaml
data:
  KMS_VENDOR: {{ include "lerian-common.kms.value" (dict "context" $ "configmap" .Values.myapp.configmap "field" "vendor" "nativeKey" "KMS_VENDOR" "default" "none") | quote }}
  KMS_VAULT_ADDR: {{ include "lerian-common.kms.value" (dict "context" $ "configmap" .Values.myapp.configmap "field" "vaultAddr" "nativeKey" "KMS_VAULT_ADDR" "default" "") | quote }}
  KMS_VAULT_AUTH_METHOD: {{ include "lerian-common.kms.value" (dict "context" $ "configmap" .Values.myapp.configmap "field" "vaultAuthMethod" "nativeKey" "KMS_VAULT_AUTH_METHOD" "default" "") | quote }}
  KMS_VAULT_ROLE_ID: {{ include "lerian-common.kms.value" (dict "context" $ "configmap" .Values.myapp.configmap "field" "vaultRoleId" "nativeKey" "KMS_VAULT_ROLE_ID" "default" "") | quote }}
  KMS_VAULT_MOUNT: {{ include "lerian-common.kms.value" (dict "context" $ "configmap" .Values.myapp.configmap "field" "vaultMount" "nativeKey" "KMS_VAULT_MOUNT" "default" "") | quote }}
```

**Operational impact:**

- **For standalone deployments:** No action required. The helper falls back to existing component values.
- **For umbrella deployments:** Operators can now declare KMS configuration once at the umbrella level instead of repeating it in every product chart.

### 2. Object Storage Mask Resolver

The `lerian-common.objectStorage.value` helper resolves object storage (S3/SeaweedFS) connection fields from an operator-friendly "mask" instead of requiring operators to set product-specific environment variable keys.

**Problem solved:**

Instead of setting `OBJECT_STORAGE_CCS_BUCKET`, `OBJECT_STORAGE_CCS_ENDPOINT`, `OBJECT_STORAGE_CCS_REGION` separately per product, operators declare `objectStorage.ccs.bucket` once (shared) or per-product (dedicated).

**Deploy modes:**

- **SHARED:** `global.objectStorage.<name>.<field>` — all products use one backend
- **DEDICATED:** `<product>.objectStorage.<name>.<field>` — each product has its own backend

**Supported backend names:**

Backend names are product-specific. Common examples:

- `ccs` — CCS (Core Card System) storage
- `fetcher` — Fetcher service storage
- `sta` — STA (Statement) storage
- `default` — Default backend

**Supported fields:**

- `endpoint` — S3/SeaweedFS endpoint (e.g. `s3.amazonaws.com` or `seaweedfs.prod.svc.cluster.local:8333`)
- `region` — S3 region (e.g. `us-east-1`)
- `bucket` — Bucket name
- `disableSSL` — Disable SSL for S3 connections (boolean)
- `usePathStyle` — Use path-style S3 URLs instead of virtual-hosted-style (boolean)

> **Important:** `*_ACCESS_KEY_ID` and `*_SECRET_ACCESS_KEY` are **secrets** and must be set per component under `.secrets`, never in `global.objectStorage`.

**Precedence:**

Native configmap key > dedicated (`<product>.objectStorage`) > shared (`global.objectStorage`) > default

**Configuration example (umbrella `values.yaml`):**

```yaml
# Shared S3 backend (all products)
global:
  objectStorage:
    ccs:
      endpoint: "s3.amazonaws.com"
      region: "us-east-1"
      bucket: "lerian-ccs-prod"
      disableSSL: false
      usePathStyle: false
    fetcher:
      endpoint: "s3.amazonaws.com"
      region: "us-east-1"
      bucket: "lerian-fetcher-prod"
      disableSSL: false
      usePathStyle: false

# Dedicated SeaweedFS backend for br-ccs
br-ccs:
  objectStorage:
    ccs:
      endpoint: "seaweedfs-ccs.prod.svc.cluster.local:8333"
      region: ""
      bucket: "br-ccs"
      disableSSL: true
      usePathStyle: true
```

**Usage in product charts:**

```yaml
# templates/configmap.yaml
data:
  OBJECT_STORAGE_CCS_ENDPOINT: {{ include "lerian-common.objectStorage.value" (dict "context" $ "configmap" .Values.myapp.configmap "name" "ccs" "field" "endpoint" "nativeKey" "OBJECT_STORAGE_CCS_ENDPOINT" "default" "") | quote }}
  OBJECT_STORAGE_CCS_REGION: {{ include "lerian-common.objectStorage.value" (dict "context" $ "configmap" .Values.myapp.configmap "name" "ccs" "field" "region" "nativeKey" "OBJECT_STORAGE_CCS_REGION" "default" "") | quote }}
  OBJECT_STORAGE_CCS_BUCKET: {{ include "lerian-common.objectStorage.value" (dict "context" $ "configmap" .Values.myapp.configmap "name" "ccs" "field" "bucket" "nativeKey" "OBJECT_STORAGE_CCS_BUCKET" "default" "") | quote }}
  OBJECT_STORAGE_CCS_DISABLE_SSL: {{ include "lerian-common.objectStorage.value" (dict "context" $ "configmap" .Values.myapp.configmap "name" "ccs" "field" "disableSSL" "nativeKey" "OBJECT_STORAGE_CCS_DISABLE_SSL" "default" "false") | quote }}
  OBJECT_STORAGE_CCS_USE_PATH_STYLE: {{ include "lerian-common.objectStorage.value" (dict "context" $ "configmap" .Values.myapp.configmap "name" "ccs" "field" "usePathStyle" "nativeKey" "OBJECT_STORAGE_CCS_USE_PATH_STYLE" "default" "false") | quote }}
```

**Operational impact:**

- **For standalone deployments:** No action required. The helper falls back to existing component values.
- **For umbrella deployments:** Operators can now declare object storage configuration once at the umbrella level instead of repeating it in every product chart.

### 3. Service Discovery Activation Toggle

The `lerian-common.serviceDiscovery.env` helper now supports an **environment-wide activation toggle** via `global.serviceDiscovery.enabled`, with per-component override support.

**What changed:**

The helper now resolves `SD_ENABLED` using a three-tier precedence:

1. Explicit `.enabled` parameter (legacy callers — backward-compatible)
2. Component-level `configmap.SD_ENABLED` (per-component override)
3. `global.serviceDiscovery.enabled` (environment-wide toggle)
4. `false` (default)

**Before (v1.4.0):**

Operators had to set `SD_ENABLED` per component in each product chart's values:

```yaml
ledger:
  configmap:
    SD_ENABLED: "true"

crm:
  configmap:
    SD_ENABLED: "true"

onboarding:
  configmap:
    SD_ENABLED: "true"
```

**After (v1.5.0):**

Operators can enable service discovery for the entire umbrella with one flag:

```yaml
global:
  serviceDiscovery:
    enabled: true
    address: "consul.prod.example.com:443"
    tls: true
```

**Per-component override:**

If a specific component should **not** use service discovery (or should override the global setting), set `SD_ENABLED` in that component's configmap:

```yaml
global:
  serviceDiscovery:
    enabled: true  # Enable for all components

ledger:
  configmap:
    SD_ENABLED: "false"  # Disable for ledger only
```

**Operational impact:**

- **For standalone deployments:** No action required. The helper falls back to existing component values.
- **For umbrella deployments:** Operators can now enable service discovery for all products with one flag instead of setting it per component.

### 4. Service Discovery Advertise Address

The `lerian-common.serviceDiscovery.env` helper now emits two new environment variables for service registration: `SD_ADVERTISE_ADDRESS` and `SD_ADVERTISE_PORT`.

**New environment variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `SD_ADVERTISE_ADDRESS` | `""` | Advertise address for service registration (overrides auto-detected address) |
| `SD_ADVERTISE_PORT` | `0` | Advertise port for service registration (overrides auto-detected port) |

**Configuration example (umbrella `values.yaml`):**

```yaml
global:
  serviceDiscovery:
    enabled: true
    address: "consul.prod.example.com:443"
    advertiseAddress: "10.0.1.100"
    advertisePort: "8080"
```

**Per-component override:**

```yaml
ledger:
  configmap:
    SD_ADVERTISE_ADDRESS: "10.0.2.50"
    SD_ADVERTISE_PORT: "9090"
```

**Operational impact:**

- **For existing deployments:** No action required. The new fields default to empty string and `0`, which preserves existing behavior (auto-detection).
- **For deployments that need explicit advertise addresses:** Set `global.serviceDiscovery.advertiseAddress` and `global.serviceDiscovery.advertisePort` at the umbrella level, or override per component.

### 5. Streaming Activation Toggle

The `lerian-common.streaming.env` helper now supports an **environment-wide activation toggle** via `global.streaming.enabled`, with per-component override support.

**What changed:**

The helper now resolves `STREAMING_ENABLED` using a three-tier precedence:

1. Explicit `.enabled` parameter (legacy callers — backward-compatible)
2. Component-level `configmap.STREAMING_ENABLED` (per-component override)
3. `global.streaming.enabled` (environment-wide toggle)
4. `false` (default)

**Before (v1.4.0):**

Operators had to set `STREAMING_ENABLED` per component in each product chart's values:

```yaml
ledger:
  configmap:
    STREAMING_ENABLED: "true"

crm:
  configmap:
    STREAMING_ENABLED: "true"

onboarding:
  configmap:
    STREAMING_ENABLED: "true"
```

**After (v1.5.0):**

Operators can enable streaming for the entire umbrella with one flag:

```yaml
global:
  streaming:
    enabled: true
    brokers: "redpanda.prod.example.com:9092"
    tlsEnabled: true
```

**Per-component override:**

If a specific component should **not** use streaming (or should override the global setting), set `STREAMING_ENABLED` in that component's configmap:

```yaml
global:
  streaming:
    enabled: true  # Enable for all components

ledger:
  configmap:
    STREAMING_ENABLED: "false"  # Disable for ledger only
```

**Operational impact:**

- **For standalone deployments:** No action required. The helper falls back to existing component values.
- **For umbrella deployments:** Operators can now enable streaming for all products with one flag instead of setting it per component.

### 6. Multi-Tenant Redis CA Certificate

The `lerian-common.multiTenant.env` helper now supports a new field for Redis TLS CA certificate: `MULTI_TENANT_REDIS_CA_CERT`.

**New environment variable:**

| Variable | Default | Description |
|----------|---------|-------------|
| `MULTI_TENANT_REDIS_CA_CERT` | `""` | CA certificate for TLS-enabled tenant Redis (PEM-encoded) |

**Configuration example (umbrella `values.yaml`):**

```yaml
global:
  multiTenant:
    url: "http://tenant-manager.prod.svc.cluster.local"
    redisHost: "redis-mt.prod.svc.cluster.local"
    redisPort: "6379"
    redisTls: "true"
    redisCaCert: |
      -----BEGIN CERTIFICATE-----
      MIIDXTCCAkWgAwIBAgIJAKZ...
      -----END CERTIFICATE-----
```

**Per-component override:**

```yaml
reporter:
  configmap:
    MULTI_TENANT_REDIS_CA_CERT: |
      -----BEGIN CERTIFICATE-----
      MIIDXTCCAkWgAwIBAgIJAKZ...
      -----END CERTIFICATE-----
```

**Usage in product charts:**

Product chart maintainers must opt in to this field by passing `emitRedisCaCert: true` to the helper:

```yaml
# templates/configmap.yaml
data:
  {{- include "lerian-common.multiTenant.env" (dict "context" $ "configmap" .Values.myapp.configmap "emitRedis" true "emitRedisCaCert" true) | nindent 2 }}
```

**Operational impact:**

- **For existing deployments:** No action required. The new field defaults to empty string, which preserves existing behavior (no CA cert validation).
- **For deployments with TLS-enabled tenant Redis:** Set `global.multiTenant.redisCaCert` at the umbrella level, or override per component.

> **Note:** This field is only emitted when the product chart explicitly passes `emitRedisCaCert: true` to the helper. Not all product charts support this field (e.g. reporter does, but others may not).

## Configuration Reference

The following new configuration blocks are available in v1.5.0:

### KMS Configuration

```yaml
global:
  kms:
    vendor: "hashicorp-vault"  # KMS vendor (none | hashicorp-vault)
    vaultAddr: ""              # Vault server address (e.g. https://vault.prod.example.com:8200)
    vaultAuthMethod: ""        # Vault authentication method (e.g. approle)
    vaultRoleId: ""            # Vault AppRole role ID
    vaultMount: ""             # Vault mount path (e.g. secret)
```

**Per-product dedicated KMS:**

```yaml
<product>:
  kms:
    vendor: "hashicorp-vault"
    vaultAddr: ""
    vaultAuthMethod: ""
    vaultRoleId: ""
    vaultMount: ""
```

### Object Storage Configuration

```yaml
global:
  objectStorage:
    <name>:  # Backend name (e.g. ccs, fetcher, sta, default)
      endpoint: ""       # S3/SeaweedFS endpoint
      region: ""         # S3 region
      bucket: ""         # Bucket name
      disableSSL: false  # Disable SSL for S3 connections
      usePathStyle: false  # Use path-style S3 URLs
```

**Per-product dedicated object storage:**

```yaml
<product>:
  objectStorage:
    <name>:
      endpoint: ""
      region: ""
      bucket: ""
      disableSSL: false
      usePathStyle: false
```

### Service Discovery Configuration (Updated)

```yaml
global:
  serviceDiscovery:
    enabled: false            # NEW: Environment-wide activation toggle
    address: ""
    advertiseAddress: ""      # NEW: Advertise address for service registration
    advertisePort: "0"        # NEW: Advertise port for service registration
    tls: false
    tlsSkipVerify: false
    workload: ""
    preferView: "external"
    internalScheme: "http"
    externalPort: "443"
```

### Streaming Configuration (Updated)

```yaml
global:
  streaming:
    enabled: false            # NEW: Environment-wide activation toggle
    brokers: ""
    tlsEnabled: false
    saslMechanism: ""
    saslUsername: ""
```

### Multi-Tenant Configuration (Updated)

```yaml
global:
  multiTenant:
    url: ""
    redisHost: ""
    redisPort: "6379"
    redisTls: "false"
    redisCaCert: ""           # NEW: CA certificate for TLS-enabled tenant Redis
```

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.5.0 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Important:** Since `lerian-common` is a library chart, `helm diff` will show no resource changes (library charts render nothing). To preview the impact of adopting `lerian-common` v1.5.0, run `helm diff` on the **product charts** that consume it.

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.5.0 -n lerian-common
```

> **Note:** Since `lerian-common` is a library chart, you typically do **not** install or upgrade it directly. Instead, update the dependency version in your umbrella or product chart's `Chart.yaml` to `1.5.0` and run `helm dependency update`.
