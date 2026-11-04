# Helm Upgrade from v2.2.0 to v2.2.1

## Topics

- **[Fixes](#fixes)**
  - [Graceful shutdown documentation update](#graceful-shutdown-documentation-update)
- **[Upgrade notes](#upgrade-notes)**
  - [Migration Job runs on every upgrade](#migration-job-runs-on-every-upgrade)

---

## Fixes

### Graceful shutdown documentation update

| Setting | v2.2.0 | v2.2.1 |
|---------|---------|---------|
| `terminationGracePeriodSeconds` | `115` | `115` (unchanged) |
| Documentation | Outdated shutdown sequence | Updated for lib-commons v7.21.0-beta.20+ |

**What changed:**

The inline documentation for `terminationGracePeriodSeconds` in `values.yaml` has been updated to reflect the shutdown behavior of application images built on lib-commons v7.21.0-beta.20 or later. The grace period value itself remains `115` seconds — only the explanatory comments have changed.

**Why it matters:**

The chart change is limited to `values.yaml` comments: the pod templates of 2.2.0 and 2.2.1 render identical, so the pods do not restart. The upgrade still runs the migration Job (see [Upgrade notes](#upgrade-notes)). The `terminationGracePeriodSeconds` value of `115` remains correct for the default SPB budget configuration (15s read + 60s persist).

The new comments also say to leave `SHUTDOWN_TIMEOUT` unset: on images built on lib-commons v7.21.0-beta.20 or later, the service sets its shutdown budget to `SPB_TAKE_BUDGET_SEC` + `SPB_PERSIST_TIMEOUT_SEC` + 15 s. A lower `SHUTDOWN_TIMEOUT` makes the hooks stop waiting for the single writer and close Postgres under an in-flight persist. If your values set `SHUTDOWN_TIMEOUT`, remove it before you move to such an image. The default image `1.2.1` does not read it.

**Migration action:**

No values change is required.

> **Note:** If you are running application images older than lib-commons v7.21.0-beta.20, the previous shutdown behavior still applies. The chart's default image `1.2.1` is one of them: it is built on lib-commons v7.19.0. The documentation update prepares you for newer images but does not change the behavior of older ones.

---

## Upgrade notes

### Migration Job runs on every upgrade

With `migrations.enabled: true` (the default), the chart renders the `br-jd-courier-migrate` Job as a `pre-install,pre-upgrade` hook. It runs `migrate up` against the Courier database on every `helm upgrade`, including this one, before the Deployments change. If the Job fails, Helm marks the upgrade as failed. The default image is `1.2.1` in both versions, so the Job applies no new migration.

---

## Preview changes before upgrading

```bash
helm diff upgrade br-jd-courier oci://ghcr.io/lerianstudio/br-jd-courier-helm --version 2.2.1 -n br-jd-courier
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Note:** The commands use GHCR, as the chart README does. An anonymous pull from `oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm` is refused with `401`.

---

## Command to upgrade

```bash
helm upgrade br-jd-courier oci://ghcr.io/lerianstudio/br-jd-courier-helm --version 2.2.1 -n br-jd-courier
```
