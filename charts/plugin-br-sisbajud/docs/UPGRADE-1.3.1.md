# Helm Upgrade from v1.3.0 to v1.3.1

This guide covers the upgrade of the `plugin-br-sisbajud` Helm chart from version **1.3.0** to **1.3.1**. This is a patch release. It does not change the application image or any value.

## Table of Contents

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**
- **[Verify](#verify)**

## Overview

**What changed:**

| Area | Change |
|------|--------|
| Pod template | The pod template no longer carries the `helm.sh/chart` label. The other labels are unchanged. |
| Pod template | The `checksum/config` and `checksum/secret` annotations now hash only the ConfigMap `data` and the Secret `stringData`. |
| Documentation | The README, the getting-started guides and the `NOTES.txt` output describe application version 1.2.0, the version the chart deploys. |

**Application version:**

| Chart Version | App Version |
|---------------|-------------|
| 1.3.0 | 1.2.0 |
| 1.3.1 | 1.2.0 |

**Migration impact:**

- **No action required** before or after the upgrade.
- There are no changes to default values, environment variables or the values schema.
- The pod template changes, so the `sisbajud` pods restart once during the upgrade. Subsequent chart upgrades no longer restart the pods only because the chart version changed.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm -n sisbajud --version 1.3.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm -n sisbajud --version 1.3.1
```

## Verify

```bash
kubectl rollout status deployment -n sisbajud -l app.kubernetes.io/instance=plugin-br-sisbajud
helm list -n sisbajud
```

The release shows chart `plugin-br-sisbajud-helm-1.3.1` and the rollout completes.
