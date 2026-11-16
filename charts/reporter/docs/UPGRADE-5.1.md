# Helm Upgrade from v5.0.1 to v5.1.0

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Product license now required for app >= 4.6.0](#1-product-license-now-required-for-app--460)
- **[Features](#features)**
  - [1. Application version bump to 4.6.0](#1-application-version-bump-to-460)
  - [2. Optional regulatory catalog](#2-optional-regulatory-catalog)
  - [3. Chart-level license enforcement](#3-chart-level-license-enforcement)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
  - [Step 1: Obtain product license key](#step-1-obtain-product-license-key)
  - [Step 2: Set license credentials](#step-2-set-license-credentials)
  - [Step 3: Execute the upgrade](#step-3-execute-the-upgrade)
  - [Step 4: Verify deployment health](#step-4-verify-deployment-health)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that bumps the application version to `4.6.0` and makes a product license mandatory. The manager and worker components now refuse to boot without a valid `LICENSE_KEY`, and the chart enforces this requirement at render time for app versions >= 4.6.0.

| Field | v5.0.1 | v5.1.0 |
|-------|--------|--------|
| Chart version | `5.0.1` | `5.1.0` |
| App version | `4.5.1` | `4.6.0` |
| Manager image tag | `4.5.1` | `4.6.0` |
| Worker image tag | `4.5.1` | `4.6.0` |

> **Warning:** This upgrade will fail at render time if `secrets.LICENSE_KEY` is not set when deploying app version 4.6.0 or later. Both the manager and worker refuse to boot without a license.

## Breaking Changes

### 1. Product license now required for app >= 4.6.0

Starting with application version `4.6.0`, both the manager and worker components require a valid `LICENSE_KEY` environment variable to boot. The chart now enforces this requirement at render time: if the resolved image tag is >= 4.6.0 (parsed as semver) and `secrets.LICENSE_KEY` is empty, the render will fail with a descriptive error message.

| Setting | v5.0.1 | v5.1.0 |
|---------|--------|--------|
| `secrets.LICENSE_KEY` | not present | required for app >= 4.6.0 |
| `secrets.ORGANIZATION_IDS` | not present | optional (defaults to `"global"` when unset) |

**Error message when license is missing:**

```
ERROR: secrets.LICENSE_KEY is REQUIRED for reporter app >= 4.6.0 (worker.image.tag is "4.6.0").
   The manager AND the worker refuse to boot without a license.
   Set secrets.LICENSE_KEY (and secrets.ORGANIZATION_IDS for a per-organization license),
   or point worker.useExistingSecret at a Secret that carries them.
   See charts/reporter/docs/UPGRADE-5.1.md.
```

**Before (v5.0.1):**

```yaml
secrets:
  DATASOURCE_ONBOARDING_PASSWORD: "your-password"
  # No license fields
```

**After (v5.1.0):**

```yaml
secrets:
  DATASOURCE_ONBOARDING_PASSWORD: "your-password"
  LICENSE_KEY: "your-product-license-key"
  ORGANIZATION_IDS: ""  # Optional: set for per-organization license; defaults to "global"
```

> **Important:** The license enforcement applies to both the manager and worker components. If you use separate existing Secrets for each component (via `manager.useExistingSecret` and `worker.useExistingSecret`), both Secrets must contain `LICENSE_KEY` (and optionally `ORGANIZATION_IDS`).

> **Note:** The chart only enforces the license requirement when the resolved image tag can be parsed as semver and is >= 4.6.0. Floating tags (`latest`, digest references, or custom tags like `4.5.1-custom_1`) bypass the gate. However, the application itself will still refuse to boot without `LICENSE_KEY` if it is version 4.6.0 or later.

## Features

### 1. Application version bump to 4.6.0

The manager and worker image tags have been updated from `4.5.1` to `4.6.0`, and the chart `appVersion` field reflects this change.

| Component | v5.0.1 | v5.1.0 |
|-----------|--------|--------|
| `manager.image.tag` | `"4.5.1"` | `"4.6.0"` |
| `worker.image.tag` | `"4.5.1"` | `"4.6.0"` |
| Chart `appVersion` | `"4.5.1"` | `"4.6.0"` |

### 2. Optional regulatory catalog

The chart's `values.yaml` now documents the optional regulatory catalog settings, commented out. It stays off while unset: the regulatory surface answers with error code `RPT-0147` and everything else works.

### 3. Chart-level license enforcement

The chart now includes a template helper (`reporter.licenseKeyRequired`) that validates the presence of `LICENSE_KEY` at render time when the resolved image tag is >= 4.6.0. This prevents deployments that would result in pods stuck in `CrashLoopBackOff` due to missing license credentials.

**Enforcement logic:**

1. The helper is called in both `manager/secrets.yaml` and `worker/secrets.yaml` templates
2. It resolves the component's image tag (from `<component>.image.tag` or the chart `appVersion`)
3. If the tag parses as semver and is >= 4.6.0, it checks whether `secrets.LICENSE_KEY` is set
4. If the key is empty, the render fails with a descriptive error message
5. If the tag is a floating tag (`latest`, digest, or non-semver custom tag), the check is skipped

**Skipped scenarios:**

- Floating tags: `latest`, `main`, `develop`
- Digest references: `sha256:abc123...`
- Custom tags that don't parse as semver: `4.5.1-custom_1`, `4.6.0_patched`
- Existing Secrets: when `manager.useExistingSecret` or `worker.useExistingSecret` is set, the chart cannot inspect the Secret contents and assumes the operator has included the license

> **Note:** The enforcement only applies when the chart renders the Secret itself. If you use `manager.useExistingSecret` or `worker.useExistingSecret`, you are responsible for ensuring the existing Secret contains `LICENSE_KEY`.

## Configuration Reference

### License fields

| Field | Default | Description |
|-------|---------|-------------|
| `secrets.LICENSE_KEY` | `""` | Product license key (required for app >= 4.6.0) |
| `secrets.ORGANIZATION_IDS` | `""` | Per-organization license scope (defaults to `"global"` when unset) |

## Migration Steps

### Step 1: Obtain product license key

Contact Lerian Studio support to obtain a valid `LICENSE_KEY` for your deployment. If you require a per-organization license, also obtain the `ORGANIZATION_IDS` value.

### Step 2: Set license credentials

Add the license key to your `values.yaml` or values override file:

```yaml
secrets:
  LICENSE_KEY: "your-product-license-key"
  ORGANIZATION_IDS: ""  # Optional: set for per-organization license
```

If you use an existing Secret (via `manager.useExistingSecret` or `worker.useExistingSecret`), ensure the Secret contains the `LICENSE_KEY` field.

> **Important:** If you use separate existing Secrets for the manager and worker, both must contain `LICENSE_KEY`.

### Step 3: Execute the upgrade

Run the upgrade command with your updated values:

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm \
  --version 5.1.0 \
  -n reporter \
  -f values.yaml
```

> **Warning:** The upgrade rolls the manager Deployment (and the worker Deployment when KEDA is disabled). With the default KEDA ScaledJob, the chart sets no `rollout.strategy`, so KEDA deletes the worker Jobs of the previous version, including Jobs still running, and new worker Jobs start on the new image. A report that was being generated restarts from the beginning in a new Job, because the worker acknowledges its message only after finishing. To see the running Jobs before you upgrade: `kubectl get jobs -n reporter -l scaledjob.keda.sh/name=reporter-worker`. If `LICENSE_KEY` is not set, the chart will fail at render time with a descriptive error message.

### Step 4: Verify deployment health

Check that all pods are running and healthy:

```bash
kubectl get pods -n reporter
```

Verify manager and worker logs to confirm successful license validation:

```bash
kubectl logs -n reporter -l app.kubernetes.io/name=reporter-manager --tail=50
# Default KEDA ScaledJob: Job pods carry only the scaledjob.keda.sh/name label.
# With KEDA disabled, use -l app.kubernetes.io/name=reporter-worker instead.
kubectl logs -n reporter -l scaledjob.keda.sh/name=reporter-worker --tail=50
```

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 5.1.0 -n reporter -f values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

Pass the values file that carries `secrets.LICENSE_KEY`. Without `-f`, Helm reuses the release's stored values, and the render fails if they have no license.

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 5.1.0 -n reporter -f values.yaml
```
