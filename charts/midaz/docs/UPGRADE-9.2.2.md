# Helm Upgrade from v9.2.1 to v9.2.2

## Topics

- **[Fixes](#fixes)**
  - [1. Zero-downtime rollout strategy for CRM and Tracer services](#1-zero-downtime-rollout-strategy-for-crm-and-tracer-services)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Zero-downtime rollout strategy for CRM and Tracer services

The rolling update strategy for the `crm` and `tracer` services has been adjusted to prevent service interruptions during deployments, particularly in single-replica scenarios.

#### What changed

The `maxUnavailable` parameter in the deployment strategy has been changed from `1` to `0` for both services. This ensures that the new pod is fully ready before the old pod is terminated.

| Setting | v9.2.1 | v9.2.2 |
|---------|--------|--------|
| `crm.strategy.maxUnavailable` | `1` | `0` |
| `tracer.strategy.maxUnavailable` | `1` | `0` |

#### Why it matters

With `maxUnavailable: 1`, Kubernetes terminates the old pod before the new one is ready. If the replacement pod takes time to become ready (for example, waiting for a node to be provisioned via Karpenter due to nodeAffinity constraints), the service experiences downtime.

With `maxUnavailable: 0`, Kubernetes:
1. Creates the new pod first (`maxSurge: 1` allows this)
2. Waits for the new pod to pass readiness checks
3. Only then terminates the old pod

This is especially important for:
- Single-replica deployments where no other pod can handle traffic
- Environments using node autoscaling (e.g., Karpenter) where pod scheduling may be delayed
- Services with strict availability requirements

#### Configuration details

**Before (v9.2.1):**

```yaml
crm:
  strategy:
    type: RollingUpdate
    maxSurge: 1
    maxUnavailable: 1

tracer:
  strategy:
    type: RollingUpdate
    maxSurge: 1
    maxUnavailable: 1
```

**After (v9.2.2):**

```yaml
crm:
  strategy:
    type: RollingUpdate
    maxSurge: 1
    # 0 = surge the new pod and wait for it Ready before terminating the old one,
    # giving zero-downtime rollouts for single-replica components — matches the
    # ledger default. Important where the replacement pod may briefly stay Pending
    # (e.g. a required nodeAffinity that waits for a Karpenter node to be launched):
    # with maxUnavailable=1 the old pod is torn down first and the service blips.
    maxUnavailable: 0

tracer:
  strategy:
    type: RollingUpdate
    maxSurge: 1
    # 0 = surge the new pod and wait for it Ready before terminating the old one,
    # giving zero-downtime rollouts for single-replica components — matches the
    # ledger default. Important where the replacement pod may briefly stay Pending
    # (e.g. a required nodeAffinity that waits for a Karpenter node to be launched):
    # with maxUnavailable=1 the old pod is torn down first and the service blips.
    maxUnavailable: 0
```

> **Note:** This change aligns the `crm` and `tracer` services with the existing `ledger` service configuration, which already uses `maxUnavailable: 0` for zero-downtime deployments.

#### Action required

No action is required from operators. This change is applied automatically during the upgrade and improves deployment reliability without requiring configuration changes.

If you have explicitly overridden these values in your `values.yaml`, review whether you still need the override:

```yaml
# If you previously set:
crm:
  strategy:
    maxUnavailable: 1

# Consider removing the override to adopt the new default, or keep it if you have specific requirements
```

> **Important:** If you run multiple replicas of `crm` or `tracer` and prefer faster rollouts at the cost of brief capacity reduction, you can override back to `maxUnavailable: 1` in your values. However, for single-replica deployments, `maxUnavailable: 0` is strongly recommended.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.2 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.2 -n midaz
```
