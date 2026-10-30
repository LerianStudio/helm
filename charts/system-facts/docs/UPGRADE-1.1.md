<!-- {% raw %} -->
# Helm Upgrade from v1.0.2 to v1.1.0

This guide covers the upgrade of the `system-facts` Helm chart from version **1.0.2** to **1.1.0**. This is a minor release that introduces support for permission declaration via the Identity Provider (IDP) integration, updates the `lerian-common-helm` dependency, and adds new configuration options for Access Manager Resource Identifier (RI) workflows.

---

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
- **[New Features](#new-features)**
  - [1. Identity Provider (IDP) Integration](#1-identity-provider-idp-integration)
  - [2. Lerian Common Helm Dependency Update](#2-lerian-common-helm-dependency-update)
- **[Configuration Reference](#configuration-reference)**
  - [Global IDP Configuration](#global-idp-configuration)
  - [System Facts IDP Secrets](#system-facts-idp-secrets)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Overview

Version **1.1.0** introduces support for permission declaration via the Identity Provider (IDP) integration. This feature allows the System Facts service to declare its permissions to the Access Manager Identity service at startup, enabling Resource Identifier (RI) workflows for fine-grained access control.

**Key changes:**

- New `global.idp` configuration block for environment-wide IDP settings
- New `system-facts.secrets.IDP_M2M_CLIENT_ID` and `IDP_M2M_CLIENT_SECRET` fields for M2M authentication
- New environment variables `IDP_HOST` and `IDP_DECLARATION_ENABLED` in the ConfigMap
- Updated `lerian-common-helm` dependency from `2.0.0` to `2.4.0`
- Template changes to render IDP configuration and filter IDP-related `extraEnvVars` entries

The IDP integration is **opt-in** and disabled by default. Existing deployments can upgrade without configuration changes. To enable permission declaration, operators must configure the IDP endpoint and provide M2M client credentials.

---

## Breaking Changes

**None.** This is a minor release with no breaking changes. All new features are opt-in and backward compatible.

---

## New Features

### 1. Identity Provider (IDP) Integration

Version 1.1.0 adds support for permission declaration via the Access Manager Identity Provider (IDP). When enabled, the System Facts service declares its permissions to the IDP at startup, allowing the Access Manager to enforce fine-grained access control using Resource Identifiers (RI).

**What changed:**

- New `global.idp` configuration block with `host` and `declarationEnabled` fields
- New `system-facts.secrets.IDP_M2M_CLIENT_ID` and `IDP_M2M_CLIENT_SECRET` fields for M2M authentication
- New environment variables `IDP_HOST` and `IDP_DECLARATION_ENABLED` rendered in the ConfigMap
- Template logic to filter IDP-related `extraEnvVars` entries to avoid duplication

**Why it matters:**

Permission declaration enables the Access Manager to enforce access control policies based on Resource Identifiers (RI). Without this integration, the System Facts service cannot participate in RI-based authorization workflows. This feature is required for environments using the Access Manager Identity service for centralized permission management.

**How to enable:**

The IDP integration is disabled by default. To enable it, configure the IDP endpoint and provide M2M client credentials.

**Configuration:**

```yaml
global:
  idp:
    host: "http://plugin-access-manager-identity:4001"
    declarationEnabled: true

system-facts:
  secrets:
    IDP_M2M_CLIENT_ID: "system-facts-client-id"
    IDP_M2M_CLIENT_SECRET: "system-facts-client-secret"
```

**Environment variables added:**

| Variable | Default | Description |
|----------|---------|-------------|
| `IDP_DECLARATION_ENABLED` | `false` | Enable permission declaration at startup |
| `IDP_HOST` | (empty) | Identity Provider endpoint URL |
| `IDP_M2M_CLIENT_ID` | (empty) | M2M client ID for IDP authentication (secret) |
| `IDP_M2M_CLIENT_SECRET` | (empty) | M2M client secret for IDP authentication (secret) |

> **Note:** The `IDP_DECLARATION_ENABLED` variable is always rendered in the ConfigMap (default `false`). The `IDP_HOST` variable is only rendered when non-empty. The client credentials (`IDP_M2M_CLIENT_ID` and `IDP_M2M_CLIENT_SECRET`) are only rendered in the Secret when non-empty.

**Precedence rules:**

The IDP configuration follows a precedence hierarchy:

1. `system-facts.configmap.IDP_DECLARATION_ENABLED` / `IDP_HOST` (highest priority)
2. `system-facts.extraEnvVars` entries with names `IDP_DECLARATION_ENABLED` / `IDP_HOST`
3. `global.idp.declarationEnabled` / `global.idp.host`
4. Default values (`false` for `IDP_DECLARATION_ENABLED`, empty for `IDP_HOST`)

**Example with global configuration:**

```yaml
global:
  idp:
    host: "http://plugin-access-manager-identity:4001"
    declarationEnabled: true

system-facts:
  secrets:
    IDP_M2M_CLIENT_ID: "system-facts-client-id"
    IDP_M2M_CLIENT_SECRET: "system-facts-client-secret"
```

**Example with per-service override:**

```yaml
global:
  idp:
    host: "http://plugin-access-manager-identity:4001"
    declarationEnabled: true

system-facts:
  configmap:
    IDP_DECLARATION_ENABLED: "false"  # Override global setting
  secrets:
    IDP_M2M_CLIENT_ID: ""
    IDP_M2M_CLIENT_SECRET: ""
```

> **Important:** The `global.idp.declarationEnabled` setting enables permission declaration for **all components** in the release. If you only want to enable it for System Facts, use `system-facts.configmap.IDP_DECLARATION_ENABLED` instead of the global setting.

**Using an existing secret:**

To avoid storing credentials in `values.yaml`, use an existing Kubernetes Secret:

```bash
kubectl create secret generic system-facts-idp-secret \
  --from-literal=IDP_M2M_CLIENT_ID='your-client-id' \
  --from-literal=IDP_M2M_CLIENT_SECRET='your-client-secret' \
  -n system-facts
```

Then reference it in your values:

```yaml
system-facts:
  useExistingSecret: true
  existingSecretName: "system-facts-idp-secret"
```

> **Note:** When using `useExistingSecret`, the existing Secret must contain all required secret keys, including `IDP_M2M_CLIENT_ID` and `IDP_M2M_CLIENT_SECRET` if IDP is enabled.

**Template changes:**

The ConfigMap template now includes logic to render IDP environment variables and filter IDP-related `extraEnvVars` entries:

**Before (v1.0.2):**

```yaml
# Extra Env Vars
{{- with (index .Values "system-facts").extraEnvVars }}
{{- range . }}
{{ .name }}: {{ .value | quote }}
{{- end }}
{{- end }}
```

**After (v1.1.0):**

```yaml
# =============================================================================
# PERMISSION DECLARATION (RI) — lib-auth declaration.WireFromEnv, rendered by
# lerian-common.idp.env. Precedence: system-facts.configmap.<KEY> >
# system-facts.extraEnvVars entry (legacy) > global.idp.<field> > default.
# IDP_DECLARATION_ENABLED is always rendered (default "false"); IDP_HOST only
# when non-empty. extraEnvVars is a name/value list here, so its IDP_* entries
# are folded into a map for the helper and skipped in the passthrough below.
# The client pair (IDP_M2M_CLIENT_ID/SECRET) lives in the Secret.
# =============================================================================
{{- $idpEnvKeys := include "lerian-common.idp.keys" (dict "kind" "env") | fromJsonArray }}
{{- $idpExtra := dict }}
{{- range ((index .Values "system-facts").extraEnvVars | default list) }}
{{- if has .name $idpEnvKeys }}{{- $_ := set $idpExtra .name .value }}{{- end }}
{{- end }}
{{- include "lerian-common.idp.env" (dict "context" $ "configmap" (index .Values "system-facts").configmap "extraEnvVars" $idpExtra) | nindent 2 }}

# Extra Env Vars (IDP_DECLARATION_ENABLED / IDP_HOST here already fed lerian-common.idp.env)
{{- with (index .Values "system-facts").extraEnvVars }}
{{- range . }}
{{- if not (has .name $idpEnvKeys) }}
{{ .name }}: {{ .value | quote }}
{{- end }}
{{- end }}
{{- end }}
```

**Operational impact:**

- The template now filters `extraEnvVars` entries with names `IDP_DECLARATION_ENABLED` or `IDP_HOST` to avoid duplication
- If you previously set IDP variables via `extraEnvVars`, they will now be consumed by the `lerian-common.idp.env` helper instead of being rendered directly
- The behavior is unchanged: the variables are still rendered in the ConfigMap, but the template logic is more robust

The Secret template now includes logic to render IDP client credentials:

**Before (v1.0.2):**

```yaml
stringData:
  {{- range $key, $value := (index .Values "system-facts").secrets }}
  {{- if not (or (and $pgInternal (eq $key "POSTGRES_PASSWORD")) (and $vkInternal (eq $key "REDIS_PASSWORD"))) }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
  {{- end }}
```

**After (v1.1.0):**

```yaml
stringData:
  {{- $idpSecretKeys := include "lerian-common.idp.keys" (dict "kind" "secret") | fromJsonArray }}
  {{- range $key, $value := (index .Values "system-facts").secrets }}
  {{- if not (or (and $pgInternal (eq $key "POSTGRES_PASSWORD")) (and $vkInternal (eq $key "REDIS_PASSWORD")) (has $key $idpSecretKeys)) }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
  {{- end }}
  {{- /* Permission declaration (RI) client pair — lerian-common.idp.secret, each
     key only when non-empty, so it is emitted once and never as an empty value. */}}
  {{- with (include "lerian-common.idp.secret" (dict "secrets" (index .Values "system-facts").secrets "mode" "stringData")) }}
  {{- . | nindent 2 }}
  {{- end }}
```

**Operational impact:**

- The template now filters `IDP_M2M_CLIENT_ID` and `IDP_M2M_CLIENT_SECRET` from the main secrets loop to avoid duplication
- The `lerian-common.idp.secret` helper renders these keys only when non-empty
- If you previously set IDP credentials via `system-facts.secrets`, they will still be rendered, but the template logic is more robust

### 2. Lerian Common Helm Dependency Update

The `lerian-common-helm` dependency has been updated from version `2.0.0` to `2.4.0`. This update includes new helpers for IDP configuration rendering and other improvements.

**Dependency version change:**

| Dependency | v1.0.2 | v1.1.0 |
|------------|--------|--------|
| `lerian-common-helm` | `2.0.0` | `2.4.0` |

**What changed:**

- New `lerian-common.idp.env` helper for rendering IDP environment variables
- New `lerian-common.idp.secret` helper for rendering IDP secret credentials
- New `lerian-common.idp.keys` helper for listing IDP-related keys

**Why it matters:**

The updated dependency provides the template helpers required for IDP integration. Without this update, the IDP configuration would not be rendered correctly.

**How to handle:**

No action required. The dependency update is handled automatically by Helm during the upgrade.

---

## Configuration Reference

### Global IDP Configuration

The `global.idp` block configures the Identity Provider endpoint and permission declaration behavior for all components in the release.

**Fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `global.idp.host` | string | (empty) | Identity Provider endpoint URL |
| `global.idp.declarationEnabled` | boolean | `false` | Enable permission declaration at startup |

**Example:**

```yaml
global:
  idp:
    host: "http://plugin-access-manager-identity:4001"
    declarationEnabled: true
```

> **Important:** Setting `global.idp.declarationEnabled: true` enables permission declaration for **all components** in the release. If you only want to enable it for System Facts, use `system-facts.configmap.IDP_DECLARATION_ENABLED` instead.

### System Facts IDP Secrets

The `system-facts.secrets` block now includes fields for IDP M2M client credentials.

**New fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `system-facts.secrets.IDP_M2M_CLIENT_ID` | string | (empty) | M2M client ID for IDP authentication |
| `system-facts.secrets.IDP_M2M_CLIENT_SECRET` | string | (empty) | M2M client secret for IDP authentication |

**Example:**

```yaml
system-facts:
  secrets:
    IDP_M2M_CLIENT_ID: "system-facts-client-id"
    IDP_M2M_CLIENT_SECRET: "system-facts-client-secret"
```

> **Note:** These credentials are only rendered in the Secret when non-empty. If you do not enable IDP, you can leave these fields empty or omit them entirely.

**Using an existing secret:**

```yaml
system-facts:
  useExistingSecret: true
  existingSecretName: "system-facts-idp-secret"
```

The existing Secret must contain the following keys (if IDP is enabled):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: system-facts-idp-secret
type: Opaque
stringData:
  IDP_M2M_CLIENT_ID: "system-facts-client-id"
  IDP_M2M_CLIENT_SECRET: "system-facts-client-secret"
  POSTGRES_PASSWORD: "your-postgres-password"
  REDIS_PASSWORD: "your-redis-password"
```

---

## Migration Steps

This is a minor release with no breaking changes. Existing deployments can upgrade without configuration changes. The IDP integration is opt-in and disabled by default.

### Step 1: Review current configuration

Verify your current chart version:

```bash
helm list -n system-facts
```

Expected output should show version `1.0.2`.

### Step 2: Decide whether to enable IDP

If you want to enable permission declaration, prepare the IDP configuration and M2M client credentials. If you do not need IDP, proceed to Step 3.

**To enable IDP:**

1. Obtain the Identity Provider endpoint URL (e.g., `http://plugin-access-manager-identity:4001`)
2. Obtain M2M client credentials from your Access Manager administrator
3. Create a Kubernetes Secret or update your `values.yaml` with the credentials

**Create a secret:**

```bash
kubectl create secret generic system-facts-idp-secret \
  --from-literal=IDP_M2M_CLIENT_ID='your-client-id' \
  --from-literal=IDP_M2M_CLIENT_SECRET='your-client-secret' \
  --from-literal=POSTGRES_PASSWORD='your-postgres-password' \
  --from-literal=REDIS_PASSWORD='your-redis-password' \
  -n system-facts
```

**Update your values:**

```yaml
global:
  idp:
    host: "http://plugin-access-manager-identity:4001"
    declarationEnabled: true

system-facts:
  useExistingSecret: true
  existingSecretName: "system-facts-idp-secret"
```

### Step 3: Apply the upgrade

Upgrade to version `1.1.0` using your existing values:

```bash
helm upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm \
  --version 1.1.0 \
  --namespace system-facts \
  --reuse-values
```

> **Note:** If you are enabling IDP, use `--values values.yaml` instead of `--reuse-values` to apply the new configuration.

**With IDP enabled:**

```bash
helm upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm \
  --version 1.1.0 \
  --namespace system-facts \
  --values values.yaml
```

### Step 4: Verify the upgrade

Confirm the chart version was updated:

```bash
helm list -n system-facts
```

Expected output should show version `1.1.0`.

Verify that all pods are healthy:

```bash
kubectl get pods -n system-facts
```

> **Note:** If you enabled IDP, Kubernetes will recreate the pods to apply the new ConfigMap and Secret. If you did not enable IDP, the upgrade completes without pod restarts (only the chart metadata changes).

### Step 5: Verify IDP configuration (if enabled)

If you enabled IDP, verify that the environment variables are set correctly:

```bash
kubectl exec -n system-facts deployment/system-facts -- env | grep IDP
```

Expected output:

```
IDP_DECLARATION_ENABLED=true
IDP_HOST=http://plugin-access-manager-identity:4001
IDP_M2M_CLIENT_ID=system-facts-client-id
IDP_M2M_CLIENT_SECRET=system-facts-client-secret
```

Check the application logs for permission declaration activity:

```bash
kubectl logs -n system-facts deployment/system-facts | grep -i "permission\|declaration\|idp"
```

---

## Preview changes before upgrading

```bash
helm diff upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm --version 1.1.0 -n system-facts
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm --version 1.1.0 -n system-facts
```
<!-- {% endraw %} -->
