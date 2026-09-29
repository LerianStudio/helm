# Helm Upgrade from v9.5.7 to v9.5.8

# Topics

- **[Breaking change: production-like installs need Caradhras over HTTPS](#breaking-change-production-like-installs-need-caradhras-over-https)**
- **[Fixes](#fixes)**
  - [1. Application Version Update](#1-application-version-update)
  - [2. User Initialization Image Update](#2-user-initialization-image-update)
- **[Features](#features)**
  - [3. SSO Security and Network Configuration](#3-sso-security-and-network-configuration)
  - [4. Self-Service Password Recovery](#4-self-service-password-recovery)
  - [5. Machine-to-Machine Authentication Configuration](#5-machine-to-machine-authentication-configuration)
  - [6. Single-Tenant SSO Organization Support](#6-single-tenant-sso-organization-support)
  - [7. JWKS Cache TTL Configuration](#7-jwks-cache-ttl-configuration)
- **[Configuration Reference](#configuration-reference)**
  - [Identity Service SSO Configuration](#identity-service-sso-configuration)
  - [Identity Service M2M Configuration](#identity-service-m2m-configuration)
  - [Auth Service SSO Configuration](#auth-service-sso-configuration)
  - [Auth Service JWKS Configuration](#auth-service-jwks-configuration)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Breaking change: production-like installs need Caradhras over HTTPS

> **Warning:** Read this section before upgrading any install whose `ENV_NAME` is not `development`, `staging` or `local`, including environments that are not production but run with a production `ENV_NAME`. With the chart's default Caradhras address, auth and identity **fail to start** after this upgrade.

**What changed:**

Since application `3.3.0`, auth and identity fetch the Caradhras JWKS (the key set every token is verified against) **over `https` only**, unless `ENV_NAME` is `development`, `staging` or `local`. Letter case and surrounding spaces are ignored. Any other value fails closed: `production`, an empty value, a typo, or a short form such as `dev`. v9.5.8 is the first chart release that ships an application past `3.3.0` (`3.1.0` → `3.9.0`), so this is the upgrade where the requirement lands.

Caradhras itself serves plain http, and the chart's default `AUTHORIZER_ADDRESS` is its in-cluster Service (`http://<release>-caradhras:8000`). Each component derives its JWKS URL from that address:

| Component | JWKS URL | Accepted when `ENV_NAME` is not `development` / `staging` / `local` |
|-----------|----------|------------------------------------------------------------------|
| auth | `<AUTHORIZER_ADDRESS>/.well-known/jwks`, or the Caradhras address resolved by service discovery when `SD_ENABLED=true` | `https` only |
| identity (while `PLUGIN_AUTH_ENABLED` is true, the default) | `AUTH_M2M_JWKS_URL` when set, else `<AUTHORIZER_ADDRESS>/.well-known/jwks` | `https`, or `http` to a loopback host (`localhost`, `127.0.0.1`, `::1`) |

| `ENV_NAME` | Caradhras address | v9.5.7 (app `3.1.0`) | v9.5.8 (app `3.9.0`) |
|------------|-------------------|----------------------|----------------------|
| `development` / `staging` / `local` | `http://…` (chart default) | Starts | Starts |
| Anything else (`production`, empty, a typo) | `http://…` (chart default) | Starts | **auth and identity exit at startup** |
| Anything else | `https://…` | Starts | Starts |

**Who is affected:**

Every install whose `ENV_NAME` (`global.env.name`, or per component `auth.configmap.ENV_NAME` / `identity.configmap.ENV_NAME`) is not `development`, `staging` or `local`, and whose auth or identity JWKS URL from the table above is not `https`. When `ENV_NAME` is not set anywhere, the chart renders `development` and the install is not affected. A component whose image is pinned below `3.3.0` is not affected either.

**What happens if you upgrade anyway:**

- auth exits with `validating jwks cache upstream url: SaaS TLS enforcement: jwks cache upstream must use https, got "<url>"`.
- identity exits while building its M2M key source, with an error wrapped as `initializing m2m jwks key source`.
- Both exit before their telemetry is flushed. Nothing reaches your log collector; the reason is only in `kubectl logs --previous`.
- The pods go into `CrashLoopBackOff`, and `helm upgrade --wait` ends in `context deadline exceeded` (`--atomic` then rolls back).
- identity runs one replica with `maxUnavailable: 1`, so it is unavailable for the whole wait.

**No setting relaxes this.** The application decides on `ENV_NAME` alone. Setting `ENV_NAME` to `staging` makes the pods start, but compared with `production` it also turns off production behavior: panic details are no longer redacted in error reports (both components), auth's OTLP exporter may run without TLS, and the JWKS is accepted over plain http. Do that only for an environment that really is not production.

**Check before upgrading:**

On the running release (the ConfigMaps are named `<release>-auth` and `<release>-identity`; the names below are for a release called `plugin-access-manager`):

```bash
kubectl -n <namespace> get configmap plugin-access-manager-auth plugin-access-manager-identity \
  -o custom-columns='NAME:.metadata.name,ENV_NAME:.data.ENV_NAME,AUTHORIZER_ADDRESS:.data.AUTHORIZER_ADDRESS,AUTH_M2M_JWKS_URL:.data.AUTH_M2M_JWKS_URL'
```

You are affected when `ENV_NAME` is not `development`, `staging` or `local` and the address is not `https://`. On identity, `AUTH_M2M_JWKS_URL` replaces the address when it is set (`<none>` means it is not). To check the values you are about to apply instead of the running ones, render them:

```bash
helm template plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.8 -f <your-values.yaml> \
  | grep -E '^  (ENV_NAME|AUTHORIZER_ADDRESS|AUTH_M2M_JWKS_URL|PLUGIN_AUTH_ENABLED|SD_ENABLED):'
```

**How to fix: reach Caradhras over HTTPS**

Terminate TLS in front of Caradhras with the chart's own `caradhras.ingress` (disabled by default, same shape as `auth.ingress`), and point both components at that address:

```yaml
global:
  env:
    name: production

caradhras:
  ingress:
    enabled: true
    className: "nginx"            # prefer an internal-only ingress class
    annotations:
      # Restrict who can reach the Caradhras admin panel and API, e.g. with
      # ingress-nginx (uncomment the line below and set your CIDRs):
      # nginx.ingress.kubernetes.io/whitelist-source-range: "<cluster pod and node CIDRs>"
    hosts:
      - host: caradhras.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: caradhras-tls   # certificate issued by a public CA
        hosts:
          - caradhras.example.com

auth:
  configmap:
    AUTHORIZER_ADDRESS: "https://caradhras.example.com"   # no trailing slash

identity:
  configmap:
    AUTHORIZER_ADDRESS: "https://caradhras.example.com"   # same value as auth
```

This renders an Ingress named `<release>-caradhras`, with TLS for the host, routing to the Caradhras Service on port `8000`. The TLS Secret (`caradhras-tls` here) is yours to provide, for example through cert-manager.

Things to get right:

- **A certificate from a public CA.** The auth and identity images trust only their default CA bundle, and the chart cannot mount a custom CA, so a self-signed or private-CA certificate fails the TLS handshake. auth's `wait-for-dependencies` init container polls `<AUTHORIZER_ADDRESS>/api/health` with `curl`, so it also waits until that handshake succeeds.
- **Reachable from inside the cluster.** auth and identity call this hostname from their own pods, so it must resolve and route there, not only from users' networks.
- **The same URL on both components, with no trailing slash.** identity also uses `AUTHORIZER_ADDRESS` as the expected issuer (`iss`) of M2M tokens and compares it exactly, while Caradhras stamps the issuer from the address it was called on (unless its own `origin` setting is set). After the switch, confirm that an M2M call to identity is still accepted. Tokens issued before the switch carry the old issuer, so identity rejects them until the client obtains a new one.
- **Keep the ingress internal.** `caradhras.ingress` exposes the Caradhras admin panel and API. Use an internal ingress class or load balancer, or restrict source ranges (for example `nginx.ingress.kubernetes.io/whitelist-source-range` on ingress-nginx).
- **Every call to Caradhras goes through it**, not only the JWKS fetch: auth's logins and token issuance and identity's Caradhras API calls too. The ingress becomes part of the login path, so give it the timeouts, limits and availability that path needs.
- **IP allowlists.** Caradhras now sees platform calls arrive through the ingress, from a different source address than the pods. If your organizations use an IP allowlist, review `PLATFORM_INTERNAL_CIDRS` (which must stay identical on `auth.configmap` and `identity.configmap`) so it covers that path.

identity's `wait-for-dependencies` init container only checks TCP reachability of plugin-auth, so it is unaffected.

**Render-time check:** chart releases after v9.5.8 refuse to render this combination. The error names every component that would crash-loop, its resolved `ENV_NAME`, its JWKS URL and the values they came from, instead of letting the pods crash-loop. The check is skipped exactly where the application starts anyway: `ENV_NAME` is `development`, `staging` or `local`; the component's image tag is a version below `3.3.0`; auth uses service discovery (`SD_ENABLED=true`); identity has `PLUGIN_AUTH_ENABLED` off; or identity's JWKS URL is `http` to a loopback host. There is no value that turns the check off, because the application has none.

# Fixes

### 1. Application Version Update

**What changed:**

The application version (appVersion) has been updated from `3.1.0` to `3.9.0`, and both the identity and auth service image tags have been updated to match.

| Setting | v9.5.7 | v9.5.8 |
|---------|--------|--------|
| Chart appVersion | `3.1.0` | `3.9.0` |
| Identity service image tag | `3.1.0` | `3.9.0` |
| Auth service image tag | `3.1.0` | `3.9.0` |

**Before (v9.5.7):**

```yaml
# values.yaml
identity:
  image:
    repository: ghcr.io/lerianstudio/midaz-identity
    pullPolicy: Always
    tag: "3.1.0"

auth:
  image:
    repository: ghcr.io/lerianstudio/midaz-auth
    pullPolicy: Always
    tag: "3.1.0"
```

**After (v9.5.8):**

```yaml
# values.yaml
identity:
  image:
    repository: ghcr.io/lerianstudio/midaz-identity
    pullPolicy: Always
    tag: "3.9.0"

auth:
  image:
    repository: ghcr.io/lerianstudio/midaz-auth
    pullPolicy: Always
    tag: "3.9.0"
```

**Why this matters:**

- **Feature additions:** The `3.9.0` release includes new SSO security controls, self-service password recovery, and enhanced M2M authentication configuration options
- **Bug fixes and improvements:** This release includes fixes and enhancements from the `3.1.0` baseline
- **Synchronized versions:** Both identity and auth services are updated to the same version to ensure API compatibility

**Operational impact:**

- If you have not explicitly overridden `identity.image.tag` or `auth.image.tag` in your `values.yaml`, the upgrade will automatically use the new `3.9.0` images for both services
- If you have pinned specific image tags, your overrides will continue to take precedence
- The new version introduces several new configuration options (detailed in the Features section below), all of which are opt-in with safe defaults

**What operators need to do:**

No action required when `ENV_NAME` is `development`, `staging` or `local` (the chart renders `development` when it is not set). **Any other `ENV_NAME`, including `production`, needs an `https` Caradhras address before upgrading**: with the default address the new images refuse to start. See [Breaking change: production-like installs need Caradhras over HTTPS](#breaking-change-production-like-installs-need-caradhras-over-https). All new configuration options default to safe values that preserve existing behavior.

> **Note:** If you have explicitly pinned `identity.image.tag` or `auth.image.tag` to `3.1.0` in your values overrides, you should update both to `3.9.0` to benefit from the latest features and fixes.

### 2. User Initialization Image Update

**What changed:**

The default image tag for the user initialization Job has been updated from `3.3.1` to `3.9.0` to align with the main application version.

| Setting | v9.5.7 | v9.5.8 |
|---------|--------|--------|
| Default init user image tag | `3.3.1` | `3.9.0` |

**Before (v9.5.7):**

```yaml
# templates/auth/init_user.yaml
image: "{{ $initUserImage.repository | default "ghcr.io/lerianstudio/caradhras-user-init" }}:{{ $initUserImage.tag | default "3.3.1" }}"
```

**After (v9.5.8):**

```yaml
# templates/auth/init_user.yaml
image: "{{ $initUserImage.repository | default "ghcr.io/lerianstudio/caradhras-user-init" }}:{{ $initUserImage.tag | default "3.9.0" }}"
```

**Why this matters:**

- **Version alignment:** The init user Job now uses the same version as the main application services
- **Compatibility:** Ensures the initialization logic is compatible with the `3.9.0` application version

**Operational impact:**

- The init user Job runs automatically during Helm upgrade (as a pre-upgrade hook)
- If you have overridden `auth.initUser.image.tag` in your values, your override will continue to take precedence
- The Job creates the initial admin user if it doesn't already exist — existing users are not affected

**What operators need to do:**

No action required. The init user Job will automatically use the updated image version on the next upgrade.

# Features

### 3. SSO Security and Network Configuration

**What changed:**

The identity service now supports two new security flags for SSO integration: `PLUGIN_AUTH_SSO_PREFLIGHT_ALLOW_INSECURE` and `PLUGIN_AUTH_SSO_ALLOW_PRIVATE_NETWORKS`. These flags control TLS validation and network access restrictions when communicating with external identity providers.

| Setting | v9.5.7 | v9.5.8 |
|---------|--------|--------|
| SSO insecure TLS flag | Not available | `PLUGIN_AUTH_SSO_PREFLIGHT_ALLOW_INSECURE` (default: `false`) |
| SSO private network flag | Not available | `PLUGIN_AUTH_SSO_ALLOW_PRIVATE_NETWORKS` (default: `false`) |

**Before (v9.5.7):**

```yaml
# templates/identity/configmap.yaml
# SSO
PLUGIN_AUTH_SSO_CALLBACK_URL: {{ . | quote }}
{{- end }}

# RUNTIME
DEPLOYMENT_MODE: {{ .Values.identity.configmap.DEPLOYMENT_MODE | default "local" | quote }}
```

**After (v9.5.8):**

```yaml
# templates/identity/configmap.yaml
# SSO
PLUGIN_AUTH_SSO_CALLBACK_URL: {{ . | quote }}
{{- end }}
PLUGIN_AUTH_SSO_PREFLIGHT_ALLOW_INSECURE: {{ .Values.identity.configmap.PLUGIN_AUTH_SSO_PREFLIGHT_ALLOW_INSECURE | default "false" | quote }}
PLUGIN_AUTH_SSO_ALLOW_PRIVATE_NETWORKS: {{ .Values.identity.configmap.PLUGIN_AUTH_SSO_ALLOW_PRIVATE_NETWORKS | default "false" | quote }}

# RUNTIME
DEPLOYMENT_MODE: {{ .Values.identity.configmap.DEPLOYMENT_MODE | default "local" | quote }}
```

**Why this matters:**

- **Development environments:** The `PLUGIN_AUTH_SSO_PREFLIGHT_ALLOW_INSECURE` flag allows integration with identity providers that don't have valid TLS certificates (e.g., self-signed certificates in development)
- **BYOC and on-premises deployments:** The `PLUGIN_AUTH_SSO_ALLOW_PRIVATE_NETWORKS` flag enables SSO integration with identity providers hosted on private RFC1918 networks (e.g., `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`)
- **Security by default:** Both flags default to `false`, ensuring strict TLS validation and blocking private network access unless explicitly enabled

**Default behavior:**

Both flags are **disabled by default** (`false`). The identity service will:

- Require valid TLS certificates from identity providers
- Block connections to identity providers on private networks

This ensures secure defaults for production environments.

**New environment variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `PLUGIN_AUTH_SSO_PREFLIGHT_ALLOW_INSECURE` | `false` | Allow SSO connections to identity providers without valid TLS certificates. Only enable in development environments. |
| `PLUGIN_AUTH_SSO_ALLOW_PRIVATE_NETWORKS` | `false` | Allow SSO connections to identity providers on private RFC1918 networks. Required for BYOC/on-premises IdP deployments. |

**Configuration examples:**

#### Option 1: Keep Default Secure Behavior (Recommended for Production)

No configuration changes required. The identity service will enforce strict TLS validation and block private network access:

```yaml
# No changes needed - defaults are secure
identity:
  configmap:
    # PLUGIN_AUTH_SSO_PREFLIGHT_ALLOW_INSECURE: "false"  # Default
    # PLUGIN_AUTH_SSO_ALLOW_PRIVATE_NETWORKS: "false"    # Default
```

#### Option 2: Enable for Development with Self-Signed Certificates

For development environments where your identity provider uses self-signed certificates:

```yaml
identity:
  configmap:
    PLUGIN_AUTH_SSO_PREFLIGHT_ALLOW_INSECURE: "true"
```

> **Warning:** Only enable `PLUGIN_AUTH_SSO_PREFLIGHT_ALLOW_INSECURE` in development environments. This flag disables TLS certificate validation and should never be used in production.

#### Option 3: Enable for BYOC/On-Premises Identity Providers

For BYOC or on-premises deployments where your identity provider is hosted on a private network:

```yaml
identity:
  configmap:
    PLUGIN_AUTH_SSO_ALLOW_PRIVATE_NETWORKS: "true"
```

> **Note:** This flag only allows connections to RFC1918 private networks. It does not disable TLS validation — your identity provider must still have a valid certificate.

#### Option 4: Enable Both (Development with Private Network IdP)

For development environments with a private network identity provider using self-signed certificates:

```yaml
identity:
  configmap:
    PLUGIN_AUTH_SSO_PREFLIGHT_ALLOW_INSECURE: "true"
    PLUGIN_AUTH_SSO_ALLOW_PRIVATE_NETWORKS: "true"
```

> **Warning:** This combination should only be used in isolated development environments. Never use both flags in production.

### 4. Self-Service Password Recovery

**What changed:**

The identity service now supports self-service password recovery (forgot password functionality) through a new `ENABLE_FORGOT_PASSWORD` configuration flag. This feature exposes public routes for password reset requests and must be explicitly enabled.

| Setting | v9.5.7 | v9.5.8 |
|---------|--------|--------|
| Forgot password feature | Not available | `ENABLE_FORGOT_PASSWORD` (default: `false`) |

**Before (v9.5.7):**

```yaml
# templates/identity/configmap.yaml
PLUGIN_AUTH_SSO_ALLOW_PRIVATE_NETWORKS: {{ .Values.identity.configmap.PLUGIN_AUTH_SSO_ALLOW_PRIVATE_NETWORKS | default "false" | quote }}

# RUNTIME
DEPLOYMENT_MODE: {{ .Values.identity.configmap.DEPLOYMENT_MODE | default "local" | quote }}
```

**After (v9.5.8):**

```yaml
# templates/identity/configmap.yaml
PLUGIN_AUTH_SSO_ALLOW_PRIVATE_NETWORKS: {{ .Values.identity.configmap.PLUGIN_AUTH_SSO_ALLOW_PRIVATE_NETWORKS | default "false" | quote }}

# FORGOT PASSWORD (public self-service routes; off unless explicitly "true")
ENABLE_FORGOT_PASSWORD: {{ .Values.identity.configmap.ENABLE_FORGOT_PASSWORD | default "false" | quote }}

# RUNTIME
DEPLOYMENT_MODE: {{ .Values.identity.configmap.DEPLOYMENT_MODE | default "local" | quote }}
```

**Why this matters:**

- **Self-service capability:** Users can reset their passwords without administrator intervention
- **Email provider requirement:** This feature requires an email provider to be configured in your application to send password reset links
- **Security consideration:** Enabling this feature exposes public password reset routes — ensure your email provider is properly configured before enabling

**Default behavior:**

The feature is **disabled by default** (`false`). Password reset functionality is not available unless explicitly enabled.

**New environment variable:**

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_FORGOT_PASSWORD` | `false` | Enable self-service password recovery routes. Requires an email provider to be configured. |

**Configuration example:**

```yaml
identity:
  configmap:
    ENABLE_FORGOT_PASSWORD: "true"
```

> **Important:** Before enabling this feature, ensure you have configured an email provider in your application. The password reset flow requires sending email notifications to users. If no email provider is configured, password reset requests will fail.

**What operators need to do:**

1. **Verify email provider configuration** — ensure your application has a working email provider configured
2. **Enable the feature** — set `identity.configmap.ENABLE_FORGOT_PASSWORD: "true"` in your values
3. **Test the flow** — verify that password reset emails are delivered successfully
4. **Monitor logs** — watch for any email delivery failures after enabling

### 5. Machine-to-Machine Authentication Configuration

**What changed:**

The identity service now supports optional configuration for machine-to-machine (M2M) authentication through two new flags: `AUTH_M2M_JWKS_URL` and `AUTH_M2M_JWKS_REFRESH_INTERVAL`. These flags control how the identity service fetches and refreshes JSON Web Key Sets (JWKS) for validating M2M tokens.

| Setting | v9.5.7 | v9.5.8 |
|---------|--------|--------|
| M2M JWKS URL | Not configurable | `AUTH_M2M_JWKS_URL` (optional) |
| M2M JWKS refresh interval | Not configurable | `AUTH_M2M_JWKS_REFRESH_INTERVAL` (optional) |

**Before (v9.5.7):**

```yaml
# templates/identity/configmap.yaml
# M2M (lib-auth/v3 middleware — identity authorizes inbound M2M calls)
AUTH_M2M_INVERSION_ENABLED: {{ .Values.identity.configmap.AUTH_M2M_INVERSION_ENABLED | default "false" | quote }}

# SERVICE DISCOVERY
```

**After (v9.5.8):**

```yaml
# templates/identity/configmap.yaml
# M2M (lib-auth/v3 middleware — identity authorizes inbound M2M calls)
AUTH_M2M_INVERSION_ENABLED: {{ .Values.identity.configmap.AUTH_M2M_INVERSION_ENABLED | default "false" | quote }}
{{- with .Values.identity.configmap.AUTH_M2M_JWKS_URL }}
AUTH_M2M_JWKS_URL: {{ . | quote }}
{{- end }}
{{- with .Values.identity.configmap.AUTH_M2M_JWKS_REFRESH_INTERVAL }}
AUTH_M2M_JWKS_REFRESH_INTERVAL: {{ . | quote }}
{{- end }}

# SERVICE DISCOVERY
```

**Why this matters:**

- **Custom JWKS endpoints:** Allows overriding the default JWKS URL derived from the Casdoor address
- **Refresh interval control:** Allows tuning how frequently the identity service refreshes its JWKS cache
- **Opt-in configuration:** Both settings are optional and only included in the ConfigMap when explicitly set

**Default behavior:**

Both settings are **optional** and omitted from the ConfigMap by default:

- `AUTH_M2M_JWKS_URL`: When not set, the identity service derives the JWKS URL from the configured Casdoor address
- `AUTH_M2M_JWKS_REFRESH_INTERVAL`: When not set, the identity service uses its internal default refresh interval

**New environment variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `AUTH_M2M_JWKS_URL` | (derived from Casdoor address) | Custom JWKS endpoint URL for M2M token validation. Only set if you need to override the default. |
| `AUTH_M2M_JWKS_REFRESH_INTERVAL` | (application default) | How frequently to refresh the JWKS cache (e.g., `5m`, `10m`). Only set if you need to override the default. |

**Configuration examples:**

#### Option 1: Use Default Behavior (Recommended)

No configuration changes required. The identity service will derive the JWKS URL from your Casdoor configuration:

```yaml
# No changes needed - defaults work for most deployments
identity:
  configmap:
    AUTH_M2M_INVERSION_ENABLED: "true"
    # AUTH_M2M_JWKS_URL: ""  # Omitted - derived from Casdoor
    # AUTH_M2M_JWKS_REFRESH_INTERVAL: ""  # Omitted - uses app default
```

#### Option 2: Override JWKS URL

If you need to point to a custom JWKS endpoint:

```yaml
identity:
  configmap:
    AUTH_M2M_INVERSION_ENABLED: "true"
    AUTH_M2M_JWKS_URL: "https://custom-idp.example.com/.well-known/jwks.json"
```

#### Option 3: Customize Refresh Interval

If you need to tune the JWKS refresh frequency:

```yaml
identity:
  configmap:
    AUTH_M2M_INVERSION_ENABLED: "true"
    AUTH_M2M_JWKS_REFRESH_INTERVAL: "10m"
```

#### Option 4: Override Both

For complete control over M2M JWKS configuration:

```yaml
identity:
  configmap:
    AUTH_M2M_INVERSION_ENABLED: "true"
    AUTH_M2M_JWKS_URL: "https://custom-idp.example.com/.well-known/jwks.json"
    AUTH_M2M_JWKS_REFRESH_INTERVAL: "10m"
```

> **Note:** These settings apply whenever identity verifies M2M tokens, that is whenever `PLUGIN_AUTH_ENABLED` is true (the default), independently of `AUTH_M2M_INVERSION_ENABLED`. When `ENV_NAME` is not `development`, `staging` or `local`, the JWKS URL, set here or derived from `AUTHORIZER_ADDRESS`, must be `https`; see [Breaking change: production-like installs need Caradhras over HTTPS](#breaking-change-production-like-installs-need-caradhras-over-https).

### 6. Single-Tenant SSO Organization Support

**What changed:**

The auth service now supports a `PLUGIN_AUTH_SSO_STATIC_ORGANIZATION` configuration flag for BYOC single-tenant deployments. This flag pins all SSO operations to a specific organization and is mutually exclusive with multi-tenant mode.

| Setting | v9.5.7 | v9.5.8 |
|---------|--------|--------|
| Static SSO organization | Not available | `PLUGIN_AUTH_SSO_STATIC_ORGANIZATION` (optional) |

**Before (v9.5.7):**

```yaml
# templates/auth/configmap.yaml
# SSO
PLUGIN_AUTH_SSO_CALLBACK_URL: {{ . | quote }}
{{- end }}

# RUNTIME
DEPLOYMENT_MODE: {{ .Values.auth.configmap.DEPLOYMENT_MODE | default "local" | quote }}
```

**After (v9.5.8):**

```yaml
# templates/auth/configmap.yaml
# SSO
PLUGIN_AUTH_SSO_CALLBACK_URL: {{ . | quote }}
{{- end }}
{{- with .Values.auth.configmap.PLUGIN_AUTH_SSO_STATIC_ORGANIZATION }}
PLUGIN_AUTH_SSO_STATIC_ORGANIZATION: {{ . | quote }}
{{- end }}

# RUNTIME
DEPLOYMENT_MODE: {{ .Values.auth.configmap.DEPLOYMENT_MODE | default "local" | quote }}
```

**Why this matters:**

- **BYOC single-tenant deployments:** Allows pinning all SSO operations to a specific organization identifier
- **Simplified SSO flow:** Removes the need for organization selection during SSO authentication
- **Mutual exclusivity:** The auth service will refuse to start if both `PLUGIN_AUTH_SSO_STATIC_ORGANIZATION` and `MULTI_TENANT_ENABLED=true` are set

**Default behavior:**

The setting is **optional** and omitted from the ConfigMap by default. When not set, SSO organization selection follows the standard multi-tenant flow.

**New environment variable:**

| Variable | Default | Description |
|----------|---------|-------------|
| `PLUGIN_AUTH_SSO_STATIC_ORGANIZATION` | (not set) | Pin all SSO operations to a specific organization. Only for BYOC single-tenant deployments. Refused when `MULTI_TENANT_ENABLED=true`. |

**Configuration example:**

```yaml
auth:
  configmap:
    PLUGIN_AUTH_SSO_STATIC_ORGANIZATION: "my-organization-id"
    # MULTI_TENANT_ENABLED: "false"  # Must be false or unset
```

> **Warning:** Do not set `PLUGIN_AUTH_SSO_STATIC_ORGANIZATION` when `MULTI_TENANT_ENABLED` is `true`. The auth service will refuse to start and log an error. This validation prevents configuration conflicts between single-tenant and multi-tenant modes.

**What operators need to do:**

Only configure this setting if you are running a BYOC single-tenant deployment:

1. **Verify multi-tenant mode is disabled** — ensure `auth.configmap.MULTI_TENANT_ENABLED` is either `false` or not set
2. **Set the organization identifier** — configure `auth.configmap.PLUGIN_AUTH_SSO_STATIC_ORGANIZATION` with your organization ID
3. **Test SSO flow** — verify that SSO authentication works without organization selection

### 7. JWKS Cache TTL Configuration

**What changed:**

The auth service now supports an optional `AUTH_JWKS_CACHE_TTL` configuration flag to control how long JWKS (JSON Web Key Set) entries are cached before being refreshed.

| Setting | v9.5.7 | v9.5.8 |
|---------|--------|--------|
| JWKS cache TTL | Not configurable | `AUTH_JWKS_CACHE_TTL` (optional) |

**Before (v9.5.7):**

```yaml
# templates/auth/configmap.yaml
{{- with .Values.auth.configmap.PLUGIN_AUTH_SSO_STATIC_ORGANIZATION }}
PLUGIN_AUTH_SSO_STATIC_ORGANIZATION: {{ . | quote }}
{{- end }}

# RUNTIME
DEPLOYMENT_MODE: {{ .Values.auth.configmap.DEPLOYMENT_MODE | default "local" | quote }}
```

**After (v9.5.8):**

```yaml
# templates/auth/configmap.yaml
{{- with .Values.auth.configmap.PLUGIN_AUTH_SSO_STATIC_ORGANIZATION }}
PLUGIN_AUTH_SSO_STATIC_ORGANIZATION: {{ . | quote }}
{{- end }}
{{- with .Values.auth.configmap.AUTH_JWKS_CACHE_TTL }}
AUTH_JWKS_CACHE_TTL: {{ . | quote }}
{{- end }}

# RUNTIME
DEPLOYMENT_MODE: {{ .Values.auth.configmap.DEPLOYMENT_MODE | default "local" | quote }}
```

**Why this matters:**

- **Performance tuning:** Allows operators to balance between JWKS freshness and network overhead
- **Key rotation support:** Shorter TTLs ensure faster propagation of key rotations from the identity provider
- **Opt-in configuration:** Only included in the ConfigMap when explicitly set

**Default behavior:**

The setting is **optional** and omitted from the ConfigMap by default. When not set, the auth service uses its internal default cache TTL.

**New environment variable:**

| Variable | Default | Description |
|----------|---------|-------------|
| `AUTH_JWKS_CACHE_TTL` | (application default) | How long to cache JWKS entries before refreshing (e.g., `5m`, `10m`, `1h`). Only set if you need to override the default. |

**Configuration example:**

```yaml
auth:
  configmap:
    AUTH_JWKS_CACHE_TTL: "5m"
```

> **Note:** Use Go duration format for the TTL value (e.g., `5m` for 5 minutes, `1h` for 1 hour, `30s` for 30 seconds). Shorter TTLs increase network traffic to the JWKS endpoint but ensure faster key rotation propagation.

# Configuration Reference

### Identity Service SSO Configuration

Configure SSO security and network settings for the identity service in your `values.yaml`:

```yaml
identity:
  configmap:
    # SSO security flags (default "false")
    PLUGIN_AUTH_SSO_PREFLIGHT_ALLOW_INSECURE: "false"  # Only for IdP with no TLS
    PLUGIN_AUTH_SSO_ALLOW_PRIVATE_NETWORKS: "false"    # BYOC/on-prem IdP on RFC1918 only
    
    # Self-service password recovery (default "false")
    ENABLE_FORGOT_PASSWORD: "false"  # Needs email provider linked to the app
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `PLUGIN_AUTH_SSO_PREFLIGHT_ALLOW_INSECURE` | `false` | Allow SSO connections without valid TLS certificates. Only enable in development. |
| `PLUGIN_AUTH_SSO_ALLOW_PRIVATE_NETWORKS` | `false` | Allow SSO connections to private RFC1918 networks. Required for BYOC/on-premises IdP. |
| `ENABLE_FORGOT_PASSWORD` | `false` | Enable self-service password recovery routes. Requires email provider configuration. |

### Identity Service M2M Configuration

Configure machine-to-machine authentication for the identity service in your `values.yaml`:

```yaml
identity:
  configmap:
    # M2M JWKS configuration (optional, omitted unless set)
    AUTH_M2M_JWKS_URL: ""  # Empty derives it from the Casdoor address
    AUTH_M2M_JWKS_REFRESH_INTERVAL: "5m"
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `AUTH_M2M_JWKS_URL` | (derived from Casdoor) | Custom JWKS endpoint URL. Only set to override the default. |
| `AUTH_M2M_JWKS_REFRESH_INTERVAL` | (application default) | JWKS cache refresh interval (Go duration format). Only set to override the default. |

### Auth Service SSO Configuration

Configure single-tenant SSO for the auth service in your `values.yaml`:

```yaml
auth:
  configmap:
    # Single-tenant SSO organization (optional, omitted unless set)
    PLUGIN_AUTH_SSO_STATIC_ORGANIZATION: ""  # BYOC single-tenant SSO org; refused when MULTI_TENANT_ENABLED=true
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `PLUGIN_AUTH_SSO_STATIC_ORGANIZATION` | (not set) | Pin all SSO operations to a specific organization. Only for BYOC single-tenant deployments. Mutually exclusive with `MULTI_TENANT_ENABLED=true`. |

### Auth Service JWKS Configuration

Configure JWKS caching for the auth service in your `values.yaml`:

```yaml
auth:
  configmap:
    # JWKS cache TTL (optional, omitted unless set)
    AUTH_JWKS_CACHE_TTL: "5m"
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `AUTH_JWKS_CACHE_TTL` | (application default) | JWKS cache TTL (Go duration format). Only set to override the default. |

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.8 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.8 -n plugin-access-manager
```
