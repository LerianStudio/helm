<!-- {% raw %} -->
# Helm Upgrade from v1.0.4 to v1.0.5

This guide helps operators upgrade the **Lerian BYOC agent** chart from version **1.0.4** to **1.0.5**. This is a patch release. It needs no action before or after the upgrade, except one conditional step in [Migration Steps](#migration-steps).

## Topics

- **[Overview](#overview)**
- **[Changes in v1.0.5](#changes-in-v105)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**
- **[Verify](#verify)**

## Overview

Version **1.0.5** removes the `helm.sh/chart` label from the agent pod template. There are **no breaking changes**, **no new or changed values**, and **no RBAC changes**.

**What stayed the same:**

- Application version remains `1.0.2`
- Agent container image tag remains `1.0.2`
- Deployment selectors, so the upgrade does not recreate the Deployment
- All configuration options and default values

## Changes in v1.0.5

| Item | v1.0.4 | v1.0.5 |
|------|--------|--------|
| `helm.sh/chart` label on the agent pod template | present | removed |
| `helm.sh/chart` label on all other resources | `agent-helm-1.0.4` | `agent-helm-1.0.5` |
| `sources` in `Chart.yaml` | two entries | the chart directory only |

**Operational impact:**

The pod template changes, so `helm upgrade` replaces the agent pod once. With the `Recreate` strategy (`agent.deploymentUpdate.type`), the old pod stops before the new one starts.

## Migration Steps

The commands below use the release name `lerian-agent` and the namespace `lerian-system` from the chart README install command. They are examples: replace them with the values you used at install time.

One step applies only if the control plane has moved the agent to a newer build. Read the image the Deployment runs:

```bash
kubectl -n lerian-system get deploy lerian-agent \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

If the image ends in `@sha256:<digest>`, add `--reuse-values --set agent.image.digest=sha256:<digest>` to the upgrade command below. Otherwise the upgrade re-renders the `1.0.2` tag and walks the agent back.

Save your current values (optional):

```bash
helm get values lerian-agent -n lerian-system > current-values.yaml
```

## Preview changes before upgrading

```bash
helm diff upgrade lerian-agent oci://ghcr.io/lerianstudio/agent-helm --namespace lerian-system --version 1.0.5
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade lerian-agent oci://ghcr.io/lerianstudio/agent-helm --namespace lerian-system --version 1.0.5
```

## Verify

```bash
helm list -n lerian-system
kubectl get pods -n lerian-system -l app.kubernetes.io/instance=lerian-agent
```

The chart version shows `1.0.5` and the app version remains `1.0.2`. The agent pod is new and reaches `Running`.
<!-- {% endraw %} -->
