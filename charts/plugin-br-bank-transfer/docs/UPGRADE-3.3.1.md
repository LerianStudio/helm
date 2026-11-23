# Helm Upgrade from v3.3.0 to v3.3.1

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Values Formatting Changes](#values-formatting-changes)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 3.3.1 is a patch release that updates the application version from 3.7.0 to 3.8.0 and includes minor formatting improvements to the values.yaml file. This release contains no breaking changes, no new configuration requirements, and no template modifications. The upgrade is straightforward and requires no operator action beyond running the upgrade command.

## Application Version Update

**What changed:**  
The chart now deploys application version 3.8.0 (previously 3.7.0).

| Setting | v3.3.0 | v3.3.1 |
|---------|--------|--------|
| `appVersion` (Chart.yaml) | `3.7.0` | `3.8.0` |
| `bankTransfer.image.tag` | `3.7.0` | `3.8.0` |

**Why it matters:**  
The application image will be updated to version 3.8.0 during the upgrade. This is a minor version bump that may include bug fixes, performance improvements, or new features in the bank-transfer application itself. Refer to the application's release notes for details on what changed in version 3.8.0.

**Operational impact:**  
- Kubernetes will perform a rolling update of the bank-transfer deployment
- Pods will be replaced with the new image version
- Downtime depends on your replica count and readiness probe configuration

**Migration required:**  
No — the image tag is updated automatically by the chart.

## Values Formatting Changes

**What changed:**  
The commented-out secret fields in `values.yaml` have been reformatted for improved readability. The indentation of multi-tenant, RabbitMQ, webhook, courier, and IDP secret comments has been adjusted from nested under `bankTransfer.secrets` to align at the same level as the `secrets:` key.

**Before (v3.3.0):**
```yaml
bankTransfer:
  secrets:
    # STREAMING_SASL_PASSWORD: ""
    # STREAMING_TLS_CA_CERT: ""

    # Multi-tenant (only when MULTI_TENANT_ENABLED=true). Redis CA: only when
    # MULTI_TENANT_REDIS_TLS=true and the cluster's CA isn't in the system trust pool.
    # MULTI_TENANT_SERVICE_API_KEY: ""  # REQUIRED when MULTI_TENANT_ENABLED=true
    # MULTI_TENANT_REDIS_PASSWORD: ""
    # MULTI_TENANT_REDIS_CA_CERT: ""

    # RabbitMQ credentials (when RABBITMQ_ENABLED=true; RABBITMQ_URL is required,
    # amqps:// outside development/test/local)
    # RABBITMQ_URL: ""
    # RABBITMQ_EVENT_SIGNING_SECRET: ""
```

**After (v3.3.1):**
```yaml
bankTransfer:
  secrets:
    # STREAMING_SASL_PASSWORD: ""
    # STREAMING_TLS_CA_CERT: ""
  # Multi-tenant (only when MULTI_TENANT_ENABLED=true). Redis CA: only when
  # MULTI_TENANT_REDIS_TLS=true and the cluster's CA isn't in the system trust pool.
  # MULTI_TENANT_SERVICE_API_KEY: ""  # REQUIRED when MULTI_TENANT_ENABLED=true
  # MULTI_TENANT_REDIS_PASSWORD: ""
  # MULTI_TENANT_REDIS_CA_CERT: ""

  # RabbitMQ credentials (when RABBITMQ_ENABLED=true; RABBITMQ_URL is required,
  # amqps:// outside development/test/local)
  # RABBITMQ_URL: ""
  # RABBITMQ_EVENT_SIGNING_SECRET: ""
```

**Why it matters:**  
This is a cosmetic change that improves the visual organization of the values file. The reformatted comments are now aligned at the `bankTransfer` level rather than nested under `secrets`, making it clearer that these are documentation comments rather than actual secret keys.

**Operational impact:**  
None — these are commented-out documentation lines. The change does not affect rendered templates or deployed resources. If you have uncommented any of these fields in your values overrides, they will continue to work exactly as before.

**Migration required:**  
No — this is a documentation-only change.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm -n midaz-plugins --version 3.3.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm -n midaz-plugins --version 3.3.1
```
