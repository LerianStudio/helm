# Helm Upgrade from v8.5.0 to v8.6.0

# Topics

- **[Features](#features)**
  - [1. Platform Internal CIDR Configuration](#1-platform-internal-cidr-configuration)
  - [2. CIDR Consistency Validation](#2-cidr-consistency-validation)
- **[Configuration Reference](#configuration-reference)**
  - [Auth Service PLATFORM_INTERNAL_CIDRS](#auth-service-platform_internal_cidrs)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Features

### 1. Platform Internal CIDR Configuration

This release introduces a new environment variable `PLATFORM_INTERNAL_CIDRS` to the auth service ConfigMap. This variable allows you to define internal network ranges that should be trusted by the platform.

**What changed:**

A new configuration field has been added to the auth service:

```yaml
auth:
  configmap:
    PLATFORM_INTERNAL_CIDRS: ""
```

**Why this matters:**

The `PLATFORM_INTERNAL_CIDRS` setting is critical for environments that use proxy-fronted deployments. It defines which IP address ranges are considered internal to your platform infrastructure. When properly configured, this prevents unauthorized access by ensuring that only requests from legitimate internal sources are trusted.

**Default behavior:**

The default value is an empty string (`""`), which means no internal CIDRs are configured. You should set this value if your deployment uses internal network segmentation or proxy infrastructure.

**Before (v8.5.0):**

```yaml
# auth/configmap.yaml - PLATFORM_INTERNAL_CIDRS not present
data:
  DEPLOYMENT_MODE: {{ .Values.auth.configmap.DEPLOYMENT_MODE | default "local" | quote }}
  TRUSTED_PROXIES: {{ .Values.auth.configmap.TRUSTED_PROXIES | default "" | quote }}
  SWAGGER_ENABLED: {{ .Values.auth.configmap.SWAGGER_ENABLED | default "true" | quote }}
```

**After (v8.6.0):**

```yaml
# auth/configmap.yaml - PLATFORM_INTERNAL_CIDRS added
data:
  DEPLOYMENT_MODE: {{ .Values.auth.configmap.DEPLOYMENT_MODE | default "local" | quote }}
  TRUSTED_PROXIES: {{ .Values.auth.configmap.TRUSTED_PROXIES | default "" | quote }}
  PLATFORM_INTERNAL_CIDRS: {{ .Values.auth.configmap.PLATFORM_INTERNAL_CIDRS | default "" | quote }}
  SWAGGER_ENABLED: {{ .Values.auth.configmap.SWAGGER_ENABLED | default "true" | quote }}
```

### 2. CIDR Consistency Validation

The chart now includes a built-in validation check that ensures `PLATFORM_INTERNAL_CIDRS` is configured identically across both the identity and auth services.

**What changed:**

A new template validation block has been added at the top of the auth ConfigMap template:

```yaml
{{- $idCidrs := .Values.identity.configmap.PLATFORM_INTERNAL_CIDRS | default "" -}}
{{- $authCidrs := .Values.auth.configmap.PLATFORM_INTERNAL_CIDRS | default "" -}}
{{- if ne $idCidrs $authCidrs -}}
{{- fail "PLATFORM_INTERNAL_CIDRS must be identical on identity.configmap and auth.configmap: a skew leaks the platform ranges into the enforcement entry set, which on proxy-fronted environments allows everyone" -}}
{{- end -}}
```

**Why this matters:**

If the `PLATFORM_INTERNAL_CIDRS` values differ between the identity and auth services, it creates a security vulnerability. The mismatch can leak platform IP ranges into the enforcement entry set, which in proxy-fronted environments would allow unauthorized access from any source.

**What happens during upgrade:**

- If you have different values for `identity.configmap.PLATFORM_INTERNAL_CIDRS` and `auth.configmap.PLATFORM_INTERNAL_CIDRS`, the Helm upgrade will **fail immediately** with a clear error message
- If both values are identical (including both being empty/unset), the upgrade will proceed normally
- This is a **fail-fast validation** that prevents misconfiguration before any resources are applied

> **Important:** This validation runs during Helm template rendering. If the check fails, no Kubernetes resources will be modified, and your existing deployment will remain unchanged.

# Configuration Reference

### Auth Service PLATFORM_INTERNAL_CIDRS

Configure the platform internal CIDR ranges in your `values.yaml`:

```yaml
auth:
  configmap:
    PLATFORM_INTERNAL_CIDRS: "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"

identity:
  configmap:
    PLATFORM_INTERNAL_CIDRS: "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `auth.configmap.PLATFORM_INTERNAL_CIDRS` | `""` | Comma-separated list of CIDR ranges that represent internal platform networks. Must match identity service value exactly. |
| `identity.configmap.PLATFORM_INTERNAL_CIDRS` | `""` | Comma-separated list of CIDR ranges that represent internal platform networks. Must match auth service value exactly. |

**Example: Configuring for private network ranges**

```yaml
auth:
  configmap:
    PLATFORM_INTERNAL_CIDRS: "10.0.0.0/8,172.16.0.0/12"

identity:
  configmap:
    PLATFORM_INTERNAL_CIDRS: "10.0.0.0/8,172.16.0.0/12"
```

**Example: Configuring for cloud provider internal networks**

```yaml
auth:
  configmap:
    PLATFORM_INTERNAL_CIDRS: "10.100.0.0/16,10.200.0.0/16"

identity:
  configmap:
    PLATFORM_INTERNAL_CIDRS: "10.100.0.0/16,10.200.0.0/16"
```

> **Warning:** The values for `auth.configmap.PLATFORM_INTERNAL_CIDRS` and `identity.configmap.PLATFORM_INTERNAL_CIDRS` **must be identical**. Any mismatch will cause the Helm upgrade to fail with a validation error.

> **Note:** If you don't use proxy-fronted deployments or internal network segmentation, you can leave this value as the default empty string.

# Migration Steps

Follow these steps to safely upgrade from v8.5.0 to v8.6.0:

**Step 1: Review your current configuration**

Check if you have `PLATFORM_INTERNAL_CIDRS` configured in either service:

```bash
helm get values plugin-access-manager -n plugin-access-manager
```

**Step 2: Determine your CIDR configuration**

Choose one of the following options based on your deployment:

#### Option 1: No internal network segmentation

If your deployment does not use proxy-fronted infrastructure or internal network segmentation, no action is required. Both services will use the default empty value.

#### Option 2: Configure internal CIDRs

If your deployment uses proxy-fronted infrastructure or internal network segmentation, add the `PLATFORM_INTERNAL_CIDRS` configuration to your `values.yaml`:

```yaml
auth:
  configmap:
    PLATFORM_INTERNAL_CIDRS: "your-cidr-ranges-here"

identity:
  configmap:
    PLATFORM_INTERNAL_CIDRS: "your-cidr-ranges-here"
```

> **Important:** Ensure both values are **exactly identical**. Even whitespace differences will cause the validation to fail.

**Step 3: Validate your configuration locally**

Before upgrading, test your configuration with a dry-run:

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager \
  --version 8.6.0 \
  -n plugin-access-manager \
  --dry-run \
  --debug
```

If the validation fails, you will see an error message:

```
Error: INSTALLATION FAILED: template: plugin-access-manager/templates/auth/configmap.yaml:4:3: executing "plugin-access-manager/templates/auth/configmap.yaml" at <fail "PLATFORM_INTERNAL_CIDRS must be identical on identity.configmap and auth.configmap: a skew leaks the platform ranges into the enforcement entry set, which on proxy-fronted environments allows everyone">: error calling fail: PLATFORM_INTERNAL_CIDRS must be identical on identity.configmap and auth.configmap: a skew leaks the platform ranges into the enforcement entry set, which on proxy-fronted environments allows everyone
```

**Step 4: Proceed with the upgrade**

Once your configuration passes validation, proceed with the upgrade using the command in the [Command to upgrade](#command-to-upgrade) section.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 8.6.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 8.6.0 -n plugin-access-manager
```
