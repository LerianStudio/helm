# Helm Upgrade from v1.0.2 to v1.0.3

This guide helps operators upgrade the **Lerian BYOC agent** chart from version **1.0.2** to **1.0.3**. This is a patch release.

## Topics

- **[Overview](#overview)**
- **[Changes in v1.0.3](#changes-in-v103)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version **1.0.3** is a patch release. There are **no breaking changes**, **no configuration changes**, and **no template changes**.

**What changed:**

- Chart version bumped from `1.0.2` to `1.0.3`
- The license line in the chart README now reads Elastic License 2.0

**What stayed the same:**

- Agent application version remains `1.0.2`
- Agent container image tag remains `1.0.2`
- All configuration options remain unchanged
- All default values remain unchanged
- All RBAC, networking, and security settings remain unchanged
- All template files remain unchanged

## Changes in v1.0.3

| Setting | v1.0.2 | v1.0.3 |
|---------|--------|--------|
| Chart `version` | `1.0.2` | `1.0.3` |
| `appVersion` | `1.0.2` | `1.0.2` |
| `agent.image.tag` | `1.0.2` | `1.0.2` |

**Operational impact:**

The chart version is part of the `helm.sh/chart` label on the agent pod template, so `helm upgrade` replaces the agent pod. With the `Recreate` strategy (`agent.deploymentUpdate.type`), the old pod stops before the new one starts.

## Migration Steps

This upgrade requires no manual migration steps.

If the control plane has moved the agent to a newer build, record the digest the Deployment runs in `agent.image.digest` before you upgrade. Otherwise the upgrade re-renders the `1.0.2` tag and walks the agent back.

**To upgrade:**

1. Save your current values in a private temporary directory. The export can contain the agent token and registry credentials; do not commit or share it. Keep the following commands in the same shell so the cleanup trap remains active:

```bash
umask 077
values_dir=$(mktemp -d)
trap 'rm -f "$values_dir/current-values.yaml"; rmdir "$values_dir"' EXIT
helm get values lerian-agent -n lerian-system -o yaml > "$values_dir/current-values.yaml"
```

2. Read the image the Deployment runs:

```bash
kubectl -n lerian-system get deploy lerian-agent \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

If it ends in `@sha256:...`, set `agent.image.digest` to that `sha256:...` value in `$values_dir/current-values.yaml` (the private export created above).

3. Run the upgrade command (see below) with `-f "$values_dir/current-values.yaml"`

4. Verify the release was updated:

```bash
helm list -n lerian-system
```

The chart version should show `1.0.3`, while the app version remains `1.0.2`.

## Preview changes before upgrading

```bash
helm diff upgrade lerian-agent oci://registry-1.docker.io/lerianstudio/agent-helm --version 1.0.3 -n lerian-system -f "$values_dir/current-values.yaml"
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade lerian-agent oci://registry-1.docker.io/lerianstudio/agent-helm --version 1.0.3 -n lerian-system -f "$values_dir/current-values.yaml"
```
