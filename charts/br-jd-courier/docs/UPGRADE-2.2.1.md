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

**Why it matters:**

This is a **documentation-only change** with no operational impact on existing deployments. The `terminationGracePeriodSeconds` value of `115` remains correct for the default SPB budget configuration (15s read + 60s persist).

**Migration action:**

None required. This is a documentation clarification only.

> **Note:** If you are running application images older than lib-commons v7.21.0-beta.20, the previous shutdown behavior still applies. The documentation update prepares you for newer images but does not change the behavior of older ones.

---

## Preview changes before upgrading

```bash
helm diff upgrade br-jd-courier oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm --version 2.2.1 -n br-jd-courier
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Note:** An anonymous pull from `registry-1.docker.io` is refused with `401`. Without Docker Hub access, use the GHCR reference `oci://ghcr.io/lerianstudio/br-jd-courier-helm` in both commands.

---

## Command to upgrade

```bash
helm upgrade br-jd-courier oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm --version 2.2.1 -n br-jd-courier
```
