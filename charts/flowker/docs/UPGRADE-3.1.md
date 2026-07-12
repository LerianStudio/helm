# Helm Upgrade from v3.0.0 to v3.1.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. WorkOS M2M client secret for Tenant Manager authentication](#1-workos-m2m-client-secret-for-tenant-manager-authentication)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `flowker` chart upgrade from `3.0.0` to `3.1.0`. This is a **minor version bump** with no breaking changes. The application image (`appVersion: 1.0.0`) is unchanged, and the chart adds optional support for WorkOS machine-to-machine (M2M) authentication when Flowker calls the Tenant Manager service.

The upgrade is **transparent**: all new configuration is optional and disabled by default. Existing deployments can upgrade without any values changes. The new `WORKOS_TM_CLIENT_SECRET` setting is only required if you are enabling WorkOS-based authentication for outbound calls to the Tenant Manager.

## Features

### 1. WorkOS M2M client secret for Tenant Manager authentication

The chart now supports WorkOS machine-to-machine (M2M) authentication for outbound calls from Flowker to the Tenant Manager service. This allows Flowker to mint WorkOS tokens when calling the Tenant Manager API, providing stronger authentication than static API keys.

**New secret variable:**

```yaml
flowker:
  secrets:
    # -- WorkOS M2M client secret for the outbound token flowker mints to call
    # the Tenant Manager (emitted only when set)
    WORKOS_TM_CLIENT_SECRET: ""
```

The secret is conditionally emitted in the `secrets.yaml` template:

**After (v3.1.0):**

```yaml
# WorkOS M2M client secret (outbound token flowker mints to call the Tenant Manager)
{{- if .Values.flowker.secrets.WORKOS_TM_CLIENT_SECRET }}
WORKOS_TM_CLIENT_SECRET: {{ .Values.flowker.secrets.WORKOS_TM_CLIENT_SECRET | quote }}
{{- end }}
```

> **Note:** This secret is only emitted when explicitly set. If left empty (the default), the application will not use WorkOS authentication for Tenant Manager calls and will fall back to the existing `MULTI_TENANT_SERVICE_API_KEY` authentication mechanism.

**When to use this setting:**

- You are running Flowker in multi-tenant mode (`MULTI_TENANT_ENABLED: "true"`)
- Your Tenant Manager service is configured to accept WorkOS M2M tokens
- You want to replace static API key authentication with WorkOS-based token authentication

**To enable WorkOS M2M authentication:**

```yaml
flowker:
  secrets:
    WORKOS_TM_CLIENT_SECRET: "your-workos-m2m-client-secret"
```

> **Important:** When `WORKOS_TM_CLIENT_SECRET` is set, Flowker will mint WorkOS tokens for outbound calls to the Tenant Manager. Ensure your Tenant Manager service is configured to validate WorkOS tokens before enabling this setting.

**Relationship to existing authentication:**

The `WORKOS_TM_CLIENT_SECRET` is an alternative to `MULTI_TENANT_SERVICE_API_KEY`. Both provide authentication for Flowker → Tenant Manager calls:

| Setting | Authentication Method | Use Case |
|---------|----------------------|----------|
| `MULTI_TENANT_SERVICE_API_KEY` | Static API key | Simple authentication, existing deployments |
| `WORKOS_TM_CLIENT_SECRET` | WorkOS M2M token | Token-based authentication, WorkOS-enabled environments |

> **Note:** If both are set, the application behavior depends on the Flowker implementation. Consult your Flowker documentation for precedence rules. In most cases, you should set only one of these values.

## Configuration Reference

### New Secret Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WORKOS_TM_CLIENT_SECRET` | `""` | WorkOS M2M client secret for outbound token Flowker mints to call the Tenant Manager (optional) |

### Template Changes

The `secrets.yaml` template now includes a conditional block for the WorkOS M2M client secret:

**Before (v3.0.0):**

```yaml
stringData:
  # ... existing secrets ...

  # API key (when API_KEY_ENABLED=true)
  {{- if .Values.flowker.secrets.API_KEY }}
  API_KEY: {{ .Values.flowker.secrets.API_KEY | quote }}
  {{- end }}
```

**After (v3.1.0):**

```yaml
stringData:
  # ... existing secrets ...

  # WorkOS M2M client secret (outbound token flowker mints to call the Tenant Manager)
  {{- if .Values.flowker.secrets.WORKOS_TM_CLIENT_SECRET }}
  WORKOS_TM_CLIENT_SECRET: {{ .Values.flowker.secrets.WORKOS_TM_CLIENT_SECRET | quote }}
  {{- end }}

  # API key (when API_KEY_ENABLED=true)
  {{- if .Values.flowker.secrets.API_KEY }}
  API_KEY: {{ .Values.flowker.secrets.API_KEY | quote }}
  {{- end }}
```

## Migration Steps

No migration steps are required for this upgrade. The new `WORKOS_TM_CLIENT_SECRET` setting is optional and disabled by default.

### Optional: Enable WorkOS M2M authentication

If you want to enable WorkOS-based authentication for Tenant Manager calls:

**Step 1: Obtain WorkOS M2M client secret**

Contact your WorkOS administrator or create a new M2M client in the WorkOS dashboard. You will receive a client secret.

**Step 2: Add the secret to your values file**

```yaml
flowker:
  secrets:
    WORKOS_TM_CLIENT_SECRET: "your-workos-m2m-client-secret"
```

**Step 3: Verify Tenant Manager configuration**

Ensure your Tenant Manager service is configured to validate WorkOS M2M tokens. Consult your Tenant Manager documentation for configuration details.

**Step 4: Upgrade the chart**

```bash
helm upgrade flowker oci://registry-1.docker.io/lerianstudio/flowker-helm \
  --version 3.1.0 \
  -n flowker \
  -f flowker-values.yaml
```

**Step 5: Verify the deployment**

```bash
# Check rollout status
kubectl rollout status -n flowker deploy/flowker

# Check that the secret is present
kubectl get secret -n flowker flowker-secrets -o jsonpath='{.data.WORKOS_TM_CLIENT_SECRET}' | base64 -d

# Check application logs for WorkOS authentication
kubectl logs -n flowker -l app.kubernetes.io/name=flowker --tail=50 | grep -i workos
```

## Preview changes before upgrading

```bash
helm diff upgrade flowker oci://registry-1.docker.io/lerianstudio/flowker-helm --version 3.1.0 -n flowker
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade flowker oci://registry-1.docker.io/lerianstudio/flowker-helm --version 3.1.0 -n flowker
```
