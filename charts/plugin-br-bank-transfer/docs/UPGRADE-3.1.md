<!-- {% raw %} -->
# Helm Upgrade from v3.0.6 to v3.1.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. License File Support](#1-license-file-support)
- **[Configuration Reference](#configuration-reference)**
  - [New License File Configuration](#new-license-file-configuration)
  - [New Template Helpers](#new-template-helpers)
  - [New Environment Variables](#new-environment-variables)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Evaluate License Delivery Method](#step-1-evaluate-license-delivery-method)
  - [Step 2: Create License File Secret (Optional)](#step-2-create-license-file-secret-optional)
  - [Step 3: Update Values Configuration (Optional)](#step-3-update-values-configuration-optional)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Chart **3.1.0** adds optional license-file mounts; it still ships application and default migrations **3.5.0**, the same images as chart 3.0.6. **Application 3.5.0 uses lib-license-go v4, requires a nonempty `LICENSE_KEY`, and does not read `LICENSE_FILE_PATH`. Keep the key with these shipped images.** The first chart whose default images read the file is **3.2.1** (application and migrations **3.6.0**, on `lib-license-go` v5). In 3.6.0, when both are set, `LICENSE_FILE_PATH` wins over `LICENSE_KEY`. To move to the file, upgrade to chart 3.2.1 and follow its guides; do not remove the key on chart 3.1.0.

The chart also adds new template helpers to support license file mounting and introduces a dedicated PreSync hook Secret that copies `LICENSE_KEY` to the migration Job, which runs before the application Secret exists.

## Features

### 1. License File Support

**What changed:**  
The chart now supports mounting a signed license file from an existing Kubernetes Secret into the application and migration containers. When configured, the license file is mounted at `/etc/lerian/license/license` and the `LICENSE_FILE_PATH` environment variable is automatically set.

**Why it matters:**  
- **File-based licensing:** Applications using `lib-license-go` v5+ can read license data from a file instead of an environment variable
- **Secret projection:** Mounted Secret files can receive Kubernetes updates (no `subPath`). Application reread and license reload must be verified separately; the shipped 3.5.0 application does not read this file.
- **Migration support:** The migration container receives the license (hook Secret, application Secret or file mount). The migrations 3.5.0 executable shipped with this chart does not read it; the migrator from application 3.6.0 (chart 3.2.1) requires it.

**How it works:**

| Scenario | License Delivery | Configuration |
|----------|------------------|---------------|
| **Existing (v3.0.6)** | `LICENSE_KEY` environment variable from `bankTransfer.secrets.LICENSE_KEY` or `bankTransfer.extraEnvVars.LICENSE_KEY` | No change required |
| **New (v3.1.0)** | Signed license file from an existing Secret | Set `bankTransfer.licenseFile.existingSecret` to the Secret name; the chart mounts it and sets `LICENSE_FILE_PATH` |
| **Hybrid** | Both `LICENSE_KEY` and license file | The shipped 3.5.0 application uses the key and ignores the file. Application 3.6.0 (chart 3.2.1) uses the file when both are set. |

**Effect on the rendered resources:**

- **Application container:** with `bankTransfer.licenseFile.existingSecret` set, the chart mounts the Secret at `/etc/lerian/license` and adds `LICENSE_FILE_PATH: "/etc/lerian/license/license"` to the ConfigMap. Without it, the application container does not change.
- **Migration container:** the chart adds `LICENSE_KEY` (and, with the file, `LICENSE_FILE_PATH` and the mount) to the migration container, from one of these sources:

1. **License file mount:** If `bankTransfer.licenseFile.existingSecret` is set, the file is mounted at `/etc/lerian/license/license` and `LICENSE_FILE_PATH` is set
2. **LICENSE_KEY from hook Secret:** If `bankTransfer.secrets.LICENSE_KEY` or `bankTransfer.extraEnvVars.LICENSE_KEY` is set and the migration runs as a PreSync Job (external PostgreSQL, non-multi-tenant, without an existing application Secret), a dedicated hook Secret is created with the key and injected via `secretKeyRef`. Its name is the chart fullname truncated to 50 characters, followed by `-license-hook` (normally `bank-transfer-license-hook`).
3. **LICENSE_KEY in the init container:** If the migration runs as an init container of the Deployment (bundled PostgreSQL), the key comes from the application Secret (`bankTransfer.secrets.LICENSE_KEY`) or inline (`bankTransfer.extraEnvVars.LICENSE_KEY`). With `bankTransfer.useExistingSecret=true`, the key comes from `bankTransfer.existingSecretName` in both migration modes.

**New hook Secret:**

A new template (`templates/license-hook-secret.yaml`) creates a PreSync hook Secret containing `LICENSE_KEY` when:
- Migrations are enabled (`bankTransfer.enabled=true` and `bankTransfer.migrations.enabled=true`)
- A license key is set (`bankTransfer.secrets.LICENSE_KEY` or `bankTransfer.extraEnvVars.LICENSE_KEY`)
- The operator is **not** using `bankTransfer.useExistingSecret=true`
- The deployment uses external PostgreSQL (not the bundled subchart)
- Multi-tenant mode is disabled

**Why this hook Secret exists:**  
PreSync migration Jobs run before the application Secret is created, so the chart gives the Job its own copy of `LICENSE_KEY`. The hook Secret is created with `helm.sh/hook: pre-install,pre-upgrade` and `argocd.argoproj.io/hook: PreSync` annotations, ensuring it exists before the migration Job runs. The migrations 3.5.0 executable does not read the key.

> **Warning:** The hook Secret stays in the namespace with `LICENSE_KEY` after the upgrade. Its delete policy is `before-hook-creation` (Argo CD: `BeforeHookCreation`), so Helm replaces it only on the next upgrade, and `helm uninstall` does not remove hook resources. After an uninstall, delete it yourself: `kubectl delete secret <release>-license-hook -n <namespace>` (`bank-transfer-license-hook` with the default fullname).

**Operational impact:**
- **Retain existing key delivery:** Keep `LICENSE_KEY` for the default 3.5.0 application.
- **Pod restarts (file mode off):** they depend on where the migration runs.
  - Bundled PostgreSQL (migration as init container of the `bank-transfer` Deployment): with `bankTransfer.secrets.LICENSE_KEY`, `bankTransfer.extraEnvVars.LICENSE_KEY` or `bankTransfer.useExistingSecret: true`, the init container gains `LICENSE_KEY`, so the Deployment pods restart on the upgrade.
  - External PostgreSQL (migration as PreSync Job): the Deployment does not change and its pods do not restart. Only the migration Job gains `LICENSE_KEY`; the chart also creates the `bank-transfer-license-hook` Secret when the key comes from values (not with `useExistingSecret`).
  - No `LICENSE_KEY` in values and no `useExistingSecret`: the Deployment and the Job render the same as in 3.0.6.
- **License file rotation:** Updates to the license file Secret reach the mounted file in running pods (the mount does not use `subPath`). Application 3.5.0 does not read the file.
- **Migration licensing:** The default migrations 3.5.0 executable does not initialize license validation. Injection does not make it license-gated; verify the contract of any replacement migrator before changing its inputs.

## Configuration Reference

### New License File Configuration

Add the following block to `bankTransfer` to enable license file mounting:

```yaml
bankTransfer:
  licenseFile:
    # Name of an existing Secret containing a signed license file under the key "license"
    existingSecret: ""
```

| Field | Default | Description |
|-------|---------|-------------|
| `bankTransfer.licenseFile.existingSecret` | `""` (empty) | Name of an existing Kubernetes Secret containing a signed license file under the key `license`. When set, the chart mounts the file at `/etc/lerian/license/license` and sets `LICENSE_FILE_PATH=/etc/lerian/license/license` in the ConfigMap. Requires an application image built with `lib-license-go` v5 or later: application 3.6.0, the default from chart 3.2.1. |

**Secret structure:**

The referenced Secret must contain a key named `license` with the signed license file content:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-license-secret
  namespace: midaz-plugins
type: Opaque
data:
  license: <base64-encoded-license-file-content>
```

### New Template Helpers

The chart introduces five new template helpers to support license file functionality:

| Helper | Purpose |
|--------|---------|
| `bank-transfer.licenseSecret` | Returns the value of `bankTransfer.licenseFile.existingSecret` (or empty string if not set) |
| `bank-transfer.licenseKeyValue` | Returns the `LICENSE_KEY` value from `bankTransfer.secrets.LICENSE_KEY` or `bankTransfer.extraEnvVars.LICENSE_KEY` (used by the hook Secret template) |
| `bank-transfer.licenseHookName` | Returns the chart fullname truncated to 50 characters plus `-license-hook` (normally `bank-transfer-license-hook`) |
| `bank-transfer.licenseFileMount` | Emits a `volumeMounts` entry for the license file (empty if `licenseFile.existingSecret` is not set) |
| `bank-transfer.licenseFileVolume` | Emits a `volumes` entry for the license file Secret (empty if `licenseFile.existingSecret` is not set) |

### New Environment Variables

When `bankTransfer.licenseFile.existingSecret` is set, the chart automatically adds the following environment variable to the ConfigMap:

| Variable | Value | Description |
|----------|-------|-------------|
| `LICENSE_FILE_PATH` | `/etc/lerian/license/license` | Path to the mounted file. The shipped application 3.5.0 ignores this input and still requires `LICENSE_KEY`; verify file handling in a replacement image. |

## Migration Steps

### Step 1: Evaluate License Delivery Method

For the shipped 3.5.0 application, retain `LICENSE_KEY`; do not perform a file-only migration. Steps 2 and 3 apply only from chart 3.2.1, whose default application and migrations images (3.6.0) read the file. Do not pin a newer image on chart 3.1.0 for this.

**Choose license file delivery if:**
- Your application and migrations images are 3.6.0 or later (`lib-license-go` v5)
- Your licensing workflow uses signed license files instead of inline keys

**Keep existing `LICENSE_KEY` delivery if:**
- Your application image uses `lib-license-go` v4 or earlier
- You do not need file-based licensing
- You prefer environment variable–based configuration

> **Note:** Both inputs can be delivered. Application 3.5.0 uses the key and ignores the file; application 3.6.0 uses the file when both are set.

### Step 2: Create License File Secret (Optional)

If you choose to use license file delivery, create a Kubernetes Secret containing your signed license file:

```bash
kubectl create secret generic my-license-secret \
  --from-file=license=/path/to/your/license.lic \
  -n midaz-plugins
```

> **Important:** The Secret **must** contain a key named `license`. The chart mounts this specific key at `/etc/lerian/license/license`.

Verify the Secret was created correctly:

```bash
kubectl get secret my-license-secret -n midaz-plugins -o json \
  | jq -e '(.data.license // "") | length > 0' > /dev/null
```

### Step 3: Update Values Configuration (Optional)

Only on chart 3.2.1 or later (application and migrations 3.6.0), merge this fragment into a complete, maintained `values-override.yaml` preserving all existing deployment settings. This fragment alone is not a complete deployment configuration:

```yaml
bankTransfer:
  licenseFile:
    existingSecret: "my-license-secret"
```

**Complete example with both license methods:**

```yaml
bankTransfer:
  # Existing LICENSE_KEY (required by the shipped 3.5.0 application)
  secrets:
    LICENSE_KEY: "your-existing-license-key"
  
  # New license file (optional)
  licenseFile:
    existingSecret: "my-license-secret"
```

> **Note:** If you set both `secrets.LICENSE_KEY` and `licenseFile.existingSecret`, the application receives both. Application 3.5.0 uses the key; application 3.6.0 uses the file.

## Preview changes before upgrading

Create a fresh private export for review; it may contain credentials. Reconcile it with the target defaults, retaining database, integration, authentication, organization, license and intentional image settings. An empty or `null` export must be replaced with a reviewed YAML mapping. Explicitly preserve old defaults you intentionally depend on, because user-value exports omit computed defaults. Do not add the license file fragment for this upgrade to chart 3.1.0; adopt it with chart 3.2.1.

```bash
umask 077
REVIEW_DIR="$(mktemp -d "${TMPDIR:-.}/bank-transfer-upgrade.XXXXXXXX")"
helm get values plugin-br-bank-transfer -n midaz-plugins -o yaml > "$REVIEW_DIR/values-override.yaml"
```

Use the same complete reviewed file in preview and upgrade. `--reset-values` avoids implicit reuse of old settings when the file is empty, and is appropriate only after the full intended configuration is reviewed. Rendered output may contain Secret data; do not publish it.

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm -n midaz-plugins --version 3.1.0 --reset-values -f "$REVIEW_DIR/values-override.yaml"
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm -n midaz-plugins --version 3.1.0 --reset-values -f "$REVIEW_DIR/values-override.yaml" --wait --timeout 15m
```

Verify release status, migration results, readiness and license acceptance before declaring success. Back up the database under your operational policy before an upgrade that can run migrations. Record the previous Helm revision and image pins. Helm rollback does not restore database contents or reverse schema migrations; use the tested restore procedure if the old application is incompatible with migration effects. No live upgrade, restore or application startup test is asserted here.

Remove the temporary export after it is no longer needed:

```bash
rm -f -- "$REVIEW_DIR/values-override.yaml"
rmdir -- "$REVIEW_DIR"
unset REVIEW_DIR
```
<!-- {% endraw %} -->
