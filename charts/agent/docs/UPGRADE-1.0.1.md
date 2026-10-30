# Helm Upgrade from v1.0.0 to v1.0.1

This guide helps operators upgrade the **Lerian BYOC agent** chart from version **1.0.0** to **1.0.1**. This is a patch release that updates the agent application version and removes extraneous whitespace from the chart files.

## Topics

- **[Overview](#overview)**
- **[Changes in v1.0.1](#changes-in-v101)**
  - [Application Version Update](#application-version-update)
  - [Chart Formatting](#chart-formatting)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version **1.0.1** is a patch release that updates the agent application from `1.0.0` to `1.0.1` and normalizes chart file formatting. There are **no breaking changes**, **no new configuration options**, and **no required operator actions** beyond running `helm upgrade`.

**What changed:**

- Agent application version bumped to `1.0.1`
- Agent container image tag updated to `1.0.1`
- Whitespace normalization in `Chart.yaml` and `values.yaml`

**What stayed the same:**

- All configuration options remain unchanged
- All default values remain unchanged (except image tag)
- All RBAC, networking, and security settings remain unchanged
- All template files remain unchanged

## Changes in v1.0.1

### Application Version Update

The agent application and container image have been updated to version `1.0.1`.

| Setting | v1.0.0 | v1.0.1 |
|---------|--------|--------|
| `appVersion` | `1.0.0` | `1.0.1` |
| `agent.image.tag` | `1.0.0` | `1.0.1` |

**Before (v1.0.0):**

```yaml
agent:
  image:
    repository: ghcr.io/lerianstudio/agent
    tag: "1.0.0"
```

**After (v1.0.1):**

```yaml
agent:
  image:
    repository: ghcr.io/lerianstudio/agent
    tag: "1.0.1"
```

**Operational impact:**

When you run `helm upgrade`, the agent pod will be recreated with the new image tag. Because the deployment strategy is `Recreate` (not `RollingUpdate`), the existing pod will terminate before the new one starts. This ensures only one agent instance runs at a time.

> **Note:** If you have pinned the agent image using `agent.image.digest`, the digest value will take precedence over the tag. Review your values file and update the digest if needed, or remove it to use the tag-based version.

### Chart Formatting

The chart files have been reformatted to remove extraneous blank lines and normalize YAML structure. These changes have **no functional impact** and do not affect deployed resources.

**Changes:**

- Removed extra blank lines in `Chart.yaml` (between `annotations`, `version`, `appVersion`, `keywords`, and `dependencies`)
- Removed extra blank lines throughout `values.yaml` (between configuration sections)
- Normalized multi-line string formatting in `agent.description`

**Example from values.yaml:**

**Before (v1.0.0):**

```yaml
agent:
  # -- Component name
  name: agent

  # -- Component description
  description: "Lerian BYOC agent: executes the control plane's Helm operations in this cluster"

  # -- Enable or disable the agent
  enabled: true
```

**After (v1.0.1):**

```yaml
agent:
  # -- Component name
  name: agent
  # -- Component description
  description: "Lerian BYOC agent: executes the control plane's Helm operations in
    this cluster"
  # -- Enable or disable the agent
  enabled: true
```

> **Important:** These formatting changes do not alter any configuration values or defaults. Your existing values files will continue to work without modification.

## Migration Steps

This upgrade requires no manual migration steps. The only change that affects deployed resources is the agent container image tag.

**To upgrade:**

1. Review your current values file (if you have one):

```bash
helm get values agent -n agent > current-values.yaml
```

2. **(Optional)** If you have pinned the agent image using `agent.image.digest`, decide whether to keep the digest or switch to tag-based versioning:

   - **Keep digest:** Update your values file with the new digest for v1.0.1 (obtain from your control plane or registry)
   - **Switch to tag:** Remove the `agent.image.digest` field from your values file

3. Run the upgrade command (see below)

4. Verify the new pod is running:

```bash
kubectl -n agent get pods -l app.kubernetes.io/name=agent
kubectl -n agent logs deploy/lerian-agent | grep -i "version\|heartbeat"
```

> **Note:** The agent pod will restart during the upgrade. Any in-progress Helm operations will be interrupted. The agent will resume work after reconnecting to the control plane.

## Preview changes before upgrading

```bash
helm diff upgrade agent oci://registry-1.docker.io/lerianstudio/agent-helm --version 1.0.1 -n agent
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade agent oci://registry-1.docker.io/lerianstudio/agent-helm --version 1.0.1 -n agent
```
