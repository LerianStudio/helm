<!-- {% raw %} -->
# Helm Upgrade from v1.4.1 to v1.4.2

## Topics

- **[Fixes](#fixes)**
  - [Graceful shutdown configuration](#graceful-shutdown-configuration)

## Fixes

### Graceful shutdown configuration

The chart now explicitly sets `terminationGracePeriodSeconds` on the br-sisbajud deployment. Previously, the chart relied on the Kubernetes default 30-second termination grace period.

| Setting | v1.4.1 | v1.4.2 |
|---------|--------|--------|
| `brSisbajud.terminationGracePeriodSeconds` | Not set (Kubernetes default: 30s) | `55` (15s drain delay + 30s shutdown budget + 10s margin) |
| `SHUTDOWN_DRAIN_DELAY` | Not set | `"15s"` (default), added to the ConfigMap |

The deployment now sets `terminationGracePeriodSeconds: 55` and adds `SHUTDOWN_DRAIN_DELAY` (default `"15s"`) to the ConfigMap. Override the ConfigMap value with `brSisbajud.configmap.SHUTDOWN_DRAIN_DELAY`.

#### New configuration flags

| Flag | Default | Description |
|------|---------|-------------|
| `brSisbajud.terminationGracePeriodSeconds` | `55` | Kubernetes termination grace period |

#### Customizing shutdown timing

To override the default grace period, add the following to your `values.yaml`:

```yaml
brSisbajud:
  terminationGracePeriodSeconds: 75
```

> **Warning:** Never set `terminationGracePeriodSeconds` lower than 55 seconds. The chart comment states: "never lower it."

#### Validation changes

The chart's validation error message has been reworded; the check itself (a whole number below 30) is unchanged:

**Before (v1.4.1):**

```yaml
{{- if or (not (regexMatch "^[0-9]+$" $closeS)) (ge (atoi $closeS) 30) -}}
{{- fail (printf "\n\nERROR: br-sisbajud: STREAMING_CLOSE_TIMEOUT_S must be a whole number of seconds below the pod terminationGracePeriodSeconds (Kubernetes default 30; this chart does not override it), got %q.\n  set: brSisbajud.streaming.closeTimeoutS (default \"20\")\n" $closeS) -}}
{{- end -}}
```

**After (v1.4.2):**

```yaml
{{- if or (not (regexMatch "^[0-9]+$" $closeS)) (ge (atoi $closeS) 30) -}}
{{- fail (printf "\n\nERROR: br-sisbajud: STREAMING_CLOSE_TIMEOUT_S must be a whole number of seconds below the 30s shutdown budget that runs inside terminationGracePeriodSeconds, got %q.\n  set: brSisbajud.streaming.closeTimeoutS (default \"20\")\n" $closeS) -}}
{{- end -}}
```

`STREAMING_CLOSE_TIMEOUT_S` must stay below the 30-second shutdown budget, not the full `terminationGracePeriodSeconds`.

#### Migration steps

No action is required. The chart automatically applies the new defaults:

1. `terminationGracePeriodSeconds: 55` is set on the deployment
2. `SHUTDOWN_DRAIN_DELAY: "15s"` is added to the ConfigMap

Existing deployments will be updated with these values on the next `helm upgrade`.

## Preview changes before upgrading

```bash
helm diff upgrade br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm --version 1.4.2 -n br-sisbajud
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm --version 1.4.2 -n br-sisbajud
```
<!-- {% endraw %} -->
