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
- New deployments should use the `midaz` chart instead, which includes fees functionality
- Existing deployments can continue running but should plan migration to the `midaz` chart

**Migration path:**

> **Important:** If you are running `plugin-fees` in production, begin planning your migration to the `midaz` chart. The fees functionality is now a native component of the Midaz ledger.

**For new deployments:**

Instead of installing `plugin-fees`, install the `midaz` chart:

```bash
helm install midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version <version> -n midaz --create-namespace
```

**For existing deployments:**

1. Review the [midaz chart documentation](https://github.com/LerianStudio/helm/tree/main/charts/midaz) to understand the integrated fees configuration
2. Plan a migration window to transition from the standalone `plugin-fees` deployment to the integrated fees functionality in `midaz`
3. Backup your current fees configuration and data before migration
4. Test the migration in a non-production environment first

Before you uninstall this release, follow [Moving to Midaz](https://github.com/LerianStudio/helm/tree/main/charts/plugin-fees#moving-to-midaz) in the chart README. Keep this release while Bank Transfer has an open `legacy` TED IN or any Pix Indirect BTG install calls it, and recreate the fee packages in Midaz with the [Midaz fees migration guide](https://docs.lerian.studio/en/products/midaz/fees/fees-migration-guide) instead of copying this database. With the bundled MongoDB, `helm uninstall` deletes the MongoDB volume and every fee record in it.

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
