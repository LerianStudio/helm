# Helm Upgrade from v8.4.0 to v8.5.0

# Topics

- **[Features](#features)**
  - [1. Platform Internal CIDRs Configuration](#1-platform-internal-cidrs-configuration)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Features

### 1. Platform Internal CIDRs Configuration

A new environment variable `PLATFORM_INTERNAL_CIDRS` has been added to the identity service ConfigMap. This allows operators to configure trusted internal network ranges for the platform.

**What changed:**

The identity service now supports specifying internal CIDR ranges that should be treated as trusted platform networks. This is useful for scenarios where the identity service needs to distinguish between internal platform traffic and external requests.

**Before (v8.4.0):**

```yaml
# identity/configmap.yaml
data:
  DEPLOYMENT_MODE: {{ .Values.identity.configmap.DEPLOYMENT_MODE | default "local" | quote }}
  TRUSTED_PROXIES: {{ .Values.identity.configmap.TRUSTED_PROXIES | default "" | quote }}
```

**After (v8.5.0):**

```yaml
# identity/configmap.yaml
data:
  DEPLOYMENT_MODE: {{ .Values.identity.configmap.DEPLOYMENT_MODE | default "local" | quote }}
  TRUSTED_PROXIES: {{ .Values.identity.configmap.TRUSTED_PROXIES | default "" | quote }}
  PLATFORM_INTERNAL_CIDRS: {{ .Values.identity.configmap.PLATFORM_INTERNAL_CIDRS | default "" | quote }}
```

**Why this matters:**

- Enables the identity service to apply different security policies for internal vs external traffic
- Supports multi-cluster or multi-zone deployments where internal network ranges need explicit configuration
- Complements the existing `TRUSTED_PROXIES` setting for more granular network trust configuration

**Default behavior:**

If you don't specify `PLATFORM_INTERNAL_CIDRS`, it defaults to an empty string, maintaining backward compatibility. The identity service will continue to function normally without this configuration.

# Configuration Reference

### Platform Internal CIDRs

Configure the internal CIDR ranges for your platform in your `values.yaml`:

```yaml
identity:
  configmap:
    PLATFORM_INTERNAL_CIDRS: "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `PLATFORM_INTERNAL_CIDRS` | `""` (empty) | Comma-separated list of CIDR ranges that represent internal platform networks |

**Example: Single CIDR range**

```yaml
identity:
  configmap:
    PLATFORM_INTERNAL_CIDRS: "10.100.0.0/16"
```

**Example: Multiple CIDR ranges**

```yaml
identity:
  configmap:
    PLATFORM_INTERNAL_CIDRS: "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
```

**Example: Kubernetes cluster network**

```yaml
identity:
  configmap:
    PLATFORM_INTERNAL_CIDRS: "10.244.0.0/16"
```

> **Note:** The format should be standard CIDR notation (e.g., `10.0.0.0/8`). Multiple ranges should be separated by commas without spaces.

> **Important:** Ensure the CIDR ranges you specify accurately represent your internal platform networks. Incorrectly configured ranges may affect how the identity service processes requests from different network sources.

**Common use cases:**

1. **Private cloud deployments:** Specify your private network ranges to distinguish internal service-to-service communication
2. **Multi-cluster setups:** Include all cluster pod and service network CIDRs
3. **Hybrid environments:** Define both on-premises and cloud internal network ranges

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 8.5.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 8.5.0 -n plugin-access-manager
```
