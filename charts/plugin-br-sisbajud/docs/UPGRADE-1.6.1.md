# Helm Upgrade from v1.6.0 to v1.6.1

This guide covers the upgrade of the `plugin-br-sisbajud` Helm chart from version **1.6.0** to **1.6.1**. This is a patch release that updates the application version and pins the migrations image to a specific version due to a build failure in the upstream release.

## Table of Contents

- **[Overview](#overview)**
- **[Changes](#changes)**
  - [Application Version Update](#application-version-update)
  - [Migrations Image Pinning](#migrations-image-pinning)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 1.6.1 updates the default application image from `1.3.0` to `1.5.0` and introduces a temporary pin for the migrations image to `1.4.0`. This release addresses a build failure in the `v1.5.0` release where the `plugin-br-sisbajud-migrations:1.5.0` image was not published due to a `proxy.golang.org` timeout during the build process.

**What changed:**

| Component | v1.6.0 | v1.6.1 | Impact |
|-----------|--------|--------|--------|
| `Chart.appVersion` | `1.3.0` | `1.5.0` | Application image defaults to newer version |
| `migrations.image.tag` | `""` (defaults to `Chart.appVersion`) | `"1.4.0"` (pinned) | Migrations use `1.4.0` instead of `1.5.0` |

**Migration impact:**

- **Application pods will be recreated** with the new `1.5.0` image (unless `sisbajud.image.tag` is explicitly set)
- **Migrations will continue using `1.4.0`** (schema-compatible with `1.5.0`)
- **No configuration changes required** for standard deployments

> **Important:** The `1.4.0` migrations image is schema-compatible with the `1.5.0` application. The `migrations/`, `migrations-image/Dockerfile`, `go.mod`, and all imported packages in `cmd/postgres-migrations` are identical between `v1.4.0` and `v1.5.0`.

## Changes

### Application Version Update

The default application image version has been updated from `1.3.0` to `1.5.0`.

**Chart.yaml change:**

| Setting | v1.6.0 | v1.6.1 |
|---------|--------|--------|
| `appVersion` | `1.3.0` | `1.5.0` |

**Operational impact:**

- Deployments that do **not** override `sisbajud.image.tag` will automatically pull `ghcr.io/lerianstudio/plugin-br-sisbajud:1.5.0`
- Deployments that **do** override `sisbajud.image.tag` will continue using the pinned version

**Example configuration (using default):**

```yaml
sisbajud:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-sisbajud
    tag: ""  # Defaults to Chart.appVersion (1.5.0)
    pullPolicy: IfNotPresent
```

**Example configuration (pinned to specific version):**

```yaml
sisbajud:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-sisbajud
    tag: "1.3.0"  # Explicitly pinned, will not change
    pullPolicy: IfNotPresent
```

### Migrations Image Pinning

The migrations image tag has been explicitly pinned to `1.4.0` in the default values due to a build failure in the `v1.5.0` release.

**values.yaml change:**

| Setting | v1.6.0 | v1.6.1 |
|---------|--------|--------|
| `migrations.image.tag` | `""` (defaults to `Chart.appVersion`) | `"1.4.0"` (pinned) |

**Before (v1.6.0):**

```yaml
migrations:
  enabled: true
  image:
    repository: ghcr.io/lerianstudio/plugin-br-sisbajud-migrations
    # -- Defaults to Chart.appVersion.
    tag: ""
    pullPolicy: IfNotPresent
```

**After (v1.6.1):**

```yaml
migrations:
  enabled: true
  image:
    repository: ghcr.io/lerianstudio/plugin-br-sisbajud-migrations
    # -- Defaults to Chart.appVersion when empty. Pinned to 1.4.0 because the
    # v1.5.0 release did not publish plugin-br-sisbajud-migrations:1.5.0 (its
    # build failed on a proxy.golang.org timeout). 1.4.0 runs the same schema:
    # migrations/, migrations-image/Dockerfile, go.mod and every package
    # cmd/postgres-migrations imports are identical between v1.4.0 and v1.5.0.
    # Set back to "" once the 1.5.0 migrations image exists.
    tag: "1.4.0"
    pullPolicy: IfNotPresent
```

**Operational impact:**

- Migrations will use `ghcr.io/lerianstudio/plugin-br-sisbajud-migrations:1.4.0` instead of attempting to pull `1.5.0` (which does not exist)
- The `1.4.0` migrations image is fully compatible with the `1.5.0` application (identical schema definitions)
- This pin will be removed in a future release once the `1.5.0` migrations image is successfully published

> **Note:** The comment in `values.yaml` instructs operators to set `migrations.image.tag` back to `""` once the `1.5.0` migrations image becomes available. Monitor the upstream repository for this update.

**Why this matters:**

Without this pin, deployments using the default `migrations.image.tag: ""` would attempt to pull `plugin-br-sisbajud-migrations:1.5.0` (matching `Chart.appVersion`), which would fail with an image pull error. The explicit `1.4.0` pin ensures migrations continue to run successfully.

**Schema compatibility verification:**

The following files are identical between `v1.4.0` and `v1.5.0`:

- `migrations/` directory (all SQL migration files)
- `migrations-image/Dockerfile`
- `go.mod` (migration dependencies)
- All packages imported by `cmd/postgres-migrations`

This guarantees that running `1.4.0` migrations against a `1.5.0` application deployment is safe and correct.

## Migration Steps

This upgrade requires no manual intervention for standard deployments. Follow these steps based on your configuration:

### Standard Deployment (No Custom Image Tags)

**No action required.** The upgrade will:

1. Update the application pods to use `1.5.0`
2. Continue using `1.4.0` for migrations (pre-install/pre-upgrade hook)

**Upgrade command:**

```bash
helm upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm -n sisbajud --version 1.6.1
```

### Deployment with Pinned Application Image

If you have explicitly set `sisbajud.image.tag` in your `values.yaml`:

**Your configuration:**

```yaml
sisbajud:
  image:
    tag: "1.3.0"  # Explicitly pinned
```

**Action:** Decide whether to upgrade to `1.5.0` or remain on your pinned version.

#### Option 1: Upgrade to 1.5.0

Remove the explicit pin to use the new default:

```yaml
sisbajud:
  image:
    tag: ""  # Use Chart.appVersion (1.5.0)
```

#### Option 2: Stay on Current Version

Keep your existing pin:

```yaml
sisbajud:
  image:
    tag: "1.3.0"  # Remain on 1.3.0
```

> **Note:** If you remain on `1.3.0`, the migrations will still upgrade to `1.4.0` (which is forward-compatible).

### Deployment with Custom Migrations Image

If you have explicitly set `migrations.image.tag` in your `values.yaml`:

**Your configuration:**

```yaml
migrations:
  image:
    tag: "1.3.0"  # Custom pin
```

**Action:** Update to `1.4.0` or remove the pin to use the new default:

```yaml
migrations:
  image:
    tag: "1.4.0"  # Match new default
```

Or:

```yaml
migrations:
  image:
    tag: ""  # Use default (currently 1.4.0)
```

> **Warning:** Do not set `migrations.image.tag: "1.5.0"` — this image does not exist and will cause image pull failures.

### Verification After Upgrade

After running the upgrade, verify the deployed image versions:

```bash
# Check application pod image
kubectl get deployment plugin-br-sisbajud -n sisbajud -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check migrations job image (if using Job mode)
kubectl get job -n sisbajud -l app.kubernetes.io/component=migrations --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].spec.template.spec.containers[0].image}'
```

**Expected output:**

```
ghcr.io/lerianstudio/plugin-br-sisbajud:1.5.0
ghcr.io/lerianstudio/plugin-br-sisbajud-migrations:1.4.0
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm -n sisbajud --version 1.6.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm -n sisbajud --version 1.6.1
```
