# Helm Upgrade from v1.0.2 to v1.0.3

This guide helps operators upgrade the **Lerian BYOC agent** chart from version **1.0.2** to **1.0.3**. This is a patch release that updates only the chart version metadata.

## Topics

- **[Overview](#overview)**
- **[Changes in v1.0.3](#changes-in-v103)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version **1.0.3** is a patch release that updates the chart version metadata only. There are **no breaking changes**, **no configuration changes**, **no template changes**, and **no required operator actions** beyond running `helm upgrade`.

**What changed:**

- Chart version bumped from `1.0.2` to `1.0.3`

**What stayed the same:**

- Agent application version remains `1.0.2`
- Agent container image tag remains `1.0.2`
- All configuration options remain unchanged
- All default values remain unchanged
- All RBAC, networking, and security settings remain unchanged
- All template files remain unchanged

## Changes in v1.0.3

This release contains only a chart version bump with no functional changes.

| Setting | v1.0.2 | v1.0.3 |
|---------|--------|--------|
| Chart `version` | `1.0.2` | `1.0.3` |
| `appVersion` | `1.0.2` | `1.0.2` |
| `agent.image.tag` | `1.0.2` | `1.0.2` |

**Operational impact:**

When you run `helm upgrade`, Helm will update the chart metadata in the release history but will not modify any deployed Kubernetes resources. The agent pod will **not** restart, and there will be no service interruption.

> **Note:** This is a metadata-only release. No pods, services, or other resources will be recreated or modified during the upgrade.

## Migration Steps

This upgrade requires no manual migration steps. No deployed resources will be affected.

**To upgrade:**

1. Review your current values file (if you have one):

```bash
helm get values agent -n agent > current-values.yaml
```

2. Run the upgrade command (see below)

3. Verify the release was updated:

```bash
helm list -n agent
```

The chart version should show `1.0.3`, while the app version remains `1.0.2`.

## Preview changes before upgrading

```bash
helm diff upgrade agent oci://registry-1.docker.io/lerianstudio/agent-helm --version 1.0.3 -n agent
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade agent oci://registry-1.docker.io/lerianstudio/agent-helm --version 1.0.3 -n agent
```
