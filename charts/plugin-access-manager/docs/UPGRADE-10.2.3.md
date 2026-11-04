<!-- {% raw %} -->
# Helm Upgrade from v10.2.2 to v10.2.3

# Topics

- **[Fixes](#fixes)**
  - [1. Graceful Shutdown Timing for Caradhras](#1-graceful-shutdown-timing-for-caradhras)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. Graceful Shutdown Timing for Caradhras

The chart now sets the environment variable `SHUTDOWN_DRAIN_DELAY` to `"5s"` on the caradhras container. It also updates the termination grace period comment to include this variable.

| Setting | v10.2.2 | v10.2.3 |
|---------|---------|---------|
| `SHUTDOWN_DRAIN_DELAY` environment variable | Not present | `"5s"` |
| Termination grace period calculation | `15 + SHUTDOWN_TIMEOUT_SEC (30) + 10` | `15 + SHUTDOWN_DRAIN_DELAY (5) + SHUTDOWN_TIMEOUT_SEC (30) + 5` |

The variable sets how long the caradhras readiness endpoint answers 503 after SIGTERM while the listener still serves. The chart's default caradhras image (`1.8.6`) does not read this variable, so the shutdown behavior does not change with the default image.

- The termination grace period stays 55 seconds.
- `SHUTDOWN_DRAIN_DELAY` is hardcoded to `"5s"` and is not configurable via `values.yaml`.
- No configuration changes are required.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.2.3 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.2.3 -n plugin-access-manager
```
<!-- {% endraw %} -->
