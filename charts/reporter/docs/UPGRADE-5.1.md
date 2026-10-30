# Helm Upgrade from v5.0.1 to v5.1.0

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Product license now required for app >= 4.6.0](#1-product-license-now-required-for-app--460)
- **[Features](#features)**
  - [1. Application version bump to 4.6.0](#1-application-version-bump-to-460)
  - [2. Regulatory catalog integration](#2-regulatory-catalog-integration)
  - [3. Chart-level license enforcement](#3-chart-level-license-enforcement)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
  - [Step 1: Obtain product license key](#step-1-obtain-product-license-key)
  - [Step 2: Set license credentials](#step-2-set-license-credentials)
  - [Step 3: Configure regulatory catalog (optional)](#step-3-configure-regulatory-catalog-optional)
  - [Step 4: Execute the upgrade](#step-4-execute-the-upgrade)
  - [Step 5: Verify deployment health](#step-5-verify-deployment-health)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that bumps the application version to `4.6.0` and introduces two major changes: mandatory product licensing and optional regulatory catalog integration. The manager and worker components now refuse to boot without a valid `LICENSE_KEY`, and the chart enforces this requirement at render time for app versions >= 4.6.0.

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
ERROR: secrets.LICENSE_KEY is REQUIRED for reporter app >= 4.6.0 (manager.image.tag is "4.6.0").
   The manager AND the worker refuse to boot without a license.
   Set secrets.LICENSE_KEY (and secrets.ORGANIZATION_IDS for a per-organization license),
   or point manager.useExistingSecret at a Secret that carries them.
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

> **Note:** The chart only enforces the license requirement when the resolved image tag can be parsed as semver and is >= 4.6.0. Floating tags (`latest`, digest references, or custom tags like `4.5.1-custom_1`) bypass the gate, allowing you to test custom builds without a license. However, the application itself will still refuse to boot without `LICENSE_KEY` if it is version 4.6.0 or later.

## Features

### 1. Application version bump to 4.6.0

The manager and worker image tags have been updated from `4.5.1` to `4.6.0`, and the chart `appVersion` field reflects this change.

| Component | v5.0.1 | v5.1.0 |
|-----------|--------|--------|
| `manager.image.tag` | `"4.5.1"` | `"4.6.0"` |
| `worker.image.tag` | `"4.5.1"` | `"4.6.0"` |
| Chart `appVersion` | `"4.5.1"` | `"4.6.0"` |

### 2. Regulatory catalog integration

The chart now supports optional integration with the Lerian regulatory catalog, which provides compliance rules and templates. The catalog can be sourced from a public or private GitHub repository, with automatic Sigstore attestation verification for releases read from GitHub.

**New configuration fields (all optional):**

| Field | Default | Description |
|-------|---------|-------------|
| `manager.configmap.REGULATORY_CATALOG_GITHUB_REPO` | not set | GitHub repository for the catalog (e.g., `"LerianStudio/lerian-regulatory-catalog"`) |
| `manager.configmap.REGULATORY_CATALOG_CHANNEL` | not set | Release channel: `"stable"` (production), `"rc"` (staging), or `"beta"` (development) |
| `manager.configmap.REGULATORY_CATALOG_GITHUB_TOKEN` | not set | GitHub token for private repositories (set in `secrets`, not configmap) |
| `manager.configmap.REGULATORY_CATALOG_GITHUB_URL` | not set | GitHub Enterprise API root (empty = github.com) |
| `manager.configmap.REGULATORY_CATALOG_DIR` | not set | Path to a mounted catalog tree (for development; bypasses verification) |
| `secrets.REGULATORY_CATALOG_GITHUB_TOKEN` | not set | GitHub token for private catalog repositories |

**Example configuration for public catalog:**

```yaml
manager:
  configmap:
    REGULATORY_CATALOG_GITHUB_REPO: "LerianStudio/lerian-regulatory-catalog"
    REGULATORY_CATALOG_CHANNEL: "stable"
```

**Example configuration for private catalog:**

```yaml
manager:
  configmap:
    REGULATORY_CATALOG_GITHUB_REPO: "your-org/private-regulatory-catalog"
    REGULATORY_CATALOG_CHANNEL: "stable"

secrets:
  REGULATORY_CATALOG_GITHUB_TOKEN: "ghp_your_github_token"
```

**Example configuration for development (mounted catalog):**

```yaml
manager:
  configmap:
    REGULATORY_CATALOG_DIR: "/mnt/catalog"

# Mount the catalog tree into both manager and worker pods
# (requires custom volume and volumeMount configuration)
```

> **Note:** When the regulatory catalog is not configured, the regulatory surface answers with error code `RPT-0147` and all other functionality continues to work normally.

> **Important:** Releases read from GitHub are verified offline using Sigstore attestation against a root certificate embedded in the application. No additional keys or tokens are required for verification. The `REGULATORY_CATALOG_GITHUB_TOKEN` is only needed for private repositories.

> **Warning:** The `REGULATORY_CATALOG_DIR` option is intended for development only and bypasses Sigstore verification. If you use this option, you must mount the catalog tree into both the manager and worker pods, and set the variable in `common.configmap` (or in both `manager.configmap` and `worker.configmap`).

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

### Regulatory catalog fields (manager configmap)

| Field | Default | Description |
|-------|---------|-------------|
| `manager.configmap.REGULATORY_CATALOG_GITHUB_REPO` | not set | GitHub repository for the catalog (e.g., `"LerianStudio/lerian-regulatory-catalog"`) |
| `manager.configmap.REGULATORY_CATALOG_CHANNEL` | not set | Release channel: `"stable"`, `"rc"`, or `"beta"` |
| `manager.configmap.REGULATORY_CATALOG_GITHUB_URL` | not set | GitHub Enterprise API root (empty = github.com) |
| `manager.configmap.REGULATORY_CATALOG_DIR` | not set | Path to a mounted catalog tree (development only; not verified) |

### Regulatory catalog fields (secrets)

| Field | Default | Description |
|-------|---------|-------------|
| `secrets.REGULATORY_CATALOG_GITHUB_TOKEN` | not set | GitHub token for private catalog repositories |

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

If you use an existing Secret (via `manager.useExistingSecret` or `worker.useExistingSecret`), ensure the Secret contains the `LICENSE_KEY` field:

```bash
kubectl create secret generic reporter-manager \
  --from-literal=LICENSE_KEY="your-product-license-key" \
  --from-literal=ORGANIZATION_IDS="" \
  --dry-run=client -o yaml | kubectl apply -f -
```

> **Important:** If you use separate existing Secrets for the manager and worker, both must contain `LICENSE_KEY`.

### Step 3: Configure regulatory catalog (optional)

If you want to enable regulatory catalog integration, add the catalog configuration to your values file:

**For public catalog:**

```yaml
manager:
  configmap:
    REGULATORY_CATALOG_GITHUB_REPO: "LerianStudio/lerian-regulatory-catalog"
    REGULATORY_CATALOG_CHANNEL: "stable"
```

**For private catalog:**

```yaml
manager:
  configmap:
    REGULATORY_CATALOG_GITHUB_REPO: "your-org/private-regulatory-catalog"
    REGULATORY_CATALOG_CHANNEL: "stable"

secrets:
  REGULATORY_CATALOG_GITHUB_TOKEN: "ghp_your_github_token"
```

> **Note:** If you do not configure the regulatory catalog, the application will continue to function normally, but the regulatory surface will return error code `RPT-0147` for catalog-dependent operations.

### Step 4: Execute the upgrade

Run the upgrade command with your updated values:

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm \
  --version 5.1.0 \
  -n reporter \
  -f values.yaml
```

> **Warning:** The upgrade will trigger a rolling restart of both manager and worker deployments. If `LICENSE_KEY` is not set, the chart will fail at render time with a descriptive error message.

### Step 5: Verify deployment health

Check that all pods are running and healthy:

```bash
kubectl get pods -n reporter
```

Verify manager and worker logs to confirm successful license validation:

```bash
kubectl logs -n reporter -l app.kubernetes.io/name=reporter-manager --tail=50
kubectl logs -n reporter -l app.kubernetes.io/name=reporter-worker --tail=50
```

If you configured the regulatory catalog, verify that the manager has successfully loaded the catalog:

```bash
kubectl logs -n reporter -l app.kubernetes.io/name=reporter-manager --tail=100 | grep -i "regulatory"
```

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 5.1.0 -n reporter
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 5.1.0 -n reporter
```
