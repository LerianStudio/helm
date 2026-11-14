# Helm Upgrade from v5.2.0 to v5.2.1

## Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that increments the chart version from `5.2.0` to `5.2.1`. The application version remains `1.12.0` and no configuration values or templates have changed.

**What changed:**

| Setting | v5.2.0 | v5.2.1 |
|---------|--------|--------|
| Chart version | `5.2.0` | `5.2.1` |
| App version | `1.12.0` | `1.12.0` |

**Why it matters:**

The only rendered change is the `helm.sh/chart` label, which changes from `plugin-br-pix-indirect-btg-helm-5.2.0` to `plugin-br-pix-indirect-btg-helm-5.2.1`. Probe configurations, environment variables and service behavior do not change.

**Operational impact:**

Upgrading to `5.2.1` restarts the pods of the five chart Deployments (`pix`, `inbound`, `outbound`, `reconciliation`, `schedule`), because the `helm.sh/chart` label in their pod templates now carries the new chart version. The bundled PostgreSQL, MongoDB and Valkey pods do not restart. No configuration changes.

**No action required** beyond running the upgrade command. Your existing values files and custom configurations remain fully compatible.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.2.1 -n plugin-br-pix-indirect-btg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.2.1 -n plugin-br-pix-indirect-btg
```
