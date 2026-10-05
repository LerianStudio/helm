# Helm Upgrade from v9.5.8 to v9.5.9

# Topics

- **[Fixes](#fixes)**
  - [1. HTTPS Enforcement for Caradhras JWKS URL](#1-https-enforcement-for-caradhras-jwks-url)
  - [2. Enhanced Startup Validation](#2-enhanced-startup-validation)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. HTTPS Enforcement for Caradhras JWKS URL

This release adds render-time validation to prevent deployment failures caused by the application's HTTPS-only JWKS requirement introduced in application version 3.3.0.

**What changed:**

The chart now validates that auth and identity services will fetch the Caradhras JWKS (JSON Web Key Set) over HTTPS when `ENV_NAME` indicates a production-like environment. This validation runs during `helm upgrade` and fails the render with a detailed error message if the configuration would cause pods to crash-loop at startup.

**Why this matters:**

Since application version 3.3.0, both auth and identity services require HTTPS for fetching the Caradhras JWKS in production environments. The process exits at startup before telemetry flushes, so the failure reason only appears in `kubectl logs --previous`, not in your log collector. This makes troubleshooting difficult, and `helm upgrade --wait` or `--atomic` operations end in timeouts.

The chart's default `AUTHORIZER_ADDRESS` points to the in-cluster Caradhras Service over plain HTTP, which triggers this failure in production-like installations.

**When validation triggers:**

The chart fails the render when ALL of these conditions are met:

1. `ENV_NAME` (from `auth.configmap.ENV_NAME`, `identity.configmap.ENV_NAME`, or `global.env.name`) is NOT `development`, `staging`, or `local`
2. The component's image tag is application version 3.3.0 or later
3. The Caradhras JWKS URL uses a scheme other than `https`

**When validation is skipped:**

The check does NOT run when:

- `ENV_NAME` is `development`, `staging`, or `local` (the application allows HTTP in these environments)
- The component image predates application 3.3.0 (the HTTPS requirement doesn't exist yet)
- Auth service has service discovery enabled (`auth.configmap.SD_ENABLED=true` or legacy `auth.extraEnvVars.SERVICE_DISCOVERY_ENABLED=true`) — the chart cannot see the runtime-resolved address, but the requirement still applies
- Identity service has `identity.configmap.AUTH_ENABLED` set to anything other than `true`, `1`, `t`, `T`, `TRUE`, or `True` (the pass-through authenticator fetches no JWKS)
- Identity service uses an HTTP JWKS URL pointing to a loopback host (`localhost`, `127.0.0.0/8`, or `::1`) — lib-auth allows this exemption

**JWKS URL resolution:**

The chart validates the URL each component will use:

| Component | JWKS URL Source | Default |
|-----------|----------------|---------|
| Auth | `<AUTHORIZER_ADDRESS>/.well-known/jwks` | `http://<caradhras-service>:<port>/.well-known/jwks` |
| Identity | `identity.configmap.AUTH_M2M_JWKS_URL` (if set), else `identity.extraEnvVars.AUTH_M2M_JWKS_URL` (if set), else `<AUTHORIZER_ADDRESS>/.well-known/jwks` | `http://<caradhras-service>:<port>/.well-known/jwks` |

**Migration steps:**

> **Important:** Caradhras serves plain HTTP and has no TLS listener. You must terminate TLS in front of it.

#### Option 1: Use Caradhras Ingress (Recommended)

1. Enable TLS termination for Caradhras using a certificate from a public CA:

```yaml
caradhras:
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: caradhras.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: caradhras-tls
        hosts:
          - caradhras.example.com
```

> **Note:** The chart cannot mount a private CA certificate into auth and identity pods. You must use a certificate from a public CA that the container's trust store already recognizes.

2. Set both auth and identity to use the same HTTPS URL:

```yaml
auth:
  configmap:
    AUTHORIZER_ADDRESS: https://caradhras.example.com

identity:
  configmap:
    AUTHORIZER_ADDRESS: https://caradhras.example.com
```

> **Warning:** Identity pins `AUTHORIZER_ADDRESS` as the issuer of M2M tokens. Both services MUST use the exact same URL, or token validation will fail.

#### Option 2: Mark Environment as Non-Production

If this environment is truly not production (development, staging, or local), set `ENV_NAME` to one of the allowed values:

```yaml
global:
  env:
    name: staging
```

This disables the HTTPS requirement and other production-only application behaviors.

**Example error message:**

If the validation fails, you'll see:

```
ERROR: plugin-access-manager: auth and identity would crash-loop at startup: the Caradhras JWKS URL is not https in an environment the application treats as production.
   auth: ENV_NAME "production" (from the chart default)
      JWKS URL "http://plugin-caradhras:3000/.well-known/jwks" (from the chart default for auth.configmap.AUTHORIZER_ADDRESS, the in-cluster Caradhras Service over plain http)
   identity: ENV_NAME "production" (from the chart default)
      JWKS URL "http://plugin-caradhras:3000/.well-known/jwks" (from the chart default for identity.configmap.AUTHORIZER_ADDRESS, the in-cluster Caradhras Service over plain http)
   Since application 3.3.0, auth and identity fetch the JWKS over https whenever ENV_NAME is not development, staging or local, and no setting relaxes this. The process exits before its telemetry flushes, so the reason shows only in `kubectl logs --previous` and helm reports a timeout.
   Fix: Caradhras serves plain http, so terminate TLS in front of it with caradhras.ingress, using a certificate from a public CA (the chart cannot mount a private CA), and set auth.configmap.AUTHORIZER_ADDRESS and identity.configmap.AUTHORIZER_ADDRESS to the SAME https URL: identity also pins that address as the issuer of M2M tokens.
   Only if this environment really is not production, set global.env.name to development, staging or local instead; that also switches off the application's production-only behavior.
```

### 2. Enhanced Startup Validation

The chart now includes comprehensive render-time validation to catch configuration errors that would cause startup failures.

**What changed:**

A new validation template (`_startup-validation.tpl`) consolidates and extends existing checks:

| Validation | Scope | Error Prevented |
|------------|-------|-----------------|
| Chart-owned ConfigMap keys in `extraEnvVars` | auth, identity | Duplicate key rendering, undefined behavior |
| `MFA_SECRET` in `auth.extraEnvVars` | auth | Sensitive data in ConfigMap instead of Secret |
| `MFA_ENABLED=true` without `MFA_SECRET` | auth | Auth service crash-loop at startup |
| `AUTH_M2M_JWKS_URL` in both `configmap` and `extraEnvVars` | identity | Duplicate key rendering, undefined behavior |
| `MFA_ENABLED` as non-string in `extraEnvVars` | auth | YAML rendering error (ConfigMap data values must be strings) |

**Before (v9.5.8):**

Only MFA validation existed, embedded in `_helpers.tpl`:

```yaml
{{- define "plugin-access-manager.validateMfaEnabled" -}}
{{- $extra := .Values.auth.extraEnvVars | default dict -}}
{{- if hasKey $extra "MFA_ENABLED" -}}
{{- if hasKey (.Values.auth.configmap | default dict) "MFA_ENABLED" -}}
{{- fail "MFA_ENABLED is set both in auth.configmap and in auth.extraEnvVars..." -}}
{{- end -}}
{{- end }}
```

**After (v9.5.9):**

Validation is centralized and expanded in `_startup-validation.tpl`, called once from `templates/auth/configmap.yaml`:

```yaml
{{- include "plugin-access-manager.validateStartup" . -}}
{{- include "plugin-access-manager.validateJwksTls" . -}}
```

**What this means for operators:**

These validations catch misconfigurations during `helm upgrade` instead of discovering them after pods crash-loop. No configuration changes are required unless you have an invalid configuration that was previously allowed to render.

**Common validation failures and fixes:**

#### Duplicate ConfigMap keys

**Error:**

```
auth.extraEnvVars.ENV_NAME duplicates a chart-owned ConfigMap key; use auth.configmap.ENV_NAME instead
```

**Fix:**

Move the value from `extraEnvVars` to `configmap`:

```yaml
# Before (invalid)
auth:
  extraEnvVars:
    ENV_NAME: production

# After (valid)
auth:
  configmap:
    ENV_NAME: production
```

#### Sensitive data in ConfigMap

**Error:**

```
MFA_SECRET is sensitive: use auth.secrets.MFA_SECRET or auth.useExistingSecret, not auth.extraEnvVars (a ConfigMap)
```

**Fix:**

Move the secret to the appropriate location:

```yaml
# Before (invalid)
auth:
  extraEnvVars:
    MFA_SECRET: my-secret-value

# After (valid)
auth:
  secrets:
    MFA_SECRET: my-secret-value
```

#### MFA enabled without secret

**Error:**

```
MFA_ENABLED requires a non-empty auth.secrets.MFA_SECRET (or auth.useExistingSecret with an existing Secret containing MFA_SECRET)
```

**Fix:**

Provide the required secret:

```yaml
auth:
  configmap:
    MFA_ENABLED: "true"
  secrets:
    MFA_SECRET: your-mfa-secret-here
```

Or use an existing secret:

```yaml
auth:
  configmap:
    MFA_ENABLED: "true"
  useExistingSecret: true
  existingSecretName: my-auth-secrets
```

> **Note:** When using `useExistingSecret`, the Secret must exist before the upgrade and must contain a non-empty `MFA_SECRET` key.

#### Non-string value in extraEnvVars

**Error:**

```
auth.extraEnvVars.MFA_ENABLED must be a quoted string because it renders in ConfigMap.data; alternatively use auth.configmap.MFA_ENABLED
```

**Fix:**

Quote the value or move it to `configmap`:

```yaml
# Before (invalid)
auth:
  extraEnvVars:
    MFA_ENABLED: true

# After (valid - option 1)
auth:
  extraEnvVars:
    MFA_ENABLED: "true"

# After (valid - option 2)
auth:
  configmap:
    MFA_ENABLED: true
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.9 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.9 -n plugin-access-manager
```
