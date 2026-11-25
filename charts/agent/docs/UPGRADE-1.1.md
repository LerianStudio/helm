# Helm Upgrade from v1.0.6 to v1.1.0

This guide helps operators upgrade the **Lerian BYOC agent** chart from version **1.0.6** to **1.1.0**. This is a minor release that adds a new environment variable to the agent deployment to communicate which namespaces the agent is authorized to manage.

## Topics

- **[Overview](#overview)**
- **[Changes in v1.1.0](#changes-in-v110)**
  - [New Environment Variable: AGENT_MANAGED_NAMESPACES](#new-environment-variable-agent_managed_namespaces)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version **1.1.0** is a minor release that introduces a new environment variable to the agent deployment. The agent now receives an explicit list of namespaces it is authorized to manage, derived from the same RBAC configuration used to generate the agent's Roles in `rbac.yaml`. This ensures the agent's runtime behavior and RBAC permissions are always in sync.

**What changed:**

- New environment variable `AGENT_MANAGED_NAMESPACES` added to the agent deployment
- The variable is automatically populated from the chart's RBAC configuration using the `lerian-agent.managedNamespaces` template helper

**What stayed the same:**

- Agent application version remains `1.0.2`
- Agent container image tag remains `1.0.2`
- All configuration options remain unchanged
- All default values remain unchanged
- All RBAC, networking, and security settings remain unchanged

**Operational impact:**

This upgrade will trigger a pod restart to inject the new environment variable. The agent will continue to operate with the same permissions as before—this change only makes those permissions explicitly visible to the agent at runtime.

## Changes in v1.1.0

### New Environment Variable: AGENT_MANAGED_NAMESPACES

The agent deployment now includes a new environment variable that lists all namespaces the agent is authorized to manage. This variable is automatically generated from the same configuration that drives the RBAC Roles, ensuring the two never disagree.

**Before (v1.0.6):**

```yaml
env:
  - name: AGENT_SELF_NAMESPACE
    valueFrom:
      fieldRef:
        fieldPath: metadata.namespace
  - name: AGENT_SELF_DEPLOYMENT
    value: "lerian-agent"
```

**After (v1.1.0):**

```yaml
env:
  - name: AGENT_SELF_NAMESPACE
    valueFrom:
      fieldRef:
        fieldPath: metadata.namespace
  - name: AGENT_SELF_DEPLOYMENT
    value: "lerian-agent"
  # The namespaces the agent may write to, built from the same list as
  # the RBAC Roles in rbac.yaml so the two never disagree.
  - name: AGENT_MANAGED_NAMESPACES
    value: "namespace1,namespace2,namespace3"
```

**What it does:**

The `AGENT_MANAGED_NAMESPACES` variable provides the agent with a comma-separated list of namespaces it is authorized to manage. The agent application can use this list to:

- Validate incoming requests against its authorized scope
- Provide better error messages when asked to operate outside its permissions
- Log or report its operational boundaries

**How it's populated:**

The value is generated using the `lerian-agent.managedNamespaces` template helper, which reads the same configuration that generates the agent's RBAC Roles. This ensures the environment variable and RBAC permissions are always consistent.

| Environment Variable | Source | Format |
|---------------------|--------|--------|
| `AGENT_MANAGED_NAMESPACES` | `lerian-agent.managedNamespaces` template helper | Comma-separated namespace list |

**Operational impact:**

When you run `helm upgrade`, the agent pod will be recreated with the new environment variable. Because the deployment strategy is `Recreate` (not `RollingUpdate`), the existing pod will terminate before the new one starts. This ensures only one agent instance runs at a time.

The agent's actual permissions remain unchanged—this variable only makes those permissions visible to the agent at runtime. No configuration changes are required from operators.

> **Note:** The agent pod will restart during the upgrade. Any in-progress Helm operations will be interrupted. The agent will resume work after reconnecting to the control plane.

## Migration Steps

This upgrade requires no manual migration steps. The new environment variable is automatically populated from existing chart configuration.

**To upgrade:**

1. Review your current values file (if you have one):

```bash
helm get values lerian-agent -n lerian-system > current-values.yaml
```

2. Run the upgrade command (see below)

3. Verify the new pod is running and the environment variable is set:

```bash
kubectl -n lerian-system get pods -l app.kubernetes.io/name=agent
kubectl -n lerian-system exec deploy/lerian-agent -- env | grep AGENT_MANAGED_NAMESPACES
```

4. Check the agent logs to confirm it has reconnected to the control plane:

```bash
kubectl -n lerian-system logs deploy/lerian-agent | grep -i "version\|heartbeat"
```

> **Note:** If you have customized the agent's RBAC configuration (e.g., by modifying the namespaces the agent can access), the `AGENT_MANAGED_NAMESPACES` variable will automatically reflect those customizations. No additional action is required.

## Preview changes before upgrading

```bash
helm diff upgrade lerian-agent oci://ghcr.io/lerianstudio/agent-helm --namespace lerian-system --version 1.1.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade lerian-agent oci://ghcr.io/lerianstudio/agent-helm --namespace lerian-system --version 1.1.0
```
