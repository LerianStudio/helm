# Helm Upgrade from v4.0.6 to v4.1.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. New optional configuration keys with explicit declarations](#1-new-optional-configuration-keys-with-explicit-declarations)
  - [2. Validation to prevent duplicate key definitions](#2-validation-to-prevent-duplicate-key-definitions)
- **[Configuration Reference](#configuration-reference)**
  - [Optional configuration keys](#optional-configuration-keys)
  - [Migration from extraEnvVars](#migration-from-extraenvvars)
- **[Migration Steps](#migration-steps)**
  - [Option 1: Keep existing extraEnvVars configuration (no action required)](#option-1-keep-existing-extraenvvars-configuration-no-action-required)
  - [Option 2: Migrate to the new configmap declarations](#option-2-migrate-to-the-new-configmap-declarations)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that introduces explicit declarations for optional configuration keys previously only accessible through `extraEnvVars`. The chart now provides first-class support for `TRUSTED_PROXIES`, `PLUGIN_AUTH_PUBLIC_BASE_PATH`, `MFA_ENABLED`, `FLOWKER_BASE_PATH`, and `TRACER_BASE_PATH` under the `configmap` values block, with comprehensive documentation explaining their purpose and safe defaults.

| Field | v4.0.6 | v4.1.0 |
|-------|--------|--------|
| Chart version | `4.0.6` | `4.1.0` |
| App version | `1.12.0` | `1.12.0` |

**Key changes:**

- Five optional configuration keys moved from undocumented `extraEnvVars` usage to explicit `configmap` declarations
- New validation logic prevents accidental duplicate key definitions across `configmap` and `extraEnvVars`
- Extensive inline documentation added to `values.yaml` explaining each optional key's purpose, risks, and when to set it
- Backward compatibility maintained: existing `extraEnvVars` configurations continue to work unchanged

> **Important:** This release does NOT change application behavior or require configuration changes. It provides a safer, more discoverable way to configure optional features while preserving full backward compatibility with existing deployments.

## Features

### 1. New optional configuration keys with explicit declarations

The chart now declares five optional configuration keys under `configmap` that previously could only be set through `extraEnvVars`. These keys ship with **no default values** because no safe default exists for them — they represent deployment-specific addresses, infrastructure topology, or feature flags that operators must consciously configure.

**New configmap keys:**

| Key | Purpose | Required |
|-----|---------|----------|
| `TRUSTED_PROXIES` | CIDR list of infrastructure hops for X-Forwarded-For parsing | Recommended for production |
| `PLUGIN_AUTH_PUBLIC_BASE_PATH` | Browser-facing Access Manager address for SSO redirects | Required for SSO |
| `MFA_ENABLED` | Deployment-wide assertion that Access Manager has MFA enabled | Required when MFA is on |
| `FLOWKER_BASE_PATH` | Address of optional Flowker service | Optional |
| `TRACER_BASE_PATH` | Address of optional Tracer service | Optional |

**Before (v4.0.6):**

These keys were only reachable through `extraEnvVars`, with minimal documentation:

```yaml
extraEnvVars:
  TRUSTED_PROXIES: "198.51.100.0/24"
  PLUGIN_AUTH_PUBLIC_BASE_PATH: "https://auth.example.com/v1"
  MFA_ENABLED: "true"
```

**After (v4.1.0):**

The same keys can now be declared under `configmap` with full inline documentation:

```yaml
configmap:
  TRUSTED_PROXIES: "198.51.100.0/24"
  PLUGIN_AUTH_PUBLIC_BASE_PATH: "https://auth.example.com/v1"
  MFA_ENABLED: "true"
  FLOWKER_BASE_PATH: "http://flowker.flowker.svc.cluster.local:4021/v1"
  TRACER_BASE_PATH: "http://midaz-tracer.midaz.svc.cluster.local:4020"
```

**Operational impact:**

- Operators gain discoverability: the keys are now visible in `values.yaml` with detailed explanations of what they control and when to set them
- The chart refuses to render if a key is set in both `configmap` and `extraEnvVars`, preventing undefined behavior from duplicate YAML keys
- Existing deployments using `extraEnvVars` for these keys continue to work without modification
- New deployments should prefer `configmap` for these keys to benefit from validation and documentation

> **Note:** The chart emits these keys into the ConfigMap **only when set**. An unset key means the console falls back to its own built-in default, which for addresses means "feature not available" rather than "wrong address." This prevents connection errors on pages for optional services not installed in your cluster.

### 2. Validation to prevent duplicate key definitions

The chart now validates at render time that optional configuration keys are not defined in both `configmap` and `extraEnvVars`. Both blocks write into the same ConfigMap `data` map, so a duplicate key would be emitted twice and the surviving value would be whichever one the YAML parser kept last — undefined behavior.

**Validation logic:**

The new `product-console.validateOptionalConfigKeys` template helper checks all five optional keys and fails the render with a descriptive error if any key appears in both places.

**Example error message:**

```
Error: FAILED: template: product-console/templates/configmap.yaml:6:4: executing "product-console/templates/configmap.yaml" at <include "product-console.validateOptionalConfigKeys" .>: error calling include: template: product-console/templates/_helpers.tpl:227:6: executing "product-console.validateOptionalConfigKeys" at <fail (printf "%s is set both in configmap and in extraEnvVars. Both render into the same ConfigMap data map, so the key would be emitted twice and the effective value is whatever the YAML parser keeps - undefined behavior. Keep it in configmap.%s and remove it from extraEnvVars." $key $key)>: TRUSTED_PROXIES is set both in configmap and in extraEnvVars. Both render into the same ConfigMap data map, so the key would be emitted twice and the effective value is whatever the YAML parser keeps - undefined behavior. Keep it in configmap.TRUSTED_PROXIES and remove it from extraEnvVars.
```

**Operational impact:**

- Prevents silent misconfigurations where operators accidentally set the same key in two places
- Forces a conscious choice: use `configmap` (recommended) or `extraEnvVars` (backward compatibility), but not both
- Existing deployments using only `extraEnvVars` are unaffected — validation only triggers when a key exists in both blocks

> **Warning:** If you currently set any of the five optional keys in `extraEnvVars` and attempt to also set them in `configmap`, the Helm render will fail. Choose one location and remove the duplicate.

## Configuration Reference

### Optional configuration keys

The following keys are now declared under `configmap` in `values.yaml`. Each ships with **no default value** and is emitted into the ConfigMap only when explicitly set by the operator.

#### TRUSTED_PROXIES

**Type:** String (comma-separated CIDR list)  
**Default:** Unset (console names no caller at all)  
**Purpose:** Tells the console which IP ranges to trust as its own infrastructure hops when parsing `X-Forwarded-For` headers to determine the real client IP.

**Example:**

```yaml
configmap:
  TRUSTED_PROXIES: "198.51.100.0/24,203.0.113.0/24"
```

**When to set:**

- **Required for production** if you use tenant IP allowlists or need accurate client IP logging
- Set it to the CIDR ranges of your ingress controllers or load balancers — the actual infrastructure in front of the `product-console` service
- **Never** set it to the pod CIDR or service CIDR — that would trust all cluster traffic as infrastructure

**Risks if misconfigured:**

- **Unset:** The console cannot determine the real client IP, so tenant IP allowlists either block everyone or allow everyone
- **Set too broadly (e.g. to a range covering real clients):** Clients can spoof their IP by setting `X-Forwarded-For`, bypassing IP-based access controls

> **Important:** Read the README section "Client IP resolution" before choosing a CIDR range. Incorrect configuration can create security vulnerabilities.

#### PLUGIN_AUTH_PUBLIC_BASE_PATH

**Type:** String (absolute HTTPS URL ending in `/v1`)  
**Default:** Unset (console falls back to `PLUGIN_AUTH_BASE_PATH`, which is cluster-internal)  
**Purpose:** The **browser-facing** address of the Access Manager, used for SSO redirects. This is distinct from `PLUGIN_AUTH_BASE_PATH`, which is the cluster-internal address the console calls server-to-server.

**Example:**

```yaml
configmap:
  PLUGIN_AUTH_PUBLIC_BASE_PATH: "https://auth.example.com/v1"
```

**When to set:**

- **Required for SSO** in any environment where the browser cannot resolve cluster-internal DNS names
- Must be an absolute URL with `https` scheme and end in `/v1`
- Only local development (where both browser and console use `localhost`) can leave it unset

**Risks if unset:**

- SSO redirects send the user's browser to the cluster-internal address (e.g. `http://plugin-access-manager-auth.plugin-access-manager.svc.cluster.local:4000/v1`)
- The browser cannot resolve the hostname, and every SSO login fails with a DNS error

#### MFA_ENABLED

**Type:** String (`"true"` or unset)  
**Default:** Unset (console assumes MFA is off)  
**Purpose:** A deployment-wide assertion that the Access Manager in front of this console may respond to a correct password with an MFA challenge. This does **not** enable MFA for any user — that is per-user configuration in the Access Manager.

**Example:**

```yaml
configmap:
  MFA_ENABLED: "true"
```

**When to set:**

- **Required when MFA is enabled** in the Access Manager for any user
- Leave unset when MFA is off for all users

**Risks if misconfigured:**

- **Unset when MFA is on:** The console does not recognize the MFA challenge response, and users with MFA enabled cannot sign in at all
- **Set when MFA is off:** No operational impact — the console expects MFA challenges that never arrive

#### FLOWKER_BASE_PATH

**Type:** String (cluster-internal URL ending in `/v1`)  
**Default:** Unset (console does not call Flowker)  
**Purpose:** Address of the optional Flowker service. Unlike the ledger and Access Manager, Flowker is an optional deployment.

**Example:**

```yaml
configmap:
  FLOWKER_BASE_PATH: "http://flowker.flowker.svc.cluster.local:4021/v1"
```

**When to set:**

- Only when Flowker is deployed in your cluster
- Set it to the Flowker service's FQDN and port, ending in `/v1`

**Why no default:**

- A default address would make the console attempt to call a service that may not exist, turning "feature not installed" into a connection error on the page
- Unset, the console simply does not offer Flowker-dependent features

#### TRACER_BASE_PATH

**Type:** String (cluster-internal origin, **no `/v1` suffix**)  
**Default:** Unset (console does not call Tracer)  
**Purpose:** Address of the optional Tracer service. Unlike the ledger and Access Manager, Tracer is an optional deployment.

**Example:**

```yaml
configmap:
  TRACER_BASE_PATH: "http://midaz-tracer.midaz.svc.cluster.local:4020"
```

**When to set:**

- Only when Tracer is deployed in your cluster
- Set it to the Tracer service's FQDN and port, **without** a `/v1` suffix — the console adds that itself

**Why no default:**

- Same reasoning as `FLOWKER_BASE_PATH`: a default would cause connection errors for a service that may not be installed

> **Note:** `TRACER_BASE_PATH` is a bare origin (scheme + host + port) with no path. This differs from `FLOWKER_BASE_PATH`, which ends in `/v1`. The console appends `/v1` when calling Tracer.

### Migration from extraEnvVars

Existing deployments that set any of the five optional keys through `extraEnvVars` do not need to change. The chart continues to accept them from `extraEnvVars` and will emit them into the ConfigMap exactly as before.

**Current configuration (still works in v4.1.0):**

```yaml
extraEnvVars:
  TRUSTED_PROXIES: "198.51.100.0/24"
  PLUGIN_AUTH_PUBLIC_BASE_PATH: "https://auth.example.com/v1"
  MFA_ENABLED: "true"
```

**Recommended configuration (v4.1.0 and later):**

```yaml
configmap:
  TRUSTED_PROXIES: "198.51.100.0/24"
  PLUGIN_AUTH_PUBLIC_BASE_PATH: "https://auth.example.com/v1"
  MFA_ENABLED: "true"
```

**Benefits of migrating to `configmap`:**

- Inline documentation in `values.yaml` explains each key's purpose and risks
- Validation prevents duplicate definitions across `configmap` and `extraEnvVars`
- Consistent location for all console configuration (other keys like `ALLOWED_ORIGINS`, `PLUGIN_AUTH_BASE_PATH` are already under `configmap`)

> **Important:** Do not set the same key in both `configmap` and `extraEnvVars`. The chart will refuse to render with a descriptive error message.

## Migration Steps

This upgrade requires no mandatory configuration changes. Existing deployments will continue to work unchanged. Operators may optionally migrate optional keys from `extraEnvVars` to `configmap` to benefit from validation and documentation.

### Option 1: Keep existing extraEnvVars configuration (no action required)

If your current `values.yaml` sets any of the five optional keys through `extraEnvVars`, you can upgrade without modification. The chart continues to accept them from `extraEnvVars`.

**Current values.yaml:**

```yaml
extraEnvVars:
  TRUSTED_PROXIES: "198.51.100.0/24"
  PLUGIN_AUTH_PUBLIC_BASE_PATH: "https://auth.example.com/v1"
  MFA_ENABLED: "true"
```

**Action:** None. Run the upgrade command and verify the deployment rolls successfully.

### Option 2: Migrate to the new configmap declarations

If you want to adopt the new `configmap` declarations for better discoverability and validation, follow these steps:

1. **Identify which optional keys you currently set** in `extraEnvVars`:

```bash
helm get values product-console -n product-console | grep -A10 extraEnvVars
```

2. **Move those keys to the `configmap` block** in your values override file:

**Before:**

```yaml
extraEnvVars:
  TRUSTED_PROXIES: "198.51.100.0/24"
  PLUGIN_AUTH_PUBLIC_BASE_PATH: "https://auth.example.com/v1"
  MFA_ENABLED: "true"
  CUSTOM_VAR: "custom-value"
```

**After:**

```yaml
configmap:
  TRUSTED_PROXIES: "198.51.100.0/24"
  PLUGIN_AUTH_PUBLIC_BASE_PATH: "https://auth.example.com/v1"
  MFA_ENABLED: "true"

extraEnvVars:
  CUSTOM_VAR: "custom-value"
```

> **Note:** Only move the five optional keys (`TRUSTED_PROXIES`, `PLUGIN_AUTH_PUBLIC_BASE_PATH`, `MFA_ENABLED`, `FLOWKER_BASE_PATH`, `TRACER_BASE_PATH`). Leave any other custom environment variables in `extraEnvVars`.

3. **Preview the changes** using the helm-diff plugin:

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.1.0 -n product-console -f your-values.yaml
```

4. **Verify the ConfigMap diff** shows the keys moving from `extraEnvVars` to the explicit declarations, with no change in effective values.

5. **Run the upgrade**:

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.1.0 -n product-console -f your-values.yaml
```

6. **Verify the deployment rolls successfully**:

```bash
kubectl rollout status deployment/product-console -n product-console
```

7. **Confirm the ConfigMap contains the expected keys**:

```bash
kubectl get configmap product-console -n product-console -o yaml | grep -E "TRUSTED_PROXIES|PLUGIN_AUTH_PUBLIC_BASE_PATH|MFA_ENABLED"
```

> **Warning:** If you accidentally set a key in both `configmap` and `extraEnvVars`, the Helm render will fail with an error message. Remove the duplicate from one location and retry.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.1.0 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.1.0 -n product-console
```
