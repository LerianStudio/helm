<!-- {% raw %} -->
# Helm Upgrade from v2.1.2 to v2.2.0

## Topics

- **[Features](#features)**
  - [Shutdown drain delay configuration](#shutdown-drain-delay-configuration)
  - [Extended termination grace period](#extended-termination-grace-period)
- **[Upgrade notes](#upgrade-notes)**
  - [Migration Job runs on every upgrade](#migration-job-runs-on-every-upgrade)

---

## Features

### Shutdown drain delay configuration

| Setting | v2.1.2 | v2.2.0 |
|---------|---------|---------|
| `SHUTDOWN_DRAIN_DELAY` environment variable | Not set | `15s` (set for all roles) |

**What changed:**

The chart now sets a new environment variable `SHUTDOWN_DRAIN_DELAY` to `15s` for all role Deployments (`spb-consumer`, `spb-sender`, `pix-ingress`, `admin`).

The variable takes effect only on images built on lib-commons v7.21.0-beta.20 or later. The chart's default image `1.2.1` is built on lib-commons v7.19.0, which does not read `SHUTDOWN_DRAIN_DELAY`, so with the default image the shutdown sequence is unchanged.

**Migration action:**

No action required. The environment variable is set automatically by the chart.

**If you need to adjust the delay:**

The drain delay is hardcoded in the chart templates. `config.SHUTDOWN_DRAIN_DELAY` does not change it: the pod env wins over the ConfigMap.

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
| t=12 | Readiness drain ends; HTTP drain starts (runs alongside rail stop) |
| t≤80 | Rail finishes |
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
  SPB_LEASE_TTL_SEC: "45"        # Must exceed SPB_TAKE_BUDGET_SEC + max(SPB_IDLE_INTERVAL_SEC, SPB_EMPTY_BACKOFF_CAP_SEC), or the spb-consumer refuses to start
                                 # (app defaults 5 and 10: 30 + 10 = 40 < 45)

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

## Upgrade notes

### Migration Job runs on every upgrade

With `migrations.enabled: true` (the default), the chart renders the `br-jd-courier-migrate` Job as a `pre-install,pre-upgrade` hook. It runs `migrate up` against the Courier database on every `helm upgrade`, before the Deployments change, including this one. If the Job fails, Helm marks the upgrade as failed and does not apply the new Deployments.

The Job name follows the release fullname: with a different release name, it is `<fullname>-migrate`.

---

## Preview changes before upgrading

```bash
helm diff upgrade br-jd-courier oci://ghcr.io/lerianstudio/br-jd-courier-helm --version 2.2.0 -n br-jd-courier -f values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Note:** Pass the values file of your release (`values.yaml` here, with any `config` or `terminationGracePeriodSeconds` change from this guide). Without `-f` or `--set`, Helm reuses the values stored in the release and ignores the edited file.

> **Note:** The commands use GHCR, as the chart README does. An anonymous pull from `oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm` is refused with `401`.

---

## Command to upgrade

```bash
helm upgrade br-jd-courier oci://ghcr.io/lerianstudio/br-jd-courier-helm --version 2.2.0 -n br-jd-courier -f values.yaml
```
<!-- {% endraw %} -->
