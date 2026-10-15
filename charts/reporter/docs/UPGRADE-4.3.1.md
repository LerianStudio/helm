# Helm Upgrade from v4.3.0 to v4.3.1

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Optional CRM datasource support](#1-optional-crm-datasource-support)
- **[Configuration Reference](#configuration-reference)**
  - [CRM datasource configuration fields](#crm-datasource-configuration-fields)
  - [CRM datasource secret fields](#crm-datasource-secret-fields)
- **[Migration Steps](#migration-steps)**
  - [Option 1: No action required (CRM not used)](#option-1-no-action-required-crm-not-used)
  - [Option 2: Enable CRM datasource](#option-2-enable-crm-datasource)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that adds optional CRM datasource support to the Reporter chart. The application version is bumped from `3.0.0` to `3.0.1`, and both manager and worker image tags are updated accordingly. CRM datasource configuration is entirely optional — installations that do not configure CRM will see no behavioral changes.

| Field | v4.3.0 | v4.3.1 |
|-------|--------|--------|
| Chart version | `4.3.0` | `4.3.1` |
| App version | `3.0.0` | `3.0.1` |
| Manager image tag | `3.0.0` | `3.0.1` |
| Worker image tag | `3.0.0` | `3.0.1` |

## Fixes

### 1. Optional CRM datasource support

The chart now supports an optional CRM datasource backed by MongoDB. When enabled, both manager and worker components can connect to a dedicated CRM database using a reserved datasource name (`plugin_crm`). CRM configuration is all-or-nothing: once any `DATASOURCE_CRM_*` key is set in `common.configmap`, the chart enforces a complete configuration contract and validates all required fields at render time.

**What changed:**

- New template helpers (`reporter.crmDeclared`, `reporter.crmConfigRequired`, `reporter.crmSecretsRequired`) validate CRM configuration when declared
- New documentation block added to `values.yaml` under `common.configmap` with example CRM configuration
- New secret fields documented under `secrets:` for CRM password and crypto keys
- Manager and worker Secret templates now call `reporter.crmSecretsRequired` to enforce secret presence when CRM is declared and chart-managed Secrets are used

**Operational impact:**

CRM datasource configuration is **disabled by default**. If you do not set any `DATASOURCE_CRM_*` keys, the upgrade will proceed with no changes to your deployment. If you choose to enable CRM, the chart will validate that all required configuration and secret fields are present before rendering.

**CRM datasource contract:**

When CRM is declared (any `DATASOURCE_CRM_*` key is set), the following fields become required:

| Field | Location | Required Value | Description |
|-------|----------|----------------|-------------|
| `DATASOURCE_CRM_CONFIG_NAME` | `common.configmap` | `"plugin_crm"` | Reserved datasource name (must not be changed) |
| `DATASOURCE_CRM_TYPE` | `common.configmap` | `"mongodb"` | Datasource type (only MongoDB is supported) |
| `DATASOURCE_CRM_HOST` | `common.configmap` | operator-provided | CRM MongoDB host |
| `DATASOURCE_CRM_PORT` | `common.configmap` | operator-provided | CRM MongoDB port |
| `DATASOURCE_CRM_DATABASE` | `common.configmap` | operator-provided | CRM database name |
| `DATASOURCE_CRM_USER` | `common.configmap` | operator-provided | CRM MongoDB username |
| `DATASOURCE_CRM_MIDAZ_ORGANIZATION_ID` | `common.configmap` | operator-provided | Organization ID for CRM integration |
| `DATASOURCE_CRM_PASSWORD` | `secrets` | operator-provided | CRM MongoDB password |
| `CRYPTO_HASH_SECRET_KEY_CRM` | `secrets` | operator-provided | CRM crypto hash key |
| `CRYPTO_ENCRYPT_SECRET_KEY_CRM` | `secrets` | operator-provided | CRM crypto encryption key |

**Validation behavior:**

The chart enforces the following rules when CRM is declared:

1. **Misplaced secrets:** If `DATASOURCE_CRM_PASSWORD`, `CRYPTO_HASH_SECRET_KEY_CRM`, or `CRYPTO_ENCRYPT_SECRET_KEY_CRM` are set in `common.configmap`, the chart will fail with an error instructing you to move them to `secrets:` or an external Secret.

2. **Incomplete configuration:** If any required non-secret field is missing or empty in `common.configmap`, the chart will fail with an error listing the missing keys.

3. **Reserved name enforcement:** If `DATASOURCE_CRM_CONFIG_NAME` is set to any value other than `"plugin_crm"`, the chart will fail with an error.

4. **Type enforcement:** If `DATASOURCE_CRM_TYPE` is set to any value other than `"mongodb"`, the chart will fail with an error.

5. **Chart-managed Secret validation:** When `manager.useExistingSecret=false` or `worker.useExistingSecret=false`, the chart will fail if the corresponding component's Secret is missing any of the three required CRM secret keys.

> **Important:** When using external Secrets (`manager.useExistingSecret=true` or `worker.useExistingSecret=true`), you must provide the same three CRM secret keys in your external Secret. The chart cannot validate external Secret contents at render time.

**Example CRM configuration:**

```yaml
common:
  configmap:
    DATASOURCE_CRM_CONFIG_NAME: "plugin_crm"
    DATASOURCE_CRM_TYPE: "mongodb"
    DATASOURCE_CRM_HOST: "crm.example.com"
    DATASOURCE_CRM_PORT: "27017"
    DATASOURCE_CRM_DATABASE: "crm"
    DATASOURCE_CRM_USER: "reporter"
    DATASOURCE_CRM_MIDAZ_ORGANIZATION_ID: "org-12345"

secrets:
  DATASOURCE_CRM_PASSWORD: "your-crm-mongodb-password"
  CRYPTO_HASH_SECRET_KEY_CRM: "your-crm-hash-key"
  CRYPTO_ENCRYPT_SECRET_KEY_CRM: "your-crm-encrypt-key"
```

> **Note:** The `DATASOURCE_CRED_ENC_KEY` field (used for encrypting dynamically registered datasource credentials) remains unchanged and must not be rotated. CRM crypto keys are separate and specific to the CRM datasource.

## Configuration Reference

### CRM datasource configuration fields

All CRM datasource configuration fields are set under `common.configmap`. These fields are shared between manager and worker components.

| Field | Default | Description |
|-------|---------|-------------|
| `common.configmap.DATASOURCE_CRM_CONFIG_NAME` | not set | Reserved datasource name; must be `"plugin_crm"` when CRM is enabled |
| `common.configmap.DATASOURCE_CRM_TYPE` | not set | Datasource type; must be `"mongodb"` when CRM is enabled |
| `common.configmap.DATASOURCE_CRM_HOST` | not set | CRM MongoDB host (required when CRM is enabled) |
| `common.configmap.DATASOURCE_CRM_PORT` | not set | CRM MongoDB port (required when CRM is enabled) |
| `common.configmap.DATASOURCE_CRM_DATABASE` | not set | CRM database name (required when CRM is enabled) |
| `common.configmap.DATASOURCE_CRM_USER` | not set | CRM MongoDB username (required when CRM is enabled) |
| `common.configmap.DATASOURCE_CRM_MIDAZ_ORGANIZATION_ID` | not set | Organization ID for CRM integration (required when CRM is enabled) |

### CRM datasource secret fields

All CRM datasource secret fields are set under `secrets:` (or in external Secrets when `manager.useExistingSecret=true` or `worker.useExistingSecret=true`).

| Field | Default | Description |
|-------|---------|-------------|
| `secrets.DATASOURCE_CRM_PASSWORD` | `""` | CRM MongoDB password (required when CRM is enabled and chart-managed Secrets are used) |
| `secrets.CRYPTO_HASH_SECRET_KEY_CRM` | `""` | CRM crypto hash key (required when CRM is enabled and chart-managed Secrets are used) |
| `secrets.CRYPTO_ENCRYPT_SECRET_KEY_CRM` | `""` | CRM crypto encryption key (required when CRM is enabled and chart-managed Secrets are used) |

> **Important:** When using external Secrets, you must provide these three keys in both the manager and worker external Secrets. The chart cannot validate external Secret contents at render time.

## Migration Steps

### Option 1: No action required (CRM not used)

If you do not need CRM datasource support, no configuration changes are required. The upgrade will update the manager and worker image tags from `3.0.0` to `3.0.1` and proceed with a standard rolling restart.

**Upgrade command:**

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.1 -n reporter
```

**Verification:**

```bash
kubectl get pods -n reporter
kubectl logs -n reporter -l app.kubernetes.io/name=reporter-manager --tail=50
kubectl logs -n reporter -l app.kubernetes.io/name=reporter-worker --tail=50
```

### Option 2: Enable CRM datasource

If you need to enable CRM datasource support, follow these steps:

#### Step 1: Prepare CRM configuration values

Create a `values-crm.yaml` file with all required CRM configuration and secret fields:

```yaml
common:
  configmap:
    DATASOURCE_CRM_CONFIG_NAME: "plugin_crm"
    DATASOURCE_CRM_TYPE: "mongodb"
    DATASOURCE_CRM_HOST: "crm.example.com"
    DATASOURCE_CRM_PORT: "27017"
    DATASOURCE_CRM_DATABASE: "crm"
    DATASOURCE_CRM_USER: "reporter"
    DATASOURCE_CRM_MIDAZ_ORGANIZATION_ID: "org-12345"

secrets:
  DATASOURCE_CRM_PASSWORD: "your-crm-mongodb-password"
  CRYPTO_HASH_SECRET_KEY_CRM: "your-crm-hash-key"
  CRYPTO_ENCRYPT_SECRET_KEY_CRM: "your-crm-encrypt-key"
```

> **Important:** Replace all placeholder values with your actual CRM MongoDB connection details and secure crypto keys. The organization ID must match the organization ID configured in your Midaz deployment.

#### Step 2: Verify configuration completeness

Before upgrading, verify that all required fields are present and non-empty. The chart will fail at render time if any required field is missing or if secrets are misplaced in `common.configmap`.

#### Step 3: Execute the upgrade

Run the upgrade command with your CRM configuration file:

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm \
  --version 4.3.1 \
  -n reporter \
  -f values-crm.yaml
```

#### Step 4: Verify CRM datasource connectivity

After the upgrade completes, verify that both manager and worker components can connect to the CRM datasource:

```bash
kubectl logs -n reporter -l app.kubernetes.io/name=reporter-manager --tail=50 | grep -i crm
kubectl logs -n reporter -l app.kubernetes.io/name=reporter-worker --tail=50 | grep -i crm
```

> **Note:** If you are using external Secrets (`manager.useExistingSecret=true` or `worker.useExistingSecret=true`), ensure that your external Secrets include the three required CRM secret keys before upgrading. The chart cannot validate external Secret contents at render time, so missing keys will cause runtime failures.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.1 -n reporter
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.1 -n reporter
```
