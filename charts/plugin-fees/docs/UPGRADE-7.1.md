# Helm Upgrade from v7.0.0 to v7.1.0

# Topics

- ***[Features](#features)***
    - [1. Rate Limiting Control](#1-rate-limiting-control)
- ***[Application Version Update](#application-version-update)***
- ***[Configuration Reference](#configuration-reference)***
- ***[Preview changes before upgrading](#preview-changes-before-upgrading)***
- ***[Command to upgrade](#command-to-upgrade)***

# Features

### 1. Rate Limiting Control

A new configuration variable has been added to enable or disable rate limiting functionality at runtime.

**New ConfigMap variable:**

```yaml
fees:
  configmap:
    RATE_LIMIT_ENABLED: "true"
```

| Variable | Default | Description |
|----------|---------|-------------|
| `RATE_LIMIT_ENABLED` | `"true"` | Controls whether rate limiting is active for API requests |

**Why this matters:**

This flag provides operators with the ability to disable rate limiting without modifying the `RATE_LIMIT_MAX` or `RATE_LIMIT_WINDOW_SECONDS` values. This is useful for:

- Testing and debugging scenarios where rate limits interfere with load testing
- Temporary disabling during maintenance windows or data migrations
- Environments where rate limiting is handled by external infrastructure (API gateways, ingress controllers)

**Example: Disabling rate limiting**

```yaml
fees:
  configmap:
    RATE_LIMIT_ENABLED: "false"
    RATE_LIMIT_MAX: "100"
    RATE_LIMIT_WINDOW_SECONDS: "60"
```

**Example: Keeping rate limiting enabled with custom limits**

```yaml
fees:
  configmap:
    RATE_LIMIT_ENABLED: "true"
    RATE_LIMIT_MAX: "200"
    RATE_LIMIT_WINDOW_SECONDS: "30"
```

> **Note:** When `RATE_LIMIT_ENABLED` is set to `"false"`, the application will not enforce any rate limits regardless of the `RATE_LIMIT_MAX` and `RATE_LIMIT_WINDOW_SECONDS` values.

# Application Version Update

The application version has been updated from 3.2.0 to 3.3.0, and the default image tag has been updated accordingly.

| Setting | v7.0.0 | v7.1.0 |
|---------|--------|--------|
| Chart version | 7.0.0 | 7.1.0 |
| Application version | 3.2.0 | 3.3.0 |
| Default image tag | 3.2.1 | 3.3.0 |

**Before (v7.0.0):**

```yaml
fees:
  image:
    tag: "3.2.1"
```

**After (v7.1.0):**

```yaml
fees:
  image:
    tag: "3.3.0"
```

**Migration impact:**

- The new image version will be pulled automatically during upgrade
- If you have pinned a specific image tag in your values.yaml, review whether you want to continue using that version or adopt the new default
- The application version 3.3.0 includes the rate limiting control feature described above

> **Important:** If you are using a custom image tag, ensure it is compatible with the new chart version and includes support for the `RATE_LIMIT_ENABLED` configuration variable.

# Configuration Reference

**Complete example with v7.1.0 rate limiting configuration:**

```yaml
fees:
  image:
    repository: lerianstudio/plugin-fees
    pullPolicy: Always
    tag: "3.3.0"
  
  configmap:
    # Rate limiting configuration
    RATE_LIMIT_ENABLED: "true"
    RATE_LIMIT_MAX: "100"
    RATE_LIMIT_WINDOW_SECONDS: "60"
```

**Example: Production environment with rate limiting disabled**

```yaml
fees:
  configmap:
    RATE_LIMIT_ENABLED: "false"
    RATE_LIMIT_MAX: "500"
    RATE_LIMIT_WINDOW_SECONDS: "60"
```

# Preview changes before upgrading

```bash
helm diff upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 7.1.0 -n plugin-fees
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 7.1.0 -n plugin-fees
```
