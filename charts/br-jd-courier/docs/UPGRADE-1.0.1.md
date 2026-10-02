# Helm Upgrade from v1.0.0 to v1.0.1

## Topics

- **[Fixes](#fixes)**
  - [Application version update](#application-version-update)
  - [Chart formatting cleanup](#chart-formatting-cleanup)

---

## Fixes

### Application version update

| Setting | v1.0.0 | v1.0.1 |
|---------|---------|---------|
| `appVersion` | `1.0.0-rc.1` | `1.0.0` |
| `jd-courier.image.tag` | `1.0.0-rc.1` | `1.0.0` |

**What changed:**

The chart now defaults to the stable `1.0.0` application release instead of the release candidate `1.0.0-rc.1`. Both the chart's `appVersion` (the fallback when `jd-courier.image.tag` is empty) and the explicit default tag in `values.yaml` have been updated.

**Why it matters:**

If you are using the default image tag (not overriding `jd-courier.image.tag` in your values), upgrading to v1.0.1 will deploy the stable `1.0.0` application image instead of the release candidate. This is the production-ready version of the br-jd-courier application.

**Migration action:**

No action required for most operators. The upgrade will automatically pull the stable `1.0.0` image.

**If you want to stay on a specific version:**

Override the tag explicitly in your `values.yaml`:

```yaml
jd-courier:
  image:
    tag: "1.0.0-rc.1"  # Pin to release candidate
```

**If you are already overriding the tag:**

Your override will continue to take precedence. Review your `values.yaml` to ensure you're using the intended version:

```yaml
jd-courier:
  image:
    tag: "1.0.0"  # Explicitly use stable release
```

> **Note:** Registry tags have no leading `v`. Always use `1.0.0`, not `v1.0.0`.

### Chart formatting cleanup

**What changed:**

The chart metadata files (`Chart.yaml` and `values.yaml`) have been reformatted to remove extraneous blank lines. No functional changes were made — only whitespace cleanup for consistency.

**Why it matters:**

This change has **no operational impact**. The rendered Kubernetes manifests are identical. This is purely a maintenance improvement to the chart source files.

**Migration action:**

None required.

---

## Preview changes before upgrading

```bash
helm diff upgrade br-jd-courier oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm --version 1.0.1 -n br-jd-courier
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade br-jd-courier oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm --version 1.0.1 -n br-jd-courier
```
