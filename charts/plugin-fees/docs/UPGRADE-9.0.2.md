# Helm Upgrade from v9.0.1 to v9.0.2

# Topics

- ***[Important Notice](#important-notice)***
    - [1. Chart Deprecation](#1-chart-deprecation)
- ***[Preview changes before upgrading](#preview-changes-before-upgrading)***
- ***[Command to upgrade](#command-to-upgrade)***

# Important Notice

### 1. Chart Deprecation

The `plugin-fees` chart has been officially deprecated in v9.0.2. The fees functionality is now integrated directly into the Midaz ledger.

| Setting | v9.0.1 | v9.0.2 |
|---------|--------|--------|
| Chart status | Active | **Deprecated** |
| Chart description | "A Helm chart for Kubernetes" | "DEPRECATED - fees run inside the Midaz ledger; install the midaz chart instead" |
| Deprecated flag | Not set | `true` |

**What this means:**

- The `plugin-fees` chart will no longer receive feature updates
- Security patches and critical bug fixes may still be provided for a limited time
- New deployments should use the `midaz` chart instead, which includes fees functionality
- Existing deployments can continue running but should plan migration to the `midaz` chart

**Migration path:**

> **Important:** If you are running `plugin-fees` in production, begin planning your migration to the `midaz` chart. The fees functionality is now a native component of the Midaz ledger and does not require a separate plugin installation.

**For new deployments:**

Instead of installing `plugin-fees`, install the `midaz` chart:

```bash
helm install midaz oci://registry-1.docker.io/lerianstudio/midaz --version <latest-version> -n midaz
```

**For existing deployments:**

1. Review the [midaz chart documentation](https://github.com/LerianStudio/helm/tree/main/charts/midaz) to understand the integrated fees configuration
2. Plan a migration window to transition from the standalone `plugin-fees` deployment to the integrated fees functionality in `midaz`
3. Backup your current fees configuration and data before migration
4. Test the migration in a non-production environment first

> **Note:** You can still upgrade to v9.0.2 to receive any final patches, but no new features will be added to this chart. The deprecation notice serves as an early warning to plan your migration timeline.

**No configuration changes required:**

This is a patch release that only updates metadata. All existing configuration values remain unchanged and compatible. If you choose to upgrade to v9.0.2, no changes to your `values.yaml` are required.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 9.0.2 -n plugin-fees
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 9.0.2 -n plugin-fees
```
