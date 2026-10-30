# Helm Upgrade from v2.1.1 to v2.1.2

## Topics

- **[Fixes](#fixes)**
  - [Application version update](#application-version-update)

---

## Fixes

### Application version update

| Setting | v2.1.1 | v2.1.2 |
|---------|---------|---------|
| `appVersion` | `1.2.0` | `1.2.1` |
| `jd-courier.image.tag` | `1.2.0` | `1.2.1` |

**What changed:**

The chart now defaults to application version `1.2.1` instead of `1.2.0`. Both the chart's `appVersion` (the fallback when `jd-courier.image.tag` is empty) and the explicit default tag in `values.yaml` have been updated.

**Why it matters:**

If you are using the default image tag (not overriding `jd-courier.image.tag` in your values), upgrading to v2.1.2 will deploy the `1.2.1` application image. This is a patch release of the br-jd-courier application that includes bug fixes and minor improvements.

**Migration action:**

No action required for most operators. The upgrade will automatically pull the `1.2.1` image.

**If you want to stay on version 1.2.0:**

Override the tag explicitly in your `values.yaml`:

```yaml
jd-courier:
  image:
    tag: "1.2.0"  # Pin to previous version
```

**If you are already overriding the tag:**

Your override will continue to take precedence. Review your `values.yaml` to ensure you're using the intended version:

```yaml
jd-courier:
  image:
    tag: "1.2.1"  # Explicitly use new version
```

> **Note:** Registry tags have no leading `v`. Always use `1.2.1`, not `v1.2.1`.

---

## Preview changes before upgrading

```bash
helm diff upgrade br-jd-courier oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm --version 2.1.2 -n br-jd-courier
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade br-jd-courier oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm --version 2.1.2 -n br-jd-courier
```
