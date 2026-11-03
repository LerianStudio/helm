<!-- {% raw %} -->
# Helm Upgrade from v2.1.2 to v2.2.0

## Topics

- **[Features](#features)**
  - [Shutdown drain delay configuration](#shutdown-drain-delay-configuration)
  - [Extended termination grace period](#extended-termination-grace-period)

---

## Features

### Shutdown drain delay configuration

| Setting | v2.1.2 | v2.2.0 |
|---------|---------|---------|
| `SHUTDOWN_DRAIN_DELAY` environment variable | Not set | `15s` (set for all roles) |

**What changed:**

The chart now sets a new environment variable `SHUTDOWN_DRAIN_DELAY` to `15s` for all role Deployments (`spb-consumer`, `spb-sender`, `pix-ingress`, `admin`).

**Before (v2.1.2):**

```yaml
env:
  - name: COURIER_ROLES
    value: {{ .role | quote }}
  # No SHUTDOWN_DRAIN_DELAY
```

**After (v2.2.0):**

```yaml
env:
  - name: SHUTDOWN_DRAIN_DELAY
    value: "15s"
  - name: COURIER_ROLES
    value: {{ .role | quote }}
```

**Migration action:**

No action required. The environment variable is set automatically by the chart.

**If you need to adjust the delay:**

The drain delay is currently hardcoded in the chart templates.


### Extended termination grace period

| Setting | v2.1.2 | v2.2.0 |
|---------|---------|---------|
| `terminationGracePeriodSeconds` | `100` | `115` |

**What changed:**

The pod termination grace period has been increased from 100 seconds to 115 seconds to account for the new 15-second `SHUTDOWN_DRAIN_DELAY`.

**Why it matters:**

The termination grace period must be long enough to accommodate the entire graceful shutdown sequence.

**Previous timeline (v2.1.2):**

| Time | Event |
|------|-------|
| t=0 | SIGTERM received; rail stop starts immediately |
| t≤80 | Rail finishes |
| t=12 | Readiness drain ends; HTTP drain starts (runs alongside rail stop) |
| After HTTP drain | Lifecycle hooks wait for rail, then 10s for workers |
| t=100 | SIGKILL if not exited |

**Migration action:**

No action required. The chart default rises to 115 and takes effect on the next pod restart (during the upgrade). If your values set `terminationGracePeriodSeconds`, the chart keeps your value; raise it by 15 to cover `SHUTDOWN_DRAIN_DELAY`.

**If you have customized SPB budgets:**

If you have overridden the default SPB timing values in your `config` block, ensure your `terminationGracePeriodSeconds` is still sufficient:

```yaml
# Example: If you increased SPB budgets beyond defaults
config:
  SPB_TAKE_BUDGET_SEC: "30"      # Increased from 15
  SPB_PERSIST_TIMEOUT_SEC: "90"  # Increased from 60

# You must also increase the grace period:
terminationGracePeriodSeconds: 160  # 15 (drain delay) + 30 (take) + 90 (persist) + 5 (routing) + 10 (workers) + 10 (margin)
```

> **Important:** The chart does not automatically calculate `terminationGracePeriodSeconds` based on your SPB budget overrides. If you customize `SPB_TAKE_BUDGET_SEC` or `SPB_PERSIST_TIMEOUT_SEC`, you must manually adjust `terminationGracePeriodSeconds` to match.

**Formula for calculating grace period:**

```
terminationGracePeriodSeconds = SHUTDOWN_DRAIN_DELAY + SPB_TAKE_BUDGET_SEC + SPB_PERSIST_TIMEOUT_SEC + 5 (routing margin) + 10 (workers) + 10 (margin)
```

With defaults:
```
115 = 15 + 15 + 60 + 5 + 10 + 10
```

> **Note:** A collector that does not answer holds the telemetry shutdown ~15 seconds; a SIGKILL at that point loses only the last telemetry export.

---

## Preview changes before upgrading

```bash
helm diff upgrade br-jd-courier oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm --version 2.2.0 -n br-jd-courier
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Note:** An anonymous pull from `registry-1.docker.io` is refused with `401`. Without Docker Hub access, use the GHCR reference `oci://ghcr.io/lerianstudio/br-jd-courier-helm` in both commands.

---

## Command to upgrade

```bash
helm upgrade br-jd-courier oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm --version 2.2.0 -n br-jd-courier
```
<!-- {% endraw %} -->
