<!-- {% raw %} -->
# Helm Upgrade from v11.2.0 to v11.2.1

# Topics

- **[Overview](#overview)**
- **[Changes](#changes)**
  - [1. App-Lerian Client Secret Management](#1-app-lerian-client-secret-management)
- **[Migration Steps](#migration-steps)**
  - [Scenario 1: Fresh Install (No Existing Database)](#scenario-1-fresh-install-no-existing-database)
  - [Scenario 2: Upgrade with Existing Database](#scenario-2-upgrade-with-existing-database)
  - [Scenario 3: GitOps / Helm Template Workflows](#scenario-3-gitops--helm-template-workflows)
  - [Scenario 4: Using External Secrets (auth.useExistingSecret=true)](#scenario-4-using-external-secrets-authuseexistingsecrettrue)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Overview

This is a patch release that changes how the `AUTHORIZER_CLIENT_SECRET` (app-lerian's client secret) is managed across the auth, identity, and caradhras components. The application version remains `3.17.0`, and no image tags change.

**What changed:**

- The `AUTHORIZER_CLIENT_SECRET` value is now centralized under `auth.secrets.AUTHORIZER_CLIENT_SECRET` instead of being duplicated in both `auth.secrets` and `identity.secrets`
- A new dedicated Secret resource (`<release>-auth-app-client-secret`) is created to hold this value, shared by all three components
- The Secret is marked with `helm.sh/resource-policy: keep` to survive uninstalls (required because reinstalling reopens the existing database, which still holds the old secret)
- New validation logic prevents silent auth breakage: upgrades with an existing database must provide the current secret value

**Why this matters:**

Before this release, operators had to set the same `AUTHORIZER_CLIENT_SECRET` value in two places (`auth.secrets` and `identity.secrets`). The secret is stored in the Caradhras database and must match across all components. If the value changed between installs or upgrades, authentication would break silently.

This release:

- Eliminates the duplication risk by single-sourcing the value
- Prevents accidental secret regeneration on upgrades (which would break auth)
- Adds explicit validation for GitOps and `helm template` workflows
- Requires Caradhras `>= 2.4.0-beta.4` for fresh installs that rely on generated secrets

**Pods restart during the upgrade:**

The auth, identity, and caradhras Deployment templates now include a `checksum/app-client-secret` annotation that triggers pod replacement when the secret value changes. Even if your secret value does not change, the pod templates carry the label `helm.sh/chart: plugin-access-manager-<version>`, so any chart version bump replaces the pods of all three components.

# Changes

### 1. App-Lerian Client Secret Management

**What changed:**

The `AUTHORIZER_CLIENT_SECRET` environment variable is now sourced from a single Secret (`<release>-auth-app-client-secret`) instead of being embedded in the auth and identity Secrets. The value is set once in `auth.secrets.AUTHORIZER_CLIENT_SECRET` and shared across all components.

| Setting | v11.2.0 | v11.2.1 |
|---------|---------|---------|
| `auth.secrets.AUTHORIZER_CLIENT_SECRET` | Required | Required (single source) |
| `identity.secrets.AUTHORIZER_CLIENT_SECRET` | Required | **Removed** (now reads from `auth.secrets`) |
| Secret resource | Embedded in `<release>-auth` and `<release>-identity` | New dedicated `<release>-auth-app-client-secret` (kept on uninstall) |

**Before (v11.2.0):**

```yaml
# values.yaml
auth:
  secrets:
    AUTHORIZER_CLIENT_SECRET: "your-secret-here"
    DB_PASSWORD: ""
    REDIS_PASSWORD: ""
    LICENSE_KEY: ""

identity:
  secrets:
    AUTHORIZER_CLIENT_SECRET: "your-secret-here"  # Duplicated
    LICENSE_KEY: ""
    ORGANIZATION_IDS: ""
```

**After (v11.2.1):**

```yaml
# values.yaml
auth:
  secrets:
    AUTHORIZER_CLIENT_SECRET: "your-secret-here"  # Single source
    DB_PASSWORD: ""
    REDIS_PASSWORD: ""
    LICENSE_KEY: ""

identity:
  secrets:
    # AUTHORIZER_CLIENT_SECRET removed - now reads from auth.secrets
    LICENSE_KEY: ""
    ORGANIZATION_IDS: ""
```

**Template changes:**

The auth, identity, and caradhras Deployments now reference the secret via `secretKeyRef` instead of reading it from their own Secret resources:

**Before (v11.2.0):**

```yaml
# templates/auth/deployment.yaml
envFrom:
- secretRef:
    name: {{ include "plugin-auth.fullname" . }}  # Contains AUTHORIZER_CLIENT_SECRET

# templates/identity/deployment.yaml
envFrom:
- secretRef:
    name: {{ include "plugin-identity.fullname" . }}  # Contains AUTHORIZER_CLIENT_SECRET
```

**After (v11.2.1):**

```yaml
# templates/auth/deployment.yaml
envFrom:
- secretRef:
    name: {{ include "plugin-auth.fullname" . }}  # No longer contains AUTHORIZER_CLIENT_SECRET
env:
- name: AUTHORIZER_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "plugin-access-manager.appClientSecretName" . }}
      key: AUTHORIZER_CLIENT_SECRET

# templates/identity/deployment.yaml
envFrom:
- secretRef:
    name: {{ include "plugin-identity.fullname" . }}  # No longer contains AUTHORIZER_CLIENT_SECRET
env:
- name: AUTHORIZER_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "plugin-access-manager.appClientSecretName" . }}
      key: AUTHORIZER_CLIENT_SECRET

# templates/caradhras/deployment.yaml
env:
- name: appLerianClientSecret
  valueFrom:
    secretKeyRef:
      name: {{ include "plugin-access-manager.appClientSecretName" . }}
      key: AUTHORIZER_CLIENT_SECRET
```

**New Secret resource:**

A new template `templates/caradhras/app-client-secret.yaml` creates the dedicated Secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <release>-auth-app-client-secret
  annotations:
    helm.sh/resource-policy: keep
type: Opaque
data:
  AUTHORIZER_CLIENT_SECRET: <base64-encoded-value>
```

The `keep` annotation ensures the Secret survives `helm uninstall`. This is critical because a reinstall with the same release name reopens the existing Caradhras database, which still holds the old secret. Without the kept Secret, a reinstall would generate a new secret and break authentication.

**Validation logic:**

The chart now enforces these rules:

1. **Fresh installs without a value set:** The chart generates a random 40-character secret, but only if:
   - The Caradhras image tag is `>= 2.4.0-beta.4` (required for the seed change)
   - The render can read the cluster (fails for `helm template`, ArgoCD, helmfile, `--dry-run`)

2. **Upgrades without a value set:** The chart fails with an error. An existing Caradhras database keeps the secret app-lerian already holds, so generating a new one would break auth silently.

3. **GitOps / helm template workflows:** The chart fails if no value is set and the render cannot read the cluster (no `lookup` support). You must provide the value explicitly.

**Error messages you might see:**

If you upgrade without setting `auth.secrets.AUTHORIZER_CLIENT_SECRET`:

```
ERROR: no app-lerian client secret is set on an upgrade. An existing Caradhras database keeps the secret app-lerian already holds, so a generated one would break auth silently.
   Set auth.secrets.AUTHORIZER_CLIENT_SECRET or auth.useExistingSecret to the current value. To change it, rotate it with Caradhras POST /api/regenerate-application-secret?id=admin/app-lerian, then update the value and restart auth, identity and Caradhras in the same window (Console, plugin-fees and Tenant Manager need the new value too).
```

If you use `helm template` or GitOps without setting the value:

```
ERROR: no app-lerian client secret is set and this render cannot read the cluster (helm template, ArgoCD, helmfile, client --dry-run), so a generated secret would change on every render.
   Set auth.secrets.AUTHORIZER_CLIENT_SECRET or auth.useExistingSecret. On an existing install, use the value app-lerian already holds; if this chart generated it, it is in Secret <release>-auth-app-client-secret, key AUTHORIZER_CLIENT_SECRET.
```

If you try a fresh install with an old Caradhras image:

```
ERROR: no app-lerian client secret is set and the Caradhras image tag "3.16.0" cannot seed a generated one.
   Set auth.secrets.AUTHORIZER_CLIENT_SECRET, use auth.useExistingSecret, or pin a semver Caradhras tag >= 2.4.0-beta.4 (a bare digest or latest cannot be checked).
```

**Why this matters:**

- **Eliminates duplication:** You no longer need to set the same secret in two places
- **Prevents silent breakage:** The chart refuses to generate a new secret on upgrades, which would break authentication
- **Supports secret rotation:** The error message documents the correct rotation procedure (Caradhras API call + coordinated restart)
- **Enforces GitOps best practices:** Renders without cluster access must provide the value explicitly

**Operational impact:**

- **Existing deployments:** You must retrieve the current secret value and set it in `auth.secrets.AUTHORIZER_CLIENT_SECRET` before upgrading (see Migration Steps below)
- **Fresh installs:** If you provide no value, the chart generates one (requires Caradhras `>= 2.4.0-beta.4`)
- **GitOps workflows:** You must set the value explicitly in your values file; the chart cannot generate one without cluster read access
- **Secret rotation:** To change the secret, use the Caradhras API endpoint documented in the error message, then update the value and restart all components in the same maintenance window

# Migration Steps

### Scenario 1: Fresh Install (No Existing Database)

If this is a new installation with no existing Caradhras database:

**Option 1: Let the chart generate a secret (recommended)**

No action required. The chart will generate a random 40-character secret automatically. This requires:

- Caradhras image tag `>= 2.4.0-beta.4`
- A render that can read the cluster (not `helm template`, ArgoCD, or `--dry-run`)

**Option 2: Provide your own secret**

Set the value in your `values.yaml`:

```yaml
auth:
  secrets:
    AUTHORIZER_CLIENT_SECRET: "your-generated-secret-here"
```

Then install:

```bash
helm install plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 11.2.1 -n midaz-plugins -f values.yaml
```

### Scenario 2: Upgrade with Existing Database

If you are upgrading an existing installation, you **must** retrieve the current secret value and set it in `auth.secrets.AUTHORIZER_CLIENT_SECRET`.

**Step 1: Retrieve the current secret value**

If the chart generated the secret in a previous install, it is stored in the Secret the chart created:

```bash
kubectl get secret <release>-auth -n midaz-plugins -o jsonpath='{.data.AUTHORIZER_CLIENT_SECRET}' | base64 -d
```

If you set the value manually in a previous install, use that same value.

**Step 2: Update your values.yaml**

Remove `identity.secrets.AUTHORIZER_CLIENT_SECRET` (if present) and set the value under `auth.secrets`:

```yaml
auth:
  secrets:
    AUTHORIZER_CLIENT_SECRET: "the-value-from-step-1"
    DB_PASSWORD: ""
    REDIS_PASSWORD: ""
    LICENSE_KEY: ""

identity:
  secrets:
    # Remove AUTHORIZER_CLIENT_SECRET from here
    LICENSE_KEY: ""
    ORGANIZATION_IDS: ""
```

**Step 3: Upgrade**

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 11.2.1 -n midaz-plugins -f values.yaml
```

> **Important:** If you do not set `auth.secrets.AUTHORIZER_CLIENT_SECRET`, the upgrade will fail with an error message. Do not attempt to bypass this by generating a new secret — it will break authentication.

### Scenario 3: GitOps / Helm Template Workflows

If you use ArgoCD, helmfile, or `helm template` (any workflow that cannot read the cluster), you **must** provide the secret value explicitly.

**Step 1: Retrieve the current secret value**

If upgrading an existing install:

```bash
kubectl get secret <release>-auth -n midaz-plugins -o jsonpath='{.data.AUTHORIZER_CLIENT_SECRET}' | base64 -d
```

If this is a fresh install, generate a secret:

```bash
openssl rand -base64 30
```

**Step 2: Set the value in your values file**

```yaml
auth:
  secrets:
    AUTHORIZER_CLIENT_SECRET: "your-secret-here"
```

**Step 3: Commit and sync**

Commit the updated `values.yaml` to your Git repository and sync with your GitOps tool.

> **Note:** The chart will fail to render if you do not set this value and the render cannot read the cluster. This is intentional to prevent generating a new secret on every render, which would cause constant pod restarts.

### Scenario 4: Using External Secrets (auth.useExistingSecret=true)

If you manage secrets externally and set `auth.useExistingSecret=true`, you must ensure your external Secret contains the `AUTHORIZER_CLIENT_SECRET` key.

**Step 1: Verify your external Secret**

Your external Secret must include:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: your-external-secret-name
  namespace: midaz-plugins
type: Opaque
data:
  AUTHORIZER_CLIENT_SECRET: <base64-encoded-value>
  DB_PASSWORD: <base64-encoded-value>
  REDIS_PASSWORD: <base64-encoded-value>
  LICENSE_KEY: <base64-encoded-value>
```

**Step 2: Update your values.yaml**

```yaml
auth:
  useExistingSecret: true
  existingSecretName: "your-external-secret-name"
```

**Step 3: Upgrade**

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 11.2.1 -n midaz-plugins -f values.yaml
```

The chart will read `AUTHORIZER_CLIENT_SECRET` from your external Secret and use it for all three components (auth, identity, caradhras).

> **Warning:** If you also set `identity.useExistingSecret=true`, ensure your identity external Secret does **not** contain `AUTHORIZER_CLIENT_SECRET`. The chart now reads it from the auth Secret only. The identity Secret should contain only `LICENSE_KEY`, `ORGANIZATION_IDS`, and any Google Workspace directory keys.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.2.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.2.1
```
<!-- {% endraw %} -->
