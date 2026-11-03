<!-- {% raw %} -->
# Helm Upgrade from v1.1.0 to v1.1.1

## Topics

- **[Fixes](#fixes)**
  - [Graceful Shutdown Configuration](#graceful-shutdown-configuration)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Fixes

### Graceful Shutdown Configuration

This release adds explicit graceful shutdown configuration to ensure the application has sufficient time to drain in-flight requests and shut down cleanly during pod termination.

| Setting | v1.1.0 | v1.1.1 |
|---------|--------|--------|
| `terminationGracePeriodSeconds` | Not set (Kubernetes default: 30s) | `55` |
| `SHUTDOWN_DRAIN_DELAY` environment variable | Not set | `15s` |

**What changed:**

The chart now sets:

1. **Pod termination grace period** (`terminationGracePeriodSeconds: 55`): Kubernetes waits 55 seconds after sending SIGTERM before forcefully killing the pod
2. **Container environment variable** (`SHUTDOWN_DRAIN_DELAY: 15s`): a fixed value in the container `env` of the Deployment.

**Why it matters:**

The 55-second grace period is calculated as:
- 15s drain delay (allow deregistration from load balancers)
- 30s shutdown budget (complete in-flight requests and close connections)
- 10s safety margin (prevent premature SIGKILL)

App `1.0.0-beta.64`, the image this chart deploys, does not read `SHUTDOWN_DRAIN_DELAY`: its shutdown budget is a fixed 30s. With that image the 15s drain share has no effect.

**Configuration:**

**After (v1.1.1):**
```yaml
plugin-br-ted-lerian:
  # -- Seconds Kubernetes waits after SIGTERM before killing the pod
  # 55 = 15s drain + 30s shutdown budget + 10s margin
  terminationGracePeriodSeconds: 55
```

**New environment variable:**
- `SHUTDOWN_DRAIN_DELAY`: set to `15s` in the container `env` by the chart template (not a values key).

**Impact:**

- Kubernetes will wait up to 55 seconds for graceful shutdown before sending SIGKILL

**Migration:**

No action required. The new defaults are applied automatically on upgrade.

#### Customizing shutdown timeouts

If your application requires a longer or shorter grace period, you can override the default:

```yaml
plugin-br-ted-lerian:
  # Increase grace period for long-running requests
  terminationGracePeriodSeconds: 90
```

> **Warning:** Setting `terminationGracePeriodSeconds` too low may result in SIGKILL before graceful shutdown completes. Setting it too high may delay deployments and node drains unnecessarily.

---

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --version 1.1.1 -n plugin-br-ted-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --version 1.1.1 -n plugin-br-ted-lerian
```
<!-- {% endraw %} -->
