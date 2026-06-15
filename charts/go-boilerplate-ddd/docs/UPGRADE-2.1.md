# Helm Upgrade from v2.0.1 to v2.1.0

This release marks the chart as **deprecated** and provides migration instructions to the new OCI registry location.

## Summary

| Aspect | Details |
|--------|---------|
| **Chart version change** | 2.0.1 → 2.1.0 |
| **App version** | 1.0.0 (unchanged) |
| **Breaking changes** | None |
| **Action required** | Yes - migration to new registry recommended |

## Topics

- **[Chart Deprecation](#chart-deprecation)**
  - [What Changed](#what-changed)
  - [Why This Matters](#why-this-matters)
  - [Migration Steps](#migration-steps)

## Chart Deprecation

### What Changed

The `go-boilerplate-ddd-helm` chart has been marked as deprecated and moved to a new OCI registry location. The chart description and metadata have been updated to reflect this change.

**Before (v2.0.1):**

```yaml
description: A Helm chart for Go Boilerplate DDD - Lerian reference service template
deprecated: false  # (implicit)
```

**After (v2.1.0):**

```yaml
description: '[DEPRECATED] Moved to helm-internal. Use oci://ghcr.io/lerianstudio/helm-internal/go-boilerplate-ddd-helm instead.'
deprecated: true
```

| Setting | v2.0.1 | v2.1.0 |
|---------|--------|--------|
| Chart status | Active | Deprecated |
| Registry location | `oci://registry-1.docker.io/lerianstudio/go-boilerplate-ddd-helm` | `oci://ghcr.io/lerianstudio/helm-internal/go-boilerplate-ddd-helm` (new) |

### Why This Matters

The chart is being relocated to a new internal registry at GitHub Container Registry (GHCR). While this v2.1.0 release remains functional and introduces no breaking changes to templates or configuration, future updates and support will only be available from the new registry location.

> **Important:** The old registry location (`oci://registry-1.docker.io/lerianstudio/go-boilerplate-ddd-helm`) will not receive updates beyond v2.1.0. Plan to migrate to the new location to receive future patches, features, and security updates.

### Migration Steps

You have two options for handling this deprecation:

#### Option 1: Continue using the deprecated chart temporarily

If you need time to plan your migration, you can upgrade to v2.1.0 from the existing registry. This version is fully functional and contains no breaking changes.

```bash
helm upgrade go-boilerplate-ddd oci://registry-1.docker.io/lerianstudio/go-boilerplate-ddd-helm --version 2.1.0 -n go-boilerplate-ddd
```

> **Warning:** This is a temporary solution. The deprecated registry will not receive updates beyond v2.1.0.

#### Option 2: Migrate to the new registry location (recommended)

Migrate your deployment to use the new GHCR registry location. This ensures you receive future updates and support.

1. **Verify access to the new registry**

   Ensure you have access to the new OCI registry at `ghcr.io/lerianstudio/helm-internal`:

   ```bash
   helm pull oci://ghcr.io/lerianstudio/helm-internal/go-boilerplate-ddd-helm --version 2.1.0
   ```

   If authentication is required, configure your Helm registry credentials:

   ```bash
   helm registry login ghcr.io
   ```

2. **Preview the migration**

   Use helm-diff to verify that switching registries produces no unexpected changes:

   ```bash
   helm diff upgrade go-boilerplate-ddd oci://ghcr.io/lerianstudio/helm-internal/go-boilerplate-ddd-helm --version 2.1.0 -n go-boilerplate-ddd
   ```

3. **Perform the upgrade with the new registry**

   ```bash
   helm upgrade go-boilerplate-ddd oci://ghcr.io/lerianstudio/helm-internal/go-boilerplate-ddd-helm --version 2.1.0 -n go-boilerplate-ddd
   ```

4. **Update your deployment automation**

   Update any CI/CD pipelines, GitOps configurations, or documentation that reference the old registry location to use the new GHCR URL:

   ```yaml
   # Old reference (deprecated)
   # oci://registry-1.docker.io/lerianstudio/go-boilerplate-ddd-helm
   
   # New reference
   oci://ghcr.io/lerianstudio/helm-internal/go-boilerplate-ddd-helm
   ```

> **Note:** The chart name, values schema, and all templates remain identical between registries. Only the registry URL changes.

## Preview changes before upgrading

```bash
helm diff upgrade go-boilerplate-ddd oci://registry-1.docker.io/lerianstudio/go-boilerplate-ddd-helm --version 2.1.0 -n go-boilerplate-ddd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade go-boilerplate-ddd oci://registry-1.docker.io/lerianstudio/go-boilerplate-ddd-helm --version 2.1.0 -n go-boilerplate-ddd
```
