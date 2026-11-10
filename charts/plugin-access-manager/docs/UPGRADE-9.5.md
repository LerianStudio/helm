# Helm Upgrade from v9.4.0 to v9.5.0

# Topics

- **[Features](#features)**
  - [1. SSO Callback URL Configuration](#1-sso-callback-url-configuration)
  - [2. Multi-Factor Authentication Control](#2-multi-factor-authentication-control)
- **[Configuration Reference](#configuration-reference)**
  - [SSO Callback URL Settings](#sso-callback-url-settings)
  - [MFA Settings](#mfa-settings)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Features

### 1. SSO Callback URL Configuration

Version 9.5.0 introduces explicit configuration for the SSO callback URL that identity providers redirect users to after authentication. Previously, this URL had to be manually configured in each component's ConfigMap or extraEnvVars. The new `common.sso` configuration block provides a centralized, validated way to set this critical value.

**What changed:**

Three new fields have been added under `common.sso` in `values.yaml`:

| Field | Default | Purpose |
|-------|---------|---------|
| `common.sso.baseUrl` | `""` (empty) | Scheme + host (+ optional path prefix) where the console is served |
| `common.sso.callbackUrl` | `""` (empty) | Literal full callback URL (alternative to baseUrl) |
| `common.sso.allowCustomCallbackPath` | `false` | Disables path validation for custom console routes |

The chart now automatically composes `PLUGIN_AUTH_SSO_CALLBACK_URL` for both the `auth` and `identity` components by appending `/signin/sso/callback` to the base URL you provide.

**Why this matters:**

- **SSO cannot work without this URL**: The identity service refuses to save an SSO provider configuration if the callback URL is missing or invalid, so providers would appear configurable but no login could ever complete
- **The URL must be browser-reachable**: This is the URL the end user's browser is redirected to after authenticating with the identity provider (e.g., Google, GitHub). It cannot be derived from `PLUGIN_AUTH_ADDRESS`, which is the in-cluster service address
- **Path mistakes break logins silently**: If the callback path is wrong (e.g., `/sso/callback` instead of `/signin/sso/callback`), Caradhras rejects the redirect without indicating which part was incorrect. The chart now enforces the correct path at render time
- **auth and identity must agree**: The identity service registers the callback URL in the provider's redirect allow-list, and the auth service sends it as the `redirect_uri` parameter. A mismatch causes login failures with cryptic "rejected redirect_uri" errors

**Before (v9.4.0):**

Operators had to manually set `PLUGIN_AUTH_SSO_CALLBACK_URL` in both components:

```yaml
auth:
  configmap:
    PLUGIN_AUTH_SSO_CALLBACK_URL: "https://console.example.com/signin/sso/callback"

identity:
  configmap:
    PLUGIN_AUTH_SSO_CALLBACK_URL: "https://console.example.com/signin/sso/callback"
```

**After (v9.5.0):**

Set the base URL once, and the chart composes the full callback URL for both components:

```yaml
common:
  sso:
    baseUrl: "https://console.example.com"
```

The chart automatically generates:
- `auth` ConfigMap: `PLUGIN_AUTH_SSO_CALLBACK_URL: "https://console.example.com/signin/sso/callback"`
- `identity` ConfigMap: `PLUGIN_AUTH_SSO_CALLBACK_URL: "https://console.example.com/signin/sso/callback"`

**Configuration options:**

#### Option 1: Use baseUrl (Recommended)

Provide only the scheme, host, and optional path prefix where your console is served. The chart appends the console route automatically.

**Example 1: Console at root domain**

```yaml
common:
  sso:
    baseUrl: "https://console.example.com"
```

Result: `https://console.example.com/signin/sso/callback`

**Example 2: Console under a path prefix**

```yaml
common:
  sso:
    baseUrl: "https://apps.example.com/console"
```

Result: `https://apps.example.com/console/signin/sso/callback`

> **Important:** Do NOT include the `/signin/sso/callback` path in `baseUrl`. The chart appends it automatically. If you include it, the chart will fail to render with an error indicating the path is already present.

#### Option 2: Use callbackUrl (Literal URL)

For deployments with custom console routes or path-rewriting proxies, provide the complete callback URL:

```yaml
common:
  sso:
    callbackUrl: "https://console.example.com/signin/sso/callback"
```

> **Warning:** The URL must still end in `/signin/sso/callback` unless you also set `allowCustomCallbackPath: true`. The chart validates this at render time to prevent silent login failures.

#### Option 3: Per-component override (Migration path)

If you need different callback URLs for auth and identity (not recommended), use the per-component override:

```yaml
auth:
  configmap:
    PLUGIN_AUTH_SSO_CALLBACK_URL: "https://console.example.com/signin/sso/callback"

identity:
  configmap:
    PLUGIN_AUTH_SSO_CALLBACK_URL: "https://console.example.com/signin/sso/callback"
```

> **Important:** The chart enforces that both components resolve to the same URL. If they differ, the upgrade will fail with an error explaining the mismatch.

**Validation rules:**

The chart performs the following checks at render time:

1. **Mutual exclusivity**: `baseUrl` and `callbackUrl` cannot both be set
2. **No double paths**: `baseUrl` must not already end in `/signin/sso/callback`
3. **Absolute URL required**: The resolved URL must be an absolute `http://` or `https://` URL with a path (e.g., `https://console.example.com/signin/sso/callback`)
4. **Path enforcement**: The resolved URL must end in `/signin/sso/callback` (unless `allowCustomCallbackPath: true`)
5. **Component agreement**: `auth` and `identity` must resolve to the same callback URL
6. **No collisions**: The callback URL cannot be set both as a named chart key and in `extraEnvVars`

If any validation fails, the chart will refuse to render and display a detailed error message indicating which field is incorrect and how to fix it.

**Migration steps for existing deployments:**

If you are already using SSO and have manually configured `PLUGIN_AUTH_SSO_CALLBACK_URL`:

**Step 1: Identify your current callback URL**

Check your current values file or deployed ConfigMaps:

```bash
kubectl get configmap plugin-access-manager-auth -n plugin-access-manager -o jsonpath='{.data.PLUGIN_AUTH_SSO_CALLBACK_URL}'
```

**Step 2: Extract the base URL**

Remove `/signin/sso/callback` from the end of the URL. For example:
- Current: `https://console.example.com/signin/sso/callback`
- Base: `https://console.example.com`

**Step 3: Update your values file**

Replace the per-component settings with the centralized configuration:

```yaml
# Remove these:
# auth:
#   configmap:
#     PLUGIN_AUTH_SSO_CALLBACK_URL: "https://console.example.com/signin/sso/callback"
# identity:
#   configmap:
#     PLUGIN_AUTH_SSO_CALLBACK_URL: "https://console.example.com/signin/sso/callback"

# Add this:
common:
  sso:
    baseUrl: "https://console.example.com"
```

**Step 4: Verify before upgrading**

Use `helm diff` to confirm the callback URL remains unchanged:

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.0 -n plugin-access-manager -f values.yaml
```

Look for the `PLUGIN_AUTH_SSO_CALLBACK_URL` line in both the `auth` and `identity` ConfigMaps. The value should be identical to your current deployment.

> **Note:** If you have set `PLUGIN_AUTH_SSO_CALLBACK_URL` in `extraEnvVars` instead of `configmap`, you must remove it from `extraEnvVars` and use the new `common.sso` fields. The chart will fail to render if the key appears in both places.

**For new SSO deployments:**

If you are configuring SSO for the first time, simply set `common.sso.baseUrl` to the public URL where your console is served:

```yaml
common:
  sso:
    baseUrl: "https://console.example.com"
```

Then configure your identity provider (Google, GitHub, etc.) to allow the callback URL:

```
https://console.example.com/signin/sso/callback
```

**Custom console routes:**

If your deployment serves the console SSO callback on a different path (e.g., a custom Next.js route or a path-rewriting proxy), you must explicitly opt in:

```yaml
common:
  sso:
    callbackUrl: "https://console.example.com/custom/sso/callback"
    allowCustomCallbackPath: true
```

> **Warning:** Setting `allowCustomCallbackPath: true` disables the path validation that prevents silent login failures. Use this only if your deployment genuinely answers SSO on a different route. The URL must still be an absolute `http://` or `https://` URL with a path.

### 2. Multi-Factor Authentication Control

Version 9.5.0 adds explicit control over the MFA (multi-factor authentication) feature gate via the `auth.configmap.MFA_ENABLED` field.

**What changed:**

A new optional field has been added to `auth.configmap`:

| Field | Default | Purpose |
|-------|---------|---------|
| `auth.configmap.MFA_ENABLED` | unset | Enables or disables multi-factor authentication |

**Why this matters:**

- **Previously implicit**: The MFA feature was controlled by the application's internal default, which could not be overridden via Helm without using `extraEnvVars`
- **Now explicit**: Operators can enable or disable MFA directly in the chart's values file
- **Validation added**: The chart now prevents `MFA_ENABLED` from being set in both `configmap` and `extraEnvVars`, which would cause undefined behavior

**Before (v9.4.0):**

MFA was controlled by the application's default (enabled). To disable it, operators had to use `extraEnvVars`:

```yaml
auth:
  extraEnvVars:
    MFA_ENABLED: "false"
```

**After (v9.5.0):**

Use the dedicated field in `auth.configmap`:

```yaml
auth:
  configmap:
    MFA_ENABLED: "false"
```

**Configuration options:**

#### Option 1: Use application default (Recommended)

Leave `MFA_ENABLED` unset to use the application's built-in default:

```yaml
auth:
  configmap:
    # MFA_ENABLED not set - application default applies
```

#### Option 2: Explicitly enable MFA

```yaml
auth:
  configmap:
    MFA_ENABLED: "true"
```

#### Option 3: Explicitly disable MFA

```yaml
auth:
  configmap:
    MFA_ENABLED: "false"
```

> **Important:** The value must be a string (`"true"` or `"false"`), not a boolean. Helm will convert boolean values to strings, but it's clearer to use quoted strings.

**Migration steps for existing deployments:**

If you are currently setting `MFA_ENABLED` via `extraEnvVars`:

**Step 1: Check your current configuration**

```bash
kubectl get configmap plugin-access-manager-auth -n plugin-access-manager -o jsonpath='{.data.MFA_ENABLED}'
```

**Step 2: Move the setting to the dedicated field**

```yaml
# Remove this:
# auth:
#   extraEnvVars:
#     MFA_ENABLED: "false"

# Add this:
auth:
  configmap:
    MFA_ENABLED: "false"
```

**Step 3: Verify before upgrading**

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.0 -n plugin-access-manager -f values.yaml
```

Confirm that `MFA_ENABLED` appears in the `auth` ConfigMap with the same value as your current deployment.

> **Note:** If you have not explicitly set `MFA_ENABLED` in your deployment, no action is required. The application default will continue to apply.

**Validation:**

The chart enforces that `MFA_ENABLED` cannot be set in both `auth.configmap` and `auth.extraEnvVars`. If both are present, the upgrade will fail with an error:

```
MFA_ENABLED is set both in auth.configmap and in auth.extraEnvVars. Both render into the same ConfigMap data map, so the key would be emitted twice and the effective value is whatever the YAML parser keeps — undefined behavior. Keep it in auth.configmap.MFA_ENABLED and remove it from auth.extraEnvVars.
```

# Configuration Reference

### SSO Callback URL Settings

The following fields control the SSO callback URL configuration:

```yaml
common:
  sso:
    # -- Base URL: scheme + host (+ optional path prefix) where the console is served.
    # The chart appends "/signin/sso/callback" automatically.
    # Examples:
    #   "https://console.example.com" -> https://console.example.com/signin/sso/callback
    #   "https://apps.example.com/console" -> https://apps.example.com/console/signin/sso/callback
    # Required to configure any SSO provider. Empty (default) omits the callback URL.
    baseUrl: ""

    # -- Literal full callback URL (alternative to baseUrl).
    # Use this for custom console routes or path-rewriting proxies.
    # Must be an absolute http(s) URL and must end in "/signin/sso/callback"
    # (unless allowCustomCallbackPath is true).
    # Set this OR baseUrl, never both.
    callbackUrl: ""

    # -- Disable path validation for custom console routes.
    # Only set this if your deployment genuinely serves SSO on a different path.
    # The URL must still be an absolute http(s) URL with a path.
    allowCustomCallbackPath: false
```

**Per-component override (for migration):**

```yaml
auth:
  configmap:
    # -- Override the SSO callback URL for the auth component only.
    # Must match identity's callback URL (the chart enforces this).
    PLUGIN_AUTH_SSO_CALLBACK_URL: ""

identity:
  configmap:
    # -- Override the SSO callback URL for the identity component only.
    # Must match auth's callback URL (the chart enforces this).
    PLUGIN_AUTH_SSO_CALLBACK_URL: ""
```

### MFA Settings

The following field controls multi-factor authentication:

```yaml
auth:
  configmap:
    # -- Enable or disable multi-factor authentication.
    # Unset (default) uses the application's built-in default.
    # Must be a string: "true" or "false".
    MFA_ENABLED: ""
```

**Existing MFA configuration fields (unchanged):**

```yaml
auth:
  configmap:
    # -- MFA session TTL in seconds (default: 300)
    MFA_SESSION_TTL_SEC: "300"

    # -- MFA "remember this device" TTL in seconds (default: 2592000 = 30 days)
    MFA_REMEMBER_TTL_SEC: "2592000"

    # -- Maximum MFA verification attempts (default: 5)
    MFA_MAX_ATTEMPTS: "5"

    # -- Maximum MFA code resend attempts (default: 3)
    MFA_MAX_RESEND_ATTEMPTS: "3"
```

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.0 -n plugin-access-manager
```
