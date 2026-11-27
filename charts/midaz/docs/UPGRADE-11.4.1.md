<!-- {% raw %} -->
# Helm Upgrade from v11.4.0 to v11.4.1

## Topics

- **[Fixes](#fixes)**
  - [1. License validation for ledger service](#1-license-validation-for-ledger-service)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. License validation for ledger service

The chart now validates that a license is configured for the ledger service **before** attempting to upgrade. This prevents a critical failure scenario where the database would be migrated but the ledger service would fail to start due to a missing license.

#### Why this matters

Starting from ledger version `4.5.0-beta.59`, the ledger service requires a valid license to boot. From version `4.5.0-beta.220` onwards, the partition reconcile hook (which runs after database migrations) also requires a license. Without this validation, an upgrade could leave your deployment in a broken state:

1. Helm runs the pre-upgrade migration job (succeeds)
2. Database schema is migrated to the new version
3. Ledger pod fails to start due to missing license
4. Partition reconcile hook fails (if using `>=4.5.0-beta.220`)
5. Manual intervention required to rollback or add license

With this fix, the chart **fails the render phase** if no license is detected, preventing the upgrade from starting.

#### What changed

A new template helper function `midaz-ledger.validateLicense` has been added to `_helpers.tpl`:

**New validation logic:**

```yaml
{{- define "midaz-ledger.validateLicense" -}}
{{- $ledger := .Values.ledger -}}
{{- $tag := $ledger.image.tag | default .Chart.AppVersion | toString | trimPrefix "v" -}}
{{- if regexMatch "^[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$" $tag -}}
{{- if semverCompare ">=4.5.0-beta.59" $tag -}}
{{- if not (or ($ledger.secrets | default dict).LICENSE_KEY (include "midaz.licenseFileSecret" $ledger) $ledger.useExistingSecret) -}}
{{- fail (printf "ledger: no license is configured for ledger image %s. The ledger refuses to boot without a license from 4.5.0-beta.59 on, and from 4.5.0-beta.220 on so does its partition reconcile hook, which runs after the migrations: the upgrade would stop with the database already migrated. Set ledger.secrets.LICENSE_KEY, or ledger.licenseFile.existingSecret (a Secret holding the signed license file under the key \"license\"), or ledger.useExistingSecret=true with LICENSE_KEY already in the Secret named by ledger.existingSecretName. A license in ledger.extraEnvVars does not count: the pre-upgrade hook reads the ConfigMap of the previous release" $tag) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
```

This validation is invoked in `templates/ledger/configmap.yaml` before rendering the ConfigMap:

**Before (v11.4.0):**

```yaml
{{- include "midaz.validateManagedMongo" (dict "context" $) }}
{{- /* Single-sourced env name so ENV_NAME/OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT
   can't drift from one another; resolved once via global.env, consumed below
   both directly (ENV_NAME) and as the default for the observability block's
```

**After (v11.4.1):**

```yaml
{{- include "midaz.validateManagedMongo" (dict "context" $) }}
{{- include "midaz-ledger.validateLicense" . }}
{{- /* Single-sourced env name so ENV_NAME/OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT
   can't drift from one another; resolved once via global.env, consumed below
   both directly (ENV_NAME) and as the default for the observability block's
```

#### When validation is skipped

The validation is **skipped** in the following cases:

- `ledger.useExistingSecret: true` — The chart cannot read the contents of an existing secret, so it assumes the license is present
- The ledger image tag is not a valid semantic version (e.g., `latest`, `dev`, custom tags) — The chart cannot determine if the version requires a license
- The ledger image tag is `<4.5.0-beta.59` — Older versions do not require a license

#### Validation behavior by configuration

| Configuration | Validation Result |
|---------------|-------------------|
| `ledger.secrets.LICENSE_KEY` is set | ✅ Pass |
| `ledger.licenseFile.existingSecret` is set | ✅ Pass |
| `ledger.useExistingSecret: true` | ✅ Pass (skipped) |
| Image tag is `latest` or non-SemVer | ✅ Pass (skipped) |
| Image tag is `<4.5.0-beta.59` | ✅ Pass (skipped) |
| Image tag is `>=4.5.0-beta.59` and no license | ❌ Fail (render error) |

#### How to configure a license

You have three options to provide a license:

##### Option 1: Set license key in values.yaml

```yaml
ledger:
  secrets:
    LICENSE_KEY: "your-license-key-here"
```

##### Option 2: Use an existing secret with a license file

Create a Kubernetes secret containing your signed license file:

```bash
kubectl create secret generic midaz-license \
  --from-file=license=./path/to/license.lic \
  -n midaz
```

Then reference it in your values:

```yaml
ledger:
  licenseFile:
    existingSecret: midaz-license
```

> **Note:** The secret must contain a key named `license` with the signed license file content.

##### Option 3: Use an existing secret with all ledger secrets

If you manage all ledger secrets externally:

```yaml
ledger:
  useExistingSecret: true
  existingSecretName: my-ledger-secrets
```

> **Important:** When using `useExistingSecret: true`, ensure your external secret includes the `LICENSE_KEY` key. The chart cannot validate this, so the upgrade will proceed and fail at runtime if the license is missing.

#### Why extraEnvVars doesn't count

The validation explicitly does **not** check `ledger.extraEnvVars` for a license. This is because:

- The pre-upgrade migration hook reads the ConfigMap from the **previous release**
- If you add a license via `extraEnvVars` during the upgrade, it won't be available to the hook
- This would result in the same failure scenario the validation is designed to prevent

> **Warning:** Do not rely on `ledger.extraEnvVars` to provide the license. Use one of the three supported methods above.

## Migration Steps

### Step 1: Check your current ledger version

Determine which ledger image version you are currently running:

```bash
helm get values midaz -n midaz | grep -A 2 "ledger:" | grep "tag:"
```

If the tag is `>=4.5.0-beta.59` (or you're using the default `appVersion` from the chart), you **must** configure a license before upgrading.

### Step 2: Verify if you already have a license configured

Check your current values for any of these configurations:

```bash
helm get values midaz -n midaz | grep -E "(LICENSE_KEY|licenseFile|useExistingSecret)"
```

If you see any of the following, you already have a license configured and can proceed to [Step 4](#step-4-upgrade-the-chart):

- `LICENSE_KEY: "..."`
- `licenseFile.existingSecret: "..."`
- `useExistingSecret: true`

### Step 3: Configure a license (if not already present)

Choose one of the three options from [How to configure a license](#how-to-configure-a-license) and update your values file or create the necessary secrets.

**Example values update:**

```yaml
ledger:
  secrets:
    LICENSE_KEY: "your-license-key-here"
```

### Step 4: Upgrade the chart

Proceed with the upgrade using the command in the [Command to upgrade](#command-to-upgrade) section.

> **Note:** If the validation fails during the upgrade, the chart will display a detailed error message explaining which configuration is missing. No changes will be applied to your cluster.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.4.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.4.1
```
<!-- {% endraw %} -->
