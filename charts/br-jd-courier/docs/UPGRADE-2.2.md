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

The chart now sets a new environment variable `SHUTDOWN_DRAIN_DELAY` to `15s` for all role Deployments (`spb-consumer`, `spb-sender`, `pix-ingress`, `admin`). This variable controls an initial delay before the application begins its graceful shutdown sequence after receiving SIGTERM.

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

**Why it matters:**

The 15-second drain delay provides a buffer between when Kubernetes sends SIGTERM and when the application begins shutting down its internal components. This ensures:

1. **Readiness probe propagation:** The pod's readiness probe has time to fail and propagate through the Service endpoints before the HTTP server starts draining connections
2. **Load balancer deregistration:** External load balancers and ingress controllers have time to remove the pod from their backend pools
3. **In-flight request completion:** Requests that were already routed to the pod before SIGTERM can complete normally without hitting a closed listener

This is particularly important for the `spb-sender` and `pix-ingress` roles, which serve external traffic and need clean connection draining to avoid client errors during rolling updates.

**Migration action:**

No action required. The environment variable is set automatically by the chart. The application will honor this delay on its next restart (during the upgrade).

**If you need to adjust the delay:**

The drain delay is currently hardcoded in the chart templates. If your environment requires a different delay (e.g., due to slow load balancer updates), you would need to fork the chart or request a configurable value in a future release.

> **Note:** The 15-second delay is a Lerian Studio operational standard based on typical Kubernetes Service endpoint propagation times. Most operators should not need to change this value.

### Extended termination grace period

| Setting | v2.1.2 | v2.2.0 |
|---------|---------|---------|
| `terminationGracePeriodSeconds` | `100` | `115` |

**What changed:**

The pod termination grace period has been increased from 100 seconds to 115 seconds to account for the new 15-second `SHUTDOWN_DRAIN_DELAY`.

**Why it matters:**

The termination grace period must be long enough to accommodate the entire graceful shutdown sequence:

**Updated shutdown timeline (v2.2.0):**

| Time | Event |
|------|-------|
| t=0 | SIGTERM received |
| t=0–15 | `SHUTDOWN_DRAIN_DELAY`: pod waits before starting shutdown |
| t=15 | Actual shutdown begins: rail stop starts (except HTTP) |
| t=15–95 | Rail finishes: one read (15s) + one persist (60s) + 5s margin |
| t=27 | Readiness probe fails; HTTP drain starts (runs alongside rail stop) |
| After HTTP drain | Lifecycle hooks wait for rail, then 10s for workers |
| t=115 | SIGKILL if not exited |

The 15-second increase ensures that the `spb-consumer` role has the full 80 seconds it needs for rail shutdown (after the initial drain delay), plus the 10-second worker cleanup period, plus a 10-second margin before SIGKILL.

**Previous timeline (v2.1.2):**

| Time | Event |
|------|-------|
| t=0 | SIGTERM received; rail stop starts immediately |
| t≤80 | Rail finishes |
| t=12 | Readiness probe fails; HTTP drain starts |
| After HTTP drain | Lifecycle hooks wait for rail, then 10s for workers |
| t=100 | SIGKILL if not exited |

**Migration action:**

No action required. The increased grace period is set automatically by the chart and takes effect on the next pod restart (during the upgrade).

**If you have customized SPB budgets:**

If you have overridden the default SPB timing values in your `config` block, ensure your `terminationGracePeriodSeconds` is still sufficient:

```yaml
# Example: If you increased SPB budgets beyond defaults
config:
  SPB_TAKE_BUDGET_SEC: "30"      # Increased from 15
  SPB_PERSIST_TIMEOUT_SEC: "90"  # Increased from 60

# You must also increase the grace period:
terminationGracePeriodSeconds: 160  # 15 (drain delay) + 30 (take) + 90 (persist) + 10 (workers) + 15 (margin)
```

> **Important:** The chart does not automatically calculate `terminationGracePeriodSeconds` based on your SPB budget overrides. If you customize `SPB_TAKE_BUDGET_SEC` or `SPB_PERSIST_TIMEOUT_SEC`, you must manually adjust `terminationGracePeriodSeconds` to match.

**Formula for calculating grace period:**

```
terminationGracePeriodSeconds = SHUTDOWN_DRAIN_DELAY + SPB_TAKE_BUDGET_SEC + SPB_PERSIST_TIMEOUT_SEC + 10 (workers) + 15 (margin)
```

With defaults:
```
115 = 15 + 15 + 60 + 10 + 15
```

> **Note:** The 15-second margin accounts for telemetry export delays and other cleanup tasks. A collector that does not respond within this window will delay the shutdown by ~15 seconds, but a SIGKILL at that point loses only the last telemetry export, not application data.

---

## Preview changes before upgrading

```bash
helm diff upgrade br-jd-courier oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm --version 2.2.0 -n br-jd-courier
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade br-jd-courier oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm --version 2.2.0 -n br-jd-courier
```
<!-- {% endraw %} -->
