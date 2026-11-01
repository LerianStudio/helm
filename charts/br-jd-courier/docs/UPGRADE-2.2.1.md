# Helm Upgrade from v2.2.0 to v2.2.1

## Topics

- **[Fixes](#fixes)**
  - [Graceful shutdown documentation update](#graceful-shutdown-documentation-update)

---

## Fixes

### Graceful shutdown documentation update

| Setting | v2.2.0 | v2.2.1 |
|---------|---------|---------|
| `terminationGracePeriodSeconds` | `115` | `115` (unchanged) |
| Documentation | Outdated shutdown sequence | Updated for lib-commons v7.21.0-beta.20+ |

**What changed:**

The inline documentation for `terminationGracePeriodSeconds` in `values.yaml` has been updated to reflect the shutdown behavior of application images built on lib-commons v7.21.0-beta.20 or later. The grace period value itself remains `115` seconds — only the explanatory comments have changed.

**Key documentation changes:**

1. **Unified shutdown budget:** The HTTP drain and lifecycle hooks now share a single 90-second budget (starting at t=15, deadline at t=105), rather than running with separate overlapping timelines
2. **Listener behavior clarified:** All listeners (HTTP, SOAP) now continue serving until `SHUTDOWN_DRAIN_DELAY` (15s) ends, then the HTTP drain and hooks consume one shared budget
3. **SHUTDOWN_TIMEOUT guidance:** The documentation now explicitly states to leave `SHUTDOWN_TIMEOUT` unset, allowing the service to calculate it automatically as `SPB_TAKE_BUDGET_SEC + SPB_PERSIST_TIMEOUT_SEC + 15s`

**Updated shutdown sequence (lib-commons v7.21.0-beta.20+):**

| Time | Event |
|------|-------|
| t=0 | SIGTERM: rail stop starts; all listeners keep serving until SHUTDOWN_DRAIN_DELAY ends |
| t≤80 | Rail finishes: one read (SPB_TAKE_BUDGET_SEC 15s) + one persist (SPB_PERSIST_TIMEOUT_SEC 60s) + 5s routing margin |
| t=15 | HTTP drain begins, then hooks run — both share ONE 90s budget (deadline t=105) |
| t=105 | Hooks wait for rail completion, then close remaining resources (10s) |
| t=115 | SIGKILL if process has not exited (grace period expires) |

**Why it matters:**

This is a **documentation-only change** with no operational impact on existing deployments. The `terminationGracePeriodSeconds` value of `115` remains correct for the default SPB budget configuration (15s read + 60s persist).

However, the updated documentation provides important guidance for operators:

- **If you override SPB budgets:** The grace period calculation remains the same (`SHUTDOWN_DRAIN_DELAY + rail_budget + 10s margin`), but you should now understand that the hooks and HTTP drain share a unified budget rather than running independently
- **If you set SHUTDOWN_TIMEOUT manually:** The new documentation recommends leaving it unset to allow automatic calculation, preventing mismatches between the timeout and your SPB configuration

**Migration action:**

None required. This is a documentation clarification only.

**If you have customized SPB budgets:**

Review your `terminationGracePeriodSeconds` to ensure it still provides adequate margin:

```yaml
config:
  SPB_TAKE_BUDGET_SEC: "20"      # Increased from default 15s
  SPB_PERSIST_TIMEOUT_SEC: "90"  # Increased from default 60s

terminationGracePeriodSeconds: 135  # 15 (SHUTDOWN_DRAIN_DELAY) + 20 + 90 + 10 (margin)
```

**If you have set SHUTDOWN_TIMEOUT manually:**

Consider removing it to allow automatic calculation:

```yaml
config:
  # SHUTDOWN_TIMEOUT: "90"  # Remove this line — let the service calculate it
  SPB_TAKE_BUDGET_SEC: "15"
  SPB_PERSIST_TIMEOUT_SEC: "60"
```

The service will automatically set `SHUTDOWN_TIMEOUT = 15 + 60 + 15 = 90s`, matching your SPB configuration.

> **Note:** If you are running application images older than lib-commons v7.21.0-beta.20, the previous shutdown behavior still applies. The documentation update prepares you for newer images but does not change the behavior of older ones.

---

## Preview changes before upgrading

```bash
helm diff upgrade br-jd-courier oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm --version 2.2.1 -n br-jd-courier
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade br-jd-courier oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm --version 2.2.1 -n br-jd-courier
```
