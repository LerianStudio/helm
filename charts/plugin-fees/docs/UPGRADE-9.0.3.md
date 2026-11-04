# Helm Upgrade from v9.0.2 to v9.0.3

# Topics

- ***[Overview](#overview)***
- ***[Preview changes before upgrading](#preview-changes-before-upgrading)***
- ***[Command to upgrade](#command-to-upgrade)***
- ***[Verify the upgrade](#verify-the-upgrade)***

# Overview

This is a patch release. The app version stays at `3.4.0`. No `values.yaml` change and no action before or after the upgrade is required.

| Component | v9.0.2 | v9.0.3 |
|-----------|--------|--------|
| Chart version | 9.0.2 | 9.0.3 |
| App version | 3.4.0 | 3.4.0 (unchanged) |

**What changed:**

- The `fees` pod template no longer carries the `helm.sh/chart` label. The Deployment, Service, ConfigMap and Secret keep it. The Deployment selector is unchanged.
- `Chart.yaml` no longer links to a documentation page that does not exist.

**Impact:**

- The pod template changes, so the `fees` pods restart once during this upgrade. Later chart upgrades no longer restart them on a chart version change alone.
- The Deployment selector does not change, so the upgrade needs no delete and re-create.

The chart stays deprecated. To retire it, follow [Moving to Midaz](https://github.com/LerianStudio/helm/tree/main/charts/plugin-fees#moving-to-midaz) in the chart README.

# Preview changes before upgrading

The release name and namespace in the commands below are examples. Replace them with the values you used at install time.

```bash
helm diff upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 9.0.3 -n plugin-fees
```

> **Note:** Requires the helm-diff plugin. Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-fees oci://registry-1.docker.io/lerianstudio/plugin-fees-helm --version 9.0.3 -n plugin-fees
```

# Verify the upgrade

```bash
kubectl rollout status deployment -l app.kubernetes.io/instance=plugin-fees -n plugin-fees
kubectl get pods -l app.kubernetes.io/instance=plugin-fees -n plugin-fees
```

All pods must reach `Running` and `Ready`.
