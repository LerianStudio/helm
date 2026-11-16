<!-- {% raw %} -->
# Helm Upgrade from v10.2.3 to v10.3.0

# Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Built-in Admin Password Configuration](#1-built-in-admin-password-configuration)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Overview

This is a minor release that increments the chart version from 10.2.3 to 10.3.0. The application version remains unchanged at `3.14.0`.

**What changed:**

- New opt-in configuration for setting the built-in/admin password from a Secret
- New template helpers and validation logic for the admin password feature
- New environment variable injection in the Caradhras deployment

**What this means for operators:**

This release adds an optional security feature that allows you to set a custom password for the built-in/admin account when Caradhras first creates it (fresh database). The feature is **disabled by default** and requires explicit opt-in. If you do not enable it, the upgrade is transparent and requires no action.

| Component | v10.2.3 | v10.3.0 |
|-----------|---------|---------|
| Chart version | 10.2.3 | 10.3.0 |
| App version | 3.14.0 | 3.14.0 |
| Caradhras image | *(unchanged)* | *(unchanged)* |
| Identity image | *(unchanged)* | *(unchanged)* |
| Auth image | *(unchanged)* | *(unchanged)* |

**Action required:**

None, unless you want to enable the new built-in admin password feature. See the [Features](#features) section below.

# Features

## 1. Built-in Admin Password Configuration

**What changed:**

The chart now supports injecting a custom password for the `built-in/admin` account from a Kubernetes Secret. This password is used by Caradhras only when it first creates the built-in organization (fresh database). Once the admin account exists, Caradhras never changes its password automatically.

**Before (v10.2.3):**

No configuration existed for the built-in admin password. Caradhras always created the `built-in/admin` account with the public default password `123` on a fresh database. Operators had to change it manually after deployment.

**After (v10.3.0):**

You can opt in to providing the password via a Secret. The chart injects it as an environment variable that Caradhras reads during database seeding.

```yaml
# New values.yaml configuration block
caradhras:
  builtInAdminPassword:
    enabled: false
    secretName: ""
    secretKey: builtInAdminPassword
```

**Why this matters:**

The default password `123` is public and insecure. Without this feature, every fresh deployment starts with a known password, creating a security window between deployment and manual password change. This feature lets you:

- Set a strong password before the first boot
- Avoid manual post-deployment password changes
- Meet security requirements that forbid default passwords

**Important constraints:**

1. **Caradhras version requirement:** This feature requires Caradhras >= 1.9.0-beta.25. The chart default image tag is `1.8.6`, which **does not support this feature**. If you enable `builtInAdminPassword.enabled: true` without upgrading the Caradhras image, the chart render will fail with a validation error.

2. **Fresh database only:** Caradhras uses the password only when creating the built-in organization for the first time. If the admin account already exists, the password in the Secret does not change it.

3. **Password length limit:** Bcrypt (used by Caradhras) has a 72-byte limit. A password longer than 72 bytes will cause Caradhras to fail at boot before seeding the database.

4. **No default Secret:** This chart does not create a Secret containing the admin password. You must create and manage the Secret yourself.

**When to use this feature:**

- **Fresh deployments:** Enable this before the first deployment to set a secure password from the start.
- **Existing deployments:** This feature never changes the password of an existing built-in/admin. Do not enable it unless you are deploying to a fresh database.

**When NOT to use this feature:**

- If your database already has a built-in/admin account (existing deployment), the password in the Secret does not change it.
- If you cannot upgrade Caradhras to >= 1.9.0-beta.25, you cannot use this feature.

**How to enable:**

### Step 1: Create a Secret with the admin password

Create a Kubernetes Secret in the same namespace as the chart deployment:

```bash
kubectl create secret generic caradhras-admin-password \
  --from-literal=builtInAdminPassword='your-secure-password-here' \
  -n plugin-access-manager
```

> **Important:** Choose a password of at most 72 bytes. A longer password makes Caradhras fail at startup.

### Step 2: Upgrade the Caradhras image

The chart default image tag `1.8.6` does not support this feature. You must pin a Caradhras image tag >= 1.9.0-beta.25:

```yaml
# values.yaml
caradhras:
  image:
    tag: "<caradhras-tag>"  # a semver tag >= 1.9.0-beta.25
  migrations:
    image:
      tag: "<caradhras-tag>"
```

Set `caradhras.migrations.image.tag` to the same tag. It does not follow `caradhras.image.tag`.

The published stable tags that meet this requirement are `2.0.0` and `2.1.0`. Caradhras `2.0.0` and later refuse to boot without their own `LICENSE_KEY` (see `UPGRADE-10.2.md`): set `caradhras.secrets.LICENSE_KEY`, or add the key to your existing Secret if you use `caradhras.useExistingSecret`.

> **Warning:** The chart validation requires a semver tag (e.g., `1.9.0-beta.25`, `2.0.0`). Digest references (e.g., `sha256:abc123...`) or `latest` cannot be validated and will cause the render to fail.

### Step 3: Enable the feature in values.yaml

```yaml
# values.yaml
caradhras:
  image:
    tag: "<caradhras-tag>"
  migrations:
    image:
      tag: "<caradhras-tag>"
  builtInAdminPassword:
    enabled: true
    secretName: "caradhras-admin-password"
    secretKey: "builtInAdminPassword"
  # Caradhras 2.x refuses to boot without its own license key.
  secrets:
    LICENSE_KEY: "your-caradhras-license-key"
```

### Step 4: Upgrade the chart

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager \
  --version 10.3.0 \
  -n plugin-access-manager \
  -f values.yaml
```

**Validation errors:**

The chart includes two validation checks that will fail the render if misconfigured:

1. **Missing Caradhras version:**

   If `builtInAdminPassword.enabled: true` but `caradhras.image.tag` is not a semver tag >= 1.9.0-beta.25:

   ```
   ERROR: caradhras.builtInAdminPassword.enabled is true but the Caradhras image tag "1.8.6" does not read it.
      Caradhras reads builtInAdminPassword from 1.9.0-beta.25 on; older images seed the public default password.
      Set caradhras.image.tag to a semver tag and pin a Caradhras tag >= 1.9.0-beta.25 (a digest or latest cannot be checked).
   ```

2. **Missing Secret name:**

   If `builtInAdminPassword.enabled: true` but `builtInAdminPassword.secretName` is empty:

   ```
   ERROR: caradhras.builtInAdminPassword.enabled is true but caradhras.builtInAdminPassword.secretName is empty.
      No Secret this chart creates carries the built-in/admin password.
      Name the Secret holding it in caradhras.builtInAdminPassword.secretName (key: caradhras.builtInAdminPassword.secretKey).
   ```

**Template changes:**

When enabled, the chart injects the password into the Caradhras container as:

```yaml
- name: builtInAdminPassword
  valueFrom:
    secretKeyRef:
      name: caradhras-admin-password
      key: builtInAdminPassword
```

**Operational impact:**

- **Default behavior (feature disabled):** No environment variable is added. Caradhras behavior is unchanged. The upgrade is transparent.
- **Feature enabled:** Caradhras reads the `builtInAdminPassword` environment variable at startup. If the database is fresh, it uses the password from the Secret. If the admin account already exists, its password does not change.
- **Pod restart:** Enabling this feature changes the Caradhras pod template, triggering a rolling restart. The Deployment uses `maxSurge: 1` and `maxUnavailable: 0`, so no downtime occurs if the database is healthy.

**What happens if you enable this on an existing deployment:**

The existing admin password does not change: Caradhras uses the Secret only when it creates the built-in organization. A value over 72 bytes still fails the boot.

**What happens if Caradhras is too old:**

The chart render fails before deployment. You cannot accidentally deploy with an incompatible Caradhras version.

**What happens if the Secret is missing:**

If `builtInAdminPassword.enabled: true` but the Secret does not exist at runtime, the Caradhras pod fails to start. Kubernetes reports a `CreateContainerConfigError` because the secretKeyRef cannot be resolved. Fix this by creating the Secret or disabling the feature.

# Configuration Reference

## New configuration: caradhras.builtInAdminPassword

| Setting | Default | Description |
|---------|---------|-------------|
| `caradhras.builtInAdminPassword.enabled` | `false` | Opt-in flag. When `true`, injects the built-in/admin password from a Secret. Requires Caradhras >= 1.9.0-beta.25. |
| `caradhras.builtInAdminPassword.secretName` | `""` | Name of the Secret holding the password. Required when `enabled: true`. No Secret created by this chart carries the password. |
| `caradhras.builtInAdminPassword.secretKey` | `"builtInAdminPassword"` | Key inside the Secret. |

**Example values.yaml:**

```yaml
caradhras:
  image:
    tag: "<caradhras-tag>"
  migrations:
    image:
      tag: "<caradhras-tag>"
  builtInAdminPassword:
    enabled: true
    secretName: "caradhras-admin-password"
    secretKey: "builtInAdminPassword"
  # Caradhras 2.x refuses to boot without its own license key.
  secrets:
    LICENSE_KEY: "your-caradhras-license-key"
```

## New environment variable: builtInAdminPassword

When `caradhras.builtInAdminPassword.enabled: true`, the chart injects this environment variable into the Caradhras container:

| Variable | Source | Description |
|----------|--------|-------------|
| `builtInAdminPassword` | Secret (via `secretKeyRef`) | Password for the built-in/admin account. Used by Caradhras >= 1.9.0-beta.25 only when creating the built-in organization on a fresh database. Never changes an existing admin. Must be <= 72 bytes (bcrypt limit). |

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.3.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.3.0 -n plugin-access-manager
```
<!-- {% endraw %} -->
